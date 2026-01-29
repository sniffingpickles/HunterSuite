--[[
    HunterSuite - Hunter Utilities for TBC Anniversary
    Core module: shared state and initialization
]]

local addonName, HunterSuite = ...
_G.HunterSuite = HunterSuite

-- Constants
HunterSuite.HAPPINESS = {
    UNHAPPY = 1,    -- 75% damage
    CONTENT = 2,    -- 100% damage
    HAPPY = 3       -- 125% damage
}

HunterSuite.HAPPINESS_NAMES = {
    [1] = "Unhappy",
    [2] = "Content", 
    [3] = "Happy"
}

HunterSuite.HAPPINESS_COLORS = {
    [1] = { r = 0.9, g = 0.2, b = 0.2 },  -- Red for unhappy
    [2] = { r = 1.0, g = 0.8, b = 0.0 },  -- Yellow for content
    [3] = { r = 0.2, g = 0.9, b = 0.2 }   -- Green for happy
}

HunterSuite.DIET_TYPES = {
    "Meat", "Fish", "Cheese", "Bread", "Fungus", "Fruit"
}

-- Pet family food preferences (TBC)
-- Used as fallback if GetPetFoodTypes() doesn't work correctly
HunterSuite.PET_FAMILY_DIETS = {
    ["Bat"]          = { "Fruit", "Fungus" },
    ["Bear"]         = { "Fruit", "Fungus", "Cheese", "Bread", "Meat", "Fish" },
    ["Boar"]         = { "Fruit", "Fungus", "Cheese", "Bread", "Meat", "Fish" },
    ["Carrion Bird"] = { "Meat", "Fish" },
    ["Cat"]          = { "Meat", "Fish" },
    ["Crab"]         = { "Bread", "Fruit", "Fish", "Fungus" },
    ["Crocolisk"]    = { "Meat", "Fish" },
    ["Gorilla"]      = { "Fungus", "Fruit" },
    ["Hyena"]        = { "Fruit", "Meat" },
    ["Owl"]          = { "Meat" },
    ["Raptor"]       = { "Meat" },
    ["Scorpid"]      = { "Meat" },
    ["Spider"]       = { "Meat" },
    ["Tallstrider"]  = { "Fruit", "Fungus" },
    ["Turtle"]       = { "Fruit", "Fungus", "Fish" },
    ["Wind Serpent"] = { "Bread", "Fish", "Cheese" },
    ["Wolf"]         = { "Meat" },
    -- Aliases
    ["Vulture"]      = { "Meat", "Fish" },
    ["Lion"]         = { "Meat", "Fish" },
    ["Strider"]      = { "Meat", "Fish" },
    ["Worg"]         = { "Meat" },
}

