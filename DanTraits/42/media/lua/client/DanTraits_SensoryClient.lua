-- Sensory Issues, client side: the stim option on a fidget toy or a plush
-- (ISSensoryStimAction), and a food's tooltip line, safe or can't stand it
-- (DanShared_Tooltip.lua), and a garment's feel: soft, or scratchy, rough or tight.
require "DanTraits"
require "DanShared_Tooltip"
require "DanTraits_ClientUtil"
require "TimedActions/ISSensoryStimAction"

local hasTrait = DanTraits_HasTrait
local actualItems = DanTraits_ActualItems

local function onStim(item, playerObj)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(ISSensoryStimAction:new(playerObj, item))
end

local function stimMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not hasTrait(playerObj, "sensory") or not DanTraits_SensoryStimKind then return end
    for _, item in ipairs(actualItems(items)) do
        local kind = DanTraits_SensoryStimKind(item)
        if kind then
            context:addOption(getText(kind == "hold" and "ContextMenu_DanTraits_SensoryHold" or "ContextMenu_DanTraits_SensoryFidget"), item, onStim, playerObj)
            return
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Add(stimMenu)

-- a garment: soft in green; scratchy, rough or tight in red
local FEEL_COLOUR = { soft = { 0.45, 0.85, 0.45 }, scratchy = { 0.9, 0.4, 0.35 }, denim = { 0.9, 0.6, 0.35 }, tight = { 0.9, 0.4, 0.35 } }

local function garmentLines(item)
    local feel = DanTraits_SensoryGarmentTip and DanTraits_SensoryGarmentTip(item)
    local c = feel and FEEL_COLOUR[feel]
    if not c then return nil end
    return { { getText("Tooltip_DanTraits_Sensory_" .. feel), c[1], c[2], c[3] } }
end

-- the lines for a food or a garment, for a character with the trait
function DanTraits_SensoryTooltipLines(player, item)
    if not player or not item or not DanTraits_SensoryFood or not hasTrait(player, "sensory") then return nil end
    if DanTraits_Is(item, "Clothing") then return garmentLines(item) end
    if not DanTraits_Is(item, "Food") then return nil end
    local verdict, group = DanTraits_SensoryFood(player, item)
    if verdict == "safe" then
        return { { getText("Tooltip_DanTraits_SensorySafe", getText("UI_DanTraits_SensoryGroup_" .. group)), 0.45, 0.85, 0.45 } }
    elseif verdict == "disliked" then
        return { { getText("Tooltip_DanTraits_SensoryHate", getText("UI_DanTraits_SensoryGroup_" .. group)), 0.9, 0.4, 0.35 } }
    end
    return nil
end

DanShared_Tooltip.add("sensory", 21, DanTraits_SensoryTooltipLines)
