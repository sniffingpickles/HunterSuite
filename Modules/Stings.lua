--[[
    HunterSuite - sting timers
    Serpent / Scorpid / Viper (and optionally Hunter's Mark) countdowns for
    your target on a bar you can place anywhere, and above enemy nameplates.
    Aura data is secret in combat on Forever, so timers start when your shot
    lands (the target's UNIT_AURA still fires) and are corrected from real
    auras whenever the client lets us read them. A shot that never lands
    (miss, resist, immune) leaves no timer.
]]

local _, HS = ...
local L = HS.L
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Stings = HS:NewModule("stings", { title = L.STING_TIMERS_2 })

local ROW_H, ROW_GAP, MAX_ROWS = 18, 4, 4
local DOCK_GAP = 14       -- clears the Auto Shot bar's GCD line and delay text
local WARN_AT = 3         -- seconds left when a row turns red (a quarter of short ones)
-- Stings and Concussive Shot fly at 40 yards a second, so they land up to a
-- second after the cast, and they can miss, be resisted or hit something immune.
local LAND_WINDOW = 1.5   -- seconds a shot gets to land: a 41-yard flight plus slack
local FLIGHT_GUESS = 0.5  -- typical flight, used until a landing has been seen in combat

local tracked = {}        -- spellID -> { key, duration, ids, name, travels }
local byName = {}         -- localized name -> entry
local isSting = {}        -- key -> true for the stings, which replace each other
for _, sting in ipairs(S.STINGS) do isSting[sting.key] = true end

-- One record per enemy: { timers = { [key] = { expires, duration, icon, name } }, plate, guid }.
-- Other units' GUIDs are secret in combat, so a record is found by its
-- nameplate frame, by GUID when that's readable, or as `current`, which is
-- always the record of whatever you're targeting now.
local records = {}        -- rec -> true
local byPlate = {}        -- plate -> rec
local byGUID = {}         -- guid -> rec
local current

local inFlight = {}       -- shots that haven't landed: { entry, icon, rec, castAt, deadline }
local landingSeen = false -- UNIT_AURA has caught a landing while auras were secret

local holders = {}        -- plate -> holder frame
local pool = {}

local function BuildLookups(db)
    wipe(tracked)
    wipe(byName)
    local function add(key, ids, duration, travels)
        local name = S.Name(ids)
        local entry = { key = key, ids = ids, duration = duration, name = name or key, travels = travels }
        for _, id in ipairs(ids) do tracked[id] = entry end
        if name then byName[name] = entry end
    end
    for _, sting in ipairs(S.STINGS) do add(sting.key, sting.ids, sting.duration, true) end
    if db.showMark then add("mark", S.HUNTERS_MARK, S.HUNTERS_MARK_DURATION) end
    if db.showConcussive then add("concussive", S.CONCUSSIVE_SHOT, S.CONCUSSIVE_SHOT_DURATION, true) end
    if db.showWingClip then add("wingClip", S.WING_CLIP, S.WING_CLIP_DURATION) end
end

local function Lookup(spellID, name)
    return (spellID and tracked[spellID]) or (name and byName[name])
end

local function OnPlates() return Stings.db.display ~= "bar" end
local function OnBar() return Stings.db.display ~= "plates" end

local function PlateFor(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then return nil end
    if plate.IsForbidden and plate:IsForbidden() then return nil end
    return plate
end

local function GUIDOf(unit)
    return C.Readable(UnitGUID(unit))
end

---------------------------------------------------------------------------
-- Nameplate icons
---------------------------------------------------------------------------

local function AcquireHolder(plate)
    local h = holders[plate]
    if h then return h end
    h = table.remove(pool) or CreateFrame("Frame")
    local ok = pcall(h.SetParent, h, plate)
    if not ok then
        table.insert(pool, h)
        return nil
    end
    h:ClearAllPoints()
    h:SetPoint("BOTTOM", plate, "TOP", 0, Stings.db.offsetY or 6)
    h:SetSize(1, 1)
    h.icons = h.icons or {}
    holders[plate] = h
    h:Show()
    return h
end

local function ReleaseHolder(plate)
    local h = holders[plate]
    if not h then return end
    holders[plate] = nil
    h:Hide()
    for _, icon in ipairs(h.icons) do icon:Hide() end
    h:SetParent(nil)
    table.insert(pool, h)
end

local function GetIcon(h, i)
    local icon = h.icons[i]
    if icon then return icon end
    local size = Stings.db.size or 22
    icon = UI:Icon(h, size, { cooldown = true })
    icon.text = UI:Text(icon.cooldown or icon, { size = math.floor(size * 0.5), flags = "OUTLINE" })
    icon.text:SetPoint("CENTER", 0, 0)
    h.icons[i] = icon
    return icon
end

local function RenderPlate(plate, entries)
    local h = AcquireHolder(plate)
    if not h then return end
    local size = Stings.db.size or 22
    local gap = 3
    local total = #entries * size + (#entries - 1) * gap
    for i, t in ipairs(entries) do
        local icon = GetIcon(h, i)
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT", h, "BOTTOM", -total / 2 + (i - 1) * (size + gap), 0)
        icon.icon:SetTexture(t.icon)
        if icon.cooldown and icon.cdStart ~= t.expires - t.duration then
            icon.cdStart = t.expires - t.duration
            icon.cooldown:SetCooldown(icon.cdStart, t.duration)
        end
        icon.expires = t.expires
        icon:Show()
    end
    for i = #entries + 1, #h.icons do h.icons[i]:Hide() end
end

---------------------------------------------------------------------------
-- Records
---------------------------------------------------------------------------

local function Link(rec, plate, guid)
    records[rec] = true
    if plate and rec.plate ~= plate then
        local old = byPlate[plate]
        if old and old ~= rec then old.plate = nil end
        byPlate[plate] = rec
        rec.plate = plate
    end
    if guid then
        byGUID[guid] = rec
        rec.guid = guid
    end
end

local function Drop(rec)
    records[rec] = nil
    if rec.plate then
        if byPlate[rec.plate] == rec then byPlate[rec.plate] = nil end
        ReleaseHolder(rec.plate)
    end
    if rec.guid and byGUID[rec.guid] == rec then byGUID[rec.guid] = nil end
    if current == rec then current = nil end
end

local function Find(unit)
    if unit == "target" and current then return current end
    local plate = PlateFor(unit)
    local rec = plate and byPlate[plate]
    if not rec then
        local guid = GUIDOf(unit)
        rec = guid and byGUID[guid]
        -- Your target's plate showing up for the first time.
        if not rec and plate and current and not current.plate and plate == PlateFor("target") then
            rec = current
        end
        if rec and plate then Link(rec, plate) end
    end
    return rec
end

local function Ensure(unit)
    local rec = Find(unit) or { timers = {} }
    local plate = PlateFor(unit)
    Link(rec, plate, GUIDOf(unit))
    if unit == "target" or (plate and plate == PlateFor("target")) then current = rec end
    return rec
end

-- Live timers, soonest first. Expired ones are removed.
local function Active(rec, now)
    local list = {}
    for key, t in pairs(rec.timers) do
        if t.expires > now then
            list[#list + 1] = t
        else
            rec.timers[key] = nil
        end
    end
    table.sort(list, function(a, b) return a.expires < b.expires end)
    return list
end

local function Flying(rec)
    for _, shot in ipairs(inFlight) do
        if shot.rec == rec then return true end
    end
    return false
end

local function Update(rec)
    local list = Active(rec, GetTime())
    if #list == 0 then
        -- Keep the record while a shot at it is still in the air.
        if not Flying(rec) then
            Drop(rec)
        elseif rec.plate then
            ReleaseHolder(rec.plate)
        end
        return
    end
    if not rec.plate then return end
    if OnPlates() then
        RenderPlate(rec.plate, list)
    else
        ReleaseHolder(rec.plate)
    end
end

---------------------------------------------------------------------------
-- Sources
---------------------------------------------------------------------------

-- The real auras are readable: shots they show landed, with exact times.
local function Settle(rec)
    for i = #inFlight, 1, -1 do
        local shot = inFlight[i]
        local t = shot.rec == rec and rec.timers[shot.entry.key]
        -- an aura put on before the cast is the old sting, not this one
        if t and t.expires - t.duration >= shot.castAt - 0.1 then table.remove(inFlight, i) end
    end
end

-- Replace a unit's timers with its real auras, when they can be read.
local function ScanUnit(unit)
    if not unit or C.IsSecret(unit) then return end
    local found = {}
    local scanned = C.ForEachAura(unit, "HARMFUL|PLAYER", function(aura)
        local entry = Lookup(aura.spellId, aura.name)
        if entry then
            local duration, expires = C.AuraTimes(aura)
            if duration and duration > 0 then
                found[entry.key] = { expires = expires, duration = duration, icon = aura.icon, name = entry.name }
            end
        end
    end)
    if not scanned then return end
    if next(found) then
        local rec = Ensure(unit)
        rec.timers = found
        Settle(rec)
        Update(rec)
    else
        local rec = Find(unit)
        if rec then
            wipe(rec.timers)
            Update(rec)
        end
    end
    Stings:Wake()
end

-- Start a shot's timer from the moment it reached the target.
local function Land(shot, at)
    local rec, entry = shot.rec, shot.entry
    if not records[rec] then return end -- the target died or was forgotten meanwhile
    if isSting[entry.key] then
        -- One sting per hunter on a target: a new one replaces the last.
        for key in pairs(rec.timers) do
            if isSting[key] then rec.timers[key] = nil end
        end
    end
    rec.timers[entry.key] = {
        expires = at + entry.duration, duration = entry.duration, icon = shot.icon, name = entry.name,
    }
    Update(rec)
    Stings:Wake()
end

-- A unit with a shot in the air got an aura change: the shot landed. In
-- combat the event's contents are secret, but it still fires on time.
local function Landed(unit)
    if #inFlight == 0 then return end
    local rec = Find(unit)
    if not rec then return end
    local now = GetTime()
    for i = #inFlight, 1, -1 do
        local shot = inFlight[i]
        if shot.rec == rec then
            table.remove(inFlight, i)
            Land(shot, now)
            if C.AurasRestricted() then landingSeen = true end
        end
    end
end

-- Nothing landed in time. Once a landing has been caught in combat, that
-- means a miss, a resist or an immune target. Until then the event may just
-- not be reaching us, so the timer starts after a typical flight instead.
local function Missed(shot)
    if C.AurasRestricted() and not landingSeen then
        Land(shot, shot.castAt + FLIGHT_GUESS)
    elseif records[shot.rec] then
        Update(shot.rec)
    end
end

function Stings:OnCast(spellID)
    local entry = Lookup(spellID, C.GetSpellName(spellID))
    if not entry or not UnitExists("target") then return end
    local now = GetTime()
    local shot = {
        entry = entry, rec = Ensure("target"), castAt = now,
        icon = C.GetSpellTexture(spellID) or S.Icon(entry.ids),
    }
    if entry.travels then
        shot.deadline = now + LAND_WINDOW + C.GetLatency()
        inFlight[#inFlight + 1] = shot
    else
        Land(shot, now)
    end
    -- When reads are allowed the real aura replaces the estimate.
    C_Timer.After(0.3, function() ScanUnit("target") end)
end

function Stings:OnTargetChanged()
    current = nil
    if UnitExists("target") then
        current = Find("target")
        ScanUnit("target")
    end
    self:Wake()
end

---------------------------------------------------------------------------
-- Target bar
---------------------------------------------------------------------------

function Stings:BuildBar()
    local f = UI:Element("HunterSuiteStings", self.db, L.STINGS)
    f:SetSize(self.db.barWidth or 200, ROW_H)
    f.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_H + ROW_GAP))
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * (ROW_H + ROW_GAP))
        row.iconFrame = UI:Icon(row, ROW_H)
        row.iconFrame:SetPoint("LEFT")
        row.bar = UI:Bar(row, { height = ROW_H - 2 })
        row.bar:SetPoint("LEFT", row.iconFrame, "RIGHT", 4, 0)
        row.bar:SetPoint("RIGHT")
        row.name = UI:Text(row.bar.bar, { size = 10, flags = "OUTLINE" })
        row.name:SetPoint("LEFT", 5, 0)
        row.time = UI:Text(row.bar.bar, { size = 10, flags = "OUTLINE" })
        row.time:SetPoint("RIGHT", -5, 0)
        row:Hide()
        f.rows[i] = row
    end
    f:SetScript("OnUpdate", function() Stings:Draw() end)
    f:Hide()
    self.bar = f
    HS.Movers:Register(f, { label = L.STINGS, defaultPath = "stings.position", module = "stings",
        hidden = function() return Stings.docked or Stings.db.display == "plates" end })
end

function Stings:Layout()
    local f, db = self.bar, self.db
    local shot = HS:GetModule("shotTimer")
    f:ClearAllPoints()
    if db.attach and shot and shot.enabled and shot.frame then
        f:SetScale(HS.db.appearance.scale or 1)
        f:SetPoint("TOPLEFT", shot.frame, "BOTTOMLEFT", 0, -DOCK_GAP)
        f:SetPoint("TOPRIGHT", shot.frame, "BOTTOMRIGHT", 0, -DOCK_GAP)
        self.docked = true
    else
        self.docked = false
        f:SetWidth(db.barWidth or 200)
        UI:ApplyPosition(f)
    end
end

-- Show the bar when there's something to show; Draw hides it again.
function Stings:Wake()
    local f = self.bar
    if not f or not self.enabled then return end
    if OnBar() and (HS.state.editMode or (current and next(current.timers))) then
        UI:StopTween(f)
        f:SetAlpha(1)
        f:Show()
    else
        f:Hide()
    end
end

local function Sample(now)
    local list = {
        { name = S.Name(S.STINGS[1].ids) or L.SERPENT_STING, icon = S.Icon(S.STINGS[1].ids) or 132204, expires = now + 2.4, duration = 15 },
    }
    if Stings.db.showMark then
        list[2] = { name = S.Name(S.HUNTERS_MARK) or L.HUNTERS_MARK, icon = S.Icon(S.HUNTERS_MARK) or 132212, expires = now + 84, duration = 120 }
    end
    return list
end

function Stings:Draw()
    local f, now = self.bar, GetTime()
    local list
    if HS.state.editMode then
        list = Sample(now)
    else
        if current and C.Readable(UnitIsDead("target")) then Drop(current) end
        list = current and Active(current, now)
        if not list or #list == 0 then
            if current and not Flying(current) then Drop(current) end
            f:Hide()
            return
        end
    end

    for i, row in ipairs(f.rows) do
        local t = list[i]
        if t then
            local left = t.expires - now
            row.iconFrame.icon:SetTexture(t.icon)
            row.name:SetText(t.name)
            row.bar:SetRange(0, t.duration)
            row.bar:SetValueNow(left)
            row.bar:SetFillColor(UI:Color(left <= math.min(WARN_AT, t.duration / 4) and "danger" or "info"))
            row.time:SetText(left >= 10 and tostring(math.floor(left)) or ("%.1f"):format(left))
            row:Show()
        else
            row:Hide()
        end
    end
    local n = math.min(#list, MAX_ROWS)
    f:SetHeight(math.max(ROW_H, n * ROW_H + (n - 1) * ROW_GAP))
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Stings:OnInitialize()
    BuildLookups(self.db)
    self:BuildBar()
    self.events = HS:Events(self)
    local ticker = CreateFrame("Frame")
    local accum = 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        accum = accum + elapsed
        if accum < 0.1 then return end
        accum = 0
        local now = GetTime()
        for i = #inFlight, 1, -1 do
            local shot = inFlight[i]
            if now >= shot.deadline then
                table.remove(inFlight, i)
                Missed(shot)
            end
        end
        for rec in pairs(records) do
            for _, t in pairs(rec.timers) do
                if t.expires <= now then
                    Update(rec)
                    break
                end
            end
            local h = rec.plate and holders[rec.plate]
            if h then
                for _, icon in ipairs(h.icons) do
                    if icon:IsShown() and icon.expires then
                        local left = icon.expires - now
                        if Stings.db.showText and left > 0 then
                            icon.text:SetText(left >= 10 and tostring(math.floor(left)) or ("%.1f"):format(left))
                        else
                            icon.text:SetText("")
                        end
                    end
                end
            end
        end
    end)
    ticker:Hide()
    self.ticker = ticker
end

function Stings:OnEnable()
    local ev = self.events
    ev:On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, _, _, spellID)
        spellID = C.Readable(spellID)
        if spellID then self:OnCast(spellID) end
    end, "player")
    ev:On("PLAYER_TARGET_CHANGED", function() self:OnTargetChanged() end)
    ev:On("NAME_PLATE_UNIT_ADDED", function(_, _, unit)
        if C.IsSecret(unit) then return end
        local rec = Find(unit)
        if rec then Update(rec) end
        ScanUnit(unit)
    end)
    ev:On("NAME_PLATE_UNIT_REMOVED", function(_, _, unit)
        if C.IsSecret(unit) then return end
        local plate = PlateFor(unit)
        if not plate then return end
        ReleaseHolder(plate)
        local rec = byPlate[plate]
        if rec then
            byPlate[plate] = nil
            rec.plate = nil
            -- Nothing else can find it again.
            if not rec.guid and rec ~= current then Drop(rec) end
        end
    end)
    ev:On("UNIT_AURA", function(_, _, unit)
        if C.IsSecret(unit) or type(unit) ~= "string" then return end
        if unit == "target" or unit:find("^nameplate") then
            Landed(unit)
            ScanUnit(unit)
        end
    end)
    ev:On("PLAYER_REGEN_ENABLED", function()
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
                local unit = plate.namePlateUnitToken
                if unit and not C.IsSecret(unit) then ScanUnit(unit) end
            end
        end
        ScanUnit("target")
    end)
    ev:On("PLAYER_DEAD", function()
        wipe(inFlight)
        for rec in pairs(records) do Drop(rec) end
        self:Wake()
    end)
    self:Layout()
    self.ticker:Show()
    self:OnTargetChanged()
end

function Stings:OnDisable()
    self.events:OffAll()
    self.ticker:Hide()
    for plate in pairs(holders) do ReleaseHolder(plate) end
    wipe(inFlight)
    wipe(records)
    wipe(byPlate)
    wipe(byGUID)
    current = nil
    self.bar:Hide()
end

function Stings:Refresh()
    BuildLookups(self.db)
    for plate, h in pairs(holders) do
        h:ClearAllPoints()
        h:SetPoint("BOTTOM", plate, "TOP", 0, self.db.offsetY or 6)
        for _, icon in ipairs(h.icons) do
            UI:SetTextSize(icon.text, math.floor((self.db.size or 22) * 0.5), "OUTLINE")
        end
    end
    for rec in pairs(records) do Update(rec) end
    self:Layout()
    self:Wake()
end

HS:On("EDIT_MODE", function()
    if Stings.enabled then Stings:Wake() end
end)

-- Re-dock when the Auto Shot bar moves or is toggled.
HS:On("ELEMENT_MOVED", function()
    if Stings.enabled and Stings.docked then Stings:Layout() end
end)
HS:On("MODULE_TOGGLED", function(key)
    if key == "shotTimer" and Stings.enabled then Stings:Layout() end
end)
