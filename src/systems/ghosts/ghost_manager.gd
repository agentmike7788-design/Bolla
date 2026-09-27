class_name GhostManager
extends Node
## Ghosts of the buried (docs/PHASE3_DESIGN.md §2.8, §3.4) – Systems/Ghosts (groups ghosts,
## saveable; save_id "ghosts", save_order 30).
## One ghost per MARKED grave from the night after its completion, visible appear_minute …
## vanish_minute (21:30 … 04:30) with a fade of fade_minutes. A pool of max_active Ghost nodes
## under container_path shows the graves nearest to the player, re-selected every
## reselect_seconds with reselect_hysteresis (no node is created or freed per switch).
## Other systems are only read through their groups: graveyard, corpse_manager, cleanliness
## (level of "dirt_<grave_id>"), decorations (ghost_bonus_at). Moods are recomputed on
## grave_state_changed, grave_quality_changed, dirt_changed and decor_changed.
## Saved: {gifts: {grave_id: day}, heard: {grave_id: day}} (+ late, see save_state). Ghost nodes, moods and the
## "said within repeat_minutes" memory are not saved.

const GROUP := &"ghosts"
const SAVEABLE_GROUP := &"saveable"
const GRAVEYARD_GROUP := &"graveyard"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const CLEANLINESS_GROUP := &"cleanliness"
const DECORATIONS_GROUP := &"decorations"
const PLOT_GROUP := &"grave_plot"
const PLAYER_GROUP := &"player"
const DEFAULT_SCENE := "res://src/entities/ghost/ghost.tscn"
const DIRT_PREFIX := "dirt_"
const COIN_ITEM := &"coin"
const FLAG_SEEN := &"ghosts_seen"
const NOTIFY_KIND := &"info"
const MINUTES_PER_DAY := 1440
## §2.8 "completed before 21:00 of the same day": a grave completed from this minute on gets
## its ghost only in the following night.
const LATE_MINUTE := 1260
## Minutes before noon still belong to the previous day's night.
const NIGHT_SPLIT_MINUTE := 720

@export var ghost_scene: PackedScene
## Decor/Ghosts
@export var container_path: NodePath
@export var save_id: String = "ghosts"
@export var save_order: int = 30

## null = Database (data/config/ghost_config.tres, data/ghosts/ghost_lines.tres,
## data/config/cleanliness_config.tres, economy_config).
var config: GhostConfig
var lines: GhostLines
var cleanliness_config: CleanlinessConfig
var economy: EconomyConfig
## Debug ("ghosts on"): ghost time regardless of the clock, fully faded in.
var forced: bool = false

## grave_id -> day of the one-time gift / of the last listening.
var _gifts: Dictionary[String, int] = {}
var _heard: Dictionary[String, int] = {}
## Graves completed at/after LATE_MINUTE (grave_id -> day); saved while still relevant.
var _late: Dictionary[String, int] = {}
## grave_id -> {total: int, text: String, mood: StringName, day: int, turn: int}
var _said: Dictionary[String, Dictionary] = {}
var _pool: Array[Ghost] = []
## grave_id -> ghost of the pool bound to it.
var _bound: Dictionary[String, Ghost] = {}
var _plots: Dictionary[String, Node3D] = {}
var _container: Node3D
var _reselect_left: float = 0.0
var _night_active: bool = false
var _moods_dirty: bool = true


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(SAVEABLE_GROUP, true)


func _ready() -> void:
	EventBus.grave_state_changed.connect(_on_mood_input)
	EventBus.grave_quality_changed.connect(_on_mood_input)
	EventBus.dirt_changed.connect(_on_mood_input)
	EventBus.decor_changed.connect(_on_decor_changed)
	EventBus.grave_completed.connect(_on_grave_completed)
	EventBus.world_ready.connect(_on_world_ready)


func _process(delta: float) -> void:
	var minute := TimeManager.get_minute_f()
	var active := forced or is_ghost_time(int(minute))
	if active != _night_active:
		_night_active = active
		EventBus.ghost_night_changed.emit(active)
		_reselect_left = 0.0
	_reselect_left -= delta
	if _reselect_left <= 0.0:
		_reselect_left = _config().reselect_seconds
		reselect()
	update_visuals(minute)


## appear_minute … vanish_minute (wraps over midnight).
func is_ghost_time(minute_of_day: int) -> bool:
	var cfg := _config()
	var m := posmod(minute_of_day, MINUTES_PER_DAY)
	var span := posmod(cfg.vanish_minute - cfg.appear_minute, MINUTES_PER_DAY)
	return posmod(m - cfg.appear_minute, MINUTES_PER_DAY) < span


