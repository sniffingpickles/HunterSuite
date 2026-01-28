--[[
    HunterSuite - Pet Feed Module
    Handles pet happiness tracking and feeding UI
]]

local addonName, HunterSuite = ...

-- Module setup
HunterSuite.PetFeed = {}
local PetFeed = HunterSuite.PetFeed

-- Local references
local mainFrame = nil
local happinessBar = nil
local statusText = nil
local feedButton = nil
local feedProgressBar = nil
local iconTexture = nil

-- Create the main pet feed bar
function PetFeed:CreateBar()
    if mainFrame then return mainFrame end
    
    local db = HunterSuite.db.petFeed
    
    -- Main frame
    mainFrame = CreateFrame("Frame", "HunterSuitePetFeed", UIParent, "BackdropTemplate")
    mainFrame:SetSize(db.barWidth + 16, db.barHeight + 8)
    mainFrame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or -200)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetClampedToScreen(true)
    
    -- Dark backdrop
    mainFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    mainFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    mainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    -- Happiness bar
    happinessBar = CreateFrame("StatusBar", "HunterSuitePetHappiness", mainFrame, "BackdropTemplate")
    happinessBar:SetSize(db.barWidth - 8, db.barHeight - 4)
    happinessBar:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
    happinessBar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
    happinessBar:SetStatusBarColor(0.2, 0.9, 0.2, 1)
    happinessBar:SetMinMaxValues(0, 100)
    happinessBar:SetValue(100)
    
    happinessBar:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    happinessBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    happinessBar:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
    
    -- Status text
    statusText = happinessBar:CreateFontString(nil, "OVERLAY")
    statusText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    statusText:SetPoint("CENTER", happinessBar, "CENTER", 0, 0)
    statusText:SetTextColor(1, 1, 1, 1)
    statusText:SetText("Happy")
    
    -- Feed button (SecureActionButton)
    feedButton = CreateFrame("Button", "HunterSuiteFeedButton", mainFrame, "SecureActionButtonTemplate")
    feedButton:SetAllPoints(mainFrame)
    feedButton:SetAttribute("type1", "macro")
    feedButton:SetAttribute("macrotext1", "/cast Feed Pet")
    feedButton:RegisterForClicks("AnyUp", "AnyDown")
    
    -- Highlight on hover
    feedButton:SetHighlightTexture([[Interface\Buttons\WHITE8X8]])
    local highlight = feedButton:GetHighlightTexture()
    highlight:SetVertexColor(1, 1, 1, 0.08)
    
    -- Update macro on enter
    feedButton:SetScript("OnEnter", function(self)
        PetFeed:UpdateFeedMacro()
        if HunterSuite.db.petFeed.showTooltip then
            PetFeed:ShowTooltip(self)
        end
    end)
    feedButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Right-click for settings
    feedButton:SetScript("PostClick", function(self, button)
        if button == "RightButton" and HunterSuite.ShowSettings then
            HunterSuite:ShowSettings()
        end
    end)
    
    -- Dragging (only in edit mode)
    feedButton:SetMovable(true)
    feedButton:RegisterForDrag("LeftButton")
    feedButton:SetScript("OnDragStart", function(self)
        if HunterSuite.state.editMode then
            mainFrame:StartMoving()
        end
    end)
    feedButton:SetScript("OnDragStop", function(self)
        mainFrame:StopMovingOrSizing()
        local point, _, _, x, y = mainFrame:GetPoint()
        HunterSuite.db.petFeed.position.point = point
        HunterSuite.db.petFeed.position.x = x
        HunterSuite.db.petFeed.position.y = y
    end)
    
    -- Icon for icon style (bone icon)
    iconTexture = mainFrame:CreateTexture(nil, "ARTWORK")
    iconTexture:SetSize(24, 24)
    iconTexture:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
    iconTexture:SetTexture([[Interface\Icons\INV_Misc_Bone_01]])
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconTexture:Hide()
    
    -- Feed progress bar
    feedProgressBar = CreateFrame("StatusBar", "HunterSuiteFeedProgress", mainFrame, "BackdropTemplate")
    feedProgressBar:SetSize(db.barWidth - 8, 6)
    feedProgressBar:SetPoint("TOP", happinessBar, "BOTTOM", 0, -4)
    feedProgressBar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
    feedProgressBar:SetStatusBarColor(0.2, 0.6, 1, 1)
    feedProgressBar:SetMinMaxValues(0, 1)
    feedProgressBar:SetValue(0)
    feedProgressBar:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    feedProgressBar:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    feedProgressBar:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)
    feedProgressBar:Hide()
    
    feedProgressBar.text = feedProgressBar:CreateFontString(nil, "OVERLAY")
    feedProgressBar.text:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
    feedProgressBar.text:SetPoint("CENTER", feedProgressBar, "CENTER", 0, 0)
    feedProgressBar.text:SetTextColor(1, 1, 1, 1)
    
    -- Apply initial style (must be after all UI elements are created)
    self:ApplyStyle()
    
    -- Update timer
    local updateTimer = 0
    local progressTimer = 0
    mainFrame:SetScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        progressTimer = progressTimer + elapsed
        
        if updateTimer >= 0.5 then
            updateTimer = 0
            HunterSuite:UpdatePetState()
            PetFeed:UpdateUI()
        end
        
        if progressTimer >= 0.1 then
            progressTimer = 0
            PetFeed:UpdateFeedProgress()
        end
    end)
    
    self.mainFrame = mainFrame
    self.happinessBar = happinessBar
    self.statusText = statusText
    self.feedButton = feedButton
    
    return mainFrame
end

