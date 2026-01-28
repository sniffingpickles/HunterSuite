--[[
    HunterSuite - Fancy Settings UI
    A polished, tabbed settings interface
]]

local _, HunterSuite = ...

local settingsFrame = nil
local currentTab = 1

-- UI Colors
local COLORS = {
    bg = { 0.08, 0.08, 0.10, 0.95 },
    bgLight = { 0.12, 0.12, 0.15, 1 },
    border = { 0.3, 0.3, 0.35, 1 },
    borderLight = { 0.4, 0.4, 0.45, 1 },
    accent = { 0.2, 0.8, 0.4, 1 },       -- Hunter green
    accentDark = { 0.15, 0.6, 0.3, 1 },
    text = { 0.95, 0.95, 0.95, 1 },
    textDim = { 0.6, 0.6, 0.6, 1 },
    tabActive = { 0.2, 0.8, 0.4, 1 },
    tabInactive = { 0.2, 0.2, 0.25, 1 },
    toggleOn = { 0.2, 0.8, 0.4, 1 },
    toggleOff = { 0.3, 0.3, 0.35, 1 },
    sliderBg = { 0.15, 0.15, 0.18, 1 },
    sliderFill = { 0.2, 0.8, 0.4, 1 },
}

-- Tab definitions
local TABS = {
    { id = "pet", name = "Pet Feed", icon = [[Interface\Icons\Ability_Hunter_BeastCall]] },
    { id = "shot", name = "Auto Shot", icon = [[Interface\Icons\Ability_Hunter_RunningShot]] },
    { id = "aspect", name = "Aspects", icon = [[Interface\Icons\Spell_Nature_RavenForm]] },
    { id = "growl", name = "Growl", icon = [[Interface\Icons\Ability_Physical_Taunt]] },
    { id = "combat", name = "Combat", icon = [[Interface\Icons\Ability_Hunter_SniperShot]] },
    { id = "utility", name = "Utility", icon = [[Interface\Icons\INV_Misc_Bag_10]] },
    { id = "general", name = "General", icon = [[Interface\Icons\INV_Misc_Gear_01]] },
}

