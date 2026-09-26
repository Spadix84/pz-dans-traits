-- Registers this mod's traits with the B42 CharacterTrait registry.
-- This file is loaded early, before scripts are parsed, so the
-- character_trait_definition blocks in media/scripts can resolve them.

DanTraitsRegistry = {}

DanTraitsRegistry.dependent = CharacterTrait.register("DanTraits:dependent")
DanTraitsRegistry.brittle   = CharacterTrait.register("DanTraits:brittle")
DanTraitsRegistry.jinxed    = CharacterTrait.register("DanTraits:jinxed")
DanTraitsRegistry.spiraling = CharacterTrait.register("DanTraits:spiraling")
DanTraitsRegistry.badday    = CharacterTrait.register("DanTraits:badday")
DanTraitsRegistry.schizophrenia = CharacterTrait.register("DanTraits:schizophrenia")
DanTraitsRegistry.asthma    = CharacterTrait.register("DanTraits:asthma")
DanTraitsRegistry.gluten    = CharacterTrait.register("DanTraits:gluten")
DanTraitsRegistry.vegetarian = CharacterTrait.register("DanTraits:vegetarian")
DanTraitsRegistry.diabetes1 = CharacterTrait.register("DanTraits:diabetes1")
DanTraitsRegistry.diabetes2 = CharacterTrait.register("DanTraits:diabetes2")
DanTraitsRegistry.renfaire  = CharacterTrait.register("DanTraits:renfaire")
DanTraitsRegistry.gymregular = CharacterTrait.register("DanTraits:gymregular")
DanTraitsRegistry.arthritis = CharacterTrait.register("DanTraits:arthritis")
DanTraitsRegistry.caffeine  = CharacterTrait.register("DanTraits:caffeine")
DanTraitsRegistry.migraine  = CharacterTrait.register("DanTraits:migraine")
DanTraitsRegistry.hemophilia = CharacterTrait.register("DanTraits:hemophilia")
DanTraitsRegistry.anemia    = CharacterTrait.register("DanTraits:anemia")
DanTraitsRegistry.ironstomach = CharacterTrait.register("DanTraits:ironstomach")
DanTraitsRegistry.earlyriser = CharacterTrait.register("DanTraits:earlyriser")
DanTraitsRegistry.mealprepper = CharacterTrait.register("DanTraits:mealprepper")
