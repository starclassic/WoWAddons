local addonName = ...
local eventFrame = CreateFrame("Frame")
local db, holder, overlay, dragOverlay, zoneText, coordinatesPanel, coordinatesText, directionText
local buttonLauncher, buttonTray, buttonCountText, emptyButtonsText, buttonKeeper, clockPanel, mailControl
local calendarControl
local rightEdgeDayNightFrames = {}
local initialized, elapsed, scanElapsed = false, 0, 0
local buttonRecords = {}
local unpackPoint = unpack or table.unpack
local HEADER_RIGHT_TEXTURE_INSET = 3
local SQUARE_MASK_TEXTURE = "Interface\\ChatFrame\\ChatFrameBackground"
local COMPASS_DIRECTIONS = {"N", "NW", "W", "SW", "S", "SE", "E", "NE"}

local addonButtonNamePatterns = {
    "^LibDBIcon10_",
    "MinimapButton",
    "MiniMapButton",
}

local persistentAddonButtonNames = {
    "LibDBIcon10_VuhDo",
    "LibDBIcon10_Details",
}

local excludedButtonNames = {
    AddonCompartmentFrame = true,
    ExpansionLandingPageMinimapButton = true,
    GameTimeFrame = true,
    GarrisonLandingPageMinimapButton = true,
    GuildInstanceDifficulty = true,
    MiniMapBattlefieldFrame = true,
    MiniMapChallengeMode = true,
    MiniMapInstanceDifficulty = true,
    MiniMapLFGFrame = true,
    MiniMapMailFrame = true,
    MiniMapTracking = true,
    MiniMapTrackingButton = true,
    MiniMapVoiceChatFrame = true,
    MiniMapWorldMapButton = true,
    MinimapZoneTextButton = true,
    MinimapZoomIn = true,
    MinimapZoomOut = true,
    QueueStatusButton = true,
    TimeManagerClockButton = true,
}

local function public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function say(text)
    print("|cffb8b8b8SCMinimap:|r " .. text)
end

local function updateZone()
    if zoneText then zoneText:SetText("") end
end

local function updateCoordinates()
    if not db or not coordinatesText then return end
    if not db.showCoordinates then
        coordinatesText:SetText("")
        if directionText then directionText:SetText("") end
        if coordinatesPanel then coordinatesPanel:Hide() end
        return
    end
    if coordinatesPanel then coordinatesPanel:Show() end

    if directionText then
        local facing
        if GetPlayerFacing then
            local okFacing, value = pcall(GetPlayerFacing)
            if okFacing and public(value) and type(value) == "number" then facing = value end
        end
        if facing then
            if facing < 0 then facing = facing + (math.pi * 2) end
            local index = (math.floor((facing / (math.pi / 4)) + 0.5) % 8) + 1
            directionText:SetText(COMPASS_DIRECTIONS[index])
        else
            directionText:SetText("--")
        end
    end

    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        coordinatesText:SetText("--, --")
        return
    end
    local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not okMap or not public(mapID) or type(mapID) ~= "number" then
        coordinatesText:SetText("--, --")
        return
    end
    local okPosition, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not okPosition or not public(position) or not position or not position.GetXY then
        coordinatesText:SetText("--, --")
        return
    end
    local okXY, x, y = pcall(position.GetXY, position)
    if not okXY or not public(x) or not public(y) or type(x) ~= "number" or type(y) ~= "number" then
        coordinatesText:SetText("--, --")
        return
    end
    coordinatesText:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
end

local function applyPosition()
    holder:ClearAllPoints()
    if db.positioned then
        holder:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    else
        holder:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
    end
end

local function applyEmphasis()
    if Minimap.SetIconScale then
        pcall(Minimap.SetIconScale, Minimap, db.iconScale)
    end
    -- Forever's indoor/cave terrain renderer turns solid black when the
    -- Minimap frame alpha is below 1. Keep the native renderer fully opaque.
    Minimap:SetAlpha(1)
end

local function hideObject(object)
    if not object then return end
    if object.Hide then object:Hide() end
    if object.SetAlpha then object:SetAlpha(0) end
end

local function suppressObject(object)
    if not object then return end
    hideObject(object)
    if object.HookScript and not object.__scMinimapSuppressed then
        object.__scMinimapSuppressed = true
        object:HookScript("OnShow", function(self) hideObject(self) end)
    end
end

local function showObject(object)
    if not object then return end
    if object.SetAlpha then object:SetAlpha(1) end
    if object.Show then object:Show() end
end

local function hideTextureRegions(frame)
    if not (frame and frame.GetRegions) then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            hideObject(region)
        end
    end
end

local function hideTextureTree(frame, depth)
    if not frame or depth > 5 then return end
    hideTextureRegions(frame)
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            hideTextureTree(child, depth + 1)
        end
    end
end

