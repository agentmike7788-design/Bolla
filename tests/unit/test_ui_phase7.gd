extends TestCase
## W-UI Phase 7 (docs/PHASE7_DESIGN.md §6, §7, §10): the shop, gift, orders, anatomist, lecture, pult,
## collection and deduction panels (values and reasons = the systems), the specimen card at the crypt
## table (seven rows, the limit of three, two-stage, the consequence line, where the piece is), the veil
## on screen_veil_changed, the region name, the remark bubble, the Merkbuch pages „Aufträge" /
## „Hollerbrück" and „Ursache deuten" on the death note, the objective lines, the register / day summary /
## chapter panel additions and the debug commands. Systems come from Phase7Fixtures or small doubles –
## no village scene is needed.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const SHELF_SCENE := "res://src/entities/collection_shelf/collection_shelf.tscn"
const STORE_SCENE := "res://src/entities/pult_store/pult_store.tscn"


class FakePlayer extends Node3D:
	var inventory: Inventory
	var busy: bool = false
	var region_id: StringName = &"graveyard"
	var actions: Array = []

	func _init() -> void:
		add_to_group(&"player")

	func is_busy() -> bool:
		return busy

	## Runs the action at once and reports it like the TimedAction runner.
	func start_timed_action(label: String, minutes: int, on_done: Callable, cancellable: bool = true, _anim: StringName = &"") -> bool:
		actions.append([label, minutes, cancellable])
		EventBus.timed_action_started.emit(label, 0.0)
		on_done.call()
		EventBus.timed_action_finished.emit(true)
		return true


class ManagerDouble extends CorpseManager:
	func _ready() -> void:
		pass

	func put(r: CorpseRecord) -> void:
		_records[r.id] = r

	func refresh_decay(_id: String) -> void:
		pass

	func notify_changed(_id: String) -> void:
		pass


class CareDouble extends CorpseCare:
	var reasons: Dictionary = {}

	func organ_block_reason(_id: String, organ: StringName, _container: StringName, _inv: Inventory) -> String:
		return str(reasons.get(organ, ""))

	func get_anatomy_config() -> AnatomyConfig:
		return Phase7Fixtures.anatomy_config()


## MorgueTable double: a fixed Phase-4 panel_state() and the organ requests.
class TableDouble extends Node3D:
	var calls: Array = []

	func panel_state() -> Dictionary:
		return {"stage": &"fresh", "freshness": 0.85, "examined": true, "steps": [], "open_steps": [], "exam_all_minutes": 0,
				"finds": [], "nothing_steps": [], "nothing_text": "", "next_loss": {}, "prep": {}, "harvest_visible": false,
				"harvest": {}}

	func panel_title() -> String:
		return "Gruft-Tisch"

	func request_organ(organ: StringName, container: StringName) -> void:
		calls.append(["organ", organ, container])


class NpcDouble extends Node3D:
	var npc_id: StringName = &""
	var region_id: StringName = &"village"

	func _init() -> void:
		add_to_group(&"npc")


class JournalDouble extends Node:
	var list: Array[Dictionary] = []

	func _init() -> void:
		add_to_group(&"journal")

	func people() -> Array[Dictionary]:
		return list


var ui: UIRoot
var player: FakePlayer
var inv: Inventory
var world: Node3D
var manager: ManagerDouble
var specimens: Specimens
var rel: Relationships
var corpse: CorpseRecord


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	Debug.reset()
	TimeManager.load_state({"day": 3, "minute_of_day": 600})


func after_each() -> void:
	if is_instance_valid(ui):
		ui.close_all()
		ui.queue_free()
	for node: Node in [world, player]:
		if is_instance_valid(node):
			node.queue_free()
	UIState.clear()
	GameState.reset()
	TimeManager.reset()
	Debug.reset()
	await wait_frames(1)


# --- shop -----------------------------------------------------------------------------------------

func test_shop_panel_prices_stock_buy_sell() -> void:
	await _setup()
	var shops := _shops(&"smith")
	TimeManager.load_state({"day": 3, "minute_of_day": 540})
	GameState.stats[&"reputation"] = 50
	rel = Phase7Fixtures.villager(&"smith", 45, null)
	_world().add_child(rel)
	inv.add_item(&"coin", 20)
	inv.add_item(&"charcoal", 3)
	var panel := _open(&"shop", {"shop_id": &"smith", "inventory": inv, "player": player}) as ShopPanel
	assert_true(shops.is_open(&"smith"), "Esch stands at the anvil at 09:00")
	assert_eq(panel.person_label.text, "Ulrich Esch")
	assert_eq(panel.rel_label.text, "Vertraut  ●●○○○")
	assert_eq(panel.buy_rows.size(), 3)
	assert_eq(panel.sell_rows.size(), 2)
	var bar: Dictionary = panel.buy_rows[&"iron_bar"]
	assert_true((bar.price as RichTextLabel).text.begins_with("[s][color=#b07a62]6[/color][/s] [color=#8a8f94]→[/color] [color=#f2a93b]5"),
			"trusted: the base price struck through, the new one in amber (QA7)")
	assert_eq((bar.stock as Label).text, "noch 2 heute")
	assert_true(panel.buy(&"iron_bar", 1))
	assert_eq(inv.count(&"coin"), 15)
	assert_eq(inv.count(&"iron_bar"), 1)
	assert_eq((bar.stock as Label).text, "noch 1 heute")
	assert_true((bar.five as Button).disabled, "only one left")
	assert_eq((bar.five as Button).tooltip_text, "Nur noch 1 da.")
	var coal: Dictionary = panel.sell_rows[&"charcoal"]
	assert_eq((coal.held as Label).text, "du hast 3")
	assert_eq(panel.sell(&"charcoal", 1), 1)
	assert_eq(inv.count(&"coin"), 16)
	assert_eq((coal.held as Label).text, "du hast 2")
	assert_eq(panel.reply_label.text, Phase7Texts.SHOP_AFTER_SELL)
	assert_false(panel.closed_label.visible)


