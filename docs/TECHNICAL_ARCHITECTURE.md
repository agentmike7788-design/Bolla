# Technical Architecture Document

Status: **ENTWURF – wartet auf Freigabe (Gate 0)**
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
project.godot          Engine-Konfiguration (Input-Map, Autoloads, Physik-Layer)
CLAUDE.md              Arbeitsregeln für KI-Sessions (Kurzfassung)
docs/                  Single Source of Truth (von Godot ignoriert)
src/                   Gesamter Spielcode, nach FEATURE gruppiert (Szene + Script zusammen)
  core/                Autoloads: EventBus, GameConfig (später SaveManager, TimeManager)
  boot/                Startszene
  systems/             Spielsysteme ohne eigene Weltpräsenz (save, time, inventory, crafting …)
  entities/            Alles, was in der Welt existiert (player, npc, corpse, grave …)
  world/               Level-/Gebietsszenen (graveyard, village …)
  ui/                  HUD, Menüs
  debug/               Debug-Konsole/-Overlay (nur Debug-Builds)
data/                  Balancing & Inhalte als Godot-Resources (.tres) – keine Zahlen im Code
assets/                Importierte Assets (glb, png, ogg, Fonts)
art_source/            Blender-Quelldateien, Referenzen, Concepts (von Godot ignoriert)
tests/                 Headless-Testrunner
tools/                 Blender-Export-/Generator-Scripts, Build-Scripts (von Godot ignoriert)
```

Regel: Ein Feature = ein Ordner, z. B. `src/entities/corpse/corpse.tscn`, `corpse.gd`, `corpse_data.gd`.

## 3. Architekturprinzipien

1. **Lose Kopplung über `EventBus`** – Systeme kennen sich nicht direkt. Signale nur dort, wo ≥ 2 Systeme sie brauchen.
2. **Daten statt Hardcoding** – Spielwerte (Preise, Zeiten, Qualitätspunkte, Rezepte) liegen als `Resource`-Klassen in `data/`.
3. **Komposition vor Vererbung** – wiederverwendbare Komponenten-Nodes (z. B. `Interactable`, `Inventory`, `Saveable`).
4. **Kleine Scripts** – Richtwert < 300 Zeilen; sonst aufteilen.
5. **Autoloads sparsam** – nur für echte globale Dienste (Events, Config, Save, Zeit). Kein globaler Spielzustand in beliebigen Variablen.
6. **Saveable-Vertrag** (ab Phase 2): Jedes speicherbare Objekt ist in Gruppe `saveable` und implementiert `save_state() -> Dictionary` / `load_state(data: Dictionary)`. SaveManager sammelt diese → JSON in `user://saves/` mit Versionsnummer für Migrationen.
7. **Debug abschaltbar** – Debug-Code prüft `GameConfig.debug_enabled`; in Release-Exports automatisch aus (`OS.is_debug_build()`).

## 4. Aktueller Stand (Phase 0)

| Datei | Zweck |
|---|---|
| `src/core/event_bus.gd` | Globaler Signal-Hub (Autoload `EventBus`) |
| `src/core/game_config.gd` | Version, Debug-Flag (Autoload `GameConfig`) |
| `src/boot/main.tscn/.gd` | Startszene, beweist sauberen Start |
| `tests/run_tests.gd` | Smoke-Tests (Main-Szene, Input-Map, Autoloads) |

Input-Map: `move_up/down/left/right` (WASD + Pfeile), `interact` (E), `debug_toggle` (F1).
Physik-Layer: 1 world, 2 player, 3 npc, 4 interactable, 5 corpse.

## 5. Tests

```
godot --headless --path . --import                       # einmalig / nach neuen Assets
godot --headless --path . -s res://tests/run_tests.gd    # Smoke-/Unit-Tests, Exit-Code 0 = PASS
godot --headless --path . --quit-after 5                 # Start-Test der Hauptszene
```

Ab Phase 2: pro System eigene Testdatei `tests/test_<system>.gd`, Save/Load-Roundtrip-Tests, Regressionsliste in `QUALITY_GATE_STATUS.md`.

## 6. Performance-Budget (Startwerte, werden in Phase 1 gemessen)

| Größe | Budget Vertical Slice |
|---|---|
| FPS | 60 @ 1080p auf Mittelklasse-GPU |
| Draw Calls | < 1 000 (MultiMesh für Gras/Kleinzeug) |
| Schattenwerfende Lichter | 1 Directional + max. 4 Omni/Spot gleichzeitig |
| Aktive NPCs | ≤ 10 |
| Dreiecke sichtbar | < 500 k |
