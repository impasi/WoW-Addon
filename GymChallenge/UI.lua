local _, GC = ...

local UI = {}
GC.UI = UI

local ROWS = 7
local ROW_H = 36
local RANK_ROWS = 10
local WIN_W = 380

local WHITE = "Interface\\Buttons\\WHITE8x8"
local BACKDROP = {
  bgFile = WHITE,
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = false, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- Look & feel
local THEME = {
  bg = { 0.05, 0.06, 0.08, 0.94 },
  border = { 0.30, 0.70, 0.50, 0.90 },
  titleBar = { 0.10, 0.32, 0.23, 0.95 },
  rowA = { 1, 1, 1, 0.06 },
  rowB = { 1, 1, 1, 0.025 },
  own = { 0.20, 0.80, 0.50, 0.14 },
}
local ICON_MAIN = "Interface\\Icons\\Spell_Nature_Strength"

-- Icon + accent color per exercise kind.
local KIND_STYLE = {
  squats  = { icon = "Interface\\Icons\\Ability_Rogue_Sprint",            color = { 0.95, 0.65, 0.20 } },
  pushups = { icon = "Interface\\Icons\\Spell_Holy_SealOfMight",          color = { 0.95, 0.85, 0.35 } },
  burpees = { icon = "Interface\\Icons\\Ability_Warrior_Charge",          color = { 0.90, 0.35, 0.30 } },
  situps  = { icon = "Interface\\Icons\\Ability_Rogue_FeignDeath",        color = { 0.55, 0.70, 0.95 } },
  plank   = { icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance", color = { 0.45, 0.85, 0.55 } },
  flight  = { icon = "Interface\\Icons\\Ability_Druid_FlightForm",        color = { 0.40, 0.75, 0.95 } },
}
UI.KIND_STYLE = KIND_STYLE

local function styleBackdrop(f, alpha)
  f:SetBackdrop(BACKDROP)
  f:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], alpha or THEME.bg[4])
  if f.SetBackdropBorderColor then f:SetBackdropBorderColor(unpack(THEME.border)) end
end

-- Width/height of a frame, with a fallback while the size is not known yet.
local function frameW(f, default)
  local w = f.GetWidth and f:GetWidth()
  return (w and w > 0) and w or default
end
local function frameH(f, default)
  local h = f.GetHeight and f:GetHeight()
  return (h and h > 0) and h or default
end
UI.frameW, UI.frameH = frameW, frameH

local function savePosition(f, posKey)
  local point, _, relPoint, x, y = f:GetPoint()
  if point then GC.db[posKey] = { point = point, relPoint = relPoint, x = x, y = y } end
end

-- opts (optional): { minW, minH, onResize = function(frame) } makes the window
-- resizable with a grip in the bottom right corner. The size is saved.
local function makeWindow(name, w, h, posKey, opts)
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  local size = opts and GC.db[posKey .. "Size"]
  if size and size.w and size.h then
    w = math.max(opts.minW, size.w)
    h = math.max(opts.minH, size.h)
  end
  f:SetSize(w, h)
  styleBackdrop(f)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition(self, posKey)
  end)
  local pos = GC.db[posKey]
  if pos then
    f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
  else
    f:SetPoint("CENTER")
  end
  local bar = f:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", 4, -4)
  bar:SetPoint("TOPRIGHT", -4, -4)
  bar:SetHeight(24)
  bar:SetColorTexture(unpack(THEME.titleBar))
  f.titleBar = bar
  local icon = f:CreateTexture(nil, "OVERLAY")
  icon:SetSize(18, 18)
  icon:SetPoint("TOPLEFT", 9, -7)
  icon:SetTexture(ICON_MAIN)
  if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  f.titleIcon = icon
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)

  if opts then
    f:SetResizable(true)
    if f.SetResizeBounds then
      f:SetResizeBounds(opts.minW, opts.minH, 1800, 1400)
    elseif f.SetMinResize then
      f:SetMinResize(opts.minW, opts.minH)
    end
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel((f:GetFrameLevel() or 0) + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(_, button)
      if button == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end
    end)
    grip:SetScript("OnMouseUp", function()
      f:StopMovingOrSizing()
      GC.db[posKey .. "Size"] = { w = frameW(f, w), h = frameH(f, h) }
      savePosition(f, posKey)
      opts.onResize(f)
    end)
    f.grip = grip
    f:SetScript("OnSizeChanged", function() opts.onResize(f) end)
  end
  return f
end

-- Single-line text: never wraps into the next element, cuts off with "..." instead.
local function oneLine(fs, w)
  fs:SetWidth(w)
  fs:SetJustifyH("LEFT")
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  if fs.SetMaxLines then fs:SetMaxLines(1) end
end
UI.oneLine = oneLine

local function makeButton(parent, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b.w = w
  b.minW = w
  b:SetScript("OnClick", onClick)
  return b
end

-- Sets the label and widens the button so the text always fits.
local function setButtonText(b, text)
  b:SetText(text)
  local fs = b.GetFontString and b:GetFontString()
  local tw = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
  b.w = math.max(b.minW or 40, math.ceil(tw) + 24)
  b:SetWidth(b.w)
end
UI.setButtonText = setButtonText

-------------------------------------------------------------------------------
-- Confirmation dialog
-------------------------------------------------------------------------------
local confirm
function UI:Confirm(text, onOk)
  if not confirm then
    confirm = CreateFrame("Frame", "GymChallengeConfirm", UIParent, "BackdropTemplate")
    confirm:SetSize(300, 100)
    styleBackdrop(confirm, 0.97)
    confirm:SetFrameStrata("DIALOG")
    confirm:SetPoint("CENTER", 0, 120)
    confirm:EnableMouse(true)
    confirm.text = confirm:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    confirm.text:SetPoint("TOP", 0, -16)
    confirm.text:SetWidth(270)
    confirm.ok = makeButton(confirm, 100, function()
      confirm:Hide()
      if confirm.onOk then confirm.onOk() end
    end)
    confirm.ok:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 12)
    confirm.cancel = makeButton(confirm, 100, function() confirm:Hide() end)
    confirm.cancel:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 12)
  end
  confirm.text:SetText(text)
  setButtonText(confirm.ok, GC.L("ok"))
  setButtonText(confirm.cancel, GC.L("cancel"))
  confirm.onOk = onOk
  confirm:Show()
end

