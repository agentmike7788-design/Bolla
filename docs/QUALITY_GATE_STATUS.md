# Quality Gate Status

| Gate | Phase | Status | Datum | Freigabe durch Benutzer |
|---|---|---|---|---|
| G0 | Projektsetup | ✅ **PASSED** | 27.09.2026 | ✅ „Phase 0 freigegeben" (27.09.2026) |
| G1 | Art Direction | ✅ **PASSED** (Runde 1) | 27.09.2026 | ✅ „Art Direction freigegeben" (27.09.2026) |
| G2 | Vertical Slice | ✅ **PASSED** (nach Änderungsrunde 1: Leichen/Kutscher/Hauptfigur verschönert; Änderungsrunde 2: Hütte 5 × 4 m + begehbarer Innenraum mit Bett, Ofen, Truhe, Grabregister) | 27.09.2026 | ✅ „Vertical Slice freigegeben" (27.09.2026) |
| G3 | Friedhof vollständig ausbauen | ✅ **PASSED** (Runde 1; 1120 Tests; Bilder `docs/reviews/phase3_round1/`) | 27.09.2026 | ✅ „Phase 3 freigegeben" (27.09.2026) |
| G4 | Leichensystem erweitern | ✅ **PASSED** (Runde 1; 1473 Tests; Bilder `docs/reviews/phase4_round1/`; Lampe 2,2/4,5 m und Verfall-Sichtweite 40 m mit freigegeben) | 28.09.2026 | ✅ „Phase 4 freigegeben" (28.09.2026) |

**ART STYLE LOCK:** ✅ **ACTIVE** seit 27.09.2026 (Referenz: `src/world/art_prototype/`, Screenshots `docs/reviews/phase1_round1/`). Keine grundlegende Stiländerung ohne Benutzerfreigabe.

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
| ph_chr_carter | Charakter | Prototyp – Leichenkutscher Osric, Rig + 4 Animationen; Änderungsrunde 1 verfeinert |
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
| ph_env_ground_graveyard | Boden Welt (Phase 3: 56×64 m, mit Kutschweg – W-Welt neu gebaut) | Prototyp |
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
| Godot-Standardschrift | UI-Schrift | **Platzhalter** – Schriftwahl offen |

## Bekannte Probleme

- Keine. (Blender/Godot sind in der Cloud-Umgebung nicht vorinstalliert; werden pro Session in den Scratch-Ordner geladen – kein Einfluss auf das Projekt.)
