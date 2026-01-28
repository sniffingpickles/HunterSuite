-- HunterSuite Traps Module
-- Tracks trap placement and expiration

local Traps = {}
HunterSuite.Traps = Traps

-- Trap spell IDs (TBC)
local TRAP_SPELLS = {
    [1499] = "Freezing Trap",
    [14310] = "Freezing Trap",
    [14311] = "Freezing Trap",
    [13809] = "Frost Trap",
    [13795] = "Immolation Trap",
    [14302] = "Immolation Trap",
    [14303] = "Immolation Trap",
    [14304] = "Immolation Trap",
    [14305] = "Immolation Trap",
    [27023] = "Immolation Trap",
    [13813] = "Explosive Trap",
    [14316] = "Explosive Trap",
    [14317] = "Explosive Trap",
    [27025] = "Explosive Trap",
    [34600] = "Snake Trap",
}

-- Trap trigger spell IDs (for early detection)
local TRAP_EFFECTS = {
    ["Freezing Trap Effect"] = true,
    ["Frost Trap Aura"] = true,
    ["Immolation Trap"] = true,
    ["Explosive Trap Effect"] = true,
    ["Snake Trap Effect"] = true,
}

local trapFrame = nil
local trapBar = nil
local trapText = nil
local trapLabel = nil

local placedAt = 0
local trapName = nil
local trapState = "NONE"  -- NONE, ARMING, ACTIVE, TRIGGERED
local playerGUID = nil

-- Create the trap timer bar
function Traps:CreateBar()
    if trapFrame then return trapFrame end
    
    local db = HunterSuite.db.traps
    
    trapFrame = CreateFrame("Frame", "HunterSuiteTraps", UIParent, "BackdropTemplate")
    trapFrame:SetSize(160, 20)
    trapFrame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or -280)
    trapFrame:SetFrameStrata("MEDIUM")
    trapFrame:SetMovable(true)
    trapFrame:EnableMouse(true)
    trapFrame:RegisterForDrag("LeftButton")
    trapFrame:SetClampedToScreen(true)
    
    trapFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    trapFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    trapFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    -- Timer bar
    trapBar = CreateFrame("StatusBar", nil, trapFrame, "BackdropTemplate")
    trapBar:SetSize(152, 12)
    trapBar:SetPoint("CENTER", trapFrame, "CENTER", 0, 0)
    trapBar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
    trapBar:SetStatusBarColor(0.4, 0.7, 0.9, 1)
    trapBar:SetMinMaxValues(0, 60)
    trapBar:SetValue(60)
    
    trapBar:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
    })
    trapBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    -- Label
    trapLabel = trapBar:CreateFontString(nil, "OVERLAY")
    trapLabel:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    trapLabel:SetPoint("LEFT", trapBar, "LEFT", 4, 0)
    trapLabel:SetText("Trap")
    trapLabel:SetTextColor(0.7, 0.9, 1, 1)
    
    -- Time text
    trapText = trapBar:CreateFontString(nil, "OVERLAY")
    trapText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    trapText:SetPoint("RIGHT", trapBar, "RIGHT", -4, 0)
    trapText:SetTextColor(1, 1, 1, 1)
    
    -- Dragging (only in edit mode)
    trapFrame:SetScript("OnDragStart", function(self)
        if HunterSuite.state.editMode then
            self:StartMoving()
        end
    end)
    trapFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HunterSuite.db.traps.position.point = point
        HunterSuite.db.traps.position.x = x
        HunterSuite.db.traps.position.y = y
    end)
    
    -- Update loop
    trapFrame:SetScript("OnUpdate", function(self, elapsed)
        Traps:OnUpdate(elapsed)
    end)
    
    trapFrame:Hide()
    
    -- Register events
    trapFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    trapFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    trapFrame:RegisterEvent("PLAYER_LOGIN")
    trapFrame:SetScript("OnEvent", function(self, event, ...)
        Traps:OnEvent(event, ...)
    end)
    
    self.trapFrame = trapFrame
    return trapFrame
