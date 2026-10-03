# Phase 6 – QA-Playthrough, Befunde, Art-/Ton-Prüfung, Performance (W3)

Stand: Branch `vs/p6-qa` (auf `a0a4bf7`). Vertrag: `docs/PHASE6_DESIGN.md` (§14 Benutzerentscheidungen: Gruft = Leichenhalle + Beinhaus, 6 Altgräber umbetten, Lage wie vorgeschlagen, alter Tisch wird entfernt; W0-Notizen). Phase-6-Code = Diff `c5bd76d..a0a4bf7`.

## 1. Befunde (adversariales Review)

Jeder Befund hat einen Regressionstest in `tests/integration/test_phase6_qa.gd` (vor dem Fix rot gemessen, wo nicht anders vermerkt).

| ID | Schwere | Befund | Behoben | Test |
|---|---|---|---|---|
| QA6-01 | **hoch** | `Graveyard.place_marker` / `set_designed_stone` riefen `Buildings.check_goal` nie (§3.3 verlangt es bei `service_held`). Kam das Grabzeichen der ausgesegneten Leiche als letzte Bedingung, fiel „Unter Dach und Erde" nicht – und nach der 6. Umbettung mit allen Gebäuden auf Stufe 3 **nie mehr** (kein Auslöser übrig). | ✅ `Graveyard._check_buildings_goal(corpse)` nach Zeichen / gestaltetem Stein (nur `service_held`) | `test_chapter_completes_when_the_serviced_grave_is_marked_last`, `…_designed_stone_is_set_last` |
| QA6-07 | **hoch** | `ChapelRites.hold_service` prüfte die Frische am **Ende** der 45 Minuten erneut: Eine Leiche mit 0,31 beim Beginn fiel während des Ritus unter 0,3 → keine Aussegnung, Kerze behalten, 45 Min verloren, „Gerade nicht möglich.“ und eine Warnung im Normalspiel (vom Bot `mortician` gefunden). | ✅ Frische zählt wie das Zeitfenster beim Beginn (`ANY_MINUTE` überspringt beides) | `test_service_begun_fresh_enough_ends_with_its_fee` |
| QA6-02 | mittel | Kapitel-Panel „Aussegnungen (davon mit Trauergästen)“ zeigte nur die nackte Zahl – `services_mourners` fehlte in `Buildings.chapter_context()`. | ✅ `ChapelRites` zählt Aussegnungen mit Trauergästen (gespeichert als `chapel.mourned`, tolerant), Kontext + Panel-Zeile | `test_chapter_context_counts_services_with_mourners` |
| QA6-04 | mittel | „Überschuss einlagern“ (Schuppen 3) nahm leere Gebeinkisten und Altarkerzen mit (§2.5: „keine Gebeinkisten“). Danach sagte das Altgrab „Keine Gebeinkiste – an der Werkbank zimmern.“ bzw. der Altar „Keine Altarkerze“ – dort gibt es kein Holen. | ✅ `excluded_items` = `bone_box_full`, `bone_box`, `altar_candle` (Daten, Klassen-Default, Fixture, Hinweistext) – **Entscheidung E2** | `test_store_surplus_keeps_bone_boxes_and_candles` |
| QA6-06 | klein | `Buildings.upgrade` brachte erst die Räume, dann (`Ossuary.on_crypt_level`) den Gang auf die neue Stufe; `SealedPassage`/`OssuaryShelf` waren in keiner Gruppe → die vermauerte Tür erschien erst einen Frame später (verzögertes Signal), `apply_levels` erreichte sie nie. | ✅ Gruft-Zustand vor `apply_levels`; Gruppen `sealed_passage`, `ossuary_shelf` | `test_crypt_upgrade_shows_the_walled_door_at_once` |
| QA6-08 | klein | Beschädigte v5-Stände ergaben halb angewandte Zustände (Fuzzer, echter Phase-6-Stand): zwei Leichen in einer Nische / auf dem Katafalk, eine Leiche in einer noch vermauerten Nische, Leichen in einer Gruft/Kapelle der Stufe 0, gehobene Altgräber, die noch `OLD` stehen (doppelt hebbar). | ✅ `CorpseManager._sanitize_places` (post_load): unzulässiger Platz → Boden des Raums bzw. vor der Tür, Kältefenster folgt, Warnung; `Ossuary.load_state` hebt ein noch `OLD` stehendes gehobenes Grab | Save-Fuzzer `test_fuzz_v5_real_mid_phase6_save` (6 gezielte Fälle + Konsistenzprüfung) |
| QA6-10 | klein | `GameState.get_flag(goal) == true` in HUD-Ziel-/Kapitelzeile (Phase 5/6): eine Zahl im Flag (beschädigter Stand) → „Invalid operands 'float' and 'bool'“ beim Laden. | ✅ `GameState.flag_on()` (Wahrheitswert jeder Art), in `cemetery_status`, Debug, Türzettel | `test_number_in_a_goal_flag_is_no_script_error` |
| QA6-11 | klein | `MorgueTable` hatte kein `refresh()`: Stufen über `load_state` + `apply_levels` (Debug-Konsole, Inszenierung) ließen Tisch, Waschschüssel und Räucherschale vor der Hütte stehen (sichtbar im HUD-Bild bei Gruft 2). | ✅ `refresh()` → `refresh_active()` | `test_apply_levels_retires_the_old_table` |
| QA6-03 | klein | Debug-Konsole und UI-Regie riefen das private `Buildings._open()` per Namen. | ✅ öffentliches `Buildings.open()` (idempotent) | `test_buildings_open_is_public_and_idempotent` |
| QA6-05 | Prüfung | W1/W2-Punkt 1: Panels `building`, `chapel`, `devotion` sind in `UIRoot` registriert; der Loop läuft durch sie (Knöpfe gedrückt). Der Bot nutzt sie in allen Strategien. | – | `test_phase6_panels_are_registered_and_drive_the_loop` |
| QA6-09 | Prüfung | W1/W2-Punkt 5: v4 `day20_crafter` öffnet `buildings_open` sofort beim Laden – **richtig** laut §1.2 („Migrierte Stände (v4) … sofort (auch nach 06:00)“); die W0-Notiz stammt von vor W2. Testkommentar berichtigt. | ✅ Kommentar | `test_saves_v4_load.gd::test_day20_crafter_loads` |
| QA6-A1 | Art | Gruft innen: Tiefennebel `#8A98A8` färbte die Leere um den Raum hellgrau (Nebel wirkte auf den Hintergrund) und legte über alles einen milchigen, selbstleuchtenden Schleier – nachts fast so hell wie am Tag. | ✅ `fog_sky_affect 0`; Nebellicht Tag 0,6 / Nacht 0,25 (`InteriorConfig.fog_day/night_energy`, Gruft-Config) | `qa_01_crypt_fog_void.jpg` |
| QA6-A2 | Art | Gehobenes Altgrab: Gras wuchs in die offene Grube und durch den Aushub am Fußende (Gras-Sperre nur über Hügel/Stein). | ✅ Gras-Sperre der Altgräber = Grube mit Aushub (`foot_footprint`), Gras neu gebacken | `qa_02_lifted_grave_grass.jpg` |
| QA6-A3 | Art/Kamera | Gruft innen: das Beinhaus (Kisten, alte Steine, Namenstafel, Gitter) lag an der nördlichen Kameragrenze am oberen Bildrand, halb abgeschnitten. | ✅ Kameragrenze Nord −1,3 → −2,4 m (Frustum-Test grün) | `qa_03_crypt_camera_ossuary.jpg` |
| QA6-A4 | Werkzeug | UI-Regie (W1/W2-Punkt 6) stellte Kapellen-, Andachts-, Schuppen- und Gruft-Tisch-Panel über die Außenwelt; die Welt-Regie ließ Inszenierungs-Leichen liegen (`records` statt `corpses`) – die Andacht stand mit Leiche auf dem Katafalk. | ✅ echte Räume, echter Altar/Katafalk/Tisch/Schuppen; Leichen werden geräumt | Bilder `phase6_round1/ui_*`, `world_p6_11` |
| QA6-T1…4 | Ton | „Die Tote vom alten Tisch …“ auch bei Männern → „Die Leiche vom alten Tisch liegt jetzt unten in der Gruft.“ · Kapelle 1 in der 3. Person („Hier kann der Totengräber …“) → „Hier hältst du die Aussegnung selbst.“ · Einlager-Hinweis nennt Kisten und Kerzen · Umbettungs-Namen mit „ · “ getrennt („Elias Brand, Totengräber“ trägt ein eigenes Komma). | ✅ | `qa_05_chapter_panel.jpg`, `test_ui_phase6` |

