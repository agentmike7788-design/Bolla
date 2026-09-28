# Phase 5 – QA-Playthrough, Befunde, Art-/Ton-Prüfung, Performance (W3)

Stand: Branch `vs/p5-qa` (auf `fe842e1`). Vertrag: `docs/PHASE5_DESIGN.md` (§14 Benutzerentscheidungen: Stationen neben der Hütte, Jahreszahl 1834; W0-Notizen). Phase-5-Code = Diff `69f8d49..fe842e1`.

## 1. Befunde (adversariales Review)

Jeder Befund hat einen Regressionstest in `tests/integration/test_phase5_qa.gd` (QA5-01…04 vor dem Fix rot gemessen; QA5-05…10 mit gemessenem Vorher-Wert, siehe Spalte).

| ID | Schwere | Befund | Behoben | Test |
|---|---|---|---|---|
| QA5-01 | mittel | `Workshop.build` buchte die Baukosten an `GameState.note_coins_spent` vorbei (eigenes `add_stat` + `coins_spent.emit`): `coin_ledger()` zeigte nie „Bau“ – Tageszusammenfassung und Kapitel-Panel („Ausgaben nach Zweck“) waren um 50 Münzen zu niedrig. | ✅ `GameState.note_coins_spent(build_coins, &"build")` | `test_build_costs_go_into_the_coin_ledger` (vorher: build 0 statt 15) |
| QA5-02 | klein | `Stonemasonry.carve` entnahm das Material Posten für Posten; scheiterte eine Entnahme mittendrin, blieben die ersten Posten weg (plus Engine-Fehler). | ✅ atomar mit Schnappschuss/Wiederherstellung, Warnung statt Fehler | `test_carve_takes_the_material_atomically` (vorher: 4 Stein weg) |
| QA5-03 | klein | `GravePlot` wertete „Stein setzen“ über die Qualitätsdifferenz: Bei einem voll beraubten, verfallenen Toten bleibt die Qualität auf 0 geklemmt – der Stein stand, aber „Der Stein passt hier nicht mehr.“ erschien. | ✅ Erfolg = der Stein hat die Ablage verlassen und steht am Grab | `test_setting_a_stone_on_a_clamped_grave_reports_no_failure` |
| QA5-04 | klein | Ein niedrigeres Werkzeug neben einem besseren am Gürtel (Eisenschaufel bei Meisterschaufel) meldete `tool_tier_changed(shovel, 1)` und „Graben dauert jetzt 50 statt 60 Minuten.“ – falsch. | ✅ Signal + Wirkungs-Notiz nur, wenn die Stufe steigt; sonst „… hängt jetzt am Gürtel.“ | `test_lower_tool_announces_no_tier_change` |
| QA5-05 | Art | Am Bruch: die 8 Kantenstücke der Ostkante zeigten der Kamera ihre **Rückseite** (Front nach Osten, `rot_y 75…100`) – 1,2 m tiefe Grasdecke = „hohe grasbedeckte Blöcke“; Findlinge = glatte Kugeln. | ✅ Kantenstücke um 180° gedreht (Felsfront nach Westen in den Bruch), Kantenstück mit zackiger Oberkante aus Kluftblöcken, nackter Fels mit Moos in den Fugen, lose Blöcke obenauf, dunklere Schutthalde; Findling mit 10 Spaltflächen (gebrochene Facetten), Riss, Flechten, Moos in Flecken. Stil, Material, Shader unverändert. | `test_quarry_edges_face_into_am_bruch_and_the_boulder_is_faceted` (Facettenanteil 0,12 → ≈ 0,28; Gras auf der Kante 0,36 → 0,00); Bilder `qa_bruch_before_after.jpg`, `qa_quarry_before_after.jpg` |
| QA5-06 | Art | Schlag: Stumpf und Stockausschlag standen hinter Waldkronen und hinter den Kronen der anderen Erlen (`gather_alder_4`: 6 % sichtbar, `_1` 56 %, `_2` 61 %). | ✅ Erlen versetzt (bis 4,7 m, im Schlag westlich des Kutschwegs, keine Krone 1–9 m südlich innerhalb 2,8 m): alle 5 zu 100 % sichtbar von der Spielkamera | `test_alder_stages_are_seen_from_the_gameplay_camera`; Bild `qa_schlag_before_after.jpg` |
| QA5-07 | Art | Kaminrauch der Esse bei Tag kaum lesbar: von oben liegt er über dem olivgrünen Gras, unbeleuchtetes Mittelgrau `#8E8478` ging darin unter. | ✅ helles Warmgrau `#C2BAAE`, **beleuchtet** wie die Welt (bei Tag hell, nachts gedämpft statt leuchtend), breitere Puffs (2,0 / 1,6 m), die sich beim Aufsteigen weiten (→ 1,35); **weiter 3 + 3 Partikel** | `test_workyard_smoke_reads_by_day_within_the_budget` |
| QA5-08 | UI | Der Gürtel-Tooltip (Schaufel/Axt/Spitzhacke, 5 Zeilen) lag über der Reihe der Pflegewerkzeuge; Namen „Eisenscha…“, „Alte Spitz…“ abgeschnitten. | ✅ Wirkung als feste Infozeile unter dem Gürtel (beim Zeigen), Pflegewerkzeuge behalten ihren kurzen Tooltip; Namen in 18 px, Symbol 34 px → volle Namen | `test_belt_effect_shows_in_the_panel_not_over_the_care_tools`; Bild `qa_belt_before_after.jpg` |
| QA5-09 | Art | Inschriften bei 10 m: lange Einzeilen-Namen durch `label_width` klein (z. B. „Cornelius Kornblum“ ≈ 0,047 m Buchstaben ≈ 6 px). | ✅ Name in zwei Zeilen (Vor-/Nachname, nur Darstellung, Text im Stein unverändert), wenn er sonst unter 0,07 m fiele und der Stein ≤ 4 Zeilen behält; `label_width` Stele 0,50 → 0,54, Rundbogen 0,55 → 0,58 (Schriftfeld 0,58 / 0,64 m) | `test_long_name_is_set_in_two_larger_lines`; Bild `qa_inscription_before_after.jpg` |
| QA5-10 | Art | Die fertigen Steine in der Ablage der Steinmetzbank zeigten der Kamera ihren Rücken (Inschrift unsichtbar). | ✅ Fronten zur Spielkamera (Süd), leicht zur Bank gedreht | `test_rack_stones_face_the_gameplay_camera` |
| QA5-11 | Ton | Abschluss-Panel „Namen in Stein“: Zeile „Ausgaben (Phase 5)“ – Entwicklerbegriff. | ✅ „Ausgaben seit dem Werkhof“ | `test_calendar_1834_and_chapter_texts` |