func test_shop_panel_surcharge_and_closed() -> void:
	await _setup()
	var shops := _shops(&"smith")
	TimeManager.load_state({"day": 3, "minute_of_day": 540})
	GameState.stats[&"reputation"] = 0
	inv.add_item(&"coin", 3)
	var panel := _open(&"shop", {"shop_id": &"smith", "inventory": inv, "player": player}) as ShopPanel
	var fittings: Dictionary = panel.buy_rows[&"iron_fittings"]
	assert_eq((fittings.surcharge as Label).text, "+1 (Ruf)", "disreputable: one coin more")
	assert_true((fittings.surcharge as Label).visible)
	assert_true((fittings.one as Button).disabled, "4 coins needed, 3 there")
	assert_eq((fittings.one as Button).tooltip_text, ShopRules.TEXT_COINS)
	TimeManager.load_state({"day": 3, "minute_of_day": 750})
	panel.refresh()
	assert_false(shops.is_open(&"smith"), "lunch at the inn")
	assert_true(panel.closed_label.visible)
	assert_true((fittings.one as Button).disabled)
	assert_eq((fittings.one as Button).tooltip_text, VillageShops.TEXT_CLOSED)


# --- gift ---------------------------------------------------------------------------------------------

func test_gift_panel_likes_and_once_a_day() -> void:
	await _setup()
	rel = Phase7Fixtures.villager(&"innkeeper", 30, null)
	_world().add_child(rel)
	inv.add_item(&"honey_cake", 2)
	inv.add_item(&"wood", 3)
	var panel := _open(&"gift", {"npc_id": &"innkeeper", "inventory": inv, "player": player}) as GiftPanel
	assert_eq(panel.title_label.text, "Ein Geschenk für Rosine Wackernagel")
	assert_true(panel.rows.has(&"honey_cake") and panel.rows.has(&"wood"))
	assert_false(panel.give(&"wood"), "not liked: kindly turned down")
	assert_eq(panel.reply_label.text, "„Das brauch ich nicht, aber danke.“")
	assert_eq(inv.count(&"wood"), 3, "nothing left the pack")
	assert_false(GiftPanel.liked_known(&"innkeeper"))
	assert_true(panel.give(&"honey_cake"))
	assert_eq(rel.value(&"innkeeper"), 34, "+4 for a liked gift")
	assert_eq(inv.count(&"honey_cake"), 1)
	assert_true(GiftPanel.liked_known(&"innkeeper"), "now known what she likes")
	assert_true((panel.rows[&"honey_cake"].button as Button).disabled, "once a day")
	assert_eq((panel.rows[&"honey_cake"].button as Button).tooltip_text, Relationships.TEXT_GIFT_TODAY)


# --- orders -------------------------------------------------------------------------------------------

func test_orders_panel_card_accept_and_limit() -> void:
	await _setup()
	rel = Phase7Fixtures.villager(&"innkeeper", 30, null)
	_world().add_child(rel)
	var orders := _orders(&"o_rosine_berries", &"offered")
	var panel := _open(&"orders", {"board": false, "orders": [&"o_rosine_berries"] as Array[StringName], "inventory": inv,
			"player": player}) as OrdersPanel
	assert_eq(panel.title_label.text, Phase7Texts.ORDERS_TITLE_ASK)
	var card: Dictionary = panel.cards[&"o_rosine_berries"]
	assert_eq((card.checks as Label).text, "8× Holunderbeeren  0/8 –")
	assert_true((card.reward as Label).text.contains("▲ +8 Rosine"), (card.reward as Label).text)
	assert_false((card.accept as Button).disabled, (card.accept as Button).tooltip_text)
	assert_true(panel.accept(&"o_rosine_berries"))
	assert_eq(orders.state(&"o_rosine_berries"), Orders.STATE_ACCEPTED)
	card = panel.cards[&"o_rosine_berries"]
	assert_eq((card.state as Label).text, Phase7Texts.ORDER_ACCEPTED)
	assert_false((card.accept as Button).visible)
	inv.add_item(&"elderberries", 8)
	card = panel.cards[&"o_rosine_berries"]
	assert_eq((card.checks as Label).text, "8× Holunderbeeren  8/8 ✓", "refreshes on the inventory")
	assert_eq(Phase7Texts.deadline_text(Phase7Fixtures.order(&"o_rosine_berries"), 5), "noch 5 Tage")
	assert_eq(Phase7Texts.deadline_text(Phase7Fixtures.order(&"o_rosine_berries"), 1), "bis morgen früh")
	assert_eq(Phase7Texts.deadline_text(Phase7Fixtures.order(&"o_rosine_berries"), -1), "Frist: 5 Tage")


func test_orders_board_header_and_four_active() -> void:
	await _setup()
	GameState.set_flag(&"village_open", true)
	_orders(&"o_fenner_well", &"offered", {"ob_wood": "accepted", "o_esch_charcoal": "accepted", "o_quast_tincture": "accepted",
			"o_rosine_berries": "accepted"})
	var panel := _open(&"orders", {"board": true, "orders": [&"o_fenner_well"] as Array[StringName], "header": "Totengräber auf dem Hügel – Ruf: Geachtet",
			"inventory": inv, "player": player}) as OrdersPanel
	assert_eq(panel.title_label.text, Phase7Texts.ORDERS_TITLE_BOARD)
	assert_eq(panel.header_label.text, "Totengräber auf dem Hügel – Ruf: Geachtet")
	var card: Dictionary = panel.cards[&"o_fenner_well"]
	assert_true((card.accept as Button).disabled)
	assert_eq((card.reason as Label).text, "Vier Aufträge laufen schon.")
	assert_eq(panel.count_label.text, "Laufende Aufträge: 4 von 4")


