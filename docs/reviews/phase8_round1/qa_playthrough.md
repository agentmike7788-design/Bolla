# Phase 8 – QA-Playthrough, Befunde, Art-Prüfung, Performance (W3)

Stand: Branch `vs/p8-qa` (auf `1d2a022`). Vertrag: `docs/PHASE8_DESIGN.md` (§9 Performance, §10 Tests/Bots, §11 Bilder, §14 Entscheidungen, W0-Notizen, W1-Anschlüsse). Phase-8-Code = Diff `bb21a75~1..1d2a022`.

## 1. Befunde (adversariales Review) und Behebungen

Regressionstests: `tests/unit/test_phase8_qa.gd` (ohne Welt), `tests/integration/test_phase8_qa.gd` (echte Welt aus dem v6-Fixture), dazu `test_apprentice_day`, `test_visit_routes`, `test_phase8_loop`, `test_save_fuzzer`.

| ID | Schwere | Befund | Behoben | Test |
|---|---|---|---|---|
| QA8-03 | **hoch** | Fenners Geschichte 2 (Treffen an `l_12`) und Rosines Geschichte 3 (an Jakobs Bank) waren **nicht erfüllbar**: kein Zeitplan brachte die beiden zur Zeit des Fensters an den Ort – das Kapitel hing an einer Freundschaft, die nie „voll“ werden konnte. | ✅ `OrderData.conditions.schedule_flag` (`meet_mayor_day`, `meet_innkeeper_day`); `Orders` setzt den Tag beim Annehmen (heute, wenn ≥ 60 Min vor dem Fenster, sonst morgen) und jeden Morgen, nie auf den Lichtgang; `build_phase8_schedules.py` → `today_flag`-Einträge in `mayor_schedule` / `innkeeper_schedule` (hin, warten, zurück) | unit `test_qa8_03_…` (2), `test_phase8_loop` (Fenner steht an `l_12`), Bots: Fenner 2 + 3 bei `kindly8`/`anatomist8` erfüllt |
| QA8-18 | **hoch** | Nach dem **Laden mitten in einem Besuch** (und nach `visit` in der Debug-Konsole) war die Besucherin **unsichtbar**: der Weg der Angehörigen-Figur wurde nur beim Übergang „arriving“ gesetzt, ein geladener Stand gilt als schon angekündigt. | ✅ `Visitors.load_state` (deferred) / `post_load` setzen den Weg jeder laufenden Besuchs-Figur neu | integration `test_qa8_18_visitor_figure_after_a_load_mid_visit` |
| QA8-17 | mittel | Jedes Laden eines Phase-8-Stands warf Engine-Fehler (`global_transform`/`look_yaw` außerhalb des Baums): die alte Welt rief verzögert `Apprentice.refresh_npcs` auf. Aufgedeckt vom neuen v7-Fuzzer (539 Fehlschläge) und `save_load8`. | ✅ `refresh_npcs` außerhalb des Baums = nichts | unit `test_qa8_17_…`, Fuzzer, `save_load8` |
| QA8-01 | mittel | Lenz' und Theres' Gefallen lösten `favor_use` ohne Auswahl aus (kein Grab / keine Ware wählbar). | ✅ Wahl `open_panel:favor` (`build_phase8_dialogue.py`, `v_priest`/`v_grocer`) | unit `test_qa8_01_…` |
| QA8-04 | mittel | Für die Aufträge Lenz 1 / Theres 2 gab es **keine Quelle** für `register_extract`. | ✅ Hüttenpult: „[E] Namen für … abschreiben (20 Min, 1 Tinte)“, solange ein angenommener Auftrag den Auszug braucht (`GraveCareConfig.extract_*`) | integration `test_qa8_04_…` |
| QA8-05 | mittel | `apprentice_off_day` wurde nie gesetzt – Jakobs Dorf-Figur folgte an freien Tagen dem Laufzeitplan. | ✅ `Apprentice._new_day` setzt das Flag (nicht am Lichtgang), `free_day()`; Dorf-Figur nach Datenzeitplan (Gaststube) | integration `test_qa8_05_…` |
| QA8-06 | mittel | Liesels Totenwäsche (Gefallen) war unsichtbar. | ✅ `Friendship` legt ihr einen Laufzeitplan an (Gruft-Treppe → hinter dem Tisch, `work`, zurück), auch nach dem Laden | integration `test_qa8_06_…` |
| QA8-07 | klein | Jakobs Rechen verschwand zwischen zwei Laubhaufen (nur `show_with`). | ✅ `Npc`: `carry_with` – das Werkzeug bleibt in den Trage-Clips, solange der nächste Arbeits-Clip es zeigt | `test_apprentice_day` |
| QA8-08 | klein (UX) | [E] am Grab setzte in der Dämmerung erst Blumen, die Kerze danach. | ✅ `GravePlot.care_order`: anzündbare Kerze vor Blumen/Kranz | integration `test_qa8_08_…` |
| QA8-09 | klein | Werkbank prüfte `RecipeData.requires_flag` nur im Panel (Namenstafel ohne `friend_innkeeper_2` herstellbar). | ✅ `Workbench.request_craft` lehnt ab | integration `test_qa8_09_…` |
| QA8-10 | klein (Text) | Prompt „2 Münzen auf dem Stein“. | ✅ „[E] Zwei Münzen auf dem Stein (Martha Kehr)“ (`Phase8Texts.coins_on_stone`) | unit `test_qa8_10_…`, `test_ui_phase8` |
| QA8-16 | klein (UX) | Auf dem Grab gewann der Grab-Prompt gegen die Münzen auf dem Stein (Bild p8_06 ohne Prompt). | ✅ `TipStone` Priorität 12 (> Grab) | unit `test_qa8_16_…`, Bild `p8_06` |
| QA8-11 | klein | Pflegestellen `dirt_y01` (Südzaun) / `dirt_h03` (Holunderwinkel) – Jakob stand im Zaun. | ✅ `ApprenticePlanner.spot_stand` (Nav-Freiraum 0,4 m) | `test_visit_routes` (Ausnahme entfernt) |
| QA8-12 | klein | Ladestände: `disturbed` auf leeren Gräbern, Gitter auf EMPTY, > `max_open` Wünsche, zwei Wünsche je Grab, Plan eines späteren Tages wurden übernommen. | ✅ `GraveCare.load_state`, `Visitors.load_state` bereinigen | integration `test_qa8_12_…`, Fuzzer-Prüfungen |
| QA8-13 | klein (Ton) | Gießen ohne Takt zum Clip. | ✅ `ToolAnimConfig` `bite_at`/`beat_cues` water, `PlayerAnimator` | integration `test_qa8_13_…` |
| QA8-15 | klein | Der Lichtgang-Zug nahm auch die Dorf-Figur `npc_priest` mit (Region falsch). | ✅ `Festivals.apply_procession` nur Friedhofs-Figuren | integration `test_qa8_15_…` |
| QA8-19 | klein (Text) | Abschluss-Panel „Wer heraufkommt“: „In **Phase sieben** bist du hinuntergegangen …“ – Wort aus der Entwicklung im Spieltext. | ✅ „Erst bist du die drei Meilen hinuntergegangen. …“ (`Phase8Texts.CHAPTER_INTRO`) | unit `test_qa8_19_…`, Bild `ui_p8_chapter` |
| QA8-20 | klein (Robustheit) | Ein beschädigter Spielstand mit Besuchs-Flags, die keine Wahrheitswerte sind (`ended`, `flowers`, `waits`, `noise`), ließ `Visitors._advance` **jede Minute** mit „Nonexistent 'bool' constructor“ abbrechen. Gefunden vom neuen v7-Fuzzer. | ✅ `Visitors.load_state` macht sie zu `bool`, eine Phase ohne Namen fällt weg | integration `test_qa8_20_…`, Fuzzer |
| QA8-14 | Liste | W-Ton-Platzhalter fehlten in der Placeholder-Liste. | ✅ Zeile in `QUALITY_GATE_STATUS.md` (28 Cues, 62 Dateien) | – |

