class_name Desk
extends Node3D
## The gravekeeper's desk with the grave register (docs §11). [E] opens &"grave_register" with
## {entries, total, rating}; one entry per grave holding a corpse (Graveyard records + the
## CorpseManager's CorpseRecords): {name, age, cause_label, day_buried, grave_id, quality,
## marker_label}. Old graves have no record and are not listed.

const PANEL := &"grave_register"
const PROMPT_READ := "[E] Grabregister lesen"
## W3 (QA8-04, docs/PHASE8_DESIGN.md §2.4, §2.11): while an accepted order asks for a register extract the
## gravekeeper has not copied yet, [E] copies one (GraveCareConfig.extract_minutes, 1 ink) – reading again after.
const PROMPT_COPY := "[E] Namen für %s abschreiben (%d Min, 1 Tinte)"
const PROMPT_COPY_NO_INK := "Namen für %s abschreiben: keine Tinte"
const LABEL_COPY := "Namen abschreiben"
const ANIM_COPY := &"interact"
const ORDERS_GROUP := &"orders"
const GRAVEYARD_GROUP := &"graveyard"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const SCORE_GROUP := &"cemetery_score"
const GHOSTS_GROUP := &"ghosts"
const MINUTES_PER_DAY := 1440
# Phase 9 (docs/PHASE9_DESIGN.md §1.3, §2.2.3, §2.2.7, §2.4.3, §7.5; P3 – the prompts of P4's chain too): after the
# extract copy, in this order – read Lorenz' ledger (H1) · compare the register with the list (H2) · write the nameless
# letter (ending A, from H5 on) · write an answer (a letter that can be answered, 1 ink). Each only with its system in
# the tree; none of them → the register as before.
const WHO_KNOWS_GROUP := &"who_knows"
const QUESTS_GROUP := &"quests"
const LETTERS_GROUP := &"letters"
const MAIN_QUEST := &"q_who_knows"
const NOTE_REGISTER := &"register_compared"
const P9_KLADDE := &"kladde"
const P9_REGISTER := &"register"
const P9_NAMELESS := &"nameless"
const P9_ANSWER := &"answer"
const NAMELESS_ITEM := &"nameless_letter"
const PROMPT_KLADDE := "[E] Lorenz' Kladde lesen (%d Min)"
const PROMPT_REGISTER_LIST := "[E] Grabregister mit der Liste vergleichen (%d Min)"
const PROMPT_NAMELESS := "[E] Brief ohne Namen schreiben (%d Min)"
const PROMPT_ANSWER := "[E] Antwort schreiben (%d Min)"
const LABEL_KLADDE := "Lorenz' Kladde lesen"
const LABEL_REGISTER_LIST := "Grabregister vergleichen"
const LABEL_NAMELESS := "Brief ohne Namen schreiben"
const LABEL_ANSWER := "Antwort schreiben"
const TEXT_REGISTER_NONE := "Im Register steht keiner, der zu einem Datum passt."
const TEXT_REGISTER := "Neben den Daten stehen jetzt Namen: %s."
const TEXT_NAMELESS := "Ein Brief ohne Namen. Die Hand ist nicht deine. Sie soll es nicht sein."
const ANIM_READ_BOOK := &"read_book"
const ANIM_WRITE := &"write_letter"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy()


func get_interaction_prompt(player: Player) -> String:
	var giver := extract_wanted_by(player)
	if giver != "":
		var cfg := _care_config()
		if player.inventory == null or not player.inventory.has(cfg.line_item):
			return PROMPT_COPY_NO_INK % giver
		return PROMPT_COPY % [giver, cfg.extract_minutes]
	var p9 := phase9_action(player)
	if p9 != &"":
		return phase9_prompt(p9)
	return PROMPT_READ


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	if extract_wanted_by(player) != "":
		var cfg := _care_config()
		if player.inventory != null and player.inventory.has(cfg.line_item):
			player.start_timed_action(LABEL_COPY, cfg.extract_minutes, _finish_copy.bind(player), true,
					ToolAnimConfig.clip_for(&"desk_copy", ANIM_COPY))
		return
	var p9 := phase9_action(player)
	if p9 != &"":
		_start_phase9(p9, player)
		return
	EventBus.ui_panel_requested.emit(PANEL, register_context())


