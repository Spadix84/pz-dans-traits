package com.spadix84.dansclimate;

import java.util.ArrayList;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import com.spadix84.dansclimate.ZoneModel.Env;
import com.spadix84.dansclimate.ZoneModel.Mode;
import com.spadix84.dansclimate.ZoneModel.Thermostat;
import com.spadix84.dansclimate.ZoneModel.Zone;

import zombie.iso.BuildingDef;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;
import zombie.iso.areas.IsoBuilding;
import zombie.iso.areas.IsoRoom;
import zombie.iso.objects.IsoCurtain;
import zombie.iso.objects.IsoDoor;
import zombie.iso.objects.IsoFire;
import zombie.iso.objects.IsoFireplace;
import zombie.iso.objects.IsoWindow;
import zombie.iso.weather.ClimateManager;

/**
 * Reads the game into ZoneModel: which rooms there are, their windows, doors, fires
 * and window ACs, the weather and the power. Map buildings only (rooms with an
 * IsoRoom); a room the player built has none and keeps the vanilla rule for now.
 *
 * A building's rooms become zones the first time anything asks for the temperature
 * inside it (the player walking in, the clock reading it), starting from the steady
 * state for the weather. They're stepped each game minute from Lua (Api.tick) while
 * loaded, and forgotten when their chunk unloads; nothing is saved but the thermostats,
 * which Lua keeps in global ModData and hands over with Api.setThermostat.
 */
public final class GameBridge {
    private GameBridge() {}

    /** Every few game minutes the windows, doors, fires and units are looked at again. */
    static final int REFRESH_MINUTES = 10;

    static final class Building {
        final long id;
        final String key;
        final List<Zone> zones = new ArrayList<>();
        int refreshed = Integer.MIN_VALUE / 2;
        volatile boolean dirty;

        Building(long id, String key) {
            this.id = id;
            this.key = key;
        }
    }

    /** What the bridge keeps for a zone besides the model's state. */
    static final class Room {
        IsoRoom room;
        final int x, y, z;   // one of its squares, to tell whether it's still loaded
        boolean generator;   // a generator reaches it

        Room(IsoRoom room, IsoGridSquare sample) {
            this.room = room;
            x = sample.getX();
            y = sample.getY();
            z = sample.getZ();
        }
    }

    static final Map<Long, Zone> zones = new ConcurrentHashMap<>();
    static final Map<Long, Building> buildings = new ConcurrentHashMap<>();
    static final Map<String, Thermostat> thermostats = new ConcurrentHashMap<>();
    static final Env env = new Env();
    static volatile boolean envReady;
    static volatile boolean enabled = true;
    static int minute;
    static boolean grid;

    // -- the hot path -----------------------------------------------------------------

    /** The zone for an indoor square, made on first sight; null outdoors or in a player-built room. */
    public static Zone zoneFor(IsoGridSquare sq) {
        IsoRoom room = sq.getRoom();
        if (room == null || room.def == null) return null;
        Zone z = zones.get(room.def.id);
        if (z != null) {
            Room r = (Room) z.handle;
            if (r.room != room) r.room = room;   // the chunk was reloaded
            return z;
        }
        return register(room);
    }

    // -- making zones -----------------------------------------------------------------

    static synchronized Zone register(IsoRoom room) {
        Zone found = zones.get(room.def.id);
        if (found != null) return found;
        IsoBuilding b = room.getBuilding();
        if (b == null || b.def == null) return null;
        updateEnv();
        Building bld = buildings.computeIfAbsent(b.def.id, id -> new Building(id, key(b.def)));
        for (IsoRoom r : new ArrayList<>(b.rooms)) {
            if (r == null || r.def == null || zones.containsKey(r.def.id)) continue;
            List<IsoGridSquare> squares = r.getSquares();
            if (squares.isEmpty()) continue;   // not loaded yet: made when it's asked for
            Zone z = new Zone(r.def.id);
            z.building = b.def.id;
            z.name = r.getName() == null ? "" : r.getName();
            z.area = Math.max(1, squares.size());
            z.level = r.def.level;
            z.top = r.def.level >= b.def.getMaxLevel();
            z.residential = b.isResidential();
            z.handle = new Room(r, squares.get(0));
            refresh(z, bld);
            z.t = ZoneModel.steadyState(z, env);
            bld.zones.add(z);
            zones.put(z.id, z);
        }
        return zones.get(room.def.id);
    }

    static String key(BuildingDef def) {
        return def.getX() + "," + def.getY();
    }

    // -- reading a room -----------------------------------------------------------------

    static IsoGridSquare square(int x, int y, int z) {
        IsoCell cell = IsoWorld.instance == null ? null : IsoWorld.instance.getCell();
        return cell == null ? null : cell.getGridSquare(x, y, z);
    }

    /** The square on the far side of an edge object (north edge: the one north of it). */
    static IsoGridSquare across(IsoGridSquare sq, boolean north) {
        return north ? square(sq.getX(), sq.getY() - 1, sq.getZ()) : square(sq.getX() - 1, sq.getY(), sq.getZ());
    }

