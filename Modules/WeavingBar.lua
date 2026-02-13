--[[
    HunterSuite - Weaving Bar Module
    Real-time rotation guide for TBC Hunter shot weaving
    
    Displays a scrolling timeline bar showing optimal shot rotation
    based on current haste buffs, spec, and melee weaving preference.
    
    Based on diziet559's rotationtools:
    https://diziet559.github.io/rotationtools/
]]

local addonName, HunterSuite = ...

HunterSuite.WeavingBar = {}
local WeavingBar = HunterSuite.WeavingBar

-- ============================================================================
-- Constants
-- ============================================================================

local GCD = 1.5
local STEADY_CAST = 1.5
local MULTI_CAST = 0.5
local ARCANE_CAST = 0.5
local WEAVE_TIME = 0.3  -- Time to step in, swing, step out

-- Spell IDs
local SPELL_AUTO_SHOT       = 75
local SPELL_STEADY_SHOT     = 34120
local SPELL_MULTI_SHOT      = 27021
local SPELL_ARCANE_SHOT     = 27019
local SPELL_RAPTOR_STRIKE   = 27014
local SPELL_RAPID_FIRE      = 3045
local SPELL_KILL_COMMAND     = 34026

-- Buff spell IDs / names for detection
local BUFF_RAPID_FIRE       = "Rapid Fire"
local BUFF_QUICK_SHOTS       = "Quick Shots"          -- Imp. Aspect of the Hawk proc
local BUFF_BLOODLUST         = "Bloodlust"
local BUFF_HEROISM           = "Heroism"
local BUFF_DRUMS_OF_BATTLE   = "Drums of Battle"
local BUFF_DST_PROC          = "Haste"                -- Dragon Spine Trophy proc name

-- Haste multipliers (multiplicative)
local HASTE_QUIVER           = 1.15
local HASTE_SERPENTS_SWIFT   = 1.20
local HASTE_IMP_HAWK         = 1.15
local HASTE_RAPID_FIRE       = 1.40
local HASTE_BLOODLUST        = 1.30
local HASTE_DRUMS            = 1.05

-- Ability display info: color {r,g,b}, label, cast_time, is_melee, icon
local ABILITY_INFO = {
    auto    = { color = {0.2, 0.8, 0.2},  label = "A",   castTime = 0,           isMelee = false, icon = [[Interface\Icons\Ability_Hunter_RunningShot]] },
    steady  = { color = {0.3, 0.5, 1.0},  label = "S",   castTime = STEADY_CAST, isMelee = false, icon = [[Interface\Icons\Ability_Hunter_SteadyShot]] },
    multi   = { color = {1.0, 0.8, 0.1},  label = "M",   castTime = MULTI_CAST,  isMelee = false, icon = [[Interface\Icons\Ability_UpgradeMoonGlaive]] },
    arcane  = { color = {0.7, 0.3, 1.0},  label = "Arc", castTime = ARCANE_CAST, isMelee = false, icon = [[Interface\Icons\Ability_ImpalingBolt]] },
    raptor  = { color = {0.9, 0.2, 0.2},  label = "R",   castTime = 0,           isMelee = true,  icon = [[Interface\Icons\Ability_MeleeDamage]] },
    melee   = { color = {1.0, 0.6, 0.1},  label = "W",   castTime = 0,           isMelee = true,  icon = [[Interface\Icons\Ability_MeleeDamage]] },
    weave   = { color = {0.9, 0.4, 0.1},  label = "W",   castTime = WEAVE_TIME,  isMelee = true,  icon = [[Interface\Icons\Ability_MeleeDamage]] },
}

-- ============================================================================
-- Rotation Definitions
-- ============================================================================

-- Each rotation is a function that takes eWS and returns:
--   sequence: array of {t=time, ability=string, duration=number}
--   cycleDuration: total cycle length in seconds
local ROTATIONS = {}

-- 1:1 - Bread and butter high haste rotation
ROTATIONS["1:1"] = {
    name = "1:1",
    notation = "as",
    hasWeaving = false,
    buildSequence = function(eWS)
        return {
            { t = 0,   ability = "auto",   duration = 0 },
            { t = 0,   ability = "steady", duration = STEADY_CAST },
        }, eWS
    end,
}

-- French Rotation 5:5:1:1 - THE core rotation
ROTATIONS["french"] = {
    name = "French 5:5:1:1",
    notation = "asmasasAasas",
    hasWeaving = false,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = GCD,         ability = "multi",  duration = MULTI_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS + 0.5,   ability = "steady", duration = STEADY_CAST },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD, ability = "arcane", duration = ARCANE_CAST },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS*3 + 0.5, ability = "steady", duration = STEADY_CAST },
            { t = eWS * 4,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "steady", duration = STEADY_CAST },
        }
        return seq, eWS * 5
    end,
}

