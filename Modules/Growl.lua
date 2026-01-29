--[[
    HunterSuite - Growl Reminder Module
    Alerts when entering a dungeon/raid with pet taunt (Growl) enabled
]]

local addonName, HunterSuite = ...

HunterSuite.Growl = {}
local Growl = HunterSuite.Growl

-- Local references
local alertFrame = nil
local alertText = nil
local pulseAnim = nil
local isInInstance = false
local growlEnabled = false

-- Create the alert frame
function Growl:CreateAlert()
    if alertFrame then return alertFrame end
    
    local db = HunterSuite.db.growl
    
    alertFrame = CreateFrame("Frame", "HunterSuiteGrowlAlert", UIParent, "BackdropTemplate")
    alertFrame:SetSize(220, 30)
    alertFrame:SetPoint(db.position.point or "TOP", UIParent, db.position.point or "TOP", db.position.x or 0, db.position.y or -140)
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
    alertFrame:SetBackdropColor(0.7, 0.4, 0.1, 0.9)
    alertFrame:SetBackdropBorderColor(0.9, 0.5, 0.1, 1)
    
    -- Alert text
    local db = HunterSuite.db.growl
    alertText = alertFrame:CreateFontString(nil, "OVERLAY")
    alertText:SetFont(STANDARD_TEXT_FONT, db.fontSize or 14, "OUTLINE")
    alertText:SetPoint("CENTER", alertFrame, "CENTER", 0, 0)
    alertText:SetText(db.alertText or "GROWL ON!")
    alertText:SetTextColor(1, 1, 0.3, 1)
    
    -- Pulse animation
    local ag = alertFrame:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    
    local fade1 = ag:CreateAnimation("Alpha")
    fade1:SetFromAlpha(1)
    fade1:SetToAlpha(0.5)
    fade1:SetDuration(0.6)
    fade1:SetOrder(1)
    
    local fade2 = ag:CreateAnimation("Alpha")
    fade2:SetFromAlpha(0.5)
    fade2:SetToAlpha(1)
    fade2:SetDuration(0.6)
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
        HunterSuite.db.growl.position.point = point
        HunterSuite.db.growl.position.x = x
        HunterSuite.db.growl.position.y = y
    end)
    
    -- Click to dismiss
    alertFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            self:Hide()
            -- Remind again when zone changes
        elseif button == "LeftButton" then
            -- Try to toggle Growl off (show pet spellbook)
            ToggleSpellBook(BOOKTYPE_PET)
        end
    end)
    
    -- Tooltip
    alertFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Growl Reminder", 1, 1, 1)
        GameTooltip:AddLine("Your pet's Growl (taunt) is enabled!", 1, 0.5, 0.3)
        GameTooltip:AddLine("This may cause issues in groups.", 1, 0.5, 0.3)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to open Pet Spellbook", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click to dismiss", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    alertFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    alertFrame:Hide()
    
    -- Register events
    alertFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    alertFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    alertFrame:RegisterEvent("ZONE_CHANGED")
    alertFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    alertFrame:RegisterEvent("PET_BAR_UPDATE")
    alertFrame:RegisterEvent("UNIT_PET")
    alertFrame:RegisterEvent("SPELL_UPDATE_USABLE")
    
    alertFrame:SetScript("OnEvent", function(self, event, ...)
        Growl:CheckGrowl()
    end)
    
    self.alertFrame = alertFrame
    
    return alertFrame
end

-- Check if Growl is enabled on the pet bar
function Growl:IsGrowlEnabled()
    if not HasPetUI() then return false end
    
    -- Check pet action bar for Growl
    for i = 1, NUM_PET_ACTION_SLOTS do
        local name, _, _, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(i)
        
        -- Growl is typically the taunt ability
        if name then
            local spellName = isToken and _G[name] or name
            if spellName == "Growl" then
                -- autoCastAllowed indicates if autocast is toggled ON
                -- autoCastEnabled returns spell ID (truthy) even when off
                return autoCastAllowed == true
            end
        end
    end
    
    return false
end

-- Check if we're in an instance
function Growl:IsInGroupInstance()
    local inInstance, instanceType = IsInInstance()
    
    if inInstance then
        if instanceType == "party" or instanceType == "raid" then
            return true
        end
    end
    
    return false
end

-- Main check function
function Growl:CheckGrowl()
    if not alertFrame then return end
    
    -- In edit mode, show the alert for positioning
    if HunterSuite.state.editMode then
        alertFrame:Show()
        alertFrame:SetAlpha(0.8)
        if pulseAnim then pulseAnim:Stop() end
        return
    end
    
    local db = HunterSuite.db.growl
    
    if not db.enabled or not HunterSuite.state.isHunter then
        alertFrame:Hide()
        return
    end
    
    if not HunterSuite.state.hasPet then
        alertFrame:Hide()
        return
    end
    
    isInInstance = self:IsInGroupInstance()
    growlEnabled = self:IsGrowlEnabled()
    
    -- Only alert if in instance AND growl is enabled
    if isInInstance and growlEnabled then
        alertFrame:Show()
        pulseAnim:Play()
    else
        alertFrame:Hide()
        pulseAnim:Stop()
    end
end

-- Update UI
function Growl:UpdateUI()
    if not alertFrame then return end
    
    local db = HunterSuite.db.growl
    alertFrame:SetScale(db.scale or 1)
    alertFrame:SetAlpha(db.alpha or 1)
    
    self:CheckGrowl()
end

-- Initialize
function Growl:Init()
    self:CreateAlert()
    
    -- Delay initial check
    C_Timer.After(2, function()
        Growl:CheckGrowl()
    end)
end
