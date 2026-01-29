-- HunterSuite Range Module
-- Range indicator using LibRangeCheck-3.0

local Range = {}
HunterSuite.Range = Range

-- Get the library
local rc = LibStub("LibRangeCheck-3.0")

local rangeFrame = nil
local rangeText = nil
local lastUpdate = 0

local currentMinRange = nil
local currentMaxRange = nil

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

-- Check range to target using LibRangeCheck-3.0
function Range:CheckRange()
    if not rangeFrame then return end
    
    local db = HunterSuite.db.range
    
    -- Edit mode - show sample
    if HunterSuite.state.editMode then
        rangeFrame:Show()
        currentMinRange = 15
        currentMaxRange = 25
        self:UpdateDisplay()
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
            currentMinRange = nil
            currentMaxRange = nil
            self:UpdateDisplay()
            rangeFrame:Show()
        else
            rangeFrame:Hide()
        end
        return
    end
    
    -- Get range from LibRangeCheck-3.0
    currentMinRange, currentMaxRange = rc:GetRange("target")
    self:UpdateDisplay()
    rangeFrame:Show()
end

-- Update display based on range
function Range:UpdateDisplay()
    if not rangeFrame then return end
    
    local db = HunterSuite.db.range
    local style = db.style or "text"
    
    local r, g, b = 1, 1, 1
    local text = ""
    
    if currentMinRange == nil and currentMaxRange == nil then
        -- No target
        r, g, b = 0.5, 0.5, 0.5  -- Gray
        text = "NO TARGET"
    elseif currentMinRange and currentMinRange < 8 then
        -- Dead zone (too close for ranged)
        r, g, b = 0.8, 0.2, 0.8  -- Purple
        text = "DEAD ZONE"
    elseif currentMaxRange and currentMaxRange <= 35 then
        -- In ranged attack range (good!)
        r, g, b = 0.2, 0.9, 0.2  -- Green
        if currentMinRange and currentMaxRange then
            text = string.format("%d - %d", currentMinRange, currentMaxRange)
        else
            text = "IN RANGE"
        end
    elseif currentMinRange and currentMinRange >= 35 then
        -- Too far
        r, g, b = 0.9, 0.2, 0.2  -- Red
        text = "TOO FAR"
    else
        -- Unknown/transitional
        r, g, b = 1.0, 0.8, 0.0  -- Yellow
        if currentMinRange and currentMaxRange then
            text = string.format("%d - %d", currentMinRange, currentMaxRange)
        elseif currentMinRange then
            text = string.format("%d+", currentMinRange)
        else
            text = "???"
        end
    end
    
    -- Set colors
    rangeFrame:SetBackdropColor(r * 0.3, g * 0.3, b * 0.3, 0.9)
    rangeFrame:SetBackdropBorderColor(r * 0.5, g * 0.5, b * 0.5, 1)
    rangeText:SetTextColor(r, g, b, 1)
    
    -- Set text
    if style == "dot" then
        rangeText:Hide()
    else
        rangeText:Show()
        rangeText:SetText(text)
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
        rangeFrame:SetSize(80, 22)  -- Slightly wider for "XX - XX" format
        rangeText:Show()
    end
    
    -- Re-apply current display
    self:UpdateDisplay()
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
