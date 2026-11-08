local _, GC = ...

-- Crowded-area detection:
--  a) capital cities (map IDs + zone names, plus zones the player added)
--  b) harbor zones (ships)
--  c) learned spots: wherever the player opened a vendor or flight master window
--  d) manual override (auto / always crowded / always uncrowded)
local Areas = {}
GC.Areas = Areas

-- Known capital city map IDs (modern uiMapIDs and Classic-era uiMapIDs).
local CITY_MAP_IDS = {
  [84] = true, [85] = true, [87] = true, [88] = true, [89] = true, [90] = true,       -- modern
  [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true, -- classic
}

-- Zone names (German + English) as returned by GetRealZoneText().
local CITY_NAMES = {
  ["Stormwind"] = true, ["Stormwind City"] = true, ["Sturmwind"] = true,
  ["Ironforge"] = true, ["Eisenschmiede"] = true,
  ["Darnassus"] = true,
  ["Orgrimmar"] = true,
  ["Thunder Bluff"] = true, ["Donnerfels"] = true,
  ["Undercity"] = true, ["Unterstadt"] = true,
}

-- Harbor subzones / towns with ships or zeppelins (German + English).
local HARBOR_NAMES = {
  ["Menethil Harbor"] = true, ["Hafen von Menethil"] = true,
  ["Booty Bay"] = true, ["Beutebucht"] = true,
  ["Ratchet"] = true, ["Ratschet"] = true,
  ["Auberdine"] = true,
  ["Theramore Isle"] = true, ["Insel Theramore"] = true, ["Theramore"] = true,
  ["Rut'theran Village"] = true, ["Rut'theran"] = true,
}

local LEAVE_MARGIN = 5 -- yards of hysteresis when leaving a learned spot

-- World position of the player in yards (nil when unavailable, e.g. in instances).
function Areas.GetPlayerPos()
  if UnitPosition then
    local y, x, _, instance = GC.SafeCall(UnitPosition, "player")
    if x and y then return x, y, instance end
  end
  if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos then
    local mapID = GC.SafeCall(C_Map.GetBestMapForUnit, "player")
    if not mapID then return nil end
    local pos = GC.SafeCall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not pos then return nil end
    local continent, world = GC.SafeCall(C_Map.GetWorldPosFromMapPos, mapID, pos)
    if continent and world then
      local wx, wy = world:GetXY()
      return wx, wy, continent
    end
  end
  return nil
end

function Areas.SaveSpot()
  local x, y, inst = Areas.GetPlayerPos()
  if not x then return false end
  -- Do not store near-duplicates.
  for _, s in ipairs(GC.db.spots) do
    if s.instance == inst and math.abs(s.x - x) < 10 and math.abs(s.y - y) < 10 then
      return true
    end
  end
  table.insert(GC.db.spots, { x = x, y = y, instance = inst })
  return true
end

local function nearSpot(margin)
  local x, y, inst = Areas.GetPlayerPos()
  if not x then return false end
  local r = (GC.db.spotRadius or 30) + (margin or 0)
  for _, s in ipairs(GC.db.spots) do
    if s.instance == inst then
      local dx, dy = s.x - x, s.y - y
      if dx * dx + dy * dy <= r * r then return true end
    end
  end
  return false
end

function Areas.IsCityZone()
  local mapID = C_Map and GC.SafeCall(C_Map.GetBestMapForUnit, "player")
  if mapID and CITY_MAP_IDS[mapID] then return true end
  local zone = GC.SafeCall(GetRealZoneText)
  if zone and (CITY_NAMES[zone] or GC.db.customCities[zone]) then return true end
  return false
end

function Areas.IsHarbor()
  local sub = GC.SafeCall(GetSubZoneText)
  local zone = GC.SafeCall(GetRealZoneText)
  return (sub and HARBOR_NAMES[sub]) or (zone and HARBOR_NAMES[zone]) or false
end

-- Returns crowded (bool), reasonKey.
function Areas.Evaluate(wasCrowded)
  local mode = GC.db.crowdedMode
  if mode == "on" then return true, "reason_manual" end
  if mode == "off" then return false, nil end
  if GC.Events and GC.Events.IsFlying() then return false, nil end
  if Areas.IsCityZone() then return true, "reason_city" end
  if Areas.IsHarbor() then return true, "reason_harbor" end
  if nearSpot(wasCrowded and LEAVE_MARGIN or 0) then return true, "reason_spot" end
  return false, nil
end

Areas.crowded = false
Areas.reason = nil

-- Re-evaluates the area. Leaving a crowded area shows the collected paladins.
function Areas.Update()
  local crowded, reason = Areas.Evaluate(Areas.crowded)
  local was = Areas.crowded
  -- After login/reload the previous state is unknown: if paladins are still
  -- collected (saved) and we are not in a crowded area, show them now.
  if not Areas.initialized then
    Areas.initialized = true
    was = (GC.cdb.crowded.count or 0) > 0
  end
  Areas.crowded = crowded
  Areas.reason = reason
  if was and not crowded and GC.Paladins then
    GC.Paladins.FlushCrowded()
  end
  if GC.UI then GC.UI:RefreshStatus() end
end

function Areas.IsCrowded() return Areas.crowded end

function Areas.ToggleCustomCity()
  local zone = GC.SafeCall(GetRealZoneText)
  if not zone or zone == "" then return end
  if GC.db.customCities[zone] then
    GC.db.customCities[zone] = nil
    GC.Print(GC.L("city_removed", zone))
  else
    GC.db.customCities[zone] = true
    GC.Print(GC.L("city_added", zone))
  end
  Areas.Update()
end

function Areas.SetMode(mode)
  GC.db.crowdedMode = mode
  Areas.Update()
  if GC.UI then GC.UI:Refresh() end
end

function Areas.CycleMode()
  local next = { auto = "on", on = "off", off = "auto" }
  Areas.SetMode(next[GC.db.crowdedMode] or "auto")
end

-- Learn vendor / flight master positions when their windows open.
local function learn()
  if Areas.SaveSpot() then Areas.Update() end
end
GC.On("MERCHANT_SHOW", learn)
GC.On("TAXIMAP_OPENED", learn)

GC.On("ZONE_CHANGED", Areas.Update)
GC.On("ZONE_CHANGED_INDOORS", Areas.Update)
GC.On("ZONE_CHANGED_NEW_AREA", Areas.Update)
GC.OnTick(Areas.Update)
