-- Client side pieces for Project Zomboid Vitality Project: the Airway Irritation moodle
-- (needs Moodle Framework; skipped without it), the inhaler context menu,
-- the Vegetarian grey-out, the diabetes items (inject, check sugar,
-- take metformin), iron pills, nicotine gum, anticonvulsants, the MS pills and sun block, the wrap that hides Wakeful
-- (and Deep Sleeper on a no-sleep server) from the character creation list, and Age at
-- character creation (In Their 30s hidden, age's levels shown in the Major Skills list,
-- and the body traits' extra cost in the 40s and 50s).
-- Game methods are wrapped through DanTraits_Wrap (DanTraits.lua).
require "DanTraits"
require "TimedActions/ISUseInhalerAction"
require "TimedActions/ISDiabetesAction"
require "TimedActions/ISVitalityPillAction"

local ok = pcall(function() require "MF_ISMoodle" end)
if ok and MF and MF.createMoodle then
    MF.createMoodle("AirwayIrritation")
    MF.createMoodle("Vitality")
    MF.createMoodle("SleptBadly")
    MF.createMoodle("Hangover")
    MF.createMoodle("Migraine")
    MF.createMoodle("BloodLoss")
    MF.createMoodle("Infection")
    MF.createMoodle("Concussion")
    MF.createMoodle("BloodSugar")
    -- the rest are fed from one place, shared/DanTraits_Moodles.lua
    for _, name in ipairs(DanTraits_MoodleNames or {}) do MF.createMoodle(name) end
end

local function actualItems(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then
        return ISInventoryPane.getActualItems(items)
    end
    return items
end

local function findFirst(items, test)
    if not test then return nil end
    for _, item in ipairs(actualItems(items)) do
        if test(item) then return item end
    end
    return nil
end

local usesOf = DanTraits_ItemUses

local function greyOut(option, textKey)
    option.notAvailable = true
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = getText(textKey)
    option.toolTip = tooltip
end

local function onUseInhaler(item, playerObj)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(ISUseInhalerAction:new(playerObj, item))
end

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    local inhaler = findFirst(items, DanTraits_IsInhaler)
    if not inhaler then return end
    -- never offer the vanilla pill option on it; swallowing a dose does nothing
    pcall(function() context:removeOptionByName(getText("ContextMenu_Take_pills")) end)

    local option = context:addOption(getText("ContextMenu_DanTraits_UseInhaler"), inhaler, onUseInhaler, playerObj)
    if usesOf(inhaler) <= 0 then greyOut(option, "Tooltip_DanTraits_InhalerEmpty") end
end

-- Vegetarian and Straight Edge: grey out Eat (or the item's own verb, Smoke)
-- on what they refuse, with the reason
local function greyOutMeat(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not DanTraits_RefuseReason then return end
    local reason
    local meat = findFirst(items, function(item)
        reason = DanTraits_RefuseReason(playerObj, item)
        return reason ~= nil
    end)
    if not meat or not reason then return end
    local names = { getText("ContextMenu_Eat") }
    pcall(function() local custom = meat:getCustomMenuOption(); if custom then table.insert(names, custom) end end)
    local tooltip = (string.gsub(reason, "^UI_", "Tooltip_"))
    for _, name in ipairs(names) do
        local option = context:getOptionFromName(name)
        if option then greyOut(option, tooltip) end
    end
end

-- Diabetes items ---------------------------------------------------------------
local function queue(playerObj, item, kind, doses, strips)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    if strips then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, strips) end
    ISTimedActionQueue.add(ISDiabetesAction:new(playerObj, item, kind, doses, strips))
end

local function onInject(pen, playerObj, doses) queue(playerObj, pen, "inject", doses) end
local function onCheckSugar(meter, playerObj, strips) queue(playerObj, meter, "test", nil, strips) end
local function onTakeMetformin(pills, playerObj) queue(playerObj, pills, "pill") end

local INJECT_DOSES = { 1, 2, 4, 8 }

local function diabetesMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    local diabetic = DanTraits_IsDiabetic and DanTraits_IsDiabetic(playerObj)

    local pen = findFirst(items, DanTraits_IsInsulin)
    if pen then
        local option = context:addOption(getText("ContextMenu_DanTraits_Inject"), pen, nil)
        if not diabetic then
            greyOut(option, "Tooltip_DanTraits_NotDiabetic")
        elseif usesOf(pen) <= 0 then
            greyOut(option, "Tooltip_DanTraits_InsulinEmpty")
        else
            local sub = context:getNew(context)
            context:addSubMenu(option, sub)
            local left = math.floor(usesOf(pen) + 0.01)
            for _, n in ipairs(INJECT_DOSES) do
                local label = getText("ContextMenu_DanTraits_InjectDoses", n)
                local o = sub:addOption(label, pen, onInject, playerObj, n)
                if n > left then greyOut(o, "Tooltip_DanTraits_InsulinShort") end
            end
        end
    end

    local meter = findFirst(items, DanTraits_IsMeter)
    if meter then
        local strips
        pcall(function()
            local all = playerObj:getInventory():getAllEvalRecurse(function(item) return DanTraits_IsStrips(item) and usesOf(item) > 0 end)
            if all and all:size() > 0 then strips = all:get(0) end
        end)
        local option = context:addOption(getText("ContextMenu_DanTraits_CheckSugar"), meter, onCheckSugar, playerObj, strips)
        if not strips then greyOut(option, "Tooltip_DanTraits_NoStrips") end
    end

    local pills = findFirst(items, DanTraits_IsMetformin)
    if pills then
        local option = context:addOption(getText("ContextMenu_DanTraits_TakeMetformin"), pills, onTakeMetformin, playerObj)
        if not diabetic then
            greyOut(option, "Tooltip_DanTraits_NotDiabetic")
        elseif usesOf(pills) <= 0 then
            greyOut(option, "Tooltip_DanTraits_MetforminEmpty")
        end
    end
end

-- Iron pills (Anaemic) ---------------------------------------------------------
local function onTakeIronPill(pills, playerObj)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, pills)
    ISTimedActionQueue.add(ISVitalityPillAction:new(playerObj, pills))
end

local function ironPillsMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not DanTraits_IsIronPills then return end
    local pills = findFirst(items, DanTraits_IsIronPills)
    if not pills then return end
    pcall(function() context:removeOptionByName(getText("ContextMenu_Take_pills")) end)
    local option = context:addOption(getText("ContextMenu_DanTraits_TakeIronPill"), pills, onTakeIronPill, playerObj)
    if usesOf(pills) <= 0 then greyOut(option, "Tooltip_DanTraits_IronPillsEmpty") end
end

-- Nicotine gum (Smoker) ----------------------------------------------------------
local function onChewGum(gum, playerObj)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, gum)
    ISTimedActionQueue.add(ISVitalityPillAction:new(playerObj, gum, "ContextMenu_DanTraits_ChewGum"))
end

local function nicotineGumMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not DanTraits_IsNicotineGum then return end
    local gum = findFirst(items, DanTraits_IsNicotineGum)
    if not gum then return end
    pcall(function() context:removeOptionByName(getText("ContextMenu_Take_pills")) end)
    local option = context:addOption(getText("ContextMenu_DanTraits_ChewGum"), gum, onChewGum, playerObj)
    if usesOf(gum) <= 0 then greyOut(option, "Tooltip_DanTraits_NicotineGumEmpty") end
end

-- Anticonvulsants (Epilepsy) ------------------------------------------------------
local function onTakeAnticonvulsant(pills, playerObj)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, pills)
    ISTimedActionQueue.add(ISVitalityPillAction:new(playerObj, pills, "ContextMenu_DanTraits_TakeAnticonvulsant"))
