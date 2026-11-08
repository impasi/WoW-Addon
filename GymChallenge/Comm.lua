local _, GC = ...

-- Group ranking exchange via addon messages.
--  * Only the numbers needed for the ranking are sent (no names, no task list).
--  * Every client sends its OWN absolute totals plus a revision number. The
--    receiver replaces the stored entry for that sender instead of adding,
--    so repeated exchanges never count twice.
--  * Messages go to the group channel AND as whispers, because on WoW Forever
--    some channel types were reported to return success without delivering.
--  * Nothing is sent inside instances or during the chat lockdown; the update
--    is sent once that ends. Trial/veteran accounts cannot send at all.
local Comm = {}
GC.Comm = Comm

local PREFIX = "GymChallenge"   -- max. 16 characters
local PROTO = "1"
local BROADCAST_DELAY = 5       -- seconds of debounce after a stats change
local SENDS_PER_TICK = 2        -- stays well below the 10 msg burst / 1 per sec regen

local queue = {}                -- { text, chatType, target }
local known = {}                -- names of group members that answered (addon users)
local members = {}              -- current group members
local broadcastDue = nil
local wasGrouped = false

function Comm:Init()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  end
end

local function myName()
  local name = UnitName("player")
  local realm = GetNormalizedRealmName and GetNormalizedRealmName()
  return name, realm
end

local function isSelf(sender)
  local name, realm = myName()
  if sender == name then return true end
  return realm and sender == (name .. "-" .. realm) or false
end

-- Full name used as leaderboard key ("Name-Realm").
local function normalize(sender)
  if sender:find("-", 1, true) then return sender end
  local _, realm = myName()
  return realm and (sender .. "-" .. realm) or sender
end

local function blocked()
  if GC.Events and GC.Events.InAnyInstance() then return true end
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local locked = GC.SafeCall(C_ChatInfo.InChatMessagingLockdown)
    if locked then return true end
  end
  return false
end

local function groupChannel()
  if IsInRaid and IsInRaid() then return "RAID" end
  return "PARTY"
end

local function groupMembers()
  local list = {}
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  local raid = IsInRaid and IsInRaid()
  for i = 1, n do
    local unit = raid and ("raid" .. i) or ("party" .. i)
    if GC.SafeCall(UnitExists, unit) and not GC.SafeCall(UnitIsUnit, unit, "player") then
      local name, realm = GC.SafeCall(UnitName, unit)
      if name and name ~= "" then
        if not realm or realm == "" then
          local _, myRealm = myName()
          realm = myRealm
        end
        list[realm and (name .. "-" .. realm) or name] = unit
      end
    end
  end
  return list
end

function Comm.StatsMessage()
  local c = GC.cdb
  local s = c.stats
  return table.concat({ "S" .. PROTO, c.rev, c.updated, s.squats, s.pushups, s.burpees,
    s.situps, s.plank, s.flightsMade, s.flightsFailed }, ";")
end

local function enqueue(text, chatType, target)
  for _, q in ipairs(queue) do
    if q.text:sub(1, 2) == text:sub(1, 2) and q.chatType == chatType and q.target == target then
      q.text = text -- replace an older pending message of the same kind
      return
    end
  end
  table.insert(queue, { text = text, chatType = chatType, target = target })
end

-- Sends our stats to the group channel and whispers them to known addon users.
function Comm:Broadcast(alsoWhisperAll)
  if not GC.db.comm or not (IsInGroup and IsInGroup()) then return end
  local msg = Comm.StatsMessage()
  enqueue(msg, groupChannel())
  for name in pairs(alsoWhisperAll and members or known) do
    if members[name] then enqueue(msg, "WHISPER", name) end
  end
end

function Comm:Hello()
  if not GC.db.comm or not (IsInGroup and IsInGroup()) then return end
  local msg = "H" .. PROTO
  enqueue(msg, groupChannel())
  for name in pairs(members) do enqueue(msg, "WHISPER", name) end
  Comm:Broadcast(true)
end

function Comm:ScheduleBroadcast()
  broadcastDue = GetTime() + BROADCAST_DELAY
end

local THROTTLED = { [3] = true, [8] = true, [11] = true } -- throttle / channel throttle / lockdown

local function processQueue()
  if broadcastDue and GetTime() >= broadcastDue and not blocked() then
    broadcastDue = nil
    Comm:Broadcast(false)
  end
  if #queue == 0 or blocked() or not GC.db.comm then return end
  for _ = 1, SENDS_PER_TICK do
    local q = table.remove(queue, 1)
    if not q then break end
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, q.text, q.chatType, q.target)
    if ok and type(res) == "number" and THROTTLED[res] then
      table.insert(queue, 1, q) -- try again next second
      break
    end
    GC.Debug("sent " .. q.chatType .. " " .. tostring(q.target) .. " -> " .. tostring(res))
  end
end
GC.OnTick(processQueue)

-- Stores received totals. Replaces the old entry; never adds up.
function Comm.Store(sender, fields)
  local rev, updated = tonumber(fields[2]), tonumber(fields[3])
  if not rev or not updated then return false end
  local lb = GC.db.leaderboard
  local old = lb[sender]
  if old and rev <= old.rev and updated <= old.updated then
    return false -- same or older data: ignore (no double counting)
  end
  local function n(i) return math.max(0, math.floor(tonumber(fields[i]) or 0)) end
  lb[sender] = {
    rev = rev,
    updated = updated,      -- sender's time of their last change
    received = time(),      -- when we received it
    squats = n(4), pushups = n(5), burpees = n(6), situps = n(7),
    plank = n(8), flightsMade = n(9), flightsFailed = n(10),
  }
  if GC.UI then GC.UI:RefreshRank() end
  return true
end

function Comm.OnMessage(prefix, text, _, sender)
  if prefix ~= PREFIX then return end
  if GC.IsSecret(text) or GC.IsSecret(sender) then return end
  if not GC.db.comm or type(text) ~= "string" or type(sender) ~= "string" then return end
  if isSelf(sender) then return end
  sender = normalize(sender)
  known[sender] = true

  local fields = {}
  for part in string.gmatch(text, "[^;]+") do table.insert(fields, part) end
  local kind = fields[1]
  if kind == "H" .. PROTO then
    -- Someone joined / asked: answer with our stats directly to them.
    enqueue(Comm.StatsMessage(), "WHISPER", sender)
  elseif kind == "S" .. PROTO then
    Comm.Store(sender, fields)
  end
end
GC.On("CHAT_MSG_ADDON", Comm.OnMessage)

function Comm.OnRosterUpdate()
  local grouped = IsInGroup and IsInGroup() or false
  local now = groupMembers()
  local newcomers = false
  for name in pairs(now) do
    if not members[name] then newcomers = true end
  end
  members = now
  if grouped and (not wasGrouped or newcomers) then
    Comm:Hello()
  end
  if not grouped then
    queue = {}
    known = {}
  end
  wasGrouped = grouped
end
GC.On("GROUP_ROSTER_UPDATE", Comm.OnRosterUpdate)
GC.On("PLAYER_ENTERING_WORLD", Comm.OnRosterUpdate)

function Comm:SetEnabled(on)
  GC.db.comm = on and true or false
  if on then
    Comm.OnRosterUpdate()
    Comm:Hello()
  else
    queue = {}
  end
  if GC.UI then GC.UI:RefreshRank() end
end

function Comm:ResetLeaderboard()
  GC.db.leaderboard = {}
  if GC.UI then GC.UI:RefreshRank() end
end