-- Default settings for all modules
HunterSuite.defaults = {
    -- Pet Feed module
    petFeed = {
        enabled = true,
        locked = false,
        scale = 1.0,
        alpha = 1.0,
        showText = true,
        alertThreshold = 2,
        autoSelectFood = true,
        preferHighLevel = true,
        foodSelectionMode = "level",
        showTooltip = true,
        position = { point = "CENTER", x = 0, y = -200 },
        barWidth = 180,
        barHeight = 24,
        fontSize = 12,
        glowOnAlert = true,
        soundAlert = true,
        showAlways = false,
        style = "bar",  -- "bar" or "icon"
    },
    -- Auto Shot timer module
    autoShot = {
        enabled = true,
        locked = false,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "CENTER", x = 0, y = -240 },
        barWidth = 180,
        barHeight = 16,
        fontSize = 11,
        hideWhenInactive = true,
        -- TBC timing settings
        windup = 0.5,
        queueWindow = 0.10,
        latencyComp = true,
        -- Zone text labels
        safeText = "",          -- Empty = show time remaining
        windupText = "",        -- Empty = show time remaining  
        queueText = "QUEUE",    -- Text shown in queue window
        waitText = "WAIT",      -- Text when timer overdue
        showClippingMarkers = true, -- Show visual tick marks for safe/danger zones
        showDelayTimer = true,      -- Show how much last shot was clipped
        showGCDBar = true,          -- Show GCD bar below autoshot bar
        oocAlpha = 0.3,             -- Out of combat alpha (0 to hide completely)
    },
    -- Aspect reminder module
    aspects = {
        enabled = true,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "TOP", x = 0, y = -100 },
        onlyInCombat = false,
        fontSize = 14,
        alertText = "NO ASPECT!",
        dismissDuration = 30,  -- seconds to dismiss reminder
    },
    -- Growl reminder module
    growl = {
        enabled = true,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "TOP", x = 0, y = -140 },
        fontSize = 14,
        alertText = "GROWL ON!",
    },
    -- Trap expiration timer
    traps = {
        enabled = true,
        locked = false,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "CENTER", x = 0, y = -280 },
        hideWhenInactive = true,
        duration = 60,
        armingTime = 2.0,
        showTriggeredText = true,
    },
    -- Range indicator (dead zone)
    range = {
        enabled = true,
        locked = false,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "CENTER", x = 120, y = -240 },
        updateHz = 10,
        attachToAutoShot = true,
        showAlways = false,
        style = "text",  -- "text" or "dot"
    },
    -- Feign Death last target
    feign = {
        enabled = true,
        locked = false,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "CENTER", x = 0, y = -320 },
        showSeconds = 6,
        showOnlyInCombat = true,
    },
    -- Low ammo warning
    ammo = {
        enabled = true,
        locked = false,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "CENTER", x = 0, y = 120 },
        lowThreshold = 200,
        criticalThreshold = 50,
        sound = true,
    },
    -- Serpent Sting nameplate timer
    stings = {
        enabled = true,
        showOnNameplates = true,
        textSize = 10,
        iconSize = 14,
        onlyMine = true,
    },
    -- Pet reminders
    petReminder = {
        enabled = true,
        locked = false,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "CENTER", x = 0, y = 200 },
        healThreshold = 0.65,
        bgOnly = false,
        remindInterval = 10,
    },
    -- Track Humanoids helper
    tracking = {
        enabled = true,
        locked = false,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "CENTER", x = 0, y = 160 },
        bgOnly = true,
        remindInterval = 30,
    },
    -- Auto-mark enemy pets
    autoMark = {
        enabled = false,  -- Off by default (can be annoying)
        onlyInPVPInstances = true,
        throttleSeconds = 10,
    },
}

-- State
HunterSuite.state = {
    happiness = nil,
    damagePercent = nil,
    loyaltyRate = nil,
    hasPet = false,
    isHunter = false,
    selectedFood = nil,
    petDiet = {},
    editMode = false,  -- Edit mode for positioning UI elements
}

-- Initialize saved variables
function HunterSuite:InitDB()
    if not HunterSuiteDB then
        HunterSuiteDB = {}
    end
    
    -- Deep copy defaults for nested tables
    local function deepCopy(src, dest)
        for k, v in pairs(src) do
            if type(v) == "table" then
                if dest[k] == nil then
                    dest[k] = {}
                end
                deepCopy(v, dest[k])
            else
                if dest[k] == nil then
                    dest[k] = v
                end
            end
        end
    end
    
    deepCopy(self.defaults, HunterSuiteDB)
    self.db = HunterSuiteDB
end

-- Check if player is a hunter
function HunterSuite:IsHunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

-- Check if pet exists and get its info
function HunterSuite:HasPet()
    local hasUI, isHunterPet = HasPetUI()
    return hasUI and isHunterPet
end

-- Get pet happiness info
function HunterSuite:GetPetHappiness()
    if not self:HasPet() then
        return nil, nil, nil
    end
    
    local happiness, damagePercentage, loyaltyRate = GetPetHappiness()
    return happiness, damagePercentage, loyaltyRate
end