end

local function anticonvulsantMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not DanTraits_IsAnticonvulsants then return end
    local pills = findFirst(items, DanTraits_IsAnticonvulsants)
    if not pills then return end
    pcall(function() context:removeOptionByName(getText("ContextMenu_Take_pills")) end)
    local option = context:addOption(getText("ContextMenu_DanTraits_TakeAnticonvulsant"), pills, onTakeAnticonvulsant, playerObj)
    if usesOf(pills) <= 0 then greyOut(option, "Tooltip_DanTraits_AnticonvulsantsEmpty") end
end

-- MS medication: prednisone, baclofen, amantadine ---------------------------------
local function onTakeMSMed(pills, playerObj)
    local label = "ContextMenu_DanTraits_Take" .. tostring(pills:getType())
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, pills)
    ISTimedActionQueue.add(ISVitalityPillAction:new(playerObj, pills, label))
end

local function msMedMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not DanTraits_IsMSMed then return end
    local pills = findFirst(items, DanTraits_IsMSMed)
    if not pills then return end
    pcall(function() context:removeOptionByName(getText("ContextMenu_Take_pills")) end)
    local option = context:addOption(getText("ContextMenu_DanTraits_Take" .. tostring(pills:getType())), pills, onTakeMSMed, playerObj)
    if usesOf(pills) <= 0 then greyOut(option, "Tooltip_DanTraits_MSMedEmpty") end
