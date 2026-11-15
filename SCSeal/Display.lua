local addonName, NS = ...
local eventFrame = CreateFrame("Frame")
local tracker, db, frame, iconFrame, icon, barFrame, bar, timer, sealName
local previewUntil, initialized
local fallbackIcon = "Interface\\Icons\\Spell_Holy_RighteousnessAura"

local function say(text)
    print("|cffffe36bSCSeal:|r " .. text)
end

local function inCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function applyLayout()
    local height, width = db.height, db.width
    local fontSize = math.max(10, math.floor(height * 0.42))
    frame:SetSize(height + 2 + width, height)
    iconFrame:SetSize(height, height)
    barFrame:SetSize(width, height)
    timer:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    timer:SetWidth(math.max(52, math.floor(height * 2.1)))
    sealName:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local function render()
    local now = GetTime()
    local left = tracker:Remaining(now)
    local current = tracker.current
    local preview = previewUntil and previewUntil > now
    if not current and not preview and not (tracker.blocked and inCombat()) then
        frame:Hide()
        return
    end
    frame:Show()
    local unknown = not current and not preview
    icon:SetTexture(current and current.icon or fallbackIcon)
    local duration = current and current.duration or 30
    if unknown then
        timer:SetText("?")
        sealName:SetText("Seal unknown")
    else
        local seconds = left or (previewUntil - now)
        local text
        if seconds == math.huge then text = "--"
        elseif seconds >= 60 then text = string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
        else text = string.format("%.1f", seconds) end
        if current and current.estimated then text = text .. "*" end
        timer:SetText(text)
        sealName:SetText(current and current.name or "Seal of Righteousness")
    end

    local ratio
    if unknown then
        ratio = 0
    elseif left == math.huge or duration == 0 then
        ratio = 1
    else
        local seconds = left or (previewUntil - now)
        ratio = math.max(0, math.min(1, seconds / math.max(0.001, duration)))
    end
    bar:SetValue(ratio)
    if unknown then
        bar:SetStatusBarColor(0.28, 0.28, 0.28, 1)
    elseif ratio < 0.20 then
        bar:SetStatusBarColor(0.92, 0.08, 0.06, 1)
    elseif ratio < 0.50 then
        bar:SetStatusBarColor(1.00, 0.78, 0.04, 1)
    else
        bar:SetStatusBarColor(0.10, 0.78, 0.20, 1)
    end
    timer:SetTextColor(1, 1, 1)
end

local function rescan()
    tracker:Scan(inCombat())
    render()
end

local function initialize()
    if initialized then return end
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then eventFrame:UnregisterAllEvents(); return end
    initialized = true
    SCSealDB = type(SCSealDB) == "table" and SCSealDB
        or type(StarclassicsSealTimerDB) == "table" and StarclassicsSealTimerDB or {}
    StarclassicsSealTimerDB = nil
    db = SCSealDB
    local legacySize = type(db.size) == "number" and db.size or nil
    db.height = type(db.height) == "number" and math.max(24, math.min(80, db.height))
        or legacySize and math.max(24, math.min(80, math.floor(legacySize * 0.625))) or 36
    db.width = type(db.width) == "number" and math.max(140, math.min(600, db.width)) or 320
    if (tonumber(db.layoutVersion) or 0) < 3 then
        db.width = math.max(320, db.width)
        db.layoutVersion = 3
    end
    db.x = type(db.x) == "number" and db.x or 0
    db.y = type(db.y) == "number" and db.y or -150
    db.size, db.locked, db.showName = nil, nil, nil
    tracker = NS.Core:New(db)
    frame = CreateFrame("Frame", "SCSealFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
    iconFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = false, edgeSize = 1, insets = {left = 1, right = 1, top = 1, bottom = 1}})
    iconFrame:SetBackdropColor(0.04, 0.04, 0.04, 1)
    iconFrame:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    iconFrame:EnableMouse(false)
    icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    barFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    barFrame:SetPoint("LEFT", iconFrame, "RIGHT", 2, 0)
    barFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = false, edgeSize = 1, insets = {left = 1, right = 1, top = 1, bottom = 1}})
    barFrame:SetBackdropColor(0.025, 0.03, 0.04, 1)
    barFrame:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    barFrame:EnableMouse(false)

    bar = CreateFrame("StatusBar", nil, barFrame)
    bar:SetPoint("TOPLEFT", barFrame, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -1, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:EnableMouse(false)

    timer = bar:CreateFontString(nil, "OVERLAY")
    timer:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    timer:SetJustifyH("RIGHT")
    timer:SetShadowColor(0, 0, 0, 1)
    timer:SetShadowOffset(1, -1)

    sealName = bar:CreateFontString(nil, "OVERLAY")
    sealName:SetPoint("LEFT", bar, "LEFT", 6, 0)
    sealName:SetPoint("RIGHT", timer, "LEFT", -8, 0)
    sealName:SetJustifyH("LEFT")
    sealName:SetWordWrap(false)
    sealName:SetTextColor(1, 0.96, 0.82)
    sealName:SetShadowColor(0, 0, 0, 1)
    sealName:SetShadowOffset(1, -1)

    local function beginMove(self)
        if self.dragging or not (IsShiftKeyDown and IsShiftKeyDown()) then return end
        self.dragging = true
        self:StartMoving()
    end
    local function finishMove(self)
        if not self.dragging then return end
        self.dragging = nil
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        db.x, db.y = x - ux, y - uy
    end
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then beginMove(self) end
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then finishMove(self) end
    end)
    frame:SetScript("OnDragStart", beginMove)
    frame:SetScript("OnDragStop", finishMove)
    applyLayout()
    SlashCmdList.SCSEAL = function(message)
        local command, value = message:lower():match("^%s*(%S*)%s*(.-)%s*$")
        if command == "size" then
            local n = tonumber(value)
            if not n or n < 24 or n > 80 then say("Use /scseal size 24-80"); return end
            db.height = n; applyLayout()
        elseif command == "width" then
            local n = tonumber(value)
            if not n or n < 140 or n > 600 then say("Use /scseal width 140-600"); return end
            db.width = n; applyLayout()
        elseif command == "test" then previewUntil = GetTime() + 30
        elseif command == "reset" then db.height, db.width, db.x, db.y = 36, 320, 0, -150; applyLayout()
        else say("Shift + left-drag to move | /scseal size 36 | width 320 | test | reset"); return end
        render()
    end
    SLASH_SCSEAL1 = "/scseal"
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "SPELLS_CHANGED"}) do
        eventFrame:RegisterEvent(event)
    end
    local elapsed, pollElapsed = 0, 0
    eventFrame:SetScript("OnUpdate", function(_, dt)
        elapsed, pollElapsed = elapsed + dt, pollElapsed + dt
        if pollElapsed >= 1 then
            pollElapsed = 0
            if not inCombat() then tracker:Scan(false) end
        end
        if elapsed >= 0.05 then elapsed = 0; render() end
    end)
    rescan()
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "ADDON_LOADED" then
        if unit == addonName then initialize() end
        return
    end
    if not initialized then return end
    if event == "UNIT_AURA" then
        if NS.Public(unit) and unit == "player" then rescan() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if NS.Public(unit) and unit == "player" and tracker:Cast(spellID, GetTime()) then
            render()
            if C_Timer and C_Timer.After then C_Timer.After(0.15, rescan) end
        end
    elseif event == "PLAYER_DEAD" then tracker:Clear(); render()
    elseif event == "SPELLS_CHANGED" then tracker:RefreshNames(); rescan()
    else rescan() end
end)
