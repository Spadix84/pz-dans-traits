-- Found where the vanilla toaster is, plus home and store kitchen cupboards.
-- Uncommon: a 1993 kitchen staple. Home kitchens 3 against 8-10 for a pot or pan
-- (vanilla's 1-2 is rare); stores close behind the toaster's 20 + 10.
local LOOT = {
    ElectronicStoreAppliances = 15,
    CrateElectronics = 0.5,
    GigamartHouseElectronics = 6,
    KitchenPots = 3,
    StoreKitchenPots = 6,
}

-- The recipe pamphlet: kitchen drawers and the odd bookshelf, rarer than a cookbook.
local BOOKLET = {
    KitchenBook = 2,
    CrateBooks = 1,
    LibraryBooks = 0.5,
    PostOfficeBooks = 0.5,
    LivingRoomShelfRedneck = 0.1,
}

local function add(lists, item)
    for name, weight in pairs(lists) do
        local list = ProceduralDistributions.list[name]
        if list and list.items then
            table.insert(list.items, item)
            table.insert(list.items, weight)
        end
    end
end

-- One card per dish, wherever vanilla's recipe clippings turn up. Per card, so
-- all nine together come to about what a single vanilla clipping gets.
local CARDS = {
    KitchenBook = 1,
    KitchenRandom = 0.05,
    CrateRandomJunk = 0.1,
    SafehouseBookShelf = 1,
    SafehouseFood = 1,
    SafehouseFood_Mid = 1,
    SafehouseFood_Late = 1,
}

add(LOOT, "Mov_SlowCooker")
add(BOOKLET, "SlowCookerBooklet")
for _, id in ipairs({ "soupbeans", "chili", "beefstew", "cornchowder", "potroast", "sloppyjoes",
    "chickendumplings", "pulledpork", "burgoo" }) do
    add(CARDS, "SlowCookerCard_" .. id)
end
