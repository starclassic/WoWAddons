-- SCSeal: native aura widgets draw the stack-dependent reminder.
-- Never inspect, compare, or estimate secret combat stack counts.
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end

local seals = {
    Command = { ranks = {20375, 20915, 20918, 20919, 20920}, echo = 1311703,
        other = "Righteousness", icon = "Interface\\Icons\\Ability_Warrior_InnerRage" },
    Righteousness = { ranks = {20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293},
        echo = 1311704, other = "Command", icon = "Interface\\Icons\\Ability_ThunderBolt" },
}
local byID = {}
for key, seal in pairs(seals) do
    for _, id in ipairs(seal.ranks) do byID[id] = key end
end
-- Other seal casts must also dismiss a previous Command/Righteousness prompt.
for _, id in ipairs({20164, 20165, 20347, 20348, 20349, 20166, 20356, 20357,
    21082, 20162, 20305, 20306, 20307, 20308, 1311649, 1311656,
    20163, 20419, 20421, 20422, 20423}) do byID[id] = "Other" end

local db, root, preview, previewText, active, missingSince
local durationEntry, previewCooldown, previewCount
local entries, status, pending = {}, "not initialized", false
local positioning, moving = false, false
local events = CreateFrame("Frame")
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function combat() return InCombatLockdown() end
local function say(message) print("|cffffd45cSCSeal:|r " .. message) end
local function clamp(value, low, high, fallback)
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.max(low, math.min(high, value))
end

local function spellInfo(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info and public(info.name) and public(info.iconID) then return info.name, info.iconID end
    end
end

local function known(id)
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook and bank ~= nil then
        local ok, value = pcall(C_SpellBook.IsSpellInSpellBook, id, bank, false)
        if ok and public(value) then return value == true end
    end
    if IsPlayerSpell then
        local ok, value = pcall(IsPlayerSpell, id)
        if ok and public(value) then return value == true end
    end
    if IsSpellKnown then
        local ok, value = pcall(IsSpellKnown, id)
        if ok and public(value) then return value == true end
    end
    return false
end

local function pairKnown()
    for _, seal in pairs(seals) do
        local found = false
        for _, id in ipairs(seal.ranks) do if known(id) then found = true; break end end
        if not found then return false end
    end
    return true
end

local function prompt(key)
    local seal = seals[key]
    local _, icon = spellInfo(seal.ranks[1])
    return "|T" .. tostring(icon or seal.icon) .. ":64:64|t\n|cffffd45cSwitch|r"
end

local function addGlow(parent, nativeButton)
    -- Outer halo surrounds the icon, outside its thin duration border.
    local glow = CreateFrame("StatusBar", nil, parent)
    glow:SetPoint("CENTER", parent, "CENTER", 0, 0)
    glow:SetSize(144, 144)
    glow:EnableMouse(false)
    glow:SetStatusBarTexture("Interface\\AddOns\\SCSeal\\Glow.tga")
    glow:SetStatusBarColor(1, 1, 1, 1)
    glow:GetStatusBarTexture():SetBlendMode("ADD")
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.8)
    fade:SetToAlpha(1)
    fade:SetDuration(0.45)
    pulse:Play()
    if nativeButton then
        -- Blizzard reveals the border only at 3 stacks, like the icon text.
        -- No Lua comparisons of restricted stack counts are involved.
        nativeButton:SetApplicationBar(glow, {minApplications = 2, maxApplications = 3})
    else
        glow:SetMinMaxValues(0, 1)
        glow:SetValue(1)
    end
end

local function visibility()
    if not db then return end
    -- These wrappers belong to us. Blizzard owns the aura buttons inside them.
    for key, entry in pairs(entries) do
        entry.wrap:SetAlpha(db.enabled and not db.preview and not positioning and not moving
            and db.pairKnown and key == active and 1 or 0)
    end
    if durationEntry then
        durationEntry.wrap:SetAlpha(db.enabled and not db.preview and not positioning and not moving and 1 or 0)
    end
    if preview then
        preview:SetShown(positioning or moving or db.preview)
        previewText:SetText(prompt(db.previewSeal or "Righteousness"))
    end
