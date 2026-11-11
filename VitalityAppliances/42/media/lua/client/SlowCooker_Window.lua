-- The Slow Cooker window: pick a recipe, tick the ingredients, add them to the crock.
-- Opened from the cooker's right-click menu. Recipes you don't know yet are listed
-- greyed out with the Cooking level that unlocks them.
--
-- Ingredients (and the crock) can come from anywhere the game's own crafting looks:
-- the character's inventory and bags, and every container the loot window can reach
-- (counters, fridges, the floor). The chosen ones are fetched when you press Add,
-- then the character goes to the cooker and fills the crock.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "TimedActions/SlowCookerActions"

SlowCookerWindow = ISCollapsableWindow:derive("SlowCookerWindow")
SlowCookerWindow.instances = {}
SlowCookerWindow.lastRecipe = {}   -- per player: the recipe picked last time

local FONT = UIFont.Small
local WHITE = { r = 0.9, g = 0.9, b = 0.9, a = 1 }
local GREY = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
local HEAD = { r = 0.95, g = 0.75, b = 0.4, a = 1 }
local SHORT = { r = 0.9, g = 0.4, b = 0.35, a = 1 }
local GOOD = { r = 0.45, g = 0.8, b = 0.4, a = 1 }
local STALE = { r = 0.9, g = 0.7, b = 0.3, a = 1 }
local PAD = 10
local RECIPE_W = 220
local RESCAN_MS = 1000             -- how often the window looks again for ingredients

local function fontHeight() return getTextManager():getFontHeight(FONT) end

local function isCrock(item)
    local t = item:getFullType()
    return t == SlowCooker.CROCK or t == SlowCooker.DISH
end

-- Every container in reach: the character's own first, then the loot window's.
-- The game's crafting uses the same list (locked player-built crates left out).
local function reachable(playerObj)
    local out = {}
    local function add(c)
        if not c then return end
        for _, have in ipairs(out) do
            if have == c then return end
        end
        table.insert(out, c)
    end
    add(playerObj:getInventory())
    local ok, list = pcall(ISInventoryPaneContextMenu.getContainers, playerObj)
    if ok and list then
        for i = 0, list:size() - 1 do add(list:get(i)) end
    end
    return out
end

local function isCarried(container, playerObj)
    return container == playerObj:getInventory() or container:isInCharacterInventory(playerObj)
end

-- Where an item is, for the right-hand column: "Carried", a bag's name, "Fridge"...
local function placeName(container, playerObj)
    if container == playerObj:getInventory() then return getText("IGUI_SlowCooker_Carried") end
    local bag = container:getContainingItem()
    if bag then return bag:getDisplayName() end
    return getTextOrNull("IGUI_ContainerTitle_" .. tostring(container:getType()))
        or getText("IGUI_SlowCooker_Nearby")
end

local function freshness(item)
    local ok, rotten = pcall(function() return item:isRotten() end)
    if ok and rotten then return "rotten" end
    local ok2, fresh = pcall(function() return item:isFresh() end)
    if ok2 and fresh == false then return "stale" end
    return nil
end

local function ageShare(item)
    local share = 0
    pcall(function() share = item:getAge() / math.max(item:getOffAge(), 1) end)
    return share
end

local function usable(item)
    if not instanceof(item, "Food") then return false end
    if isCrock(item) or item:isFrozen() or item:isBurnt() then return false end
    return true
end

local function firstCrockIn(container)
    local items = container and container:getItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        if isCrock(items:get(i)) then return items:get(i) end
    end
    return nil
end

-- The crock to use: the one in the cooker, else one carried, else one nearby.
-- Returns the crock and whether it's in the cooker.
local function findCrock(cooker, playerObj)
    local own = cooker:getContainer()
    local inCooker = firstCrockIn(own)
    if inCooker then return inCooker, true end
    for _, c in ipairs(reachable(playerObj)) do
        if c ~= own then
            local found = isCarried(c, playerObj) and c:getFirstEvalRecurse(isCrock) or firstCrockIn(c)
            if found then return found, false end
        end
    end
    return nil, false
end

