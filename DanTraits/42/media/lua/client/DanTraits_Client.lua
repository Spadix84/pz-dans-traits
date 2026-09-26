-- Client side pieces for Dan's Traits: the Airway Irritation moodle
-- (needs Moodle Framework; skipped without it), the inhaler context menu,
-- the Vegetarian grey-out, and the diabetes items (inject, check sugar,
-- take metformin).
require "TimedActions/ISUseInhalerAction"
require "TimedActions/ISDiabetesAction"

local ok = pcall(function() require "MF_ISMoodle" end)
if ok and MF and MF.createMoodle then
    MF.createMoodle("AirwayIrritation")
    MF.createMoodle("Vitality")
    MF.createMoodle("SleptBadly")
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

local function usesOf(item)
    local n = 0
    pcall(function() n = item:getCurrentUsesFloat() or 0 end)
    return n
end

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

-- Vegetarian: grey out Eat on meat with the reason
local function greyOutMeat(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not DanTraits_RefusesFood then return end
    local meat = findFirst(items, function(item) return DanTraits_RefusesFood(playerObj, item) end)
    if not meat then return end
    local names = { getText("ContextMenu_Eat") }
    pcall(function() local custom = meat:getCustomMenuOption(); if custom then table.insert(names, custom) end end)
    for _, name in ipairs(names) do
        local option = context:getOptionFromName(name)
        if option then greyOut(option, "Tooltip_DanTraits_VegetarianRefuse") end
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

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(greyOutMeat)
Events.OnFillInventoryObjectContextMenu.Add(diabetesMenu)
