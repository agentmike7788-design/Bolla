class_name ApprenticeBoardPanel
extends UIPanel
## &"apprentice_board" – Jakob's work list on the chalk board at the hut (docs/PHASE8_DESIGN.md §2.5.3, §7.1):
## context ApprenticeBoard.context() {apprentice, box, board, lines, levels, …}; "apprentice" / "box" may be
## left out (the nodes of the groups are used). Chalk grey on slate in a wooden frame:
## - top „Jakob – Arbeitsliste" and how he is today („Jakob ist eifrig."),
## - three lines, each a choice of task (only what he was shown; the others grey, „noch nicht gezeigt") and of
##   the area (click cycles Alter Hof → … → überall → Gräber mit Wunsch),
## - right his levels as chalk strokes (|, ||) per task with „noch 4 Stellen bis Geübt",
## - below the wage tin „9 Münzen (3 Tage)" with „Münzen einlegen (3)" and its state („bezahlt bis morgen" /
##   „schuldet 6"), the estimated work from the planner („≈ 12 Laubstellen im Alten Hof, dann …") and what is
##   missing in his box,
## - „Zeig mir, was du heute geschafft hast" swaps the lines for the list of today's finished places.
## Every value is read from Apprentice / ApprenticeBox on refresh; the panel writes only through
## Apprentice.set_board_lines and ApprenticeBox.deposit.

const APPRENTICE_GROUP := &"apprentice"
const BOX_GROUP := &"apprentice_box"
const PLAYER_GROUP := &"player"
const TASK_NONE := &""
const AREA_ORDER: Array[StringName] = [&"yard", &"east", &"north", &"elder", &"linden", &"all", &"wished"]
const DONE_ROWS_MAX := 14

@export var panel_width: float = 1320.0
@export var task_button_width: float = 158.0
@export var area_button_width: float = 230.0

var apprentice: Apprentice
var box: ApprenticeBox
var title_label: Label
var morale_label: Label
var lines_box: VBoxContainer
var done_box: VBoxContainer
## line index → {task: StringName → Button, none: Button, area: Button}
var line_rows: Array[Dictionary] = []
## task → {marks: Label, word: Label, practice: Label}
var level_rows: Dictionary[StringName, Dictionary] = {}
var tin_label: Label
var tin_state_label: Label
var deposit_button: Button
var estimate_label: Label
var missing_label: Label
var reply_label: Label
var done_button: Button
var showing_done: bool = false
var reply: String = ""


func _build() -> void:
	theme_type_variation = &"SlatePanel"
	custom_minimum_size.x = panel_width
	var box_v := UIKit.vbox(12)
	add_child(box_v)
	var head := UIKit.hbox(16)
	title_label = UIKit.label(Phase8Texts.BOARD_TITLE, &"ChalkHeaderLabel")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	morale_label = UIKit.label("", &"ChalkDimLabel")
	morale_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(morale_label)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"ChalkButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box_v.add_child(head)
	var body := UIKit.hbox(28)
	box_v.add_child(body)
	var left := UIKit.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	lines_box = UIKit.vbox(10)
	left.add_child(lines_box)
	for i: int in 3:
		lines_box.add_child(_line_row(i))
	lines_box.add_child(UIKit.label(Phase8Texts.BOARD_GREY_HINT, &"ChalkDimLabel"))
	done_box = UIKit.vbox(4)
	done_box.visible = false
	left.add_child(done_box)
	var right := UIKit.vbox(8)
	right.custom_minimum_size.x = 300.0
	body.add_child(right)
	right.add_child(UIKit.label(Phase8Texts.BOARD_LEVELS, &"ChalkLabel"))
	for task: StringName in Apprentice.TASKS:
		var row := UIKit.vbox(0)
		var line := UIKit.hbox(10)
		var name := UIKit.label(Phase8Texts.task_label(task), &"ChalkLabel")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name)
		var marks := UIKit.label("", &"ChalkMarkLabel")
		marks.custom_minimum_size.x = 40.0
		line.add_child(marks)
		row.add_child(line)
		var word := UIKit.label("", &"ChalkDimLabel")
		row.add_child(word)
		var practice := UIKit.label("", &"ChalkDimLabel")
		row.add_child(practice)
		right.add_child(row)
		level_rows[task] = {"marks": marks, "word": word, "practice": practice}
	var tin_row := UIKit.panel(&"SlateRowPanel")
	var tin_line := UIKit.hbox(16)
	tin_line.add_child(UIKit.icon(Database.icon(&"coin"), 34.0))
	var tin_col := UIKit.vbox(0)
	tin_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tin_label = UIKit.label("", &"ChalkLabel")
	tin_col.add_child(tin_label)
	tin_state_label = UIKit.label("", &"ChalkDimLabel")
	tin_col.add_child(tin_state_label)
	tin_line.add_child(tin_col)
	deposit_button = UIKit.button("", &"ChalkButton")
	deposit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deposit_button.pressed.connect(deposit)
	tin_line.add_child(deposit_button)
	tin_row.add_child(tin_line)
	box_v.add_child(tin_row)
	estimate_label = UIKit.label("", &"ChalkLabel", true)
	estimate_label.custom_minimum_size.x = panel_width - 90.0
	box_v.add_child(estimate_label)
	missing_label = UIKit.label("", &"ChalkDimLabel", true)
	box_v.add_child(missing_label)
	reply_label = UIKit.label("", &"ChalkDimLabel", true)
	box_v.add_child(reply_label)
	var bottom := UIKit.hbox(16)
	done_button = UIKit.button(Phase8Texts.BOARD_SHOW_DONE, &"ChalkButton")
	done_button.pressed.connect(toggle_done)
	bottom.add_child(done_button)
	bottom.add_child(UIKit.spacer())
	var back := UIKit.button(TEXT_CLOSE, &"ChalkButton")
	back.pressed.connect(request_close)
	bottom.add_child(back)
	box_v.add_child(bottom)