# --- anatomist & lecture ------------------------------------------------------------------------------

func test_anatomist_panel_sell_and_expertise() -> void:
	await _setup()
	_anatomy_world()
	GameState.set_flag(&"anatomy_known", true)
	var lectures := Phase7Fixtures.lecture_night(3, null)
	_world().add_child(lectures)
	var heart := _take(&"heart", SpecimenRecord.CONTAINER_JAR)
	var stomach := _take(&"stomach", SpecimenRecord.CONTAINER_JAR)
	var speaker := Node3D.new()
	_world().add_child(speaker)
	var panel := _open(&"anatomist", {"speaker": speaker, "inventory": inv}) as AnatomistPanel
	assert_eq(panel.rows.size(), 2)
	var price := specimens.sale_price(heart)
	assert_eq((panel.rows[heart].sell as Button).text, "Verkaufen (%d)" % price)
	assert_eq((panel.rows[heart].expertise as Button).text, "Gutachten (30 Min)")
	assert_false((panel.rows[heart].lecture as Button).visible, "no lecture night at 10:00")
	assert_true(panel.hint_label.visible)
	assert_eq(panel.hint_label.text, "Im Dorf wird man davon hören.")
	var before := inv.count(&"coin")
	assert_eq(panel.sell(heart), price)
	assert_eq(inv.count(&"coin"), before + price)
	assert_false(panel.rows.has(heart), "sold pieces leave the list")
	assert_true(panel.request_expertise(stomach))
	assert_eq(player.actions.back()[1], 30)
	assert_true(panel.result_card.visible)
	assert_eq(panel.result_text.text, Phase7Fixtures.finding(&"b_empty_stomach").text)
	assert_true(panel.result_teaching.text.begins_with("Neuer Lehrsatz: "), panel.result_teaching.text)
	assert_true(lectures.known_teachings().has("l_stomach"))
	assert_true(panel.rows.is_empty())
	assert_true(panel.empty_label.visible)
	assert_eq(panel.empty_label.text, "„Bringen Sie mir, was die Erde nicht vermisst.“")


func test_lecture_panel_fee_veil_and_result() -> void:
	await _setup()
	_anatomy_world()
	GameState.set_flag(&"anatomy_known", true)
	var lectures := Phase7Fixtures.lecture_night(3, null)
	_world().add_child(lectures)
	var heart := _take(&"heart", SpecimenRecord.CONTAINER_JAR)
	var bundle := _take(&"liver", SpecimenRecord.CONTAINER_BUNDLE)
	TimeManager.load_state({"day": 3, "minute_of_day": 1390})
	assert_true(lectures.tonight())
	var anatomist := _open(&"anatomist", {"speaker": player, "inventory": inv}) as AnatomistPanel
	assert_true((anatomist.rows[heart].lecture as Button).visible, "lecture night: „Für die Vorlesung“")
	(anatomist.rows[heart].lecture as Button).pressed.emit()
	await wait_frames(1)
	assert_eq(ui.top(), &"lecture")
	var panel := ui.get_panel(&"lecture") as LecturePanel
	assert_eq(panel.selected, heart)
	assert_false(panel.rows.has(bundle), "no bundle on the lectern")
	assert_eq((panel.rows[heart].fee as Label).text, "Honorar %d Münzen" % lectures.fee_for(heart))
	assert_ne(panel.night_label.text, "")
	assert_eq(panel.hold_button.text, "Vorlesung halten (60 Min)")
	var seen := []
	var before := inv.count(&"coin")
	ui.veil.visibility_changed.connect(func() -> void: seen.append(ui.veil.active))
	assert_true(panel.request_hold())
	assert_true(seen.has(true), "the veil came")
	assert_almost(ui.veil.target_alpha, 0.6, 0.001, "lecture veil 60 %")
	assert_false(ui.veil.active, "and went again")
	assert_true(panel.result_card.visible)
	assert_eq(inv.count(&"coin"), before + int(panel.result.get("fee", 0)))
	assert_true(lectures.known_teachings().has("l_heart"))
	assert_true(panel.result_teaching.text.begins_with("Mitschrift: "), panel.result_teaching.text)


# --- pult & collection --------------------------------------------------------------------------------