## 0..1: fades in over fade_minutes from appear_minute, out over fade_minutes up to vanish_minute.
func fade_at(minute_f: float) -> float:
	var cfg := _config()
	var m := fposmod(minute_f, float(MINUTES_PER_DAY))
	var span := float(posmod(cfg.vanish_minute - cfg.appear_minute, MINUTES_PER_DAY))
	var since := fposmod(m - float(cfg.appear_minute), float(MINUTES_PER_DAY))
	if since >= span:
		return 0.0
	var edge := minf(since, span - since)
	if cfg.fade_minutes <= 0:
		return 1.0
	return clampf(edge / float(cfg.fade_minutes), 0.0, 1.0)


## MARKED graves whose ghost walks tonight (in Graveyard order).
func eligible_graves() -> PackedStringArray:
	var out := PackedStringArray()
	var graveyard := _graveyard()
	if graveyard == null:
		return out
	var night := night_index(TimeManager.day, TimeManager.minute_of_day)
	for grave: GraveRecord in graveyard.graves():
		if grave.state == GraveRecord.State.MARKED and night > _completion_night(grave):
			out.append(grave.id)
	return out


## &"restless" / &"calm" / &"content"; &"" for a grave without a ghost (not MARKED / unknown).
func mood_of(grave_id: String) -> StringName:
	var info := mood_info(grave_id)
	return info.get("mood", &"")


## {score, mood, reason, quality, dirt_level, decor_bonus} – {} without a MARKED grave.
## (Also for the debug command "ghost mood" and the cemetery overview.)
func mood_info(grave_id: String) -> Dictionary:
	var graveyard := _graveyard()
	var grave := graveyard.get_grave(grave_id) if graveyard != null else null
	if grave == null or grave.state != GraveRecord.State.MARKED:
		return {}
	var corpse := _corpse(grave.corpse_id)
	var dirt := _dirt_level(grave_id)
	var bonus := mini(_decor_bonus(grave_id), _config().decor_bonus_max)
	var value := GhostMood.score(grave.quality, dirt, bonus, _cleanliness_config(), _config())
	return {
		"score": value,
		"mood": GhostMood.mood(value, _config()),
		"reason": GhostMood.main_reason(grave, corpse, dirt, bonus, _economy()),
		"quality": grave.quality,
		"dirt_level": dirt,
		"decor_bonus": bonus,
	}


func active_ghosts() -> Array[Ghost]:
	var out: Array[Ghost] = []
	for ghost: Ghost in _bound.values():
		out.append(ghost)
	return out


## Text of the ghost; the one-time gift of a content ghost; ghost_spoke; flag ghosts_seen.
## Within repeat_minutes the same ghost repeats its line; otherwise the line is chosen
## deterministically from hash(grave_id) + day (+ how often it spoke today).
func listen(grave_id: String, player: Player) -> String:
	var info := mood_info(grave_id)
	if info.is_empty():
		return ""
	var mood: StringName = info.mood
	var now := TimeManager.total_minutes()
	var day := TimeManager.day
	var text := ""
	var last: Dictionary = _said.get(grave_id, {})
	if not last.is_empty() and now - int(last.total) < _config().repeat_minutes and last.mood == mood:
		text = last.text
	else:
		var turn := int(last.turn) + 1 if not last.is_empty() and int(last.day) == day else 0
		var corpse := _corpse(_graveyard().get_grave(grave_id).corpse_id)
		var traits: Array[StringName] = corpse.traits.duplicate() if corpse != null else []
		text = GhostMood.pick_line(_lines(), mood, info.reason, traits, line_seed(grave_id, day) + turn)
		_said[grave_id] = {"total": now, "text": text, "mood": mood, "day": day, "turn": turn}
	if mood == GhostMood.CONTENT and not _gifts.has(grave_id):
		_give_gift(grave_id, player, day)
	_heard[grave_id] = day
	GameState.set_flag(FLAG_SEEN, true)
	EventBus.ghost_spoke.emit(grave_id, mood, text)
	return text


## {gifts, heard} (+ "late": {grave_id: day} while a grave finished after 21:00 is still
## waiting for its first night – QA-04: otherwise a load lets its ghost walk that same night).
func save_state() -> Dictionary:
	var out := {"gifts": _gifts.duplicate(), "heard": _heard.duplicate()}
	var late := {}
	for id: String in _late:
		if _late[id] >= TimeManager.day - 1:
			late[id] = _late[id]
	if not late.is_empty():
		out["late"] = late
	return out


