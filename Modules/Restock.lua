--[[
    HunterSuite - ammo restock
    At a vendor selling ammo for your weapon, a panel beside the vendor window
    tops you up with the best ammo you can use, to the amount you like to carry.
    Away from vendors, it pins the nearest one that sells it on your map.
]]

local _, HS = ...
local L = HS.L
local UI, C = HS.UI, HS.Compat

local Restock = HS:NewModule("restock", { title = L.AMMO_RESTOCK })

local RANGED_SLOT = _G.INVSLOT_RANGED or 18
local AMMO_SLOT = _G.INVSLOT_AMMO or 0
local PROJECTILE = 6
local ARROW, BULLET = 2, 3
-- What each ranged weapon fires: bows and crossbows arrows, guns bullets.
local FIRES = { [2] = ARROW, [18] = ARROW, [3] = BULLET }
-- The bag family bit of the bag that holds it: quivers and ammo pouches.
local BAG_BIT = { [ARROW] = 1, [BULLET] = 2 }
-- Vendor ammo by the level it needs. Rarer ammo (Ice Threaded, Thorium) is
-- bought when a merchant has it, but the finder only looks for these.
local TIERS = {
    [ARROW] = { { 2512, 1 }, { 2515, 10 }, { 3030, 25 }, { 11285, 40 } },
    [BULLET] = { { 2516, 1 }, { 2519, 10 }, { 3033, 25 }, { 11284, 40 } },
}
local BUY_GAP = 0.3       -- seconds between purchases, so each one reaches the server
local YARDS_PER_SECOND = 7

local merchantOpen = false
local buying               -- { offer, left, bought } while a top-up runs

local function Fires()
    local id = GetInventoryItemID("player", RANGED_SLOT)
    if not id then return nil end
    local _, _, _, _, _, classID, subclassID = C.GetItemInfoInstant(id)
    return classID == 2 and FIRES[subclassID] or nil
end

local function HasBit(family, bit)
    return math.floor((family or 0) / bit) % 2 == 1
end

---------------------------------------------------------------------------
-- What to buy
---------------------------------------------------------------------------

-- The best ammo this merchant sells for your weapon and level. Returns nil
-- and true when an item still has to load.
function Restock:BestOffer()
    local kind = Fires()
    if not kind then return nil end
    local level = UnitLevel("player") or 1
    local best, loading
    for index = 1, GetMerchantNumItems() or 0 do
        local m = C.GetMerchantItem(index)
        local id = m and m.id
        if id then
            local _, _, _, _, _, classID, subclassID = C.GetItemInfoInstant(id)
            if classID == PROJECTILE and subclassID == kind and m.purchasable and not m.extended then
                local name, link, _, ilvl, minLevel, _, _, maxStack, _, icon = C.GetItemInfo(id)
                if not name then
                    loading = true
                    C.RequestItem(id, function() if merchantOpen then Restock:UpdatePanel() end end)
                elseif (minLevel or 0) <= level and (not best or (ilvl or 0) > best.ilvl) then
                    best = { index = index, id = id, name = name, link = link, icon = icon, ilvl = ilvl or 0,
                             stack = maxStack or 200, bundle = math.max(1, m.bundle), price = m.price,
                             available = m.available, kind = kind }
                end
            end
        end
    end
    return best, loading
end

-- How many of `offer` fit in your bags, counting room left in its stacks.
local function Room(offer, useBags)
    local room = 0
    for bag = 0, C.NUM_BAGS do
        local free, family = C.GetBagFreeSlots(bag)
        if (family == 0 and useBags) or HasBit(family, BAG_BIT[offer.kind]) then
            room = room + free * offer.stack
        end
    end
    C.ForEachBagItem(function(bag, slot, itemID)
        if itemID == offer.id then
            room = room + math.max(0, offer.stack - C.GetContainerItemCount(bag, slot))
        end
    end)
    return room
end

-- What your quivers or ammo pouches hold when full of this ammo.
local function AmmoBagSize(offer)
    local size = 0
    for bag = 1, C.NUM_BAGS do
        local _, family = C.GetBagFreeSlots(bag)
        if HasBit(family, BAG_BIT[offer.kind]) then
            size = size + C.GetContainerNumSlots(bag) * offer.stack
        end
    end
    return size
end

