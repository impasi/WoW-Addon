local _, GC = ...

local UI = {}
GC.UI = UI

local ROWS = 7
local ROW_H = 34
local RANK_ROWS = 10

local BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function makeWindow(name, w, h, posKey)
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  f:SetSize(w, h)
  f:SetBackdrop(BACKDROP)
  f:SetBackdropColor(0, 0, 0, 0.85)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    GC.db[posKey] = { point = point, relPoint = relPoint, x = x, y = y }
  end)
  local pos = GC.db[posKey]
  if pos then
    f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
  else
    f:SetPoint("CENTER")
  end
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", 10, -9)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  return f
end

local function makeButton(parent, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 20)
  b:SetScript("OnClick", onClick)
  return b
end

-------------------------------------------------------------------------------
-- Confirmation dialog
-------------------------------------------------------------------------------
local confirm
function UI:Confirm(text, onOk)
  if not confirm then
    confirm = CreateFrame("Frame", "GymChallengeConfirm", UIParent, "BackdropTemplate")
    confirm:SetSize(260, 90)
    confirm:SetBackdrop(BACKDROP)
    confirm:SetBackdropColor(0, 0, 0, 0.95)
    confirm:SetFrameStrata("DIALOG")
    confirm:SetPoint("CENTER", 0, 120)
    confirm:EnableMouse(true)
    confirm.text = confirm:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    confirm.text:SetPoint("TOP", 0, -16)
    confirm.text:SetWidth(230)
    confirm.ok = makeButton(confirm, 100, function()
      confirm:Hide()
      if confirm.onOk then confirm.onOk() end
    end)
    confirm.ok:SetPoint("BOTTOMLEFT", 20, 12)
    confirm.cancel = makeButton(confirm, 100, function() confirm:Hide() end)
    confirm.cancel:SetPoint("BOTTOMRIGHT", -20, 12)
  end
  confirm.text:SetText(text)
  confirm.ok:SetText(GC.L("ok"))
  confirm.cancel:SetText(GC.L("cancel"))
  confirm.onOk = onOk
  confirm:Show()
end

-------------------------------------------------------------------------------
-- Main window: to-do list
-------------------------------------------------------------------------------
function UI:Init()
  local f = makeWindow("GymChallengeFrame", 300, 120 + ROWS * ROW_H, "window")
  self.frame = f

  f.lang = makeButton(f, 40, function()
    GC.db.lang = (GC.GetLang() == "de") and "en" or "de"
    UI:Refresh(); UI:RefreshRank()
  end)
  f.lang:SetPoint("TOPRIGHT", -28, -6)

  f.sound = makeButton(f, 86, function()
    GC.db.sound = not GC.db.sound
    UI:Refresh()
  end)
  f.sound:SetPoint("TOPLEFT", 8, -28)

  f.mode = makeButton(f, 120, function() GC.Areas.CycleMode() end)
  f.mode:SetPoint("LEFT", f.sound, "RIGHT", 4, 0)

  f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.status:SetPoint("TOPLEFT", 10, -54)
  f.status:SetWidth(280)
  f.status:SetJustifyH("LEFT")

  f.warn = f:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
  f.warn:SetPoint("TOPLEFT", f.status, "BOTTOMLEFT", 0, -2)
  f.warn:SetWidth(280)
  f.warn:SetJustifyH("LEFT")

  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.count:SetPoint("TOPLEFT", 10, -84)

  f.offset = 0
  f.rows = {}
  for i = 1, ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(284, ROW_H - 2)
    r:SetPoint("TOPLEFT", 8, -98 - (i - 1) * ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0.08)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("TOPLEFT", 4, -3)
    r.text:SetWidth(170)
    r.text:SetJustifyH("LEFT")
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.sub:SetPoint("BOTTOMLEFT", 4, 3)
    r.sub:SetWidth(170)
    r.sub:SetJustifyH("LEFT")
    r.b1 = makeButton(r, 54, function() if r.onB1 then r.onB1() end end)
    r.b1:SetPoint("RIGHT", -2, 0)
    r.b2 = makeButton(r, 54, function() if r.onB2 then r.onB2() end end)
    r.b2:SetPoint("RIGHT", r.b1, "LEFT", -2, 0)
    f.rows[i] = r
  end
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta)
    local max = math.max(0, #GC.cdb.tasks - ROWS)
    f.offset = math.min(max, math.max(0, f.offset - delta))
    UI:Refresh()
  end)

  f.clear = makeButton(f, 90, function()
    UI:Confirm(GC.L("confirm_clear"), function() GC.ClearTasks() end)
  end)
  f.clear:SetPoint("BOTTOMLEFT", 8, 22)
  f.rank = makeButton(f, 90, function() UI:ToggleRank() end)
  f.rank:SetPoint("LEFT", f.clear, "RIGHT", 4, 0)
  f.spot = makeButton(f, 90, function()
    if GC.Areas.SaveSpot() then
      GC.Print(GC.L("spot_saved"))
      GC.Areas.Update()
    else
      GC.Print(GC.L("spot_failed"))
    end
  end)
  f.spot:SetPoint("LEFT", f.rank, "RIGHT", 4, 0)

  f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.note:SetPoint("BOTTOM", 0, 8)

  GC.OnTick(function() if f:IsShown() then UI:Refresh() end end)
  self:InitFlightTimer()
  self:Refresh()