-- Short French 5:4:1:1 - SV without Serpent's Swiftness
ROTATIONS["short_french"] = {
    name = "Short French 5:4:1:1",
    notation = "asmasasAas",
    hasWeaving = false,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = GCD,         ability = "multi",  duration = MULTI_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS + 0.5,   ability = "steady", duration = STEADY_CAST },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD, ability = "arcane", duration = ARCANE_CAST },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS * 3,     ability = "steady", duration = STEADY_CAST },
        }
        return seq, eWS * 4
    end,
}

-- Long French 5:6:1:1 - BM with Imp. Hawk proc
ROTATIONS["long_french"] = {
    name = "Long French 5:6:1:1",
    notation = "asAamasasasas",
    hasWeaving = false,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = GCD,         ability = "arcane", duration = ARCANE_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS,         ability = "multi",  duration = MULTI_CAST },
            { t = eWS + 0.5,   ability = "auto",   duration = 0 },
            { t = eWS*2,       ability = "steady", duration = STEADY_CAST },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS*2 + 0.5, ability = "steady", duration = STEADY_CAST },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS * 3,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 4,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 5,     ability = "auto",   duration = 0 },
        }
        return seq, eWS * 6
    end,
}

-- Skipping Rotation 5:9:1:1
ROTATIONS["skipping"] = {
    name = "Skipping 5:9:1:1",
    notation = "asasamaasasaAaasa",
    hasWeaving = false,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,             ability = "auto",   duration = 0 },
            { t = 0,             ability = "steady", duration = STEADY_CAST },
            { t = eWS,           ability = "auto",   duration = 0 },
            { t = eWS * 2,       ability = "auto",   duration = 0 },
            { t = eWS * 2,       ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD,   ability = "multi",  duration = MULTI_CAST },
            { t = eWS * 3,       ability = "auto",   duration = 0 },
            { t = eWS * 4,       ability = "auto",   duration = 0 },
            { t = eWS * 4,       ability = "steady", duration = STEADY_CAST },
            { t = eWS * 5,       ability = "auto",   duration = 0 },
            { t = eWS * 5,       ability = "steady", duration = STEADY_CAST },
            { t = eWS * 6,       ability = "auto",   duration = 0 },
            { t = eWS*6,         ability = "arcane", duration = ARCANE_CAST },
            { t = eWS * 7,       ability = "auto",   duration = 0 },
            { t = eWS * 7,       ability = "steady", duration = STEADY_CAST },
            { t = eWS * 8,       ability = "auto",   duration = 0 },
        }
        return seq, eWS * 9
    end,
}

-- 1:2 - Extreme haste
ROTATIONS["1:2"] = {
    name = "1:2",
    notation = "aas",
    hasWeaving = false,
    buildSequence = function(eWS)
        return {
            { t = 0,       ability = "auto",   duration = 0 },
            { t = eWS,     ability = "auto",   duration = 0 },
            { t = eWS,     ability = "steady", duration = STEADY_CAST },
        }, eWS * 2
    end,
}

-- 2:3 - Transitional between 1:1 and 1:2
ROTATIONS["2:3"] = {
    name = "2:3",
    notation = "asaas",
    hasWeaving = false,
    buildSequence = function(eWS)
        return {
            { t = 0,       ability = "auto",   duration = 0 },
            { t = 0,       ability = "steady", duration = STEADY_CAST },
            { t = eWS,     ability = "auto",   duration = 0 },
            { t = eWS * 2, ability = "auto",   duration = 0 },
            { t = eWS * 2, ability = "steady", duration = STEADY_CAST },
        }, eWS * 3
    end,
}

-- ============================================================================
-- Melee Weaving Rotations
-- ============================================================================

-- French Weaving 5:5:1:1 3w
ROTATIONS["french_weave"] = {
    name = "French Weave 5:5:1:1 3w",
    notation = "asmasasAasas +3w",
    hasWeaving = true,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,               ability = "auto",   duration = 0 },
            { t = 0,               ability = "steady", duration = STEADY_CAST },
            { t = GCD,             ability = "multi",  duration = MULTI_CAST },
            { t = GCD + MULTI_CAST,ability = "weave",  duration = WEAVE_TIME },
            { t = eWS,             ability = "auto",   duration = 0 },
            { t = eWS + 0.5,       ability = "steady", duration = STEADY_CAST },
            { t = eWS + GCD + 0.5, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 2,         ability = "auto",   duration = 0 },
            { t = eWS * 2,         ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD,     ability = "arcane", duration = ARCANE_CAST },
            { t = eWS*2 + GCD + ARCANE_CAST, ability = "weave", duration = WEAVE_TIME },
            { t = eWS * 3,         ability = "auto",   duration = 0 },
            { t = eWS*3 + 0.5,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 4,         ability = "auto",   duration = 0 },
            { t = eWS * 4,         ability = "steady", duration = STEADY_CAST },
        }
        return seq, eWS * 5
    end,
}

