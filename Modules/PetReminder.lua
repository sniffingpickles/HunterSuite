-- HunterSuite PetReminder Module
-- Missing pet + Mend Pet reminders

local PetReminder = {}
HunterSuite.PetReminder = PetReminder

local reminderFrame = nil
local reminderText = nil
local callPetBtn = nil
local revivePetBtn = nil
local mendPetBtn = nil
local lastRemind = 0

local MEND_PET_BUFF = "Mend Pet"

-- Create the reminder frame
function PetReminder:CreateReminder()
    if reminderFrame then return reminderFrame end
    
    local db = HunterSuite.db.petReminder
    
    reminderFrame = CreateFrame("Frame", "HunterSuitePetReminder", UIParent, "BackdropTemplate")
    reminderFrame:SetSize(180, 50)
    reminderFrame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or 200)
    reminderFrame:SetFrameStrata("HIGH")
    reminderFrame:SetMovable(true)
    reminderFrame:EnableMouse(true)
    reminderFrame:RegisterForDrag("LeftButton")
    reminderFrame:SetClampedToScreen(true)
    
    reminderFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    reminderFrame:SetBackdropColor(0.6, 0.3, 0.1, 0.95)
    reminderFrame:SetBackdropBorderColor(0.8, 0.4, 0.1, 1)
    
    reminderText = reminderFrame:CreateFontString(nil, "OVERLAY")
    reminderText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    reminderText:SetPoint("TOP", reminderFrame, "TOP", 0, -6)
    reminderText:SetText("No Pet!")
    reminderText:SetTextColor(1, 1, 0.3, 1)
    
    -- Call Pet button
    callPetBtn = CreateFrame("Button", "HunterSuiteCallPet", reminderFrame, "SecureActionButtonTemplate, BackdropTemplate")
    callPetBtn:SetSize(50, 22)
    callPetBtn:SetPoint("BOTTOMLEFT", reminderFrame, "BOTTOMLEFT", 8, 6)
    callPetBtn:RegisterForClicks("AnyUp", "AnyDown")
    callPetBtn:SetAttribute("type", "spell")
    callPetBtn:SetAttribute("spell", "Call Pet")
    
    callPetBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    callPetBtn:SetBackdropColor(0.3, 0.5, 0.3, 1)
    callPetBtn:SetBackdropBorderColor(0.4, 0.6, 0.4, 1)
    
    local callText = callPetBtn:CreateFontString(nil, "OVERLAY")
    callText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    callText:SetPoint("CENTER")
    callText:SetText("Call")
    callText:SetTextColor(1, 1, 1, 1)
    
    callPetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.4, 0.6, 0.4, 1)
    end)
    callPetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.3, 0.5, 0.3, 1)
    end)
    
    -- Revive Pet button
    revivePetBtn = CreateFrame("Button", "HunterSuiteRevivePet", reminderFrame, "SecureActionButtonTemplate, BackdropTemplate")
    revivePetBtn:SetSize(50, 22)
    revivePetBtn:SetPoint("BOTTOMRIGHT", reminderFrame, "BOTTOMRIGHT", -8, 6)
    revivePetBtn:RegisterForClicks("AnyUp", "AnyDown")
    revivePetBtn:SetAttribute("type", "spell")
    revivePetBtn:SetAttribute("spell", "Revive Pet")
    
    revivePetBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    revivePetBtn:SetBackdropColor(0.5, 0.3, 0.3, 1)
    revivePetBtn:SetBackdropBorderColor(0.6, 0.4, 0.4, 1)
    
    local reviveText = revivePetBtn:CreateFontString(nil, "OVERLAY")
    reviveText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    reviveText:SetPoint("CENTER")
    reviveText:SetText("Revive")
    reviveText:SetTextColor(1, 1, 1, 1)
    
    revivePetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.6, 0.4, 0.4, 1)
    end)
    revivePetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.5, 0.3, 0.3, 1)
    end)
    
    -- Dragging (only in edit mode)
    reminderFrame:SetScript("OnDragStart", function(self)
        if HunterSuite.state.editMode and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    reminderFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HunterSuite.db.petReminder.position.point = point
        HunterSuite.db.petReminder.position.x = x
        HunterSuite.db.petReminder.position.y = y
    end)
    
    reminderFrame:Hide()
    
    -- Mend Pet reminder (separate smaller frame)
    local mendFrame = CreateFrame("Frame", "HunterSuiteMendReminder", UIParent, "BackdropTemplate")
    mendFrame:SetSize(120, 32)
    mendFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 240)
    mendFrame:SetFrameStrata("HIGH")
    mendFrame:SetMovable(true)
    mendFrame:EnableMouse(true)
    mendFrame:RegisterForDrag("LeftButton")
    
    mendFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    mendFrame:SetBackdropColor(0.7, 0.2, 0.2, 0.95)
    mendFrame:SetBackdropBorderColor(0.9, 0.3, 0.3, 1)
    
    local mendText = mendFrame:CreateFontString(nil, "OVERLAY")
    mendText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    mendText:SetPoint("TOP", mendFrame, "TOP", 0, -4)
    mendText:SetText("Heal Pet!")
    mendText:SetTextColor(1, 1, 0.3, 1)
    
    -- Mend Pet button
    mendPetBtn = CreateFrame("Button", "HunterSuiteMendPet", mendFrame, "SecureActionButtonTemplate, BackdropTemplate")
    mendPetBtn:SetSize(60, 18)
    mendPetBtn:SetPoint("BOTTOM", mendFrame, "BOTTOM", 0, 4)
    mendPetBtn:RegisterForClicks("AnyUp", "AnyDown")
    mendPetBtn:SetAttribute("type", "spell")
    mendPetBtn:SetAttribute("spell", "Mend Pet")
    
    mendPetBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    mendPetBtn:SetBackdropColor(0.3, 0.5, 0.3, 1)
    mendPetBtn:SetBackdropBorderColor(0.4, 0.6, 0.4, 1)
    
    local mendBtnText = mendPetBtn:CreateFontString(nil, "OVERLAY")
    mendBtnText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    mendBtnText:SetPoint("CENTER")
    mendBtnText:SetText("Mend")
    mendBtnText:SetTextColor(1, 1, 1, 1)
    
    mendPetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.4, 0.6, 0.4, 1)
    end)
    mendPetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.3, 0.5, 0.3, 1)
    end)
    
    mendFrame:SetScript("OnDragStart", function(self)
        if HunterSuite.state.editMode and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    mendFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    
    mendFrame:Hide()
    self.mendFrame = mendFrame
    
    -- Register events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_PET")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        PetReminder:OnEvent(event, ...)
    end)
    
    self.reminderFrame = reminderFrame
    self.eventFrame = eventFrame
    return reminderFrame