-- Building the window ----------------------------------------------------------
function SlowCookerWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local fh = fontHeight()
    local th = self:titleBarHeight()
    self.statusY = th + 8
    self.headerY = self.statusY + fh + 10
    local top = self.headerY + fh + 4
    local by = self.height - PAD - 25
    self.messageY = by - fh - 8
    local listH = self.messageY - 6 - top
    local ingX = PAD + RECIPE_W + PAD
    self.ingX = ingX

    self.recipes = ISScrollingListBox:new(PAD, top, RECIPE_W, listH)
    self.recipes:initialise()
    self.recipes:instantiate()
    self.recipes.font = FONT
    self.recipes.fontHgt = fh
    self.recipes.itemheight = fh + 10
    self.recipes.window = self
    self.recipes.doDrawItem = SlowCookerWindow.drawRecipe
    self.recipes:setOnMouseDownFunction(self, self.onRecipe)
    self:addChild(self.recipes)

    self.ingredients = ISScrollingListBox:new(ingX, top, self.width - ingX - PAD, listH)
    self.ingredients:initialise()
    self.ingredients:instantiate()
    self.ingredients.font = FONT
    self.ingredients.fontHgt = fh
    self.ingredients.itemheight = math.max(fh + 8, 26)
    self.ingredients.window = self
    self.ingredients.doDrawItem = SlowCookerWindow.drawIngredient
    self.ingredients:setOnMouseDownFunction(self, self.onIngredient)
    self:addChild(self.ingredients)

    local function button(x, w, text, fn, tip)
        local b = ISButton:new(x, by, w, 25, getText(text), self, fn)
        b:initialise()
        if tip then b:setTooltip(getText(tip)) end
        self:addChild(b)
        return b
    end
    self.autoButton = button(ingX, 100, "IGUI_SlowCooker_AutoPick", self.autoPick, "IGUI_SlowCooker_AutoPickTip")
    self.clearButton = button(ingX + 106, 80, "IGUI_SlowCooker_Clear", self.clearChosen)
    self.closeButton = button(self.width - PAD - 100, 100, "IGUI_SlowCooker_Close", self.close)
    self.addButton = button(self.width - PAD - 100 - 6 - 130, 130, "IGUI_SlowCooker_Add", self.onAdd)

    self:refresh(true)
    self:fillRecipes()
end

