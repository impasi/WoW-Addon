# Gym Challenge – Addon für WoW Forever

Das Addon weist dir für Spielereignisse Übungen zu und zeigt sie in einer kleinen To-do-Liste an.
Die Übungen weist das Addon zu. In deine Statistik und in die Rangliste kommen sie erst, wenn du sie als **erledigt** abhakst. Ob du sie wirklich gemacht hast, prüft das Addon nicht.

Ziel-Client: **WoW Forever** mit `## Interface: 16001`, geprüft im Spiel mit `/dump select(4, GetBuildInfo())`.
WoW Forever verwendet die moderne Addon-API mit den Midnight-Einschränkungen, also keine Classic-API.

## Regeln

| Ereignis | Übung | Erkennung |
|---|---|---|
| Tod | 10 Squats | `PLAYER_DEAD` |
| Paladin in einer Crowded Area | 1 Liegestütz pro Paladin, wird beim Verlassen angezeigt | siehe unten |
| Paladin außerhalb | 5 Liegestütze, sofort | siehe unten |
| Level-up | 5 Burpees | `PLAYER_LEVEL_UP` |
| Fliegen | Plank vom Abflug bis zur Landung, mit Anzeige der erwarteten Flugzeit | `UnitOnTaxi("player")`, Strecke über `TakeTaxiNode` (Secure-Hook) |
| Dungeon, Raid oder Schlachtfeld verlassen | 20 Sit-ups | `PLAYER_ENTERING_WORLD` + `IsInInstance()` |
| Elite getötet (nicht in Instanzen) | 20 Sek. Plank, der Timer startet erst per Klick | aktuelles Ziel |
| Neuer Flugpunkt | 15 Squats | Systemmeldung `ERR_NEWTAXIPATH` |

### Details zu den Regeln
- **Paladine:** Gezählt werden nur **untote** Paladin-Spieler (Rasse über `UnitRace`, sprachunabhängig `Scourge`). Erkannt werden alle Paladin-Spieler, für die der Client eine Namensplakette anzeigt, außerdem dein Ziel und der Spieler unter der Maus. Das gilt für beide Fraktionen. Die eigene Gruppe zählt nie, du selbst auch nicht. Jeder Name zählt höchstens einmal pro Stunde. Dieser Cooldown gilt nur für die laufende Sitzung und nur für den aktuellen Charakter. Nach `/reload` oder einem Neustart beginnt er von vorn.
- **Crowded Areas:**
  - Hauptstädte, erkannt über Karten-ID oder Zonenname. Mit `/gym city` fügst du die aktuelle Zone als Stadt hinzu oder entfernst sie wieder.
  - Häfen, erkannt über Zonen- und Unterzonennamen.
  - Ein Umkreis von 30 m um jeden Händler und Flugmeister, dessen Fenster du einmal geöffnet hast. Das Addon lernt diese Orte selbst. Mit „Ort merken“ (oder `/gym spot`) speicherst du eine Stelle auch manuell. Das Addon fragt dann, was es speichern soll: einen **Umkreis von 30 m** um deine Position (z. B. für einen Schiffsanleger) oder das **ganze Gebiet** mit seinem Namen, z. B. „Das Wegekreuz“. Ein gespeichertes Gebiet gilt überall, wo das Spiel diesen Gebietsnamen anzeigt.
  - Mit der Schaltfläche „Gebiet“ wechselst du zwischen Auto, immer Crowded und immer Uncrowded.
  - Mit dem Button **„Jetzt machen (N)“** neben der Statuszeile übernimmst du die gesammelten Liegestütze schon vor dem Verlassen in die Liste. Paladine, die du danach im selben Gebiet siehst, werden wieder gesammelt und beim Verlassen angezeigt.
  - Verlässt du eine Crowded Area per Flug, kommt die Summe **vor** dem Flug. Während des Flugs werden keine Paladine gezählt.
- **Flugzeit-Anzeige:** Beim Abflug zeigt eine große, verschiebbare Anzeige oben in der Bildschirmmitte die erwartete Flugzeit und dann die Restzeit ("Flugzeit: 2:14 - noch 1:30"). Die API kennt keine Flugdauer. Deshalb merkt sich das Addon die Dauer jeder Strecke (Start > Ziel), die du einmal geflogen bist, für den ganzen Account. Beim ersten Flug auf einer Strecke steht dort "noch unbekannt". Flüge, deren Landung erst nach einem Login oder /reload erkannt wurde, werden nicht gelernt.
- **Fliegen:** Nach der Landung gilt die Übung als erledigt. Das Addon fragt dich dann „Plank geschafft? Ja / Nein“ und speichert die Antwort in deiner Statistik.
- **Instanz verlassen:** Ein Login nach einem Disconnect zählt nicht. Das Verlassen als Geist zählt auch nicht.
- **Elite:** Gezählt wird, wenn dein aktuelles Ziel ein Elite ist (auch Rar-Elite und Weltboss) und stirbt. Das zählt auch, wenn ein anderer Spieler den Gegner getötet hat. Ohne Ziel wird nichts gezählt. In Instanzen ist die Regel aus.