end

local function updateMovement()
    local wasPositioning = positioning
    positioning = not combat() and db.enabled and IsControlKeyDown() or false
    root:EnableMouse(positioning or moving)
    if positioning and not wasPositioning and previewCooldown then previewCooldown:SetCooldown(GetTime() - 12, 30) end
    visibility()
end

local function finishMoving(self)
    self:StopMovingOrSizing()
    if moving then
        local point, _, _, x, y = self:GetPoint(1)
        db.point, db.x, db.y = point, x, y
    end
    moving = false
    updateMovement()
end

local function scan()
    if combat() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, hidden = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or not public(hidden) or hidden then return end
    end
    for i = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not public(aura) then return end
        if aura == nil then break end
        if issecrettable and issecrettable(aura) then return end
        local id = aura.spellId
        if not public(id) then return end
        if byID[id] then
            active, missingSince = byID[id], nil
            visibility()
            return
        end
    end
    -- Around combat entry the client may briefly return an empty aura list.
    missingSince = missingSince or GetTime()
    if GetTime() - missingSince >= 1 then active = nil; visibility() end
end


-- Native seal duration stays attached to the active seal, independently of
-- which next-seal image the Echo formatter displays above its icon.
local function makeCountdown(parent)
    local cd = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
    cd:SetAllPoints(root)
    cd:SetFrameLevel(root:GetFrameLevel() + 7)
    cd:EnableMouse(false)
    cd:SetReverse(false)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetHideCountdownNumbers(true)
    cd:SetUseCircularEdge(false)
    cd:SetSwipeTexture("Interface\\AddOns\\SCSeal\\DurationBorder.tga")
    cd:SetSwipeColor(1, 0.86, 0.4, 1)
    return cd
end

local function prepareButton(button, level)
    button:EnableMouse(false)
    button:ClearAllPoints()
    button:SetAllPoints(root)
    button:SetFrameLevel(root:GetFrameLevel() + level)
end

local function initializeSeal(button)
    prepareButton(button, 1)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", root, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    button:SetIcon(icon)
    local track = button:CreateTexture(nil, "OVERLAY")
    track:SetAllPoints(root)
    track:SetTexture("Interface\\AddOns\\SCSeal\\DurationBorder.tga")
    track:SetVertexColor(0.18, 0.16, 0.1, 1)
    local cd = makeCountdown(button)
    button:SetDurationCooldown(cd)
    -- Some client builds restyle the cooldown as they bind it.
    cd:SetDrawSwipe(true)
    cd:SetUseCircularEdge(false)
    cd:SetSwipeTexture("Interface\\AddOns\\SCSeal\\DurationBorder.tga")
    cd:SetSwipeColor(1, 0.86, 0.4, 1)
end

local function initializeCount(button)
    prepareButton(button, 9)
    local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -5, 4)
    count:SetTextColor(1, 1, 1)
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:SetBreakpoints({
        {threshold = 0, format = ""}, {threshold = 1, format = "1"},
        {threshold = 2, format = "2"}, {threshold = 3, format = "3"},
    })
    button:SetApplicationCount(count, {formatter = formatter})
end

local function newContainer(parent, slot, ids, initializeFrame)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetAllPoints(root)
    wrap:EnableMouse(false)
    local c = CreateFrame("AuraContainer", nil, wrap, "CustomAuraContainerTemplate")
    c:SetEnabled(false)
    c:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
    c:SetPoint("TOPLEFT", root, "TOPLEFT")
    c:SetUnit("player")
    local ok, err = pcall(function()
        c:AddAuraSlot(slot, "HELPFUL", {candidateFilters = {includeSpellIDs = ids}, initializeFrame = initializeFrame})
        c:SetAuraSlotEnabled(slot, true)
        c:SetEnabled(true)
    end)
    if not ok then c:SetEnabled(false); wrap:SetAlpha(0); error(err) end
    return {wrap = wrap, container = c}
