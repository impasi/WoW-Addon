-- Logic tests for GymChallenge against the mock API. Run: python3 tests/run_tests.py
local GC = {}
local files = { "Locales.lua", "Core.lua", "Areas.lua", "Paladins.lua", "Events.lua", "Comm.lua", "UI.lua", "Minimap.lua" }
for _, f in ipairs(files) do
  local chunk = assert(loadfile(ADDON_DIR .. "/" .. f))
  chunk("GymChallenge", GC)
end

local passed, failed = 0, 0
local function check(name, cond)
  if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. name) end
end
local function tasksOf(kind)
  local n, amount = 0, 0
  for _, t in ipairs(GymChallengeCharDB.tasks) do
    if t.kind == kind then n = n + 1; amount = amount + (t.amount or 0) end
  end
  return n, amount
end

GC.debug = true
Mock.fire("ADDON_LOADED", "GymChallenge")
Mock.fire("PLAYER_LOGIN")
Mock.fire("PLAYER_ENTERING_WORLD", true, false)
Mock.tick()
check("own minimap button created", GymChallengeMinimapButton ~= nil and GymChallengeMinimapButton.shown)
GymChallengeMinimapButton.scripts.OnClick(GymChallengeMinimapButton, "LeftButton")
check("minimap left click toggles window", GymChallengeFrame.shown == false)
GymChallengeMinimapButton.scripts.OnClick(GymChallengeMinimapButton, "LeftButton")
SlashCmdList["GYMCHALLENGE"]("minimap")
check("minimap hide", not GymChallengeMinimapButton.shown and GymChallengeDB.minimap.hide)
SlashCmdList["GYMCHALLENGE"]("minimap")
check("minimap show", GymChallengeMinimapButton.shown)
-- LibDBIcon path (simulated libraries loaded by another addon)
local registered
LibStub = function(name) 
  if name == "LibDataBroker-1.1" then return { NewDataObject = function(_, n, o) return o end } end
  if name == "LibDBIcon-1.0" then return { Register = function(_, n, o, db) registered = { n = n, o = o, db = db } end, Show = function() end, Hide = function() end } end
end
GC.Minimap:Init()
check("registers with LibDBIcon when present", registered and registered.n == "GymChallenge" and registered.db == GymChallengeDB.minimap)
LibStub = nil
check("compartment func exists", type(GymChallenge_OnAddonCompartmentClick) == "function")

-- Death / level / taxi node
Mock.fire("PLAYER_DEAD")
check("death -> 10 squats", select(2, tasksOf("squats")) == 10)
Mock.fire("PLAYER_LEVEL_UP", 13)
check("level -> 5 burpees", select(2, tasksOf("burpees")) == 5)
Mock.fire("UI_INFO_MESSAGE", 0, ERR_NEWTAXIPATH)
Mock.fire("CHAT_MSG_SYSTEM", ERR_NEWTAXIPATH) -- same discovery twice
check("taxi node -> 15 squats once", select(2, tasksOf("squats")) == 25)

-- Paladin outside crowded area: 5 push-ups, once per hour per name
Mock.units.nameplate1 = { name = "Lichtbringer", realm = nil, class = "PALADIN", player = true }
Mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Mock.tick(5)
check("uncrowded paladin -> 5 push-ups", select(2, tasksOf("pushups")) == 5)
Mock.advance(1800); Mock.tick()
check("same paladin within hour not counted", select(2, tasksOf("pushups")) == 5)
Mock.advance(1800); Mock.tick()
check("same paladin after hour counted again", select(2, tasksOf("pushups")) == 10)
Mock.units.nameplate1 = nil

-- Group member paladin never counts
Mock.units.nameplate2 = { name = "Gruppenpala", class = "PALADIN", player = true, party = true }
Mock.tick(2)
check("group paladin not counted", select(2, tasksOf("pushups")) == 10)
Mock.units.nameplate2 = nil