-- 1:1 Half-Weave 2:2 1w - THE sweet spot
ROTATIONS["half_weave"] = {
    name = "1:1 Half-Weave",
    notation = "aswas",
    hasWeaving = true,
    buildSequence = function(eWS)
        return {
            { t = 0,                       ability = "auto",   duration = 0 },
            { t = 0,                       ability = "steady", duration = STEADY_CAST },
            { t = STEADY_CAST,             ability = "weave",  duration = WEAVE_TIME },
            { t = eWS,                     ability = "auto",   duration = 0 },
            { t = eWS,                     ability = "steady", duration = STEADY_CAST },
        }, eWS * 2
    end,
}

-- 6:9:1:1 3w - Rapid Fire active
ROTATIONS["rf_weave"] = {
    name = "6:9:1:1 3w",
    notation = "6:9:1:1 3w",
    hasWeaving = true,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS,         ability = "steady", duration = STEADY_CAST },
            { t = eWS + GCD,   ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "multi",  duration = MULTI_CAST },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS * 3,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 4,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*4 + GCD, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 5,     ability = "auto",   duration = 0 },
            { t = eWS * 5,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 6,     ability = "auto",   duration = 0 },
            { t = eWS * 6,     ability = "arcane", duration = ARCANE_CAST },
            { t = eWS * 7,     ability = "auto",   duration = 0 },
            { t = eWS * 7,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*7 + GCD, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 8,     ability = "auto",   duration = 0 },
        }
        return seq, eWS * 9
    end,
}

-- 3:7 2w - Maximum haste weaving
ROTATIONS["max_weave"] = {
    name = "3:7 2w",
    notation = "3:7 2w",
    hasWeaving = true,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*4 + GCD, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 5,     ability = "auto",   duration = 0 },
            { t = eWS * 6,     ability = "auto",   duration = 0 },
        }
        return seq, eWS * 7
    end,
}

-- ============================================================================
-- State
-- ============================================================================

local state = {
    -- Haste & speed
    eWS = 0,                    -- Effective weapon swing (ranged)
    meleeEWS = 0,               -- Effective weapon swing (melee)
    baseWeaponSpeed = 3.0,      -- Tooltip ranged weapon speed
    baseMeleeSpeed = 3.7,       -- Tooltip melee weapon speed
    
    -- Spec
    isBM = false,
    hasSerpentsSwiftness = false,
    
    -- Active buffs (booleans)
    hasQuiver = false,
    hasRapidFire = false,
    hasQuickShots = false,      -- Imp. Hawk proc
    hasBloodlust = false,
    hasDrums = false,
    hasDST = false,
    
    -- Buff durations for display
    rapidFireExpires = 0,
    quickShotsExpires = 0,
    bloodlustExpires = 0,
    drumsExpires = 0,
    dstExpires = 0,
    
    -- Current rotation
    currentRotation = nil,      -- Key into ROTATIONS table
    currentSequence = nil,      -- Built sequence for current eWS
    cycleDuration = 0,          -- Duration of one cycle
    
    -- Swing tracking
    lastAutoTime = 0,           -- When last auto shot fired
    cycleStartTime = 0,         -- When current rotation cycle started
    isAutoShooting = false,     -- Auto shot repeating
    
    -- GCD tracking
    gcdStart = 0,
    gcdDuration = 0,
    
    -- Cast tracking
    isCasting = false,
    castEndTime = 0,
    currentCastAbility = nil,
    
    -- Melee tracking
    lastMeleeTime = 0,
    raptorStrikeCD = 0,         -- Expiration time of Raptor Strike CD
    nextMeleeIsRaptor = true,   -- Alternate raptor/white
    
    -- Kill Command tracking
    killCommandCD = 0,
    
    -- Player state
    isMoving = false,
    playerGUID = nil,
    
    -- Rotation change alert
    rotationChangeTime = 0,
    previousRotation = nil,
}

-- ============================================================================
-- eWS Calculation
-- ============================================================================

-- Get ranged eWS directly from game API (most accurate)
function WeavingBar:GetRangedEWS()
    local speed = UnitRangedDamage("player")
    if speed and speed > 0 then
        return speed
    end
    return 3.0 / HASTE_QUIVER  -- Fallback: base speed with quiver
end

-- Get melee eWS from game API
function WeavingBar:GetMeleeEWS()
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    if mainSpeed and mainSpeed > 0 then
        return mainSpeed
    end
    return 3.7  -- Fallback
end

-- Detect spec via talents
function WeavingBar:DetectSpec()
    -- Scan BM tree (tab 1) for Serpent's Swiftness
    local numTalents = GetNumTalents(1)
    state.hasSerpentsSwiftness = false
    for i = 1, numTalents do
        local name, _, _, _, rank = GetTalentInfo(1, i)
        if name == "Serpent's Swiftness" then
            state.hasSerpentsSwiftness = (rank and rank > 0)
            break
        end
    end
    state.isBM = state.hasSerpentsSwiftness
end