-- Get pet's diet types
function HunterSuite:GetPetDiet()
    local diet = {}
    
    if not self:HasPet() then
        return diet
    end
    
    -- ALWAYS use pet family lookup - API is unreliable (returns incomplete data)
    local petFamily = UnitCreatureFamily("pet")
    if petFamily and self.PET_FAMILY_DIETS[petFamily] then
        for _, foodType in ipairs(self.PET_FAMILY_DIETS[petFamily]) do
            table.insert(diet, foodType)
        end
    end
    
    -- Fallback to API if we don't have the pet family in our database
    if #diet == 0 then
        local foodTypes = GetPetFoodTypes()
        if foodTypes and foodTypes ~= "" then
            for foodType in string.gmatch(foodTypes, "[^,]+") do
                foodType = foodType:match("^%s*(.-)%s*$")
                -- Normalize to title case for matching
                foodType = foodType:sub(1,1):upper() .. foodType:sub(2):lower()
                table.insert(diet, foodType)
            end
        end
    end
    
    return diet
end

-- Update pet state
function HunterSuite:UpdatePetState()
    self.state.hasPet = self:HasPet()
    
    if self.state.hasPet then
        self.state.happiness, self.state.damagePercent, self.state.loyaltyRate = self:GetPetHappiness()
        self.state.petDiet = self:GetPetDiet()
    else
        self.state.happiness = nil
        self.state.damagePercent = nil
        self.state.loyaltyRate = nil
        self.state.petDiet = {}
    end
    
    return self.state
end

-- Check if pet needs feeding
function HunterSuite:NeedsFeeding()
    if not self.state.hasPet or not self.state.happiness then
        return false
    end
    
    return self.state.happiness <= self.db.petFeed.alertThreshold
end

-- Get happiness as percentage (0-100)
function HunterSuite:GetHappinessPercent()
    if not self.state.happiness then
        return 0
    end
    
    return self.state.happiness * 33.33
end

-- Get color for current happiness
function HunterSuite:GetHappinessColor()
    local happiness = self.state.happiness or 1
    return self.HAPPINESS_COLORS[happiness]
end

-- Find best food to feed pet
function HunterSuite:FindBestFood()
    if not self.state.hasPet then
        return nil
    end
    
    local diet = self.state.petDiet
    if #diet == 0 then
        return nil
    end
    
    local db = self.db.petFeed
    local bestFood = nil
    local bestValue = nil
    local mode = db.foodSelectionMode or "level"
    
    -- Initialize bestValue based on mode
    if mode == "level" then
        bestValue = db.preferHighLevel and 0 or 999
    elseif mode == "minQuantity" then
        bestValue = 999999
    elseif mode == "maxQuantity" then
        bestValue = 0
    end
    
    -- Scan bags for food
    for bag = 0, 4 do
        local numSlots = C_Container and C_Container.GetContainerNumSlots(bag) or GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemInfo
            if C_Container and C_Container.GetContainerItemInfo then
                itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            else
                local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bag, slot)
                if texture then
                    itemInfo = { iconFileID = texture, stackCount = itemCount, itemID = itemLink and GetItemInfoInstant(itemLink) }
                end
            end
            
            if itemInfo and itemInfo.itemID then
                local itemID = itemInfo.itemID
                local foodType = HunterSuite.FoodDB and HunterSuite.FoodDB[itemID]
                
                if foodType then
                    for _, dietType in ipairs(diet) do
                        if foodType.type == dietType then
                            local itemName, _, _, itemLevel = GetItemInfo(itemID)
                            itemLevel = itemLevel or foodType.level or 1
                            local itemCount = GetItemCount(itemID) or 1
                            
                            local isBetter = false
                            if mode == "level" then
                                if db.preferHighLevel then
                                    isBetter = itemLevel > bestValue
                                else
                                    isBetter = itemLevel < bestValue
                                end
                                if isBetter then bestValue = itemLevel end
                            elseif mode == "minQuantity" then
                                isBetter = itemCount < bestValue
                                if isBetter then bestValue = itemCount end
                            elseif mode == "maxQuantity" then
                                isBetter = itemCount > bestValue
                                if isBetter then bestValue = itemCount end
                            end
                            
                            if isBetter then
                                bestFood = { bag = bag, slot = slot, itemID = itemID, name = itemName, level = itemLevel, count = itemCount }
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    
    self.state.selectedFood = bestFood
    return bestFood
end