-- Crowded area (city): collect, show on leave
Mock.zone = "Sturmwind"; Mock.mapID = 84
Mock.fire("ZONE_CHANGED_NEW_AREA"); Mock.tick()
check("city is crowded", GC.Areas.IsCrowded())
Mock.units.nameplate3 = { name = "PalaA", class = "PALADIN", player = true }
Mock.units.nameplate4 = { name = "PalaB", class = "PALADIN", player = true }
Mock.units.nameplate5 = { name = "Krieger", class = "WARRIOR", player = true }
Mock.tick(3)
check("crowded collects 2", GymChallengeCharDB.crowded.count == 2)
check("no push-ups yet in crowded", select(2, tasksOf("pushups")) == 10)
GC.UI:RefreshStatus()
check("do-now button shown with count", GymChallengeFrame.doNow.shown and GymChallengeFrame.doNow.text:find("2") ~= nil)
GymChallengeFrame.doNow.scripts.OnClick()
check("do-now adds push-ups early", select(2, tasksOf("pushups")) == 12 and GymChallengeCharDB.crowded.count == 0)
check("do-now button hidden after", not GymChallengeFrame.doNow.shown)
Mock.units.nameplate3, Mock.units.nameplate4 = nil, nil
Mock.units.nameplate8 = { name = "PalaD", class = "PALADIN", player = true }
Mock.units.nameplate9b = { name = "PalaE", class = "PALADIN", player = true }
Mock.tick(2)
Mock.units.nameplate8, Mock.units.nameplate9b = nil, nil
check("collecting continues after do-now", GymChallengeCharDB.crowded.count == 2)
Mock.units.nameplate3, Mock.units.nameplate4, Mock.units.nameplate5 = nil, nil, nil
Mock.zone = "Wald von Elwynn"; Mock.mapID = 37
Mock.tick()
check("leaving crowded -> rest 2 push-ups", select(2, tasksOf("pushups")) == 14)
check("crowded counter reset", GymChallengeCharDB.crowded.count == 0)

-- Learned vendor spot
Mock.pos = { 100, 100 }
Mock.fire("MERCHANT_SHOW"); Mock.tick()
check("vendor spot crowded", GC.Areas.IsCrowded())
Mock.pos = { 132, 100 } Mock.tick() -- inside radius + hysteresis
check("hysteresis keeps crowded", GC.Areas.IsCrowded())
Mock.pos = { 200, 100 } Mock.tick()
check("far from spot uncrowded", not GC.Areas.IsCrowded())

