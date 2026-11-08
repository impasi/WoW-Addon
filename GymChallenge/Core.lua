local ADDON_NAME, GC = ...
_G.GymChallenge = GC

GC.version = "1.0.0"

-- Exercise kinds. "plank" amounts are seconds; the others are repetitions.
GC.KINDS = { "squats", "pushups", "burpees", "situps", "plank" }

local ACCOUNT_DEFAULTS = {
  lang = nil,           -- nil = follow client locale
  sound = true,
  comm = true,          -- group ranking exchange
  crowdedMode = "auto", -- "auto" | "on" | "off"
  spotRadius = 30,      -- yards around learned vendor/flight master spots
  spots = {},           -- learned crowded spots { x, y, instance }
  customCities = {},    -- zone names the player added as city
  crowdedAreas = {},    -- whole subzones saved via "Save spot": ["Zone|Subzone"] = true
  leaderboard = {},     -- received stats, keyed by "Name-Realm"
  flightTimes = {},     -- learned flight durations: ["From > To"] = { t = seconds, n = flights }
  window = nil,         -- saved window position
  rankWindow = nil,
}

local CHAR_DEFAULTS = {
  tasks = {},
  history = {},     -- every assigned exercise (newest last), see GC.AddHistory
  nextId = 1,
  stats = { squats = 0, pushups = 0, burpees = 0, situps = 0, plank = 0,
            flightsMade = 0, flightsFailed = 0 },
  rev = 0,          -- increases on every stats change (used for de-duplication)
  updated = 0,      -- time() of the last stats change
  crowded = { count = 0, names = {} }, -- paladins collected in the current crowded area
  flight = nil,     -- { start = time(), lastSeen = time(), taskId = n } while on a taxi
  wasInInstance = false,
}

local function applyDefaults(target, defaults)
  for k, v in pairs(defaults) do
    if target[k] == nil then
      if type(v) == "table" then
        target[k] = {}
        applyDefaults(target[k], v)
      else
        target[k] = v
      end
    elseif type(v) == "table" and type(target[k]) == "table" then
      applyDefaults(target[k], v)
    end
  end
end

-------------------------------------------------------------------------------
-- Helpers for the secret-value restrictions of the modern API.
-------------------------------------------------------------------------------

-- True if v is a secret value that addons may not inspect.
function GC.IsSecret(v)
  if issecretvalue then
    local ok, res = pcall(issecretvalue, v)
    return ok and res and true or false
  end
  return false
end

-- Calls fn(...) safely. Returns nil if it errors or returns a secret first value.
function GC.SafeCall(fn, ...)
  if not fn then return nil end
  local res = { pcall(fn, ...) }
  if not res[1] then return nil end
  for i = 2, #res do
    if GC.IsSecret(res[i]) then return nil end
  end
  return select(2, unpack(res))
end

function GC.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Gym Challenge:|r " .. tostring(msg))
end

function GC.Debug(msg)
  if GC.debug then GC.Print("|cff888888" .. tostring(msg) .. "|r") end
end

-------------------------------------------------------------------------------
-- Sound + on-screen alerts
-------------------------------------------------------------------------------

