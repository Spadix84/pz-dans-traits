-- One pill (or a piece of gum, or a coat of sun block) from one of this mod's
-- items, then the shared "pill" hook with the item's type, so the system that
-- cares (iron pills: Anaemic; nicotine gum: Smoker; anticonvulsants: Epilepsy;
-- sun block: Sunburn) does the rest. Same shape as taking metformin.
-- new(character, item, label, anim, time): anim is the action animation
-- (default the pill one), time the action's length (default 60).
require "TimedActions/ISBaseTimedAction"

ISVitalityPillAction = ISBaseTimedAction:derive("ISVitalityPillAction")

function ISVitalityPillAction:isValid()
    return self.character:getInventory():contains(self.item) and DanTraits_ItemUses(self.item) > 0
end

function ISVitalityPillAction:update()
    self.item:setJobDelta(self:getJobDelta())
    self:setActionAnim(self.anim or CharacterActionAnims.TakePills)
end

function ISVitalityPillAction:start()
    self.item:setJobType(getText(self.label or "ContextMenu_DanTraits_TakeIronPill"))
    self.item:setJobDelta(0.0)
    self:setOverrideHandModels(nil, self.item)
end

function ISVitalityPillAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function ISVitalityPillAction:perform()
    self.item:setJobDelta(0.0)
    local kind = ""
    pcall(function() kind = tostring(self.item:getType()) end)
    -- the same two hooks as the vanilla pill action gets (DanTraits.lua): before the dose, then after
    if DanTraits_RunHooks then DanTraits_RunHooks("prePill", nil, self.character, kind, self.item) end
    self.item:Use()
    if DanTraits_RunHooks then DanTraits_RunHooks("pill", nil, self.character, kind) end
    ISBaseTimedAction.perform(self)
end

function ISVitalityPillAction:new(character, item, label, anim, time)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.label = label
    o.anim = anim
    o.maxTime = time or 60
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
