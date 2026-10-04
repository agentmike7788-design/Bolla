class_name HudBuilder
extends RefCounted
## Widget builders for the permanent HUD (GameHud, docs §7): the clock panel (day, clock,
## sun/moon, objective, delivery notice), the resource panel (item chips + cemetery quality)
## and the bottom column (timed-action bar + interaction prompt). Static: each builder adds
## its nodes to the HUD and stores the widgets in the HUD's public fields; GameHud keeps the
## signal wiring and the updates. Layout values come from the HUD's exports.


static func build_clock_panel(hud: GameHud) -> void:
	var panel := UIKit.panel(&"HudPanel")
	panel.name = "ClockPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(hud.margin, hud.margin)
	panel.custom_minimum_size.x = hud.top_panel_width
	hud.add_child(panel)
	var box := UIKit.vbox(6)
	panel.add_child(box)
	var row := UIKit.hbox(14)
	hud.day_icon = DayIcon.new()
	hud.day_icon.custom_minimum_size = Vector2(52, 52)
	row.add_child(hud.day_icon)
	var texts := UIKit.vbox(0)
	hud.day_label = UIKit.label("", &"HudDimLabel")
	hud.clock_label = UIKit.label("", &"HudClockLabel")
	texts.add_child(hud.day_label)
	texts.add_child(hud.clock_label)
	row.add_child(texts)
	row.add_child(UIKit.spacer())
	# Phase 4 §7: the book beside the day with the unread count (hidden without a journal).
	hud.journal_badge = UIKit.hbox(8)
	hud.journal_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.journal_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.journal_badge.add_child(JournalBookIcon.new())
	hud.journal_label = UIKit.label("", &"HudDimLabel")
	hud.journal_badge.add_child(hud.journal_label)
	hud.journal_badge.visible = false
	row.add_child(hud.journal_badge)
	hud.map_badge = MapBadge.new()
	row.add_child(hud.map_badge)
	box.add_child(row)
	box.add_child(UIKit.separator())
	var objective_row := UIKit.hbox(10)
	var marker := UIKit.label("◆", &"AccentLabel")
	marker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	objective_row.add_child(marker)
	hud.objective_label = UIKit.label("", &"HudLabel", true)
	hud.objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.objective_label.custom_minimum_size.x = hud.top_panel_width - 80.0
	objective_row.add_child(hud.objective_label)
	box.add_child(objective_row)
	hud.notice_label = UIKit.label("", &"WarningLabel", true)
	hud.notice_label.custom_minimum_size.x = hud.top_panel_width - 40.0
	hud.notice_label.visible = false
	box.add_child(hud.notice_label)


## Returns the chips: item id -> {chip: Control, count: Label, caption: Label (crafted items only)}.
static func build_resource_panel(hud: GameHud) -> Dictionary[StringName, Dictionary]:
	var chip_map: Dictionary[StringName, Dictionary] = {}
	var panel := UIKit.panel(&"HudPanel")
	panel.name = "ResourcePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -hud.margin
	panel.offset_right = -hud.margin
	panel.offset_top = hud.margin
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(panel)
	var box := UIKit.vbox(8)
	panel.add_child(box)
	var chips := UIKit.hbox(20)
	chips.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(chips)
	for id: StringName in item_order():
		var chip := UIKit.hbox(6)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.tooltip_text = UIKit.item_name(id)
		chip.add_child(UIKit.icon(Database.icon(id), hud.icon_edge))
		var count := UIKit.label("0", &"HudLabel")
		count.custom_minimum_size.x = 26.0
		chip.add_child(count)
		var entry := {"chip": chip, "count": count}
		if not id in GameHud.BASE_ITEMS:
			# Crafted items: their name under the icon (shroud and linen look alike).
			var column := UIKit.vbox(0)
			column.mouse_filter = Control.MOUSE_FILTER_PASS
			column.tooltip_text = chip.tooltip_text
			column.add_child(chip)
			var caption := UIKit.label(UIKit.item_name(id), &"HudCaptionLabel")
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(caption)
			entry = {"chip": column, "count": count, "caption": caption}
		var holder: Control = entry.chip
		# Top-aligned, so captioned and plain chips keep their icons on one line.
		holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		chips.add_child(holder)
		holder.visible = id in GameHud.BASE_ITEMS
		chip_map[id] = entry
	var quality_row := UIKit.hbox(10)
	quality_row.alignment = BoxContainer.ALIGNMENT_END
	# Hover target of the quality tooltip (Phase 3 §7); the labels ignore the mouse.
	quality_row.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.quality_row = quality_row
	hud.quality_caption = UIKit.label(GameHud.TEXT_QUALITY_CAPTION, &"HudDimLabel")
	quality_row.add_child(hud.quality_caption)
	hud.quality_label = UIKit.label("", &"HudLabel")
	quality_row.add_child(hud.quality_label)
	hud.next_tier_label = UIKit.label("", &"HudDimLabel")
	quality_row.add_child(hud.next_tier_label)
	box.add_child(quality_row)
	box.add_child(build_reputation_row(hud))
	return chip_map