end

local function build()
    if combat() then pending = true; return end
    pending = false
    if durationEntry then
        durationEntry.wrap:SetAlpha(0)
        pcall(durationEntry.container.SetEnabled, durationEntry.container, false)
        durationEntry = nil
    end
    for _, entry in pairs(entries) do
        entry.wrap:SetAlpha(0)
        pcall(entry.container.SetEnabled, entry.container, false)
        if entry.countEntry then pcall(entry.countEntry.container.SetEnabled, entry.countEntry.container, false) end
    end
    entries = {}
    db.pairKnown = pairKnown()
    if not (C_AuraContainerUtil and CustomAuraContainerAuraProcessingPolicy
        and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then
        status = "This client lacks the native aura/formatter API. No combat estimates are used."
        say(status)
        return
    end
    local ok, err = pcall(function()
        local sealIDs = {}
        for id in pairs(byID) do sealIDs[id] = true end
        durationEntry = newContainer(root, "Seal", sealIDs, initializeSeal)
        for key, seal in pairs(seals) do
            local wrap = CreateFrame("Frame", nil, root)
            wrap:SetAllPoints(root)
            wrap:EnableMouse(false)
            wrap:SetAlpha(0)
            local container = CreateFrame("AuraContainer", nil, wrap, "CustomAuraContainerTemplate")
            -- Retain immediately so a partially built display can be disabled.
            entries[key] = {wrap = wrap, container = container}
            container:SetEnabled(false)
            container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
            container:SetPoint("TOPLEFT", wrap, "TOPLEFT")
            container:SetUnit("player")
            local text = prompt(seal.other)
            container:AddAuraSlot("Echo", "HELPFUL", {
                candidateFilters = {includeSpellIDs = {[seal.echo] = true}},
                initializeFrame = function(button)
                    -- Initialization is the only time we modify this native button.
                    button:EnableMouse(false)
                    button:ClearAllPoints()
                    button:SetAllPoints(wrap)
                    button:SetFrameLevel(root:GetFrameLevel() + 4)
                    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
                    label:SetPoint("CENTER", button, "CENTER", 0, -7)
                    label:SetJustifyH("CENTER")
                    label:SetTextColor(1, 1, 1)
                    local formatter = C_StringUtil.CreateNumericRuleFormatter()
                    formatter:SetBreakpoints({{threshold = 0, format = ""}, {threshold = 3, format = text}})
                    -- Blizzard chooses the text. Lua never receives a stack number.
                    button:SetApplicationCount(label, {formatter = formatter})
                    addGlow(button, button)
                end,
            })
            container:SetAuraSlotEnabled("Echo", true)
            container:SetEnabled(true)
            -- A separate native slot owns the count; binding it must not replace
            -- the formatter that shows the next-seal icon at three stacks.
            entries[key].countEntry = newContainer(wrap, "Count", {[seal.echo] = true}, initializeCount)
        end
    end)
    if not ok then
        if durationEntry then
            durationEntry.wrap:SetAlpha(0)
            pcall(durationEntry.container.SetEnabled, durationEntry.container, false)
            durationEntry = nil
        end
        for _, entry in pairs(entries) do
            entry.wrap:SetAlpha(0)
            pcall(entry.container.SetEnabled, entry.container, false)
        if entry.countEntry then pcall(entry.countEntry.container.SetEnabled, entry.countEntry.container, false) end
        end
        entries = {}
        status = "Native display could not initialize: " .. tostring(err)
        say(status)
    else
        status = "native display ready"
    end
    visibility()
end

local function layout()
    root:ClearAllPoints()
    root:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    root:SetScale(db.size / 64)
    updateMovement()
end

local function initialize()
    SCSealDB = type(SCSealDB) == "table" and SCSealDB
        or type(StarclassicsSealTimerDB) == "table" and StarclassicsSealTimerDB or {}
    StarclassicsSealTimerDB = nil
    db = SCSealDB
    db.size = clamp(db.size, 32, 128, 64)
    db.x, db.y = clamp(db.x, -10000, 10000, 0), clamp(db.y, -10000, 10000, -140)
    local points = {CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true,
        TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true}
    if not points[db.point or ""] then db.point = "CENTER" end
    db.enabled = db.enabled ~= false
    db.unlocked, db.preview = nil, false
    db.previewSeal = "Righteousness"
    root = CreateFrame("Frame", "SCSealFrame", UIParent)
    root:SetSize(64, 64)
    root:SetFrameLevel(20)
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self)
        if db.enabled and IsControlKeyDown() and not combat() then
            moving = true
            self:StartMoving()
            visibility()
        end
    end)
    root:SetScript("OnDragStop", finishMoving)
    preview = CreateFrame("Frame", nil, root)
    preview:SetAllPoints(root)
    preview:EnableMouse(false)
    previewText = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    previewText:SetPoint("CENTER", preview, "CENTER", 0, -7)
    previewCooldown = makeCountdown(preview)
    previewCooldown:SetCooldown(GetTime() - 12, 30)
    previewCount = previewCooldown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewCount:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    previewCount:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -5, 4)
    previewCount:SetText("3")
    previewCount:SetTextColor(1, 1, 1)
    addGlow(preview)
    layout()
    build()
    scan()
    say("loaded. Ctrl + left-drag to move; /scseal test to preview.")
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("MODIFIER_STATE_CHANGED")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then initialize(); return end
    if not db then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Exact learned spell IDs reject Seal of Command damage procs (20424).
        if public(spellID) and byID[spellID] and known(spellID) then
            active, missingSince = byID[spellID], nil
            visibility()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        db.preview = false
        finishMoving(root)
    elseif event == "MODIFIER_STATE_CHANGED" then
        updateMovement()
    elseif event == "SPELLS_CHANGED" then
        build()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then build() end
        updateMovement()
        scan()
    elseif event == "PLAYER_ENTERING_WORLD" then
        active, missingSince = nil, nil
        visibility()
        scan()
    end