func _line_row(index: int) -> Control:
	var row := UIKit.panel(&"SlateRowPanel")
	var line := UIKit.hbox(8)
	var number := UIKit.label("%d." % (index + 1), &"ChalkLabel")
	number.custom_minimum_size.x = 30.0
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(number)
	var buttons := {}
	var none := UIKit.button(Phase8Texts.BOARD_TASK_NONE, &"ChalkButton")
	none.pressed.connect(set_task.bind(index, TASK_NONE))
	line.add_child(none)
	for task: StringName in Apprentice.TASKS:
		var b := UIKit.button(Phase8Texts.task_label(task), &"ChalkButton")
		b.custom_minimum_size.x = task_button_width
		b.pressed.connect(set_task.bind(index, task))
		line.add_child(b)
		buttons[task] = b
	line.add_child(UIKit.spacer())
	var area := UIKit.button("", &"ChalkButton")
	area.custom_minimum_size.x = area_button_width
	area.pressed.connect(cycle_area.bind(index))
	line.add_child(area)
	row.add_child(line)
	line_rows.append({"tasks": buttons, "none": none, "area": area})
	return row


func _on_opened() -> void:
	var a: Variant = context.get("apprentice")
	apprentice = a if is_instance_valid(a) else _first(APPRENTICE_GROUP) as Apprentice
	var b: Variant = context.get("box")
	box = b if is_instance_valid(b) else _first(BOX_GROUP) as ApprenticeBox
	showing_done = false
	reply = ""


