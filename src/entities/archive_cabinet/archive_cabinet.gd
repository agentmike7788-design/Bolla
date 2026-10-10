class_name ArchiveCabinet
extends Node3D
## The parish archive in the church (docs/PHASE8_DESIGN.md §2.4 Lenz 2 / Fenner 2, §3.4, §4.6 D7):
## „[E] Im Archiv helfen (60 Min)" with Lenz step 2 (the task order of_lenz_2 accepted; beside him,
## 16:00–18:00) or the parish key (flag archive_key; alone, 08:00–18:00) → a TimedAction that cannot be
## cancelled → Orders.note_task(&"archive_help") → item lorenz_ledger_2 (once, flag archive_ledger_found);
## without either: „Das Archiv ist verschlossen."

const PROMPT := "[E] Im Archiv helfen (60 Min)"
const TEXT_LOCKED := "Das Archiv ist verschlossen."
const TEXT_CLOSED_NOW := "Jetzt nicht. Das Archiv ist nur bis sechs offen."
const TEXT_FOUND := "Zwischen den Kirchenrechnungen von 1831 steckt ein schmales Heft in Lorenz' Hand."
const TEXT_BUSY := "Gerade nicht möglich."
const LABEL := "Im Archiv helfen"
const TASK_ID := &"archive_help"
const KEY_FLAG := &"archive_key"
const FOUND_FLAG := &"archive_ledger_found"
const LEDGER_ITEM := &"lorenz_ledger_2"
const CLUE_KLADDE := &"c_n_kladde"
const MINUTES := 60
## With Lenz (his order's window, else 16:00–18:00) / alone with the key (08:00–18:00).
const LENZ_WINDOW := Vector2i(960, 1080)
const KEY_WINDOW := Vector2i(480, 1080)
const ORDERS_GROUP := &"orders"
const ANIM := &"interact"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


## A free player with empty hands, while there is still something to find or a task waits.
func can_interact(player: Player) -> bool:
	if player == null or player.is_busy() or is_instance_valid(player.carried):
		return false
	return _task_order() != &"" or not GameState.flag_on(FOUND_FLAG)


func get_interaction_prompt(player: Player) -> String:
	if not can_interact(player):
		return ""
	return PROMPT if access() != "" else TEXT_LOCKED


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var how := access()
	if how == "":
		EventBus.notification_requested.emit(TEXT_LOCKED, &"warning")
		return
	if not open_now(how, TimeManager.minute_of_day):
		EventBus.notification_requested.emit(TEXT_CLOSED_NOW, &"warning")
		return
	if not player.start_timed_action(LABEL, MINUTES, _finish.bind(player), false, ANIM):
		EventBus.notification_requested.emit(TEXT_BUSY, &"warning")


## "lenz" (his task order runs) | "key" (Fenner's parish key) | "" (locked).
func access() -> String:
	if _task_order() != &"":
		return "lenz"
	if GameState.flag_on(KEY_FLAG):
		return "key"
	return ""


## The archive may be worked in now by `how` (Lenz' window or the key's).
func open_now(how: String, minute: int) -> bool:
	var w := _lenz_window() if how == "lenz" else KEY_WINDOW
	return minute >= w.x and minute <= w.y


func _finish(player: Player) -> void:
	var orders := _orders()
	if orders != null:
		orders.note_task(TASK_ID)
	if GameState.flag_on(FOUND_FLAG):
		return
	GameState.set_flag(FOUND_FLAG, true)
	if player != null and player.inventory != null:
		player.inventory.add_item(LEDGER_ITEM, 1)
	EventBus.notification_requested.emit(TEXT_FOUND, &"reward")
	# W-Welt (W2): the second notebook is the clue „Lorenz' zweite Kladde" (§1.6 point 6) – nothing gave it before.
	var journal := get_tree().get_first_node_in_group(&"journal") if is_inside_tree() else null
	if journal != null and journal.has_method(&"add_clue"):
		journal.call(&"add_clue", CLUE_KLADDE, "", false)


func _task_order() -> StringName:
	var orders := _orders()
	return orders.task_open(TASK_ID) if orders != null else &""


func _lenz_window() -> Vector2i:
	var orders := _orders()
	var id := _task_order()
	var o := orders.order_data(id) if orders != null and id != &"" else null
	var w: Variant = o.conditions.get("window") if o != null else null
	if w is Array and w.size() >= 2:
		return Vector2i(int(w[0]), int(w[1]))
	return LENZ_WINDOW


func _orders() -> Orders:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(ORDERS_GROUP) as Orders