-- Scan player buffs for haste effects
function WeavingBar:ScanBuffs()
    local now = GetTime()
    
    state.hasRapidFire = false
    state.hasQuickShots = false
    state.hasBloodlust = false
    state.hasDrums = false
    state.hasDST = false
    
    for i = 1, 40 do
        local name, _, _, _, duration, expirationTime, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        
        if name == BUFF_RAPID_FIRE or spellId == 3045 then
            state.hasRapidFire = true
            state.rapidFireExpires = expirationTime or 0
        elseif name == BUFF_QUICK_SHOTS then
            state.hasQuickShots = true
            state.quickShotsExpires = expirationTime or 0
        elseif name == BUFF_BLOODLUST or name == BUFF_HEROISM or spellId == 2825 or spellId == 32182 then
            state.hasBloodlust = true
            state.bloodlustExpires = expirationTime or 0
        elseif name == BUFF_DRUMS_OF_BATTLE or spellId == 35476 then
            state.hasDrums = true
            state.drumsExpires = expirationTime or 0
        elseif name == BUFF_DST_PROC then
            -- DST proc is generic "Haste" - check if it's ~325 haste rating worth
            state.hasDST = true
            state.dstExpires = expirationTime or 0
        end
    end
    
    -- Quiver detection: check if ranged haste includes quiver
    -- In TBC, quivers are equipped items; check ammo slot
    state.hasQuiver = true  -- Assume quiver for now (virtually all hunters have one)
end

-- Update all haste state and eWS
function WeavingBar:UpdateHaste()
    self:ScanBuffs()
    
    -- Use game API for actual eWS (most accurate, accounts for all haste)
    state.eWS = self:GetRangedEWS()
    state.meleeEWS = self:GetMeleeEWS()
    
    -- Get base weapon speed from tooltip for display
    -- UnitRangedDamage returns hasted speed; to get base we'd need to reverse-calculate
    -- For now store the hasted value as eWS which is what we need
end

-- ============================================================================
-- Rotation Selection
-- ============================================================================

function WeavingBar:SelectRotation()
    local db = HunterSuite.db.weavingBar
    local eWS = state.eWS
    local weaving = db.enableWeaving
    local previousRotation = state.currentRotation
    
    local selected = nil
    
    if weaving then
        -- Melee weaving rotation selection
        if state.isBM then
            if eWS < 0.94 then
                selected = "max_weave"          -- 3:7 2w
            elseif state.hasRapidFire then
                if state.hasBloodlust or (state.hasQuickShots and state.hasDrums) then
                    selected = "max_weave"      -- RF + BL, or RF + Hawk + Drums
                else
                    selected = "rf_weave"       -- 6:9:1:1 3w
                end
            elseif state.hasQuickShots or state.hasBloodlust or state.hasDST then
                selected = "half_weave"         -- 1:1 Half-Weave
            else
                selected = "french_weave"       -- French Weaving baseline
            end
        else
            -- SV with weaving: simpler selection
            if eWS < 1.3 then
                selected = "half_weave"
            elseif eWS < 2.0 then
                selected = "half_weave"
            else
                selected = "french_weave"
            end
        end
    else
        -- Ranged-only rotation selection
        if state.isBM then
            if eWS >= 2.0 then
                selected = "french"             -- French 5:5:1:1
            elseif eWS >= 1.8 then
                selected = "long_french"        -- Long French 5:6:1:1
            elseif eWS >= 1.3 then
                selected = "1:1"                -- 1:1
            elseif eWS >= 1.0 then
                selected = "skipping"           -- Skipping 5:9:1:1
            elseif eWS >= 0.8 then
                selected = "2:3"                -- 2:3
            else
                selected = "1:2"                -- 1:2 extreme haste
            end
        else
            -- SV ranged-only
            if eWS > 2.4 then
                selected = "short_french"       -- Short French 5:4:1:1
            elseif eWS >= 2.0 then
                selected = "french"             -- French 5:5:1:1
            elseif eWS >= 1.3 then
                selected = "1:1"
            elseif eWS >= 1.0 then
                selected = "skipping"
            elseif eWS >= 0.8 then
                selected = "2:3"
            else
                selected = "1:2"
            end
        end
    end
    
    -- Apply rotation
    if selected and ROTATIONS[selected] then
        state.currentRotation = selected
        local rotation = ROTATIONS[selected]
        state.currentSequence, state.cycleDuration = rotation.buildSequence(eWS)
        
        -- Detect rotation change
        if previousRotation and previousRotation ~= selected then
            state.rotationChangeTime = GetTime()
            state.previousRotation = previousRotation
        end
    end
end

-- ============================================================================
-- UI Elements
-- ============================================================================

local mainFrame = nil          -- Main container frame
local timelineFrame = nil      -- The scrolling bar area
local rotationLabel = nil      -- Current rotation name text
local ewsLabel = nil           -- eWS display text
local alertText = nil          -- Rotation change alert
local clippingText = nil       -- "DON'T CAST" / "MULTI NOW" overlay
local killCmdIndicator = nil   -- Kill Command CD indicator

-- Block pool for timeline
local MAX_BLOCKS = 40
local blockPool = {}           -- Pre-created block frames