func _refresh() -> void:
	var cfg := _cfg()
	var lines := current_lines()
	morale_label.text = Phase8Texts.morale_text(apprentice.morale()) if apprentice != null else ""
	for i: int in line_rows.size():
		var r := line_rows[i]
		var line: Dictionary = lines[i] if i < lines.size() else {}
		var chosen := StringName(str(line.get("task", "")))
		(r.none as Button).theme_type_variation = &"ChalkSelected" if chosen == TASK_NONE else &"ChalkButton"
		(r.none as Button).disabled = action_running
		for task: StringName in Apprentice.TASKS:
			var b: Button = r.tasks[task]
			var shown := level(task) > 0
			b.disabled = action_running or not shown
			b.tooltip_text = "" if shown else Phase8Texts.BOARD_NOT_SHOWN
			b.theme_type_variation = &"ChalkSelected" if chosen == task else &"ChalkButton"
		var area := StringName(str(line.get("area", "all")))
		(r.area as Button).text = "‹ %s ›" % Phase8Texts.area_label(area)
		(r.area as Button).disabled = action_running or chosen == TASK_NONE
		(r.area as Button).visible = chosen != TASK_NONE
	for task: StringName in Apprentice.TASKS:
		var lv := level(task)
		var row := level_rows[task]
		(row.marks as Label).text = Phase8Texts.level_marks(lv) if lv > 0 else Phase8Texts.BOARD_LEVEL_NONE
		(row.word as Label).text = Phase8Texts.level_word(lv)
		var practice := Phase8Texts.practice_text(lv, apprentice.jobs(task) if apprentice != null else 0, cfg.practice_jobs)
		(row.practice as Label).text = practice
		(row.practice as Label).visible = practice != ""
	var coins_in := box.coins if box != null else 0
	var debt := apprentice.debt() if apprentice != null else 0
	tin_label.text = "%s: %s" % [Phase8Texts.BOARD_TIN, Phase8Texts.tin_text(coins_in, cfg.wage)]
	tin_state_label.text = Phase8Texts.tin_state(coins_in, cfg.wage, debt)
	tin_state_label.theme_type_variation = &"WarningLabel" if debt > 0 or coins_in < cfg.wage else &"ChalkDimLabel"
	deposit_button.text = Phase8Texts.BOARD_DEPOSIT % cfg.wage
	var inv := _player_inventory()
	deposit_button.disabled = action_running or box == null or inv == null or inv.count(&"coin") < cfg.wage
	deposit_button.tooltip_text = Phase8Texts.BOARD_NO_COINS % cfg.wage if deposit_button.disabled and box != null else ""
	estimate_label.text = estimate_text()
	var missing := apprentice.missing_items() if apprentice != null else [] as Array[StringName]
	var names := PackedStringArray()
	for id: StringName in missing:
		names.append(UIKit.item_name(id))
	missing_label.text = Phase8Texts.BOARD_MISSING % ", ".join(names) if not names.is_empty() else ""
	missing_label.visible = not names.is_empty()
	reply_label.text = reply
	reply_label.visible = reply != ""
	lines_box.visible = not showing_done
	done_box.visible = showing_done
	done_button.text = Phase8Texts.BOARD_BACK if showing_done else Phase8Texts.BOARD_SHOW_DONE
	if showing_done:
		_refresh_done()


# --- state & actions (public for tests and the screenshot director) ---------------------------------

## The board lines as three entries [{task, area}] (missing lines = {} = „– nichts –").
func current_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if apprentice != null:
		out = apprentice.board_lines()
	return out


func level(task: StringName) -> int:
	return apprentice.level(task) if apprentice != null else 0


## Line `index` gets `task` (&"" clears it); only a task he was shown can be chosen.
func set_task(index: int, task: StringName) -> bool:
	if apprentice == null or index < 0 or index >= line_rows.size():
		return false
	if task != TASK_NONE and level(task) <= 0:
		reply = "„%s“" % Apprentice.TEXT_NOT_SHOWN
		refresh()
		return false
	var lines := current_lines()
	while lines.size() <= index:
		lines.append({})
	if task == TASK_NONE:
		lines[index] = {}
	else:
		var area := str((lines[index] as Dictionary).get("area", "all"))
		lines[index] = {"task": String(task), "area": area}
	_write(lines)
	return true


## The area of line `index` moves on to the next one (AREA_ORDER, wrapping).
func cycle_area(index: int) -> void:
	var lines := current_lines()
	if index < 0 or index >= lines.size() or str(lines[index].get("task", "")) == "":
		return
	var area := StringName(str(lines[index].get("area", "all")))
	lines[index]["area"] = String(AREA_ORDER[posmod(AREA_ORDER.find(area) + 1, AREA_ORDER.size())])
	_write(lines)


func set_area(index: int, area: StringName) -> void:
	var lines := current_lines()
	if index < 0 or index >= lines.size() or not area in AREA_ORDER:
		return
	lines[index]["area"] = String(area)
	_write(lines)


## „Münzen einlegen": one day's wage from the pack into the tin.
func deposit() -> bool:
	var inv := _player_inventory()
	var cfg := _cfg()
	if box == null or inv == null:
		return false
	var ok := box.deposit(inv, cfg.wage)
	reply = "" if ok else Phase8Texts.BOARD_NO_COINS % cfg.wage
	refresh()
	return ok


func toggle_done() -> void:
	showing_done = not showing_done
	refresh()


