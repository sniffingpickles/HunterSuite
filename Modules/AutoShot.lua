--[[
    HunterSuite - Auto Shot Timer Module
    Displays a swing timer bar for Auto Shot to help with shot weaving
    
    TBC Auto Shot Mechanics:
    - Auto Shot has a ~0.5s "windup/cast" before the projectile leaves
    - Time between shots = ranged weapon speed (affected by haste)
    - Movement during windup delays the shot (500ms retry timer)
    - For weaving: press next shot in the last ~0.1s to queue it
    
    3-Zone Timing Model:
    - SAFE (white): Cast/move freely (0 to safeEnd)
    - WINDUP (red): Auto Shot casting, don't start casts (safeEnd to shotSpeed)
    - QUEUE NOW (blue): Press next shot to queue (last queueWindow before shot)
]]

local addonName, HunterSuite = ...

HunterSuite.AutoShot = {}
local AutoShot = HunterSuite.AutoShot

-- Constants
local AUTO_SHOT_ID = 75  -- Auto Shot spell ID
local AUTO_SHOT_NAME = GetSpellInfo(AUTO_SHOT_ID) or "Auto Shot"  -- Localized name

-- Local references
local timerFrame = nil
local timerBar = nil
local timeText = nil
local zoneText = nil  -- Shows current zone (SAFE/WINDUP/QUEUE)
local safeMarker = nil  -- Tick mark at safe zone end
local queueMarker = nil -- Tick mark at queue zone start
local delayText = nil   -- Shows how much last shot was clipped
local gcdBar = nil      -- GCD indicator bar
local isAutoShooting = false
local lastShotTime = 0  -- Time when Auto Shot projectile left (end of windup)
local expectedShotTime = 0  -- When shot should have fired (for delay calc)
local lastDelay = 0     -- How much last shot was delayed
local shotSpeed = 0
local playerGUID = nil
local waitingForFirstShot = false  -- True until we see our first shot event
local gcdStart = 0      -- GCD start time
local gcdDuration = 0   -- GCD duration

-- Get network latency in seconds
local function GetLatencySeconds()
    local _, _, home, world = GetNetStats()
    local ms = math.max(home or 0, world or 0)
    return ms / 1000
end