-- Active haste buff icons
local hasteIcons = {}

-- Create a single ability block (reusable)
local function CreateBlock(parent, index)
    local block = CreateFrame("Frame", "HunterSuiteWeavingBlock" .. index, parent)
    block:SetSize(40, 30)
    
    local bg = block:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    block.bg = bg
    
    local border = block:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 0.8)
    block.border = border
    
    -- Ability icon
    local icon = block:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", block, "LEFT", 2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    block.icon = icon
    
    local text = block:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
    text:SetTextColor(1, 1, 1, 1)
    block.text = text
    
    block:Hide()
    return block
end

-- Create the main weaving bar UI
function WeavingBar:CreateUI()
    if mainFrame then return mainFrame end
    
    local db = HunterSuite.db.weavingBar
    
    -- Main container
    mainFrame = CreateFrame("Frame", "HunterSuiteWeavingBar", UIParent, "BackdropTemplate")
    mainFrame:SetSize(db.barWidth + 12, db.barHeight + 36)
    mainFrame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", 
        db.position.x or 0, db.position.y or -160)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetClampedToScreen(true)
    
    mainFrame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    mainFrame:SetBackdropColor(0.04, 0.04, 0.06, 0.92)
    mainFrame:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
    
    -- Header area: rotation name (left) and eWS (right)
    rotationLabel = mainFrame:CreateFontString(nil, "OVERLAY")
    rotationLabel:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    rotationLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 6, -4)
    rotationLabel:SetTextColor(0.4, 1.0, 0.4, 1)
    rotationLabel:SetText("French 5:5:1:1")
    
    ewsLabel = mainFrame:CreateFontString(nil, "OVERLAY")
    ewsLabel:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    ewsLabel:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -5)
    ewsLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    ewsLabel:SetText("eWS: 2.17s")
    
    -- Timeline area (the scrolling bar)
    timelineFrame = CreateFrame("Frame", "HunterSuiteWeavingTimeline", mainFrame)
    timelineFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 6, -18)
    timelineFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -6, 16)
    timelineFrame:SetClipsChildren(true)  -- Clip blocks outside the frame
    
    -- Timeline background
    local tlBg = timelineFrame:CreateTexture(nil, "BACKGROUND")
    tlBg:SetAllPoints()
    tlBg:SetColorTexture(0.06, 0.06, 0.08, 1)
    
    -- "Now" marker - vertical line on the left
    local nowLine = timelineFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    nowLine:SetSize(2, db.barHeight)
    nowLine:SetPoint("TOPLEFT", timelineFrame, "TOPLEFT", 0, 0)
    nowLine:SetColorTexture(1, 1, 1, 0.9)
    
    -- Create block pool
    for i = 1, MAX_BLOCKS do
        blockPool[i] = CreateBlock(timelineFrame, i)
    end
    
    -- Clipping warning overlay text
    clippingText = mainFrame:CreateFontString(nil, "OVERLAY", nil, 7)
    clippingText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    clippingText:SetPoint("CENTER", timelineFrame, "CENTER", 0, 0)
    clippingText:SetTextColor(1, 0.3, 0.3, 1)
    clippingText:Hide()
    
    -- Rotation change alert text
    alertText = mainFrame:CreateFontString(nil, "OVERLAY", nil, 7)
    alertText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    alertText:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
    alertText:SetTextColor(1, 1, 0.3, 1)
    alertText:Hide()
    
    -- Haste buff icons (bottom row)
    local buffNames = {"RF", "Hawk", "BL", "Drums", "DST"}
    for i, name in ipairs(buffNames) do
        local icon = mainFrame:CreateFontString(nil, "OVERLAY")
        icon:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
        icon:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 6 + (i-1) * 42, 3)
        icon:SetTextColor(0.5, 0.5, 0.5, 0.6)
        icon:SetText(name)
        hasteIcons[i] = { text = icon, name = name }
    end
    
    -- Kill Command indicator
    killCmdIndicator = mainFrame:CreateFontString(nil, "OVERLAY")
    killCmdIndicator:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    killCmdIndicator:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -6, 3)
    killCmdIndicator:SetTextColor(0.5, 0.5, 0.5, 0.6)
    killCmdIndicator:SetText("KC")
    
    -- Dragging (only in edit mode)
    mainFrame:SetScript("OnDragStart", function(self)
        if HunterSuite.state.editMode then
            self:StartMoving()
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HunterSuite.db.weavingBar.position.point = point
        HunterSuite.db.weavingBar.position.x = x
        HunterSuite.db.weavingBar.position.y = y
    end)
    
    mainFrame:Hide()
    
    self.mainFrame = mainFrame
    return mainFrame
end

-- ============================================================================
-- Timeline Rendering
-- ============================================================================

-- Pixels per second for the timeline
local function GetPixelsPerSecond()
    if not timelineFrame then return 40 end
    local db = HunterSuite.db.weavingBar
    local timeWindow = db.timeWindow or 10  -- Seconds visible on bar
    return timelineFrame:GetWidth() / timeWindow