## Bedienung
- `/gym` öffnet oder schließt das Fenster. Bei jeder Übung stehen Anzahl bzw. Dauer und der Grund.
- **Erledigt** entfernt eine Übung. **Start** startet den Timer einer Plank. Ist die Zeit um, ertönt ein Ton, aber die Übung bleibt in der Liste, bis du sie abhakst.
- **Fenstergröße:** Das Hauptfenster, die Rangliste und der Verlauf lassen sich über den Griff unten rechts größer und kleiner ziehen. In ein größeres Fenster passen mehr Zeilen. Wird es breiter, bekommen in der Rangliste die Namen und im Verlauf die Gründe mehr Platz. Ist das Hauptfenster schmal, verteilen sich die Buttons auf mehrere Reihen. Größe und Position werden gespeichert.
- **Liste leeren** fragt vorher nach. Deine Statistik bleibt dabei erhalten.
- Mit **DE/EN** wechselst du die Sprache, mit **Sound an/aus** schaltest du die Töne.
- **Verlauf** zeigt alle zugewiesenen Übungen mit Zeit, Grund und Status (offen, erledigt, entfernt, gelandet, geschafft, nicht geschafft), die neuesten zuerst. Mit dem Mausrad blätterst du. Mit **X** löschst du ein einzelnes Ereignis, nach einer Rückfrage. War das Ereignis schon erledigt, verschwindet es auch aus deiner Statistik und aus der Rangliste deiner Gruppe. Gespeichert werden die letzten 500 Einträge.
- Die offene Liste und die gesammelten Paladine einer Crowded Area bleiben über `/reload` und Neustart erhalten.

- **Minimap-Button:** Linksklick öffnet die Übungen, Rechtsklick die Rangliste und Shift+Linksklick den Verlauf. Den Button kannst du um die Minimap ziehen. Mit `/gym minimap` blendest du ihn ein oder aus. Hat ein anderes Addon LibDBIcon geladen (das tun die meisten Minimap-Sammler), meldet sich der Button dort an, sodass Sammler wie Good Addons ihn gruppieren können. Sonst erstellt das Addon einen eigenen Button direkt an der Minimap.

### Befehle
```
/gym                    Fenster an/aus
/gym rank               Gruppen-Rangliste
/gym history            Verlauf deiner Übungen
/gym minimap            Minimap-Button ein/aus
/gym lang de|en         Sprache
/gym sound              Sound an/aus
/gym crowded auto|on|off
/gym spot               Ort merken (Umkreis oder ganzes Gebiet)
/gym city               aktuelle Zone als Stadt hinzufügen/entfernen
/gym comm on|off        Ranglisten-Austausch an/aus
/gym resetrank          empfangene Ranglisten-Daten löschen
/gym resetstats         eigene Statistik auf 0 setzen
/gym status             Zone, Karten-ID, Crowded-Status (zum Debuggen)
/gym debug              Debug-Ausgaben an/aus
/gym test <ereignis>    death | level | flightstart | flightend | dungeon | elite | taxinode | paladin
```

## Gruppen-Rangliste
- Wenn du einer Gruppe beitrittst, schicken sich alle Addon-Nutzer ihre Statistik. Ändert sich danach etwas, wird sie nach 5 Sekunden erneut gesendet.
- Übertragen werden nur Zahlen: Revision, Zeitstempel, Squats, Liegestütze, Burpees, Sit-ups, Plank-Sekunden und Flug-Planks (geschafft / nicht geschafft). Eine Nachricht hat höchstens etwa 60 Byte, das Limit liegt bei 255.
- **Gezählt werden nur erledigte Übungen:** Eine Übung zählt, sobald du auf „Erledigt“ klickst. Eine Flug-Plank zählt nur, wenn du nach der Landung „Ja“ wählst. Übungen, die du mit „Liste leeren“ entfernst, zählen nicht.
- **Keine Doppelzählung:** Jeder sendet seine eigene Gesamtsumme mit einer Revisionsnummer. Der Empfänger ersetzt den alten Eintrag, statt etwas zu addieren. Gleiche oder ältere Daten werden ignoriert.
- Empfangene Werte werden lokal gespeichert, für den ganzen Account. Sie bleiben auch nach dem Verlassen der Gruppe sichtbar. Dein eigener Eintrag ist grün und mit „(du)“ markiert. Namen werden ohne Realm angezeigt. Die Spalte „aktualisiert“ zeigt, wann der Spieler seine Werte zuletzt geändert hat.
- Die Rangliste hat eigene Spalten für Squats, Liegestütze, Burpees, Sit-ups, Plank (Zeit), Flug +/- (Flug-Planks geschafft/nicht geschafft) und Gesamt (Summe der Wiederholungen). Mit einem Klick auf einen Spaltenkopf sortierst du nach dieser Spalte.
- Mit **Statistiken laden** fragst du alle Addon-Nutzer in deiner Gruppe sofort nach ihren aktuellen Werten.
- Du kannst den Austausch abschalten und die Rangliste zurücksetzen.