-- Feed pet with selected food
function HunterSuite:FeedPet()
    if not self.state.hasPet then
        return false
    end
    
    local food = self.db.petFeed.autoSelectFood and self:FindBestFood() or self.state.selectedFood
    
    if food then
        CastSpellByName("Feed Pet")
        
        if C_Container and C_Container.PickupContainerItem then
            C_Container.PickupContainerItem(food.bag, food.slot)
        else
            PickupContainerItem(food.bag, food.slot)
        end
        
        return true
    else
        print("|cffff6600HunterSuite:|r No suitable food found in bags!")
        return false
    end
end

-- Event handling
HunterSuite.frame = CreateFrame("Frame")
HunterSuite.frame:RegisterEvent("ADDON_LOADED")
HunterSuite.frame:RegisterEvent("PLAYER_LOGIN")
HunterSuite.frame:RegisterEvent("UNIT_PET")
HunterSuite.frame:RegisterEvent("PET_BAR_UPDATE")
HunterSuite.frame:RegisterEvent("UNIT_HAPPINESS")
HunterSuite.frame:RegisterEvent("PET_UI_UPDATE")

HunterSuite.frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        HunterSuite:InitDB()
        HunterSuite.state.isHunter = HunterSuite:IsHunter()
        
        if HunterSuite.state.isHunter then
            HunterSuite:UpdatePetState()
            
            -- Initialize all modules
            if HunterSuite.PetFeed and HunterSuite.PetFeed.Init then
                HunterSuite.PetFeed:Init()
            end
            if HunterSuite.AutoShot and HunterSuite.AutoShot.Init then
                HunterSuite.AutoShot:Init()
            end
            if HunterSuite.Aspects and HunterSuite.Aspects.Init then
                HunterSuite.Aspects:Init()
            end
            if HunterSuite.Growl and HunterSuite.Growl.Init then
                HunterSuite.Growl:Init()
            end
            if HunterSuite.Traps and HunterSuite.Traps.Init then
                HunterSuite.Traps:Init()
            end
            if HunterSuite.Range and HunterSuite.Range.Init then
                HunterSuite.Range:Init()
            end
            if HunterSuite.Ammo and HunterSuite.Ammo.Init then
                HunterSuite.Ammo:Init()
            end
            if HunterSuite.Stings and HunterSuite.Stings.Init then
                HunterSuite.Stings:Init()
            end
            if HunterSuite.PetReminder and HunterSuite.PetReminder.Init then
                HunterSuite.PetReminder:Init()
            end
            if HunterSuite.AutoMark and HunterSuite.AutoMark.Init then
                HunterSuite.AutoMark:Init()
            end
            
            -- Create minimap button
            HunterSuite:CreateMinimapButton()
            
            print("|cff00ff00Hunter Suite|r loaded! Type |cffaaaaaa/hs|r for settings.")
        end
        
    elseif event == "PLAYER_LOGIN" then
        HunterSuite.state.isHunter = HunterSuite:IsHunter()
        if HunterSuite.state.isHunter then
            HunterSuite:UpdatePetState()
        end
        
    elseif HunterSuite.state.isHunter then
        if event == "UNIT_PET" and arg1 == "player" then
            HunterSuite:UpdatePetState()
            if HunterSuite.PetFeed then HunterSuite.PetFeed:UpdateUI() end
            if HunterSuite.Growl then HunterSuite.Growl:CheckGrowl() end
            
        elseif event == "PET_BAR_UPDATE" or event == "UNIT_HAPPINESS" or event == "PET_UI_UPDATE" then
            HunterSuite:UpdatePetState()
            if HunterSuite.PetFeed then HunterSuite.PetFeed:UpdateUI() end
        end
    end
end)

-- Edit Mode overlay frame
local editModeOverlay = nil