**Geprüft ohne Befund** (Tests: `test_phase5_qa.gd` „Prüfung“, Bot, Fuzzer, Besitzer-Tests):
- Speichern/Laden: mit brennendem Meiler (Ende aus `end_total`, fertig → „[E] Holzkohle holen (3)“), **Meiler fertig → speichern → holen → laden: genau eine Ladung**, zwei Steine in der Ablage (Text bleibt festgeschrieben), Erle im Stumpf-/Schössling-Stadium, nach dem Kapitel (`test_phase5_loop` + Bot `save_load5` bitgleich). **Mitten im Hauen:** das Hauen ist nicht abbrechbar (Laufen bricht es nicht ab), Speichern ist gesperrt (`can_save` false), Material wird erst am Ende genommen; ein Laden mitten im Hauen hinterlässt keinen Stein und kein fehlendes Material (`test_carve_from_the_panel_is_robust`).
- Migration v3→v4 und älter: 6 v3-, 4 v2-, 3 v1-Fixtures laden (Kette 1→4), Gürtel-Migration (Werkzeug aus Slots an den Gürtel, Truhe unverändert, zweites Stück bleibt im Slot – nichts verloren), `design {}`, leere Phase-5-Knoten, Zier im Werkhof → Truhe (Überlauf ins Inventar, Rest offen bis Platz ist).
- Exploits: kein Rückerstatten beim Bau (atomar am Ende, Station nicht abreißbar); Meiler höchstens ein Auftrag, Holen nur einmal (auch über Speichern/Laden); Nachwachsen aus der Tageszahl, idempotent – Zeitsprung über 3 Tage und Schlaf füllen genau auf `charges_max`, ein Laden am selben Tag gibt nichts dazu; Münzbuch ohne Doppelzählung (Summe der Zwecke = `stats.coins_spent`, im Bot zusätzlich Start + Einnahmen − Ausgaben = Ende); Alte Spitzhacke einmalig (Flag), gleiches Werkzeug zweimal am Gürtel unmöglich (`can_add` → Rezept gesperrt); Stein setzen zahlt nur bei FILLED, MARKED nie; `master_stone` +3 genau einmal je Grab (auch bei besserem zweitem Meisterstein).
- Routen: W2-Flood-Fill (1,5 m) für Werkhof unverändert grün; neu: Am Bruch und Steinbruch mit der Kapsel des Totengräbers vor und nach den Findlingen – alle Sammelstellen, `tp_bruch`, `tp_quarry` hängen an der Ostpforte, keine Falle (`test_am_bruch_and_quarry_are_never_a_trap`).
- Kapitel `names_in_stone`: in allen 6 Bot-Strategien genau einmal, jede Reihenfolge der drei Bedingungen (Station, Werkzeug, Meisterstein zuletzt) löst es aus.
- Pietät-Fix §2.9: Phase-4-Bot `mixed` mit `prep_on_harvest`: 17 hergerichtet (8 davon verwertet), nur 9 `full_prep`-Ereignisse, Pietät 13 „Sachlich“.
- Signale/Warnungen: **keine Warnung und kein Fehler** in 6 Strategien × 10–30 Tagen Normalspiel (Logger im Test).
- Texte: alle neuen deutschen Texte (Stationen, Sammelstellen, Werkstoffe, Werkzeuge, Inschriften, Zierden, Osric `p5_*`, Ilse Blattgold, Geisterzeilen `nameless`/`by_design`, Panels) ohne Tippfehler; Kalender 1834 geprüft (Tag 1 = 3. Gilbhart 1834, Tag 30 = 1. Nebelung, Tag 60 = 1. Julmond, Tag 91 = 1. Hartung 1835); Osric nennt den Bruch in genau einem Satz „Lorenz' alter Werkplatz“ (§14.4).

## 2. Offene Punkte / Entscheidungen für den Benutzer

