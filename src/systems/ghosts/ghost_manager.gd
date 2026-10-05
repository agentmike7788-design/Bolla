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
## Phase 6 (docs/PHASE6_DESIGN.md §2.4): the devotion of a grave (ChapelRites.devotion_level, group
## chapel_rites) adds ChapelRules.devotion_bonus to the mood (capped for robbed souls). Once per grave
## the ghost speaks a by_service line (corpse with a funeral service) and once per devotion level a
## by_devotion line (&"robbed" pool for robbed souls) – saved as service_heard / devotion_heard.

const GROUP := &"ghosts"
const SAVEABLE_GROUP := &"saveable"
const GRAVEYARD_GROUP := &"graveyard"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const CLEANLINESS_GROUP := &"cleanliness"
const DECORATIONS_GROUP := &"decorations"
const PIETY_GROUP := &"piety"
const PLOT_GROUP := &"grave_plot"
const PLAYER_GROUP := &"player"
const STONEMASONRY_GROUP := &"stonemasonry"
const CHAPEL_GROUP := &"chapel_rites"
const DEVOTION_DEFAULT := &"default"
const DEVOTION_ROBBED := &"robbed"
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
# Phase 8 (docs/PHASE8_DESIGN.md §2.3, §2.7.2, §2.11, §3.4; P2): the care bonus of GraveCare, the prayer of
# Lenz' favour (Friendship.prayer_bonus, P4 – a robbed soul stays at most calm like with a devotion), the
# care pools of the lines and the early window of the night of the lights (a pale shimmer, display only).
const GRAVE_CARE_GROUP := &"grave_care"
const FRIENDSHIP_GROUP := &"friendship"
const VISITORS_GROUP := &"visitors"
## GameState flag (int day) of the night of the lights (FestivalData fest_lights.day_flag, P4).
const LIGHTS_DAY_FLAG := &"fest_lights_day"
const EARLY_ALPHA := 0.35

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
## Phase 7: organ moods (null = data/config/anatomy_config.tres).
var anatomy: AnatomyConfig
## Debug ("ghosts on"): ghost time regardless of the clock, fully faded in.
var forced: bool = false

## grave_id -> day of the one-time gift / of the last listening.
var _gifts: Dictionary[String, int] = {}
var _heard: Dictionary[String, int] = {}
## Graves completed at/after LATE_MINUTE (grave_id -> day); saved while still relevant.
var _late: Dictionary[String, int] = {}
## Phase 6: grave_id -> day its by_service line was spoken; grave_id -> devotion level whose line was spoken.
var _service_heard: Dictionary[String, int] = {}
var _devotion_heard: Dictionary[String, int] = {}
## Phase 7: grave_id -> number of returned organs whose by_returned line was spoken.
var _returned_heard: Dictionary[String, int] = {}
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
## Night in which the "no gift" line was shown (once per night, not saved).
var _no_gift_night: int = -(1 << 30)
## Phase 8: the early window of the night of the lights {day, from, minutes, graves} (not saved – display
## only; Festivals sets it again).
var _early: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(SAVEABLE_GROUP, true)


func _ready() -> void:
	EventBus.grave_state_changed.connect(_on_mood_input)
	EventBus.grave_quality_changed.connect(_on_mood_input)
	EventBus.dirt_changed.connect(_on_mood_input)
	EventBus.decor_changed.connect(_on_decor_changed)
	EventBus.grave_completed.connect(_on_grave_completed)
	EventBus.devotion_held.connect(_on_mood_input)
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.grave_care_changed.connect(_on_care_changed)


func _process(delta: float) -> void:
	var minute := TimeManager.get_minute_f()
	var active := forced or is_ghost_time(int(minute)) or early_active(int(minute))
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