-- Helper: Create a styled frame
local function CreateStyledFrame(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(unpack(COLORS.bg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    return frame
end

-- Helper: Create a toggle switch
local function CreateToggle(parent, label, initialValue, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(260, 28)
    
    -- Label
    local text = container:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 12, "")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetText(label)
    text:SetTextColor(unpack(COLORS.text))
    
    -- Toggle button (using Frame to avoid Button's default background)
    local toggle = CreateFrame("Frame", nil, container)
    toggle:SetSize(44, 22)
    toggle:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    toggle:EnableMouse(true)
    
    -- Track
    local track = toggle:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetTexture([[Interface\Buttons\WHITE8X8]])
    track:SetVertexColor(unpack(COLORS.toggleOff))
    toggle.track = track
    
    -- Round the corners visually with overlay
    local trackBorder = toggle:CreateTexture(nil, "BORDER")
    trackBorder:SetPoint("TOPLEFT", -1, 1)
    trackBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    trackBorder:SetTexture([[Interface\Buttons\WHITE8X8]])
    trackBorder:SetVertexColor(unpack(COLORS.border))
    
    -- Knob
    local knob = toggle:CreateTexture(nil, "ARTWORK")
    knob:SetSize(18, 18)
    knob:SetTexture([[Interface\Buttons\WHITE8X8]])
    knob:SetVertexColor(1, 1, 1, 1)
    toggle.knob = knob
    
    -- State
    toggle.isOn = initialValue or false
    
    local function UpdateToggle()
        if toggle.isOn then
            track:SetVertexColor(unpack(COLORS.toggleOn))
            knob:ClearAllPoints()
            knob:SetPoint("RIGHT", toggle, "RIGHT", -2, 0)
        else
            track:SetVertexColor(unpack(COLORS.toggleOff))
            knob:ClearAllPoints()
            knob:SetPoint("LEFT", toggle, "LEFT", 2, 0)
        end
    end
    
    UpdateToggle()
    
    toggle:SetScript("OnMouseUp", function(self)
        self.isOn = not self.isOn
        UpdateToggle()
        if onChange then onChange(self.isOn) end
    end)
    
    toggle:SetScript("OnEnter", function(self)
        self.track:SetVertexColor(
            self.isOn and COLORS.toggleOn[1] * 1.2 or COLORS.toggleOff[1] * 1.5,
            self.isOn and COLORS.toggleOn[2] * 1.2 or COLORS.toggleOff[2] * 1.5,
            self.isOn and COLORS.toggleOn[3] * 1.2 or COLORS.toggleOff[3] * 1.5,
            1
        )
    end)
    
    toggle:SetScript("OnLeave", function(self)
        UpdateToggle()
    end)
    
    container.toggle = toggle
    container.SetValue = function(self, value)
        toggle.isOn = value
        UpdateToggle()
    end
    
    return container
end

-- Helper: Create a slider
local function CreateSlider(parent, label, min, max, step, initialValue, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(260, 40)
    
    -- Label
    local text = container:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 12, "")
    text:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    text:SetText(label)
    text:SetTextColor(unpack(COLORS.text))
    
    -- Value display
    local valueText = container:CreateFontString(nil, "OVERLAY")
    valueText:SetFont(STANDARD_TEXT_FONT, 11, "")
    valueText:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    valueText:SetTextColor(unpack(COLORS.accent))
    
    -- Slider track
    local sliderBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    sliderBg:SetSize(260, 8)
    sliderBg:SetPoint("BOTTOM", container, "BOTTOM", 0, 4)
    sliderBg:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    sliderBg:SetBackdropColor(unpack(COLORS.sliderBg))
    sliderBg:SetBackdropBorderColor(unpack(COLORS.border))
    
    -- Slider fill
    local fill = sliderBg:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", sliderBg, "LEFT", 1, 0)
    fill:SetHeight(6)
    fill:SetTexture([[Interface\Buttons\WHITE8X8]])
    fill:SetVertexColor(unpack(COLORS.sliderFill))
    
    -- Slider thumb (using Frame to avoid Button's default background)
    local thumb = CreateFrame("Frame", nil, sliderBg)
    thumb:SetSize(16, 16)
    thumb:SetPoint("CENTER", sliderBg, "LEFT", 0, 0)
    thumb:EnableMouse(true)
    
    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetTexture([[Interface\Buttons\WHITE8X8]])
    thumbTex:SetVertexColor(1, 1, 1, 1)
    
    local thumbBorder = thumb:CreateTexture(nil, "BORDER")
    thumbBorder:SetPoint("TOPLEFT", -1, 1)
    thumbBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    thumbBorder:SetTexture([[Interface\Buttons\WHITE8X8]])
    thumbBorder:SetVertexColor(unpack(COLORS.border))
    
    -- Value
    local value = initialValue or min
    
    local function UpdateSlider()
        local pct = (value - min) / (max - min)
        local width = sliderBg:GetWidth() - 2
        fill:SetWidth(math.max(1, pct * width))
        thumb:SetPoint("CENTER", sliderBg, "LEFT", pct * width, 0)
        valueText:SetText(string.format("%.1f", value))
    end
    
    UpdateSlider()
    
    -- Dragging
    thumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
    end)
    
    thumb:SetScript("OnMouseUp", function(self)
        self.dragging = false
    end)
    
    sliderBg:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            local x = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
            local left = self:GetLeft()
            local width = self:GetWidth()
            local pct = math.max(0, math.min(1, (x - left) / width))
            value = min + pct * (max - min)
            value = math.floor(value / step + 0.5) * step
            value = math.max(min, math.min(max, value))
            UpdateSlider()
            if onChange then onChange(value) end
        end
    end)
    
    container:SetScript("OnUpdate", function(self)
        if thumb.dragging then
            local x = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
            local left = sliderBg:GetLeft()
            local width = sliderBg:GetWidth()
            local pct = math.max(0, math.min(1, (x - left) / width))
            value = min + pct * (max - min)
            value = math.floor(value / step + 0.5) * step
            value = math.max(min, math.min(max, value))
            UpdateSlider()
            if onChange then onChange(value) end
        end
    end)
    
    container.SetValue = function(self, v)
        value = v
        UpdateSlider()
    end
    
    return container
end

-- Helper: Create section header
local function CreateHeader(parent, text)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(280, 24)
    
    local line1 = header:CreateTexture(nil, "ARTWORK")
    line1:SetSize(40, 1)
    line1:SetPoint("LEFT", header, "LEFT", 0, 0)
    line1:SetTexture([[Interface\Buttons\WHITE8X8]])
    line1:SetVertexColor(unpack(COLORS.border))
    
    local label = header:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 11, "")
    label:SetPoint("LEFT", line1, "RIGHT", 8, 0)
    label:SetText(text)
    label:SetTextColor(unpack(COLORS.textDim))
    
    local line2 = header:CreateTexture(nil, "ARTWORK")
    line2:SetHeight(1)
    line2:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line2:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    line2:SetTexture([[Interface\Buttons\WHITE8X8]])
    line2:SetVertexColor(unpack(COLORS.border))
    
    return header
end

-- Helper: Create a text input box
local function CreateTextInput(parent, label, initialValue, width, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 260, 40)
    
    -- Label
    local text = container:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 11, "")
    text:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    text:SetText(label)
    text:SetTextColor(unpack(COLORS.text))
    
    -- Edit box background
    local editBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    editBg:SetSize(width or 260, 22)
    editBg:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    editBg:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    editBg:SetBackdropColor(0.1, 0.1, 0.12, 1)
    editBg:SetBackdropBorderColor(unpack(COLORS.border))
    
    -- Edit box
    local editBox = CreateFrame("EditBox", nil, editBg)
    editBox:SetPoint("TOPLEFT", 6, -3)
    editBox:SetPoint("BOTTOMRIGHT", -6, 3)
    editBox:SetFont(STANDARD_TEXT_FONT, 11, "")
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetAutoFocus(false)
    editBox:SetText(initialValue or "")
    
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onChange then onChange(self:GetText()) end
    end)
    
    editBox:SetScript("OnEditFocusLost", function(self)
        if onChange then onChange(self:GetText()) end
    end)
    
    container.editBox = editBox
    container.SetValue = function(self, value)
        editBox:SetText(value or "")
    end
    
    return container