    /** Whether an edge object between sq and its neighbour is in this room's outer wall. */
    static boolean outer(IsoRoom room, IsoGridSquare sq, boolean north) {
        IsoGridSquare other = across(sq, north);
        IsoRoom a = sq.getRoom(), b = other == null ? null : other.getRoom();
        return (a == room && b == null) || (b == room && a == null);
    }

    /** Look at the room's windows, doors, fires and units again. */
    static void refresh(Zone z, Building bld) {
        Room r = (Room) z.handle;
        IsoRoom room = r.room;
        z.thermostat = thermostats.getOrDefault(bld.key, Thermostat.DEFAULT);
        z.ventWindows = z.ventDoors = z.sunWindows = 0;
        z.fires = z.acUnits = 0;
        r.generator = false;
        Set<IsoObject> seen = Collections.newSetFromMap(new IdentityHashMap<>());
        for (IsoGridSquare sq : room.getSquares()) {
            if (sq == null) continue;
            if (!r.generator && sq.haveElectricity()) r.generator = true;
            // edge objects in this square's north and west edges, and in its south and
            // east edges (which belong to the squares beyond them)
            scanEdges(z, room, sq, seen);
            scanEdges(z, room, square(sq.getX(), sq.getY() + 1, sq.getZ()), seen);
            scanEdges(z, room, square(sq.getX() + 1, sq.getY(), sq.getZ()), seen);
            List<IsoObject> objects = sq.getObjects();
            for (int i = 0; i < objects.size(); i++) {
                IsoObject o = objects.get(i);
                if (o instanceof IsoFireplace f && f.isLit()) z.fires++;
                else if (o instanceof IsoFire) z.fires++;
            }
        }
        z.powered = grid || r.generator;
    }

    static void scanEdges(Zone z, IsoRoom room, IsoGridSquare sq, Set<IsoObject> seen) {
        if (sq == null) return;
        List<IsoObject> objects = sq.getObjects();
        for (int i = 0; i < objects.size(); i++) {
            IsoObject o = objects.get(i);
            if (o instanceof IsoWindow w) {
                if (seen.add(w) && outer(room, sq, w.isNorth())) window(z, room, w);
            } else if (o instanceof IsoDoor d) {
                if (seen.add(d) && outer(room, sq, d.isNorth()) && (d.IsOpen() || d.isDestroyed())) {
                    z.ventDoors += d.isBarricaded() ? 0.5 : 1;
                }
            }
        }
    }

    static void window(Zone z, IsoRoom room, IsoWindow w) {
        int unit = WindowClimbPatch.unitTile(w);
        if (unit >= 0) {
            // the unit and its side panels fill the opening, and it may blow into this room
            if (unit >= 4 && unitRoom(w, unit) == room && unitPowered(w, unit)) z.acUnits++;
            z.sunWindows += 0.5;
            return;
        }
        boolean open = w.IsOpen() || w.isSmashed() || w.isGlassRemoved() || w.isDestroyed();
        boolean boarded = w.isBarricaded();
        if (open) z.ventWindows += boarded ? 0.5 : 1;
        double sun = 1;
        if (boarded) sun = 0.3;
        IsoCurtain curtain = w.HasCurtains();
        if (curtain != null && !curtain.IsOpen()) sun = Math.min(sun, 0.3);
        z.sunWindows += sun;
    }

    /** The square a unit blows into: its own for S and E, the one north or west for N and W. */
    static IsoGridSquare unitFront(IsoWindow w, int tile) {
        IsoGridSquare sq = w.getSquare();
        int facing = tile % 4;   // 0 S, 1 E, 2 N, 3 W
        if (facing == 0 || facing == 1) return sq;
        return across(sq, facing == 2);
    }

    static IsoRoom unitRoom(IsoWindow w, int tile) {
        IsoGridSquare front = unitFront(w, tile);
        return front == null ? null : front.getRoom();
    }

    /** As DansClimate_WindowAC.lua's isPowered: a generator on either side, or the grid indoors. */
    static boolean unitPowered(IsoWindow w, int tile) {
        IsoGridSquare front = unitFront(w, tile);
        if (w.getSquare().haveElectricity() || (front != null && front.haveElectricity())) return true;
        return front != null && front.getRoom() != null && grid;
    }

    // -- the weather ----------------------------------------------------------------------

    static void updateEnv() {
        ClimateManager cm = ClimateManager.getInstance();
        if (cm == null) return;
        env.tOut = cm.getTemperature();
        env.daylight = cm.getDayLightStrength();
        env.cloud = cm.getCloudIntensity();
        env.windKph = cm.getWindspeedKph();
        if (!envReady) {
            env.tGround = cm.getDayMeanTemperature();
            envReady = true;
        }
        grid = IsoWorld.instance != null && IsoWorld.instance.isHydroPowerOn();
    }

