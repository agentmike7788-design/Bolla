# G9 – Gehtempo der Dorfbewohner (Benutzerentscheidung 18.10.2026)

Branch `vs/p9-tempo`. Benutzerentscheidung (docs/PHASE9_DESIGN.md „G9 – Benutzerentscheidungen“ 1): Alle Zeitplan-Wege bekommen ein natürliches Gehtempo; Abfahrt früher statt Hetzen; die Ankunftszeiten der Systeme bleiben.

## Befund

- Zeitskala: 1 Spielminute = 0,5 s real (`TimeConfig.seconds_per_game_minute`). 1 m je Spielminute = 2 m/s real.
- Der Walk-Clip ist für **1,65 m/s** gebaut (`Npc.walk_anim_speed`), der Karren-Clip für 1,14 m/s (`push_anim_speed`). `Npc` stellt `AnimationPlayer.speed_scale = Bodentempo / Clip-Tempo` – die Füße rutschen nicht, aber bei 4–9 × läuft der Schritt hektisch („gleitet“); in LOD-Stufe 2 steht der Clip ganz.
- Phase 8 hat „1,6 m/s ≙ 3,2 m je Spielminute“ gerechnet (`NpcConfig.walk_m_per_minute` 3,2, PHASE8_DESIGN §2.5) – das sind **6,4 m/s**. Die handgeschriebenen Wege (Phase 7/8) lagen bei 4–16 m/s, Liesels Totenwache bei den Siebers 57 m in 15 Min (7,7 m/s), Esch' Grabbesuch-Weg 47 m in 6 Min (15,5 m/s). Auch die W3-Wege (Quast/Lenz zu den Siebers, 60–64 m in 40 Min) liefen mit 3,0–3,2 m/s, der Clip also doppelt so schnell.
- Bestandsaufnahme (`src/debug/walk_tempo_report.gd`, echte Welt): **135 Wege in `data/npc`, 116 außerhalb des Bands** (Tabelle unten). Dazu alle Laufzeit-Wege (Besucher, Lichtgang-Zug, Jakob, Räuber, Liesels Leichenwäsche) mit 3,2 m/min.

## Zieltempo (Spielwert in `data/config/npc_config.tres`)

| Wert | | real | Clip |
|---|---|---|---|
| `walk_m_per_minute` | **0,8 m/Spielminute** | 1,6 m/s | `speed_scale` 0,97 |
| `walk_min/max_m_per_minute` | 0,5 – 1,0 | 1,0 – 2,0 m/s | 0,6 – 1,2 × |
| `cart_m_per_minute` (Schieben / Mitfahren) | 0,55 | 1,1 m/s | 0,96 |
| `cart_min/max_m_per_minute` | 0,4 – 0,7 | | 0,7 – 1,2 × |

Schritte von 1–2 Minuten dürfen langsamer sein (ganze Minuten, aufgerundet); Laufen/Klettern (Räuber auf der Flucht, über den Zaun) sind keine Gehwege. Die Laufzeit-Systeme rechnen mit demselben Wert (`ScheduleBuilder`), die Generatoren lesen ihn aus der `.tres`.

## Regel und Umsetzung

- **Ankunft bleibt, Abfahrt früher** – Besuche (Esch 13:40, Theres 14:40, Liesel 09:40, Johann 10:00), Treffen am Hügel (Fenner 15:55, Rosine 14:55), Klopfen der Nachtwege (21:00, 22:30, 02:40), Kathreintanz (19:00/20:00), Lichtgang an den Gräbern (17:00), Läden/Türen auf, Osrics Lieferung (an der Bahre 07:24, Lieferung 07:40), Ende-B-Bank 18:00, Wache ab 21:00, Brenneisen am Tor 14:10, Hanne am Brunnen 10:00.
- **Abfahrt bleibt**, wo ein System ein Fenster beendet: Besuchsende, Treffen, Osric 10:00 (an der Straße 10:54), Hanne 14:00 vom Brunnen, Veit 11:30 von der Kirchtür, Johanns Abschied 16:20 / 10:00 (`WhoKnowsConfig.gone_after_minutes` 40 → 60), die Plauderei am Brunnen bis 16:30.
- **Resolver** (`ScheduleResolver.entry_at`, alte Zeitpläne bitgleich): ein gültiger `today_flag`-Weg, der noch unterwegs ist, wird von einem Alltags-Eintrag, der währenddessen beginnt, nicht abgeschnitten; ein Flag-Weg über Mitternacht geht bis zur Ankunft weiter. So können die längeren Overlay-Wege früher losgehen, ohne jeden Alltagseintrag zu kopieren.
- **Generatoren:** `tools/dialogue/walk_tempo.py` (Tempo, Längen aus den Layouts – deckungsgleich mit der Welt), `tools/dialogue/retime_walks.py` (Phase-7-Einträge, Tabelle mit Begründung), `build_phase8_schedules.py` / `build_phase9_schedules.py` rechnen jede Wegzeit aus der Polylinie; die W3-Handeinträge (Nachtwächter-Wege, Sieber-Nächte, Ende-B-Abende, Jakobs Kehrplatz …) stehen jetzt im Generator. Reihenfolge: `retime_walks.py`, dann `build_phase8`, dann `build_phase9` (idempotent).
- **Laufzeit:** Festivals (Aufstieg startet an den Gräbern − Wegzeit), Apprentice (`arrive_minute` 08:15 → 07:30, am Brett 08:25 wie bisher; Dorfwege ab der Krugtür statt aus dem 650 m entfernten Raum; abends nach dem Abstieg, 17:39), Visitors (Heimweg = Wegzeit statt 12 Min – vorher verschwand die Figur nach 12 Min mitten am Hang; Haushalte stehen wie bisher ~13 Min nach dem Slot am Grab und brechen früher auf; Debug „visit“ mit echter Wegzeit), NightRobber (gräbt ab seiner Ankunft), Wanderers (Veit sitzt durchgehend bis 19:30 auf der Brücke).