end

-- Create tab content: Pet Feed
local function CreatePetFeedContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    
    local y = -20
    
    -- Enable toggle
    local enableToggle = CreateToggle(content, "Enable Pet Feed Bar", HunterSuite.db.petFeed.enabled, function(value)
        HunterSuite.db.petFeed.enabled = value
        if HunterSuite.PetFeed then HunterSuite.PetFeed:UpdateUI() end
    end)
    enableToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    -- Lock toggle
    local lockToggle = CreateToggle(content, "Lock Position", HunterSuite.db.petFeed.locked, function(value)
        HunterSuite.db.petFeed.locked = value
    end)
    lockToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    -- Auto food toggle
    local autoToggle = CreateToggle(content, "Auto-Select Best Food", HunterSuite.db.petFeed.autoSelectFood, function(value)
        HunterSuite.db.petFeed.autoSelectFood = value
    end)
    autoToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    -- Show tooltip toggle
    local tooltipToggle = CreateToggle(content, "Show Tooltip on Hover", HunterSuite.db.petFeed.showTooltip, function(value)
        HunterSuite.db.petFeed.showTooltip = value
    end)
    tooltipToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 45
    
    -- Visibility header
    local visHeader = CreateHeader(content, "VISIBILITY")
    visHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 35
    
    -- Show always toggle
    local alwaysToggle = CreateToggle(content, "Always Show Bar", HunterSuite.db.petFeed.showAlways, function(value)
        HunterSuite.db.petFeed.showAlways = value
        if HunterSuite.PetFeed then HunterSuite.PetFeed:UpdateUI() end
    end)
    alwaysToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 28
    
    -- Threshold info
    local threshInfo = content:CreateFontString(nil, "OVERLAY")
    threshInfo:SetFont(STANDARD_TEXT_FONT, 10, "")
    threshInfo:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    threshInfo:SetWidth(260)
    threshInfo:SetText("|cffaaaaaaWhen off, bar only shows if pet is Content or Unhappy|r")
    threshInfo:SetTextColor(unpack(COLORS.textDim))
    y = y - 35
    
    -- Appearance header
    local appearHeader = CreateHeader(content, "APPEARANCE")
    appearHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 35
    
    -- Icon style toggle
    local iconStyleToggle = CreateToggle(content, "Icon Style (minimal)", HunterSuite.db.petFeed.style == "icon", function(value)
        HunterSuite.db.petFeed.style = value and "icon" or "bar"
        if HunterSuite.PetFeed then HunterSuite.PetFeed:UpdateUI() end
    end)
    iconStyleToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    -- Scale slider
    local scaleSlider = CreateSlider(content, "Scale", 0.5, 2.0, 0.1, HunterSuite.db.petFeed.scale, function(value)
        HunterSuite.db.petFeed.scale = value
        if HunterSuite.PetFeed then HunterSuite.PetFeed:UpdateUI() end
    end)
    scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    -- Alpha slider
    local alphaSlider = CreateSlider(content, "Opacity", 0.3, 1.0, 0.1, HunterSuite.db.petFeed.alpha, function(value)
        HunterSuite.db.petFeed.alpha = value
        if HunterSuite.PetFeed then HunterSuite.PetFeed:UpdateUI() end
    end)
    alphaSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    
    return content
end

