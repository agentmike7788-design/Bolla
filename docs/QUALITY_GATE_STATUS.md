# Quality Gate Status

| Gate | Phase | Status | Datum | Freigabe durch Benutzer |
|---|---|---|---|---|
| G0 | Projektsetup | ✅ **PASSED** | 27.09.2026 | ✅ „Phase 0 freigegeben" (27.09.2026) |
| G1 | Art Direction | ✅ **PASSED** (Runde 1) | 27.09.2026 | ✅ „Art Direction freigegeben" (27.09.2026) |
| G2 | Vertical Slice | ✅ **PASSED** (nach Änderungsrunde 1: Leichen/Kutscher/Hauptfigur verschönert; Änderungsrunde 2: Hütte 5 × 4 m + begehbarer Innenraum mit Bett, Ofen, Truhe, Grabregister) | 27.09.2026 | ✅ „Vertical Slice freigegeben" (27.09.2026) |
| G3 | Friedhof vollständig ausbauen | ✅ **PASSED** (Runde 1; 1120 Tests; Bilder `docs/reviews/phase3_round1/`) | 27.09.2026 | ✅ „Phase 3 freigegeben" (27.09.2026) |
| G4 | Leichensystem erweitern | ✅ **PASSED** (Runde 1; 1473 Tests; Bilder `docs/reviews/phase4_round1/`; Lampe 2,2/4,5 m und Verfall-Sichtweite 40 m mit freigegeben) | 28.09.2026 | ✅ „Phase 4 freigegeben" (28.09.2026) |
| G5 | Crafting und Ressourcen | ✅ **PASSED** (Runde 1; 1748 Tests; Bilder `docs/reviews/phase5_round1/`; Werkhof-Lage, Erlen-Verschiebung und Tempo wie gebaut freigegeben, Münzausgleich Verwerten → Phase 10) | 28.09.2026 | ✅ „Phase 5 freigegeben" (28.09.2026) |
| G6 | Gebäude | ✅ **PASSED** (Runde 1; 2017 Tests; Bilder `docs/reviews/phase6_round1/`; Tempo, Schuppen-Ausnahmen, Taschengröße und Gruft-Kamera wie gebaut freigegeben) | 03.10.2026 | ✅ „Phase 6 freigegeben" (03.10.2026) |
| G7 | Dorf | ✅ **PASSED** (Runde 2; 2472 Tests; Bilder `docs/reviews/phase7_round1/` + `phase7_round2/`; Ton, Licht, Gruft-Treppe, Flackern, Dorfkirche, Karte, neue Gesichter, Werkzeuge/Schaufel in der Hand, sichtbare Grablegung, Balance Kapitel B11 / Münzen 60–71; Lenz 16–18 Uhr in der Kirche, 9. Rig-Knochen `tool` und Kleinigkeiten wie gebaut freigegeben) | 04.10.2026 | ✅ „Phase 7 freigegeben" (04.10.2026) |
| G8 | NPCs | 🟡 **PENDING Runde 2** (Gruft-Eingang neu, Besuche länger + Torglocke, Münzausgleich, Vasen-Herkunft; Licht E8-1 bestätigt) · 2903 Tests; Bilder `docs/reviews/phase8_round1/`; Browser-Testversion v9) | 10.10.2026 | ⏳ wartet auf „Phase 8 freigegeben" |

**ART STYLE LOCK:** ✅ **ACTIVE** seit 27.09.2026 (Referenz: `src/world/art_prototype/`, Screenshots `docs/reviews/phase1_round1/`). Keine grundlegende Stiländerung ohne Benutzerfreigabe.

## G8 – QA-Protokoll W3 (vorläufig – Benutzerprüfung offen)

