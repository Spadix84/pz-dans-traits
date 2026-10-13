-- Dan's Vanilla Fixes: store stock is full.
--
-- Vanilla tags a cigarette pack "lessfull", so wherever it spawns the loot
-- roll (ItemPickerJava) leaves it with a random number of cigarettes. That
-- suits a pack in a dresser or a desk, not one on a gas station or
-- convenience store shelf. The roll is done before OnFillContainer fires, so
-- here every pack that spawns in a shop room is filled back up. The rooms are
-- the ones whose containers vanilla stocks from its retail cigarette tables
-- (StoreCounterTobacco, GasStoreSpecial, TobaccoStoreCigarettes).

DVF_StoreStock = DVF_StoreStock or {}
local S = DVF_StoreStock

S.ITEMS = { ["Base.CigarettePack"] = true }
S.ROOMS = {
    conveniencestore = true, cornerstore = true, cornerstorecounter = true, fossoil = true,
    gas2go = true, gasstore = true, generalstore = true, liquorstore = true,
    tobaccostorage = true, tobaccostore = true, zippeestore = true,
}

-- top a drainable up to its full count; false when it already was
function S.fill(item)
    local max = item:getMaxUses()
    if item:getCurrentUses() >= max then return false end
    item:setCurrentUses(max)
    return true
end

function S.onFillContainer(roomName, containerType, container)
    if not S.ROOMS[roomName or ""] then return end
    if not container or not instanceof(container, "ItemContainer") then return end   -- the game sometimes passes a loot-table entry
    local ok, items = pcall(function() return container:getItems() end)
    if not ok or not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and S.ITEMS[item:getFullType()] then pcall(S.fill, item) end
    end
end

Events.OnFillContainer.Add(S.onFillContainer)