func test_pult_panel_seal_medicine_and_cold_box() -> void:
	await _setup()
	_anatomy_world()
	GameState.set_flag(&"anatomy_known", true)
	var store := (load(STORE_SCENE) as PackedScene).instantiate() as PultStore
	store.specimens = specimens
	_world().add_child(store)
	await wait_frames(1)
	var liver := _take(&"liver", SpecimenRecord.CONTAINER_BUNDLE)
	var kidneys := _take(&"kidneys", SpecimenRecord.CONTAINER_BUNDLE)
	inv.remove_uid(kidneys)
	store.store().add_unique(&"specimen_bundle", kidneys)
	inv.add_item(&"prep_jar", 1)
	inv.add_item(&"spirits", 2)
	inv.add_item(&"herbs", 2)
	var panel := _open(&"pult", {"station": &"pult", "inventory": inv, "player": player}) as PultPanel
	assert_eq(panel.pieces().size(), 2)
	assert_true(panel.piece_buttons[kidneys].disabled, "in the cold box: take it out first")
	assert_eq(panel.selected, liver)
	assert_eq(panel.action_reason(PultPanel.ACTION_SEAL), "")
	assert_eq(panel.action_reason(PultPanel.ACTION_BONE), PultRules.TEXT_HAND_ONLY)
	assert_eq(panel.action_reason(PultPanel.ACTION_INSPECT), PultRules.TEXT_INSPECT_BUNDLE)
	var bitter: Dictionary = panel.medicine_rows[&"bitter_drops"]
	assert_eq((bitter.reason as Label).text, PultRules.TEXT_SEAL_FIRST)
	assert_true(panel.request_action(PultPanel.ACTION_SEAL))
	assert_eq(specimens.get_record(liver).container, SpecimenRecord.CONTAINER_JAR, "sealed")
	assert_eq(inv.count(&"prep_jar"), 0, "Specimens.seal took the jar (not twice)")
	bitter = panel.medicine_rows[&"bitter_drops"]
	assert_eq((bitter.reason as Label).text, "", (bitter.reason as Label).text)
	assert_true(panel.request_medicine(&"bitter_drops"))
	assert_eq(inv.count(&"bitter_drops"), 2)
	assert_eq(specimens.get_record(liver).state, &"used")
	assert_eq(inv.count(&"herbs"), 0)
	assert_true(panel.take_from_cold(kidneys))
	assert_true(inv.has_uid(kidneys))
	assert_false(store.store().has_uid(kidneys))
	assert_eq(panel.selected, kidneys)


func test_collection_panel_place_sets_standing() -> void:
	await _setup()
	_anatomy_world()
	var shelf := (load(SHELF_SCENE) as PackedScene).instantiate() as CollectionShelf
	shelf.specimens = specimens
	shelf.sets = Phase7Fixtures.collection_sets()
	_world().add_child(shelf)
	await wait_frames(1)
	var heart := _take(&"heart", SpecimenRecord.CONTAINER_JAR)
	var lung := _take(&"lung", SpecimenRecord.CONTAINER_JAR)
	var bundle := _take(&"liver", SpecimenRecord.CONTAINER_BUNDLE)
	var panel := _open(&"collection", {"shelf": shelf, "storage": shelf.storage, "inventory": inv, "player": player}) as CollectionPanel
	assert_eq(panel.standing_label.text, "Ansehen bei der Universität: 0")
	assert_eq((panel.slot_rows[&"heart"].label as Label).text, "Herz – leer")
	assert_true(panel.place_buttons[bundle].disabled, "no bundle on the shelf")
	assert_eq(panel.place_buttons[bundle].tooltip_text, CollectionShelf.TEXT_NOT_ACCEPTED)
	assert_true(panel.place(heart))
	assert_true(panel.place(lung))
	assert_true((panel.slot_rows[&"heart"].label as Label).text.begins_with("Herz – Hedwig Lamprecht"))
	assert_eq(panel.set_labels[&"set_chest"].text, "✓ Brustraum")
	assert_eq(panel.standing_label.text, "Ansehen bei der Universität: 1")
	assert_true(panel.take_out(&"heart"))
	assert_true(inv.has_uid(heart))
	assert_eq(panel.set_labels[&"set_chest"].text, "✓ Brustraum", "a set stays done")


# --- deduction ------------------------------------------------------------------------------------------

func test_deduction_panel_right_and_wrong() -> void:
	await _setup()
	_anatomy_world()
	var d := Phase7Fixtures.cards_for(corpse.id, ["b_white_stomach", "l_stomach"])
	d.deductions = Phase7Fixtures.deductions()
	_world().add_child(d)
	var panel := _open(&"deduction", {"corpse_id": corpse.id}) as DeductionPanel
	assert_eq(panel.card_buttons.size(), 2)
	assert_true(panel.for_label.text.begins_with("Hedwig Lamprecht · laut Osric: Fieber"), panel.for_label.text)
	assert_true(panel.cause_buttons.has(&"arsenic") and panel.cause_buttons.has(&"unexplained"))
	assert_true(panel.deduce_button.disabled)
	panel.toggle_card("b_white_stomach")
	panel.toggle_card("l_stomach")
	panel.choose_cause(&"drink")
	assert_false(panel.deduce_button.disabled)
	var wrong := panel.deduce()
	assert_false(bool(wrong.get("ok", true)))
	assert_eq(panel.result_label.text, "Das passt nicht zusammen.")
	assert_eq(GameState.get_stat(&"deductions"), 0, "no counter, no cost")
	panel.choose_cause(&"arsenic")
	var right := panel.deduce()
	assert_true(bool(right.get("ok", false)))
	assert_eq(panel.result_label.text, "Gedeutet: Arsenik")
	assert_eq(corpse.revealed_cause, &"arsenic")
	assert_eq(panel.done_label.text, "Schon gedeutet: Arsenik")
	assert_false(panel.done_label.visible, "the result card says it already")


# --- specimen card at the crypt table ----------------------------------------------------------------------