-- Looking for ingredients ------------------------------------------------------
-- Everything stew-able in reach, carried first. Also returns a key that changes
-- when what's in reach changes, so the lists are only rebuilt when they need to be.
function SlowCookerWindow:scan()
    local playerObj = self.playerObj
    self.evolved = self.evolved or SlowCooker.evolvedRecipe()
    local evolved = self.evolved
    local own = self.cooker:getContainer()
    local found, seen, ids = {}, {}, {}
    local function fits(item)
        return usable(item) and (evolved == nil or evolved:getItemRecipe(item) ~= nil)
    end
    for _, c in ipairs(reachable(playerObj)) do
        if c ~= own then
            local carried = isCarried(c, playerObj)
            local items = carried and c:getAllEvalRecurse(fits) or c:getAllEval(fits)
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                local id = item:getID()
                if not seen[id] then
                    seen[id] = true
                    table.insert(ids, id)
                    table.insert(found, {
                        item = item, id = id, type = item:getFullType(), name = item:getDisplayName(),
                        place = placeName(item:getContainer() or c, playerObj), carried = carried,
                        fresh = freshness(item),
                    })
                end
            end
        end
    end
    table.sort(found, function(a, b)
        if a.carried ~= b.carried then return a.carried end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    table.sort(ids)
    return found, table.concat(ids, ",")
end

function SlowCookerWindow:refresh(force)
    local crock, inCooker = findCrock(self.cooker, self.playerObj)
    local found, key = self:scan()
    key = key .. "|" .. (crock and (crock:getID() .. tostring(inCooker)) or "-")
    self.crock, self.crockInCooker = crock, inCooker
    if not force and key == self.scanKey then return end
    self.scanKey = key
    self.found = found
    self.haveTypes = {}
    local byId = {}
    for _, f in ipairs(found) do
        self.haveTypes[f.type] = true
        byId[f.id] = f
    end
    local kept = {}                          -- keep choices that are still in reach
    for id in pairs(self.chosen) do
        kept[id] = byId[id]
    end
    self.chosen = kept
    self:updateRecipeStates()
    if self.recipe then self:fillIngredients() end
end

-- Recipes ------------------------------------------------------------------------
function SlowCookerWindow:recipeState(r)
    if r.id == SlowCooker.FREEFORM then
        if #self.found > 0 then return "ready", getText("IGUI_SlowCooker_FreeformTip") end
        return "missing", getText("IGUI_SlowCooker_NothingStew")
    end
    if not SlowCooker.knows(self.playerObj, r) then
        return "locked", getText("IGUI_SlowCooker_NeedsLevel", r.level)
    end
    local missing = {}
    for _, g in ipairs(r.groups) do
        if g.need > 0 then
            local n = 0
            for _, t in ipairs(g.items) do
                if self.haveTypes[t] then n = n + 1 end
            end
            if n < g.need then table.insert(missing, getText(g.label)) end
        end
    end
    if #missing == 0 then return "ready", getText("IGUI_SlowCooker_HaveAll") end
    return "missing", getText("IGUI_SlowCooker_Missing", table.concat(missing, ", "))
end

function SlowCookerWindow:updateRecipeStates()
    self.recipeStates = {}
    if not self.recipes then return end
    for _, row in ipairs(self.recipes.items) do
        local state, tip = self:recipeState(row.item)
        self.recipeStates[row.item] = state
        row.tooltip = tip
    end
end

function SlowCookerWindow:fillRecipes()
    self.recipes:clear()
    local want = SlowCookerWindow.lastRecipe[self.playerNum]
    local free = { id = SlowCooker.FREEFORM }
    local pick, pickIndex = free, 1
    self.recipes:addItem(getText("IGUI_SlowCooker_Freeform"), free)
    for i, r in ipairs(SlowCooker.RECIPES) do
        self.recipes:addItem(getText(r.name), r)
        if r.id == want then pick, pickIndex = r, i + 1 end
    end
    self:updateRecipeStates()
    self.recipes.selected = pickIndex
    self.recipes:ensureVisible(pickIndex)
    self:onRecipe(pick)
end

function SlowCookerWindow:onRecipe(recipe)
    self.recipe = recipe
    self.chosen = {}
    SlowCookerWindow.lastRecipe[self.playerNum] = recipe and recipe.id
    self.ingredients:setYScroll(0)
    self:fillIngredients()
end

function SlowCookerWindow:isFree()
    return self.recipe == nil or self.recipe.id == SlowCooker.FREEFORM
end

-- Ingredients ----------------------------------------------------------------------
-- What's in reach that fits the selected recipe, under the recipe's group headings.
function SlowCookerWindow:fillIngredients()
    local list = self.ingredients
    local scroll = list:getYScroll()
    list:clear()
    if self:isFree() then
        self:addHeading(getText("IGUI_SlowCooker_AnyStew"), nil)
        self:addItems(self.found)
    else
        for _, g in ipairs(self.recipe.groups) do
            local wanted = {}
            for _, t in ipairs(g.items) do wanted[t] = true end
            local items = {}
            for _, f in ipairs(self.found) do
                if wanted[f.type] then table.insert(items, f) end
            end
            self:addHeading(getText(g.label), g)
            self:addItems(items)
        end
    end
    list.selected = -1
    list:setYScroll(scroll)
end

function SlowCookerWindow:addHeading(text, g)
    self.ingredients:addItem(text, { heading = true, group = g })
end

function SlowCookerWindow:addItems(items)
    if #items == 0 then
        self.ingredients:addItem(getText("IGUI_SlowCooker_NoneCarried"), { empty = true })
        return
    end
    for _, f in ipairs(items) do
        local tip = f.place
        if f.fresh then
            tip = tip .. " <LINE> " .. getText(f.fresh == "rotten" and "IGUI_SlowCooker_Rotten" or "IGUI_SlowCooker_Stale")
        end
        self.ingredients:addItem(f.name, f, tip)
    end
end

function SlowCookerWindow:onIngredient(row)
    if not row or row.heading or row.empty then return end
    local id = row.id
    self.chosen[id] = (not self.chosen[id]) and row or nil
end

function SlowCookerWindow:clearChosen()
    self.chosen = {}
end

function SlowCookerWindow:chosenItems()
    local out = {}
    for _, f in pairs(self.chosen) do table.insert(out, f.item) end
    table.sort(out, function(a, b) return a:getID() < b:getID() end)
    return out
end

function SlowCookerWindow:chosenCount()
    local n = 0
    for _ in pairs(self.chosen) do n = n + 1 end
    return n
end

-- How many different chosen types count towards a group (as SlowCooker.check counts).
function SlowCookerWindow:groupHave(g)
    local wanted, types, n = {}, {}, 0
    for _, t in ipairs(g.items) do wanted[t] = true end
    for _, f in pairs(self.chosen) do
        if wanted[f.type] and not types[f.type] then
            types[f.type] = true
            n = n + 1
        end
    end
    return n
end

function SlowCookerWindow:inCrock()
    local crock = self.crock
    if crock and crock:getFullType() == SlowCooker.DISH then
        local extra = crock:getExtraItems()
        return extra and extra:size() or 0
    end
    return 0
end

-- Fill each required group with the best of what's in reach: good food before stale
-- before rotten, carried before nearby, then the freshest. Extras are left to you.
function SlowCookerWindow:autoPick()
    if self:isFree() then return end
    self.chosen = {}
    local room = SlowCooker.MAX_INGREDIENTS - self:inCrock()
    local rank = { stale = 1, rotten = 2 }
    for _, g in ipairs(self.recipe.groups) do
        if g.need > 0 then
            local wanted = {}
            for _, t in ipairs(g.items) do wanted[t] = true end
            local cands = {}
            for _, f in ipairs(self.found) do
                if wanted[f.type] then table.insert(cands, f) end
            end
            table.sort(cands, function(a, b)
                local ra, rb = rank[a.fresh] or 0, rank[b.fresh] or 0
                if ra ~= rb then return ra < rb end
                if a.carried ~= b.carried then return a.carried end
                return ageShare(a.item) < ageShare(b.item)
            end)
            local have = self:groupHave(g)
            local types = {}
            for _, f in pairs(self.chosen) do types[f.type] = true end
            for _, f in ipairs(cands) do
                if have >= g.need or room <= 0 then break end
                if not types[f.type] then
                    self.chosen[f.id] = f
                    types[f.type] = true
                    have = have + 1
                    room = room - 1
                end
            end
        end
    end
end

-- Why the Add button can't go ahead yet, or nil.
function SlowCookerWindow:problem()
    local crock = self.crock
    if not crock then return getText("IGUI_SlowCooker_NoCrock") end
    if not self:isFree() and not SlowCooker.knows(self.playerObj, self.recipe) then
        return getText("IGUI_SlowCooker_NeedsLevel", self.recipe.level)
    end
    local items = self:chosenItems()
    if #items == 0 then
        return getText(self:isFree() and "IGUI_SlowCooker_PickSome" or "IGUI_SlowCooker_PickOrAuto")
    end
    if crock:getFullType() == SlowCooker.DISH and not self:isFree() then
        return getText("IGUI_SlowCooker_CrockFull")
    end
    if self:inCrock() + #items > SlowCooker.MAX_INGREDIENTS then
        return getText("IGUI_SlowCooker_TooMany", SlowCooker.MAX_INGREDIENTS)
    end
    if not self:isFree() then
        local types = {}
        for _, item in ipairs(items) do table.insert(types, item:getFullType()) end
        local ok, short = SlowCooker.check(self.recipe, types)
        if not ok then return getText("IGUI_SlowCooker_Short", getText(short)) end
    end
    return nil
end

-- Drawing ----------------------------------------------------------------------------
local function offscreen(list, y, h)
    return y + list:getYScroll() + h < 0 or y + list:getYScroll() >= list.height
end

local function hovered(list, row)
    return list.mouseoverselected == row.index and list:isMouseOver() and not list:isMouseOverScrollBar()
end

function SlowCookerWindow.drawRecipe(list, y, row, alt)
    local h = row.height or list.itemheight
    if offscreen(list, y, h) then return y + h end
    local win = list.window
    if list.selected == row.index then
        list:drawSelection(0, y, list:getWidth(), h - 1)
    elseif hovered(list, row) then
        list:drawMouseOverHighlight(0, y, list:getWidth(), h - 1)
    end
    local state = win.recipeStates and win.recipeStates[row.item] or "missing"
    local dot = state == "ready" and GOOD or (state == "locked" and GREY or STALE)
    list:drawRect(9, y + (h - 8) / 2, 8, 8, 1, dot.r, dot.g, dot.b)
    local c = state == "locked" and GREY or WHITE
    local ty = y + (h - list.fontHgt) / 2
    list:drawText(row.text, 24, ty, c.r, c.g, c.b, c.a, list.font)
    if state == "locked" then
        list:drawTextRight(getText("IGUI_SlowCooker_LevelShort", row.item.level), list:getWidth() - 18, ty,
            GREY.r, GREY.g, GREY.b, GREY.a, list.font)
    end
    return y + h
end

function SlowCookerWindow.drawIngredient(list, y, row, alt)
    local h = row.height or list.itemheight
    if offscreen(list, y, h) then return y + h end
    local win, d, w = list.window, row.item, list:getWidth()
    local ty = y + (h - list.fontHgt) / 2
    local right = w - 18

    if d.heading then
        list:drawRect(0, y, w, h - 1, 0.5, 0.22, 0.17, 0.12)
        list:drawText(row.text, 8, ty, HEAD.r, HEAD.g, HEAD.b, HEAD.a, list.font)
        local g = d.group
        if g and g.need > 0 then
            local have = win:groupHave(g)
            local c = have >= g.need and GOOD or SHORT
            list:drawTextRight(have .. " / " .. g.need, right, ty, c.r, c.g, c.b, c.a, list.font)
        elseif not g then
            list:drawTextRight(tostring(win:chosenCount()), right, ty, WHITE.r, WHITE.g, WHITE.b, WHITE.a, list.font)
        end
        return y + h
    end
    if d.empty then
        list:drawText(row.text, 30, ty, GREY.r, GREY.g, GREY.b, GREY.a, list.font)
        return y + h
    end

    local on = win.chosen[d.id] ~= nil
    if on then
        list:drawRect(0, y, w, h - 1, 0.18, GOOD.r, GOOD.g, GOOD.b)
    end
    if hovered(list, row) then
        list:drawMouseOverHighlight(0, y, w, h - 1)
    end
    local by = y + (h - 12) / 2
    list:drawRectBorder(8, by, 12, 12, 0.9, 0.8, 0.8, 0.8)
    if on then list:drawRect(11, by + 3, 6, 6, 1, GOOD.r, GOOD.g, GOOD.b) end
    local tex = d.item:getTex()
    if tex then list:drawTextureScaledAspect(tex, 28, y + (h - 20) / 2, 20, 20, 1, 1, 1, 1) end
    list:drawText(d.name, 54, ty, WHITE.r, WHITE.g, WHITE.b, WHITE.a, list.font)
    if d.fresh then
        local x = 54 + getTextManager():MeasureStringX(list.font, d.name)
        local c = d.fresh == "rotten" and SHORT or STALE
        local tag = getText(d.fresh == "rotten" and "IGUI_SlowCooker_Rotten" or "IGUI_SlowCooker_Stale")
        list:drawText("  " .. tag, x, ty, c.r, c.g, c.b, c.a, list.font)
    end
    local pc = d.carried and WHITE or GREY
    list:drawTextRight(d.place, right, ty, pc.r, pc.g, pc.b, 0.7, list.font)
    return y + h
end

function SlowCookerWindow:prerender()
    ISCollapsableWindow.prerender(self)
    local now = getTimestampMs()
    if not self.lastScan or now - self.lastScan >= RESCAN_MS then
        self.lastScan = now
        self:refresh(false)
    end

    local crock = self.crock
    local status
    if not crock then
        status = getText("IGUI_SlowCooker_NoCrock")
    elseif crock:getFullType() == SlowCooker.CROCK then
        status = getText("IGUI_SlowCooker_CrockEmpty")
    else
        status = getText("IGUI_SlowCooker_CrockHas", crock:getDisplayName())
    end
    if crock and not self.crockInCooker then
        status = status .. "  " .. getText("IGUI_SlowCooker_CrockElsewhere")
    end
    self:drawText(status, PAD, self.statusY, 1, 1, 1, 0.9, FONT)
    local count = getText("IGUI_SlowCooker_Chosen", self:chosenCount(), SlowCooker.MAX_INGREDIENTS - self:inCrock())
    self:drawTextRight(count, self.width - PAD, self.statusY, 1, 1, 1, 0.9, FONT)

    self:drawText(getText("IGUI_SlowCooker_RecipesHeader"), PAD, self.headerY, HEAD.r, HEAD.g, HEAD.b, 1, FONT)
    self:drawText(getText("IGUI_SlowCooker_IngredientsHeader"), self.ingX, self.headerY, HEAD.r, HEAD.g, HEAD.b, 1, FONT)

    local problem = self:problem()
    self.addButton:setEnable(problem == nil)
    self.autoButton:setEnable(not self:isFree() and SlowCooker.knows(self.playerObj, self.recipe))
    self.clearButton:setEnable(self:chosenCount() > 0)   -- the game's Lua has no next()
    if problem then
        self:drawText(problem, PAD, self.messageY, SHORT.r, SHORT.g, SHORT.b, 1, FONT)
    else
        self:drawText(getText("IGUI_SlowCooker_Ready"), PAD, self.messageY, GOOD.r, GOOD.g, GOOD.b, 1, FONT)
    end
end

-- Adding ---------------------------------------------------------------------------
local function walksQueued(playerObj, from)
    local q = ISTimedActionQueue.getTimedActionQueue(playerObj)
    local list = q and q.queue or {}
    for i = from + 1, #list do
        if list[i].Type == "ISWalkToTimedAction" then return true end
    end
    return false
end

local function queueLength(playerObj)
    local q = ISTimedActionQueue.getTimedActionQueue(playerObj)
    return q and q.queue and #q.queue or 0
end

function SlowCookerWindow:onAdd()
    self:refresh(true)
    if self:problem() then return end
    local playerObj, cooker = self.playerObj, self.cooker
    local crock, inCooker = findCrock(cooker, playerObj)
    local items = self:chosenItems()

    -- Gather first, from where the character stands: what's in reach now is what the
    -- window listed. Each transfer walks to its container if it has to.
    local before = queueLength(playerObj)
    for _, item in ipairs(items) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    end
    if not inCooker then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, crock) end

    -- Then to the cooker. If gathering walked anywhere, walk back whatever happens now.
    local there
    if walksQueued(playerObj, before) then
        local adjacent = AdjacentFreeTileFinder.Find(cooker:getSquare(), playerObj)
        if adjacent then ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, adjacent)) end
        there = adjacent ~= nil
    else
        there = luautils.walkAdj(playerObj, cooker:getSquare(), true)
    end
    if there then
        if inCooker then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, crock, cooker:getContainer(),
                playerObj:getInventory()))
        end
        local recipeId = (not self:isFree()) and self.recipe.id or nil
        ISTimedActionQueue.add(SlowCookerAddAction:new(playerObj, cooker, crock, items, recipeId))
    end
    self:close()