## Phase 9: the desk work of now for `player` (&"" = none – the register opens).
func phase9_action(player: Player) -> StringName:
	if player == null:
		return &""
	var inv := player.inventory
	var who := _first(WHO_KNOWS_GROUP)
	var quests := _first(QUESTS_GROUP)
	if who != null and quests != null:
		var step := StringName(str(quests.call(&"current_step", MAIN_QUEST)))
		var ended := StringName(str(quests.call(&"ending", MAIN_QUEST))) != &""
		if not ended and step == &"h1" and str(who.call(&"read_block_reason", inv)) == "":
			return P9_KLADDE
		if not ended and step == &"h2" and (quests.call(&"notes", NOTE_REGISTER) as PackedStringArray).is_empty():
			return P9_REGISTER
		if not ended and step in [&"h5", &"h6"] and inv != null and inv.has(_who_cfg(who).letter_item) \
				and not inv.has(NAMELESS_ITEM) and not bool(who.call(&"letter_posted")):
			return P9_NAMELESS
	var letters := _first(LETTERS_GROUP) as Letters
	if letters != null and inv != null and inv.has(letters.get_config().answer_item) and letters.answerable(inv) != "":
		return P9_ANSWER
	return &""


func phase9_prompt(action: StringName) -> String:
	match action:
		P9_KLADDE:
			return PROMPT_KLADDE % _who_cfg(_first(WHO_KNOWS_GROUP)).kladde_minutes
		P9_REGISTER:
			return PROMPT_REGISTER_LIST % _who_cfg(_first(WHO_KNOWS_GROUP)).register_minutes
		P9_NAMELESS:
			return PROMPT_NAMELESS % _who_cfg(_first(WHO_KNOWS_GROUP)).letter_minutes
		P9_ANSWER:
			var letters := _first(LETTERS_GROUP) as Letters
			return PROMPT_ANSWER % (letters.get_config().answer_minutes if letters != null else 20)
	return ""


func _start_phase9(action: StringName, player: Player) -> void:
	var cfg := _who_cfg(_first(WHO_KNOWS_GROUP))
	match action:
		P9_KLADDE:
			player.start_timed_action(LABEL_KLADDE, cfg.kladde_minutes, _finish_phase9.bind(action, player), true,
					ToolAnimConfig.clip_for(&"desk_read_book", ANIM_READ_BOOK))
		P9_REGISTER:
			player.start_timed_action(LABEL_REGISTER_LIST, cfg.register_minutes, _finish_phase9.bind(action, player), true,
					ToolAnimConfig.clip_for(&"desk_read_book", ANIM_READ_BOOK))
		P9_NAMELESS:
			player.start_timed_action(LABEL_NAMELESS, cfg.letter_minutes, _finish_phase9.bind(action, player), true,
					ToolAnimConfig.clip_for(&"desk_write_letter", ANIM_WRITE))
		P9_ANSWER:
			var letters := _first(LETTERS_GROUP) as Letters
			var minutes := letters.get_config().answer_minutes if letters != null else 20
			player.start_timed_action(LABEL_ANSWER, minutes, _finish_phase9.bind(action, player), true,
					ToolAnimConfig.clip_for(&"desk_write_letter", ANIM_WRITE))


func _finish_phase9(action: StringName, player: Player) -> void:
	var inv := player.inventory if is_instance_valid(player) else null
	var who := _first(WHO_KNOWS_GROUP)
	var quests := _first(QUESTS_GROUP)
	match action:
		P9_KLADDE:
			if who != null:
				who.call(&"read_kladde")
		P9_REGISTER:
			if who == null:
				return
			var matched := who.call(&"compare_register") as PackedStringArray
			EventBus.notification_requested.emit(TEXT_REGISTER % ", ".join(matched) if not matched.is_empty() else TEXT_REGISTER_NONE,
					&"info")
			if quests != null:
				quests.call(&"note", NOTE_REGISTER, "")
		P9_NAMELESS:
			var item := _who_cfg(who).letter_item
			if inv == null or not inv.remove_item(item, 1):
				return
			if inv.add_item(NAMELESS_ITEM, 1) > 0:
				inv.add_item(item, 1)
				return
			EventBus.notification_requested.emit(TEXT_NAMELESS, &"info")
		P9_ANSWER:
			var letters := _first(LETTERS_GROUP) as Letters
			if letters == null or inv == null:
				return
			var uid := letters.answerable(inv)
			if uid != "":
				letters.decide(uid, &"answer", {"inventory": inv, "place": &"desk"})


