-- Project Zomboid Vitality Project: Undress and Sleep, in one click.
--
-- Wherever the game offers Sleep (a bed, a sofa, the ground), "Undress and
-- Sleep" goes right under it: walk to the bed, take off everything that
-- costs sleep (DanTraits_SleepUndressList in DanTraits_Sleep.lua: the same
-- slots the clothes-in-bed penalty charges; warm clothes stay on once it is
-- cold enough to want them), put it all on the floor where you stand by the
-- bed with the worn bags, bags in the hands and whatever hung on a slot the
-- clothes give (the knife on the belt), then sleep, without the "are you
-- sure" dialog. Nothing stays in the inventory: a sleep carrying the lot is
-- an over-encumbered sleep, and with a Bad Back that throws it out (found in
-- play 2026-10-27). Every step is the game's own action
-- (unequip, drop, the bed's own sleep), so interruptions, zombies in sight,
-- pain and panic behave as they always do; a cancelled step cancels the
-- sleep too. Shown only while the vanilla Sleep option is available and the
-- sandbox option SleepClothesEnabled is on; greyed when nothing needs to
-- come off.
--
-- The whole outfit is written down when the undressing starts (after the
-- walk), the way Take A Bath And Shower does it: the clothes in the order
-- they were worn, the bags and the hand each one was in, what hung on the
-- hotbar and the hotbar's slot order (taking off a belt or a holster makes
-- the game drop what was on its slots, and putting it back on adds the slot
-- at the end). Clothes come off outer layer first; favourites lose the flag
-- for the drop (the game will not put a favourite on the floor) and get it
-- back in the morning.
--
-- On waking (or once a refused sleep leaves you idle), it all goes back on:
-- up off the bed, over to the pile and everything picked up (as with Take A
-- Bath And Shower), the clothes inner layer first, the bags
-- worn or taken back in hand, the hotbar slots put back in their old order
-- and the knife back on the belt. Every step is the game's own, so moving
-- cancels it; the record is kept until everything that can still be found
-- is back, and "Get Dressed" in the world menu finishes the job (for 12 game
-- hours, then it is let go). The record lives in the player's mod data, so it
-- survives a save.
require "DanTraits_Sleep"
require "TimedActions/ISBaseTimedAction"

DanTraits_SleepMenu = DanTraits_SleepMenu or {}
local M = DanTraits_SleepMenu

