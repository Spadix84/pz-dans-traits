package com.spadix84.dansclimate;

/**
 * The room temperature model, without any game types so it can be tested on its own
 * (java/test/ZoneModelTest.java). GameBridge fills in the zones and the weather.
 *
 * One zone per room. Its air temperature T moves each game minute by
 *
 *   dT/dt = kEnv  (Tsol    - T)   walls and roof, toward the sun-heated outside
 *         + kGnd  (Tground - T)   floor slab or basement walls
 *         + kVent (Tout    - T)   open or broken windows and open outer doors, x wind
 *         + kMix  (Tbldg   - T)   air shared with the building's other rooms
 *         + Qsun + Qfire + Qac + Qhvac
 *
 * in degrees C per game hour. The sources (sun, fire, window AC) are scaled by
 * REF_AREA / the room's area, so a fire warms a closet faster than a hall; the
 * building's own heating and cooling is sized for the building and isn't.
 * The numbers are the design note's starting values (plans/climate.md), to balance.
 */
public final class ZoneModel {
    private ZoneModel() {}

    public static final double K_ENV_HOME = 0.08, K_ENV_OTHER = 0.12, K_ENV_BASEMENT = 0.02;
    public static final double K_GND_GROUND = 0.02, K_GND_BASEMENT = 0.10;
    public static final double K_WINDOW = 0.25, K_DOOR = 0.5, WIND_REF_KPH = 20;
    public static final double K_MIX = 0.5;
    public static final double SOL_TOP = 8, SOL_OTHER = 3;
    public static final double SUN_PER_WINDOW = 0.6;
    public static final double FIRE = 3.0, MAX_FIRES = 4;
    public static final double AC_COOL = 3.0, AC_SETPOINT = 22.0;
    public static final double HVAC_HEAT = 6.0, HVAC_COOL = 4.0;
    /** How hard a thermostat or an AC pushes per degree off its setpoint (per hour). */
    public static final double GAIN = 6.0;
    public static final double REF_AREA = 20;
    /** The ground follows the outside air over about a month. */
    public static final double GROUND_HOURS = 30 * 24;

    public enum Mode { OFF, HEAT, COOL, AUTO }

    public static final class Thermostat {
        public final Mode mode;
        public final double heat, cool;

        public Thermostat(Mode mode, double heat, double cool) {
            this.mode = mode;
            this.heat = heat;
            this.cool = Math.max(cool, heat);   // the cooling setpoint is never under the heating one
        }

        public static final Thermostat DEFAULT = new Thermostat(Mode.AUTO, 21, 24);
    }

    /** The weather, the same for every zone. */
    public static final class Env {
        public double tOut = 15, tGround = 15, daylight, cloud, windKph;

        /** How strong the sun is: 0 at night or under thick cloud, 1 in a clear midday. */
        public double sun() {
            return clamp01(daylight) * (1 - 0.7 * clamp01(cloud));
        }
    }

    // The terms, in the order the readout lists them.
    public static final int ENV = 0, GND = 1, VENT = 2, MIX = 3, SUN = 4, FIRES = 5, AC = 6, HVAC = 7, TERMS = 8;
    public static final String[] TERM_NAMES = { "walls", "ground", "drafts", "other rooms", "sun", "fire", "window AC", "heating/cooling" };

    public static final class Zone {
        public final long id;
        public long building;
        public String name = "";
        public double area = REF_AREA;
        public int level;
        public boolean top, residential = true;

        // Openings and sources; the bridge refreshes these every few game minutes.
        /** Open or broken outer windows, counted 1 each (0.5 boarded up). */
        public double ventWindows;
        /** Open outer doors, counted 1 each (0.5 boarded up). */
        public double ventDoors;
        /** Outer windows letting the sun in, 1 each (less behind curtains or boards). */
        public double sunWindows;
        public int fires;
        /** Window ACs switched on and powered, blowing into this room. */
        public int acUnits;
        /** The building's heating and cooling has power. */
        public boolean powered;
        /** The building's thermostat; null for a building without heating and cooling. */
        public Thermostat thermostat = Thermostat.DEFAULT;

        public double t;
        /** The last step's terms, for the readout. */
        public final double[] terms = new double[TERMS];
        /** The game's room, for the bridge (ZoneModel never looks at it). */
        public Object handle;

        public Zone(long id) {
            this.id = id;
        }
    }

    public static double kEnv(Zone z) {
        if (z.level < 0) return K_ENV_BASEMENT;
        return z.residential ? K_ENV_HOME : K_ENV_OTHER;
    }

