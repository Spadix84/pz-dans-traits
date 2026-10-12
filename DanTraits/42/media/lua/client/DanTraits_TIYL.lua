-- Project Zomboid Vitality Project: This Is Your Life compatibility.
require "DanTraits"

-- Does nothing unless This Is Your Life (Workshop 3773911887) is loaded. No
-- dependency either way.
--
-- This Is Your Life swaps the vanilla trait screen for its own "Personnel
-- Assessment" folder (TIYL.TraitSelect, ThisIsYourLife/TIYLTraitSelect.lua).
-- The vanilla screen is still there, hidden, and does all the work: the folder
-- adds and removes traits, counts points (PointToSpend), randomises, loads
-- builds and fills its Major Skills from it, so the age levels, the
-- surcharge in the points, Random's age and the build loader already work
-- through the wraps in DanTraits_Client.lua. What the folder does itself:
--
--   populate     lists every trait with a cost above or below zero, straight
--                from CharacterTraitDefinition.getTraits(). In Their 30s costs
--                nothing and was never listed, and the traits this mod keeps
--                off the screen (the gate, the other ages' traits, retired
--                ones) were listed and greyed out as "unavailable with the
--                current game settings". After it runs, those rows come out
--                (DanTraits_Creation.hides) and In Their 30s goes in at the
--                top of the positive list.
--   Continue     only checks the points, so it is held back while the gate is
--                up (no age chosen), with the same tooltip and hint as the
--                vanilla screen's Next.
--   rows         draw the trait's own cost only; the age surcharge or discount
--                is written under it.
--
-- Its Quick Start and poster stories skip the trait screen: those characters
-- have no age trait and get the Default Age sandbox setting, like any
-- character made without the creation screen.
local installed = false

local function screen()
    return MainScreen.instance and MainScreen.instance.charCreationProfession
end

local function chosen(vanilla, trait)
    local items = vanilla and vanilla.listboxTraitSelected and vanilla.listboxTraitSelected.items
    if not items then return false end
    for _, row in pairs(items) do
        if row.item == trait then return true end
    end
    return false
end

-- the surcharge or discount, under the cost on the right
local function drawWithSurcharge(original)
    return function(list, y, item, alt)
        local yy = original(list, y, item, alt)
        pcall(function()
            local band = DanTraits_Creation.band(screen())
            local extra = band and DanTraits_AgeSurcharge(band, item.item:getType()) or 0
            if extra == 0 then return end
            local hc = extra > 0 and getCore():getBadHighlitedColor() or getCore():getGoodHighlitedColor()
            local label = extra > 0 and getText("UI_DanTraits_AgeSurcharge", extra) or getText("UI_DanTraits_AgeDiscount", extra)
            list:drawTextRight(label, list.width - 18, y + 21, hc:getR(), hc:getG(), hc:getB(), 0.9, UIFont.NewSmall)
        end)
        return yy
    end
end

local function setDraws(panel)
    for _, list in ipairs({ panel.goodList, panel.badList }) do
        if list and list.doDrawItem and not list.danTraitsDraw then
            list.doDrawItem = drawWithSurcharge(list.doDrawItem)
            list.danTraitsDraw = true
        end
    end
end

local function fixLists(panel)
    local vanilla = screen()
    if not vanilla or not DanTraits_Creation then return end
    for _, list in ipairs({ panel.goodList, panel.badList }) do
        for i = #list.items, 1, -1 do
            local trait = list.items[i].item
            if trait and not chosen(vanilla, trait) and DanTraits_Creation.hides(vanilla, trait) then
                list:removeItemByIndex(i)
            end
        end
    end
    if DanTraits_Creation.ageOff() or not DanTraitsRegistry or not DanTraitsRegistry.age30s then return end
    local def = CharacterTraitDefinition.getCharacterTraitDefinition(DanTraitsRegistry.age30s)
    if not def or def:isFree() or def:getCost() ~= 0 then return end
    for _, row in pairs(panel.goodList.items) do
        if row.item == def then return end
    end
    if chosen(vanilla, def) or vanilla:isTraitEnabled(def) then
        local row = panel.goodList:insertItem(1, def:getLabel(), def)
        row.tooltip = def:getDescription()
    end
end

local function gateOn()
    local vanilla = screen()
    return vanilla ~= nil and DanTraits_Creation ~= nil and DanTraits_Creation.gateOn(vanilla)
end

local function install()
    if installed then return end
    local panel = type(TIYL) == "table" and TIYL.TraitSelect
    if type(panel) ~= "table" or type(panel.populate) ~= "function" then return end
    installed = true
    DanTraits_Wrap(panel, "populate", "tiyl-age", function(original, self, ...)
        local result = original(self, ...)
        pcall(fixLists, self)
        pcall(setDraws, self)
        return result
    end)
    DanTraits_Wrap(panel, "render", "tiyl-age-gate", function(original, self, ...)
        local result = original(self, ...)
        pcall(function()
            if not gateOn() then return end
            self.continueButton:setEnable(false)
            self.continueButton:setTooltip(getText("UI_DanTraits_PickAgeFirst"))
            local hc = getCore():getBadHighlitedColor()
            local y = self.continueButton:getY() - getTextManager():getFontHeight(UIFont.Medium) - 8
            self:drawTextRight(getText("UI_DanTraits_PickAgeHint"), self.continueButton:getRight(), y,
                hc:getR(), hc:getG(), hc:getB(), 1, UIFont.Medium)
        end)
        return result
    end)
    -- the button is greyed, but a controller's A presses it all the same
    DanTraits_Wrap(panel, "onContinue", "tiyl-age-gate", function(original, self, ...)
        if gateOn() then return end
        return original(self, ...)
    end)
    print("[DanTraits] This Is Your Life found: age support for its trait folder on")
end

install()
Events.OnGameBoot.Add(install)
Events.OnMainMenuEnter.Add(install)
