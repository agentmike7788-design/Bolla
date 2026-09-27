# Technical Architecture Document

Status: **Phase 2 (Vertical Slice)** – G0 freigegeben, G1 freigegeben (Art Style Lock). Detail-Vertrag: `docs/VERTICAL_SLICE_DESIGN.md`.
Verantwortlich: Agent 08 (Godot Core), Agent 01 (Lead)

## 1. Technologie

| Bereich | Entscheidung | Begründung |
|---|---|---|
| Engine | **Godot 4.7.2 stable** (neueste stabile Version, geprüft 27.09.2026) | Aktuell, stabil, alle 4.x-Features |
| Sprache | GDScript, **statisch typisiert** | Weniger Laufzeitfehler, bessere Performance |
| Renderer | **Forward+** | Beste Qualität für Licht, Schatten, Nebel, Volumetrics – Kern der Atmosphäre |
| Darstellung | **Echte 3D-Szene mit fixer, gewinkelter Kamera** (2.5D-Wirkung) | Blender-Modelle direkt nutzbar, echtes Licht/Schatten, Tag/Nacht ohne Sprite-Varianten |
| 3D-Format | glTF 2.0 binär (`.glb`) | Offizieller Godot-Import-Weg aus Blender |
| Blender | Blender 5.0 (lokal beim Benutzer) / `bpy 5.0.1` headless in der Cloud | Beides erlaubt skriptbasierte, reproduzierbare Assets |
| Zielplattform | PC (Windows/Linux), Tastatur+Maus, Gamepad später | **offene Entscheidung** – siehe Gate-Status |
| Versionskontrolle | Git, Feature-Branches, Commit pro stabilem Meilenstein | – |

## 2. Verzeichnisstruktur

```
project.godot          Engine-Konfiguration (Input-Map, Autoloads, Physik-Layer, Shader-Globals)
CLAUDE.md              Arbeitsregeln für KI-Sessions (Kurzfassung)
docs/                  Single Source of Truth (von Godot ignoriert)
src/                   Gesamter Spielcode, nach FEATURE gruppiert (Szene + Script zusammen)
  core/                Autoloads ohne Spiellogik: EventBus, GameConfig, Database, UIState; import/ (glb-Post-Import)
  boot/                Startszene → Titelbildschirm
  systems/             Spielsysteme: time, game_state, save, inventory, crafting, corpse, graveyard, dialogue, npc
  components/          Wiederverwendbare Komponenten (Interactable, InteractionDetector)
  entities/            Alles mit Weltpräsenz: player, corpse, grave, morgue_table, workbench, dropoff, resource_node, npc, hut_door
  world/               Weltszenen: graveyard/ (Vertical Slice), art_prototype/ (eingefroren), camera/, atmosphere/
  ui/                  UIRoot, HUD, Panels, Dialogbox, Titel, Theme, Tools (Icons, Screenshots)
  debug/               Debug-Konsole (nur Debug-Builds), Asset-Vorschau, Screenshot-Serie
data/                  Balancing & Inhalte als Resources (.tres) und Layout-JSON (nur Build-Zeit)
assets/                Importierte Assets (glb, Shader, Materialien, Icons)
art_source/            Blender-Quelldateien (von Godot ignoriert)
tests/                 framework/, unit/, integration/, fixtures/ – Runner tests/run_tests.gd
tools/                 Blender-Generatoren, godot_run.sh (von Godot ignoriert)
```

Regel: Ein Feature = ein Ordner, z. B. `src/entities/corpse/corpse.tscn` + `corpse.gd`.

## 3. Architekturprinzipien

1. **Lose Kopplung über `EventBus`** – Systeme kennen sich nicht direkt. Signale nur dort, wo ≥ 2 Systeme sie brauchen.
2. **Daten statt Hardcoding** – Spielwerte (Preise, Zeiten, Qualitätspunkte, Rezepte) liegen als `Resource`-Klassen in `data/`.
3. **Komposition vor Vererbung** – wiederverwendbare Komponenten-Nodes (z. B. `Interactable`, `Inventory`, `Saveable`).
4. **Kleine Scripts** – Richtwert < 300 Zeilen; sonst aufteilen.
5. **Autoloads sparsam** – nur für echte globale Dienste (Events, Config, Save, Zeit). Kein globaler Spielzustand in beliebigen Variablen.
6. **Saveable-Vertrag** (ab Phase 2): Jedes speicherbare Objekt ist in Gruppe `saveable` und implementiert `save_state() -> Dictionary` / `load_state(data: Dictionary)`. SaveManager sammelt diese → JSON in `user://saves/` mit Versionsnummer für Migrationen.
7. **Debug abschaltbar** – Debug-Code prüft `GameConfig.debug_enabled`; in Release-Exports automatisch aus (`OS.is_debug_build()`).

## 4. Aktueller Stand (Phase 2 – Vertical Slice)

