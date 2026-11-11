package com.spadix84.dansclimate;

import me.zed_0xff.zombie_buddy.Exposer;
import zombie.iso.IsoGridSquare;

/**
 * What Lua can call, as DansClimateJava.<method>(...). ZombieBuddy exposes the class
 * (it must sit in the mod's own package, like the patches). Numbers come from Lua as
 * doubles. Nothing here throws back into Lua: a failure switches the model off and logs.
 */
@Exposer.LuaClass(name = "DansClimateJava")
public class Api {
    public static String version() {
        return Main.VERSION;
    }

    /** Whether the model is running (false after an error). */
    public static boolean enabled() {
        return GameBridge.enabled;
    }

    /** One game minute: Lua's EveryOneMinute calls it, so it pauses and speeds up with the game. */
    public static void tick() {
        if (!GameBridge.enabled) return;
        try {
            GameBridge.tick();
        } catch (Throwable e) {
            GameBridge.fail(e);
        }
    }

    /** The room temperature at a square, or -999 outdoors or in a room the model doesn't cover. */
    public static double temperatureAt(double x, double y, double z) {
        try {
            IsoGridSquare sq = GameBridge.square((int) x, (int) y, (int) z);
            ZoneModel.Zone zone = sq == null ? null : GameBridge.zoneFor(sq);
            return zone == null ? -999 : zone.t;
        } catch (Throwable e) {
            GameBridge.fail(e);
            return -999;
        }
    }

    /** A few lines on the room at a square and what moves its temperature, or "" if none. */
    public static String readout(double x, double y, double z) {
        try {
            return GameBridge.readout(GameBridge.square((int) x, (int) y, (int) z));
        } catch (Throwable e) {
            GameBridge.fail(e);
            return "";
        }
    }

    /** A building's thermostat, the building named by its BuildingDef's corner (x, y). */
    public static void setThermostat(double bx, double by, String mode, double heat, double cool) {
        GameBridge.setThermostat(key(bx, by), mode == null ? "AUTO" : mode, heat, cool);
    }

    /** "MODE heat cool", e.g. "AUTO 21 24" (the default for a building never set). */
    public static String thermostat(double bx, double by) {
        ZoneModel.Thermostat th = GameBridge.thermostat(key(bx, by));
        return th.mode.name() + " " + fmt(th.heat) + " " + fmt(th.cool);
    }

    /**
     * Look at the building around a square again next minute (a unit or window changed),
     * and have the generators in range add up their load again.
     */
    public static void refreshAt(double x, double y, double z) {
        try {
            IsoGridSquare sq = GameBridge.square((int) x, (int) y, (int) z);
            Units.generatorsLookAgain(sq);
            GameBridge.dirty(sq);
        } catch (Throwable e) {
            GameBridge.fail(e);
        }
    }

    /**
     * A unit is on this square now (placed, or loaded with its chunk): a window AC gets
     * its hum. Returns how many units the square holds.
     */
    public static int trackUnits(double x, double y, double z) {
        try {
            return Units.track(GameBridge.square((int) x, (int) y, (int) z));
        } catch (Throwable e) {
            System.out.println("[DansClimate] no hum for the unit at " + (int) x + "," + (int) y + ": " + e);
            return 0;
        }
    }

    /** The sandbox's Unit Generator Draw as a factor: 1 is the mod's own rate, 0 free. */
    public static void setDrawFactor(double factor) {
        Units.drawFactor = Math.max(0, factor);
    }

    /** Generator fuel in litres an hour the units on this square cost right now (0 switched off). */
    public static double unitDraw(double x, double y, double z) {
        try {
            IsoGridSquare sq = GameBridge.square((int) x, (int) y, (int) z);
            if (sq == null) return 0;
            double sum = 0;
            for (int i = 0; i < sq.getObjects().size(); i++) {
                if (Units.isUnit(sq.getObjects().get(i))) sum += sq.getObjects().get(i).getGeneratorPowerConsumption();
            }
            return sum;
        } catch (Throwable e) {
            return -1;
        }
    }

    /**
     * A number about the player's furnaces, central air conditioners and vents in the
     * building at a square (or beside it, for a unit standing outdoors against a wall).
     * what: "furnaces", "furnacesOn", "condensers", "condensersOn" (installed, and those
     * switched on with power), "vents", "area" (the floor of the rooms with a vent),
     * "heat", "cool" (degrees an hour a vented room gets), "heatShare", "coolShare" (that as
     * a share of full strength, 0 to 1), "heating", "cooling" (1 while
     * they are working), "here" (vents in the square's own room).
     */
    public static double central(double x, double y, double z, String what) {
        try {
            return GameBridge.central(GameBridge.square((int) x, (int) y, (int) z), what);
        } catch (Throwable e) {
            GameBridge.fail(e);
            return 0;
        }
    }

    /** Whether a furnace or a central air conditioner on this square is working right now. */
    public static boolean centralRunning(double x, double y, double z) {
        try {
            IsoGridSquare sq = GameBridge.square((int) x, (int) y, (int) z);
            if (sq == null) return false;
            for (int i = 0; i < sq.getObjects().size(); i++) {
                if (Units.centralRunning(sq.getObjects().get(i))) return true;
            }
            return false;
        } catch (Throwable e) {
            return false;
        }
    }

    public static int zoneCount() {
        return GameBridge.zones.size();
    }

    static String key(double bx, double by) {
        return (int) bx + "," + (int) by;
    }

    static String fmt(double v) {
        return v == Math.rint(v) ? Integer.toString((int) v) : Double.toString(v);
    }
}