end

-- Render the timeline blocks based on current rotation and time
function WeavingBar:RenderTimeline()
    if not timelineFrame or not state.currentSequence then return end
    
    local db = HunterSuite.db.weavingBar
    local now = GetTime()
    local pps = GetPixelsPerSecond()
    local barHeight = timelineFrame:GetHeight()
    local barWidth = timelineFrame:GetWidth()
    local timeWindow = db.timeWindow or 10
    
    -- Calculate cycle position
    local cycleTime = 0
    if state.lastAutoTime > 0 and state.cycleDuration > 0 then
        local elapsed = now - state.cycleStartTime
        cycleTime = elapsed % state.cycleDuration
    end
    
    -- Hide all blocks first
    for i = 1, MAX_BLOCKS do
        blockPool[i]:Hide()
    end
    
    local blockIndex = 0
    local sequence = state.currentSequence
    local cycleDur = state.cycleDuration
    
    if not sequence or cycleDur <= 0 then return end
    
    -- Render 3 cycles worth (past, current, future) to ensure coverage
    for cycleOffset = -1, 2 do
        for _, step in ipairs(sequence) do
            local stepTime = step.t + (cycleOffset * cycleDur)
            local relativeTime = stepTime - cycleTime  -- Time relative to now
            
            -- Only render if within visible window
            if relativeTime >= -0.5 and relativeTime <= timeWindow then
                blockIndex = blockIndex + 1
                if blockIndex > MAX_BLOCKS then break end
                
                local block = blockPool[blockIndex]
                local info = ABILITY_INFO[step.ability]
                if info then
                    local xPos = relativeTime * pps
                    local blockWidth = math.max(4, (step.duration > 0 and step.duration or 0.15) * pps)
                    local blockHeight = barHeight - 2
                    
                    -- Melee abilities on bottom half
                    block:ClearAllPoints()
                    if info.isMelee then
                        blockHeight = (barHeight * 0.35) - 1
                        block:SetPoint("BOTTOMLEFT", timelineFrame, "BOTTOMLEFT", xPos, 1)
                    else
                        blockHeight = (barHeight * 0.65) - 1
                        block:SetPoint("TOPLEFT", timelineFrame, "TOPLEFT", xPos, -1)
                    end
                    
                    block:SetSize(blockWidth, blockHeight)
                    block.bg:SetColorTexture(info.color[1], info.color[2], info.color[3], 0.85)
                    
                    -- Set ability icon
                    if info.icon then
                        local iconSize = math.min(blockHeight - 2, blockWidth - 2, 14)
                        block.icon:SetSize(iconSize, iconSize)
                        block.icon:SetTexture(info.icon)
                        block.icon:Show()
                    else
                        block.icon:Hide()
                    end
                    
                    -- Only show text label if block is wide enough
                    if blockWidth > 20 then
                        block.text:SetText(info.label)
                        block.text:Show()
                    else
                        block.text:Hide()
                    end
                    
                    -- Dim past events
                    if relativeTime < 0 then
                        block:SetAlpha(0.3)
                    else
                        block:SetAlpha(1.0)
                    end
                    
                    block:Show()
                end
            end
        end
        if blockIndex >= MAX_BLOCKS then break end
    end
end

-- ============================================================================
-- Header & Status Updates
-- ============================================================================

function WeavingBar:UpdateHeader()
    if not rotationLabel or not ewsLabel then return end
    
    local rotation = state.currentRotation and ROTATIONS[state.currentRotation]
    if rotation then
        rotationLabel:SetText(rotation.name)
    else
        rotationLabel:SetText("--")
    end
    
    ewsLabel:SetText(string.format("eWS: %.2fs", state.eWS))
end

function WeavingBar:UpdateHasteIcons()
    if #hasteIcons == 0 then return end
    
    local now = GetTime()
    local buffs = {
        { active = state.hasRapidFire,  expires = state.rapidFireExpires },
        { active = state.hasQuickShots, expires = state.quickShotsExpires },
        { active = state.hasBloodlust,  expires = state.bloodlustExpires },
        { active = state.hasDrums,      expires = state.drumsExpires },
        { active = state.hasDST,        expires = state.dstExpires },
    }
    
    for i, info in ipairs(buffs) do
        local icon = hasteIcons[i]
        if icon then
            if info.active then
                local remaining = info.expires - now
                if remaining > 0 then
                    icon.text:SetText(string.format("%s:%.0f", icon.name, remaining))
                else
                    icon.text:SetText(icon.name)
                end
                icon.text:SetTextColor(0.2, 1.0, 0.2, 1)
            else
                icon.text:SetText(icon.name)
                icon.text:SetTextColor(0.5, 0.5, 0.5, 0.4)
            end
        end
    end
end

