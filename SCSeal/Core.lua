local addonName, NS = ...
local Core = {}
NS.Core = Core

local function public(value)
    return not (issecretvalue and issecretvalue(value))
end
NS.Public = public

local function spellInfo(id)
    if not public(id) then return end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and public(info) and type(info) == "table" then
            if public(info.name) and type(info.name) == "string" then
                local icon = public(info.iconID) and info.iconID or nil
                return info.name, icon
            end
        end
    end
end
NS.SpellInfo = spellInfo

local function isKnownPlayerSpell(id)
    -- UNIT_SPELLCAST_SUCCEEDED also fires for triggered effects. Seal of
    -- Command's damage proc shares the seal's localized name, but its spell ID
    -- is not a learned spell. Reject that proc before it can restart the timer.
    local function check(checker)
        if type(checker) == "function" then
            local ok, known = pcall(checker, id)
            if ok and public(known) and type(known) == "boolean" then
                return known
            end
        end
        return nil
    end
    local known = check(IsPlayerSpell)
    if known ~= nil then return known end
    known = check(IsSpellKnown)
    if known ~= nil then return known end
    known = check(C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook)
    if known ~= nil then return known end
    -- Preserve compatibility with clients that do not expose a spellbook API.
    return true
end
NS.IsKnownPlayerSpell = isKnownPlayerSpell

local function isKnownPlayerSpell(id)
    -- UNIT_SPELLCAST_SUCCEEDED also fires for triggered effects. Seal of
    -- Command's damage proc shares the seal's localized name, but its spell ID
    -- is not a learned spell. Prefer the spellbook check so that proc cannot
    -- restart the estimated timer while aura data is restricted in combat.
    local checkers = {
        IsPlayerSpell,
        IsSpellKnown,
        C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook,
    }
    for _, checker in ipairs(checkers) do
        if type(checker) == "function" then
            local ok, known = pcall(checker, id)
            if ok and public(known) and type(known) == "boolean" then
                return known
            end
        end
    end
    -- Preserve compatibility with clients that do not expose a spellbook API.
    return true
end
NS.IsKnownPlayerSpell = isKnownPlayerSpell

function Core:New(db)
    local tracker = setmetatable({db = db, names = {}, current = nil, blocked = false}, {__index = self})
    db.durations = type(db.durations) == "table" and db.durations or {}
    tracker:RefreshNames()
    return tracker
end

function Core:RefreshNames()
    -- Resolve familiar base IDs to localized names; name fallback covers new Forever seals.
    for _, id in ipairs({21084, 20154, 20375, 20164, 20165, 20166, 21082, 20162, 31801, 31892, 53720, 53736}) do
        local name = spellInfo(id)
        if name then self.names[name] = true end
    end
end

function Core:IsSeal(name)
    return public(name) and type(name) == "string"
        and (self.names[name] or name:match("^Seal of ") ~= nil)
end

function Core:Cast(id, now)
    if not public(id) or type(id) ~= "number" then return false end
    if not isKnownPlayerSpell(id) then return false end
    if not isKnownPlayerSpell(id) then return false end
    if not isKnownPlayerSpell(id) then return false end
    local name, icon = spellInfo(id)
    if not self:IsSeal(name) then return false end
    local duration = self.db.durations[id] or self.db.durations[name]
    local learned = type(duration) == "number" and duration >= 0
    if not learned then duration = 30 end
    self.current = {name = name, icon = icon, id = id, duration = duration,
        expiration = duration == 0 and 0 or now + duration, estimated = true, defaultDuration = not learned}
    return true
end

function Core:Scan(inCombat)
    -- Never request restricted combat auras. Keep the last public snapshot instead.
    if inCombat then
        self.blocked = true
        if self.current then self.current.estimated = true end
        return false
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or not public(secret) or secret then self.blocked = true; return false end
    end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        self.blocked = true
        return false
    end
    local found
    for index = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
        if not ok or not public(aura) then self.blocked = true; return false end
        if aura == nil then break end
        if type(aura) ~= "table" or (issecrettable and issecrettable(aura)) then
            self.blocked = true; return false
        end
        if not public(aura.name) then self.blocked = true; return false end
        if self:IsSeal(aura.name) then
            local duration, expiration, id, icon = aura.duration, aura.expirationTime, aura.spellId, aura.icon
            if not public(duration) or not public(expiration) or not public(id) or not public(icon) then
                self.blocked = true; return false
            end
            if type(duration) ~= "number" or type(expiration) ~= "number" then
                self.blocked = true; return false
            end
            if duration >= 0 then
                self.db.durations[aura.name] = duration
                if type(id) == "number" then self.db.durations[id] = duration end
            end
            local candidate = {name = aura.name, icon = icon, id = id, duration = duration,
                expiration = expiration, estimated = false}
            if not found or expiration > found.expiration then found = candidate end
        end
    end
    self.current = found
    self.blocked = false
    return true
end

function Core:Remaining(now)
    local current = self.current
    if not current then return nil end
    if current.expiration == 0 then return math.huge end
    local left = current.expiration - now
    if left <= 0 then self.current = nil; return nil end
    return left
end

function Core:Clear()
    self.current = nil
end
