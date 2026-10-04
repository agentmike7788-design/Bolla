# Phase 7 – QA-Playthrough, Befunde, Art-Prüfung, Performance (W3)

Stand: Branch `vs/p7-qa` (auf `b7adb79`). Vertrag: `docs/PHASE7_DESIGN.md` (§14 Benutzerentscheidungen, W0-Notizen). Phase-7-Code = Diff bis `b7adb79`.

## 1. Befunde (adversariales Review)

Regressionstests: `tests/unit/test_phase7_qa.gd` (ohne Welt) und `tests/integration/test_phase7_qa.gd` (echte Welt).

| ID | Schwere | Befund | Behoben | Test |
|---|---|---|---|---|
| QA7-11 | **hoch** | Quast stand an Vorlesungsabenden **zu Hause**: der Zeitplan kannte die Vorlesung nicht, die Wundarztstube war nachts zu, die Vorlesung (§2.7) war im echten Spiel **nicht erreichbar** (nur über die Debug-Regie). | ✅ `Lectures` setzt `lecture_night_day` / `lecture_after_day` (stündlich, `sync_night_flags`); `surgeon_schedule` +3 `today_flag`-Einträge (22:55 Lesepult `v_in_surgery_lectern`, nach Mitternacht weiter, 01:30 heim); Wegpunkt im Raum-Layout | unit `test_qa7_05_quast_at_the_lectern_on_a_lecture_night`, integration `test_qa7_11_…` (echte Tür, echter Dialog `open_lecture`) |
| QA7-13 | mittel | Ein FILLED-Grab, dessen Toter ein Präparat im Gepäck hat: `[E]` bot nur „Präparat beisetzen“ – der Stein ließ sich per `[E]` **gar nicht** setzen (Bezahlung/Qualität hängen am Zeichen). | ✅ `GravePlot`: auf FILLED zuerst das Grabzeichen, „Präparat beisetzen“ danach auf dem MARKED-Grab – **Entscheidung E7-2** (Vertrag: „Vorrang nach dem Stein“ war mehrdeutig) | `test_qa7_13_marker_before_the_specimen_return_on_a_filled_grave` |
| QA7-12 | mittel (Art) | Lindenacker `l_04` / `l_08`: die Grube mit Aushub ragte über den Ostzaun (Fußabdruck bis x = 22,07 > Zaun 21,5); ±0,4 m Verschieben reichte nicht. | ✅ `pit_variant: "foot"` (Aushub am Fußende) für `l_04`/`l_08` (Layout, Builder, Gras-Maske); `graveyard.tscn` neu gebaut | `test_qa7_12_lindenacker_east_graves_keep_the_pit_inside_the_fence` |
| QA7-01 | klein | Verkauf von Augen/Hand: Beziehungsänderungen doppelt (Basis-Deltas `SELL_REL_BASE` + `on_specimen_sold`). | ✅ nur noch `Relationships.on_specimen_sold(organ)` (Werte aus `AnatomyConfig.organs[*].sell_rel`) | `test_qa7_01_…` (2) + `test_specimens` |
| QA7-02 | klein | Auftrags-Stufen (`OrderRules.TIERS`) als eigene Kopie neben `RelationshipRules` (15/40/70) – Gefahr des Auseinanderlaufens. | ✅ `OrderRules` delegiert an `RelationshipRules` | `test_qa7_02_…` |
| QA7-04 | klein | Kältefenster der Länge 0 (Bündel in derselben Minute hinein/heraus) blieb als `[t,t,f]` stehen → Roundtrip ungleich. | ✅ `Specimens._closed()` verwirft es | `test_qa7_04_…` (2) |
| QA7-05 | klein (Inszenierung) | G7-Motive passten nicht zu den Zeitplänen: Theres' Brunnenpause 14:00 lag nicht bei Liesel; beide auf demselben Wegpunkt `v_well`; Osric lief nie abends in den Holderkrug (er stand dort einfach). | ✅ Theres' Pause 16:00–16:35, Liesel `v_well_w`, Osric 21:55 Weg Remise → Holderkrug (5 Min); `p7_03` jetzt **16:15** statt 14:30 (Fenner steht erst ab 16:05 an der Tafel) | `test_qa7_05_…` (2) |
| QA7-06 | klein (UI) | Laden-Rabatt „6 → 5“ war bei 720p kaum lesbar. | ✅ alter Preis durchgestrichen rostrot, neuer bernstein, Pfeil grau (`Phase7Texts.SHOP_PRICE_BB`) | `test_qa7_06_…`, `ui_shop` |
| QA7-A1 | Art | Schmiede: Esse-Glut außen nicht sichtbar (Esse im geschlossenen Raum). | ✅ Esse hinter offener Südluke (Wandöffnung, Rahmen, Laden, 14 Glutstücke, `light_ember` an der Luke) | `p7_01`, `p7_07` |
| QA7-A2 | Art | Bach: einfarbig blaugrau, wirkte wie ein Band. | ✅ gedämpfte Palette (Wasser/Tiefe/Spiegel/Ufer/Glanz, kein gesättigtes Kalt), Strichtupfer je Vertex | `p7_01` |
| QA7-A3 | Art | Präparierpult `p7_16` zu dunkel, Tuch ununterscheidbar. | ✅ Leinentuch, Messingleuchter mit Kerze + `light_candle` | `p7_16` |
| QA7-A4 | Art | Trauerflor (`ribbon`) in Spielansicht kaum sichtbar. | ✅ ≈ 1,7× größer (Schleifen + Bänder) | `p7_15` |
| QA7-A5 | Werkzeug | UI-Regie zeigte die Dorf-Panels über dem Friedhof, Rosines Gerede über einem Stellvertreter; die Vorlesung ohne Quast. | ✅ Laden, Gabe, Tafel, Gerede, Ankunft, Wundarzt, Vorlesung jetzt **im echten Dorf** (RegionTravel, echte Npc, Räume über HutPortal) | `ui_*` |
| QA7-A6 | Werkzeug | UI-Regie: p7_24/p7_25 fehlten; das Grabregister zeigte in der Fußzeile die Summe der Gräber statt des HUD-Werts (`CemeteryScore`, wie `Desk.register_context`). | ✅ neue Bilder `ui_specimen_return`, `ui_ghost_returned`, `ui_ghost_organ`; Fußzeile wie im Spiel | Bilder |
| QA7-03 | Prüfung | Ruf-/Frömmigkeitsereignisse der Phase 7 stehen vollständig in den Daten (kein Klassen-Default). | – | `test_qa7_03_…` |
| QA7-07…10 | Prüfung | Laden im Holderkrug (Region + Raum + Kamera zurück), keine Reise während einer Zeitaktion, Laden während der Blende verwirft die Reise, Laden mitten im Präparat (Schleier/Tuch aus). | – | integration `test_qa7_07…10` |

