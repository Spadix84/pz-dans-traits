-- Project Zomboid Vitality Project: the reading overhaul's client side (the rules are in
-- shared/DanTraits_Reading.lua, the action in
-- shared/DanTraits_ReadingAction.lua).
--
--   right-click  "Read a chapter (~30 min)" on one book, under the vanilla
--                Read: the same action, stopped after a chapter's worth of
--                pages (DanTraits_ReadingAction.lua, readChapter), with
--                the bookmark kept. Only when more than a chapter is left.
--   tooltip      lines under the vanilla tooltip: the genre (with how you
--                feel about it once you know), the pages read of the total,
--                and your verdict once you have finished it (in the strip
--                DanShared_Tooltip.lua draws; the time left to finish
--                is Dan's Vanilla Fixes' item info, when that mod is on).
--   moodle       Good Read (Moodle Framework, optional): Good Read, Great
--                Read, Loved It on the good side, for as long as the finish
--                earned, fed once a minute and straight after a finish.

require "DanShared_Tooltip"
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPaneContextMenu"
require "DanTraits_Reading"
require "DanTraits_ReadingAction"

local R = DanTraits_Reading
local MOODLE = "GoodRead"

-- moodle -------------------------------------------------------------------------

local mfOk = pcall(require, "MF_ISMoodle")
if mfOk and MF and MF.createMoodle then
    pcall(MF.createMoodle, MOODLE)
end

-- a moodle set straight to a level on the good side (the thresholds a tenth
-- apart either side of 0.5, the value in the middle of the level's band); its
-- description names the genre's buff and the hours left (MF good side = 1)
local function showLevel(player, level, text)
    if not MF or not MF.getMoodle then return end
    pcall(function()
        local moodle = MF.getMoodle(MOODLE, player:getPlayerNum())
        if not moodle then return end
        moodle:setThresholds(0.1, 0.2, 0.3, 0.4, 0.6, 0.7, 0.8, 0.9)
        if level > 0 then
            if text then moodle:setDescription(1, math.min(3, level), text) end
            moodle:setValue(0.55 + 0.1 * math.min(3, level))
        else
            moodle:setValue(0.5)
        end
    end)
end

function R.refreshMoodle(player)
    if not player then return end
    local m = R.moodle(player)
    showLevel(player, m and m.level or 0, m and R.moodleText(player))
end

local function refreshAll()
    for i = 0, R.PLAYERS - 1 do
        local player = getSpecificPlayer(i)
        if player then pcall(R.refreshMoodle, player) end
    end
end

Events.EveryOneMinute.Add(refreshAll)
Events.OnGameStart.Add(refreshAll)
R.onFinish("moodle", function(player) R.refreshMoodle(player) end)

-- right-click ----------------------------------------------------------------------

local function onReadChapter(item, playerNum)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not item or item:getContainer() == nil then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    local action = ISReadABook:new(playerObj, item, 150)
    action.readChapter = true
    action.maxTime = action:getDuration()
    ISTimedActionQueue.add(action)
end

local function canRead(player, item)
    if player:hasTrait(CharacterTrait.ILLITERATE) and not R.pictureOnly(item) then return false end
    return true
end

function R.onContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or not R.on() then return end
    local actual = ISInventoryPane.getActualItems(items)
    if #actual ~= 1 then return end
    local item = actual[1]
    local info = R.info(item)
    if not info or not canRead(player, item) then return end
    local left = info.pages - R.mark(player, item, info)
    if left <= 0 then left = info.pages end
    if left <= R.chapterPages(player, info) then return end
    -- not on a multiplayer client: the server rebuilds the action from
    -- ISReadABook:new's own parameters (character, item), so the chapter flag
    -- set after new() never reaches it and the server reads the whole book,
    -- finishing the title when the client's chapter ends. Singleplayer and
    -- split-screen run the one action and are fine. (plans/multiplayer.md)
    if isClient and isClient() then return end
    local option = context:addOption(getText("ContextMenu_DanTraits_ReadChapter", R.CHAPTER_MINUTES), item, onReadChapter, playerNum)
    if option then
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip.description = getText("IGUI_DanTraits_Reading_Pages", R.mark(player, item, info), info.pages)
        option.toolTip = tooltip
    end
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    pcall(R.onContextMenu, playerNum, context, items)
end)

-- tooltip ---------------------------------------------------------------------------

-- the lines for an item we handle: { { text, r, g, b }, ... } or nil
function R.tooltipLines(player, item)
    if not player then return nil end
    local info = R.info(item)
    if not info then return nil end
    local lines = {}
    local genre = R.familyName(info.family)
    local r, g, b = 0.8, 0.8, 0.8
    if R.tasteKnown(player, info.family) then
        local taste = R.tasteOf(player, info.family)
        genre = genre .. getText("IGUI_DanTraits_Reading_" .. taste)
        if taste == "liked" then
            local c = getCore():getGoodHighlitedColor()
            r, g, b = c:getR(), c:getG(), c:getB()
        elseif taste == "disliked" then
            local c = getCore():getBadHighlitedColor()
            r, g, b = c:getR(), c:getG(), c:getB()
        end
    end
    lines[#lines + 1] = { getText("IGUI_DanTraits_Reading_Genre", genre), r, g, b }
    lines[#lines + 1] = { getText("IGUI_DanTraits_Reading_Pages", R.mark(player, item, info), info.pages), 0.8, 0.8, 0.8 }
    local verdict = R.verdict(player, info)
    if verdict then
        lines[#lines + 1] = { getText("IGUI_DanTraits_Reading_Verdict", getText("IGUI_DanTraits_Verdict_" .. verdict)), 0.8, 0.8, 0.8 }
    end
    return lines
end

DanShared_Tooltip.add("reading", 20, R.tooltipLines)
