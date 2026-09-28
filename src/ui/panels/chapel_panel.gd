class_name ChapelPanel
extends UIPanel
## &"chapel" – the funeral service at the altar (docs/PHASE6_DESIGN.md §2.4, §7): context
## {corpse_id, altar: ChapelAltar, inventory, player}. The name of the dead, a checklist of what the
## service needs (on the catafalque · dressed · freshness ≥ 30 % · an altar candle · beginning
## 08:00–17:00 · not held yet) and what it brings at the chapel's level (the family's fee „Die
## Familie legt 5 Münzen auf den Altar.", reputation, mourners, „Ausgesegnet" at the grave, the
## duration). The button „Aussegnung halten (45 Min)" is dimmed with ChapelRites' reason; pressing
## it closes the panel and calls altar.request_service().

const MANAGER_GROUP := &"corpse_manager"
const RITES_GROUP := &"chapel_rites"

@export var panel_width: float = 1180.0

var title_label: Label
var name_label: Label
var checks_box: VBoxContainer
var preview_box: VBoxContainer
var reason_label: Label
var service_button: Button
## Checklist as shown (Phase6Texts.service_checks).
var checks: Array[Dictionary] = []
## Preview lines as shown.
var preview: PackedStringArray = []

var _inventory: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(16)
	add_child(box)
	var head := UIKit.hbox(18)
	title_label = UIKit.label(Phase6Texts.CHAPEL_TITLE, &"HeaderLabel")
	head.add_child(title_label)
	name_label = UIKit.label("", &"SubheaderLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(name_label)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	var intro := UIKit.label(Phase6Texts.CHAPEL_INTRO, &"WhisperLabel", true)
	intro.custom_minimum_size.x = panel_width - 80.0
	box.add_child(intro)
	var columns := UIKit.hbox(24)
	box.add_child(columns)
	var width := (panel_width - 104.0) * 0.5
	checks_box = _column(columns, Phase6Texts.CHAPEL_CONDITIONS, width)
	preview_box = _column(columns, Phase6Texts.CHAPEL_PREVIEW, width)
	_make_action_row(box)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	reason_label = UIKit.label("", &"WarningLabel")
	reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(reason_label)
	var close_button := UIKit.button(TEXT_CLOSE)
	close_button.pressed.connect(request_close)
	bottom.add_child(close_button)
	service_button = UIKit.button("", &"AccentButton")
	service_button.pressed.connect(_on_service_pressed)
	bottom.add_child(service_button)
	box.add_child(bottom)


func _ready() -> void:
	super._ready()
	EventBus.corpse_updated.connect(_on_corpse_updated)
	EventBus.time_tick.connect(_on_time_tick)


func _on_opened() -> void:
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


func _refresh() -> void:
	var rites := rites_node()
	var cfg := rites.get_config() if rites != null else _chapel_config()
	var reason := block_reason()
	var record := current_record()
	name_label.text = Phase6Texts.CHAPEL_FOR % record.display_name if record != null else ""
	checks = Phase6Texts.service_checks(record, _inventory, TimeManager.minute_of_day, cfg)
	UIKit.clear_children(checks_box)
	for check: Dictionary in checks:
		checks_box.add_child(_check_row(check))
	preview = Phase6Texts.service_preview(rites.level() if rites != null else 0, cfg, _economy().quality_service)
	UIKit.clear_children(preview_box)
	for i: int in preview.size():
		preview_box.add_child(UIKit.label(preview[i], &"GoodLabel" if i == 0 else &"", true))
	service_button.text = Phase6Texts.SERVICE_BUTTON % UIKit.minutes(cfg.service_minutes)
	service_button.disabled = reason != ""
	service_button.tooltip_text = reason
	reason_label.text = reason if reason != TEXT_BUSY else ""


## "" or why the service cannot begin now (ChapelRites.service_block_reason) or TEXT_BUSY.
func block_reason() -> String:
	if action_running:
		return TEXT_BUSY
	var rites := rites_node()
	if rites == null:
		return ChapelRules.TEXT_NO_CHAPEL
	return rites.service_block_reason(corpse_id(), _inventory)


func corpse_id() -> String:
	return str(context.get("corpse_id", ""))


func current_record() -> CorpseRecord:
	if corpse_id() == "" or not is_inside_tree():
		return null
	var manager := get_tree().get_first_node_in_group(MANAGER_GROUP)
	return manager.call(&"get_record", corpse_id()) as CorpseRecord if manager != null and manager.has_method(&"get_record") else null


func rites_node() -> ChapelRites:
	return get_tree().get_first_node_in_group(RITES_GROUP) as ChapelRites if is_inside_tree() else null


## ok of the checklist entry `id` (&"catafalque", &"dressed", &"fresh", &"candle", &"time", &"held").
func check_ok(id: StringName) -> bool:
	for check: Dictionary in checks:
		if check.id == id:
			return bool(check.ok)
	return false


func _column(parent: Container, caption: String, width: float) -> VBoxContainer:
	var frame := UIKit.panel(&"SectionPanel")
	frame.custom_minimum_size.x = width
	parent.add_child(frame)
	var box := UIKit.vbox(10)
	frame.add_child(box)
	box.add_child(UIKit.label(caption, &"AccentLabel"))
	var list := UIKit.vbox(8)
	box.add_child(list)
	return list


func _check_row(check: Dictionary) -> Control:
	var row := UIKit.hbox(12)
	var ok := bool(check.ok)
	var mark := UIKit.label("✓" if ok else "✗", &"GoodLabel" if ok else &"WarningLabel")
	mark.custom_minimum_size.x = 24.0
	row.add_child(mark)
	row.add_child(UIKit.label(str(check.text), &"" if ok else &"WarningLabel"))
	row.set_meta(&"id", check.id)
	return row


func _on_service_pressed() -> void:
	if block_reason() != "":
		return
	var altar: Variant = context.get("altar")
	if not is_instance_valid(altar) or not (altar as Object).has_method(&"request_service"):
		push_warning("[ChapelPanel] altar has no request_service()")
		return
	request_close()
	(altar as Object).call(&"request_service")


func _on_corpse_updated(id: String) -> void:
	if is_open and id == corpse_id():
		refresh()


func _on_time_tick(_day: int, _minute: int) -> void:
	if is_open:
		refresh()


static func _chapel_config() -> ChapelConfig:
	var cfg := Database.config(&"chapel_config") as ChapelConfig
	return cfg if cfg != null else ChapelConfig.new()