## 2. Offene Punkte / Entscheidungen für den Benutzer

- **B7-1 (Balance, Kapitel zu früh) – ✅ G7 Runde 2:** vorher Tag 42 (B3) bei allen Bots (Ruf-Bonus +10 machte Fenner/Lenz sofort „Vertraut“, alle drei Hinweise am ersten Tag). Jetzt: `RelationshipConfig.rep_start_bonus` [−10, −5, 0, +5, +10] → **[0, +2, +4, +6, +8]** (niemand startet über „Bekannt“, höchstens 38) und Liesels Hinweis `c_v_washing` (beide Wege, `v_washer.tres`) zusätzlich `village_open_days_gte:10`. Kapitel bei **allen drei Bots Tag 50 = B11** (10 Tage nach `village_open`); der verwertende Weg (`anatomist7`, Liesel 0–8, Pfarrer ≤ „Bekannt“) erreicht es über Kaspar + Amtsstube. Der Playthrough-Test prüft jetzt „nicht vor B11“.
- **B7-2 (Münzen) – ✅ G7 Runde 2:** vorher Ende 91 / 107. Geändert: Auftragslöhne (vor allem mittlere und späte Aufträge −2…−4, Tafel −1…−2, s. `PHASE7_DESIGN.md` §2.5), `o_fenner_linden` 0 → 6 (Rodungslohn, sonst fiele der Morgen B2 unter 5: die Weihe kostet jetzt 10 und die Abschrift eine Spende), Quast-Grundpreise Herz/Augen/Hand 7/9/10 → 9/11/12. Ende **neighbor7 60** (Ziel ≈ 63, −5 %), **anatomist7 71** (≈ 77, −8 %), Abstand **+11** (Ziel ≈ +14), morgens min. 12 / 13. Der Test prüft „morgens nie unter 5“ (vorher 15).
- **Bot-Eigenheiten (nicht geändert, nur gemeldet):** `anatomist7` nimmt trotz `donations: false` die Brücken-Spende an (Dialogpfad nach einer Tafel-Abgabe, kostet 20); `neighbor7` nimmt `o_quast_specimen`/`o_lenz_poor` an und lässt sie verfallen; `o_hagedorn_place` scheitert bei `anatomist7`. Die Bot-Endstände reagieren stark auf kleine Datenänderungen (±20 Münzen bei `anatomist7`).
- **E7-1 (p7_03-Uhrzeit):** Motiv „Brunnen 14:30“ jetzt 16:15 (Theres' Pause verschoben, Fenner ab 16:05 an der Tafel). Bitte bestätigen oder Uhrzeit des Motivs ändern.
- **E7-2 (QA7-13):** Grabzeichen vor „Präparat beisetzen“. Bitte bestätigen.
- **E7-3 (Lindenacker `l_04`/`l_08`):** Aushub am Fußende statt seitlich (QA7-12).
- **Kirchturm:** St. Gallus hat im Spielwinkel nie den ganzen Turm im Bild (nur das Dach/Giebel; `p7_02b`). Nur gemeldet, nicht geändert.
- **Kosmetik Bot-Tabelle:** Eine Vorlesungsnacht über Mitternacht lässt die Tageszeile dieses Tages aus (anatomist7, Tag 48) – nur in der Bot-Tabelle.

## 3. Playthrough-Bot Phase 7

`tests/integration/phase7_bot.gd` (`Phase7Bot extends Phase6Bot`): Dorfgang über die echten Portale (Wegstein ↔ Holderbrücke, `HouseDoor`, `RoomExit`), echte Dialoge (generischer Auswahl-Wähler), echte Panels (Laden, Gabe, Aufträge/Tafel, Wundarzt, Vorlesung, Pult, Sammlung), Aufträge mit Reservierungs-Regeln, Lindenacker räumen, Weihetag, Pult bauen und Arbeiten, Präparate über `MorgueTable.request_organ`, verdorbene Bündel zurück ins Grab, Vorlesungsnächte. Strategien: `neighbor7` (würdevoll, keine Präparate), `anatomist7` (Präparate, Vorlesung, Sammlung), `save_load7` (lädt jeden Morgen und einmal im Holderkrug).

`tests/integration/test_phase7_playthrough.gd` prüft: keine Fehler/Warnungen, keine Bot-Probleme, Kapitel, Münzbuch (Start + Einnahmen − Ausgaben = Ende), Strategie-Erwartungen, `save_load7` = `neighbor7` zeilengleich.

| Strategie | Start | Tage | Kapitel (Tag) | Einnahmen | Ausgaben | Ende | morgens min. | Aufträge (Geber) | Präparate | Vertraut |
|---|---|---|---|---|---|---|---|---|---|---|
| neighbor7 | v5 `slot_p6_day40_reverent`, 20 Münzen | 13 | 50 | 318 (burial 117, stipend 52, gift 27, reinter 4, service 37, order 56, village_sale 25) | 278 (donation 42, round 20, village 61, consecration 10, osric 14, build 12, ilse 44, building 75) | 60 | 12 | 11 (7) | 0 | 8 |
| anatomist7 | dto. | 13 | 50 | 381 (burial 88, stipend 56, gift 7, reinter 4, service 32, order 71, village_sale 20, specimen 88, lecture 7, collection 8) | 330 (donation 25, round 15, village 110, consecration 10, osric 39, build 12, ilse 44, building 75) | 71 | 13 | 13 (7) | 16 genommen | 5 (Lenz/Liesel ≤ Bekannt) |
| save_load7 | dto. | 13 | 50 | = neighbor7 | = neighbor7 | 60 | 12 | = | = | = |

*G7 Runde 2 (Balance B7-1/B7-2):* vorher Kapitel 42 / 42, Ende 91 / 107, morgens min. 16 / 17, Aufträge 10 / 13.

Tag für Tag (anatomist7, G7 Runde 2):

| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Aufträge erledigt (Geber) | aktiv | Vertraut | Beziehungen Fe/Le/Ro/Es/Th/Qu/Li/Ha | Lindenacker | Präparate gen./verk. | Ansehen | Erkenntnis | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | 20 | donation 5, round 5, village 3, consecration 10 | order 12, stipend 4 | 13 | 2 (1) | 3 | 1 | 58/39/36/28/29/29/24/39 | – | 0/0 | 0 | – | offen |
| 41 | 13 | round 5, village 7 | order 14, stipend 4 | 19 | 4 (3) | 4 | 4 | 66/40/39/29/40/30/25/40 | offen | 0/0 | 0 | – | offen |
| 42 | 19 | osric 2, village 26, build 12 | service 5, burial 15, order 13, village_sale 2, gift 3, stipend 4 | 21 | 6 (5) | 4 | 5 | 71/41/48/38/41/31/26/41 | offen | 0/0 | 0 | – | offen |
| 43 | 21 | osric 2, village 13, ilse 4 | burial 9, order 16, collection 8, stipend 4 | 39 | 8 (6) | 4 | 6 | 76/42/59/39/42/42/27/42 | offen | 3/0 | 1 | – | offen |
| 44 | 39 | village 14, ilse 6 | village_sale 2, stipend 4 | 25 | 8 (6) | 4 | 7 | 81/43/60/40/43/43/28/43 | offen | 6/0 | 1 | – | offen |
| 45 | 25 | village 6, building 35, ilse 4 | service 5, burial 7, village_sale 3, specimen 21, stipend 4 | 20 | 8 (6) | 3 | 6 | 86/35/61/41/44/44/23/40 | offen | 7/2 | 1 | – | offen |
| 46 | 20 | osric 2, village 5, ilse 4 | service 5, burial 11, village_sale 1, reinter 4, stipend 4 | 34 | 8 (6) | 4 | 6 | 91/36/62/42/45/45/24/41 | offen | 10/2 | 1 | – | offen |
| 47 | 34 | osric 11, village 11 | service 5, burial 7, village_sale 3, stipend 4, order 4 | 35 | 9 (6) | 2 | 5 | 96/37/63/39/46/46/25/42 | offen | 13/2 | 1 | – | offen |
| 49 | 35 | osric 11, round 5, village 5, ilse 13 | service 5, burial 8, order 4, village_sale 3, specimen 43, stipend 8, lecture 7 | 79 | 10 (6) | 3 | 5 | 100/14/66/40/47/58/4/34 | offen | 13/6 | 1 | – | offen |
| 50 | 79 | osric 8, village 2, building 40, ilse 7 | burial 11, gift 2, stipend 4 | 39 | 10 (6) | 3 | 5 | 100/10/71/41/48/59/1/34 | offen | 13/6 | 1 | ✓ | ✓ |
| 51 | 39 | osric 3, donation 20, village 13, ilse 6 | burial 11, village_sale 3, gift 2, specimen 24, stipend 4 | 41 | 11 (6) | 2 | 5 | 100/0/72/42/49/64/0/30 | offen | 16/8 | 1 | ✓ | ✓ |
| 52 | 41 | village 3 | service 7, burial 9, order 4, stipend 4 | 62 | 12 (7) | 1 | 5 | 96/8/77/43/50/65/1/30 | offen | 16/8 | 1 | ✓ | ✓ |
| 53 | 62 | village 2 | order 4, village_sale 3, stipend 4 | 71 | 13 (7) | 1 | 5 | 100/8/82/44/51/66/2/30 | offen | 16/8 | 1 | ✓ | ✓ |

(Tag 48 fehlt: Vorlesungsnacht über Mitternacht · Spalte Lindenacker: „offen“ = freigegeben.)

## 4. Save-Fuzzer

`test_save_fuzzer.gd`: neu `test_fuzz_v6_real_mid_phase7_save` – Phase7Bot (`anatomist7`) spielt 3 Tage ab dem Phase-6-Ende, dann: Glas im Gepäck, Bündel im Kühlfach des Pults mit offenem Kältefenster, drei aktive Aufträge, Weihetag, Totengräber im Holderkrug – gespeichert (v6). JSON-/native Mutationen (60 auf den Phase-7-Teilen) + 8 gezielte Fälle (unbekannte Region, Region keine Zeichenkette, uid doppelt in Gepäck und Kühlfach, alle uids fehlen, Präparat-Datensätze unbekannter Leiche/Organ, unbekannte Auftrags-Zustände/-IDs, Beziehungen außerhalb 0…100, `returned ⊄ harvested`). Neue Konsistenzprüfung für jeden geladenen Stand: jede uid in höchstens einem Platz, Region eine der Welt und aktiv, Beziehungen 0…100, Auftrags-Zustände bekannt, ≤ 4 aktiv, `returned ⊆ harvested`. Ergebnis: **v6 (echt) 92 geladen / 21 abgelehnt**, v6-Phase-7-Teile 8/0, v5-Fixtures 113/76 – nur die zwei erlaubten Ausgänge, kein halb angewandter Zustand. Gesamter Fuzzer 14/14 grün.

## 5. Performance (§9, relativ in derselben Messung)

`tools/qa_tmp/cpu_probe7.gd` (nicht eingecheckt; Rohdaten `qa_cpu_p7.txt`): headless, v5-Phase-6-Endstand, Uhr läuft, **Frame-Begrenzung aus** (`low_processor_usage_mode_sleep_usec = 0`, `max_fps = 0` – sonst misst man die 6,9-ms-Schlafpause), Wandzeit je Frame, 4 Läufe × 360 Frames, abwechselnd:

| Konfiguration | Mittel (4 Läufe) | Median |
|---|---|---|
| Friedhof aktiv (wie gespielt) | 0,161 ms | 0,141 ms |
| Friedhof, Phase-7-Teile aus (Dorf + Phase-7-Systeme `DISABLED`) | 0,160 ms | 0,140 ms |
| Dorf aktiv | 0,168 ms | 0,146 ms |

→ Dorf aktiv **+0,007 ms** gegenüber Friedhof (Budget +0,3 ms); Phase-7-Anteil auf dem Friedhof **≈ +0,001 ms** (Budget +0,1 ms). Kein Hotspot, nichts optimiert. Render-Werte der Bilder: `render_stats_p7_village.txt` / `render_stats_p7_graveyard.txt` in `docs/reviews/phase7_round1/`.

Render (Satz G7, llvmpipe, `render_stats_p7_*.txt`): Dorf Spielzoom Draw Calls ≤ 143, Kamera-Dreiecke ≤ 121 k (Übersicht weit 198 k), ≤ 12 Omni sichtbar, 2 Schattenlichter (Holderkrug, Kirchentür); Gaststube voll 61 Draw Calls / 35 k; Friedhof mit Lindenacker belegt (`perf_p7_04`) 287 Draw Calls / 401 k inkl. Gras; Gruft mit Pult und vollen Nischen 94 / 43 k, 1 Schattenlicht. Alles unter §9 (Dorf < 1 000, Friedhof ≤ 600, < 500 k). Nur die Draufsicht-Sichtprüfung `p7_vis_linden_*` (Abstand 44 m, kein Spielzoom) hat 567 k.

## 6. Tests

Volle Suite am Ende (nach Import, nach dem letzten Code-Stand): **RESULT PASS (2372 bestanden, 0 fehlgeschlagen)**. G7 Runde 2 (Balance, Branch `vs/g7r2-balance`): **RESULT PASS (2445 bestanden, 0 fehlgeschlagen)**, Fuzzer v6 echt 92 geladen / 21 abgelehnt. Darin u. a. `test_phase7_qa` (unit 10, integration 7), `test_phase7_playthrough` (3 Strategien × 13 Tage, Zahlen wie in §3), Save-Fuzzer 14/14 (v6 echt 92 geladen / 21 abgelehnt). Die einzige `ERROR`-Zeile im Log ist der absichtliche Selbsttest des Test-Frameworks.

## 7. Screenshot-Satz Gate G7 (`docs/reviews/phase7_round1/`, 1280×720, echter Renderer)

Alle Bilder selbst angesehen; geändert nach Ansicht: `p7_05` (Osric jetzt im Laternenlicht vor dem Holderkrug, 21:59), `p7_08` (zu Theres gewandt), `p7_16` (Pult mit Kerze und Tuch im Bild), neu `p7_04b` (Holderkrug-Laterne in der Dämmerung), neu `ui_specimen_return` / `ui_ghost_returned` (p7_24) und `ui_ghost_organ` (p7_25), `ui_remark` (Blase frei vom HUD), `ui_register` (Fußzeile = HUD-Wert aus `CemeteryScore`), `ui_chapter_name_in_village` (keine Geisterblase im Hintergrund). Kontaktblatt: `p7_contact_sheet_final.jpg`.

| §11 | Bild(er) |
|---|---|
| p7_00 | `p7_00_wegstein_day` |
| p7_01 | `p7_01_arrival_bridge_morning` (Bach neu, Esse-Glut an der Luke) |
| p7_02 | `p7_02_anger_overview_day`, `p7_02b_anger_overview_far` |
| p7_03 | `p7_03_anger_afternoon` (16:15, s. E7-1) |
| p7_04 | `p7_04_anger_dusk`, `p7_04b_inn_dusk` |
| p7_05 | `p7_05_village_night` |
| p7_06 | `p7_06_contact_sheet` |
| p7_07 | `p7_07_smithy_esch` (Prompt „Mit Ulrich reden“: der Npc hat Vorrang 30 vor der Theke 5; der Laden öffnet über seinen Dialog) |
| p7_08 | `p7_08_shop_theres` |
| p7_09 | `p7_09_church_lenz` |
| p7_10 | `p7_10_inn_day`, `p7_10b_inn_night` |
| p7_11 / p7_12 | `p7_11_surgery`, `p7_12_office` |
| p7_13 | `p7_13a_linden_before`, `p7_13b_linden_cleared`, `p7_13c_linden_graves` (l_04/l_08 im Zaun) |
| p7_14 | `p7_14_consecration_day` |
| p7_15 | `p7_15_mourning_hagedorn` (größerer Trauerflor) |
| p7_16 | `p7_16_crypt_pult` |
| p7_17 / p7_33 | `ui_organs_armed`, `ui_organs_eyes` |
| p7_18 | `ui_organ_veil` |
| p7_19 | `ui_shop` (Rabatt durchgestrichen) |
| p7_20 | `ui_anatomist` |
| p7_21 | `ui_board` |
| p7_22 | `ui_journal_village`, `ui_journal_orders` |
| p7_23 | `ui_remark` |
| p7_24 | `ui_specimen_return`, `ui_ghost_returned` |
| p7_25 | `ui_ghost_organ` |
| p7_26 | `p7_26_new_stone_old_08` |
| p7_27 | `ui_insight_deathbook` |
| p7_28 | `ui_chapter_name_in_village` |
| p7_29 | `ui_collection` (Regal selbst: `perf_p7_05`) |
| p7_30 | `p7_30_lecture_night`, `ui_lecture`, `ui_lecture_veil` |
| p7_31 | `ui_deduction` |
| p7_32 | `ui_pult_medicines` |
| p7_vis | `p7_vis_village_z12/22/26`, `p7_vis_linden_z12/22/24` |
| Budget | `perf_p7_01…05`, `render_stats_p7_village.txt`, `render_stats_p7_graveyard.txt` |
| sonst | `ui_hud_village`, `ui_gift`, `ui_register`, `ui_day_summary` |
