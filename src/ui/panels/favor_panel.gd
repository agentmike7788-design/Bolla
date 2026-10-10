class_name FavorPanel
extends UIPanel
## &"favor" – the small choice of a favour (docs/PHASE8_DESIGN.md §2.4, §7.3): context {npc_id | speaker,
## inventory, player} (dialogue open_panel:favor, the Merkbuch). One row per choice, by the favour's effect:
## - free_iron (Esch): the pieces of FavorData.params.choices („3× Eisenbeschläge", „Grabgitter leihen"),
## - prayer (Lenz): the graves with a dead (name, section) – „Für wen soll gebetet werden?",
## - night_watch (Fenner): tonight / tomorrow night,
## - order_ware (Theres): what Hanne carries, at her price,
## - every other favour: one row „Darum bitten".
## „Darum bitten" → Friendship.use_favor(npc, choice); dimmed with Friendship.favor_block_reason („Gerade erst.
## Frag in 3 Tagen wieder."). Nothing else changes anything.

const FRIENDSHIP_GROUP := &"friendship"
const GRAVEYARD_GROUP := &"graveyard"
const ROWS_MAX := 40

@export var panel_width: float = 900.0
@export var list_height: float = 430.0
@export var icon_edge: float = 36.0

var friendship: Friendship
var npc_id: StringName = &""
var favor: FavorData
var title_label: Label
var question_label: Label
var reason_label: Label
var reply_label: Label
var list_box: VBoxContainer
var scroll: ScrollContainer
## choice (String; "" = the plain favour) → Button
var buttons: Dictionary[String, Button] = {}
var reply: String = ""
var done: bool = false


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	title_label = _make_header(box, "")
	question_label = UIKit.label("", &"SubheaderLabel", true)
	box.add_child(question_label)
	reason_label = UIKit.label("", &"WarningLabel", true)
	box.add_child(reason_label)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(panel_width - 60.0, list_height)
	list_box = UIKit.vbox(6)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	box.add_child(scroll)
	reply_label = UIKit.label("", &"WhisperLabel", true)
	box.add_child(reply_label)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	bottom.add_child(UIKit.spacer())
	var back := UIKit.button(TEXT_CLOSE)
	back.pressed.connect(request_close)
	bottom.add_child(back)
	box.add_child(bottom)


func _on_opened() -> void:
	var f: Variant = context.get("friendship")
	friendship = f if is_instance_valid(f) else (get_tree().get_first_node_in_group(FRIENDSHIP_GROUP) as Friendship if is_inside_tree() else null)
	npc_id = StringName(str(context.get("npc_id", "")))
	if npc_id == &"":
		var speaker: Variant = context.get("speaker")
		if is_instance_valid(speaker):
			npc_id = StringName(str((speaker as Object).get(&"npc_id")))
	favor = friendship.favor(npc_id) if friendship != null else null
	reply = ""
	done = false


func _refresh() -> void:
	title_label.text = Phase8Texts.FAVOR_TITLE % (favor.label if favor != null else Phase8Texts.NONE)
	question_label.text = question()
	var reason := block_reason()
	reason_label.text = reason
	reason_label.visible = reason != "" and not done
	UIKit.clear_children(list_box)
	buttons.clear()
	var rows := choices()
	scroll.visible = not rows.is_empty()
	for i: int in mini(rows.size(), ROWS_MAX):
		var c: Dictionary = rows[i]
		var row := UIKit.panel(&"TradeRowPanel")
		var line := UIKit.hbox(12)
		var icon_id := StringName(str(c.get("icon", "")))
		if icon_id != &"":
			line.add_child(UIKit.icon(Database.icon(icon_id), icon_edge))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(str(c.text), &""))
		if str(c.get("meta", "")) != "":
			col.add_child(UIKit.label(str(c.meta), &"DimLabel"))
		line.add_child(col)
		var b := UIKit.button(Phase8Texts.FAVOR_ASK, &"AccentButton")
		b.disabled = reason != "" or done or action_running
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(ask.bind(str(c.choice)))
		line.add_child(b)
		row.add_child(line)
		list_box.add_child(row)
		buttons[str(c.choice)] = b
	reply_label.text = reply
	reply_label.visible = reply != ""


