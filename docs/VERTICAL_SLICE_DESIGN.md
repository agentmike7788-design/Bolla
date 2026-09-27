# Vertical Slice Design (Phase 2) – Vertrag v2

Status: **v2 – verbindlich für die Umsetzung** · Verantwortlich: Agent 01 (Lead)
v2 arbeitet die Befunde der Design-Review ein (3 unabhängige Linsen: Gameplay, Godot-Technik, Parallel-Vertrag/Testbarkeit).
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Vertical-Slice-Gate. ART STYLE LOCK ist aktiv.

**Regeln für alle Agents**
- Klassen, Signaturen, Dateipfade, Signale und Datenformate in diesem Dokument sind **fest**. Änderungen nur über den Lead.
- Die Datenklassen (Resources) sind bereits vollständig implementiert; Logikklassen existieren als **Stubs mit exakten Signaturen** – der Besitzer füllt die Körper, benennt nichts um.
- Nach dem Anlegen eines Worktrees und nach jedem Merge: `godot --headless --path . --import` (sonst sind `class_name`s unbekannt).
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern – Bedarf an den Lead melden.

---

## 1. Spielablauf im Slice

**Ein Tag (1 Spieltag = 12 Echtminuten, Aktionen raffen Spielzeit):**
1. **06:30** Tag beginnt. HUD-Zielzeile: „Der Leichenkutscher kommt gegen 07:40".
2. **07:00** Leichenkutscher **Osric Faulhaber** schiebt seinen Karren vom Kutschweg ans Friedhofstor, **07:40** Ankunft an der **Ablage** (Bahre am Tor): liefert **eine Leiche** (Regeln §2.5). Er bleibt bis **10:00** (Dialog, **Leinen kaufen**), kommt **18:30–21:00** wieder ans Tor (Dialog, Leinen kaufen).
3. Beim **ersten Gespräch** erklärt er in 2–3 Sätzen den Job, das Leichentuch (braucht Leinen) und wann er wiederkommt.
4. Spieler **hebt die Leiche auf** (E), trägt sie (langsamer), legt sie auf den **Leichentisch** vor der Hütte (E).
5. **E am belegten Tisch** (Hände frei) öffnet das **Untersuchungs-Panel**:
   - **Untersuchen** (20 Min): deckt Todesursache-Details und Merkmale auf.
   - **Entscheidung** (nur wenn untersucht und Merkmal *Wertsachen* aufgedeckt): *Nehmen* (+Münzen, Grabqualität −2, Ruf sinkt) oder *Liegen lassen* (Grabqualität +1). Endgültig. Die Knöpfe zeigen die Folgen.
   - **Leichentuch anlegen** (10 Min, verbraucht 1 Leichentuch, +2 Qualität; gesperrt bis die Wertsachen-Entscheidung gefallen ist, falls es eine gibt).
   - **Aufnehmen** (Leiche wieder tragen).