local function hideNamedArtworkTree(frame, depth)
    if not frame or depth > 5 then return end
    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            if region and region.IsObjectType and region:IsObjectType("Texture") and region.GetTexture then
                local texture = region:GetTexture()
                if type(texture) == "string" then
                    local path = texture:lower()
                    if (path:find("minimap", 1, true)
                        and (path:find("border", 1, true)
                            or path:find("compass", 1, true) or path:find("north", 1, true)))
                        or path:find("daynight", 1, true) or path:find("sun", 1, true) then
                        hideObject(region)
                    end
                end
            end
        end
    end
    if not frame.GetChildren then return end
    for _, child in ipairs({frame:GetChildren()}) do
        local name = child.GetName and child:GetName()
        local lower = type(name) == "string" and name:lower() or ""
        if lower:find("border", 1, true)
            or lower:find("compass", 1, true) or lower:find("northtag", 1, true)
            or lower:find("daynight", 1, true) or lower:find("gametime", 1, true)
            or lower:find("sun", 1, true) or lower:find("moon", 1, true) then
            suppressObject(child)
        else
            hideNamedArtworkTree(child, depth + 1)
        end
    end
end

local function isCalendarArtworkName(value)
    if type(value) ~= "string" then return false end
    local lower = value:lower()
    return lower:find("calendar", 1, true) ~= nil
        or lower:find("daynight", 1, true) ~= nil
        or lower:find("gametime", 1, true) ~= nil
        or lower:find("sun", 1, true) ~= nil
        or lower:find("moon", 1, true) ~= nil
end

local function suppressCalendarArtworkTree(frame, depth)
    if not frame or depth > 6 then return end
    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            local texture = region and region.GetTexture and region:GetTexture()
            local atlas = region and region.GetAtlas and region:GetAtlas()
            if isCalendarArtworkName(texture) or isCalendarArtworkName(atlas) then
                hideObject(region)
            end
        end
    end
    if not frame.GetChildren then return end
    for _, child in ipairs({frame:GetChildren()}) do
        local name = child.GetName and child:GetName()
        if isCalendarArtworkName(name) then
            suppressObject(child)
        else
            suppressCalendarArtworkTree(child, depth + 1)
        end
    end
end

local function hideDefaultArtwork()
    Minimap:SetMaskTexture(SQUARE_MASK_TEXTURE)
    for _, name in ipairs({
        "MinimapBorder", "MinimapBorderTop",
        "MinimapCompassTexture", "MinimapNorthTag", "MinimapNorthTagFrame", "MiniMapNorthTag",
        "MinimapZoomIn", "MinimapZoomOut",
    }) do
        hideObject(_G[name])
    end
    showObject(_G.MinimapBackdrop)

    local container = MinimapCluster and MinimapCluster.MinimapContainer
    for _, parent in ipairs({MinimapCluster, container}) do
        if parent then
            for _, key in ipairs({
                "Border", "BorderFrame", "BorderTop",
                "Compass", "CompassFrame", "CompassTexture", "NorthTag", "NorthTagFrame",
                "MinimapBorder", "MinimapBorderTop",
            }) do
                hideObject(parent[key])
            end
        end
    end
    hideNamedArtworkTree(MinimapCluster, 1)
    suppressCalendarArtworkTree(MinimapCluster, 1)
end

local function containsCalendarArtwork(frame)
    if not (frame and frame.GetRegions) then return false end
    for _, region in ipairs({frame:GetRegions()}) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            local texture = region.GetTexture and region:GetTexture()
            local atlas = region.GetAtlas and region:GetAtlas()
            if type(texture) == "string" and texture:lower():find("calendar", 1, true) then return true end
            if type(atlas) == "string" and atlas:lower():find("calendar", 1, true) then return true end
        end
    end
    return false
end

local function findCalendarControl(parent, depth)
    if not (parent and parent.GetChildren) or depth > 4 then return nil end
    for _, child in ipairs({parent:GetChildren()}) do
        if child ~= _G.GameTimeFrame then
            local name = child.GetName and child:GetName()
            if (type(name) == "string" and name:lower():find("calendar", 1, true)) or containsCalendarArtwork(child) then
                return child
            end
            local nested = findCalendarControl(child, depth + 1)
            if nested then return nested end
        end
    end
end

local function getCalendarControl()
    if calendarControl then return calendarControl end
    for _, candidate in pairs({
        _G.CalendarButton,
        _G.MinimapCalendarButton,
        _G.MiniMapCalendarButton,
        MinimapCluster and MinimapCluster.CalendarButton,
        MinimapCluster and MinimapCluster.CalendarFrame,
    }) do
        if candidate and candidate ~= _G.GameTimeFrame then
            calendarControl = candidate
            return candidate
        end
    end
    calendarControl = findCalendarControl(MinimapCluster, 1)
    return calendarControl
end

local function findFontString(frame, depth)
    if not frame or depth > 4 then return nil end
    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            if region and region.IsObjectType and region:IsObjectType("FontString") then return region end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            local font = findFontString(child, depth + 1)
            if font then return font end
        end
    end
