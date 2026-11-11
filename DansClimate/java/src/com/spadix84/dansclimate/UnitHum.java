package com.spadix84.dansclimate;

import zombie.audio.BaseSoundEmitter;
import zombie.audio.ObjectAmbientEmitters;
import zombie.iso.IsoChunk;
import zombie.iso.IsoObject;

/**
 * A running window air conditioner hums, and so does a central air conditioner's
 * outdoor unit while it is working. The game keeps a list of objects with an
 * ambient sound in each chunk (fridges, humming lights) and plays the nearest ones to
 * the player; this adds a unit to that list with its own rule for when it sounds:
 * switched on and powered. The sound is the game's own fridge hum.
 *
 * This is only what the player hears. What zombies hear is a world sound Lua makes
 * every few minutes (DansClimate_WindowACServer.lua).
 */
public final class UnitHum extends ObjectAmbientEmitters.PerObjectLogic {
    public static final String SOUND = "FridgeHumB";

    @Override
    public boolean shouldPlaySound() {
        try {
            return Units.acRunning(object) || Units.centralRunning(object);
        } catch (Throwable e) {
            return false;
        }
    }

    @Override
    public String getSoundName() {
        return SOUND;
    }

    @Override
    public void startPlaying(BaseSoundEmitter emitter, long instance) {}

    @Override
    public void checkParameters(BaseSoundEmitter emitter, long instance) {}

    /** Put a unit on its chunk's list, once. The game takes it off when the object goes. */
    static void attach(IsoObject unit) {
        IsoChunk chunk = unit.getChunk();
        if (chunk == null || chunk.hasObjectAmbientEmitter(unit)) return;
        chunk.addObjectAmbientEmitter(unit, new UnitHum().init(unit));
    }
}
