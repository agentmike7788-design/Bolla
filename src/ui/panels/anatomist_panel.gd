class_name AnatomistPanel
extends UIPanel
## &"anatomist" – Severin Quast's surgery (docs/PHASE7_DESIGN.md §2.6.1, §2.6.4, §7): context {speaker,
## inventory} (dialogue action open_anatomist, opens over his dialogue). The held specimens in the pack,
## each with its label (organ, name, age), clarity as a word and a bar, the container (Glas / Bündel /
## Schau- / Knochenpräparat), „verdorben in ≈ 4 h" for a bundle, Quast's price („+2 Ansehen"), the buttons
## „Verkaufen (8)" and „Gutachten (30 Min)" and, on a lecture night, „Für die Vorlesung" (opens &"lecture"
## with the piece chosen). Selling: Specimens.sell at once, with the line „Im Dorf wird man davon hören.";
## the expertise runs as a TimedAction, then Specimens.expertise shows its card (finding, new teaching).
## Without pieces: Quast's line „Bringen Sie mir, was die Erde nicht vermisst." Pieces sold or researched
## leave the list. Presence: the dialogue opens the panel; without a speaker the shop rule decides
## (VillageShops.is_open(&"surgeon")).

const SPECIMENS_GROUP := &"specimens"
const LECTURES_GROUP := &"lectures"
const SHOPS_GROUP := &"village_shops"
const MANAGER_GROUP := &"corpse_manager"
const SURGEON_SHOP := &"surgeon"
const LECTURE_PANEL := &"lecture"
const COIN_ITEM := &"coin"
const ANIM := &"interact"

@export var panel_width: float = 1300.0
@export var icon_edge: float = 46.0

var specimens: Specimens
var list_box: VBoxContainer
var empty_label: Label
var hint_label: Label
var reply_label: Label
var away_label: Label
var coins_label: Label
var result_card: PanelContainer
var result_title: Label
var result_text: Label
var result_teaching: Label
var back_button: Button
## uid -> {row, sell, expertise, lecture, price, eta, bar}
var rows: Dictionary[String, Dictionary] = {}
var reply: String = ""
## Last expertise result ({} = none).
var result: Dictionary = {}

var _inventory: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	var head := UIKit.hbox(16)
	var titles := UIKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.label(Phase7Texts.ANATOMIST_TITLE, &"HeaderLabel"))
	titles.add_child(UIKit.label(Phase7Texts.ANATOMIST_SUB, &"DimLabel"))
	head.add_child(titles)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	box.add_child(UIKit.separator())
	list_box = UIKit.vbox(6)
	box.add_child(list_box)
	empty_label = UIKit.label(Phase7Texts.ANATOMIST_EMPTY, &"WhisperLabel", true)
	box.add_child(empty_label)
	hint_label = UIKit.label(Phase7Texts.ANATOMIST_SELL_HINT, &"DimLabel")
	box.add_child(hint_label)
	result_card = UIKit.panel(&"CardPanel")
	var rbox := UIKit.vbox(4)
	result_title = UIKit.label(Phase7Texts.ANATOMIST_RESULT_TITLE, &"InkHeaderLabel")
	rbox.add_child(result_title)
	result_text = UIKit.label("", &"InkLabel", true)
	result_text.custom_minimum_size.x = panel_width - 140.0
	rbox.add_child(result_text)
	result_teaching = UIKit.label("", &"InkStampLabel", true)
	rbox.add_child(result_teaching)
	rbox.add_child(UIKit.label(Phase7Texts.ANATOMIST_RESULT_STAYS, &"InkDimLabel"))
	result_card.add_child(rbox)
	box.add_child(result_card)
	reply_label = UIKit.label("", &"WhisperLabel", true)
	reply_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(reply_label)
	away_label = UIKit.label(Phase7Texts.ANATOMIST_AWAY, &"WarningLabel")
	box.add_child(away_label)
	_make_action_row(box)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	coins_label = UIKit.label("", &"SubheaderLabel")
	coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coins_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(coins_label)
	back_button = UIKit.button(TEXT_CLOSE)
	back_button.pressed.connect(request_close)
	bottom.add_child(back_button)
	box.add_child(bottom)


