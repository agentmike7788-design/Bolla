class_name Phase8DayLog
extends Node
## What happened since the last day summary for its Phase-8 rows (docs/PHASE8_DESIGN.md §7.6): the visits
## (grave_viewed: who, which grave, how it looked), the wishes by state (wish_changed: new, accepted, done,
## lapsed), the tips (payment_received „Trinkgeld"), Jakob's places per task and his mistakes with their place
## (apprentice_job_done), his wage (coins_spent apprentice) or a day without it (his notice), and the night
## (robber_event, night_visit observed). Pure bookkeeping of the UI – it listens only and never changes game
## state. take() hands the values over and starts anew; a load or a new game starts anew as well.

const TIP_REASON := "Trinkgeld"
const WAGE_REASON := &"apprentice"

## [{kin_id, grave, view}]
var visits: Array[Dictionary] = []
## {state: n}
var wishes: Dictionary = {}
var tips: int = 0
## {task: n}
var jobs: Dictionary = {}
## [place]
var mistakes: PackedStringArray = []
var wage: int = -1
## robber kinds seen
var robber: Array[StringName] = []
## houses with an observed night visit
var sick: PackedStringArray = []


func _init() -> void:
	name = "Phase8DayLog"


func _ready() -> void:
	EventBus.grave_viewed.connect(_on_viewed)
	EventBus.wish_changed.connect(_on_wish)
	EventBus.payment_received.connect(_on_payment)
	EventBus.apprentice_job_done.connect(_on_job)
	EventBus.coins_spent.connect(_on_spent)
	EventBus.notification_requested.connect(_on_note)
	EventBus.robber_event.connect(_on_robber)
	EventBus.night_visit.connect(_on_night_visit)
	EventBus.game_loaded.connect(reset.unbind(1))
	EventBus.new_game_started.connect(reset)
	reset()


func _exit_tree() -> void:
	for pair: Array in [[EventBus.grave_viewed, _on_viewed], [EventBus.wish_changed, _on_wish],
			[EventBus.payment_received, _on_payment], [EventBus.apprentice_job_done, _on_job], [EventBus.coins_spent, _on_spent],
			[EventBus.notification_requested, _on_note], [EventBus.robber_event, _on_robber], [EventBus.night_visit, _on_night_visit]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func reset() -> void:
	visits.clear()
	wishes.clear()
	tips = 0
	jobs.clear()
	mistakes.clear()
	wage = -1
	robber.clear()
	sick.clear()


## {visits, wishes, tips, jakob {jobs, mistakes, wage?, tomorrow}, night {robber, sick}} and a fresh start.
func take(tree: SceneTree = null) -> Dictionary:
	var jakob := {"jobs": jobs.duplicate(), "mistakes": Array(mistakes)}
	if wage >= 0:
		jakob["wage"] = wage
	var t := tree if tree != null else (get_tree() if is_inside_tree() else null)
	var app := t.get_first_node_in_group(&"apprentice") as Apprentice if t != null else null
	if app != null and app.is_hired():
		jakob["tomorrow"] = tomorrow_text(app)
	var out := {"visits": visits.duplicate(true), "wishes": wishes.duplicate(), "tips": tips, "jakob": jakob,
			"night": {"robber": robber.duplicate(), "sick": Array(sick)}}
	reset()
	return out


## „Laub harken im Alten Hof" (the first board line) or „frei" for the next day.
static func tomorrow_text(app: Apprentice) -> String:
	if not app.works_today(TimeManager.day + 1):
		return Phase8Texts.DAY_JAKOB_OFF
	var lines := app.board_lines()
	if lines.is_empty():
		return Phase8Texts.NONE
	var first: Dictionary = lines[0]
	var where: String = Phase8Texts.AREA_IN.get(StringName(str(first.get("area", "all"))), "")
	return Phase8Texts.task_label(StringName(str(first.get("task", "")))) + (" " + where if where != "" else "")


func _on_viewed(grave_id: String, kin_id: StringName, view: StringName) -> void:
	var t := get_tree() if is_inside_tree() else null
	visits.append({"kin_id": String(kin_id), "grave": grave_id, "grave_name": Phase8Status.dead_name(t, grave_id), "view": String(view)})


func _on_wish(_wish_id: String, state: StringName) -> void:
	wishes[state] = int(wishes.get(state, 0)) + 1


func _on_payment(amount: int, reason: String) -> void:
	if reason == TIP_REASON and amount > 0:
		tips += amount


func _on_job(task_id: StringName, spot_id: String, mistake: bool) -> void:
	jobs[task_id] = int(jobs.get(task_id, 0)) + 1
	if mistake:
		mistakes.append(spot_id)


func _on_spent(amount: int, reason: StringName) -> void:
	if reason == WAGE_REASON:
		wage = maxi(wage, 0) + amount


func _on_note(text: String, _kind: StringName) -> void:
	if text == Apprentice.TEXT_UNPAID or text == Apprentice.TEXT_STAYS_HOME:
		wage = maxi(wage, 0)


func _on_robber(kind: StringName, _grave_id: String) -> void:
	if not robber.has(kind):
		robber.append(kind)


func _on_night_visit(path_id: StringName, _npc_id: StringName, phase: StringName) -> void:
	if phase != &"observed":
		return
	var data := Database.night_path(path_id) as NightPathData
	var house := String(data.house) if data != null else String(path_id)
	if not house in sick:
		sick.append(house)
