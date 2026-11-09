local _, GC = ...

-- Shame message: if an exercise stays open for 30 minutes, friends who also
-- use the addon get a short note ("X1;name;kind;amount;minutes").
--  * Only online time counts (the counter runs while the game is running),
--    so logging out does not trigger a message.
--  * Once per task. Flight tasks are excluded (they are answered, not done).
--  * Recipients: group (channel + whispers), online friends from the friends
--    list (whisper) and Battle.net friends playing WoW (BNSendGameData).
--    Friends without the addon simply ignore the hidden addon message.
--  * Sending follows the same queue as the ranking (no sending inside
--    instances or during the chat lockdown; it is sent afterwards).
local Shame = {}
GC.Shame = Shame

Shame.SECONDS = 30 * 60
local DEDUPE_SECONDS = 60
local recent = {} -- payload -> time() of last alert

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  return GC.SafeCall(fn, ...)
end

-- Online character friends: list of "Name" / "Name-Realm".
local function characterFriends()
  local list = {}
  if not (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex) then return list end
  local n = safe(C_FriendList.GetNumFriends) or 0
  for i = 1, n do
    local info = safe(C_FriendList.GetFriendInfoByIndex, i)
    if type(info) == "table" and info.connected and type(info.name) == "string" and info.name ~= "" then
      table.insert(list, info.name)
    end
  end
  return list
end

-- Battle.net friends currently in WoW: list of { id = gameAccountID, name = characterName }.
local function bnetFriends()
  local list = {}
  if not (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendNumGameAccounts
      and C_BattleNet.GetFriendGameAccountInfo and BNSendGameData) then return list end
  local n = safe(BNGetNumFriends) or 0
  local wow = BNET_CLIENT_WOW or "WoW"
  for i = 1, n do
    local accounts = safe(C_BattleNet.GetFriendNumGameAccounts, i) or 0
    for j = 1, accounts do
      local g = safe(C_BattleNet.GetFriendGameAccountInfo, i, j)
      if type(g) == "table" and g.isOnline and g.clientProgram == wow and g.gameAccountID then
        table.insert(list, { id = g.gameAccountID, name = g.characterName })
      end
    end
  end
  return list
end

function Shame.Message(task, minutes)
  local name = GC.Comm.myName()
  return table.concat({ "X1", name or "?", task.kind, task.amount or 0, minutes }, ";")
end

-- Queues the message to everybody reachable. Returns the number of recipients.
function Shame.Send(task, minutes)
  local msg = Shame.Message(task, minutes)
  local count, done = 0, {}
  local function whisper(name)
    local key = name:lower()
    if not key:find("-", 1, true) then
      local _, realm = GC.Comm.myName()
      if realm then key = key .. "-" .. realm:lower() end
    end
    if done[key] or GC.Comm.isSelf(name) then return end
    done[key] = true
    GC.Comm.Enqueue(msg, "WHISPER", name, true)
    count = count + 1
  end
  if IsInGroup and IsInGroup() then
    GC.Comm.Enqueue(msg, GC.Comm.groupChannel(), nil, true)
    for name in pairs(GC.Comm.members()) do whisper(name) end
  end
  for _, name in ipairs(characterFriends()) do whisper(name) end
  for _, f in ipairs(bnetFriends()) do
    local key = "bn:" .. tostring(f.id)
    if not done[key] then
      done[key] = true
      GC.Comm.Enqueue(msg, "BN", f.id, true)
      count = count + 1
    end
  end
  return count
end

local function tick()
  if not GC.db.shameSend then return end
  for _, t in ipairs(GC.cdb.tasks) do
    if t.kind ~= "flight" and not t.shamed then
      t.openSecs = (t.openSecs or 0) + 1
      if t.openSecs >= Shame.SECONDS then
        t.shamed = true
        local minutes = math.floor(t.openSecs / 60)
        local n = Shame.Send(t, minutes)
        GC.Print(GC.L(n > 0 and "shame_sent" or "shame_nobody", GC.TaskText(t), minutes))
      end
    end
  end
end
GC.OnTick(tick)

function Shame.OnReceive(text)
  if not GC.db.shameReceive then return end
  local f = {}
  for part in string.gmatch(text, "[^;]+") do table.insert(f, part) end
  local name, kind, amount, minutes = f[2], f[3], tonumber(f[4]), tonumber(f[5])
  if not name or not amount or not minutes then return end
  local valid = false
  for _, k in ipairs(GC.KINDS) do if k == kind then valid = true end end
  if not valid then return end
  -- The same message may arrive via group, whisper and Battle.net.
  local now = time()
  if recent[text] and now - recent[text] < DEDUPE_SECONDS then return end
  recent[text] = now
  local short = name:match("^([^%-]+)") or name
  local what = GC.TaskText({ kind = kind, amount = math.max(0, math.floor(amount)) })
  GC.Alert(GC.L("shame_received", short, math.floor(minutes), what), "timer")
end