-- Create tab content: Auto Shot
local function CreateAutoShotContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    
    local y = -20
    
    local enableToggle = CreateToggle(content, "Enable Auto Shot Timer", HunterSuite.db.autoShot.enabled, function(value)
        HunterSuite.db.autoShot.enabled = value
        if HunterSuite.AutoShot then HunterSuite.AutoShot:UpdateUI() end
    end)
    enableToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local hideToggle = CreateToggle(content, "Hide When Not Shooting", HunterSuite.db.autoShot.hideWhenInactive, function(value)
        HunterSuite.db.autoShot.hideWhenInactive = value
    end)
    hideToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local lockToggle = CreateToggle(content, "Lock Position", HunterSuite.db.autoShot.locked, function(value)
        HunterSuite.db.autoShot.locked = value
    end)
    lockToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local latencyToggle = CreateToggle(content, "Latency Compensation", HunterSuite.db.autoShot.latencyComp, function(value)
        HunterSuite.db.autoShot.latencyComp = value
    end)
    latencyToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 45
    
    -- Appearance header
    local appearHeader = CreateHeader(content, "APPEARANCE")
    appearHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 35
    
    local scaleSlider = CreateSlider(content, "Scale", 0.5, 2.0, 0.1, HunterSuite.db.autoShot.scale, function(value)
        HunterSuite.db.autoShot.scale = value
        if HunterSuite.AutoShot and HunterSuite.AutoShot.timerFrame then
            HunterSuite.AutoShot.timerFrame:SetScale(value)
        end
    end)
    scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    local widthSlider = CreateSlider(content, "Bar Width", 100, 300, 10, HunterSuite.db.autoShot.barWidth, function(value)
        HunterSuite.db.autoShot.barWidth = value
        if HunterSuite.AutoShot then HunterSuite.AutoShot:UpdateUI() end
    end)
    widthSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    local heightSlider = CreateSlider(content, "Bar Height", 8, 32, 2, HunterSuite.db.autoShot.barHeight, function(value)
        HunterSuite.db.autoShot.barHeight = value
        if HunterSuite.AutoShot then HunterSuite.AutoShot:UpdateUI() end
    end)
    heightSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 45
    
    -- Timing header
    local timingHeader = CreateHeader(content, "TIMING")
    timingHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 35
    
    local windupSlider = CreateSlider(content, "Windup Time", 0.3, 0.7, 0.05, HunterSuite.db.autoShot.windup, function(value)
        HunterSuite.db.autoShot.windup = value
    end)
    windupSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    local queueSlider = CreateSlider(content, "Queue Window", 0.05, 0.3, 0.01, HunterSuite.db.autoShot.queueWindow, function(value)
        HunterSuite.db.autoShot.queueWindow = value
    end)
    queueSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 45
    
    -- Text labels header
    local textHeader = CreateHeader(content, "TEXT LABELS")
    textHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 40
    
    local queueInput = CreateTextInput(content, "Queue Text", HunterSuite.db.autoShot.queueText, 120, function(value)
        HunterSuite.db.autoShot.queueText = value
    end)
    queueInput:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    
    local waitInput = CreateTextInput(content, "Wait Text", HunterSuite.db.autoShot.waitText, 120, function(value)
        HunterSuite.db.autoShot.waitText = value
    end)
    waitInput:SetPoint("TOPLEFT", content, "TOPLEFT", 150, y)
    
    return content
end

-- Create tab content: Aspects
local function CreateAspectsContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    
    local y = -20
    
    local enableToggle = CreateToggle(content, "Enable Aspect Reminder", HunterSuite.db.aspects.enabled, function(value)
        HunterSuite.db.aspects.enabled = value
        if HunterSuite.Aspects then HunterSuite.Aspects:UpdateUI() end
    end)
    enableToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local combatToggle = CreateToggle(content, "Only Alert In Combat", HunterSuite.db.aspects.onlyInCombat, function(value)
        HunterSuite.db.aspects.onlyInCombat = value
        if HunterSuite.Aspects then HunterSuite.Aspects:CheckAspect() end
    end)
    combatToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 45
    
    -- Appearance header
    local appearHeader = CreateHeader(content, "APPEARANCE")
    appearHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 35
    
    local scaleSlider = CreateSlider(content, "Scale", 0.5, 2.0, 0.1, HunterSuite.db.aspects.scale, function(value)
        HunterSuite.db.aspects.scale = value
        if HunterSuite.Aspects then HunterSuite.Aspects:UpdateUI() end
    end)
    scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    local alertInput = CreateTextInput(content, "Alert Text", HunterSuite.db.aspects.alertText, 260, function(value)
        HunterSuite.db.aspects.alertText = value
    end)
    alertInput:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    local info = content:CreateFontString(nil, "OVERLAY")
    info:SetFont(STANDARD_TEXT_FONT, 11, "")
    info:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    info:SetWidth(260)
    info:SetJustifyH("LEFT")
    info:SetText("|cffaaaaaaShows a pulsing alert when you don't have any aspect active. Right-click to dismiss.|r")
    info:SetTextColor(unpack(COLORS.textDim))
    
    return content
end