**Geprüft ohne Befund** (Tests: `test_phase6_qa.gd` „Prüfung“, Bot, Fuzzer, Besitzer-Tests):
- Speichern/Laden in **jedem** Raum (Gruft, Kapelle, Schuppen): richtiger Raum aktiv, die anderen aus, Kameraprofil und Raum-Environment zurück, Außensonne aus; hinaus: Außenrahmen und Sonne wieder da (`test_save_and_load_in_every_room_restores_room_and_camera`). Mitten im Ritus / beim Heben / beim Beisetzen ist Speichern gesperrt (`can_save`: TimedAction). Nischen-Leiche mit offenem Kälte- und Räucherfenster, Katafalk, gehobene Kiste, nach dem Kapitel: W-Welt-Roundtrips + `save_load6` (lädt jeden Morgen und einmal in der Gruft mit Leiche in der Nische) **zeilengleich zu `reverent6`**.
- Migration v4→v5 und älter: 7 v4-, 6 v3-, 4 v2-, 3 v1-Fixtures laden (Kette 1→5); Leiche auf dem alten Tisch bleibt dort und wandert bei Gruft 1 mit allen Zuständen (Schritte, Funde, Zopf, Räucherfenster) auf den Gruft-Tisch (`test_phase5_save_upgrade`).
- Tischwechsel: auf jeder Gruft-Stufe genau ein aktiver Tisch (`test_morgue_table`, QA6-11).
- Kälte vs. Wacholder: der `mortician` misst die Frische bei der Untersuchung nach einer Nacht in der Nische: **Uhr-Differenz = `CorpseDecay`-Formel = Σ Minuten × Kältefaktor von Hand** (6 Leichen, Abweichung < 1e-6); Schlaf und Zeitsprung laufen über offene Fenster.
- Exploits: kein Rückbau, keine Rückerstattung (Verbrauch atomar am Bauende); Gebühr einmal je Leiche (`service_held` bleibt beim Auf-/Ablegen); Andacht je Grab und Stufe einmal, höherer Wert ersetzt (kein Summieren), beraubte Seele höchstens 8; Umbettgeld nur FIFO je gehobenem Grab (keine Schleife); Holen/Einlagern atomar, Summen bleiben gleich; Stapel × 2 nur im Schuppen, nach Laden erhalten; keine Kistenverdopplung (Kiste wird erst am Ende des Hebens verbraucht, Abbruch verliert nichts).
- Altgräber: genau 6 hebbar, `old_01`/`old_08` sperren mit Ruhezeit-Text; gehobene Stellen nehmen wieder Leichen auf (Lieferungen laufen in allen Strategien wieder); das Kapitel fällt in allen Strategien genau einmal.
- Wege/Portale: mit Leiche nur Gruft/Kapelle (Schuppen weist ab), Hinaufgehen aus jedem Raum, nach dem Laden der richtige Raum; Kirchpforte vor dem Leichenzug.
- Sichtbarkeit aller Gebäude: W-Welt-Kamerastrahl-Test §4.5 grün; Bilder `world_p6_02/03/04` je Stufe.
- **Keine Warnung und kein Fehler** in 6 Strategien × 10–36 Tagen Normalspiel (Logger im Test).

## 2. Offene Punkte / Entscheidungen für den Benutzer