### Art (ART STYLE LOCK „Gemaltes Diorama“ – nur Korrekturen, keine Stiländerung)

| ID | Befund | Behoben | Bild |
|---|---|---|---|
| QA8-A1 | Veit am Tor schwebte/stand steif (p8_16). | ✅ Clip `sit_ground` (Hüfte am Boden, Beine gestreckt, Becher), Zeitplan `veit_gate` | `p8_16` |
| QA8-A2 | Münzen auf dem Stein zu klein (p8_06). | ✅ `ph_prop_tip_coins` Radius 3 cm, Messing, Zettel 12 × 8 cm | `p8_06` |
| QA8-A3 | Dorf nachts sehr dunkel (p8_18/19). | ✅ nur das Krankenlicht (Fenster der Otts) heller/weiter (2,2 / 6 m) – kein Eingriff in die Nacht-Presets | `p8_18`, `p8_19` |
| QA8-A4 | Hinrichs Hut in `mourn_stand` zu groß. | ✅ `hat_hand` 0,78 ×, 35° gedreht | `p8_04` |
| QA8-A5 | Novemberdämmerung zu spät (p8_22: 17:55 noch Tag). | ✅ `AtmosphereController` verschiebt die Zeit-Schlüssel ab Tag 50 → 56 (Tag bis 15:00, Dämmerung 16:40, Nacht 18:10); Presets selbst unverändert – **Entscheidung E8-1** | unit `test_qa8_a5_…`, `p8_22` |
| QA8-A6 | Bartstoppeln Veit/Johann unsichtbar. | ✅ Farbe/Deckkraft in `asset_wanderers.py` / `asset_mourners.py` | `faces_close` |
| QA8-A7 | Jakobs Haar wirkte wie ein Helm. | ✅ ungleichmäßige Strähnen, Stirnfransen, flache Büschel (`asset_apprentice.py`) | `p8_08`, `faces_close` |
| QA8-A8 | Hanne bot mit der Kiepe auf dem Rücken an. | ✅ Kindmesh `kiepe_down` (neben ihr, `show_with: offer`), Dreiecke 8966 ≤ 9000 | `p8_16`, `p8_17` |