-- Create Edit Mode overlay with Save/Cancel
local function CreateEditModeOverlay()
    if editModeOverlay then return editModeOverlay end
    
    editModeOverlay = CreateFrame("Frame", "HunterSuiteEditOverlay", UIParent, "BackdropTemplate")
    editModeOverlay:SetSize(300, 80)
    editModeOverlay:SetPoint("TOP", UIParent, "TOP", 0, -100)
    editModeOverlay:SetFrameStrata("DIALOG")
    editModeOverlay:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    editModeOverlay:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
    editModeOverlay:SetBackdropBorderColor(0.3, 0.8, 0.4, 1)
    
    -- Title
    local title = editModeOverlay:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    title:SetPoint("TOP", editModeOverlay, "TOP", 0, -12)
    title:SetText("|cffFFD700EDIT MODE|r - Drag elements to reposition")
    
    -- Save button
    local saveBtn = CreateFrame("Button", nil, editModeOverlay, "BackdropTemplate")
    saveBtn:SetSize(100, 28)
    saveBtn:SetPoint("BOTTOMLEFT", editModeOverlay, "BOTTOMLEFT", 30, 12)
    saveBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    saveBtn:SetBackdropColor(0.2, 0.6, 0.3, 1)
    saveBtn:SetBackdropBorderColor(0.3, 0.8, 0.4, 1)
    
    local saveText = saveBtn:CreateFontString(nil, "OVERLAY")
    saveText:SetFont(STANDARD_TEXT_FONT, 12, "")
    saveText:SetPoint("CENTER")
    saveText:SetText("Save")
    saveText:SetTextColor(1, 1, 1, 1)
    
    saveBtn:SetScript("OnClick", function()
        HunterSuite:ExitEditMode(true)  -- Save positions
    end)
    saveBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.7, 0.35, 1)
    end)
    saveBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.6, 0.3, 1)
    end)
    
    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, editModeOverlay, "BackdropTemplate")
    cancelBtn:SetSize(100, 28)
    cancelBtn:SetPoint("BOTTOMRIGHT", editModeOverlay, "BOTTOMRIGHT", -30, 12)
    cancelBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    cancelBtn:SetBackdropColor(0.5, 0.2, 0.2, 1)
    cancelBtn:SetBackdropBorderColor(0.7, 0.3, 0.3, 1)
    
    local cancelText = cancelBtn:CreateFontString(nil, "OVERLAY")
    cancelText:SetFont(STANDARD_TEXT_FONT, 12, "")
    cancelText:SetPoint("CENTER")
    cancelText:SetText("Cancel")
    cancelText:SetTextColor(1, 1, 1, 1)
    
    cancelBtn:SetScript("OnClick", function()
        HunterSuite:ExitEditMode(false)  -- Restore positions
    end)
    cancelBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.6, 0.25, 0.25, 1)
    end)
    cancelBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.5, 0.2, 0.2, 1)
    end)
    
    editModeOverlay:Hide()
    return editModeOverlay
end

-- Store original positions for cancel
local originalPositions = {}

-- Toggle Edit Mode - shows all UI elements for positioning
function HunterSuite:ToggleEditMode()
    if self.state.editMode then
        self:ExitEditMode(true)  -- Save by default when toggling off
    else
        self:EnterEditMode()
    end
end

-- Enter Edit Mode
function HunterSuite:EnterEditMode()
    self.state.editMode = true
    
    -- Store original positions
    originalPositions = {
        petFeed = { point = self.db.petFeed.position.point, x = self.db.petFeed.position.x, y = self.db.petFeed.position.y },
        autoShot = { point = self.db.autoShot.position.point, x = self.db.autoShot.position.x, y = self.db.autoShot.position.y },
        aspects = self.db.aspects.position and { point = self.db.aspects.position.point, x = self.db.aspects.position.x, y = self.db.aspects.position.y } or nil,
        growl = self.db.growl.position and { point = self.db.growl.position.point, x = self.db.growl.position.x, y = self.db.growl.position.y } or nil,
    }
    
    -- Unlock all elements
    self.db.petFeed.locked = false
    self.db.autoShot.locked = false
    
    -- Show all elements
    if self.PetFeed and self.PetFeed.mainFrame then
        self.PetFeed.mainFrame:Show()
        self.PetFeed.mainFrame:SetAlpha(1)
    end
    if self.AutoShot and self.AutoShot.timerFrame then
        self.AutoShot.timerFrame:Show()
        self.AutoShot.timerFrame:SetAlpha(1)
    end
    if self.Aspects and self.Aspects.alertFrame then
        self.Aspects.alertFrame:Show()
        self.Aspects.alertFrame:SetAlpha(0.8)
    end
    if self.Growl and self.Growl.alertFrame then
        self.Growl.alertFrame:Show()
        self.Growl.alertFrame:SetAlpha(0.8)
    end
    -- New modules
    if self.Traps and self.Traps.trapFrame then
        self.Traps.trapFrame:Show()
        self.Traps.trapFrame:SetAlpha(1)
    end
    if self.Range and self.Range.rangeFrame then
        self.Range.rangeFrame:Show()
        self.Range.rangeFrame:SetAlpha(1)
    end
    if self.Ammo and self.Ammo.ammoFrame then
        self.Ammo.ammoFrame:Show()
        self.Ammo.ammoFrame:SetAlpha(1)
    end
    if self.PetReminder and self.PetReminder.reminderFrame and not InCombatLockdown() then
        self.PetReminder.reminderFrame:Show()
        self.PetReminder.reminderFrame:SetAlpha(1)
    end
    if self.PetReminder and self.PetReminder.mendFrame then
        self.PetReminder.mendFrame:Show()
        self.PetReminder.mendFrame:SetAlpha(1)
    end
    
    -- Show overlay
    CreateEditModeOverlay()
    editModeOverlay:Show()
    
    -- Fire callbacks
    self:FireEditModeCallbacks()
    
    print("|cff00ff00Hunter Suite|r |cffFFD700EDIT MODE|r - Drag elements to position them.")
