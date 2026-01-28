--[[
    HunterSuite - Aspect Reminder Module
    Alerts when no aspect is active
]]

local addonName, HunterSuite = ...

HunterSuite.Aspects = {}
local Aspects = HunterSuite.Aspects

-- Aspect spell names (TBC)
local ASPECT_SPELLS = {
    "Aspect of the Hawk",
    "Aspect of the Monkey",
    "Aspect of the Cheetah",
    "Aspect of the Pack",
    "Aspect of the Beast",
    "Aspect of the Wild",
    "Aspect of the Viper",
}

-- Local references
local alertFrame = nil
local alertText = nil
local pulseAnim = nil
local hasAspect = false
local lastCheck = 0

-- Create the alert frame
function Aspects:CreateAlert()
    if alertFrame then return alertFrame end
    
    local db = HunterSuite.db.aspects
    
    alertFrame = CreateFrame("Frame", "HunterSuiteAspectAlert", UIParent, "BackdropTemplate")
    alertFrame:SetSize(200, 30)
    alertFrame:SetPoint(db.position.point or "TOP", UIParent, db.position.point or "TOP", db.position.x or 0, db.position.y or -100)
    alertFrame:SetFrameStrata("HIGH")
    alertFrame:SetMovable(true)
    alertFrame:EnableMouse(true)
    alertFrame:RegisterForDrag("LeftButton")
    alertFrame:SetClampedToScreen(true)
    
    alertFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    alertFrame:SetBackdropColor(0.6, 0.1, 0.1, 0.9)
    alertFrame:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    
    -- Alert text
    local db = HunterSuite.db.aspects
    alertText = alertFrame:CreateFontString(nil, "OVERLAY")
    alertText:SetFont(STANDARD_TEXT_FONT, db.fontSize or 14, "OUTLINE")
    alertText:SetPoint("CENTER", alertFrame, "CENTER", 0, 0)
    alertText:SetText(db.alertText or "NO ASPECT!")
    alertText:SetTextColor(1, 1, 0.3, 1)
    
    -- Pulse animation
    local ag = alertFrame:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    
    local fade1 = ag:CreateAnimation("Alpha")
    fade1:SetFromAlpha(1)
    fade1:SetToAlpha(0.5)
    fade1:SetDuration(0.5)
    fade1:SetOrder(1)
    
    local fade2 = ag:CreateAnimation("Alpha")
    fade2:SetFromAlpha(0.5)
    fade2:SetToAlpha(1)
    fade2:SetDuration(0.5)
    fade2:SetOrder(2)
    
    pulseAnim = ag
    
    -- Dragging (only in edit mode)
    alertFrame:SetScript("OnDragStart", function(self)
        if HunterSuite.state.editMode then
            self:StartMoving()
        end
    end)
    alertFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HunterSuite.db.aspects.position.point = point
        HunterSuite.db.aspects.position.x = x
        HunterSuite.db.aspects.position.y = y
    end)
    
    -- Click to dismiss temporarily
    alertFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            self:Hide()
            C_Timer.After(30, function()
                Aspects:CheckAspect()
            end)
        end
    end)
    
    -- Tooltip
    alertFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Aspect Reminder", 1, 1, 1)
        GameTooltip:AddLine("You don't have an aspect active!", 1, 0.5, 0.5)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Right-click to dismiss for 30s", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    alertFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    alertFrame:Hide()
    
    -- Register events
    alertFrame:RegisterEvent("UNIT_AURA")
    alertFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    alertFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    alertFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    
    alertFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_AURA" then
            local unit = ...
            if unit == "player" then
                Aspects:CheckAspect()
            end
        else
            Aspects:CheckAspect()
        end
    end)
    
    self.alertFrame = alertFrame
    
    return alertFrame
end

-- Check if player has an aspect active
function Aspects:HasAspect()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        
        for _, aspect in ipairs(ASPECT_SPELLS) do
            if name == aspect then
                return true, name
            end
        end
    end
    return false, nil
end

-- Check and update alert
function Aspects:CheckAspect()
    if not alertFrame then return end
    
    -- In edit mode, show the alert for positioning
    if HunterSuite.state.editMode then
        alertFrame:Show()
        alertFrame:SetAlpha(0.8)
        if pulseAnim then pulseAnim:Stop() end
        return
    end
    
    local db = HunterSuite.db.aspects
    
    if not db.enabled or not HunterSuite.state.isHunter then
        alertFrame:Hide()
        return
    end
    
    -- Only alert in combat or when configured
    local inCombat = UnitAffectingCombat("player")
    if db.onlyInCombat and not inCombat then
        alertFrame:Hide()
        return
    end
    
    hasAspect, _ = self:HasAspect()
    
    if hasAspect then
        alertFrame:Hide()
        pulseAnim:Stop()
    else
        alertFrame:Show()
        pulseAnim:Play()
    end
end

-- Update UI
function Aspects:UpdateUI()
    if not alertFrame then return end
    
    local db = HunterSuite.db.aspects
    alertFrame:SetScale(db.scale or 1)
    alertFrame:SetAlpha(db.alpha or 1)
    
    self:CheckAspect()
end

-- Initialize
function Aspects:Init()
    self:CreateAlert()
    self:CheckAspect()
end
