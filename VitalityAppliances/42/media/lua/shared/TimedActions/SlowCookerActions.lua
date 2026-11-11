-- Serving a bowl from the crock, and moving the whole meal into a cooking pot.
-- The dish can stay where it is (in the cooker, seen through the loot window);
-- the bowl or pot comes from the character's inventory and the result goes there.
require "TimedActions/ISBaseTimedAction"
require "SlowCooker_Food"
require "SlowCooker_API"

local function swap(container, old, new)
    container:DoRemoveItem(old)
    sendRemoveItemFromContainer(container, old)
    container:AddItem(new)
    sendAddItemToContainer(container, new)
end

local function give(character, item)
    local inv = character:getInventory()
    inv:AddItem(item)
    sendAddItemToContainer(inv, item)
end

local function take(character, item)
    local container = item:getContainer()
    container:DoRemoveItem(item)
    sendRemoveItemFromContainer(container, item)
end

local function stillThere(self, item)
    local container = item and item:getContainer()
    return container ~= nil and container:containsID(item:getID())
end

-- Serve one bowl ---------------------------------------------------------------
SlowCookerServeAction = ISBaseTimedAction:derive("SlowCookerServeAction")

function SlowCookerServeAction:isValid()
    return stillThere(self, self.dish) and self.character:getInventory():containsID(self.bowl:getID())
end

function SlowCookerServeAction:start()
    self:setActionAnim(CharacterActionAnims.Pour)
    self:setOverrideHandModels(self.bowl, nil)
    self.sound = self.character:playSound("CraftPrepareCooking")
end

function SlowCookerServeAction:stop()
    if self.sound then self.character:stopOrTriggerSound(self.sound) end
    ISBaseTimedAction.stop(self)
end

function SlowCookerServeAction:perform()
    if self.sound then self.character:stopOrTriggerSound(self.sound) end
    ISBaseTimedAction.perform(self)
end

function SlowCookerServeAction:complete()
    local out = SlowCooker.BOWLS[self.bowl:getFullType()]
    if not out then return false end
    local container = self.dish:getContainer()
    local filled, empty = SlowCooker.fillBowl(self.dish, out, instanceItem)
    take(self.character, self.bowl)
    give(self.character, filled)
    if empty then
        swap(container, self.dish, instanceItem(SlowCooker.CROCK))
    else
        sendItemStats(self.dish)
    end
    SlowCooker.fire("served", self.character, (not empty) and self.dish or nil, filled, "bowl")
    return true
end

function SlowCookerServeAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 60
end

function SlowCookerServeAction:new(character, dish, bowl)
    local o = ISBaseTimedAction.new(self, character)
    o.dish, o.bowl = dish, bowl
    o.maxTime = o:getDuration()
    return o
end

-- Move it all into a pot ---------------------------------------------------------
SlowCookerToPotAction = ISBaseTimedAction:derive("SlowCookerToPotAction")

function SlowCookerToPotAction:isValid()
    return stillThere(self, self.dish) and self.character:getInventory():containsID(self.pot:getID())
end

function SlowCookerToPotAction:start()
    self:setActionAnim(CharacterActionAnims.Pour)
    self:setOverrideHandModels(self.pot, nil)
    self.sound = self.character:playSound("CraftPrepareCooking")
end

SlowCookerToPotAction.stop = SlowCookerServeAction.stop
SlowCookerToPotAction.perform = SlowCookerServeAction.perform

function SlowCookerToPotAction:complete()
    local out = SlowCooker.POTS[self.pot:getFullType()]
    if not out then return false end
    local container = self.dish:getContainer()
    local filled = SlowCooker.fillPot(self.dish, out, instanceItem)
    take(self.character, self.pot)
    give(self.character, filled)
    swap(container, self.dish, instanceItem(SlowCooker.CROCK))
    SlowCooker.fire("served", self.character, nil, filled, "pot")
    return true
end

function SlowCookerToPotAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 120
end

function SlowCookerToPotAction:new(character, dish, pot)
    local o = ISBaseTimedAction.new(self, character)
    o.dish, o.pot = dish, pot
    o.maxTime = o:getDuration()
    return o
end

-- Add ingredients ------------------------------------------------------------------
-- The crock and the ingredients are in the character's inventory by now (the window
-- queues the transfers). Each goes in through the game's evolved recipe, the same
-- call its own "add to stew" makes. A named recipe then names the dish, and the
-- crock goes back into the cooker.
require "SlowCooker_Recipes"
require "TimedActions/ISAddItemInRecipe"

SlowCookerAddAction = ISBaseTimedAction:derive("SlowCookerAddAction")

function SlowCookerAddAction:isValid()
    local inv = self.character:getInventory()
    if not inv:containsID(self.crock:getID()) then return false end
    for _, item in ipairs(self.items) do
        if not inv:containsID(item:getID()) then return false end
    end
    return true
end

function SlowCookerAddAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    self.sound = self.character:playSound("CraftPrepareCooking")
end

SlowCookerAddAction.stop = SlowCookerServeAction.stop
SlowCookerAddAction.perform = SlowCookerServeAction.perform

function SlowCookerAddAction:complete()
    local recipe = SlowCooker.evolvedRecipe()
    if not recipe then return false end
    local inv = self.character:getInventory()
    self.character:removeFromHands(self.crock)
    local dish = self.crock
    for _, item in ipairs(self.items) do
        if inv:containsID(item:getID()) then
            dish = recipe:addItem(dish, item, self.character)
            if isServer() and item:getContainer() then sendItemStats(item) end
        end
    end
    local named = self.recipeId and SlowCooker.recipeById(self.recipeId)
    if named then
        SlowCooker.nameDish(dish, named)
    else
        ISAddItemInRecipe.checkName(dish, recipe)
        dish:getModData().slowCookerHome = true
    end
    if isServer() then sendItemStats(dish) end

    local container = self.cooker and self.cooker:getContainer()
    if container and inv:containsID(dish:getID()) then
        inv:DoRemoveItem(dish)
        sendRemoveItemFromContainer(inv, dish)
        container:AddItem(dish)
        sendAddItemToContainer(container, dish)
    end
    SlowCooker.fire("dishMade", self.character, dish, named or nil)
    return true
end

function SlowCookerAddAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 60 + 30 * #self.items
end

-- recipeId: a named recipe's id, or nil for plain crock stew.
function SlowCookerAddAction:new(character, cooker, crock, items, recipeId)
    local o = ISBaseTimedAction.new(self, character)
    o.cooker, o.crock, o.items, o.recipeId = cooker, crock, items, recipeId
    o.maxTime = o:getDuration()
    return o
end