- **E1 Erlen versetzt (Vertrag §4.3 erlaubt ±0,6 m):** für QA5-06 um bis zu 4,7 m verschoben (`gather_alder_1` (−6,2|16,4) → (−6,9|15,6) · `_2` (−10,4|15,8) → (−10,4|15,6) · `_3` (−7,6|20,4) → (−4,0|17,4) · `_4` (−10,6|21,2) → (−8,8|24,0) · `_5` (−5,4|24,2) → (−5,0|24,6)); alle im Schlag westlich des Kutschwegs, Bäume und Büsche unverändert. Bitte bestätigen.
- **E2 Kantenstücke der Ostkante gedreht** (Layout `quarry_edges`, rot_y + 180°) – nur Am Bruch, keine freigegebene Fläche berührt.
- **E3 Inschriften:** lange Namen werden auf zweizeilig gesetzt (nur Darstellung); dadurch 70 statt 56 `Label3D` bei 18 Inschriften (+14 statische Labels, +≈ 18 Draw Calls im Motiv `perf_p5_03`: 284, Budget < 1 000). `label_width` Stele/Rundbogen etwas breiter.
- **E4 Kapiteltempo:** Der Bot erreicht „Namen in Stein“ vom Phase-4-Endstand in **4 Tagen** (Tag 24; Vertrag §1.4 rechnet mit 7, Grenze ≤ 28), im neuen Spiel an Tag 20 (Grenze ≤ 30). Ein Mensch braucht länger (Wege, Planen); die Zahlen liegen im Vertrag. Nicht geändert.
- **E5 Verwertender Weg bleibt reich:** `harvester5` endet mit **102** Münzen (§2.8 rechnet mit ≈ 70–80, Test „≥ 60“ ist ein dokumentierter Befund, kein Fehler): nur Pflichtausgaben (102), kein Gold. Vorschlag für später: Münzsenke im Dorf (Phase 7/10) – in Phase 5 keine Datenänderung.
- **E6 Nicht-deterministischer Asset-Export:** `ph_env_workstone_ledge.glb` ändert beim Neubau von `asset_env_phase5` jedes Mal die Bytes (ohne Code-Änderung); zurückgesetzt, nicht Teil dieses Stands. P5 sollte den Zufall dort an `L.reset` binden.
- **CPU-Budget 1,5 ms:** siehe §6 – in diesem Container nicht messbar genau; Phase 5 ist im Rauschen nicht zu sehen.

## 3. Playthrough-Bot Phase 5

Bot: `tests/integration/phase5_bot.gd` (erweitert `Phase4Bot`) · Test: `tests/integration/test_phase5_playthrough.gd` (Einzelstrategie: `P5QA_ONLY=reverent5,…`).
Der Bot spielt die echte Welt über die Entitäten mit `instant_actions`: Osric über den **echten `DialogueRunner`** (`carter.tres`: `p3_intro` → `p4_intro` → `p5_intro` je ein Gespräch, dann Brief, Alte Spitzhacke, Stahlstäbe, Beschläge – `take_item:coin` bucht ins Münzbuch), Ostpforte, Sammelstellen (`GatherNode.interact`), Findlinge, Bauplätze über das **Bauplatz-Panel** („Bauen“), Stationen über `Workbench.interact/request_craft` (Meiler, Barren, Beschläge, Werkzeug in Kettenreihenfolge, Garn/Totenhemd, Tinte, Räucherkräuter), „[E] Holzkohle holen“, Steine über das **echte Stein-Panel** (Grab, Form, Inschrift – passende zuerst –, Zierde, Gold → „Stein hauen“) und „[E] Gestalteten Stein setzen“ am Grab, Blattgold nachts bei Ilse. Phase-3/4-Käufe bei Osric laufen wie der Dialog über `GameState.note_coins_spent` (vollständiges Münzbuch).

Geprüft je Strategie: keine Engine-Fehler, **keine Warnungen**, keine Bot-Probleme (jede gewollte Handlung möglich → kein Softlock), Qualität 0…380, Ruf 0…100, Pietät −100…100, Münzen ≥ 0; **Münzbuch:** Summe der Zwecke = `stats.coins_spent` und Start + Einnahmen − Ausgaben = Ende.

| Strategie | Start | Tage | Verhalten | Erwartung (§10) | Ergebnis |
|---|---|---|---|---|---|
| reverent5 | v3 `day20_reverent` | 10 | Bogen A, Gold für 3 Steine, Meisterschaufel/-axt, alle Gräber neu | Kapitel ≤ 28, Ausgaben ≥ 100, Ende 10–45, früh nie < 10 (≈ 15), ≥ 6 neu gesetzt | ✅ Kapitel **Tag 24**, Ausgaben **138** (84 % von 165 verfügbar), Ende **27**, niedrigster Morgen **17**, 11 Steine (5 Meistersteine, 3 vergoldet) |
| toolsmith | v3 `day20_reverent` | 10 | erst alle Werkzeuge auf Stufe 2 | alle Stufe 2 bis Tag 25, Minuten = §2.3, Kapitel ≤ 29 | ✅ Stufe 2: Hacke 23, Schaufel 23, Axt **25**; 9 gemessene Minutenwerte = Tabelle §2.3; Kapitel Tag 26; Ende 39 |
| mender | v3 `day20_mixed` | 10 | Meistersteine zuerst für beraubte Gräber | zufriedene Geister +≥ 3; kein voll beraubter zufrieden | ✅ zufrieden **10 → 17**; Kapitel Tag 24; Ende 41 (in `mixed` wurde nur Haar genommen – kein voll beraubtes Grab) |
| harvester5 | v3 `day25_harvester` | 10 | Pflicht, kein Gold | Kapitel; Ende ≥ 60 (Befund); voll Beraubte bleiben unruhig | ✅ Kapitel Tag 29; Ende **102** (E5); alle **14** voll beraubten Geister nicht zufrieden |
| crafter | neues Spiel | 30 | würdevoll + Phase 5 ab `workshop_open` | `six_pits` ≤ 22, Kapitel ≤ 30, Ausgaben ≥ 100, Ende 15–80, ≥ 4 Totenhemden vom Webstuhl | ✅ `six_pits` Tag 19, `workshop_open` Tag 13, Kapitel **Tag 20**, Ausgaben Phase 5 **165**, Ende **53**, **4** Webstuhl-Totenhemden, niedrigster Morgen ab Werkhof 15 |
| save_load5 | wie reverent5 | 10 | lädt jeden Morgen | bitgleich zu reverent5 | ✅ alle 10 Tageszeilen identisch |