func test_exam_specimen_card_rows_and_two_stage() -> void:
	await _setup()
	_anatomy_world()
	var care := CareDouble.new()
	care.reasons = {&"kidneys": "Es fehlt: Präparatglas"}
	_world().add_child(care)
	var heart := _take(&"heart", SpecimenRecord.CONTAINER_JAR)
	corpse.harvested.append(&"heart")
	var table := TableDouble.new()
	_world().add_child(table)
	ui.open_panel(&"corpse_exam", {"corpse_id": corpse.id, "table": table, "player": player})
	await wait_frames(1)
	var panel := ui.get_panel(&"corpse_exam") as CorpseExamPanel
	var tabs := panel.tabs
	assert_true(tabs.tab_buttons[&"organs"].visible, "anatomy known at the crypt table: the card is there")
	assert_eq(tabs.tab_buttons[&"organs"].text, "Präparate")
	tabs.select_tab(&"organs")
	assert_eq(tabs.organs_head.text, "Genommen: 1 von höchstens 3 · Klarheit jetzt: sehr gut")
	assert_eq(tabs.organ_rows.size(), 7)
	var eyes: Dictionary = tabs.organ_rows[&"eyes"]
	assert_true((eyes.jar as Button).visible and not (eyes.bundle as Button).visible, "eyes only in the jar")
	assert_false(panel.freshness_bar.is_visible_in_tree(), "the card takes the condition's room")
	var hand: Dictionary = tabs.organ_rows[&"hand"]
	assert_true((hand.bundle as Button).visible and not (hand.jar as Button).visible, "the hand only in linen")
	var heart_row: Dictionary = tabs.organ_rows[&"heart"]
	assert_eq((heart_row.taken as Label).text, "Genommen – im Glas, bei dir")
	assert_false((heart_row.button as Button).visible)
	var lung: Dictionary = tabs.organ_rows[&"lung"]
	assert_eq((lung.button as Button).text, "im Glas nehmen (20 Min)")
	assert_true((lung.consequence as Label).text.begins_with("Qualität −2 · Ruf "), (lung.consequence as Label).text)
	assert_true((lung.consequence as Label).text.ends_with("der Geist wird es merken"))
	assert_false((lung.consequence as Label).text.contains("Pietät"), "no piety number")
	assert_true((eyes.consequence as Label).text.ends_with("das wird ihr fehlen"))
	assert_true((lung.info as Label).text.begins_with("Präparatglas"), (lung.info as Label).text)
	var kidneys: Dictionary = tabs.organ_rows[&"kidneys"]
	assert_true((kidneys.button as Button).disabled)
	assert_eq((kidneys.reason as Label).text, "Es fehlt: Präparatglas")
	tabs.press_organ(&"lung")
	assert_eq((lung.button as Button).text, "Wirklich? Noch einmal drücken.")
	assert_true(table.calls.is_empty(), "first press only arms")
	tabs.press_organ(&"lung")
	assert_eq(table.calls, [["organ", &"lung", &"jar"]])
	tabs.choose_container(&"lung", &"bundle")
	assert_eq((lung.button as Button).text, "im Bündel nehmen (20 Min)")
	tabs.press_organ(&"eyes")
	assert_eq((eyes.button as Button).text, "Das bleibt ihr fehlen. Wirklich? Noch einmal drücken.")
	tabs.disarm()
	ui.close_top_panel()
	care.reasons = {}
	for organ: StringName in AnatomyConfig.ORGANS:
		care.reasons[organ] = SpecimenRules.REASON_NO_CARD
	ui.open_panel(&"corpse_exam", {"corpse_id": corpse.id, "table": table, "player": player})
	await wait_frames(1)
	assert_false(tabs.tab_buttons[&"organs"].visible, "no anatomy: no card")
	assert_ne(heart, "")


func test_exam_cause_line_after_deduction() -> void:
	await _setup()
	_anatomy_world()
	corpse.revealed_cause = &"arsenic"
	var table := TableDouble.new()
	_world().add_child(table)
	ui.open_panel(&"corpse_exam", {"corpse_id": corpse.id, "table": table, "player": player})
	await wait_frames(1)
	var panel := ui.get_panel(&"corpse_exam") as CorpseExamPanel
	assert_eq(panel.cause_label.text, "laut Osric: Fieber · gedeutet: Arsenik")


# --- HUD: veil, region, remarks ------------------------------------------------------------------------------

func test_veil_follows_screen_veil_changed() -> void:
	await _setup()
	assert_false(ui.veil.active)
	EventBus.screen_veil_changed.emit(true)
	assert_true(ui.veil.active)
	assert_true(ui.veil.visible)
	assert_almost(ui.veil.target_alpha, 0.85, 0.001)
	EventBus.timed_action_started.emit(MorgueTable.TEXT_ORGAN, 1.0)
	assert_eq(ui.veil.line_label.text, "Du ziehst das Tuch über sie und arbeitest, ohne hinzusehen.")
	EventBus.timed_action_progress.emit(0.5)
	assert_almost(ui.veil.bar.value, 0.5, 0.001)
	EventBus.screen_veil_changed.emit(false)
	assert_false(ui.veil.active)
	assert_eq(ui.veil.color, Color(ScreenVeil.INK, 0.85), "ink blue #1F2A3A")


func test_region_label_and_remark_bubble() -> void:
	await _setup()
	EventBus.region_changed.emit(&"village")
	assert_eq(ui.region_label.shown_text, "Hollerbrück · Anger")
	assert_true(ui.region_label.visible)
	var graveyard_npc := NpcDouble.new()
	graveyard_npc.npc_id = &"innkeeper"
	graveyard_npc.region_id = &"graveyard"
	_world().add_child(graveyard_npc)
	var village_npc := NpcDouble.new()
	village_npc.npc_id = &"innkeeper"
	_world().add_child(village_npc)
	EventBus.villager_remarked.emit(&"innkeeper", "Wackernagel hat für dich einen Stuhl am Ofen frei.")
	assert_true(ui.remark_bubbles.is_showing())
	assert_eq(ui.remark_bubbles.bubble.text, "Wackernagel hat für dich einen Stuhl am Ofen frei.")
	assert_eq(ui.remark_bubbles.bubble.get_parent(), village_npc, "the village Npc speaks")
	EventBus.villager_remarked.emit(&"smith", "Grüß Gott.")
	assert_false(ui.remark_bubbles.is_showing(), "one at a time; Esch is not here")


# --- objective ------------------------------------------------------------------------------------------------