## 2. Offene Punkte / Entscheidungen für den Benutzer

- **E8-1 (Licht, ART LOCK):** kürzere Novembertage über verschobene Zeit-Schlüssel (QA8-A5) und ein helleres Krankenlicht (QA8-A3). Die Tageszeit-Presets selbst sind unverändert. Bitte bestätigen oder zurücknehmen.
- **E8-2 (Münzen außerhalb von `kindly8`):** `kindly8` trifft das Ziel (+22, Ziel ≈ +28; Prüfregel ≤ Start + 50 erfüllt). Die übrigen Wege enden höher: `anatomist8` +66, `night8` +65, `lazy8` +122 (`founder8` −11, er baut und kauft). Ursache ist das Einkommen aus Phase 5–7 (Begräbnisse, Stipendium, Präparate, Aufträge ≈ 17 Münzen/Tag) ohne die Phase-8-Senken (Kerzen, Setzlinge, Gitter, Lohn). Trinkgeld ist **nicht** der Hebel (10–12 je Bogen, Ziel 16 % → gemessen 6 %): `tip_cap_day` bleibt. Vorschlag für den Benutzer: so lassen (Phase 8 belohnt Pflege, nicht Sparen) oder in Phase 10 die Grundeinnahmen dämpfen. Der Test prüft bis dahin die §10-Untergrenzen und gemessene Obergrenzen (Regressionswächter).
- **B8-1 (Besuche verpasst):** Das Gesprächsfenster eines Besuchs ist ≈ 40 Min (30 Trauer + 10 Warten). Ein Bot, der wie ein Spieler Begräbnisse, Steinbruch und Dorf erledigt, verpasst 40–55 % der Besuche (vor allem 09:30, wenn Osric liefert). Das senkt Trinkgeld und Wünsche. Frage an den Benutzer: so gewollt (man kann nicht überall sein) oder `wait_minutes` 10 → 25 / eine Glocke am Tor.
- **B8-2 (Vasen-Wünsche):** Auf gut gepflegten Gräbern ist der erste offene Wunsch oft die **Vase** (founder8: 7 von 15 Angeboten). Sie braucht Stein + Samen an der Werkbank – erfüllbar, aber ohne Hinweis im Wunschtext, woher die Vase kommt.
- **B8-3 (Trinkgeld des verwertenden Wegs):** §10 erwartet bei `anatomist8` weniger Trinkgeld als bei `kindly8` (Gerede über Präparate). Gemessen 12 gegen 10 (10 bzw. 9 Gespräche): das Gerede senkt das Wohlwollen nur an den Gräbern der Toten, deren Präparat verkauft wurde, und die kamen selten zu Besuch. Der Test prüft bis zur Entscheidung nur „kein klarer Vorteil“ (≤ kindly8 + 4). Frage: Gerede dorfweit wirken lassen (alle Besuche −1) oder so lassen.
- **P8-1 (Performance, §9):** Phase-8-Skriptanteil je Frame (direkt gemessen, Cloud-CPU): Friedhof Tag **0,29 ms** (Budget 0,2), Lichtgang **0,54 ms** (0,5), Dorf **0,17 ms** (0,1). Fast alles ist `Npc._process` der Phase-8-Figuren (je ≈ 0,06 ms). Die Cloud-CPU ist langsamer als eine Mittelklasse-CPU (Leerlauf-Frame hier 7 ms headless); Plan B §9 (`max_full` 4, Stufe-1-Rate 2 Hz) wäre der erste Schritt, falls der Benutzer am PC Ruckler sieht. Nicht geändert.
- **P8-2 (Dreiecke bei Maximal-Zoom):** Lichtgang-Übersicht bei Spiel-Zoom 22 **444 k** (< 500 k ✓), bei Zoom 31 (p8_22, Maximum 34) **609 k** – davon 348 k Gras; im **Compatibility-Renderer** (Browser) zählt dasselbe Bild **856 Draw Calls** (> 750; Forward+ 379), weil dort jedes Licht einen eigenen Pass kostet. Bei Spiel-Zoom 22 im Budget. Nur gemeldet.
- **A8-2 (Browser-Licht):** Im Compatibility-Renderer wirkt der Lichtgang 17:55 deutlich heller als in Forward+ (`p8_22_web` gegen `p8_22`) – dieselben Presets, anderer Renderer. Nur gemeldet.
- **A8-1 (Lichtgang-Laternen):** Im Zug (p8_21) sind die Laternen nur kleine Leuchtpunkte, keine Lichtpfützen (Lichtbudget: Pool 6 Omni ohne Schatten). Nur gemeldet.
- **Bild-Lücke:** `p8_31` (Liesels Totenwäsche am Gruft-Tisch) hat kein Weltmotiv – die sichtbare Wäsche ist per Integrationstest geprüft (QA8-06); `p8_00`/`p8_01` sind die Asset-Tafeln `lineup_day` / `faces_close`.
- **Bot-Eigenheiten (nicht geändert):** `night8b` = `night8` bis auf den Ausgang mit Lambert; `anatomist8` erreicht das Kapitel über Fenners volle Geschichte (Treffen am Hügel B6, Holderkrug B7, Archivschlüssel).

