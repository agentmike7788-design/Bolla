class_name RewardCard
extends PanelContainer
## Parchment card shown on EventBus.grave_completed: the quality breakdown, the final
## quality and – from the payment_received that follows – the coins paid. Fades out
## after `show_seconds`. Never drawn over a modal panel/dialogue: while UIState has a modal
## open the card is held back (hidden) and shown for its full time once it closes.

const TEXT_TITLE := "Grab vollendet"
const TEXT_QUALITY := "Qualität"
const QUALITY_FORMAT := "%d/%d"
const PAYMENT_FORMAT := "+%d Münzen"
const COIN_ITEM := &"coin"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const ICON_EDGE := 30.0

@export var show_seconds: float = 4.0
@export var fade_time: float = 0.5
@export var card_width: float = 520.0

var _title: Label
var _subtitle: Label
var _lines: VBoxContainer
var _quality: Label
var _payment_row: HBoxContainer
var _payment: Label
var _tween: Tween
## True between grave_completed and the payment that belongs to it.
var _awaiting_payment: bool = false
## True while a card is waiting for an open modal to close.
var _held: bool = false


func _init() -> void:
	theme_type_variation = &"CardPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var box := UIKit.vbox(6)
	add_child(box)
	_title = UIKit.label(TEXT_TITLE, &"InkHeaderLabel")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_subtitle = UIKit.label("", &"InkDimLabel")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	_lines = UIKit.vbox(2)
	box.add_child(_lines)
	box.add_child(UIKit.separator())
	var total := UIKit.hbox()
	var total_label := UIKit.label(TEXT_QUALITY, &"InkLabel")
	total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(total_label)
	_quality = UIKit.label("", &"InkHeaderLabel")
	total.add_child(_quality)
	box.add_child(total)
	_payment_row = UIKit.hbox(8)
	_payment_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_payment_row.add_child(UIKit.icon(Database.icon(COIN_ITEM), ICON_EDGE))
	_payment = UIKit.label("", &"InkHeaderLabel")
	_payment_row.add_child(_payment)
	_payment_row.visible = false
	box.add_child(_payment_row)


func _ready() -> void:
	custom_minimum_size.x = card_width
	EventBus.grave_completed.connect(_on_grave_completed)
	EventBus.payment_received.connect(_on_payment_received)
	EventBus.ui_modal_changed.connect(_on_ui_modal_changed)


## Shows the card for one completed grave (breakdown = [{label, points}]).
func show_grave(corpse_name: String, quality: int, breakdown: Array) -> void:
	_subtitle.text = corpse_name
	_subtitle.visible = corpse_name != ""
	UIKit.clear_children(_lines)
	for entry: Variant in breakdown:
		if not entry is Dictionary:
			continue
		var line := UIKit.hbox()
		var l := UIKit.label(str((entry as Dictionary).get("label", "")), &"InkLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
		line.add_child(UIKit.label(UIKit.signed(int((entry as Dictionary).get("points", 0))), &"InkLabel"))
		_lines.add_child(line)
	_quality.text = QUALITY_FORMAT % [quality, _economy().quality_max]
	_payment_row.visible = false
	_awaiting_payment = true
	_restart()


func set_payment(amount: int) -> void:
	_payment.text = PAYMENT_FORMAT % amount
	_payment_row.visible = true
	_awaiting_payment = false


## True while the card waits for the payment of the grave it shows.
func is_awaiting_payment() -> bool:
	return (visible or _held) and _awaiting_payment


## True while a card waits (hidden) for an open modal to close.
func is_held() -> bool:
	return _held


func line_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for line: Node in _lines.get_children():
		if line.is_queued_for_deletion():
			continue
		var parts: PackedStringArray = []
		for l: Node in line.get_children():
			parts.append((l as Label).text)
		out.append(" ".join(parts))
	return out


func quality_text() -> String:
	return _quality.text


func payment_text() -> String:
	return _payment.text if _payment_row.visible else ""


func _restart() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if UIState.is_modal():
		_hold()
		return
	_held = false
	visible = true
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(show_seconds)
	_tween.tween_property(self, ^"modulate:a", 0.0, fade_time)
	_tween.tween_callback(_hide_card)


## Hidden until the modal closes; the display time starts again afterwards.
func _hold() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_held = true
	visible = false


func _hide_card() -> void:
	visible = false
	_held = false
	_awaiting_payment = false


func _on_ui_modal_changed(open: bool) -> void:
	if not is_inside_tree():
		return
	if open and visible:
		_hold()
	elif not open and _held and not UIState.is_modal():
		_restart()


func _on_grave_completed(_grave_id: String, corpse_id: String, quality: int, breakdown: Array) -> void:
	show_grave(_corpse_name(corpse_id), quality, breakdown)


func _on_payment_received(amount: int, _reason: String) -> void:
	if is_awaiting_payment():
		set_payment(amount)


func _corpse_name(corpse_id: String) -> String:
	var manager := get_tree().get_first_node_in_group(CORPSE_MANAGER_GROUP) if is_inside_tree() else null
	if manager == null or not manager.has_method(&"get_record"):
		return ""
	var record := manager.call(&"get_record", corpse_id) as CorpseRecord
	return record.display_name if record != null else ""


func _economy() -> EconomyConfig:
	var cfg := Database.config(&"economy_config") as EconomyConfig
	return cfg if cfg != null else EconomyConfig.new()
