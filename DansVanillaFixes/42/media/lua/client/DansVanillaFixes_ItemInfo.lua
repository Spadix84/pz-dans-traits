-- Dan's Vanilla Fixes: more in an item's tooltip, in the strip
-- DanShared_Tooltip.lua draws under vanilla's. Sandbox page Dan's
-- Vanilla Fixes: Item Info (ItemInfoTooltips turns it all off).
--
--   read time   skill books and the novels, comics and magazines the reading
--               overhaul handles: the game time left to finish, from the
--               read action's own duration, so Fast and Slow Reader, glasses,
--               sitting and every mod's speed-up or slow-down count. Nothing
--               for a skill book above your level + 1 (vanilla will not let
--               you read it), illiterate, or one already read through.
--   uses left   drainables: "Uses left: 7 of 20"; batteries and anything that
--               runs on one as a charge in percent.
--   weapons     the skill it trains and your level, then the numbers that
--               skill lets you judge (ItemInfoWeaponSkill; off, all of them):
--               melee damage from level 1, critical chance 2, attack speed
--               and reach 3, knockback and endurance per swing 4; firearms by
--               Aiming the same way (damage, critical chance, accuracy, range
--               and noise). Maintenance 1 shows the condition in numbers and
--               Maintenance 2 how often a hit wears it. Vanilla already draws
--               a damage bar and the condition bar.
--   clothing    the body parts it covers, and, for a garment you are not
--               wearing, how its insulation, wind and water resistance and
--               speed modifiers compare with what you wear in that slot (one
--               line each, green better, red worse; vanilla already compares
--               bite, scratch and bullet defence).
require "DanShared_Tooltip"

DVF_ItemInfo = DVF_ItemInfo or {}
local I = DVF_ItemInfo

I.READ_CACHE_MS = 1000     -- a read time is asked of the action at most this often per item
I.PARTS_PER_LINE = 4

local WHITE = { 0.8, 0.8, 0.8 }
local GREY = { 0.6, 0.6, 0.6 }

local function opt(name, default)
    local o = SandboxVars and SandboxVars.DansVanillaFixes
    local v = o and o[name]
    if v == nil then return default end
    return v
end

-- obj:method(...), or nil when the object has no such method or it fails
local function call(obj, method, ...)
    if not obj or type(obj[method]) ~= "function" then return nil end
    local ok, v = pcall(obj[method], obj, ...)
    if ok then return v end
    return nil
end

local function hasTag(item, name)
    local ok, yes = pcall(function() return ItemTag and ItemTag[name] and item:hasTag(ItemTag[name]) end)
    return ok and yes == true
end

local function good() local c = getCore():getGoodHighlitedColor() return { c:getR(), c:getG(), c:getB() } end
local function bad() local c = getCore():getBadHighlitedColor() return { c:getR(), c:getG(), c:getB() } end

local function line(text, colour)
    colour = colour or WHITE
    return { text, colour[1], colour[2], colour[3] }
end

-- 1.25 -> "1.25", 2.0 -> "2"
function I.num(v, decimals)
    local m = 10 ^ (decimals or 1)
    local r = math.floor(v * m + 0.5) / m
    if r == math.floor(r) then return tostring(math.floor(r)) end
    return tostring(r)
end

-- game minutes as "45 min" or "3 h 20 min"
function I.duration(minutes)
    minutes = math.max(1, math.floor(minutes + 0.5))
    if minutes < 60 then return getText("IGUI_DVF_Info_Minutes", minutes) end
    local h, m = math.floor(minutes / 60), minutes % 60
    if m == 0 then return getText("IGUI_DVF_Info_Hours", h) end
    return getText("IGUI_DVF_Info_HoursMinutes", h, m)
end

-- read time --------------------------------------------------------------------------

local cache = {}

local function skillBookOf(item)
    local ok, sb = pcall(function() return SkillBook and SkillBook[item:getSkillTrained()] end)
    return ok and sb or nil
end

-- the game minutes left to finish this book, or nil when there is nothing to say
function I.readMinutes(player, item)
    if not instanceof(item, "Literature") then return nil end
    local sb = skillBookOf(item)
    local R = DanTraits_Reading
    local ours = not sb and R and R.info and R.info(item)
    if not sb and not ours then return nil end
    if player:hasTrait(CharacterTrait.ILLITERATE) then return nil end
    local pages, read = 0, 0
    if sb then
        pages = item:getNumberOfPages() or 0
        if pages <= 0 then return nil end
        if (item:getLvlSkillTrained() or 0) > player:getPerkLevel(sb.perk) + 1 then return nil end
        read = player:getAlreadyReadPages(item:getFullType()) or 0
        if read >= pages then return nil end
    end
    local t = ISReadABook:new(player, item):getDuration()
    if type(t) ~= "number" or t <= 1 then return nil end
    local minutes = t / getGameTime():getMinutesPerDay() / 2   -- the action's units, as vanilla builds them
    if sb then minutes = minutes * (pages - read) / pages end  -- vanilla's time is the whole book
    return minutes
