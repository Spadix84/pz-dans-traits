package com.spadix84.dansclimate;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.iso.IsoObject;

/**
 * IsoObject.couldBePoweredByGenerator: whether a generator should look at this object
 * at all. The game asks when an object joins or leaves the world (IsoObject.addToWorld,
 * removeFromWorld) and keeps the answer in the chunk's list of things generators add up.
 * For a plain object it is true only for fridges and fuel pumps; window air
 * conditioners and space heaters now count too, so GeneratorDrawPatch gets asked for them.
 *
 * The advice body is copied into IsoObject, so it only calls a public method of ours.
 */
@Patch(className = "zombie.iso.IsoObject", methodName = "couldBePoweredByGenerator")
public class GeneratorPoweredPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object self, @Patch.Return(readOnly = false) boolean result) {
        if (!result && self instanceof IsoObject object && Units.isUnit(object)) result = true;
    }
}