## {score, mood, reason, quality, dirt_level, decor_bonus, devotion} – {} without a MARKED grave.
## devotion = the (capped) bonus of the grave's devotion (Phase 6), included in score.
## (Also for the debug command "ghost mood" and the cemetery overview.)
func mood_info(grave_id: String) -> Dictionary:
	var graveyard := _graveyard()
	var grave := graveyard.get_grave(grave_id) if graveyard != null else null
	if grave == null or grave.state != GraveRecord.State.MARKED:
		return {}
	var corpse := _corpse(grave.corpse_id)
	var dirt := _dirt_level(grave_id)
	var bonus := mini(_decor_bonus(grave_id), _config().decor_bonus_max)
	var robbed := GhostMood.robbed_count(corpse)
	# Phase 7 (§2.11): the robbed penalty per kind (hair / teeth robbed_mood, organs their own mood);
	# for hair / teeth alone identical to score(..., robbed).
	var base := GhostMood.score(grave.quality, dirt, bonus, _cleanliness_config(), _config(), 0) \
			+ GhostMood.robbed_penalty(corpse, _config(), anatomy)
	var devotion := _devotion_bonus(grave_id, robbed, base)
	var value := base + maxi(devotion, 0)
	# Phase 8: care (flowers / candle ≤ care_cap, disturbed −3) and Lenz' prayer; the positive part keeps a
	# robbed soul at most calm (devotion_robbed_cap, like the devotion).
	var care := _care_bonus(grave_id)
	var prayer := _prayer_bonus(grave_id)
	var plus := maxi(care, 0) + prayer
	if robbed > 0:
		plus = mini(plus, maxi(_config().devotion_robbed_cap - value, 0))
	value += plus + mini(care, 0)
	return {
		"score": value,
		"mood": GhostMood.mood(value, _config()),
		"reason": GhostMood.main_reason(grave, corpse, dirt, bonus, _economy()),
		"quality": grave.quality,
		"dirt_level": dirt,
		"decor_bonus": bonus,
		"devotion": devotion,
		"care": care,
		"prayer": prayer,
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
		var story: StringName = corpse.story_id if corpse != null else &""
		var harvested: Array[StringName] = corpse.harvested.duplicate() if corpse != null else []
		var seed := line_seed(grave_id, day) + turn
		var key := _care_key(grave_id, corpse)
		if key == GhostMood.CARE_DISTURBED:
			text = GhostMood.pick_care_line(_lines(), key, seed)
		if text == "":
			text = _returned_line(grave_id, corpse, line_seed(grave_id, day) + turn)
		if text == "":
			text = _chapel_line(grave_id, corpse, line_seed(grave_id, day) + turn)
		if text == "":
			text = _design_line(grave_id, mood, corpse, line_seed(grave_id, day) + turn)
		if text == "" and key != GhostMood.CARE_ROBBED:
			text = GhostMood.pick_care_line(_lines(), key, seed)
		if text == "":
			text = GhostMood.pick_line(_lines(), mood, info.reason, traits, line_seed(grave_id, day) + turn, story, piety_tier(), harvested)
		_said[grave_id] = {"total": now, "text": text, "mood": mood, "day": day, "turn": turn}
	if mood == GhostMood.CONTENT and not _gifts.has(grave_id):
		_give_gift(grave_id, player, day)
	_heard[grave_id] = day
	GameState.set_flag(FLAG_SEEN, true)
	EventBus.ghost_spoke.emit(grave_id, mood, text)
	return text


## Phase 5 §2.5: the by_design line of a content / calm ghost whose designed stone is new (once
## per grave – Stonemasonry remembers it and saves it); "" = none.
func _design_line(grave_id: String, mood: StringName, corpse: CorpseRecord, seed: int) -> String:
	if mood != GhostMood.CONTENT and mood != GhostMood.CALM:
		return ""
	var masonry := get_tree().get_first_node_in_group(STONEMASONRY_GROUP) if is_inside_tree() else null
	if masonry == null or not masonry.has_method(&"design_line_pending") or not masonry.call(&"design_line_pending", grave_id):
		return ""
	var grave := _graveyard().get_grave(grave_id)
	var text := GhostMood.pick_design_line(_lines(), GhostMood.design_key(grave.design, corpse), seed)
	if text != "":
		masonry.call(&"mark_design_heard", grave_id)
	return text


## Phase 7 §2.6.2, §2.11: the first night after a specimen went back into the grave, one by_returned
## line (once per returned organ – saved as returned_heard); "" = none.
func _returned_line(grave_id: String, corpse: CorpseRecord, seed: int) -> String:
	var l := _lines()
	if l == null or corpse == null or l.by_returned.is_empty():
		return ""
	if corpse.returned.size() <= int(_returned_heard.get(grave_id, 0)):
		return ""
	_returned_heard[grave_id] = corpse.returned.size()
	return l.by_returned[posmod(seed, l.by_returned.size())]


## Phase 6 §2.4: the by_service line once per grave of a corpse with a funeral service, else the
## by_devotion line once per new devotion level (robbed pool for a robbed soul, else default); "" = none.
## Any mood – the rite was for this one.
func _chapel_line(grave_id: String, corpse: CorpseRecord, seed: int) -> String:
	var l := _lines()
	if l == null:
		return ""
	if corpse != null and corpse.service_held and not _service_heard.has(grave_id) and not l.by_service.is_empty():
		_service_heard[grave_id] = TimeManager.day
		return l.by_service[posmod(seed, l.by_service.size())]
	var held := _devotion_level(grave_id)
	if held <= 0 or held <= int(_devotion_heard.get(grave_id, 0)):
		return ""
	var key := DEVOTION_ROBBED if GhostMood.robbed_count(corpse) > 0 else DEVOTION_DEFAULT
	var pool: PackedStringArray = l.by_devotion.get(key, PackedStringArray())
	if pool.is_empty():
		pool = l.by_devotion.get(DEVOTION_DEFAULT, PackedStringArray())
	if pool.is_empty():
		return ""
	_devotion_heard[grave_id] = held
	return pool[posmod(seed, pool.size())]


## Chapel level of the grave's devotion (0 without ChapelRites).
func _devotion_level(grave_id: String) -> int:
	var chapel := _first(CHAPEL_GROUP)
	if chapel == null or not chapel.has_method(&"devotion_level"):
		return 0
	return int(chapel.call(&"devotion_level", grave_id))


## ChapelRules.devotion_bonus of the grave's devotion for `base` (its score without it).
func _devotion_bonus(grave_id: String, robbed: int, base: int) -> int:
	var held := _devotion_level(grave_id)
	if held <= 0:
		return 0
	var chapel := _first(CHAPEL_GROUP)
	var chapel_cfg: ChapelConfig = null
	if chapel != null and chapel.has_method(&"get_config"):
		chapel_cfg = chapel.call(&"get_config") as ChapelConfig
	return ChapelRules.devotion_bonus(held, robbed, base, chapel_cfg)


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
	if not _service_heard.is_empty():
		out["service_heard"] = _service_heard.duplicate()
	if not _devotion_heard.is_empty():
		out["devotion_heard"] = _devotion_heard.duplicate()
	if not _returned_heard.is_empty():
		out["returned_heard"] = _returned_heard.duplicate()
	return out


func load_state(data: Dictionary) -> void:
	_gifts = _read_days(data.get("gifts", {}))
	_heard = _read_days(data.get("heard", {}))
	_late = _read_days(data.get("late", {}))
	_service_heard = _read_days(data.get("service_heard", {}))
	_devotion_heard = _read_days(data.get("devotion_heard", {}))
	_returned_heard = _read_days(data.get("returned_heard", {}))
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


## Phase 8 (docs/PHASE8_DESIGN.md §2.7.2, §3.4): on the night of the lights the ghosts of `graves` show
## today from `from_minute` for `minutes` as a pale shimmer (alpha EARLY_ALPHA, display only – no gift, no
## mood change). minutes ≤ 0 or no graves = off. Not saved (Festivals sets it again).
func set_early_window(from_minute: int, minutes: int, graves: PackedStringArray) -> void:
	if minutes <= 0 or graves.is_empty():
		_early = {}
	else:
		_early = {"day": TimeManager.day, "from": posmod(from_minute, MINUTES_PER_DAY), "minutes": minutes, "graves": graves.duplicate()}
	_reselect_left = 0.0


## The early window of the night of the lights is running at `minute_of_day` (today).
func early_active(minute_of_day: int) -> bool:
	if _early.is_empty() or int(_early.day) != TimeManager.day:
		return false
	var since := minute_of_day - int(_early.from)
	return since >= 0 and since < int(_early.minutes)


## The graves of the early window (empty = none).
func early_graves() -> PackedStringArray:
	var graves: Variant = _early.get("graves", PackedStringArray())
	return (graves as PackedStringArray).duplicate() if graves is PackedStringArray else PackedStringArray()


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


## Coins of a ghost's gift: Piety.gift_coins() (§2.7: 0 / 2 / 2 / 2 / 3 by tier); without a
## Piety node GhostConfig.gift_coins.
func gift_amount() -> int:
	var piety := _first(PIETY_GROUP)
	if piety != null and piety.has_method(&"gift_coins"):
		return maxi(0, int(piety.call(&"gift_coins")))
	return _config().gift_coins


## Current Pietät tier (&"" without a Piety node).
func piety_tier() -> StringName:
	var piety := _first(PIETY_GROUP)
	if piety != null and piety.has_method(&"tier"):
		return StringName(piety.call(&"tier"))
	return &""


## Binds the pool to the nearest eligible graves (outside ghost time: releases all).
func reselect() -> void:
	var early := not forced and not is_ghost_time(TimeManager.minute_of_day) and early_active(TimeManager.minute_of_day)
	if not (forced or early or is_ghost_time(TimeManager.minute_of_day)):
		_release_all()
		return
	var distances := {}
	var origin := _player_position()
	var candidates := eligible_graves()
	if early:
		var graves := early_graves()
		var keep := PackedStringArray()
		for id: String in candidates:
			if graves.has(id):
				keep.append(id)
		candidates = keep
	for id: String in candidates:
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
	if not forced and alpha <= 0.0 and early_active(int(minute_f)):
		alpha = EARLY_ALPHA
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
	var coins := gift_amount()
	if coins <= 0:
		_note_no_gift()
		return
	if inv == null or not inv.can_add(COIN_ITEM, coins):
		return
	inv.add_item(COIN_ITEM, coins)
	_gifts[grave_id] = day
	var text := gift_text(coins)
	EventBus.payment_received.emit(coins, text)
	if text != "":
		EventBus.notification_requested.emit(text, NOTIFY_KIND)


## Gift line for `coins` (GhostLines.gift_by_coins, else GhostLines.gift).
func gift_text(coins: int) -> String:
	var l := _lines()
	if l == null:
		return ""
	return l.gift_by_coins.get(coins, l.gift)


## "Die Geister deuten nicht mehr ins Moos." once per night; the grave keeps its gift for later.
func _note_no_gift() -> void:
	var night := night_index(TimeManager.day, TimeManager.minute_of_day)
	if night == _no_gift_night:
		return
	_no_gift_night = night
	var text := _lines().no_gift if _lines() != null else ""
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


func _on_care_changed(_grave_id: String, _kind: StringName, _active: bool) -> void:
	_moods_dirty = true


## Phase 8: GraveCare.care_bonus (0 without GraveCare).
func _care_bonus(grave_id: String) -> int:
	var care := _first(GRAVE_CARE_GROUP)
	if care == null or not care.has_method(&"care_bonus"):
		return 0
	return int(care.call(&"care_bonus", grave_id))


## Phase 8: Lenz' prayer on this grave (Friendship.prayer_bonus, P4; 0 without it).
func _prayer_bonus(grave_id: String) -> int:
	var friendship := _first(FRIENDSHIP_GROUP)
	if friendship == null or not friendship.has_method(&"prayer_bonus"):
		return 0
	return maxi(0, int(friendship.call(&"prayer_bonus", grave_id)))


## Phase 8 §2.11: the care pool of tonight's line (GhostMood.care_key).
func _care_key(grave_id: String, corpse: CorpseRecord) -> StringName:
	var care := _first(GRAVE_CARE_GROUP) as GraveCare
	var night := night_index(TimeManager.day, TimeManager.minute_of_day)
	var disturbed := care != null and care.is_disturbed(grave_id)
	var burning := care != null and care.candle_lit(grave_id)
	var candle := burning or (care != null and care.lit_last_night(grave_id))
	var flowers := care != null and (care.flowers_state(grave_id) == GraveCare.FLOWERS_FRESH or care.bouquet_fresh(grave_id))
	var lights_day: Variant = GameState.get_flag(LIGHTS_DAY_FLAG, -1)
	var lights := burning and (lights_day is int or lights_day is float) and int(lights_day) == night
	var visitors := _first(VISITORS_GROUP)
	var visited := visitors != null and visitors.has_method(&"visited_on") and bool(visitors.call(&"visited_on", grave_id, night))
	return GhostMood.care_key(disturbed, GhostMood.robbed_count(corpse) > 0, lights, visited, candle, flowers)


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