-------------------------------------------------------------------------------
-- "Save spot": ask whether to save a radius around the position or the whole
-- area (subzone, e.g. "Crossroads").
-------------------------------------------------------------------------------
local choice
function UI:AskSaveSpot()
  if not choice then
    choice = CreateFrame("Frame", "GymChallengeSpotChoice", UIParent, "BackdropTemplate")
    choice:SetSize(340, 120)
    styleBackdrop(choice, 0.97)
    choice:SetFrameStrata("DIALOG")
    choice:SetPoint("CENTER", 0, 120)
    choice:EnableMouse(true)
    choice.text = choice:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    choice.text:SetPoint("TOP", 0, -16)
    choice.text:SetWidth(310)
    choice.radius = makeButton(choice, 100, function()
      choice:Hide()
      GC.Print(GC.Areas.SaveSpot() and GC.L("spot_saved") or GC.L("spot_failed"))
      GC.Areas.Update()
    end)
    choice.radius:SetPoint("BOTTOMLEFT", 14, 40)
    choice.area = makeButton(choice, 100, function()
      choice:Hide()
      local sub = GC.Areas.SaveSubzone()
      GC.Print(sub and GC.L("area_saved", sub) or GC.L("area_failed"))
      GC.Areas.Update()
    end)
    choice.area:SetPoint("BOTTOMRIGHT", -14, 40)
    choice.cancel = makeButton(choice, 100, function() choice:Hide() end)
    choice.cancel:SetPoint("BOTTOM", 0, 12)
  end
  local sub = GC.Areas.CurrentSubzone()
  choice.text:SetText(GC.L("spot_question"))
  setButtonText(choice.radius, GC.L("spot_radius", GC.db.spotRadius or 30))
  if sub then
    setButtonText(choice.area, GC.L("spot_area", sub))
    choice.area:Enable()
  else
    setButtonText(choice.area, GC.L("spot_area_none"))
    choice.area:Disable()
  end
  setButtonText(choice.cancel, GC.L("cancel"))
  choice:Show()
end

-------------------------------------------------------------------------------
-- Main window: to-do list
--   y  -6  title ................................ [DE]  [x]
--   y -32  [Sound: an] [Gebiet: Auto]
--   y -60  area status (1 line)
--   y -74  nameplate warning (1 line)
--   y -90  "Offene Übungen: n"
--   y -106 rows (ROWS x ROW_H)
--   bottom [Liste leeren] [Rangliste] [Ort merken] + note line
-------------------------------------------------------------------------------
local ROWS_TOP = 106
local MAX_ROWS = 25
local MAIN_BOTTOM = 56

local MAIN_MIN_W = 260
local BTN_LINE = 26

-- Places buttons left to right and starts a new line when the next one does
-- not fit. Returns the lines as lists of buttons.
local function flowLines(buttons, W)
  local lines, line, x = {}, {}, 8
  for _, b in ipairs(buttons) do
    local w = b.w or 80
    if #line > 0 and x + w > W - 8 then
      table.insert(lines, line)
      line, x = {}, 8
    end
    table.insert(line, b)
    x = x + w + 4
  end
  if #line > 0 then table.insert(lines, line) end
  return lines
end

-- Positions everything in the main window for its current size. Narrow
-- windows get more button lines instead of overlapping buttons.
local function placeMain(f)
  local W = frameW(f, WIN_W)
  local H = frameH(f, ROWS_TOP + ROWS * ROW_H + MAIN_BOTTOM)

  local top = flowLines({ f.sound, f.mode }, W)
  for li, line in ipairs(top) do
    local x = 8
    for _, b in ipairs(line) do
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", x, -32 - (li - 1) * BTN_LINE)
      x = x + (b.w or 80) + 4
    end
  end
  local statusY = 32 + #top * BTN_LINE + 2
  f.statusDot:ClearAllPoints(); f.statusDot:SetPoint("TOPLEFT", 10, -statusY - 1)
  f.doNow:ClearAllPoints(); f.doNow:SetPoint("TOPRIGHT", -8, -statusY + 4)
  f.status:ClearAllPoints(); f.status:SetPoint("TOPLEFT", 22, -statusY)
  f.warn:ClearAllPoints();   f.warn:SetPoint("TOPLEFT", 10, -statusY - 14)
  f.count:ClearAllPoints();  f.count:SetPoint("TOPLEFT", 10, -statusY - 30)
  local rowsTop = statusY + 46

  local bottom = flowLines({ f.clear, f.rank, f.history, f.spot, f.options }, W - 16) -- keep clear of the grip
  for li, line in ipairs(bottom) do
    local x = 8
    for _, b in ipairs(line) do
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", x, 24 + (#bottom - li) * BTN_LINE)
      x = x + (b.w or 80) + 4
    end
  end
  local bottomH = 24 + #bottom * BTN_LINE + 6

  f.visibleRows = math.max(1, math.min(MAX_ROWS, math.floor((H - rowsTop - bottomH) / ROW_H)))
  f.topLines, f.bottomLines = #top, #bottom
  for i, r in ipairs(f.rows) do
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 8, -rowsTop - (i - 1) * ROW_H)
    r:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  end
end
UI.placeMain = placeMain

local function layoutMain(f)
  if not f.status then return end
  local W = frameW(f, WIN_W)
  for _, fs in ipairs({ f.warn, f.count, f.note }) do fs:SetWidth(W - 20) end
  f.status:SetWidth(W - 32)
  if f.rows then UI:Refresh() end
end