-- { have, target, buy, cost, short } where short says what held the amount
-- back: "room", "money" or "stock".
function Restock:Plan(offer)
    local db = self.db
    local have = C.GetItemCount(offer.id)
    local target = db.fill and AmmoBagSize(offer) or 0
    if target == 0 then target = db.amount end
    local need = math.max(0, target - have)
    local bundle = offer.bundle
    local buy = math.ceil(need / bundle) * bundle
    local short
    local function cap(limit, reason)
        limit = math.floor(limit / bundle) * bundle
        if buy > limit then buy, short = limit, reason end
    end
    cap(Room(offer, db.useBags), "room")
    if offer.price > 0 then cap(math.floor(GetMoney() / offer.price) * bundle, "money") end
    if offer.available and offer.available >= 0 then cap(offer.available * bundle, "stock") end
    return { have = have, target = target, buy = buy, cost = buy / bundle * offer.price, short = short }
end

---------------------------------------------------------------------------
-- Buying
---------------------------------------------------------------------------

-- Equip the new ammo unless what you have on is as good (crafted arrows, say).
local function EquipIfBetter(offer)
    if not Restock.db.equip or InCombatLockdown() then return end
    local worn = GetInventoryItemID("player", AMMO_SLOT)
    if worn == offer.id then return end
    if worn then
        local _, _, _, ilvl = C.GetItemInfo(worn)
        if ilvl and ilvl >= offer.ilvl then return end
    elseif GetInventoryItemTexture("player", AMMO_SLOT) then
        return -- something is on that this client won't name: leave it
    end
    C.EquipItem(offer.id)
end

local function Finish()
    local run = buying
    buying = nil
    if run.bought > 0 then
        HS:Print(L.BOUGHT_D_S_FOR_S:format(run.bought, run.offer.link or run.offer.name, C.MoneyText(run.bought / run.offer.bundle * run.offer.price)))
        C_Timer.After(0.5, function() EquipIfBetter(run.offer) end)
    end
    Restock:UpdatePanel()
end

local function Step()
    local run = buying
    if not run then return end
    if not merchantOpen or run.left <= 0 then
        Finish()
        return
    end
    local offer = run.offer
    -- Each purchase takes up to a stack, in whole vendor bundles.
    local most = math.max(offer.bundle, math.floor((GetMerchantItemMaxStack(offer.index) or offer.stack) / offer.bundle) * offer.bundle)
    local n = math.min(run.left, most)
    BuyMerchantItem(offer.index, n)
    run.left, run.bought = run.left - n, run.bought + n
    C_Timer.After(BUY_GAP, Step)
end

function Restock:Buy()
    if buying or not merchantOpen then return end
    local offer = self:BestOffer()
    if not offer then return end
    local plan = self:Plan(offer)
    if plan.buy <= 0 then return end
    buying = { offer = offer, left = plan.buy, bought = 0 }
    self:UpdatePanel()
    Step()
end

---------------------------------------------------------------------------
-- Panel beside the vendor window
---------------------------------------------------------------------------

function Restock:BuildPanel()
    local f = CreateFrame("Frame", "HunterSuiteRestock", UIParent)
    f:SetSize(240, 66)
    f:SetFrameStrata("HIGH")
    UI:Surface(f, { radius = 6, color = "bg", border = { 1, 1, 1, 0.08 }, shadow = true })
    f.iconFrame = UI:Icon(f, 28)
    f.iconFrame:SetPoint("TOPLEFT", 9, -9)
    f.title = UI:Text(f, { size = 12, justify = "LEFT" })
    f.title:SetPoint("TOPLEFT", f.iconFrame, "TOPRIGHT", 8, -1)
    f.title:SetPoint("RIGHT", -9, 0)
    f.sub = UI:Text(f, { size = 10, color = "textDim", justify = "LEFT" })
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.sub:SetPoint("RIGHT", -9, 0)
    f.button = UI:Button(f, L.TOP_UP, "primary", 92, 22)
    f.button:SetPoint("BOTTOMRIGHT", -9, 8)
    f.button:SetScript("OnClick", function() Restock:Buy() end)
    f:Hide()
    self.panel = f
end

-- Beside the vendor window (which may open just after MERCHANT_SHOW reaches us).
local function Anchor(f)
    f:ClearAllPoints()
    local merchant = _G.MerchantFrame
    if merchant then
        f:SetPoint("TOPLEFT", merchant, "TOPRIGHT", 6, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 260, 120)
    end
end