- **B6-1 (Balance, würdevoller Bogen):** Gemessen ab dem echten Startbeutel **27** (W0-Notiz; §2.8 rechnete mit 31) fällt das Kapitel bei `reverent6` an **Tag 37 (B8)** statt B6 (§10: ≤ 36). Die ersten zwei Leichen kommen, bevor die Kapelle bezahlt ist → **3 statt 4 Aussegnungen**; Gruft 3 ist in 10 Tagen nicht bezahlbar → **5 statt 6 Umbettungen**. Ausgegeben 158 von 178 verfügbaren Münzen (89 %), morgens nie unter 16. Engpass neben den Münzen: **Eisen** (Start 2 Beschläge, 1 Erz; Stufe 1+2 brauchen 8 Beschläge + 3 Barren ≈ 14 Erz). Das liegt im Benutzerumfang „8–10 Spieltage“. **Keine Spielwerte geändert.** Vorschlag, falls B6 gewünscht: Kapelle 1 kostet 20 statt 25 Münzen.
- **B6-2 (Totengräber-Strategie „Gruft zuerst auf 3“):** Nach der 6. Umbettung kommen keine Leichen mehr, das Pflegegeld (4/Tag) ist die einzige Einnahme → Kapitel erst an **Tag 42** (13 Tage, §10: ≤ 38). Bewusste Wahl des Spielers; Test läuft 13 Tage.
- **B6-3 (`mender6`):** Kapelle zuerst + volle Pflege jeden Tag → letzte Stufe am Abend von Tag 39 oder 40 (eine Abendlänge Spielraum); Test 11 Tage. Andachten: **0** – im Fixture sind alle Geister zufrieden (W0-Notiz), es gibt nichts zu beruhigen; zufriedene Geister kommen nur über neue Gräber (+5).
- **B6-4 (`harvester6`):** Kapitel Tag 42 (B8), 14 Andachten für beraubte Seelen (alle höchstens gleichmütig), Ausgaben 227; „alle Stufe 3“ in 10 Tagen nicht erreicht (Gruft 3 ja, Kapelle 3/Schuppen 3 nein) – endet trotzdem reich (≈ 60–90). Befund E5 aus G5 wird gemildert, nicht gelöst.
- **E2 (Datenänderung QA6-04):** Leere Gebeinkisten und Altarkerzen bleiben beim „Überschuss einlagern“ beim Totengräber (Vertrag nennt nur `bone_box_full`). Bitte bestätigen.
- **E3 (Inventardruck):** Mit 20 Plätzen und Phase-6-Waren (Kisten, belegte Kisten, Kerzen) läuft das Inventar voll, bis der Schuppen steht; der Bot lagert dann Holz/Stein ein. Spielerisch gewollt? (kein Fix)
- **E4 (Kamera Gruft):** Kameragrenze Nord auf −2,4 m erweitert (QA6-A3) – Abweichung vom Raum-Layout W-Welt, gemeldet.

## 3. Playthrough-Bot Phase 6

`tests/integration/phase6_bot.gd` erweitert `Phase5Bot`: Osric (echter Dialog: `p6_intro`, Altarkerzen), Bau über das echte **Gebäude-Panel** (Knopf „Stufe n bauen“, ab Schuppen 2 „Fehlendes aus dem Schuppen holen“), Gebeinkisten an der Werkbank, Altgräber heben (`GravePlot`), Beisetzen am `OssuaryShelf`, vermauerte Tür/Gitter ansehen, Leichen über die echte **BuildingDoor** in die Gruft (Tisch, Kühlnische), **RoomExit**, Kirchpforte, Leichenzug (45 Min), **Katafalk**, **Kapellen-Panel** („Aussegnung halten“), zurück zum vorher ausgehobenen Grab, Stele über das Stein-Panel (Holen aus dem Schuppen an der Steinmetzbank), **Andachts-Panel**, Schuppen über das Truhen-Panel (`ChestTransfer`) und Holen an Werkbank/Esse/Bauplatz. Portale: die Regeln der Türen/Ausgänge (`can_interact`), dann `HutPortal.arrive` wie der Bett-Gang der Phase-3-Bots (ohne 0,5-s-Blende, die Uhr läuft über Wegminuten). Münzbuch: Phase 5 + Einnahmen „reinter“ (Umbettgeld) und „service“ (Gebühr), Ausgaben nach `coins_spent`-Zweck inkl. `building`.

`tests/integration/test_phase6_playthrough.gd` prüft: keine Fehler/Warnungen, keine Bot-Probleme (jede gewollte Handlung möglich), Wertebereiche (Qualität 0…400), Kapitel für **jede** Strategie inkl. der drei Bedingungen, Münzbuch (Ausgaben nach Zweck = Statistik; Start + Einnahmen − Ausgaben = Ende), Strategie-Erwartungen (Abweichungen von §10 siehe B6-1…4), `save_load6` = `reverent6` Zeile für Zeile.