6. **Freie Grabstelle** → **Grab ausheben** (60 Min).
7. Mit getragener Leiche am offenen Grab → **Bestatten** (30 Min) → frischer Grabhügel.
8. **Grabzeichen setzen** (10 Min): Holzkreuz oder Grabstein; hat der Spieler beide, erscheint eine kleine Auswahl.
9. **Grab vollendet**: Belohnungskarte mit Aufschlüsselung („Qualität 9/10: Bestattet +2, Leichentuch +2, Grabstein +3, frisch +1, untersucht +1 → +7 Münzen"), Münzen, Friedhofsqualität steigt.
10. **Ressourcen**: Holzstapel (6/Tag), Steinhaufen (4/Tag), je 1 pro Interaktion (10 Min). Leinen nur beim Kutscher.
11. **Werkbank**: Leichentuch, Holzkreuz, Grabstein.
12. **Hüttentür**: vor 18:00 **„Ausruhen bis 18:00"**; ab 18:00 (oder nach Mitternacht vor 06:00) **„Schlafen bis 06:00"** → Tageszusammenfassung → **Autosave**.
13. **Speichern/Laden**: F5/F9 (Schnellspeicher), Esc-Menü, Titelbildschirm „Fortsetzen / Neues Spiel / Beenden".

**Slice-Ende:** Nach dem 6. vollendeten Grab: Flag `slice_complete`, keine Lieferungen mehr, **Abschluss-Panel** (Tage, Bestattungen, Friedhofsqualität, Stufe, Ruf). Ziel: Stufe „Würdevoll" (≥ 50, ≈ 8,3 pro Grab).

## 2. Spielwerte (Vorschläge, alle in `data/`)

### 2.1 Zeit & Aktionen
| Wert | Vorschlag | Ort |
|---|---|---|
| Echtzeit pro Spielminute | 0,5 s | `TimeConfig.seconds_per_game_minute` |
| Start | Tag 1, 06:30 (390) | `TimeConfig.start_day/start_minute` |
| Nacht | 21:00–05:30 | `TimeConfig.night_start_minute=1260 / night_end_minute=330` |
| Ausruhen bis / Schlafen ab / Aufwachen | 18:00 / 18:00 / 06:00 | `TimeConfig.rest_until_minute=1080 / sleep_from_minute=1080 / wake_minute=360` |
| Laufen / mit Leiche | 3,2 / 2,0 m/s | `PlayerConfig` |
| Aktionen (Spielminuten) | Untersuchen 20, Tuch 10, Graben 60, Bestatten 30, Grabzeichen 10, Sammeln 10, Crafting = Rezept | `ActionConfig` |
| Echtzeit einer Aktion | `clamp(minuten × 0.05, 1.5, 4.0)` s | `ActionConfig.real_seconds_for()` |

### 2.2 Items (`data/items/<id>.tres`)
| id | Name | Kategorie | Stapel |
|---|---|---|---|
| `coin` | Münze | CURRENCY (belegt **keinen** Slot) | – |
| `wood` | Holz | RESOURCE | 50 |
| `stone` | Stein | RESOURCE | 50 |
| `linen` | Leinen | RESOURCE | 20 |
| `shroud` | Leichentuch | CRAFTED | 10 |
| `wooden_cross` | Holzkreuz | CRAFTED | 5 |
| `gravestone_simple` | Grabstein | CRAFTED | 5 |

Startinventar (bei *Neues Spiel*): 5 Münzen, 2 Holz, 1 Leinen (`PlayerConfig.start_items`).

### 2.3 Rezepte (`data/recipes/<id>.tres`, Station `workbench`)
| id | Zutaten | Ergebnis | Minuten |
|---|---|---|---|
| `shroud` | 2 linen | 1 shroud | 20 |
| `wooden_cross` | 3 wood | 1 wooden_cross | 30 |
| `gravestone_simple` | 4 stone, 1 wood | 1 gravestone_simple | 60 |

### 2.4 Grabqualität & Bezahlung (`data/config/economy_config.tres`, Klasse `EconomyConfig`)
| Faktor | Punkte |
|---|---|
| Bestattet | +2 |
| Leichentuch | +2 |
| Holzkreuz / Grabstein | +1 / +3 |
| Frische bei Bestattung ≥ 0,6 / < 0,3 | +1 / −1 |
| Untersucht | +1 |
| Wertsachen liegen gelassen / genommen | +1 / −2 |
Qualität = Summe, geklemmt 0…10. **Bezahlung** = `base_payment(Todesursache)` (2–4) + `floor(Qualität × 0,5)`.
Wertsachen: 5–8 Münzen (pro Leiche beim Generieren festgelegt), Ruf −1.
**Friedhofsqualität** = Summe der Qualitäten aller vollendeten Gräber (alte Gräber zählen **0**). Stufen (v3, nach Playthrough-Review): Verwahrlost < 15 ≤ Ordentlich < 32 ≤ Gepflegt < 50 ≤ Würdevoll – ohne Leichentuch, mit Holzkreuzen oder bei dreimaligem Wertsachen-Raub wird „Würdevoll" verfehlt.
Ruf (`GameState.stats.reputation`, Start 0): ≥ 0 „Geachtet", −1…−2 „Unauffällig", ≤ −3 „Verrufen" (Anzeige im Inventar-Panel; Kutscher reagiert).

*Nachrechnung Tag 1:* 5 Münzen − 3 (1 Leinen) = 2 → Qualität 9 (ohne Wertsachen) → +3+4 = **9 Münzen**. Tag 2 (Wertsachen): liegen lassen 9−6+(3+5)=11 · nehmen 9−6+6+(3+3)=15 → Raub lohnt kurzfristig (+4), kostet Qualität/Ruf.

### 2.5 Leichen (`data/corpses/corpse_tables.tres`, Klasse `CorpseTables`)
- **Lieferung** um `delivery_minute = 460` (07:40), einmal pro Tag, nur wenn **(a)** die Ablage frei ist **und (b)** `freie Grabstellen (EMPTY/DUG) > nicht bestattete Leichen`. Sonst: keine Leiche (keine Warteschlange), `stats.missed_deliveries += 1`, Flag `delivery_skipped` = Tag, Kutscher-Dialog „Die Bahre ist noch belegt …". Nach `slice_complete`: keine Lieferungen.
- **Verfall**: `base_decay_per_hour = 0.05` × `decay_mult` der Todesursache (0,75–1,5), berechnet aus der **Differenz der Spielminuten** (nie Ticks zählen), stoppt bei Bestattung, Minimum 0. Stufen: Frisch ≥ 0,6 · Welk · Verwesend < 0,3.
- **Merkmale**: `valuables` (Wertsachen, Chance 0,35, hat Entscheidung), `letter` (Brief), `tattoo`, `strange_wound` (Geheimnis-Andeutung) – außer `valuables` nur Erzähltext. `forced_traits_by_day` (v3): Tag 1 = keine (Tutorial), Tag 2 = `valuables`, Tag 3 = `strange_wound`, Tag 4 = `valuables`+`letter`, Tag 5 = `valuables`+`tattoo`, ab Tag 6 zufällig – so erscheint die Moral-Entscheidung 3× und „Verrufen" ist erreichbar.
- **Determinismus**: Seed = `day × 7919 + 17 + 104729 × spawn_index_of_day`; nur lokaler `RandomNumberGenerator`.

## 3. Architektur

### 3.1 Autoloads (Reihenfolge in `project.godot`, alle `PROCESS_MODE_ALWAYS` wo nötig)
| Name | Datei | Besitzer | Aufgabe |
|---|---|---|---|
| `EventBus` | `src/core/event_bus.gd` | Lead | Signale §3.3 (nur Benachrichtigung – Listener ändern **keinen** Spielzustand) |
| `GameConfig` | `src/core/game_config.gd` | Lead | Version, Debug-Flag |
| `Database` | `src/core/database.gd` | Lead | Daten-Registry §3.5 |
| `UIState` | `src/core/ui_state.gd` | Lead | Modal-Stapel: `push_modal(id)`, `pop_modal(id)`, `clear()`, `is_modal()`, `top()`; sendet `ui_modal_changed` bei 0↔1; pausiert/entpausiert die Zeit (`&"modal"`) |
| `TimeManager` | `src/systems/time/time_manager.gd` | M2 | Spieluhr §3.4 |
| `GameState` | `src/systems/game_state/game_state.gd` | M2 | Flags & Statistik |
| `SaveManager` | `src/systems/save/save_manager.gd` | M2 | Neues Spiel, Speichern, Laden §5 |
| `Debug` | `src/debug/debug_console.tscn` | W2 | Debug-Konsole §6 |

### 3.2 Module & Besitz
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** | `project.godot`, `src/core/*`, `src/boot/*`, `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*`, alle **Datenklassen** (unten ✦), `docs/*`, `CLAUDE.md` |
| **M1 Inventar/Crafting** | `src/systems/inventory/inventory.gd`, `src/systems/crafting/crafting_system.gd`, `data/items/*`, `data/recipes/*`, `tests/unit/test_inventory.gd`, `test_crafting.gd` |
| **M2 Zeit/Status/Speichern** | `tests/fixtures/save_world/*`, `src/systems/time/time_manager.gd`, `src/systems/game_state/game_state.gd`, `src/systems/save/save_manager.gd`, `src/world/atmosphere/*` (Erweiterung, Prototyp-kompatibel), `data/config/time_config.tres`, `data/atmosphere/dawn.tres`, `dusk.tres`, `tests/unit/test_time.gd`, `test_game_state.gd`, `test_save.gd`, `test_atmosphere.gd` |
| **M3 Leichen/Gräber** | `src/systems/corpse/{corpse_record,corpse_generator,corpse_manager}.gd`, `src/systems/graveyard/{grave_record,grave_quality,cemetery_rating,graveyard}.gd`, `data/corpses/corpse_tables.tres`, `data/config/economy_config.tres`, `tests/unit/test_corpse.gd`, `test_corpse_manager.gd`, `test_grave_quality.gd`, `test_cemetery_rating.gd`, `test_graveyard.gd` |
| **M4 Dialog/NPC-Logik** | `src/systems/dialogue/dialogue_runner.gd`, `src/systems/npc/schedule_resolver.gd`, `data/dialogue/*`, `data/npc/*`, `tests/unit/test_dialogue.gd`, `test_schedule.gd` |
| **M5 Spieler/Interaktion** | `src/components/{interactable,interaction_detector}.gd`, `src/entities/player/{player.gd,player.tscn}`, `data/config/player_config.tres`, `action_config.tres`, `tests/unit/test_interaction.gd`, `test_player.gd` |
| **M6a Figuren/Rig** | `tools/blender/lib_painted.py`, `build_all.py`, `asset_character.py`, `asset_carter.py`, `rig.py`, `assets/models/characters/**`, `art_source/blender/characters/**`, `tests/unit/test_assets_characters.gd` |
| **M6b Requisiten/Items** | `tools/blender/asset_props_slice.py`, `asset_items.py`, zugehörige `assets/models/{props,environment,items}/**` + `art_source/**`, `tests/unit/test_assets_props.gd`, `docs/reviews/phase2_assets/*` |
| **W1 Welt/Entitäten** (Welle 2) | `src/entities/{corpse,grave,morgue_table,workbench,dropoff,resource_node,npc,hut_door}/*`, `src/world/graveyard/*`, `data/world/graveyard_layout.json`, `tools/blender/asset_ground_graveyard.py`, `tests/integration/test_vertical_slice_loop.gd`, `test_graveyard_world.gd` |
| **W2 UI/Debug** (Welle 2) | `src/ui/**`, `assets/ui/**`, `src/debug/*` (außer `asset_preview.gd`, `screenshot_capture.gd`), `tests/unit/test_objective.gd`, `tests/integration/test_ui.gd` |
| **Nachträge (Lead-genehmigt)** | W1: `src/world/camera/camera_rig.gd` (optionale Bounds, Prototyp unverändert), `tests/unit/test_entities.gd`; W2: `tests/unit/test_ui.gd` + `tests/integration/test_ui_flow.gd` (statt `tests/integration/test_ui.gd`), `src/ui/tools/*` |
| **Eingefroren** | `src/world/art_prototype/*`, `src/entities/player/player_proto.*`, `data/art_prototype/*` (Stil-Referenz) |

✦ **Datenklassen (vom Lead fertig implementiert, nur Felder):** `ItemData`, `RecipeData`, `TimeConfig`, `PlayerConfig`, `ActionConfig`, `EconomyConfig`, `CorpseTables`, `DialogueData`, `DialogueNode`, `DialogueChoice`, `ScheduleEntry`, `NpcSchedule`, `AtmospherePreset` (existiert).

### 3.2.1 Klassen → Dateien
| Klasse | Datei | Art |
|---|---|---|
| `ItemData` | `src/systems/inventory/item_data.gd` | ✦ Daten |
| `Inventory` | `src/systems/inventory/inventory.gd` | Stub (M1) |
| `RecipeData` | `src/systems/crafting/recipe_data.gd` | ✦ |
| `CraftingSystem` | `src/systems/crafting/crafting_system.gd` | Stub (M1) |
| `TimeConfig` | `src/systems/time/time_config.gd` | ✦ |
| `EconomyConfig` | `src/systems/graveyard/economy_config.gd` | ✦ |
| `CorpseTables` | `src/systems/corpse/corpse_tables.gd` | ✦ |
| `CorpseRecord` / `CorpseGenerator` / `CorpseManager` | `src/systems/corpse/*.gd` | Stub (M3) |
| `GraveRecord` / `GraveQuality` / `CemeteryRating` / `Graveyard` | `src/systems/graveyard/*.gd` | Stub (M3) |
| `DialogueData` / `DialogueNode` / `DialogueChoice` | `src/systems/dialogue/*.gd` | ✦ |
| `DialogueRunner` | `src/systems/dialogue/dialogue_runner.gd` | Stub (M4) |
| `ScheduleEntry` / `NpcSchedule` | `src/systems/npc/*.gd` | ✦ |
| `ScheduleResolver` | `src/systems/npc/schedule_resolver.gd` | Stub (M4) |
| `PlayerConfig` / `ActionConfig` | `src/entities/player/{player_config,action_config}.gd` | ✦ |
| `Interactable` / `InteractionDetector` | `src/components/*.gd` | Stub (M5) |
| `Player` | `src/entities/player/player.gd` | Stub (M5) |
| `WorldRoot` | `src/world/graveyard/world_root.gd` | Stub (W1) |
| `Corpse`, `GravePlot`, `MorgueTable`, `Workbench`, `Dropoff`, `ResourceNode`, `Npc`, `HutDoor` | `src/entities/<ordner>/<name>.gd` | Stub (W1) |
| `UIRoot` | `src/ui/ui_root.gd` | Stub (W2) |
| `ObjectiveResolver` | `src/ui/hud/objective_resolver.gd` | Stub (W2) |

### 3.3 EventBus-Signale (vollständig, `src/core/event_bus.gd`)
```gdscript
signal game_booted
signal debug_mode_changed(enabled: bool)
# Zeit (TimeManager)
signal time_tick(day: int, minute_of_day: int)          # jede Spielminute im Echtzeitlauf; nach advance/Laden genau einmal
signal hour_changed(day: int, hour: int)                 # je überschrittene volle Stunde (auch in advance)
signal day_started(day: int)                             # beim Überschreiten von 00:00 (auch in advance)
signal time_skipped(from_total: int, to_total: int)      # advance(n) mit n > 1
# Spielablauf
signal new_game_started                                  # SaveManager nach world_ready eines neuen Spiels
signal world_ready(world: Node)                          # WorldRoot, nachdem alle Kinder bereit sind
signal notification_requested(text: String, kind: StringName)   # &"info", &"reward", &"warning"
signal interaction_focus_changed(prompt: String, enabled: bool) # "" = kein Fokus
signal timed_action_started(label: String, duration_sec: float)
signal timed_action_progress(ratio: float)
signal timed_action_finished(completed: bool)
# Leichen & Gräber (M3)
signal corpse_arrived(corpse_id: String)
signal corpse_updated(corpse_id: String)                 # jede Änderung am CorpseRecord (Untersuchen, Tuch, Ort, Verfall-Stufe)
signal corpse_buried(corpse_id: String, grave_id: String)
signal grave_state_changed(grave_id: String, state: int)
signal grave_completed(grave_id: String, corpse_id: String, quality: int, breakdown: Array)  # [{label, points}]
signal cemetery_quality_changed(total: int, rating: StringName)
signal payment_received(amount: int, reason: String)
signal delivery_skipped(day: int, reason: String)
signal slice_completed
# UI
signal ui_panel_requested(panel: StringName, context: Dictionary)   # Panels & Kontexte §7
signal ui_modal_changed(open: bool)                                  # nur UIState sendet
# Dialog
signal dialogue_requested(dialogue_id: StringName, speaker: Node)
signal dialogue_ended(dialogue_id: StringName)
# Speichern
signal game_saved(slot: int)
signal game_loaded(slot: int)
```

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Inventar & Crafting (M1)**
```gdscript
class_name Inventory extends Node        # Kind "Inventory" des Spielers
signal changed
@export var slot_count: int = 16
func add_item(id: StringName, amount: int) -> int        # Rest, der nicht passte. Unbekannte id → Warnung, gibt amount zurück. amount<=0 → 0
func remove_item(id: StringName, amount: int) -> bool    # alles oder nichts; amount<=0 → true
func count(id: StringName) -> int
func has(id: StringName, amount: int = 1) -> bool
func can_add(id: StringName, amount: int) -> bool
func get_slots() -> Array[Dictionary]                    # slot_count Einträge: {id: StringName, amount: int} oder {} – ohne CURRENCY
func clear() -> void
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void   # ersetzt vollständig
# Stapeln: erst bestehende Stapel auffüllen, dann leere Slots in Index-Reihenfolge. CURRENCY-Items separat (ohne Slot).
class_name CraftingSystem extends RefCounted
static func missing(recipe: RecipeData, inv: Inventory) -> Dictionary     # {id: fehlende Menge}
static func can_craft(recipe: RecipeData, inv: Inventory) -> bool          # Zutaten da UND Ergebnis passt
static func craft(recipe: RecipeData, inv: Inventory) -> bool              # atomar; keine Zeit (Zeit über TimedAction)
```

**Zeit, Status, Speichern (M2)**
```gdscript
# Autoload TimeManager
var config: TimeConfig                  # Database.config(&"time_config")
var day: int; var minute_of_day: int    # 0..1439
var running: bool = false               # tickt erst nach new_game()/load_game()
var paused: bool: get                   # true solange ein Pause-Grund aktiv ist
func push_pause(reason: StringName) -> void; func pop_pause(reason: StringName) -> void; func clear_pauses() -> void
func advance(minutes: int) -> void      # läuft auch pausiert; Grenz-Signale (day_started/hour_changed) je Übertritt, dann time_skipped (n>1), dann EIN time_tick
func set_time(day: int, minute_of_day: int) -> void   # nur vorwärts (früher = nächster Tag), via advance
func minutes_until(target_minute_of_day: int) -> int  # 0..1439 bis zur nächsten Uhrzeit
func get_minute_f() -> float            # minute_of_day + Bruchteil des Echtzeit-Akkus
func total_minutes() -> int             # (day-1)*1440 + minute_of_day
func is_night() -> bool
func format_clock() -> String           # "07:40"
func emit_refresh() -> void             # genau ein time_tick (nach Laden)
func reset() -> void                    # Config-Startwerte, running=false, keine Pausen
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void   # still (keine Signale)
# Autoload GameState
var flags: Dictionary; var stats: Dictionary   # stats: burials, valuables_taken, reputation, missed_deliveries, days_played
func set_flag(name: StringName, value: Variant = true) -> void; func get_flag(name: StringName, default: Variant = null) -> Variant
func has_flag(name: StringName) -> bool; func clear_flag(name: StringName) -> void; func clear_flags() -> void
func add_stat(name: StringName, amount: int) -> void; func get_stat(name: StringName) -> int
func reputation_label() -> String       # "Geachtet"/"Unauffällig"/"Verrufen"
func reset() -> void; func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# Autoload SaveManager → §5
# AtmosphereController (Erweiterung): @export var time_driven := false; @export var blend_presets: Array[AtmospherePreset]  # [night, dawn, day, dusk] mit Stützstellen-Uhrzeiten
#   @export var blend_minutes: PackedInt32Array = [0, 330, 540, 1110, 1260]  (Stützstellen); bei time_driven folgt die Stimmung TimeManager.get_minute_f(); apply(index)/cycle() bleiben für den Prototyp unverändert.
```

**Leichen & Gräber (M3)**
```gdscript
class_name CorpseRecord extends RefCounted
var id: String; var seed: int; var display_name: String; var age: int; var cause_id: StringName
var traits: Array[StringName]; var examined: bool; var shrouded: bool
var valuables_coins: int; var valuables_decision: StringName = &""    # &"", &"taken", &"left"
var freshness: float = 1.0; var freshness_at_burial: float = -1.0; var last_decay_total: int
var location: StringName = &"dropoff"   # &"dropoff", &"carried", &"table", &"ground", &"buried"
var position: Vector3; var rot_y: float; var grave_id: String = ""; var arrival_total_minutes: int
func has_trait(t: StringName) -> bool
func revealed_traits() -> Array[StringName]                 # leer bis examined
func freshness_stage() -> StringName                        # &"fresh", &"wilted", &"decaying"
func needs_valuables_decision() -> bool                     # examined && has valuables && decision == &""
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> CorpseRecord
class_name CorpseGenerator extends RefCounted
static func generate(seed: int, tables: CorpseTables, day: int) -> CorpseRecord   # setzt name, age, cause, traits, valuables_coins, freshness=1, seed
static func seed_for(day: int, spawn_index: int) -> int
class_name CorpseManager extends Node   # WorldRoot/Systems/CorpseManager, Gruppen &"corpse_manager", &"saveable"; save_id "corpse_manager", save_order 0
@export var corpse_scene: PackedScene   # res://src/entities/corpse/corpse.tscn
@export var container_path: NodePath    # Elternknoten für Leichen am Boden/Ablage
func records() -> Array[CorpseRecord]; func get_record(id: String) -> CorpseRecord; func get_corpse_node(id: String) -> Corpse
func try_daily_delivery(day: int) -> CorpseRecord          # Regeln §2.5, idempotent pro Tag; null bei Überspringen
func spawn_corpse(record: CorpseRecord = null, at: Transform3D = Transform3D.IDENTITY, location: StringName = &"dropoff") -> CorpseRecord  # null → neu generiert (Debug)
func pick_up(id: String, player: Player) -> bool           # → location carried, player.attach_carried(node)
func put_down(id: String, location: StringName, xform: Transform3D, parent: Node3D = null) -> bool   # player.detach_carried(); parent (Tischslot) oder container
func examine(id: String) -> void                           # examined=true, corpse_updated
func apply_shroud(id: String, inv: Inventory) -> bool      # braucht 1 shroud; gesperrt solange needs_valuables_decision
func decide_valuables(id: String, take: bool, inv: Inventory) -> void   # einmalig; take: +coins, stats, Ruf
func mark_buried(id: String, grave_id: String) -> void     # von Graveyard.bury: location buried, freshness_at_burial, auto &"left" wenn untersucht & unentschieden, Knoten entfernen
func unburied_count() -> int
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void; func post_load() -> void   # post_load hängt getragene Leiche an player an
# Verfall: bei hour_changed und time_skipped aus total_minutes-Differenz (last_decay_total)
# Lieferung: bei time_tick/time_skipped, sobald minute_of_day >= tables.delivery_minute und noch nicht für diesen Tag versucht
class_name GraveRecord extends RefCounted
enum State { EMPTY, DUG, FILLED, MARKED, OLD }
var id: String; var state: State; var corpse_id: String; var marker_id: StringName; var quality: int; var breakdown: Array
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> GraveRecord
class_name GraveQuality extends RefCounted
static func breakdown(corpse: CorpseRecord, marker_id: StringName, config: EconomyConfig) -> Array[Dictionary]   # [{label: String, points: int}]
static func compute(corpse: CorpseRecord, marker_id: StringName, config: EconomyConfig) -> int                  # clamp(Summe, min, max)
static func payment(corpse: CorpseRecord, quality: int, tables: CorpseTables, config: EconomyConfig) -> int
class_name CemeteryRating extends RefCounted
static func rating(total: int, config: EconomyConfig) -> StringName   # &"neglected", &"orderly", &"tended", &"dignified"
static func label(rating: StringName) -> String                        # Verwahrlost/Ordentlich/Gepflegt/Würdevoll
class_name Graveyard extends Node        # WorldRoot/Systems/Graveyard, Gruppen &"graveyard", &"saveable"; save_id "graveyard", save_order 10
# sammelt in _ready alle Knoten der Gruppe &"grave_plot" (Eigenschaften grave_id: String, is_old: bool) → EMPTY bzw. OLD
func graves() -> Array[GraveRecord]; func get_grave(id: String) -> GraveRecord
func free_plot_count() -> int            # EMPTY + DUG
func dig(id: String) -> bool             # EMPTY → DUG
func bury(grave_id: String, corpse_id: String) -> bool     # DUG → FILLED, corpse_manager.mark_buried, stats.burials+1, corpse_buried
func place_marker(grave_id: String, marker_id: StringName, inv: Inventory) -> int  # FILLED → MARKED; entnimmt Item, Qualität+Aufschlüsselung, zahlt Münzen in inv; Signale: grave_state_changed, grave_completed, payment_received, cemetery_quality_changed; ggf. slice_complete; gibt Bezahlung zurück
func total_quality() -> int; func rating() -> StringName
func broadcast_state() -> void           # grave_state_changed für alle + cemetery_quality_changed (nach world_ready/Laden)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
```

**Dialog & NPC (M4)**
```gdscript
class_name DialogueRunner extends RefCounted
func start(data: DialogueData, context: Dictionary) -> void     # context: {inventory: Inventory, speaker: Node}
func current_node() -> DialogueNode; func current_text() -> String
func available_choices() -> Array[DialogueChoice]               # nur Wahlen mit erfüllten Bedingungen
func choose(index: int) -> void                                  # führt actions aus, springt zu next (&"" = Ende)
func is_finished() -> bool
static func check_condition(cond: String, context: Dictionary) -> bool
static func apply_action(action: String, context: Dictionary) -> void
# Bedingungen: has_item:<id>:<n> · flag:<name> · !flag:<name> · stat_gte:<name>:<n> · stat_lt:<name>:<n> · time_between:<a>:<b> · flag_eq:<name>:<wert> · flag_today:<name> (Flag-Wert == TimeManager.day)
# Aktionen:   set_flag:<name>[:<wert>] · clear_flag:<name> · take_item:<id>:<n> · give_item:<id>:<n> · stat_add:<name>:<n> · notify:<Text>
# Knoten mit unerfüllten conditions werden übersprungen → fallback_next (Kette), start_node ist der Einstieg
class_name ScheduleResolver extends RefCounted
static func entry_at(schedule: NpcSchedule, minute_of_day: int) -> ScheduleEntry       # letzter Eintrag mit start <= t, Wrap über Mitternacht
static func progress(entry: ScheduleEntry, minute_f: float) -> float                   # clamp(wrap(minute_f - start, 0, 1440) / travel_minutes, 0, 1); travel 0 → 1
static func arrival_minute(entry: ScheduleEntry) -> int                                 # (start + travel) % 1440
```

**Interaktion & Spieler (M5)**
```gdscript
class_name Interactable extends Area3D   # collision_layer = 8 (Layer 4), mask 0, monitoring=false, monitorable=true
@export var prompt: String = "Benutzen"; @export var enabled := true   # priority = native Area3D-Eigenschaft (NICHT neu deklarieren)
@export var target_path: NodePath = ^".."
# Ziel implementiert: can_interact(player: Player) -> bool; get_interaction_prompt(player: Player) -> String; interact(player: Player) -> void
# Leerer Prompt = nicht fokussierbar. can_interact=false + Prompt = sichtbar gedimmt (Prompt enthält den Grund), E zeigt Warnung.
func get_target() -> Node
class_name InteractionDetector extends Area3D   # am Spieler, layer 0, mask 8; bewertet get_overlapping_areas() jeden Physik-Frame
signal focus_changed(interactable: Interactable)
var focused: Interactable
# Wertung: höchste priority, dann Distanz + Blickrichtung. Prioritäten: NPC 30, Leiche 20, Grab 10, Stationen 5
class_name Player extends CharacterBody3D   # Gruppen &"player", &"saveable"; save_id "player", save_order 100
enum State { FREE, CARRYING, LOCKED }
var config: PlayerConfig; var actions: ActionConfig; var state: State
@onready var inventory: Inventory = $Inventory
var carried: Node3D                   # aktuell getragene Leiche (Knoten)
var carried_id: String
var instant_actions: bool = false     # Tests: Aktionen sofort fertig (Spielzeit wird trotzdem vorgerückt)
func is_busy() -> bool                # TimedAction läuft
func attach_carried(node: Node3D, id: String) -> void   # rein mechanisch: an CarrySocket, Interactables des Knotens aus
func detach_carried() -> Node3D                          # löst vom Socket (Aufrufer hängt um), Interactables an
func start_timed_action(label: String, game_minutes: int, on_done: Callable, cancellable: bool = true, animation: StringName = &"interact") -> bool
func cancel_timed_action() -> void    # verbrauchte Minuten bleiben verbraucht, on_done wird NICHT aufgerufen
func apply_start_inventory() -> void  # aus config.start_items (nur bei new_game_started)
func drop_position() -> Transform3D   # gültige Ablage vor dem Spieler (0,8 m), sonst an den Füßen; Transform3D() + ungültig → Warnung
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# Tragen erlaubt: Tisch (ablegen), offenes Grab (bestatten), NPC (reden), Q (ablegen). Sonst Prompt "Hände frei nötig – [Q] ablegen".
# Timed Action: push_pause(&"action"), Spielzeit rückt proportional zum Fortschritt vor, am Ende Rest + on_done; Bewegung bricht ab (wenn cancellable).
# Im Zustand LOCKED (Panel offen) dürfen Panel-Knöpfe Aktionen starten (cancellable=false).
```

### 3.5 Database-API (`src/core/database.gd`, fertig)
Ordner → Schlüssel: `data/items` (`id`), `data/recipes` (`id`), `data/dialogue` (`id`), `data/npc` (`npc_id`), `data/config` (Dateiname).
`item(id)`, `has_item(id)`, `items()`, `recipe(id)`, `recipes(station=&"")`, `dialogue(id)`, `schedule(npc_id)`, `config(name)`, `corpse_tables()`, `reload()`, `icon(id) -> Texture2D` (lädt `res://assets/ui/icons/<id>.png`, sonst Platzhalter).
Rückgaben sind untypisiert `Resource` → beim Aufrufer casten: `Database.config(&"economy_config") as EconomyConfig`.
Scan per `ResourceLoader.list_directory()` (funktioniert auch in Exporten mit `.remap`).

## 4. Welt `src/world/graveyard/graveyard.tscn` (W1)

Erzeugt von `src/world/graveyard/graveyard_builder.gd` aus `data/world/graveyard_layout.json` (Schema unten). Laufzeit liest **kein** JSON.
```
Graveyard (WorldRoot)
├─ WorldEnvironment, Sun, Atmosphere (time_driven; Halte-Stützstellen, z. B. [night, night, dawn, day, day, dusk, night] @ [0, 240, 330, 480, 1020, 1140, 1260])
├─ Ground (ph_env_ground_graveyard), GroundCollision, Colliders/
├─ Systems/ CorpseManager, Graveyard
├─ Entities/ <layout-id>…   (GravePlot, MorgueTable, Workbench, Dropoff, ResourceNode, HutDoor, Npc)
├─ Decor/ (alte Gräber-Visuals, Bäume, Zaun, Props, Gras)
├─ Waypoints/ <id> (Marker3D)
├─ Corpses/ (Container der CorpseManager)
├─ Player (player.tscn)   ├─ CameraRig   └─ UI (ui_root.tscn)
```
| Szene | Wurzel / Klasse | Exporte | Gruppen |
|---|---|---|---|
| `src/entities/corpse/corpse.tscn` | Node3D / `Corpse` | – (`corpse_id` zur Laufzeit) | – |
| `src/entities/grave/grave_plot.tscn` | Node3D / `GravePlot` | `grave_id: String`, `is_old: bool` | `grave_plot` |
| `src/entities/morgue_table/morgue_table.tscn` | Node3D / `MorgueTable` | – | `morgue_table` |
| `src/entities/workbench/workbench.tscn` | Node3D / `Workbench` | `station: StringName = &"workbench"` | – |
| `src/entities/dropoff/dropoff.tscn` | Node3D / `Dropoff` | – | `dropoff` |
| `src/entities/resource_node/resource_node.tscn` | Node3D / `ResourceNode` | `save_id`, `item_id`, `daily_amount`, `model: PackedScene` | `saveable` |
| `src/entities/npc/npc.tscn` | Node3D / `Npc` | `save_id`, `npc_id`, `model: PackedScene` | `saveable`, `npc` |
| `src/entities/hut_door/hut_door.tscn` | Node3D / `HutDoor` | – | – |
| `src/entities/player/player.tscn` | CharacterBody3D / `Player` | – | `player`, `saveable` |
| `src/ui/ui_root.tscn` | CanvasLayer / `UIRoot` | – | `ui_root` |

`WorldRoot`: `var corpse_manager: CorpseManager; var graveyard: Graveyard; var is_world_ready: bool; func get_waypoint(id: StringName) -> Vector3; func get_player() -> Player; func get_node_by_layout_id(id: String) -> Node`. Sendet `EventBus.world_ready(self)` deferred nach `_ready`.
Kollisionen: Layer 1 world. Spieler: Layer 2, Maske 1|4 (world, npc). NPC-Körper: Layer 3. Interactables: Layer 4. Leichen haben keinen Körper.

**Layout-Schema** (`data/world/graveyard_layout.json`): `ground: {size:[x,z], center:[x,z], cell}`, `path`, `road` (Polylinien), `old_graves: [{id, pos, rot_y, stone, mound}]`, `plots: [{id, pos, rot_y}]`, `entities: [{id, type, pos, rot_y, params}]`, `waypoints: {id: [x,z]}`, `colliders: {asset: [{shape, size|radius+height, offset}]}`, `walkable_bounds: {min, max}`, `camera_bounds`, `player_start`, sowie `hut`, `tree`, `background_trees`, `fence`, `props`, `grass`, `lights` wie im Prototyp; Erweiterungen (W1): `lantern_posts`, `signpost`, `fallen_log`, `forest`, `waypoint_facing`, `atmosphere`, Gras-Dichte/Chunks, Boden-Abflachung, Kamera-Zoom. Generiert: `graveyard.tscn`, `grass.scn` (180 Gras-Chunks), `ground_shape.res` (HeightMap-Kollision). `WorldRoot` hat zusätzlich `ground_height(pos)` und `get_waypoint_facing(id)`.
Ids: `plot_01…plot_06`, `old_01…`, `res_wood`, `res_stone`, `npc_carter`, `morgue_table`, `workbench`, `dropoff`, `hut_door`. **Angrenzender Bereich „Kutschweg"** südlich des Tors bis z ≈ +26 mit Wegweiser „Hollerbrück" und umgestürztem Baum als Grenze. Wegpunkte: `road_end, road_mid, gate_outside, dropoff, evening_spot`.

## 5. Speichern / Laden (M2)
```gdscript
# Autoload SaveManager (PROCESS_MODE_ALWAYS), behandelt quick_save/quick_load selbst
const WORLD_SCENE := "res://src/world/graveyard/graveyard.tscn"
var save_dir: String = "user://saves"   # Tests: "user://test_saves"
var is_loading: bool
func new_game(scene_path: String = WORLD_SCENE) -> void   # reset Autoloads → Szenenwechsel → world_ready → new_game_started → TimeManager.running
func save_game(slot: int) -> Error
func load_game(slot: int) -> Error      # Coroutine; Aufrufer muss nicht warten
func can_save() -> bool                 # false bei laufender Aktion, offenem Dialog/Panel (außer Pause-Menü), is_loading
func has_save(slot: int) -> bool; func delete_save(slot: int) -> void
func get_slot_info(slot: int) -> Dictionary   # {exists, day, minute_of_day, saved_unix, game_version}
func newest_slot() -> int               # -1 wenn keiner
func collect_state() -> Dictionary      # exakt der gespeicherte "data"-Teil
func apply_state(data: Dictionary) -> void    # auf aktuelle Welt (ohne Datei/Szenenwechsel)
func reset() -> void
```
- **Datei** `<save_dir>/slot_<n>.json`: `{"format_version": 1, "meta": {game_version, day, minute_of_day, saved_unix, scene}, "data": <JSON.from_native(state)>}`. `state = {autoloads: {TimeManager, GameState}, nodes: {<save_id>: {...}}}` – innerhalb von `data` sind Vector3, int, StringName typtreu (`JSON.from_native/to_native`, ohne Objekte).
- **Saveable-Vertrag**: Gruppe `saveable`, Eigenschaften `save_id: String`, `save_order: int`; Methoden `save_state()`, `load_state(data)` (ersetzt vollständig, idempotent), optional `post_load()`.
- **Laden**: Datei lesen → `is_loading=true`, `UIState.clear()`, `TimeManager.clear_pauses()`, `get_tree().paused=false` → Autoload-Zustände still anwenden → `change_scene_to_file(meta.scene)` → `world_ready` abwarten → `load_state` je save_id **nach save_order** → `post_load()` für alle → `is_loading=false`, `running=true`, `emit_refresh()`, `Graveyard.broadcast_state()` → `game_loaded`.
- **Welt-`_ready`** erzeugt nur Struktur/Standardzustand, **nie** Spielinhalt. `Player.save_state` enthält das Inventar. Tisch/Ablage leiten ihre Belegung aus den CorpseRecords ab (nicht gespeichert). Nur `CorpseManager` hängt Leichen-Knoten um bzw. gibt sie frei (Entitäten rufen nie selbst `detach_carried`). Startinhalt (Startinventar, volle Ressourcen) nur auf `new_game_started`.
- **Slots**: 0 = Autosave (Schlafen), 1 = Schnellspeicher (F5/F9, Pause-Menü). F5/F9 bei `can_save()==false` bzw. fehlender Datei → Warnung.

## 6. Debug-Konsole (W2, F1, nur `GameConfig.debug_enabled`)
Modal (`UIState.push_modal(&"debug")`), Eingaben erreichen den Spieler nicht. Knöpfe + Befehlszeile:
`time HH:MM` · `day +1` · `pause` · `give <item> <n>` · `spawn corpse` · `npc carter here` · `tp <gate|hut|road|workbench|table>` · `save [slot]` · `load [slot]` · `camera ortho|persp` · `flags` · `flags clear` (≙ Quest zurücksetzen) · `quality` · `fps` · `instant on|off`.

## 7. UI (W2) – `src/ui/`
Theme `src/ui/theme/gravekeeper_theme.tres` (dunkles Holz/Pergament, Bernstein-Akzent, **Platzhalter-Schrift**).
`UIRoot` (CanvasLayer, `PROCESS_MODE_ALWAYS`) hört auf `ui_panel_requested`/`dialogue_requested`, verwaltet Panels über `UIState`; **Esc** schließt das oberste Panel, sonst Pause-Menü; **I** Inventar.
| Panel | Kontext |
|---|---|
| `&"inventory"` | `{inventory: Inventory}` |
| `&"corpse_exam"` | `{corpse_id: String, table: MorgueTable, player: Player}` → ruft nur `table.request_examine()`, `table.request_shroud()`, `table.decide_valuables(take)`, `table.request_pick_up()` |
| `&"crafting"` | `{station: StringName, inventory: Inventory, workbench: Workbench, player: Player}` → `workbench.request_craft(recipe_id)` |
| `&"marker_choice"` | `{grave_id: String, plot: GravePlot, options: Array[StringName]}` → `plot.request_marker(id)` |
| `&"day_summary"` | `{day, burials_today, coins_today, total, rating}` |
| `&"slice_summary"` | `{days, burials, total, rating, reputation}` |
| `&"pause"` | `{}` (setzt zusätzlich `get_tree().paused`) |
| Dialog | über `dialogue_requested(id, speaker)` → Dialogbox baut `{inventory: player.inventory, speaker}` |
**HUD**: Tag + Uhr + Sonne/Mond · Zielzeile (`ObjectiveResolver.current(...)`) · Münzen, Holz, Stein, Leinen + gefertigte Items (wenn > 0) · Friedhofsqualität + Stufe · Interaktions-Hinweis (gedimmt wenn gesperrt, mit Zeitkosten „[E] Grab ausheben (60 Min)") · Aktions-Fortschritt · Benachrichtigungen · Belohnungskarte bei `grave_completed`.
`class_name ObjectiveResolver extends RefCounted` · `static func current(corpses: Array[CorpseRecord], graves: Array[GraveRecord], inv: Inventory, minute_of_day: int, flags: Dictionary) -> String`.
**Titelbildschirm** `src/ui/title/title_screen.tscn` (Fortsetzen = `SaveManager.newest_slot()`, Neues Spiel, Beenden); `src/boot/main.gd` wechselt dorthin.
Icons: `src/ui/tools/icon_renderer.gd` rendert Item-Modelle → `assets/ui/icons/<id>.png`.

## 8. Assets (M6, Stil gesperrt)
| Asset | Zweck |
|---|---|
| `ph_chr_gravekeeper` (Rig + Animationen) | `idle-loop, walk-loop, carry_idle-loop, carry_walk-loop, dig-loop, interact` |
| `ph_chr_carter` (gleiches Rig) | `idle-loop, walk-loop, push_cart-loop, talk-loop` |
| `ph_prop_corpse`, `ph_prop_corpse_shrouded` | liegende Leiche / eingehüllt (Pivot Mitte, liegt entlang X) |
| `ph_prop_handcart`, `ph_prop_morgue_table`, `ph_prop_workbench`, `ph_prop_dropoff_bier` | Stationen (Marker `slot_corpse` wo eine Leiche liegt) |
| `ph_prop_grave_plot_empty`, `ph_prop_grave_pit` | Pflöcke+Schnur / offenes Grab mit Erdhaufen |
| `ph_prop_wood_pile`, `ph_prop_stone_rubble`, `ph_prop_cross_wood`, `ph_prop_signpost`, `ph_prop_fallen_log`, `ph_env_bush` | Ressourcen, Grabzeichen, Kutschweg |
| `ph_item_log`, `ph_item_stone`, `ph_item_linen`, `ph_item_coin`, `ph_item_shroud` | Item-Modelle (Icons) |
- **Marker-Konventionen**: `slot_corpse` (Tisch, Bahre, Karren): lokale +X-Achse = Längsachse der Leiche → Leiche mit Identitäts-Transform an den Marker hängen. `label_board` (Wegweiser): Vorderseite des Schilds für ein `Label3D`. `light_*`: Lichtpunkte (Welt-Builder hängt OmniLights an).
- **Rig**: starre Gewichtung, Knochen `root, hips, spine, head, arm_l, arm_r, leg_l, leg_r`, Armature-Objekt heißt `Armature`. Aktionen mit Suffix `-loop` werden in Godot geloopt und ohne Suffix importiert (`&"idle"`, `&"walk"` …). Export: Armature als Wurzel, Aktionen als NLA-Spuren, `export_animation_mode='ACTIONS'`. Godot-Pfade: `<glb>/AnimationPlayer`, `<glb>/Armature/Skeleton3D`.
- Tests `test_assets_characters.gd` / `test_assets_props.gd`: alle Modelle vorhanden, Charaktere haben die Animationen, `-loop`-Animationen haben `loop_mode != NONE`, Dreiecksbudgets aus ASSET_GUIDELINES.

## 9. Tests
**Framework** (`tests/framework/test_case.gd`, Runner `tests/run_tests.gd`):
- Testdateien `tests/unit/test_*.gd`, `tests/integration/test_*.gd`, `extends TestCase`, Methoden `test_*` (dürfen `await` nutzen), Hooks `before_each/after_each` (pro Methode, eigene Instanz), `before_all/after_all` (eigene Instanz → nur globalen Zustand anfassen).
- Vor **jeder** Testmethode: `reset()` auf TimeManager, GameState, SaveManager, UIState; danach werden neue Kinder von `root` freigegeben und die aktuelle Szene entladen.
- **Fehler-Logger**: jeder `push_error`/Script-Fehler während eines Tests lässt ihn scheitern; erwartete Fehler mit `expect_errors(n)`.
- **Watchdog**: 20 s pro Test (Datei-Konstante `TIMEOUT` überschreibt), dann Exit 2.
- Exit-Codes: 0 alles grün, 1 Testfehler, 2 Runner-Fehler/Timeout/keine Tests.
- Fixtures: `tests/fixtures/items/*.tres`, `tests/fixtures/corpse_tables_fixture.tres`, `economy_config_fixture.tres` – Unit-Tests nutzen Fixtures statt Moduldaten anderer Agents.
- Aufruf: `godot --headless --path . -s res://tests/run_tests.gd [-- --filter=<text>]`.

**Integrationstest** `tests/integration/test_vertical_slice_loop.gd` (W1): `SaveManager.save_dir = "user://test_saves"`; `SaveManager.new_game()` → `world_ready`; `player.instant_actions = true`; Leiche mit festem Seed ohne Wertsachen spawnen; aufheben → Tisch (`table.interact(player)`) → `table.request_examine()` → 1 shroud + 1 wooden_cross geben → `table.request_shroud()` → `plot.interact(player)` (graben, Hände frei) → `table.request_pick_up()` → `plot.interact(player)` (bestatten) → `plot.interact(player)` (Kreuz). Erwartet: Qualität = 2+2+1+1+(Frische-Bonus) – exakt aus Record berechnet –, Münzen = Start + Bezahlung, Friedhofsqualität = Qualität, Stufe korrekt. **Roundtrip**: `a = collect_state()` → `save_game(98)` → `load_game(98)` (await) → `b = collect_state()` → `assert_eq(a, b)` (ohne `meta`).
Plus: Tag-2-Lieferung mit Wertsachen, übersprungene Lieferung bei belegter Ablage, Schlafen → Autosave.

## 10. Nicht im Slice
Dorf, Quests, Kampf, Gegner, Krypten, Auferstehung, Gebäudebau, Musik/Sound (Agent 17 inaktiv), Controller-Unterstützung, Lokalisierung.