local SOUNDS = {
  new = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959,
  flight = (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960,
  timer = (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 12889,
}

function GC.PlaySound(kind)
  if not GC.db.sound then return end
  local id = SOUNDS[kind] or SOUNDS.new
  if PlaySound then pcall(PlaySound, id, "Master") end
end

function GC.Alert(text, soundKind)
  GC.Print(text)
  if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
  end
  if soundKind ~= false then GC.PlaySound(soundKind or "new") end
end

-------------------------------------------------------------------------------
-- Tasks and statistics
-------------------------------------------------------------------------------

-- Human readable "what to do" text of a task.
function GC.TaskText(task)
  if task.kind == "flight" then
    local dur
    if task.state == "running" then
      dur = time() - task.start
    else
      dur = task.amount or 0
    end
    return GC.L(task.state == "running" and "ex_flight_running" or "ex_flight_done", GC.FormatDuration(dur))
  end
  if task.kind == "plank" then return GC.L("ex_plank", GC.FormatPlank(task.amount)) end
  return GC.L("ex_" .. task.kind, task.amount)
end

-- 60 -> "1 Min.", 90 -> "1:30 Min.", 20 -> "20 Sek."
function GC.FormatPlank(sec)
  sec = math.floor(sec or 0)
  if sec < 60 then return GC.L("unit_sec", sec) end
  if sec % 60 == 0 then return GC.L("unit_min", sec / 60) end
  return GC.L("unit_min_s", GC.FormatDuration(sec))
end

function GC.ReasonText(task)
  if task.reasonArg ~= nil then
    return GC.L(task.reason, task.reasonArg)
  end
  return GC.L(task.reason)
end

function GC.BumpStats()
  local c = GC.cdb
  c.rev = c.rev + 1
  c.updated = time()
  if GC.Comm then GC.Comm:ScheduleBroadcast() end
end

function GC.AddStat(kind, amount)
  if GC.cdb.stats[kind] == nil then return end
  GC.cdb.stats[kind] = GC.cdb.stats[kind] + (amount or 0)
  GC.BumpStats()
end

-------------------------------------------------------------------------------
-- History: one entry per assigned exercise. Entries share the id of their task.
-- status: open | done | cleared | landed | made | failed
-------------------------------------------------------------------------------
local HISTORY_MAX = 500

function GC.AddHistory(task, status)
  local h = GC.cdb.history
  table.insert(h, {
    id = task.id, t = task.created or time(), kind = task.kind, amount = task.amount,
    reason = task.reason, reasonArg = task.reasonArg, status = status or "open",
  })
  while #h > HISTORY_MAX do table.remove(h, 1) end -- oldest entries drop out; stats stay
  if GC.UI and GC.UI.RefreshHistory then GC.UI:RefreshHistory() end
end

function GC.FindHistory(id)
  for i, e in ipairs(GC.cdb.history) do
    if e.id == id then return e, i end
  end
end

function GC.SetHistoryStatus(id, status)
  local e = GC.FindHistory(id)
  if e then e.status = status end
  if GC.UI and GC.UI.RefreshHistory then GC.UI:RefreshHistory() end
end

-- Deletes one event: removes it from the history, from the open list and
-- subtracts it from the own statistics (which are shared with the ranking).
function GC.DeleteHistory(id)
  local e, i = GC.FindHistory(id)
  if not e then return end
  local st = GC.cdb.stats
  local function sub(key, n) st[key] = math.max(0, (st[key] or 0) - (n or 0)) end
  -- Only events that were counted (done / made / failed) are subtracted.
  if e.kind == "flight" then
    if e.status == "made" then sub("plank", e.amount); sub("flightsMade", 1) end
    if e.status == "failed" then sub("flightsFailed", 1) end
  elseif e.status == "done" then
    sub(e.kind, e.amount)
  end
  table.remove(GC.cdb.history, i)
  local _, ti = GC.FindTask(id)
  if ti then table.remove(GC.cdb.tasks, ti) end
  GC.BumpStats()
  if GC.UI then GC.UI:Refresh(); GC.UI:RefreshHistory(); GC.UI:RefreshRank() end
end

-- Adds a task to the open list. kind: one of GC.KINDS or "flight".
-- Statistics count what the addon assigned, not what was performed.
function GC.AddTask(kind, amount, reason, reasonArg, opts)
  local c = GC.cdb
  local task = {
    id = c.nextId,
    kind = kind,
    amount = amount,
    reason = reason,
    reasonArg = reasonArg,
    created = time(),
    state = "open",
  }
  c.nextId = c.nextId + 1
  if opts then for k, v in pairs(opts) do task[k] = v end end
  table.insert(c.tasks, task)

  if kind ~= "flight" then
    -- Statistics only count once the player marks the exercise as done.
    GC.AddHistory(task, "open")
    if not (opts and opts.silent) then
      GC.Alert(GC.L("alert_new", GC.TaskText(task), GC.ReasonText(task)))
    end
  end
  if GC.UI then GC.UI:Refresh() end
  return task
end

function GC.FindTask(id)
  for i, t in ipairs(GC.cdb.tasks) do
    if t.id == id then return t, i end
  end
end

-- Manual completion by the player.
-- Only now the exercise counts for the statistics / ranking.
function GC.CompleteTask(id)
  local task, i = GC.FindTask(id)
  if not task then return end
  table.remove(GC.cdb.tasks, i)
  if task.kind ~= "flight" then GC.AddStat(task.kind, task.amount) end
  GC.SetHistoryStatus(id, "done")
  if GC.UI then GC.UI:Refresh() end
end

-- Answer to "did you make it?" after a flight plank.
function GC.AnswerFlight(id, made)
  local task, i = GC.FindTask(id)
  if not task then return end
  if made then
    -- Only a made flight plank counts its seconds.
    GC.cdb.stats.plank = GC.cdb.stats.plank + (task.amount or 0)
    GC.cdb.stats.flightsMade = GC.cdb.stats.flightsMade + 1
  else
    GC.cdb.stats.flightsFailed = GC.cdb.stats.flightsFailed + 1
  end
  GC.BumpStats()
  GC.SetHistoryStatus(id, made and "made" or "failed")
  table.remove(GC.cdb.tasks, i)
  if GC.UI then GC.UI:Refresh() end
end

-- Starts the countdown of a timed plank (only on the player's click).
function GC.StartTimer(id)
  local task = GC.FindTask(id)
  if not task or task.kind ~= "plank" then return end
  task.timerStart = time()
  task.timerAlerted = nil
  if GC.UI then GC.UI:Refresh() end
end

-- Removes all open tasks except a flight that is still running.
function GC.ClearTasks()
  local keep = {}
  for _, t in ipairs(GC.cdb.tasks) do
    if t.kind == "flight" and t.state == "running" then
      table.insert(keep, t)
    else
      local e = GC.FindHistory(t.id)
      if e and (e.status == "open" or e.status == "landed") then e.status = "cleared" end
    end
  end
  GC.cdb.tasks = keep
  if GC.UI then GC.UI:Refresh() end
end

-- Version 2: statistics count only completed exercises. Older saved data
-- counted every assigned exercise, so recompute it once from the history.
function GC.MigrateStats()
  local c = GC.cdb
  if c.statsVersion == 2 then return end
  for k in pairs(c.stats) do c.stats[k] = 0 end
  for _, e in ipairs(c.history) do
    if e.kind == "flight" then
      if e.status == "made" then
        c.stats.plank = c.stats.plank + (e.amount or 0)
        c.stats.flightsMade = c.stats.flightsMade + 1
      elseif e.status == "failed" then
        c.stats.flightsFailed = c.stats.flightsFailed + 1
      end
    elseif e.status == "done" and c.stats[e.kind] then
      c.stats[e.kind] = c.stats[e.kind] + (e.amount or 0)
    end
  end
  c.statsVersion = 2
  c.rev = c.rev + 1
  c.updated = time()
end

function GC.ResetOwnStats()
  for k in pairs(GC.cdb.stats) do GC.cdb.stats[k] = 0 end
  GC.BumpStats()
  if GC.UI then GC.UI:Refresh() end
end

-- Checked once per second: finished plank timers.
function GC.TickTimers()
  for _, t in ipairs(GC.cdb.tasks) do
    if t.kind == "plank" and t.timerStart and not t.timerAlerted then
      if time() - t.timerStart >= t.amount then
        t.timerAlerted = true
        GC.Alert(GC.L("alert_timer_done"), "timer")
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Event dispatcher
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
GC.eventFrame = frame
local handlers = {}

function GC.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    frame:RegisterEvent(event)
  end
  table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  if not GC.cdb and event ~= "ADDON_LOADED" then return end
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn, ...)
    if not ok then GC.Debug(event .. ": " .. tostring(err)) end
  end
end)

local tickers = {}
function GC.OnTick(fn) table.insert(tickers, fn) end

GC.On("ADDON_LOADED", function(name)
  if name ~= ADDON_NAME then return end
  GymChallengeDB = GymChallengeDB or {}
  GymChallengeCharDB = GymChallengeCharDB or {}
  applyDefaults(GymChallengeDB, ACCOUNT_DEFAULTS)
  applyDefaults(GymChallengeCharDB, CHAR_DEFAULTS)
  GC.db = GymChallengeDB
  GC.cdb = GymChallengeCharDB
  GC.MigrateStats()

  if GC.UI then GC.UI:Init() end
  if GC.Comm then GC.Comm:Init() end

  C_Timer.NewTicker(1, function()
    for _, fn in ipairs(tickers) do
      local ok, err = pcall(fn)
      if not ok then GC.Debug("tick: " .. tostring(err)) end
    end
  end)
end)

GC.OnTick(GC.TickTimers)