end

-- Exit Edit Mode
function HunterSuite:ExitEditMode(save)
    self.state.editMode = false
    
    if save then
        print("|cff00ff00Hunter Suite|r Positions |cff00ff00saved|r!")
    else
        -- Restore original positions
        if originalPositions.petFeed and self.PetFeed and self.PetFeed.mainFrame then
            self.db.petFeed.position = originalPositions.petFeed
            self.PetFeed.mainFrame:ClearAllPoints()
            self.PetFeed.mainFrame:SetPoint(originalPositions.petFeed.point, UIParent, originalPositions.petFeed.point, originalPositions.petFeed.x, originalPositions.petFeed.y)
        end
        if originalPositions.autoShot and self.AutoShot and self.AutoShot.timerFrame then
            self.db.autoShot.position = originalPositions.autoShot
            self.AutoShot.timerFrame:ClearAllPoints()
            self.AutoShot.timerFrame:SetPoint(originalPositions.autoShot.point, UIParent, originalPositions.autoShot.point, originalPositions.autoShot.x, originalPositions.autoShot.y)
        end
        print("|cff00ff00Hunter Suite|r Positions |cffff6666cancelled|r - restored to previous.")
    end
    
    -- Hide overlay
    if editModeOverlay then
        editModeOverlay:Hide()
    end
    
    -- Restore normal visibility
    if self.PetFeed then self.PetFeed:UpdateUI() end
    if self.AutoShot then self.AutoShot:UpdateUI() end
    if self.Aspects then self.Aspects:CheckAspect() end
    if self.Growl then self.Growl:CheckGrowl() end
    -- New modules
    if self.Traps then self.Traps:UpdateUI() end
    if self.Range then self.Range:UpdateUI() end
    if self.Ammo then self.Ammo:UpdateUI() end
    if self.PetReminder then self.PetReminder:UpdateUI() end
    
    -- Fire callbacks
    self:FireEditModeCallbacks()
end

-- Check if in edit mode (used by modules)
function HunterSuite:IsEditMode()
    return self.state.editMode
end

-- Edit mode state change callbacks
HunterSuite.editModeCallbacks = {}

function HunterSuite:RegisterEditModeCallback(callback)
    table.insert(self.editModeCallbacks, callback)
end

function HunterSuite:FireEditModeCallbacks()
    for _, callback in ipairs(self.editModeCallbacks) do
        callback(self.state.editMode)
    end
end