end

function SlowCookerWindow:close()
    SlowCookerWindow.instances[self.playerNum] = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function SlowCookerWindow.open(playerNum, cooker)
    local old = SlowCookerWindow.instances[playerNum]
    if old then old:close() end
    local w, h = 700, 480
    local x = getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - w) / 2
    local y = getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - h) / 2
    local o = ISCollapsableWindow.new(SlowCookerWindow, x, y, w, h)
    o.playerNum = playerNum
    o.playerObj = getSpecificPlayer(playerNum)
    o.cooker = cooker
    o.title = getText("IGUI_SlowCooker_Title")
    o.resizable = false
    o.chosen = {}
    o.found = {}
    o.haveTypes = {}
    o:initialise()
    o:addToUIManager()
    SlowCookerWindow.instances[playerNum] = o
    return o
end

-- Right-click the cooker: "Slow Cooker..." ---------------------------------------
local function cookerIn(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if SlowCooker.isCooker(obj) then return obj end
        local square = obj:getSquare()
        if square then
            local objects = square:getObjects()
            for i = 0, objects:size() - 1 do
                if SlowCooker.isCooker(objects:get(i)) then return objects:get(i) end
            end
        end
    end
    return nil
end

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
    local cooker = cookerIn(worldobjects)
    if not cooker then return end
    if test then return true end
    context:addOption(getText("ContextMenu_SlowCooker_Open"), player, SlowCookerWindow.open, cooker)
end)

-- New recipes as Cooking goes up ---------------------------------------------------
Events.LevelPerk.Add(function(player, perk, level, increased)
    if perk ~= Perks.Cooking or not increased or not player:isLocalPlayer() then return end
    if SlowCooker.hasBooklet(player) then return end
    for _, r in ipairs(SlowCooker.unlockedAt(level)) do
        if not SlowCooker.hasCard(player, r) then HaloTextHelper.addGoodText(player, getText("IGUI_SlowCooker_Learned", getText(r.name))) end
    end
end)
