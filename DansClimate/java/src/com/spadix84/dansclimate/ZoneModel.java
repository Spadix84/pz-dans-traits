package com.spadix84.dansclimate;

import java.util.ArrayList;
import java.util.List;

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
 *         + Qsun + Qfire + Qac + Qheater + Qhvac + Qcentral
 *
 * in degrees C per game hour. The sources (sun, fire, window AC, space heater) are
 * scaled by REF_AREA / the room's area, so a fire warms a closet faster than a hall;
 * the building's own heating and cooling is sized for the building and isn't.
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
    /** A window AC on low and on high, and what it cools to if its dial was never touched. */
    public static final double AC_LOW = 1.5, AC_HIGH = 3.0, AC_SETPOINT = 22.0;
    /** A space heater on low and on high, and what it heats to if its dial was never touched. */
    public static final double HEATER_LOW = 2.0, HEATER_HIGH = 4.0, HEATER_SETPOINT = 21.0;
    public static final double HVAC_HEAT = 6.0, HVAC_COOL = 4.0;
    /**
     * A furnace or a central air conditioner the player installed: what one gives each
     * room with a vent, in degrees an hour, while the vented floor is CENTRAL_AREA tiles
     * or less. Past that the same output is shared, so every extra room slows them all.
     */
    public static final double CENTRAL_HEAT = 6.0, CENTRAL_COOL = 4.0, CENTRAL_AREA = 120;
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

    /**
     * A window AC or a space heater working on a room: how hard it can push, in
     * degrees an hour in a REF_AREA room, and the temperature its dial is set to.
     */
    public static final class Unit {
        public final double power, setpoint;

        public Unit(double power, double setpoint) {
            this.power = power;
            this.setpoint = setpoint;
        }
    }

    // The terms, in the order the readout lists them.
    public static final int ENV = 0, GND = 1, VENT = 2, MIX = 3, SUN = 4, FIRES = 5, AC = 6, HVAC = 7, HEATER = 8, CENTRAL = 9, TERMS = 10;
    public static final String[] TERM_NAMES = { "walls", "ground", "drafts", "other rooms", "sun", "fire", "window AC", "heating/cooling", "space heater", "furnace/central air" };

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
        public final List<Unit> acs = new ArrayList<>();
        /** Space heaters switched on and powered, standing in this room. */
        public final List<Unit> heaters = new ArrayList<>();
        /** The building's heating and cooling has power: the grid, never a generator. */
        public boolean powered;
        /** The building's thermostat; null for a building without heating and cooling. */
        public Thermostat thermostat = Thermostat.DEFAULT;
        /** Vents the player built in this room: with one, the furnace and central air reach it. */
        public int vents;
        /**
         * What the building's running furnaces and central air conditioners can give
         * this room, in degrees an hour (centralShare); 0 without a vent or a unit.
         */
        public double centralHeat, centralCool;

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

    /** Window ACs pull the room down toward their setpoints, never below them. */
    public static double qAc(Zone z, double t) {
        double q = 0;
        for (int i = 0; i < z.acs.size(); i++) {
            Unit u = z.acs.get(i);
            if (t > u.setpoint) q -= Math.min(u.power * scale(z), GAIN * (t - u.setpoint));
        }
        return q;
    }

    /** Space heaters push the room up toward their setpoints, never above them. */
    public static double qHeater(Zone z, double t) {
        double q = 0;
        for (int i = 0; i < z.heaters.size(); i++) {
            Unit u = z.heaters.get(i);
            if (t < u.setpoint) q += Math.min(u.power * scale(z), GAIN * (u.setpoint - t));
        }
        return q;
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
     * What each vented room gets from `units` running furnaces (or central air
     * conditioners) of `full` strength sharing `ventedArea` tiles of floor.
     */
    public static double centralShare(double full, int units, double ventedArea) {
        if (units <= 0 || ventedArea <= 0) return 0;
        return Math.min(full, full * units * CENTRAL_AREA / ventedArea);
    }

    /** The thermostat calls for heat (or for cooling) in a room at temperature t. */
    public static boolean wantsHeat(Thermostat th, double t) {
        return th != null && (th.mode == Mode.HEAT || th.mode == Mode.AUTO) && t < th.heat;
    }

    public static boolean wantsCool(Thermostat th, double t) {
        return th != null && (th.mode == Mode.COOL || th.mode == Mode.AUTO) && t > th.cool;
    }

    /**
     * The player's furnace and central air conditioner, through this room's vent,
     * toward the building thermostat's setpoints. They don't need the grid.
     */
    public static double qCentral(Zone z, double t) {
        Thermostat th = z.thermostat;
        if (z.vents <= 0) return 0;
        if (z.centralHeat > 0 && wantsHeat(th, t)) return Math.min(z.centralHeat, GAIN * (th.heat - t));
        if (z.centralCool > 0 && wantsCool(th, t)) return -Math.min(z.centralCool, GAIN * (t - th.cool));
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
        q[HEATER] = qHeater(z, t);
        q[CENTRAL] = qCentral(z, t);
        double sum = 0;
        for (double v : q) sum += v;
        return sum;
    }

    /**
     * Move the zone on by the given game hours. Substeps keep the explicit step
     * stable however many windows are open or however long the step.
     */
    public static void step(Zone z, Env e, double tBldg, double hours) {
        // every thermostat (the building's, the central units', each unit's) can be as steep as GAIN
        double k = kEnv(z) + kGnd(z) + kVent(z, e) + (Double.isNaN(tBldg) ? 0 : K_MIX)
            + GAIN * (2 + z.acs.size() + z.heaters.size());
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