-- Create the auto shot timer bar
function AutoShot:CreateBar()
    if timerFrame then return timerFrame end
    
    local db = HunterSuite.db.autoShot
    
    -- Main frame
    timerFrame = CreateFrame("Frame", "HunterSuiteAutoShot", UIParent, "BackdropTemplate")
    timerFrame:SetSize(db.barWidth + 8, db.barHeight + 4)
    timerFrame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or -240)
    timerFrame:SetFrameStrata("MEDIUM")
    timerFrame:SetMovable(true)
    timerFrame:EnableMouse(true)
    timerFrame:RegisterForDrag("LeftButton")
    timerFrame:SetClampedToScreen(true)
    
    timerFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    timerFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    timerFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    -- Timer bar
    timerBar = CreateFrame("StatusBar", "HunterSuiteAutoShotBar", timerFrame, "BackdropTemplate")
    timerBar:SetSize(db.barWidth, db.barHeight - 2)
    timerBar:SetPoint("CENTER", timerFrame, "CENTER", 0, 0)
    timerBar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
    timerBar:SetStatusBarColor(0.8, 0.4, 0.1, 1)  -- Orange for auto shot
    timerBar:SetMinMaxValues(0, 1)
    timerBar:SetValue(0)
    
    timerBar:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    timerBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    timerBar:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
    
    -- Label
    local label = timerBar:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    label:SetPoint("LEFT", timerBar, "LEFT", 4, 0)
    label:SetText("Auto Shot")
    label:SetTextColor(1, 0.8, 0.5, 1)
    
    -- Time text
    timeText = timerBar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    timeText:SetPoint("RIGHT", timerBar, "RIGHT", -4, 0)
    timeText:SetTextColor(1, 1, 1, 1)
    
    -- Clipping markers (tick marks showing zone boundaries)
    -- Safe zone end marker (red line - stop casting here)
    safeMarker = timerBar:CreateTexture(nil, "OVERLAY")
    safeMarker:SetSize(2, db.barHeight + 4)
    safeMarker:SetColorTexture(0.9, 0.2, 0.2, 1)  -- Red
    safeMarker:SetPoint("CENTER", timerBar, "LEFT", 0, 0)  -- Will be positioned in OnUpdate
    
    -- Queue zone start marker (blue line - queue ability here)
    queueMarker = timerBar:CreateTexture(nil, "OVERLAY")
    queueMarker:SetSize(2, db.barHeight + 4)
    queueMarker:SetColorTexture(0.2, 0.6, 1.0, 1)  -- Blue
    queueMarker:SetPoint("CENTER", timerBar, "LEFT", 0, 0)  -- Will be positioned in OnUpdate
    
    -- Delay text (shows how much last shot was clipped)
    delayText = timerFrame:CreateFontString(nil, "OVERLAY")
    delayText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    delayText:SetPoint("TOP", timerFrame, "BOTTOM", 0, -2)
    delayText:SetTextColor(1, 0.3, 0.3, 1)  -- Red for delay
    delayText:Hide()
    
    -- GCD bar (thin bar below main bar)
    gcdBar = CreateFrame("StatusBar", "HunterSuiteGCDBar", timerFrame)
    gcdBar:SetSize(db.barWidth, 4)
    gcdBar:SetPoint("TOP", timerFrame, "BOTTOM", 0, -1)
    gcdBar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
    gcdBar:SetStatusBarColor(0.8, 0.8, 0.2, 0.8)  -- Yellow for GCD
    gcdBar:SetMinMaxValues(0, 1)
    gcdBar:SetValue(0)
    
    local gcdBg = gcdBar:CreateTexture(nil, "BACKGROUND")
    gcdBg:SetAllPoints()
    gcdBg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
    gcdBar:Hide()
    
    -- Dragging (only in edit mode)
    timerFrame:SetScript("OnDragStart", function(self)
        if HunterSuite.state.editMode then
            self:StartMoving()
        end
    end)
    timerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HunterSuite.db.autoShot.position.point = point
        HunterSuite.db.autoShot.position.x = x
        HunterSuite.db.autoShot.position.y = y
    end)
    
    -- Update loop
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        AutoShot:OnUpdate(elapsed)
    end)
    
    -- Register events
    timerFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
    timerFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    timerFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")  -- Primary: fires when Auto Shot goes off
    timerFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") -- Fallback detection
    timerFrame:RegisterEvent("UNIT_RANGEDDAMAGE")         -- For weapon speed updates
    timerFrame:RegisterEvent("PLAYER_LOGIN")
    timerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    timerFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")     -- For GCD tracking
    timerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")     -- Enter combat
    timerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")      -- Leave combat
    
    timerFrame:SetScript("OnEvent", function(self, event, ...)
        AutoShot:OnEvent(event, ...)
    end)
    
    timerFrame:Hide()  -- Hidden by default until shooting
    
    -- Get player GUID
    playerGUID = UnitGUID("player")
    
    self.timerFrame = timerFrame
    self.timerBar = timerBar
    
    return timerFrame
end

