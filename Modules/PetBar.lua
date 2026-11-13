--[[
    HunterSuite - pet card
    Portrait, happiness, health and the food it will use. Left-click feeds
    the best food in your bags, or the one picked from the food icon for
    this pet family; right-click casts Mend Pet. The card is a secure button,
    so visibility runs through a state driver that keeps working in combat.
]]

local _, HS = ...
local L = HS.L
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Pet = HS:NewModule("petBar", { title = L.PET_CARD_2, secure = true })

local HAPPINESS = {
    [1] = { label = L.UNHAPPY, color = "danger", damage = 75 },
    [2] = { label = L.CONTENT, color = "warn", damage = 100 },
    [3] = { label = L.HAPPY, color = "good", damage = 125 },
}
Pet.HAPPINESS = HAPPINESS

local Food = HS.Food
local FOOD_TYPE_LABELS = {
    L.FOOD_TYPE_MEAT, L.FOOD_TYPE_FISH, L.FOOD_TYPE_CHEESE, L.FOOD_TYPE_BREAD,
    L.FOOD_TYPE_FUNGUS, L.FOOD_TYPE_FRUIT, L.FOOD_TYPE_RAW_MEAT, L.FOOD_TYPE_RAW_FISH,
}

---------------------------------------------------------------------------
-- Food selection
---------------------------------------------------------------------------

-- Happiness gain falls off as food gets lower level than the pet.
local function FoodBand(petLevel, foodLevel)
    if not petLevel or not foodLevel then return 1 end
    local gap = petLevel - foodLevel
    if gap < 10 then return 3 end   -- full
    if gap < 20 then return 2 end   -- reduced
    if gap < 30 then return 1 end   -- low
    return 0                        -- refused
end
Pet.FoodBand = FoodBand
local BAND_LABEL = { [3] = L.FULL_HAPPINESS, [2] = L.REDUCED_HAPPINESS, [1] = L.LOW_HAPPINESS, [0] = L.TOO_LOW_LEVEL }
local BAND_COLOR = { [3] = "good", [2] = "warn", [1] = "danger", [0] = "danger" }

local function AddBandLine(band)
    local r, g, b = UI:Color(BAND_COLOR[band])
    GameTooltip:AddLine(BAND_LABEL[band], r, g, b)
end

-- A pet eats food type t (Data/Food.lua) when bit t of its diet mask is set.
local function Eats(mask, foodType)
    return math.floor(mask / 2 ^ (foodType - 1)) % 2 == 1
end

