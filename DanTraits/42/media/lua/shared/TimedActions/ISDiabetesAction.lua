-- One timed action for the diabetes items: inject insulin (any number of
-- doses), check blood sugar with the meter (uses a test strip), or take a
-- metformin pill. Which one is set by `kind`.
require "TimedActions/ISBaseTimedAction"

ISDiabetesAction = ISBaseTimedAction:derive("ISDiabetesAction")

local function uses(item)
    local n = 0
    pcall(function() n = item:getCurrentUsesFloat() or 0 end)
    return n
end

function ISDiabetesAction:isValid()
    local inv = self.character:getInventory()
    if not inv:contains(self.item) then return false end
    if self.kind == "inject" then
        return DanTraits_IsInsulin and DanTraits_IsInsulin(self.item) and uses(self.item) > 0
    elseif self.kind == "test" then
        return DanTraits_IsMeter and DanTraits_IsMeter(self.item) and self.strips ~= nil and inv:contains(self.strips) and uses(self.strips) > 0
    elseif self.kind == "pill" then
        return DanTraits_IsMetformin and DanTraits_IsMetformin(self.item) and uses(self.item) > 0
    end
    return false
end

function ISDiabetesAction:update()
    self.item:setJobDelta(self:getJobDelta())
    if self.kind == "pill" then
        self:setActionAnim(CharacterActionAnims.TakePills)
    else
        self:setActionAnim(CharacterActionAnims.Bandage)
    end
end

function ISDiabetesAction:start()
    self.item:setJobType(self.label)
    self.item:setJobDelta(0.0)
    self:setOverrideHandModels(nil, self.item)
end

function ISDiabetesAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function ISDiabetesAction:perform()
    self.item:setJobDelta(0.0)
    if self.kind == "inject" then
        local n = math.min(self.doses, math.floor(uses(self.item) + 0.01))
        for _ = 1, n do self.item:Use() end
        if n > 0 and DanTraits_DiaInject then DanTraits_DiaInject(self.character, n) end
    elseif self.kind == "test" then
        self.strips:Use()
        if DanTraits_DiaRead then
            local value, bad = DanTraits_DiaRead(self.character)
            if value then
                if bad then DanTraits_NotifyFmt(self.character, "UI_DanTraits_DiaReading", value)
                else DanTraits_NotifyFmtGood(self.character, "UI_DanTraits_DiaReading", value) end
                pcall(function()
                    -- B42 item names are keyed by full type in ItemName.json, not "ItemName_<type>",
                    -- so getText() on that key returns the raw key; ask the item system instead
                    local base = getItemNameFromFullType and getItemNameFromFullType("DanTraits.GlucoseMeter") or "Glucose Meter"
                    self.item:setName(base .. " (" .. value .. ")")
                    self.item:setCustomName(true)
                end)
            end
        end
    elseif self.kind == "pill" then
        self.item:Use()
        if DanTraits_DiaOnPill then DanTraits_DiaOnPill(self.character) end
    end
    ISBaseTimedAction.perform(self)
end

-- kind: "inject" (item = pen, doses), "test" (item = meter, strips = strips), "pill" (item = metformin)
function ISDiabetesAction:new(character, item, kind, doses, strips)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.kind = kind
    o.doses = doses or 1
    o.strips = strips
    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = false
    if kind == "inject" then
        o.label = getText("ContextMenu_DanTraits_Inject")
        o.maxTime = 90
    elseif kind == "test" then
        o.label = getText("ContextMenu_DanTraits_CheckSugar")
        o.maxTime = 70
    else
        o.label = getText("ContextMenu_DanTraits_TakeMetformin")
        o.maxTime = 60
    end
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
