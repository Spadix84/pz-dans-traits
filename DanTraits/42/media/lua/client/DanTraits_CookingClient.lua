-- Cooking, client side: a dish's tooltip line (DanShared_Tooltip.lua): the
-- meal it makes for this character (Home-cooked, Hearty or Chef's) and what
-- it is mostly, or that a dish still raw would make one once cooked.
require "DanTraits"
require "DanShared_Tooltip"

local GREEN, GREY = { 0.45, 0.85, 0.45 }, { 0.7, 0.7, 0.7 }

local function isFood(item) return DanTraits_Is(item, "Food") end

function DanTraits_CookTooltipLines(player, item)
    if not player or not item or not DanTraits_CookTier or not DanTraits_SandboxOn("CookingEnabled") then return nil end
    if not isFood(item) then return nil end
    local tier = DanTraits_CookTier(player, item)
    if tier > 0 then
        local name = getText("IGUI_DanTraits_CookTier_" .. DanTraits_CookTierKeys[tier])
        local kind = DanTraits_CookMacroOf(item)
        local text = kind and getText("Tooltip_DanTraits_CookMealMacro", name, getText("IGUI_DanTraits_CookMacro_" .. kind))
            or getText("Tooltip_DanTraits_CookMeal", name)
        return { { text, GREEN[1], GREEN[2], GREEN[3] } }
    end
    -- a dish with its ingredients in, still raw
    local raw = false
    pcall(function()
        raw = item:isCookable() and not item:isCooked() and not item:isBurnt()
            and item:haveExtraItems() and item:getExtraItems():size() >= 2
    end)
    if raw then return { { getText("Tooltip_DanTraits_CookRaw"), GREY[1], GREY[2], GREY[3] } } end
    return nil
end

DanShared_Tooltip.add("cooking", 23, DanTraits_CookTooltipLines)