end

-------------------------------------------------------------------------------
-- Large flight timer: visible during the whole flight (even when the main
-- window is closed) and for a few seconds after landing.
-------------------------------------------------------------------------------
local LANDED_SHOW_SECONDS = 15

function UI:InitFlightTimer()
  local t = CreateFrame("Frame", "GymChallengeFlightTimer", UIParent, "BackdropTemplate")
  t:SetSize(320, 44)
  t:SetBackdrop(BACKDROP)
  t:SetBackdropColor(0, 0, 0, 0.75)
  t:SetFrameStrata("HIGH")
  t:SetClampedToScreen(true)
  t:EnableMouse(true)
  t:SetMovable(true)
  t:RegisterForDrag("LeftButton")
  t:SetScript("OnDragStart", t.StartMoving)
  t:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    GC.db.flightTimerPos = { point = point, relPoint = relPoint, x = x, y = y }
  end)
  local pos = GC.db.flightTimerPos
  if pos then
    t:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
  else
    t:SetPoint("TOP", UIParent, "TOP", 0, -140)
  end
  t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t.text:SetPoint("CENTER")
  t:Hide()
  self.flightTimer = t
  GC.OnTick(function() UI:RefreshFlightTimer() end)
end

-- Called by Events.EndFlight with the measured duration.
function UI:ShowLanded(duration)
  self.landedDuration = duration
  self.landedUntil = time() + LANDED_SHOW_SECONDS
  self:RefreshFlightTimer()
end

function UI:RefreshFlightTimer()
  local t = self.flightTimer
  if not t then return end
  if GC.Events and GC.Events.IsFlying() then
    t.text:SetText(GC.L("flight_timer", GC.FormatDuration(time() - GC.cdb.flight.start)))
    t:Show()
  elseif self.landedUntil and time() < self.landedUntil then
    t.text:SetText("|cff33ff33" .. GC.L("flight_landed", GC.FormatDuration(self.landedDuration)) .. "|r")
    t:Show()
  else
    t:Hide()
  end
end

function UI:RefreshStatus()
  local f = self.frame
  if not f then return end
  if GC.Events and GC.Events.IsFlying() then
    f.status:SetText(GC.L("area_flying", GC.FormatDuration(time() - GC.cdb.flight.start)))
  elseif GC.Areas.IsCrowded() then
    f.status:SetText(GC.L("area_crowded", GC.L(GC.Areas.reason or "reason_manual"), GC.cdb.crowded.count))
  else
    f.status:SetText(GC.L("area_uncrowded"))
  end
  f.warn:SetText(GC.Paladins.NameplatesEnabled() and "" or GC.L("warn_nameplates"))
end

local function configureRow(r, task)
  r.b1:Hide(); r.b2:Hide(); r.onB1 = nil; r.onB2 = nil
  r.text:SetText(GC.TaskText(task))
  local sub = GC.ReasonText(task)

  if task.kind == "flight" then
    if task.state == "landed" then
      sub = GC.L("flight_question")
      r.b1:SetText(GC.L("btn_no")); r.b1:Show()
      r.onB1 = function() GC.AnswerFlight(task.id, false) end
      r.b2:SetText(GC.L("btn_yes")); r.b2:Show()
      r.onB2 = function() GC.AnswerFlight(task.id, true) end
    end
  else
    r.b1:SetText(GC.L("btn_done")); r.b1:Show()
    r.onB1 = function() GC.CompleteTask(task.id) end
    if task.kind == "plank" then
      if task.timerStart then
        local left = task.amount - (time() - task.timerStart)
        if left > 0 then
          r.text:SetText(GC.TaskText(task) .. " – |cffffd100" .. GC.L("timer_left", GC.FormatDuration(left)) .. "|r")
        else
          r.text:SetText(GC.TaskText(task) .. " – |cff33ff33" .. GC.L("timer_over") .. "|r")
        end
      else
        r.b2:SetText(GC.L("btn_start")); r.b2:Show()
        r.onB2 = function() GC.StartTimer(task.id) end
      end
    end
  end
  r.sub:SetText(sub)
