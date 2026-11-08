-- Minimal mock of the WoW client API, just enough to load the addon outside
-- the game and simulate events. This is NOT the real API; it only lets us
-- test the addon's own logic (task creation, cooldowns, de-duplication, ...).

Mock = { now = 1000000, gettime = 500, units = {}, cvars = {}, sent = {}, frames = {},
         tickers = {}, timers = {}, instance = { false, "none" }, zone = "Wald von Elwynn",
         subzone = "", mapID = 37, pos = { 0, 0 }, onTaxi = false, inGroup = false,
         groupMembers = {}, raid = false, lockdown = false }

function time() return Mock.now end
function GetTime() return Mock.gettime end
unpack = unpack or table.unpack

function Mock.advance(sec)
  Mock.now = Mock.now + sec
  Mock.gettime = Mock.gettime + sec
end

local function noop() end
local widgetMT
widgetMT = {
  __index = function(t, k)
    return function(self, ...)
      return nil
    end
  end,
}

function CreateFrame(kind, name, parent, template)
  local f = { events = {}, scripts = {}, shown = true }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:SetScript(s, fn) self.scripts[s] = fn end
  function f:IsShown() return self.shown end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:CreateFontString()
    local fs = { text = "" }
    function fs:SetText(t) self.text = t end
    function fs:GetText() return self.text end
    return setmetatable(fs, widgetMT)
  end
  function f:CreateTexture() return setmetatable({}, widgetMT) end
  function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
  function f:SetText(t) self.text = t end
  function f:SetSize(w, h) self.w, self.h = w, h; if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self) end end
  function f:SetWidth(w) self.w = w end
  function f:SetHeight(h) self.h = h end
  function f:GetWidth() return self.w end
  function f:GetHeight() return self.h end
  setmetatable(f, widgetMT)
  table.insert(Mock.frames, f)
  if name then _G[name] = f end
  return f
end
UIParent = CreateFrame("Frame")

function Mock.fire(event, ...)
  for _, f in ipairs(Mock.frames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end

C_Timer = {
  NewTicker = function(_, fn) table.insert(Mock.tickers, fn) end,
  After = function(_, fn) table.insert(Mock.timers, fn) end,
}
function Mock.tick(n)
  for _ = 1, (n or 1) do
    Mock.advance(1)
    local timers = Mock.timers
    Mock.timers = {}
    for _, fn in ipairs(timers) do fn() end
    for _, fn in ipairs(Mock.tickers) do fn() end
  end
end

DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) Mock.lastPrint = msg; if msg:find("|cff888888") and not msg:find("sent ") and not msg:find("collected") then print("DEBUG " .. msg) end end }
SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960, ALARM_CLOCK_WARNING_3 = 12889 }
Mock.sounds = 0
function PlaySound() Mock.sounds = Mock.sounds + 1 end
function GetLocale() return "deDE" end
function GetCVar(k) return Mock.cvars[k] end
ERR_NEWTAXIPATH = "Neue Flugroute entdeckt!"
UNKNOWNOBJECT = "Unbekannt"
SlashCmdList = {}

-- Units: Mock.units[token] = { name=, realm=, class=, player=, classification=, dead=, guid=, party= }
local function U(unit) return Mock.units[unit] end
function UnitExists(u) return U(u) ~= nil end
function UnitIsPlayer(u) return U(u) and U(u).player or false end
function UnitIsUnit(a, b) return a == b end
function UnitInParty(u) return U(u) and U(u).party or false end
function UnitInRaid(u) return nil end
function UnitClass(u) local x = U(u); if x then return x.class, x.class end end
function UnitName(u)
  if u == "player" then return "Ich" end
  local x = U(u); if x then return x.name, x.realm end
end
function UnitGUID(u) return U(u) and U(u).guid end
function UnitClassification(u) return U(u) and U(u).classification or "normal" end
function UnitIsDead(u) return U(u) and U(u).dead or false end
function UnitIsDeadOrGhost(u) return Mock.ghost or false end
function UnitLevel() return 12 end
function UnitOnTaxi() return Mock.onTaxi end
function UnitPosition() return Mock.pos[2], Mock.pos[1], 0, 0 end
function UnitIsConnected() return true end
function IsInInstance() return Mock.instance[1], Mock.instance[2] end
function GetRealZoneText() return Mock.zone end
function GetSubZoneText() return Mock.subzone end
function GetNormalizedRealmName() return "Realm" end
C_Map = { GetBestMapForUnit = function() return Mock.mapID end }
C_NamePlate = { GetNamePlates = function()
  local list = {}
  for token in pairs(Mock.units) do
    if token:match("^nameplate") then table.insert(list, { namePlateUnitToken = token }) end
  end
  return list
end }

function IsInGroup() return Mock.inGroup end
function IsInRaid() return Mock.raid end
function GetNumGroupMembers() return Mock.inGroup and (#Mock.groupMembers + 1) or 0 end
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, text, chatType, target)
    table.insert(Mock.sent, { prefix = prefix, text = text, chatType = chatType, target = target })
    return 0
  end,
  InChatMessagingLockdown = function() return Mock.lockdown end,
}

-- Taxi map
Mock.taxiNodes = { { name = "Sturmwind", type = "CURRENT" }, { name = "Seenhain", type = "REACHABLE" } }
function NumTaxiNodes() return #Mock.taxiNodes end
function TaxiNodeGetType(i) return Mock.taxiNodes[i].type end
function TaxiNodeName(i) return Mock.taxiNodes[i].name end
function TakeTaxiNode(i) end
function hooksecurefunc(name, fn)
  local orig = _G[name]
  _G[name] = function(...) local r = orig(...); fn(...); return r end
end
date = os.date
