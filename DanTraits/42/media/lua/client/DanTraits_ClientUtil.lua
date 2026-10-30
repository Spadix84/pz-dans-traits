-- Project Zomboid Vitality Project: the client-side one-liners the context
-- menus used to carry their own copy of. Loaded by any client file that
-- needs them (require "DanTraits_ClientUtil"); nothing here touches the game
-- outside a guard.
--
--   DanTraits_GreyOut(option, textKey)    grey a context-menu option out and hang the
--                                         reason (getText(textKey)) under it as a
--                                         tooltip: one of the game's pooled tooltips
--                                         (ISInventoryPaneContextMenu, else
--                                         ISWorldObjectContextMenu) when the game is
--                                         there, else a fresh ISToolTip; the option
--                                         is still greyed when no tooltip can be built
--   DanTraits_ActualItems(items)          the items behind an inventory menu's rows
--                                         (ISInventoryPane.getActualItems: a row can
--                                         stand for a stack), or the list as given

function DanTraits_GreyOut(option, textKey)
    option.notAvailable = true
    pcall(function()
        local tip
        if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.addToolTip then
            tip = ISInventoryPaneContextMenu.addToolTip()
        elseif ISWorldObjectContextMenu and ISWorldObjectContextMenu.addToolTip then
            tip = ISWorldObjectContextMenu.addToolTip()
        else
            tip = ISToolTip:new()
            tip:initialise()
            tip:setVisible(false)
        end
        tip.description = getText(textKey)
        option.toolTip = tip
    end)
end

function DanTraits_ActualItems(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then return ISInventoryPane.getActualItems(items) end
    return items
end