-- Diet names for display, and the mask the food table is matched against.
-- The client gives the names in its own language; Data/Food.lua knows them all.
function Pet:GetDiet()
    local names, mask = C.GetPetFoodTypes(), 0
    for _, name in ipairs(names) do
        local t = Food.dietNames[name:lower()]
        if t and not Eats(mask, t) then mask = mask + 2 ^ (t - 1) end
    end
    if mask == 0 then
        local family, familyID = UnitCreatureFamily("pet")
        mask = Food.FamilyDiet(C.Readable(family), C.Readable(familyID))
        if #names == 0 then
            for t, name in ipairs(FOOD_TYPE_LABELS) do
                if Eats(mask, t) then names[#names + 1] = name end
            end
        end
    end
    return names, mask
end

-- Scan bags; returns the chosen food and the list of all candidates.
function Pet:FindFood()
    local petLevel = C.Readable(UnitLevel("pet"))
    local _, diet = self:GetDiet()
    -- Foods the game refused are remembered per pet.
    local who = C.Readable(UnitGUID("pet")) or C.Readable(UnitName("pet"))
    if who ~= self.refusedPet then
        self.refused, self.refusedPet = {}, who
    end
    local refused, never = self.refused, HS.char.neverFeed
    local seen, list = {}, {}
    C.ForEachBagItem(function(bag, slot, itemID)
        -- Feed from the smallest stack of each food so partial stacks go first.
        local stack = C.GetContainerItemCount(bag, slot)
        local known = seen[itemID]
        if known then
            if known ~= true and stack < known.stack then
                known.bag, known.slot, known.stack = bag, slot, stack
            end
            return
        end
        seen[itemID] = true
        local edible = C.CanPetEat(itemID)
        local entry = Food.items[itemID]
        if edible == nil then
            edible = entry ~= nil and Eats(diet, entry[1])
        end
        if not edible or refused[itemID] then return end
        local name, _, _, itemLevel = C.GetItemInfo(itemID)
        itemLevel = itemLevel or (entry and entry[2])
        local band = FoodBand(petLevel, itemLevel)
        if band == 0 then return end
        local food = {
            itemID = itemID, name = name, level = itemLevel or 0, band = band,
            count = C.GetItemCount(itemID), icon = C.GetItemIcon(itemID),
            bag = bag, slot = slot, stack = stack, blocked = never[itemID] == true,
        }
        seen[itemID] = food
        list[#list + 1] = food
    end)

    local mode = self.db.foodMode
    table.sort(list, function(a, b)
        -- Never-fed foods stay in the list (the picker shows them) but go last.
        if a.blocked ~= b.blocked then return b.blocked end
        if mode == "highest" then
            if a.level ~= b.level then return a.level > b.level end
        elseif mode == "lowest" then
            if a.level ~= b.level then return a.level < b.level end
        elseif mode == "mostStacked" then
            if a.count ~= b.count then return a.count > b.count end
        elseif mode == "leastStacked" then
            if a.count ~= b.count then return a.count < b.count end
        else -- smart: best happiness band, then the cheapest food in it, then use up small stacks
            if a.band ~= b.band then return a.band > b.band end
            if a.level ~= b.level then return a.level < b.level end
            if a.count ~= b.count then return a.count < b.count end
        end
        return a.itemID < b.itemID
    end)
    local best = list[1]
    if best and best.blocked then best = nil end
    return best, list
end

---------------------------------------------------------------------------
-- Picked food
---------------------------------------------------------------------------

-- A food picked from the card's food icon is kept per pet family on this
-- character. The card then feeds only that food, and shows no food rather
-- than falling back to another one when it runs out. Foods right-clicked in
-- the list are never fed on Auto; a food is never both picked and never fed.

local function ItemName(itemID)
    return (C.GetItemInfo(itemID)) or L.ITEM_D:format(itemID)
end

-- Forever returns the family ID as well as the localised name; TBC only the name.
function Pet:FamilyKey()
    local name, id = UnitCreatureFamily("pet")
    name, id = C.Readable(name), C.Readable(id)
    if id or name then
        self.familyKey, self.familyName = id or name, name
    end
    return self.familyKey, self.familyName
end

function Pet:ChosenFood()
    local key = self:FamilyKey()
    return key and HS.char.petFood[key] or nil
end

-- The food the card feeds, every food the pet will eat, and the picked item if any.
function Pet:PickFood()
    local best, list = self:FindFood()
    local chosen = self:ChosenFood()
    if not chosen then return best, list, nil end
    for _, food in ipairs(list) do
        if food.itemID == chosen then return food, list, chosen end
    end
    return nil, list, chosen
end

-- itemID nil goes back to Auto. Picking a never-fed food takes it off that list.
function Pet:ChooseFood(itemID)
    local key = self:FamilyKey()
    if not key or InCombatLockdown() then return end
    HS.char.petFood[key] = itemID
    if itemID then HS.char.neverFeed[itemID] = nil end
    self:UpdateFood()
end

function Pet:IsNeverFed(itemID)
    return HS.char.neverFeed[itemID] == true
end

-- Never feeding a picked food sends every family that picked it back to Auto.
function Pet:SetNeverFeed(itemID, never)
    if InCombatLockdown() then return end
    HS.char.neverFeed[itemID] = never and true or nil
    if never then
        for key, picked in pairs(HS.char.petFood) do
            if picked == itemID then HS.char.petFood[key] = nil end
        end
    end
    self:UpdateFood()
end

-- Settings button. Works with the pet card off too.
function Pet:AllowAllFoods()
    local count = 0
    for _ in pairs(HS.char.neverFeed) do count = count + 1 end
    HS.char.neverFeed = {}
    if count == 0 then
        HS:Print(L.NO_FOODS_ARE_NEVER_FED)
    else
        HS:Print(L.FOODS_ALLOWED_AGAIN_D, count)
    end
    if self.enabled and not InCombatLockdown() then self:UpdateFood() end
end

-- Why Auto has nothing to feed.
local function NoFoodText(list)
    for _, food in ipairs(list or {}) do
        if food.blocked then return L.ONLY_NEVER_FED_FOODS_LEFT end
    end
    return L.NO_FOOD_YOUR_PET_WILL_EAT_IS_IN_YOUR_BAGS
end

-- Why the picked food isn't being fed: none left, or the pet won't take it.
function Pet:MissingText(itemID)
    if C.GetItemCount(itemID) > 0 then return L.YOUR_PET_WONT_EAT_S:format(ItemName(itemID)), L.WONT_EAT end
    return L.NO_S_LEFT_IN_YOUR_BAGS:format(ItemName(itemID)), L.NONE_LEFT
end

---------------------------------------------------------------------------
-- Secure actions
---------------------------------------------------------------------------

-- Left click casts Feed Pet and the secure template then targets the food's
-- bag slot itself (target-bag / target-slot). No macro is involved, so the
-- button also works from /click inside a player's own macro.
function Pet:ApplyActions()
    HS:RunOutOfCombat(function()
        local food = self.food
        self.armedFood = food
        local feed = S.Name(S.FEED_PET) or L.FEED_PET
        local mend = S.Name(S.MEND_PET) or L.MEND_PET
        -- "*" so shift/ctrl/alt clicks and modified key bindings still match.
        for _, btn in ipairs({ self.card, self.feedButton }) do
            if btn then
                btn:SetAttribute("*type1", "spell")
                btn:SetAttribute("*spell1", feed)
                btn:SetAttribute("*target-bag1", food and food.bag or nil)
                btn:SetAttribute("*target-slot1", food and food.slot or nil)
                btn:SetAttribute("*type2", "spell")
                btn:SetAttribute("*spell2", mend)
            end
        end
    end, "petbar-actions")
end

function Pet:UpdateFood()
    if not UnitExists("pet") then
        self.food, self.foodList, self.chosen = nil, nil, nil
    else
        self.food, self.foodList, self.chosen = self:PickFood()
    end
    self:PaintFood()
    self:ApplyActions()
    if self.picker and self.picker:IsShown() then self:PaintPicker() end
end

-- Prints the food choice (/hs feed).
function Pet:ReportFood()
    if not UnitExists("pet") then
        HS:Print(L.NO_PET_OUT)
        return
    end
    local food, list, chosen = self:PickFood()
    local _, family = self:FamilyKey()
    if chosen and not food then
        HS:Print("%s %s", (self:MissingText(chosen)), L.PICKED_FOOD_EMPTY_HINT)
        return
    end
    local others, never = {}, {}
    for _, other in ipairs(list) do
        local label = (other.name or other.itemID) .. " x" .. other.count
        if other.blocked then
            never[#never + 1] = label
        elseif other ~= food and #others < 4 then
            others[#others + 1] = label
        end
    end
    if not food then
        if #never > 0 then
            HS:Print(L.ONLY_NEVER_FED_FOODS_LEFT)
        else
            HS:Print(L.NO_FOOD_WITH_DIET, table.concat(self:GetDiet(), ", "))
        end
    else
        HS:Print(L.FEEDING_SELECTED_FOOD,
            food.name or L.ITEM_D:format(food.itemID), food.count, BAND_LABEL[food.band]:lower())
        if chosen then
            HS:Print(L.PICKED_FOOD_HINT_S, family or L.PET)
        elseif #others > 0 then
            HS:Print(L.ALSO_EDIBLE_S, table.concat(others, ", "))
        end
    end
    if #never > 0 then HS:Print(L.NEVER_FED_S, table.concat(never, ", ")) end
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local CARD_H = 48

function Pet:Build()
    local db = self.db
    local card = UI:Element("HunterSuitePetCard", db, L.PET, "SecureActionButtonTemplate")
    card:RegisterForClicks("AnyUp", "AnyDown")
    card:SetSize(db.width, CARD_H)
    UI:Surface(card, { radius = 6, color = "bg", border = { 1, 1, 1, 0.07 }, shadow = true })
    self.card = card

    -- Portrait with a happiness ring.
    local ring = card:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetTexture(UI.tex.circle)
    ring:SetSize(38, 38)
    ring:SetPoint("LEFT", 6, 0)
    card.ring = ring
    local portraitBg = card:CreateTexture(nil, "ARTWORK", nil, 2)
    portraitBg:SetTexture(UI.tex.circle)
    portraitBg:SetVertexColor(0.02, 0.02, 0.03, 1)
    portraitBg:SetSize(34, 34)
    portraitBg:SetPoint("CENTER", ring)
    local portrait = card:CreateTexture(nil, "ARTWORK", nil, 3)
    portrait:SetSize(32, 32)
    portrait:SetPoint("CENTER", ring)
    local mask = card:CreateMaskTexture()
    mask:SetTexture(UI.tex.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    card.portrait = portrait

    -- Name / level and mood.
    -- Top row: name on the left, the food the card will use on the right.
    -- The 38px ring is centred in the 48px card, so its top/bottom sit 5px in.
    local food = card:CreateTexture(nil, "OVERLAY")
    food:SetSize(14, 14)
    food:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    food:SetPoint("TOPRIGHT", -8, -6)
    card.foodIcon = food
    card.foodText = UI:Text(card, { size = 10, color = "textDim" })
    card.foodText:SetPoint("RIGHT", food, "LEFT", -4, 0)

    -- The food icon opens the food picker. It's a plain button over the
    -- secure card, so it never touches the card's attributes.
    local pick = CreateFrame("Button", nil, card)
    pick:SetSize(20, 20)
    pick:SetPoint("CENTER", food)
    pick:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pick.ring = UI:Border(pick, "accent")
    pick.ring:SetShown(false)
    pick:SetScript("OnClick", function() Pet:TogglePicker() end)
    pick:SetScript("OnEnter", function(btn)
        btn.hover = true
        Pet:PaintPickRing()
        Pet:ShowFoodTooltip(btn)
    end)
    pick:SetScript("OnLeave", function(btn)
        btn.hover = false
        Pet:PaintPickRing()
        GameTooltip:Hide()
    end)
    card.foodPick = pick

    card.name = UI:Text(card, { size = 12, color = "text" })
    card.name:SetPoint("TOPLEFT", ring, "TOPRIGHT", 8, -2)
    card.name:SetPoint("TOPRIGHT", card, "TOPRIGHT", -64, -7)
    card.name:SetJustifyH("LEFT")

    -- Bottom row: health bar carrying the mood (left) and health (right).
    local hp = UI:Bar(card, { height = 14 })
    hp:SetPoint("BOTTOMLEFT", ring, "BOTTOMRIGHT", 8, 4)
    hp:SetPoint("BOTTOMRIGHT", -8, 9)
    card.hp = hp
    card.mood = UI:Text(hp.bar, { size = 10, flags = "OUTLINE", color = "text" })
    card.mood:SetPoint("LEFT", 4, 0)
    card.hpText = UI:Text(hp.bar, { size = 10, flags = "OUTLINE", color = "text" })
    card.hpText:SetPoint("RIGHT", -4, 0)

    -- Feeding progress along the bottom edge.
    local feeding = UI:Bar(card, { height = 3, spark = false, border = false })
    feeding:SetPoint("BOTTOMLEFT", 6, 2)
    feeding:SetPoint("BOTTOMRIGHT", -6, 2)
    feeding:SetFillColor(UI:Color("info"))
    feeding:Hide()
    card.feeding = feeding

    card:SetScript("OnEnter", function(btn) Pet:ShowTooltip(btn) end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Keybinding / macro target with the same actions.
    -- /click sends only a release, so act on release (bindings send both).
    local fb = CreateFrame("Button", "HunterSuiteFeedButton", UIParent, "SecureActionButtonTemplate")
    fb:RegisterForClicks("AnyUp", "AnyDown")
    fb:SetAttribute("useOnKeyDown", false)
    fb:Hide()
    self.feedButton = fb

    HS.Movers:Register(card, { label = L.PET, defaultPath = "petBar.position", module = "petBar" })
end

function Pet:Layout()
    local card, db = self.card, self.db
    local compact = db.style == "compact"
    HS:RunOutOfCombat(function()
        card:SetSize(compact and 150 or db.width, CARD_H)
        UI:ApplyPosition(card)
    end, "petbar-layout")
    card.name:SetShown(not compact)
    card.foodText:SetShown(not compact)
    card.portrait:SetShown(db.showPortrait ~= false)
    card.hpText:SetShown(db.showHealthText ~= false)
end

---------------------------------------------------------------------------
-- Painting
---------------------------------------------------------------------------

function Pet:PaintFood()
    local card = self.card
    if not card then return end
    local food, chosen = self.food, self.chosen
    if food then
        card.foodIcon:SetTexture(food.icon)
        card.foodIcon:SetDesaturated(false)
        card.foodIcon:Show()
        card.foodText:SetText(food.count)
        card.foodText:SetTextColor(UI:Color(food.count <= 5 and "warn" or "textDim"))
    elseif UnitExists("pet") then
        -- A picked food that ran out stays on the card, greyed, so it's clear
        -- what the card is waiting for.
        card.foodIcon:SetTexture(chosen and C.GetItemIcon(chosen) or 133971)
        card.foodIcon:SetDesaturated(true)
        card.foodIcon:Show()
        card.foodText:SetText(L.NO_FOOD)
        card.foodText:SetTextColor(UI:Color("danger"))
    else
        card.foodIcon:Hide()
        card.foodText:SetText("")
    end
    card.foodPick:SetShown(UnitExists("pet") == true)
    self:PaintPickRing()
end

-- Accent ring while a picked food is in charge, faint ring on hover.
function Pet:PaintPickRing()
    local pick = self.card.foodPick
    if self.chosen then
        pick.ring:SetColor(UI:Accent())
        pick.ring:SetShown(true)
    elseif pick.hover then
        pick.ring:SetColor(1, 1, 1, 0.3)
        pick.ring:SetShown(true)
    else
        pick.ring:SetShown(false)
    end
end

function Pet:PaintIdentity()
    local card = self.card
    SetPortraitTexture(card.portrait, "pet")
    local name = UnitName("pet")
    local level = UnitLevel("pet")
    if C.IsSecret(name) or C.IsSecret(level) then
        card.name:SetText(name)
    else
        card.name:SetText(("%s |c%s%s|r"):format(name or L.PET, UI:Hex("textMute"), level or ""))
    end
end

function Pet:PaintHappiness()
    local card = self.card
    local happiness = C.GetPetHappiness()
    self.happiness = happiness
    local spec = HAPPINESS[happiness or 0]
    if spec then
        local r, g, b = UI:Color(spec.color)
        card.ring:SetVertexColor(r, g, b, 1)
        card.mood:SetText(("|T%s:8:8:0:0:64:64:0:64:0:64:%d:%d:%d|t %s"):format(UI.tex.circle, r * 255, g * 255, b * 255, spec.label))
    else
        card.ring:SetVertexColor(UI:Color("border"))
        card.mood:SetText("")
    end
    if happiness == 1 and self.lastHappiness and self.lastHappiness > 1 and self.db.soundOnUnhappy then
        C.PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
    end
    self.lastHappiness = happiness
end

-- Pet health colour from a curve, evaluated in C so it works while health
-- is secret in combat.
local healthCurve
local function BuildHealthCurve(threshold)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent and CreateColor) then return nil end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateColorCurve()
        if Enum.LuaCurveType then c:SetType(Enum.LuaCurveType.Step) end
        local dr, dg, db = UI:Color("danger")
        local gr, gg, gb = UI:Color("good")
        c:AddPoint(0, CreateColor(dr, dg, db, 1))
        c:AddPoint(threshold, CreateColor(gr, gg, gb, 1))
        return c
    end)
    return ok and curve or nil
end

function Pet:PaintHealth()
    local card = self.card
    local hp, maxHP = UnitHealth("pet"), UnitHealthMax("pet")
    card.hp:SetRange(0, maxHP)
    card.hp:SetValueSmooth(hp)

    local frac = C.UnitHealthFraction("pet")
    local low = false
    if frac then
        low = frac < self.db.mendThreshold and not self.mending
        card.hp:SetFillColor(UI:Color(low and "danger" or "good"))
        card.hpText:SetFormattedText("%d%%", math.floor(frac * 100 + 0.5))
    else
        -- Secret health: let the client pick the colour and print the value.
        local colored = false
        if healthCurve then
            local ok, color = pcall(UnitHealthPercent, "pet", true, healthCurve)
            if ok and color and color.GetRGB then
                card.hp.bar:SetStatusBarColor(color:GetRGB())
                colored = true
            end
        end
        if not colored then card.hp:SetFillColor(UI:Color("good")) end
        card.hpText:SetText(hp)
    end
    self.lowHealth = low
    self:PaintAttention()
end

function Pet:PaintAuras()
    local card = self.card
    if C.AurasRestricted() then return end
    local feedIDs = S.Sets(S.FEED_PET_EFFECT)
    local mendIDs, mendNames = S.Sets(S.MEND_PET)
    local feed = C.FindAura("pet", "HELPFUL", feedIDs, { [S.Name(S.FEED_PET_EFFECT) or "Feed Pet Effect"] = true })
    local mend = C.FindAura("pet", "HELPFUL", mendIDs, mendNames)
    self.mending = mend ~= nil
    local duration, expiration = C.AuraTimes(feed)
    if duration and duration > 0 then
        card.feeding:SetRange(0, duration)
        card.feeding.expiration = expiration
        card.feeding:SetValueNow(expiration - GetTime())
        card.feeding:Show()
        card.feeding:SetScript("OnUpdate", function(bar)
            local left = bar.expiration - GetTime()
            if left <= 0 then
                bar:Hide()
                bar:SetScript("OnUpdate", nil)
            else
                bar.bar:SetValue(left)
            end
        end)
    else
        card.feeding:Hide()
        card.feeding:SetScript("OnUpdate", nil)
    end
end

function Pet:PaintAttention()
    local card = self.card
    local unhappy = self.happiness == 1
    if self.lowHealth then
        UI:SetGlow(card, true, "danger")
        UI:SetBorderColor(card, "danger", 0.6)
    elseif unhappy then
        UI:SetGlow(card, true, "warn")
        UI:SetBorderColor(card, "warn", 0.5)
    else
        UI:SetGlow(card, false)
        UI:SetBorderColor(card, { 1, 1, 1, 0.07 })
    end
end

function Pet:PaintAll()
    if not self.card then return end
    if not UnitExists("pet") then
        self:PaintFood()
        return
    end
    self:PaintIdentity()
    self:PaintHappiness()
    self:PaintAuras()
    self:PaintHealth()
    self:PaintFood()
end

---------------------------------------------------------------------------
-- Visibility (state driver so it works in combat)
---------------------------------------------------------------------------

function Pet:NeedsAttention()
    if (self.happiness or 3) < (self.db.happyHideThreshold or 3) then return true end
    if self.lowHealth then return true end
    return false
end

function Pet:UpdateVisibility()
    HS:RunOutOfCombat(function()
        local card = self.card
        if not card then return end
        if not self.enabled then
            UnregisterStateDriver(card, "visibility")
            card:Hide()
            return
        end
        if HS.state.editMode then
            UnregisterStateDriver(card, "visibility")
            card:Show()
            return
        end
        local mode = self.db.visibility
        local rule
        if mode == "always" then
            rule = "[nopet][@pet,dead] hide; show"
        elseif mode == "combat" then
            rule = "[nopet][@pet,dead] hide; [combat] show; hide"
        else
            rule = "[nopet][@pet,dead] hide; [combat] show; " .. (self:NeedsAttention() and "show" or "hide")
        end
        if rule ~= self.rule then
            self.rule = rule
            RegisterStateDriver(card, "visibility", rule)
        end
    end, "petbar-visibility")
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

function Pet:ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP", 0, 6)
    if HS.state.editMode or not UnitExists("pet") then
        GameTooltip:AddLine(L.PET_CARD, 1, 1, 1)
        GameTooltip:AddLine(L.SHOWS_YOUR_PET_S_MOOD_HEALTH_AND_FOOD, 0.75, 0.77, 0.8, true)
        GameTooltip:Show()
        return
    end
    local name = C.Readable(UnitName("pet"))
    local family = UnitCreatureFamily("pet")
    GameTooltip:AddDoubleLine(name or L.PET, C.Readable(family) or "", 1, 1, 1, 0.6, 0.62, 0.66)
    local happiness, damage = C.GetPetHappiness()
    local spec = HAPPINESS[happiness or 0]
    if spec then
        local r, g, b = UI:Color(spec.color)
        GameTooltip:AddDoubleLine(L.MOOD, (L.S_D_DAMAGE):format(spec.label, damage or spec.damage), 0.75, 0.77, 0.8, r, g, b)
    end
    local loyalty = C.GetPetLoyalty()
    if loyalty then
        GameTooltip:AddDoubleLine(L.LOYALTY, loyalty, 0.75, 0.77, 0.8, 1, 1, 1)
    end
    local diet = self:GetDiet()
    if #diet > 0 then
        GameTooltip:AddDoubleLine(L.DIET, table.concat(diet, ", "), 0.75, 0.77, 0.8, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    local food, chosen = self.food, self.chosen
    if food then
        local r, g, b = UI:Color(BAND_COLOR[food.band])
        GameTooltip:AddDoubleLine(L.FOOD, ("%s x%d"):format(food.name or "?", food.count), 0.75, 0.77, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(" ", BAND_LABEL[food.band], 0.75, 0.77, 0.8, r, g, b)
    elseif chosen then
        GameTooltip:AddLine((self:MissingText(chosen)), 1, 0.45, 0.45, true)
    else
        GameTooltip:AddLine(NoFoodText(self.foodList), 1, 0.45, 0.45, true)
    end
    if chosen then
        local _, family = self:FamilyKey()
        GameTooltip:AddDoubleLine(" ", L.YOUR_PICK_FOR_S:format(family or L.PET), 0.75, 0.77, 0.8, UI:Accent())
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.LEFT_CLICK, L.FEED_PET, 0.67, 0.83, 0.45, 0.9, 0.9, 0.9)
    GameTooltip:AddDoubleLine(L.RIGHT_CLICK, L.MEND_PET, 0.67, 0.83, 0.45, 0.9, 0.9, 0.9)
    GameTooltip:AddDoubleLine(L.FOOD_ICON, L.CHOOSE_FOOD, 0.67, 0.83, 0.45, 0.9, 0.9, 0.9)
    GameTooltip:Show()
end

-- Over the food icon: just the food, and what a click does.
function Pet:ShowFoodTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP", 0, 6)
    local food, chosen = self.food, self.chosen
    if food then
        GameTooltip:AddDoubleLine(food.name or "?", "x" .. food.count, 1, 1, 1, 0.75, 0.77, 0.8)
        AddBandLine(food.band)
    elseif chosen then
        GameTooltip:AddLine(ItemName(chosen), 1, 1, 1)
        GameTooltip:AddLine((self:MissingText(chosen)), 1, 0.45, 0.45, true)
    else
        GameTooltip:AddLine(NoFoodText(self.foodList), 1, 0.45, 0.45, true)
    end
    if chosen then
        local _, family = self:FamilyKey()
        GameTooltip:AddLine(L.YOUR_PICK_FOR_S:format(family or L.PET), UI:Accent())
    else
        GameTooltip:AddLine(L.PICKED_AUTOMATICALLY, 0.6, 0.62, 0.66)
    end
    GameTooltip:AddLine(" ")
    if InCombatLockdown() then
        GameTooltip:AddLine(L.CHOOSE_A_FOOD_OUT_OF_COMBAT, 0.6, 0.62, 0.66, true)
    else
        GameTooltip:AddDoubleLine(L.CLICK, L.CHOOSE_FOOD, 0.67, 0.83, 0.45, 0.9, 0.9, 0.9)
    end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Food picker
---------------------------------------------------------------------------

local PICK_ROW, PICK_WIDTH, PICK_MAX, PICK_TOP = 24, 230, 10, 26
local NAME_COLOR = { [3] = "text", [2] = "warn", [1] = "danger" }

-- What Auto would feed: the list is sorted with never-fed foods last.
local function AutoBest(list)
    local best = list and list[1]
    if best and not best.blocked then return best end
end

local function ClickLine(button, action)
    GameTooltip:AddDoubleLine(button, action, 0.67, 0.83, 0.45, 0.9, 0.9, 0.9)
end

local function PickerRow(picker, i)
    local row = CreateFrame("Button", nil, picker)
    row:SetHeight(PICK_ROW)
    row:SetPoint("TOPLEFT", 4, -PICK_TOP - (i - 1) * PICK_ROW)
    row:SetPoint("TOPRIGHT", -4, -PICK_TOP - (i - 1) * PICK_ROW)
    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetTexture(UI.tex.white)
    hl:SetVertexColor(1, 1, 1, 0)
    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetTexture(UI.tex.check)
    row.check:SetSize(12, 12)
    row.check:SetPoint("LEFT", 6, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:SetPoint("LEFT", 24, 0)
    row.count = UI:Text(row, { size = 10, color = "textDim" })
    row.count:SetPoint("RIGHT", -8, 0)
    row.name = UI:Text(row, { size = 12 })
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function(btn)
        if btn.entry and btn.entry.header then return end
        hl:SetVertexColor(1, 1, 1, 0.06)
        Pet:ShowPickerTooltip(btn)
    end)
    row:SetScript("OnLeave", function()
        hl:SetVertexColor(1, 1, 1, 0)
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(btn, button)
        local entry = btn.entry
        if not entry or entry.header then return end
        -- Right-click marks a food never fed (or allows it again) and keeps
        -- the list open, so several can be set in one go.
        if button == "RightButton" then
            local itemID = entry.food and entry.food.itemID or entry.missing
            if itemID then
                Pet:SetNeverFeed(itemID, not Pet:IsNeverFed(itemID))
                -- The list re-sorted, so this row may now hold another food.
                GameTooltip:Hide()
                if btn:IsShown() and btn.entry and not btn.entry.header then
                    Pet:ShowPickerTooltip(btn)
                else
                    hl:SetVertexColor(1, 1, 1, 0)
                end
            end
            return
        end
        picker:Hide()
        if entry.auto then
            Pet:ChooseFood(nil)
        elseif entry.food then
            Pet:ChooseFood(entry.food.itemID)
        end
    end)
    return row
end

function Pet:BuildPicker()
    local p = CreateFrame("Frame", "HunterSuiteFoodPicker", UIParent)
    p:SetFrameStrata("DIALOG")
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:EnableMouseWheel(true)
    p:Hide()
    UI:Surface(p, { radius = 6, color = "surface2", shadow = true })
    p.title = UI:Text(p, { size = 10, color = "textMute" })
    p.title:SetPoint("TOPLEFT", 10, -9)
    p.title:SetPoint("TOPRIGHT", -10, -9)
    p.title:SetJustifyH("LEFT")
    p.rows, p.entries, p.offset = {}, {}, 0
    p:SetScript("OnMouseWheel", function(frame, delta)
        frame.offset = math.max(0, math.min(#frame.entries - PICK_MAX, frame.offset - delta))
        self:PaintPicker()
    end)
    -- A click anywhere else closes the list. Tied to show/hide so hiding the
    -- whole UI (Alt+Z) and bringing it back keeps this working.
    p:SetScript("OnShow", function()
        self.events:On("GLOBAL_MOUSE_DOWN", function()
            if not (p:IsMouseOver() or self.card.foodPick:IsMouseOver()) then p:Hide() end
        end)
    end)
    p:SetScript("OnHide", function() self.events:Off("GLOBAL_MOUSE_DOWN") end)
    tinsert(UISpecialFrames, "HunterSuiteFoodPicker")
    self.picker = p
end

-- Auto on top, then the picked food if it ran out, then every food the pet
-- will eat in the order Auto ranks them, then the never-fed ones.
function Pet:PaintPicker()
    local p, list, chosen = self.picker, self.foodList or {}, self.chosen
    local entries = { { auto = true } }
    if chosen and not self.food then entries[2] = { missing = chosen } end
    local header = false
    for _, food in ipairs(list) do
        if food.blocked and not header then
            header = true
            entries[#entries + 1] = { header = L.NEVER_FED }
        end
        entries[#entries + 1] = { food = food }
    end
    p.entries = entries
    local visible = math.min(#entries, PICK_MAX)
    p.offset = math.max(0, math.min(p.offset, #entries - visible))
    for i = #p.rows + 1, visible do p.rows[i] = PickerRow(p, i) end

    local _, family = self:FamilyKey()
    p.title:SetText(L.FOOD_FOR_S:format(family or L.PET))
    for i, row in ipairs(p.rows) do
        local entry = i <= visible and entries[i + p.offset] or nil
        row.entry = entry
        if entry then
            local icon, name, count, nameColor, countColor, active
            if entry.header then
                name, count, nameColor, countColor, active = entry.header, "", "textMute", "textMute", false
            elseif entry.auto then
                local best = AutoBest(list)
                icon, name, count = best and best.icon or 133971, L.AUTO, ""
                nameColor, countColor, active = "text", "textDim", chosen == nil
                row.icon:SetDesaturated(best == nil)
            elseif entry.food and entry.food.blocked then
                local food = entry.food
                icon, name, count = food.icon, food.name or L.ITEM_D:format(food.itemID), food.count
                nameColor, countColor, active = "textMute", "textMute", false
                row.icon:SetDesaturated(true)
            elseif entry.missing then
                local _, short = self:MissingText(entry.missing)
                icon, name, count = C.GetItemIcon(entry.missing) or 133971, ItemName(entry.missing), short
                nameColor, countColor, active = "textMute", "danger", true
                row.icon:SetDesaturated(true)
            else
                local food = entry.food
                icon, name, count = food.icon, food.name or L.ITEM_D:format(food.itemID), food.count
                nameColor, countColor, active = NAME_COLOR[food.band], "textDim", food.itemID == chosen
                row.icon:SetDesaturated(false)
            end
            row.icon:SetTexture(icon)
            row.icon:SetShown(icon ~= nil)
            UI:SetTextSize(row.name, entry.header and 10 or 12)
            row.name:SetText(name)
            row.name:SetTextColor(UI:Color(nameColor))
            row.count:SetText(count)
            row.count:SetTextColor(UI:Color(countColor))
            row.check:SetVertexColor(UI:Accent())
            row.check:SetShown(active)
            row:Show()
        else
            row:Hide()
        end
    end
    p:SetSize(PICK_WIDTH, PICK_TOP + visible * PICK_ROW + 4)
end

function Pet:ShowPickerTooltip(row)
    local entry = row.entry
    if not entry then return end
    if entry.header then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if entry.auto then
        GameTooltip:AddLine(L.AUTO, 1, 1, 1)
        GameTooltip:AddLine(L.AUTO_FOOD_DESCRIPTION, 0.75, 0.77, 0.8, true)
        local best = AutoBest(self.foodList)
        if best then
            GameTooltip:AddLine(L.NOW_S:format(best.name or L.ITEM_D:format(best.itemID)), 0.9, 0.9, 0.9)
        else
            GameTooltip:AddLine(NoFoodText(self.foodList), 1, 0.45, 0.45, true)
        end
    elseif entry.missing then
        GameTooltip:AddLine(ItemName(entry.missing), 1, 1, 1)
        GameTooltip:AddLine((self:MissingText(entry.missing)), 1, 0.45, 0.45, true)
        GameTooltip:AddLine(" ")
        ClickLine(L.RIGHT_CLICK, L.NEVER_FEED)
    else
        local food = entry.food
        GameTooltip:AddDoubleLine(food.name or L.ITEM_D:format(food.itemID), "x" .. food.count, 1, 1, 1, 0.75, 0.77, 0.8)
        if food.blocked then
            GameTooltip:AddLine(L.NEVER_FED_DESCRIPTION, 0.75, 0.77, 0.8, true)
        else
            AddBandLine(food.band)
        end
        GameTooltip:AddLine(" ")
        ClickLine(L.LEFT_CLICK, L.FEED_ONLY_THIS)
        ClickLine(L.RIGHT_CLICK, food.blocked and L.ALLOW_AGAIN or L.NEVER_FEED)
    end
    GameTooltip:Show()
end

function Pet:ClosePicker()
    if self.picker then self.picker:Hide() end
end

function Pet:TogglePicker()
    local p = self.picker
    if p and p:IsShown() then
        p:Hide()
        return
    end
    -- Out of combat only: the card's food can't be re-aimed until combat ends.
    if InCombatLockdown() or HS.state.editMode or not UnitExists("pet") or not self:FamilyKey() then return end
    if not p then
        self:BuildPicker()
        p = self.picker
    end
    self:UpdateFood()
    p.offset = 0
    self:PaintPicker()
    -- Open away from the nearer screen edge.
    local card = self.card
    local _, y = card:GetCenter()
    local scale = card:GetEffectiveScale() / UIParent:GetEffectiveScale()
    p:SetScale(scale)
    p:ClearAllPoints()
    if y and y * scale < UIParent:GetHeight() / 2 then
        p:SetPoint("BOTTOMRIGHT", card, "TOPRIGHT", 0, 4)
    else
        p:SetPoint("TOPRIGHT", card, "BOTTOMRIGHT", 0, -4)
    end
    p:Show()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function Pet:OnInitialize()
    self:Build()
    self.events = HS:Events(self)
    self.refused = {}
    healthCurve = BuildHealthCurve(self.db.mendThreshold)
    -- Note what a left-click is about to feed, so a refusal can be pinned on it.
    local function noteFeed(_, button)
        if button == "LeftButton" then self.lastFeed = { food = self.armedFood, time = GetTime() } end
    end
    self.card:HookScript("PreClick", noteFeed)
    self.feedButton:HookScript("PreClick", noteFeed)
end

local function FullUpdate(self)
    self:PaintAll()
    self:UpdateFood()
    self:UpdateVisibility()
end

function Pet:OnEnable()
    local ev = self.events
    ev:On("UNIT_PET", function(_, _, unit)
        if unit ~= "player" then return end
        self.familyKey, self.familyName = nil, nil
        self:ClosePicker()
        C_Timer.After(0.2, function() FullUpdate(self) end)
    end)
    ev:On("PLAYER_ENTERING_WORLD", function() FullUpdate(self) end)
    ev:On("UNIT_HAPPINESS", function() self:PaintHappiness(); self:PaintAttention(); self:UpdateVisibility() end, "pet")
    ev:On("PET_UI_UPDATE", function() self:PaintHappiness(); self:PaintAttention() end)
    ev:On("UNIT_HEALTH", function() self:PaintHealth(); self:UpdateVisibility() end, "pet")
    ev:On("UNIT_MAXHEALTH", function() self:PaintHealth() end, "pet")
    ev:On("UNIT_AURA", function() self:PaintAuras(); self:PaintHealth() end, "pet")
    ev:On("UNIT_PORTRAIT_UPDATE", function() self:PaintIdentity() end, "pet")
    ev:On("UNIT_NAME_UPDATE", function() self:PaintIdentity() end, "pet")
    ev:On("UNIT_LEVEL", function() self:PaintIdentity(); self:UpdateFood() end, "pet")
    ev:On("LOCALPLAYER_PET_RENAMED", function() self:PaintIdentity() end)
    ev:On("BAG_UPDATE_DELAYED", function() self:UpdateFood() end)
    ev:On("GET_ITEM_INFO_RECEIVED", function()
        if not self.itemInfoPending then
            self.itemInfoPending = true
            C_Timer.After(0.5, function() self.itemInfoPending = false; self:UpdateFood() end)
        end
    end)
    ev:On("PLAYER_REGEN_ENABLED", function() FullUpdate(self) end)
    ev:On("PLAYER_REGEN_DISABLED", function() self:ClosePicker() end)
    -- The game refusing a food (wrong diet, too low level) beats our table and
    -- level bands: skip that item for this pet and pick the next one.
    ev:On("UI_ERROR_MESSAGE", function(_, _, _, message)
        local last = self.lastFeed
        message = C.Readable(message)
        if not (last and last.food and message) or GetTime() - last.time > 3 then return end
        if message == _G.SPELL_FAILED_WRONG_PET_FOOD or message == _G.SPELL_FAILED_FOOD_LOWLEVEL then
            self.refused[last.food.itemID] = true
            self.lastFeed = nil
            self:UpdateFood()
        end
    end)
    self:Layout()
    FullUpdate(self)
end

function Pet:OnDisable()
    self:ClosePicker()
    self.events:OffAll()
    self.rule = nil
    self:UpdateVisibility()
end

function Pet:Refresh()
    healthCurve = BuildHealthCurve(self.db.mendThreshold)
    self:Layout()
    self.rule = nil
    FullUpdate(self)
end

HS:On("EDIT_MODE", function(on)
    if not Pet.enabled then return end
    if on then Pet:ClosePicker() end
    if on and not UnitExists("pet") then
        local card = Pet.card
        card.name:SetText(L.WOLF_CFF6B6F7860_R)
        card.portrait:SetTexture(132203)
        card.mood:SetText(L.HAPPY)
        card.ring:SetVertexColor(UI:Color("good"))
        card.hp:SetRange(0, 1)
        card.hp:SetValueNow(0.82)
        card.hpText:SetText("82%")
    end
    Pet.rule = nil
    Pet:UpdateVisibility()
end)
