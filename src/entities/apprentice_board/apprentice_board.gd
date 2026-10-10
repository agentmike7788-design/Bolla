class_name ApprenticeBoard
extends Node3D
## The chalk board at the hut wall (docs/PHASE8_DESIGN.md §2.5.3, §3.1, §3.4, §4.3 A1, §7.1): „[E] Arbeitsliste
## für Jakob" → panel &"apprentice_board" with {apprentice, box, board, lines, levels, jobs, practice_jobs,
## coins, wage, unpaid, debt, missing, estimate}; before he is hired the prompt only reads „Eine leere
## Kreidetafel." (no interaction). The panel writes through Apprentice.set_board_lines and
## ApprenticeBox.deposit.

const PANEL := &"apprentice_board"
const PROMPT := "[E] Arbeitsliste für Jakob"
const TEXT_EMPTY := "Eine leere Kreidetafel."
const APPRENTICE_GROUP := &"apprentice"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	var a := _apprentice()
	return player != null and not player.is_busy() and a != null and a.is_hired()


func get_interaction_prompt(_player: Player) -> String:
	var a := _apprentice()
	return PROMPT if a != null and a.is_hired() else TEXT_EMPTY


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	EventBus.ui_panel_requested.emit(PANEL, context())


## The panel context: the systems and the values the board shows (§7.1).
func context() -> Dictionary:
	var a := _apprentice()
	var box := get_tree().get_first_node_in_group(ApprenticeBox.GROUP) as ApprenticeBox if is_inside_tree() else null
	var levels := {}
	var jobs := {}
	if a != null:
		for task: StringName in Apprentice.TASKS:
			levels[String(task)] = a.level(task)
			jobs[String(task)] = a.jobs(task)
	var cfg := a.config if a != null and a.config != null else Database.config(&"apprentice_config") as ApprenticeConfig
	if cfg == null:
		cfg = ApprenticeConfig.new()
	return {"apprentice": a, "box": box, "board": self, "lines": a.board_lines() if a != null else [], "levels": levels,
			"jobs": jobs, "practice_jobs": cfg.practice_jobs, "coins": box.coins if box != null else 0, "wage": cfg.wage,
			"unpaid": a.unpaid_days() if a != null else 0, "debt": a.debt() if a != null else 0,
			"missing": a.missing_items() if a != null else [], "estimate": estimate(a.today_plan() if a != null else [])}


## Places per task of a plan, in order of first appearance: [{task, count, area}] (the „≈ 12 Laubstellen,
## dann Unkraut im Lindenacker" line).
static func estimate(plan: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index := {}
	for e: Dictionary in plan:
		var task := StringName(str(e.get("task", "")))
		if not task in Apprentice.TASKS:
			continue
		if not index.has(task):
			index[task] = out.size()
			out.append({"task": String(task), "count": 0})
		out[index[task]].count = int(out[index[task]].count) + 1
	return out


func _apprentice() -> Apprentice:
	return get_tree().get_first_node_in_group(APPRENTICE_GROUP) as Apprentice if is_inside_tree() else null