func test_objective_lines_phase7() -> void:
	var w := {"p7": true}
	assert_eq(Phase7Texts.objective({}), "")
	assert_eq(Phase7Texts.objective(w), "Sprich mit Osric")
	w["p7_intro"] = true
	assert_eq(Phase7Texts.objective(w), "Geh nach Hollerbrück")
	w["visited"] = true
	assert_eq(Phase7Texts.objective(w), "Der Schultheiß erwartet dich in der Amtsstube")
	w["linden_granted"] = true
	w["linden_done"] = 4
	w["linden_total"] = 10
	assert_eq(Phase7Texts.objective(w), "Lindenacker: 4/10")
	w["linden_cleared"] = true
	assert_eq(Phase7Texts.objective(w), "Bitte den Pfarrer um die Weihe")
	w["consecration_paid"] = true
	assert_eq(Phase7Texts.objective(w), "Der Pfarrer kommt am Vormittag")
	w["consecrated"] = true
	w["surgeon_waiting"] = true
	assert_eq(Phase7Texts.objective(w), "Der Wundarzt will dich sprechen")
	w["surgeon_waiting"] = false
	w["hagedorn_open"] = true
	assert_eq(Phase7Texts.objective(w), "Wiebke Hagedorns letzter Wunsch")
	w["hagedorn_open"] = false
	w["urgent_order"] = {"title": "Holunderbeeren", "days_left": 2}
	assert_eq(Phase7Texts.objective(w), "Auftrag: Holunderbeeren (noch 2 Tage)")
	w["urgent_order"] = {"title": "Holz für den Zaun", "days_left": 1}
	assert_eq(Phase7Texts.objective(w), "Auftrag: Holz für den Zaun (bis morgen früh)")
	w["urgent_order"] = {}
	w["goal_parts"] = 3
	w["goal_total"] = 4
	assert_eq(Phase7Texts.objective(w), "Ein Name im Dorf: 3/4")
	w["goal_done"] = true
	w["board_open"] = 2
	assert_eq(Phase7Texts.objective(w), "Die Gemeindetafel hat neue Bitten")
	# In the resolver: after the Phase-6 goal (it is done), before its devotion hint.
	var world := {"p6": true, "p6_intro": true, "levels": {&"crypt": 2, &"chapel": 2, &"shed": 2}, "goal_levels": {},
			"goal_done": true, "devotion_name": "Agnes Hollweg", "p7": true}
	var none: Array[CorpseRecord] = []
	var graves: Array[GraveRecord] = []
	assert_eq(ObjectiveResolver.current(none, graves, null, 720, {}, world), "Sprich mit Osric")
	world.erase("p7")
	assert_eq(ObjectiveResolver.current(none, graves, null, 720, {}, world), "Eine Andacht für Agnes Hollweg?")


# --- Merkbuch -------------------------------------------------------------------------------------------------

func test_journal_pages_orders_and_village() -> void:
	await _setup()
	GameState.set_flag(&"village_open", true)
	rel = Phase7Fixtures.villager(&"innkeeper", 45, null, {"mayor": 20})
	_world().add_child(rel)
	_orders(&"o_rosine_berries", &"accepted", {"o_fenner_well": "completed", "ob_wood": "failed"})
	ui.open_panel(&"journal", {"page": &"orders"})
	await wait_frames(1)
	var panel := ui.get_panel(&"journal") as JournalPanel
	assert_eq(panel.current_page, &"orders")
	assert_true(panel.tab_buttons[&"orders"].get_parent().visible)
	var texts := _texts(panel)
	assert_true(texts.has("Laufend") and texts.has("Erledigt") and texts.has("Versäumt"), str(texts))
	assert_true(_contains(texts, Phase7Fixtures.order(&"o_rosine_berries").title))
	assert_true(_contains(texts, "8× Holunderbeeren  0/8 –"))
	panel.show_page(&"village")
	texts = _texts(panel)
	assert_eq(_metas(panel, &"npc_id").size(), 8, "eight cards")
	assert_true(texts.has("Vertraut  ●●○○○"), str(texts))
	assert_true(texts.has("mag: ?"), "favourites unknown until a gift was accepted")
	assert_true(texts.has(Phase7Texts.NOT_MET))
	GameState.set_flag(&"village_open", false)
	panel.show_page(&"people")
	assert_false(panel.tab_buttons[&"orders"].get_parent().visible, "before village_open: four tabs")


func test_death_note_specimens_and_deduce_button() -> void:
	await _setup()
	_anatomy_world()
	var journal := JournalDouble.new()
	journal.list = [{"corpse_id": corpse.id, "name": corpse.display_name, "age": 58, "cause_label": "Fieber", "day": 3, "finds": [],
			"lost": [], "harvested": [&"heart"]}]
	_world().add_child(journal)
	var heart := _take(&"heart", SpecimenRecord.CONTAINER_JAR)
	specimens.sell(heart, inv)
	var d := Phase7Fixtures.cards_for(corpse.id, ["b_white_stomach"])
	_world().add_child(d)
	ui.open_panel(&"journal", {"page": &"people", "journal": journal})
	await wait_frames(1)
	var panel := ui.get_panel(&"journal") as JournalPanel
	var texts := _texts(panel)
	assert_true(texts.has("Genommen: das Herz"), str(texts))
	assert_true(texts.has("Herz – an Quast verkauft"), str(texts))
	assert_not_null(panel.deduce_button)
	panel.deduce_button.pressed.emit()
	await wait_frames(1)
	assert_eq(ui.top(), &"deduction")
	assert_eq((ui.get_panel(&"deduction") as DeductionPanel).corpse_id, corpse.id)


# --- register, day summary, chapter ---------------------------------------------------------------------------