function UI:Init()
  local f = makeWindow("GymChallengeFrame", WIN_W, ROWS_TOP + ROWS * ROW_H + MAIN_BOTTOM, "window",
    { minW = MAIN_MIN_W, minH = ROWS_TOP + 2 * ROW_H + MAIN_BOTTOM, onResize = layoutMain })
  self.frame = f
  f.visibleRows = ROWS

  f.lang = makeButton(f, 36, function()
    GC.db.lang = (GC.GetLang() == "de") and "en" or "de"
    UI:Refresh(); UI:RefreshRank()
  end)
  f.lang:SetPoint("TOPRIGHT", -30, -6)

  f.sound = makeButton(f, 80, function()
    GC.db.sound = not GC.db.sound
    UI:Refresh()
  end)
  f.sound:SetPoint("TOPLEFT", 8, -32)

  f.mode = makeButton(f, 110, function() GC.Areas.CycleMode() end)
  f.mode:SetPoint("LEFT", f.sound, "RIGHT", 4, 0)

  -- "Do now": take the collected crowded-area push-ups before leaving the area.
  f.doNow = makeButton(f, 60, function()
    GC.Paladins.FlushCrowded(true)
    UI:Refresh()
  end)
  f.doNow:SetHeight(18)
  f.doNow:Hide()
  f.statusDot = f:CreateTexture(nil, "OVERLAY")
  f.statusDot:SetSize(8, 8)
  f.statusDot:SetTexture(WHITE)
  f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.status:SetPoint("TOPLEFT", 10, -60)
  oneLine(f.status, WIN_W - 20)

  f.warn = f:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
  f.warn:SetPoint("TOPLEFT", 10, -74)
  oneLine(f.warn, WIN_W - 20)

  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.count:SetPoint("TOPLEFT", 10, -90)
  oneLine(f.count, WIN_W - 20)

  f.offset = 0
  f.rows = {}
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetHeight(ROW_H - 2)
    r:SetPoint("TOPLEFT", 8, -ROWS_TOP - (i - 1) * ROW_H)
    r:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(unpack((i % 2 == 0) and THEME.rowB or THEME.rowA))
    r.accent = r:CreateTexture(nil, "ARTWORK")
    r.accent:SetPoint("TOPLEFT"); r.accent:SetPoint("BOTTOMLEFT")
    r.accent:SetWidth(3)
    r.accent:SetTexture(WHITE)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(26, 26)
    r.icon:SetPoint("LEFT", 7, 0)
    if r.icon.SetTexCoord then r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    r.progress = CreateFrame("StatusBar", nil, r)
    r.progress:SetPoint("BOTTOMLEFT", 3, 0)
    r.progress:SetPoint("BOTTOMRIGHT", 0, 0)
    r.progress:SetHeight(3)
    r.progress:SetStatusBarTexture(WHITE)
    r.progress:Hide()
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("TOPLEFT", 39, -4)
    oneLine(r.text, 200)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.sub:SetPoint("BOTTOMLEFT", 39, 5)
    oneLine(r.sub, 200)
    r.b1 = makeButton(r, 44, function() if r.onB1 then r.onB1() end end)
    r.b1:SetPoint("RIGHT", -4, 0)
    r.b2 = makeButton(r, 44, function() if r.onB2 then r.onB2() end end)
    r.b2:SetPoint("RIGHT", r.b1, "LEFT", -3, 0)
    f.rows[i] = r
  end
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta)
    local max = math.max(0, #GC.cdb.tasks - f.visibleRows)
    f.offset = math.min(max, math.max(0, f.offset - delta))
    UI:Refresh()
  end)

  f.clear = makeButton(f, 70, function()
    UI:Confirm(GC.L("confirm_clear"), function() GC.ClearTasks() end)
  end)
  f.clear:SetPoint("BOTTOMLEFT", 8, 24)
  f.rank = makeButton(f, 70, function() UI:ToggleRank() end)
  f.rank:SetPoint("LEFT", f.clear, "RIGHT", 4, 0)
  f.spot = makeButton(f, 70, function() UI:AskSaveSpot() end)
  f.history = makeButton(f, 60, function() UI:ToggleHistory() end)
  f.options = makeButton(f, 60, function() UI:ToggleOptions() end)
  f.history:SetPoint("LEFT", f.rank, "RIGHT", 4, 0)
  f.spot:SetPoint("LEFT", f.history, "RIGHT", 4, 0)

  f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.note:SetPoint("BOTTOMLEFT", 10, 8)
  oneLine(f.note, WIN_W - 20)

  GC.OnTick(function() if f:IsShown() then UI:Refresh() end end)
  self:InitFlightTimer()
  layoutMain(f)
  self:Refresh()
end

-------------------------------------------------------------------------------
-- Large flight timer: visible during the whole flight (even when the main
-- window is closed) and for a few seconds after landing.
-------------------------------------------------------------------------------
local LANDED_SHOW_SECONDS = 15

function UI:InitFlightTimer()
  local t = CreateFrame("Frame", "GymChallengeFlightTimer", UIParent, "BackdropTemplate")
  t:SetSize(320, 50)
  styleBackdrop(t, 0.85)
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
  t.icon = t:CreateTexture(nil, "ARTWORK")
  t.icon:SetSize(30, 30)
  t.icon:SetPoint("LEFT", 10, 2)
  t.icon:SetTexture(KIND_STYLE.flight.icon)
  if t.icon.SetTexCoord then t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t.text:SetPoint("LEFT", t.icon, "RIGHT", 10, 0)
  t.bar = CreateFrame("StatusBar", nil, t)
  t.bar:SetPoint("BOTTOMLEFT", 5, 5)
  t.bar:SetPoint("BOTTOMRIGHT", -5, 5)
  t.bar:SetHeight(4)
  t.bar:SetStatusBarTexture(WHITE)
  t.bar:SetStatusBarColor(0.40, 0.75, 0.95, 0.95)
  t.bar:Hide()
  if t.text.SetWordWrap then t.text:SetWordWrap(false) end
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

local function setTimerText(t, text)
  t.text:SetText(text)
  local tw = t.text.GetStringWidth and t.text:GetStringWidth() or 0
  t:SetWidth(math.max(240, math.ceil(tw) + 70))
end

function UI:RefreshFlightTimer()
  local t = self.flightTimer
  if not t then return end
  if GC.Events and GC.Events.IsFlying() then
    local elapsed = time() - GC.cdb.flight.start
    local expected = GC.Events.ExpectedDuration()
    if expected then
      local key = (GC.cdb.flight.mode == "flightplank" or not GC.cdb.flight.mode) and "flight_timer_known" or "flight_timer_known_plain"
      setTimerText(t, GC.L(key, GC.FormatDuration(expected),
        GC.FormatDuration(math.max(0, expected - elapsed))))
      t.bar:SetMinMaxValues(0, math.max(1, expected))
      t.bar:SetValue(math.min(expected, elapsed))
      t.bar:Show()
    else
      setTimerText(t, GC.L("flight_timer_unknown", GC.FormatDuration(elapsed)))
      t.bar:Hide()
    end
    t:Show()
  elseif self.landedUntil and time() < self.landedUntil then
    setTimerText(t, "|cff33ff33" .. GC.L("flight_landed", GC.FormatDuration(self.landedDuration)) .. "|r")
    t.bar:Hide()
    t:Show()
  else
    t:Hide()
  end