end

-- Handle events
function Traps:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        local spellId = select(3, ...)
        
        if unit == "player" and TRAP_SPELLS[spellId] then
            placedAt = GetTime()
            trapName = TRAP_SPELLS[spellId]
            trapState = "ARMING"
            self:UpdateUI()
        end
        
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if trapState == "NONE" then return end
        
        local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
        
        -- Check if our trap triggered
        if sourceGUID == playerGUID then
            if (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_DAMAGE") then
                if TRAP_EFFECTS[spellName] or (trapName and spellName and spellName:find(trapName)) then
                    trapState = "TRIGGERED"
                    -- Show triggered briefly then hide
                    C_Timer.After(2, function()
                        if trapState == "TRIGGERED" then
                            trapState = "NONE"
                            self:UpdateUI()
                        end
                    end)
                end
            end
        end
    end
end

-- OnUpdate handler
function Traps:OnUpdate(elapsed)
    if not trapFrame:IsShown() then return end
    
    local db = HunterSuite.db.traps
    
    -- Edit mode - show sample
    if HunterSuite.state.editMode then
        trapBar:SetMinMaxValues(0, 60)
        trapBar:SetValue(45)
        trapLabel:SetText("Freezing Trap")
        trapText:SetText("45s")
        trapBar:SetStatusBarColor(0.4, 0.7, 0.9, 1)
        return
    end
    
    if trapState == "NONE" then
        trapFrame:Hide()
        return
    end
    
    local elapsed = GetTime() - placedAt
    local armingTime = db.armingTime or 2.0
    local duration = db.duration or 60
    
    if trapState == "ARMING" then
        if elapsed >= armingTime then
            trapState = "ACTIVE"
        else
            -- Arming phase
            trapBar:SetMinMaxValues(0, armingTime)
            trapBar:SetValue(elapsed)
            trapLabel:SetText(trapName or "Trap")
            trapText:SetText("ARMING")
            trapBar:SetStatusBarColor(1, 0.7, 0.2, 1)  -- Orange
            return
        end
    end
    
    if trapState == "ACTIVE" then
        local remaining = duration - elapsed
        if remaining <= 0 then
            trapState = "NONE"
            trapFrame:Hide()
            return
        end
        
        trapBar:SetMinMaxValues(0, duration)
        trapBar:SetValue(remaining)
        trapLabel:SetText(trapName or "Trap")
        trapText:SetText(string.format("%.0fs", remaining))
        
        -- Color based on remaining time
        if remaining <= 10 then
            trapBar:SetStatusBarColor(0.9, 0.3, 0.3, 1)  -- Red
        elseif remaining <= 20 then
            trapBar:SetStatusBarColor(1, 0.7, 0.2, 1)  -- Orange
        else
            trapBar:SetStatusBarColor(0.4, 0.7, 0.9, 1)  -- Blue
        end
    end
    
    if trapState == "TRIGGERED" then
        trapBar:SetMinMaxValues(0, 1)
        trapBar:SetValue(1)
        trapLabel:SetText(trapName or "Trap")
        trapText:SetText("TRIGGERED!")
        trapBar:SetStatusBarColor(0.2, 0.9, 0.3, 1)  -- Green
    end
end

-- Update visibility
function Traps:UpdateUI()
    if not trapFrame then return end
    
    local db = HunterSuite.db.traps
    
    if not db.enabled or not HunterSuite.state.isHunter then
        trapFrame:Hide()
        return
    end
    
    trapFrame:SetScale(db.scale or 1)
    trapFrame:SetAlpha(db.alpha or 1)
    
    if trapState ~= "NONE" or HunterSuite.state.editMode then
        trapFrame:Show()
    elseif db.hideWhenInactive then
        trapFrame:Hide()
    end
end

-- Initialize
function Traps:Init()
    self:CreateBar()
end