end

local function enforceMilitaryTime()
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "timeMgrUseMilitaryTime", "1")
    elseif SetCVar then
        pcall(SetCVar, "timeMgrUseMilitaryTime", "1")
    end
end

local function styleClock(clock)
    if not clockPanel then
        clockPanel = CreateFrame("Frame", "SCMinimapClockPanel", holder, "BackdropTemplate")
    end
    clockPanel:SetBackdrop(nil)

    enforceMilitaryTime()
    hideTextureTree(clock, 1)

    local location = _G.MinimapZoneTextButton
        or (MinimapCluster and (MinimapCluster.ZoneTextButton or MinimapCluster.ZoneText))
    local sourceFont = _G.MinimapZoneText or findFontString(location, 1)
    local clockFont = _G.TimeManagerClockTicker or findFontString(clock, 1)
    local textWidth = clockFont and clockFont.GetStringWidth and clockFont:GetStringWidth() or 0
    local textHeight = clockFont and clockFont.GetStringHeight and clockFont:GetStringHeight() or 0
    local locationHeight = location and location.GetHeight and location:GetHeight() or 0
    local clockWidth = math.max(46, textWidth + 10)
    clockPanel:SetSize(clockWidth, math.max(18, locationHeight, textHeight + 6))
    clockPanel:ClearAllPoints()
    if location then
        local tracking = _G.MiniMapTracking or _G.MiniMapTrackingButton
            or (MinimapCluster and (MinimapCluster.Tracking or MinimapCluster.TrackingButton))
        local trackingWidth = tracking and tracking.GetWidth and tracking:GetWidth() or 0
        local locationWidth = math.max(clockWidth + 40, holder:GetWidth() - trackingWidth + HEADER_RIGHT_TEXTURE_INSET)
        location:SetWidth(locationWidth)
        clockPanel:SetPoint("RIGHT", location, "RIGHT", -3, 0)
    else
        clockPanel:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", 0, 0)
    end
    clockPanel:SetFrameLevel(overlay:GetFrameLevel() + 8)
    clockPanel:Show()

    clock:SetParent(clockPanel)
    clock:ClearAllPoints()
    clock:SetAllPoints(clockPanel)
    if clock.SetFrameLevel then clock:SetFrameLevel(clockPanel:GetFrameLevel() + 1) end

    if clockFont and clockFont.SetTextColor then
        clockFont:SetTextColor(1, 0.92, 0, 1)
        if clockFont.ClearAllPoints and clockFont.SetPoint then
            clockFont:ClearAllPoints()
            clockFont:SetPoint("CENTER", clockPanel, "CENTER", 0, 0)
        end
    end
    if sourceFont and location and sourceFont.ClearAllPoints and sourceFont.SetPoint then
        sourceFont:ClearAllPoints()
        sourceFont:SetPoint("LEFT", location, "LEFT", 8, 0)
        if sourceFont.SetWidth then sourceFont:SetWidth(math.max(20, location:GetWidth() - clockWidth - 16)) end
        if sourceFont.SetJustifyH then sourceFont:SetJustifyH("CENTER") end
    end
end

local function placeBuiltInControls()
    local clock = _G.TimeManagerClockButton
    if clock and clock ~= buttonLauncher then
        styleClock(clock)
        if clock.SetAlpha then clock:SetAlpha(1) end
        if clock.Show then clock:Show() end
    end

    -- Forever aliases its sun/day-night control through calendar-related names.
    suppressObject(getCalendarControl())
    suppressObject(_G.GameTimeFrame)
    suppressObject(_G.CalendarButton)
    suppressObject(_G.MinimapCalendarButton)
    suppressObject(_G.MiniMapCalendarButton)
    if MinimapCluster then
        for _, key in ipairs({"CalendarButton", "CalendarFrame", "GameTimeFrame", "DayNightFrame", "SunButton", "MoonButton", "MoonFrame"}) do
            suppressObject(MinimapCluster[key])
        end
    end
    suppressCalendarArtworkTree(MinimapCluster, 1)
    suppressCalendarArtworkTree(holder, 1)

    -- SCMinimap's numbered launcher replaces Blizzard's separate addon-compartment square.
    hideObject(_G.AddonCompartmentFrame)
end

