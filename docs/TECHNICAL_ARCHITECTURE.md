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
  entities/            Alles mit Weltpräsenz: player, corpse, grave, morgue_table, workbench, dropoff, resource_node, npc, hut_door, bed, stove, chest, desk, interior_door
  world/               Weltszenen: graveyard/ (Vertical Slice), hut_interior/ (Innenraum, §11), art_prototype/ (eingefroren), camera/, atmosphere/
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
| Hütte innen (Runde 2) | `src/world/hut_interior/`, `data/world/hut_interior_layout.json`, `data/config/interior_config.tres` | Eigene Innenraum-Szene, Portal, Kamera-Profil, Innenlicht (siehe unten) |
| UI | `src/ui/` | HUD, 7 Panels, Dialogbox, Titel, Theme, Icons |
| Stil | `assets/shaders/`, `assets/materials/` | Maler-Shader (gesperrt), Gras, Laub |

### Hütten-Innenraum & Portal (Änderungsrunde 2, VERTICAL_SLICE_DESIGN §11)
- **Szene** `src/world/hut_interior/hut_interior.tscn` (Wurzel `HutInterior`, Gruppe `hut_interior`) wird von `hut_interior_builder.gd` (headless möglich) aus `data/world/hut_interior_layout.json` erzeugt; `graveyard_builder.gd` baut sie mit und instanziert sie **fern der Außenwelt** bei `hut_interior.origin` = (0, 0, −200). Inhalt: `Room` (+ Fenster-/Laternenlichter an den Markern), `Furniture/`, `Entities/` (`bed`, `chest`, `desk`, `stove` mit Modell als Kind `Model` und Marker `UsePos`, `interior_door`), `Colliders/` (Boden, vier Wände – die Tür wird nur per [E] benutzt –, Boden- und Wandstücke), `Spawn`, eine eigene `Sun` (nur drinnen sichtbar) und `Lighting` (`InteriorLighting`).
- **Portal**: `HutDoor` (Gruppe `hut_door`, am Marker `door_outside`) „[E] Hütte betreten" – mit Leiche „Leiche draußen ablegen" (gesperrt); `InteriorDoor` „[E] Hinausgehen". `HutPortal.travel()` sendet `EventBus.screen_fade_requested(fade_seconds)` (UI: `ScreenFade`), teleportiert zur Mitte der Blende und ruft `Player.set_in_interior()` → `EventBus.interior_changed(inside)`. Die Welt läuft weiter (keine Pause, kein Szenenwechsel).
- **Ansicht**: `HutInterior.apply_view()` (auf `interior_changed`) setzt das `CameraRig`-Profil (`CameraProfile`: Distanz 9 m, Zoom 7–11, Fokus-Grenzen des Raums, eigenes `Environment` ohne Nebel) und tauscht Außen- und Innensonne. `clear_profile()` stellt Außen-Zoom/-Grenzen wieder her. `Player.save_state()` enthält `in_interior`; `load_state()` meldet es erneut → nach dem Laden stimmt die Kamera.
- **Licht**: `InteriorLighting` blendet nach `InteriorConfig.daylight(minute)` Fenster (Nacht #8fa2d0/0,35 → Tag #ffe2b0/1,3, ohne Schatten), Hängelaterne (1,1 mit Schatten → 0,3), Kerzen (0,5 → aus), Umgebungslicht und Innensonne (Tag 0,9). Der Ofen (`Light_fire`) ist ein `warm_lights`-Licht mit Meta `min_scale` (Tag 1,6 / Nacht 3,0; `flicker_light.gd`, `warm_shadow_governor.gd`).
- **Truhe/Register**: `Chest` (saveable `hut_chest`, eigenes `Inventory` 16 Slots) → Panel `&"chest"`; `Desk.register_entries()` baut die Register-Zeilen aus Graveyard + CorpseRecords (`CorpseRecord.buried_day`, von `mark_buried` gesetzt) → Panel `&"grave_register"`.
- **Screenshots**: `graveyard_shots.gd -- --out=/abs/dir --round2` (world_01…06, siehe `docs/reviews/phase2_round2/`).

Input-Map: `move_*` (WASD + Pfeile), `interact` (E), `drop` (Q), `inventory` (I), `pause` (Esc), `quick_save` (F5), `quick_load` (F9), `dialogue_choice_1..4` (1–4), `debug_toggle` (F1), `camera_zoom_in/out` (Mausrad, +/−); nur Art-Prototyp: `proto_toggle_camera` (C), `proto_toggle_time` (N).
Physik-Layer: 1 world, 2 player, 3 npc, 4 interactable, 5 corpse. Shader-Globals: `occlusion_target`, `occlusion_radius` (Laub-Freistellung um den Spieler).

### Asset-Pipeline (Befehle)

```
python tools/blender/build_all.py                       # alle Assets (bpy / Blender 5.x)
godot --headless --path . --import                      # Import (Materialzuordnung automatisch)
tools/godot_run.sh -s res://src/world/art_prototype/art_prototype_builder.gd   # Szene neu erzeugen
tools/godot_run.sh res://src/world/art_prototype/art_prototype.tscn -- --capture=/abs/pfad [--shots=01,05]   # Screenshots Art-Prototyp (Szene direkt starten – Boot führt zum Titel)
python tools/blender/asset_ground_graveyard.py                                   # Friedhofs-Boden aus data/world/graveyard_layout.json
tools/godot_run.sh -s res://src/world/graveyard/graveyard_builder.gd             # graveyard.tscn + grass.scn + ground_shape.res (+ hut_interior.tscn)
godot --headless --path . -s res://src/world/hut_interior/hut_interior_builder.gd # nur hut_interior.tscn
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

### Messung Phase 3 – Welt (W-Welt, 1280×720, Software-Renderer lavapipe, `graveyard_shots_phase3.gd`)

Welt 56 × 64 m, 12 Grabstellen (10 bestattet + 2 Phase-2-Staging), 59 Deko-Stücke (19 Zier + 40 Kies), 6 Geister nachts; Rohdaten `docs/reviews/phase3_wip/world_render_stats.txt`, `world_cpu_stats.txt`.

| Wert | Tag | Nacht (Geister) | Budget §9 |
|---|---|---|---|
| Kamera-Dreiecke inkl. Gras, Spiel-Zoom max. 24 m (`perf_01…03`) | 448 k | 392 k – 459 k | < 500 k ✅ |
| Kamera-Dreiecke, Übersicht 30–40 m (nur Screenshot, außerhalb des Spiel-Zooms) | 519 k – 536 k | 566 k | (Info) |
| Gras | 16 635 Büschel in 238 Chunks (+33 % Fläche); sichtbar 197 k – 390 k Dreiecke | | `outer_density` 0,35, `visibility_range` 50 |
| Draw Calls | 105 – 268 | 266 – 341 | < 1 000 ✅ |
| Omni-Lichter sichtbar | 8 – 14 | 20 (Laternen + 6 Geister) | ≤ 24 ✅ |
| Schattenwerfende Omni-Lichter | 0 | 2 | ≤ 4 ✅ (Laternen/Geister nie) |
| CPU pro Frame (Skripte + Engine, headless, Uhr läuft, Median / Mittel) | 0,91 – 1,16 / 1,31 – 1,46 ms | 0,93 – 1,87 / 1,14 – 1,90 ms | < 1,5 ms Median ✅ (Mittel verrauscht: geteilter 4-Kern-Container, ±1 ms) |
| Schlafen 18:00 → 06:00 (`advance 720`, einmalig) | 11 – 15 ms | | – |

Hinweis: Die Pflegestellen-Modelle (Unkraut mit `mat_grass`, animiert) liegen wie Baumkronen auf Render-Layer 2 (keine Laternen-Würfelschatten), die Verwilderung der gesperrten Abschnitte wirft keine Schatten.

### Messung Phase 4 – Welt (W-Welt, 1280×720, Software-Renderer lavapipe, `graveyard_shots_phase4.gd`)

Welt mit Holunderwinkel (18 Grabstellen, 4 im Winkel belegt + 1 offene Grube), Ilse Kranich an der Westmauer (23:30), 6 Geister, 3 verwesende Leichen am Tisch (verwesend 0,16 auf dem Tisch, verwesend 0,2 und verfallen 0,05 am Boden), Wacholderrauch am Tag; Rohdaten `docs/reviews/phase4_wip/world_render_stats.txt`.

| Wert | Tag | Nacht (Ilse, Geister, Verfall) | Budget §9 |
|---|---|---|---|
| Kamera-Dreiecke inkl. Gras, Spiel-Zoom max. 24 m (`perf_p4_01…03`) | 432 k | 365 k – 440 k | < 500 k ✅ |
| Kamera-Dreiecke, Übersicht 40 m (nur Screenshot) | 529 k – 530 k | – | (Info) |
| Draw Calls | 80 – 267 | 101 – 284 | < 1 000 ✅ |
| Partikel (Fliegen + Schwaden + Rauch, `CorpseDecayVisual.total_live_particles`) | 3 (Rauch) | 37 (10 + 5 verfallen, 2 × 8 + 3 verwesend) | ≤ 60 ✅ (jenseits 22 m Kamera-Abstand ruhen die Emitter: bei Zoom 24 m 0) |
| Omni-Lichter sichtbar | 8 | 14 – 15 (Laternen, Ilses Laterne, 6 Geister) | ≤ 24 ✅ |
| Schattenwerfende Omni-Lichter | 0 | 2 (Hütten- und Pfostenlaterne) | ≤ 4 ✅ (Ilses Laterne `#E8A55A`, 0,4, 3 m, nie Schatten) |
| Ilse Kranich | 7 348 Dreiecke, 1 Skelett, 8 Knochen; außerhalb 22:40–03:20 unsichtbar | | ≤ 9 000 ✅ |
| CPU pro Frame (headless, Uhr läuft, Zoom 12 m, Median / Mittel) | 2,22 / 2,12 ms | 2,53 / 2,51 ms (37 Partikel, 6 Geister, Ilse) | < 1,5 ms ⚠️ siehe Hinweis |

Hinweis CPU: Der Container ist heute deutlich langsamer als bei der Phase-3-Messung. Die unveränderte Phase-3-Sonde (`graveyard_shots_phase3.gd --cpu`) misst zur selben Stunde 2,12 / 2,63 ms (Tag) und 2,79 / 2,91 ms (Nacht) statt der dokumentierten 0,91 – 1,16 ms Median. Phase 4 liegt damit gleichauf mit Phase 3 (die neuen Systeme sind ereignisgetrieben, Npc Ilse ohne Karren- und Fracht-Logik). Das absolute Budget muss W3 auf ruhiger Hardware nachmessen.

### Messung Phase 5 – Welt (W-Welt, 1280×720, Software-Renderer lavapipe, `graveyard_shots_phase5.gd`)

Welt mit Werkhof (3 Stationen gebaut, Meiler brennt, 2 Steine in der Ablage), 18 gestalteten Steinen mit Inschrift (18 Gräber belegt), Am Bruch offen, Steinbruch frei, 6 Geister nachts, 3 verwesende Leichen am Tisch (`perf_p5_02`); Rohdaten `docs/reviews/phase5_wip/world_render_stats.txt`, `world_cpu_stats.txt`.

| Wert | Messung | Budget §9 |
|---|---|---|
| Kamera-Dreiecke inkl. Gras, Spiel-Zoom max. 24 m (`perf_p5_01…04`) | 318 k (Bruch Tag) · 434 k (Werkhof Nacht + Verfall) · 455 k (18 Inschriften) · 412 k (Werkhof Tag) | < 500 k ✅ |
| Kamera-Dreiecke, Übersicht 46 m (nur Screenshot) | 469 k | (Info) |
| Draw Calls | 229 – 312 (Zoom 24 m), Übersicht 307 | < 1 000 ✅ (erwartet ≤ 560) |
| Partikel | 54 (Werkhof nachts: 48 Verfall + 3 Kamin + 3 Meiler) | ≤ 60 ✅ |
| Omni-Lichter sichtbar | 9 Tag · 15 Nacht (+ Esse-Glut) | ≤ 25 ✅ |
| Schattenwerfende Omni-Lichter | 0 Tag · 2 Nacht (Hütten- und Pfostenlaterne; Esse-Glut `#E07A3A`, 0,5, 3,5 m, nie Schatten) | ≤ 4 ✅ |
| Label3D (Inschriften) | 56 bei 18 Steinen + 2 in der Ablage (StoneVisual: ein Label je Zeile, 2–4 Zeilen) | ≤ 18 Steine ✅ (§9 zählt Steine; je Zeile ein Label ist P4-Bauweise) |
| Spielstand | 108 kB, Laden 235 ms (inkl. Weltwechsel) | < 300 kB, < 1 s ✅ |
| CPU pro Frame (headless, Uhr läuft, Zoom 12 m, Median) | Tag 3,25 ms (Phase-5-Teile aus: 3,52) · Nacht 4,39 ms (aus: 3,66) | Phase-5-Anteil ≤ +0,2 ms ⚠️ nicht auflösbar |

Hinweis CPU: Während der Messung liefen im Container weitere Godot-Prozesse (andere Sitzungen); dieselbe Phase-4-Sonde (`graveyard_shots_phase4.gd --cpu`) misst dabei 5,17 / 4,06 ms Median statt der oben dokumentierten 2,22 / 2,53 ms. Die Differenz „Phase-5-Teile an/aus" schwankt zwischen −0,3 und +0,7 ms von Lauf zu Lauf und ist damit Rauschen. Die Phase-5-Knoten haben kein `_process` (Bauplätze/Sammelstellen/Stationen nur über Signale, Meiler und Ablage ereignisgetrieben, Label3D statisch); der Rauch sind 6 CPU-Partikel. W3 misst auf ruhiger Hardware nach.