function WeavingBar:UpdateClippingWarning()
    if not clippingText then return end
    
    if not state.isAutoShooting or state.lastAutoTime <= 0 then
        clippingText:Hide()
        return
    end
    
    local now = GetTime()
    local timeSinceAuto = now - state.lastAutoTime
    local timeToNextAuto = state.eWS - timeSinceAuto
    
    -- Warning: about to clip auto shot with Steady
    if timeToNextAuto > 0 and timeToNextAuto < STEADY_CAST and timeToNextAuto > MULTI_CAST then
        -- There's time for Multi/Arcane but not Steady
        clippingText:SetText("MULTI/ARC NOW")
        clippingText:SetTextColor(1, 0.8, 0.1, 1)
        clippingText:Show()
    elseif timeToNextAuto > 0 and timeToNextAuto < 0.5 then
        -- Don't cast anything, auto about to fire
        clippingText:SetText("WAIT FOR AUTO")
        clippingText:SetTextColor(1, 0.3, 0.3, 1)
        clippingText:Show()
    else
        clippingText:Hide()
    end
end

function WeavingBar:UpdateRotationAlert()
    if not alertText then return end
    
    local now = GetTime()
    local alertDuration = 2.0  -- Show alert for 2 seconds
    
    if state.rotationChangeTime > 0 and (now - state.rotationChangeTime) < alertDuration then
        local rotation = ROTATIONS[state.currentRotation]
        if rotation then
            alertText:SetText(">> " .. rotation.name .. " <<")
            -- Flash effect
            local alpha = 0.5 + 0.5 * math.abs(math.sin((now - state.rotationChangeTime) * 4))
            alertText:SetAlpha(alpha)
            alertText:Show()
        end
    else
        alertText:Hide()
        state.rotationChangeTime = 0
    end
end

function WeavingBar:UpdateKillCommand()
    if not killCmdIndicator then return end
    if not state.isBM then
        killCmdIndicator:Hide()
        return
    end
    
    killCmdIndicator:Show()
    local start, duration = GetSpellCooldown(SPELL_KILL_COMMAND)
    if start and start > 0 and duration and duration > 0 then
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            killCmdIndicator:SetText(string.format("KC:%.0f", remaining))
            killCmdIndicator:SetTextColor(0.6, 0.6, 0.6, 0.8)
        else
            killCmdIndicator:SetText("KC: RDY")
            killCmdIndicator:SetTextColor(0.2, 1.0, 0.2, 1)
        end
    else
        killCmdIndicator:SetText("KC: RDY")
        killCmdIndicator:SetTextColor(0.2, 1.0, 0.2, 1)
    end
end

-- ============================================================================
-- Event Handling
-- ============================================================================

function WeavingBar:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        state.playerGUID = UnitGUID("player")
        self:DetectSpec()
        self:UpdateHaste()
        self:SelectRotation()
        
    elseif event == "UNIT_RANGEDDAMAGE" then
        local unit = ...
        if unit == "player" then
            self:UpdateHaste()
            self:SelectRotation()
        end
        
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            local oldRF = state.hasRapidFire
            local oldQS = state.hasQuickShots
            local oldBL = state.hasBloodlust
            local oldDrums = state.hasDrums
            local oldDST = state.hasDST
            
            self:UpdateHaste()
            
            -- Check if haste buffs changed
            if oldRF ~= state.hasRapidFire or oldQS ~= state.hasQuickShots or
               oldBL ~= state.hasBloodlust or oldDrums ~= state.hasDrums or
               oldDST ~= state.hasDST then
                self:SelectRotation()
            end
        end
        
    elseif event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        self:DetectSpec()
        self:UpdateHaste()
        self:SelectRotation()
        
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        local spellId = select(3, ...)
        local spellName = spellId and GetSpellInfo(spellId) or select(2, ...)
        
        if unit == "player" then
            if spellId == SPELL_AUTO_SHOT or spellName == (GetSpellInfo(SPELL_AUTO_SHOT)) then
                local now = GetTime()
                state.lastAutoTime = now
                
                -- Sync cycle: if we don't have a cycle start, set it
                if state.cycleStartTime <= 0 then
                    state.cycleStartTime = now
                end
                
                -- Re-sync cycle if drift is too large
                if state.cycleDuration > 0 then
                    local elapsed = now - state.cycleStartTime
                    local cyclePos = elapsed % state.cycleDuration
                    -- If we're within 0.2s of a cycle boundary, re-sync
                    if cyclePos < 0.2 or (state.cycleDuration - cyclePos) < 0.2 then
                        state.cycleStartTime = now
                    end
                end
            end
        end
        
    elseif event == "UNIT_SPELLCAST_START" then
        local unit = ...
        if unit == "player" then
            local spellName, _, _, _, endTime = UnitCastingInfo("player")
            if spellName then
                state.isCasting = true
                state.castEndTime = endTime and (endTime / 1000) or (GetTime() + 1.5)
                
                -- Identify cast
                if spellName == GetSpellInfo(SPELL_STEADY_SHOT) then
                    state.currentCastAbility = "steady"
                elseif spellName == GetSpellInfo(SPELL_MULTI_SHOT) then
                    state.currentCastAbility = "multi"
                elseif spellName == GetSpellInfo(SPELL_ARCANE_SHOT) then
                    state.currentCastAbility = "arcane"
                else
                    state.currentCastAbility = nil
                end
            end
        end
        
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit == "player" then
            state.isCasting = false
            state.currentCastAbility = nil
        end
        
    elseif event == "START_AUTOREPEAT_SPELL" then
        state.isAutoShooting = true
        
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        state.isAutoShooting = false
        state.lastAutoTime = 0
        state.cycleStartTime = 0
        
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        -- GCD tracking
        local start, duration = GetSpellCooldown(SPELL_ARCANE_SHOT)
        if start and start > 0 and duration and duration > 0 and duration <= 1.5 then
            state.gcdStart = start
            state.gcdDuration = duration
        end
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat
        if HunterSuite.db.weavingBar.enabled and mainFrame then
            mainFrame:SetAlpha(HunterSuite.db.weavingBar.alpha or 1)
        end
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat
        if mainFrame then
            local oocAlpha = HunterSuite.db.weavingBar.oocAlpha
            if oocAlpha == nil then oocAlpha = 0.3 end
            mainFrame:SetAlpha(oocAlpha)
        end
        state.cycleStartTime = 0
        state.lastAutoTime = 0
    end