| Strategie | Start | Tage | Kapitel (Tag) | Stufen-Tage | Aussegnungen | Andachten | Umbettungen | Einnahmen | Ausgaben | Ende | morgens min. (Ph. 6) | geholt aus Schuppen |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| reverent6 | v4 day30_reverent, 27 Münzen | 10 | 37 | crypt1: 30, chapel1: 32, shed1: 33, crypt2: 34, shed2: 36, chapel2: 37 | 3 | 0 | 5 | 151 (burial 67, stipend 40, gift 15, ilse 0, valuables 0, reinter 20, service 9) | 158 (osric 12, building 130, ilse 16) | 20 | 16 | workstone: 3 |
| mortician | v4 day30_reverent, 27 Münzen | 13 | 42 | crypt1: 30, crypt2: 32, crypt3: 34, chapel1: 35, shed1: 38, shed2: 38, chapel2: 42 | 1 | 0 | 6 | 168 (burial 71, stipend 52, gift 18, ilse 0, valuables 0, reinter 24, service 3) | 189 (osric 16, building 165, ilse 8) | 6 | 6 | – |
| mender6 | v4 day30_mender, 41 Münzen | 11 | 40 | chapel1: 30, crypt1: 34, shed1: 35, chapel2: 37, crypt2: 38, shed2: 40 | 5 | 0 | 5 | 160 (burial 67, stipend 44, gift 10, ilse 0, valuables 0, reinter 20, service 19) | 160 (osric 16, building 130, ilse 14) | 41 | 14 | – |
| harvester6 | v4 day35_harvester, 102 Münzen | 10 | 42 | crypt1: 35, chapel1: 36, shed1: 37, crypt2: 39, shed2: 41, chapel2: 42, crypt3: 44 | 4 | 14 | 6 | 188 (burial 46, stipend 40, gift 0, ilse 55, valuables 11, reinter 24, service 12) | 227 (osric 38, building 165, ilse 24) | 63 | 90 | wood: 2, workstone: 2 |
| founder | neues Spiel, 5 Münzen | 36 | 29 | crypt1: 23, chapel1: 25, shed1: 26, crypt2: 27, shed2: 28, chapel2: 29 | 3 | 0 | 5 | 481 (burial 269, stipend 129, gift 54, ilse 0, valuables 0, reinter 20, service 9) | 446 (osric 145, ilse 101, license 20, build 50, building 130) | 40 | 16 | wood: 2, workstone: 3 |
| save_load6 | v4 day30_reverent, 27 Münzen | 10 | 37 | crypt1: 30, chapel1: 32, shed1: 33, crypt2: 34, shed2: 36, chapel2: 37 | 3 | 0 | 5 | 151 (burial 67, stipend 40, gift 15, ilse 0, valuables 0, reinter 20, service 9) | 158 (osric 12, building 130, ilse 16) | 20 | 16 | workstone: 3 |

**Münzrechnung §2.8 nachgerechnet (Start 27 statt 31):** Einnahmen gemessen 151 (Pflegegeld 40, Umbettgeld 20, Bestattungen 67, Gebühren 9, Geistergaben 15) gegen §2.8 ≈ 153 ohne Start (36 + 24 + 70 + 15 + 8). Verfügbar 178 statt 184. Ausgaben 158 (Gebäude 130, Osric-Kerzen 12, Ilse-Leinen 16 – §2.8 kennt das Leinen nicht). Ohne Gruft 3 endet der Bogen bei 20 (§2.8: ≈ 38 – minus 4 Start, minus Leinen). Die Gebühren bleiben niedriger, weil zwei Leichen vor der Kapelle kommen.

## 4. Save-Fuzzer

`test_save_fuzzer.gd` + `test_fuzz_v5_real_mid_phase6_save`: Phase6Bot (`reverent6`) spielt 4 Tage ab `day30_reverent`, dann an Tag 34: Leiche in `niche_2` mit offenem Kältefenster, eine auf dem Katafalk, eine gehobene Kiste wartet, Schuppen halb voll, Totengräber in der Gruft – gespeichert (v5). Abgeschnitten, JSON- und native Mutationen + gezielte Mutationen der Phase-6-Teile (`buildings`, `ossuary`, `chapel`, `shed_store`, `cold_windows`, `room`, `slot_id`, `interior_id`) + 6 gezielte Fälle (alle Leichen in `niche_1`, alle auf dem Katafalk, Nische der Stufe 3 bei Gruft 2, alle Gebäude zurück auf den Bauplatz, `reinterred` über `lifted` hinaus, alle auf dem Gruft-Tisch). Neue Konsistenzprüfung: höchstens eine Leiche je Nische/Tisch/Katafalk, Nischen-Leiche nur in offener Nische, keine Leiche in Gruft/Kapelle der Stufe 0, Stufen 0…3, `reinterred ⊆ lifted ⊆` hebbare Altgräber, gehoben ⇒ nicht `OLD`. Ergebnis: v5 (real) 94 geladen / 25 abgelehnt, v5 (synthetisch) 89 / 24 – jeweils die zwei erlaubten Ausgänge, kein halb angewandter Zustand (nach QA6-08/QA6-10).

## 5. Art-/Ton-Prüfung

Bilder in `docs/reviews/phase6_wip/` angesehen, Befunde QA6-A1…A4 (Vorher/Nachher `qa_01…05_*.jpg`). Ohne Befund: Gebeine nur als Kisten mit Kreuz und gelehnte alte Steine, kein Schädel, kein Gore; Trauergäste still, gesenkte Köpfe; Chorfenster farbig, ohne Figuren/Symbole fremder Werke; Kapelle innen bei Tag warm, nachts nur Kerzenlicht am Altar; Schuppen schlicht. Texte: alle neuen deutschen Texte (Gebäude-Daten, Items, Altgräber-Zeilen, Osric, Geisterzeilen, Prompts, Panels, Zielzeilen, Hinweise) gelesen – Funde T1…T4, sonst trocken-melancholisch, keine Tippfehler. „Inventar“/„Gepäck“ werden seit Phase 3 beide verwendet (unverändert).

## 6. Performance (Phase 5 `c5bd76d` gegen Phase 6, gleiche Inszenierung, dreimal hintereinander)

`tools/qa/qa_p6_cpu.gd` (headless, v4-Fixture `day30_reverent`, Uhr läuft, Alter Hof; 1 500 Frames nach 300 Aufwärmframes) in beiden Builds abwechselnd (Rohdaten `qa_cpu_p5_vs_p6.txt`):

| Probe | Phase 5 Mittel (3 Läufe) | Phase 6 Mittel | Δ Mittel | Phase 5 Median | Phase 6 Median |
|---|---|---|---|---|---|
| day | 3.80 ms (3.83 / 4.11 / 3.44) | 4.41 ms (4.62 / 3.79 / 4.82) | +0.61 ms | 3.84 | 4.37 |
| night | 3.87 ms (3.73 / 4.29 / 3.59) | 4.26 ms (4.32 / 4.23 / 4.24) | +0.39 ms | 3.70 | 3.93 |