-- Update the feed macro
function PetFeed:UpdateFeedMacro()
    if not feedButton or InCombatLockdown() then return end
    
    local food = HunterSuite.db.petFeed.autoSelectFood and HunterSuite:FindBestFood() or HunterSuite.state.selectedFood
    if food and HunterSuite.state.hasPet then
        local itemName = food.name or GetItemInfo(food.itemID)
        if itemName then
            feedButton:SetAttribute("macrotext1", "/cast Feed Pet \n/use " .. itemName)
        else
            feedButton:SetAttribute("macrotext1", "/cast Feed Pet")
        end
    else
        feedButton:SetAttribute("macrotext1", "/cast Feed Pet")
    end
end

-- Update UI based on pet state
function PetFeed:UpdateUI()
    if not mainFrame then return end
    
    -- Don't hide anything in edit mode
    if HunterSuite.state.editMode then
        mainFrame:Show()
        mainFrame:SetAlpha(1)
        return
    end
    
    local db = HunterSuite.db.petFeed
    
    if not db.enabled or not HunterSuite.state.isHunter then
        mainFrame:Hide()
        return
    end
    
    if not HunterSuite.state.hasPet then
        mainFrame:Hide()
        return
    end
    
    -- Check threshold - only show if happiness is at or below threshold (unless showAlways)
    local happiness = HunterSuite.state.happiness or 3
    if not db.showAlways and happiness > db.alertThreshold then
        mainFrame:Hide()
        return
    end
    
    mainFrame:Show()
    mainFrame:SetScale(db.scale)
    mainFrame:SetAlpha(db.alpha)
    
    local happiness = HunterSuite.state.happiness or 3
    local colors = HunterSuite.HAPPINESS_COLORS[happiness]
    local name = HunterSuite.HAPPINESS_NAMES[happiness]
    
    -- Apply style and update visuals
    self:ApplyStyle()
    
    -- Update icon border color in icon mode
    if db.style == "icon" then
        mainFrame:SetBackdropBorderColor(colors.r, colors.g, colors.b, 1)
        return
    end
    
    happinessBar:SetStatusBarColor(colors.r, colors.g, colors.b, 1)
    
    local barValue = happiness == 3 and 100 or (happiness == 2 and 66 or 33)
    happinessBar:SetValue(barValue)
    
    if db.showText then
        local petName = UnitName("pet") or "Pet"
        statusText:SetText(petName .. ": " .. name)
        statusText:Show()
    else
        statusText:Hide()
    end
    
    self:UpdateFeedMacro()
end

-- Update feed progress bar
function PetFeed:UpdateFeedProgress()
    if not feedProgressBar then return end
    
    if not UnitExists("pet") then
        feedProgressBar:Hide()
        return
    end
    
    local buffIndex = 1
    local buffName, _, _, _, duration, expirationTime = UnitBuff("pet", buffIndex)
    
    while buffName do
        if buffName == "Feed Pet Effect" then
            feedProgressBar:Show()
            local remainingTime = expirationTime - GetTime()
            if remainingTime > 0 and duration > 0 then
                feedProgressBar:SetMinMaxValues(0, duration)
                feedProgressBar:SetValue(remainingTime)
                feedProgressBar.text:SetText(string.format("%.1fs", remainingTime))
            else
                feedProgressBar:Hide()
            end
            return
        end
        buffIndex = buffIndex + 1
        buffName, _, _, _, duration, expirationTime = UnitBuff("pet", buffIndex)
    end
    
    feedProgressBar:Hide()
end

-- Show tooltip
function PetFeed:ShowTooltip(anchor)
    GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    
    local petName = UnitName("pet") or "Pet"
    GameTooltip:AddLine(petName, 1, 1, 1)
    
    local happiness = HunterSuite.state.happiness
    if happiness then
        local colors = HunterSuite.HAPPINESS_COLORS[happiness]
        local name = HunterSuite.HAPPINESS_NAMES[happiness]
        GameTooltip:AddLine("Mood: " .. name, colors.r, colors.g, colors.b)
        GameTooltip:AddLine("Damage: " .. (HunterSuite.state.damagePercent or 100) .. "%", 0.8, 0.8, 0.8)
    end
    
    local food = HunterSuite.db.petFeed.autoSelectFood and HunterSuite:FindBestFood() or HunterSuite.state.selectedFood
    if food then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Food: " .. (food.name or "Unknown"), 0.5, 1, 0.5)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click to feed", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click for settings", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag to move (when unlocked)", 0.7, 0.7, 0.7)
    
    GameTooltip:Show()
end

-- Apply style (bar or icon)
function PetFeed:ApplyStyle()
    if not mainFrame then return end
    
    local db = HunterSuite.db.petFeed
    local style = db.style or "bar"
    
    if style == "icon" then
        mainFrame:SetSize(32, 32)
        happinessBar:Hide()
        statusText:Hide()
        feedProgressBar:Hide()
        iconTexture:Show()
        
        -- Update icon border color based on happiness
        local happiness = HunterSuite.state.happiness or 3
        local colors = HunterSuite.HAPPINESS_COLORS[happiness]
        if colors then
            mainFrame:SetBackdropBorderColor(colors.r, colors.g, colors.b, 1)
        end
    else  -- "bar"
        mainFrame:SetSize(db.barWidth + 16, db.barHeight + 8)
        happinessBar:SetSize(db.barWidth - 8, db.barHeight - 4)
        happinessBar:Show()
        if db.showText then statusText:Show() end
        iconTexture:Hide()
        mainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
end

-- Initialize
function PetFeed:Init()
    self:CreateBar()
    self:UpdateUI()
end
