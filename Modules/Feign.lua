-- HunterSuite Feign Module
-- Shows "Last Target" button after Feign Death

local Feign = {}
HunterSuite.Feign = Feign

local FEIGN_DEATH_ID = 5384

local lastTargetBtn = nil
local hideTimer = nil

-- Create the last target button (SecureActionButton)
function Feign:CreateButton()
    if lastTargetBtn then return lastTargetBtn end
    
    local db = HunterSuite.db.feign
    
    -- Must create secure button at login, not during combat
    lastTargetBtn = CreateFrame("Button", "HunterSuiteLastTarget", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
    lastTargetBtn:SetSize(100, 28)
    lastTargetBtn:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or -320)
    lastTargetBtn:SetFrameStrata("HIGH")
    lastTargetBtn:SetMovable(true)
    lastTargetBtn:RegisterForDrag("LeftButton")
    lastTargetBtn:SetClampedToScreen(true)
    
    -- Secure attributes - set once at creation
    lastTargetBtn:SetAttribute("type", "macro")
    lastTargetBtn:SetAttribute("macrotext", "/targetlasttarget")
    
    lastTargetBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    lastTargetBtn:SetBackdropColor(0.8, 0.6, 0.1, 0.95)
    lastTargetBtn:SetBackdropBorderColor(1, 0.8, 0.2, 1)
    
    local btnText = lastTargetBtn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    btnText:SetPoint("CENTER", lastTargetBtn, "CENTER", 0, 0)
    btnText:SetText("Last Target")
    btnText:SetTextColor(1, 1, 1, 1)
    
    -- Hover effect
    lastTargetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(1, 0.8, 0.2, 1)
    end)
    lastTargetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.8, 0.6, 0.1, 0.95)
    end)
    
    -- Dragging (only when unlocked and not in combat)
    lastTargetBtn:SetScript("OnDragStart", function(self)
        if not HunterSuite.db.feign.locked and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    lastTargetBtn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HunterSuite.db.feign.position.point = point
        HunterSuite.db.feign.position.x = x
        HunterSuite.db.feign.position.y = y
    end)
    
    lastTargetBtn:Hide()
    
    -- Register events on a separate frame to avoid secure taint
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        Feign:OnEvent(event, ...)
    end)
    
    self.lastTargetBtn = lastTargetBtn
    self.eventFrame = eventFrame
    return lastTargetBtn
end

-- Handle events
function Feign:OnEvent(event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        local spellId = select(3, ...)
        
        if unit == "player" and spellId == FEIGN_DEATH_ID then
            self:ShowButton()
        end
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat - can hide button if still showing
        -- Button will auto-hide via timer anyway
    end
end

-- Show the button after Feign Death
function Feign:ShowButton()
    if not lastTargetBtn then return end
    
    local db = HunterSuite.db.feign
    
    if not db.enabled or not HunterSuite.state.isHunter then
        return
    end
    
    -- Only show in combat if configured
    if db.showOnlyInCombat and not InCombatLockdown() then
        return
    end
    
    -- Show button
    if not InCombatLockdown() then
        lastTargetBtn:Show()
    end
    
    -- Cancel existing timer
    if hideTimer then
        hideTimer:Cancel()
    end
    
    -- Hide after configured time
    hideTimer = C_Timer.NewTimer(db.showSeconds or 6, function()
        if not InCombatLockdown() and lastTargetBtn then
            lastTargetBtn:Hide()
        end
    end)
end

-- Update visibility
function Feign:UpdateUI()
    if not lastTargetBtn then return end
    
    local db = HunterSuite.db.feign
    
    if InCombatLockdown() then return end  -- Can't modify secure frame in combat
    
    if not db.enabled or not HunterSuite.state.isHunter then
        lastTargetBtn:Hide()
        return
    end
    
    lastTargetBtn:SetScale(db.scale or 1)
    lastTargetBtn:SetAlpha(db.alpha or 1)
    
    -- Show in edit mode
    if HunterSuite.state.editMode then
        lastTargetBtn:Show()
    end
end

-- Initialize
function Feign:Init()
    self:CreateButton()
end

-- Keybinding support
BINDING_HEADER_HUNTERSUITE = "Hunter Suite"
BINDING_NAME_HUNTERSUITE_LASTTARGET = "Last Target (after Feign)"
