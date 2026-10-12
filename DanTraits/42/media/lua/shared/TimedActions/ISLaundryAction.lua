-- One timed action for the laundry jobs that are not vanilla's wash or wring
-- (DanTraits_Laundry.lua). Which one is set by `kind`:
--
--   "bleach"    at a water source (`source`), with bleach (`extra`, a fluid
--               container): set-in stains and all blood out, dirt to the soap
--               floor, odour gone; uses L.BLEACH_LITRES of bleach and the
--               water a wash of it would. Hard on the fabric (LaundryWear).
--   "fire"      by a lit fire or stove (`source`, the object): the garment
--               dries as the bar fills, L.FIRE_PER_TICK wetness a tick.
--               Stops if the fire goes out or the character walks off.
--   "protect"   with fabric protector or fabric wax (`extra`, drainable):
--               one use treats the garment (DanTraits_LaundryGear.lua).
--   "putup"     a clothesline from square `source`, running `extra` ("ew" or
--               "ns"), with two posts and two ties carried
--               (DanTraits_LaundryDry.lua). `item` is one of the posts.
--   "takedown"  a clothesline put up that way (`source`, a post); no item.
require "TimedActions/ISBaseTimedAction"

ISLaundryAction = ISBaseTimedAction:derive("ISLaundryAction")

local function L() return DanTraits_Laundry end

function ISLaundryAction:isValid()
    local inv = self.character:getInventory()
    if self.kind == "putup" then
        return L().lineMaterials(self.character) ~= nil and L().lineSquares(self.source, self.dir) ~= nil
    elseif self.kind == "takedown" then
        local there = false
        pcall(function() there = self.source:getSquare() ~= nil end)
        return there and L().isBuiltLine(self.source)
    end
    if not self.item or not inv:containsRecursive(self.item) then return false end
    if self.kind == "bleach" then
        return self.bleach ~= nil and inv:containsRecursive(self.bleach) and L().bleachLeft(self.bleach) >= L().BLEACH_LITRES - 0.001
            and self.source ~= nil and (self.source:getFluidAmount() or 0) >= (self.water or 0)
    elseif self.kind == "fire" then
        return L().heatStillThere(self.character, self.source)
    elseif self.kind == "protect" then
        return self.agent ~= nil and inv:containsRecursive(self.agent) and DanTraits_ItemUses(self.agent) > 0
    end
    return false
end

function ISLaundryAction:update()
    if self.item then self.item:setJobDelta(self:getJobDelta()) end
    if self.faceTo then pcall(function() self.character:faceThisObject(self.faceTo) end) end
    if self.kind == "fire" then
        local w = self.startWet * (1 - self:getJobDelta())
        if w < L().wetness(self.item) then L().setWetness(self.item, w) end
    end
    pcall(function() self.character:setMetabolicTarget(Metabolics.LightDomestic) end)
end

function ISLaundryAction:start()
    if self.item then
        self.item:setJobType(self.label)
        self.item:setJobDelta(0.0)
    end
    if self.kind == "bleach" then
        self:setActionAnim("ScrubClothWithSoap")
    elseif self.kind == "fire" then
        self:setActionAnim("Loot")
        pcall(function() self:setAnimVariable("LootPosition", "") end)
    elseif self.kind == "putup" or self.kind == "takedown" then
        self:setActionAnim("Loot")
        pcall(function() self:setAnimVariable("LootPosition", "Mid") end)
    else
        self:setActionAnim(CharacterActionAnims.Craft)
    end
    pcall(function() self:setOverrideHandModels(nil, nil) end)
end

function ISLaundryAction:stop()
    if self.item then self.item:setJobDelta(0.0) end
    ISBaseTimedAction.stop(self)
end

function ISLaundryAction:perform()
    if self.item then self.item:setJobDelta(0.0) end
    if self.kind == "bleach" then
        L().useBleach(self.bleach)
        pcall(function() self.source:useFluid(self.water or 0) end)
        L().bleach(self.item, L().methodFor(self.character))
        DanTraits_NotifyGood(self.character, "UI_DanTraits_Bleached")
    elseif self.kind == "fire" then
        L().dry(self.item, 100)
    elseif self.kind == "protect" then
        self.agent:Use()
        L().protect(self.item)
        DanTraits_NotifyGood(self.character, "UI_DanTraits_Protected")
    elseif self.kind == "putup" then
        local mats = L().lineMaterials(self.character)
        if mats and L().putUpLine(self.character, self.source, self.dir, mats) then
            DanTraits_NotifyGood(self.character, "UI_DanTraits_LineUp")
        end
    elseif self.kind == "takedown" then
        L().takeDownLine(self.character, self.source)
    end
    if self.item then
        pcall(function()
            syncItemFields(self.character, self.item)
            syncVisuals(self.character)
        end)
    end
    ISBaseTimedAction.perform(self)
end

-- kind "bleach": source = water object, extra = bleach container, water = units
-- kind "fire": source = the fire or stove
-- kind "protect": extra = the protector or wax
-- kind "putup": source = the first square, extra = "ew" | "ns", item = a post
-- kind "takedown": source = a post, item = nil
function ISLaundryAction:new(character, item, kind, source, extra, water)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.kind = kind
    o.source = source
    o.water = water
    o.stopOnWalk = true
    o.stopOnRun = true
    if kind == "bleach" then
        o.bleach = extra
        o.faceTo = source
        o.label = getText("ContextMenu_DanTraits_BleachStains")
        o.maxTime = 300
    elseif kind == "fire" then
        o.faceTo = source
        o.startWet = L().wetness(item)
        o.label = getText("ContextMenu_DanTraits_DryByFire")
        o.maxTime = math.max(60, math.ceil(o.startWet / L().FIRE_PER_TICK))
    elseif kind == "putup" then
        o.dir = extra
        o.label = getText("ContextMenu_DanTraits_PutUpLine")
        o.maxTime = 400
    elseif kind == "takedown" then
        o.faceTo = source
        o.maxTime = 200
    else
        o.agent = extra
        o.label = getText("ContextMenu_DanTraits_ProtectFabric")
        o.maxTime = 150
    end
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
