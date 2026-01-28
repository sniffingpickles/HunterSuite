-- HunterSuite Tracking Module
-- Track Humanoids reminder for BGs

local Tracking = {}
HunterSuite.Tracking = Tracking

local trackingFrame = nil
local trackingText = nil
local trackBtn = nil
local lastRemind = 0

-- Create the tracking reminder
function Tracking:CreateReminder()
    if trackingFrame then return trackingFrame end
    
    local db = HunterSuite.db.tracking
    
    trackingFrame = CreateFrame("Frame", "HunterSuiteTracking", UIParent, "BackdropTemplate")
    trackingFrame:SetSize(160, 28)
    trackingFrame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or 160)
    trackingFrame:SetFrameStrata("HIGH")
    trackingFrame:SetMovable(true)
    trackingFrame:EnableMouse(true)
    trackingFrame:RegisterForDrag("LeftButton")
    trackingFrame:SetClampedToScreen(true)
    
    trackingFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    trackingFrame:SetBackdropColor(0.5, 0.3, 0.6, 0.95)
    trackingFrame:SetBackdropBorderColor(0.6, 0.4, 0.7, 1)
    
    trackingText = trackingFrame:CreateFontString(nil, "OVERLAY")
    trackingText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    trackingText:SetPoint("LEFT", trackingFrame, "LEFT", 8, 0)
    trackingText:SetText("Track Humanoids!")
    trackingText:SetTextColor(1, 1, 0.3, 1)
    
    -- Secure button for tracking
    trackBtn = CreateFrame("Button", "HunterSuiteTrackBtn", trackingFrame, "SecureActionButtonTemplate, BackdropTemplate")
    trackBtn:SetSize(50, 20)
    trackBtn:SetPoint("RIGHT", trackingFrame, "RIGHT", -4, 0)
    trackBtn:SetAttribute("type", "spell")
    trackBtn:SetAttribute("spell", "Track Humanoids")
    
    trackBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    trackBtn:SetBackdropColor(0.3, 0.5, 0.3, 1)
    trackBtn:SetBackdropBorderColor(0.4, 0.6, 0.4, 1)
    
    local btnText = trackBtn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    btnText:SetPoint("CENTER")
    btnText:SetText("Track")
    btnText:SetTextColor(1, 1, 1, 1)
    
    trackBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.4, 0.6, 0.4, 1)
    end)
    trackBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.3, 0.5, 0.3, 1)
    end)
    
    -- Dragging
    trackingFrame:SetScript("OnDragStart", function(self)
        if not HunterSuite.db.tracking.locked then
            self:StartMoving()
        end
    end)
    trackingFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HunterSuite.db.tracking.position.point = point
        HunterSuite.db.tracking.position.x = x
        HunterSuite.db.tracking.position.y = y
    end)
    
    -- Right click to dismiss
    trackingFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            self:Hide()
            lastRemind = GetTime()
        end
    end)
    
    trackingFrame:Hide()
    
    -- Register events
    trackingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    trackingFrame:RegisterEvent("MINIMAP_UPDATE_TRACKING")
    trackingFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    trackingFrame:SetScript("OnEvent", function(self, event, ...)
        Tracking:OnEvent(event, ...)
    end)
    
    self.trackingFrame = trackingFrame
    return trackingFrame
end

-- Check if in battleground
function Tracking:IsInBattleground()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

-- Check current tracking
function Tracking:IsTrackingHumanoids()
    -- Try modern API first
    if C_Minimap and C_Minimap.GetNumTrackingTypes then
        for i = 1, C_Minimap.GetNumTrackingTypes() do
            local info = C_Minimap.GetTrackingInfo(i)
            if info and info.active and info.name == "Track Humanoids" then
                return true
            end
        end
    else
        -- Fallback to older API
        for i = 1, GetNumTrackingTypes() do
            local name, _, active = GetTrackingInfo(i)
            if active and name == "Track Humanoids" then
                return true
            end
        end
    end
    return false
end

-- Handle events
function Tracking:OnEvent(event, ...)
    self:CheckTracking()
end

-- Check tracking and show reminder if needed
function Tracking:CheckTracking()
    if not trackingFrame then return end
    
    local db = HunterSuite.db.tracking
    
    if not db.enabled or not HunterSuite.state.isHunter then
        trackingFrame:Hide()
        return
    end
    
    -- Edit mode - show sample
    if HunterSuite.state.editMode then
        trackingFrame:Show()
        return
    end
    
    -- Only show in BG if configured
    if db.bgOnly and not self:IsInBattleground() then
        trackingFrame:Hide()
        return
    end
    
    -- Throttle reminders
    local remindInterval = db.remindInterval or 30
    if GetTime() - lastRemind < remindInterval then
        return
    end
    
    -- Check if tracking humanoids
    if self:IsTrackingHumanoids() then
        trackingFrame:Hide()
    else
        trackingFrame:Show()
        lastRemind = GetTime()
    end
end

-- Update visibility
function Tracking:UpdateUI()
    if not trackingFrame then return end
    
    local db = HunterSuite.db.tracking
    
    if not db.enabled or not HunterSuite.state.isHunter then
        trackingFrame:Hide()
        return
    end
    
    trackingFrame:SetScale(db.scale or 1)
    trackingFrame:SetAlpha(db.alpha or 1)
    
    if HunterSuite.state.editMode then
        trackingFrame:Show()
    else
        self:CheckTracking()
    end
end

-- Initialize
function Tracking:Init()
    self:CreateReminder()
end