| Bereich | Dateien | Kurz |
|---|---|---|
| Autoloads | `EventBus`, `GameConfig`, `Database`, `UIState`, `TimeManager`, `GameState`, `SaveManager`, `Debug` | Reihenfolge und Verträge: VERTICAL_SLICE_DESIGN.md §3.1 |
| Zeit & Atmosphäre | `src/systems/time/`, `src/world/atmosphere/`, `data/atmosphere/*.tres` | Spieluhr mit Pause-Gründen; Stimmung folgt der Uhrzeit (Halte-Stützstellen) |
| Speichern | `src/systems/save/save_manager.gd` | Slots 0 (Autosave) / 1 (Schnell); typtreu via `JSON.from_native`; feste Lade-Reihenfolge |
| Kern-Loop | `src/systems/{corpse,graveyard,inventory,crafting}/` | Leichen (deterministisch), Gräber, Qualität, Bezahlung, Inventar, Rezepte |
| NPC & Dialog | `src/systems/{npc,dialogue}/`, `data/npc/`, `data/dialogue/` | Tagesablauf deterministisch aus der Uhrzeit; Dialog-Minisprache |
| Spieler | `src/entities/player/`, `src/components/` | Bewegung, Tragen, zeitgeraffte Aktionen, Interaktions-Fokus |
| Welt | `src/world/graveyard/` (+ Builder aus `data/world/graveyard_layout.json`) | Friedhof + Kutschweg, Entitäten, Kollisionen, Wegpunkte |
| UI | `src/ui/` | HUD, 7 Panels, Dialogbox, Titel, Theme, Icons |
| Stil | `assets/shaders/`, `assets/materials/` | Maler-Shader (gesperrt), Gras, Laub |

Input-Map: `move_*` (WASD + Pfeile), `interact` (E), `drop` (Q), `inventory` (I), `pause` (Esc), `quick_save` (F5), `quick_load` (F9), `dialogue_choice_1..4` (1–4), `debug_toggle` (F1), `camera_zoom_in/out` (Mausrad, +/−); nur Art-Prototyp: `proto_toggle_camera` (C), `proto_toggle_time` (N).
Physik-Layer: 1 world, 2 player, 3 npc, 4 interactable, 5 corpse. Shader-Globals: `occlusion_target`, `occlusion_radius` (Laub-Freistellung um den Spieler).

### Asset-Pipeline (Befehle)

```
python tools/blender/build_all.py                       # alle Assets (bpy / Blender 5.x)
godot --headless --path . --import                      # Import (Materialzuordnung automatisch)
tools/godot_run.sh -s res://src/world/art_prototype/art_prototype_builder.gd   # Szene neu erzeugen
tools/godot_run.sh res://src/world/art_prototype/art_prototype.tscn -- --capture=/abs/pfad [--shots=01,05]   # Screenshots Art-Prototyp (Szene direkt starten – Boot führt zum Titel)
python tools/blender/asset_ground_graveyard.py                                   # Friedhofs-Boden aus data/world/graveyard_layout.json
tools/godot_run.sh -s res://src/world/graveyard/graveyard_builder.gd             # graveyard.tscn + grass.scn + ground_shape.res
tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots.gd -- --out=/abs/dir [--shots=01,03]
tools/godot_run.sh -s res://src/ui/tools/icon_renderer.gd                        # Item-Icons
```
Hinweis: Der Szenen-Builder braucht einen echten Renderer (nicht `--headless`), weil MultiMesh-Daten sonst verworfen werden.

## 5. Tests

```
godot --headless --path . --import                       # einmalig / nach neuen Assets
godot --headless --path . -s res://tests/run_tests.gd    # Smoke-/Unit-Tests, Exit-Code 0 = PASS
godot --headless --path . --quit-after 5                 # Start-Test der Hauptszene
```

Ab Phase 2: Framework `tests/framework/test_case.gd` + Runner `tests/run_tests.gd` (Autoload-Reset pro Test, Fehler-Logger, Watchdog, Exit 0/1/2); Tests pro Modul in `tests/unit/test_<modul>.gd`, Integration in `tests/integration/`; Details in VERTICAL_SLICE_DESIGN.md §9.

## 6. Performance-Budget

| Größe | Budget Vertical Slice |
|---|---|
| FPS | 60 @ 1080p auf Mittelklasse-GPU |
| Draw Calls | < 1 000 (MultiMesh für Gras/Kleinzeug) |
| Schattenwerfende Lichter | 1 Directional + max. 4 Omni/Spot gleichzeitig |
| Aktive NPCs | ≤ 10 |
| Dreiecke sichtbar | < 500 k (Hinweis: `RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME` zählt pro MultiMesh nur eine Instanz – Gras wird separat gerechnet, siehe `graveyard_shots.gd`) |

### Messung Vertical Slice (nach Fix-Welle, 1280×720, Software-Renderer, `graveyard_shots.gd`)

| Wert | Tag | Nacht | Budget |
|---|---|---|---|
| Draw Calls | 138 – 175 | 200 – 283 | < 1 000 ✅ |
| Kamera-Dreiecke inkl. Gras | 172 k – 473 k | 244 k – 316 k | < 500 k ✅ |
| Frame gesamt inkl. Schattenpässe | 276 k – 580 k | 409 k – 436 k | (kein eigenes Budget; Übersicht bei Zoom 30 = 580 k) |
| Schattenwerfende Punktlichter | 0 | 2 | ≤ 4 ✅ |
| CPU pro Frame (Skripte + Engine, headless) | ~0,4 – 0,55 ms | | 16,6 ms ✅ |
| Neues Spiel / Laden / Speichern | 423 ms / 39 ms / < 1 ms | | |
Echte GPU-FPS: nur auf dem Benutzer-PC messbar (Volumennebel, SSAO, MSAA 2×, weiche Schatten).