## The default focus never lands on „Verkaufen" (irreversible): the first „Gutachten", else „Schließen".
func focus_default() -> void:
	if not is_visible_in_tree():
		return
	for uid: String in rows:
		var b := rows[uid].expertise as Button
		if b.is_visible_in_tree() and not b.disabled:
			b.grab_focus()
			return
	if back_button != null and back_button.is_visible_in_tree():
		back_button.grab_focus()


func _on_opened() -> void:
	specimens = get_tree().get_first_node_in_group(SPECIMENS_GROUP) as Specimens if is_inside_tree() else null
	reply = ""
	result = {}
	_inventory = _player_inventory()
	if _inventory == null and is_inside_tree():
		var p := get_tree().get_first_node_in_group(&"player")
		_inventory = p.get(&"inventory") as Inventory if p != null else null
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


## uids of the held specimens in the pack (Specimens order).
func pieces() -> PackedStringArray:
	var out := PackedStringArray()
	if specimens == null or _inventory == null:
		return out
	for uid: String in specimens.held():
		if _inventory.has_uid(uid):
			out.append(uid)
	return out


func _refresh() -> void:
	UIKit.clear_children(list_box)
	rows.clear()
	var present := is_present()
	var night := lecture_night()
	var now := TimeManager.total_minutes()
	var cfg := specimens.get_config() if specimens != null else AnatomyConfig.new()
	for uid: String in pieces():
		var spec := specimens.get_record(uid)
		list_box.add_child(_row(Phase7Texts.specimen_row(spec, _record(spec.corpse_id), now, cfg), present, night, cfg))
	var has_any := not rows.is_empty()
	empty_label.visible = not has_any and GameState.flag_on(cfg.known_flag)
	hint_label.visible = has_any
	result_card.visible = not result.is_empty()
	if not result.is_empty():
		result_text.text = str(result.get("text", ""))
		var teaching := StringName(str(result.get("teaching", "")))
		var t := Database.teaching(teaching) as TeachingData
		result_teaching.text = Phase7Texts.ANATOMIST_RESULT_TEACHING % (t.title if t != null else String(teaching)) if bool(result.get("learned", false)) \
				else Phase7Texts.ANATOMIST_RESULT_KNOWN
	reply_label.text = reply
	reply_label.visible = reply != ""
	away_label.visible = not present
	coins_label.text = Phase7Texts.ANATOMIST_COINS % (_inventory.count(COIN_ITEM) if _inventory != null else 0)


