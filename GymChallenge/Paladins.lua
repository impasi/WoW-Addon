local _, GC = ...

-- Paladin detection.
-- The API has no "all visible players" function. A player counts as visible
-- when the client shows a nameplate for them, or when they are the player's
-- target or mouseover unit. Group members and the player are never counted.
local Paladins = {}
GC.Paladins = Paladins

local COOLDOWN = 3600       -- one count per player name per hour
local seen = {}             -- name -> GetTime() of last count (session only, per character)
Paladins.seen = seen

local function isGroupMember(unit)
  if GC.SafeCall(UnitIsUnit, unit, "player") then return true end
  if GC.SafeCall(UnitInParty, unit) then return true end
  if GC.SafeCall(UnitInRaid, unit) then return true end
  return false
end

-- Returns the full name ("Name-Realm" or "Name") of a paladin player unit, else nil.
function Paladins.GetPaladinName(unit)
  if not GC.SafeCall(UnitExists, unit) then return nil end
  if not GC.SafeCall(UnitIsPlayer, unit) then return nil end
  if isGroupMember(unit) then return nil end
  local _, classFile = GC.SafeCall(UnitClass, unit)
  if classFile ~= "PALADIN" then return nil end
  -- Only undead paladins count. The race token for Undead is "Scourge"
  -- in every client language (race ID 5).
  local _, raceFile, raceID = GC.SafeCall(UnitRace, unit)
  if raceFile ~= "Scourge" and raceID ~= 5 then return nil end
  local name, realm = GC.SafeCall(UnitName, unit)
  if not name or name == "" or name == UNKNOWNOBJECT then return nil end
  if realm and realm ~= "" then name = name .. "-" .. realm end
  return name
end

-- Registers a sighting. Returns true if it counted.
function Paladins.Count(name)
  local now = GetTime()
  local last = seen[name]
  if last and now - last < COOLDOWN then return false end
  seen[name] = now

  if GC.Areas.IsCrowded() then
    local c = GC.cdb.crowded
    c.count = c.count + 1
    table.insert(c.names, name)
    GC.Debug("Paladin collected (crowded): " .. name)
    if GC.UI then GC.UI:RefreshStatus() end
  else
    GC.AddTask("pushups", 5, "r_paladin_open", name)
  end
  return true
end

function Paladins.CheckUnit(unit)
  -- No paladins are counted during a flight (they are also not put on cooldown).
  if GC.Events and GC.Events.IsFlying() then return end
  local name = Paladins.GetPaladinName(unit)
  if name then Paladins.Count(name) end
end

-- Called when leaving a crowded area (also right before a flight starts).
-- early = true: the player pressed "do now" while still in the crowded area.
-- Paladins seen afterwards are collected again and shown when leaving.
function Paladins.FlushCrowded(early)
  local c = GC.cdb.crowded
  local n = c.count or 0
  if n > 0 then
    GC.AddTask("pushups", n * 1, "r_paladin_crowded", n, { silent = true })
    GC.Alert(GC.L(early and "alert_crowded_early" or "alert_crowded_summary", n, n * 1))
  end
  c.count = 0
  c.names = {}
  if GC.UI then GC.UI:RefreshStatus() end
end

-- True if any player nameplates are enabled (or the CVars are unknown).
function Paladins.NameplatesEnabled()
  if not GetCVar then return true end
  local known = false
  for _, cvar in ipairs({ "nameplateShowFriends", "nameplateShowFriendlyPlayers", "nameplateShowEnemies" }) do
    local v = GC.SafeCall(GetCVar, cvar)
    if v ~= nil then
      known = true
      if v == "1" then return true end
    end
  end
  return not known
end

-- Periodic rescan of all visible nameplates (class/name data can arrive late
-- or be secret during combat; we simply try again next second).
local function scanNameplates()
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  local plates = GC.SafeCall(C_NamePlate.GetNamePlates)
  if not plates then return end
  for _, plate in ipairs(plates) do
    local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if unit then Paladins.CheckUnit(unit) end
  end
end

GC.On("NAME_PLATE_UNIT_ADDED", function(unit) Paladins.CheckUnit(unit) end)
GC.On("PLAYER_TARGET_CHANGED", function() Paladins.CheckUnit("target") end)
GC.On("UPDATE_MOUSEOVER_UNIT", function() Paladins.CheckUnit("mouseover") end)
GC.OnTick(scanNameplates)