**Technische Grenzen beim Austausch:**
- In Instanzen und während der Chat-Sperre (Bosskämpfe, M+, PvP) dürfen Addons nichts senden. Das Addon sendet dann erst, wenn du wieder draußen bist.
- Laut Berichten aus der Forever-Beta melden manche Kanäle Erfolg, liefern aber nichts aus. Deshalb sendet das Addon zusätzlich per Addon-Flüsternachricht an jedes Gruppenmitglied.
- Test- und Veteranen-Accounts können keine Addon-Nachrichten senden.
- Das Limit liegt bei etwa 10 Nachrichten pro Präfix als Burst, danach 1 pro Sekunde. Das Addon sendet höchstens 2 pro Sekunde.

## Installation
1. Lade das Repo herunter: Auf GitHub unter **Code → Download ZIP**, dann entpacken.
2. Kopiere den Ordner **`GymChallenge`** (den Ordner mit der `.toc`, nicht den ganzen Repo-Ordner) nach:
   ```
   World of Warcraft\_forever_\Interface\AddOns\GymChallenge\
   ```
   Wenn dein Installationsordner anders heißt, nimm den Ordner, in dem auch deine anderen Forever-Addons liegen.
   Am Ende muss es `...\Interface\AddOns\GymChallenge\GymChallenge.toc` geben.
3. Starte das Spiel. Klicke in der Charakterauswahl auf **AddOns** und setze den Haken bei **Gym Challenge**.
4. Damit Paladine erkannt werden, schalte die **Namensplaketten für Spieler** ein, für freundliche und feindliche Spieler (Optionen → Namensplaketten).

## Testen
1. Gib im Spiel `/gym` ein. Das Fenster sollte erscheinen.
2. Probiere `/gym test death`, `/gym test elite`, `/gym test paladin` und `/gym test flightstart` gefolgt von `/gym test flightend`. Die Übungen sollten in der Liste erscheinen, und bei eingeschaltetem Sound hörst du einen Ton.
3. Gib in einer Hauptstadt `/gym status` ein. Dort sollte `crowded=true` stehen. Wenn nicht, füge die Zone mit `/gym city` hinzu.
4. Rangliste: Tritt mit einem Freund, der das Addon auch hat, außerhalb einer Instanz einer Gruppe bei. Öffne `/gym rank`. Nach ein paar Sekunden sollte sein Eintrag auftauchen.
5. Logik-Tests ohne Spiel (für Entwickler): `pip install lupa` und dann `python3 tests/run_tests.py`. Das testet die Addon-Logik gegen eine nachgebaute Mini-API, nicht gegen das echte Spiel.

## Bekannte Einschränkungen
- **Sichtweite:** Die API kennt keine echte Sichtlinie. „Sichtbar“ heißt hier, dass der Client eine Namensplakette anzeigt (in etwa 40 m Reichweite, teils auch hinter Wänden) oder dass der Spieler dein Ziel oder unter der Maus ist.
- **Kein Kampflog:** Das Kampflog steht Addons in Forever nicht zur Verfügung. Elite-Kills funktionieren deshalb nur über dein aktuelles Ziel.
- **Secret Values:** Im Kampf und in Instanzen können Namen, Klassen und andere Werte „secret“ sein. Das Addon überspringt sie dann und versucht es eine Sekunde später erneut. Ein Paladin, den du nur kurz im Kampf siehst, kann dadurch fehlen.
- **Händler, Flugmeister und Schiffe** erkennt das Addon nur über gelernte Orte und Namenslisten. Ein Händler, dessen Fenster du nie geöffnet hast, ist dem Addon unbekannt.
- **Flugzeit vorab:** Das Addon kennt eine Flugzeit erst, nachdem du die Strecke einmal geflogen bist.
- **Karten-IDs und Zonennamen** von Forever sind nicht offiziell dokumentiert. Falls eine Stadt nicht erkannt wird, hilft `/gym city`.
- Die Angaben zur Forever-API stammen aus Community-Quellen von der Beta. Blizzard kann Funktionen jederzeit ändern.