**Münzbuch** (Start · Einnahmen nach Quelle · Ausgaben nach Zweck · Ende):
- reverent5: 125 · +40 (Pflegegeld 40) · −138 (Brief 20, Bau 50, Osric 50, Ilse 18) · **27**
- toolsmith: 125 · +40 (Pflegegeld) · −126 (Brief 20, Bau 50, Osric 56) · **39**
- mender: 123 · +56 (Pflegegeld 40, Geistergaben 16) · −138 (Brief 20, Bau 50, Osric 50, Ilse 18) · **41**
- harvester5: 178 · +26 (Pflegegeld) · −102 (Brief 20, Bau 50, Osric 32) · **102**
- crafter (Tag 1–30): 5 · +342 (Bestattungen 198, Pflegegeld 105, Gaben 39) · −294 (Osric 139, Ilse 85, Brief 20, Bau 50; davon ab Werkhof 165) · **53**

**Gegen §2.8:** Die Pflichtsumme 108 und die Verteilung stimmen (reverent5 gibt 138 aus, Vertrag 138; Ende 27 statt ≈ 19, weil der Bot das Gold und die Meisterwerkzeuge früher kauft und die letzten Tage nichts mehr braucht). Der würdevolle Spieler gibt den größten Teil aus und fällt morgens nie unter 17.
Phase-3-Bot (6 Strategien) und Phase-4-Bot (5 Strategien, `mixed` mit `prep_on_harvest`) unverändert grün.

**Balancing:** keine Spielwerte geändert (die Bot-Ergebnisse liegen in den Vertragsgrenzen; E4/E5 sind Beobachtungen).

## 4. Save-Fuzzer

`tests/integration/test_save_fuzzer.gd` + `test_fuzz_v4_real_mid_phase5_save`: ein **echter v4-Stand mitten in Phase 5**, von `Phase5Bot` (reverent5, 4 Tage ab `day20_reverent`) erspielt und über die echten Entitäten inszeniert: Meiler brennt, Ablage 2/3 (über das Stein-Panel gehauen), Erlen in gemischten Stufen, Werkzeuggürtel voll. Abgeschnittene Dateien, JSON- und native Mutationen plus 60 gezielte Mutationen der Phase-5-Teile (`workshop`, `gathering`, `stonemasonry`, `design`, `tools`, Münzbuch, Flags). Ergebnis: **97 geladen, 33 abgelehnt**, jeder Ausgang einer der zwei erlaubten (abgelehnt mit Meldung und unverändertem Spiel, oder geladen und stabil nach Speichern → Laden). Neu in der Konsistenzprüfung: Ablage ≤ 3 und höchstens ein Stein je Grab, nur bekannte Stationen, Ladungen 0…`charges_max`, Gürtel 1…`max_stack` – **kein halb angewandter Zustand**. Alle v3/v2/v1-Fixtures weiter gefuzzt (v3 119/91, v2 205/147, v1 298/230).

## 5. Art-/Ton-Prüfung

Vorher/Nachher (links W2, rechts W3): `qa_bruch_before_after.jpg`, `qa_quarry_before_after.jpg`, `qa_schlag_before_after.jpg`, `qa_smoke_before_after.jpg`, `qa_belt_before_after.jpg`, `qa_inscription_before_after.jpg` (Ablage QA5-10: `world_p5_08_mason_rack.jpg`).
- **Am Bruch (QA5-05):** Die Ostkante liest sich als zerklüftete Bruchwand mit gestuften Kluftblöcken, die Findlinge als verwitterte, gespaltene Blöcke mit Moos in Flecken (Facettenanteil 0,12 → ≈ 0,28). Gleiche Materialien, Maler-Shader unverändert, Budgets: Kante 846 Dreiecke (≤ 1 500), Findling 520 (≤ 1 200).
- **Schlag (QA5-06):** Stumpf mit heller Schnittfläche und Stockausschlag stehen frei vor dem Waldrand (100 % sichtbar von der Spielkamera).
- **Rauch (QA5-07):** Kamin- und Meilerrauch hell und beleuchtet, breiter, weiter 3 + 3 Partikel; Motiv `perf_p5_02` 54 Partikel (≤ 60).
- **Gürtel (QA5-08), Inschriften (QA5-09), Ablage (QA5-10), Kapitel-Text (QA5-11):** siehe §1.
- Glut: warm, ohne Schatten; Blattgold warm, nachts nicht leuchtend (Motiv `world_p5_15b`).

## 6. Performance (Phase 4 gegen Phase 5, gleiche Inszenierung, dreimal hintereinander)

Messung headless, `TIME_PROCESS` je Frame (Median), Container mit Nachbarlast. **P4-Build** = `69f8d49` (Export), **P5-Build** = dieser Stand.

| Runde | P4-Build · P4-Probe Tag / Nacht | P5-Build · P4-Probe Tag / Nacht | P5-Build · P5-Probe an Tag / Nacht | P5-Probe aus Tag / Nacht |
|---|---|---|---|---|
| 1 | 3,98 / 4,52 | 3,99 / 3,19 | 4,31 / 4,66 | 3,60 / 4,64 |
| 2 | 3,30 / 4,52 | 4,23 / 3,83 | 4,51 / 4,66 | 5,15 / 6,90 |
| 3 | 4,21 / 3,65 | 4,80 / 5,22 | 3,45 / 3,73 | 4,05 / 3,82 |
| Mittel | 3,83 / 4,23 | 4,34 / 4,08 | 4,09 / 4,35 | 4,27 / 5,12 |