func test_register_specimens_column_and_linden() -> void:
	assert_eq(GraveRegisterPanel.grave_label("l_03"), "Linde 3")
	var entry := {"name": "Hedwig Lamprecht", "age": 58, "day_buried": 44, "grave_id": "l_01", "quality": 9, "marker_label": "Stele",
			"cause_label": "Fieber", "specimens": {"taken": 2, "returned": 1}, "deduced": true}
	var cells := GraveRegisterPanel.cells(entry, true)
	assert_eq(cells.size(), GraveRegisterPanel.COLUMNS.size() + 1)
	assert_eq(cells[1], "Hedwig Lamprecht (58) ◆", "a small seal for the deduced")
	assert_eq(cells[3], "Linde 1")
	assert_eq(cells[cells.size() - 1], "2 (1 ✓)")
	assert_eq(GraveRegisterPanel.cells(entry).size(), GraveRegisterPanel.COLUMNS.size(), "without the column: unchanged")
	await _setup()
	ui.open_panel(&"grave_register", {"entries": [entry], "total": 20, "rating": &"orderly"})
	await wait_frames(1)
	var panel := ui.get_panel(&"grave_register") as GraveRegisterPanel
	assert_true(panel.with_specimens)
	assert_eq(panel.row_texts()[0][7], "2 (1 ✓)")


func test_day_summary_village_rows() -> void:
	await _setup()
	EventBus.payment_received.emit(6, "Verkauf im Dorf")
	EventBus.payment_received.emit(10, "Auftrag: Holunderbeeren")
	EventBus.payment_received.emit(4, "Pflegegeld")
	EventBus.coins_spent.emit(5, &"round")
	EventBus.order_changed.emit(&"o_rosine_berries", &"completed")
	EventBus.relationship_changed.emit(&"mayor", 32, &"acquainted", 2, "Gespräch")
	EventBus.relationship_changed.emit(&"washer", 7, &"stranger", -3, "Im Dorf redet man.")
	EventBus.relationship_changed.emit(&"smith", 15, &"acquainted", 15, Relationships.REASON_MEET)
	EventBus.specimen_changed.emit("sp_0001", &"taken")
	EventBus.specimen_changed.emit("sp_0001", &"sold")
	ui.open_panel(&"day_summary", {"day": 44, "burials_today": 0, "coins_today": 15, "total": 180, "rating": &"venerable"})
	var panel := ui.get_panel(&"day_summary") as DaySummaryPanel
	assert_eq(panel.row_text(panel.village_label), "+16 eingenommen · 5 ausgegeben")
	assert_eq(panel.row_text(panel.orders_label), "1")
	assert_eq(panel.row_text(panel.relations_label), "Fenner ▲ 2 · Liesel ▼ 3", "the first meeting is not a change")
	assert_eq(panel.row_text(panel.specimens_label), "1 genommen · 1 verkauft")
	assert_true(panel.row_text(panel.spent_label).contains("Runden 5"), panel.row_text(panel.spent_label))


func test_chapter_panel_name_in_village() -> void:
	await _setup()
	var ctx := {"variant": &"name_in_village", "chapter": &"name_in_village", "village_days": 12, "village_trips": 14,
			"orders_done": 7, "orders_by_giver": {&"mayor": 3, &"innkeeper": 2, &"council": 2},
			"relationships": {&"innkeeper": "Vertraut", &"mayor": "Befreundet"}, "reputation_tier": "Geachtet", "linden_burials": 8,
			"specimens": {"specimens_taken": 3, "specimens_sold": 1, "specimens_returned": 2}, "deductions": 1, "university_standing": 0,
			"coins_earned_village": {"Aufträge": 65}, "coins_spent_village": {&"village": 14, &"donation": 32},
			"insights_phase7": PackedStringArray(["i_deathbook"]), "final_line": ""}
	ui.open_panel(&"slice_summary", ctx)
	var panel := ui.get_panel(&"slice_summary") as SliceSummaryPanel
	assert_eq(panel.header_label.text, "Ein Name im Dorf")
	assert_true(panel.village_grid.visible and not panel.roof_grid.visible and not panel.chapter_grid.visible)
	assert_eq(panel.village_value("Tage seit dem Wegstein"), "12")
	assert_eq(panel.village_value("Aufträge"), "7 (Rosine 2 · Fenner 3 · Gemeinde 2)")
	assert_eq(panel.village_value("Beziehungen"), "Rosine Vertraut · Fenner Befreundet")
	assert_eq(panel.village_value("Präparate"), "genommen 3 · verkauft 1 · begutachtet 0 · Vorlesung 0 · Arznei 0 · Sammlung 0 · zurückgelegt 2")
	assert_eq(panel.village_value("Im Dorf ausgegeben"), "46 Münzen (Dorf 14 · Spenden 32)")
	assert_true(panel.village_value("Erkenntnisse").begins_with("Vorher eingetragen"), panel.village_value("Erkenntnisse"))
	assert_eq(panel.goal_label.text, Phase7Texts.CHAPTER_FINAL_FALLBACK)


func test_phase4_chapter_counts_only_phase4_insights() -> void:
	assert_eq(Phase4Texts.main_insight_total(), 5, "i_deathbook is a Phase-7 insight")


# --- crafting & debug -----------------------------------------------------------------------------------------

func test_crafting_panel_pult_button() -> void:
	await _setup()
	ui.open_panel(&"crafting", {"station": &"pult", "inventory": inv, "player": player})
	var crafting := ui.get_panel(&"crafting") as CraftingPanel
	assert_true(crafting.pult_button.visible)
	assert_eq(crafting.pult_button.text, "Präparate und Arzneien")
	crafting.pult_button.pressed.emit()
	await wait_frames(1)
	assert_eq(ui.top(), &"pult")
	ui.close_all()
	ui.open_panel(&"crafting", {"station": &"workbench", "inventory": inv, "player": player})
	assert_false(crafting.pult_button.visible, "only at the pult")


