-- HunterSuite Stings Module
-- Serpent Sting nameplate timer

local Stings = {}
HunterSuite.Stings = Stings

local SERPENT_STING = "Serpent Sting"
local nameplateFrames = {}  -- unitToken -> frame
local lastUpdate = 0

local eventFrame = nil

-- Create a sting indicator for a nameplate
function Stings:CreateNameplateIndicator(nameplate, unitToken)
    local db = HunterSuite.db.stings
    
    local frame = CreateFrame("Frame", nil, nameplate, "BackdropTemplate")
    frame:SetSize((db.iconSize or 14) + 40, (db.iconSize or 14) + 4)
    frame:SetPoint("BOTTOM", nameplate, "TOP", 0, 2)
    frame:SetFrameStrata("HIGH")
    
    frame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.1, 0.4, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.2, 0.6, 0.2, 1)
    
    -- Icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(db.iconSize or 14, db.iconSize or 14)
    icon:SetPoint("LEFT", frame, "LEFT", 2, 0)
    icon:SetTexture([[Interface\Icons\Ability_Hunter_Quickshot]])
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon
    
    -- Timer text
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, db.textSize or 10, "OUTLINE")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetTextColor(1, 1, 1, 1)
    frame.text = text
    
    frame.unitToken = unitToken
    frame:Hide()
    
    return frame
end

-- Get or create indicator for a nameplate
function Stings:GetIndicator(nameplate, unitToken)
    if nameplateFrames[unitToken] then
        return nameplateFrames[unitToken]
    end
    
    local frame = self:CreateNameplateIndicator(nameplate, unitToken)
    nameplateFrames[unitToken] = frame
    return frame
end

-- Check for Serpent Sting on a unit
function Stings:CheckUnit(unitToken)
    if not unitToken or not UnitExists(unitToken) then return nil, nil end
    
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source = UnitDebuff(unitToken, i)
        if not name then break end
        
        if name == SERPENT_STING and source == "player" then
            return expirationTime, duration, icon
        end
    end
    
    return nil, nil
end

-- Update a specific nameplate indicator
function Stings:UpdateNameplate(unitToken)
    local db = HunterSuite.db.stings
    
    if not db.enabled or not db.showOnNameplates then return end
    
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitToken)
    if not nameplate then
        if nameplateFrames[unitToken] then
            nameplateFrames[unitToken]:Hide()
        end
        return
    end
    
    local expirationTime, duration, icon = self:CheckUnit(unitToken)
    
    if expirationTime and duration then
        local frame = self:GetIndicator(nameplate, unitToken)
        local remaining = expirationTime - GetTime()
        
        if remaining > 0 then
            if icon then frame.icon:SetTexture(icon) end
            frame.text:SetText(string.format("%.1fs", remaining))
            frame:Show()
        else
            frame:Hide()
        end
    else
        if nameplateFrames[unitToken] then
            nameplateFrames[unitToken]:Hide()
        end
    end
end

-- Handle events
function Stings:OnEvent(event, ...)
    local db = HunterSuite.db.stings
    
    if not db.enabled or not HunterSuite.state.isHunter then return end
    
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unitToken = ...
        self:UpdateNameplate(unitToken)
        
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unitToken = ...
        if nameplateFrames[unitToken] then
            nameplateFrames[unitToken]:Hide()
            nameplateFrames[unitToken] = nil
        end
        
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit and unit:match("^nameplate") then
            self:UpdateNameplate(unit)
        end
    end
end

-- Throttled update for all visible nameplates
function Stings:OnUpdate(elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < 0.1 then return end
    lastUpdate = 0
    
    local db = HunterSuite.db.stings
    if not db.enabled or not db.showOnNameplates then return end
    
    -- Update all visible nameplate timers
    for unitToken, frame in pairs(nameplateFrames) do
        if frame:IsShown() then
            local expirationTime = self:CheckUnit(unitToken)
            if expirationTime then
                local remaining = expirationTime - GetTime()
                if remaining > 0 then
                    frame.text:SetText(string.format("%.1fs", remaining))
                else
                    frame:Hide()
                end
            else
                frame:Hide()
            end
        end
    end
end

-- Update visibility
function Stings:UpdateUI()
    -- Refresh all nameplates
    local db = HunterSuite.db.stings
    
    if not db.enabled or not HunterSuite.state.isHunter then
        for _, frame in pairs(nameplateFrames) do
            frame:Hide()
        end
        return
    end
end

-- Initialize
function Stings:Init()
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        Stings:OnEvent(event, ...)
    end)
    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        Stings:OnUpdate(elapsed)
    end)
    
    self.eventFrame = eventFrame
end
