-- The generator's info window: show slow cookers at their own draw, and the total
-- that goes with it. The fuel itself is handled in shared/SlowCooker_Power.lua;
-- this only fixes what the window says (in multiplayer the client's copy of the
-- generator recalculates without the correction).
require "ISUI/ISGeneratorInfoWindow"
require "SlowCooker_Power"

-- Where needle first appears in s at or after init, as plain text (no patterns).
local function findPlain(s, needle, init)
    for i = init or 1, #s - #needle + 1 do
        if string.sub(s, i, i + #needle - 1) == needle then return i end
    end
    return nil
end

-- "0.0200" -> "0.02", in the style of the number the game printed (".09" or "0,09").
local function formatLike(value, original)
    local s = string.format("%.4f", value)
    s = string.gsub(s, "0+$", "")
    s = string.gsub(s, "%.$", "")
    if findPlain(original, ",") then s = string.gsub(s, "%.", ",") end
    if string.match(original, "^[%.,]") and string.match(s, "^0[%.,]") then s = string.sub(s, 2) end
    return s
end

local getRichText = ISGeneratorInfoWindow.getRichText
function ISGeneratorInfoWindow.getRichText(object, displayStats)
    if displayStats and object and object:isActivated() then
        SlowCooker.fixGenerator(object)
    end
    local text = getRichText(object, displayStats)
    local name = displayStats and object and object:isActivated() and SlowCooker.powerName()
    if not name then return text end
    -- The cooker's line: "<name> x<n> (<L/h> L/h)"
    local prefix = name .. " x"
    local start = findPlain(text, prefix)
    if not start then return text end
    local after = start + #prefix
    local n = tonumber(string.match(string.sub(text, after), "^(%d+)"))
    local open = findPlain(text, " (", after)
    local close = findPlain(text, " L/h)", after)
    if not n or not open or not close or close < open then return text end
    local old = string.sub(text, open + 2, close - 1)
    local mult = tonumber(SandboxVars and SandboxVars.GeneratorFuelConsumption) or 1
    local new = formatLike(SlowCooker.POWER_DRAW * n * mult, old)
    return string.sub(text, 1, open + 1) .. new .. string.sub(text, close)
end