static func _who_cfg(who: Node) -> WhoKnowsConfig:
	var cfg := who.get(&"config") as WhoKnowsConfig if who != null else null
	if cfg == null:
		cfg = Database.config(&"who_knows_config") as WhoKnowsConfig
	return cfg if cfg != null else WhoKnowsConfig.new()


## The short name of the giver of an accepted order that still needs a register extract from `player`
## ("" = none: every such order is covered by the extracts in the bag).
func extract_wanted_by(player: Player) -> String:
	var orders := _first(ORDERS_GROUP) as Orders
	if orders == null or player == null or player.inventory == null:
		return ""
	var item := _care_config().extract_item
	var needed := 0
	var giver := ""
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o == null or o.kind != &"deliver" or not o.items.has(item):
			continue
		needed += int(o.items[item])
		if giver == "":
			giver = _short_name(o.giver)
	return giver if needed > player.inventory.count(item) else ""


func _finish_copy(player: Player) -> void:
	var cfg := _care_config()
	var inv := player.inventory
	if inv == null or not inv.remove_item(cfg.line_item, 1):
		return
	# add_item answers what did not fit: a full bag keeps the ink.
	if inv.add_item(cfg.extract_item, 1) > 0:
		inv.add_item(cfg.line_item, 1)


static func _short_name(villager_id: StringName) -> String:
	return Phase7Texts.short_name(villager_id)


func _care_config() -> GraveCareConfig:
	var cfg := Database.config(&"grave_care_config") as GraveCareConfig
	return cfg if cfg != null else GraveCareConfig.new()


## {entries, total, rating} of the current world (empty register without the systems).
## Phase 3: total / rating from CemeteryScore (graves + decor − dirt) when present; entries of
## graves whose ghost was listened to carry "mood" (GhostMood label, §7 column „Stimmung“).
func register_context() -> Dictionary:
	var graveyard := _first(GRAVEYARD_GROUP) as Graveyard
	var corpses := _first(CORPSE_MANAGER_GROUP) as CorpseManager
	var score := _first(SCORE_GROUP) as CemeteryScore
	var ghosts := _first(GHOSTS_GROUP) as GhostManager
	var entries := register_entries(graveyard, corpses)
	if ghosts != null:
		for entry: Dictionary in entries:
			var id := str(entry.grave_id)
			if ghosts.was_heard(id) and ghosts.mood_of(id) != &"":
				entry["mood"] = GhostMood.label(ghosts.mood_of(id))
	var total := graveyard.total_quality() if graveyard != null else 0
	var rating := graveyard.rating() if graveyard != null else CemeteryRating.NEGLECTED
	if score != null:
		total = score.total()
		rating = score.rating()
	return {"entries": entries, "total": total, "rating": rating}


## Entries of every FILLED / MARKED grave whose corpse record is known, in grave order.
static func register_entries(graveyard: Graveyard, corpses: CorpseManager) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if graveyard == null or corpses == null:
		return out
	var tables := corpses.tables if corpses.tables != null else Database.corpse_tables() as CorpseTables
	for grave: GraveRecord in graveyard.graves():
		if grave.corpse_id == "" or not grave.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED]:
			continue
		var record := corpses.get_record(grave.corpse_id)
		if record == null:
			continue
		var cause: Dictionary = tables.get_cause(record.cause_id) if tables != null else {}
		out.append({
			"name": record.display_name,
			"age": record.age,
			"cause_label": str(cause.get("label", record.cause_id)),
			"day_buried": record.buried_day if record.buried_day > 0 else _arrival_day(record),
			"grave_id": grave.id,
			"quality": grave.quality if grave.state == GraveRecord.State.MARKED else 0,
			"marker_label": _marker_label(grave.marker_id),
		})
	return out


@warning_ignore("integer_division")
static func _arrival_day(record: CorpseRecord) -> int:
	return record.arrival_total_minutes / MINUTES_PER_DAY + 1


static func _marker_label(marker_id: StringName) -> String:
	if marker_id == &"":
		return ""
	var item := Database.item(marker_id) as ItemData if Database.has_item(marker_id) else null
	return item.display_name if item != null and item.display_name != "" else String(marker_id)


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null