local function suppressRightEdgeSun()
    for frame in pairs(rightEdgeDayNightFrames) do suppressObject(frame) end
    if not (EnumerateFrames and holder and holder.GetRight and holder.GetTop) then return end
    local right, top = holder:GetRight(), holder:GetTop()
    if not (public(right) and public(top) and type(right) == "number" and type(top) == "number") then return end

    local excluded = {}
    for _, object in pairs({
        holder, Minimap, MinimapCluster, overlay, dragOverlay, buttonLauncher,
        buttonTray, clockPanel, _G.TimeManagerClockButton, _G.MiniMapTracking,
        _G.MiniMapTrackingButton, _G.MinimapZoneTextButton, _G.MiniMapMailFrame,
        _G.GameTooltip, _G.ItemRefTooltip, _G.EmbeddedItemTooltip,
        _G.ShoppingTooltip1, _G.ShoppingTooltip2, _G.WorldMapTooltip,
    }) do
        excluded[object] = true
    end

    local frame
    repeat
        frame = EnumerateFrames(frame)
        if frame and not excluded[frame] and frame.GetCenter and frame.GetWidth and frame.GetHeight then
            local name = frame.GetName and frame:GetName()
            local namedTooltip = type(name) == "string" and name:lower():find("tooltip", 1, true) ~= nil
            local okType, gameTooltipType = false, false
            if frame.IsObjectType then okType, gameTooltipType = pcall(frame.IsObjectType, frame, "GameTooltip") end
            local shown = not frame.IsShown or frame:IsShown()
            local protected = frame.IsProtected and frame:IsProtected()
            local forbidden = frame.IsForbidden and frame:IsForbidden()
            if shown and not protected and not forbidden and not namedTooltip and not (okType and gameTooltipType) then
                local okCenter, x, y = pcall(frame.GetCenter, frame)
                local okWidth, width = pcall(frame.GetWidth, frame)
                local okHeight, height = pcall(frame.GetHeight, frame)
                if okCenter and okWidth and okHeight and public(x) and public(y)
                    and type(x) == "number" and type(y) == "number"
                    and type(width) == "number" and type(height) == "number"
                    and width >= 16 and width <= 50 and height >= 16 and height <= 50
                    and x > right and x <= right + 40 and y >= top - 32 and y <= top + 20 then
                    rightEdgeDayNightFrames[frame] = true
                    suppressObject(frame)
                end
            end
        end
    until not frame
end

local function updateMailIndicator()
    if not mailControl then return end
    local hasMail = false
    if HasNewMail then
        local ok, value = pcall(HasNewMail)
        hasMail = ok and public(value) and not not value
    end
    mailControl:SetShown(hasMail)
end

local function applyNativeMailArtwork(target, nativeMail)
    local source = _G.MiniMapMailIcon
        or (nativeMail and (nativeMail.Icon or nativeMail.icon or nativeMail.Texture or nativeMail.texture))
    if not source and nativeMail and nativeMail.GetRegions then
        for _, region in ipairs({nativeMail:GetRegions()}) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                source = region
                break
            end
        end
    end
    if source then
        local atlas = source.GetAtlas and source:GetAtlas()
        if atlas and target.SetAtlas then
            target:SetAtlas(atlas, false)
            return true
        end
        local artwork = source.GetTexture and source:GetTexture()
        if artwork then
            target:SetTexture(artwork)
            if source.GetTexCoord and target.SetTexCoord then
                target:SetTexCoord(source:GetTexCoord())
            end
            return true
        end
    end
    target:SetTexture("Interface\\Icons\\INV_Letter_15")
    target:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return false
end

local function ensureMailIndicator(nativeMail)
    if mailControl then return mailControl end
    mailControl = CreateFrame("Frame", "SCMinimapMailIndicator", holder)
    mailControl:SetSize(24, 24)
    mailControl:EnableMouse(false)
    local texture = mailControl:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(mailControl)
    applyNativeMailArtwork(texture, nativeMail)
    updateMailIndicator()
    return mailControl
end

local function placeHeaderControls()
    local tracking = _G.MiniMapTracking or _G.MiniMapTrackingButton
        or (MinimapCluster and (MinimapCluster.Tracking or MinimapCluster.TrackingButton))
    local location = _G.MinimapZoneTextButton
        or (MinimapCluster and (MinimapCluster.ZoneTextButton or MinimapCluster.ZoneText))
    local nativeMail = _G.MiniMapMailFrame or _G.MinimapMailFrame
        or (MinimapCluster and (MinimapCluster.MailFrame or MinimapCluster.MailIcon))
    local mail = ensureMailIndicator(nativeMail)
    if nativeMail and nativeMail ~= mailControl then suppressObject(nativeMail) end
    local level = overlay:GetFrameLevel() + 7

    if tracking then
        tracking:SetParent(holder)
        tracking:ClearAllPoints()
        tracking:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 1, 0)
        if tracking.SetFrameLevel then tracking:SetFrameLevel(level) end
        if tracking.SetAlpha then tracking:SetAlpha(1) end
        if tracking.Show then tracking:Show() end
    end

    if buttonLauncher then
        buttonLauncher:ClearAllPoints()
        buttonLauncher:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -4)
    end

    if location then
        location:SetParent(holder)
        location:ClearAllPoints()
        if tracking then
            location:SetPoint("LEFT", tracking, "RIGHT", -1, 0)
        else
            location:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, 0)
        end
        if location.SetFrameLevel then location:SetFrameLevel(level) end
        if location.SetAlpha then location:SetAlpha(1) end
        if location.Show then location:Show() end
    end

    if mail then
        mail:SetParent(holder)
        mail:ClearAllPoints()
        mail:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -10, -4)
        if mail.SetFrameLevel then mail:SetFrameLevel(level + 3) end
        if mail.SetAlpha then mail:SetAlpha(1) end
        updateMailIndicator()
    end
    suppressRightEdgeSun()