## 3. Playthrough-Bot Phase 8

`tests/integration/phase8_bot.gd` (`Phase8Bot extends Phase7Bot`): echte Besuche (warten am Grab, Trinkgeld aus der Hand, Wunsch anbieten/annehmen, Wünsche erfüllen inkl. Vase), Grabpflege (Setzlinge, Gießkanne + Regenfass, Kerzen, Gitter, aufgewühltes Grab schließen), Jakob (Einstellen bei Rosine, Rechen in die Kiste, Lohndose, Kreidetafel, Vormachen), Freundschafts-Schritte über die echten Dialoge, Treffen am Hügel / im Holderkrug, Pfarrarchiv, Registerauszug am Pult, Veit (Almosen am Tor und im Dorf), Kathreintanz (Anwesenheit je Minute), Lichtgang (Kerzen, Lenz), Nachtwege am Krankenlicht (Beobachtungsplatz), Lambert (melden / laufen lassen). Strategien: `kindly8`, `anatomist8`, `lazy8`, `night8`, `night8b`, `founder8`, `save_load8` (lädt jeden Morgen, einmal während eines Besuchs, einmal am Lichtgang; `night8` zusätzlich einmal nachts beim Räuber).

`tests/integration/test_phase8_playthrough.gd` prüft: keine Fehler/Warnungen, keine Bot-Probleme (auch: Roundtrip beim Laden gleich, Floats bis 1e-9), Werte im Bereich, Münzbuch (Start + Einnahmen − Ausgaben = Ende, Beutel + Lohndose), morgens nie < 5, Kapitel B8–B10 (`kindly8`), ≤ Tag 68 (`founder8`), kein Kapitel (`lazy8`), Beobachtungen und Lambert (`night8`/`night8b`), `save_load8` zeilengleich zu `kindly8`. Env `P8QA_ONLY=<strategie,…>`, `P8QA_DAYS=<n>`.

