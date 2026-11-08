local _, GC = ...

local Events = {}
GC.Events = Events
-- True until the first taxi check after login/reload (see CheckTaxi).
Events.loginCheckPending = true

-------------------------------------------------------------------------------
-- Death: 10 squats
-------------------------------------------------------------------------------
function Events.OnDeath()
  GC.AddTask("squats", 10, "r_death")
end
GC.On("PLAYER_DEAD", Events.OnDeath)

-------------------------------------------------------------------------------
-- Level up: 5 burpees
-------------------------------------------------------------------------------
function Events.OnLevelUp(level)
  GC.AddTask("burpees", 5, "r_level", tonumber(level) or GC.SafeCall(UnitLevel, "player") or 0)
end
GC.On("PLAYER_LEVEL_UP", Events.OnLevelUp)

-------------------------------------------------------------------------------
-- Flying: plank from take-off until landing
-------------------------------------------------------------------------------
function Events.IsFlying()
  return GC.cdb and GC.cdb.flight ~= nil
end

function Events.StartFlight(startTime, isTest)
  if GC.cdb.flight then return end
  local now = time()
  GC.cdb.flight = { start = startTime or now, lastSeen = now, test = isTest or nil }
  -- Leaving a crowded area by flight: show the collected paladins before the flight.
  GC.Areas.Update()
  local task = GC.AddTask("flight", 0, "r_flight", nil, { state = "running", start = GC.cdb.flight.start })
  GC.cdb.flight.taskId = task.id
  GC.Alert(GC.L("alert_flight_start"), "flight")
  if GC.UI and GC.UI.RefreshFlightTimer then GC.UI:RefreshFlightTimer() end
end

function Events.EndFlight(endTime)
  local f = GC.cdb.flight
  if not f then return end
  GC.cdb.flight = nil
  local duration = math.max(0, (endTime or time()) - f.start)
  local task = GC.FindTask(f.taskId)
  if task then
    task.state = "landed"   -- counts as done; the player answers "made it?"
    task.amount = duration
  else
    GC.AddTask("flight", duration, "r_flight", nil, { state = "landed" })
  end
  GC.AddStat("plank", duration)
  GC.Alert(GC.L("alert_flight_end", GC.FormatDuration(duration)), "flight")
  if GC.UI and GC.UI.ShowLanded then GC.UI:ShowLanded(duration) end
  GC.Areas.Update()
  if GC.UI then GC.UI:Refresh() end
end

function Events.CheckTaxi()
  if GC.cdb.flight and GC.cdb.flight.test then return end -- /gym test flightstart
  local onTaxi = GC.SafeCall(UnitOnTaxi, "player")
  if onTaxi == nil then return end
  if onTaxi then
    if GC.cdb.flight then
      GC.cdb.flight.lastSeen = time()
    else
      Events.StartFlight()
    end
  elseif GC.cdb.flight then
    -- Normal landing: now. After a logout during a flight: last moment seen flying.
    local f = GC.cdb.flight
    local endTime = time()
    if Events.loginCheckPending and f.lastSeen then endTime = f.lastSeen end
    Events.EndFlight(endTime)
  end
  Events.loginCheckPending = false
end

local function delayedTaxiCheck()
  C_Timer.After(0.5, Events.CheckTaxi)
end
GC.On("PLAYER_CONTROL_LOST", delayedTaxiCheck)
GC.On("PLAYER_CONTROL_GAINED", delayedTaxiCheck)
GC.On("TAXIMAP_CLOSED", delayedTaxiCheck)
GC.OnTick(Events.CheckTaxi)

-------------------------------------------------------------------------------
-- Leaving a dungeon / raid / battleground: 20 sit-ups
-- Not counted: logging in outside after a disconnect/logout, and leaving as a ghost.
-------------------------------------------------------------------------------
local COUNTED_INSTANCE_TYPES = { party = true, raid = true, pvp = true }

function Events.InCountedInstance()
  local inInstance, itype = GC.SafeCall(IsInInstance)
  return inInstance and COUNTED_INSTANCE_TYPES[itype] or false
end

function Events.InAnyInstance()
  local inInstance = GC.SafeCall(IsInInstance)
  return inInstance and true or false
end

function Events.OnEnteringWorld(isInitialLogin, isReloadingUi)
  local now = Events.InCountedInstance() and true or false
  local was = GC.cdb.wasInInstance
  if isInitialLogin then
    -- Logged in (also after a disconnect): never counts as leaving.
  elseif not isReloadingUi and was and not now then
    local ghost = GC.SafeCall(UnitIsDeadOrGhost, "player")
    if not ghost then
      GC.AddTask("situps", 20, "r_dungeon")
    end
  end
  GC.cdb.wasInInstance = now
  GC.Areas.Update()
end
GC.On("PLAYER_ENTERING_WORLD", Events.OnEnteringWorld)

-------------------------------------------------------------------------------
-- Elite kill: 20 s plank (timer starts on click).
-- Only the current target is watched (no combat log in the modern API).
-- Disabled inside instances.
-------------------------------------------------------------------------------
local ELITE = { elite = true, rareelite = true, worldboss = true }
local watch = nil          -- { guid, name } of a living elite target
local counted = {}         -- guid -> true (each kill counts once)
Events.eliteCounted = counted

function Events.WatchTarget()
  watch = nil
  if Events.InAnyInstance() then return end
  if not GC.SafeCall(UnitExists, "target") then return end
  if GC.SafeCall(UnitIsPlayer, "target") then return end
  local class = GC.SafeCall(UnitClassification, "target")
  if not class or not ELITE[class] then return end
  if GC.SafeCall(UnitIsDead, "target") then return end
  local guid = GC.SafeCall(UnitGUID, "target")
  if not guid then return end
  watch = { guid = guid, name = GC.SafeCall(UnitName, "target") or "?" }
end

function Events.CheckEliteDeath()
  if not watch then return end
  if Events.InAnyInstance() then watch = nil return end
  local guid = GC.SafeCall(UnitGUID, "target")
  if guid ~= watch.guid then return end
  if GC.SafeCall(UnitIsDead, "target") then
    if not counted[guid] then
      counted[guid] = true
      GC.AddTask("plank", 20, "r_elite", watch.name)
    end
    watch = nil
  end
end

GC.On("PLAYER_TARGET_CHANGED", function()
  Events.CheckEliteDeath() -- in case the old target died in the same frame
  Events.WatchTarget()
end)
GC.On("UNIT_HEALTH", function(unit) if unit == "target" then Events.CheckEliteDeath() end end)
GC.On("UNIT_FLAGS", function(unit) if unit == "target" then Events.CheckEliteDeath() end end)
GC.On("PLAYER_REGEN_ENABLED", Events.CheckEliteDeath)
GC.OnTick(Events.CheckEliteDeath)

-------------------------------------------------------------------------------
-- New flight point discovered: 15 squats
-------------------------------------------------------------------------------
local lastTaxiNode = 0
function Events.OnTaxiNodeMessage(msg)
  if not msg or GC.IsSecret(msg) or not ERR_NEWTAXIPATH then return end
  if msg ~= ERR_NEWTAXIPATH then return end
  local now = GetTime()
  if now - lastTaxiNode < 3 then return end -- same discovery reported twice
  lastTaxiNode = now
  GC.AddTask("squats", 15, "r_taxinode")
end
GC.On("UI_INFO_MESSAGE", function(_, msg) Events.OnTaxiNodeMessage(msg) end)
GC.On("CHAT_MSG_SYSTEM", function(msg) Events.OnTaxiNodeMessage(msg) end)
