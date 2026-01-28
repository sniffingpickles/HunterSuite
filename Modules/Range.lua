-- HunterSuite Range Module
-- Shows range indicator with dead zone detection

local Range = {}
HunterSuite.Range = Range

local rangeFrame = nil
local rangeText = nil
local lastUpdate = 0

local RANGE_STATE = {
    NONE = 0,
    IN_RANGE = 1,
    OUT_OF_RANGE = 2,
    DEAD_ZONE = 3,
}

local currentState = RANGE_STATE.NONE

-- Create the range indicator
function Range:CreateIndicator()
    if rangeFrame then return rangeFrame end
    
    local db = HunterSuite.db.range
    
    rangeFrame = CreateFrame("Frame", "HunterSuiteRange", UIParent, "BackdropTemplate")
    rangeFrame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 120, db.position.y or -240)
    rangeFrame:SetFrameStrata("MEDIUM")
    rangeFrame:SetMovable(true)
    rangeFrame:EnableMouse(true)
    rangeFrame:RegisterForDrag("LeftButton")
    rangeFrame:SetClampedToScreen(true)
    
    rangeFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    rangeFrame:SetBackdropColor(0.2, 0.7, 0.2, 0.9)
    rangeFrame:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
    
    rangeText = rangeFrame:CreateFontString(nil, "OVERLAY")
    rangeText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    rangeText:SetPoint("CENTER", rangeFrame, "CENTER", 0, 0)
    rangeText:SetText("IN RANGE")
    rangeText:SetTextColor(1, 1, 1, 1)
    
    -- Apply initial style
    self:ApplyStyle()
    
    -- Dragging (only in edit mode)
    rangeFrame:SetScript("OnDragStart", function(self)
        if HunterSuite.state.editMode then
            self:StartMoving()
        end
    end)
    rangeFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HunterSuite.db.range.position.point = point
        HunterSuite.db.range.position.x = x
        HunterSuite.db.range.position.y = y
    end)
    
    -- Throttled update
    rangeFrame:SetScript("OnUpdate", function(self, elapsed)
        -- Skip updates in edit mode - keep showing
        if HunterSuite.state and HunterSuite.state.editMode then
            rangeFrame:Show()
            return
        end
        
        lastUpdate = lastUpdate + elapsed
        local updateInterval = 1 / (HunterSuite.db.range.updateHz or 10)
        if lastUpdate >= updateInterval then
            lastUpdate = 0
            Range:CheckRange()
        end
    end)
    
    rangeFrame:Hide()
    
    self.rangeFrame = rangeFrame
    return rangeFrame
end

-- Check range to target
function Range:CheckRange()
    if not rangeFrame then return end
    
    local db = HunterSuite.db.range
    
    -- Edit mode - show sample
    if HunterSuite.state.editMode then
        rangeFrame:Show()
        self:SetState(RANGE_STATE.IN_RANGE)
        return
    end
    
    if not db.enabled or not HunterSuite.state.isHunter then
        rangeFrame:Hide()
        return
    end
    
    -- Check if we have a valid hostile target
    local hasValidTarget = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
    
    if not hasValidTarget then
        if db.showAlways then
            -- Show with "no target" state
            self:SetState(RANGE_STATE.NONE)
            rangeFrame:Show()
        else
            rangeFrame:Hide()
            currentState = RANGE_STATE.NONE
        end
        return
    end
    
    -- TBC Anniversary: Use CheckInteractDistance for range detection
    -- Distance 1 = 10 yards (inspect), 2 = 11.11 yards (trade), 3 = 9.9 yards (duel), 4 = 28 yards (follow)
    local inMeleeRange = CheckInteractDistance("target", 3)  -- ~10 yards (melee/dead zone)
    local inRangedRange = CheckInteractDistance("target", 4)  -- ~28 yards (within follow range)
    
    -- For more accuracy, also check if we're beyond melee but can still shoot
    -- Dead zone in TBC is roughly 5-8 yards (too close for ranged, too far for melee)
    -- We approximate: melee < 8yd, dead zone 8-8yd (tiny), ranged 8-35yd
    
    -- Determine state based on distance checks
    if inMeleeRange then
        -- Very close - could be dead zone or melee range
        -- CheckInteractDistance(3) is ~10yd, so if we're this close, we're in dead zone territory
        self:SetState(RANGE_STATE.DEAD_ZONE)
    elseif inRangedRange then
        -- Within 28 yards but not in melee - good ranged distance
        self:SetState(RANGE_STATE.IN_RANGE)
    else
        -- Too far
        self:SetState(RANGE_STATE.OUT_OF_RANGE)
    end
    
    rangeFrame:Show()
end

-- Set visual state
function Range:SetState(state)
    if not rangeFrame then return end
    
    currentState = state
    
    if state == RANGE_STATE.IN_RANGE then
        rangeFrame:SetBackdropColor(0.2, 0.7, 0.2, 0.9)
        rangeFrame:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
        rangeText:SetText("IN RANGE")
    elseif state == RANGE_STATE.OUT_OF_RANGE then
        rangeFrame:SetBackdropColor(0.7, 0.2, 0.2, 0.9)
        rangeFrame:SetBackdropBorderColor(0.8, 0.3, 0.3, 1)
        rangeText:SetText("TOO FAR")
    elseif state == RANGE_STATE.DEAD_ZONE then
        rangeFrame:SetBackdropColor(0.6, 0.2, 0.6, 0.9)
        rangeFrame:SetBackdropBorderColor(0.7, 0.3, 0.7, 1)
        rangeText:SetText("DEAD ZONE")
    elseif state == RANGE_STATE.NONE then
        rangeFrame:SetBackdropColor(0.3, 0.3, 0.3, 0.7)
        rangeFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        rangeText:SetText("NO TARGET")
    end
end

-- Apply style (text or dot)
function Range:ApplyStyle()
    if not rangeFrame then return end
    
    local db = HunterSuite.db.range
    local style = db.style or "text"
    
    if style == "dot" then
        rangeFrame:SetSize(16, 16)
        rangeText:Hide()
    else  -- "text"
        rangeFrame:SetSize(70, 20)
        rangeText:Show()
    end
    
    -- Re-apply current state visuals
    self:SetState(currentState)
end

-- Update visibility
function Range:UpdateUI()
    if not rangeFrame then return end
    
    local db = HunterSuite.db.range
    
    if not db.enabled or not HunterSuite.state.isHunter then
        rangeFrame:Hide()
        return
    end
    
    rangeFrame:SetScale(db.scale or 1)
    rangeFrame:SetAlpha(db.alpha or 1)
    self:ApplyStyle()
    
    self:CheckRange()
end

-- Initialize
function Range:Init()
    self:CreateIndicator()
end