## Ausnahmen (begründet)

1. **Veits Abendessen in der Remise (17:00–18:06) entfällt** – Hin- und Rückweg (je 58 Min) waren länger als das Essen; er sitzt bis 19:30 auf der Brücke (Wanderers: Brücke 17:00–18:06 jetzt „da“) und geht dann zur Brunnenbank (20:04).
2. **Lichtgang:** Sammeln an der Brücke **14:41–15:11** (vorher 16:00–16:30), zurück im Dorf ab **20:13** (vorher 18:45) – der längste Aufstieg (Lindenacker, `l_16`) braucht 98 Minuten, an den Gräbern bleibt 17:00, Abgang 18:00–18:30. Wer sonst schon zu Hause wäre (Esch, Theres, Liesel), geht danach heim; Lenz und Jakob sitzen bis 22:00 im Krug. Quast kommt um 14:50 an die Brücke (nach seinem Mittag).
3. **Plaudereien/Aufträge:** `ch_well_spin` (Theres und Liesel am Brunnen 16:00–16:30) behält ihr Fenster – Theres' Laden öffnet nachmittags 16:52 (vorher 16:35), Liesel ist 16:47 an ihrer Tür (16:35). Fenner muss 18:05 im Krug sein (`of_fenner_3`) und verlässt das Brett 17:31 – Esch geht dafür 16:44 zur Linde (17:00, vorher 17:34; `of_esch_3` ab 17:34 erfüllt), `ch_linden_bench` läuft 17:00–17:31.
4. **Liesel wäscht** an Besuchs- und Totenwachen-Tagen nicht (sie geht von zu Hause los / schläft nach der Wache).
5. **Türzeiten** Wundarztstube 07:55–11:19 / 14:00–17:16, Amtsstube 07:55–11:31 / 13:05–15:42 (vorher bis 12:00/18:00 bzw. 12:00/16:00) – die Tür ist zu, wenn der Hausherr unterwegs ist.
6. **Über Mitternacht:** Quasts Heimwege von den Kehrs/Siebers (bis 00:09/00:33) gehen über den Resolver weiter.
7. **Nicht angefasst:** der 2-Minuten-Sprung eines Haushalts zwischen zwei Gräbern seiner Runde (kein Weg, ein Wechsel des Standplatzes, `VisitRules.timeline`), Osrics kurze Wege beim Abladen (Glocke/Griffe, innerhalb des Bands).

## Bilder

`osric_vorher_nachher.jpg` – Osric von der Remise zum Holderkrug am Nachmittag, gleiche Kamera, ein Bild je Spielminute (0,5 s real), Forward+ (lavapipe), Uhr und Clip laufen echt (`src/world/village/village_shots_tempo.gd`, `tools/tempo_strip.py`). Oben vorher: 17,6 m in 5 Min – 3,6 m je Bild, 7,0 m/s, Clip 4,27 ×, nach 5 Bildern ist er im Haus. Unten nachher: 13:42–14:05, 0,78 m je Bild, 1,53 m/s, Clip 0,93 ×. Einzelbilder `osric_vorher_00/02.jpg`, `osric_nachher_00/07.jpg`, Messwerte `osric_vorher.txt` / `osric_nachher.txt`.

## Tests und Bots

- Neu `tests/integration/test_walk_tempo.gd`: Zieltempo = Clip-Tempo; jeder Weg in `data/npc` im Band (echte Welt, Wegpunkte vorhanden); alle gebackenen Routen der Laufzeit-Wege hin und zurück; Lichtgang-Zug pünktlich an den Gräbern; Jakob auf dem Hügel und im Dorf (kein Weg aus dem Raum, Kutschweg in der richtigen Reihenfolge); Räuber; Osrics Abladen und Glocke.
- `test_schedule_resolver` (Overlay-Weg nicht abgeschnitten, über Mitternacht), Zeitplan-Tests nachgezogen (Osric 06:30/54 Min, Lichtgang, Besuche, Jakob, Johann, QA7-05/QA8-03, Kaufmanns- und Türzeiten, Scaffold-Werte). Mechanik-Tests von ScheduleBuilder/Apprentice/Planer laufen mit `walk_speed_override` 3,2 (Fixture-Tempo), das echte Tempo prüft `test_walk_tempo`.
- Phase-8-Bots (`phase8_bot.gd`): der Bot wartet nur noch auf Besucher, die innerhalb von 90 Minuten am Grab warten (vorher auf jeden Besucher am Hang – bei 98 Min Aufstieg verlor er den Tag). Ergebnis: `kindly8` B10 Tag 62, 6 Wünsche, Münzziel +15…+40 erfüllt, ≤ 20 % verpasste Besuche; `anatomist8` Tag 61, +54 (Wächter 50 → 60); `night8`/`night8b` Tag 61; `founder8` Tag 55; `lazy8` ohne Kapitel; `save_load8` zeilengleich zu `kindly8`.

## Alle Wege vorher / nachher

Zeit · Minuten · m je Spielminute (m/s real, Clip-Faktor). ✓ = war schon im Band.