-- Save spot dialog: whole subzone
Mock.zone = "Brachland"; Mock.subzone = "Das Wegekreuz"; Mock.pos = { 9000, 9000 }
Mock.tick()
check("crossroads not crowded yet", not GC.Areas.IsCrowded())
GC.UI:AskSaveSpot()
check("dialog offers area", GymChallengeSpotChoice.area.text == "Gebiet: Das Wegekreuz")
GymChallengeSpotChoice.area.scripts.OnClick()
Mock.tick()
check("saved subzone is crowded", GC.Areas.IsCrowded() and GC.Areas.reason == "reason_area")
Mock.pos = { 9500, 9500 } Mock.tick()
check("whole subzone crowded regardless of position", GC.Areas.IsCrowded())
Mock.subzone = "" Mock.tick()
check("leaving subzone uncrowded", not GC.Areas.IsCrowded())
GC.UI:AskSaveSpot()
check("no subzone: area option text", GymChallengeSpotChoice.area.text == "Kein Gebietsname hier")
GymChallengeSpotChoice.radius.scripts.OnClick()
Mock.tick()
check("radius option saves spot", GC.Areas.IsCrowded() and GC.Areas.reason == "reason_spot")
GymChallengeDB.spots[#GymChallengeDB.spots] = nil
Mock.zone = "Wald von Elwynn"; Mock.pos = { 5000, 5000 }
Mock.tick()
GymChallengeCharDB.crowded.count = 0

-- Flight leaving a crowded area: summary before flight
Mock.pos = { 100, 100 } Mock.tick()
Mock.units.nameplate6 = { name = "PalaC", class = "PALADIN", player = true }
Mock.tick()
Mock.units.nameplate6 = nil
check("collected at flight master", GymChallengeCharDB.crowded.count == 1)
Mock.onTaxi = true
Mock.fire("PLAYER_CONTROL_LOST"); Mock.tick()
check("flight started", GC.Events.IsFlying())
local puFly = select(2, tasksOf("pushups"))
Mock.units.nameplate7 = { name = "FlugPala", class = "PALADIN", player = true }
Mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate7"); Mock.tick()
check("no paladins counted while flying", select(2, tasksOf("pushups")) == puFly and GC.Paladins.seen["FlugPala"] == nil)
Mock.units.nameplate7 = nil
Mock.tick(65)
check("flight timer visible", GymChallengeFlightTimer:IsShown())
check("flight timer shows time", GymChallengeFlightTimer.text:GetText():find("1:0%d") ~= nil)
Mock.advance(-65) Mock.gettime = Mock.gettime
check("summary before flight", select(2, tasksOf("pushups")) == 15)
Mock.tick(90)
Mock.onTaxi = false
Mock.pos = { 5000, 5000 }
Mock.fire("PLAYER_CONTROL_GAINED"); Mock.tick()
check("flight ended", not GC.Events.IsFlying())
check("landed time shown", GymChallengeFlightTimer:IsShown() and GymChallengeFlightTimer.text:GetText():find("Gelandet") ~= nil)
local landed
for _, t in ipairs(GymChallengeCharDB.tasks) do if t.kind == "flight" then landed = t end end
check("flight duration measured ~91s", landed and landed.state == "landed" and landed.amount >= 90 and landed.amount <= 93)
check("flight plank not counted before answer", GymChallengeCharDB.stats.plank == 0)
GC.AnswerFlight(landed.id, true)
check("made flight plank counted", GymChallengeCharDB.stats.plank == landed.amount)
check("flight answer stored", GymChallengeCharDB.stats.flightsMade == 1 and tasksOf("flight") == 0)

Mock.tick(20)
check("landed display hides later", not GymChallengeFlightTimer:IsShown())

-- Expected flight time: unknown first, learned, shown at the next take-off
TakeTaxiNode(2)
Mock.onTaxi = true; Mock.tick()
check("first flight on route: unknown", GC.Events.ExpectedDuration() == nil
  and GymChallengeFlightTimer.text:GetText():find("unbekannt") ~= nil)
Mock.tick(119); Mock.onTaxi = false; Mock.tick()
check("route time learned", GymChallengeDB.flightTimes["Sturmwind > Seenhain"] ~= nil
  and math.abs(GymChallengeDB.flightTimes["Sturmwind > Seenhain"].t - 120) <= 2)
for _, t in ipairs(GymChallengeCharDB.tasks) do if t.state == "landed" then GC.AnswerFlight(t.id, true) end end
Mock.tick(20)
TakeTaxiNode(2)
Mock.onTaxi = true; Mock.tick()
local learned = GymChallengeDB.flightTimes["Sturmwind > Seenhain"].t
check("expected shown at take-off", GC.Events.ExpectedDuration() == learned
  and GymChallengeFlightTimer.text:GetText():find(GC.FormatDuration(learned), 1, true) ~= nil)
check("start alert has duration", Mock.lastPrint:find(GC.FormatDuration(learned), 1, true) ~= nil)
Mock.tick(30)
check("remaining time counts down", GymChallengeFlightTimer.text:GetText():find("noch " .. GC.FormatDuration(learned - 31), 1, true) ~= nil
  or GymChallengeFlightTimer.text:GetText():find("noch " .. GC.FormatDuration(learned - 30), 1, true) ~= nil)
Mock.onTaxi = false; Mock.tick()
for _, t in ipairs(GymChallengeCharDB.tasks) do if t.state == "landed" then GC.AnswerFlight(t.id, true) end end
check("shorter landing updates route time", GymChallengeDB.flightTimes["Sturmwind > Seenhain"].n == 2)
Mock.tick(20)

-- Dungeon leave
Mock.instance = { true, "party" }
Mock.fire("PLAYER_ENTERING_WORLD", false, false)
Mock.instance = { false, "none" }
Mock.fire("PLAYER_ENTERING_WORLD", false, false)
check("leaving dungeon -> 20 sit-ups", select(2, tasksOf("situps")) == 20)
Mock.instance = { true, "raid" }
Mock.fire("PLAYER_ENTERING_WORLD", false, false)
Mock.ghost = true
Mock.instance = { false, "none" }
Mock.fire("PLAYER_ENTERING_WORLD", false, false)
Mock.ghost = false
check("leaving as ghost not counted", select(2, tasksOf("situps")) == 20)
Mock.instance = { true, "pvp" }
Mock.fire("PLAYER_ENTERING_WORLD", false, false)
Mock.instance = { false, "none" }
Mock.fire("PLAYER_ENTERING_WORLD", true, false) -- login after disconnect
check("disconnect/login outside not counted", select(2, tasksOf("situps")) == 20)

-- Elite kill (target based), not in instances
Mock.units.target = { name = "Hogger", guid = "C-1", classification = "elite" }
Mock.fire("PLAYER_TARGET_CHANGED")
Mock.units.target.dead = true
Mock.fire("UNIT_HEALTH", "target"); Mock.tick(2)
check("elite kill -> 20s plank", select(2, tasksOf("plank")) == 20)
Mock.fire("PLAYER_TARGET_CHANGED"); Mock.tick()
check("dead elite retargeted not counted", select(2, tasksOf("plank")) == 20)
Mock.instance = { true, "party" }
Mock.units.target = { name = "Dungeonelite", guid = "C-2", classification = "elite" }
Mock.fire("PLAYER_TARGET_CHANGED")
Mock.units.target.dead = true
Mock.tick(2)
check("elite in dungeon not counted", select(2, tasksOf("plank")) == 20)
Mock.instance = { false, "none" }
Mock.units.target = { name = "Wolf", guid = "C-3", classification = "normal" }
Mock.fire("PLAYER_TARGET_CHANGED"); Mock.units.target.dead = true; Mock.tick()
check("normal mob not counted", select(2, tasksOf("plank")) == 20)
Mock.units.target = nil

-- Plank timer only on click, never auto-completed
local plank
for _, t in ipairs(GymChallengeCharDB.tasks) do if t.kind == "plank" then plank = t end end
Mock.tick(30)
check("timer not started automatically", plank.timerStart == nil)
GC.StartTimer(plank.id); Mock.tick(25)
check("timer finished but task still open", plank.timerAlerted and GC.FindTask(plank.id) ~= nil)
GC.CompleteTask(plank.id)
check("manual completion removes task", GC.FindTask(plank.id) == nil)

-- Clear list keeps statistics
local before = GymChallengeCharDB.stats.squats
check("open tasks not in stats", before == 0)
GC.ClearTasks()
check("clear empties list", #GymChallengeCharDB.tasks == 0)
check("clear keeps stats", GymChallengeCharDB.stats.squats == before)

-- Session cooldown: reset by reload (fresh Lua state) – simulated by clearing table
-- (real reload re-runs the files). Here we just verify the table is not saved.
check("cooldown not in SavedVariables", GymChallengeCharDB.seen == nil and GymChallengeDB.seen == nil)

-- Comm: join group, hello + stats sent; receive and de-duplicate
Mock.inGroup = true
Mock.units.party1 = { name = "Freund", player = true, party = true }
Mock.groupMembers = { "party1" }
Mock.fire("GROUP_ROSTER_UPDATE"); Mock.tick(5)
local sawHello, sawStats, sawWhisper = false, false, false
for _, m in ipairs(Mock.sent) do
  if m.text == "H1" and m.chatType == "PARTY" then sawHello = true end
  if m.text:sub(1, 2) == "S1" then sawStats = true end
  if m.chatType == "WHISPER" and m.target == "Freund-Realm" then sawWhisper = true end
  check("message <= 255 bytes", #m.text <= 255)
end
check("hello on join", sawHello)
check("stats on join", sawStats)
check("whisper fallback", sawWhisper)

local msg = "S1;5;" .. (Mock.now - 60) .. ";10;20;5;20;300;1;0"
Mock.fire("CHAT_MSG_ADDON", "GymChallenge", msg, "PARTY", "Freund-Realm")
Mock.fire("CHAT_MSG_ADDON", "GymChallenge", msg, "WHISPER", "Freund-Realm") -- duplicate
local e = GymChallengeDB.leaderboard["Freund-Realm"]
check("received stored", e and e.pushups == 20 and e.plank == 300)
check("duplicate not added", e.pushups == 20)
Mock.fire("CHAT_MSG_ADDON", "GymChallenge", "S1;6;" .. Mock.now .. ";10;25;5;20;300;1;0", "PARTY", "Freund-Realm")
check("update replaces", GymChallengeDB.leaderboard["Freund-Realm"].pushups == 25)
Mock.fire("CHAT_MSG_ADDON", "GymChallenge", "S1;99;1;0;999;0;0;0;0;0", "PARTY", "Ich-Realm")
check("own echo ignored", GymChallengeDB.leaderboard["Ich-Realm"] == nil)

-- Stats change -> broadcast after debounce; blocked in instances
Mock.sent = {}
Mock.instance = { true, "party" }
GC.CompleteTask(GC.AddTask("squats", 10, "r_death").id); Mock.tick(8)
check("no send inside instance", #Mock.sent == 0)
Mock.instance = { false, "none" }
Mock.tick(3)
check("sent after leaving instance", #Mock.sent > 0)

-- Comm off: nothing sent, nothing received
GC.Comm:SetEnabled(false)
Mock.sent = {}
GC.AddTask("squats", 10, "r_death"); Mock.tick(8)
check("comm off sends nothing", #Mock.sent == 0)
Mock.fire("CHAT_MSG_ADDON", "GymChallenge", "S1;50;" .. Mock.now .. ";1;1;1;1;1;0;0", "PARTY", "Fremd-Realm")
check("comm off ignores input", GymChallengeDB.leaderboard["Fremd-Realm"] == nil)
GC.Comm:ResetLeaderboard()
check("reset leaderboard", next(GymChallengeDB.leaderboard) == nil)

-- Language switch + slash command help do not error
GymChallengeDB.lang = "en"
GC.UI:Refresh()
check("english text", GC.TaskText({ kind = "pushups", amount = 5 }) == "5 push-ups")
GymChallengeDB.lang = "de"
check("german text", GC.TaskText({ kind = "pushups", amount = 5 }) == "5 Liegestütze")
GC.UI:ToggleRank(); GC.UI:RefreshRank()
local rf = GymChallengeRankFrame
check("rank has 9 columns", #rf.headers == 9)
local function rowName(i) return rf.rows[i].cells.name.text end
for _, h in ipairs(rf.headers) do if h.col.key == "plank" then h.scripts.OnClick() end end
check("sort by plank: own (more plank) first", rowName(1):find("Ich") ~= nil)
for _, h in ipairs(rf.headers) do if h.col.key == "pushups" then h.scripts.OnClick() end end
check("pushups column shows value", rf.rows[1].cells.pushups.text ~= nil)
GymChallengeDB.leaderboard["Freund-Realm"] = { rev=1, updated=Mock.now, received=Mock.now, squats=1, pushups=999, burpees=0, situps=0, plank=0, flightsMade=2, flightsFailed=1 }
GC.UI:RefreshRank()
check("sort by pushups: friend first", rowName(1):find("Freund") ~= nil and rf.rows[1].cells.pushups.text == "999")
check("flights column", rf.rows[1].cells.flights.text == "2/1")
check("realm hidden in ranking", rowName(1):find("Realm") == nil)
for _, c in ipairs({ "", "rank", "status", "test death", "test flightstart", "test flightend", "test paladin", "bogus" }) do
  local ok, err = pcall(SlashCmdList["GYMCHALLENGE"], c)
  check("slash '" .. c .. "' " .. tostring(err), ok)
end

-- History + delete
GymChallengeDB.lang = "de"
local histBefore = #GymChallengeCharDB.history
check("history has entries", histBefore > 10)
local sq0 = GymChallengeCharDB.stats.squats
local e = GC.AddTask("squats", 15, "r_taxinode")
check("history entry added", #GymChallengeCharDB.history == histBefore + 1 and GymChallengeCharDB.history[#GymChallengeCharDB.history].status == "open")
GC.UI:ToggleHistory()
check("history window shows newest first", GymChallengeHistoryFrame.rows[1].entry.id == e.id)
check("history row text", GymChallengeHistoryFrame.rows[1].cells.ex.text == "15 Squats")
check("open task not counted", GymChallengeCharDB.stats.squats == sq0)
GC.CompleteTask(e.id)
check("completed task counted", GymChallengeCharDB.stats.squats == sq0 + 15)
GC.CompleteTask(e.id)
check("double complete counts once", GymChallengeCharDB.stats.squats == sq0 + 15)
GC.DeleteHistory(e.id)
check("delete subtracts stats", GymChallengeCharDB.stats.squats == sq0)
local o = GC.AddTask("squats", 10, "r_death")
GC.DeleteHistory(o.id)
check("deleting open event does not subtract", GymChallengeCharDB.stats.squats == sq0)
check("delete removes open task", GC.FindTask(e.id) == nil)
check("delete removes history", GC.FindHistory(e.id) == nil)
local d = GC.AddTask("burpees", 5, "r_level", 14)
GC.CompleteTask(d.id)
check("done status in history", GC.FindHistory(d.id).status == "done")
-- flight entry: delete subtracts plank + made
GC.Events.StartFlight(nil, true); Mock.tick(40); GC.Events.EndFlight()
local fl
for _, t in ipairs(GymChallengeCharDB.tasks) do if t.state == "landed" then fl = t end end
local pl0, fm0 = GymChallengeCharDB.stats.plank, GymChallengeCharDB.stats.flightsMade
GC.AnswerFlight(fl.id, true)
check("flight made in history", GC.FindHistory(fl.id).status == "made")
GC.DeleteHistory(fl.id)
check("flight delete subtracts", GymChallengeCharDB.stats.plank == pl0 and GymChallengeCharDB.stats.flightsMade == fm0)
local c1 = GC.AddTask("situps", 20, "r_dungeon")
GC.ClearTasks()
check("cleared status", GC.FindHistory(c1.id).status == "cleared")
check("cleared not counted", GymChallengeCharDB.stats.situps == 0)
-- migration recomputes from history
GymChallengeCharDB.statsVersion = nil
GymChallengeCharDB.stats.squats = 9999
GC.MigrateStats()
check("migration recomputes from done entries", GymChallengeCharDB.stats.squats < 9999 and GymChallengeCharDB.statsVersion == 2)
local rev0 = GymChallengeCharDB.rev
GC.DeleteHistory(c1.id)
check("delete bumps revision for ranking", GymChallengeCharDB.rev > rev0)
-- delete via button + confirm
local x = GC.AddTask("squats", 10, "r_death")
GC.UI:RefreshHistory()
GymChallengeHistoryFrame.rows[1].del.scripts.OnClick()
GymChallengeConfirm.ok.scripts.OnClick()
check("delete via button", GC.FindHistory(x.id) == nil)

-- Load stats button
GC.Comm:SetEnabled(true)
Mock.inGroup = true
Mock.sent = {}
GymChallengeRankFrame.load.scripts.OnClick()
Mock.tick(3)
local hello = false
for _, m in ipairs(Mock.sent) do if m.text == "H1" then hello = true end end
check("load stats sends request", hello)
Mock.inGroup = false
GymChallengeRankFrame.load.scripts.OnClick()
check("load stats without group explains", Mock.lastPrint:find("Gruppe") ~= nil)
check("slash history", pcall(SlashCmdList["GYMCHALLENGE"], "history"))

-- Resizable windows
local mf = GymChallengeFrame
check("main window has resize grip", mf.grip ~= nil)
local visBefore = mf.visibleRows
mf:SetSize(500, 700)
check("taller main window shows more rows", mf.visibleRows > visBefore)
for i = 1, 12 do GC.AddTask("squats", 1, "r_death") end
GC.UI:Refresh()
local shown = 0
for _, r in ipairs(mf.rows) do if r.shown then shown = shown + 1 end end
check("rows shown match visible rows", shown == math.min(mf.visibleRows, #GymChallengeCharDB.tasks))
mf.grip.scripts.OnMouseUp(mf.grip)
check("main size saved", GymChallengeDB.windowSize and GymChallengeDB.windowSize.w == 500)
mf:SetSize(380, 200)
check("small main window keeps >= 1 row", mf.visibleRows >= 1)
for _, b in ipairs({ mf.sound, mf.mode, mf.clear, mf.rank, mf.history, mf.spot }) do b.w = 90 end
mf:SetSize(500, 600); GC.UI:Refresh()
check("wide: bottom buttons in one line", mf.bottomLines == 1)
mf:SetSize(260, 600); GC.UI:Refresh()
check("narrow: bottom buttons wrap", mf.bottomLines >= 2)
mf:SetSize(200, 600); GC.UI:Refresh()
check("very narrow: top buttons wrap", mf.topLines == 2)
local rf2 = GymChallengeRankFrame
rf2:SetSize(900, 500)
local nameCol
for _, h in ipairs(rf2.headers) do if h.col.key == "name" then nameCol = h.col end end
check("wider ranking widens name column", nameCol.cw > nameCol.w)
check("taller ranking more rows", rf2.visibleRows > 10)
local hf = GymChallengeHistoryFrame
hf:SetSize(800, 600)
check("taller history more rows", hf.visibleRows > 14)
GC.ClearTasks()

-- Secret values are skipped without errors
issecretvalue = function(v) return v == "SECRET" end
Mock.units.nameplate9 = { name = "SECRET", class = "PALADIN", player = true }
local n0 = select(2, tasksOf("pushups"))
local ok = pcall(Mock.tick, 2)
check("secret name skipped", ok and select(2, tasksOf("pushups")) == n0)

print(("passed %d, failed %d"):format(passed, failed))
return failed