end

local function isCoordinateLabel(region)
    if not (region and region ~= coordinatesText and region.IsObjectType and region:IsObjectType("FontString") and region.GetText) then
        return false
    end
    local text = region:GetText()
    return type(text) == "string" and text:match("^%s*%d+%.?%d*%s*,%s*%d+%.?%d*%s*$") ~= nil
end

local function hideDuplicateCoordinates(parent, depth)
    if not parent or depth > 5 then return end
    if parent.GetRegions then
        for _, region in ipairs({parent:GetRegions()}) do
            if isCoordinateLabel(region) then hideObject(region) end
        end
    end
    if not parent.GetChildren then return end
    for _, child in ipairs({parent:GetChildren()}) do
        if child ~= holder and child ~= Minimap then
            if isCoordinateLabel(child) then hideObject(child) end
            hideDuplicateCoordinates(child, depth + 1)
        end
    end
end

local function applyLayout()
    local size = db.size
    holder:SetSize(size, size)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    Minimap:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    zoneText:SetWidth(size - 12)
    coordinatesPanel:SetWidth(math.min(94, size - 24))
    coordinatesText:SetWidth(coordinatesPanel:GetWidth() - 27)
    applyPosition()
    applyEmphasis()
    hideDefaultArtwork()
    placeBuiltInControls()
    placeHeaderControls()
end

local function beginMove(self)
    if self.dragging or not (IsShiftKeyDown and IsShiftKeyDown()) then return end
    self.dragging = true
    holder:StartMoving()
end

local function finishMove(self)
    if not self.dragging then return end
    self.dragging = nil
    holder:StopMovingOrSizing()
    local x, y = holder:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if x and y and ux and uy then
        db.x, db.y, db.positioned = x - ux, y - uy, true
    end
end

local function updateDragCapture()
    local shift = IsShiftKeyDown and IsShiftKeyDown() or false
    if dragOverlay.dragging and not shift then finishMove(dragOverlay) end
    -- The Minimap hooks handle Shift-drag directly. A mouse-enabled frame above
    -- the map blocks native POI hover and click-to-ping in the Forever client.
    dragOverlay:EnableMouse(false)
end

local function inCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function isExcludedButton(button)
    if button == buttonLauncher then return true end
    local name = button.GetName and button:GetName()
    return name and (excludedButtonNames[name] or name:match("^SCMinimap")) or false
end

local function isCollectibleButton(button)
    if not button or buttonRecords[button] or isExcludedButton(button) then return false end
    if button.IsForbidden and button:IsForbidden() then return false end
    if button.IsProtected and button:IsProtected() then return false end
    if not (button.IsObjectType and button:IsObjectType("Button")) then return false end
    if button.IsShown and not button:IsShown() then return false end
    local name = button.GetName and button:GetName()
    if not name then return false end
    for _, pattern in ipairs(addonButtonNamePatterns) do
        if name:match(pattern) then return true end
    end
    return false
end

local function isLibDBIconButton(button)
    local name = button and button.GetName and button:GetName()
    return type(name) == "string" and name:match("^LibDBIcon10_") ~= nil
end

local function setButtonLayer(button, strata, level, relock)
    if relock and button.SetFixedFrameStrata then button:SetFixedFrameStrata(false) end
    button:SetFrameStrata(strata)
    if relock and button.SetFixedFrameStrata then button:SetFixedFrameStrata(true) end

    if relock and button.SetFixedFrameLevel then button:SetFixedFrameLevel(false) end
    button:SetFrameLevel(level)
    if relock and button.SetFixedFrameLevel then button:SetFixedFrameLevel(true) end
end

local function saveButton(button)
    local record = {
        button = button,
        parent = button:GetParent(),
        width = button:GetWidth(),
        height = button:GetHeight(),
        scale = button:GetScale(),
        strata = button:GetFrameStrata(),
        level = button:GetFrameLevel(),
        alpha = button.GetAlpha and button:GetAlpha() or 1,
        showOnMouseover = button.showOnMouseover,
        fixedLayer = isLibDBIconButton(button),
        points = {},
    }
    for index = 1, button:GetNumPoints() do
        record.points[index] = {button:GetPoint(index)}
    end
    buttonRecords[button] = record
    button:SetParent(buttonTray)
    button:SetScale(1)
    if button.fadeOut and button.fadeOut.Stop then button.fadeOut:Stop() end
    button.showOnMouseover = false
    button:SetAlpha(1)
    setButtonLayer(button, "DIALOG", buttonTray:GetFrameLevel() + 10, record.fixedLayer)
