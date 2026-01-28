-- HunterSuite Ammo Module
-- Low ammo warning

local Ammo = {}
HunterSuite.Ammo = Ammo

local ammoFrame = nil
local ammoText = nil
local ammoSlotId = nil

-- Create the ammo warning
function Ammo:CreateWarning()
    if ammoFrame then return ammoFrame end
    
    local db = HunterSuite.db.ammo
    
    ammoFrame = CreateFrame("Frame", "HunterSuiteAmmo", UIParent, "BackdropTemplate")
    ammoFrame:SetSize(140, 24)
    ammoFrame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or 120)
    ammoFrame:SetFrameStrata("HIGH")
    ammoFrame:SetMovable(true)
    ammoFrame:EnableMouse(true)
    ammoFrame:RegisterForDrag("LeftButton")
    ammoFrame:SetClampedToScreen(true)
    
    ammoFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    ammoFrame:SetBackdropColor(0.7, 0.2, 0.2, 0.95)
    ammoFrame:SetBackdropBorderColor(0.9, 0.3, 0.3, 1)
    
    ammoText = ammoFrame:CreateFontString(nil, "OVERLAY")
    ammoText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    ammoText:SetPoint("CENTER", ammoFrame, "CENTER", 0, 0)
    ammoText:SetText("LOW AMMO!")
    ammoText:SetTextColor(1, 1, 0.3, 1)
    
    -- Pulse animation
    local ag = ammoFrame:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    
    local fade1 = ag:CreateAnimation("Alpha")
    fade1:SetFromAlpha(1)
    fade1:SetToAlpha(0.5)
    fade1:SetDuration(0.5)
    fade1:SetOrder(1)
    
    local fade2 = ag:CreateAnimation("Alpha")
    fade2:SetFromAlpha(0.5)
    fade2:SetToAlpha(1)
    fade2:SetDuration(0.5)
    fade2:SetOrder(2)
    
    self.pulseAnim = ag
    
    -- Dragging (only in edit mode)
    ammoFrame:SetScript("OnDragStart", function(self)
        if HunterSuite.state.editMode then
            self:StartMoving()
        end
    end)
    ammoFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HunterSuite.db.ammo.position.point = point
        HunterSuite.db.ammo.position.x = x
        HunterSuite.db.ammo.position.y = y
    end)
    
    -- Tooltip
    ammoFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Ammo Warning", 1, 1, 1)
        GameTooltip:AddLine("Your ammo is running low!", 1, 0.5, 0.5)
        GameTooltip:Show()
    end)
    ammoFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    ammoFrame:Hide()
    
    -- Register events
    ammoFrame:RegisterEvent("PLAYER_LOGIN")
    ammoFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ammoFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    ammoFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    ammoFrame:SetScript("OnEvent", function(self, event, ...)
        Ammo:OnEvent(event, ...)
    end)
    
    self.ammoFrame = ammoFrame
    return ammoFrame
end

-- Get ammo slot ID (slot 0 in Classic/TBC)
function Ammo:GetAmmoSlotId()
    if ammoSlotId then return ammoSlotId end
    -- Try API first, fall back to slot 0 (ammo slot in Classic/TBC)
    ammoSlotId = GetInventorySlotInfo("AmmoSlot") or 0
    return ammoSlotId
end

-- Handle events
function Ammo:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        self:GetAmmoSlotId()
        self:CheckAmmo()
        
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slot = ...
        if slot == self:GetAmmoSlotId() then
            self:CheckAmmo()
        end
        
    elseif event == "BAG_UPDATE_DELAYED" then
        self:CheckAmmo()
        
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            self:CheckAmmo()
        end
    end
end

-- Count total ammo of a specific type in bags
function Ammo:CountAmmoInBags(ammoItemId)
    local total = 0
    for bag = 0, 4 do
        local numSlots = C_Container and C_Container.GetContainerNumSlots(bag) or GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemId
            if C_Container and C_Container.GetContainerItemID then
                itemId = C_Container.GetContainerItemID(bag, slot)
            else
                itemId = GetContainerItemID(bag, slot)
            end
            if itemId == ammoItemId then
                local info
                if C_Container and C_Container.GetContainerItemInfo then
                    info = C_Container.GetContainerItemInfo(bag, slot)
                    total = total + (info and info.stackCount or 0)
                else
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    total = total + (itemCount or 0)
                end
            end
        end
    end
    return total
end

-- Check ammo count
function Ammo:CheckAmmo()
    if not ammoFrame then return end
    
    local db = HunterSuite.db.ammo
    
    if not db.enabled or not HunterSuite.state.isHunter then
        ammoFrame:Hide()
        return
    end
    
    local slotId = self:GetAmmoSlotId()
    if slotId == nil then
        ammoFrame:Hide()
        return
    end
    
    -- In TBC Anniversary, GetInventoryItemLink returns nil for ammo slot
    -- but GetInventoryItemCount works correctly
    local count = GetInventoryItemCount("player", slotId) or 0
    
    if count == 0 then
        -- No ammo equipped
        ammoText:SetText("NO AMMO!")
        ammoFrame:SetBackdropColor(0.8, 0.1, 0.1, 0.95)
        ammoFrame:Show()
        if self.pulseAnim then self.pulseAnim:Play() end
        return
    end
    
    if count <= (db.criticalThreshold or 50) then
        -- Critical
        ammoText:SetText("AMMO: " .. count .. " !")
        ammoFrame:SetBackdropColor(0.8, 0.1, 0.1, 0.95)
        ammoFrame:Show()
        if self.pulseAnim then self.pulseAnim:Play() end
    elseif count <= (db.lowThreshold or 200) then
        -- Low
        ammoText:SetText("Ammo: " .. count)
        ammoFrame:SetBackdropColor(0.7, 0.5, 0.1, 0.95)
        ammoFrame:Show()
        if self.pulseAnim then self.pulseAnim:Stop() end
    else
        -- OK
        ammoFrame:Hide()
        if self.pulseAnim then self.pulseAnim:Stop() end
    end
end

-- Update visibility
function Ammo:UpdateUI()
    if not ammoFrame then return end
    
    local db = HunterSuite.db.ammo
    
    if not db.enabled or not HunterSuite.state.isHunter then
        ammoFrame:Hide()
        return
    end
    
    ammoFrame:SetScale(db.scale or 1)
    ammoFrame:SetAlpha(db.alpha or 1)
    
    -- Show in edit mode
    if HunterSuite.state.editMode then
        ammoText:SetText("Ammo: 150")
        ammoFrame:SetBackdropColor(0.7, 0.5, 0.1, 0.95)
        ammoFrame:Show()
        if self.pulseAnim then self.pulseAnim:Stop() end
    else
        self:CheckAmmo()
    end
end

-- Initialize
function Ammo:Init()
    self:CreateWarning()
end
