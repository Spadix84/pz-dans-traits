package com.spadix84.dansclimate;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.iso.IsoObject;

/**
 * IsoObject.getGeneratorPowerConsumption: what an object costs a generator in fuel. A
 * generator adds this up over everything in range when something changes
 * (IsoGenerator.setSurroundingElectricity), and lists each kind by its tile's name in
 * its info window. A switched-on window air conditioner or space heater now has a
 * cost (Units.generatorDraw); the game's own answer for a plain object is 0 unless it
 * holds a fridge or a fuel pump.
 *
 * The advice body is copied into IsoObject, so it only calls a public method of ours.
 */
@Patch(className = "zombie.iso.IsoObject", methodName = "getGeneratorPowerConsumption")
public class GeneratorDrawPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object self, @Patch.Return(readOnly = false) float result) {
        if (result <= 0f && self instanceof IsoObject object) result = Units.generatorDraw(object);
    }
}