local MAX_DEPTH = 3   -- submenus searched for the game's Sleep option
local REFUSED_MIN = 2 -- awake, idle and never asleep this many minutes after bedtime: the sleep was refused
local GRAB_TIME = 50  -- the first pick-up from the floor (the rest are free, as in the game's grab-all)
local KEEP_MIN = 720  -- "Get Dressed" stays this long after the morning's try, then the record is let go

local traitData = DanTraits_Data

local function worn(player, item)
    local yes = false
    pcall(function() yes = player:getWornItems():contains(item) end)
    return yes
end

local function held(player, item)
    local yes = false
    pcall(function() yes = player:getPrimaryHandItem() == item or player:getSecondaryHandItem() == item end)
    return yes
end

local function worldMinutes() return DanTraits_WorldHours() * 60 end

local function hotbarOf(player)
    local hotbar = nil
    pcall(function() hotbar = getPlayerHotbar(player:getPlayerNum()) end)
    return hotbar
end

local function itemID(item)
    local id = nil
    pcall(function() id = item:getID() end)
    return id
end

-- the night's record; an older save kept only a list of clothes IDs
function M.record(d)
    local rec = d.slUndressed
    if rec and rec.clothes == nil then
        rec = { clothes = rec, bags = {}, hotbar = {}, at = d.slUndressAt, slept = d.slUndressSlept }
        d.slUndressed, d.slUndressAt, d.slUndressSlept = rec, nil, nil
    end
    return rec
end

-- where an item of the record is now: the inventory (bags inside bags too), else the floor round the bed
local function carried(player, id)
    local item = nil
    pcall(function() item = player:getInventory():getItemWithIDRecursiv(id) end)
    return item
end

local function onFloor(rec, id)
    local sq = rec.sq
    if not sq then return nil, nil end
    local found, obj = nil, nil
    pcall(function()
        for dx = -1, 1 do
            for dy = -1, 1 do
                local square = getCell():getGridSquare(sq.x + dx, sq.y + dy, sq.z)
                local objs = square and square:getWorldObjects()
                for i = 0, (objs and objs:size() or 0) - 1 do
                    local o = objs:get(i)
                    local it = o:getItem()
                    if it and it:getID() == id then found, obj = it, o; return end
                end
            end
        end
    end)
    return found, obj
end

local function favourite(item)
    local yes = false
    pcall(function() yes = item:isFavorite() end)
    return yes
end

-- what hangs on a hotbar slot that one of these items gives (a belt's, a holster's):
-- off with them it would fall into the inventory
local function looseOnHotbar(player, items)
    local gone, loose = {}, {}
    local hotbar = hotbarOf(player)
    if not hotbar then return loose end
    pcall(function()
        for _, item in ipairs(items) do
            local provided = item:getAttachmentsProvided()
            for i = 0, (provided and provided:size() or 0) - 1 do gone[provided:get(i)] = true end
        end
        for _, item in pairs(hotbar.attachedItems) do
            if gone[item:getAttachedSlotType()] then loose[#loose + 1] = item end
        end
    end)
    return loose
end

-- write the outfit down: clothes in worn order, bags with their hand, the hotbar
local function writeDown(player, clothes, bags, loose)
    local rec = { clothes = {}, bags = {}, hotbar = {}, favs = {}, at = worldMinutes() }
    for _, item in ipairs(clothes) do rec.clothes[#rec.clothes + 1] = itemID(item) end
    for _, list in ipairs({ clothes, bags, loose }) do
        for _, item in ipairs(list) do
            if favourite(item) then rec.favs[#rec.favs + 1] = itemID(item) end
        end
    end
    local primary, secondary = nil, nil
    pcall(function() primary, secondary = player:getPrimaryHandItem(), player:getSecondaryHandItem() end)
    for _, item in ipairs(bags) do
        local hand = nil
        if item == primary and item == secondary then hand = "both"
        elseif item == primary then hand = "primary"
        elseif item == secondary then hand = "secondary" end
        rec.bags[#rec.bags + 1] = { id = itemID(item), hand = hand }
    end
    local hotbar = hotbarOf(player)
    if hotbar then
        pcall(function()
            for _, item in pairs(hotbar.attachedItems) do
                rec.hotbar[#rec.hotbar + 1] = { id = item:getID(), slot = item:getAttachedSlotType() }
            end
            local order = player:getModData().hotbar
            if order then
                rec.order = {}
                for i, slotType in ipairs(order) do rec.order[i] = slotType end
            end
        end)
    end
    pcall(function()
        local sq = player:getCurrentSquare()
        rec.sq = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
    end)
    return rec
end

-- the last step: the bed's own sleep, as if its dialog had said yes. Client
-- only and never sent to the server, like the game's walk-to.
ISDanTraitsBedtimeAction = ISBaseTimedAction:derive("ISDanTraitsBedtimeAction")

function ISDanTraitsBedtimeAction:isValid() return true end

function ISDanTraitsBedtimeAction:perform()
    ISBaseTimedAction.perform(self)
    ISWorldObjectContextMenu.onConfirmSleep(nil, { internal = "YES" }, self.character:getPlayerNum(), self.bed)
end

function ISDanTraitsBedtimeAction:new(character, bed)
    local o = ISBaseTimedAction.new(self, character)
    o.bed = bed
    o.maxTime = 1
    o.stopOnWalk = false
    o.stopOnRun = true
    return o
end

-- by the bed: write the outfit down, then queue onto the floor what hangs off
-- the belt, the bags and the clothes (outer layer first), then the sleep,
-- right behind this step
ISDanTraitsUndressAction = ISBaseTimedAction:derive("ISDanTraitsUndressAction")

function ISDanTraitsUndressAction:isValid() return true end

function ISDanTraitsUndressAction:start()
    local player, playerNum = self.character, self.character:getPlayerNum()
    local clothes, bags = DanTraits_SleepUndressList(player)
    local all = {}
    for _, item in ipairs(clothes) do all[#all + 1] = item end
    for _, item in ipairs(bags) do all[#all + 1] = item end
    local loose = looseOnHotbar(player, all)
    local rec = writeDown(player, clothes, bags, loose)
    local d = traitData(player)
    d.slUndressed = (#rec.clothes > 0 or #rec.bags > 0) and rec or nil
    local hotbar = hotbarOf(player)
    local function down(item)
        pcall(function() item:setFavorite(false) end)
        ISInventoryPaneContextMenu.dropItem(item, playerNum)
    end
    self:beginAddingActions()
    for _, item in ipairs(loose) do
        pcall(function() hotbar:removeItem(item, false) end)   -- off its slot properly first, or it comes back up "attached" to nothing
        down(item)
    end
    for _, item in ipairs(bags) do down(item) end
    for i = #clothes, 1, -1 do down(clothes[i]) end
    ISTimedActionQueue.add(ISDanTraitsBedtimeAction:new(player, self.bed))
    self:endAddingActions()
    self:forceComplete()
end

function ISDanTraitsUndressAction:perform() ISBaseTimedAction.perform(self) end

function ISDanTraitsUndressAction:new(character, bed)
    local o = ISBaseTimedAction.new(self, character)
    o.bed = bed
    o.maxTime = 1
    return o
end

-- the hotbar as it was: the slots in their old order, then everything that
-- hung there back on its slot (what stayed on all night, on the back, is
-- taken off and hung again only when the slots had to move)
local function restoreHotbar(player, rec)
    local hotbar = hotbarOf(player)
    if not hotbar then return end
    pcall(function()
        hotbar.wornItems = nil
        hotbar:refresh()
        local hang = {}
        if rec.order then
            local byType, slots, used = {}, {}, {}
            for _, slot in ipairs(hotbar.availableSlot) do byType[slot.slotType] = slot end
            for _, slotType in ipairs(rec.order) do
                if byType[slotType] and not used[slotType] then slots[#slots + 1] = byType[slotType]; used[slotType] = true end
            end
            for _, slot in ipairs(hotbar.availableSlot) do
                if not used[slot.slotType] then slots[#slots + 1] = slot; used[slot.slotType] = true end
            end
            local moved = false
            for i, slot in ipairs(slots) do if hotbar.availableSlot[i] ~= slot then moved = true end end
            if moved then
                for _, item in pairs(hotbar.attachedItems) do
                    hang[#hang + 1] = { item = item, slot = item:getAttachedSlotType() }
                    hotbar:removeItem(item, false)
                end
                hotbar.availableSlot = slots
                hotbar:savePosition()
            end
        end
        local inv = player:getInventory()
        for _, h in ipairs(rec.hotbar) do
            local item = inv:getItemWithID(h.id)
            if item and not hotbar:isItemAttached(item) then hang[#hang + 1] = { item = item, slot = h.slot } end
        end
        for _, h in ipairs(hang) do
            local index = hotbar:getThisSlotIndex(h.slot)
            local slot = index and hotbar.availableSlot[index]
            local model = slot and slot.def.attachments[h.item:getAttachmentType()]
            if model and not hotbar.attachedItems[index] and not held(player, h.item) and not h.item:isBroken()
                and hotbar:canBeAttached(slot, h.item) then
                hotbar:attachItem(h.item, model, index, slot.def, false)
            end
        end
        hotbar:reloadIcons()
    end)
end

-- everything that can still be found is back where it was
function M.dressed(player, rec)
    for _, id in ipairs(rec.clothes) do
        local item = carried(player, id) or onFloor(rec, id)
        if item and not worn(player, item) then return false end
    end
    for _, b in ipairs(rec.bags) do
        local item = carried(player, b.id) or onFloor(rec, b.id)
        if item and not worn(player, item) and not held(player, item) then return false end
    end
    local hotbar = hotbarOf(player)
    if hotbar then
        local ok, done = pcall(function()
            local inv = player:getInventory()
            for _, h in ipairs(rec.hotbar) do
                if onFloor(rec, h.id) then return false end
                local item = inv:getItemWithID(h.id)
                local index = item and not hotbar:isItemAttached(item) and not held(player, item) and hotbar:getThisSlotIndex(h.slot)
                local slot = index and hotbar.availableSlot[index]
                if slot and not hotbar.attachedItems[index] and hotbar:canBeAttached(slot, item) then return false end
            end
            return true
        end)
        if ok and not done then return false end
    end
    return true
end

-- getting dressed, in three steps so each works on items where they are by then:
-- 1 the walk back and the pick-ups from the floor, 2 the clothes (inner layer
-- first) and the bags, 3 the hotbar, the favourites and the record
ISDanTraitsDressAction = ISBaseTimedAction:derive("ISDanTraitsDressAction")

function ISDanTraitsDressAction:isValid() return true end

function ISDanTraitsDressAction:start()
    local player = self.character
    local rec = M.record(traitData(player))
    if not rec then self:forceComplete(); return end
    if self.step == 3 then return end
    local playerNum = player:getPlayerNum()
    self:beginAddingActions()
    if self.step == 1 then
        local ids = {}
        for _, id in ipairs(rec.clothes) do ids[#ids + 1] = id end
        for _, b in ipairs(rec.bags) do ids[#ids + 1] = b.id end
        for _, h in ipairs(rec.hotbar) do ids[#ids + 1] = h.id end
        local walked, grab = false, GRAB_TIME
        for _, id in ipairs(ids) do
            local item, obj = nil, nil
            if not carried(player, id) then item, obj = onFloor(rec, id) end
            if item then
                if not walked then   -- up off the bed and over to the pile
                    walked = true
                    local sitting = false
                    pcall(function() sitting = player:isSittingOnFurniture() end)
                    if sitting then ISTimedActionQueue.add(ISWaitWhileGettingUp:new(player)) end
                    pcall(function()
                        local sq = getCell():getGridSquare(rec.sq.x, rec.sq.y, rec.sq.z)
                        local here = player:getCurrentSquare()
                        if sq and here and (here:getX() ~= sq:getX() or here:getY() ~= sq:getY() or here:getZ() ~= sq:getZ()) then
                            luautils.walk(player, sq, true)
                        end
                    end)
                end
                if isClient() then
                    ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, item:getContainer(), player:getInventory()))
                else
                    ISTimedActionQueue.add(ISGrabItemAction:new(player, obj, grab))
                    grab = 0
                end
            end
        end
        ISTimedActionQueue.add(ISDanTraitsDressAction:new(player, 2))
    else
        for _, id in ipairs(rec.clothes) do
            local item = carried(player, id)
            if item and not worn(player, item) then ISInventoryPaneContextMenu.wearItem(item, playerNum) end
        end
        for _, b in ipairs(rec.bags) do
            local item = carried(player, b.id)
            if item and not worn(player, item) and not held(player, item) then
                if b.hand then
                    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
                    ISTimedActionQueue.add(ISEquipWeaponAction:new(player, item, 50, b.hand ~= "secondary", b.hand == "both"))
                else
                    ISInventoryPaneContextMenu.wearItem(item, playerNum)
                end
            end
        end
        ISTimedActionQueue.add(ISDanTraitsDressAction:new(player, 3))
    end
    self:endAddingActions()
    self:forceComplete()
end

function ISDanTraitsDressAction:perform()
    ISBaseTimedAction.perform(self)
    if self.step ~= 3 then return end
    local player = self.character
    local d = traitData(player)
    local rec = M.record(d)
    if not rec then return end
    restoreHotbar(player, rec)
    local favs = {}
    for _, id in ipairs(rec.favs or {}) do favs[#favs + 1] = id end
    for _, b in ipairs(rec.bags) do if b.fav then favs[#favs + 1] = b.id end end   -- a record from before 2026-10-27
    for _, id in ipairs(favs) do
        local item = carried(player, id)
        if item then pcall(function() item:setFavorite(true) end) end
    end
    if M.dressed(player, rec) then d.slUndressed = nil end
end

function ISDanTraitsDressAction:new(character, step)
    local o = ISBaseTimedAction.new(self, character)
    o.step = step or 1
    o.maxTime = 1
    return o
end

local function isObject(x) return DanTraits_Is(x, "IsoObject") end

-- what the game's Sleep option sleeps on: (true, bed), (true, nil) for the
-- ground, or false when it cannot be told. Sat or lying on the furniture the
-- game builds it as "get up, then sleep" (ISContextMenu:addGetUpOption): the
-- target is the menu itself, the sleep its first parameter, the bed its second.
function M.sleepBed(opt)
    if opt.onSelect == ISContextMenu.onGetUpAndThen then
        if isObject(opt.param2) then return true, opt.param2 end
        return false, nil
    end
    if opt.target == nil then return opt.onSelect == ISWorldObjectContextMenu.onSleep, nil end
    if isObject(opt.target) then return true, opt.target end
    return false, nil
end

-- the game's Sleep option, in the menu or one of its submenus: the menu it is in and the option
function M.findSleep(menu, depth)
    depth = depth or 0
    if not menu or not menu.options then return nil, nil end
    local name = getText("ContextMenu_Sleep")
    for _, opt in ipairs(menu.options) do
        local getUp = opt.onSelect == ISContextMenu.onGetUpAndThen and opt.param1 == ISWorldObjectContextMenu.onSleep
        if opt.onSelect == ISWorldObjectContextMenu.onSleep or getUp or (opt.name == name and not opt.subOption) then
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

-- walk to the bed, then undress there (which queues the sleep)
function M.undressAndSleep(playerObj, bed)
    ISTimedActionQueue.clear(playerObj)
    local sitting = false
    pcall(function() sitting = playerObj:isSittingOnFurniture() end)
    if sitting then
        ISTimedActionQueue.add(ISWaitWhileGettingUp:new(playerObj))   -- clothes come off standing; the sleep lies back down
    elseif bed then
        local near = true
        pcall(function() near = luautils.walkAdj(playerObj, bed:getSquare(), true) end)
        if not near then return end
    end
    ISTimedActionQueue.add(ISDanTraitsUndressAction:new(playerObj, bed))
end

-- put back on what Undress and Sleep took off
function M.getDressed(player)
    ISTimedActionQueue.add(ISDanTraitsDressAction:new(player, 1))
end

-- each minute: asleep is noted; awake after it, or never asleep and idle,
-- dresses once by itself; after that only "Get Dressed" does, and the record
-- goes once everything is back on (by hand too)
function M.onMinute(player, d)
    local rec = M.record(d)
    if not rec then return end
    if DanTraits_Asleep(player) then
        rec.slept = true
        return
    end
    local busy = false
    pcall(function() busy = player:hasTimedActions() end)
    if rec.tried then
        if worldMinutes() - rec.tried > KEEP_MIN or (not busy and M.dressed(player, rec)) then d.slUndressed = nil end
        return
    end
    if not rec.slept and (busy or worldMinutes() - (rec.at or 0) < REFUSED_MIN) then return end
    rec.tried = worldMinutes()
    M.getDressed(player)
end

function M.onMenu(playerNum, context, worldobjects, test)
    if test or not context then return end
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    local rec = M.record(traitData(playerObj))
    if rec and rec.tried and not DanTraits_Asleep(playerObj) then
        local opt = context:addOption(getText("ContextMenu_DanTraits_GetDressed"), playerObj, M.getDressed)
        tooltip(opt, getText("ContextMenu_DanTraits_GetDressedTip"))
    end
    if not DanTraits_SandboxOn("SleepClothesEnabled") then return end
    local menu, sleep = M.findSleep(context)
    if not sleep or sleep.notAvailable then return end
    local known, bed = M.sleepBed(sleep)
    if not known then return end
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
