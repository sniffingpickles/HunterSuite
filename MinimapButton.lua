--[[
    HunterSuite - Minimap Button
    Custom minimap icon without external dependencies
]]

local _, HunterSuite = ...

local minimapButton = nil
local isDragging = false

-- Create the minimap button
function HunterSuite:CreateMinimapButton()
    if minimapButton then return minimapButton end
    
    -- Initialize position
    if not self.db.minimap then
        self.db.minimap = { hide = false, position = 225 }
    end
    
    -- Create button frame
    minimapButton = CreateFrame("Button", "HunterSuiteMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetMovable(true)
    minimapButton:SetClampedToScreen(true)
    minimapButton:RegisterForClicks("AnyUp")
    minimapButton:RegisterForDrag("LeftButton")
    
    -- Background
    local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(26, 26)
    bg:SetPoint("CENTER")
    bg:SetTexture([[Interface\Minimap\UI-Minimap-Background]])
    
    -- Icon overlay (hunter themed)
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture([[Interface\Icons\Ability_Hunter_BeastCall]])
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    minimapButton.icon = icon
    
    -- Border
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
    
    -- Highlight
    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(26, 26)
    highlight:SetPoint("CENTER")
    highlight:SetTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
    highlight:SetBlendMode("ADD")
    
    -- Position around minimap edge
    local function UpdatePosition()
        local angle = math.rad(HunterSuite.db.minimap.position or 225)
        local cos = math.cos(angle)
        local sin = math.sin(angle)
        local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
        
        local r = 80
        if minimapShape == "SQUARE" then
            r = r * 1.414
        end
        
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", r * cos, r * sin)
    end
    
    -- Dragging
    minimapButton:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            
            local angle = math.atan2(cy - my, cx - mx)
            HunterSuite.db.minimap.position = math.deg(angle)
            UpdatePosition()
        end)
    end)
    
    minimapButton:SetScript("OnDragStop", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    
    -- Click handlers
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if IsShiftKeyDown() then
                -- Quick feed
                HunterSuite:FeedPet()
            else
                -- Open settings
                HunterSuite:ShowSettings()
            end
        elseif button == "RightButton" then
            -- Toggle lock
            local locked = not HunterSuite.db.petFeed.locked
            HunterSuite.db.petFeed.locked = locked
            HunterSuite.db.autoShot.locked = locked
            print("|cff00ff00Hunter Suite|r " .. (locked and "locked" or "unlocked"))
        end
    end)
    
    -- Tooltip
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        
        -- Title with icon
        GameTooltip:AddLine("|cff00ff00Hunter Suite|r", 1, 1, 1)
        GameTooltip:AddLine(" ")
        
        -- Pet status
        if HunterSuite.state.hasPet then
            local petName = UnitName("pet") or "Pet"
            local happiness = HunterSuite.state.happiness or 3
            local happyName = HunterSuite.HAPPINESS_NAMES[happiness]
            local colors = HunterSuite.HAPPINESS_COLORS[happiness]
            GameTooltip:AddDoubleLine("Pet:", petName, 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine("Mood:", happyName, 0.7, 0.7, 0.7, colors.r, colors.g, colors.b)
        else
            GameTooltip:AddLine("No pet active", 0.5, 0.5, 0.5)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffaaaaaaLeft-click:|r Open settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffaaaaaaShift+click:|r Feed pet", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffaaaaaaRight-click:|r Lock/unlock bars", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffaaaaaaDrag:|r Move around minimap", 0.8, 0.8, 0.8)
        
        GameTooltip:Show()
    end)
    
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Initial position
    UpdatePosition()
    
    -- Hide if configured
    if self.db.minimap.hide then
        minimapButton:Hide()
    end
    
    self.minimapButton = minimapButton
    return minimapButton
end

-- Toggle minimap button visibility
function HunterSuite:ToggleMinimapButton()
    if not minimapButton then return end
    
    self.db.minimap.hide = not self.db.minimap.hide
    if self.db.minimap.hide then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end
end
