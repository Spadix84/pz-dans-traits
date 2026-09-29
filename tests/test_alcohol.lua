-- Offline test for DanTraits_Alcohol.lua: a drink no longer counts as a
-- beta blocker and a painkiller; instead the Drunk moodle floors the body's
-- pain reduction by level and speeds panic decay each tick. DanTraits_Diabetes
-- is loaded too: both wrap ISDrinkFluidAction.updateEat, and the meds restore
-- and the `drink` hook must both work (they once shared a guard flag, so only
-- one of them was ever installed).
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()

-- vanilla-shaped drink action: updateEat reaches DrinkFluid, which for any
-- alcohol at all sets the beta-blocker and painkiller timers in full; the
-- container also loses a sip, as the real fluid container does
ISDrinkFluidAction = {}
function ISDrinkFluidAction:updateEat(delta)
  self.character:DrinkFluid(self.fluidContainer, delta)
  self.fluidContainer._amount = self.fluidContainer._amount - 0.1
end

H.load("Diabetes", "Alcohol")
H.expectEvery("minute", "Alcohol")
H.expectEvery("frame", "Alcohol")
local drinkWraps = ISDrinkFluidAction.DanTraitsWraps
assert(drinkWraps and drinkWraps["updateEat:alcohol-relief"] and drinkWraps["updateEat:drink-intake"], "both drink layers installed")

-- the one definition of drunk: named thresholds, and a 0..1 intoxication read
assert(DanTraits_DRINK and DanTraits_DRINK.any == 0.01 and DanTraits_DRINK.tipsy == 0.05
  and DanTraits_DRINK.buzz == 0.20 and DanTraits_DRINK.sober == 0.05, "DanTraits_DRINK thresholds")

local newPlayer = H.factory({ moodles = {} }, function(p)
  p.DrinkFluid = function(self, container, delta)
    local alcohol = container:getProperties():getAlcohol()
    if alcohol > 0 then
      self._beta, self._betaD = 6600, self._betaD + 0.2 * alcohol
      self._painFx, self._painD = 5400, self._painD + 0.2 * alcohol
    end
  end
end)
local function container(alcohol)
  return { _amount = 1, getAmount = function(self) return self._amount end,
           getProperties = function() return { getAlcohol = function() return alcohol end, getCarbohydrates = function() return 0 end } end }
end
local lastContainer
local function drink(p, alcohol)
  lastContainer = container(alcohol)
  ISDrinkFluidAction.updateEat({ character = p, fluidContainer = lastContainer }, 0.1)
end
local drinkHook = {}
DanTraits_AddHook("drink", function(_, player, fluid, litres) drinkHook[#drinkHook + 1] = { player = player, fluid = fluid, litres = litres } end)
local minute, frame = H.minute, H.frame
local near = H.near

-- 1. a sip of whiskey no longer sets the pill timers
local p = newPlayer(); H.current = p; p._moodles.drunk = 0
drink(p, 0.004)
assert(p._beta == 0 and p._betaD == 0, "beta-blocker timer put back")
assert(p._painFx == 0 and p._painD == 0, "painkiller timer put back")

-- 1b. and the Diabetes layer on the same method still ran: the drink hook fired with the litres swallowed
assert(#drinkHook == 1 and drinkHook[1].player == p and drinkHook[1].fluid == lastContainer and math.abs(drinkHook[1].litres - 0.1) < 1e-9,
  "drink hook fired once with player, fluid and litres")

p._st.intox = 40; near(DanTraits_Intoxication(p), 0.4, 1e-9, "intoxication read as 0..1"); p._st.intox = 0

-- 2. pills taken earlier keep working
p._beta, p._betaD, p._painFx, p._painD = 3000, 1, 2000, 1
drink(p, 0.4)
assert(p._beta == 3000 and p._betaD == 1 and p._painFx == 2000 and p._painD == 1, "earlier pills untouched")

-- 3. a soft drink is left alone (the wrapper only steps in for alcohol)
local soft = newPlayer(); H.current = soft; soft._moodles.drunk = 0
soft.DrinkFluid = function(self) self._painFx = 7 end   -- some other effect on the character
drink(soft, 0)
assert(soft._painFx == 7, "non-alcoholic: nothing restored")
assert(#drinkHook == 3 and drinkHook[3].player == soft, "every drink (pills-taken case included) fires the drink hook, soft drinks too")

-- 4. pain: the reduction floor follows the Drunk level, steps down as you sober, keeps other sources
H.current = p
p._moodles.drunk = 2; minute(); near(p._pr, 40, 1e-9, "level 2: 40")
p._moodles.drunk = 4; minute(); near(p._pr, 80, 1e-9, "level 4: 80")
p._pr = p._pr + 10                                       -- a medicinal fluid's own reduction
p._moodles.drunk = 3; minute(); near(p._pr, 70, 1e-9, "level 3 with 10 from elsewhere: 60 + 10")
p._pr = p._pr - 0.3                                       -- vanilla decay over the minute
p._moodles.drunk = 1; minute(); near(p._pr, 29.7, 1e-9, "level 1: 20 + the other 9.7")
p._moodles.drunk = 0; minute(); near(p._pr, 9.7, 1e-9, "sober: only the other source is left")
assert(p._md.DanTraits.alcPainCut == 0, "bookkeeping cleared")
minute(); near(p._pr, 9.7, 1e-9, "sober and nothing applied: not touched")

-- 5. panic: level 4 takes the beta-blocker rate (0.6 a tick), level 1 a quarter of it; not while asleep or sober
p._st.panic = 50; p._moodles.drunk = 4; frame(p); near(p._st.panic, 49.4, 1e-9, "level 4: 0.6")
p._moodles.drunk = 1; frame(p); near(p._st.panic, 49.25, 1e-9, "level 1: 0.15")
p._asleep = true; frame(p); near(p._st.panic, 49.25, 1e-9, "asleep: none"); p._asleep = false
p._moodles.drunk = 0; frame(p); near(p._st.panic, 49.25, 1e-9, "sober: none")
p._st.panic = 0.1; p._moodles.drunk = 4; frame(p); assert(p._st.panic == 0, "clamped at zero")

-- 6. no moodle API: the level comes from intoxication (10/30/50/70)
local q = newPlayer({ moodles = false }); H.current = q
q._st.intox = 5; assert(DanTraits_DrunkLevel(q) == 0, "5%: sober")
q._st.intox = 15; assert(DanTraits_DrunkLevel(q) == 1, "15%: tipsy")
q._st.intox = 55; assert(DanTraits_DrunkLevel(q) == 3, "55%: level 3")
q._st.intox = 90; minute(); near(q._pr, 80, 1e-9, "90%: level 4 floor")

H.pass()