end

-- Sun block (Sunburn, anyone) -------------------------------------------------------
local SUNBLOCK_ANIM = "WashFace"    -- the game's washing animation: rubbing it in
local SUNBLOCK_TIME = 150

local function onApplySunblock(bottle, playerObj)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, bottle)
    ISTimedActionQueue.add(ISVitalityPillAction:new(playerObj, bottle, "ContextMenu_DanTraits_ApplySunblock", SUNBLOCK_ANIM, SUNBLOCK_TIME))
end

local function sunblockMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not DanTraits_IsSunblock then return end
    local bottle = findFirst(items, DanTraits_IsSunblock)
    if not bottle then return end
    pcall(function() context:removeOptionByName(getText("ContextMenu_Take_pills")) end)
    local option = context:addOption(getText("ContextMenu_DanTraits_ApplySunblock"), bottle, onApplySunblock, playerObj)
    if usesOf(bottle) <= 0 then greyOut(option, "Tooltip_DanTraits_SunblockEmpty") end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(sunblockMenu)
Events.OnFillInventoryObjectContextMenu.Add(anticonvulsantMenu)
Events.OnFillInventoryObjectContextMenu.Add(msMedMenu)
Events.OnFillInventoryObjectContextMenu.Add(nicotineGumMenu)
Events.OnFillInventoryObjectContextMenu.Add(ironPillsMenu)
Events.OnFillInventoryObjectContextMenu.Add(greyOutMeat)
Events.OnFillInventoryObjectContextMenu.Add(diabetesMenu)

-- Character creation: Wakeful is folded into Deep Sleeper, so it is hidden
-- from the list (Deep Sleeper grants it). Deep Sleeper follows vanilla's rule
-- for the sleep traits: hidden on a server where sleep is off. The Age traits
-- are hidden when the sandbox switches Age off (they would do nothing), and
-- In Their 30s always: it is what a character who picks no age is given.
-- at character creation SandboxVars is still the previous copy: read the live
-- sandbox options the way vanilla's creation screen does (NegativeTraitsPenalty)
local function ageOffAtCreation()
    local ok, value = pcall(function() return getSandboxOptions():getOptionByName("DanTraits.AgeEnabled"):getValue() end)
    if ok and value ~= nil then return value == false end
    return DanTraits_SandboxOn ~= nil and not DanTraits_SandboxOn("AgeEnabled")
end

-- a number option of the new game, the same way; SandboxVars when that fails
local function ageOption(name)
    local ok, value = pcall(function() return getSandboxOptions():getOptionByName("DanTraits." .. name):getValue() end)
    if ok and value ~= nil then return value end
    return SandboxVars and SandboxVars.DanTraits and SandboxVars.DanTraits[name]
end

local AGE_BAND_OF = { age20s = 20, age30s = 30, age40s = 40, age50s = 50 }

-- the Age trait's key ("age40s") for a trait type, or nil
local function ageKeyOf(kind)
    if kind == nil or not DanTraitsRegistry then return nil end
    for key in pairs(AGE_BAND_OF) do
        if kind == DanTraitsRegistry[key] then return key end
    end
    return nil