- **Delta P5 − P4 (gleiche P4-Inszenierung):** Tag +0,51 ms, Nacht −0,15 ms – das Vorzeichen wechselt, die Streuung einer Messung ist ±1 ms. Phase-5-Teile an/aus im selben Build: −0,18 / −0,77 ms. **Kein messbarer Phase-5-Anteil** in diesem Container; §9 (≤ +0,2 ms) ist hier weder zu belegen noch zu widerlegen.
- Strukturell: Phase 5 bringt **kein neues `_process`** (Sammelstellen, Stationen, Ablage, Meiler reagieren nur auf Signale; `Workshop` und 3 `BuildSite` je Spielminute ein `time_tick`), 70 statische `Label3D`, 6 Partikel. Deshalb keine Optimierung nötig. Bitte am Benutzer-PC messen (`--cpu`).
- Rendern (Motive `perf_p5_*`, 1280×720): Kamera-Dreiecke ≤ 455 k (< 500 k), Draw Calls ≤ 334 (< 1 000), Schattenlichter 2 (≤ 4), Partikel ≤ 54 (≤ 60). Spielstand 108 kB, Laden 243–283 ms.

## Tests

Vollständige Suite am Ende dreimal hintereinander: **1748 / 1748 grün** in allen drei Läufen (RESULT: PASS; je ≈ 900 s). Basis vor W3: 1725; neu 16 (`test_phase5_qa`) + 6 (`test_phase5_playthrough`) + 1 (Fuzzer v4 echt).

## 7. Screenshot-Satz Gate G5 (`docs/reviews/phase5_round1/`, 1280×720, echte Phase-5-Welt)

Welt: `graveyard_shots_phase5.gd --jpg` (Bühnen über die echten Systeme); UI: `ui_screenshots.gd --phase5` – der Regisseur nutzt jetzt den echten Bauplatz `site_forge` und zeigt gebaute Stationen in der Welt (`refresh_built`). Alle Bilder angesehen; behoben dabei: Ablage-Steine zeigten den Rücken (QA5-10), Stationen fehlten hinter den UI-Panels, Schlag-Motiv gerahmt auf die drei Erlen-Stufen, Gürtel-Namen gekürzt → voll.

| Datei | Motiv |
|---|---|
| `world_p5_00a_hof_before.jpg` | Alter Hof vorher (Build `69f8d49`, W2-Render derselben Kamera) |
| `world_p5_00b_hof_sites.jpg` | Alter Hof nachher, Bauplätze leer (Holzhaufen versetzt) |
| `world_p5_00c_hof_built.jpg` | Werkhof gebaut: Webstuhl, Steinmetzbank mit 2 Steinen, Esse, Rauch |
| `world_p5_08_mason_rack.jpg` | Ablage an der Steinmetzbank nah – Inschriften lesbar |
| `world_p5_03_workyard_forge_day.jpg` · `_03b_workyard_evening.jpg` | Werkhof bei Tag / am Abend (Glut, Rauch) |
| `world_p5_04_workyard_night.jpg` · `_04b_loom.jpg` | Werkhof nachts mit Esse-Glut und Geistern · Webstuhl |
| `world_p5_01_overview.jpg` | Übersicht: Friedhof, Werkhof, Am Bruch mit offener Ostpforte |
| `world_p5_02_am_bruch.jpg` | Am Bruch: Findlinge, Flachs, Felskante |
| `world_p5_05_quarry_open.jpg` | Steinbruch offen: Erz, Werkstein, Bruchstein |
| `world_p5_06_schlag_alders.jpg` | Schlag: Erle als Baum, Stumpf, Stockausschlag |
| `world_p5_07_flax_herbs.jpg` | Flachs reif / gerauft, Kräuterrain, Lehmkuhle |
| `world_p5_15_graves_stones.jpg` · `_15b_elder_stones_night.jpg` | gestaltete Steine an den Gräbern (Spiel-Zoom 12 m) · Holunderwinkel nachts |
| `ui_stone_zoom10.jpg` | Meisterstein vergoldet + Stele bei 10 m (zweizeiliger Name) |
| `ui_build_site.jpg` | Bauplatz-Panel Esse (etwas fehlt) am echten Bauplatz |
| `ui_stone_design.jpg` | Stein-Panel mit 3D-Vorschau: Marthe Quendel, passende Inschrift, vergoldet, Holunderdolde, Grab 10 → 16 |
| `ui_stone_rack.jpg` | Ablage 2/3, „passt nicht mehr – Wirklich verwerfen?“ |
| `ui_loom.jpg` · `ui_forge_kiln.jpg` · `ui_forge_tools.jpg` | Webstuhl · Esse mit Meiler („fertig um 14:20“) · Werkzeug-Rezepte mit Wirkung |
| `ui_tool_belt.jpg` | Inventar mit Werkzeuggürtel und Wirkungszeile |
| `ui_osric_p5.jpg` | Osric `p5_intro` – „Lorenz' alter Werkplatz“ |
| `ui_trade_gold.jpg` | Ilse: Blattgold im Laden |
| `ui_hud_chapter.jpg` | HUD-Tooltip mit „Werkhof 3/3 · Werkzeug 1/3 · Meisterstein 0/1“ |
| `ui_chapter_names_in_stone.jpg` | Abschluss-Panel „Namen in Stein“ |
| `perf_p5_01…04` + `render_stats.txt` | Budget-Motive (Bruch Tag, Werkhof nachts mit Verfall, 18 Inschriften, Werkhof Tag) |

## 8. Tag für Tag (Phase-5-Bot)
#### reverent5

`PLAYTHROUGH5 reverent5  chapter5 day 24 (open day 20, six_pits day -1)  start 125 · income 40 (burial 0, stipend 40, gift 0, ilse 0, valuables 0) · spent 138 (license 20, osric 50, build 50, ilse 18) · Phase 5 spent 138 · end 27 · lowest morning 17 (Phase 5: 17)  gathered { &"clay": 21, &"herbs": 9, &"elderberries": 14, &"iron_ore": 27, &"stone": 17, &"workstone": 18 }  stones 11 (gilded 3)  loom gowns 0  tier days { "axe1": 22, "shovel1": 22, "pickaxe2": 23, "shovel2": 24, "axe2": 26 }`

