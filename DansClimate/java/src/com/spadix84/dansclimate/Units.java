package com.spadix84.dansclimate;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.WeakHashMap;

import se.krka.kahlua.vm.KahluaTable;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;
import zombie.iso.objects.IsoGenerator;
import zombie.iso.objects.IsoWindow;
import zombie.iso.sprite.IsoSprite;

/**
 * The player's own units as the game's objects: window air conditioners and space
 * heaters. Lua places and switches them (DansClimate_WindowAC.lua,
 * DansClimate_Heater.lua); this reads them for the room model, the generator and the hum.
 *
 * A window AC is tile appliances_windowac_01_N on the window's square: N % 4 is the
 * facing (0 S, 1 E, 2 N, 3 W), and 4-7 are switched on. Its ModData table
 * DansClimateAC keeps level ("LOW" or "HIGH") and set (the temperature it cools to).
 *
 * A space heater is tile appliances_spaceheater_01_0-3 anywhere on a floor. Its
 * ModData table DansClimateHeater keeps on, level and set (the temperature it heats to).
 *
 * The central units are tiles of appliances_hvac_01: 0-3 a furnace, 8-11 a central air
 * conditioner (its outdoor unit), 16-17 a vent. Tiles 4-7 and 12-15 are the running
 * looks, only ever drawn over a unit. The player builds all three from the build menu
 * (DansClimate_entities.txt). A furnace and a central air conditioner keep `on` in the
 * ModData table DansClimateHVAC; never set, they are on. Which building they serve and
 * how hard they work is GameBridge's business; the set `running` here is its answer,
 * for the generator, the hum and the look.
 *
 * Public, with public members: the generator patches' advice is copied into IsoObject
 * and calls in here.
 */
public final class Units {
    private Units() {}

    public static final String AC_TILES = "appliances_windowac_01_";
    public static final String HEATER_TILES = "appliances_spaceheater_01_";
    public static final String HVAC_TILES = "appliances_hvac_01_";
    public static final String AC_DATA = "DansClimateAC", HEATER_DATA = "DansClimateHeater";
    public static final String HVAC_DATA = "DansClimateHVAC";
    static final String TILES = "appliances_";

    /**
     * Generator fuel in litres an hour, as the game counts it (a stove or a washing
     * machine is 0.09, a fridge-freezer 0.13, a television 0.03).
     */
    public static final float AC_DRAW_LOW = 0.07f, AC_DRAW_HIGH = 0.11f;
    public static final float HEATER_DRAW_LOW = 0.09f, HEATER_DRAW_HIGH = 0.15f;
    /** A furnace and a central air conditioner, while they are working. */
    public static final float FURNACE_DRAW = 0.40f, CONDENSER_DRAW = 0.35f;
    /** The sandbox's Unit Generator Draw, as a factor; Lua sets it at load. */
    public static volatile double drawFactor = 1.0;

