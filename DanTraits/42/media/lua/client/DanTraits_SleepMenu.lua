-- Project Zomboid Vitality Project: Undress and Sleep, in one click.
--
-- Wherever the game offers Sleep (a bed, a sofa, the ground), "Undress and
-- Sleep" goes right under it: walk to the bed, take off everything that
-- costs sleep (DanTraits_SleepUndressList in DanTraits_Sleep.lua: the same
-- slots the clothes-in-bed penalty charges; warm clothes stay on once it is
-- cold enough to want them), put worn bags and bags in the hands on the
-- floor by the bed, then sleep, without the "are you sure" dialog. The
-- clothes go into the main inventory. Every step is the game's own action
-- (unequip, drop, the bed's own sleep), so interruptions, zombies in sight,
-- pain and panic behave as they always do; a cancelled step cancels the
-- sleep too. Shown only while the vanilla Sleep option is available and the
-- sandbox option SleepClothesEnabled is on; greyed when nothing needs to
-- come off.
--
-- On waking, what it took off goes back on (the game's own wear action, one
-- per garment, so moving cancels it): whatever is still carried, bags
-- included, and not already worn. The same happens if the sleep never came
-- (zombies in sight, pain, panic) once the queue is empty. Bags stay on the
-- floor. The list is kept in the player's mod data, so it survives a save.
require "DanTraits_Sleep"
require "TimedActions/ISBaseTimedAction"

DanTraits_SleepMenu = DanTraits_SleepMenu or {}
local M = DanTraits_SleepMenu

local MAX_DEPTH = 3   -- submenus searched for the game's Sleep option
local REFUSED_MIN = 2 -- awake, idle and never asleep this many minutes after bedtime: the sleep was refused

local traitData = DanTraits_Data

local function worn(player, item)
    local yes = false
    pcall(function() yes = player:getWornItems():contains(item) end)
    return yes
end

local function worldMinutes()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h * 60
end

-- the last step: the bed's own sleep, as if its dialog had said yes. Client
-- only and never sent to the server, like the game's walk-to.
ISDanTraitsBedtimeAction = ISBaseTimedAction:derive("ISDanTraitsBedtimeAction")

function ISDanTraitsBedtimeAction:isValid() return true end

-- what came off is remembered for the morning, then the bed's own sleep
function ISDanTraitsBedtimeAction:perform()
    ISBaseTimedAction.perform(self)
    local ids = {}
    for _, item in ipairs(self.clothes or {}) do
        if not worn(self.character, item) then
            pcall(function() ids[#ids + 1] = item:getID() end)
        end
    end
    local d = traitData(self.character)
    if #ids > 0 then
        d.slUndressed, d.slUndressAt, d.slUndressSlept = ids, worldMinutes(), nil
    else
        d.slUndressed = nil
    end
    ISWorldObjectContextMenu.onConfirmSleep(nil, { internal = "YES" }, self.character:getPlayerNum(), self.bed)
end

function ISDanTraitsBedtimeAction:new(character, bed, clothes)
    local o = ISBaseTimedAction.new(self, character)
    o.bed = bed
    o.clothes = clothes
    o.maxTime = 1
    o.stopOnWalk = false
    o.stopOnRun = true
    return o
end

-- the game's Sleep option, in the menu or one of its submenus: the menu it is in and the option
function M.findSleep(menu, depth)
    depth = depth or 0
    if not menu or not menu.options then return nil, nil end
    local name = getText("ContextMenu_Sleep")
    for _, opt in ipairs(menu.options) do
        if opt.onSelect == ISWorldObjectContextMenu.onSleep or (opt.name == name and not opt.subOption) then
            return menu, opt
        end
        if opt.subOption and depth < MAX_DEPTH then
            local sub = nil
            pcall(function() sub = menu:getSubMenu(opt.subOption) end)
            local m, o = M.findSleep(sub, depth + 1)
            if m then return m, o end
        end
    end
    return nil, nil
end

local function names(items)
    local out = {}
    for _, item in ipairs(items) do
        local n = "?"
        pcall(function() n = item:getDisplayName() end)
        out[#out + 1] = n
    end
    return table.concat(out, ", ")
end

local function tooltip(option, text)
    pcall(function()
        local tip = ISToolTip:new()
        tip:initialise()
        tip:setVisible(false)
        tip.description = text
        option.toolTip = tip
    end)
end

-- walk to the bed, take things off, put the bags down, sleep
function M.undressAndSleep(playerObj, bed)
    local playerNum = playerObj:getPlayerNum()
    local clothes, bags = DanTraits_SleepUndressList(playerObj)
    ISTimedActionQueue.clear(playerObj)
    if bed and not playerObj:isSittingOnFurniture() then
        local near = true
        pcall(function() near = luautils.walkAdj(playerObj, bed:getSquare(), true) end)
        if not near then return end
    end
    for _, item in ipairs(clothes) do ISInventoryPaneContextMenu.unequipItem(item, playerNum) end
    for _, item in ipairs(bags) do ISInventoryPaneContextMenu.dropItem(item, playerNum) end
    ISTimedActionQueue.add(ISDanTraitsBedtimeAction:new(playerObj, bed, clothes))
end

-- put back on what Undress and Sleep took off, if it is still carried and not worn
function M.redress(player, d)
    local ids = d.slUndressed
    d.slUndressed, d.slUndressAt, d.slUndressSlept = nil, nil, nil
    local playerNum = player:getPlayerNum()
    local n = 0
    for _, id in ipairs(ids) do
        local item = nil
        pcall(function() item = player:getInventory():getItemWithIDRecursiv(id) end)
        if item and not worn(player, item) then
            ISInventoryPaneContextMenu.wearItem(item, playerNum)
            n = n + 1
        end
    end
    return n
end

-- each minute: asleep is noted; awake after it, or never asleep and idle, dresses again
function M.onMinute(player, d)
    if not d.slUndressed then return end
    if DanTraits_Asleep(player) then
        d.slUndressSlept = true
        return
    end
    if not d.slUndressSlept then
        local busy = false
        pcall(function() busy = player:hasTimedActions() end)
        if busy or worldMinutes() - (d.slUndressAt or 0) < REFUSED_MIN then return end
    end
    M.redress(player, d)
end

function M.onMenu(playerNum, context, worldobjects, test)
    if test or not context then return end
    if not DanTraits_SandboxOn("SleepClothesEnabled") then return end
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    local menu, sleep = M.findSleep(context)
    if not sleep or sleep.notAvailable then return end
    local bed = sleep.target
    if type(bed) ~= "userdata" and type(bed) ~= "table" then bed = nil end
    local option = menu:insertOptionAfter(sleep.name, getText("ContextMenu_DanTraits_UndressSleep"), playerObj, M.undressAndSleep, bed)
    if not option then return end
    local clothes, bags = DanTraits_SleepUndressList(playerObj)
    if #clothes == 0 and #bags == 0 then
        option.notAvailable = true
        tooltip(option, getText("ContextMenu_DanTraits_UndressSleepNone"))
        return
    end
    local lines = {}
    if #clothes > 0 then lines[#lines + 1] = getText("ContextMenu_DanTraits_UndressSleepOff", names(clothes)) end
    if #bags > 0 then lines[#lines + 1] = getText("ContextMenu_DanTraits_UndressSleepDrop", names(bags)) end
    tooltip(option, table.concat(lines, " <LINE> "))
end

Events.OnFillWorldObjectContextMenu.Add(M.onMenu)
DanTraits_Every("minute", "SleepMenu", M.onMinute, 90)