-- Handle events
function AutoShot:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID("player")
        self:UpdateShotSpeed()
        
    elseif event == "START_AUTOREPEAT_SPELL" then
        isAutoShooting = true
        self:UpdateShotSpeed()
        -- IMPORTANT: Do NOT set lastShotTime here!
        -- We wait for the actual shot event to get accurate timing
        lastShotTime = 0
        waitingForFirstShot = true
        if HunterSuite.db.autoShot.enabled then
            timerFrame:Show()
        end
        
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        isAutoShooting = false
        lastShotTime = 0
        waitingForFirstShot = false
        if HunterSuite.db.autoShot.hideWhenInactive then
            timerFrame:Hide()
        end
        
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Primary detection: UNIT_SPELLCAST_SUCCEEDED for Auto Shot
        -- Event args can vary across clients, handle defensively
        local unit = ...
        local spellId = select(3, ...)
        local spellName = spellId and GetSpellInfo(spellId) or select(2, ...)
        
        if unit == "player" and (spellId == AUTO_SHOT_ID or spellName == AUTO_SHOT_NAME) then
            local now = GetTime()
            
            -- Calculate delay (how much the shot was clipped)
            if expectedShotTime > 0 and now > expectedShotTime then
                lastDelay = now - expectedShotTime
                if lastDelay > 0.05 then  -- Only show delays > 50ms
                    local showDelay = HunterSuite.db.autoShot.showDelayTimer
                    if showDelay == nil then showDelay = true end  -- Default to true
                    if delayText and showDelay then
                        delayText:SetText(string.format("-%.2fs", lastDelay))
                        delayText:Show()
                    end
                else
                    lastDelay = 0
                    if delayText then delayText:Hide() end
                end
            else
                if delayText then delayText:Hide() end
            end
            
            lastShotTime = now
            expectedShotTime = now + shotSpeed  -- Next expected shot
            waitingForFirstShot = false
            self:UpdateShotSpeed()
        end
        
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Fallback detection via combat log (note: can be late due to projectile travel)
        -- Only use if UNIT_SPELLCAST_SUCCEEDED isn't firing
        if not waitingForFirstShot then return end  -- Already got shot from UNIT_SPELLCAST_SUCCEEDED
        
        local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == playerGUID then
            -- Check for Auto Shot damage/miss
            if (subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED") and 
               (spellId == AUTO_SHOT_ID or spellName == AUTO_SHOT_NAME) then
                lastShotTime = GetTime()
                waitingForFirstShot = false
                self:UpdateShotSpeed()
            end
        end
        
    elseif event == "UNIT_RANGEDDAMAGE" then
        local unit = ...
        if unit == "player" then
            self:UpdateShotSpeed()
        end
        
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        -- Track GCD using global cooldown spell (use any instant spell the hunter has)
        -- Try multiple spells to find one that shows GCD
        local start, duration
        
        -- Try Arcane Shot (ID 3044) - most hunters have this
        start, duration = GetSpellCooldown(3044)
        if not (start and start > 0 and duration and duration > 0 and duration <= 1.5) then
            -- Try Disengage (ID 781)
            start, duration = GetSpellCooldown(781)
        end
        if not (start and start > 0 and duration and duration > 0 and duration <= 1.5) then
            -- Try Hunter's Mark (ID 1130)
            start, duration = GetSpellCooldown(1130)
        end
        
        if start and start > 0 and duration and duration > 0 and duration <= 1.5 then
            gcdStart = start
            gcdDuration = duration
        end
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat
        if HunterSuite.db.autoShot.enabled then
            local alpha = HunterSuite.db.autoShot.alpha or 1
            timerFrame:SetAlpha(alpha)
        end
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat - apply out of combat alpha
        local oocAlpha = HunterSuite.db.autoShot.oocAlpha
        if oocAlpha == nil then oocAlpha = 0.3 end  -- Default to 0.3
        if HunterSuite.db.autoShot.enabled then
            timerFrame:SetAlpha(oocAlpha)
        end
        -- Hide delay text when leaving combat
        if delayText then delayText:Hide() end
        lastDelay = 0
        expectedShotTime = 0
    end
end

-- Update ranged attack speed
function AutoShot:UpdateShotSpeed()
    local speed = UnitRangedDamage("player")
    if speed and speed > 0 then
        shotSpeed = speed
    end
end

-- OnUpdate handler with TBC 3-zone timing model
function AutoShot:OnUpdate(elapsed)
    -- In edit mode, just show a sample bar
    if HunterSuite.state.editMode then
        timerFrame:Show()
        timerFrame:SetAlpha(1)
        timerBar:SetMinMaxValues(0, 3)
        timerBar:SetValue(1.5)
        timerBar:SetStatusBarColor(0.9, 0.9, 0.9, 1)
        timeText:SetText("1.5")
        return
    end
    
    if not HunterSuite.db.autoShot.enabled then
        timerFrame:Hide()
        return
    end
    
    if not isAutoShooting then
        if HunterSuite.db.autoShot.hideWhenInactive then
            timerFrame:Hide()
        else
            timerBar:SetValue(0)
            timeText:SetText("")
        end
        return
    end
    
    if shotSpeed <= 0 then
        self:UpdateShotSpeed()
        if shotSpeed <= 0 then
            return
        end
    end
    
    -- Waiting for first shot event - show "waiting" state
    if lastShotTime == 0 or waitingForFirstShot then
        timerBar:SetMinMaxValues(0, 1)
        timerBar:SetValue(0)
        timeText:SetText("...")
        timerBar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        return
    end
    
    local db = HunterSuite.db.autoShot
    local timeSinceShot = GetTime() - lastShotTime
    local remaining = shotSpeed - timeSinceShot
    
    -- TBC timing parameters
    local windup = db.windup or 0.5
    local queueWindow = db.queueWindow or 0.10
    local lat = db.latencyComp and GetLatencySeconds() or 0
    
    -- Calculate zone boundaries
    -- safeEnd: when windup begins (account for latency to stop early)
    local safeEnd = math.max(0, shotSpeed - windup - lat)
    -- queueStart: when to press next ability to queue it
    local queueStart = math.max(safeEnd, shotSpeed - queueWindow - lat)
    
    -- Handle timer overflow (shot should have fired but no event yet)
    if remaining < -0.3 then
        -- Way overdue - show WAIT warning
        timerBar:SetMinMaxValues(0, shotSpeed)
        timerBar:SetValue(shotSpeed)
        timerBar:SetStatusBarColor(1, 0.3, 0.3, 1)  -- Red
        timeText:SetText(db.waitText or "WAIT")
        return
    elseif remaining < 0 then
        -- Slightly overdue, cap at full
        timeSinceShot = shotSpeed
        remaining = 0
    end
    
    timerBar:SetMinMaxValues(0, shotSpeed)
    timerBar:SetValue(timeSinceShot)
    
    -- Update clipping markers position and visibility
    local showMarkers = db.showClippingMarkers
    if showMarkers == nil then showMarkers = true end  -- Default to true
    if showMarkers and safeMarker and queueMarker then
        local barWidth = timerBar:GetWidth()
        -- Position markers as percentage of bar width
        local safePos = (safeEnd / shotSpeed) * barWidth
        local queuePos = (queueStart / shotSpeed) * barWidth
        
        safeMarker:ClearAllPoints()
        safeMarker:SetPoint("CENTER", timerBar, "LEFT", safePos, 0)
        safeMarker:Show()
        
        queueMarker:ClearAllPoints()
        queueMarker:SetPoint("CENTER", timerBar, "LEFT", queuePos, 0)
        queueMarker:Show()
    elseif safeMarker and queueMarker then
        safeMarker:Hide()
        queueMarker:Hide()
    end
    
    -- 3-Zone coloring based on TBC mechanics
    local safeLabel = db.safeText or ""
    local windupLabel = db.windupText or ""
    local queueLabel = db.queueText or "QUEUE"
    
    if timeSinceShot < safeEnd then
        -- SAFE ZONE: Cast/move freely
        timerBar:SetStatusBarColor(0.9, 0.9, 0.9, 1)  -- White/light gray
        timeText:SetText(safeLabel ~= "" and safeLabel or string.format("%.1f", remaining))
    elseif timeSinceShot < queueStart then
        -- WINDUP ZONE: Auto Shot is "casting" - don't start casts, stop moving
        timerBar:SetStatusBarColor(0.9, 0.3, 0.3, 1)  -- Red
        timeText:SetText(windupLabel ~= "" and windupLabel or string.format("%.1f", remaining))
    else
        -- QUEUE NOW: Press your next shot to queue it
        timerBar:SetStatusBarColor(0.2, 0.6, 1.0, 1)  -- Blue
        timeText:SetText(queueLabel)
    end
    
    -- Update GCD bar
    local showGCD = db.showGCDBar
    if showGCD == nil then showGCD = true end  -- Default to true
    if gcdBar and showGCD then
        if gcdStart > 0 and gcdDuration > 0 then
            local gcdElapsed = GetTime() - gcdStart
            local gcdRemaining = gcdDuration - gcdElapsed
            if gcdRemaining > 0 then
                gcdBar:SetMinMaxValues(0, gcdDuration)
                gcdBar:SetValue(gcdElapsed)
                gcdBar:Show()
            else
                gcdBar:Hide()
                gcdStart = 0
                gcdDuration = 0
            end
        else
            gcdBar:Hide()
        end
    elseif gcdBar then
        gcdBar:Hide()
    end
end

-- Update visibility and appearance
function AutoShot:UpdateUI()
    if not timerFrame then return end
    
    local db = HunterSuite.db.autoShot
    
    if not db.enabled or not HunterSuite.state.isHunter then
        timerFrame:Hide()
        return
    end
    
    -- Update size
    timerFrame:SetSize(db.barWidth + 8, db.barHeight + 4)
    if timerBar then
        timerBar:SetSize(db.barWidth, db.barHeight - 2)
    end
    
    -- Update scale/alpha
    timerFrame:SetScale(db.scale or 1)
    timerFrame:SetAlpha(db.alpha or 1)
    
    if isAutoShooting then
        timerFrame:Show()
    elseif not db.hideWhenInactive then
        timerFrame:Show()
    end
end

-- Initialize
function AutoShot:Init()
    self:CreateBar()
    self:UpdateShotSpeed()
end
