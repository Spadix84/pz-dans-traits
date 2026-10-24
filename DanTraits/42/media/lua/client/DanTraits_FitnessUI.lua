-- Project Zomboid Vitality Project: fitness, the window (plans/fitness-overhaul.md).
--
-- The game's fitness window (ISFitnessUI), with:
--   - the hidden exercises (jogging, carrying, hard work) left out of the list
--   - improvised weights named for the heaviest stand-in carried ("Log
--     Curls", "Red Paint Overhead Press"), or greyed out, and that stand-in
--     equipped on OK
--   - Stretching started as our own action (allowed sat on the ground, tired
--     or in pain), stopped by Cancel like the others
--   - OK refused for an exercise that works a pulled muscle
--   - the time box is a rep count (its label is "Reps": IGUI_FitnessTime is
--     overridden in our IG_UI.json); stretching reads it as minutes
--   - the exercise's tooltip says what it works and the experience now
--   - one child panel (DanTraitsFitnessSection) with the four muscle groups,
--     the plan drop-down and today's target, the diet goal (Cooking: Bulk or
--     Cut), the last seven days and the bonuses running (a meal's among them)
-- and "Work Out" on a weight bench or treadmill, which opens it.
--
-- The section is a self-drawing child, not drawing in the window's render:
-- UI mods replace the window (Neat Rocco's NR_FitnessPanel derives from
-- ISFitnessUI, overrides render, and stacks any child it does not know at
-- the bottom, growing the window to fit), and a child survives that. With
-- the vanilla window it goes under the time box and the window grows.
-- Names: Neat Rocco lists exercises by exeData.name, so the improvised ones
-- get their name set on the definition when the list is built.
require "ISUI/ISFitnessUI"
require "ISUI/ISPanel"
require "TimedActions/ISDanTraitsStretchAction"
require "DanTraits_FitnessData"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local LINE = FONT_HGT_SMALL + 2
local PAD = 10
local CELL_GAP = 3
local CELL_H = FONT_HGT_SMALL * 2 + 6
local SECTION_W = 400   -- at least; it widens with the window
local SET_MINUTES = 240  -- the game's clock for a set counted in reps: room enough for 60 slow ones

local STATE_COLOUR = {
    ready      = { 0.35, 0.85, 0.35 },
    rested     = { 0.85, 0.85, 0.85 },
    recovering = { 0.95, 0.85, 0.35 },
    sore       = { 0.95, 0.55, 0.25 },
    overworked = { 0.95, 0.25, 0.25 },
    strained   = { 0.8, 0.2, 0.8 },
}
local GYM_NAMES = { Fitness_Contraption = true, Human_Hamster_Wheel = true }
local REP_TARGETS = { upper = true, lower = true, push = true, pull = true, legs = true }   -- shown in reps

local function fitOn() return DanTraits_SandboxOn("FitnessEnabled") end
local function txt(key, ...) return getText(key, ...) end

-- the groups an exercise works that are pulled right now
local function strainedGroup(player, key)
    local d = DanTraits_Data(player)
    local spec = DanTraits_FitExercise(key)
    if d.ftStrain and spec and (spec.load or {})[d.ftStrain.g] then return d.ftStrain.g end
    return nil
end

local function stretching(player)
    local q = ISTimedActionQueue.getTimedActionQueue(player)
    local a = q and q.queue and q.queue[1]
    return a and a.Type == "ISDanTraitsStretchAction" and a or nil
end

-- an improvised exercise's name for the stand-in carried (or "Heavy Object")
local NAME_KEYS = { dtimprovcurl = "IGUI_DanTraits_FitImprovCurl", dtonearmcurl = "IGUI_DanTraits_FitOneArmCurl", dtpress = "IGUI_DanTraits_FitPress" }
local function improvisedName(key, pick)
    local what = pick and getItemDisplayName(pick) or txt("IGUI_DanTraits_FitHeavyObject")
    return txt(NAME_KEYS[key] or "IGUI_DanTraits_FitImprovCurl", what)
end

-- the section ------------------------------------------------------------------------------

DanTraitsFitnessSection = ISPanel:derive("DanTraitsFitnessSection")

function DanTraitsFitnessSection.sectionHeight()
    return LINE * 2 + 6               -- the muscles, two to a line
        + BUTTON_HGT + 4              -- the plan
        + LINE * 2 + 4                -- today, and on or off the plan
        + LINE + CELL_H + 6           -- the last seven days
        + LINE * 3                    -- what is running, the magazines, the hint
end

function DanTraitsFitnessSection:new(x, y, width, player)
    local o = ISPanel.new(self, x, y, math.max(width, SECTION_W), DanTraitsFitnessSection.sectionHeight())
    o.player = player
    o.background = false
    o.border = false
    return o
end

function DanTraitsFitnessSection:createChildren()
    ISPanel.createChildren(self)
    local labelW = getTextManager():MeasureStringX(UIFont.Small, txt("IGUI_DanTraits_FitPlan")) + 8
    self.planY = LINE * 2 + 6
    self.combo = ISComboBox:new(labelW, self.planY, 170, BUTTON_HGT, self, DanTraitsFitnessSection.onPlan)
    self.combo:initialise()
    self:addChild(self.combo)
    self:fillPlans()
    -- the diet goal (Cooking), on the plan's line
    if DanTraits_CookSetDiet then
        self.dietLabelX = self.combo:getRight() + 12
        local dietX = self.dietLabelX + getTextManager():MeasureStringX(UIFont.Small, txt("IGUI_DanTraits_CookDiet")) + 8
        self.diet = ISComboBox:new(dietX, self.planY, 100, BUTTON_HGT, self, DanTraitsFitnessSection.onDiet)
        self.diet:initialise()
        self:addChild(self.diet)
        local d = DanTraits_Data(self.player)
        for i, id in ipairs({ "", "bulk", "cut" }) do
            local key = id == "" and "none" or id
            self.diet:addOptionWithData(txt("IGUI_DanTraits_CookDiet_" .. key), id, txt("Tooltip_DanTraits_CookDiet_" .. key))
            if (d.ckDiet or "") == id then self.diet.selected = i end
        end
    end
end

function DanTraitsFitnessSection:onDiet(combo)
    DanTraits_CookSetDiet(self.player, combo:getOptionData(combo.selected))
end

function DanTraitsFitnessSection:fillPlans()
    local combo = self.combo
    combo:clear()
    combo:addOptionWithData(txt("IGUI_DanTraits_FitPlan_none"), "")
    local d = DanTraits_Data(self.player)
    local selected = 1
    for _, plan in ipairs(DanTraits_FIT_PLANS) do
        if DanTraits_FitKnowsPlan(self.player, plan) then
            combo:addOptionWithData(txt("IGUI_DanTraits_FitPlan_" .. plan.id), plan.id)
            if d.ftPlan == plan.id then selected = #combo.options end
        end
    end
    combo.selected = selected
    self.knownPlans = #combo.options - 1
end

function DanTraitsFitnessSection:onPlan(combo)
    DanTraits_FitSetPlan(self.player, combo:getOptionData(combo.selected))
end

function DanTraitsFitnessSection:prerender()
    -- as wide as the window allows
    local parent = self.parent
    if parent then
        local w = math.max(SECTION_W, parent:getWidth() - self:getX() * 2)
        if w ~= self:getWidth() then self:setWidth(w) end
    end
    ISPanel.prerender(self)
end

local function draw(self, text, x, y, c, a)
    self:drawText(text, x, y, c[1], c[2], c[3], a or 1, UIFont.Small)
    return x + getTextManager():MeasureStringX(UIFont.Small, text)
end

function DanTraitsFitnessSection:render()
    ISPanel.render(self)
    if not fitOn() then return end
    local d = DanTraits_Data(self.player)
    local w = self:getWidth()
    local white, grey = { 1, 1, 1 }, { 0.75, 0.75, 0.75 }

    -- the muscles, two to a line
    local y = 0
    draw(self, txt("IGUI_DanTraits_FitMuscles"), 0, y, white)
    local colX = { getTextManager():MeasureStringX(UIFont.Small, txt("IGUI_DanTraits_FitMuscles")) + 10, 0 }
    colX[2] = colX[1] + math.floor((w - colX[1]) / 2)
    for i, g in ipairs(DanTraits_FIT_GROUPS) do
        local state = DanTraits_FitGroupState(self.player, d, g)
        local x = colX[((i - 1) % 2) + 1]
        local gy = y + math.floor((i - 1) / 2) * LINE
        x = draw(self, txt("IGUI_DanTraits_FitGroup_" .. g) .. ": ", x, gy, grey)
        draw(self, txt("IGUI_DanTraits_FitState_" .. state), x, gy, STATE_COLOUR[state] or white)
    end
    y = self.planY

    -- the plan and today's target
    draw(self, txt("IGUI_DanTraits_FitPlan"), 0, y + (BUTTON_HGT - FONT_HGT_SMALL) / 2, white)
    if self.diet then
        local cookOn = DanTraits_SandboxOn("CookingEnabled")
        self.diet:setVisible(cookOn)
        if cookOn then draw(self, txt("IGUI_DanTraits_CookDiet"), self.dietLabelX, y + (BUTTON_HGT - FONT_HGT_SMALL) / 2, white) end
    end
    y = y + BUTTON_HGT + 4
    local today = DanTraits_FitDayIndex()
    local target = DanTraits_FitPlanDay(d, today)
    if target then
        local minutes, need, done = DanTraits_FitTargetProgress(DanTraits_FitLog(d, today), target)
        local line
        if target == "rest" then
            line = txt(done and "IGUI_DanTraits_FitTodayRest" or "IGUI_DanTraits_FitTodayRestBroken")
        else
            if REP_TARGETS[target] then
                -- the window's exercises count in reps: two to a minute of effort
                line = txt("IGUI_DanTraits_FitTodayReps", txt("IGUI_DanTraits_FitTarget_" .. target), math.floor(minutes * 2), need * 2)
            else
                line = txt("IGUI_DanTraits_FitToday", txt("IGUI_DanTraits_FitTarget_" .. target), math.floor(minutes), need)
            end
        end
        draw(self, line, 0, y, done and STATE_COLOUR.ready or white)
        -- on or off the plan, and why
        local status, colour
        if d.ftOnPlan then
            status = txt("IGUI_DanTraits_FitOnPlan", math.floor(DanTraits_FitPlanBonus(self.player) * 100 + 0.5))
            colour = STATE_COLOUR.ready
        elseif d.ftMissDay and d.ftBackDay then
            local ago, back = today - d.ftMissDay, d.ftBackDay - today
            status = txt("IGUI_DanTraits_FitOffPlanMissed",
                ago <= 1 and txt("IGUI_DanTraits_FitYesterday") or txt("IGUI_DanTraits_FitDaysAgo", ago),
                back <= 1 and txt("IGUI_DanTraits_FitTomorrow") or txt("IGUI_DanTraits_FitInDays", back))
            colour = STATE_COLOUR.sore
        else
            status = txt("IGUI_DanTraits_FitOffPlanStart")
            colour = grey
        end
        draw(self, status, 0, y + LINE, colour)
    else
        draw(self, txt("IGUI_DanTraits_FitPickPlan"), 0, y, grey)
    end
    y = y + LINE * 2 + 4

    -- the last seven days
    draw(self, txt("IGUI_DanTraits_FitWeek"), 0, y, white)
    y = y + LINE
    local cellW = math.floor((w - CELL_GAP * 6) / 7)
    for i = 0, 6 do
        local day = today - 6 + i
        local log = DanTraits_FitLog(d, day)
        local dayTarget = DanTraits_FitPlanDay(d, day)
        local fill = { 0.2, 0.2, 0.2 }
        if dayTarget and dayTarget ~= "rest" then
            local _, _, done = DanTraits_FitTargetProgress(log, dayTarget)
            if done then fill = { 0.15, 0.5, 0.15 } elseif day < today then fill = { 0.5, 0.15, 0.15 } end
        elseif DanTraits_FitHardMinutes(log) >= DanTraits_FIT_REST_MAX then
            fill = { 0.15, 0.4, 0.15 }
        end
        local cx = i * (cellW + CELL_GAP)
        self:drawRect(cx, y, cellW, CELL_H, 0.9, fill[1], fill[2], fill[3])
        if day == today then
            self:drawRectBorder(cx, y, cellW, CELL_H, 1, 0.95, 0.85, 0.35)
        else
            self:drawRectBorder(cx, y, cellW, CELL_H, 1, 0.4, 0.4, 0.4)
        end
        local label = dayTarget and txt("IGUI_DanTraits_FitTargetShort_" .. dayTarget) or "-"
        self:drawTextCentre(label, cx + cellW / 2, y + 2, 1, 1, 1, 1, UIFont.Small)
        local total = 0
        for _, m in pairs(log) do total = total + (tonumber(m) or 0) end
        self:drawTextCentre(txt("IGUI_DanTraits_FitMinutes", math.floor(total)), cx + cellW / 2, y + 2 + FONT_HGT_SMALL, 0.8, 0.8, 0.8, 1, UIFont.Small)
    end
    y = y + CELL_H + 6

    -- what is running, the magazines, where plans come from
    local status = {}
    if (d.ftPumpMin or 0) > 0 then status[#status + 1] = txt("IGUI_DanTraits_FitPumpedNow") end
    if (d.ftLooseMin or 0) > 0 then status[#status + 1] = txt("IGUI_DanTraits_FitLooseNow") end
    if d.ftOvertrained then status[#status + 1] = txt("IGUI_DanTraits_FitOvertrainedNow") end
    if d.ftBench then status[#status + 1] = txt("IGUI_DanTraits_FitBenchNow") end
    -- a meal (Cooking): Fuelled, and the buff from what it was mostly
    local fuel = DanTraits_CookFuelTier and DanTraits_CookFuelTier(self.player) or 0
    if fuel > 0 then
        status[#status + 1] = txt("IGUI_DanTraits_CookFuelledNow", txt("IGUI_DanTraits_CookTier_" .. DanTraits_CookTierKeys[fuel]))
    end
    for _, kind in ipairs({ "protein", "carbs", "fat" }) do
        if DanTraits_CookMacroK and DanTraits_CookMacroK(self.player, kind) > 0 then
            status[#status + 1] = txt("IGUI_DanTraits_CookBuffNow_" .. kind)
        end
    end
    if #status > 0 then draw(self, table.concat(status, " - "), 0, y, grey) end
    y = y + LINE
    local strength, fitness = DanTraits_FitMagazineBonus(self.player)
    if strength > 0 or fitness > 0 then
        draw(self, txt("IGUI_DanTraits_FitMagazines", math.floor(strength * 100 + 0.5), math.floor(fitness * 100 + 0.5)), 0, y, grey)
    end
    y = y + LINE
    if (self.knownPlans or 0) < #DanTraits_FIT_PLANS then draw(self, txt("IGUI_DanTraits_FitPlanHint"), 0, y, grey, 0.8) end
end

-- the window ------------------------------------------------------------------------------

local function wrapWindow()
    -- the list: hidden ones out, improvised ones named for what is carried
    DanTraits_Wrap(ISFitnessUI, "addExerciseToList", "fitness-list", function(original, self, key, data)
        if not data then return original(self, key, data) end
        if data.dtHidden then return end
        if data.dtItems then
            -- (the shared definition is not written here: in split-screen the other
            -- player's list would rename and re-target it; the pick goes on it at OK)
            local pick = DanTraits_FitPickWeight(self.player, data)
            local text = improvisedName(key, pick)
            if not pick then text = text .. txt("IGUI_DanTraits_FitNeedHeavy") end
            self.exercises:addOption(text, key, nil, pick ~= nil)
            return
        end
        return original(self, key, data)
    end)

    -- the tooltip: what it works, and the experience now
    DanTraits_Wrap(ISFitnessUI, "selectedNewExercise", "fitness-tip", function(original, self, ...)
        local res = original(self, ...)
        if not fitOn() or not self.selectedExe then return res end
        pcall(function()
            local spec = DanTraits_FitExercise(self.selectedExe)
            local d = DanTraits_Data(self.player)
            local parts = {}
            for _, g in ipairs(DanTraits_FIT_GROUPS) do
                if spec and (spec.load or {})[g] then
                    local state = DanTraits_FitGroupState(self.player, d, g)
                    parts[#parts + 1] = txt("IGUI_DanTraits_FitGroup_" .. g) .. " (" .. txt("IGUI_DanTraits_FitState_" .. state) .. ")"
                end
            end
            if #parts > 0 then
                self.tooltipLbl.text = self.tooltipLbl.text .. " <LINE> <LINE> " .. txt("IGUI_DanTraits_FitWorks", table.concat(parts, ", "))
            end
            if spec and not spec.stretch then
                local k = DanTraits_FitTrainingFactor(self.player, d, self.selectedExe)
                self.tooltipLbl.text = self.tooltipLbl.text .. " <LINE> " .. txt("IGUI_DanTraits_FitXpNow", string.format("%.2f", k))
            end
            self.tooltipLbl:paginate()
        end)
        return res
    end)

    -- OK: stretching is ours; an improvised weight takes the heaviest stand-in. Cancel stops stretching too.
    DanTraits_Wrap(ISFitnessUI, "onClick", "fitness-click", function(original, self, button, ...)
        local data = self.exeData
        if button and button.internal == "OK" and data then
            if strainedGroup(self.player, self.selectedExe) then return end
            if data.dtCustom == "stretch" then
                ISTimedActionQueue.add(ISDanTraitsStretchAction:new(self.player, tonumber(self.exeTime:getInternalText()) or 10))
                return
            end
            if data.dtItems then
                local pick = DanTraits_FitPickWeight(self.player, data)
                if not pick then return end
                data.item = pick
            end
            -- a set of so many reps, not minutes: the box's number goes to the
            -- action as its rep count (DanTraits_FitnessActions.lua), and the game's
            -- own clock is given room enough to never be what ends it
            if fitOn() then
                local reps = tonumber(self.exeTime:getInternalText()) or 10
                DanTraits_FitPendingReps[self.player] = { reps = reps, key = self.selectedExe }
                local shown = self.exeTime:getInternalText()
                self.exeTime:setText(tostring(SET_MINUTES))
                local ok, res = pcall(original, self, button, ...)
                self.exeTime:setText(shown)
                if not ok then
                    DanTraits_FitPendingReps[self.player] = nil
                    error(res, 0)
                end
                return res
            end
        elseif button and button.internal == "CANCEL" then
            DanTraits_FitPendingReps[self.player] = nil   -- a set asked for and never started
            local action = stretching(self.player)
            if action then
                pcall(function() action:forceStop() end)
                return
            end
        end
        return original(self, button, ...)
    end)

    -- the buttons: stretching goes where the others cannot; a pulled muscle refuses
    DanTraits_Wrap(ISFitnessUI, "updateButtons", "fitness-buttons", function(original, self, currentAction, ...)
        local res = original(self, currentAction, ...)
        local data = self.exeData
        if not data then return res end
        if data.dtCustom == "stretch" then
            local blocked = self.player:getVehicle() ~= nil or self.player:isClimbing()
            self.ok.enable = not blocked and not stretching(self.player)
            if self.ok.enable then self.ok.tooltip = nil end
        end
        if stretching(self.player) then self.cancel.enable = true end
        local g = fitOn() and strainedGroup(self.player, self.selectedExe)
        if g then
            self.ok.enable = false
            self.ok.tooltip = txt("Tooltip_DanTraits_FitStrained", string.lower(txt("IGUI_DanTraits_FitGroup_" .. g)))
        end
        return res
    end)

    -- the section: a child under the time box (a replacement window restacks it)
    DanTraits_Wrap(ISFitnessUI, "initialise", "fitness-section", function(original, self, ...)
        local res = original(self, ...)
        if not fitOn() or self.dtSection then return res end
        pcall(function()
            local x = self.exercises:getX()
            local y = self.minusBtn:getBottom() + PAD
            local section = DanTraitsFitnessSection:new(x, y, self:getWidth() - x * 2, self.player)
            section:initialise()
            self:addChild(section)
            self.dtSection = section
            self:setHeight(self:getHeight() + section:getHeight() + PAD)
            for _, b in ipairs({ self.ok, self.cancel, self.close }) do
                if b then b:setY(self:getHeight() - BUTTON_HGT - PAD - 1) end
            end
        end)
        return res
    end)
end

wrapWindow()
Events.OnGameStart.Add(wrapWindow)

-- Work Out on a weight bench or treadmill ------------------------------------------------

local function openWindow(player)
    local n = player:getPlayerNum() + 1
    if ISFitnessUI.instance and ISFitnessUI.instance[n] then
        ISFitnessUI.instance[n]:removeFromUIManager()
        ISFitnessUI.instance[n] = nil
    end
    local modal = ISFitnessUI:new(0, 0, 600, 350, player)
    modal:initialise()
    modal:addToUIManager()
    if JoypadState.players[n] then setJoypadFocus(n - 1, modal) end
end

local function gymObject(worldobjects)
    for _, obj in ipairs(worldobjects or {}) do
        local name = nil
        pcall(function()
            local props = obj:getProperties()
            if props and props:has("CustomName") then name = props:get("CustomName") end
        end)
        if name and GYM_NAMES[name] then return obj end
    end
    return nil
end

local function onGymMenu(playerNum, context, worldobjects, test)
    if test or not fitOn() then return end
    local player = getSpecificPlayer(playerNum)
    if not player or not context or not gymObject(worldobjects) then return end
    context:addOption(txt("ContextMenu_DanTraits_FitWorkOut"), player, openWindow)
end
Events.OnFillWorldObjectContextMenu.Add(onGymMenu)