## "Ruf  Geachtet ▲" + slim 0–100 bar with tier ticks (Phase 3 §7); tooltip = the effects.
static func build_reputation_row(hud: GameHud) -> Control:
	var row := UIKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.reputation_row = row
	row.add_child(UIKit.label(GameHud.TEXT_REPUTATION_CAPTION, &"HudDimLabel"))
	hud.reputation_label = UIKit.label("", &"HudLabel")
	row.add_child(hud.reputation_label)
	hud.reputation_arrow = UIKit.label("", &"HudDimLabel")
	row.add_child(hud.reputation_arrow)
	hud.reputation_meter = ReputationMeter.new()
	hud.reputation_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hud.reputation_meter)
	return row


static func build_bottom(hud: GameHud) -> void:
	var column := UIKit.vbox(12)
	column.name = "BottomColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_bottom = -hud.margin * 2.0
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.alignment = BoxContainer.ALIGNMENT_END
	hud.add_child(column)
	hud.action_panel = UIKit.panel(&"HudPanel")
	hud.action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.action_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var action_box := UIKit.vbox(6)
	hud.action_label = UIKit.label("", &"HudLabel")
	hud.action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_box.add_child(hud.action_label)
	hud.action_bar = UIKit.bar()
	hud.action_bar.custom_minimum_size = Vector2(hud.action_bar_width, 20.0)
	action_box.add_child(hud.action_bar)
	hud.action_panel.add_child(action_box)
	hud.action_panel.visible = false
	column.add_child(hud.action_panel)
	hud.prompt_panel = UIKit.panel(&"HudPanel")
	hud.prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var prompt_row := UIKit.hbox(12)
	hud.prompt_key = UIKit.keycap(GameHud.KEY_INTERACT)
	hud.prompt_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(hud.prompt_key)
	hud.prompt_label = UIKit.label("", &"PromptLabel")
	prompt_row.add_child(hud.prompt_label)
	hud.prompt_panel.add_child(prompt_row)
	hud.prompt_panel.visible = false
	column.add_child(hud.prompt_panel)
	hud.build_bar = BuildBar.new()
	hud.build_bar.name = "BuildBar"
	column.add_child(hud.build_bar)


## Base items first, then every crafted item (sorted by id).
static func item_order() -> Array[StringName]:
	var out: Array[StringName] = GameHud.BASE_ITEMS.duplicate()
	var crafted: Array[StringName] = []
	for item: Resource in Database.items():
		var data := item as ItemData
		if data != null and data.category == ItemData.Category.CRAFTED and not data.id in out:
			crafted.append(data.id)
	crafted.sort()
	out.append_array(crafted)
	return out


## Small closed book (HUD journal badge); a candle-amber bookmark when something is unread.
class JournalBookIcon extends Control:
	var unread: bool = false:
		set(value):
			unread = value
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(26.0, 30.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cover := Color(0.42, 0.31, 0.22, 1.0)
		var pages := Color(0.87, 0.8, 0.65, 1.0)
		var r := Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))
		draw_rect(Rect2(r.position + Vector2(3.0, 2.0), r.size - Vector2(3.0, 2.0)), pages)
		draw_rect(Rect2(r.position, r.size - Vector2(3.0, 2.0)), cover)
		draw_line(r.position + Vector2(4.0, 1.0), r.position + Vector2(4.0, r.size.y - 3.0), Color(0.2, 0.13, 0.09, 1.0), 2.0)
		if unread:
			var x := r.position.x + r.size.x - 9.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0.0), Vector2(x + 5.0, 0.0), Vector2(x + 5.0, 12.0),
					Vector2(x + 2.5, 9.0), Vector2(x, 12.0)]), Color(0.949, 0.663, 0.231, 1.0))
