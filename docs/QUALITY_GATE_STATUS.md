# Quality Gate Status

| Gate | Phase | Status | Datum | Freigabe durch Benutzer |
|---|---|---|---|---|
| G0 | Projektsetup | ✅ **PASSED** | 27.09.2026 | ✅ „Phase 0 freigegeben" (27.09.2026) |
| G1 | Art Direction | 🔵 IN ARBEIT | 27.09.2026 | – |
| G2 | Vertical Slice | ⚪ nicht gestartet | – | – |

**ART STYLE LOCK:** INACTIVE

## G0 – QA-Protokoll (Agent 19)

| Test | Ergebnis |
|---|---|
| Godot 4.7.2 headless startet Projekt | ✅ PASS |
| Asset-Import (`--import`) ohne Fehler | ✅ PASS |
| Smoke-Tests `tests/run_tests.gd` (10 Checks) | ✅ PASS |
| Hauptszene startet, Autoloads aktiv | ✅ PASS |
| Blender 5.0.1 (bpy, headless) → .glb Export | ✅ PASS |
| .glb Import in Godot 4.7.2 (Achsen Z-up → Y-up korrekt) | ✅ PASS |

## Entscheidungen (Benutzer, 27.09.2026)

| Frage | Entscheidung |
|---|---|
| Stil-Richtung | **A – Gemaltes Diorama** |
| Kamera | **Beide im Prototyp vergleichen** (finale Wahl nach Review) |
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
