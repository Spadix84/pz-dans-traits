-- Packing clotting powder into a bleeding wound, from the health panel
-- (DanTraits_Client.lua). Shaped like vanilla's ISDisinfect: the same
-- animation, the patient may be someone else, done when complete() runs
-- DanTraits_ApplyClot (DanTraits_Clotting.lua). One use of the tin.
require "TimedActions/ISBaseTimedAction"

ISVitalityClotAction = ISBaseTimedAction:derive("ISVitalityClotAction")

function ISVitalityClotAction:isValid()
    if ISHealthPanel and ISHealthPanel.DidPatientMove
        and ISHealthPanel.DidPatientMove(self.character, self.otherPlayer, self.patientX, self.patientY) then
        return false
    end
    if not DanTraits_ClotCanApply or not DanTraits_ClotCanApply(self.bodyPart) then return false end
    return self.character:getInventory():contains(self.item) and DanTraits_ItemUses(self.item) > 0
end

function ISVitalityClotAction:waitToStart()
    if self.character == self.otherPlayer then return false end
    self.character:faceThisObject(self.otherPlayer)
    return self.character:shouldBeTurning()
end

function ISVitalityClotAction:update()
    if self.character ~= self.otherPlayer then self.character:faceThisObject(self.otherPlayer) end
    if ISHealthPanel and ISHealthPanel.setBodyPartActionForPlayer then
        ISHealthPanel.setBodyPartActionForPlayer(self.otherPlayer, self.bodyPart, self, getText("ContextMenu_DanTraits_PackClot"), { disinfect = true })
    end
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function ISVitalityClotAction:start()
    if self.character == self.otherPlayer then
        self:setActionAnim(CharacterActionAnims.Bandage)
        self:setAnimVariable("BandageType", ISHealthPanel.getBandageType(self.bodyPart))
        self.character:reportEvent("EventBandage")
    else
        self:setActionAnim("Loot")
        self.character:SetVariable("LootPosition", "Mid")
        self.character:reportEvent("EventLootItem")
    end
    self:setOverrideHandModels(nil, nil)
    self.sound = self.character:playSound("FirstAidApplyAlcoholWipes")
end

function ISVitalityClotAction:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function ISVitalityClotAction:clearPanel()
    if ISHealthPanel and ISHealthPanel.setBodyPartActionForPlayer then
        ISHealthPanel.setBodyPartActionForPlayer(self.otherPlayer, self.bodyPart, nil, nil, nil)
    end
end

function ISVitalityClotAction:stop()
    self:stopSound()
    self:clearPanel()
    ISBaseTimedAction.stop(self)
end

function ISVitalityClotAction:perform()
    self:stopSound()
    self:clearPanel()
    ISBaseTimedAction.perform(self)
end

function ISVitalityClotAction:complete()
    if DanTraits_ApplyClot and DanTraits_ApplyClot(self.otherPlayer, self.bodyPart, self.doctorLevel) then
        if self.item:IsDrainable() then self.item:UseAndSync() else self.item:Use() end
        pcall(function() addXp(self.character, Perks.Doctor, DanTraits_ClotXp or 5) end)
        pcall(function() syncBodyPart(self.bodyPart, 0x00608200) end)
    end
    return true
end

function ISVitalityClotAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 100 - (self.doctorLevel * 4)
end

function ISVitalityClotAction:new(character, otherPlayer, item, bodyPart)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.doctor = character
    o.otherPlayer = otherPlayer
    o.doctorLevel = character:getPerkLevel(Perks.Doctor)
    o.item = item
    o.bodyPart = bodyPart
    o.stopOnWalk = bodyPart:getIndex() > BodyPartType.ToIndex(BodyPartType.Groin)
    o.stopOnRun = true
    o.patientX = otherPlayer:getX()
    o.patientY = otherPlayer:getY()
    o.maxTime = o:getDuration()
    return o
end