| Strategie | Start (Fixture) | Tage | Kapitel (Tag/B) | Münzen Start → Ende (Δ) | morgens min. | Einnahmen | Ausgaben | Besuche (verpasst) | Wünsche (Angeh.) | Trinkgeld | Schritte | Jakob-Tage | Almosen | Nacht |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kindly8 | v6 neighbor | 10 | 62 / B10 | 48 → 70 (+22) | 24 | 170 (burial 53, stipend 40, service 21, order 19, village_sale 15, gift 12, tip 10) | 148 (village 82, ilse 22, apprentice 21, donation 10, alms 7, osric 6) | 9 (10) | 6 (3) | 10 | 8, Fenner voll | 7 | 7 | Quast + Lenz beobachtet, 2 Tänze |
| save_load8 | dto. | 10 | 62 / B10 | = kindly8 | 24 | = | = | = | = | = | = | = | = | zeilengleich |
| anatomist8 | v6 anatomist | 10 | 61 / B8 | 60 → 126 (+66) | 49 | 210 (… specimen 47, tip 12) | 144 | 10 (10) | 7 (3) | 12 | 7, Fenner voll | 8 | 7 | Lenz/Liesel ≤ Bekannt ✓ |
| lazy8 | v6 neighbor | 10 | – (gewollt) | 48 → 170 (+122) | 48 | 173 | 51 | 14 (3) | 0 | 0 | 0 | 0 | 8 | Ruf 100 |
| night8 | v6 neighbor | 10 | 61 / B9 | 48 → 113 (+65) | 28 | 172 | 107 | 9 (10) | 6 (3) | 10 | 9 | 7 | 9 | Quast, Lenz, Liesel beobachtet; Lambert Nacht 57 geflohen, Nacht 60 sitzend → **gemeldet** |
| night8b | dto. | 10 | 61 / B9 | 48 → 113 | 28 | = | = | = | = | = | = | = | = | Lambert **laufen gelassen** |
| founder8 | v6 founder | 16 (bis Kapitel) | 63 / B16 (≤ 68 ✓) | 52 → 41 (−11) | 47 | 238 | 249 (village 152) | 13 (17) | 5 (4) | 5 | 9 | 12 | 14 | – |

Tag für Tag (`kindly8`):

| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends (Dose) | Besuche | Wünsche erf. (Angeh.) | Trinkgeld ges. | Schritte (voll) | Jakob (Rechen/Jäten) | Almosen | Erkenntnis | Ruf | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 53 | 48 | alms 1, village 20, ilse 4 | order 7, village_sale 3, stipend 4 | 37 (12) | 2 | 0 (0) | 0 | 0 (0) | frei 0/0 | 1 | – | 99 | offen |
| 54 | 37 | osric 2, village 10, donation 5 | stipend 4 | 24 (12) | 1 | 0 (0) | 0 | 1 (0) | frei 0/0 | 1 | – | 99 | offen |
| 55 | 24 | apprentice 3, alms 1, donation 5, village 5, ilse 4 | service 7, burial 26, village_sale 3, gift 3, stipend 4 | 49 (9) | 0 | 0 (0) | 0 | 3 (0) | arbeitet 1/0 | 2 | – | 99 | offen |
| 56 | 49 | osric 2, apprentice 3, alms 1 | tip 1, service 7, burial 14, gift 6, stipend 4 | 75 (12) | 1 | 1 (1) | 1 | 3 (0) | arbeitet 1/1 | 3 | – | 100 | offen |
| 57 | 75 | alms 1, village 3, apprentice 3, ilse 7 | tip 2, village_sale 3, stipend 4 | 70 (9) | 1 | 2 (2) | 3 | 5 (0) | arbeitet 1/1 | 4 | ✓ | 100 | offen |
| 58 | 70 | ilse 3 | stipend 4 | 71 (9) | 0 | 2 (2) | 3 | 5 (0) | frei 1/1 | 4 | ✓ | 100 | offen |
| 59 | 71 | osric 2, alms 1, village 16, apprentice 3, ilse 3 | tip 2, order 4, village_sale 3, stipend 4 | 59 (12) | 2 | 4 (3) | 5 | 5 (0) | arbeitet 1/1 | 5 | ✓ | 100 | offen |
| 60 | 59 | apprentice 3, village 11, alms 1, ilse 1 | service 7, burial 13, gift 3, stipend 4 | 70 (9) | 0 | 4 (3) | 5 | 6 (0) | arbeitet 1/2 | 6 | ✓ | 100 | offen |
| 61 | 70 | apprentice 3 | tip 3, stipend 4, order 4 | 78 (12) | 1 | 5 (3) | 8 | 7 (0) | arbeitet 1/2 | 6 | ✓ | 100 | offen |
| 62 | 78 | village 17, alms 1, apprentice 3 | tip 2, order 4, village_sale 3, stipend 4 | 70 (9) | 1 | 6 (3) | 10 | 8 (1) | arbeitet 1/2 | 7 | ✓ | 100 | ✓ |

*Münzfluss:* Start gemessen 48 / 60 (W1-Notiz 10). Die §10-Spannen (für Start ≈ 60/71 geschrieben) prüft der Test relativ zum gemessenen Start. Kein Datenwert geändert (`tip_cap_day` bleibt, s. E8-2).

## 4. Save-Fuzzer

`tests/integration/test_save_fuzzer.gd`: neu `test_fuzz_v7_real_mid_phase8_save` – ein echter v7-Stand mitten im Bogen (`kindly8` drei Tage ab dem Phase-7-Endstand: Jakob eingestellt und bei der Arbeit, Wünsche offen, Freundschafts-Schritte, Gitter, Münzen auf dem Stein; dann 10:30 an Tag 56 mit Besuchern unterwegs und einem Räuber-Ziel für die Nacht) durch die JSON-/Native-Schicht, 60 Pfad-Mutationen der Phase-8-Knoten und 6 gezielte Widersprüche (zweiter Wunsch auf einem Grab, mehr als `max_open`, Plan eines späteren Tages, `disturbed`/Gitter auf allen Gräbern, Jakobs Stufen als Text, unbekannte Bewohner/Gräber). Zusätzliche Prüfungen nach jedem Laden (`_check_consistent`): `disturbed` nur auf belegten Gräbern, kein Gitter auf EMPTY, ≤ `max_open` offene Wünsche, ein Wunsch je Grab, nur bekannte Gräber, Plan-Tag ≤ heute. Ergebnis: 91 geladen / 20 abgewiesen, kein halb angewandter Zustand. Der erste Lauf (vor QA8-17) brach mit 539 Engine-Fehlern ab – alle QA8-17; der zweite fand `bool(…)` auf verdorbenen Besuchs-Flags (`Visitors._reapply_schedules`, `_advance` – QA8-20, behoben). Die Kette v1 → … → v7 läuft über alle Fixtures.

## 5. Performance (§9)