end

-- ============================================================================
-- OnUpdate - Main render loop
-- ============================================================================

local updateTimer = 0
local slowUpdateTimer = 0

function WeavingBar:OnUpdate(elapsed)
    if not mainFrame then return end
    
    -- Edit mode: show sample with animated scrolling
    if HunterSuite.state.editMode then
        mainFrame:Show()
        mainFrame:SetAlpha(1)
        rotationLabel:SetText("French 5:5:1:1")
        ewsLabel:SetText("eWS: 2.17s")
        -- Build a sample sequence for display
        if not state.currentSequence or state.currentRotation ~= "french" then
            state.currentSequence, state.cycleDuration = ROTATIONS["french"].buildSequence(2.17)
            state.currentRotation = "french"
        end
        -- Keep cycle start time running so the bar scrolls
        if state.cycleStartTime <= 0 then
            state.cycleStartTime = GetTime()
        end
        state.lastAutoTime = state.cycleStartTime  -- Needed for render
        self:RenderTimeline()
        return
    end
    
    local db = HunterSuite.db.weavingBar
    
    if not db.enabled or not HunterSuite.state.isHunter then
        mainFrame:Hide()
        return
    end
    
    -- Show/hide based on auto shooting state
    if not state.isAutoShooting then
        if db.hideWhenInactive then
            mainFrame:Hide()
            return
        end
    end
    
    mainFrame:Show()
    
    -- Fast updates (every frame): timeline rendering
    self:RenderTimeline()
    self:UpdateClippingWarning()
    self:UpdateRotationAlert()
    
    -- Slow updates (~4 Hz): header, buff icons, kill command
    slowUpdateTimer = slowUpdateTimer + elapsed
    if slowUpdateTimer >= 0.25 then
        slowUpdateTimer = 0
        self:UpdateHeader()
        self:UpdateHasteIcons()
        self:UpdateKillCommand()
        
        -- Re-read eWS periodically (catches haste rating changes from gear procs)
        self:UpdateHaste()
        
        -- Re-check rotation if eWS changed significantly
        local newEWS = state.eWS
        if state.currentSequence then
            local oldCycleDur = state.cycleDuration
            local _, newCycleDur = ROTATIONS[state.currentRotation].buildSequence(newEWS)
            if math.abs(newCycleDur - oldCycleDur) > 0.1 then
                self:SelectRotation()
            end
        end
    end
end

-- ============================================================================
-- UpdateUI (called from settings changes)
-- ============================================================================

function WeavingBar:UpdateUI()
    if not mainFrame then return end
    
    local db = HunterSuite.db.weavingBar
    
    if not db.enabled or not HunterSuite.state.isHunter then
        mainFrame:Hide()
        return
    end
    
    mainFrame:SetSize(db.barWidth + 12, db.barHeight + 36)
    mainFrame:SetScale(db.scale or 1)
    mainFrame:SetAlpha(db.alpha or 1)
    
    if HunterSuite.state.editMode then
        mainFrame:Show()
    end
end

-- ============================================================================
-- Init
-- ============================================================================

function WeavingBar:Init()
    self:CreateUI()
    self:UpdateUI()
    
    state.playerGUID = UnitGUID("player")
    self:DetectSpec()
    self:UpdateHaste()
    self:SelectRotation()
    
    -- Register events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_RANGEDDAMAGE")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
    eventFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        WeavingBar:OnEvent(event, ...)
    end)
    
    -- OnUpdate on eventFrame (not mainFrame) so it fires even when mainFrame is hidden
    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        WeavingBar:OnUpdate(elapsed)
    end)
    
    self.eventFrame = eventFrame
end
