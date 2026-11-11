package com.spadix84.dansclimate;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.iso.objects.IsoWindow;

/**
 * IsoWindow.canClimbThrough: nobody, player or zombie, climbs through a window with an
 * air conditioner in it. The Lua side already refuses the player's open and climb
 * actions; this covers the game's own checks, which zombies go through, and a smashed
 * window, which needs no opening.
 *
 * A unit is an object on the window's square with tile appliances_windowac_01_N:
 * N % 4 is 0 (S) or 2 (N) for a window in the square's north edge, 1 (E) or 3 (W) for
 * one in its west edge (see DansClimate_WindowAC.lua, and Units, which finds it).
 */
@Patch(className = "zombie.iso.objects.IsoWindow", methodName = "canClimbThrough")
public class WindowClimbPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object self, @Patch.Return(readOnly = false) boolean result) {
        if (result && self instanceof IsoWindow window && hasUnit(window)) result = false;
    }

    public static boolean hasUnit(IsoWindow window) {
        return unitTile(window) >= 0;
    }

    /** The tile number (0-7, 4-7 switched on) of the unit in this window, or -1. */
    public static int unitTile(IsoWindow window) {
        return Units.acTile(Units.acIn(window));
    }
}