func test_debug_commands_without_world() -> void:
	for command: String in ["village open", "region village", "room inn", "rel innkeeper 40", "orders", "order ob_wood accept",
			"board", "linden open", "anatomy", "specimen heart", "specimens", "spoil sp_0001", "shelf heart", "lecture",
			"rumor on", "cards table", "deduce table arsenic", "teach all", "medicine antidote", "hidden arsenic", "npclod",
			"remark innkeeper", "vis7", "goal7"]:
		var r := Debug.execute(command)
		assert_false(r.ok, command)
		assert_true(str(r.text).contains("Keine Spielwelt") or str(r.text).contains("niemand"), command + ": " + str(r.text))
	var help := str(Debug.execute("help").text)
	assert_true(help.contains("village open") and help.contains("goal7") and help.contains("specimen <organ> [jar|bundle]"), help)
	assert_true(Debug.execute("standing 2").ok)
	assert_eq(GameState.get_stat(&"university_standing"), 2)
	assert_false(Debug.execute("standing 5").ok)


func test_debug_commands_with_fixtures() -> void:
	await _setup()
	rel = Phase7Fixtures.villager(&"innkeeper", 20, null)
	_world().add_child(rel)
	assert_true(Debug.execute("rel innkeeper 45").ok)
	assert_eq(rel.value(&"innkeeper"), 45)
	assert_true(Debug.execute("rel all 50").ok)
	assert_eq(rel.value(&"oldwoman"), 50)
	var lectures := Phase7Fixtures.lecture_night(3, null)
	_world().add_child(lectures)
	assert_true(Debug.execute("teach all").ok)
	assert_eq(lectures.known_teachings().size(), 7)
	_orders(&"o_rosine_berries", &"accepted")
	var listed := Debug.execute("orders")
	assert_true(listed.ok and str(listed.text).contains("o_rosine_berries"), str(listed.text))
	assert_true(Debug.execute("order o_rosine_berries done").ok)
	assert_true(Debug.execute("medicine bitter_drops").ok)
	assert_eq(inv.count(&"bitter_drops"), 2)
	assert_true(Debug.execute("anatomy").ok)
	assert_true(GameState.flag_on(&"anatomy_known") and inv.has(&"anatomy_case"))


# --- helpers ------------------------------------------------------------------------------------------------

func _setup() -> void:
	player = FakePlayer.new()
	player.name = "FakePlayer"
	inv = Inventory.new()
	inv.slot_count = 30
	inv.tool_belt = true
	inv.name = "Inventory"
	player.add_child(inv)
	player.inventory = inv
	tree.root.add_child(player)
	ui = await add_scene(UI_SCENE) as UIRoot


func _world() -> Node3D:
	if world == null:
		world = Node3D.new()
		world.name = "P7World"
		tree.root.add_child(world)
	return world


func _open(id: StringName, ctx: Dictionary) -> UIPanel:
	ui.open_panel(id, ctx)
	return ui.get_panel(id)


func _shops(npc: StringName) -> VillageShops:
	var shops := VillageShops.new()
	shops.config = Phase7Fixtures.relationship_config()
	for id: StringName in Phase7Fixtures.SHOP_IDS:
		shops.shop_data[id] = Phase7Fixtures.shop(id)
	shops.schedules[npc] = Phase7Fixtures.schedule(npc)
	_world().add_child(shops)
	return shops


func _orders(id: StringName, state: StringName, more: Dictionary = {}) -> Orders:
	var o := Phase7Fixtures.order_in(id, state, null, more, TimeManager.day)
	for data: OrderData in Phase7Fixtures.orders():
		o.order_table[data.id] = data
	_world().add_child(o)
	return o


## CorpseManager double with „Hedwig Lamprecht" (58, fever) on the crypt table + Specimens.
func _anatomy_world() -> void:
	manager = ManagerDouble.new()
	_world().add_child(manager)
	corpse = Phase5Fixtures.corpse(58, &"fever")
	corpse.id = "c_test"
	corpse.display_name = "Hedwig Lamprecht"
	corpse.freshness = 0.85
	corpse.location = CorpseRecord.LOCATION_TABLE
	corpse.room = &"crypt"
	manager.put(corpse)
	specimens = Specimens.new()
	specimens.config = Phase7Fixtures.anatomy_config()
	specimens.findings = Phase7Fixtures.findings()
	_world().add_child(specimens)


## A real piece from the table corpse into the pack (Specimens.harvest takes its inputs).
func _take(organ: StringName, container: StringName) -> String:
	var inputs := SpecimenRules.harvest_inputs(organ, container, specimens.get_config())
	for id: StringName in inputs:
		inv.add_item(id, inputs[id])
	return specimens.harvest(corpse.id, organ, container, inv)


## Every Label text under the journal's two pages.
func _texts(panel: JournalPanel) -> PackedStringArray:
	var out := PackedStringArray()
	for page: Control in [panel.left_page, panel.right_page]:
		for node: Node in page.find_children("*", "Label", true, false):
			out.append((node as Label).text)
	return out


func _contains(texts: PackedStringArray, part: String) -> bool:
	for t: String in texts:
		if t.contains(part):
			return true
	return false


func _metas(panel: JournalPanel, key: StringName) -> Array:
	var out := []
	for page: Control in [panel.left_page, panel.right_page]:
		for node: Node in page.find_children("*", "", true, false):
			if node.has_meta(key):
				out.append(node.get_meta(key))
	return out