- **G8 Runde 4 – Arbeitsbewegungen der Dorfbewohner (Benutzerentscheidung „ja die sollen eigene arbeitsbewegungen bekommen“; Benutzerprüfung offen):** Bestandsaufnahme aller Zeitpläne (Daten + Laufzeit) → an Arbeitsorten standen Rosine (Schanktisch), Lenz (Kirchtür, Altar), Fenner (Amtstisch, Aushangbrett), Quast (Pult) mit `idle`, Liesel spann am Waschplatz und am Gruft-Tisch (`work`), Osric rauchte mit `talk`, Jakob half im Krug mit `idle`. Neu: `polish_mug`, `read_breviary`, `pray_altar` (zum Altar gewandt), `desk_files` (Stempel), `proclaim` (Bekanntmachung mit Siegel), `desk_write` (Feder), `mix_vial` (Fläschchen), `wash_brook` (kniend an den Waschsteinen, zum Bach), `wash_body` (Leichenwäsche), Osric `smoke` mit Rauchwölkchen am Marker `pipe_smoke`; Jakob fegt den Krug (`sweep`). Requisiten als Kindmeshes in der Faust (nur mit ihrem Clip), Körper und alte Clips hash-gleich, ≤ 9000 Dreiecke je Figur, Export bytegleich. Verdrahtung über `ScheduleEntry.animation` und `data/config/npc_work_config.tres` (Arbeits-Clips, Arbeitsrichtung, Pause 2,8 m, Rauch); tritt der Totengräber heran oder spricht er sie an, ruht die Arbeit, die Figur wendet sich ihm zu (`talk` im Gespräch). Quasts Stehplatz 0,27 m näher ans Pult. Kontaktbögen am echten Arbeitsort (Forward+ und `_web`): `docs/reviews/phase8_round4/dorf_*.jpg`, Notiz `dorf_arbeit.md`; Tests `test_npc_work` (unit + integration).
- **G8 Runde 4 – Leichentisch und Lieferung (Benutzerentscheidung „1 ja kannst du 8 sec machen bei 2. ja soll etwas länger dauern und das auswahl bild muss weg der verdekt den leichentisch“; Benutzerprüfung offen):** **Auswahlbild:** Das Tisch-Panel `corpse_exam` lag zweispaltig (~1250 von 1920 px) mittig mit Abdunklung und blieb während jeder Arbeit offen (nur Balken) – Tisch und Totengräber waren verdeckt. Jetzt rechts angedockt, einspaltig (~650 px, Inhalt rollt), ohne Abdunklung; während einer daraus gestarteten Arbeit ausgeblendet (HUD-Balken unten, weiter modal), danach zurück mit Fokus; Maus/Tastatur geprüft (`UIPanel.hide_while_working` / `dock_right`, `UIKit.docked_right`, `GameHud.set_work_view`). Präparierpult (1500 px) und Werkbank (900 px) verdecken die Figur weiterhin mittig – nur notiert. **Tisch-Arbeiten:** Nur am Tisch läuft der Balken mindestens 3,0 s und Ziehen des Werkzeugs + 2 Clip-Zyklen (`tool_anim_config.tres` `table_real_seconds_min`, `table_work_cycles`; 3,0–3,9 s statt 1,5 s), Spielminuten unverändert, andere Aktionen 1,5 s. **Lieferung:** `unload_minutes` 8 → 16 (= 8 s real bei 0,5 s/Spielminute); Aufbruch 06:44, an der Bahre 07:24, Lieferung weiter 07:40, Torglocke ~07:44, 07:46 an den Griffen, bis 10:00, Abend unverändert. Anteile neu (hinübertreten 22 %, heben 15 %, tragen 26 %, ablegen 18 %, neu: kurz an der Bahre stehen 19 % `idle`), damit `load_lift`/`load_lower` mit ~1,2 × ihrer Länge laufen statt 1,8–2 × gedehnt; keine Änderung an `npc.gd`. Vertrag „(G8 Runde 4 angepasst)“. Tests `test_ui.gd`, `test_table_duration.gd` (neu), `test_table_work.gd`, `test_cart_delivery*.gd`, `test_schedule.gd`, `test_graveyard_world.gd`. Bilder `docs/reviews/phase8_round4/` (`tisch_ui_vorher*/nachher*`, `tisch_ui_ablauf*`, `arbeit_ablauf*`, `osric_abladen*`, je `_web`), Notiz `runde4_tisch_lieferung.md`. Volle Suite 2965/2965 grün (`vs/g8-r4-table`).
- **G8 Runde 3 – Lieferung mit dem Holzkarren (Benutzerprüfung offen):** „ich dachte die neuen leichen werden mit dem holz wagen hergebracht" → Befund: Osric schob den Karren mit der Leiche zwar heran, aber um 07:40 sprang sie ohne jede Bewegung vom Karren auf die Bahre (er stand an den Griffen), wer den Moment verpasste, sah nur eine Leiche auf der Bahre; Story-Leichen lagen in einem falschen (zufälligen) Look auf dem Karren, an Reserve-Tagen verschwand die Karren-Leiche um 07:40 ins Nichts. Jetzt: Osric bricht 06:52 auf, steht 07:32 an der Bahre, tritt neben den Karren, hebt die Leiche herunter (`load_lift`), trägt sie hinüber (`carry_walk`), legt sie ab (`load_lower`) – um 07:40 liegt sie auf der Bahre und gilt als geliefert, danach geht er zurück zu den Griffen (Dialog ab 07:43). Ladung = Plan der echten Lieferung (`CorpseManager.cart_load`), alles aus der Uhr (Zeitsprung, Dorf, Laden konsistent), kein neues Spielstand-Feld. Werte `data/config/cart_delivery_config.tres`. Bilder und Notiz `docs/reviews/phase8_round3/` (`delivery.md`). 2933 Tests grün.
- **G8 Runde 3 – Lieferung, Prüfung im echten Spiel (Benutzerprüfung offen):** „im spiel sah es gerade nicht so aus wie auf den bilder", „er kam ohne karren und hat die leiche abgelegt" → Befund nur im **Export**: Godot 4.7.2 leert beim Umwandeln der Text-Ressourcen in Binärdateien (`editor/export/convert_text_resources_to_binary`, Standard an) alle `Packed*Array`-Werte (353 Stück), u. a. alle Wegpunkte der Zeitpläne – im Browser blieben Osric und sein Karren am `road_end` außer Sicht, die Abladehaltung trug die Leiche in 1 s über 28 m zur Bahre; ebenso Leichennamen, Plauder-Zeilen, Mischminuten der Atmosphäre (helle Nächte im Browser). Editor-Projekt, Bilder und Tests waren nicht betroffen. Fix: `project.godot` `[editor] export/convert_text_resources_to_binary=false`; neu exportiertes Web-pck im Compatibility-Renderer zeigt denselben Ablauf wie das Projekt. Nebenbei: nach `time`-Sprung platziert sich Osric sofort (`Npc._on_time_skipped`, nur Figuren mit Karren; vorher schwang der Karren ~1 s bis 3 m herum). Geprüft: neues Spiel + Konsole `tp gate` / `time 07:15|07:25|07:35|07:38|07:45` mit frei laufender Uhr, ohne `time` ab 06:30, 60 und 4 Bilder/s, v7-Stand von vor dem Umbau (07:20/07:36), Spieler im Weg (blockiert nichts, Figuren laufen durch ihn), LOD/Culling/Clips im pck in Ordnung. Abladen dauert real 4 s (Tragen 1,1 s) – Länge (`unload_minutes`) ist Benutzerentscheidung. Tests: `test_cart_delivery_live.gd` (echter Ablauf, laufende Uhr, Debug-Konsole), `test_export_packed_arrays.gd` (Einstellung + echter Export in temporäres pck, alle Packed-Arrays gegen die Quellen). Bilder `docs/reviews/phase8_round3/delivery_game_*.jpg` (Forward+), `*_web.jpg` (exportiertes pck), `*_before_web.jpg` (pck der Browser-Testversion); Notiz `delivery.md` §„Prüfung im echten Spiel".
- **G8 Runde 3 – Torglocke nach der Lieferung (Benutzerwunsch, Benutzerprüfung offen):** „und er soll an der glock klingeln das ich höre wen eine neue leiche da ist" → nach dem Ablegen (07:40) geht Osric um das Bahrenende zur Glocke am östlichen Torpfosten, zieht zweimal daran (neuer Clip `ring_bell`, Körper/alte Clips hash-gleich), 07:43,8 schwingt sie und `gate_bell` erklingt +8 dB (ganzer Friedhof); in Haus/Gruft/Dorf nur HUD „Am Tor läutet es – Osric hat eine neue Leiche gebracht."; Zeitsprung/Schlafen läuten nicht (danach nur Hinweis), Laden meldet nichts nach; 07:46 an den Griffen, Dialog/Leinen bis 10:00, Abfahrt 10:00 und Abendbesuch im exportierten pck geprüft. Werte `cart_delivery_config.tres` (`ring_bell`, `bell_*`, `return_minutes` = 1 von der Glocke). Tests `test_gate_bell_delivery.gd`, `test_cart_delivery_live.gd`. Bilder `delivery_game_0741_6 … 0746_4(_web).jpg`. Volle Suite 2959/2959 grün (`vs/g8-delivery2`).
- **G8 Runde 3 – Animationen (Benutzerkritik „annimationen fehlen“, „die leichen preperation annimation fehlen auch“; Benutzerprüfung offen):** Jede Tisch-Aktion hat ihren eigenen Clip statt des generischen Greifens `interact`: untersuchen (`table_examine`), Kleidung/Taschen durchsuchen (`table_search`), waschen mit dem Tuch (`table_wash`), Organentnahme mit dem Skalpell unter dem Tuch, Gesicht abgewandt (`table_cut`), aufbahren/kämmen am Kopfende (`table_comb`), mit Wacholder räuchern (`table_smoke`), Leichentuch/Totenhemd – Leinen zwischen beiden Fäusten ausbreiten (`table_shroud`), Zopf (`table_snip`), Zähne (`table_pull`). Die kleinen Werkzeuge kommen aus der Werkzeugtasche (`hand_draw`/`hand_stow`, wie Axt und Hammer) und sind eigene `ph_tool_*` am neuen Marker `tool_hand`; er tritt dabei an seinen Arbeitsplatz (Längsseite, von der Kamera abgewandt; Kopfarbeit am Kopfende; `ToolAnimConfig.table_*`). Audit aller zeitgesteuerten Aktionen mit weiteren Clips `pray` (Kapelle), `write` (Register), `bench_work` (Pult, Archiv), `place_low` (Beinhaus, Haufen, Deko, Schuppen), `weed_pull` (Unkraut, Flachs, Kräuter), `rake` (Laub, `ph_tool_rake`), `fill_can` (Regentonne) und vorhandenen (`kneel_place` für Blumen/Kranz/Kerze, `chisel` fürs Nachmeißeln); Verdrahtung nur über `data/config/tool_anim_config.tres` (`action_clips`). NPC-Lücken (Lenz/Quast/Wirt „stehen“, Osrics Pfeife) offen notiert. Tabelle `docs/reviews/phase8_round3/animations_audit.md`, Kontaktbögen `docs/reviews/phase8_round3/tisch_*.jpg`, `arbeit_*.jpg` (+ `_web`). Körper-Mesh und alle alten Clips bitgleich. 2924 Tests grün.
- **G8 Runde 2 – Gruft-Eingang neu (Welt/Asset, Benutzerprüfung offen):** Portal in der Südwestecke um 56° zum Weg gedreht (−9,5 | 5,6), größer (3 m breit, Giebel 3,0 m, Säulen, Gebälk mit Inschrift), offener Treppenschacht 1,6 × 1,3 m mit Geländer und zwei Pfeiler-Laternen, gepflasterter Vorplatz + Plattenweg zum Hauptweg am Tor, dunkles bemoostes Mauerwerk mit Efeu/Patina statt Grashügel; Eiche, Gräber, Zaun unverändert, nur Laubstellen `dirt_y11/_y12` versetzt; alte Stände: wer im neuen Mauerwerk/unter dem Boden steht, landet am Treppenkopf, Zier im neuen Bauplatz einmal geräumt. Bilder `docs/reviews/phase8_round2/gruft_*.jpg` (+ `_web`), Details `docs/WORLD_DESIGN.md` (G8 Runde 2). 2903 Tests grün.

