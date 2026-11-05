-- Clotting powder in the health panel: right-click a bleeding part, "Pack
-- with clotting powder" (DanTraits_Clotting.lua, ISVitalityClotAction).
-- Under a dressing the option is greyed, with the reason: take it off, pack
-- the wound, dress it again.
--
-- The panel's handlers are locals of ISHealthPanel.lua, so the menu is
-- wrapped instead and the option goes on the end of what it built. The menu
-- is the player's one context menu (getPlayerContextMenu; ISContextMenu.get
-- clears and reuses it), read after the original has run. ISContextMenu.get
-- is also caught for the length of the call, as a fallback for a mod that
-- builds its own menu, but it cannot be relied on: Replace Bandage wraps the
-- same method, catches ISContextMenu.get the same way, and its catch calls
-- the getter it saved at load, so a wrap outside its own never sees the
-- call (the powder's option was missing with it loaded, 2026-11-04).
-- Wrapped through DanTraits_Wrap, tag "clot-menu", at load and again on
-- OnGameStart.
require "DanTraits"
require "XpSystem/ISUI/ISHealthPanel"
require "TimedActions/ISVitalityClotAction"

local POWDER = "DanTraits.ClottingPowder"

-- a tin with some left, anywhere on the doctor (bags included)
local function findPowder(doctor)
    local found = nil
    pcall(function()
        local all = doctor:getInventory():getAllTypeRecurse(POWDER)
        for i = 0, all:size() - 1 do
            local item = all:get(i)
            if DanTraits_ItemUses(item) > 0 then found = item return end
        end
    end)
    return found
end

local function onPack(panel, bodyPart, item)
    local doctor = panel.otherPlayer or panel.character
    local patient = panel:getPatient()
    if not doctor or not patient then return end
    ISInventoryPaneContextMenu.transferIfNeeded(doctor, item)
    ISTimedActionQueue.add(ISVitalityClotAction:new(doctor, patient, item, bodyPart))
end

local function addOption(panel, context, bodyPart)
    local doctor = panel.otherPlayer or panel.character
    if not doctor or not DanTraits_ClotCanApply then return false end
    local can, why = DanTraits_ClotCanApply(bodyPart)
    if not can and why ~= "bandaged" then return false end
    local item = findPowder(doctor)
    if not item then return false end
    local option = context:addOption(getText("ContextMenu_DanTraits_PackClot"), panel, onPack, bodyPart, item)
    option.itemForTexture = item
    if not can then
        option.notAvailable = true
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip.description = getText("Tooltip_DanTraits_ClotBandaged")
        option.toolTip = tooltip
    end
    return true
end

local function wrapMenu()
    DanTraits_Wrap(ISHealthPanel, "doBodyPartContextMenu", "clot-menu", function(original, self, bodyPart, x, y, ...)
        local caught = nil
        local get = ISContextMenu.get
        ISContextMenu.get = function(...)
            local context = get(...)
            caught = caught or context
            return context
        end
        local ok, result = pcall(original, self, bodyPart, x, y, ...)
        ISContextMenu.get = get
        if not ok then error(result) end
        if not caught and getPlayerContextMenu then
            pcall(function()
                local who = self.otherPlayer or self.character
                local menu = who and getPlayerContextMenu(who:getPlayerNum())
                -- the one the original just built (ISContextMenu.get writes where
                -- it was asked for), not a stale menu; an empty one is hidden
                if menu and menu.requestX == x + self:getAbsoluteX()
                        and menu.requestY == y + self:getAbsoluteY() then
                    caught = menu
                end
            end)
        end
        if caught and not self.blockingMessage then
            local added = false
            pcall(function() added = addOption(self, caught, bodyPart) end)
            -- an empty menu was hidden; it isn't empty now
            if added and not caught:getIsVisible() then caught:setVisible(true) end
        end
        return result
    end)
end
wrapMenu()
Events.OnGameStart.Add(wrapMenu)