| Tag | Münzen früh | Ausgaben (Zweck) | Münzen abends | Gräber | Qualität | Ruf | Stationen | Werkzeug S/A/P | Steine | Meister | mit Namen | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | 125 | license 20, osric 12, build 25, ilse 12 | 60 | 18 | 243 | 100 | 2 | 0/0/0 | 0 | 0 | 0 | 18 | offen |
| 21 | 60 | osric 20, build 25 | 19 | 18 | 243 | 100 | 3 | 0/0/1 | 0 | 0 | 0 | 18 | offen |
| 22 | 19 | osric 6 | 17 | 18 | 253 | 100 | 3 | 1/1/1 | 2 | 0 | 2 | 18 | offen |
| 23 | 17 | – | 21 | 18 | 253 | 100 | 3 | 1/1/2 | 2 | 0 | 2 | 18 | offen |
| 24 | 21 | osric 6 | 19 | 18 | 258 | 100 | 3 | 2/1/2 | 3 | 1 | 3 | 18 | ✓ |
| 25 | 19 | – | 23 | 18 | 266 | 100 | 3 | 2/1/2 | 5 | 1 | 5 | 18 | ✓ |
| 26 | 23 | osric 6 | 21 | 18 | 267 | 100 | 3 | 2/2/2 | 6 | 2 | 5 | 18 | ✓ |
| 27 | 21 | ilse 6 | 19 | 18 | 274 | 100 | 3 | 2/2/2 | 9 | 3 | 6 | 18 | ✓ |
| 28 | 19 | – | 23 | 18 | 275 | 100 | 3 | 2/2/2 | 10 | 4 | 6 | 18 | ✓ |
| 29 | 23 | – | 27 | 18 | 280 | 100 | 3 | 2/2/2 | 11 | 5 | 7 | 18 | ✓ |

#### toolsmith

`PLAYTHROUGH5 toolsmith  chapter5 day 26 (open day 20, six_pits day -1)  start 125 · income 40 (burial 0, stipend 40, gift 0, ilse 0, valuables 0) · spent 126 (license 20, osric 56, build 50) · Phase 5 spent 126 · end 39 · lowest morning 19 (Phase 5: 19)  gathered { &"clay": 20, &"herbs": 9, &"elderberries": 14, &"iron_ore": 26, &"stone": 17, &"workstone": 15 }  stones 11 (gilded 0)  loom gowns 0  tier days { "axe1": 22, "shovel1": 22, "pickaxe2": 23, "shovel2": 23, "axe2": 25 }`

| Tag | Münzen früh | Ausgaben (Zweck) | Münzen abends | Gräber | Qualität | Ruf | Stationen | Werkzeug S/A/P | Steine | Meister | mit Namen | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | 125 | license 20, osric 12, build 25 | 72 | 18 | 243 | 100 | 2 | 0/0/0 | 0 | 0 | 0 | 18 | offen |
| 21 | 72 | osric 26 | 50 | 18 | 247 | 100 | 2 | 0/0/1 | 1 | 0 | 1 | 18 | offen |
| 22 | 50 | build 25 | 29 | 18 | 255 | 100 | 3 | 1/1/1 | 3 | 0 | 3 | 18 | offen |
| 23 | 29 | osric 12 | 21 | 18 | 255 | 100 | 3 | 2/1/2 | 3 | 0 | 3 | 18 | offen |
| 24 | 21 | osric 6 | 19 | 18 | 255 | 100 | 3 | 2/1/2 | 3 | 0 | 3 | 18 | offen |
| 25 | 19 | – | 23 | 18 | 255 | 100 | 3 | 2/2/2 | 3 | 0 | 3 | 18 | offen |
| 26 | 23 | – | 27 | 18 | 268 | 100 | 3 | 2/2/2 | 6 | 1 | 6 | 18 | ✓ |
| 27 | 27 | – | 31 | 18 | 273 | 100 | 3 | 2/2/2 | 8 | 2 | 7 | 18 | ✓ |
| 28 | 31 | – | 35 | 18 | 278 | 100 | 3 | 2/2/2 | 10 | 3 | 8 | 18 | ✓ |
| 29 | 35 | – | 39 | 18 | 279 | 100 | 3 | 2/2/2 | 11 | 4 | 8 | 18 | ✓ |

#### mender

`PLAYTHROUGH5 mender  chapter5 day 24 (open day 20, six_pits day -1)  start 123 · income 56 (burial 0, stipend 40, gift 16, ilse 0, valuables 0) · spent 138 (license 20, osric 50, build 50, ilse 18) · Phase 5 spent 138 · end 41 · lowest morning 17 (Phase 5: 17)  gathered { &"clay": 23, &"herbs": 9, &"elderberries": 16, &"iron_ore": 27, &"stone": 20, &"workstone": 18 }  stones 11 (gilded 3)  loom gowns 0  tier days { "axe1": 22, "shovel1": 23, "pickaxe2": 23, "shovel2": 25, "axe2": 26 }`

