class_name Apprentice
extends Node
## STUB (P3) – Systems/Apprentice (docs/PHASE8_DESIGN.md §2.5, §3.1, §3.3, §3.4, §5.1), groups
## &"apprentice", &"saveable": Jakob Wackernagel – hired through Rosine step 1, the chalk board (≤ 3
## lines), the day plan at 08:25 (ApprenticePlanner, saved with its progress), the visible work with the
## tool in his hand (runtime schedule of npc_apprentice), the effect at the end of each place
## (CleanlinessManager.tend_by, GraveCare.water / light), teaching (show once → Angelernt, 12 places →
## Geübt), mistakes, praise / scolding, morale, the wage from the ApprenticeBox at 15:30.
## Never: corpses, graves, stones, stations, buildings, the crypt, the night (§2.5.6).
## W0: is_hired / level / jobs / board_lines / morale / unpaid_days answer from load_state (§5.1 {"hired",
## "levels", "jobs", "board", "morale", "unpaid"}); everything else is inert.
## W1 (P3) fills the bodies; the signatures are the contract.

const GROUP := &"apprentice"
const TASKS: Array[StringName] = [&"rake", &"weed", &"water", &"candle"]
const LEVEL_UNTRAINED := 0
const LEVEL_TAUGHT := 1
const LEVEL_PRACTISED := 2
const AREAS: Array[StringName] = [&"yard", &"east", &"north", &"elder", &"linden", &"all", &"wished"]
const TEXT_NOT_SHOWN := "Das hast du mir noch nicht gezeigt."

@export var save_id: String = "apprentice"
@export var save_order: int = 73

## Rules; null = data/config/apprentice_config.tres (resolved lazily).
var config: ApprenticeConfig

## W0 stub store (P3 may rename it – the fixtures use load_state only).
var _hired: bool = false
var _levels: Dictionary[StringName, int] = {}
var _jobs: Dictionary[StringName, int] = {}
var _board: Array[Dictionary] = []
var _morale: int = 3
var _unpaid: int = 0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func is_hired() -> bool:
	return _hired


## Rosine step 1: flag apprentice_hired, apprentice_hired event.
func hire() -> void:
	pass


## 0 Ungelernt · 1 Angelernt · 2 Geübt.
func level(task_id: StringName) -> int:
	return clampi(int(_levels.get(task_id, 0)), LEVEL_UNTRAINED, LEVEL_PRACTISED)


## Places done of this task (practice).
func jobs(task_id: StringName) -> int:
	return int(_jobs.get(task_id, 0))


## [{task, area}].
func board_lines() -> Array[Dictionary]:
	return _board.duplicate(true)


func set_board_lines(_lines: Array[Dictionary]) -> void:
	pass


func teach_block_reason(_task_id: StringName, _player: Player) -> String:
	return "-"


## Jakob comes within 2 m and watches.
func start_teach(_task_id: StringName) -> void:
	pass


## A finished player action (leaves / weeds / water / candle) → Angelernt when he watched ≤ 4 m.
func note_player_job(_task_kind: StringName, _pos: Vector3) -> void:
	pass


## Once per day: morale +1.
func praise() -> bool:
	return false


## After a mistake, once per day: morale −1, mistakes × 0.5 tomorrow, Rosine −1 (jakob_scolded).
func scold() -> bool:
	return false


## 0…5.
func morale() -> int:
	return _morale


func unpaid_days() -> int:
	return _unpaid


## 15:30 from ApprenticeBox.coins.
func pay_wage() -> bool:
	return false


## From the board + the state at start_minute, saved with the progress.
func today_plan() -> Array[Dictionary]:
	return []


## The end of a place → the effect, apprentice_job_done; the Npc runtime schedule.
func apply_minute(_day: int, _minute: int) -> void:
	pass


## {hired, hire_day, levels, jobs, teach, board, plan_day, plan, progress, morale, unpaid, praised_day,
## scolded_day, mistakes_today} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_hired = typeof(data.get("hired")) == TYPE_BOOL and bool(data.get("hired"))
	_levels.clear()
	var levels: Variant = data.get("levels", {})
	if levels is Dictionary:
		for key: Variant in levels:
			_levels[StringName(str(key))] = int(levels[key])
	_jobs.clear()
	var jobs_done: Variant = data.get("jobs", {})
	if jobs_done is Dictionary:
		for key: Variant in jobs_done:
			_jobs[StringName(str(key))] = int(jobs_done[key])
	_board.clear()
	var board: Variant = data.get("board", [])
	if board is Array:
		for line: Variant in board:
			if line is Dictionary:
				_board.append((line as Dictionary).duplicate(true))
	var m: Variant = data.get("morale", 3)
	_morale = int(m) if m is int or m is float else 3
	var u: Variant = data.get("unpaid", 0)
	_unpaid = int(u) if u is int or u is float else 0
