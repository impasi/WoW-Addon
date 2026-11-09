local _, GC = ...

local Events = {}
GC.Events = Events
-- True until the first taxi check after login/reload (see CheckTaxi).
Events.loginCheckPending = true

-------------------------------------------------------------------------------
-- Death: 10 squats
-------------------------------------------------------------------------------
-- PLAYER_DEAD can fire more than once for the same death (e.g. again when
-- releasing the spirit). Each death counts once: the flag is only cleared
-- when the player is alive again (resurrected or back in the body).
function Events.OnDeath()
  if GC.cdb.deathCounted then return end
  GC.cdb.deathCounted = true
  GC.Assign("death", 1, "r_death")
end
GC.On("PLAYER_DEAD", Events.OnDeath)

function Events.CheckAlive()
  if not GC.cdb.deathCounted then return end
  local deadOrGhost = GC.SafeCall(UnitIsDeadOrGhost, "player")
  if deadOrGhost == false then GC.cdb.deathCounted = nil end
end
GC.On("PLAYER_ALIVE", Events.CheckAlive)
GC.On("PLAYER_UNGHOST", Events.CheckAlive)
GC.OnTick(Events.CheckAlive)

-------------------------------------------------------------------------------
-- Level up: 5 burpees
-------------------------------------------------------------------------------
function Events.OnLevelUp(level)
  GC.Assign("level", 1, "r_level", tonumber(level) or GC.SafeCall(UnitLevel, "player") or 0)
end
GC.On("PLAYER_LEVEL_UP", Events.OnLevelUp)

-------------------------------------------------------------------------------
-- Flying: plank from take-off until landing
-------------------------------------------------------------------------------
function Events.IsFlying()
  return GC.cdb and GC.cdb.flight ~= nil
end

-- The API has no "flight duration". The addon learns it: when you pick a
-- destination (TakeTaxiNode), it remembers origin and destination, measures
-- the flight and stores the time per route (account-wide). On the next flight
-- on the same route the expected duration is shown right at take-off.
local pendingRoute = nil -- { key, from, to, at }

local function currentTaxiNodeName()
  if not (NumTaxiNodes and TaxiNodeGetType and TaxiNodeName) then return nil end
  local n = GC.SafeCall(NumTaxiNodes) or 0
  for i = 1, n do
    if GC.SafeCall(TaxiNodeGetType, i) == "CURRENT" then
      return GC.SafeCall(TaxiNodeName, i)
    end
  end
end

function Events.OnTakeTaxiNode(slot)
  local from = currentTaxiNodeName()
  local to = TaxiNodeName and GC.SafeCall(TaxiNodeName, slot)
  if from and to then
    pendingRoute = { key = from .. " > " .. to, from = from, to = to, at = GetTime() }
  else
    pendingRoute = nil
  end
end
if hooksecurefunc and TakeTaxiNode then
  -- Secure post-hook: only observes the click, does not change or automate it.
  hooksecurefunc("TakeTaxiNode", function(slot) Events.OnTakeTaxiNode(slot) end)
end

-- Expected duration in seconds for the current flight, or nil if unknown.
function Events.ExpectedDuration()
  local f = GC.cdb and GC.cdb.flight
  if not f or not f.route then return nil end
  local known = GC.db.flightTimes[f.route]
  return known and known.t or nil
end

function Events.StartFlight(startTime, isTest)
  if GC.cdb.flight then return end
  local now = time()
  GC.cdb.flight = { start = startTime or now, lastSeen = now, test = isTest or nil }
  if pendingRoute and GetTime() - pendingRoute.at < 30 then
    GC.cdb.flight.route = pendingRoute.key
    GC.cdb.flight.to = pendingRoute.to
  end
  pendingRoute = nil
  -- Leaving a crowded area by flight: show the collected paladins before the flight.
  GC.Areas.Update()
  local cfg = GC.Challenge("flight")
  GC.cdb.flight.mode = cfg.enabled and cfg.ex or "off"
  local expected = Events.ExpectedDuration()
  if GC.cdb.flight.mode == "flightplank" then
    -- Original rule: plank for the whole flight.
    local task = GC.AddTask("flight", 0, "r_flight", nil, { state = "running", start = GC.cdb.flight.start })
    GC.cdb.flight.taskId = task.id
    if expected then
      GC.Alert(GC.L("alert_flight_start_known", GC.FormatDuration(expected)), "flight")
    else
      GC.Alert(GC.L("alert_flight_start"), "flight")
    end
  elseif GC.cdb.flight.mode ~= "off" then
    GC.Alert(GC.L("alert_flight_start_per", GC.AssignText("flight", 1)), "flight")
  end
  if GC.UI and GC.UI.RefreshFlightTimer then GC.UI:RefreshFlightTimer() end
end

-- recovered = true when the landing was only noticed after a login/reload;
-- such durations are not exact and are not learned.
function Events.EndFlight(endTime, recovered)
  local f = GC.cdb.flight
  if not f then return end
  GC.cdb.flight = nil
  local duration = math.max(0, (endTime or time()) - f.start)
  local mode = f.mode or "flightplank"
  if mode == "flightplank" then
    local task = GC.FindTask(f.taskId)
    if task then
      task.state = "landed"   -- counts as done; the player answers "made it?"
      task.amount = duration
    else
      task = GC.AddTask("flight", duration, "r_flight", nil, { state = "landed" })
    end
    GC.AddHistory(task, "landed")
  elseif mode ~= "off" then
    -- Amount of the chosen exercise per full 20 s of flight time.
    local steps = math.floor(duration / GC.FLIGHT_STEP)
    if steps > 0 then GC.Assign("flight", steps, "r_flight_time", GC.FormatDuration(duration)) end
  end
  if f.route and not recovered and not f.test and duration >= 5 then
    GC.db.flightTimes[f.route] = { t = duration, n = ((GC.db.flightTimes[f.route] or {}).n or 0) + 1 }
  end
  if mode == "flightplank" then
    GC.Alert(GC.L("alert_flight_end", GC.FormatDuration(duration)), "flight")
  end
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
    local recovered = Events.loginCheckPending
    if recovered and f.lastSeen then endTime = f.lastSeen end
    Events.EndFlight(endTime, recovered)
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
      GC.Assign("dungeon", 1, "r_dungeon")
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
      GC.Assign("elite", 1, "r_elite", watch.name)
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
  GC.Assign("taxinode", 1, "r_taxinode")
end
GC.On("UI_INFO_MESSAGE", function(_, msg) Events.OnTaxiNodeMessage(msg) end)
GC.On("CHAT_MSG_SYSTEM", function(msg) Events.OnTaxiNodeMessage(msg) end)
