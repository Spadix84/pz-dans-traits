package com.spadix84.dansclimate;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoWorld;

/**
 * ClimateManager.getAirTemperatureForSquare: where the game decides how warm a square
 * is. Inside a map building (and not in a vehicle), the answer becomes the room's
 * temperature from the model (GameBridge, ZoneModel) instead of vanilla's flat 22 C
 * with grid power or its fixed share of the outside without.
 *
 * Vanilla's later steps are kept: the hottest heat source reaching the square (a
 * campfire, a stove) still wins if it's warmer. Outdoors and in vehicles nothing
 * changes. Player-built rooms have no IsoRoom and keep the vanilla rule for now.
 *
 * The method has three overloads; the one- and two-argument ones call the
 * three-argument one, so the advice runs at every level. Only the three-argument call
 * (args.length == 3) is acted on, and the outer ones return its changed result.
 *
 * The advice body is copied into ClimateManager itself, so it may only touch public
 * classes and members: it hands everything to roomTemperature(), which runs here as
 * ordinary code with the package's access. (Reading GameBridge.enabled straight from
 * the advice threw IllegalAccessError in the game's main thread and crashed it.)
 */
@Patch(className = "zombie.iso.weather.ClimateManager", methodName = "getAirTemperatureForSquare")
public class AirTemperaturePatch {
    public static volatile boolean seenIndoor;

    @Patch.OnExit
    public static void exit(@Patch.AllArguments Object[] args, @Patch.Return(readOnly = false) float result) {
        if (args.length == 3 && args[1] == null && args[0] instanceof IsoGridSquare) {
            result = AirTemperaturePatch.roomTemperature((IsoGridSquare) args[0], result);
        }
    }

    /** The temperature for a square inside a map building, or vanilla's when the model has none. */
    public static float roomTemperature(IsoGridSquare sq, float vanilla) {
        try {
            if (!GameBridge.enabled || sq.getRoom() == null) return vanilla;
            ZoneModel.Zone zone = GameBridge.zoneFor(sq);
            if (zone == null) return vanilla;
            float t = (float) zone.t;
            float heat = IsoWorld.instance.getCell().getHeatSourceHighestTemperature(t, sq.getX(), sq.getY(), sq.getZ());
            float result = Math.max(t, heat);
            if (!seenIndoor) {
                seenIndoor = true;
                System.out.println("[DansClimate] room temperatures live: " + zone.name + " at " + sq.getX() + ","
                    + sq.getY() + "," + sq.getZ() + " = " + result + " C (vanilla " + vanilla + " C)");
            }
            return result;
        } catch (Throwable e) {
            GameBridge.fail(e);
            return vanilla;
        }
    }
}