end

function I.readLine(player, item)
    local key
    pcall(function() key = item:getID() end)
    local now = getTimestampMs()
    local c = key and cache[key]
    if c and now - c.at < I.READ_CACHE_MS and c.player == player then return c.lines end
    local ok, minutes = pcall(I.readMinutes, player, item)
    local lines = nil
    if ok and minutes then lines = { line(getText("IGUI_DVF_Info_ReadLeft", I.duration(minutes))) } end
    if key then cache[key] = { at = now, player = player, lines = lines } end
    return lines
end

-- uses left --------------------------------------------------------------------------

local function battery(item)
    return item:getFullType() == "Base.Battery" or hasTag(item, "FLASHLIGHT") or hasTag(item, "USES_BATTERY")
end

function I.usesLines(player, item)
    if not instanceof(item, "DrainableComboItem") then return nil end
    if battery(item) then
        local f = call(item, "getCurrentUsesFloat")
        if not f then return nil end
        return { line(getText("IGUI_DVF_Info_Charge", math.floor(f * 100 + 0.5) .. "%")) }
    end
    local uses, max = call(item, "getCurrentUses"), call(item, "getMaxUses")
    if not uses or not max or max <= 0 then return nil end
    return { line(getText("IGUI_DVF_Info_UsesLeft", uses, max)) }
end

-- weapons ----------------------------------------------------------------------------

-- the melee categories and the skill each trains, in vanilla's XP order
I.MELEE = {
    { "AXE", "Axe" }, { "BLUNT", "Blunt" }, { "SPEAR", "Spear" },
    { "LONG_BLADE", "LongBlade" }, { "SMALL_BLADE", "SmallBlade" }, { "SMALL_BLUNT", "SmallBlunt" },
}

-- the perk a weapon trains, its name, and whether it is an axe
function I.weaponPerk(item)
    if item:isRanged() then return Perks.Aiming, false end
    local script = item:getScriptItem()
    for _, c in ipairs(I.MELEE) do
        local cat = WeaponCategory and WeaponCategory[c[1]]
        if cat and script and call(script, "containsWeaponCategory", cat) == true then
            return Perks[c[2]], c[1] == "AXE"
        end
    end
    return nil, false
end

-- vanilla's crit chance with the skill (an axe from level 0, the rest from 1)
function I.critChance(item, level, isAxe)
    local base = call(item, "getCriticalChance") or 0
    if isAxe then return base + 3 * level end
    return base + 3 * math.max(level - 1, 0)
end