function Restock:UpdatePanel()
    local f = self.panel
    if not f then return end
    local offer = merchantOpen and self:BestOffer()
    if not offer then
        f:Hide()
        return
    end
    local plan = self:Plan(offer)
    f.iconFrame.icon:SetTexture(offer.icon or 132382)
    f.title:SetText(offer.link or offer.name)
    local have = BreakUpLargeNumbers and BreakUpLargeNumbers(plan.have) or plan.have
    if buying then
        f.sub:SetText(L.BUYING)
    elseif plan.buy > 0 then
        f.sub:SetText(L.YOU_HAVE_S_BUY_D_FOR_S:format(have, plan.buy, C.MoneyText(plan.cost)))
    elseif plan.short == "room" then
        f.sub:SetText(L.YOU_HAVE_S_NO_ROOM:format(have))
    elseif plan.short == "money" then
        f.sub:SetText(L.YOU_HAVE_S_NOT_ENOUGH_MONEY:format(have))
    elseif plan.short == "stock" then
        f.sub:SetText(L.YOU_HAVE_S_SOLD_OUT:format(have))
    else
        f.sub:SetText(L.YOU_HAVE_S_ENOUGH:format(have))
    end
    f.button:SetEnabled(plan.buy > 0 and not buying)
    if not f:IsShown() then
        Anchor(f)
        f:Show()
    end
end

---------------------------------------------------------------------------
-- Vendors you visit
---------------------------------------------------------------------------

-- Every ammo vendor you open is remembered account-wide, in the same row
-- shape as HS.AmmoVendors, and replaces the built-in row for that NPC. That
-- is how vendors in Forever's new zones, and ones Forever moved, get found.
local builtIn
local function BuiltIn(npc)
    if not builtIn then
        builtIn = {}
        for _, v in ipairs(HS.AmmoVendors or {}) do builtIn[v[1]] = v end
    end
    return builtIn[npc]
end

local function NpcID(guid)
    guid = C.Readable(guid)
    local id = guid and guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    return id and tonumber(id)
end