end

-- Check if in battleground
function PetReminder:IsInBattleground()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

-- Check if pet has Mend Pet buff
function PetReminder:HasMendPetBuff()
    for i = 1, 40 do
        local name = UnitBuff("pet", i)
        if not name then break end
        if name == MEND_PET_BUFF then
            return true
        end
    end
    return false
end

-- Handle events
function PetReminder:OnEvent(event, ...)
    if event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        self:CheckPet()
        
    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if unit == "pet" then
            self:CheckPetHealth()
        end
        
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "pet" then
            self:CheckPetHealth()
        end
    end
end

-- Check if pet exists
function PetReminder:CheckPet()
    if not reminderFrame then return end
    if InCombatLockdown() then return end
    
    local db = HunterSuite.db.petReminder
    
    if not db.enabled or not HunterSuite.state.isHunter then
        reminderFrame:Hide()
        return
    end
    
    -- Edit mode - show sample
    if HunterSuite.state.editMode then
        reminderFrame:Show()
        if self.mendFrame then self.mendFrame:Show() end
        return
    end
    
    -- Check if pet exists - always hide immediately when pet exists
    if UnitExists("pet") then
        reminderFrame:Hide()
        self:CheckPetHealth()
        return
    end
    
    -- No pet - check throttle before showing reminder again
    local remindInterval = db.remindInterval or 10
    if GetTime() - lastRemind < remindInterval then
        return
    end
    
    -- In BG, be more aggressive
    if db.bgOnly and not self:IsInBattleground() then
        reminderFrame:Hide()
    else
        reminderFrame:Show()
        lastRemind = GetTime()
    end
end

-- Check pet health for Mend Pet reminder
function PetReminder:CheckPetHealth()
    if not self.mendFrame then return end
    if InCombatLockdown() then return end
    
    local db = HunterSuite.db.petReminder
    
    if not db.enabled or not HunterSuite.state.isHunter then
        self.mendFrame:Hide()
        return
    end
    
    if not UnitExists("pet") or UnitIsDead("pet") then
        self.mendFrame:Hide()
        return
    end
    
    local hp = UnitHealth("pet")
    local maxHp = UnitHealthMax("pet")
    local pct = hp / maxHp
    
    local threshold = db.healThreshold or 0.65
    
    if pct <= threshold and not self:HasMendPetBuff() then
        self.mendFrame:Show()
    else
        self.mendFrame:Hide()
    end
end

-- Update visibility
function PetReminder:UpdateUI()
    if not reminderFrame then return end
    if InCombatLockdown() then return end
    
    local db = HunterSuite.db.petReminder
    
    if not db.enabled or not HunterSuite.state.isHunter then
        reminderFrame:Hide()
        if self.mendFrame then self.mendFrame:Hide() end
        return
    end
    
    reminderFrame:SetScale(db.scale or 1)
    reminderFrame:SetAlpha(db.alpha or 1)
    
    if HunterSuite.state.editMode then
        reminderFrame:Show()
        if self.mendFrame then self.mendFrame:Show() end
    else
        self:CheckPet()
    end
end

-- Initialize
function PetReminder:Init()
    self:CreateReminder()
end
