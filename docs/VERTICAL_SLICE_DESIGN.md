# Vertical Slice Design (Phase 2)

Status: **ENTWURF v1 – Arbeitsgrundlage für Phase 2** · Verantwortlich: Agent 01 (Lead)
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Vertical-Slice-Gate.
ART STYLE LOCK ist aktiv: alle neuen Assets im freigegebenen Stil (`tools/blender/lib_painted.py`).

Dieses Dokument ist der **Vertrag** zwischen allen Agents: Dateipfade, Klassen, Signale, Datenformate.
Abweichungen nur nach Rücksprache mit dem Lead.

---

## 1. Spielablauf im Slice (ein Spieltag)

1. **06:30 – Tag 1 beginnt.** Der Totengräber steht vor seiner Hütte.
2. **07:00** Der **Leichenkutscher „Osric Faulhaber"** (NPC) schiebt seinen Karren vom Kutschweg (südlich des Tors) zur **Ablage** am Friedhofstor.
3. **~07:40** Ankunft: Er legt **eine Leiche** auf die Ablage (falls frei) und wartet bis 10:00. Man kann mit ihm reden und **Leinen kaufen**.
4. Spieler **hebt die Leiche auf** (E), trägt sie (langsamer) zum **Leichentisch** an der Hütte und **legt sie ab** (E am Tisch).
5. Am Tisch: **Untersuchungs-Panel**
   - **Untersuchen** (20 Spielminuten): deckt Todesursache-Details und Merkmale auf.
   - **Entscheidung** (wenn Merkmal „Wertsachen"): *Wertsachen nehmen* (+Münzen, −Grabqualität, −Ruf) **oder** *liegen lassen* (+Grabqualität).
   - **Leichentuch anlegen** (braucht 1 „Leichentuch"): +Grabqualität.
6. Spieler wählt eine **freie Grabstelle** → **Grab ausheben** (60 Spielminuten, Fortschrittsbalken).
7. Leiche vom Tisch aufnehmen → zum offenen Grab → **Bestatten** (30 Spielminuten) → frischer Grabhügel.
8. **Grabzeichen setzen** (Holzkreuz oder Grabstein aus dem Inventar) → Grab abgeschlossen.
9. **Bezahlung** durch die Gemeinde (Münzen, abhängig von Grabqualität) + **Friedhofsqualität** steigt.
10. Ressourcen: **Holz** am Holzstapel, **Stein** am Steinhaufen sammeln (je 1 pro Interaktion, 10 Min, tägliche Menge begrenzt), **Leinen** beim Kutscher kaufen.
11. **Werkbank**: Leichentuch, Holzkreuz, einfacher Grabstein herstellen.
12. **Abends** steht der Kutscher am Weg vor dem Tor (18–21 Uhr, Dialog), dann geht er heim.
13. **Nacht** (ab 21:00): Laternen an, Mondlicht. **Schlafen** an der Hüttentür (ab 20:00) → nächster Morgen 06:00, **Autosave**.
14. Jederzeit: **Schnellspeichern F5 / Schnellladen F9**, Pause-Menü (Esc) mit Speichern/Laden.

Jeder Tag bringt eine neue Leiche (andere Todesursache, andere Merkmale) → Loop wiederholbar.

## 2. Spielwerte (Vorschläge, alle in `data/`)

| Wert | Vorschlag | Datei |
|---|---|---|
| Echtzeit pro Spielminute | 0,5 s (1 Tag = 12 min) | `data/config/time_config.tres` |
| Startzeit | Tag 1, 06:30 | time_config |
| Laufgeschwindigkeit / mit Leiche | 3,2 / 2,0 m/s | `data/config/player_config.tres` |
| Aktionsdauer (Spielminuten) | Untersuchen 20, Graben 60, Bestatten 30, Grabzeichen 10, Sammeln 10 | `data/config/action_config.tres` |
| Echtzeitdauer einer Aktion | 1,5 s (Graben 3 s) | action_config |
| Frische-Verlust | 0,02 pro Spielstunde (× Faktor der Todesursache) | `data/corpses/corpse_tables.tres` |
| Sammeln pro Tag | Holzstapel 6, Steinhaufen 4 | Ressourcenknoten (Layout) |
| Leinenpreis | 3 Münzen | Dialog `carter` |
| Startinventar | 5 Münzen, 2 Holz, 1 Leinen | `data/config/player_config.tres` |

### Grabqualität (0 … 10)
| Faktor | Punkte |
|---|---|
| Bestattet | +2 |
| Leichentuch | +2 |
| Holzkreuz / Grabstein | +1 / +3 |
| Frische ≥ 0,6 / < 0,3 | +1 / −1 |
| Wertsachen liegen gelassen / genommen | +1 / −2 |
| Untersucht | +1 |

**Bezahlung** = `base_payment(Todesursache) + quality × 1` Münzen (Werte in `data/config/economy_config.tres`).
**Friedhofsqualität** = Summe der Grabqualitäten aller Gräber (alte Gräber zählen mit festem Wert) → Stufen: Verwahrlost (< 10), Ordentlich (10–24), Gepflegt (25–44), Würdevoll (≥ 45).

### Rezepte (Werkbank, `data/recipes/`)
| Rezept | Zutaten | Ergebnis | Spielminuten |
|---|---|---|---|
| `shroud` Leichentuch | 2 Leinen | 1 Leichentuch | 20 |
| `wooden_cross` Holzkreuz | 3 Holz | 1 Holzkreuz | 30 |
| `gravestone_simple` Grabstein | 4 Stein, 1 Holz | 1 Grabstein | 60 |

### Items (`data/items/<id>.tres`)
`coin` (Münze, Währung, Stapel 9999) · `wood` (Holz, 50) · `stone` (Stein, 50) · `linen` (Leinen, 20) · `shroud` (Leichentuch, 10) · `wooden_cross` (Holzkreuz, 5) · `gravestone_simple` (Grabstein, 5).

## 3. Architektur

### 3.1 Autoloads (Reihenfolge in `project.godot`)
| Name | Datei | Aufgabe |
|---|---|---|
| `EventBus` | `src/core/event_bus.gd` | globale Signale (§3.3) |
| `GameConfig` | `src/core/game_config.gd` | Version, Debug-Flag |
| `Database` | `src/core/database.gd` | lädt alle Items/Rezepte/Dialoge/Tabellen aus `data/` · Lookup per id |
| `TimeManager` | `src/systems/time/time_manager.gd` | Spieluhr, Tag, Pausieren, `advance(minutes)` |
| `GameState` | `src/systems/game_state/game_state.gd` | Flags, Statistik (Bestattungen, Ruf), Tages-Zähler |
| `SaveManager` | `src/systems/save/save_manager.gd` | Speichern/Laden (§5) |
| `Debug` | `src/debug/debug_console.tscn` | Debug-Konsole (nur Debug-Builds aktiv) |

Autoloads halten **keinen** Szenenbezug fest (nur Daten/Dienste). Szenen-Systeme (Friedhof, Leichen, NPC) leben in der Weltszene.

### 3.2 Ordner & Besitz (wer schreibt was)
| Modul | Pfad | Inhalt |
|---|---|---|
| Inventar/Items/Crafting | `src/systems/inventory/`, `src/systems/crafting/`, `data/items/`, `data/recipes/`, `data/config/economy_config.tres` | `ItemData`, `ItemStack`, `Inventory`, `RecipeData`, `CraftingSystem`, `EconomyConfig` |
| Zeit/Status/Speichern | `src/systems/time/`, `src/systems/game_state/`, `src/systems/save/`, `src/world/atmosphere/` (Erweiterung), `data/config/time_config.tres`, `data/atmosphere/dawn.tres`, `dusk.tres` | `TimeConfig`, `TimeManager`, `GameState`, `SaveManager`, `Saveable`-Vertrag, Atmosphären-Blending |
| Leichen/Gräber | `src/systems/corpse/`, `src/systems/graveyard/`, `data/corpses/` | `CorpseRecord`, `CorpseTables`, `CorpseGenerator`, `GraveRecord`, `GraveQuality`, `CemeteryRating` |
| Dialog/NPC-Logik | `src/systems/dialogue/`, `src/systems/npc/`, `data/dialogue/`, `data/npc/` | `DialogueData/Node/Choice`, `DialogueRunner`, `NpcSchedule`, `ScheduleEntry`, `ScheduleResolver` |
| Spieler/Interaktion | `src/entities/player/`, `src/components/` | `Interactable`, `InteractionDetector`, `Player`, `PlayerConfig`, `ActionConfig`, `TimedAction` |
| Welt-Entitäten | `src/entities/{corpse,grave,morgue_table,workbench,dropoff,resource_node,npc}/` | Szenen + Scripts, verbinden Logik & Welt |
| Welt | `src/world/graveyard/`, `data/world/graveyard_layout.json` | `graveyard.tscn`, `graveyard_builder.gd`, `WorldRoot` |
| UI | `src/ui/` , `assets/ui/` | Theme, HUD, Panels (Inventar, Leiche, Crafting, Dialog, Pause), Icons |
| Debug | `src/debug/` | Debug-Konsole |
| Assets | `tools/blender/`, `assets/models/`, `art_source/` | neue Modelle, Rig + Animationen |
| Tests | `tests/unit/test_<modul>.gd`, `tests/integration/` | pro Modul eigene Datei |

**Geteilte Dateien** (nur Lead ändert): `project.godot`, `src/core/event_bus.gd`, `src/core/database.gd`, `tests/run_tests.gd`, `tests/framework/*`, `docs/*`.

### 3.3 EventBus-Signale (vollständige Liste für Phase 2)
```gdscript
signal game_booted
signal debug_mode_changed(enabled: bool)
# Zeit
signal time_tick(day: int, minute_of_day: int)     # jede Spielminute
signal hour_changed(day: int, hour: int)
signal day_started(day: int)
# Welt
signal world_ready(world: Node)                      # Weltszene fertig (nach Laden: danach werden Zustände angewandt)
signal notification_requested(text: String, kind: StringName)   # kind: &"info", &"reward", &"warning"
signal interaction_focus_changed(prompt: String)     # "" = kein Fokus
signal timed_action_started(label: String, duration_sec: float)
signal timed_action_progress(ratio: float)
signal timed_action_finished(completed: bool)
# Leichen & Gräber
signal corpse_arrived(corpse_id: String)
signal corpse_examined(corpse_id: String)
signal corpse_buried(corpse_id: String, grave_id: String, quality: int)
signal grave_state_changed(grave_id: String, state: int)
signal cemetery_quality_changed(total: int, rating: StringName)
signal payment_received(amount: int, reason: String)
# UI
signal ui_panel_requested(panel: StringName, context: Dictionary)  # &"inventory", &"corpse_exam", &"crafting", &"pause"
signal ui_modal_changed(open: bool)                  # Spieler-Eingabe gesperrt, solange true
# Dialog
signal dialogue_requested(dialogue_id: StringName, speaker: Node)
signal dialogue_ended(dialogue_id: StringName)
# Speichern
signal game_saved(slot: int)
signal game_loaded(slot: int)
```

### 3.4 Kernklassen (Signaturen = Vertrag)

**Items & Inventar**
```gdscript
class_name ItemData extends Resource
@export var id: StringName; @export var display_name: String; @export_multiline var description: String
@export var icon: Texture2D; @export var max_stack: int = 50
enum Category { RESOURCE, CRAFTED, CURRENCY }
@export var category: Category = Category.RESOURCE

class_name Inventory extends Node          # Komponente (Kind des Spielers)
signal changed
@export var slot_count: int = 16
func add_item(id: StringName, amount: int) -> int        # gibt NICHT hinzugefügte Menge zurück
func remove_item(id: StringName, amount: int) -> bool    # alles oder nichts
func count(id: StringName) -> int
func has(id: StringName, amount: int = 1) -> bool
func get_slots() -> Array[Dictionary]                    # [{id, amount}] oder {} für leer
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void

class_name RecipeData extends Resource
@export var id: StringName; @export var display_name: String
@export var inputs: Dictionary[StringName, int]; @export var output_id: StringName; @export var output_amount: int = 1
@export var craft_minutes: int = 30; @export var station: StringName = &"workbench"

class_name CraftingSystem extends RefCounted
static func can_craft(recipe: RecipeData, inv: Inventory) -> bool
static func craft(recipe: RecipeData, inv: Inventory) -> bool   # entnimmt Zutaten, fügt Ergebnis hinzu (atomar)
```

**Zeit & Status**
```gdscript
class_name TimeConfig extends Resource
@export var seconds_per_game_minute := 0.5; @export var start_day := 1; @export var start_minute := 390
@export var night_start_minute := 1260; @export var night_end_minute := 330

# Autoload TimeManager
var day: int; var minute_of_day: int          # 0..1439
var paused: bool                               # true während Modal-UI/Dialog
func advance(minutes: int) -> void             # sendet time_tick/hour_changed/day_started für übersprungene Zeit korrekt
func set_time(day: int, minute_of_day: int) -> void
func is_night() -> bool
func total_minutes() -> int                    # (day-1)*1440 + minute_of_day
func format_clock() -> String                  # "07:40"
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void

# Autoload GameState
func set_flag(name: StringName, value: Variant = true) -> void; func get_flag(name, default = null)
func has_flag(name) -> bool; func clear_flags() -> void
var stats: Dictionary   # burials:int, valuables_taken:int, reputation:int
```

**Leichen & Gräber (reine Logik, ohne Szene)**
```gdscript
class_name CorpseRecord extends RefCounted
var id: String; var display_name: String; var age: int; var cause_id: StringName
var traits: Array[StringName]; var revealed: bool; var examined: bool
var freshness: float = 1.0; var shrouded: bool; var valuables_decision: StringName = &""  # &"taken" / &"left"
var location: StringName = &"dropoff"   # &"dropoff", &"carried", &"table", &"ground", &"buried"
var position: Vector3; var grave_id: String = ""; var arrival_total_minutes: int
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> CorpseRecord
func decay(hours: float, tables: CorpseTables) -> void

class_name CorpseTables extends Resource   # data/corpses/corpse_tables.tres
@export var first_names: PackedStringArray; @export var last_names: PackedStringArray
@export var causes: Array[Dictionary]      # {id, label, description, weight, decay_mult, base_payment}
@export var traits: Array[Dictionary]      # {id, label, reveal_text, chance, quality}
@export var base_decay_per_hour := 0.02

class_name CorpseGenerator extends RefCounted
static func generate(seed: int, tables: CorpseTables, day: int) -> CorpseRecord   # deterministisch pro seed

class_name GraveRecord extends RefCounted
enum State { EMPTY, DUG, FILLED, MARKED, OLD }
var id: String; var state: State; var corpse_id: String; var marker_id: StringName; var quality: int
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> GraveRecord

class_name GraveQuality extends RefCounted
static func compute(corpse: CorpseRecord, marker_id: StringName, config: EconomyConfig) -> int  # §2-Tabelle, 0..10
class_name CemeteryRating extends RefCounted
static func rating(total: int) -> StringName    # &"neglected", &"orderly", &"tended", &"dignified"
static func label(rating: StringName) -> String  # deutsche Anzeige
```

**Dialog & NPC-Tagesablauf**
```gdscript
class_name DialogueData extends Resource   # data/dialogue/<id>.tres
@export var id: StringName; @export var speaker_name: String; @export var start_node: StringName
@export var nodes: Array[DialogueNode]
class_name DialogueNode extends Resource
@export var id: StringName; @export_multiline var text: String; @export var choices: Array[DialogueChoice]
@export var conditions: Array[String] = []   # alle müssen erfüllt sein, sonst wird der Knoten übersprungen (→ fallback_next)
@export var fallback_next: StringName
class_name DialogueChoice extends Resource
@export var text: String; @export var next: StringName   # &"" = Dialog endet
@export var conditions: Array[String]   # "has_item:coin:3", "flag:met_carter", "!flag:x", "time_between:420:600"
@export var actions: Array[String]      # "set_flag:met_carter", "take_item:coin:3", "give_item:linen:1", "notify:Text"

class_name DialogueRunner extends RefCounted
func start(data: DialogueData, context: Dictionary) -> void    # context: {inventory: Inventory}
func current_text() -> String; func available_choices() -> Array[DialogueChoice]
func choose(index: int) -> void; func is_finished() -> bool
static func check_condition(cond: String, context: Dictionary) -> bool
static func apply_action(action: String, context: Dictionary) -> void

class_name ScheduleEntry extends Resource
@export var start_minute: int; @export var activity: StringName   # &"home", &"walk", &"deliver", &"idle", &"smoke"
@export var path: PackedStringArray       # Wegpunkt-IDs, die ab start_minute abgelaufen werden
@export var dialogue_id: StringName       # Dialog in dieser Phase (leer = kein Dialog)
@export var visible: bool = true          # false = "zu Hause" (unsichtbar, off-map)
class_name NpcSchedule extends Resource
@export var npc_id: StringName; @export var display_name: String; @export var entries: Array[ScheduleEntry]
class_name ScheduleResolver extends RefCounted
static func entry_at(schedule: NpcSchedule, minute_of_day: int) -> ScheduleEntry   # sortiert, wrap über Mitternacht
static func progress_along_path(entry: ScheduleEntry, minute_of_day: int, path_length_m: float, speed_mps: float, seconds_per_minute: float) -> float  # 0..1 für deterministisches Positionieren nach Laden/Zeitsprung
```

**Interaktion & Spieler**
```gdscript
class_name Interactable extends Area3D      # Layer 4 "interactable"
@export var prompt: String = "Benutzen"; @export var priority: int = 0; @export var enabled := true
@export var target_path: NodePath = ^".."   # Knoten mit: can_interact(player) -> bool,
                                            #   get_interaction_prompt(player) -> String, interact(player) -> void
class_name InteractionDetector extends Area3D   # am Spieler, wählt bestes Interactable (Priorität, dann Distanz/Blickrichtung)
signal focus_changed(interactable: Interactable)

class_name Player extends CharacterBody3D   # Gruppe "player", Gruppe "saveable", save_id "player"
enum State { FREE, CARRYING, BUSY, LOCKED }
var inventory: Inventory; var carried: Node3D
func pick_up(node: Node3D) -> void; func drop_carried(target_position: Vector3) -> Node3D
func start_timed_action(label: String, real_seconds: float, game_minutes: int, on_done: Callable) -> void
func cancel_timed_action() -> void
```
Tragen: getragene Leiche wird an `CarrySocket` umgehängt. **Q** legt sie vor dem Spieler ab. E mit Fokus auf Leichentisch/offenes Grab legt sie dort ab.

## 4. Welt `src/world/graveyard/graveyard.tscn`

- Erzeugt von `graveyard_builder.gd` aus `data/world/graveyard_layout.json` (erweitert das Prototyp-Layout; Art-Prototyp bleibt unverändert als Stil-Referenz).
- **Friedhof** (wie Prototyp) + **6 freie Grabstellen** (Holzpflöcke + Schnur) + alte Gräber (Zustand OLD, feste Qualität 2).
- **Angrenzender Bereich „Kutschweg"** südlich des Tors: Weg Richtung Dorf (bis z ≈ +26), Waldrand, Wegweiser „→ Dorf Hollerbrück" (Dorf selbst folgt in Phase 7; Weg endet an einem umgestürzten Baum = Grenze).
- Übergang: durchgehende Welt (kein Ladebildschirm); Tor = Grenze Friedhof/Kutschweg. Regionen-Wechsel mit Szenenwechsel folgt, wenn das Dorf kommt.
- **Kollisionen** für Hütte, Bäume, Grabsteine, Zaun, Werkbank, Tisch, Karren (Tabelle `colliders` im Layout).
- **Wegpunkte** (`Marker3D` unter `Waypoints`): `road_end`, `road_mid`, `gate_outside`, `dropoff`, `evening_spot`.
- **Entitäten**: Ablage (am Tor), Leichentisch (vor der Hütte), Werkbank (an der Hütte), Holzstapel, Steinhaufen, Hüttentür (Schlafen), 6 Grabstellen, NPC Kutscher, Spieler.
- **Kamera**: `CameraRig` (Perspektive, FOV 30°, 45°), folgt dem Spieler; Grenzen per Layout.
- `WorldRoot` (Skript am Wurzelknoten): meldet `EventBus.world_ready`, hält Referenzen auf `CorpseManager` und `Graveyard`.
- **`CorpseManager`** (Knoten, saveable): besitzt alle `CorpseRecord`s, erzeugt/entfernt Leichen-Knoten, Tages-Seed = `day * 7919 + 17`.
- **`Graveyard`** (Knoten, saveable): verwaltet `GraveRecord`s, rechnet Friedhofsqualität, sendet `cemetery_quality_changed`.

## 5. Speichern / Laden

- Datei: `user://saves/slot_<n>.json`, Format:
```json
{ "format_version": 1, "game_version": "0.2.0", "scene": "res://src/world/graveyard/graveyard.tscn",
  "day": 2, "minute_of_day": 455,
  "autoloads": { "TimeManager": {...}, "GameState": {...} },
  "nodes": { "player": {...}, "corpse_manager": {...}, "graveyard": {...}, "npc_carter": {...}, "res_wood": {...} } }
```
- **Saveable-Vertrag**: Knoten in Gruppe `saveable` mit `@export var save_id: String` und `save_state() -> Dictionary` / `load_state(data: Dictionary) -> void`. Nur JSON-Typen (Vector3 als `[x,y,z]`).
- **Laden**: SaveManager liest Datei → wendet Autoload-Zustände an → wechselt zur gespeicherten Szene → wartet auf `world_ready` → ruft `load_state` für jede `save_id` → sendet `game_loaded`.
- Unbekannte/fehlende IDs werden gewarnt, nicht abgestürzt. `format_version` erlaubt spätere Migration.
- Autosave beim Schlafen (Slot 0), Schnellspeichern F5 / Laden F9 (Slot 1), Pause-Menü (Slot 1).

## 6. Debug-Konsole (F1, nur Debug-Builds)

Panel mit Knöpfen + Befehlszeile:
`time HH:MM` · `day +1` · `pause` · `give <item> <n>` · `spawn corpse` · `npc carter here` · `npc carter schedule` · `tp <gate|hut|road|workbench>` · `save [slot]` · `load [slot]` · `camera ortho|persp` · `flags` · `flags clear` (entspricht „Quest zurücksetzen" bis Quests existieren) · `quality` · `fps`.
Deaktiviert, wenn `GameConfig.debug_enabled == false` (Release-Export). Gegner spawnen / Gebäude platzieren kommen mit den jeweiligen Systemen.

## 7. UI (`src/ui/`)

Eigenes Theme (`src/ui/theme/gravekeeper_theme.tres`): dunkles Holz/Pergament aus der Palette, Bernstein-Akzent. **Platzhalter-Schrift** (Godot-Standard) bis zur Font-Entscheidung.
- **HUD**: Tag + Uhrzeit + Sonne/Mond (oben links) · Münzen, Holz, Stein, Leinen (oben rechts) · Friedhofsqualität + Stufe · Interaktions-Hinweis (unten Mitte, „[E] Leiche aufheben") · Fortschrittsbalken für Aktionen · Benachrichtigungen (rechts, verblassen).
- **Inventar** (I/Tab): 16 Felder mit Icon + Anzahl + Tooltip.
- **Untersuchungs-Panel**: Name, Alter, Todesursache, Frische (Balken), Merkmale (verdeckt bis untersucht), Aktionen.
- **Crafting-Panel**: Rezeptliste, Zutaten „hat/braucht", Herstellen-Knopf.
- **Dialogbox**: Sprecher, Text, Antwort-Knöpfe (1–4 per Taste).
- **Pause-Menü** (Esc): Fortsetzen, Speichern, Laden, Beenden.
- Solange ein Panel offen ist: `ui_modal_changed(true)` → Spieler gesperrt, Zeit pausiert.
- Item-Icons werden aus den 3D-Item-Modellen gerendert (`src/debug/icon_renderer.gd`) → `assets/ui/icons/<id>.png`.

## 8. Assets (Stil gesperrt, Blender-Scripts)

| Asset | Zweck |
|---|---|
| `ph_chr_gravekeeper` **mit Rig + Animationen** | idle, walk, carry_idle, carry_walk, dig, interact |
| `ph_chr_carter` (Leichenkutscher, gleiches Rig) | idle, walk, push_cart, talk |
| `ph_prop_corpse`, `ph_prop_corpse_shrouded` | liegende Leiche (einfache Kleidung), eingehüllte Leiche |
| `ph_prop_handcart` | Karren des Kutschers |
| `ph_prop_morgue_table`, `ph_prop_workbench`, `ph_prop_dropoff_bier` | Leichentisch, Werkbank, Ablage (Bahre) |
| `ph_prop_grave_plot_empty`, `ph_prop_grave_pit` | freie Grabstelle (Pflöcke+Schnur), offenes Grab mit Erdhaufen |
| `ph_prop_wood_pile`, `ph_prop_stone_rubble` | Ressourcenknoten |
| `ph_prop_cross_wood` | Holzkreuz als Grabzeichen |
| `ph_prop_signpost`, `ph_prop_fallen_log`, `ph_env_bush` | Kutschweg / Grenze |
| `ph_item_log`, `ph_item_stone`, `ph_item_linen`, `ph_item_coin`, `ph_item_shroud` | Item-Modelle (für Icons) |

**Rig**: starre Gewichtung (jedes Teil 100 % an einen Knochen): `root, hips, spine, head, arm_l, arm_r, leg_l, leg_r`; Aktionen per Script gekeyt, glTF-Export mit Animationen. 30 FPS, Root-Motion aus.

## 9. Tests (Abnahme)

- **Test-Framework**: `tests/framework/test_case.gd` (Assertions), `tests/run_tests.gd` findet alle `tests/unit/test_*.gd` und `tests/integration/test_*.gd` automatisch.
- **Unit-Tests pro Modul** (Pflicht): Inventar (Stapeln, volle Slots, atomares Entfernen), Crafting (fehlende Zutaten, atomar), Zeit (advance über Mitternacht, Signale), GameState, Save (Roundtrip Datei), Leichen (Determinismus, Verfall, dict-Roundtrip), Grabqualität (Tabelle §2), Friedhofsstufen, Dialog (Bedingungen/Aktionen), Zeitplan (entry_at mit Wrap).
- **Integrationstest** `tests/integration/test_vertical_slice_loop.gd`: lädt `graveyard.tscn` headless, spielt den kompletten Loop per API (Leiche spawnen → aufheben → Tisch → untersuchen → Tuch → Grab ausheben → bestatten → Kreuz setzen → Bezahlung/Qualität prüfen) → **speichern → neu laden → Zustand identisch**.
- **Regression**: Art-Prototyp-Tests bleiben grün.
- **Performance**: Screenshot-Durchlauf + Render-Statistik (Budgets aus TECHNICAL_ARCHITECTURE.md).

## 10. Nicht im Slice (bewusst)
Dorf, Quests, Kampf, Gegner, Krypten, Auferstehung, Wirtschaftssystem jenseits Bezahlung/Leinen, Gebäudebau, Musik/Sound (Agent 17 bleibt inaktiv), Controller-Unterstützung.