func _row(r: Dictionary, present: bool, night: bool, cfg: AnatomyConfig) -> Control:
	var uid := str(r.uid)
	var row := UIKit.panel(&"TradeRowPanel")
	row.set_meta(&"uid", uid)
	var line := UIKit.hbox(12)
	line.add_child(UIKit.icon(Database.icon(SpecimenRules.item_for(StringName(str(r.container)))), icon_edge))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("%s – %s" % [str(r.organ_label), str(r.name)], &"SubheaderLabel"))
	var info := UIKit.hbox(12)
	info.add_child(UIKit.label(str(r.container_word), &"DimLabel"))
	var bar := UIKit.bar(&"FreshBar")
	bar.custom_minimum_size = Vector2(140.0, 14.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.value = clampf(float(r.clarity), 0.0, 1.0)
	info.add_child(bar)
	info.add_child(UIKit.label("Klarheit " + str(r.clarity_word), &"WarningLabel" if bool(r.spoiled) else &""))
	var eta := UIKit.label(str(r.eta), &"WarningLabel")
	eta.visible = str(r.eta) != ""
	info.add_child(eta)
	col.add_child(info)
	line.add_child(col)
	var price := specimens.sale_price(uid) if specimens != null else 0
	var price_col := UIKit.vbox(0)
	price_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var price_label := UIKit.label(Phase7Texts.ANATOMIST_PRICE % [price, Phase7Texts.coins(price)], &"SubheaderLabel")
	price_col.add_child(price_label)
	var bonus := specimens.standing_bonus() if specimens != null else 0
	var bonus_label := UIKit.label(Phase7Texts.ANATOMIST_STANDING % bonus, &"GoodLabel")
	bonus_label.visible = bonus > 0 and price > 0
	price_col.add_child(bonus_label)
	line.add_child(price_col)
	var sell_reason := sell_block_reason(uid)
	var sell_b := UIKit.button(Phase7Texts.ANATOMIST_SELL % price, &"DangerButton")
	sell_b.disabled = action_running or not present or sell_reason != ""
	sell_b.tooltip_text = sell_reason
	sell_b.pressed.connect(sell.bind(uid))
	line.add_child(sell_b)
	var exp_b := UIKit.button(Phase7Texts.ANATOMIST_EXPERTISE % UIKit.minutes(cfg.expertise_minutes))
	var exp_reason := specimens.expertise_block_reason(uid, _inventory) if specimens != null else PultRules.TEXT_NO_PIECE
	exp_b.disabled = action_running or not present or exp_reason != ""
	exp_b.tooltip_text = exp_reason
	exp_b.pressed.connect(request_expertise.bind(uid))
	line.add_child(exp_b)
	var lec_b := UIKit.button(Phase7Texts.ANATOMIST_LECTURE, &"AccentButton")
	lec_b.visible = night
	var lec_reason := lecture_reason(uid)
	lec_b.disabled = action_running or lec_reason != ""
	lec_b.tooltip_text = lec_reason
	lec_b.pressed.connect(open_lecture.bind(uid))
	line.add_child(lec_b)
	row.add_child(line)
	rows[uid] = {"row": row, "sell": sell_b, "expertise": exp_b, "lecture": lec_b, "price": price_label, "eta": eta, "bar": bar,
			"bonus": bonus_label}
	return row


# --- actions ---------------------------------------------------------------------------------------

func sell_block_reason(uid: String) -> String:
	if specimens == null:
		return PultRules.TEXT_NO_PIECE
	if not is_present():
		return Phase7Texts.ANATOMIST_AWAY
	return specimens.sell_block_reason(uid, _inventory)


## Specimens.sell at once; returns the coins.
func sell(uid: String) -> int:
	if sell_block_reason(uid) != "" or action_running:
		return 0
	var coins := specimens.sell(uid, _inventory)
	if coins > 0:
		reply = Phase7Texts.ANATOMIST_SOLD % [coins, Phase7Texts.coins(coins)]
	result = {}
	refresh()
	return coins


## „Gutachten (30 Min)": TimedAction of the player, then Specimens.expertise (finish_expertise).
func request_expertise(uid: String) -> bool:
	if specimens == null or not is_present() or specimens.expertise_block_reason(uid, _inventory) != "":
		return false
	var p := _player_node()
	var minutes := specimens.get_config().expertise_minutes
	if p != null and p.has_method(&"start_timed_action"):
		return bool(p.call(&"start_timed_action", Phase7Texts.ANATOMIST_EXPERTISE_LABEL, minutes, finish_expertise.bind(uid, _inventory), false, ANIM))
	finish_expertise(uid, _inventory)
	return true


func finish_expertise(uid: String, inv: Inventory) -> void:
	if specimens == null:
		return
	result = specimens.expertise(uid, inv)
	reply = ""
	if is_open:
		refresh()


func lecture_night() -> bool:
	var lectures := _lectures()
	return lectures != null and lectures.invited() and lectures.tonight()


func lecture_reason(uid: String) -> String:
	var lectures := _lectures()
	if lectures == null:
		return Phase7Texts.LECTURE_NOT_TONIGHT
	return lectures.hold_block_reason(uid, _inventory)


## The lecture panel over this one, with `uid` chosen.
func open_lecture(uid: String) -> void:
	var ctx := context.duplicate()
	ctx["uid"] = uid
	EventBus.ui_panel_requested.emit(LECTURE_PANEL, ctx)


## Quast is there: the dialogue opened the panel (speaker), else the surgery shop rule.
func is_present() -> bool:
	if is_instance_valid(context.get("speaker")):
		return true
	var shops := get_tree().get_first_node_in_group(SHOPS_GROUP) as VillageShops if is_inside_tree() else null
	return shops == null or shops.is_open(SURGEON_SHOP)


func _lectures() -> Lectures:
	return get_tree().get_first_node_in_group(LECTURES_GROUP) as Lectures if is_inside_tree() else null


func _record(corpse_id: String) -> CorpseRecord:
	var manager := get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null
	return manager.get_record(corpse_id) if manager != null else null


func _player_node() -> Node:
	var p := _player()
	if p != null:
		return p
	return get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