    // -- each game minute -----------------------------------------------------------------

    public static synchronized void tick() {
        updateEnv();
        if (!envReady) return;
        env.tGround = ZoneModel.groundStep(env.tGround, env.tOut, 1.0 / 60);
        minute++;
        for (Iterator<Building> it = buildings.values().iterator(); it.hasNext(); ) {
            Building bld = it.next();
            // forget rooms whose chunk has unloaded
            for (Iterator<Zone> zi = bld.zones.iterator(); zi.hasNext(); ) {
                Zone z = zi.next();
                Room r = (Room) z.handle;
                IsoGridSquare sample = square(r.x, r.y, r.z);
                if (sample == null || sample.getRoom() == null) {
                    zi.remove();
                    zones.remove(z.id);
                } else if (sample.getRoom() != r.room) {
                    r.room = sample.getRoom();
                }
            }
            if (bld.zones.isEmpty()) {
                it.remove();
                continue;
            }
            boolean refresh = bld.dirty || minute - bld.refreshed >= REFRESH_MINUTES;
            if (refresh) {
                bld.dirty = false;
                bld.refreshed = minute;
            }
            double sum = 0, area = 0;
            for (Zone z : bld.zones) {
                if (refresh) refresh(z, bld);
                else z.powered = grid || ((Room) z.handle).generator;
                sum += z.t * z.area;
                area += z.area;
            }
            double tBldg = bld.zones.size() > 1 ? sum / area : Double.NaN;
            for (Zone z : bld.zones) ZoneModel.step(z, env, tBldg, 1.0 / 60);
        }
    }

    // -- from Lua -------------------------------------------------------------------------

    static synchronized void setThermostat(String key, String mode, double heat, double cool) {
        Mode m;
        try {
            m = Mode.valueOf(mode.toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            m = Mode.AUTO;
        }
        Thermostat th = new Thermostat(m, heat, cool);
        thermostats.put(key, th);
        for (Building bld : buildings.values()) {
            if (bld.key.equals(key)) for (Zone z : bld.zones) z.thermostat = th;
        }
    }

    static Thermostat thermostat(String key) {
        return thermostats.getOrDefault(key, Thermostat.DEFAULT);
    }

    /** Look at a building's windows and units again on the next tick (after the player changes one). */
    static void dirty(IsoGridSquare sq) {
        if (sq == null) return;
        Zone z = zoneFor(sq);
        if (z == null) {
            // a unit's own square is often outdoors (W and N facings): try its neighbours
            for (int[] d : new int[][] { { 0, -1 }, { -1, 0 }, { 0, 1 }, { 1, 0 } }) {
                IsoGridSquare n = square(sq.getX() + d[0], sq.getY() + d[1], sq.getZ());
                if (n != null && (z = zoneFor(n)) != null) break;
            }
        }
        if (z == null) return;
        Building bld = buildings.get(z.building);
        if (bld != null) bld.dirty = true;
    }

    static String readout(IsoGridSquare sq) {
        Zone z = sq == null ? null : zoneFor(sq);
        if (z == null) return "";
        Building bld = buildings.get(z.building);
        StringBuilder s = new StringBuilder();
        s.append(String.format(Locale.ROOT, "%s, level %d, %.0f tiles%s%s\n", z.name, z.level, z.area,
            z.top ? ", top floor" : "", z.residential ? ", house" : ""));
        s.append(String.format(Locale.ROOT, "Room %.1f C, outside %.1f C, ground %.1f C, sun %.2f\n",
            z.t, env.tOut, env.tGround, env.sun()));
        Thermostat th = z.thermostat;
        s.append(String.format(Locale.ROOT, "Thermostat %s, heat %.0f C, cool %.0f C, %s\n",
            th == null ? "none" : th.mode.name(), th == null ? 0 : th.heat, th == null ? 0 : th.cool,
            z.powered ? "powered" : "no power"));
        s.append(String.format(Locale.ROOT, "Open windows %.1f, open doors %.1f, sunlit windows %.1f, fires %d, window ACs on %d\n",
            z.ventWindows, z.ventDoors, z.sunWindows, z.fires, z.acUnits));
        s.append("Per hour:");
        double sum = 0;
        for (int i = 0; i < ZoneModel.TERMS; i++) {
            double v = z.terms[i];
            sum += v;
            if (Math.abs(v) >= 0.005) s.append(String.format(Locale.ROOT, " %s %+.2f,", ZoneModel.TERM_NAMES[i], v));
        }
        s.append(String.format(Locale.ROOT, " total %+.2f C/h\n", sum));
        s.append(String.format(Locale.ROOT, "Building: %d rooms tracked, %s", bld == null ? 0 : bld.zones.size(),
            bld == null ? "?" : bld.key));
        return s.toString();
    }

    static void fail(Throwable e) {
        if (!enabled) return;
        enabled = false;
        System.out.println("[DansClimate] room temperatures off after an error: " + e);
        e.printStackTrace();
    }
}
