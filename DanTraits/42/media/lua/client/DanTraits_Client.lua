-- Client side pieces for Project Zomboid Vitality Project: the Airway Irritation moodle
-- (needs Moodle Framework; skipped without it), the inhaler context menu,
-- the Vegetarian grey-out, the diabetes items (inject, check sugar,
-- take metformin), iron pills, nicotine gum, anticonvulsants, the MS pills and sun block, the wrap that hides Wakeful
-- (and Deep Sleeper on a no-sleep server) from the character creation list, and Age at
-- character creation (In Their 30s hidden, age's levels shown in the Major Skills list,
-- the body traits' extra cost in the 40s and 50s, and the traits only one age can take).
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

local INJECT_DOSES = { 1, 2, 3, 4, 8 }

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
-- are hidden when the sandbox switches Age off (they would do nothing).
-- The age gate: with Age on, the lists offer nothing but the four ages until
-- one is chosen (In Their 30s at 0 points among them, put into the positive
-- list by hand since vanilla lists only a cost above or below zero); the rest
-- unlocks then, Next is greyed until then with the reason as its tooltip and
-- on the screen, Random picks an age first, and a saved build loads first
-- and is gated after. Age off: no gate, no ages. A character with no Age
-- trait at spawn (an old save) still gets the sandbox default's (DanTraits_Age.lua).
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

-- the Age trait chosen on the screen, as its key ("age40s"), or nil
local function chosenAgeKey(screen)
    local items = screen and screen.listboxTraitSelected and screen.listboxTraitSelected.items
    if not items then return nil end
    for _, row in pairs(items) do
        local key = ageKeyOf(row.item:getType())
        if key then return key end
    end
    return nil
end

-- the gate is up: Age on, a screen with a chosen list, no build loading, and
-- no Age trait chosen yet
local function ageGateOn(screen)
    if ageOffAtCreation() then return false end
    if not screen or not screen.listboxTraitSelected or screen.danTraitsLoadingBuild then return false end
    return chosenAgeKey(screen) == nil
end

local AGE_KEYS = { "age20s", "age30s", "age40s", "age50s" }

-- Random: one of the four, added like a click
local function addRandomAge(screen)
    if not DanTraitsRegistry or not CharacterTraitDefinition then return end
    local key = AGE_KEYS[ZombRand(#AGE_KEYS) + 1]
    local def = CharacterTraitDefinition.getCharacterTraitDefinition(DanTraitsRegistry[key])
    if def then screen:addTrait(def) end
end

-- Age in the Major Skills list. Vanilla builds the list from the XP boosts of
-- the profession and the chosen traits; age adds its levels in Lua at spawn,
-- so they are added to the list here, from the same function the spawn code
-- uses (DanTraits_AgeLevels). Returns { perk = levels }, or nil with age off.
-- the band of the character being made (the chosen Age trait), or nil with
-- age off or none chosen yet (the sandbox default no longer stands in at
-- creation: the gate makes the player choose)
local function creationAgeBand(screen)
    if ageOffAtCreation() then return nil end
    local key = chosenAgeKey(screen)
    return key and AGE_BAND_OF[key] or nil
end

local function creationAgeLevels(screen)
    local band = creationAgeBand(screen)
    if not band then return nil end
    local handy, green = false, false
    for _, row in pairs(screen.listboxTraitSelected.items) do
        local kind = row.item:getType()
        if string.lower(tostring(kind)) == "base:handy" then handy = true end
        if DanTraitsRegistry and kind == DanTraitsRegistry.green then green = true end
    end
    local boosts = nil
    if screen.profession and screen.profession:getXpBoosts() then
        boosts = transformIntoKahluaTable(screen.profession:getXpBoosts())
    end
    return DanTraits_AgeLevels(boosts, band, handy, ageOption("AgeBonus" .. band .. "s"), green)
end

-- A row with age levels: vanilla draws the row for the levels the game gives
-- (its bars and XP rate; age gives levels, not a faster rate, so a skill only
-- age gives is drawn like Fitness, which has no rate), then age's bars go on
-- the end in a second colour, with vanilla's geometry.
-- Levels taken away (Green) are drawn the same way round: vanilla's row for
-- the game's levels, then the lost bars greyed out.
local AGE_BAR = { r = 0.45, g = 0.7, b = 1.0 }
local AGE_BAR_LOST = { r = 0.3, g = 0.3, b = 0.3 }
local function drawAgeXpBoost(self, y, item, alt)
    local age = item.item.ageLevels or 0
    if age == 0 then return CharacterCreationProfession.drawXpBoostMap(self, y, item, alt) end
    local base = item.item.level - age
    local row = { text = item.text, item = { perk = base > 0 and item.item.perk or Perks.Fitness, level = base } }
    local yy = CharacterCreationProfession.drawXpBoostMap(self, y, row, alt)
    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local dy = (self.itemheight - self.fontHgt) / 2
    local blitW = math.floor(fontHgt / (10 / 3))
    local blitGap = math.floor(blitW / 4)
    local x0 = self.width - (getTextManager():MeasureStringX(UIFont.Small, "+ 100%") + 13 + 12 * (blitW + blitGap))
    local from, to, colour = base + 1, item.item.level, AGE_BAR
    if age < 0 then from, to, colour = item.item.level + 1, base, AGE_BAR_LOST end
    for i = from, to do
        self:drawTextureScaled(CharacterCreationProfession.instance.whiteBar, x0 + i * (blitW + blitGap), y + dy,
            blitW, fontHgt, 1, colour.r, colour.g, colour.b)
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
        if not entry and count > 0 then entry = list:addItem(PerkFactory.getPerkName(perk), { perk = perk, level = 0 }) end
        local add = entry and math.max(-entry.item.level, math.min(count, 10 - entry.item.level)) or 0
        if add ~= 0 then
            entry.item.ageLevels = add
            entry.item.level = entry.item.level + add
            if add > 0 then entry.text = entry.text .. " " .. getText("UI_DanTraits_AgeLevels", add)
            else entry.text = entry.text .. " " .. getText("UI_DanTraits_AgeLevelsLost", -add) end
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
        if extra == 0 then return end
        local hc = extra > 0 and getCore():getBadHighlitedColor() or getCore():getGoodHighlitedColor()
        local label = extra > 0 and getText("UI_DanTraits_AgeSurcharge", extra) or getText("UI_DanTraits_AgeDiscount", extra)
        local costWid = getTextManager():MeasureStringX(UIFont.Small, item.item:getRightLabel())
        self:drawTextRight(label, self:getWidth() - 30 - costWid,
            y + (self.itemheight - self.fontHgt) / 2, hc:getR(), hc:getG(), hc:getB(), 0.9, UIFont.Small)
    end)
    return yy
end

-- set every time the lists change: the screen may have been built before this file loaded
-- (the preset box holds the load function it was built with, so it is pointed at the wrapped one)
local function setAgeDraws(screen)
    if screen.listboxXpBoost then screen.listboxXpBoost.doDrawItem = drawAgeXpBoost end
    if screen.listboxTrait then screen.listboxTrait.doDrawItem = drawAgeTrait end
    if screen.listboxTraitSelected then screen.listboxTraitSelected.doDrawItem = drawAgeTrait end
    if screen.savedBuilds and screen.savedBuilds.onChange then screen.savedBuilds.onChange = CharacterCreationProfession.loadBuild end
end

-- The traits only one age can take (DanTraits_AgeOnly, DanTraits_AgeTraits.lua).
-- The bands that may take a trait type, or nil for every other trait.
local function ageOnlyOf(kind)
    if kind == nil or not DanTraitsRegistry or not DanTraits_AgeOnly then return nil end
    for key, bands in pairs(DanTraits_AgeOnly) do
        if kind == DanTraitsRegistry[key] then return bands end
    end
    return nil
end

local function ageAllows(screen, kind)
    -- the Age traits themselves: not with Age switched off
    if ageKeyOf(kind) then return not ageOffAtCreation() end
    local bands = ageOnlyOf(kind)
    if not bands then return true end
    local band = creationAgeBand(screen)
    return band ~= nil and bands[band] == true
end

-- the age changed under a chosen trait, or Age was switched off with an Age
-- trait chosen: take it back off (its points come back)
local function dropAgeOnly(screen)
    if screen.danTraitsLoadingBuild then return end
    local items = screen.listboxTraitSelected and screen.listboxTraitSelected.items
    if not items then return end
    for i = #items, 1, -1 do
        if items[i] and not ageAllows(screen, items[i].item:getType()) then screen:removeTrait(i) end
    end
end

-- The new game's Age settings can change while the creation screen exists
-- (back to the sandbox screen, another preset, a different route into
-- creation), and not every route tells the screen. So it looks each frame it
-- is drawn: when the Age switch, the default age or a level count is not what
-- it last saw, the lists are worked out again (which also drops a chosen
-- trait Age no longer allows). One log line per change says what it read.
local function watchAgeSettings(screen)
    if not screen.listboxTrait or not screen.listboxBadTrait then return end
    local off = ageOffAtCreation()
    local seen = tostring(off)
    for _, name in ipairs({ "AgeDefault", "AgeBonus20s", "AgeBonus30s", "AgeBonus40s", "AgeBonus50s" }) do
        seen = seen .. "/" .. tostring(ageOption(name))
    end
    if seen == screen.danTraitsAgeSeen then return end
    screen.danTraitsAgeSeen = seen
    print("[DanTraits] character creation: Age is " .. (off and "off" or "on") .. " (off/default/levels: " .. seen .. ")")
    screen:repopulateTraitLists()
    screen:checkXPBoost()
end

local function wrapTraitList()
    DanTraits_Wrap(CharacterCreationProfession, "isTraitEnabled", "creation-hide-traits", function(original, self, trait, ...)
        local kind = nil
        pcall(function() kind = trait:getType() end)
        if kind ~= nil and kind == CharacterTrait.NEEDS_LESS_SLEEP then return false end
        -- retired traits (DanTraits_RETIRED in DanTraits.lua) are never offered
        if kind ~= nil and DanTraits_RETIRED and DanTraitsRegistry then
            for key in pairs(DanTraits_RETIRED) do
                if kind == DanTraitsRegistry[key] then return false end
            end
        end
        local ageKey = ageKeyOf(kind)
        if ageKey and ageOffAtCreation() then return false end
        -- the gate: until an age is chosen, only the ages
        if not ageKey and ageGateOn(self) then return false end
        -- a saved build lists its traits in no useful order: while one loads, every
        -- age-only trait is offered, and the ones the build's age cannot have are dropped after
        if not self.danTraitsLoadingBuild then
            local ok, allowed = pcall(ageAllows, self, kind)
            if ok and allowed == false then return false end
        end
        -- the game only asks whether the trait in the list excludes a chosen one (so
        -- In Their 20s, chosen first, did not hide Arthritis or Handy): ask the other way too
        local chosen = self.listboxTraitSelected and self.listboxTraitSelected.items
        if chosen then
            for _, row in pairs(chosen) do
                local ok, excluded = pcall(function() return row.item ~= trait and row.item:isMutuallyExclusive(trait) end)
                if ok and excluded == true then return false end
            end
        end
        if kind ~= nil and DanTraitsRegistry and kind == DanTraitsRegistry.deepsleeper and isMultiplayer() then
            local ok, allowed = pcall(function()
                return getServerOptions():getBoolean("SleepAllowed") and getServerOptions():getBoolean("SleepNeeded")
            end)
            if ok and not allowed then return false end
        end
        return original(self, trait, ...)
    end)
    -- In Their 30s costs nothing, and vanilla's lists take only a cost above or
    -- below zero: it goes into the positive list by hand, where it is allowed
    DanTraits_Wrap(CharacterCreationProfession, "populateTraitList", "creation-age30s", function(original, self, list, ...)
        local result = original(self, list, ...)
        pcall(function()
            if ageOffAtCreation() or not DanTraitsRegistry or not DanTraitsRegistry.age30s then return end
            local def = CharacterTraitDefinition.getCharacterTraitDefinition(DanTraitsRegistry.age30s)
            if not def or def:isFree() then return end
            local label = def:getLabel()
            if self.listboxTraitSelected and self.listboxTraitSelected:contains(label) then return end
            if self:isTraitEnabled(def) and not self:isTraitExcluded(def) and not list:contains(label) then
                list:addItem(label, def, def:getDescription())
            end
        end)
        return result
    end)
    -- the gate on Next: greyed until an age is chosen, the reason as its
    -- tooltip and written on the screen (vanilla sets the button each frame
    -- from the points; this runs after it)
    DanTraits_Wrap(CharacterCreationProfession, "render", "creation-age-gate", function(original, self, ...)
        local result = original(self, ...)
        pcall(function()
            if not ageGateOn(self) then return end
            self.playButton:setEnable(false)
            self.playButton:setTooltip(getText("UI_DanTraits_PickAgeFirst"))
            local hc = getCore():getBadHighlitedColor()
            local y = self.playButton:getY() - getTextManager():getFontHeight(UIFont.Medium) - 15
            self:drawText(getText("UI_DanTraits_PickAgeHint"), self.listboxTrait:getX(), y, hc:getR(), hc:getG(), hc:getB(), 1, UIFont.Medium)
        end)
        return result
    end)
    -- Random picks an age first (any of the four, right after vanilla's reset),
    -- then rolls the rest from the full lists; if its balancing takes the age
    -- back off, one is added at the end, so a random build always has an age
    DanTraits_Wrap(CharacterCreationProfession, "randomizeTraits", "creation-age-random", function(original, self, ...)
        local gated = not ageOffAtCreation()
        if gated then
            local reset = self.resetBuild
            self.resetBuild = function(screen, ...)
                local r = reset(screen, ...)
                pcall(addRandomAge, screen)
                return r
            end
        end
        local ok, result = pcall(original, self, ...)
        if gated then self.resetBuild = nil end
        if gated and chosenAgeKey(self) == nil then pcall(addRandomAge, self) end
        if not ok then error(result, 0) end
        return result
    end)
    DanTraits_Wrap(CharacterCreationProfession, "checkXPBoost", "creation-age-levels", function(original, self, ...)
        pcall(dropAgeOnly, self)
        local result = original(self, ...)
        pcall(addAgeLevels, self)
        pcall(setAgeDraws, self)
        return result
    end)
    DanTraits_Wrap(CharacterCreationProfession, "loadBuild", "creation-age-only", function(original, self, ...)
        self.danTraitsLoadingBuild = true
        local ok, result = pcall(original, self, ...)
        self.danTraitsLoadingBuild = nil
        pcall(function()
            self:repopulateTraitLists()
            self:checkXPBoost()
        end)
        if not ok then error(result, 0) end
        return result
    end)
    DanTraits_Wrap(CharacterCreationProfession, "PointToSpend", "creation-age-surcharge", function(original, self, ...)
        local points = original(self, ...)
        local ok, extra = pcall(ageSurchargeTotal, self)
        if ok and type(extra) == "number" then points = points - extra end
        return points
    end)
    DanTraits_Wrap(CharacterCreationProfession, "prerender", "creation-age-watch", function(original, self, ...)
        pcall(watchAgeSettings, self)
        return original(self, ...)
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