end

local function scanDirectButtons(parent)
    if not parent or not parent.GetChildren then return end
    local children = {parent:GetChildren()}
    for _, child in ipairs(children) do
        if isCollectibleButton(child) then saveButton(child) end
    end
end

local function scanPersistentAddonButtons()
    for _, name in ipairs(persistentAddonButtonNames) do
        local button = _G[name]
        if button and not buttonRecords[button] and not isExcludedButton(button)
            and not (button.IsForbidden and button:IsForbidden())
            and not (button.IsProtected and button:IsProtected())
            and button.IsObjectType and button:IsObjectType("Button") then
            saveButton(button)
        end
    end
end

local function positionButtonTray()
    if not (buttonTray and buttonLauncher) then return end
    local growUp = true
    if UIParent.GetTop and buttonLauncher.GetTop and buttonTray.GetHeight then
        local uiTop, launcherTop, trayHeight = UIParent:GetTop(), buttonLauncher:GetTop(), buttonTray:GetHeight()
        if public(uiTop) and public(launcherTop) and public(trayHeight)
            and type(uiTop) == "number" and type(launcherTop) == "number" and type(trayHeight) == "number" then
            growUp = uiTop - launcherTop >= trayHeight + 8
        end
    end
    buttonTray:ClearAllPoints()
    if growUp then
        buttonTray:SetPoint("BOTTOMRIGHT", buttonLauncher, "TOPRIGHT", 0, 4)
    else
        buttonTray:SetPoint("TOPRIGHT", buttonLauncher, "BOTTOMRIGHT", 0, -4)
    end
end

