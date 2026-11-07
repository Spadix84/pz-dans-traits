-- Vitality Cartridges: its page in the Vitality Project's Guide tab.
--
-- The Guide reads DanTraits_GuideExtra when the character window is built, so
-- this only has to put the page in the table. Without the Vitality Project the
-- table sits unused and the cartridges work as before. Plain English only: the
-- Guide's pages are not translated.
DanTraits_GuideExtra = DanTraits_GuideExtra or {}
table.insert(DanTraits_GuideExtra, {
    id = "vitalitycartridges", title = "Vitality Cartridges", mod = "VitalityCartridges", order = 50,
    body = {
        "Five game cartridges for the SpiffBoy handheld console (that mod is needed). They are games first; with the Vitality Project loaded they also reach your character.",
        "",
        "## The cartridges",
        "- Still Water: paced breathing on a quiet pond (4-6, box, 4-7-8). Hold A to breathe in, let go to breathe out, and stay in step with the disc.",
        "- Steady: keep a cross on a drifting ring for twenty seconds.",
        "- Spiffo Walk: a pedometer pet that hatches, grows and finds hats as you walk. It counts steps only from a console you carry.",
        "- First Aid Quiz: forty questions on wounds, infection and medicine as this mod models them.",
        "- Spiffo Pup: a pet to feed, play with and clean up after. It gets hungry even while the console is off.",
        "",
        "## What they do to your character",
        "- A few even breaths in Still Water calm a sensory overload, stress and panic.",
        "- Steady shows what drink, shaky hands, a sugar low or a concussion are doing to you: the ring drifts the way your hands do.",
        "- Spiffo Walk's daily goal and a looked-after pup each count as a comfort against burnout; the pup lifts a depressive episode's low mood a little.",
        "- A good quiz round teaches a little First Aid.",
        "",
        "## Need to know",
        "- Screen time counts: the console's hours go into the Vitality Project's screen-time and old-games relief wherever the console is, in a bag, on the floor or in a car.",
        "- Found where SpiffBoy's own cartridges turn up, a little rarer.",
    },
})