end

-- Age in the Major Skills list. Vanilla builds the list from the XP boosts of
-- the profession and the chosen traits; age adds its levels in Lua at spawn,
-- so they are added to the list here, from the same function the spawn code
-- uses (DanTraits_AgeLevels). Returns { perk = levels }, or nil with age off.
-- the band of the character being made (the picked Age trait, else the new
-- game's default), or nil with age off
local function creationAgeBand(screen)
    if ageOffAtCreation() or not DanTraits_AgeRoundBand then return nil end
    for _, row in pairs(screen.listboxTraitSelected.items) do
        local key = ageKeyOf(row.item:getType())
        if key then return AGE_BAND_OF[key] end
    end
    return DanTraits_AgeRoundBand(ageOption("AgeDefault"))
end

local function creationAgeLevels(screen)
    local band = creationAgeBand(screen)
    if not band then return nil end
    local handy = false
    for _, row in pairs(screen.listboxTraitSelected.items) do
        if string.lower(tostring(row.item:getType())) == "base:handy" then handy = true end
    end
    local boosts = nil
    if screen.profession and screen.profession:getXpBoosts() then
        boosts = transformIntoKahluaTable(screen.profession:getXpBoosts())
    end
    return DanTraits_AgeLevels(boosts, band, handy, ageOption("AgeBonus" .. band .. "s"))
end

-- A row with age levels: vanilla draws the row for the levels the game gives
-- (its bars and XP rate; age gives levels, not a faster rate, so a skill only
-- age gives is drawn like Fitness, which has no rate), then age's bars go on
-- the end in a second colour, with vanilla's geometry.
local AGE_BAR = { r = 0.45, g = 0.7, b = 1.0 }
local function drawAgeXpBoost(self, y, item, alt)
    local age = item.item.ageLevels or 0
    if age <= 0 then return CharacterCreationProfession.drawXpBoostMap(self, y, item, alt) end
    local base = item.item.level - age
    local row = { text = item.text, item = { perk = base > 0 and item.item.perk or Perks.Fitness, level = base } }
    local yy = CharacterCreationProfession.drawXpBoostMap(self, y, row, alt)
    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local dy = (self.itemheight - self.fontHgt) / 2
    local blitW = math.floor(fontHgt / (10 / 3))
    local blitGap = math.floor(blitW / 4)
    local x0 = self.width - (getTextManager():MeasureStringX(UIFont.Small, "+ 100%") + 13 + 12 * (blitW + blitGap))
    for i = base + 1, item.item.level do
        self:drawTextureScaled(CharacterCreationProfession.instance.whiteBar, x0 + i * (blitW + blitGap), y + dy,
            blitW, fontHgt, 1, AGE_BAR.r, AGE_BAR.g, AGE_BAR.b)
    end
    return yy
end

local function addAgeLevels(screen)
    local list = screen.listboxXpBoost
    local levels = creationAgeLevels(screen)
    if not list or not levels then return end
    for perk, count in pairs(levels) do
        local entry = nil
        for _, row in pairs(list.items) do
            if row.item.perk == perk then entry = row end
        end
        if not entry then entry = list:addItem(PerkFactory.getPerkName(perk), { perk = perk, level = 0 }) end
        local add = math.min(count, 10 - entry.item.level)
        if add > 0 then
            entry.item.ageLevels = add
            entry.item.level = entry.item.level + add
            entry.text = entry.text .. " " .. getText("UI_DanTraits_AgeLevels", add)
        end
    end
    list:sort()
end

-- The body traits cost more with age (Strong, Athletic, Stout, Fit:
-- DanTraits_AgeSurcharge). Vanilla works the points to spend out on demand
-- from the chosen traits (PointToSpend, the way its own negative-trait
-- penalty does), so the surcharge is taken off there: presets, the random
-- button and the Play button's check all go through it.
local function ageSurchargeTotal(screen)
    local band = creationAgeBand(screen)
    if not band then return 0 end
    local total = 0
    for _, row in pairs(screen.listboxTraitSelected.items) do
        total = total + DanTraits_AgeSurcharge(band, row.item:getType())
    end
    return total
end

-- a trait row, in the lists to pick from and the chosen list: vanilla's row,
-- then the surcharge beside the trait's own cost
local function drawAgeTrait(self, y, item, alt)
    local yy = CharacterCreationProfession.drawTraitMap(self, y, item, alt)
    pcall(function()
        local band = creationAgeBand(CharacterCreationProfession.instance)
        local extra = band and DanTraits_AgeSurcharge(band, item.item:getType()) or 0
        if extra <= 0 then return end
        local hc = getCore():getBadHighlitedColor()
        local costWid = getTextManager():MeasureStringX(UIFont.Small, item.item:getRightLabel())
        self:drawTextRight(getText("UI_DanTraits_AgeSurcharge", extra), self:getWidth() - 30 - costWid,
            y + (self.itemheight - self.fontHgt) / 2, hc:getR(), hc:getG(), hc:getB(), 0.9, UIFont.Small)
    end)
    return yy
end

-- set every time the lists change: the screen may have been built before this file loaded
local function setAgeDraws(screen)
    if screen.listboxXpBoost then screen.listboxXpBoost.doDrawItem = drawAgeXpBoost end
    if screen.listboxTrait then screen.listboxTrait.doDrawItem = drawAgeTrait end
    if screen.listboxTraitSelected then screen.listboxTraitSelected.doDrawItem = drawAgeTrait end
end

local function wrapTraitList()
    DanTraits_Wrap(CharacterCreationProfession, "isTraitEnabled", "creation-hide-traits", function(original, self, trait, ...)
        local kind = nil
        pcall(function() kind = trait:getType() end)
        if kind ~= nil and kind == CharacterTrait.NEEDS_LESS_SLEEP then return false end
        local ageKey = ageKeyOf(kind)
        if ageKey and (ageKey == "age30s" or ageOffAtCreation()) then return false end
        if kind ~= nil and DanTraitsRegistry and kind == DanTraitsRegistry.deepsleeper and isMultiplayer() then
            local ok, allowed = pcall(function()
                return getServerOptions():getBoolean("SleepAllowed") and getServerOptions():getBoolean("SleepNeeded")
            end)
            if ok and not allowed then return false end
        end
        return original(self, trait, ...)
    end)
    DanTraits_Wrap(CharacterCreationProfession, "checkXPBoost", "creation-age-levels", function(original, self, ...)
        local result = original(self, ...)
        pcall(addAgeLevels, self)
        pcall(setAgeDraws, self)
        return result
    end)
    DanTraits_Wrap(CharacterCreationProfession, "PointToSpend", "creation-age-surcharge", function(original, self, ...)
        local points = original(self, ...)
        local ok, extra = pcall(ageSurchargeTotal, self)
        if ok and type(extra) == "number" then points = points - extra end
        return points
    end)
    -- vanilla fills the lists once, when the screen is built at boot, before a
    -- new game's sandbox options exist: fill them again each time it is shown
    DanTraits_Wrap(CharacterCreationProfession, "setVisible", "creation-refresh-traits", function(original, self, visible, ...)
        local result = original(self, visible, ...)
        if visible and self.listboxTrait and self.listboxBadTrait and self.repopulateTraitLists then
            pcall(self.repopulateTraitLists, self)
        end
        return result
    end)
    -- and vanilla's sandbox screen shows the profession screen before it applies
    -- the new settings (SandboxOptionsScreen: PLAY, then setSandboxVars), so fill
    -- them again once the settings are in (found in play: AgeEnabled read true)
    if SandboxOptionsScreen then
        DanTraits_Wrap(SandboxOptionsScreen, "setSandboxVars", "creation-refresh-traits", function(original, self, ...)
            local result = original(self, ...)
            pcall(function()
                local screen = MainScreen.instance.charCreationProfession
                if screen and screen.listboxTrait and screen.listboxBadTrait then screen:repopulateTraitLists() end
            end)
            return result
        end)
    end
end
wrapTraitList()
Events.OnGameBoot.Add(wrapTraitList)
Events.OnMainMenuEnter.Add(wrapTraitList)