| Größe | Budget | Gemessen | |
|---|---|---|---|
| Kamera-Dreiecke Lichtgang-Übersicht (Spiel-Zoom 22, `perf_p8_03`) | < 500 k | 444 k (229 k + Gras 216 k) | ✓ |
| Friedhof Tag mit Jakob + 2 Besuchern (`perf_p8_01`) | – | 349 k, 308 Draw Calls | ✓ |
| Draw Calls Friedhof Alltag / Lichtgang | ≤ 650 / ≤ 750 | 308 (Tag), 391 (Nacht mit Räuber und Kerzen, `perf_p8_02`), 319 (Lichtgang) | ✓ |
| Lichter sichtbar / Schatten | ≤ 25 / ≤ 4 | ≤ 13 / ≤ 2 | ✓ |
| Gaststube Kathreintanz (`perf_p8_04`) / Dorf nachts mit Krankenlicht (`perf_p8_05`) | – | 71 k / 22 DC · 120 k / 119 DC | ✓ |
| Phase-8-Skriptanteil je Frame (direkt: Tick-Handler je Spielminute / 30 + `_process` der Phase-8-Systeme und -Figuren; `graveyard_shots_phase8.gd --cpu-micro`) | Tag ≤ +0,2 · Lichtgang ≤ +0,5 · Dorf ≤ +0,1 ms | Tag **0,29** · Lichtgang **0,54** · Dorf **0,17** ms | ✗ knapp, s. P8-1 |
| Frame-Spitzen headless (`perf_probe_run.gd`, gleicher Lauf wie Phase 7) | kein neuer Ausreißer | Besuch 13 ms, Lichtgang-Beginn 34, Kerzen 38, Dorf am Fest 31, Gaststube 65 (= `room_inn` 65 ohne Fest), zurück 62 (`region_back` 50) | ✓ |
| Web (Chromium + SwiftShader, Compatibility, Debug-Export `--perf-probe`) | kein Frame > 50 ms über dem Normalframe | Normalframe im Container 2,3–2,8 s; Besuch 2,6 s, Lichtgang 2,3 s, Kathrein 2,1 / 1,8 s – keiner über dem Leerlauf (Phase-7-Raumwechsel 3,0–3,6 s) | ✓ (relativ) |
| Spielstand / Laden | < 400 kB / < 1 s | 258–268 kB / 0,49–0,52 s (inkl. Weltwechsel) | ✓ |

Der Frame-Zeit-Vergleich an/aus (`--cpu`, gepaarte Proben) war in der Cloud nicht aussagekräftig (Wirt schwankt 11–19 ms zwischen gleichen Proben); deshalb die direkte Messung. Rohdaten: `qa_cpu_p8.txt`.

## 6. Bilder

Siehe `README` im Gate-Bericht / Kontaktblatt `p8_contact_sheet_final.jpg`. Neu gerendert nach allen Fixes (1280 × 720, echter Renderer): Friedhof `p8_02…p8_27`, `p8_vis_*`, `perf_p8_01…03`; Dorf `p8_14…p8_20`, `p8_28`, `perf_p8_04/05`; UI `ui_p8_*`; Compatibility-Renderer `p8_08_web`, `p8_12_web`, `p8_22_web`.

## 7. G8 Runde 1 – Benutzerentscheidungen umgesetzt (Branch `vs/g8-balance`)