local function layoutButtons()
    if not buttonTray then return end
    local active = {}
    for button, record in pairs(buttonRecords) do
        if button and record and (not button.IsShown or button:IsShown()) then
            active[#active + 1] = button
        end
    end
    table.sort(active, function(left, right)
        local leftName = left.GetName and left:GetName() or ""
        local rightName = right.GetName and right:GetName() or ""
        return leftName < rightName
    end)
    local columns, cell, padding = 4, 32, 6
    for index, button in ipairs(active) do
        local record = buttonRecords[button]
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        button:SetParent(buttonTray)
        if button.fadeOut and button.fadeOut.Stop then button.fadeOut:Stop() end
        button.showOnMouseover = false
        button:SetAlpha(1)
        setButtonLayer(button, "DIALOG", buttonTray:GetFrameLevel() + 10, record.fixedLayer)
        button:ClearAllPoints()
        button:SetSize(28, 28)
        button:SetPoint("TOPLEFT", buttonTray, "TOPLEFT", padding + column * cell + 2, -padding - row * cell - 2)
    end
    local rows = math.max(1, math.ceil(#active / columns))
    buttonTray:SetSize(columns * cell + padding * 2, rows * cell + padding * 2)
    positionButtonTray()
    emptyButtonsText:SetShown(#active == 0)
    buttonCountText:SetText(tostring(#active))
end

local function buttonPositionsNeedLayout()
    for button, record in pairs(buttonRecords) do
        if button and record and (not button.IsShown or button:IsShown()) then
            if not button.GetParent or button:GetParent() ~= buttonTray then return true end
            if not (button.GetNumPoints and button.GetPoint) or button:GetNumPoints() ~= 1 then return true end
            local ok, _, relativeTo = pcall(button.GetPoint, button, 1)
            if not ok or (relativeTo ~= buttonTray and relativeTo ~= "SCMinimapButtonTray") then return true end
        end
    end
    return false
end

local function scanButtons()
    if not initialized or not db.collectButtons or inCombat() then return end
    -- Addon launchers are direct minimap/cluster children. Recursing here captures
    -- Blizzard's internal tracking and calendar controls as if they were addons.
    scanDirectButtons(Minimap)
    scanDirectButtons(MinimapCluster)
    layoutButtons()
end

local function restoreButtons()
    if inCombat() then say("Addon buttons will be restored after combat."); return false end
    for button, record in pairs(buttonRecords) do
        button:SetParent(record.parent)
        button:SetScale(record.scale)
        setButtonLayer(button, record.strata, record.level, record.fixedLayer)
        button.showOnMouseover = record.showOnMouseover
        button:SetAlpha(record.alpha)
        button:SetSize(record.width, record.height)
        button:ClearAllPoints()
        for _, point in ipairs(record.points) do button:SetPoint(unpackPoint(point)) end
        buttonRecords[button] = nil
    end
    layoutButtons()
    return true
end

local function setToggle(field, value, label)
    if value == "on" then db[field] = true
    elseif value == "off" then db[field] = false
    else say("Use /scminimap " .. label .. " on|off"); return false end
    updateZone()
    updateCoordinates()
    return true
end

local function initialize()
    if initialized or not Minimap then return end
    initialized = true
    SCMinimapDB = type(SCMinimapDB) == "table" and SCMinimapDB or {}
    db = SCMinimapDB
    db.size = type(db.size) == "number" and math.max(140, math.min(320, db.size)) or 200
    if type(db.showCoordinates) ~= "boolean" then db.showCoordinates = true end
    db.showZone = false
    if type(db.collectButtons) ~= "boolean" then db.collectButtons = true end
    db.iconScale = type(db.iconScale) == "number" and math.max(1, math.min(1.5, db.iconScale)) or 1.20
    -- Migrate older profiles away from the unsafe terrain-fade setting.
    db.terrainAlpha = 1
    db.x = type(db.x) == "number" and db.x or 0
    db.y = type(db.y) == "number" and db.y or 0

    holder = CreateFrame("Frame", "SCMinimapFrame", UIParent, "BackdropTemplate")
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    holder:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = false, edgeSize = 1, insets = {left = 1, right = 1, top = 1, bottom = 1}})
    holder:SetBackdropColor(0.02, 0.02, 0.02, 1)
    holder:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)

    Minimap:SetParent(holder)
    Minimap:SetMaskTexture(SQUARE_MASK_TEXTURE)
    _G.GetMinimapShape = function() return "SQUARE" end
    Minimap:EnableMouse(true)
    Minimap:EnableMouseWheel(true)
    Minimap:HookScript("OnMouseWheel", function(self, delta)
        if delta > 0 and self.ZoomIn then self:ZoomIn()
        elseif delta < 0 and self.ZoomOut then self:ZoomOut() end
    end)
    Minimap:HookScript("OnMouseDown", function(_, button)
        if dragOverlay and button == "LeftButton" then beginMove(dragOverlay) end
    end)
    Minimap:HookScript("OnMouseUp", function(_, button)
        if dragOverlay and button == "LeftButton" then finishMove(dragOverlay) end
    end)

    overlay = CreateFrame("Frame", nil, holder)
    overlay:SetAllPoints(holder)
    overlay:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 1) + 5)
    overlay:EnableMouse(false)

    zoneText = overlay:CreateFontString(nil, "OVERLAY")
    zoneText:SetPoint("TOP", overlay, "TOP", 0, -6)
    zoneText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    zoneText:SetJustifyH("CENTER")
    zoneText:SetWordWrap(false)
    zoneText:SetTextColor(1, 1, 1)

    dragOverlay = CreateFrame("Frame", nil, holder)
    dragOverlay:SetAllPoints(holder)
    dragOverlay:SetFrameLevel(overlay:GetFrameLevel() + 10)
    dragOverlay:EnableMouse(false)
    dragOverlay:Hide()

    coordinatesPanel = CreateFrame("Frame", "SCMinimapCoordinatesPanel", overlay, "BackdropTemplate")
    coordinatesPanel:SetSize(94, 18)
    coordinatesPanel:SetPoint("TOP", overlay, "TOP", 0, -3)
    coordinatesPanel:SetFrameLevel(overlay:GetFrameLevel() + 1)
    coordinatesPanel:EnableMouse(false)
    coordinatesPanel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", tile = false, insets = {left = 0, right = 0, top = 0, bottom = 0}})
    coordinatesPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.50)

    coordinatesText = coordinatesPanel:CreateFontString(nil, "OVERLAY")
    coordinatesText:SetPoint("LEFT", coordinatesPanel, "LEFT", 2, 0)
    coordinatesText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    coordinatesText:SetJustifyH("CENTER")
    coordinatesText:SetTextColor(1, 1, 1)

    directionText = coordinatesPanel:CreateFontString(nil, "OVERLAY")
    directionText:SetPoint("RIGHT", coordinatesPanel, "RIGHT", -2, 0)
    directionText:SetWidth(23)
    directionText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    directionText:SetJustifyH("CENTER")
    directionText:SetTextColor(1, 0.82, 0)

    buttonLauncher = CreateFrame("Button", "SCMinimapButton", holder, "BackdropTemplate")
    buttonLauncher:SetSize(24, 24)
    buttonLauncher:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -4)
    buttonLauncher:SetFrameLevel(overlay:GetFrameLevel() + 6)
    buttonLauncher:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = false, edgeSize = 1, insets = {left = 1, right = 1, top = 1, bottom = 1}})
    buttonLauncher:SetBackdropColor(0.04, 0.04, 0.04, 0.92)
    buttonLauncher:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    buttonCountText = buttonLauncher:CreateFontString(nil, "OVERLAY")
    buttonCountText:SetPoint("CENTER")
    buttonCountText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    buttonCountText:SetText("0")
    buttonLauncher:SetAlpha(0)
    buttonLauncher:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
    end)
    buttonLauncher:SetScript("OnLeave", function(self)
        self:SetAlpha(0)
    end)

    buttonTray = CreateFrame("Frame", "SCMinimapButtonTray", UIParent, "BackdropTemplate")
    buttonTray:SetPoint("BOTTOMRIGHT", buttonLauncher, "TOPRIGHT", 0, 4)
    buttonTray:SetClampedToScreen(true)
    buttonTray:SetFrameStrata("DIALOG")
    buttonTray:SetFrameLevel(buttonLauncher:GetFrameLevel() + 10)
    buttonTray:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = false, edgeSize = 1, insets = {left = 1, right = 1, top = 1, bottom = 1}})
    buttonTray:SetBackdropColor(0.02, 0.02, 0.02, 0.94)
    buttonTray:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    emptyButtonsText = buttonTray:CreateFontString(nil, "OVERLAY")
    emptyButtonsText:SetPoint("CENTER")
    emptyButtonsText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    emptyButtonsText:SetText("No addon buttons")
    buttonTray:Hide()
    buttonLauncher:SetScript("OnClick", function()
        buttonTray:SetShown(not buttonTray:IsShown())
    end)

    buttonKeeper = CreateFrame("Frame", "SCMinimapButtonKeeper")
    local acquireElapsed = 0
    buttonKeeper:SetScript("OnUpdate", function(_, delta)
        if not initialized or not db.collectButtons then return end
        if not inCombat() then
            acquireElapsed = acquireElapsed + delta
            if acquireElapsed >= 0.5 then
                acquireElapsed = 0
                scanPersistentAddonButtons()
            end
        end
        if buttonPositionsNeedLayout() then layoutButtons() end
    end)

    SlashCmdList.SCMINIMAP = function(message)
        local command, value = message:lower():match("^%s*(%S*)%s*(.-)%s*$")
        if command == "size" then
            local number = tonumber(value)
            if not number or number < 140 or number > 320 then say("Use /scminimap size 140-320"); return end
            db.size = number
            applyLayout()
        elseif command == "coords" then
            if not setToggle("showCoordinates", value, "coords") then return end
        elseif command == "zone" then
            db.showZone = false
            say("The zone name is shown in the lens/location bar.")
        elseif command == "icons" then
            local number = tonumber(value)
            if not number or number < 1 or number > 1.5 then say("Use /scminimap icons 1.0-1.5"); return end
            db.iconScale = number
            applyEmphasis()
        elseif command == "terrain" then
            db.terrainAlpha = 1
            applyEmphasis()
            say("Terrain opacity is fixed at 1.0 because lower alpha makes cave maps black on Forever.")
        elseif command == "buttons" then
            if value == "on" then db.collectButtons = true; scanButtons()
            elseif value == "off" then
                db.collectButtons = false
                if not restoreButtons() then return end
                buttonTray:Hide()
            else say("Use /scminimap buttons on|off"); return end
        elseif command == "rescan" then
            scanButtons()
        elseif command == "reset" then
            db.size, db.showCoordinates, db.showZone, db.collectButtons = 200, true, false, true
            db.iconScale, db.terrainAlpha = 1.20, 1
            db.x, db.y, db.positioned = 0, 0, nil
            applyLayout()
            scanButtons()
        else
            say("Shift-drag | size 200 | icons 1.2 | coords | buttons | rescan | reset")
            return
        end
        updateZone()
        updateCoordinates()
    end
    SLASH_SCMINIMAP1 = "/scminimap"

    applyLayout()
    updateDragCapture()
    updateZone()
    updateCoordinates()
    hideDuplicateCoordinates(MinimapCluster, 1)
    scanButtons()
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            initialize()
            for _, name in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "MINIMAP_UPDATE_ZOOM", "MODIFIER_STATE_CHANGED", "UPDATE_PENDING_MAIL"}) do
                eventFrame:RegisterEvent(name)
            end
        elseif initialized then scanButtons() end
        return
    end
    if not initialized then return end
    if event == "MODIFIER_STATE_CHANGED" then updateDragCapture()
    elseif event == "UPDATE_PENDING_MAIL" then updateMailIndicator()
    elseif event == "MINIMAP_UPDATE_ZOOM" then
        hideDefaultArtwork()
        applyEmphasis()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if db.collectButtons then scanButtons() else restoreButtons() end
    elseif event:match("^ZONE_CHANGED") or event == "PLAYER_ENTERING_WORLD" then
        hideDefaultArtwork()
        placeBuiltInControls()
        placeHeaderControls()
        updateZone()
        updateCoordinates()
        hideDuplicateCoordinates(MinimapCluster, 1)
    end
end)

eventFrame:SetScript("OnUpdate", function(_, delta)
    if not initialized then return end
    elapsed = elapsed + delta
    if elapsed >= 0.25 then
        elapsed = 0
        updateCoordinates()
        hideDuplicateCoordinates(MinimapCluster, 1)
    end
    scanElapsed = scanElapsed + delta
    if scanElapsed >= 2 then
        scanElapsed = 0
        hideDefaultArtwork()
        placeBuiltInControls()
        placeHeaderControls()
        scanButtons()
    end
end)
