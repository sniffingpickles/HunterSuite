-- HunterSuite AutoMark Module
-- Auto-mark enemy warlock/hunter pets with skull

local AutoMark = {}
HunterSuite.AutoMark = AutoMark

local markedGUIDs = {}  -- GUID -> lastMarkTime cache
local eventFrame = nil

-- Create event frame
function AutoMark:CreateEventFrame()
    if eventFrame then return eventFrame end
    
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        AutoMark:OnEvent(event, ...)
    end)
    
    self.eventFrame = eventFrame
    return eventFrame
end

-- Check if in PVP instance
function AutoMark:IsInPVPInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

-- Check if we can mark (leader/assist in raid, or not in raid)
function AutoMark:CanMark()
    if UnitInRaid("player") then
        return IsRaidLeader() or IsRaidOfficer()
    end
    return true  -- In party or solo, anyone can mark
end

-- Try to mark a unit as skull
function AutoMark:TryMarkUnit(unit)
    if not unit or not UnitExists(unit) then return end
    
    local db = HunterSuite.db.autoMark
    
    if not db.enabled then return end
    
    -- Check PVP instance requirement
    if db.onlyInPVPInstances and not self:IsInPVPInstance() then
        return
    end
    
    -- Check if it's another player's pet
    if not UnitIsOtherPlayersPet(unit) then return end
    
    -- Check if hostile
    if not UnitCanAttack("player", unit) then return end
    
    -- Check if we can mark
    if not self:CanMark() then return end
    
    -- Get GUID for throttle check
    local guid = UnitGUID(unit)
    if not guid then return end
    
    -- Throttle check
    local throttle = db.throttleSeconds or 10
    local lastMark = markedGUIDs[guid]
    if lastMark and (GetTime() - lastMark) < throttle then
        return
    end
    
    -- Check if already marked with skull
    if GetRaidTargetIndex(unit) == 8 then return end
    
    -- Mark with skull
    SetRaidTarget(unit, 8)
    markedGUIDs[guid] = GetTime()
end

-- Handle events
function AutoMark:OnEvent(event, ...)
    local db = HunterSuite.db.autoMark
    
    if not db.enabled or not HunterSuite.state.isHunter then return end
    
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        self:TryMarkUnit(unit)
        
    elseif event == "PLAYER_TARGET_CHANGED" then
        self:TryMarkUnit("target")
        
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        self:TryMarkUnit("mouseover")
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Clear cache on zone change
        wipe(markedGUIDs)
    end
end

-- Update (for settings changes)
function AutoMark:UpdateUI()
    -- No visual UI for this module
end

-- Initialize
function AutoMark:Init()
    self:CreateEventFrame()
end