func load_state(data: Dictionary) -> void:
	_gifts = _read_days(data.get("gifts", {}))
	_heard = _read_days(data.get("heard", {}))
	_late = _read_days(data.get("late", {}))
	_said.clear()
	_plots.clear()
	_release_all()
	_moods_dirty = true
	_reselect_left = 0.0


# --- helpers (public, not part of the contract) ------------------------------------------

## Night a (day, minute) belongs to: the night that begins on the evening of that day.
static func night_index(day: int, minute_of_day: int) -> int:
	return day if minute_of_day >= NIGHT_SPLIT_MINUTE else day - 1


## Deterministic line seed of a grave on a day.
static func line_seed(grave_id: String, day: int) -> int:
	return absi(hash(grave_id)) + day


## The max_active ids nearest by distance; ids in `current` count reselect_hysteresis closer,
## so a ghost is only replaced by a clearly nearer one. Ties by id.
static func select_nearest(distances: Dictionary, current: PackedStringArray, max_active: int, hysteresis: float) -> PackedStringArray:
	var ranked: Array = []
	for id: Variant in distances:
		var d := float(distances[id]) - (hysteresis if current.has(String(id)) else 0.0)
		ranked.append([d, String(id)])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out := PackedStringArray()
	for i: int in mini(max_active, ranked.size()):
		out.append(ranked[i][1])
	return out


func gift_given(grave_id: String) -> bool:
	return _gifts.has(grave_id)


func was_heard(grave_id: String) -> bool:
	return _heard.has(grave_id)


## Heard graves by mood ({content: n, calm: n, restless: n}) – cemetery overview / summary.
func heard_moods() -> Dictionary:
	var out := {GhostMood.CONTENT: 0, GhostMood.CALM: 0, GhostMood.RESTLESS: 0}
	for id: String in _heard:
		var m := mood_of(id)
		if out.has(m):
			out[m] += 1
	return out


func is_night_active() -> bool:
	return _night_active


## Binds the pool to the nearest eligible graves (outside ghost time: releases all).
func reselect() -> void:
	if not (forced or is_ghost_time(TimeManager.minute_of_day)):
		_release_all()
		return
	var distances := {}
	var origin := _player_position()
	for id: String in eligible_graves():
		var plot := _plot(id)
		if plot != null:
			var p := plot.global_position
			distances[id] = Vector2(p.x - origin.x, p.z - origin.z).length()
	var cfg := _config()
	var current := PackedStringArray(_bound.keys())
	var chosen := select_nearest(distances, current, cfg.max_active, cfg.reselect_hysteresis)
	for id: String in current:
		if not chosen.has(id):
			var ghost: Ghost = _bound[id]
			_bound.erase(id)
			_release(ghost)
	for id: String in chosen:
		if not _bound.has(id):
			_bind(id)
	if _moods_dirty:
		_moods_dirty = false
		for id: String in _bound:
			_bound[id].set_mood(mood_of(id))


## Fade of every bound ghost for `minute_f`; hidden while the player is inside the hut.
func update_visuals(minute_f: float) -> void:
	if _moods_dirty and not _bound.is_empty():
		_moods_dirty = false
		for id: String in _bound:
			_bound[id].set_mood(mood_of(id))
	var alpha := 1.0 if forced else fade_at(minute_f)
	var player := _player()
	var inside := player != null and player.in_interior
	if _container != null:
		_container.visible = not inside
	for ghost: Ghost in _bound.values():
		ghost.set_fade(0.0 if inside else alpha)


# --- internals ---------------------------------------------------------------------------

func _bind(grave_id: String) -> void:
	var ghost := _free_ghost()
	var plot := _plot(grave_id)
	if ghost == null or plot == null:
		return
	var grave := _graveyard().get_grave(grave_id)
	var corpse := _corpse(grave.corpse_id) if grave != null else null
	ghost.bind(grave_id, plot.global_transform, corpse.display_name if corpse != null else "")
	ghost.set_mood(mood_of(grave_id))
	ghost.set_fade(0.0)
	_bound[grave_id] = ghost


func _release(ghost: Ghost) -> void:
	ghost.set_fade(0.0)
	ghost.grave_id = ""


func _release_all() -> void:
	for ghost: Ghost in _bound.values():
		_release(ghost)
	_bound.clear()


func _free_ghost() -> Ghost:
	_ensure_pool()
	for ghost: Ghost in _pool:
		if ghost.grave_id == "" and not _bound.values().has(ghost):
			return ghost
	return null


