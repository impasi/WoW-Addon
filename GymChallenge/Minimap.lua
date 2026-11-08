local _, GC = ...

-- Minimap button, so minimap-button collectors (e.g. Good Addons,
-- MinimapButtonButton) can group it.
--  * If another addon already loaded LibDataBroker-1.1 + LibDBIcon-1.0 (most
--    collectors and many addons do), the button is registered there. That is
--    the standard way collectors find buttons.
--  * Otherwise the addon creates its own round button on the minimap.
-- Left click: to-do window. Right click: ranking. Shift + left click: history.
local Minimap_ = {}
GC.Minimap = Minimap_

local ICON = "Interface\\Icons\\Spell_Nature_Strength"
local NAME = "GymChallenge"

local function onClick(button)
  if button == "RightButton" then
    GC.UI:ToggleRank()
  elseif IsShiftKeyDown and IsShiftKeyDown() then
    GC.UI:ToggleHistory()
  else
    GC.UI:Toggle()
  end
end

local function fillTooltip(tt)
  tt:AddLine(GC.L("title"))
  tt:AddLine(GC.L("open_tasks", #GC.cdb.tasks), 1, 1, 1)
  tt:AddLine(GC.L("minimap_hint"), 0.7, 0.7, 0.7, true)
end

-- Own button (fallback without LibDBIcon) -------------------------------------
local function updatePosition(b)
  local angle = math.rad(GC.db.minimap.minimapPos or 220)
  local r = (Minimap:GetWidth() or 140) / 2 + 5
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function createOwnButton()
  local b = CreateFrame("Button", "GymChallengeMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture(ICON)
  icon:SetPoint("TOPLEFT", 7, -6)
  b.icon = icon
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  b:SetScript("OnClick", function(_, button) onClick(button) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    fillTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      px, py = px / scale, py / scale
      GC.db.minimap.minimapPos = math.deg(math.atan2(py - my, px - mx)) % 360
      updatePosition(self)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  updatePosition(b)
  return b
end

function Minimap_:Init()
  GC.db.minimap = GC.db.minimap or {}
  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
  if LDB and DBI then
    local obj = LDB:NewDataObject(NAME, {
      type = "launcher",
      text = GC.L("title"),
      icon = ICON,
      OnClick = function(_, button) onClick(button) end,
      OnTooltipShow = fillTooltip,
    })
    DBI:Register(NAME, obj, GC.db.minimap)
    self.lib = DBI
  elseif Minimap then
    self.button = createOwnButton()
  end
  self:ApplyVisibility()
end

function Minimap_:ApplyVisibility()
  local hide = GC.db.minimap.hide
  if self.lib then
    if hide then self.lib:Hide(NAME) else self.lib:Show(NAME) end
  elseif self.button then
    if hide then self.button:Hide() else self.button:Show() end
  end
end

function Minimap_:Toggle()
  GC.db.minimap.hide = not GC.db.minimap.hide
  self:ApplyVisibility()
  GC.Print(GC.L("minimap_set", GC.db.minimap.hide and GC.L("off") or GC.L("on")))
end

-- Retail "addon compartment" menu (if the client has it, see .toc).
function GymChallenge_OnAddonCompartmentClick(_, button)
  onClick(button)
end

-- LibDBIcon may be loaded by an addon that loads after us, so wait for login.
GC.On("PLAYER_LOGIN", function() Minimap_:Init() end)