    /** The number after a tileset's prefix in the object's sprite name, or -1. */
    static int tile(IsoObject o, String prefix, int count) {
        IsoSprite sprite = o == null ? null : o.getSprite();
        String name = sprite == null ? null : sprite.getName();
        if (name == null || !name.startsWith(prefix)) return -1;
        try {
            int n = Integer.parseInt(name.substring(prefix.length()));
            return n >= 0 && n < count ? n : -1;
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    /** 0-7 for a window air conditioner (4-7 switched on), or -1. */
    public static int acTile(IsoObject o) {
        return tile(o, AC_TILES, 8);
    }

    /** 0-3 for a space heater, or -1. */
    public static int heaterTile(IsoObject o) {
        return tile(o, HEATER_TILES, 4);
    }

    public static boolean isUnit(IsoObject o) {
        IsoSprite sprite = o == null ? null : o.getSprite();
        String name = sprite == null ? null : sprite.getName();
        if (name == null || !name.startsWith(TILES)) return false;
        return name.startsWith(AC_TILES) || name.startsWith(HEATER_TILES) || isFurnace(o) || isCondenser(o);
    }

    /** The air conditioner in this window, or null. */
    public static IsoObject acIn(IsoWindow window) {
        IsoGridSquare sq = window.getSquare();
        if (sq == null) return null;
        List<IsoObject> objects = sq.getObjects();
        boolean north = window.isNorth();
        for (int i = 0; i < objects.size(); i++) {
            IsoObject o = objects.get(i);
            int n = acTile(o);
            // S and N sit in the square's north edge, E and W in its west edge
            if (n >= 0 && ((n % 2) == 0) == north) return o;
        }
        return null;
    }

    static KahluaTable data(IsoObject o, String key) {
        if (o == null || !o.hasModData()) return null;
        Object v = o.getModData().rawget(key);
        return v instanceof KahluaTable t ? t : null;
    }

    static boolean high(KahluaTable d) {
        return d == null || !"LOW".equals(d.rawget("level"));
    }

    static double setpoint(KahluaTable d, double fallback) {
        Object v = d == null ? null : d.rawget("set");
        return v instanceof Number n ? n.doubleValue() : fallback;
    }

    // -- window air conditioners ----------------------------------------------------------

    /** The square a unit blows into: its own for S and E, the one north or west for N and W. */
    static IsoGridSquare acFront(IsoObject unit, int tile) {
        IsoGridSquare sq = unit.getSquare();
        int facing = tile % 4;   // 0 S, 1 E, 2 N, 3 W
        if (sq == null || facing == 0 || facing == 1) return sq;
        return GameBridge.across(sq, facing == 2);
    }

    static boolean grid() {
        return IsoWorld.instance != null && IsoWorld.instance.isHydroPowerOn();
    }

    /** As DansClimate_WindowAC.lua's isPowered: a generator on either side, or the grid indoors. */
    static boolean acPowered(IsoObject unit, int tile) {
        IsoGridSquare sq = unit.getSquare();
        if (sq == null) return false;
        IsoGridSquare front = acFront(unit, tile);
        if (sq.haveElectricity() || (front != null && front.haveElectricity())) return true;
        return front != null && front.getRoom() != null && grid();
    }

    /** Switched on, powered, and still in its window (not an object that was taken out). */
    public static boolean acRunning(IsoObject unit) {
        int tile = acTile(unit);
        return tile >= 4 && unit.getObjectIndex() != -1 && acPowered(unit, tile);
    }

    /** What a running window AC does to its room. */
    static ZoneModel.Unit acUnit(IsoObject unit) {
        KahluaTable d = data(unit, AC_DATA);
        return new ZoneModel.Unit(high(d) ? ZoneModel.AC_HIGH : ZoneModel.AC_LOW, setpoint(d, ZoneModel.AC_SETPOINT));
    }

    // -- space heaters ----------------------------------------------------------------------

    public static boolean heaterOn(IsoObject o) {
        if (heaterTile(o) < 0) return false;
        KahluaTable d = data(o, HEATER_DATA);
        return d != null && Boolean.TRUE.equals(d.rawget("on"));
    }

    /** As DansClimate_Heater.lua's isPowered: a generator on its square, or the grid indoors. */
    static boolean heaterPowered(IsoObject o) {
        IsoGridSquare sq = o.getSquare();
        if (sq == null) return false;
        return sq.haveElectricity() || (sq.getRoom() != null && grid());
    }

    static ZoneModel.Unit heaterUnit(IsoObject o) {
        KahluaTable d = data(o, HEATER_DATA);
        return new ZoneModel.Unit(high(d) ? ZoneModel.HEATER_HIGH : ZoneModel.HEATER_LOW,
            setpoint(d, ZoneModel.HEATER_SETPOINT));
    }

    // -- the furnace, the central air conditioner and their vents ---------------------------

    /** 0-23 for a tile of the central units' sheet, or -1. */
    public static int hvacTile(IsoObject o) {
        return tile(o, HVAC_TILES, 24);
    }

    public static boolean isFurnace(IsoObject o) {
        int n = hvacTile(o);
        return n >= 0 && n <= 3;
    }

    public static boolean isCondenser(IsoObject o) {
        int n = hvacTile(o);
        return n >= 8 && n <= 11;
    }

    public static boolean isVent(IsoObject o) {
        int n = hvacTile(o);
        return n == 16 || n == 17;
    }

    /** Switched on: a unit is until somebody switches it off. */
    public static boolean centralOn(IsoObject o) {
        KahluaTable d = data(o, HVAC_DATA);
        return d == null || !Boolean.FALSE.equals(d.rawget("on"));
    }

    /**
     * The indoor square a central air conditioner is hooked up through: the first of the
     * four squares beside it that is in a map building's room (north, west, south, east).
     * Null if it stands away from any building.
     */
    public static IsoGridSquare condenserInner(IsoObject o) {
        IsoGridSquare sq = o == null ? null : o.getSquare();
        if (sq == null) return null;
        int[][] around = { { 0, -1 }, { -1, 0 }, { 0, 1 }, { 1, 0 } };
        for (int[] d : around) {
            IsoGridSquare n = GameBridge.square(sq.getX() + d[0], sq.getY() + d[1], sq.getZ());
            if (n != null && n.getRoom() != null) return n;
        }
        return null;
    }

    /** As DansClimate_Central.lua's isPowered: a generator reaching it, or the grid through the building. */
    public static boolean centralPowered(IsoObject o) {
        IsoGridSquare sq = o == null ? null : o.getSquare();
        if (sq == null) return false;
        if (sq.haveElectricity()) return true;
        if (isFurnace(o)) return sq.getRoom() != null && grid();
        if (!isCondenser(o)) return false;
        IsoGridSquare inner = condenserInner(o);
        return inner != null && (inner.haveElectricity() || grid());
    }

    /** Every central air conditioner Lua has told us about (Api.trackUnits); they stand outdoors, where no room scan finds them. */
    static final Set<IsoObject> condensers = Collections.synchronizedSet(Collections.newSetFromMap(new WeakHashMap<>()));
    /** The furnaces and central air conditioners that are working right now (GameBridge decides). */
    static final Set<IsoObject> running = Collections.synchronizedSet(Collections.newSetFromMap(new WeakHashMap<>()));

    static List<IsoObject> condensers() {
        synchronized (condensers) {
            return new ArrayList<>(condensers);
        }
    }

    /** Working: switched on, powered, in a building with a vent, and the thermostat is asking. */
    public static boolean centralRunning(IsoObject o) {
        return o != null && running.contains(o) && o.getObjectIndex() != -1;
    }

    /** Returns whether that changed anything. */
    static boolean setRunning(IsoObject o, boolean on) {
        return on ? running.add(o) : running.remove(o);
    }

    // -- the generator ------------------------------------------------------------------------

    /**
     * Litres of generator fuel an hour for a unit that is switched on, 0 for anything
     * else. The game calls this (through GeneratorDrawPatch) for every object a
     * generator might power, when it adds up its load.
     */
    public static float generatorDraw(IsoObject o) {
        try {
            if (!isUnit(o)) return 0f;
            float draw = 0f;
            int ac = acTile(o);
            if (ac >= 4) {
                draw = high(data(o, AC_DATA)) ? AC_DRAW_HIGH : AC_DRAW_LOW;
            } else if (heaterOn(o)) {
                draw = high(data(o, HEATER_DATA)) ? HEATER_DRAW_HIGH : HEATER_DRAW_LOW;
            } else if (centralRunning(o)) {
                draw = isFurnace(o) ? FURNACE_DRAW : CONDENSER_DRAW;
            }
            return (float) (draw * drawFactor);
        } catch (Throwable e) {
            return 0f;
        }
    }

    /** Have the generators in range add up their load again (a unit was switched or moved). */
    static void generatorsLookAgain(IsoGridSquare sq) {
        if (sq != null) IsoGenerator.updateGenerator(sq);
    }

    /**
     * A unit appeared on this square (placed, or loaded with its chunk): give a window
     * AC and a central air conditioner their hum, and remember the central air
     * conditioner. Returns how many units are on the square.
     */
    static int track(IsoGridSquare sq) {
        if (sq == null) return 0;
        int count = 0;
        List<IsoObject> objects = sq.getObjects();
        for (int i = 0; i < objects.size(); i++) {
            IsoObject o = objects.get(i);
            if (!isUnit(o)) continue;
            count++;
            if (acTile(o) >= 0) UnitHum.attach(o);
            if (isCondenser(o)) {
                condensers.add(o);
                UnitHum.attach(o);
            }
        }
        return count;
    }
}