local function Learn()
    if InCombatLockdown() then return end
    local npc = NpcID(UnitGUID("npc"))
    local map = npc and C.Readable(C_Map.GetBestMapForUnit("player"))
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    x, y = C.Readable(x), C.Readable(y)
    if not (x and y) then return end
    local items = {}
    for index = 1, GetMerchantNumItems() or 0 do
        local m = C.GetMerchantItem(index)
        if m and m.id and not m.extended then
            local _, _, _, _, _, classID, subclassID = C.GetItemInfoInstant(m.id)
            if classID == PROJECTILE and BAG_BIT[subclassID] then
                local limited = m.available >= 0 or not m.purchasable
                items[#items + 1] = limited and -m.id or m.id
            end
        end
    end
    if #items == 0 then return end
    local learned = HS.sv.ammoVendors or {}
    HS.sv.ammoVendors = learned
    local known = learned[npc] or BuiltIn(npc)
    local side = ({ Alliance = "A", Horde = "H" })[UnitFactionGroup("player")] or ""
    if known and known[4] ~= side then side = "AH" end
    local row = { npc, C.Readable(UnitName("npc")) or (known and known[2]) or "", known and known[3] or "", side, map,
                  math.floor(x * 10000 + 0.5) / 100, math.floor(y * 10000 + 0.5) / 100 }
    for _, id in ipairs(items) do row[#row + 1] = id end
    learned[npc] = row
end

-- The built-in list with what you've learned laid over it.
local function Vendors()
    local learned = HS.sv and HS.sv.ammoVendors
    if not learned or not next(learned) then return HS.AmmoVendors or {} end
    local list = {}
    for _, v in ipairs(HS.AmmoVendors or {}) do
        if not learned[v[1]] then list[#list + 1] = v end
    end
    for _, v in pairs(learned) do list[#list + 1] = v end
    return list
end

---------------------------------------------------------------------------
-- Nearest vendor
---------------------------------------------------------------------------

local worldCache = {}
local function WorldPos(map, x, y)
    local key = map .. ":" .. x .. ":" .. y
    local hit = worldCache[key]
    if hit ~= nil then return hit or nil end
    local pos = false
    if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local ok, cont, v = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
        if ok and cont and v then
            local px, py = v:GetXY()
            pos = { cont = cont, x = px, y = py }
        end
    end
    worldCache[key] = pos
    return pos or nil
end

local function Here()
    local map = C_Map and C_Map.GetBestMapForUnit and C.Readable(C_Map.GetBestMapForUnit("player"))
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    x, y = C.Readable(x), C.Readable(y)
    return x and y and WorldPos(map, x, y)
end

-- Limited stock or a reputation gate is stored as a negative ID, so it never matches here.
local function Sells(v, itemID)
    for i = 8, #v do
        if v[i] == itemID then return true end
    end
    return false
end

-- The vendor selling `itemID` you'd reach first: by Ledger Nav's travel time
-- when it's loaded (it knows flight paths), else straight-line on your continent.
local function Nearest(itemID, faction, here)
    local nav = rawget(_G, "LedgerNav")
    local reach
    if nav then
        local ok, origin = pcall(nav.Here)
        reach = ok and origin and nav.Reach(origin) or nil
    end
    local best, bestCost, bestYards
    for _, v in ipairs(Vendors()) do
        if (v[4] == "AH" or v[4] == faction) and Sells(v, itemID) then
            local w = WorldPos(v[5], v[6] / 100, v[7] / 100)
            if w and w.cont == here.cont then
                local dx, dy = w.x - here.x, w.y - here.y
                local yards = math.sqrt(dx * dx + dy * dy)
                local cost = yards / YARDS_PER_SECOND
                if reach then
                    local ok, point = pcall(nav.Point, v[5], v[6] / 100, v[7] / 100)
                    local seconds = ok and point and reach(point)
                    if seconds then cost = seconds end
                end
                if not bestCost or cost < bestCost then best, bestCost, bestYards = v, cost, yards end
            end
        end
    end
    return best, bestCost, bestYards, reach ~= nil
end

local function Pin(v)
    if not (C_Map and C_Map.SetUserWaypoint) then return false end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(v[5]) then return false end
    local x, y = v[6] / 100, v[7] / 100
    local point = UiMapPoint and UiMapPoint.CreateFromCoordinates and UiMapPoint.CreateFromCoordinates(v[5], x, y)
        or { uiMapID = v[5], position = CreateVector2D(x, y) }
    if not pcall(C_Map.SetUserWaypoint, point) then return false end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return true
end

-- Pin the nearest friendly vendor selling the best ammo you can use, or the
-- next best when nobody on this continent sells that.
function Restock:FindVendor()
    local kind = Fires()
    if not kind then
        HS:Print(L.EQUIP_A_BOW_GUN_OR_CROSSBOW_FIRST)
        return false
    end
    local here = Here()
    if not here then
        HS:Print(L.CAN_T_TELL_WHERE_YOU_ARE_HERE)
        return false
    end
    local faction = ({ Alliance = "A", Horde = "H" })[UnitFactionGroup("player")]
    local level = UnitLevel("player") or 1
    local tiers = TIERS[kind]
    for t = #tiers, 1, -1 do
        local itemID, needs = tiers[t][1], tiers[t][2]
        if needs <= level then
            local v, cost, yards, timed = Nearest(itemID, faction, here)
            if v then
                local info = C_Map.GetMapInfo and C_Map.GetMapInfo(v[5])
                local zone = info and info.name or ""
                local away = timed and L.ABOUT_D_MIN_AWAY:format(math.max(1, math.floor(cost / 60 + 0.5)))
                    or L.ABOUT_D_YARDS_AWAY:format(math.floor(yards / 10 + 0.5) * 10)
                local who = v[3] ~= "" and ("%s (%s)"):format(v[2], v[3]) or v[2]
                local ammo = C.GetItemInfo(itemID) or L.AMMO
                local line = (Pin(v) and L.S_FROM_S_IN_S_S_PINNED or L.S_FROM_S_IN_S_S):format(ammo, who, zone, away)
                HS:Print(line)
                return true
            end
        end
    end
    HS:Print(L.NO_AMMO_VENDOR_ON_THIS_CONTINENT)
    return false
end

-- For /hs ammo, the ammo counter and the settings button.
function HS:FindAmmoVendor()
    if not Restock.enabled then
        HS:Print(L.AMMO_RESTOCK_IS_TURNED_OFF)
        return false
    end
    return Restock:FindVendor()
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Restock:OnInitialize()
    self:BuildPanel()
    self.events = HS:Events(self)
end

function Restock:OnEnable()
    local ev = self.events
    ev:On("MERCHANT_SHOW", function()
        merchantOpen = true
        Learn()
        self:UpdatePanel()
        if self.db.auto and self.panel:IsShown() then self:Buy() end
    end)
    ev:On("MERCHANT_CLOSED", function()
        merchantOpen = false
        self.panel:Hide()
    end)
    local function update()
        if merchantOpen and not buying then self:UpdatePanel() end
    end
    ev:On("MERCHANT_UPDATE", update)
    ev:On("BAG_UPDATE_DELAYED", update)
    ev:On("PLAYER_MONEY", update)
end

function Restock:OnDisable()
    self.events:OffAll()
    merchantOpen = false
    buying = nil
    self.panel:Hide()
end

function Restock:Refresh()
    self:UpdatePanel()
end
