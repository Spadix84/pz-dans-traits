-- Base Unloader: the run. One step at a time: walk to the source and load up
-- (a trip's worth, planned by the core), or walk to one container and put
-- down what belongs there. A tiny marker action ends every step; when it
-- completes the next step is planned from what is actually in the trunk and
-- the bag, so an interruption (a zombie, a key press, a reload) loses
-- nothing: the plan is saved in the world's mod data and Resume plans the next
-- step from scratch.
--
-- Vanilla does the walking and the moving: luautils.walkToContainer paths to a
-- world container or a vehicle's vpart area, ISInventoryTransferAction moves
-- each item. Only one destination is queued at a time because walkToContainer
-- clears the queue before it walks.

require "TimedActions/ISBaseTimedAction"
require "BaseUnloader_Scan"

local BU = BaseUnloader
local S = BU_Scan
BU_Run = {}
local R = BU_Run

R.active = {}          -- [playerNum] = state of a run in progress
R.MAX_NO_PROGRESS = 2  -- steps in a row that moved nothing before the run gives up

-- the marker ------------------------------------------------------------------------------

BU_MarkAction = ISBaseTimedAction:derive("BU_MarkAction")

function BU_MarkAction:isValid() return true end
function BU_MarkAction:update() end
function BU_MarkAction:start() end
function BU_MarkAction:stop() ISBaseTimedAction.stop(self) end

function BU_MarkAction:perform()
    ISBaseTimedAction.perform(self)
    if self.state then self.state.stepDone = true end
end

function BU_MarkAction:new(character, state)
    local o = ISBaseTimedAction.new(self, character)
    o.state = state
    o.maxTime = 1
    o.stopOnWalk = false
    o.stopOnAim = false
    o.stopOnRun = false
    return o
end

-- helpers -----------------------------------------------------------------------------------

local function whoIs(player)
    local who
    pcall(function() who = player:getUsername() end)
    if not who or who == "" then who = "player" .. tostring(player:getPlayerNum()) end
    return who
end

local function say(player, good, text)
    pcall(function()
        if good then HaloTextHelper.addGoodText(player, text) else HaloTextHelper.addBadText(player, text) end
    end)
end

local function posOf(player)
    local sq = S.squareOf(player)
    if sq then return { x = sq:getX(), y = sq:getY(), z = sq:getZ() } end
    return { x = player:getX(), y = player:getY(), z = player:getZ() }
end

local function idKey(id)
    return tostring(id)
end

-- the worn bags, as the trip planner wants them: { inv, left (room by weight),
-- keep (the share of an item's weight still felt inside: 1 - reduction), ok }.
-- A bag only carried (in the hands or loose) is not one: what goes in it
-- weighs in full, so the hands might as well hold it.
local function bagsOf(player)
    local bags = {}
    pcall(function()
        local items = player:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local worn = false
            pcall(function() worn = it:isEquipped() == true or it:isWorn() == true end)
            if worn and instanceof(it, "InventoryContainer") and it:getInventory() then
                local inv = it:getInventory()
                local red, left = 0, 0
                pcall(function() red = it:getWeightReduction() end)
                pcall(function() left = inv:getCapacity() - inv:getCapacityWeight() end)
                bags[#bags + 1] = { item = it, inv = inv, left = left, keep = 1 - (red or 0) / 100,
                    ok = function(r)
                        local fits = false
                        pcall(function() fits = r.item ~= it and inv:hasRoomFor(player, r.item) end)
                        return fits
                    end }
            end
        end
    end)
    return bags
end

-- every item the character carries, main inventory and inside bags, as records
local function allCarried(player)
    local inv = nil
    pcall(function() inv = player:getInventory() end)
    if not inv then return {} end
    return S.allItems(inv)
end

-- the carried items this run owns, with their destinations; drops from the
-- plan anything no longer carried
local function carriedRecords(state)
    local plan = state.plan
    local found, seen = {}, {}
    for _, r in ipairs(allCarried(state.player)) do
        local dest = plan.carried[idKey(r.id)]
        if dest then
            r.dest = dest
            found[#found + 1] = r
            seen[idKey(r.id)] = true
        end
    end
    for k in pairs(plan.carried) do
        if not seen[k] then plan.carried[k] = nil end
    end
    return found
end

local function rowsByKey(rows)
    local byKey = {}
    for _, row in ipairs(rows) do byKey[row.key] = row end
    return byKey
end

-- the containers of the base: scanned once per run, their room refreshed each step
local function containersFor(state)
    if state.rows then
        for _, row in ipairs(state.rows) do
            pcall(function()
                row.capacity = S.capacity(row.container, state.player)
                row.used = row.container:getCapacityWeight()
                row.free = math.max(0, row.capacity - row.used)
            end)
        end
        return state.rows
    end
    local src = state.source
    local sq = src and S.sourceSquare(src) or nil
    local zone = S.zone(state.player, sq)
    state.zone = zone
    state.rows = S.containers(zone, src and src.container or nil, state.player)
    return state.rows
end

-- what the resolver needs to place this run's items
local function contextFor(state, rows, use)
    local store = BU.store()
    local src = state.source
    return { rules = store.rules, tags = store.tags, oneOffs = state.plan.oneOffs, containers = rows, use = use or {},
             pos = posOf(state.player), sourceKey = src and src.key or nil, hidden = store.hidden,
             offLimits = store.offLimits, ruleCounts = BU.ruleCounts(store.rules) }
end

-- Another home for an item whose container turned out full: the resolver
-- again, without that container (use = weight already planned this step).
local function elsewhere(state, r, rows, use, notKey)
    local rest = {}
    for _, row in ipairs(rows) do
        if row.key ~= notKey then rest[#rest + 1] = row end
    end
    local ctx = contextFor(state, rest, use)
    ctx.oneOffs = nil
    return (BU.resolve(r, ctx))
end

local function queueMarker(state)
    state.stepDone = false
    state.inStep = true
    ISTimedActionQueue.add(BU_MarkAction:new(state.player, state))
end

-- the steps ------------------------------------------------------------------------------------

local function finish(state)
    local plan = state.plan
    local n = state.delivered or 0
    say(state.player, true, getText("IGUI_BU_Done", n))
    local nowhere = (state.noContainer or 0) + (state.lost or 0)
    if nowhere > 0 then say(state.player, false, getText("IGUI_BU_Nowhere", nowhere)) end
    if (state.noRoom or 0) > 0 then say(state.player, false, getText("IGUI_BU_NoRoom", state.noRoom)) end
    if (state.tooHeavy or 0) > 0 then say(state.player, false, getText("IGUI_BU_TooHeavy", state.tooHeavy)) end
    BU.store().plans[state.who] = nil
    R.active[state.playerNum] = nil
end

function R.pause(state, textKey)
    R.active[state.playerNum] = nil
    state.inStep = false
    say(state.player, false, getText(textKey or "IGUI_BU_Paused"))
end

-- put down what is carried: one container per step, nearest first
local function sourcePos(state)
    local src = state.source
    if src and src.kind ~= "self" and src.x then return { x = src.x, y = src.y, z = src.z or 0 } end
    return nil
end

-- the trip's tour is planned once, from where the character stands, ending
-- near the source for the next load; each step takes its first remaining stop
local function nextStop(state, carried, rows)
    local byKey = rowsByKey(rows)
    local byDest = {}
    local lost = {}
    for _, r in ipairs(carried) do
        if r.dest and byKey[r.dest] then
            if not byDest[r.dest] then byDest[r.dest] = {} end
            local list = byDest[r.dest]
            list[#list + 1] = r
        else
            lost[#lost + 1] = r
        end
    end
    local route = state.route
    if route then
        while #route > 0 and not byDest[route[1]] do table.remove(route, 1) end
        if #route == 0 then route = nil end
    end
    if not route then
        local stops = BU.deliveryOrder(carried, rows, posOf(state.player), sourcePos(state))
        route = {}
        for _, s in ipairs(stops) do route[#route + 1] = s.key end
        state.route = route
    end
    if #route == 0 then return nil, lost end
    local key = table.remove(route, 1)
    return { key = key, items = byDest[key] }, lost
end

-- an item the run gives up on (nowhere to go, cannot get there, no room after
-- all) leaves the plan and is not picked up again this run: with the player's
-- own bag as the source, the next load would route it straight back to the
-- same container and the run would spin on it every tick (2026-10-22)
local function giveUp(state, r, counter)
    state.plan.carried[idKey(r.id)] = nil
    state.gaveUp = state.gaveUp or {}
    state.gaveUp[idKey(r.id)] = true
    state[counter] = (state[counter] or 0) + 1
end

-- a step that queued nothing counts toward the stuck check all the same
local function stall(state)
    state.noProgress = (state.noProgress or 0) + 1
    if state.noProgress >= R.MAX_NO_PROGRESS then
        R.pause(state, "IGUI_BU_Stuck")
        return true
    end
    state.pending = true
    return true
end

local function deliverStep(state, carried)
    local rows = containersFor(state)
    local stop, lost = nextStop(state, carried, rows)
    for _, r in ipairs(lost) do giveUp(state, r, "lost") end
    if not stop then return false end
    local row = rowsByKey(rows)[stop.key]
    local ok, reached = pcall(luautils.walkToContainer, row.container, state.playerNum)
    if not ok or not reached then
        -- cannot get there: those items stay in the bag and leave the plan
        for _, r in ipairs(stop.items) do giveUp(state, r, "lost") end
        return stall(state)
    end
    state.expect = {}
    local use = {}
    for _, r in ipairs(stop.items) do
        local fits = false
        pcall(function() fits = row.container:hasRoomFor(state.player, r.item) end)
        if fits then
            local from = r.item:getContainer()
            ISTimedActionQueue.add(ISInventoryTransferAction:new(state.player, r.item, from, row.container))
            state.expect[#state.expect + 1] = { record = r, from = from, delivering = true }
            use[stop.key] = (use[stop.key] or 0) + (r.weight or 0)
        else
            -- full after all: somewhere else tagged for it, or it stays in the bag
            local other = elsewhere(state, r, rows, use, stop.key)
            if other then
                state.plan.carried[idKey(r.id)] = other
                use[other] = (use[other] or 0) + (r.weight or 0)
            else
                giveUp(state, r, "noRoom")
            end
        end
    end
    if #state.expect == 0 then return stall(state) end
    queueMarker(state)
    return true
end

-- load a trip's worth from the source
local function loadStep(state)
    local src = state.source
    if not src then return false end
    local plan = state.plan
    local rows = containersFor(state)
    local pool
    if src.kind == "self" then pool = allCarried(state.player) else pool = S.allItems(src.container) end
    -- every item through the resolver, the room it takes counted for the next;
    -- bags are unpacked (a bag waits until nothing inside it is going anywhere)
    local items, nowhere = BU.route(pool, contextFor(state, rows, {}))
    state.noContainer = nowhere
    if #items == 0 then return false end
    if src.kind == "self" then
        -- already in hand: everything with a home joins the delivery, except what
        -- this run has already given up on
        local joined = 0
        for _, r in ipairs(items) do
            if not (state.gaveUp and state.gaveUp[idKey(r.id)]) then
                plan.carried[idKey(r.id)] = r.dest
                joined = joined + 1
            end
        end
        if joined == 0 then return false end
        state.pending = true
        return true
    end
    local player = state.player
    -- never past the sandbox's Heavy Load level (2: 1.5x the max weight); worn bags fill first
    local budget = 0
    pcall(function() budget = BU.loadBudget(player:getMaxWeight(), player:getInventory():getCapacityWeight(), S.maxLoad()) end)
    local trip = BU.trip(items, rows, posOf(player), budget, bagsOf(player))
    state.noRoom = trip.skipped.noRoom
    state.tooHeavy = trip.skipped.tooHeavy
    if #trip.stops == 0 then return false end
    state.route = nil
    local ok, reached = pcall(luautils.walkToContainer, src.container, state.playerNum)
    if not ok then
        R.pause(state, "IGUI_BU_LeaveVehicle")
        return true
    end
    if not reached then
        R.pause(state, "IGUI_BU_CantReach")
        return true
    end
    if src.kind == "vehicle" then
        -- a closed trunk lid opens on the way
        pcall(function()
            local vpart = src.vpart
            if vpart:getDoor() and vpart:getInventoryItem() and not vpart:getDoor():isOpen() then
                if vpart:getDoor():isLocked() then
                    ISTimedActionQueue.add(ISUnlockVehicleDoor:new(player, vpart))
                end
                ISTimedActionQueue.add(ISOpenVehicleDoor:new(player, vpart:getVehicle(), vpart))
            end
        end)
    end
    state.expect = {}
    for _, stop in ipairs(trip.stops) do
        for _, r in ipairs(stop.items) do
            local into = r.into and r.into.inv or player:getInventory()
            local from = r.from or src.container
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, r.item, from, into))
            plan.carried[idKey(r.id)] = stop.key
            state.expect[#state.expect + 1] = { record = r, from = from }
        end
    end
    queueMarker(state)
    return true
end

function R.step(state)
    local player = state.player
    if not player or player:isDead() then
        R.active[state.playerNum] = nil
        return
    end
    local carried = carriedRecords(state)
    if #carried > 0 and deliverStep(state, carried) then return end
    if loadStep(state) then return end
    finish(state)
end

-- a step's marker completed: count what moved, give up if nothing does twice
local function afterStep(state)
    local moved = 0
    for _, e in ipairs(state.expect or {}) do
        local now
        pcall(function() now = e.record.item:getContainer() end)
        if now ~= e.from then
            moved = moved + 1
            if e.delivering then
                state.delivered = (state.delivered or 0) + 1
                state.plan.carried[idKey(e.record.id)] = nil
            end
        elseif not e.delivering then
            -- did not leave the source: not carried after all
            state.plan.carried[idKey(e.record.id)] = nil
        end
    end
    state.expect = nil
    if moved == 0 then
        state.noProgress = (state.noProgress or 0) + 1
        if state.noProgress >= R.MAX_NO_PROGRESS then
            R.pause(state, "IGUI_BU_Stuck")
            return
        end
    else
        state.noProgress = 0
    end
    state.pending = true
end

function R.onTick()
    for num, state in pairs(R.active) do
        if state.pending then
            state.pending = false
            R.step(state)
        elseif state.inStep then
            if state.stepDone then
                state.inStep = false
                afterStep(state)
            else
                local q = ISTimedActionQueue.getTimedActionQueue(state.player)
                if q and #q.queue == 0 then R.pause(state) end
            end
        end
    end
end

-- starting, resuming, forgetting ---------------------------------------------------------------------

local function newState(player, source, plan)
    local num = player:getPlayerNum()
    return { player = player, playerNum = num, who = whoIs(player), source = source, plan = plan,
             delivered = 0, pending = true }
end

-- a new run from the window: the one-off assignments ride with the plan
function R.start(player, source, oneOffs)
    local who = whoIs(player)
    local plan = { source = S.saveSource(source), oneOffs = oneOffs or {}, carried = {} }
    BU.store().plans[who] = plan
    local state = newState(player, source, plan)
    R.active[player:getPlayerNum()] = state
    say(player, true, getText("IGUI_BU_Started"))
end

function R.hasPlan(player)
    return BU.store().plans[whoIs(player)] ~= nil
end

function R.isRunning(player)
    return R.active[player:getPlayerNum()] ~= nil
end

-- pick a saved plan back up: the source is found again by id or key; with the
-- source gone, what is already carried is still put away
function R.resume(player)
    local who = whoIs(player)
    local plan = BU.store().plans[who]
    if not plan then return false end
    plan.carried = plan.carried or {}
    plan.oneOffs = plan.oneOffs or {}
    local source = S.loadSource(plan.source, player)
    if not source then say(player, false, getText("IGUI_BU_SourceGone")) end
    local state = newState(player, source, plan)
    R.active[player:getPlayerNum()] = state
    say(player, true, getText("IGUI_BU_Resumed"))
    return true
end

function R.forget(player)
    BU.store().plans[whoIs(player)] = nil
    R.active[player:getPlayerNum()] = nil
end

function R.stop(player)
    local state = R.active[player:getPlayerNum()]
    if state then R.pause(state) end
end

Events.OnTick.Add(R.onTick)
Events.OnGameStart.Add(function()
    BU.resetStore()
    pcall(function() BU.store().lastTags = nil end)   -- "same categories as last" is for this sitting
    R.active = {}
end)
