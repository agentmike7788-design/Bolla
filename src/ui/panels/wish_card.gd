class_name WishCard
extends UIPanel
## &"wish_card" – a visitor's wish in the talk at the grave (docs/PHASE8_DESIGN.md §2.2.5, §7.2): context
## {offer {wish_id, kind, grave_id, text}, kin_id, speaker, inventory, player} (dialogue action wish_offer).
## Shows the visitor (portrait, name), the grave („Hedwig Lamprecht, Lindenacker"), the wish as a quote, its
## kind as a symbol (flower, candle, rake, chisel, vase), where it comes from (G8 Runde 1: offer.source), the deadline „bis zum nächsten Besuch (≈ in 3
## Tagen)" and the thanks without a number („Die Kehrs werden es dir danken."). „Das mache ich." →
## Visitors.accept_wish; „Ich kann es nicht versprechen." closes. With three wishes open already both are
## dimmed: „Drei Wünsche sind schon offen."

const VISITORS_GROUP := &"visitors"
const GRAVEYARD_GROUP := &"graveyard"

@export var panel_width: float = 860.0
@export var portrait_edge: float = 96.0
@export var kind_icon_edge: float = 56.0

var visitors: Visitors
var wish_id: String = ""
var kind: StringName = &""
var grave_id: String = ""
var kin_id: StringName = &""
var name_label: Label
var grave_label: Label
var quote_label: Label
var kind_label: Label
var kind_icon: TextureRect
var line_label: Label
var origin_label: Label
var deadline_label: Label
var reward_label: Label
var full_label: Label
var portrait: TextureRect
var accept_button: Button
var decline_button: Button
var accepted: bool = false


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	var head := UIKit.hbox(16)
	portrait = UIKit.icon(null, portrait_edge)
	head.add_child(portrait)
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.label(Phase8Texts.WISH_TITLE, &"DimLabel"))
	name_label = UIKit.label("", &"HeaderLabel")
	titles.add_child(name_label)
	grave_label = UIKit.label("", &"SubheaderLabel")
	titles.add_child(grave_label)
	head.add_child(titles)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	var card := UIKit.panel(&"CardPanel")
	var card_box := UIKit.hbox(18)
	var kind_col := UIKit.vbox(4)
	kind_icon = UIKit.icon(null, kind_icon_edge)
	kind_col.add_child(kind_icon)
	kind_label = UIKit.label("", &"InkDimLabel")
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_col.add_child(kind_label)
	card_box.add_child(kind_col)
	var text_col := UIKit.vbox(8)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quote_label = UIKit.label("", &"InkLabel", true)
	quote_label.custom_minimum_size.x = panel_width - 220.0
	text_col.add_child(quote_label)
	line_label = UIKit.label("", &"InkHeaderLabel", true)
	text_col.add_child(line_label)
	# G8 Runde 1 (B8-2): where the thing comes from (WishData.source_text – the vase: the workbench, Theres' seeds).
	origin_label = UIKit.label("", &"InkDimLabel", true)
	origin_label.custom_minimum_size.x = panel_width - 220.0
	text_col.add_child(origin_label)
	card_box.add_child(text_col)
	card.add_child(card_box)
	box.add_child(card)
	deadline_label = UIKit.label("", &"AccentLabel")
	box.add_child(deadline_label)
	reward_label = UIKit.label("", &"DimLabel")
	box.add_child(reward_label)
	full_label = UIKit.label(Phase8Texts.WISH_FULL, &"WarningLabel")
	box.add_child(full_label)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	bottom.add_child(UIKit.spacer())
	decline_button = UIKit.button(Phase8Texts.WISH_DECLINE)
	decline_button.pressed.connect(decline)
	bottom.add_child(decline_button)
	accept_button = UIKit.button(Phase8Texts.WISH_ACCEPT, &"AccentButton")
	accept_button.pressed.connect(accept)
	bottom.add_child(accept_button)
	box.add_child(bottom)