end

function UI:RefreshStatus()
  local f = self.frame
  if not f then return end
  local showDoNow = false
  if GC.Events and GC.Events.IsFlying() then
    local expected = GC.Events.ExpectedDuration()
    f.status:SetText(GC.L("area_flying", expected and GC.FormatDuration(expected) or GC.L("flight_unknown")))
    f.statusDot:SetVertexColor(0.40, 0.75, 0.95)
  elseif GC.Areas.IsCrowded() then
    f.status:SetText(GC.L("area_crowded", GC.L(GC.Areas.reason or "reason_manual"), GC.cdb.crowded.count))
    showDoNow = (GC.cdb.crowded.count or 0) > 0
    f.statusDot:SetVertexColor(1.00, 0.60, 0.15)
  else
    f.status:SetText(GC.L("area_uncrowded"))
    f.statusDot:SetVertexColor(0.30, 0.85, 0.45)
  end
  f.warn:SetText(GC.Paladins.NameplatesEnabled() and "" or GC.L("warn_nameplates"))
  local W = frameW(f, WIN_W)
  if showDoNow then
    setButtonText(f.doNow, GC.L("btn_do_now", GC.cdb.crowded.count))
    f.doNow:Show()
    f.status:SetWidth(W - 32 - f.doNow.w - 6)
  else
    f.doNow:Hide()
    f.status:SetWidth(W - 32)
  end
end

local function configureRow(r, task, rowW)
  r.b1:Hide(); r.b2:Hide(); r.onB1 = nil; r.onB2 = nil
  r.progress:Hide()
  local style = KIND_STYLE[task.kind] or KIND_STYLE.squats
  r.icon:SetTexture(style.icon)
  r.accent:SetVertexColor(style.color[1], style.color[2], style.color[3], 1)
  r.progress:SetStatusBarColor(style.color[1], style.color[2], style.color[3], 0.9)
  r.text:SetText(GC.TaskText(task))
  local sub = GC.ReasonText(task)
  local buttonsW = 0

  if task.kind == "flight" then
    local expected = task.state == "running" and GC.Events.ExpectedDuration()
    if expected and expected > 0 then
      r.progress:SetMinMaxValues(0, expected)
      r.progress:SetValue(math.min(expected, time() - task.start))
      r.progress:Show()
    end
    if task.state == "landed" then
      sub = "|cffffd100" .. GC.L("flight_question") .. "|r"
      setButtonText(r.b1, GC.L("btn_no")); r.b1:Show()
      r.onB1 = function() GC.AnswerFlight(task.id, false) end
      setButtonText(r.b2, GC.L("btn_yes")); r.b2:Show()
      r.onB2 = function() GC.AnswerFlight(task.id, true) end
      buttonsW = r.b1.w + r.b2.w + 3
    end
  else
    setButtonText(r.b1, GC.L("btn_done")); r.b1:Show()
    r.onB1 = function() GC.CompleteTask(task.id) end
    buttonsW = r.b1.w
    if task.kind == "plank" then
      if task.timerStart then
        local left = task.amount - (time() - task.timerStart)
        r.progress:SetMinMaxValues(0, task.amount)
        r.progress:SetValue(math.min(task.amount, time() - task.timerStart))
        r.progress:Show()
        if left > 0 then
          sub = "|cffffd100" .. GC.L("timer_left", GC.FormatDuration(left)) .. "|r"
        else
          sub = "|cff33ff33" .. GC.L("timer_over") .. "|r"
        end
      else
        setButtonText(r.b2, GC.L("btn_start")); r.b2:Show()
        r.onB2 = function() GC.StartTimer(task.id) end
        buttonsW = buttonsW + r.b2.w + 3
      end
    end
  end
  r.sub:SetText(sub)
  -- Text uses the space left of the buttons, so it never runs under them.
  local textW = rowW - 39 - buttonsW - 8
  r.text:SetWidth(textW)
  r.sub:SetWidth(textW)
end