-- Create tab content: Growl
local function CreateGrowlContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    
    local y = -20
    
    local enableToggle = CreateToggle(content, "Enable Growl Reminder", HunterSuite.db.growl.enabled, function(value)
        HunterSuite.db.growl.enabled = value
        if HunterSuite.Growl then HunterSuite.Growl:UpdateUI() end
    end)
    enableToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 45
    
    -- Appearance header
    local appearHeader = CreateHeader(content, "APPEARANCE")
    appearHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 35
    
    local scaleSlider = CreateSlider(content, "Scale", 0.5, 2.0, 0.1, HunterSuite.db.growl.scale, function(value)
        HunterSuite.db.growl.scale = value
        if HunterSuite.Growl then HunterSuite.Growl:UpdateUI() end
    end)
    scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    local alertInput = CreateTextInput(content, "Alert Text", HunterSuite.db.growl.alertText, 260, function(value)
        HunterSuite.db.growl.alertText = value
    end)
    alertInput:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    local info = content:CreateFontString(nil, "OVERLAY")
    info:SetFont(STANDARD_TEXT_FONT, 11, "")
    info:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    info:SetWidth(260)
    info:SetJustifyH("LEFT")
    info:SetText("|cffaaaaaaAlerts when entering a dungeon/raid if pet Growl is on. Left-click opens pet spellbook.|r")
    info:SetTextColor(unpack(COLORS.textDim))
    
    return content
end

-- Create tab content: Combat (Traps, Range, Feign, Stings)
local function CreateCombatContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    
    local y = -20
    
    -- Traps section
    local trapsHeader = CreateHeader(content, "TRAP TIMER")
    trapsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 30
    
    local trapsToggle = CreateToggle(content, "Enable Trap Timer", HunterSuite.db.traps.enabled, function(value)
        HunterSuite.db.traps.enabled = value
        if HunterSuite.Traps then HunterSuite.Traps:UpdateUI() end
    end)
    trapsToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local trapScaleSlider = CreateSlider(content, "Scale", 0.5, 2.0, 0.1, HunterSuite.db.traps.scale, function(value)
        HunterSuite.db.traps.scale = value
        if HunterSuite.Traps then HunterSuite.Traps:UpdateUI() end
    end)
    trapScaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    -- Range section
    local rangeHeader = CreateHeader(content, "RANGE / DEAD ZONE")
    rangeHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 30
    
    local rangeToggle = CreateToggle(content, "Enable Range Indicator", HunterSuite.db.range.enabled, function(value)
        HunterSuite.db.range.enabled = value
        if HunterSuite.Range then HunterSuite.Range:UpdateUI() end
    end)
    rangeToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local rangeAlwaysToggle = CreateToggle(content, "Show At All Times", HunterSuite.db.range.showAlways, function(value)
        HunterSuite.db.range.showAlways = value
        if HunterSuite.Range then HunterSuite.Range:UpdateUI() end
    end)
    rangeAlwaysToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local rangeDotToggle = CreateToggle(content, "Dot Style (minimal)", HunterSuite.db.range.style == "dot", function(value)
        HunterSuite.db.range.style = value and "dot" or "text"
        if HunterSuite.Range then HunterSuite.Range:UpdateUI() end
    end)
    rangeDotToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local rangeScaleSlider = CreateSlider(content, "Scale", 0.5, 2.0, 0.1, HunterSuite.db.range.scale, function(value)
        HunterSuite.db.range.scale = value
        if HunterSuite.Range then HunterSuite.Range:UpdateUI() end
    end)
    rangeScaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    -- Stings section
    local stingsHeader = CreateHeader(content, "SERPENT STING TRACKER")
    stingsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 30
    
    local stingsToggle = CreateToggle(content, "Show on Nameplates", HunterSuite.db.stings.enabled, function(value)
        HunterSuite.db.stings.enabled = value
        if HunterSuite.Stings then HunterSuite.Stings:UpdateUI() end
    end)
    stingsToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 40
    
    return content
end

-- Create tab content: Utility (Ammo, Pet Reminder, Tracking, AutoMark)
local function CreateUtilityContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    
    local y = -20
    
    -- Ammo section
    local ammoHeader = CreateHeader(content, "AMMO WARNING")
    ammoHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 30
    
    local ammoToggle = CreateToggle(content, "Enable Ammo Warning", HunterSuite.db.ammo.enabled, function(value)
        HunterSuite.db.ammo.enabled = value
        if HunterSuite.Ammo then HunterSuite.Ammo:UpdateUI() end
    end)
    ammoToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local ammoLowSlider = CreateSlider(content, "Low Threshold", 50, 500, 50, HunterSuite.db.ammo.lowThreshold, function(value)
        HunterSuite.db.ammo.lowThreshold = value
    end)
    ammoLowSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    local ammoCritSlider = CreateSlider(content, "Critical Threshold", 10, 100, 10, HunterSuite.db.ammo.criticalThreshold, function(value)
        HunterSuite.db.ammo.criticalThreshold = value
    end)
    ammoCritSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    -- Pet Reminder section
    local petHeader = CreateHeader(content, "PET REMINDERS")
    petHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 30
    
    local petToggle = CreateToggle(content, "Enable Pet Reminders", HunterSuite.db.petReminder.enabled, function(value)
        HunterSuite.db.petReminder.enabled = value
        if HunterSuite.PetReminder then HunterSuite.PetReminder:UpdateUI() end
    end)
    petToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local healSlider = CreateSlider(content, "Mend Pet Threshold %", 0.3, 0.9, 0.05, HunterSuite.db.petReminder.healThreshold, function(value)
        HunterSuite.db.petReminder.healThreshold = value
    end)
    healSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 50
    
    -- AutoMark section
    local markHeader = CreateHeader(content, "AUTO-MARK PETS")
    markHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 30
    
    local markToggle = CreateToggle(content, "Mark Enemy Pets (Skull)", HunterSuite.db.autoMark.enabled, function(value)
        HunterSuite.db.autoMark.enabled = value
    end)
    markToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 35
    
    local markPvpToggle = CreateToggle(content, "Only in PVP Instances", HunterSuite.db.autoMark.onlyInPVPInstances, function(value)
        HunterSuite.db.autoMark.onlyInPVPInstances = value
    end)
    markPvpToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 40
    
    return content