Im Mittel liegt Phase 6 **+0,4…0,6 ms** höher (Budget §9: +0,2 ms), die Streuung gleicher Läufe im Container reicht aber bis 1,0 ms (Phase 6 Tag 3,79…4,82, Phase 5 3,44…4,11) – das Budget ist hier nicht sicher zu messen (**offen, Messung auf echter Hardware empfohlen**); die Zuordnung im Phase-6-Build (Räume, Bauplätze/Türen, Phase-6-Systeme abwechselnd abgeschaltet) zeigt **keinen** Teil mit messbarem Anteil (abgeschaltet teils langsamer als an). Im Code laufen pro Frame nur die drei `BuildingExterior._process` (Glocke) und – im aktiven Raum – `InteriorLighting`/`ChapelRiteLights` (gedrosselt). Kein messbarer Phase-6-Hotspot → **nicht optimiert**. Render (W-Welt + Satz G6): Draw Calls außen ≤ 351, Kamera-Dreiecke ≤ 391 k, 2 Schattenlichter (`render_stats_p6.txt`). Spielstand 141 kB, Laden 267 ms (W-Welt).

## Tests

Volle Suite dreimal am Ende (Baseline vor W3: 1 999 bestanden):
- `p6qa_runA.log`: RESULT PASS (2017 bestanden, 0 fehlgeschlagen), 1147 s
- `p6qa_runB.log`: RESULT PASS (2017 bestanden, 0 fehlgeschlagen), 1151 s
- `p6qa_runC.log`: RESULT PASS (2017 bestanden, 0 fehlgeschlagen), 1139 s

## 7. Screenshot-Satz Gate G6 (`docs/reviews/phase6_round1/`, 1280×720, echte Phase-6-Welt und Innenräume)

| Bild | Motiv |
|---|---|
| `world_p6_00a_hof_before` | vor der Hütte vorher (Build `c5bd76d`, W-Welt) |
| `world_p6_00b_hof_sites` / `_00c_hof_crypt1` | nachher: Gruft 0 (Tisch noch da) / Gruft 1 (Tisch fort, Portal unter der Eiche) |
| `world_p6_01_overview_day`, `_01b_overview_zoom24` | Übersicht |
| `world_p6_02_crypt_l0…l3_day`, `_l3_night`, `_l3_zoom12` | Gruft außen, alle Stufen, Tag/Nacht |
| `world_p6_03_chapel_l0…l3_day`, `_05_chapel_l3_night` | Kapelle außen, alle Stufen, Nacht mit Totenleuchter und Geistern |
| `world_p6_04_shed_l0…l3_day`, `_l3_night` | Schuppen außen, alle Stufen, Nacht |
| `world_p6_06_crypt_int_l1_day` | Gruft innen Stufe 1, Tisch mit Leiche |
| `world_p6_07_crypt_int_l3_night` | Gruft Stufe 3 nachts, Nischen belegt, Kältehauch |
| `world_p6_08_ossuary_l2` / `_08b_ossuary_l3_grille` | Beinhaus mit Kisten und alten Steinen, vermauerte Tür / Gitter |
| `world_p6_09_chapel_int_l2_service`, `_10_chapel_int_l3_service` | Aussegnung mit Trauergästen (2 / 4) |
| `world_p6_11_chapel_int_l2_night_devotion` | Andacht nachts, Katafalk leer |
| `world_p6_12_shed_int_l3` | Schuppen innen |
| `world_p6_13_procession_gate` | Leichenzug an der Kirchpforte |
| `world_p6_14_old_grave_lifted` | gehobenes Altgrab, Aushub am Fußende |
| `perf_p6_01…05` + `render_stats_p6.txt` | Budget-Motive §9 |
| `ui_building_crypt`, `ui_building_fetch` | Gebäude-Panel, Holen-Knopf |
| `ui_exam_crypt` | Gruft-Tisch-Untersuchung (in der Gruft) mit Kühle-Zeile |
| `ui_chapel`, `ui_devotion` | Kapellen- und Andachts-Panel (in der Kapelle) |
| `ui_shed_chest` | Schuppen-Lager (im Schuppen) |
| `ui_hud_chapter` | HUD-Tooltip mit Kapitelzeile |
| `ui_chapter_roof_and_earth` | Abschluss „Unter Dach und Erde“ |
| `ui_osric_p6` | Osric mit Altarkerzen |

## 8. Tag für Tag (Phase-6-Bot)

#### reverent6

| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Gruft/Kapelle/Schuppen | Aussegnungen | Andachten | gehoben/beigesetzt | Nischen-Wartende | Gräber | frei | Qualität | Ruf | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | 27 | osric 2, building 20, ilse 4 | reinter 12, stipend 4 | 17 | 1/0/0 | 0 | 0 | 3/3 | 0 | 18 | 3 | 280 | 100 | 18 | offen |
| 31 | 17 | – | burial 13, gift 3, stipend 4 | 37 | 1/0/0 | 0 | 0 | 3/3 | 1 | 19 | 2 | 295 | 100 | 19 | offen |
| 32 | 37 | osric 2, building 25, ilse 6 | burial 14, gift 3, stipend 4 | 25 | 1/1/0 | 0 | 0 | 3/3 | 1 | 20 | 1 | 308 | 100 | 20 | offen |
| 33 | 25 | building 10 | service 3, burial 13, gift 3, stipend 4 | 38 | 1/1/1 | 1 | 0 | 3/3 | 1 | 21 | 0 | 326 | 100 | 21 | offen |
| 34 | 38 | building 30, ilse 2 | reinter 8, stipend 4 | 18 | 2/1/1 | 1 | 0 | 5/5 | 1 | 21 | 2 | 321 | 100 | 21 | offen |
| 35 | 18 | osric 2, ilse 4 | service 3, burial 13, gift 3, stipend 4 | 35 | 2/1/1 | 2 | 0 | 5/5 | 1 | 22 | 1 | 334 | 100 | 22 | offen |
| 36 | 35 | osric 2, building 15 | service 3, burial 14, gift 3, stipend 4 | 42 | 2/1/2 | 3 | 0 | 5/5 | 1 | 23 | 0 | 359 | 100 | 23 | offen |
| 37 | 42 | building 30 | stipend 4 | 16 | 2/2/2 | 3 | 0 | 5/5 | 1 | 23 | 0 | 357 | 100 | 23 | ✓ |
| 38 | 16 | osric 4 | stipend 4 | 16 | 2/2/2 | 3 | 0 | 5/5 | 1 | 23 | 0 | 352 | 100 | 23 | ✓ |
| 39 | 16 | – | stipend 4 | 20 | 2/2/2 | 3 | 0 | 5/5 | 1 | 23 | 0 | 358 | 100 | 23 | ✓ |