- **G8 Runde 2 – Lichtgang (Licht/Asset, Benutzerprüfung offen):** „Laternen nur Leuchtpunkte" → echte Handlaterne an allen Laternenträgern (Eisenrahmen, Glas `mat_lantern_glass`, Dach mit Kamin, Bügel, Kerze mit Flamme; 146 Dreiecke, Körper-Hashes unverändert), neuer Clip `lantern_idle`; der Zug trägt die Laterne jetzt auch im Spiel (hinauf/hinab `lantern_walk`, an Grab/Kirchhof `lantern_idle` – vorher nur in den Bildern). `CarriedLanterns`: 4 Pool-Lichter ohne Schatten für die nächsten Laternen (die Kerzen geben ebenso viele ab, ≥ 2 bleiben), weicher Fake-Bodenfleck für alle übrigen, Flamme/Glas/Licht/Fleck flackern im Gleichtakt, Pendeln im Gehen (Werte `data/config/fx/carried_lanterns.tres`). „Im Browser heller" → Ursache fehlender Volumennebel (und SSAO) im Compatibility-Renderer; dort Tiefennebel als Ersatz über `data/atmosphere/compat_overrides.tres` (Presets bytegleich), Browser-Zweige in den additiven Shadern. Messung Browser gegen Forward+: Lichtgang −6…+8 % (vorher +50…+56 %), Dorf nachts ±1 % (vorher +68 %), Gruft +6…+7 % (vorher +43…+55 %); offen: warme Bodenpfützen der Übersicht im Browser schwächer (8 Lichter je Mesh). Bilder `docs/reviews/phase8_round2/lichtgang_*.jpg`, `laterne_nah*.jpg`, Messung `lichtgang_messung.md`. 2912 Tests grün.
- Befunde, Playthrough-Tabellen mit Münzbuch, Fuzzer, Art-Prüfung, Performance: `docs/reviews/phase8_round1/qa_playthrough.md` (Rohdaten `qa_cpu_p8.txt`).
- Screenshot-Satz Gate G8 (§11, echter Renderer, 1280×720, nach allen Fixes): `docs/reviews/phase8_round1/` (Friedhof `p8_02…p8_27`, Dorf `p8_14…p8_20`, `p8_28`, Sicht `p8_vis_*`, Budget `perf_p8_01…05` + `render_stats_p8_*.txt`, UI `ui_p8_*`, Compatibility `p8_08/12/22_web`, Asset-Tafeln als `p8_00`/`p8_01`), Kontaktblatt `p8_contact_sheet_final.jpg`.
- Befunde behoben: QA8-03 (Fenner 2 / Rosine 3 nicht erfüllbar – hoch), QA8-18 (Besucherin nach dem Laden mitten im Besuch unsichtbar – hoch), QA8-17 (Engine-Fehler bei jedem Laden eines Phase-8-Stands – mittel), QA8-01/04/05/06 (Gefallen-Panel, Registerauszug, Jakobs freier Tag, Liesels Wäsche – mittel), QA8-07…16, 19, 20 (klein: Rechen tragen, Kerze vor Blumen, Werkbank-Flag, „Zwei Münzen“, Pflegestellen am Zaun, Ladestände bereinigen, Gießtakt, Lichtgang-Zug, Münz-Prompt, Kapiteltext ohne „Phase“, Besuchs-Flags beschädigter Stände), Art QA8-A1…A8 (Veit sitzt, Münzen, Krankenlicht, Hut, Novemberdämmerung, Stoppeln, Jakobs Haar, Hannes Kiepe); jeder mit Regressionstest (`tests/unit/test_phase8_qa.gd`, `tests/integration/test_phase8_qa.gd`, Fuzzer, `test_apprentice_day`, `test_visit_routes`, `test_phase8_loop`).
- Playthrough-Bot (`phase8_bot.gd`): `kindly8` Kapitel B10 (Tag 62), 48 → 70; `anatomist8` B8, `night8`/`night8b` B9 (Lambert gemeldet / laufen gelassen), `founder8` Tag 63, `lazy8` ohne Kapitel (gewollt), `save_load8` zeilengleich; morgens nie < 24; keine Fehler/Warnungen.
- Save-Fuzzer: echter v7-Stand mitten im Bogen + Phase-8-Konsistenzprüfungen.
- Entscheidungen offen: P8-1 (Phase-8-CPU knapp über Budget auf Cloud-CPU), P8-2 (609 k Dreiecke bei Maximal-Zoom am Lichtgang).
- **G8 Runde 1 – Benutzerentscheidungen** („die 4 offenen Punkte kannst du alle machen", umgesetzt auf `vs/g8-balance`, Vertrag „(G8 Runde 1 angepasst)", 2900 Tests grün):
  - **E8-1 Licht: vom Benutzer bestätigt** – kürzere Novembertage (Zeit-Schlüssel ab Tag 50 → 56) und helleres Krankenlicht (2,2 / 6 m) bleiben wie gebaut; nichts geändert.
  - **B8-1 Besuche:** Haushalte warten nach dem Ansehen bis zu 100 Min (`wait_minutes` 10 → 100), nie über 16:30 (`wait_until_minute`), und warten **immer** auf ein Wort (`wait_always`); nach dem Gespräch gehen sie 3 Min später (`leave_after_talk_minutes`); Bewohner 18 Min (Theres bis 15:30, Liesel bis 12:00 in den Daten-Zeitplänen). Die Figur bleibt jetzt auch wirklich am Grab stehen (vorher lief sie nach dem Ansehen fort, während Visitors noch „wartet" meldete). **Torglocke** `ph_prop_gate_bell` am östlichen Torpfeiler (Layout `phase8.gate_bell`, `GateBell`, Cue `gate_bell`) läutet beim Heraufkommen, HUD-Notiz „Am Tor läutet es – Martha Kehr kommt herauf." (nur auf dem Friedhof), Karten-Marker wie bisher. Bild `docs/reviews/phase8_round2/torglocke.jpg`. `kindly8` verpasst 1 von 19 Besuchen (vorher 10 von 19).
  - **E8-2 / B8-3 Münzen:** Pflegegeld nach Bedarf – ab Phase 8 bleibt es an Tagen mit ≥ 80 Münzen (Beutel + Truhen + Lohndose) in der Gemeindekasse (`ReputationConfig.stipend_purse_cap`; Phase-3-Staffel unverändert); Gerede über die Gläser dorfweit: jedes Trinkgeld −1, sobald je ein Präparat verkauft wurde (`VisitorConfig.rumor_tip_malus`). Ergebnis s. Bot-Tabelle in `docs/reviews/phase8_round1/qa_playthrough.md` §7.
  - **B8-2 Vase:** Wunschtext „Eine Vase aus Stein … wie du sie an deiner Werkbank machst." und Wunschkarte „Woher: Grabvase: an der Werkbank (15 Min) aus 1 Stein und 1 Samen – Samen gibt es bei Theres im Krämerladen …" (`WishData.source_text`).

## G7 – QA-Protokoll W3 (Agent 19, vorläufig – Benutzerprüfung offen)

- Befunde, Playthrough-Tabellen mit Münzbuch, Fuzzer, Art-Prüfung, Performance: `docs/reviews/phase7_wip/qa_playthrough.md` (CPU-Rohdaten `qa_cpu_p7.txt`).
- Screenshot-Satz Gate G7 (§11, echtes Dorf, echte Räume, echter Renderer, 1280×720): `docs/reviews/phase7_round1/` (Welt `p7_*`, Budget `perf_p7_*` + `render_stats_p7_*.txt`, UI `ui_*` im echten Dorf), Kontaktblatt `p7_contact_sheet_final.jpg`.
- Befunde behoben: QA7-11 (Vorlesung im echten Spiel unerreichbar – Quast war nachts zu Hause – hoch), QA7-13 (FILLED-Grab mit Präparat im Gepäck nicht per [E] zu markieren – mittel), QA7-12 (Lindenacker `l_04`/`l_08` Grube über dem Zaun – mittel), QA7-01/02/04/05/06 (doppelte Verkaufs-Deltas, Stufen doppelt definiert, Kältefenster der Länge 0, Zeitpläne der G7-Motive, Rabatt-Lesbarkeit), Art QA7-A1…A4 (Esse-Glut, Bach, Pult, Trauerflor), Werkzeug A5/A6; jeder mit Regressionstest (`tests/unit/test_phase7_qa.gd`, `tests/integration/test_phase7_qa.gd`, Fuzzer).
- Playthrough-Bot (`phase7_bot.gd`, echte Portale/Dialoge/Panels): `neighbor7`, `anatomist7`, `save_load7` je 13 Tage ohne Fehler und Warnung; Kapitel „Ein Name im Dorf“ an Tag 42; Ende 91 / 107 Münzen; `save_load7` zeilengleich zu `neighbor7`.
- Save-Fuzzer um einen echten v6-Stand mitten in Phase 7 erweitert – kein halb angewandter Zustand.
- Datenänderungen: Zeitpläne (Quast Lesepult, Theres' Brunnenpause 16:00, Liesel `v_well_w`, Osric Abendweg), Lindenacker `pit_variant`; keine Münz-/Beziehungswerte. Entscheidungen B7-1 (Kapitel zu früh), B7-2, E7-1…3 stehen im Bericht.

## G6 – QA-Protokoll W3 (Agent 19, vorläufig – Benutzerprüfung offen)

- Befunde, Playthrough-Tabellen mit Münzbuch, Fuzzer, Art-/Ton-Prüfung, Performance: `docs/reviews/phase6_wip/qa_playthrough.md` (Vorher/Nachher `docs/reviews/phase6_wip/qa_01…05_*.jpg`, CPU-Rohdaten `qa_cpu_p5_vs_p6.txt`).
- Screenshot-Satz Gate G6 (§11, echte Phase-6-Welt und Innenräume, 1280×720): `docs/reviews/phase6_round1/` (Welt `world_p6_*`, Budget `perf_p6_*` + `render_stats_p6.txt`, UI `ui_*` jetzt in den echten Räumen).
- Befunde behoben: QA6-01 (Kapitel fiel nicht, wenn das Grabzeichen der ausgesegneten Leiche zuletzt kam – hoch), QA6-07 (Aussegnung scheiterte am Ende an der Frische – hoch), QA6-02/03/04/06/08/10/11 (Trauergäste im Kapitel-Panel, `Buildings.open()`, Schuppen behält Kisten/Kerzen, Gruft-Zustand vor den Bildern, Lade-Bereinigung der Leichenplätze, Zahl im Flag, alter Tisch über `apply_levels`), Art QA6-A1…A4 (Gruft-Nebel, Gras im gehobenen Altgrab, Gruft-Kamera zum Beinhaus, UI-Bilder in den Räumen), Ton T1…T4; jeder mit Regressionstest (`tests/integration/test_phase6_qa.gd`, Fuzzer).
- Playthrough-Bot (`phase6_bot.gd`, echte Panels): 6 Strategien (reverent6, mortician, mender6, harvester6, founder, save_load6) ohne Fehler und ohne Warnung; **alle erreichen „Unter Dach und Erde“** (Tag 29–42); `save_load6` zeilengleich zu `reverent6`; Phase-3/4/5-Bot-Erwartungen grün.
- Save-Fuzzer um einen echten v5-Stand mitten in Phase 6 erweitert – kein halb angewandter Zustand.
- Datenänderungen: nur `shed_config.excluded_items` (+ `bone_box`, `altar_candle`), Gruft-Nebellicht (`fog_day/night_energy`), Kameragrenze Gruft. Keine Münz-/Mengenwerte geändert. Entscheidungen B6-1…4 (Bogen B8 statt B6 bei Start 27, Totengräber 13 Tage, mender 11 Tage, harvester), E2–E4 stehen im Bericht.

## G5 – QA-Protokoll W3 (Agent 19, vorläufig – Benutzerprüfung offen)

- Befunde, Playthrough-Tabellen mit Münzbuch, Fuzzer, Art-/Ton-Prüfung, Performance: `docs/reviews/phase5_wip/qa_playthrough.md` (Vorher/Nachher `docs/reviews/phase5_wip/qa_*.jpg`, CPU-Rohdaten `qa_cpu_p4_vs_p5.txt`).
- Screenshot-Satz Gate G5 (§11, echte Phase-5-Welt, 1280×720): `docs/reviews/phase5_round1/` (Welt `world_p5_*`, Budget `perf_p5_*` + `render_stats.txt`, UI `ui_*`).
- Stand der Befunde: 11 behoben (QA5-01…11: Münzbuch „Bau“, atomares Hauen, Stein auf geklemmtem Grab, Werkzeug-Notiz, Am-Bruch-Kanten/Findlinge, Erlen-Lesbarkeit, Rauch, Gürtel-Infozeile, zweizeilige Namen, Ablage zur Kamera, Kapiteltext), jeder mit Regressionstest (`tests/integration/test_phase5_qa.gd`).
- Playthrough-Bot (`phase5_bot.gd`): 6 Strategien (reverent5, toolsmith, mender, harvester5, crafter, save_load5) ohne Fehler und ohne Warnung; alle erreichen „Namen in Stein“ (Tag 20–29); würdevoll gibt 138 von 165 Münzen aus, morgens nie unter 17. Phase-3/4-Bot-Erwartungen weiter grün.
- Save-Fuzzer um einen echten v4-Stand mitten in Phase 5 erweitert (Meiler, Ablage 2/3, Erlen gemischt, Gürtel voll) – kein halb angewandter Zustand.
- Keine Spielwerte geändert. Entscheidungen E1–E5 (Erlen versetzt, Bruchkanten gedreht, 70 Inschrift-Labels, Kapiteltempo, verwertender Weg bleibt reich) stehen im Bericht.

## G4 – QA-Protokoll W3 (Agent 19, vorläufig – Benutzerprüfung offen)

- Befunde, Playthrough-Tabellen, Fuzzer, Art-/Ton-Prüfung, Performance: `docs/reviews/phase4_wip/qa_playthrough.md` (Vorher/Nachher-Ausschnitte `docs/reviews/phase4_wip/qa_*.jpg`).
- Screenshot-Satz Gate G4 (§11, echte Phase-4-Welt, 1280×720): `docs/reviews/phase4_round1/` (Welt `world_p4_*`, Budget `perf_p4_*` + `render_stats.txt`, UI `ui_*`).
- Stand der Befunde: 8 behoben (QA4-01…08), jeder mit Regressionstest (`tests/integration/test_phase4_qa.gd`).
- Playthrough-Bot (`phase4_bot.gd`): 5 Moral-Strategien × 24–28 Tage ohne Fehler und ohne Warnung; beide Wege erreichen „Sechs Gruben“ (würdevoll Tag 19, verwertend Tag 24); alle 5 Erkenntnisse würdevoll erreichbar; Phase-3-Bot-Erwartungen (§2.14) weiter grün.
- Save-Fuzzer um einen v3-Stand mitten in Phase 4 erweitert (gezielte Mutationen der Phase-4-Teile).
- Werte unverändert bis auf die Art-Fixes (Laterne Ilse, `visibility_range` der Verfallseffekte); Entscheidungen B1/B2 (Münzüberschuss, Verwerten + Herrichten) stehen im Bericht.

## G3 – QA-Protokoll W3 (Agent 19, vorläufig – Benutzerprüfung offen)

- Befunde, Playthrough-Zahlen, Fuzzer: `docs/reviews/phase3_wip/qa_playthrough.md`.
- Screenshot-Satz: `docs/reviews/phase3_round1/`.
- Stand der Befunde: 11 behoben (QA-01…11), jeder mit Regressionstest.
- Playthrough-Bot: 6 Strategien × 14 Tage ohne Fehler und ohne Warnung.
- Werte unverändert; Balancing-Empfehlungen für G3 stehen im Bericht.

## G0 – QA-Protokoll (Agent 19)

| Test | Ergebnis |
|---|---|
| Godot 4.7.2 headless startet Projekt | ✅ PASS |
| Asset-Import (`--import`) ohne Fehler | ✅ PASS |
| Smoke-Tests `tests/run_tests.gd` (10 Checks) | ✅ PASS |
| Hauptszene startet, Autoloads aktiv | ✅ PASS |
| Blender 5.0.1 (bpy, headless) → .glb Export | ✅ PASS |
| .glb Import in Godot 4.7.2 (Achsen Z-up → Y-up korrekt) | ✅ PASS |

## G2 – QA-Protokoll Vertical Slice (Agent 19)

Screenshots: `docs/reviews/phase2_vertical_slice/` (Software-Renderer, 1280×720). Assets: `docs/reviews/phase2_assets/`.

### Abdeckung der Vertical-Slice-Anforderungen
| Anforderung | Umsetzung | Status |
|---|---|---|
| Spieler, Bewegung, Kamera, Interaktion | Totengräber mit Rig + 6 Animationen, feste 2.5D-Kamera (Perspektive 30°/45°), E/Q-Interaktion mit Fokus-Logik | ✅ |
| Friedhof, Gräber, Grabsteine, Friedhofsbereich, kleines Gebäude | Freigegebene Komposition + 6 freie Grabstellen, Hütte, Tisch, Werkbank, Zaun/Tor | ✅ |
| Leiche: Ankunft, aufnehmen, untersuchen, Zustand anzeigen | Kutscher liefert 07:40 auf die Bahre; Untersuchungs-Panel (Todesursache, Frische, Merkmale, Wertsachen-Entscheidung) | ✅ |
| Bestattung: Grab vorbereiten, Leiche hinbringen, bestatten | Grab ausheben → tragen → bestatten → Grabzeichen → Qualität/Bezahlung | ✅ |
| NPC mit Position, Tagesroutine, Dialog, Interaktion | Leichenkutscher Osric Faulhaber: 9-Phasen-Tagesplan, 20-Knoten-Dialog, Leinen-Handel | ✅ |
| Welt: kleiner Friedhof, angrenzender Bereich, Tag/Nacht | Friedhof + „Kutschweg" nach Hollerbrück; Tageszeit mit Dämmerungen und Laternen | ✅ |
| Systeme: Inventar, Ressourcen, einfaches Crafting, Speichern, Laden | 16 Slots + Münzen; Holz/Stein/Leinen; 3 Rezepte; Autosave + Schnellspeicher, Titel „Fortsetzen" | ✅ |
| Debug-System (Zeit, Teleport, Ressourcen, Leiche/NPC spawnen, Quest-Reset …) | F1-Konsole, 15+ Befehle, in Release-Builds deaktiviert | ✅ |

### Tests & Prüfungen
| Prüfung | Ergebnis |
|---|---|
| Automatische Tests (`tests/run_tests.gd`, 26 Dateien) | ✅ **735 / 735 PASS** |
| Integrationstest kompletter Loop inkl. Speichern → Laden (identischer Zustand) | ✅ |
| Save/Load-Review: ~80 Roundtrips an allen kritischen Momenten | ✅ keine Blocker |
| Korrektheits-Review inkl. Zufalls-Fuzzer (API + echte Eingaben, 1 200 Schritte) | ✅ 0 Invarianten-Verletzungen, 0 Engine-Fehler |
| Playthrough-Bot: 7 Strategien × 6 Tage | ✅ alle erreichen das Slice-Ende, keine Softlocks |
| Architektur-/Regel-Review | ✅ nur kleine Befunde (behoben / dokumentiert) |
| Performance: Draw Calls 138–283, Kamera-Dreiecke ≤ 473 k, 2 Schattenlichter, CPU ~0,5 ms/Frame | ✅ im Budget (GPU-FPS: nur auf Benutzer-PC messbar) |
| UI/UX-Review: Kontraste ≥ 4,5:1, Deutsch korrekt, Zielzeile bei jedem Schritt korrekt | ✅ |
| Review-Befunde | 5 schwere + 28 kleine gefunden → 31 behoben mit Regressionstests, 2 begründet offen (s. u.) |
| Refactoring: 10 übergroße Skripte aufgeteilt, verhaltensneutral (735 → 735, Builder-Ausgabe identisch) | ✅ |

### Bekannte Punkte / Restposten
- **PERF-02** Gras-LOD nicht aktiv: die LOD-Stufe dünnt das freigegebene Gras sichtbar aus; Budget wird auch so eingehalten.
- **GP-03** Münzen häufen sich ab Tag 2 an (einzige Ausgabe: Leinen) → Designentscheidung Wirtschaft (Phase 10).
- Figuren-Rig ohne Ellbogen/Knie (starre Teile, bewusst einfach); keine Musik/Sounds (Agent 17 inaktiv).
- Platzhalter-Schrift (Godot-Standard); Titelbildschirm schlicht.
- `corpse_manager.gd` (464) und `player.gd` (380) liegen noch über der 300-Zeilen-Richtlinie (Rest = öffentliche API + Zustand; weitere Aufteilung erst mit Zustands-Komponenten).
- Hinweis zur Lieferung wird bei belegter Bahre doppelt angezeigt (HUD-Hinweis + Meldung, gleicher Text).

## G1 – QA-Protokoll Runde 1 (Agent 19)

Screenshots: `docs/reviews/phase1_round1/` (Software-Renderer, 1280×720).

| Test | Ergebnis |
|---|---|
| Alle 18 Assets bauen reproduzierbar aus `tools/blender/build_all.py` | ✅ PASS |
| Import ohne Fehler, alle Oberflächen nutzen geteilte Materialien | ✅ PASS |
| Automatische Tests `tests/run_tests.gd` (40 Checks) | ✅ PASS |
| Inhalt laut Plan: Spieler, 8 Gräber, 4 Grabstein-Typen, Baum, Gras, Weg, Hütte, Lichtquellen, Schatten, Kamera, Atmosphäre | ✅ vollständig |
| Tag/Nacht umschaltbar (N), Kamera Perspektive/Ortho (C), Zoom | ✅ PASS |
| Draw Calls (Budget < 1 000) | ✅ 139 – 185 |
| Schattenwerfende Punktlichter (Budget ≤ 4) | ✅ 2 |
| Dreiecke pro Frame (Budget < 500 k sichtbar) | ⚠️ Gesamtübersicht 240–420 k, Nahansicht bis 590 k inkl. Schattenpässe – Gras ist der Hauptanteil → LOD/Chunking in Phase 2 |
| Nacht lesbar (nicht schwarz) | ✅ PASS |
| Echte FPS-Messung auf GPU | ⏳ nur beim Benutzer möglich (Cloud rendert per CPU) |

### Interne QA-Iterationen vor der Präsentation
1. Gras fast schwarz (Rückseiten-Normalen) → behoben
2. Arme um falschen Drehpunkt gedreht (Figur 3,2 m hoch) → behoben
3. Baumkrone „Wattebäusche", Wurzeln wie Spinnenbeine → neue Krone, Blatt-Ränder-Shader
4. Steine überstrahlt, Farben zu gelb, Schatten zu schwarz → Palette & Licht neu abgestimmt
5. Grabhügel eiförmig → rechteckige Aufschüttung
6. Laternenlicht im Laternenkörper → harter Vieleck-Schatten → Marker unter das Glas
7. Bodenkante sichtbar → größerer Boden + Hintergrundbäume

## Entscheidungen (Benutzer, 27.09.2026)

| Frage | Entscheidung |
|---|---|
| Stil-Richtung | **A – Gemaltes Diorama** |
| Kamera | Beide verglichen; Freigabe ohne Gegenwunsch → **Perspektive (FOV 30°, 45° Neigung) als Standard**, Orthografisch bleibt per Debug umschaltbar |
| Plattform | **Nur PC** |
| Blender | **Lokal vorhanden, 5.x** → .blend-Quellen werden mitgeliefert |
| Git LFS | später (noch kleine Dateien) |

## Placeholder-Liste

Alle Phase-1-Assets sind Prototypen (`ph_`-Präfix) und **nicht final**, bis der Benutzer sie ausdrücklich akzeptiert.

| Asset | Kategorie | Status |
|---|---|---|
| ph_chr_gravekeeper | Charakter | Prototyp – Rig + 6 Animationen; Änderungsrunde 1: Details verfeinert (Benutzerwunsch) |
| ph_chr_carter | Charakter | Prototyp – Leichenkutscher Osric, Rig + 4 Animationen; Änderungsrunde 1 verfeinert; G8 Runde 3 + `carry_walk`, `load_lift`, `load_lower` (Abladen an der Bahre) |
| ph_bld_gravekeeper_hut | Gebäude | Prototyp – Änderungsrunde 2: auf 5 × 4 m vergrößert, Schindeln/Moos/Kamin/Blumenkasten |
| ph_layout_placeholder (Code-Mesh Zweig/Kerzenstumpf, Rückfall wenn ph_prop_layout_sprig fehlt) | Aufbahrung (Phase 4) | Prototyp |
| ph_ghost_placeholder (Code-Mesh `GhostPlaceholderMesh`, Rückfall wenn ph_chr_ghost fehlt) | Geist (Phase 3) | Prototyp |
| ph_door_note (Code-Mesh-Zettel an der Hüttentür, `graveyard_build_phase4.gd`, `door_note.gd`) | Ilses Zettel (Phase 4, W-Welt) | Prototyp – Benutzerprüfung offen |
| ph_int_room, ph_int_bed, _stove, _desk, _table, _chair, _chest, _shelf, _rug, _herbs, _coat_hook, _candles, _picture, _broom, _bucket, _washbasin, _cat | Innenraum Hütte (Änderungsrunde 2) | Prototyp |
| ph_env_ground, ph_env_tree_old_oak, ph_env_grass_tuft | Umgebung | Prototyp |
| ph_prop_gravestone_cross / _round / _obelisk / _slab_old | Grabsteine | Prototyp |
| ph_prop_grave_mound_fresh / _grassy / _sunken | Gräber | Prototyp |
| ph_prop_lantern_post, ph_prop_candle_cluster, ph_prop_shovel, ph_prop_crate, ph_prop_fence_iron, ph_prop_gate_post | Props | Prototyp |
| ph_prop_corpse (+ _02 Frau, _03 alter Mann, _04 Müller – Änderungsrunde 1), _corpse_shrouded, _handcart, _morgue_table, _workbench, _dropoff_bier, _grave_plot_empty, _grave_pit, _wood_pile, _stone_rubble, _cross_wood, _signpost, _fallen_log, ph_env_bush | Props (Phase 2) | Prototyp |
| ph_item_log, _stone, _linen, _coin, _shroud | Item-Modelle (Icons) | Prototyp |
| ph_env_ground_graveyard | Boden Welt (Phase 3: 56×64 m, mit Kutschweg; Phase 5: 64×64 m bis Am Bruch, Steinboden-Tönung im Steinbruch – W-Welt neu gebaut) | Prototyp |
| ph_deco_bench_wood, _bench_stone, _flowerbed, _grave_vase, _lantern_small, _path_gravel, _path_gravel_02 | Zier (Phase 3, P5) | Prototyp – Vorschau `docs/reviews/phase3_wip/p5_*.jpg`, Benutzerprüfung offen |
| ph_prop_fence_iron_broken, _fence_passage, _rubble_large, _notice_board | Props (Phase 3, P5) | Prototyp – Benutzerprüfung offen |
| ph_env_bramble, _stump, _hedge_thorn, _weeds_1…3, _leaves_1…3, _birch | Umgebung / Hindernisse / Pflegestellen (Phase 3, P5) | Prototyp – Unkraut/Laub W3 auf Lesbarkeit überarbeitet (`docs/reviews/phase3_wip/qa_weeds_before_after.jpg`), Benutzerprüfung offen |
| ph_chr_ghost | Geist (Phase 3, P5; ohne Rig, Material `mat_ghost` von P4) | Prototyp – Benutzerprüfung offen |
| ph_item_rake, _seeds, _iron_fittings | Item-Modelle (Icons, Phase 3) | Prototyp – Benutzerprüfung offen |
| ph_chr_kranich | Charakter (Phase 4, P5) – Nachthändlerin Ilse Kranich, gemeinsames 8-Knochen-Rig, idle/walk/talk/offer, Marker `light_lantern` (linke Hand), `coins` (rechte Hand) | Prototyp – Vorschau `docs/reviews/phase4_wip/p5_*.jpg`, Benutzerprüfung offen |
| ph_prop_corpse_05 (S5, Mantel), _corpse_06 (S3, Reisemantel), _corpse_gown (Totenhemd) | Leichen (Phase 4, P5; Marker `sprig`) | Prototyp – Benutzerprüfung offen |
| ph_prop_layout_sprig, _wash_basin, _smoke_bowl (Marker `smoke`), _wall_ledge | Props Herrichten / Ilse (Phase 4, P5) | Prototyp – Benutzerprüfung offen |
| ph_prop_gate_small, _gate_small_open, _pit_sunken, ph_env_elder_thicket, ph_env_elder_bush | Holunderwinkel (Phase 4, P5) | Prototyp – Benutzerprüfung offen |
| ph_item_scrub_brush, _comb, _burial_gown, _juniper, _shears, _pliers, _hair_braid, _teeth_pouch, _elder_key | Item-Modelle (Icons, Phase 4, P5; `_elder_key` zusätzlich zu §8) | Prototyp – Benutzerprüfung offen |
| ph_vfx_fly_atlas.png, ph_vfx_stench_wisp.png, ph_vfx_smoke_wisp.png (`assets/vfx/`, `tools/textures/paint_vfx.py`) | Partikel-Texturen (Phase 4, P5; Materialien/Partikel P4) | Prototyp – Benutzerprüfung offen |
| ph_bld_mason_bench (Marker `stone_slot_1…3`, `use`), ph_bld_loom, ph_bld_forge (Marker `light_ember`, `smoke`) | Werkhof-Stationen (Phase 5, P5) | Prototyp – Vorschau `docs/reviews/phase5_wip/p5_*.jpg`, Benutzerprüfung offen |
| ph_prop_charcoal_kiln, _charcoal_kiln_burning (Marker `smoke`), _build_site (Kindmesh `stakes`), _build_site_slab | Werkhof-Requisiten / Bruch-Steinplatte (Phase 5, P5) | Prototyp – Benutzerprüfung offen |
| ph_env_alder_coppice, _alder_stump, _alder_sapling, _flax_bed, _flax_bed_empty, _clay_pit, _quarry_face, _quarry_edge, _ore_vein, _ore_vein_empty, _workstone_ledge, _workstone_ledge_empty, _rubble_face, _boulder, _boulder_broken, _herb_patch, _herb_patch_cut | Sammelstellen / Steinbruch (Phase 5, P5) | Prototyp – Benutzerprüfung offen |
| ph_prop_gravestone_stele, _gravestone_arch, _gravestone_master (Marker `inscription`, `ornament`) | Steinformen (Phase 5, P5) | Prototyp – Benutzerprüfung offen |
| ph_prop_orn_ivy, _orn_poppy, _orn_elder, _orn_torch | Relief-Zierden (Phase 5, P5) | Prototyp – Benutzerprüfung offen |
| ph_item_shovel_iron, _shovel_master, _axe_iron, _axe_master, _pickaxe_iron, _pickaxe_master | Werkzeug-Stufen (Icons / Gürtel, Phase 5, P5) | Prototyp – Benutzerprüfung offen |
| ph_item_flax, _yarn, _clay, _iron_ore, _iron_bar, _charcoal, _workstone, _elderberries, _herbs, _ink, _herb_bundle, _gold_leaf, _steel_rod | Item-Modelle (Icons, Phase 5, P5) | Prototyp – Benutzerprüfung offen |
| ph_bld_crypt_site, ph_bld_crypt_l1, _l2, _l3 (Marker `door_outside`, `build`, l1+ `light_lantern_1/_2`; l3 + `light_lantern`, `inscription`) | Gruft außen, Stufen 0–3 (Phase 6, P5; **G8 Runde 2 neu**: versenktes Portal 3 m breit / Giebel 3,0 m mit Pilastern, Gebälk, Giebel, offener Treppenschacht 1,6 × 1,3 m mit Pfeiler-Laternen, Moos/Efeu/Patina, kein Grashügel) · ph_env_crypt_paving (Vorplatz und Plattenweg, `asset_ground_graveyard.py`) | Prototyp – Bilder `docs/reviews/phase8_round2/gruft_*.jpg`, Benutzerprüfung offen |
| ph_bld_chapel_ruin, ph_bld_chapel_l1, _l2, _l3 (Marker `door_outside`, `build`, `light_window_1…4`; l2+ Kindmesh `bell`; l3 + `light_choir`), ph_prop_soul_lantern (Marker `light_soul`) | Kapelle außen, Stufen 0–3, Totenleuchter (Phase 6, P5) | Prototyp – Benutzerprüfung offen |
| ph_bld_shed_site, ph_bld_shed_l1, _l2, _l3 (Marker `door_outside`, `build`) | Lagerschuppen außen, Stufen 0–3 (Phase 6, P5; l2 mit eigenem leichtem Handkarren) | Prototyp – Benutzerprüfung offen |
| ph_prop_grave_pit_foot | Altgrab gehoben, Aushub am Fußende (Phase 6, P5) | Prototyp – Benutzerprüfung offen |
| ph_int_crypt_room, _crypt_stair, _crypt_table, _crypt_niche, _crypt_niche_sealed, _crypt_lantern, _candle_niche, _ossuary_shelf, _bone_box, _bone_rack, _name_board, _sealed_passage, _sealed_passage_grille | Gruft innen (Phase 6, P5) | Prototyp – Benutzerprüfung offen |
| ph_int_chapel_room, _altar (Kindmeshes `flame_1/2`), _catafalque, _pew_rough, _pew, _bell_rope, _candelabrum, _stained_window, _holy_water | Kapelle innen (Phase 6, P5; `_holy_water` zusätzlich zu §8) | Prototyp – Benutzerprüfung offen |
| ph_int_shed_room, _shed_rack, _wood_rack, _stone_bin | Lagerschuppen innen (Phase 6, P5) | Prototyp – Benutzerprüfung offen |
| ph_chr_mourner_a, _b, _c, _d | Trauergäste, sitzend, ohne Rig (Phase 6, P5) | Prototyp – Benutzerprüfung offen |
| ph_item_altar_candle, _bone_box, _bone_box_full | Item-Modelle (Icons, Phase 6, P5) | Prototyp – Benutzerprüfung offen |
| ph_env_ground_graveyard (neu exportiert, 64 × 80 m) · Kirchpforte = ph_prop_gate_small(_open) × 1,345 · Innenraum-Szenen crypt/chapel/shed_interior.tscn (aus den ph_int_*-Teilen, generiert) | Phase-6-Welt (W-Welt): Boden Nord-Erweiterung, Kirchpforte, drei Innenräume, Gebäude in der Welt verbaut | Prototyp – Aufnahmen `docs/reviews/phase6_wip/world_p6_*.jpg`, Benutzerprüfung offen |
| ph_chr_v_innkeeper, _v_smith, _v_grocer, _v_priest, _v_mayor, _v_surgeon, _v_washer, _v_oldwoman | Die acht Dorfbewohner (Phase 7, P5): gemeinsames 8-Knochen-Rig, idle/walk/talk, dazu work (Schmied, Krämerin, Liesel) und sit (Hagedorn) | Prototyp – Vorschau `docs/reviews/phase7_wip/p5_*.jpg`, Benutzerprüfung offen |
| ph_chr_guest_a, _guest_b, ph_chr_student_a, _b, _c | Sitzende Figuren ohne Rig: Gäste der Gaststube, Studenten der Vorlesung (Phase 7, P5) | Prototyp – Benutzerprüfung offen |
| ph_bld_v_church, _v_office, _v_inn, _v_smithy, _v_shop, _v_surgery, _v_remise, _v_cottage_a, _v_cottage_b, _v_house_a, _v_house_b, _v_house_c, _v_inn2 | Hollerbrück außen (Phase 7, P5; Marker `door_outside`, `light_window(_N)`, `light_lantern`/`light_door`, `label_board`, `ribbon`, `counter`, `anvil`, `light_ember`, `smoke`) | Prototyp – Benutzerprüfung offen |
| ph_prop_v_well, _v_bridge, _v_board, _v_shrine, _v_sign, _v_ribbon, _v_bench, _v_wash_stones, ph_prop_milestone, ph_env_linden_old, ph_env_brook, ph_env_garden_fence | Dorf-Requisiten, Wegstein, Linde (Dorf + Lindenacker), Bach, Gartenzaun (Phase 7, P5) | Prototyp – Benutzerprüfung offen |
| ph_prop_corpse_poppy | D1 Wiebke Hagedorn: Mohnsträußchen als Kindmesh `poppy` für Look 1 (Phase 7, P5) | Prototyp – Benutzerprüfung offen |
| ph_int_inn_room, _inn_bar, _inn_table, _inn_stove, _inn_barrels, _inn_stairs | Gaststube (Phase 7, P5) | Prototyp – Benutzerprüfung offen |
| ph_int_surgery_room, _surgery_table, _surgery_cabinet, _surgery_desk, _surgery_bag, _surgery_lectern, _surgery_bench, _surgery_shutters | Wundarztstube + Vorlesung (Phase 7, P5; Gläser trüb und verschlossen, kein Skelett) | Prototyp – Benutzerprüfung offen |
| ph_int_office_room, _office_desk, _office_shelf, _office_poor_box, _office_lectern | Amtsstube (Phase 7, P5) | Prototyp – Benutzerprüfung offen |
| Alle Klänge `assets/audio/{sfx,ui,ambience,music}/ph_<cue>[_n].wav|.ogg` (G7 Runde 2: Einzelklänge WAV → QOA, Schleifen/Musik Vorbis; sfx 46 Cues/102 Dateien, ui 8/11, ambience 30/45 inkl. ph_amb_*, ph_loop_*, Spots, music 4: ph_mus_title, _day, _night, _village) – alle prozedural aus `tools/audio/build_audio.py`, Liste `docs/reviews/phase7_round2/audio_list.md` | Audio (G7 Änderungsrunde 1: Atmosphäre, Geräusche, UI, Musik; Runde 2: Wind neu, Pegel nach Ziel-Lautheit, 17,7 MiB Quellen) | Prototyp – Hörprobe `docs/reviews/phase7_round2/audio_preview_v2.ogg` (Runde 2; alt `audio_preview.ogg`), Benutzerprüfung offen |
| Phase-8-Klänge (W-Ton): `assets/audio/sfx/ph_{rake_leaves,weed_pull,water_pour,barrel_fill,match_strike,candle_glass,broom_sweep,mortsafe_set,cloth_kneel,flowers_lay,mourn_breath,coins_stone,chatter_murmur,whistle_tune,tin_cup,wage_tin,kiepe_bells,kiepe_set,spade_night,run_gravel,climb_wall,knock_door,watchman_call,chapter_who}[_n].wav|.ogg`, `ui/ph_chalk_write_*.wav`, `ambience/ph_amb_inn_fest.ogg`, `music/ph_mus_dance.ogg`, `ph_mus_lights.ogg` (28 Cues, 62 Dateien) – alle prozedural (`tools/audio/sfx_phase8.py`, `build_audio.py`), Liste `docs/reviews/phase8_round1/audio_list.md` | Audio Phase 8 (Besuche, Grabpflege, Lehrling, Wanderer, Nachtgräber, Kathreintanz, Lichtgang, Kapitel) | Prototyp – Hörprobe `docs/reviews/phase8_round1/audio_preview_p8.ogg`, Benutzerprüfung offen |
| ph_int_church_room, _church_pulpit, _church_font, _church_poor_box, _church_memorial (`tools/blender/asset_village_church.py`; Bänke, Altar, Leuchter = ph_int_pew / _altar / _candelabrum der Kapelle) · church_interior.tscn (generiert) | Dorfkirche St. Gallus innen (G7 Änderungsrunde 1, Licht-Agent): Schiff mit Bankreihen, Chor mit Altar und buntem Fenster, Kanzel, Taufstein, Opferstock, Gedenkbrett | Prototyp – Aufnahmen `docs/reviews/phase7_round2/church_*.jpg`, Benutzerprüfung offen |
| Flackern: `src/world/fx/flicker_light.gd` (FlickerLight), `data/config/fx/*.tres`, `assets/shaders/flame_glow.gdshader` (mat_emissive_warm), Funken an Ofen/Esse (CPUParticles, Code) | Feuer, Kerzen, Laternen, Fenster nachts (G7 Änderungsrunde 1) | Prototyp – `docs/reviews/phase7_round2/flicker_*.jpg`, Benutzerprüfung offen |
| ph_int_pult (Marker `use`, `cold`), ph_int_collection_shelf (Marker `slot_1…7`, `use`) | Präparierpult und Sammlungsregal in der Gruft (Phase 7, P5; Gläser unter Tuch, Fächer hinter Vorhängen) | Prototyp – Benutzerprüfung offen |
| ph_item_prep_jar, _prep_jar_small, _spirits, _beeswax, _anatomy_case, _specimen_jar, _specimen_jar_eyes, _specimen_bundle, _display_specimen, _bone_specimen, _fever_tincture, _wound_salve, _corpse_balm, _antidote, _bitter_drops, _dropsy_powder, _honey_cake, _elder_wine | Item-Modelle (Icons, Phase 7, P5; `_specimen_jar_eyes` zusätzlich zu §8: das dunkle Augenglas) | Prototyp – Benutzerprüfung offen |
| ph_env_ground_village (70 × 56 m, `tools/blender/asset_ground_village.py`: Pflaster-/Weg-Masken aus `village_layout.json`, Bachbett, Hausflächen eingeebnet) · ph_env_ground_graveyard (Lindenacker-Bereich neu exportiert, 66 × 80 m Maske) · Lindenacker-Pforte = ph_prop_gate_small(_open) × 1,345 · Innenraum-Szenen inn/surgery/office_interior.tscn, village.tscn (generiert) · Sicht-Strahlen `village_sight.gd` (Code-Balken, nur Aufnahmen p7_vis_*) | Phase-7-Welt (W-Welt): Dorf-Boden, Lindenacker, Wegstein, drei Dorf-Innenräume, Präparierpult-Platz in der Gruft | Prototyp – Aufnahmen `docs/reviews/phase7_round1/p7_*.jpg`, Benutzerprüfung offen |
| ph_chr_apprentice | Lehrling Jakob Wackernagel (Phase 8, P5): 9 Knochen mit `tool`, ≈ 1,45 m, Gesicht `lib_faces` (Sommersprossen), Werkzeug-Kindmeshes `rake`, `watering_can`, `broom`, `lantern` am `tool` (Extras `show_with`/`carry_with`), 18 Clips | Prototyp – Vorschau `docs/reviews/phase8_assets/`, Benutzerprüfung offen |
| ph_chr_mourner_w_a, _w_b, _m_a, _m_b | Angehörige Martha Kehr, Gesa Ott, Hinrich Brandt, Johann Sieber (Phase 8, P5): 8 Knochen, Kindmeshes `bouquet`, `basket`, `hat_head`/`hat_hand`, `lantern_prop`; idle_low, kneel_in/kneel/kneel_out (Frauen), lay_flowers, mourn_stand (Männer), lantern_walk | Prototyp – Benutzerprüfung offen |
| ph_chr_beggar, ph_chr_peddler, ph_chr_robber | Veit Ammer (steifes Bein, `tin_cup`), Hanne Vogelsang (`kiepe` am `spine`, `staff`), Lambert Grell (9 Knochen, `spade` am `tool`, `lantern_blind`, `scarf_up`/`scarf_down`) (Phase 8, P5) | Prototyp – Benutzerprüfung offen |
| ph_chr_fiddler | Spielmann, sitzend, ohne Rig, Kindmesh `bow` (Ursprung = rechte Schulter) (Phase 8, P5) | Prototyp – Benutzerprüfung offen |
| ph_chr_v_* (8), ph_chr_gravekeeper – Neu-Export | Zusatz-Clips Phase 8 (P5): Bewohner idle_low/lantern_walk (+ Kindmesh `lantern_prop`) und je nach Person kneel_*, lay_flowers, mourn_stand, knock, dance, clap; Totengräber kneel_place, water, sit_bench, dance (+ Marker `can_grip` am `arm_r`); Körper-Mesh und alte Clips bitgleich | Prototyp – Benutzerprüfung offen |
| ph_chr_v_innkeeper, _priest, _mayor, _surgeon, _washer, ph_chr_carter – Neu-Export G8 Runde 4 | Arbeits-Clips (`tools/blender/asset_villager_work.py`, Osric in `asset_carter.py`): `polish_mug`, `pray_altar`, `read_breviary`, `desk_files`, `proclaim`, `desk_write`, `mix_vial`, `wash_brook`, `wash_body`, `smoke`; Kindmeshes (Requisiten in der Faust, nur mit ihrem Clip sichtbar) `prop_mug`, `prop_rag`, `prop_stamp`, `prop_notice`, `prop_quill`, `prop_vial`, `prop_washcloth`; Marker `pipe_smoke` (Osric, Kopf); Körper-Mesh und alle alten Clips hash-gleich, je Figur ≤ 9000 Dreiecke mit Requisiten | Prototyp – Benutzerprüfung offen |
| ph_prop_grave_flowers, _grave_flowers_wilted, _wax_wreath, _bouquet_heath, _bouquet_fir, _bouquet_straw, _bouquet_rose, _grave_candle, _mortsafe, _grave_disturbed, _tip_coins | Grabpflege (Phase 8, P5) | Prototyp – Benutzerprüfung offen |
| ph_prop_chalkboard, _apprentice_box, _apprentice_bench, _rain_barrel, ph_prop_peddler_kiepe, ph_prop_tin_cup | Lehrlingsecke, Hannes Kiepe, Veits Becher (Phase 8, P5) | Prototyp – Benutzerprüfung offen |
| ph_tool_rake_small, _watering_can, _broom, _lantern_hand, _spade_robber, _lantern_blind | Werkzeug-Meshes (Werkzeugraum: Griff im Ursprung, Stiel +Y) (Phase 8, P5; **G8 Runde 2**: `_lantern_hand` = echte Handlaterne – Eisenrahmen, Glas `mat_lantern_glass`, Dach mit Kamin, Bügel, Kerze mit Flamme, 146 Dreiecke; dieselbe Laterne als `lantern_prop` aller Laternenträger) | Prototyp – Benutzerprüfung offen |
| ph_tool_scalpel, _washcloth, _comb, _juniper, _shears, _pliers, _linen, _rake · ph_chr_gravekeeper – Neu-Export G8 Runde 3 | Handwerkzeuge des Totengräbers am Leichentisch und Rechen (Werkzeugraum = Raum des `tool`-Knochens: Griff/Stielende im Ursprung, +Y entlang des Stiels, +Z Arbeitsseite; 12–156 Dreiecke, eigene Szenen am Marker `tool_hand`, nicht im Körper-Budget); 22 neue Clips `table_*` (untersuchen, durchsuchen, waschen, Skalpell, kämmen, räuchern, Leinen, Schere, Zange), `hand_draw/_stow/_stow_walk`, `pray`, `write`, `bench_work`, `place_low`, `weed_pull`, `fill_can`, `rake` + `rake_take/_put/_put_walk`; Körper-Mesh und alte Clips bitgleich | Prototyp – Benutzerprüfung offen (`docs/reviews/phase8_round3/`) |
| ph_int_church_archive (Marker `use`), ph_int_memorial_plate, ph_int_inn_fest_decor | Pfarrarchiv, Namenstafel, Kathrein-Schmuck (Phase 8, P5) | Prototyp – Benutzerprüfung offen |
| ph_item_flower_seedlings, _grave_candle, _watering_can, _apprentice_rake, _mortsafe, _wax_wreath, _register_extract, _memorial_plate, _quast_crate, _lorenz_ledger_2 | Item-Modelle (Icons, Phase 8, P5) | Prototyp – Benutzerprüfung offen |
| ph_prop_gate_bell (Kindmesh `bell` schwingt) · Klang `assets/audio/sfx/ph_gate_bell.wav` (Cue `gate_bell`, prozedural `tools/audio/sfx_phase8.py`) | Torglocke am östlichen Torpfeiler (G8 Runde 1, B8-1; Bild `docs/reviews/phase8_round2/torglocke.jpg`) | Prototyp – Benutzerprüfung offen |
| Godot-Standardschrift | UI-Schrift | **Platzhalter** – Schriftwahl offen |

## Bekannte Probleme

- Keine. (Blender/Godot sind in der Cloud-Umgebung nicht vorinstalliert; werden pro Session in den Scratch-Ordner geladen – kein Einfluss auf das Projekt.)