-- one in how many hits wears the weapon (vanilla's maintenance mod)
function I.wearOneIn(item, maintenance, level)
    local chance = call(item, "getConditionLowerChance") or 0
    if chance <= 0 then return nil end
    return chance + math.floor((maintenance + math.floor(level / 2)) / 2) * 2
end

function I.weaponLines(player, item)
    if not instanceof(item, "HandWeapon") then return nil end
    local perk, isAxe = I.weaponPerk(item)
    if not perk then return nil end
    local level = player:getPerkLevel(perk)
    local judge = opt("ItemInfoWeaponSkill", true) and level or 10
    local lines = {}
    local name = PerkFactory.getPerk(perk):getName()
    lines[#lines + 1] = line(getText("IGUI_DVF_Info_Skill", name, level))
    local function at(need, text)
        if judge >= need then lines[#lines + 1] = line(text) end
    end
    at(1, getText("IGUI_DVF_Info_Damage", I.num(item:getMinDamage(), 1), I.num(item:getMaxDamage(), 1)))
    if item:isRanged() then
        at(2, getText("IGUI_DVF_Info_Crit", I.num(call(item, "getCriticalChance") or 0, 0) .. "%"))
        at(3, getText("IGUI_DVF_Info_Accuracy", I.num(call(item, "getHitChance") or 0, 0) .. "%"))
        at(4, getText("IGUI_DVF_Info_RangeNoise", I.num(call(item, "getMaxRange") or 0, 1), I.num(call(item, "getSoundRadius") or 0, 0)))
    else
        at(2, getText("IGUI_DVF_Info_Crit", I.num(I.critChance(item, level, isAxe), 0) .. "%"))
        at(3, getText("IGUI_DVF_Info_Speed", I.num(call(item, "getBaseSpeed") or 1, 2), I.num(call(item, "getMaxRange") or 0, 2)))
        at(4, getText("IGUI_DVF_Info_Knockback", I.num(call(item, "getPushBackMod") or 0, 2), I.num(call(item, "getEnduranceMod") or 1, 2)))
    end
    local maintenance = opt("ItemInfoWeaponSkill", true) and player:getPerkLevel(Perks.Maintenance) or 10
    if maintenance >= 1 then
        lines[#lines + 1] = line(getText("IGUI_DVF_Info_Condition", item:getCondition(), item:getConditionMax()))
    end
    if maintenance >= 2 and not item:isRanged() then
        local n = I.wearOneIn(item, player:getPerkLevel(Perks.Maintenance), level)
        if n then lines[#lines + 1] = line(getText("IGUI_DVF_Info_Wear", n)) end
    end
    if #lines < 2 and judge < 1 then
        lines[#lines + 1] = line(getText("IGUI_DVF_Info_LearnMore"), GREY)
    end
    return lines
end

-- clothing ---------------------------------------------------------------------------

-- the stats compared, as percentage points; higher is better for all five
-- (the speeds are factors, so they read as a percent)
I.CLOTHING = {
    { "getInsulation", "IGUI_DVF_Info_Insulation" },
    { "getWindresistance", "IGUI_DVF_Info_Wind" },
    { "getWaterResistance", "IGUI_DVF_Info_Water" },
    { "getRunSpeedModifier", "IGUI_DVF_Info_RunSpeed", "%" },
    { "getCombatSpeedModifier", "IGUI_DVF_Info_CombatSpeed", "%" },
}

function I.coverLines(item)
    local parts = call(item, "getCoveredParts")
    if not parts or parts:size() == 0 then return {} end
    local names = {}
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        names[#names + 1] = call(part, "getDisplayName") or tostring(part)
    end
    local lines, chunk = {}, {}
    for i, n in ipairs(names) do
        chunk[#chunk + 1] = n
        if #chunk == I.PARTS_PER_LINE or i == #names then
            local text = table.concat(chunk, ", ")
            lines[#lines + 1] = line(#lines == 0 and getText("IGUI_DVF_Info_Covers", text) or ("  " .. text))
            chunk = {}
        end
    end
    return lines
end

-- what the player wears in this garment's slot, if it is another item
function I.wornInSlot(player, item)
    local loc = call(item, "getBodyLocation")
    if not loc then return nil end
    local worn = call(player, "getWornItem", loc)
    if not worn or worn == item then return nil end
    if instanceof and not instanceof(worn, "Clothing") then return nil end
    return worn
end

function I.compareLines(player, item)
    local worn = I.wornInSlot(player, item)
    if not worn then return {} end
    local lines = {}
    for _, s in ipairs(I.CLOTHING) do
        local a, b = call(item, s[1]), call(worn, s[1])
        if type(a) == "number" and type(b) == "number" then
            local diff = math.floor((a - b) * 100 + 0.5)
            if diff ~= 0 then
                local text = getText(s[2], (diff > 0 and "+" or "") .. tostring(diff) .. (s[3] or ""))
                lines[#lines + 1] = line(text, diff > 0 and good() or bad())
            end
        end
    end
    if #lines > 0 then
        table.insert(lines, 1, line(getText("IGUI_DVF_Info_Versus", worn:getDisplayName())))
    end
    return lines
end

function I.clothingLines(player, item)
    if not instanceof(item, "Clothing") then return nil end
    local lines = I.coverLines(item)
    for _, l in ipairs(I.compareLines(player, item)) do lines[#lines + 1] = l end
    return lines
end

-- the source -------------------------------------------------------------------------

function I.lines(player, item)
    if not opt("ItemInfoTooltips", true) then return nil end
    local lines = {}
    for _, fn in ipairs({ I.readLine, I.usesLines, I.weaponLines, I.clothingLines }) do
        local ok, more = pcall(fn, player, item)
        if ok and type(more) == "table" then
            for _, l in ipairs(more) do lines[#lines + 1] = l end
        end
    end
    return #lines > 0 and lines or nil
end

DanShared_Tooltip.add("iteminfo", 25, I.lines)