#### mortician

| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Gruft/Kapelle/Schuppen | Aussegnungen | Andachten | gehoben/beigesetzt | Nischen-Wartende | Gräber | frei | Qualität | Ruf | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | 27 | osric 2, building 20, ilse 4 | reinter 12, stipend 4 | 17 | 1/0/0 | 0 | 0 | 3/3 | 0 | 18 | 3 | 280 | 100 | 18 | offen |
| 31 | 17 | – | stipend 4 | 21 | 1/0/0 | 0 | 0 | 3/3 | 0 | 18 | 3 | 280 | 100 | 18 | offen |
| 32 | 21 | building 30 | burial 12, gift 3, stipend 4 | 10 | 2/0/0 | 0 | 0 | 3/3 | 1 | 19 | 2 | 291 | 100 | 19 | offen |
| 33 | 10 | ilse 4 | burial 13, reinter 8, gift 3, stipend 4 | 34 | 2/0/0 | 0 | 0 | 5/5 | 2 | 20 | 3 | 304 | 100 | 20 | offen |
| 34 | 34 | building 35 | burial 11, reinter 4, gift 3, stipend 4 | 21 | 3/0/0 | 0 | 0 | 6/6 | 3 | 21 | 3 | 313 | 100 | 21 | offen |
| 35 | 21 | building 25 | burial 11, gift 3, stipend 4 | 14 | 3/1/0 | 0 | 0 | 6/6 | 4 | 22 | 2 | 320 | 100 | 22 | offen |
| 36 | 14 | osric 12 | stipend 4 | 6 | 3/1/0 | 0 | 0 | 6/6 | 4 | 22 | 2 | 325 | 100 | 22 | offen |
| 37 | 6 | osric 2 | service 3, burial 24, gift 6, stipend 4 | 41 | 3/1/0 | 1 | 0 | 6/6 | 6 | 24 | 0 | 357 | 100 | 24 | offen |
| 38 | 41 | building 25 | stipend 4 | 20 | 3/1/2 | 1 | 0 | 6/6 | 6 | 24 | 0 | 350 | 100 | 24 | offen |
| 39 | 20 | – | stipend 4 | 24 | 3/1/2 | 1 | 0 | 6/6 | 6 | 24 | 0 | 356 | 100 | 24 | offen |
| 40 | 24 | – | stipend 4 | 28 | 3/1/2 | 1 | 0 | 6/6 | 6 | 24 | 0 | 352 | 100 | 24 | offen |
| 41 | 28 | – | stipend 4 | 32 | 3/1/2 | 1 | 0 | 6/6 | 6 | 24 | 0 | 347 | 100 | 24 | offen |
| 42 | 32 | building 30 | stipend 4 | 6 | 3/2/2 | 1 | 0 | 6/6 | 6 | 24 | 0 | 341 | 100 | 24 | ✓ |

#### mender6

| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Gruft/Kapelle/Schuppen | Aussegnungen | Andachten | gehoben/beigesetzt | Nischen-Wartende | Gräber | frei | Qualität | Ruf | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | 41 | osric 6, building 25 | stipend 4 | 14 | 0/1/0 | 0 | 0 | 0/0 | 0 | 18 | 0 | 255 | 100 | 17 | offen |
| 31 | 14 | – | stipend 4 | 18 | 0/1/0 | 0 | 0 | 0/0 | 0 | 18 | 0 | 255 | 100 | 18 | offen |
| 32 | 18 | – | stipend 4 | 22 | 0/1/0 | 0 | 0 | 0/0 | 0 | 18 | 0 | 255 | 100 | 17 | offen |
| 33 | 22 | – | stipend 4 | 26 | 0/1/0 | 0 | 0 | 0/0 | 0 | 18 | 0 | 255 | 100 | 17 | offen |
| 34 | 26 | building 20, ilse 4 | reinter 12, stipend 4 | 18 | 1/1/0 | 0 | 0 | 3/3 | 0 | 18 | 3 | 255 | 100 | 17 | offen |
| 35 | 18 | osric 2, building 10 | service 3, burial 13, gift 2, stipend 4 | 28 | 1/1/1 | 1 | 0 | 3/3 | 0 | 19 | 2 | 271 | 100 | 18 | offen |
| 36 | 28 | osric 2, ilse 2 | service 3, burial 14, gift 2, stipend 4 | 47 | 1/1/1 | 2 | 0 | 3/3 | 0 | 20 | 1 | 287 | 100 | 20 | offen |
| 37 | 47 | osric 2, building 30 | service 3, burial 12, gift 2, stipend 4 | 36 | 1/2/1 | 3 | 0 | 3/3 | 0 | 21 | 0 | 300 | 100 | 21 | offen |
| 38 | 36 | building 30, ilse 4 | reinter 8, stipend 4 | 14 | 2/2/1 | 3 | 0 | 5/5 | 0 | 21 | 2 | 300 | 100 | 19 | offen |
| 39 | 14 | osric 2, ilse 4 | service 5, burial 14, gift 2, stipend 4 | 33 | 2/2/1 | 4 | 0 | 5/5 | 0 | 22 | 1 | 317 | 100 | 22 | offen |
| 40 | 33 | osric 2, building 15 | service 5, burial 14, gift 2, stipend 4 | 41 | 2/2/2 | 5 | 0 | 5/5 | 0 | 23 | 0 | 334 | 100 | 23 | ✓ |

#### harvester6

| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Gruft/Kapelle/Schuppen | Aussegnungen | Andachten | gehoben/beigesetzt | Nischen-Wartende | Gräber | frei | Qualität | Ruf | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 35 | 102 | osric 2, building 20 | reinter 12, stipend 4 | 96 | 1/0/0 | 0 | 0 | 3/3 | 0 | 18 | 3 | 129 | 92 | 2 | offen |
| 36 | 96 | building 25, ilse 6 | burial 10, stipend 4 | 90 | 1/1/0 | 0 | 1 | 3/3 | 0 | 19 | 2 | 138 | 91 | 2 | offen |
| 37 | 90 | osric 8, building 10, ilse 6 | service 3, burial 11, stipend 4 | 95 | 1/1/1 | 1 | 2 | 3/3 | 0 | 20 | 1 | 147 | 91 | 2 | offen |
| 38 | 95 | osric 4 | service 3, burial 7, stipend 4 | 121 | 1/1/1 | 2 | 3 | 3/3 | 0 | 21 | 0 | 153 | 82 | 2 | offen |
| 39 | 121 | osric 2, building 30, ilse 4 | reinter 8, stipend 4 | 97 | 2/1/1 | 2 | 4 | 5/5 | 0 | 21 | 2 | 142 | 89 | 2 | offen |
| 40 | 97 | osric 4, ilse 4 | service 3, burial 9, stipend 4 | 122 | 2/1/1 | 3 | 5 | 5/5 | 0 | 22 | 1 | 153 | 82 | 2 | offen |
| 41 | 122 | osric 4, building 15 | service 3, burial 9, stipend 4 | 130 | 2/1/2 | 4 | 6 | 5/5 | 0 | 23 | 0 | 171 | 83 | 2 | offen |
| 42 | 130 | osric 2, building 30 | stipend 4 | 102 | 2/2/2 | 4 | 9 | 5/5 | 0 | 23 | 0 | 169 | 89 | 2 | ✓ |
| 43 | 102 | osric 6 | stipend 4 | 100 | 2/2/2 | 4 | 12 | 5/5 | 0 | 23 | 0 | 167 | 93 | 2 | ✓ |
| 44 | 100 | osric 6, building 35, ilse 4 | reinter 4, stipend 4 | 63 | 3/2/2 | 4 | 14 | 6/6 | 0 | 23 | 1 | 171 | 96 | 2 | ✓ |

#### founder

| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Gruft/Kapelle/Schuppen | Aussegnungen | Andachten | gehoben/beigesetzt | Nischen-Wartende | Gräber | frei | Qualität | Ruf | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 5 | osric 3 | burial 7, gift 2, stipend 1 | 12 | 0/0/0 | 0 | 0 | 0/0 | 0 | 1 | 5 | 9 | 26 | 1 | – |
| 2 | 12 | osric 14 | burial 7, gift 2, stipend 1 | 8 | 0/0/0 | 0 | 0 | 0/0 | 0 | 2 | 4 | 26 | 31 | 2 | – |
| 3 | 8 | osric 9 | burial 8, gift 2, stipend 2 | 11 | 0/0/0 | 0 | 0 | 0/0 | 0 | 3 | 3 | 37 | 36 | 3 | – |
| 4 | 11 | osric 15, ilse 1 | burial 10, gift 2, stipend 2 | 9 | 0/0/0 | 0 | 0 | 0/0 | 0 | 4 | 5 | 52 | 45 | 4 | – |
| 5 | 9 | osric 12, ilse 1 | burial 10, gift 2, stipend 2 | 10 | 0/0/0 | 0 | 0 | 0/0 | 0 | 5 | 4 | 64 | 51 | 5 | – |
| 6 | 10 | osric 12, ilse 1 | burial 8, gift 2, stipend 3 | 10 | 0/0/0 | 0 | 0 | 0/0 | 0 | 6 | 6 | 78 | 60 | 6 | – |
| 7 | 10 | osric 9, ilse 6 | burial 11, gift 2, stipend 3 | 11 | 0/0/0 | 0 | 0 | 0/0 | 0 | 7 | 5 | 96 | 67 | 7 | – |
| 8 | 11 | osric 6, ilse 6 | burial 11, gift 2, stipend 3 | 15 | 0/0/0 | 0 | 0 | 0/0 | 0 | 8 | 4 | 111 | 75 | 8 | – |
| 9 | 15 | osric 3, ilse 7 | burial 12, gift 2, stipend 4 | 23 | 0/0/0 | 0 | 0 | 0/0 | 0 | 9 | 9 | 123 | 85 | 9 | – |
| 10 | 23 | osric 3, ilse 6 | burial 13, gift 2, stipend 4 | 33 | 0/0/0 | 0 | 0 | 0/0 | 0 | 10 | 8 | 142 | 91 | 10 | – |
| 11 | 33 | osric 3, ilse 6 | burial 12, gift 2, stipend 4 | 42 | 0/0/0 | 0 | 0 | 0/0 | 0 | 11 | 7 | 157 | 95 | 11 | – |
| 12 | 42 | ilse 6 | burial 13, gift 2, stipend 4 | 55 | 0/0/0 | 0 | 0 | 0/0 | 0 | 12 | 6 | 169 | 98 | 12 | – |
| 13 | 55 | license 20, osric 12, ilse 7 | burial 13, gift 2, stipend 4 | 35 | 0/0/0 | 0 | 0 | 0/0 | 0 | 13 | 5 | 181 | 100 | 13 | – |
| 14 | 35 | build 10, ilse 6 | burial 13, gift 2, stipend 4 | 38 | 0/0/0 | 0 | 0 | 0/0 | 0 | 14 | 4 | 193 | 100 | 14 | – |
| 15 | 38 | osric 20, ilse 6 | burial 13, gift 2, stipend 4 | 31 | 0/0/0 | 0 | 0 | 0/0 | 0 | 15 | 3 | 205 | 100 | 15 | – |
| 16 | 31 | build 15, ilse 13 | burial 12, gift 3, stipend 4 | 22 | 0/0/0 | 0 | 0 | 0/0 | 0 | 16 | 2 | 217 | 100 | 16 | – |
| 17 | 22 | build 25 | burial 13, gift 3, stipend 4 | 17 | 0/0/0 | 0 | 0 | 0/0 | 0 | 17 | 1 | 230 | 100 | 17 | – |
| 18 | 17 | osric 6 | stipend 4 | 15 | 0/0/0 | 0 | 0 | 0/0 | 0 | 17 | 1 | 235 | 100 | 17 | – |
| 19 | 15 | ilse 13 | burial 12, gift 3, stipend 4 | 21 | 0/0/0 | 0 | 0 | 0/0 | 0 | 18 | 0 | 247 | 100 | 18 | – |
| 20 | 21 | osric 6 | stipend 4 | 19 | 0/0/0 | 0 | 0 | 0/0 | 0 | 18 | 0 | 258 | 100 | 18 | offen |
| 21 | 19 | osric 2 | stipend 4 | 21 | 0/0/0 | 0 | 0 | 0/0 | 0 | 18 | 0 | 258 | 100 | 18 | offen |
| 22 | 21 | – | stipend 4 | 25 | 0/0/0 | 0 | 0 | 0/0 | 0 | 18 | 0 | 258 | 100 | 18 | offen |
| 23 | 25 | building 20 | reinter 12, stipend 4 | 21 | 1/0/0 | 0 | 0 | 3/3 | 0 | 18 | 3 | 244 | 100 | 18 | offen |
| 24 | 21 | ilse 4 | burial 14, gift 3, stipend 4 | 38 | 1/0/0 | 0 | 0 | 3/3 | 0 | 19 | 2 | 270 | 100 | 19 | offen |
| 25 | 38 | osric 2, building 25, ilse 4 | burial 15, gift 3, stipend 4 | 29 | 1/1/0 | 0 | 0 | 3/3 | 0 | 20 | 1 | 285 | 100 | 20 | offen |
| 26 | 29 | building 10 | service 3, burial 14, gift 3, stipend 4 | 43 | 1/1/1 | 1 | 0 | 3/3 | 0 | 21 | 0 | 299 | 100 | 21 | offen |
| 27 | 43 | building 30, ilse 4 | reinter 8, stipend 4 | 21 | 2/1/1 | 1 | 0 | 5/5 | 0 | 21 | 2 | 301 | 100 | 21 | offen |
| 28 | 21 | osric 2, building 15, ilse 4 | service 3, burial 14, gift 3, stipend 4 | 24 | 2/1/2 | 2 | 0 | 5/5 | 0 | 22 | 1 | 319 | 100 | 22 | offen |
| 29 | 24 | osric 2, building 30 | service 3, burial 14, gift 3, stipend 4 | 16 | 2/2/2 | 3 | 0 | 5/5 | 0 | 23 | 0 | 334 | 100 | 23 | ✓ |
| 30 | 16 | osric 4 | stipend 4 | 16 | 2/2/2 | 3 | 0 | 5/5 | 0 | 23 | 0 | 331 | 100 | 23 | ✓ |
| 31 | 16 | – | stipend 4 | 20 | 2/2/2 | 3 | 0 | 5/5 | 0 | 23 | 0 | 336 | 100 | 23 | ✓ |
| 32 | 20 | – | stipend 4 | 24 | 2/2/2 | 3 | 0 | 5/5 | 0 | 23 | 0 | 334 | 100 | 23 | ✓ |
| 33 | 24 | – | stipend 4 | 28 | 2/2/2 | 3 | 0 | 5/5 | 0 | 23 | 0 | 328 | 100 | 23 | ✓ |
| 34 | 28 | – | stipend 4 | 32 | 2/2/2 | 3 | 0 | 5/5 | 0 | 23 | 0 | 330 | 100 | 23 | ✓ |
| 35 | 32 | – | stipend 4 | 36 | 2/2/2 | 3 | 0 | 5/5 | 0 | 23 | 0 | 330 | 100 | 23 | ✓ |
| 36 | 36 | – | stipend 4 | 40 | 2/2/2 | 3 | 0 | 5/5 | 0 | 23 | 0 | 336 | 100 | 23 | ✓ |