end

-- Create tab content: General
local function CreateGeneralContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    
    local y = -20
    
    local minimapToggle = CreateToggle(content, "Show Minimap Button", not (HunterSuite.db.minimap and HunterSuite.db.minimap.hide), function(value)
        if HunterSuite.db.minimap then
            HunterSuite.db.minimap.hide = not value
        end
        HunterSuite:ToggleMinimapButton()
    end)
    minimapToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    y = y - 45
    
    -- Edit Mode header
    local editHeader = CreateHeader(content, "POSITIONING")
    editHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 35
    
    -- Edit Mode button
    local editBtn = CreateFrame("Button", nil, content, "BackdropTemplate")
    editBtn:SetSize(200, 32)
    editBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    editBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    editBtn:SetBackdropColor(0.2, 0.6, 0.3, 1)
    editBtn:SetBackdropBorderColor(0.3, 0.8, 0.4, 1)
    
    local editIcon = editBtn:CreateTexture(nil, "ARTWORK")
    editIcon:SetSize(18, 18)
    editIcon:SetPoint("LEFT", editBtn, "LEFT", 10, 0)
    editIcon:SetTexture([[Interface\Icons\INV_Misc_Wrench_01]])
    editIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    local editText = editBtn:CreateFontString(nil, "OVERLAY")
    editText:SetFont(STANDARD_TEXT_FONT, 12, "")
    editText:SetPoint("LEFT", editIcon, "RIGHT", 8, 0)
    editText:SetText("Enter Edit Mode")
    editText:SetTextColor(1, 1, 1, 1)
    
    editBtn:SetScript("OnClick", function()
        HunterSuite:ToggleEditMode()
        if settingsFrame then settingsFrame:Hide() end
    end)
    
    editBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.7, 0.35, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Edit Mode", 1, 1, 1)
        GameTooltip:AddLine("Shows all UI elements so you can", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("drag them to your preferred position.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Type /hs edit again to exit.", 0.5, 0.8, 0.5)
        GameTooltip:Show()
    end)
    editBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.6, 0.3, 1)
        GameTooltip:Hide()
    end)
    y = y - 45
    
    -- Commands header
    local cmdHeader = CreateHeader(content, "COMMANDS")
    cmdHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    y = y - 30
    
    local commands = {
        { cmd = "/hs", desc = "Open this settings panel" },
        { cmd = "/hs edit", desc = "Toggle edit mode (position UI)" },
        { cmd = "/hs lock", desc = "Lock/unlock all bars" },
        { cmd = "/hs feed", desc = "Feed your pet" },
        { cmd = "/hs reset", desc = "Reset all settings" },
    }
    
    for _, c in ipairs(commands) do
        local line = content:CreateFontString(nil, "OVERLAY")
        line:SetFont(STANDARD_TEXT_FONT, 11, "")
        line:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
        line:SetText("|cff00ff00" .. c.cmd .. "|r  " .. c.desc)
        line:SetTextColor(unpack(COLORS.textDim))
        y = y - 18
    end
    y = y - 20
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, content, "BackdropTemplate")
    resetBtn:SetSize(120, 28)
    resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    resetBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    resetBtn:SetBackdropColor(0.6, 0.2, 0.2, 1)
    resetBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1)
    
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY")
    resetText:SetFont(STANDARD_TEXT_FONT, 11, "")
    resetText:SetPoint("CENTER")
    resetText:SetText("Reset All Settings")
    resetText:SetTextColor(1, 1, 1, 1)
    
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("HUNTERSUITE_RESET")
    end)
    
    resetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.7, 0.25, 0.25, 1)
    end)
    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.6, 0.2, 0.2, 1)
    end)
    
    -- Reset dialog
    StaticPopupDialogs["HUNTERSUITE_RESET"] = {
        text = "Reset all Hunter Suite settings to defaults?\n\nThis will reload your UI.",
        button1 = "Reset",
        button2 = "Cancel",
        OnAccept = function()
            HunterSuiteDB = nil
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    
    return content
end

-- Create the main settings frame
function HunterSuite:CreateSettingsFrame()
    if settingsFrame then return settingsFrame end
    
    local width = 400
    local height = 480
    
    -- Main frame
    settingsFrame = CreateStyledFrame(UIParent, width, height)
    settingsFrame:SetPoint("CENTER")
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:SetMovable(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:RegisterForDrag("LeftButton")
    settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
    settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
    settingsFrame:SetClampedToScreen(true)
    settingsFrame:Hide()
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, settingsFrame, "BackdropTemplate")
    titleBar:SetSize(width - 2, 40)
    titleBar:SetPoint("TOP", settingsFrame, "TOP", 0, -1)
    titleBar:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
    })
    titleBar:SetBackdropColor(unpack(COLORS.bgLight))
    
    -- Icon
    local icon = titleBar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    icon:SetTexture([[Interface\Icons\Ability_Hunter_BeastCall]])
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Title
    local title = titleBar:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 16, "")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    title:SetText("|cff00ff00Hunter Suite|r")
    
    -- Version
    local version = titleBar:CreateFontString(nil, "OVERLAY")
    version:SetFont(STANDARD_TEXT_FONT, 10, "")
    version:SetPoint("LEFT", title, "RIGHT", 8, -2)
    version:SetText("v2.0")
    version:SetTextColor(unpack(COLORS.textDim))
    
    -- Edit Mode button (in header)
    local editBtn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    editBtn:SetSize(70, 22)
    editBtn:SetPoint("RIGHT", titleBar, "RIGHT", -40, 0)
    editBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    editBtn:SetBackdropColor(0.2, 0.6, 0.3, 1)
    editBtn:SetBackdropBorderColor(0.3, 0.8, 0.4, 1)
    
    local editText = editBtn:CreateFontString(nil, "OVERLAY")
    editText:SetFont(STANDARD_TEXT_FONT, 10, "")
    editText:SetPoint("CENTER")
    editText:SetText("Edit Mode")
    editText:SetTextColor(1, 1, 1, 1)
    
    -- Function to update button appearance based on edit mode state
    local function UpdateEditButtonState(isEditMode)
        if isEditMode then
            editText:SetText("Exit Edit")
            editBtn:SetBackdropColor(0.6, 0.3, 0.2, 1)
            editBtn:SetBackdropBorderColor(0.8, 0.4, 0.3, 1)
        else
            editText:SetText("Edit Mode")
            editBtn:SetBackdropColor(0.2, 0.6, 0.3, 1)
            editBtn:SetBackdropBorderColor(0.3, 0.8, 0.4, 1)
        end
    end
    
    -- Register callback to stay in sync
    HunterSuite:RegisterEditModeCallback(UpdateEditButtonState)
    
    -- Initialize button state
    UpdateEditButtonState(HunterSuite.state.editMode)
    
    editBtn:SetScript("OnClick", function()
        HunterSuite:ToggleEditMode()
    end)
    editBtn:SetScript("OnEnter", function(self)
        if HunterSuite.state.editMode then
            self:SetBackdropColor(0.7, 0.35, 0.25, 1)
        else
            self:SetBackdropColor(0.25, 0.7, 0.35, 1)
        end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(HunterSuite.state.editMode and "Exit Edit Mode" or "Edit Mode", 1, 1, 1)
        GameTooltip:AddLine("Show all UI elements for positioning.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Adjust settings live while visible.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    editBtn:SetScript("OnLeave", function(self)
        if HunterSuite.state.editMode then
            self:SetBackdropColor(0.6, 0.3, 0.2, 1)
        else
            self:SetBackdropColor(0.2, 0.6, 0.3, 1)
        end
        GameTooltip:Hide()
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)
    
    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetTexture([[Interface\Buttons\WHITE8X8]])
    closeTex:SetVertexColor(0.4, 0.4, 0.4, 1)
    
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY")
    closeX:SetFont(STANDARD_TEXT_FONT, 16, "")
    closeX:SetPoint("CENTER", 0, 1)
    closeX:SetText("×")
    closeX:SetTextColor(0.8, 0.8, 0.8, 1)
    
    closeBtn:SetScript("OnClick", function()
        settingsFrame:Hide()
        -- Sound removed
    end)
    closeBtn:SetScript("OnEnter", function()
        closeTex:SetVertexColor(0.8, 0.2, 0.2, 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeTex:SetVertexColor(0.4, 0.4, 0.4, 1)
    end)
    
    -- Tab bar
    local tabBar = CreateFrame("Frame", nil, settingsFrame)
    tabBar:SetSize(90, height - 42)
    tabBar:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 1, -41)
    
    local tabBg = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBg:SetAllPoints()
    tabBg:SetTexture([[Interface\Buttons\WHITE8X8]])
    tabBg:SetVertexColor(0.06, 0.06, 0.08, 1)
    
    -- Credits in sidebar
    local credits = tabBar:CreateFontString(nil, "OVERLAY")
    credits:SetFont(STANDARD_TEXT_FONT, 9, "")
    credits:SetPoint("BOTTOM", tabBar, "BOTTOM", 0, 8)
    credits:SetText("|cffffcc00twitch.tv/muggles|r")
    credits:SetTextColor(1, 0.8, 0, 1)
    
    -- Content area with scroll
    local contentArea = CreateFrame("Frame", nil, settingsFrame)
    contentArea:SetPoint("TOPLEFT", tabBar, "TOPRIGHT", 0, 0)
    contentArea:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -1, 1)
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, contentArea, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -24, 0)
    
    -- Style the scrollbar
    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName() .. "ScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 16)
    end
    
    -- Scroll child (container for all tab contents)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(contentArea:GetWidth() - 24, 700)  -- Height for all settings
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local step = 40  -- Pixels per scroll
        local newScroll = current - (delta * step)
        newScroll = math.max(0, math.min(newScroll, maxScroll))
        self:SetVerticalScroll(newScroll)
    end)
    
    -- Also enable scrolling when hovering over content
    scrollChild:EnableMouseWheel(true)
    scrollChild:SetScript("OnMouseWheel", function(self, delta)
        local current = scrollFrame:GetVerticalScroll()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        local step = 40
        local newScroll = current - (delta * step)
        newScroll = math.max(0, math.min(newScroll, maxScroll))
        scrollFrame:SetVerticalScroll(newScroll)
    end)
    
    -- Tab buttons and content
    local tabButtons = {}
    local tabContents = {}
    local contentCreators = {
        CreatePetFeedContent,
        CreateAutoShotContent,
        CreateAspectsContent,
        CreateGrowlContent,
        CreateCombatContent,
        CreateUtilityContent,
        CreateGeneralContent,
    }
    
    for i, tab in ipairs(TABS) do
        -- Tab button
        local btn = CreateFrame("Button", nil, tabBar)
        btn:SetSize(88, 36)
        btn:SetPoint("TOP", tabBar, "TOP", 0, -((i - 1) * 38) - 10)
        
        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints()
        btnBg:SetTexture([[Interface\Buttons\WHITE8X8]])
        btn.bg = btnBg
        
        local btnIcon = btn:CreateTexture(nil, "ARTWORK")
        btnIcon:SetSize(20, 20)
        btnIcon:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btnIcon:SetTexture(tab.icon)
        btnIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        local btnText = btn:CreateFontString(nil, "OVERLAY")
        btnText:SetFont(STANDARD_TEXT_FONT, 10, "")
        btnText:SetPoint("LEFT", btnIcon, "RIGHT", 6, 0)
        btnText:SetText(tab.name)
        btn.text = btnText
        
        btn:SetScript("OnClick", function()
            currentTab = i
            for j, b in ipairs(tabButtons) do
                if j == i then
                    b.bg:SetVertexColor(unpack(COLORS.accent))
                    b.text:SetTextColor(0.1, 0.1, 0.1, 1)
                    tabContents[j]:Show()
                else
                    b.bg:SetVertexColor(unpack(COLORS.tabInactive))
                    b.text:SetTextColor(unpack(COLORS.textDim))
                    tabContents[j]:Hide()
                end
            end
            -- Reset scroll to top when switching tabs
            scrollFrame:SetVerticalScroll(0)
            -- Sound removed
        end)
        
        tabButtons[i] = btn
        
        -- Tab content (parent to scrollChild for scrolling)
        local content = contentCreators[i](scrollChild)
        content:SetSize(scrollChild:GetWidth(), 600)
        content:Hide()
        tabContents[i] = content
    end
    
    -- Select first tab
    tabButtons[1].bg:SetVertexColor(unpack(COLORS.accent))
    tabButtons[1].text:SetTextColor(0.1, 0.1, 0.1, 1)
    tabContents[1]:Show()
    
    -- ESC to close (UISpecialFrames handles this automatically)
    tinsert(UISpecialFrames, "HunterSuiteSettings")
    
    self.settingsFrame = settingsFrame
    return settingsFrame
end

-- Show/hide settings
function HunterSuite:ShowSettings()
    if not settingsFrame then
        self:CreateSettingsFrame()
    end
    settingsFrame:Show()
    -- Sound removed
end

function HunterSuite:HideSettings()
    if settingsFrame then
        settingsFrame:Hide()
    end
end