end

function UI:Refresh()
  local f = self.frame
  if not f then return end
  f.title:SetText(GC.L("title"))
  f.lang:SetText(GC.L("btn_lang"))
  f.sound:SetText(GC.db.sound and GC.L("btn_sound_on") or GC.L("btn_sound_off"))
  f.mode:SetText(GC.L("crowded_mode_" .. (GC.db.crowdedMode or "auto")))
  f.clear:SetText(GC.L("btn_clear"))
  f.rank:SetText(GC.L("btn_rank"))
  f.spot:SetText(GC.L("btn_spot"))
  f.note:SetText(GC.L("assigned_note"))

  local tasks = GC.cdb.tasks
  local max = math.max(0, #tasks - ROWS)
  if f.offset > max then f.offset = max end
  f.count:SetText(#tasks > 0 and GC.L("open_tasks", #tasks) or GC.L("no_tasks"))
  for i = 1, ROWS do
    local r = f.rows[i]
    local task = tasks[i + f.offset]
    if task then
      configureRow(r, task)
      r:Show()
    else
      r:Hide()
    end
  end
  self:RefreshStatus()
end

function UI:Toggle()
  if not self.frame then return end
  if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:Refresh() end
end

-------------------------------------------------------------------------------
-- Ranking window
-------------------------------------------------------------------------------
local function reps(e) return e.squats + e.pushups + e.burpees + e.situps end

function UI:InitRank()
  local f = makeWindow("GymChallengeRankFrame", 340, 90 + RANK_ROWS * 18 + 40, "rankWindow")
  self.rankFrame = f
  f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.note:SetPoint("TOPLEFT", 10, -28)
  f.note:SetWidth(320)
  f.note:SetJustifyH("LEFT")

  local function header(x, key)
    local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h:SetPoint("TOPLEFT", x, -48)
    h.key = key
    return h
  end
  f.headers = { header(10, "rank_header"), header(170, "rank_reps"), header(210, "rank_plank"), header(260, "rank_updated") }

  f.rows = {}
  for i = 1, RANK_ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(320, 18)
    r:SetPoint("TOPLEFT", 8, -62 - (i - 1) * 18)
    r:EnableMouse(true)
    local function col(x, w)
      local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("LEFT", x, 0)
      fs:SetWidth(w)
      fs:SetJustifyH("LEFT")
      return fs
    end
    r.name, r.reps, r.plank, r.updated = col(2, 158), col(162, 40), col(202, 50), col(252, 70)
    r:SetScript("OnEnter", function(self)
      if not self.entry or not GameTooltip then return end
      local e = self.entry
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.label)
      GameTooltip:AddLine(GC.L("rank_tooltip", e.squats, e.pushups, e.burpees, e.situps,
        GC.FormatDuration(e.plank), e.flightsMade, e.flightsFailed), 1, 1, 1, true)
      GameTooltip:AddLine(GC.L("rank_note"), 0.6, 0.6, 0.6, true)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f.rows[i] = r
  end

  f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.empty:SetPoint("TOPLEFT", 10, -84)

  f.comm = makeButton(f, 120, function() GC.Comm:SetEnabled(not GC.db.comm) end)
  f.comm:SetPoint("BOTTOMLEFT", 8, 10)
  f.reset = makeButton(f, 120, function()
    UI:Confirm(GC.L("confirm_reset_rank"), function() GC.Comm:ResetLeaderboard() end)
  end)
  f.reset:SetPoint("BOTTOMRIGHT", -8, 10)
  f:Hide()
end

function UI:RefreshRank()
  local f = self.rankFrame
  if not f or not f:IsShown() then return end
  f.title:SetText(GC.L("rank_title"))
  f.note:SetText(GC.L("rank_note"))
  for _, h in ipairs(f.headers) do h:SetText(GC.L(h.key)) end
  f.comm:SetText(GC.db.comm and GC.L("rank_comm_on") or GC.L("rank_comm_off"))
  f.reset:SetText(GC.L("rank_reset"))

  local own = {}
  for k, v in pairs(GC.cdb.stats) do own[k] = v end
  own.updated = GC.cdb.updated
  local list = { { label = GC.L("rank_you", UnitName("player")), entry = own, self = true } }
  local others = 0
  for name, e in pairs(GC.db.leaderboard) do
    table.insert(list, { label = name, entry = e })
    others = others + 1
  end
  table.sort(list, function(a, b) return reps(a.entry) > reps(b.entry) end)

  for i = 1, RANK_ROWS do
    local r, item = f.rows[i], list[i]
    if item then
      local e = item.entry
      r.entry, r.label = e, item.label
      local color = item.self and "|cff33ff99" or "|cffffffff"
      r.name:SetText(color .. i .. ". " .. item.label .. "|r")
      r.reps:SetText(reps(e))
      r.plank:SetText(GC.FormatDuration(e.plank))
      r.updated:SetText(GC.FormatAgo(e.updated))
      r:Show()
    else
      r:Hide()
    end
  end
  f.empty:SetText(others == 0 and GC.L("rank_empty") or "")
  f.empty:ClearAllPoints()
  f.empty:SetPoint("TOPLEFT", 10, -64 - math.min(#list, RANK_ROWS) * 18)
end

function UI:ToggleRank()
  if not self.rankFrame then self:InitRank() end
  if self.rankFrame:IsShown() then
    self.rankFrame:Hide()
  else
    self.rankFrame:Show()
    self:RefreshRank()
  end
end

GC.OnTick(function() UI:RefreshRank() end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
local TESTS = {
  death = function() GC.Events.OnDeath() end,
  level = function() GC.Events.OnLevelUp((GC.SafeCall(UnitLevel, "player") or 1)) end,
  flightstart = function() GC.Events.StartFlight(nil, true) end,
  flightend = function() GC.Events.EndFlight() end,
  dungeon = function() GC.AddTask("situps", 20, "r_dungeon") end,
  elite = function() GC.AddTask("plank", 20, "r_elite", "Test-Elite") end,
  taxinode = function() GC.AddTask("squats", 15, "r_taxinode") end,
  paladin = function() GC.Paladins.Count("Testpaladin-" .. math.random(1000, 9999)) end,
}

SLASH_GYMCHALLENGE1 = "/gym"
SLASH_GYMCHALLENGE2 = "/gymchallenge"
SlashCmdList["GYMCHALLENGE"] = function(input)
  local cmd, arg = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if cmd == "" then
    UI:Toggle()
  elseif cmd == "rank" then
    UI:ToggleRank()
  elseif cmd == "lang" and (arg == "de" or arg == "en") then
    GC.db.lang = arg
    GC.Print(GC.L("lang_set"))
    UI:Refresh(); UI:RefreshRank()
  elseif cmd == "sound" then
    GC.db.sound = not GC.db.sound
    GC.Print(GC.L("sound_set", GC.db.sound and GC.L("on") or GC.L("off")))
    UI:Refresh()
  elseif cmd == "crowded" and (arg == "auto" or arg == "on" or arg == "off") then
    GC.Areas.SetMode(arg)
  elseif cmd == "spot" then
    GC.Print(GC.Areas.SaveSpot() and GC.L("spot_saved") or GC.L("spot_failed"))
    GC.Areas.Update()
  elseif cmd == "city" then
    GC.Areas.ToggleCustomCity()
  elseif cmd == "comm" and (arg == "on" or arg == "off") then
    GC.Comm:SetEnabled(arg == "on")
    GC.Print((arg == "on") and GC.L("rank_comm_on") or GC.L("rank_comm_off"))
  elseif cmd == "resetrank" then
    UI:Confirm(GC.L("confirm_reset_rank"), function() GC.Comm:ResetLeaderboard() end)
  elseif cmd == "resetstats" then
    UI:Confirm(GC.L("confirm_reset_stats"), function() GC.ResetOwnStats() end)
  elseif cmd == "status" then
    local mapID = C_Map and GC.SafeCall(C_Map.GetBestMapForUnit, "player")
    GC.Print(("zone=%s subzone=%s mapID=%s crowded=%s instance=%s nameplates=%s spots=%d"):format(
      tostring(GC.SafeCall(GetRealZoneText)), tostring(GC.SafeCall(GetSubZoneText)), tostring(mapID),
      tostring(GC.Areas.IsCrowded()), tostring(GC.Events.InAnyInstance()),
      tostring(GC.Paladins.NameplatesEnabled()), #GC.db.spots))
  elseif cmd == "debug" then
    GC.debug = not GC.debug
    GC.Print("debug " .. tostring(GC.debug))
  elseif cmd == "test" and TESTS[arg] then
    TESTS[arg]()
    GC.Print(GC.L("test_done", arg))
  else
    GC.Print(GC.L("help"))
  end
end