## The estimate line from today's plan (what is still to come) or, before Jakob read the board, a plan of the
## next working day made with the same planner.
func estimate_text() -> String:
	if apprentice == null:
		return ""
	var lines := current_lines()
	if lines.is_empty():
		return Phase8Texts.BOARD_ESTIMATE_NONE
	var plan: Array[Dictionary] = []
	plan.assign(_today_plan())
	if not plan.is_empty():
		var rest: Array[Dictionary] = []
		rest.assign(plan.slice(apprentice.progress()))
		plan = rest
	else:
		if not apprentice.works_today(TimeManager.day) and not apprentice.works_today(TimeManager.day + 1):
			return Phase8Texts.BOARD_ESTIMATE_OFF
		plan = _preview_plan(lines)
	var text := Phase8Texts.estimate_text(ApprenticeBoard.estimate(plan), lines)
	return text if text != "" else Phase8Texts.BOARD_ESTIMATE_NONE


## Today's finished places [{entry, mistake}] (plan entries before Apprentice.progress()).
func done_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if apprentice == null:
		return out
	var plan := _today_plan()
	for i: int in mini(apprentice.progress(), plan.size()):
		var e: Dictionary = plan[i]
		if StringName(str(e.get("task", ""))) in Apprentice.TASKS:
			out.append({"entry": e, "mistake": bool(e.get("mistake", false))})
	return out


func _refresh_done() -> void:
	UIKit.clear_children(done_box)
	done_box.add_child(UIKit.label(Phase8Texts.BOARD_DONE_TITLE, &"ChalkLabel"))
	var done := done_entries()
	if done.is_empty():
		done_box.add_child(UIKit.label(Phase8Texts.BOARD_DONE_NONE, &"ChalkDimLabel"))
		return
	var shown := 0
	for d: Dictionary in done:
		if shown >= DONE_ROWS_MAX:
			done_box.add_child(UIKit.label("… +%d" % (done.size() - shown), &"ChalkDimLabel"))
			break
		var e: Dictionary = d.entry
		done_box.add_child(UIKit.label(Phase8Texts.done_row(e, _section_of(str(e.get("grave_id", "")), str(e.get("spot_id", ""))),
				bool(d.mistake)), &"WarningLabel" if bool(d.mistake) else &"ChalkLabel"))
		shown += 1


## Apprentice.today_plan() untyped (its empty branch is an untyped [] – avoids a typed-array conversion error).
func _today_plan() -> Array:
	var raw: Variant = apprentice.call(&"today_plan") if apprentice != null else []
	return raw as Array if raw is Array else []


func _write(lines: Array[Dictionary]) -> void:
	var clean: Array[Dictionary] = []
	for l: Dictionary in lines:
		if str(l.get("task", "")) != "":
			clean.append(l)
	apprentice.set_board_lines(clean)
	reply = ""
	refresh()


func _preview_plan(lines: Array[Dictionary]) -> Array[Dictionary]:
	if not is_inside_tree():
		return [] as Array[Dictionary]
	var cfg := _cfg()
	var levels := {}
	for task: StringName in Apprentice.TASKS:
		levels[String(task)] = level(task)
	var items := {}
	if box != null and box.storage != null:
		for slot: Dictionary in box.storage.get_slots():
			if not slot.is_empty():
				items[StringName(slot.id)] = int(items.get(StringName(slot.id), 0)) + int(slot.amount)
	var care := _first(&"grave_care") as GraveCare
	var state := {"levels": levels, "morale": apprentice.morale(), "scolded": false, "position": Apprentice.WP_BOARD,
			"fills": care.can_fill(GraveCare.OWNER_APPRENTICE) if care != null else 0, "items": items,
			"world": _world_of(apprentice.npc), "done": []}
	var day := TimeManager.day if TimeManager.minute_of_day < cfg.start_minute else TimeManager.day + 1
	return ApprenticePlanner.plan(day, cfg.start_minute, lines, state, get_tree(), cfg)


func _section_of(grave_id: String, spot_id: String) -> String:
	var id := grave_id if grave_id != "" else spot_id
	if id == "":
		return ""
	var graveyard := _first(&"graveyard")
	if graveyard != null and graveyard.has_method(&"section_of"):
		var s := Database.section(StringName(str(graveyard.call(&"section_of", id)))) as SectionData
		if s != null:
			return s.display_name
	return id


static func _world_of(node: Node) -> Node:
	var n := node
	while n != null and not n.has_method(&"get_waypoint"):
		n = n.get_parent()
	return n


func _cfg() -> ApprenticeConfig:
	if apprentice != null and apprentice.config != null:
		return apprentice.config
	var cfg := Database.config(&"apprentice_config") as ApprenticeConfig
	return cfg if cfg != null else ApprenticeConfig.new()


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null