Der Benutzer hat die vier offenen Punkte freigegeben („die 4 offenen Punkte kannst du alle machen"). Vertrag: `docs/PHASE8_DESIGN.md` „(G8 Runde 1 angepasst)", Regressionstests `tests/unit/test_g8_round1.gd`, `tests/integration/test_g8_round1.gd`, `test_ui_phase8.gd` (Woher-Zeile), Bot-Grenzen `test_phase8_playthrough.gd`.

| Punkt | Umsetzung | Werte alt → neu |
|---|---|---|
| E8-1 Licht | bestätigt, nichts geändert | – |
| B8-1 Besuche | Haushalte warten nach dem Ansehen **immer** auf ein Wort, bis 100 Min, nie über 16:30, 3 Min nach dem Gespräch gehen sie; Bewohner 18 Min (Theres bleibt bis 15:30, Liesel bis 12:00); die Figur bleibt jetzt auch wirklich am Grab stehen (vorher lief sie nach dem Ansehen weg, während Visitors „wartet" meldete); **Torglocke** am östlichen Torpfeiler (`ph_prop_gate_bell`, `GateBell`, Cue `gate_bell`), HUD „Am Tor läutet es – {Name} kommt herauf." nur auf dem Friedhof | `wait_minutes` 10 → 100 · neu `wait_min_minutes` 10, `wait_until_minute` 990, `wait_minutes_villager` 18, `leave_after_talk_minutes` 3, `wait_always` true, `bell_cue` gate_bell · Theres-/Liesel-Besuch 910 → 930 / 640 → 720 (`build_phase8_schedules.py`) |
| E8-2 Münzen | Pflegegeld nach Bedarf: ab `p8_open` bleibt es an Tagen mit ≥ 80 Münzen (Beutel + Truhen + Lohndose) in der Gemeindekasse (Notiz von Fenner); Phase-3-Staffel unverändert | neu `ReputationConfig.stipend_purse_cap` 80, `stipend_cap_flag` p8_open |
| B8-3 Trinkgeld Anatom | Gerede dorfweit: jedes Trinkgeld −1, sobald je ein Präparat verkauft wurde | neu `VisitorConfig.rumor_tip_malus` 1, `rumor_stat` specimens_sold |
| B8-2 Vase | Wunschtext nennt die Werkbank, die Wunschkarte zeigt „Woher: Grabvase: an der Werkbank (15 Min) aus 1 Stein und 1 Samen – Samen gibt es bei Theres im Krämerladen. Dann im Baumodus [B] dicht ans Grab stellen." | neu `WishData.source_text`; `w_vase.ask_text` |

Bot vorher (G8 Runde 1-Abgabe) → nachher (10 Tage; `founder8` bis zum Kapitel):

| Strategie | Kapitel (Tag / B) | Münzen Start → Ende (Δ) | morgens min. | Besuche verpasst | Trinkgeld | Pflegegeld |
|---|---|---|---|---|---|---|
| kindly8 | 62 / B10 → 62 / B10 | 48 → 70 (+22) → 48 → 68 (+20) | 24 → 24 | 10 von 19 (53 %) → **1 von 19 (5 %)** | 10 → 10 | 40 → 40 |
| anatomist8 | 61 / B8 → 61 / B8 | 60 → 126 (+66) → 60 → 103 (**+43**) | 49 → 47 | 10 von 20 → 1 von 20 | 12 → **5** | 40 → 24 |
| night8 / night8b | 61 / B9 → 61 / B9 | 48 → 113 (+65) → 48 → 101 (**+53**) | 28 → 28 | 10 von 19 → 1 von 19 | 10 → 10 | 40 → 28 |
| lazy8 | – → – (gewollt) | 48 → 170 (+122) → 48 → 140 (**+92**) | 48 → 48 | 3 von 17 → 1 von 17 | 0 → 0 | 40 → 8 |
| founder8 | 63 / B16 → **60 / B13** | 52 → 41 (−11) → 52 → 57 (+5) | 47 → 52 | 17 von 30 → 3 von 24 | 5 → 11 | 64 → 36 |
| save_load8 | = kindly8 | = kindly8 (zeilengleich) | | | | |

- `night8` liegt mit +53 knapp über +50: Er kauft kein Gitter und keine Kerzen (die Nachtwache ersetzt sie – `kindly8` kauft dafür drei Gitter, ≈ 28 Münzen) und hat nur an drei Morgen ≥ 80. Eine Grenze von 76 träfe auch `kindly8` (morgens bis 75) – deshalb 80 und „grob im Band".
- `lazy8` bleibt absichtlich höher: kein Lohn, keine Kerzen, Setzlinge oder Gitter; die Gemeinde zahlt ihm ab 80 Münzen nichts mehr (−32), er verdient aber weiter an Begräbnissen und Aufträgen aus Phase 5–7.
- `founder8` endet unter +15, weil er baut und kauft (Dorf 117) – morgens nie unter 52, Kapitel früher als vorher (die wartenden Besucher bringen die Wünsche schneller).
- Bild Torglocke: `docs/reviews/phase8_round2/torglocke.jpg` (`graveyard_shots_phase8.gd --shots=g8`).