| Figur | Tag | Weg | Strecke | vorher | nachher |
|---|---|---|---|---|---|
| Brenneisen | Ankunft | peddler_in → inn_door | 44,0 m | 09:30–09:50 · 20 min · 2,20 m/min (4,40 m/s, 2,66 ×) | 08:55–09:50 · 55 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Brenneisen | Brenneisens Tag | inn_door → road_in | 46,6 m | 13:30–13:40 · 10 min · 4,66 m/min (9,32 m/s, 5,65 ×) | 12:32–13:31 · 59 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Brenneisen | Brenneisens Tag | road_end → stranger_gate | 27,0 m | 13:50–14:10 · 20 min · 1,35 m/min (2,70 m/s, 1,64 ×) | 13:36–14:10 · 34 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Brenneisen | Brenneisens Tag | stranger_gate → road_end | 27,0 m | 15:30–15:50 · 20 min · 1,35 m/min (2,70 m/s, 1,64 ×) | 15:30–16:04 · 34 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Brenneisen | Brenneisens Tag | road_in → inn_door | 46,6 m | 16:00–16:10 · 10 min · 4,66 m/min (9,32 m/s, 5,65 ×) | 16:09–17:08 · 59 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Esch | Alltag | house_n → anvil | 18,3 m | 06:30–06:40 · 10 min · 1,83 m/min (3,67 m/s, 2,22 ×) | 06:17–06:40 · 23 min · 0,80 m/min (1,59 m/s, 0,97 ×) |
| Esch | Alltag | inn_door → anvil | 34,0 m | 13:00–13:06 · 6 min · 5,66 m/min (11,33 m/s, 6,86 ×) | 12:23–13:06 · 43 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Esch | Alltag | anvil → linden | 12,6 m | 17:30–17:34 · 4 min · 3,16 m/min (6,31 m/s, 3,83 ×) | 16:44–17:00 · 16 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Esch | Kathreintanz | linden → inn_door | 24,5 m | 18:56–19:00 · 4 min · 6,12 m/min (12,23 m/s, 7,41 ×) | 18:29–19:00 · 31 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Esch | Lichtgang | anvil → bridge | 18,1 m | 15:50–16:00 · 10 min · 1,81 m/min (3,63 m/s, 2,20 ×) | 14:18–14:41 · 23 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Esch | Lichtgang | bridge → road_in | 4,6 m | 16:30–16:35 · 5 min · 0,91 m/min (1,83 m/s, 1,11 ×) ✓ | 15:11–15:17 · 6 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Esch | Lichtgang | road_in → house_n (vorher road_in → anvil, 22,7 m) | 30,9 m | 18:45–18:57 · 12 min · 1,89 m/min (3,78 m/s, 2,29 ×) | 20:13–20:52 · 39 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Esch | Grabbesuch | anvil → road_in (vorher inn_door → road_in, 46,6 m) | 22,7 m | 13:00–13:06 · 6 min · 7,77 m/min (15,53 m/s, 9,41 ×) | 12:16–12:45 · 29 min · 0,78 m/min (1,57 m/s, 0,95 ×) |
| Esch | Grabbesuch | road_end → gold_01 | 40,0 m | 13:27–13:40 · 13 min · 3,08 m/min (6,15 m/s, 3,73 ×) | 12:50–13:40 · 50 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Esch | Grabbesuch | gold_01 → road_end | 40,0 m | 14:30–14:43 · 13 min · 3,08 m/min (6,15 m/s, 3,73 ×) | 14:30–15:20 · 50 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Esch | Grabbesuch | road_in → anvil | 22,7 m | 14:55–15:03 · 8 min · 2,84 m/min (5,68 m/s, 3,44 ×) | 15:25–15:54 · 29 min · 0,78 m/min (1,57 m/s, 0,95 ×) |
| Fenner | Alltag | office_door → board | 38,8 m | 12:00–12:20 · 20 min · 1,94 m/min (3,88 m/s, 2,35 ×) | 11:31–12:20 · 49 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Fenner | Alltag | board → office_door | 17,6 m | 13:00–13:05 · 5 min · 3,52 m/min (7,05 m/s, 4,27 ×) | 12:42–13:05 · 23 min · 0,77 m/min (1,53 m/s, 0,93 ×) |
| Fenner | Alltag | office_door → board | 17,6 m | 16:00–16:05 · 5 min · 3,52 m/min (7,05 m/s, 4,27 ×) | 15:42–16:05 · 23 min · 0,77 m/min (1,53 m/s, 0,93 ×) |
| Fenner | Alltag | board → inn_door | 27,0 m | 18:00–18:05 · 5 min · 5,41 m/min (10,81 m/s, 6,55 ×) | 17:31–18:05 · 34 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Fenner | Lichtgang | board → bridge | 20,4 m | 15:50–16:00 · 10 min · 2,04 m/min (4,07 m/s, 2,47 ×) | 14:15–14:41 · 26 min · 0,78 m/min (1,57 m/s, 0,95 ×) |
| Fenner | Lichtgang | bridge → road_in | 4,6 m | 16:30–16:35 · 5 min · 0,91 m/min (1,83 m/s, 1,11 ×) ✓ | 15:11–15:17 · 6 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Fenner | Lichtgang | road_in → board | 24,9 m | 18:45–18:57 · 12 min · 2,08 m/min (4,16 m/s, 2,52 ×) | 20:13–20:45 · 32 min · 0,78 m/min (1,56 m/s, 0,94 ×) |
| Fenner | Treffen oben | office_door → road_in | 49,1 m | 15:15–15:31 · 16 min · 3,07 m/min (6,14 m/s, 3,72 ×) | 13:15–14:17 · 62 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Fenner | Treffen oben | road_end → gl_12 | 74,4 m | 15:31–15:55 · 24 min · 3,10 m/min (6,20 m/s, 3,76 ×) | 14:22–15:55 · 93 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Fenner | Treffen oben | gl_12 → road_end | 74,4 m | 16:40–17:04 · 24 min · 3,10 m/min (6,20 m/s, 3,76 ×) | 16:40–18:13 · 93 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Fenner | Treffen oben | road_in → inn_door (vorher road_in → board, 24,9 m) | 46,6 m | 17:04–17:12 · 8 min · 3,12 m/min (6,24 m/s, 3,78 ×) | 18:18–19:17 · 59 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Hanne | Hannes Tag | peddler_in → well_peddler | 31,5 m | 09:30–10:00 · 30 min · 1,05 m/min (2,10 m/s, 1,27 ×) | 09:20–10:00 · 40 min · 0,79 m/min (1,57 m/s, 0,95 ×) |
| Hanne | Hannes Tag | well_peddler → road_in | 34,1 m | 14:00–14:10 · 10 min · 3,41 m/min (6,82 m/s, 4,13 ×) | 14:00–14:43 · 43 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Hanne | Hannes Tag | road_end → peddler_gate | 28,0 m | 15:20–15:40 · 20 min · 1,40 m/min (2,80 m/s, 1,70 ×) | 14:48–15:23 · 35 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Hanne | Hannes Tag | peddler_gate → trader_far | 45,0 m | 16:20–16:40 · 20 min · 2,25 m/min (4,50 m/s, 2,72 ×) | 16:20–17:17 · 57 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Ilse | Alltag | trader_spot → trader_far | 15,2 m | 03:00–03:20 · 20 min · 0,76 m/min (1,52 m/s, 0,92 ×) ✓ | 03:00–03:20 · 20 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Ilse | Alltag | trader_far → trader_spot | 15,2 m | 22:40–23:00 · 20 min · 0,76 m/min (1,52 m/s, 0,92 ×) ✓ | 22:40–23:00 · 20 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Jakob | Alltag | inn_door → road_in | 46,6 m | 07:45–07:55 · 10 min · 4,66 m/min (9,32 m/s, 5,65 ×) | 06:26–07:25 · 59 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Jakob | Lichtgang | inn_door → bridge | 42,0 m | 15:50–16:00 · 10 min · 4,20 m/min (8,40 m/s, 5,09 ×) | 13:48–14:41 · 53 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Jakob | Lichtgang | bridge → road_in | 4,6 m | 16:30–16:35 · 5 min · 0,91 m/min (1,83 m/s, 1,11 ×) ✓ | 15:11–15:17 · 6 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Jakob | Lichtgang | road_in → inn_door | 46,6 m | 18:45–18:57 · 12 min · 3,88 m/min (7,77 m/s, 4,71 ×) | 20:13–21:12 · 59 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Johann | Bank (H4) | sieber_door → sieber_bench | 2,2 m | 13:56–14:00 · 4 min · 0,55 m/min (1,10 m/s, 0,67 ×) ✓ | 13:56–14:00 · 4 min · 0,55 m/min (1,10 m/s, 0,67 ×) |
| Johann | Bank (H4) | sieber_bench → sieber_door | 2,2 m | 16:00–16:04 · 4 min · 0,55 m/min (1,10 m/s, 0,67 ×) ✓ | 16:00–16:04 · 4 min · 0,55 m/min (1,10 m/s, 0,67 ×) |
| Johann | Ende A mit Osric | sieber_door → road_in | 19,8 m | 09:05–09:14 · 9 min · 2,21 m/min (4,41 m/s, 2,67 ×) | 08:33–08:58 · 25 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Johann | Ende A mit Osric | road_end → dropoff | 29,4 m | 09:20–09:40 · 20 min · 1,47 m/min (2,94 m/s, 1,78 ×) | 09:03–09:40 · 37 min · 0,80 m/min (1,59 m/s, 0,96 ×) |
| Johann | Ende A mit Osric | dropoff → road_end | 29,4 m | 10:00–10:40 · 40 min · 0,74 m/min (1,47 m/s, 1,29 ×) | 10:00–10:54 · 54 min · 0,54 m/min (1,09 m/s, 0,96 ×) |
| Johann | Ende A mit Hanne | sieber_door → road_in | 19,8 m | 14:01–14:10 · 9 min · 2,21 m/min (4,41 m/s, 2,67 ×) | 14:19–14:44 · 25 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Johann | Ende A mit Hanne | road_end → sieber_gate | 27,2 m | 15:21–15:41 · 20 min · 1,36 m/min (2,72 m/s, 1,65 ×) | 14:49–15:24 · 35 min · 0,78 m/min (1,55 m/s, 0,94 ×) |
| Johann | Ende A mit Hanne | sieber_gate → trader_far | 44,2 m | 16:21–16:41 · 20 min · 2,21 m/min (4,42 m/s, 2,68 ×) | 16:21–17:17 · 56 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Johann | Ende B Abend | sieber_door → sieber_bench | 2,2 m | 17:56–18:00 · 4 min · 0,55 m/min (1,10 m/s, 0,67 ×) ✓ | 17:56–18:00 · 4 min · 0,55 m/min (1,10 m/s, 0,67 ×) |
| Johann | Ende B Abend | sieber_bench → sieber_door | 2,2 m | 20:00–20:04 · 4 min · 0,55 m/min (1,10 m/s, 0,67 ×) ✓ | 20:00–20:04 · 4 min · 0,55 m/min (1,10 m/s, 0,67 ×) |
| Lenz | Alltag | church_door → hagedorn_gate | 21,4 m | 11:30–11:38 · 8 min · 2,68 m/min (5,35 m/s, 3,24 ×) | 11:11–11:38 · 27 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Lenz | Alltag | church_door → inn_door | 15,0 m | 18:00–18:10 · 10 min · 1,50 m/min (3,00 m/s, 1,82 ×) | 17:51–18:10 · 19 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Lenz | Lichtgang | church_door → bridge | 35,2 m | 15:50–16:00 · 10 min · 3,52 m/min (7,03 m/s, 4,26 ×) | 13:57–14:41 · 44 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Lenz | Lichtgang | bridge → road_in | 4,6 m | 16:30–16:35 · 5 min · 0,91 m/min (1,83 m/s, 1,11 ×) ✓ | 15:11–15:17 · 6 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Lenz | Lichtgang | road_in → inn_door | 46,6 m | 18:45–18:57 · 12 min · 3,88 m/min (7,77 m/s, 4,71 ×) | 20:13–21:12 · 59 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Lenz | Weihe Lindenacker | road_end → linden_spot | 57,7 m | 08:40–09:20 · 40 min · 1,44 m/min (2,88 m/s, 1,75 ×) | 08:07–09:20 · 73 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Lenz | Weihe Lindenacker | linden_spot → road_end | 57,7 m | 10:30–11:10 · 40 min · 1,44 m/min (2,88 m/s, 1,75 ×) | 10:30–11:43 · 73 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Lenz | Nachtbesuch Kehr | church_door → kehr_door | 34,5 m | 20:50–21:00 · 10 min · 3,45 m/min (6,89 m/s, 4,18 ×) | 20:16–21:00 · 44 min · 0,78 m/min (1,57 m/s, 0,95 ×) |
| Lenz | Nachtbesuch Kehr | kehr_door → church_door | 34,5 m | 21:32–21:42 · 10 min · 3,45 m/min (6,89 m/s, 4,18 ×) | 21:32–22:16 · 44 min · 0,78 m/min (1,57 m/s, 0,95 ×) |
| Lenz | Nachtbesuch Ott | church_door → ott_door | 31,8 m | 20:50–21:00 · 10 min · 3,18 m/min (6,36 m/s, 3,85 ×) | 20:20–21:00 · 40 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Lenz | Nachtbesuch Ott | ott_door → church_door | 31,8 m | 21:42–21:52 · 10 min · 3,18 m/min (6,36 m/s, 3,85 ×) | 21:42–22:22 · 40 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Lenz | Nachtbesuch Sieber | church_door → sieber_door | 59,6 m | 20:20–21:00 · 40 min · 1,49 m/min (2,98 m/s, 1,81 ×) | 19:45–21:00 · 75 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Lenz | Nachtbesuch Sieber | sieber_door → church_door | 59,6 m | 21:42–22:22 · 40 min · 1,49 m/min (2,98 m/s, 1,81 ×) | 21:42–22:57 · 75 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Lenz | Ende B Abend | church_door → sieber_bench_2 | 56,5 m | 17:20–18:00 · 40 min · 1,41 m/min (2,82 m/s, 1,71 ×) | 16:49–18:00 · 71 min · 0,80 m/min (1,59 m/s, 0,96 ×) |
| Lenz | Ende B Abend | sieber_bench_2 → church_door | 56,5 m | 20:00–20:40 · 40 min · 1,41 m/min (2,82 m/s, 1,71 ×) | 20:00–21:11 · 71 min · 0,80 m/min (1,59 m/s, 0,96 ×) |
| Liesel | Alltag | dorn_door → wash | 29,6 m | 06:30–06:38 · 8 min · 3,70 m/min (7,40 m/s, 4,48 ×) | 06:00–06:38 · 38 min · 0,78 m/min (1,56 m/s, 0,94 ×) |
| Liesel | Alltag | dorn_door → well_w | 13,1 m | 15:00–15:05 · 5 min · 2,62 m/min (5,24 m/s, 3,17 ×) | 14:48–15:05 · 17 min · 0,77 m/min (1,54 m/s, 0,93 ×) |
| Liesel | Alltag | well_w → dorn_door | 13,1 m | 16:30–16:35 · 5 min · 2,62 m/min (5,24 m/s, 3,17 ×) | 16:30–16:47 · 17 min · 0,77 m/min (1,54 m/s, 0,93 ×) |
| Liesel | Kathreintanz | dorn_door → inn_door | 20,8 m | 19:55–20:00 · 5 min · 4,17 m/min (8,34 m/s, 5,05 ×) | 19:33–20:00 · 27 min · 0,77 m/min (1,54 m/s, 0,94 ×) |
| Liesel | Kathreintanz | inn_door → dorn_door | 20,8 m | 21:00–21:05 · 5 min · 4,17 m/min (8,34 m/s, 5,05 ×) | 21:00–21:27 · 27 min · 0,77 m/min (1,54 m/s, 0,94 ×) |
| Liesel | Lichtgang | dorn_door → bridge | 38,3 m | 15:50–16:00 · 10 min · 3,83 m/min (7,66 m/s, 4,64 ×) | 13:53–14:41 · 48 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Liesel | Lichtgang | bridge → road_in | 4,6 m | 16:30–16:35 · 5 min · 0,91 m/min (1,83 m/s, 1,11 ×) ✓ | 15:11–15:17 · 6 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Liesel | Lichtgang | road_in → dorn_door | 42,9 m | 18:45–18:57 · 12 min · 3,57 m/min (7,15 m/s, 4,33 ×) | 20:13–21:07 · 54 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Liesel | Nachtbesuch Ott | dorn_door → ott_door | 34,9 m | 02:30–02:40 · 10 min · 3,49 m/min (6,99 m/s, 4,23 ×) | 01:56–02:40 · 44 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Liesel | Nachtbesuch Ott | ott_door → dorn_door | 34,9 m | 05:32–05:42 · 10 min · 3,49 m/min (6,99 m/s, 4,23 ×) | 05:32–06:16 · 44 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Liesel | Nachtbesuch Sieber | dorn_door → sieber_door | 57,4 m | 02:25–02:40 · 15 min · 3,82 m/min (7,65 m/s, 4,64 ×) | 01:28–02:40 · 72 min · 0,80 m/min (1,59 m/s, 0,97 ×) |
| Liesel | Nachtbesuch Sieber | sieber_door → dorn_door | 57,4 m | 05:32–05:47 · 15 min · 3,82 m/min (7,65 m/s, 4,64 ×) | 05:32–06:44 · 72 min · 0,80 m/min (1,59 m/s, 0,97 ×) |
| Liesel | Ende B Abend | dorn_door → sieber_bench_2 | 54,3 m | 17:25–18:00 · 35 min · 1,55 m/min (3,10 m/s, 1,88 ×) | 16:52–18:00 · 68 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Liesel | Ende B Abend | sieber_bench_2 → dorn_door | 54,3 m | 20:00–20:35 · 35 min · 1,55 m/min (3,10 m/s, 1,88 ×) | 20:00–21:08 · 68 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Liesel | Grabbesuch | dorn_door → road_in | 42,9 m | 09:00–09:08 · 8 min · 5,36 m/min (10,72 m/s, 6,50 ×) | 07:23–08:17 · 54 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Liesel | Grabbesuch | road_end → linden_spot | 62,3 m | 09:20–09:40 · 20 min · 3,11 m/min (6,23 m/s, 3,77 ×) | 08:22–09:40 · 78 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Liesel | Grabbesuch | linden_spot → road_end | 62,3 m | 12:00–12:20 · 20 min · 3,11 m/min (6,23 m/s, 3,77 ×) | 12:00–13:18 · 78 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Liesel | Grabbesuch | road_in → dorn_door | 42,9 m | 12:50–12:58 · 8 min · 5,36 m/min (10,72 m/s, 6,50 ×) | 13:23–14:17 · 54 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Nachtwächter | Ende C Wache | sieber_watch → office_door | 68,1 m | 06:00–06:40 · 40 min · 1,70 m/min (3,41 m/s, 2,06 ×) | 06:00–07:26 · 86 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Nachtwächter | Ende C Wache | office_door → sieber_watch | 68,1 m | 20:20–21:00 · 40 min · 1,70 m/min (3,41 m/s, 2,06 ×) | 19:34–21:00 · 86 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Osric | Alltag | road_end → dropoff | 29,4 m | 06:44–07:24 · 40 min · 0,74 m/min (1,47 m/s, 1,29 ×) | 06:30–07:24 · 54 min · 0,54 m/min (1,09 m/s, 0,96 ×) |
| Osric | Alltag | dropoff → road_end | 29,4 m | 10:00–10:40 · 40 min · 0,74 m/min (1,47 m/s, 1,29 ×) | 10:00–10:54 · 54 min · 0,54 m/min (1,09 m/s, 0,96 ×) |
| Osric | Alltag | road_in → remise | 45,8 m | 11:10–11:18 · 8 min · 5,72 m/min (11,45 m/s, 6,94 ×) | 11:24–12:22 · 58 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Osric | Alltag | remise → inn_door | 17,6 m | 14:00–14:05 · 5 min · 3,52 m/min (7,04 m/s, 4,27 ×) | 13:42–14:05 · 23 min · 0,77 m/min (1,53 m/s, 0,93 ×) |
| Osric | Alltag | road_end → evening_spot | 28,0 m | 18:00–18:30 · 30 min · 0,93 m/min (1,87 m/s, 1,13 ×) ✓ | 18:00–18:30 · 30 min · 0,93 m/min (1,87 m/s, 1,13 ×) |
| Osric | Alltag | evening_spot → road_end | 28,0 m | 21:00–21:30 · 30 min · 0,93 m/min (1,87 m/s, 1,13 ×) ✓ | 21:00–21:30 · 30 min · 0,93 m/min (1,87 m/s, 1,13 ×) |
| Osric | Alltag | remise → inn_door | 17,6 m | 21:55–22:00 · 5 min · 3,52 m/min (7,04 m/s, 4,27 ×) | 21:37–22:00 · 23 min · 0,77 m/min (1,53 m/s, 0,93 ×) |
| Quast | Alltag | surgery_door → house_n | 40,0 m | 12:00–12:10 · 10 min · 4,00 m/min (8,01 m/s, 4,85 ×) | 11:19–12:10 · 51 min · 0,78 m/min (1,57 m/s, 0,95 ×) |
| Quast | Alltag | house_n → surgery_door | 40,0 m | 13:50–14:00 · 10 min · 4,00 m/min (8,01 m/s, 4,85 ×) | 13:09–14:00 · 51 min · 0,78 m/min (1,57 m/s, 0,95 ×) |
| Quast | Alltag | surgery_door → bridge | 39,9 m | 18:00–18:06 · 6 min · 6,65 m/min (13,30 m/s, 8,06 ×) | 17:16–18:06 · 50 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Quast | Lichtgang | surgery_door → bridge | 39,9 m | 16:00–16:06 · 6 min · 6,65 m/min (13,30 m/s, 8,06 ×) | 14:00–14:50 · 50 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Quast | Nachtbesuch Kehr | surgery_door → kehr_door | 45,1 m | 22:20–22:30 · 10 min · 4,51 m/min (9,03 m/s, 5,47 ×) | 21:33–22:30 · 57 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Quast | Nachtbesuch Kehr | kehr_door → surgery_door | 45,1 m | 23:12–23:22 · 10 min · 4,51 m/min (9,03 m/s, 5,47 ×) | 23:12–00:09 · 57 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Quast | Nachtbesuch Ott | surgery_door → ott_door | 14,5 m | 22:20–22:30 · 10 min · 1,45 m/min (2,91 m/s, 1,76 ×) | 22:11–22:30 · 19 min · 0,77 m/min (1,53 m/s, 0,93 ×) |
| Quast | Nachtbesuch Ott | ott_door → surgery_door | 14,5 m | 23:12–23:22 · 10 min · 1,45 m/min (2,91 m/s, 1,76 ×) | 23:12–23:31 · 19 min · 0,77 m/min (1,53 m/s, 0,93 ×) |
| Quast | Nachtbesuch Sieber | surgery_door → sieber_door | 64,3 m | 21:50–22:30 · 40 min · 1,61 m/min (3,22 m/s, 1,95 ×) | 21:09–22:30 · 81 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Quast | Nachtbesuch Sieber | sieber_door → surgery_door | 64,3 m | 23:12–23:52 · 40 min · 1,61 m/min (3,22 m/s, 1,95 ×) | 23:12–00:33 · 81 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Rosine | Alltag | inn_door → well | 16,0 m | 06:00–06:10 · 10 min · 1,60 m/min (3,19 m/s, 1,93 ×) | 05:50–06:10 · 20 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Rosine | Alltag | well → inn_door | 16,0 m | 06:40–06:50 · 10 min · 1,60 m/min (3,19 m/s, 1,93 ×) | 06:30–06:50 · 20 min · 0,80 m/min (1,60 m/s, 0,97 ×) |
| Rosine | Lichtgang | inn_door → bridge | 42,0 m | 15:50–16:00 · 10 min · 4,20 m/min (8,40 m/s, 5,09 ×) | 13:48–14:41 · 53 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Rosine | Lichtgang | bridge → road_in | 4,6 m | 16:30–16:35 · 5 min · 0,91 m/min (1,83 m/s, 1,11 ×) ✓ | 15:11–15:17 · 6 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Rosine | Lichtgang | road_in → inn_door | 46,6 m | 18:45–18:57 · 12 min · 3,88 m/min (7,77 m/s, 4,71 ×) | 20:13–21:12 · 59 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Rosine | Treffen oben | inn_door → road_in | 46,6 m | 14:25–14:40 · 15 min · 3,11 m/min (6,21 m/s, 3,76 ×) | 12:52–13:51 · 59 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Rosine | Treffen oben | road_end → vw_39 | 46,8 m | 14:40–14:55 · 15 min · 3,12 m/min (6,24 m/s, 3,78 ×) | 13:56–14:55 · 59 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Rosine | Treffen oben | vw_39 → road_end | 46,8 m | 15:40–15:55 · 15 min · 3,12 m/min (6,24 m/s, 3,78 ×) | 15:40–16:39 · 59 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Rosine | Treffen oben | road_in → inn_door | 46,6 m | 15:55–16:10 · 15 min · 3,11 m/min (6,21 m/s, 3,76 ×) | 16:44–17:43 · 59 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Theres | Alltag | shop_window → well | 17,1 m | 16:00–16:05 · 5 min · 3,42 m/min (6,85 m/s, 4,15 ×) | 15:28–15:50 · 22 min · 0,78 m/min (1,56 m/s, 0,94 ×) |
| Theres | Alltag | well → shop_window | 17,1 m | 16:30–16:35 · 5 min · 3,42 m/min (6,85 m/s, 4,15 ×) | 16:30–16:52 · 22 min · 0,78 m/min (1,56 m/s, 0,94 ×) |
| Theres | Kathreintanz | shop_window → inn_door | 33,1 m | 18:55–19:00 · 5 min · 6,61 m/min (13,23 m/s, 8,02 ×) | 18:18–19:00 · 42 min · 0,79 m/min (1,57 m/s, 0,95 ×) |
| Theres | Lichtgang | shop_window → bridge | 43,6 m | 15:50–16:00 · 10 min · 4,36 m/min (8,72 m/s, 5,29 ×) | 13:46–14:41 · 55 min · 0,79 m/min (1,59 m/s, 0,96 ×) |
| Theres | Lichtgang | bridge → road_in | 4,6 m | 16:30–16:35 · 5 min · 0,91 m/min (1,83 m/s, 1,11 ×) ✓ | 15:11–15:17 · 6 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Theres | Lichtgang | road_in → shop_window | 48,2 m | 18:45–18:57 · 12 min · 4,01 m/min (8,03 m/s, 4,87 ×) | 20:13–21:14 · 61 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Theres | Grabbesuch | shop_window → road_in | 48,2 m | 14:05–14:13 · 8 min · 6,02 m/min (12,04 m/s, 7,30 ×) | 12:49–13:50 · 61 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Theres | Grabbesuch | road_end → gold_08 | 35,5 m | 14:28–14:40 · 12 min · 2,96 m/min (5,92 m/s, 3,59 ×) | 13:55–14:40 · 45 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Theres | Grabbesuch | gold_08 → road_end | 35,5 m | 15:30–15:42 · 12 min · 2,96 m/min (5,92 m/s, 3,59 ×) | 15:30–16:15 · 45 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Theres | Grabbesuch | road_in → shop_window | 48,2 m | 15:45–15:55 · 10 min · 4,82 m/min (9,64 m/s, 5,84 ×) | 16:20–17:21 · 61 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Veit | Alltag | remise_sleep → church_step | 52,0 m | 07:50–08:00 · 10 min · 5,20 m/min (10,41 m/s, 6,31 ×) | 06:54–08:00 · 66 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Veit | Alltag | church_step → bridge_sit | 34,6 m | 11:30–11:40 · 10 min · 3,46 m/min (6,91 m/s, 4,19 ×) | 11:30–12:14 · 44 min · 0,79 m/min (1,57 m/s, 0,95 ×) |
| Veit | Alltag | bridge_sit → well_bench (vorher bridge_sit → remise_sleep, 46,1 m) | 27,1 m | 17:00–17:08 · 8 min · 5,76 m/min (11,52 m/s, 6,98 ×) | 19:30–20:04 · 34 min · 0,80 m/min (1,59 m/s, 0,97 ×) |
| Veit | Alltag | well_bench → remise_sleep | 24,5 m | 23:30–23:38 · 8 min · 3,06 m/min (6,12 m/s, 3,71 ×) | 23:29–00:00 · 31 min · 0,79 m/min (1,58 m/s, 0,96 ×) |
| Veit | Tor (ungerade Tage) | bridge_sit → road_in | 5,8 m | 13:00–13:06 · 6 min · 0,97 m/min (1,94 m/s, 1,17 ×) ✓ | 12:51–12:59 · 8 min · 0,73 m/min (1,45 m/s, 0,88 ×) |
| Veit | Tor (ungerade Tage) | road_end → veit_gate | 28,2 m | 13:20–13:40 · 20 min · 1,41 m/min (2,82 m/s, 1,71 ×) | 13:04–13:40 · 36 min · 0,78 m/min (1,57 m/s, 0,95 ×) |
| Veit | Tor (ungerade Tage) | veit_gate → road_end | 28,2 m | 16:00–16:20 · 20 min · 1,41 m/min (2,82 m/s, 1,71 ×) | 16:00–16:36 · 36 min · 0,78 m/min (1,57 m/s, 0,95 ×) |
| Veit | Tor (ungerade Tage) | road_in → bridge_sit | 5,8 m | 16:40–16:46 · 6 min · 0,97 m/min (1,94 m/s, 1,17 ×) ✓ | 16:41–16:49 · 8 min · 0,73 m/min (1,45 m/s, 0,88 ×) |
| Veit | Lichtgang | bridge_sit → road_in | 5,8 m | 16:00–16:06 · 6 min · 0,97 m/min (1,94 m/s, 1,17 ×) ✓ | 15:57–16:05 · 8 min · 0,73 m/min (1,45 m/s, 0,88 ×) |
| Veit | Lichtgang | road_end → lights_gate | 27,9 m | 16:25–16:45 · 20 min · 1,39 m/min (2,79 m/s, 1,69 ×) | 16:10–16:45 · 35 min · 0,80 m/min (1,59 m/s, 0,97 ×) |
| Veit | Lichtgang | lights_gate → road_end | 27,9 m | 18:30–18:50 · 20 min · 1,39 m/min (2,79 m/s, 1,69 ×) | 18:30–19:05 · 35 min · 0,80 m/min (1,59 m/s, 0,97 ×) |
| Veit | Lichtgang | road_in → bridge_sit | 5,8 m | 19:10–19:16 · 6 min · 0,97 m/min (1,94 m/s, 1,17 ×) ✓ | 19:10–19:18 · 8 min · 0,73 m/min (1,45 m/s, 0,88 ×) |
| Wiebke | Alltag | hagedorn_gate → well_bench | 14,5 m | 09:00–09:06 · 6 min · 2,41 m/min (4,82 m/s, 2,92 ×) | 08:47–09:06 · 19 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Wiebke | Alltag | well_bench → hagedorn_gate | 14,5 m | 11:00–11:06 · 6 min · 2,41 m/min (4,82 m/s, 2,92 ×) | 10:47–11:06 · 19 min · 0,76 m/min (1,52 m/s, 0,92 ×) |
| Veit | Alltag | remise_sleep → bridge_sit | 46,1 m | 17:58–18:06 · 8 min · 5,76 m/min (11,52 m/s, 6,98 ×) | entfällt |
| Veit | Alltag | bridge_sit → remise_sleep | 46,1 m | 19:30–19:38 · 8 min · 5,76 m/min (11,52 m/s, 6,98 ×) | entfällt |
| Veit | Alltag | remise_sleep → well_bench | 24,5 m | 20:50–21:00 · 10 min · 2,45 m/min (4,89 m/s, 2,97 ×) | entfällt |

vorher: 135 Wege, 116 außerhalb des Bands; nachher: 132 Wege, 0 außerhalb