## Friendship.favor_block_reason ("" = it may be asked now).
func block_reason() -> String:
	if friendship == null:
		return Phase8Texts.FAVOR_NONE
	return friendship.favor_block_reason(npc_id)


func question() -> String:
	if favor == null:
		return ""
	match favor.effect:
		&"prayer":
			return Phase8Texts.FAVOR_CHOOSE_GRAVE
		&"night_watch":
			return Phase8Texts.FAVOR_CHOOSE_NIGHT
		&"free_iron", &"order_ware":
			return Phase8Texts.FAVOR_CHOOSE_ITEM
	return ""


## [{choice: String, text, meta, icon}] of the favour (one plain row for a favour without a choice).
func choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if favor == null:
		return out
	match favor.effect:
		&"free_iron":
			var raw: Variant = favor.params.get("choices", {})
			var keys: Array = (raw as Dictionary).keys() if raw is Dictionary else []
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			for k: Variant in keys:
				var id := StringName(str(k))
				var n := int((raw as Dictionary)[k])
				if id == Friendship.MORTSAFE_LOAN:
					out.append({"choice": String(id), "text": "%s – %d %s" % [UIKit.item_name(Friendship.MORTSAFE_ITEM), n,
							Phase8Texts.days_word(n)], "meta": "geliehen", "icon": String(Friendship.MORTSAFE_ITEM)})
				else:
					out.append({"choice": String(id), "text": Phase8Texts.FAVOR_ITEM_COUNT % [n, UIKit.item_name(id)], "meta": "",
							"icon": String(id)})
		&"order_ware":
			var shop := friendship.peddler_shop if friendship != null and friendship.peddler_shop != null else \
					Database.shop(StringName(str(favor.params.get("shop", Friendship.SHOPS_FALLBACK)))) as ShopData
			if shop != null:
				var ids: Array = shop.sells.keys()
				ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
				for id: Variant in ids:
					var price := int((shop.sells[id] as Dictionary).get("price", 0))
					out.append({"choice": String(id), "text": UIKit.item_name(StringName(str(id))),
							"meta": Phase8Texts.FAVOR_PRICE % [price, Phase8Texts.coins(price)], "icon": String(id)})
		&"prayer":
			for g: Dictionary in _graves():
				out.append(g)
		&"night_watch":
			var tonight := FavorRules.night_of(TimeManager.day, TimeManager.minute_of_day)
			out.append({"choice": "", "text": Phase8Texts.FAVOR_NIGHT, "meta": "", "icon": ""})
			out.append({"choice": str(tonight + 1), "text": Phase8Texts.FAVOR_NIGHT_NEXT, "meta": "", "icon": ""})
		_:
			out.append({"choice": "", "text": favor.label, "meta": "", "icon": ""})
	return out


## Asks the favour with `choice` (Friendship.use_favor). True when it was granted.
func ask(choice: String) -> bool:
	if friendship == null or done:
		return false
	var reason := block_reason()
	if reason != "":
		reply = reason
		refresh()
		return false
	done = friendship.use_favor(npc_id, StringName(choice))
	reply = Phase8Texts.FAVOR_DONE if done else FavorRules.TEXT_CHOICE
	refresh()
	return done


## Graves with a dead (FILLED / MARKED), named, by section.
func _graves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tree := get_tree() if is_inside_tree() else null
	var graveyard := tree.get_first_node_in_group(GRAVEYARD_GROUP) if tree != null else null
	if graveyard == null or not graveyard.has_method(&"graves"):
		return out
	for g: GraveRecord in graveyard.call(&"graves"):
		if g.state != GraveRecord.State.FILLED and g.state != GraveRecord.State.MARKED:
			continue
		var section := Database.section(StringName(str(graveyard.call(&"section_of", g.id)))) as SectionData if graveyard.has_method(&"section_of") else null
		out.append({"choice": g.id, "text": Phase8Status.dead_name(tree, g.id),
				"meta": Phase8Texts.FAVOR_GRAVE_META % [section.display_name if section != null else "", g.id], "icon": ""})
	return out