end)
local elapsedScan = 0
events:SetScript("OnUpdate", function(_, elapsed)
    elapsedScan = elapsedScan + elapsed
    if elapsedScan < 0.25 then return end
    elapsedScan = 0
    if db then scan() end
end)

SLASH_SCSEAL1 = "/scseal"
SLASH_SCSEAL2 = "/uwbox"
SlashCmdList.SCSEAL = function(message)
    if not db then return end
    local command, argument = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "debug" then
        say(status .. "; active seal=" .. tostring(active) .. "; both seals learned=" .. tostring(db.pairKnown))
        say("Echo IDs: Command=1311703, Righteousness=1311704. Stack counts are drawn by Blizzard.")
        return
    end
    if combat() then say("Change settings after combat."); return end
    if command == "test" then
        db.preview = not db.preview
        db.previewSeal = argument == "command" and "Command" or "Righteousness"
        if db.preview then previewCooldown:SetCooldown(GetTime() - 12, 30) end
        say(db.preview and "Preview on. /scseal test again to stop." or "Preview off.")
    elseif command == "size" then
        local size = tonumber(argument)
        if not size or size < 32 or size > 128 then say("Use /scseal size 32 through 128."); return end
        db.size = size
    elseif command == "on" or command == "off" then
        db.enabled = command == "on"
        db.preview = false
        say(db.enabled and "Reminder enabled." or "Reminder disabled.")
    elseif command == "reset" then
        db.point, db.x, db.y, db.size = "CENTER", 0, -140, 64
        db.preview = false
    else
        say("Hold Ctrl + left-drag to move. /scseal test [command] | size 64 | on | off | reset | debug")
        return
    end
    layout()
end