func _ensure_pool() -> void:
	if _pool.size() >= _config().max_active or not is_inside_tree():
		return
	if _container == null:
		_container = get_node_or_null(container_path) as Node3D if not container_path.is_empty() else null
		if _container == null:
			_container = Node3D.new()
			_container.name = "GhostPool"
			add_child(_container)
	var scene := ghost_scene if ghost_scene != null else load(DEFAULT_SCENE) as PackedScene
	while _pool.size() < _config().max_active:
		var ghost := scene.instantiate() as Ghost
		ghost.name = "Ghost%d" % _pool.size()
		ghost.manager = self
		ghost.config = _config()
		_container.add_child(ghost)
		ghost.set_fade(0.0)
		_pool.append(ghost)


func _give_gift(grave_id: String, player: Player, day: int) -> void:
	var inv: Inventory = player.inventory if player != null else null
	var coins := _config().gift_coins
	if inv == null or coins <= 0 or not inv.can_add(COIN_ITEM, coins):
		return
	inv.add_item(COIN_ITEM, coins)
	_gifts[grave_id] = day
	var text := _lines().gift if _lines() != null else ""
	EventBus.payment_received.emit(coins, text)
	if text != "":
		EventBus.notification_requested.emit(text, NOTIFY_KIND)


## Night in which the grave was completed – its ghost walks from the next night on.
func _completion_night(grave: GraveRecord) -> int:
	if grave.completed_day <= 0:
		return -(1 << 30)
	if _late.get(grave.id, -1) == grave.completed_day:
		return grave.completed_day
	return grave.completed_day - 1


func _on_grave_completed(grave_id: String, _corpse_id: String, _quality: int, _breakdown: Array) -> void:
	if TimeManager.minute_of_day >= LATE_MINUTE:
		_late[grave_id] = TimeManager.day
	_moods_dirty = true


func _on_mood_input(_id: String, _value: int) -> void:
	_moods_dirty = true


func _on_decor_changed(_uid: String, _decor_id: StringName, _placed: bool) -> void:
	_moods_dirty = true


func _on_world_ready(world: Node) -> void:
	if world != null and world.is_ancestor_of(self):
		_plots.clear()
		_moods_dirty = true
		_reselect_left = 0.0


func _plot(grave_id: String) -> Node3D:
	var cached: Node3D = _plots.get(grave_id)
	if is_instance_valid(cached):
		return cached
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(PLOT_GROUP):
		var id: Variant = node.get("grave_id")
		if node is Node3D and (id is String or id is StringName):
			_plots[String(id)] = node as Node3D
	return _plots.get(grave_id)


func _dirt_level(grave_id: String) -> int:
	var clean := _first(CLEANLINESS_GROUP)
	if clean == null or not clean.has_method(&"level"):
		return 0
	return int(clean.call(&"level", DIRT_PREFIX + grave_id))


func _decor_bonus(grave_id: String) -> int:
	var decor := _first(DECORATIONS_GROUP)
	var plot := _plot(grave_id)
	if decor == null or plot == null or not decor.has_method(&"ghost_bonus_at"):
		return 0
	var p := plot.global_position
	return int(decor.call(&"ghost_bonus_at", Vector2(p.x, p.z)))


func _corpse(corpse_id: String) -> CorpseRecord:
	var manager := _first(CORPSE_MANAGER_GROUP) as CorpseManager
	return manager.get_record(corpse_id) if manager != null and corpse_id != "" else null


func _graveyard() -> Graveyard:
	return _first(GRAVEYARD_GROUP) as Graveyard


func _player() -> Player:
	return _first(PLAYER_GROUP) as Player


func _player_position() -> Vector3:
	var player := _player()
	return player.global_position if player != null and player.is_inside_tree() else Vector3.ZERO


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _read_days(raw: Variant) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	if raw is Dictionary:
		for key: Variant in raw:
			var v: Variant = raw[key]
			if (key is String or key is StringName) and (v is int or v is float):
				out[String(key)] = roundi(float(v))
			else:
				push_warning("[GhostManager] invalid saved entry %s: %s" % [str(key), str(v)])
	elif raw != null:
		push_warning("[GhostManager] invalid saved ghost state")
	return out


func _config() -> GhostConfig:
	if config == null:
		config = Database.config(&"ghost_config") as GhostConfig
		if config == null:
			config = GhostConfig.new()
	return config


func _lines() -> GhostLines:
	if lines == null:
		lines = Database.ghost_lines() as GhostLines
	return lines


func _cleanliness_config() -> CleanlinessConfig:
	if cleanliness_config == null:
		cleanliness_config = Database.config(&"cleanliness_config") as CleanlinessConfig
		if cleanliness_config == null:
			cleanliness_config = CleanlinessConfig.new()
	return cleanliness_config


func _economy() -> EconomyConfig:
	if economy == null:
		economy = EconomyConfig.resolve()
	return economy