    public static double kGnd(Zone z) {
        if (z.level < 0) return K_GND_BASEMENT;
        return z.level == 0 ? K_GND_GROUND : 0;
    }

    public static double kVent(Zone z, Env e) {
        double wind = 1 + Math.max(0, e.windKph) / WIND_REF_KPH;
        return (K_WINDOW * z.ventWindows + K_DOOR * z.ventDoors) * wind;
    }

    /** The outside temperature the walls and roof feel, warmer in the sun. */
    public static double tSol(Zone z, Env e) {
        if (z.level < 0) return e.tOut;
        return e.tOut + e.sun() * (z.top ? SOL_TOP : SOL_OTHER);
    }

    static double scale(Zone z) {
        return REF_AREA / Math.max(1, z.area);
    }

    public static double qSun(Zone z, Env e) {
        return SUN_PER_WINDOW * z.sunWindows * e.sun() * scale(z);
    }

    public static double qFire(Zone z) {
        return FIRE * Math.min(MAX_FIRES, z.fires) * scale(z);
    }

    /** Window ACs pull the room down toward their setpoint, never below it. */
    public static double qAc(Zone z, double t) {
        if (z.acUnits <= 0 || t <= AC_SETPOINT) return 0;
        return -Math.min(AC_COOL * z.acUnits * scale(z), GAIN * (t - AC_SETPOINT));
    }

    /** The building's heating and cooling, toward the thermostat's setpoints. */
    public static double qHvac(Zone z, double t) {
        Thermostat th = z.thermostat;
        if (!z.powered || th == null || th.mode == Mode.OFF) return 0;
        boolean heat = th.mode == Mode.HEAT || th.mode == Mode.AUTO;
        boolean cool = th.mode == Mode.COOL || th.mode == Mode.AUTO;
        if (heat && t < th.heat) return Math.min(HVAC_HEAT, GAIN * (th.heat - t));
        if (cool && t > th.cool) return -Math.min(HVAC_COOL, GAIN * (t - th.cool));
        return 0;
    }

    /**
     * dT/dt in degrees per hour at temperature t, writing each term into z.terms.
     * tBldg is the building's mean temperature; NaN leaves mixing out.
     */
    public static double rate(Zone z, Env e, double t, double tBldg) {
        double[] q = z.terms;
        q[ENV] = kEnv(z) * (tSol(z, e) - t);
        q[GND] = kGnd(z) * (e.tGround - t);
        q[VENT] = kVent(z, e) * (e.tOut - t);
        q[MIX] = Double.isNaN(tBldg) ? 0 : K_MIX * (tBldg - t);
        q[SUN] = qSun(z, e);
        q[FIRES] = qFire(z);
        q[AC] = qAc(z, t);
        q[HVAC] = qHvac(z, t);
        double sum = 0;
        for (double v : q) sum += v;
        return sum;
    }

    /**
     * Move the zone on by the given game hours. Substeps keep the explicit step
     * stable however many windows are open or however long the step.
     */
    public static void step(Zone z, Env e, double tBldg, double hours) {
        double k = kEnv(z) + kGnd(z) + kVent(z, e) + (Double.isNaN(tBldg) ? 0 : K_MIX) + GAIN;
        int n = (int) Math.ceil(hours * k / 0.2);
        n = Math.max(1, Math.min(n, 10000));
        double dt = hours / n;
        for (int i = 0; i < n; i++) z.t += rate(z, e, z.t, tBldg) * dt;
        rate(z, e, z.t, tBldg);   // leave the terms for the readout at the new temperature
    }

    /**
     * The temperature the room settles at in this weather, with its heating, cooling
     * and units running, ignoring the other rooms. Where a room starts the first time
     * it's seen. rate() falls as t rises (every term does), so bisect for its zero.
     */
    public static double steadyState(Zone z, Env e) {
        double lo = -80, hi = 100;
        for (int i = 0; i < 60; i++) {
            double mid = (lo + hi) / 2;
            if (rate(z, e, mid, Double.NaN) > 0) lo = mid; else hi = mid;
        }
        double t = (lo + hi) / 2;
        rate(z, e, t, Double.NaN);
        return t;
    }

    /** The ground's temperature after some hours of this outside temperature. */
    public static double groundStep(double tGround, double tOut, double hours) {
        return tGround + (tOut - tGround) * (1 - Math.exp(-hours / GROUND_HOURS));
    }

    static double clamp01(double v) {
        return v < 0 ? 0 : (v > 1 ? 1 : v);
    }
}