| Tag | Münzen früh | Ausgaben (Zweck) | Münzen abends | Gräber | Qualität | Ruf | Stationen | Werkzeug S/A/P | Steine | Meister | mit Namen | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | 123 | license 20, osric 12, build 25, ilse 12 | 58 | 18 | 210 | 99 | 2 | 0/0/0 | 0 | 0 | 0 | 10 | offen |
| 21 | 58 | osric 20, ilse 6 | 38 | 18 | 215 | 100 | 2 | 0/0/1 | 1 | 0 | 1 | 11 | offen |
| 22 | 38 | build 25 | 19 | 18 | 220 | 100 | 3 | 0/1/1 | 2 | 0 | 2 | 12 | offen |
| 23 | 19 | osric 6 | 17 | 18 | 220 | 100 | 3 | 1/1/2 | 2 | 0 | 2 | 10 | offen |
| 24 | 17 | – | 25 | 18 | 230 | 100 | 3 | 1/1/2 | 4 | 1 | 4 | 13 | ✓ |
| 25 | 25 | osric 6 | 25 | 18 | 234 | 100 | 3 | 2/1/2 | 5 | 1 | 5 | 15 | ✓ |
| 26 | 25 | osric 6 | 25 | 18 | 239 | 100 | 3 | 2/2/2 | 6 | 2 | 6 | 14 | ✓ |
| 27 | 25 | – | 33 | 18 | 250 | 100 | 3 | 2/2/2 | 9 | 3 | 8 | 18 | ✓ |
| 28 | 33 | – | 37 | 18 | 255 | 100 | 3 | 2/2/2 | 11 | 4 | 9 | 17 | ✓ |
| 29 | 37 | – | 41 | 18 | 255 | 100 | 3 | 2/2/2 | 11 | 4 | 9 | 17 | ✓ |

#### harvester5

`PLAYTHROUGH5 harvester5  chapter5 day 29 (open day 25, six_pits day -1)  start 178 · income 26 (burial 0, stipend 26, gift 0, ilse 0, valuables 0) · spent 102 (license 20, osric 32, build 50) · Phase 5 spent 102 · end 102 · lowest morning 82 (Phase 5: 82)  gathered { &"clay": 14, &"herbs": 8, &"elderberries": 14, &"iron_ore": 16, &"workstone": 3 }  stones 7 (gilded 0)  loom gowns 0  tier days { "axe1": 28, "shovel1": 28, "pickaxe2": 29 }`

| Tag | Münzen früh | Ausgaben (Zweck) | Münzen abends | Gräber | Qualität | Ruf | Stationen | Werkzeug S/A/P | Steine | Meister | mit Namen | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 25 | 178 | license 20, osric 12, build 15 | 132 | 18 | 114 | 24 | 1 | 0/0/0 | 2 | 0 | 2 | 2 | offen |
| 26 | 132 | osric 14, build 10 | 109 | 18 | 118 | 31 | 2 | 0/0/1 | 3 | 0 | 3 | 2 | offen |
| 27 | 109 | build 25 | 86 | 18 | 126 | 39 | 3 | 0/0/1 | 5 | 0 | 5 | 2 | offen |
| 28 | 86 | osric 6 | 82 | 18 | 127 | 46 | 3 | 1/1/1 | 6 | 0 | 5 | 2 | offen |
| 29 | 82 | – | 85 | 18 | 129 | 56 | 3 | 1/1/2 | 7 | 1 | 5 | 2 | ✓ |
| 30 | 85 | – | 88 | 18 | 129 | 62 | 3 | 1/1/2 | 7 | 1 | 5 | 2 | ✓ |
| 31 | 88 | – | 91 | 18 | 129 | 68 | 3 | 1/1/2 | 7 | 1 | 5 | 2 | ✓ |
| 32 | 91 | – | 94 | 18 | 129 | 74 | 3 | 1/1/2 | 7 | 1 | 5 | 2 | ✓ |
| 33 | 94 | – | 98 | 18 | 129 | 80 | 3 | 1/1/2 | 7 | 1 | 5 | 2 | ✓ |
| 34 | 98 | – | 102 | 18 | 129 | 86 | 3 | 1/1/2 | 7 | 1 | 5 | 2 | ✓ |

#### crafter

`PLAYTHROUGH5 crafter  chapter5 day 20 (open day 13, six_pits day 19)  start 5 · income 342 (burial 198, stipend 105, gift 39, ilse 0, valuables 0) · spent 294 (osric 139, ilse 85, license 20, build 50) · Phase 5 spent 165 · end 53 · lowest morning 5 (Phase 5: 15)  gathered { &"clay": 30, &"flax": 18, &"herbs": 13, &"elderberries": 22, &"iron_ore": 41, &"stone": 30, &"workstone": 33 }  stones 20 (gilded 3)  loom gowns 4  tier days { "axe1": 17, "shovel1": 18, "pickaxe2": 18, "shovel2": 20, "axe2": 22 }`

