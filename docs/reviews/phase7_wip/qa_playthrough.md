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

- **B7-1 (Balance, Kapitel zu früh):** „Ein Name im Dorf“ fällt bei beiden Bots an **Tag 42 (B3)** statt um B12. Ursache: der Ruf „Gerühmt“ (+10 Bonus) macht Fenner (30) und Lenz (25 + 10 + 5) schon beim ersten Treffen „vertraut“; der Register-Hinweis kommt sofort über Fenner, der Liesel-Hinweis über Kaspar, Ilse bringt in der ersten Nacht `i_deathbook`; 6 Aufträge von 4 Gebern sind bis B3 erledigt. **Keine Werte geändert.** Vorschlag: Startwerte der Beziehungen oder den Ruf-Bonus senken (z. B. Bonus +5, Fenner 20), oder Kapitel zusätzlich an „Lindenacker belegt ≥ 3“ binden.
- **B7-2 (Münzen):** Ende nach 13 Tagen neighbor7 ≈ **91**, anatomist7 ≈ **107** (Vertrag ≈ 63 / ≈ 77). Mehr Einnahmen aus Aufträgen (57–85) und Dorfverkauf (25) als in §2.12 gerechnet; der Abstand anatomisch/würdevoll stimmt ungefähr (+16 statt +14).
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
| neighbor7 | v5 `slot_p6_day40_reverent`, 20 Münzen | 13 | 42 | 324 (burial 117, stipend 52, gift 27, reinter 4, service 39, order 60, village_sale 25) | 253 (round 15, village 61, consecration 5, osric 14, build 12, ilse 46, building 75, donation 25) | 91 | 16 | 10 (7) | 0 | 8 |
| anatomist7 | dto. | 13 | 42 | 383 (burial 84, stipend 56, gift 6, reinter 4, service 32, order 85, village_sale 25, specimen 76, lecture 7, collection 8) | 296 (round 15, village 118, consecration 5, osric 30, build 12, ilse 41, building 75) | 107 | 17 | 13 (7) | 16 genommen | 5 (Lenz/Liesel ≤ Bekannt) |
| save_load7 | dto. | 13 | 42 | = neighbor7 | = neighbor7 | 91 | 16 | = | = | = |

Tag für Tag (anatomist7):

| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Aufträge erledigt (Geber) | aktiv | Vertraut | Beziehungen Fe/Le/Ro/Es/Th/Qu/Li/Ha | Lindenacker | Präparate gen./verk. | Ansehen | Erkenntnis | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | 20 | round 5, village 3, consecration 5 | order 6, stipend 4 | 17 | 2 (1) | 3 | 3 | 59/41/38/30/31/31/26/41 | – | 0/0 | 0 | ✓ | offen |
| 41 | 17 | round 5, village 14 | order 17, stipend 4 | 19 | 4 (3) | 4 | 5 | 67/42/41/31/42/32/27/42 | offen | 0/0 | 0 | ✓ | offen |
| 42 | 19 | osric 2, village 25, build 12, ilse 2 | service 5, burial 12, order 23, village_sale 2, stipend 4 | 24 | 7 (6) | 4 | 7 | 72/44/50/40/43/43/30/43 | offen | 2/0 | 0 | ✓ | ✓ |
| 43 | 24 | osric 2, village 13, ilse 4 | burial 9, order 8, collection 8, stipend 4 | 34 | 8 (6) | 4 | 7 | 77/45/61/41/44/44/31/44 | offen | 5/0 | 1 | ✓ | ✓ |
| 44 | 34 | village 13, ilse 6 | village_sale 2, stipend 4 | 21 | 8 (6) | 4 | 7 | 82/46/62/42/45/45/32/45 | offen | 7/0 | 1 | ✓ | ✓ |
| 45 | 21 | village 2, building 35, ilse 2 | service 5, burial 8, village_sale 3, order 10, specimen 18, stipend 4 | 30 | 9 (6) | 4 | 6 | 87/37/67/43/46/58/25/42 | offen | 7/2 | 1 | ✓ | ✓ |
| 46 | 30 | osric 2, village 13, ilse 4 | service 5, burial 12, village_sale 3, reinter 4, gift 2, stipend 4 | 41 | 9 (6) | 4 | 6 | 92/38/68/44/47/59/26/43 | offen | 10/2 | 1 | ✓ | ✓ |
| 47 | 41 | osric 11, village 17, ilse 2 | service 5, burial 7, order 6, village_sale 3, stipend 4 | 36 | 10 (7) | 2 | 7 | 97/47/69/41/48/60/23/44 | offen | 13/2 | 1 | ✓ | ✓ |
| 49 | 36 | osric 11, round 5, village 3, ilse 15 | burial 17, order 5, village_sale 3, specimen 47, service 5, gift 2, stipend 8, lecture 7 | 96 | 11 (7) | 1 | 5 | 100/11/72/42/49/74/0/34 | offen | 13/7 | 1 | ✓ | ✓ |
| 50 | 96 | osric 2, village 2, building 40, ilse 6 | burial 10, gift 2, stipend 4 | 62 | 11 (7) | 1 | 5 | 100/11/77/43/50/75/1/34 | offen | 13/7 | 1 | ✓ | ✓ |
| 51 | 62 | village 13 | village_sale 3, service 7, burial 9, specimen 11, stipend 4 | 83 | 11 (7) | 0 | 5 | 100/1/78/44/51/78/0/32 | offen | 16/8 | 1 | ✓ | ✓ |
| 52 | 83 | – | village_sale 3, stipend 4 | 90 | 11 (7) | 1 | 5 | 100/2/83/45/52/79/3/32 | offen | 16/8 | 1 | ✓ | ✓ |
| 53 | 90 | – | order 10, village_sale 3, stipend 4 | 107 | 13 (7) | 1 | 5 | 100/3/88/46/53/80/6/32 | offen | 16/8 | 1 | ✓ | ✓ |

(Tag 48 fehlt: Vorlesungsnacht über Mitternacht, s. o. · Spalte Lindenacker: „offen“ = freigegeben.)

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

Volle Suite am Ende (nach Import, nach dem letzten Code-Stand): **RESULT PASS (2372 bestanden, 0 fehlgeschlagen)**. Darin u. a. `test_phase7_qa` (unit 10, integration 7), `test_phase7_playthrough` (3 Strategien × 13 Tage, Zahlen wie in §3), Save-Fuzzer 14/14 (v6 echt 92 geladen / 21 abgelehnt). Die einzige `ERROR`-Zeile im Log ist der absichtliche Selbsttest des Test-Frameworks.

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
