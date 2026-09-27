# Quality Gate Status

| Gate | Phase | Status | Datum | Freigabe durch Benutzer |
|---|---|---|---|---|
| G0 | Projektsetup | ✅ **PASSED** | 27.09.2026 | ✅ „Phase 0 freigegeben" (27.09.2026) |
| G1 | Art Direction | ✅ **PASSED** (Runde 1) | 27.09.2026 | ✅ „Art Direction freigegeben" (27.09.2026) |
| G2 | Vertical Slice | 🔵 IN ARBEIT | 27.09.2026 | – |

**ART STYLE LOCK:** ✅ **ACTIVE** seit 27.09.2026 (Referenz: `src/world/art_prototype/`, Screenshots `docs/reviews/phase1_round1/`). Keine grundlegende Stiländerung ohne Benutzerfreigabe.

## G0 – QA-Protokoll (Agent 19)

| Test | Ergebnis |
|---|---|
| Godot 4.7.2 headless startet Projekt | ✅ PASS |
| Asset-Import (`--import`) ohne Fehler | ✅ PASS |
| Smoke-Tests `tests/run_tests.gd` (10 Checks) | ✅ PASS |
| Hauptszene startet, Autoloads aktiv | ✅ PASS |
| Blender 5.0.1 (bpy, headless) → .glb Export | ✅ PASS |
| .glb Import in Godot 4.7.2 (Achsen Z-up → Y-up korrekt) | ✅ PASS |

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
| ph_chr_gravekeeper | Charakter | Prototyp (statische Pose, kein Rig) |
| ph_bld_gravekeeper_hut | Gebäude | Prototyp |
| ph_env_ground, ph_env_tree_old_oak, ph_env_grass_tuft | Umgebung | Prototyp |
| ph_prop_gravestone_cross / _round / _obelisk / _slab_old | Grabsteine | Prototyp |
| ph_prop_grave_mound_fresh / _grassy / _sunken | Gräber | Prototyp |
| ph_prop_lantern_post, ph_prop_candle_cluster, ph_prop_shovel, ph_prop_crate, ph_prop_fence_iron, ph_prop_gate_post | Props | Prototyp |

## Bekannte Probleme

- Keine. (Blender/Godot sind in der Cloud-Umgebung nicht vorinstalliert; werden pro Session in den Scratch-Ordner geladen – kein Einfluss auf das Projekt.)
