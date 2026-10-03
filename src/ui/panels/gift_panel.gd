class_name GiftPanel
extends UIPanel
## &"gift" – a gift for a villager (docs/PHASE7_DESIGN.md §2.4, §7): context {npc_id, speaker, inventory,
## player} (dialogue action open_gifts). Lists what the gravekeeper carries that could be given (goods,
## materials, crafted things – no coins, tools or specimens); what the person likes is marked once a gift
## of that kind was accepted (UI knowledge flag gifts_known_<npc>, also read by the Merkbuch page
## „Hollerbrück"). „Schenken" → Relationships.give_gift (once a day); a gift the person does not care for
## is turned down kindly with Relationships' reason – nothing leaves the pack then.

const RELATIONSHIPS_GROUP := &"relationships"
const EXCLUDED: Array[StringName] = [&"coin"]
const ROWS_MAX := 9

@export var panel_width: float = 980.0
@export var icon_edge: float = 40.0

var npc_id: StringName = &""
var title_label: Label
var rel_label: Label
var list_box: VBoxContainer
var empty_label: Label
var reply_label: Label
## item -> {row, button}
var rows: Dictionary[StringName, Dictionary] = {}
var reply: String = ""

var _inventory: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	var head := UIKit.hbox(16)
	title_label = UIKit.label("", &"HeaderLabel")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	rel_label = UIKit.label("", &"AccentLabel")
	rel_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rel_label)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	var intro := UIKit.label(Phase7Texts.GIFT_INTRO, &"WhisperLabel", true)
	intro.custom_minimum_size.x = panel_width - 80.0
	box.add_child(intro)
	list_box = UIKit.vbox(6)
	box.add_child(list_box)
	empty_label = UIKit.label(Phase7Texts.GIFT_NOTHING, &"DimLabel", true)
	box.add_child(empty_label)
	reply_label = UIKit.label("", &"WhisperLabel", true)
	reply_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(reply_label)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	bottom.add_child(UIKit.spacer())
	var back := UIKit.button(TEXT_CLOSE)
	back.pressed.connect(request_close)
	bottom.add_child(back)
	box.add_child(bottom)


func _on_opened() -> void:
	npc_id = StringName(str(context.get("npc_id", "")))
	if npc_id == &"":
		var speaker: Variant = context.get("speaker")
		if is_instance_valid(speaker):
			npc_id = StringName(str((speaker as Node).get(&"npc_id")))
	reply = ""
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


func _refresh() -> void:
	title_label.text = Phase7Texts.GIFT_TITLE % Phase7Texts.person_name(npc_id)
	var rel := _relationships()
	rel_label.text = Phase7Texts.rel_line(rel.value(npc_id), rel.tier(npc_id)) if rel != null and rel.met(npc_id) else ""
	UIKit.clear_children(list_box)
	rows.clear()
	var known := liked_known(npc_id)
	var liked := liked_items(npc_id)
	var items := giftable(_inventory)
	# Known favourites first.
	items.sort_custom(func(a: StringName, b: StringName) -> bool:
		var la := known and liked.has(a)
		var lb := known and liked.has(b)
		return la and not lb if la != lb else String(a) < String(b))
	for i: int in mini(items.size(), ROWS_MAX):
		var item := items[i]
		var row := UIKit.panel(&"TradeRowPanel")
		var line := UIKit.hbox(12)
		line.add_child(UIKit.icon(Database.icon(item), icon_edge))
		var name := UIKit.label("%s ×%d" % [UIKit.item_name(item), _inventory.count(item)], &"")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(name)
		if known and liked.has(item):
			var tag := UIKit.label(Phase7Texts.GIFT_LIKED, &"GoodLabel")
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(tag)
		var b := UIKit.button(Phase7Texts.GIFT_BUTTON)
		var reason := block_reason(item)
		b.disabled = action_running or (reason != "" and reason != Relationships.TEXT_GIFT_DISLIKED)
		b.tooltip_text = reason if reason != Relationships.TEXT_GIFT_DISLIKED else ""
		b.pressed.connect(give.bind(item))
		line.add_child(b)
		row.add_child(line)
		list_box.add_child(row)
		rows[item] = {"row": row, "button": b}
	empty_label.visible = items.is_empty()
	reply_label.text = reply
	reply_label.visible = reply != ""


## Relationships.gift_block_reason ("" = she or he takes it).
func block_reason(item: StringName) -> String:
	var rel := _relationships()
	if rel == null:
		return Relationships.TEXT_GIFT_UNKNOWN
	return rel.gift_block_reason(npc_id, item, _inventory)


## Gives one `item` (Relationships.give_gift). A dislike is answered politely, nothing changes.
func give(item: StringName) -> bool:
	var rel := _relationships()
	if rel == null or _inventory == null:
		return false
	var reason := block_reason(item)
	if reason != "":
		reply = "„%s“" % reason if reason == Relationships.TEXT_GIFT_DISLIKED else reason
		refresh()
		return false
	var ok := rel.give_gift(npc_id, item, _inventory)
	if ok:
		GameState.set_flag(StringName(Phase7Texts.GIFT_KNOWN_FLAG % npc_id), true)
		reply = Phase7Texts.GIFT_THANKS
	refresh()
	return ok


## Stackable things in `inv` one could give (no coins, tools, unique pieces).
static func giftable(inv: Inventory) -> Array[StringName]:
	var out: Array[StringName] = []
	if inv == null:
		return out
	for slot: Dictionary in inv.get_slots():
		var id := StringName(str(slot.get("id", "")))
		if id == &"" or id in EXCLUDED or out.has(id):
			continue
		var data := Database.item(id) as ItemData if Database.has_item(id) else null
		if data != null and (data.unique or data.category == ItemData.Category.TOOL):
			continue
		out.append(id)
	return out


## The person's liked items have been found out (a gift was accepted once).
static func liked_known(id: StringName) -> bool:
	return GameState.flag_on(StringName(Phase7Texts.GIFT_KNOWN_FLAG % id))


static func liked_items(id: StringName) -> Array[StringName]:
	var data := Database.villager(id) as VillagerData
	return data.gifts_liked.duplicate() if data != null else [] as Array[StringName]


func _relationships() -> Relationships:
	return get_tree().get_first_node_in_group(RELATIONSHIPS_GROUP) as Relationships if is_inside_tree() else null