func _on_opened() -> void:
	var v: Variant = context.get("visitors")
	visitors = v if is_instance_valid(v) else (get_tree().get_first_node_in_group(VISITORS_GROUP) as Visitors if is_inside_tree() else null)
	var offer: Dictionary = context.get("offer", {}) if context.get("offer") is Dictionary else {}
	wish_id = str(offer.get("wish_id", ""))
	kind = StringName(str(offer.get("kind", "")))
	grave_id = str(offer.get("grave_id", ""))
	kin_id = StringName(str(context.get("kin_id", "")))
	if kin_id == &"" and visitors != null:
		kin_id = visitors.kin_for_grave(grave_id)
	accepted = false


func _refresh() -> void:
	var offer: Dictionary = context.get("offer", {}) if context.get("offer") is Dictionary else {}
	portrait.texture = Database.icon(Phase8Texts.kin_portrait(kin_id))
	name_label.text = Phase8Texts.person_name(kin_id)
	grave_label.text = Phase8Texts.grave_title(Phase8Status.dead_name(get_tree() if is_inside_tree() else null, grave_id), grave_id,
			_section_of(grave_id))
	quote_label.text = Phase8Texts.WISH_QUOTE % str(offer.get("text", ""))
	kind_label.text = Phase8Texts.wish_kind_label(kind)
	var icon_id := Phase8Texts.wish_icon(kind)
	kind_icon.texture = Database.icon(icon_id) if icon_id != &"" else null
	var line := line_text()
	line_label.text = Phase8Texts.WISH_LINE % line if line != "" else ""
	line_label.visible = line != ""
	var origin := str(offer.get("source", ""))
	origin_label.text = Phase8Texts.WISH_SOURCE % origin if origin != "" else ""
	origin_label.visible = origin != ""
	deadline_label.text = Phase8Texts.wish_deadline(days_to_next_visit())
	reward_label.text = Phase8Texts.wish_reward(kin_id)
	var full := is_full()
	full_label.visible = full and not accepted
	accept_button.disabled = full or accepted or action_running or wish_id == ""
	decline_button.disabled = accepted
	accept_button.text = Phase8Texts.WISH_ACCEPTED if accepted else Phase8Texts.WISH_ACCEPT


## Three (VisitorConfig.max_open) other wishes are open already.
func is_full() -> bool:
	if visitors == null:
		return false
	var others := 0
	for w: Dictionary in visitors.open_wishes():
		if str(w.get("wish_id", "")) != wish_id:
			others += 1
	var cfg := visitors.config if visitors.config != null else VisitorConfig.new()
	return others >= cfg.max_open


## The inscription line of a wish of kind line ("" otherwise).
func line_text() -> String:
	if visitors == null or kind != WishRules.KIND_LINE:
		return ""
	for w: Dictionary in visitors.open_wishes():
		if str(w.get("wish_id", "")) == wish_id:
			return str(w.get("line", ""))
	return ""


## Days until the visitor comes again (the wish's deadline): the visit rules with today as the last look.
func days_to_next_visit() -> int:
	var tree := get_tree() if is_inside_tree() else null
	var kin := Database.kin(kin_id) as KinData if kin_id != &"" else null
	var cfg := visitors.config if visitors != null and visitors.config != null else VisitorConfig.new()
	var today := TimeManager.day
	if kin != null and kin.villager_id != &"" and kin.visit_every_days > 0:
		return kin.visit_every_days
	var open_day := int(GameState.get_flag(&"p8_open_day", today))
	var next := VisitRules.next_due(grave_id, Phase8Status.buried_day(tree, grave_id), today, open_day, cfg)
	return maxi(next - today, 1)


## „Das mache ich.": Visitors.accept_wish, then the card closes.
func accept() -> bool:
	if visitors == null or wish_id == "" or is_full() or accepted:
		return false
	accepted = visitors.accept_wish(wish_id)
	refresh()
	if accepted:
		request_close()
	return accepted


func decline() -> void:
	request_close()


func _section_of(id: String) -> StringName:
	var graveyard := get_tree().get_first_node_in_group(GRAVEYARD_GROUP) if is_inside_tree() else null
	if graveyard != null and graveyard.has_method(&"section_of"):
		return StringName(str(graveyard.call(&"section_of", id)))
	return &""