| Tag | Münzen früh | Ausgaben (Zweck) | Münzen abends | Gräber | Qualität | Ruf | Stationen | Werkzeug S/A/P | Steine | Meister | mit Namen | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 5 | osric 3 | 12 | 1 | 9 | 26 | 0 | 0/0/0 | 0 | 0 | 0 | 1 | – |
| 2 | 12 | osric 14 | 8 | 2 | 26 | 31 | 0 | 0/0/0 | 0 | 0 | 0 | 2 | – |
| 3 | 8 | osric 9 | 11 | 3 | 37 | 36 | 0 | 0/0/0 | 0 | 0 | 0 | 3 | – |
| 4 | 11 | osric 15, ilse 1 | 9 | 4 | 52 | 45 | 0 | 0/0/0 | 0 | 0 | 0 | 4 | – |
| 5 | 9 | osric 12, ilse 1 | 10 | 5 | 64 | 51 | 0 | 0/0/0 | 0 | 0 | 0 | 5 | – |
| 6 | 10 | osric 12, ilse 1 | 10 | 6 | 78 | 60 | 0 | 0/0/0 | 0 | 0 | 0 | 6 | – |
| 7 | 10 | osric 9, ilse 6 | 11 | 7 | 96 | 67 | 0 | 0/0/0 | 0 | 0 | 0 | 7 | – |
| 8 | 11 | osric 6, ilse 6 | 15 | 8 | 111 | 75 | 0 | 0/0/0 | 0 | 0 | 0 | 8 | – |
| 9 | 15 | osric 3, ilse 7 | 23 | 9 | 123 | 85 | 0 | 0/0/0 | 0 | 0 | 0 | 9 | – |
| 10 | 23 | osric 3, ilse 6 | 33 | 10 | 142 | 91 | 0 | 0/0/0 | 0 | 0 | 0 | 10 | – |
| 11 | 33 | osric 3, ilse 6 | 42 | 11 | 157 | 95 | 0 | 0/0/0 | 0 | 0 | 0 | 11 | – |
| 12 | 42 | ilse 6 | 55 | 12 | 169 | 98 | 0 | 0/0/0 | 0 | 0 | 0 | 12 | offen |
| 13 | 55 | license 20, osric 12, ilse 7 | 35 | 13 | 181 | 100 | 0 | 0/0/0 | 0 | 0 | 0 | 13 | offen |
| 14 | 35 | build 10, ilse 6 | 38 | 14 | 193 | 100 | 1 | 0/0/0 | 0 | 0 | 0 | 14 | offen |
| 15 | 38 | osric 20, ilse 6 | 31 | 15 | 205 | 100 | 1 | 0/0/1 | 0 | 0 | 0 | 15 | offen |
| 16 | 31 | build 15, ilse 13 | 22 | 16 | 217 | 100 | 2 | 0/0/1 | 0 | 0 | 0 | 16 | offen |
| 17 | 22 | build 25 | 17 | 17 | 230 | 100 | 3 | 0/1/1 | 0 | 0 | 0 | 17 | offen |
| 18 | 17 | osric 6 | 15 | 17 | 235 | 100 | 3 | 1/1/2 | 1 | 0 | 1 | 17 | offen |
| 19 | 15 | ilse 13 | 21 | 18 | 247 | 100 | 3 | 1/1/2 | 1 | 0 | 1 | 18 | offen |
| 20 | 21 | osric 6 | 19 | 18 | 258 | 100 | 3 | 2/1/2 | 3 | 1 | 3 | 18 | ✓ |
| 21 | 19 | – | 23 | 18 | 258 | 100 | 3 | 2/1/2 | 3 | 1 | 3 | 18 | ✓ |
| 22 | 23 | osric 6 | 21 | 18 | 267 | 100 | 3 | 2/2/2 | 5 | 2 | 5 | 18 | ✓ |
| 23 | 21 | – | 25 | 18 | 276 | 100 | 3 | 2/2/2 | 8 | 3 | 7 | 18 | ✓ |
| 24 | 25 | – | 29 | 18 | 281 | 100 | 3 | 2/2/2 | 9 | 4 | 8 | 18 | ✓ |
| 25 | 29 | – | 33 | 18 | 286 | 100 | 3 | 2/2/2 | 10 | 5 | 9 | 18 | ✓ |
| 26 | 33 | – | 37 | 18 | 297 | 100 | 3 | 2/2/2 | 13 | 6 | 11 | 18 | ✓ |
| 27 | 37 | – | 41 | 18 | 306 | 100 | 3 | 2/2/2 | 15 | 7 | 13 | 18 | ✓ |
| 28 | 41 | – | 45 | 18 | 311 | 100 | 3 | 2/2/2 | 16 | 8 | 14 | 18 | ✓ |
| 29 | 45 | – | 49 | 18 | 320 | 100 | 3 | 2/2/2 | 18 | 9 | 16 | 18 | ✓ |
| 30 | 49 | – | 53 | 18 | 327 | 100 | 3 | 2/2/2 | 20 | 10 | 18 | 18 | ✓ |

#### save_load5

`PLAYTHROUGH5 save_load5  chapter5 day 24 (open day 20, six_pits day -1)  start 125 · income 40 (burial 0, stipend 40, gift 0, ilse 0, valuables 0) · spent 138 (license 20, osric 50, build 50, ilse 18) · Phase 5 spent 138 · end 27 · lowest morning 17 (Phase 5: 17)  gathered { &"clay": 21, &"herbs": 9, &"elderberries": 14, &"iron_ore": 27, &"stone": 17, &"workstone": 18 }  stones 11 (gilded 3)  loom gowns 0  tier days { "axe1": 22, "shovel1": 22, "pickaxe2": 23, "shovel2": 24, "axe2": 26 }`

| Tag | Münzen früh | Ausgaben (Zweck) | Münzen abends | Gräber | Qualität | Ruf | Stationen | Werkzeug S/A/P | Steine | Meister | mit Namen | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | 125 | license 20, osric 12, build 25, ilse 12 | 60 | 18 | 243 | 100 | 2 | 0/0/0 | 0 | 0 | 0 | 18 | offen |
| 21 | 60 | osric 20, build 25 | 19 | 18 | 243 | 100 | 3 | 0/0/1 | 0 | 0 | 0 | 18 | offen |
| 22 | 19 | osric 6 | 17 | 18 | 253 | 100 | 3 | 1/1/1 | 2 | 0 | 2 | 18 | offen |
| 23 | 17 | – | 21 | 18 | 253 | 100 | 3 | 1/1/2 | 2 | 0 | 2 | 18 | offen |
| 24 | 21 | osric 6 | 19 | 18 | 258 | 100 | 3 | 2/1/2 | 3 | 1 | 3 | 18 | ✓ |
| 25 | 19 | – | 23 | 18 | 266 | 100 | 3 | 2/1/2 | 5 | 1 | 5 | 18 | ✓ |
| 26 | 23 | osric 6 | 21 | 18 | 267 | 100 | 3 | 2/2/2 | 6 | 2 | 5 | 18 | ✓ |
| 27 | 21 | ilse 6 | 19 | 18 | 274 | 100 | 3 | 2/2/2 | 9 | 3 | 6 | 18 | ✓ |
| 28 | 19 | – | 23 | 18 | 275 | 100 | 3 | 2/2/2 | 10 | 4 | 6 | 18 | ✓ |
| 29 | 23 | – | 27 | 18 | 280 | 100 | 3 | 2/2/2 | 11 | 5 | 7 | 18 | ✓ |
