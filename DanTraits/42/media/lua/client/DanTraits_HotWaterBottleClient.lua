-- The hot water bottle, client side (DanTraits_HotWaterBottle.lua): "Hold on
-- sore muscles" on the bottle's menu, a muscle group each (with its state
-- when Fitness Training is on), greyed out until it is Hot or Warm; and a line
-- under its tooltip saying how warm it is and for how long (DanShared_Tooltip.lua).
require "DanTraits"
require "DanShared_Tooltip"
require "TimedActions/ISDanTraitsHeatAction"

local function actualItems(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then return ISInventoryPane.getActualItems(items) end
    return items
end

local function onHold(item, playerObj, group)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(ISDanTraitsHeatAction:new(playerObj, item, group))
end

local function greyOut(option, textKey)
    option.notAvailable = true
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = getText(textKey)
    option.toolTip = tooltip
end

local function groupLabel(playerObj, g)
    local name = getText("IGUI_DanTraits_FitGroup_" .. g)
    if not (DanTraits_SandboxOn("FitnessEnabled") and DanTraits_FitGroupState) then return name end
    local state = nil
    pcall(function() state = DanTraits_FitGroupState(playerObj, nil, g) end)
    if not state then return name end
    return getText("ContextMenu_DanTraits_HwbGroup", name, getText("IGUI_DanTraits_FitState_" .. state))
end

local function bottleMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not DanTraits_HwbIsBottle then return end
    for _, item in ipairs(actualItems(items)) do
        if DanTraits_HwbIsBottle(item) then
            local option = context:addOption(getText("ContextMenu_DanTraits_HwbApply"), item, nil)
            local stage = DanTraits_HwbStage(item)
            if stage ~= "hot" and stage ~= "warm" then
                greyOut(option, DanTraits_HwbHasFluid(item) and "Tooltip_DanTraits_HwbCold" or "Tooltip_DanTraits_HwbEmpty")
                return
            end
            local sub = ISContextMenu:getNew(context)
            context:addSubMenu(option, sub)
            for _, g in ipairs(DanTraits_FIT_GROUPS) do
                sub:addOption(groupLabel(playerObj, g), item, onHold, playerObj, g)
            end
            return
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Add(bottleMenu)

-- "Hot: about 40 min more", "Warm: about 1 h 30 min more", "Tepid", or how to use it
local function duration(hours)
    local minutes = math.max(5, math.floor(hours * 60 / 5 + 0.5) * 5)
    if minutes < 60 then return getText("Tooltip_DanTraits_HwbMin", minutes) end
    local h, m = math.floor(minutes / 60), minutes % 60
    if m == 0 then return getText("Tooltip_DanTraits_HwbHours", h) end
    return getText("Tooltip_DanTraits_HwbHoursMin", h, m)
end

local COLOURS = { hot = { 1, 0.55, 0.3 }, warm = { 1, 0.8, 0.45 }, tepid = { 0.75, 0.75, 0.75 } }

DanShared_Tooltip.add("dt-hotwaterbottle", 40, function(player, item)
    if not DanTraits_HwbIsBottle or not DanTraits_HwbIsBottle(item) then return nil end
    local stage, left = DanTraits_HwbStageLeft(item)
    local text
    if stage == "hot" or stage == "warm" then
        text = getText("Tooltip_DanTraits_Hwb_" .. stage, duration(left))
    elseif stage == "tepid" then
        text = getText("Tooltip_DanTraits_Hwb_tepid")
    else
        text = getText(DanTraits_HwbHasFluid(item) and "Tooltip_DanTraits_HwbCold" or "Tooltip_DanTraits_HwbEmpty")
    end
    local c = COLOURS[stage] or { 0.75, 0.75, 0.75 }
    return { { text, c[1], c[2], c[3] } }
end)