-- Slash commands
SLASH_HUNTERSUITE1 = "/huntersuite"
SLASH_HUNTERSUITE2 = "/hs"
SlashCmdList["HUNTERSUITE"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "config" or msg == "options" or msg == "settings" then
        if HunterSuite.ShowSettings then
            HunterSuite:ShowSettings()
        end
    elseif msg == "edit" or msg == "move" or msg == "unlock" then
        HunterSuite:ToggleEditMode()
    elseif msg == "feed" then
        HunterSuite:FeedPet()
    elseif msg == "lock" then
        -- Exit edit mode if active
        if HunterSuite.state.editMode then
            HunterSuite:ToggleEditMode()
        end
        -- Toggle lock on all modules
        local locked = not HunterSuite.db.petFeed.locked
        HunterSuite.db.petFeed.locked = locked
        HunterSuite.db.autoShot.locked = locked
        print("|cff00ff00Hunter Suite|r " .. (locked and "locked" or "unlocked"))
    elseif msg == "reset" then
        HunterSuiteDB = nil
        HunterSuite:InitDB()
        print("|cff00ff00Hunter Suite|r settings reset to defaults!")
        ReloadUI()
    elseif msg == "debug" then
        print("|cff00ff00Hunter Suite|r Debug Info:")
        local db = HunterSuite.db.autoShot
        print("  showClippingMarkers: " .. tostring(db.showClippingMarkers))
        print("  showDelayTimer: " .. tostring(db.showDelayTimer))
        print("  showGCDBar: " .. tostring(db.showGCDBar))
        print("  oocAlpha: " .. tostring(db.oocAlpha))
        print("  enabled: " .. tostring(db.enabled))
        -- Check GCD detection
        local start, duration = GetSpellCooldown(3044)  -- Arcane Shot
        print("  GCD (Arcane Shot): start=" .. tostring(start) .. " dur=" .. tostring(duration))
        -- Pet info
        print("|cff00ff00Pet Info:|r")
        local petFamily = UnitCreatureFamily("pet") or "none"
        print("  Pet Family: " .. petFamily)
        local apiDiet = GetPetFoodTypes() or "none"
        print("  API Diet: " .. apiDiet)
        HunterSuite:UpdatePetState()
        local diet = table.concat(HunterSuite.state.petDiet, ", ")
        print("  Resolved Diet: " .. (diet ~= "" and diet or "none"))
        local food = HunterSuite:FindBestFood()
        if food then
            print("  Best Food: " .. (food.name or "ID:" .. food.itemID) .. " (type: " .. (HunterSuite.FoodDB[food.itemID] and HunterSuite.FoodDB[food.itemID].type or "unknown") .. ")")
        else
            print("  Best Food: none found")
        end
    elseif msg == "food" then
        print("|cff00ff00Hunter Suite|r Food in bags:")
        local foundAny = false
        for bag = 0, 4 do
            local numSlots = C_Container and C_Container.GetContainerNumSlots(bag) or GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local itemInfo
                if C_Container and C_Container.GetContainerItemInfo then
                    itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                else
                    local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bag, slot)
                    if texture then
                        itemInfo = { stackCount = itemCount }
                        if itemLink then itemInfo.itemID = GetItemInfoInstant(itemLink) end
                    end
                end
                if itemInfo and itemInfo.itemID then
                    local itemID = itemInfo.itemID
                    local foodEntry = HunterSuite.FoodDB[itemID]
                    if foodEntry then
                        local itemName = GetItemInfo(itemID) or ("ID:" .. itemID)
                        local count = GetItemCount(itemID) or 1
                        print("  " .. itemName .. " x" .. count .. " |cffaaaaaa(" .. foodEntry.type .. ", lvl " .. (foodEntry.level or "?") .. ")|r")
                        foundAny = true
                    end
                end
            end
        end
        if not foundAny then
            print("  No recognized pet food found!")
            print("  |cffaaaaaaYour pet eats: " .. table.concat(HunterSuite.state.petDiet or {}, ", ") .. "|r")
        end
    else
        if HunterSuite.ShowSettings then
            HunterSuite:ShowSettings()
        else
            print("|cff00ff00Hunter Suite|r Commands:")
            print("  |cffaaaaaa/hs config|r - Open settings")
            print("  |cffaaaaaa/hs edit|r - Toggle edit mode (show/move all elements)")
            print("  |cffaaaaaa/hs lock|r - Lock/unlock all bars")
            print("  |cffaaaaaa/hs feed|r - Feed pet now")
            print("  |cffaaaaaa/hs reset|r - Reset to defaults")
        end
    end
end