#### save_load6

| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Gruft/Kapelle/Schuppen | Aussegnungen | Andachten | gehoben/beigesetzt | Nischen-Wartende | Gräber | frei | Qualität | Ruf | zufrieden | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | 27 | osric 2, building 20, ilse 4 | reinter 12, stipend 4 | 17 | 1/0/0 | 0 | 0 | 3/3 | 0 | 18 | 3 | 280 | 100 | 18 | offen |
| 31 | 17 | – | burial 13, gift 3, stipend 4 | 37 | 1/0/0 | 0 | 0 | 3/3 | 1 | 19 | 2 | 295 | 100 | 19 | offen |
| 32 | 37 | osric 2, building 25, ilse 6 | burial 14, gift 3, stipend 4 | 25 | 1/1/0 | 0 | 0 | 3/3 | 1 | 20 | 1 | 308 | 100 | 20 | offen |
| 33 | 25 | building 10 | service 3, burial 13, gift 3, stipend 4 | 38 | 1/1/1 | 1 | 0 | 3/3 | 1 | 21 | 0 | 326 | 100 | 21 | offen |
| 34 | 38 | building 30, ilse 2 | reinter 8, stipend 4 | 18 | 2/1/1 | 1 | 0 | 5/5 | 1 | 21 | 2 | 321 | 100 | 21 | offen |
| 35 | 18 | osric 2, ilse 4 | service 3, burial 13, gift 3, stipend 4 | 35 | 2/1/1 | 2 | 0 | 5/5 | 1 | 22 | 1 | 334 | 100 | 22 | offen |
| 36 | 35 | osric 2, building 15 | service 3, burial 14, gift 3, stipend 4 | 42 | 2/1/2 | 3 | 0 | 5/5 | 1 | 23 | 0 | 359 | 100 | 23 | offen |
| 37 | 42 | building 30 | stipend 4 | 16 | 2/2/2 | 3 | 0 | 5/5 | 1 | 23 | 0 | 357 | 100 | 23 | ✓ |
| 38 | 16 | osric 4 | stipend 4 | 16 | 2/2/2 | 3 | 0 | 5/5 | 1 | 23 | 0 | 352 | 100 | 23 | ✓ |
| 39 | 16 | – | stipend 4 | 20 | 2/2/2 | 3 | 0 | 5/5 | 1 | 23 | 0 | 358 | 100 | 23 | ✓ |

