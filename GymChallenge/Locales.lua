local _, GC = ...

-- All user-facing strings. Keys are looked up via GC.L(key, ...).
local strings = {
  de = {
    title = "Gym Challenge",
    open_tasks = "Offene Übungen: %d",
    no_tasks = "Keine offenen Übungen. Gut gemacht!",
    assigned_note = "Vom Addon zugewiesen, nicht überprüft.",

    ex_squats = "%d Squats",
    ex_pushups = "%d Liegestütze",
    ex_burpees = "%d Burpees",
    ex_situps = "%d Sit-ups",
    ex_plank = "%d Sek. Plank",
    ex_flight_running = "Flug-Plank: %s",
    ex_flight_done = "Flug-Plank: %s",

    r_death = "Tod",
    r_level = "Level-up auf %d",
    r_flight = "Flug",
    r_dungeon = "Instanz verlassen",
    r_elite = "Elite getötet: %s",
    r_taxinode = "Neuer Flugpunkt",
    r_paladin_open = "Paladin gesehen: %s",
    r_paladin_crowded = "%d Paladin(e) in Crowded Area",
    r_manual = "Manuell",

    btn_start = "Start",
    btn_done = "Erledigt",
    btn_yes = "Ja",
    btn_no = "Nein",
    btn_clear = "Liste leeren",
    btn_rank = "Rangliste",
    btn_lang = "EN",
    btn_sound_on = "Sound: an",
    btn_sound_off = "Sound: aus",
    btn_spot = "Ort merken",
    crowded_mode_auto = "Gebiet: Auto",
    crowded_mode_on = "Gebiet: Crowded",
    crowded_mode_off = "Gebiet: Uncrowded",
    timer_left = "%s übrig",
    timer_over = "Zeit um! Jetzt abhaken.",
    flight_question = "Plank geschafft?",

    area_crowded = "Crowded (%s): %d Paladin(e) gesammelt",
    area_uncrowded = "Uncrowded Area",
    area_flying = "Fliegen - Flugzeit: %s",
    flight_unknown = "unbekannt",
    flight_timer_known = "Flugzeit: %s - noch %s - planken!",
    flight_timer_unknown = "Flugzeit noch unbekannt (wird gemerkt) - %s",
    flight_landed = "Gelandet - Flugzeit: %s",
    reason_city = "Stadt",
    reason_harbor = "Hafen",
    reason_spot = "Händler/Flugpunkt",
    reason_manual = "manuell",

    warn_nameplates = "Namensplaketten aus: Paladine nur per Ziel/Maus",
    confirm_clear = "Alle offenen Übungen entfernen?",
    confirm_reset_rank = "Empfangene Ranglisten-Daten löschen?",
    confirm_reset_stats = "Eigene Statistik auf 0 setzen?",
    ok = "OK",
    cancel = "Abbrechen",

    alert_new = "Neue Übung: %s (%s)",
    alert_crowded_summary = "Crowded Area verlassen: %d Paladin(e) = %d Liegestütze",
    alert_flight_start = "Flug gestartet - Plank bis zur Landung! Flugzeit noch unbekannt.",
    alert_flight_start_known = "Flug gestartet - Flugzeit %s. Plank bis zur Landung!",
    alert_flight_end = "Gelandet nach %s. Hast du es geschafft?",
    alert_timer_done = "Plank-Zeit vorbei!",
    spot_saved = "Ort als Crowded Area gespeichert.",
    spot_failed = "Position nicht verfügbar (z. B. in Instanzen).",
    city_added = "Zone \"%s\" als Stadt hinzugefügt.",
    city_removed = "Zone \"%s\" aus den Städten entfernt.",

    rank_title = "Gruppen-Rangliste",
    rank_note = "Zugewiesene Übungen, nicht bestätigt. Flug +/- = Flug-Planks geschafft/nicht. Spaltenkopf anklicken = sortieren.",
    rank_header = "Name",
    rank_reps = "Wdh.",
    col_squats = "Squats",
    col_pushups = "Liegest.",
    col_burpees = "Burpees",
    col_situps = "Sit-ups",
    col_plank = "Plank",
    col_flights = "Flug +/-",
    col_total = "Gesamt",
    rank_plank = "Plank",
    rank_updated = "aktualisiert",
    rank_you = "%s (du)",
    rank_empty = "Noch keine Daten von anderen Addon-Nutzern.",
    rank_comm_on = "Austausch: an",
    rank_comm_off = "Austausch: aus",
    rank_reset = "Zurücksetzen",
    rank_tooltip = "Squats %d, Liegestütze %d, Burpees %d, Sit-ups %d, Plank %s, Flug-Planks geschafft %d / nicht %d",
    ago_now = "gerade eben",
    ago_min = "vor %d Min.",
    ago_hour = "vor %d Std.",
    ago_day = "vor %d Tg.",
    comm_blocked = "Austausch in Instanzen nicht möglich - wird danach gesendet.",

    help = "Befehle: /gym (Fenster), /gym rank, /gym lang de|en, /gym sound, /gym crowded auto|on|off, /gym spot, /gym city, /gym comm on|off, /gym resetrank, /gym resetstats, /gym status, /gym test <death|level|flightstart|flightend|dungeon|elite|taxinode|paladin>",
    lang_set = "Sprache: Deutsch",
    sound_set = "Sound: %s",
    on = "an",
    off = "aus",
    test_done = "Test-Ereignis ausgelöst: %s",
  },
  en = {
    title = "Gym Challenge",
    open_tasks = "Open exercises: %d",
    no_tasks = "No open exercises. Well done!",
    assigned_note = "Assigned by the addon, not verified.",

    ex_squats = "%d squats",
    ex_pushups = "%d push-ups",
    ex_burpees = "%d burpees",
    ex_situps = "%d sit-ups",
    ex_plank = "%d sec plank",
    ex_flight_running = "Flight plank: %s",
    ex_flight_done = "Flight plank: %s",

    r_death = "Death",
    r_level = "Level up to %d",
    r_flight = "Flight",
    r_dungeon = "Left instance",
    r_elite = "Elite killed: %s",
    r_taxinode = "New flight point",
    r_paladin_open = "Paladin seen: %s",
    r_paladin_crowded = "%d paladin(s) in crowded area",
    r_manual = "Manual",

    btn_start = "Start",
    btn_done = "Done",
    btn_yes = "Yes",
    btn_no = "No",
    btn_clear = "Clear list",
    btn_rank = "Ranking",
    btn_lang = "DE",
    btn_sound_on = "Sound: on",
    btn_sound_off = "Sound: off",
    btn_spot = "Save spot",
    crowded_mode_auto = "Area: auto",
    crowded_mode_on = "Area: crowded",
    crowded_mode_off = "Area: uncrowded",
    timer_left = "%s left",
    timer_over = "Time's up! Tick off?",
    flight_question = "Did you make the plank?",

    area_crowded = "Crowded (%s): %d paladin(s) collected",
    area_uncrowded = "Uncrowded area",
    area_flying = "Flying - flight time: %s",
    flight_unknown = "unknown",
    flight_timer_known = "Flight time: %s - %s left - keep planking!",
    flight_timer_unknown = "Flight time not known yet (learning) - %s",
    flight_landed = "Landed - flight time: %s",
    reason_city = "city",
    reason_harbor = "harbor",
    reason_spot = "vendor/flight point",
    reason_manual = "manual",

    warn_nameplates = "Nameplates off: paladins only via target/mouse",
    confirm_clear = "Remove all open exercises?",
    confirm_reset_rank = "Delete received ranking data?",
    confirm_reset_stats = "Reset your own statistics to 0?",
    ok = "OK",
    cancel = "Cancel",

    alert_new = "New exercise: %s (%s)",
    alert_crowded_summary = "Left crowded area: %d paladin(s) = %d push-ups",
    alert_flight_start = "Flight started - plank until you land! Flight time not known yet.",
    alert_flight_start_known = "Flight started - flight time %s. Plank until you land!",
    alert_flight_end = "Landed after %s. Did you make it?",
    alert_timer_done = "Plank time is over!",
    spot_saved = "Spot saved as crowded area.",
    spot_failed = "Position not available (e.g. inside instances).",
    city_added = "Zone \"%s\" added as city.",
    city_removed = "Zone \"%s\" removed from cities.",

    rank_title = "Group ranking",
    rank_note = "Assigned exercises, not confirmed. Flight +/- = flight planks made/failed. Click a header to sort.",
    rank_header = "Name",
    rank_reps = "Reps",
    col_squats = "Squats",
    col_pushups = "Push-ups",
    col_burpees = "Burpees",
    col_situps = "Sit-ups",
    col_plank = "Plank",
    col_flights = "Flight +/-",
    col_total = "Total",
    rank_plank = "Plank",
    rank_updated = "updated",
    rank_you = "%s (you)",
    rank_empty = "No data from other addon users yet.",
    rank_comm_on = "Sharing: on",
    rank_comm_off = "Sharing: off",
    rank_reset = "Reset",
    rank_tooltip = "Squats %d, push-ups %d, burpees %d, sit-ups %d, plank %s, flight planks made %d / failed %d",
    ago_now = "just now",
    ago_min = "%d min ago",
    ago_hour = "%d h ago",
    ago_day = "%d d ago",
    comm_blocked = "Sharing is not possible inside instances - will be sent afterwards.",

    help = "Commands: /gym (window), /gym rank, /gym lang de|en, /gym sound, /gym crowded auto|on|off, /gym spot, /gym city, /gym comm on|off, /gym resetrank, /gym resetstats, /gym status, /gym test <death|level|flightstart|flightend|dungeon|elite|taxinode|paladin>",
    lang_set = "Language: English",
    sound_set = "Sound: %s",
    on = "on",
    off = "off",
    test_done = "Test event fired: %s",
  },
}

GC.strings = strings

function GC.GetLang()
  local lang = GC.db and GC.db.lang
  if lang ~= "de" and lang ~= "en" then
    local locale = GetLocale and GetLocale() or "enUS"
    lang = (locale == "deDE") and "de" or "en"
  end
  return lang
end

function GC.L(key, ...)
  local s = strings[GC.GetLang()][key] or strings.en[key] or key
  if select("#", ...) > 0 then
    return string.format(s, ...)
  end
  return s
end

function GC.FormatDuration(sec)
  sec = math.max(0, math.floor(sec or 0))
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  if h > 0 then
    return string.format("%d:%02d:%02d", h, m, s)
  end
  return string.format("%d:%02d", m, s)
end

function GC.FormatAgo(ts)
  if not ts or ts == 0 then return "-" end
  local d = time() - ts
  if d < 60 then return GC.L("ago_now") end
  if d < 3600 then return GC.L("ago_min", math.floor(d / 60)) end
  if d < 86400 then return GC.L("ago_hour", math.floor(d / 3600)) end
  return GC.L("ago_day", math.floor(d / 86400))
end