function UI:Refresh()
  local f = self.frame
  if not f then return end
  local pts = GC.OwnPoints()
  f.title:SetText(GC.L("title") .. "  " .. GC.RankName(GC.RankFor(pts), true) .. " |cffaaaaaa" .. GC.L("points_short", pts) .. "|r")
  setButtonText(f.lang, GC.L("btn_lang"))
  setButtonText(f.sound, GC.db.sound and GC.L("btn_sound_on") or GC.L("btn_sound_off"))
  setButtonText(f.mode, GC.L("crowded_mode_" .. (GC.db.crowdedMode or "auto")))
  setButtonText(f.clear, GC.L("btn_clear"))
  setButtonText(f.rank, GC.L("btn_rank"))
  setButtonText(f.history, GC.L("btn_history"))
  setButtonText(f.options, GC.L("btn_options"))
  setButtonText(f.spot, GC.L("btn_spot"))
  f.note:SetText(GC.L("assigned_note"))
  placeMain(f)

  local tasks = GC.cdb.tasks
  local visible = f.visibleRows or ROWS
  local max = math.max(0, #tasks - visible)
  if f.offset > max then f.offset = max end
  f.count:SetText(#tasks > 0 and GC.L("open_tasks", #tasks) or GC.L("no_tasks"))
  local rowW = frameW(f, WIN_W) - 16
  for i = 1, MAX_ROWS do
    local r = f.rows[i]
    local task = i <= visible and tasks[i + f.offset]
    if task then
      configureRow(r, task, rowW)
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

-- One column per exercise. Click a header to sort by that column.
local RANK_COLUMNS = {
  { key = "name",    head = "rank_header",  w = 150, sortable = true },
  { key = "rank",    head = "col_rank",     w = 86, value = function(e) return GC.CalcPoints(e) end,
    text = function(e) return GC.RankName(GC.RankFor(GC.CalcPoints(e)), true) end },
  { key = "points",  head = "col_points",   w = 64, value = function(e) return GC.CalcPoints(e) end },
  { key = "squats",  head = "col_squats",   w = 58, value = function(e) return e.squats end },
  { key = "pushups", head = "col_pushups",  w = 70, value = function(e) return e.pushups end },
  { key = "burpees", head = "col_burpees",  w = 64, value = function(e) return e.burpees end },
  { key = "situps",  head = "col_situps",   w = 58, value = function(e) return e.situps end },
  { key = "plank",   head = "col_plank",    w = 56, value = function(e) return e.plank end,
    text = function(e) return GC.FormatDuration(e.plank) end },
  { key = "flights", head = "col_flights",  w = 70, value = function(e) return e.flightsMade end,
    text = function(e) return e.flightsMade .. "/" .. e.flightsFailed end },
  { key = "total",   head = "col_total",    w = 64, value = reps },
  { key = "updated", head = "rank_updated", w = 96, value = function(e) return e.updated or 0 end,
    text = function(e) return GC.FormatAgo(e.updated) end },
}
local RANK_WIDTH = 16
for _, c in ipairs(RANK_COLUMNS) do RANK_WIDTH = RANK_WIDTH + c.w end

local MAX_RANK_ROWS = 40
local RANK_TOP = 72
local RANK_BOTTOM = 40
local NAME_MIN_W = 90

-- Columns keep their width; the name column takes the extra space.
local function layoutRank(f)
  local W = frameW(f, RANK_WIDTH)
  local H = frameH(f, RANK_TOP + RANK_ROWS * 18 + RANK_BOTTOM)
  f.visibleRows = math.max(1, math.min(MAX_RANK_ROWS, math.floor((H - RANK_TOP - RANK_BOTTOM) / 18)))
  local x = 10
  for _, c in ipairs(RANK_COLUMNS) do
    c.cw = c.w
    if c.key == "name" then c.cw = math.max(NAME_MIN_W, c.w + (W - RANK_WIDTH)) end
    c.x = x
    x = x + c.cw
  end
  for _, h in ipairs(f.headers) do
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", h.col.x, -56)
    h:SetSize(h.col.cw, 16)
    h.fs:SetWidth(h.col.cw - 4)
  end
  for _, r in ipairs(f.rows) do
    for _, c in ipairs(RANK_COLUMNS) do
      local fs = r.cells[c.key]
      fs:ClearAllPoints()
      fs:SetPoint("LEFT", c.x - 8, 0)
      fs:SetWidth(c.cw - 6)
    end
  end
  f.note:SetWidth(W - 20)
  f.empty:SetWidth(W - 20)
  UI:RefreshRank()
end

local function columnByKey(key)
  for _, c in ipairs(RANK_COLUMNS) do if c.key == key then return c end end
end

function UI:InitRank()
  local f = makeWindow("GymChallengeRankFrame", RANK_WIDTH, RANK_TOP + RANK_ROWS * 18 + RANK_BOTTOM + 10, "rankWindow",
    { minW = RANK_WIDTH - (RANK_COLUMNS[1].w - NAME_MIN_W), minH = RANK_TOP + 3 * 18 + RANK_BOTTOM,
      onResize = function(fr) if fr.rows then layoutRank(fr) end end })
  self.rankFrame = f
  f.visibleRows = RANK_ROWS
  f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.note:SetPoint("TOPLEFT", 10, -28)
  f.note:SetWidth(RANK_WIDTH - 20)
  f.note:SetJustifyH("LEFT")

  f.headers = {}
  local x = 10
  for _, c in ipairs(RANK_COLUMNS) do
    local h = CreateFrame("Button", nil, f)
    h:SetSize(c.w, 16)
    h:SetPoint("TOPLEFT", x, -56)
    h.fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.fs:SetPoint("LEFT")
    oneLine(h.fs, c.w - 4)
    h.col = c
    if c.value or c.sortable then
      -- Click: sort by this column; click again: reverse the direction.
      h:SetScript("OnClick", function()
        if GC.db.rankSort == c.key then
          GC.db.rankSortAsc = not GC.db.rankSortAsc
        else
          GC.db.rankSort = c.key
          GC.db.rankSortAsc = (c.key == "name") -- names A-Z, numbers high to low
        end
        UI:RefreshRank()
      end)
    end
    c.x = x
    x = x + c.w
    table.insert(f.headers, h)
  end

  f.rows = {}
  for i = 1, MAX_RANK_ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetHeight(18)
    r:SetPoint("TOPLEFT", 8, -RANK_TOP - (i - 1) * 18)
    r:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    r:EnableMouse(true)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(unpack((i % 2 == 0) and THEME.rowB or THEME.rowA))
    r.stripe = i % 2 == 0
    r.cells = {}
    for _, c in ipairs(RANK_COLUMNS) do
      local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("LEFT", c.x - 8, 0)
      oneLine(fs, c.w - 6)
      r.cells[c.key] = fs
    end
    r:SetScript("OnEnter", function(self)
      if not self.label or not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.label)
      if self.entry then
        local pts = GC.CalcPoints(self.entry)
        local rank, nextRank = GC.RankFor(pts)
        GameTooltip:AddLine(GC.L("rank_points_line", GC.RankName(rank, true), pts), 1, 1, 1)
        if nextRank then
          GameTooltip:AddLine(GC.L("rank_next_line", nextRank.min - pts, GC.RankName(nextRank, true)), 0.8, 0.8, 0.8)
        end
      end
      GameTooltip:AddLine(GC.L("rank_points_info"), 0.6, 0.6, 0.6, true)
      GameTooltip:AddLine(GC.L("rank_note"), 0.6, 0.6, 0.6, true)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f.rows[i] = r
  end

  f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.empty:SetPoint("TOPLEFT", 10, -84)
  oneLine(f.empty, RANK_WIDTH - 20)

  f.comm = makeButton(f, 90, function() GC.Comm:SetEnabled(not GC.db.comm) end)
  f.comm:SetPoint("BOTTOMLEFT", 8, 10)
  f.reset = makeButton(f, 90, function()
    UI:Confirm(GC.L("confirm_reset_rank"), function() GC.Comm:ResetLeaderboard() end)
  end)
  f.reset:SetPoint("BOTTOMRIGHT", -24, 10)
  f.load = makeButton(f, 90, function()
    local _, key = GC.Comm:RequestStats()
    GC.Print(GC.L(key))
  end)
  f.load:SetPoint("LEFT", f.comm, "RIGHT", 6, 0)
  f:Hide()
  layoutRank(f)
end

function UI:RefreshRank()
  local f = self.rankFrame
  if not f or not f:IsShown() then return end
  f.title:SetText(GC.L("rank_title"))
  f.note:SetText(GC.L("rank_note"))
  local sortCol = columnByKey(GC.db.rankSort or "points") or columnByKey("points")
  local asc = GC.db.rankSortAsc and true or false
  for _, h in ipairs(f.headers) do
    local label = GC.L(h.col.head)
    if h.col == sortCol then label = label .. (asc and " ^" or " v") end
    h.fs:SetText(label)
  end
  setButtonText(f.comm, GC.db.comm and GC.L("rank_comm_on") or GC.L("rank_comm_off"))
  setButtonText(f.reset, GC.L("rank_reset"))
  setButtonText(f.load, GC.L("btn_load"))

  local own = {}
  for k, v in pairs(GC.cdb.stats) do own[k] = v end
  own.updated = GC.cdb.updated
  local list = { { label = GC.L("rank_you", UnitName("player")), entry = own, self = true } }
  local others = 0
  for name, e in pairs(GC.db.leaderboard) do
    -- Show the character name without "-Realm" (the full name stays the key).
    table.insert(list, { label = (name:match("^([^%-]+)") or name), entry = e })
    others = others + 1
  end
  table.sort(list, function(a, b)
    local va, vb
    if sortCol.key == "name" then
      va, vb = a.label:lower(), b.label:lower()
    else
      va, vb = sortCol.value(a.entry), sortCol.value(b.entry)
    end
    if va ~= vb then
      if asc then return va < vb end
      return va > vb
    end
    return a.label < b.label
  end)

  local visible = f.visibleRows or RANK_ROWS
  for i = 1, MAX_RANK_ROWS do
    local r, item = f.rows[i], (i <= visible) and list[i] or nil
    if item then
      local e = item.entry
      r.label = item.label
      r.entry = e
      local color = item.self and "|cff33ff99" or "|cffffffff"
      local medal = ({ "|cffffd700", "|cffd0d0d0", "|cffcd7f32" })[i] or "|cff888888"
      r.bg:SetColorTexture(unpack(item.self and THEME.own or (r.stripe and THEME.rowB or THEME.rowA)))
      for _, c in ipairs(RANK_COLUMNS) do
        local text
        if c.key == "name" then
          text = medal .. i .. ".|r " .. color .. item.label .. "|r"
        elseif c.text then
          text = c.text(e)
        else
          text = tostring(c.value(e))
        end
        r.cells[c.key]:SetText(text)
      end
      r:Show()
    else
      r:Hide()
    end
  end
  f.empty:SetText(others == 0 and GC.L("rank_empty") or "")
  f.empty:ClearAllPoints()
  f.empty:SetPoint("TOPLEFT", 10, -RANK_TOP - 2 - math.min(#list, visible) * 18)
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
-- History window: all assigned exercises, newest first, each deletable.
-------------------------------------------------------------------------------
local HIST_ROWS = 14
local HIST_COLUMNS = {
  { key = "time",   head = "hist_col_time",   w = 90 },
  { key = "ex",     head = "hist_col_ex",     w = 140 },
  { key = "reason", head = "hist_col_reason", w = 170 },
  { key = "status", head = "hist_col_status", w = 100 },
}
local HIST_WIDTH = 16 + 30
for _, c in ipairs(HIST_COLUMNS) do HIST_WIDTH = HIST_WIDTH + c.w end

local STATUS_COLOR = { open = "|cffffd100", done = "|cff33ff33", made = "|cff33ff33",
  failed = "|cffff5555", cleared = "|cff999999", landed = "|cffffd100" }

local MAX_HIST_ROWS = 60
local HIST_TOP = 66
local HIST_BOTTOM = 40
local REASON_MIN_W = 110

-- The reason column takes the extra width.
local function layoutHistory(f)
  local W = frameW(f, HIST_WIDTH)
  local H = frameH(f, HIST_TOP + HIST_ROWS * 18 + HIST_BOTTOM)
  f.visibleRows = math.max(1, math.min(MAX_HIST_ROWS, math.floor((H - HIST_TOP - HIST_BOTTOM) / 18)))
  local x = 10
  for _, c in ipairs(HIST_COLUMNS) do
    c.cw = c.w
    if c.key == "reason" then c.cw = math.max(REASON_MIN_W, c.w + (W - HIST_WIDTH)) end
    c.x = x
    x = x + c.cw
  end
  for i, h in ipairs(f.headers) do
    local c = HIST_COLUMNS[i]
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", c.x, -50)
    h:SetWidth(c.cw - 4)
  end
  for _, r in ipairs(f.rows) do
    for _, c in ipairs(HIST_COLUMNS) do
      local fs = r.cells[c.key]
      fs:ClearAllPoints()
      fs:SetPoint("LEFT", c.x - 8, 0)
      fs:SetWidth(c.cw - 6)
    end
  end
  f.note:SetWidth(W - 20)
  f.empty:SetWidth(W - 20)
  UI:RefreshHistory()
end

local function historyExerciseText(e)
  if e.kind == "flight" then return GC.L("ex_flight_done", GC.FormatDuration(e.amount)) end
  return GC.L("ex_" .. e.kind, e.amount)
end

function UI:InitHistory()
  local f = makeWindow("GymChallengeHistoryFrame", HIST_WIDTH, HIST_TOP + HIST_ROWS * 18 + HIST_BOTTOM, "historyWindow",
    { minW = HIST_WIDTH - (HIST_COLUMNS[3].w - REASON_MIN_W), minH = HIST_TOP + 3 * 18 + HIST_BOTTOM,
      onResize = function(fr) if fr.rows then layoutHistory(fr) end end })
  self.historyFrame = f
  f.visibleRows = HIST_ROWS
  f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.note:SetPoint("TOPLEFT", 10, -30)
  oneLine(f.note, HIST_WIDTH - 20)

  local x = 10
  f.headers = {}
  for _, c in ipairs(HIST_COLUMNS) do
    local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h:SetPoint("TOPLEFT", x, -50)
    oneLine(h, c.w - 4)
    h.key = c.head
    c.x = x
    x = x + c.w
    table.insert(f.headers, h)
  end

  f.offset = 0
  f.rows = {}
  for i = 1, MAX_HIST_ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetHeight(18)
    r:SetPoint("TOPLEFT", 8, -HIST_TOP - (i - 1) * 18)
    r:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(unpack((i % 2 == 0) and THEME.rowB or THEME.rowA))
    r.stripe = i % 2 == 0
    r.cells = {}
    for _, c in ipairs(HIST_COLUMNS) do
      local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("LEFT", c.x - 8, 0)
      oneLine(fs, c.w - 6)
      r.cells[c.key] = fs
    end
    r.del = makeButton(r, 26, function()
      local e = r.entry
      if not e then return end
      UI:Confirm(GC.L("hist_confirm_delete", historyExerciseText(e), GC.ReasonText(e)),
        function() GC.DeleteHistory(e.id) end)
    end)
    r.del:SetHeight(18)
    r.del:SetPoint("RIGHT", -2, 0)
    f.rows[i] = r
  end
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta)
    local max = math.max(0, #GC.cdb.history - f.visibleRows)
    f.offset = math.min(max, math.max(0, f.offset - delta))
    UI:RefreshHistory()
  end)

  f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.empty:SetPoint("TOPLEFT", 10, -70)
  oneLine(f.empty, HIST_WIDTH - 20)
  f.pos = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.pos:SetPoint("BOTTOMRIGHT", -24, 10)
  f:Hide()
  layoutHistory(f)
end

function UI:RefreshHistory()
  local f = self.historyFrame
  if not f or not f:IsShown() then return end
  f.title:SetText(GC.L("hist_title"))
  f.note:SetText(GC.L("hist_note"))
  for _, h in ipairs(f.headers) do h:SetText(GC.L(h.key)) end

  local h = GC.cdb.history
  local n = #h
  local visible = f.visibleRows or HIST_ROWS
  local max = math.max(0, n - visible)
  if f.offset > max then f.offset = max end
  for i = 1, MAX_HIST_ROWS do
    local r = f.rows[i]
    local e = (i <= visible) and h[n - f.offset - i + 1] or nil -- newest first
    if e then
      r.entry = e
      r.cells.time:SetText(date("%d.%m. %H:%M", e.t))
      r.cells.ex:SetText(historyExerciseText(e))
      r.cells.reason:SetText(GC.ReasonText(e))
      r.cells.status:SetText((STATUS_COLOR[e.status] or "") .. GC.L("st_" .. e.status) .. "|r")
      setButtonText(r.del, GC.L("hist_delete"))
      r:Show()
    else
      r.entry = nil
      r:Hide()
    end
  end
  f.empty:SetText(n == 0 and GC.L("hist_empty") or "")
  f.pos:SetText(n > visible and ((f.offset + 1) .. "-" .. math.min(n, f.offset + visible) .. " / " .. n) or "")
end

function UI:ToggleHistory()
  if not self.historyFrame then self:InitHistory() end
  if self.historyFrame:IsShown() then
    self.historyFrame:Hide()
  else
    self.historyFrame.offset = 0
    self.historyFrame:Show()
    self:RefreshHistory()
  end
end

-------------------------------------------------------------------------------
-- Options window: per challenge on/off, exercise and amount.
-------------------------------------------------------------------------------
local OPT_ROW_H = 30
local OPT_W = 560

local function unitText(key, cfg)
  if cfg.ex == "flightplank" then return "" end
  local u = (cfg.ex == "plank") and GC.L("opt_unit_min") or GC.L("opt_unit_reps")
  if key == "flight" then return u .. " " .. GC.L("opt_per_20s") end
  if key == "paladin_crowded" or key == "paladin_open" then return u .. " " .. GC.L("opt_per_paladin") end
  return u
end

-- Simple own dropdown list (no dependency on the client's menu API).
local dropdown
local DD_ITEM_H = 20

function UI:OpenDropdown(anchor, choices, current, onSelect)
  if not dropdown then
    dropdown = CreateFrame("Frame", "GymChallengeDropdown", UIParent, "BackdropTemplate")
    styleBackdrop(dropdown, 0.98)
    dropdown:SetFrameStrata("FULLSCREEN_DIALOG")
    dropdown:EnableMouse(true)
    dropdown:SetClampedToScreen(true)
    dropdown.items = {}
    -- Close when the mouse leaves the list for a moment.
    dropdown:SetScript("OnUpdate", function(self, elapsed)
      if self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver()) then
        self.away = 0
      else
        self.away = (self.away or 0) + (elapsed or 0)
        if self.away > 1.5 then self:Hide() end
      end
    end)
  end
  if dropdown:IsShown() and dropdown.anchor == anchor then
    dropdown:Hide()
    return
  end
  local width = math.max(160, (anchor.w or 150))
  for i, choice in ipairs(choices) do
    local item = dropdown.items[i]
    if not item then
      item = CreateFrame("Button", nil, dropdown)
      item:SetHeight(DD_ITEM_H)
      item:SetPoint("TOPLEFT", 6, -6 - (i - 1) * DD_ITEM_H)
      item:SetPoint("RIGHT", dropdown, "RIGHT", -6, 0)
      item.hl = item:CreateTexture(nil, "HIGHLIGHT")
      item.hl:SetAllPoints()
      item.hl:SetColorTexture(1, 1, 1, 0.12)
      item.icon = item:CreateTexture(nil, "ARTWORK")
      item.icon:SetSize(16, 16)
      item.icon:SetPoint("LEFT", 2, 0)
      if item.icon.SetTexCoord then item.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
      item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      item.text:SetPoint("LEFT", item.icon, "RIGHT", 6, 0)
      oneLine(item.text, width - 40)
      dropdown.items[i] = item
    end
    local style = KIND_STYLE[choice == "flightplank" and "flight" or choice]
    item.icon:SetTexture(style and style.icon or nil)
    local selected = choice == current
    item.text:SetText((selected and "|cff33ff99" or "") .. GC.L("exn_" .. choice) .. (selected and "|r" or ""))
    item:SetScript("OnClick", function()
      dropdown:Hide()
      onSelect(choice)
    end)
    item.choice = choice
    item:Show()
  end
  for i = #choices + 1, #dropdown.items do dropdown.items[i]:Hide() end
  dropdown:SetSize(width, #choices * DD_ITEM_H + 12)
  dropdown:ClearAllPoints()
  dropdown:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  dropdown.anchor = anchor
  dropdown.away = 0
  dropdown:Show()
end

function UI:InitOptions()
  local n = #GC.CHALLENGE_ORDER
  local f = makeWindow("GymChallengeOptionsFrame", OPT_W, 84 + n * OPT_ROW_H + 50 + 52, "optionsWindow")
  self.optionsFrame = f
  f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.note:SetPoint("TOPLEFT", 12, -34)
  f.note:SetWidth(OPT_W - 24)
  f.note:SetJustifyH("LEFT")

  f.rows = {}
  for i, key in ipairs(GC.CHALLENGE_ORDER) do
    local r = CreateFrame("Frame", nil, f)
    r:SetHeight(OPT_ROW_H - 2)
    r:SetPoint("TOPLEFT", 8, -70 - (i - 1) * OPT_ROW_H)
    r:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    r.key = key
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(unpack((i % 2 == 0) and THEME.rowB or THEME.rowA))

    r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
    r.check:SetSize(24, 24)
    r.check:SetPoint("LEFT", 2, 0)
    r.check:SetScript("OnClick", function()
      local cfg = GC.Challenge(key)
      cfg.enabled = not cfg.enabled
      UI:RefreshOptions()
    end)
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.label:SetPoint("LEFT", r.check, "RIGHT", 4, 0)
    oneLine(r.label, 210)

    r.ex = makeButton(r, 150, function(self)
      local cfg = GC.Challenge(key)
      UI:OpenDropdown(self, GC.ExerciseChoices(key), cfg.ex, function(choice)
        cfg.ex = choice
        UI:RefreshOptions()
      end)
    end)
    r.ex.minW = 150
    r.ex:SetPoint("LEFT", 244, 0)

    local function step(delta)
      local cfg = GC.Challenge(key)
      if IsShiftKeyDown and IsShiftKeyDown() then delta = delta * 10 end
      cfg.amount = math.max(1, math.min(999, (cfg.amount or 1) + delta))
      UI:RefreshOptions()
    end
    r.minus = makeButton(r, 24, function() step(-1) end)
    r.minus:SetPoint("LEFT", 400, 0)
    r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.value:SetPoint("LEFT", r.minus, "RIGHT", 2, 0)
    r.value:SetWidth(34)
    r.value:SetJustifyH("CENTER")
    r.plus = makeButton(r, 24, function() step(1) end)
    r.plus:SetPoint("LEFT", r.value, "RIGHT", 2, 0)
    r.unit = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.unit:SetPoint("LEFT", r.plus, "RIGHT", 6, 0)
    oneLine(r.unit, 90)
    f.rows[i] = r
  end

  -- Shame message toggles (account wide).
  f.shame = {}
  for i, key in ipairs({ "shameSend", "shameReceive" }) do
    local c = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", 10, -70 - n * OPT_ROW_H - 4 - (i - 1) * 24)
    c:SetScript("OnClick", function()
      GC.db[key] = not GC.db[key]
      UI:RefreshOptions()
    end)
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.label:SetPoint("LEFT", c, "RIGHT", 4, 0)
    oneLine(c.label, OPT_W - 60)
    c.key = key
    f.shame[i] = c
  end

  f.reset = makeButton(f, 120, function()
    UI:Confirm(GC.L("opt_confirm_reset"), function() GC.ResetChallenges(); UI:RefreshOptions() end)
  end)
  f.reset:SetPoint("BOTTOMLEFT", 10, 12)
  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.hint:SetPoint("LEFT", f.reset, "RIGHT", 10, 0)
  oneLine(f.hint, OPT_W - 170)
  f:Hide()
end

function UI:RefreshOptions()
  local f = self.optionsFrame
  if not f or not f:IsShown() then return end
  f.title:SetText(GC.L("opt_title"))
  f.note:SetText(GC.L("opt_note"))
  setButtonText(f.reset, GC.L("opt_reset"))
  f.hint:SetText(GC.L("opt_hint"))
  for _, c in ipairs(f.shame) do
    c:SetChecked(GC.db[c.key] and true or false)
    c.label:SetText(GC.L(c.key == "shameSend" and "opt_shame_send" or "opt_shame_receive"))
  end
  for _, r in ipairs(f.rows) do
    local cfg = GC.Challenge(r.key)
    r.check:SetChecked(cfg.enabled and true or false)
    r.label:SetText((cfg.enabled and "" or "|cff888888") .. GC.L("ch_" .. r.key) .. (cfg.enabled and "" or "|r"))
    setButtonText(r.ex, GC.L("exn_" .. cfg.ex) .. "  v")
    local fixed = cfg.ex == "flightplank"
    for _, w in ipairs({ r.minus, r.plus }) do
      if fixed then w:Hide() else w:Show() end
      if cfg.enabled then w:Enable() else w:Disable() end
    end
    if cfg.enabled then r.ex:Enable() else r.ex:Disable() end
    r.value:SetText(fixed and "" or tostring(cfg.amount))
    r.unit:SetText(unitText(r.key, cfg))
  end
end

function UI:ToggleOptions()
  if not self.optionsFrame then self:InitOptions() end
  if self.optionsFrame:IsShown() then
    self.optionsFrame:Hide()
  else
    self.optionsFrame:Show()
    self:RefreshOptions()
  end
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
local TESTS = {
  death = function() GC.Events.OnDeath() end,
  level = function() GC.Events.OnLevelUp((GC.SafeCall(UnitLevel, "player") or 1)) end,
  flightstart = function() GC.Events.StartFlight(nil, true) end,
  flightend = function() GC.Events.EndFlight() end,
  dungeon = function() GC.Assign("dungeon", 1, "r_dungeon") end,
  elite = function() GC.Assign("elite", 1, "r_elite", "Test-Elite") end,
  taxinode = function() GC.Assign("taxinode", 1, "r_taxinode") end,
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
  elseif cmd == "history" then
    UI:ToggleHistory()
  elseif cmd == "options" or cmd == "config" then
    UI:ToggleOptions()
  elseif cmd == "minimap" then
    GC.Minimap:Toggle()
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
    UI:AskSaveSpot()
  elseif cmd == "city" then
    GC.Areas.ToggleCustomCity()
  elseif cmd == "comm" and (arg == "on" or arg == "off") then
    GC.Comm:SetEnabled(arg == "on")
    GC.Print((arg == "on") and GC.L("rank_comm_on") or GC.L("rank_comm_off"))
  elseif cmd == "shame" and (arg == "send" or arg == "receive") then
    local key = (arg == "send") and "shameSend" or "shameReceive"
    GC.db[key] = not GC.db[key]
    GC.Print(GC.L("shame_set", GC.db.shameSend and GC.L("on") or GC.L("off"),
      GC.db.shameReceive and GC.L("on") or GC.L("off")))
    UI:RefreshOptions()
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
