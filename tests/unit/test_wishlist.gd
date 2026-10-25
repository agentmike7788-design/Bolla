extends TestCase
## P1 (docs/PHASE10_DESIGN.md §2.3 Grundsatz 2, §3.4, §10.1): data/economy/wishlist.tres and WishlistProbe.open_cost –
## only available (flag) and not owned entries count; stations by Workshop.is_built, building levels by Buildings.level,
## tools / items by the pieces in pack, chests and placed decor, per_grave entries per occupied grave without it (at most
## max_count). The systems are stand-ins in the test tree (the probe asks them by group).

var _nodes: Array[Node] = []
var _flags: Dictionary


class FakeWorkshop extends Node:
	var built: Array[StringName] = []
	func is_built(id: StringName) -> bool:
		return id in built


class FakeBuildings extends Node:
	var levels: Dictionary = {}
	func level(id: StringName) -> int:
		return int(levels.get(id, 0))


class FakeGraveyard extends Node:
	var list: Array[GraveRecord] = []
	func graves() -> Array[GraveRecord]:
		return list


class FakeCare extends Node:
	var mortsafes: PackedStringArray = []
	var roses: PackedStringArray = []
	func has_mortsafe(id: String) -> bool:
		return id in mortsafes
	func has_rose(id: String) -> bool:
		return id in roses


class FakeDecor extends Node:
	var counts: Dictionary = {}
	func count_of(id: StringName) -> int:
		return int(counts.get(id, 0))


class FakePlayer extends Node:
	var inventory: Inventory


func before_each() -> void:
	_flags = GameState.flags.duplicate(true)


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	GameState.flags = _flags


func _add(node: Node, group: StringName) -> Node:
	node.add_to_group(group)
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func _entry(id: StringName, kind: StringName, ref: StringName, coins: int, flag: StringName = &"", max_count: int = 1) -> WishlistEntryData:
	var e := WishlistEntryData.new()
	e.id = id
	e.kind = kind
	e.ref = ref
	e.coins = coins
	e.available_flag = flag
	e.max_count = max_count
	return e


func _grave(id: String, state: GraveRecord.State, gilded := false) -> GraveRecord:
	var g := GraveRecord.new()
	g.id = id
	g.state = state
	if gilded:
		g.design = {"gilded": true}
	return g


func test_only_available_and_missing_entries_count() -> void:
	var ws := _add(FakeWorkshop.new(), &"workshop") as FakeWorkshop
	var b := _add(FakeBuildings.new(), &"buildings") as FakeBuildings
	var data := WishlistData.new()
	data.entries = [_entry(&"a", &"station", &"forge", 25, &"workshop_open"), _entry(&"b", &"station", &"loom", 10, &"workshop_open"),
			_entry(&"c", &"building", &"chapel", 25, &"buildings_open", 1), _entry(&"d", &"building", &"chapel", 30, &"buildings_open", 2),
			_entry(&"e", &"station", &"pult", 12)] as Array[WishlistEntryData]
	GameState.clear_flag(&"workshop_open")
	GameState.clear_flag(&"buildings_open")
	assert_eq(WishlistProbe.open_cost(tree, data), 12, "only the entry without a flag")
	GameState.set_flag(&"workshop_open")
	assert_eq(WishlistProbe.open_cost(tree, data), 47)
	ws.built = [&"forge"]
	assert_eq(WishlistProbe.open_cost(tree, data), 22, "a built station is owned")
	GameState.set_flag(&"buildings_open")
	assert_eq(WishlistProbe.open_cost(tree, data), 77)
	b.levels = {&"chapel": 1}
	assert_eq(WishlistProbe.open_cost(tree, data), 52, "level 1 bought, level 2 open")
	b.levels = {&"chapel": 2}
	assert_eq(WishlistProbe.open_cost(tree, data), 22)
	assert_eq(WishlistProbe.open_cost(tree, null), 0)


func test_items_count_pack_chests_and_placed_decor() -> void:
	var player := FakePlayer.new()
	player.inventory = Inventory.new()
	player.add_child(player.inventory)
	_add(player, &"player")
	var deco := _add(FakeDecor.new(), &"decorations") as FakeDecor
	var data := WishlistData.new()
	data.entries = [_entry(&"l", &"item", &"decor_lantern", 10, &"", 6), _entry(&"w", &"tool", &"watering_can", 4)] as Array[WishlistEntryData]
	assert_eq(WishlistProbe.open_cost(tree, data), 6 * 10 + 4)
	player.inventory.add_item(&"watering_can", 1)
	player.inventory.add_item(&"decor_lantern", 1)
	deco.counts = {&"decor_lantern": 2}
	assert_eq(WishlistProbe.owned(tree, &"decor_lantern"), 3, "pack + placed")
	assert_eq(WishlistProbe.open_cost(tree, data), 3 * 10, "three lanterns still wanted, the can is owned")
	deco.counts = {&"decor_lantern": 9}
	assert_eq(WishlistProbe.open_cost(tree, data), 0, "never below 0")


func test_per_grave_entries_count_occupied_graves_without_it() -> void:
	var gy := _add(FakeGraveyard.new(), &"graveyard") as FakeGraveyard
	var care := _add(FakeCare.new(), &"grave_care") as FakeCare
	gy.list = [_grave("a", GraveRecord.State.MARKED), _grave("b", GraveRecord.State.FILLED, true), _grave("c", GraveRecord.State.EMPTY),
			_grave("d", GraveRecord.State.MARKED), _grave("e", GraveRecord.State.DUG), _grave("f", GraveRecord.State.MARKED)] as Array[GraveRecord]
	var data := WishlistData.new()
	data.entries = [_entry(&"rose", &"per_grave", &"rose_bush", 12, &"", 60)] as Array[WishlistEntryData]
	assert_eq(WishlistProbe.open_cost(tree, data), 4 * 12, "4 occupied graves (empty and dug ones do not count)")
	care.roses = ["a", "d"]
	assert_eq(WishlistProbe.open_cost(tree, data), 2 * 12)
	data.entries = [_entry(&"ms", &"per_grave", &"mortsafe", 12, &"", 2)] as Array[WishlistEntryData]
	assert_eq(WishlistProbe.open_cost(tree, data), 2 * 12, "at most max_count graves")
	care.mortsafes = ["a", "b", "d"]
	assert_eq(WishlistProbe.open_cost(tree, data), 1 * 12)
	data.entries = [_entry(&"g", &"per_grave", &"gold_leaf", 6, &"", 60)] as Array[WishlistEntryData]
	assert_eq(WishlistProbe.open_cost(tree, data), 3 * 6, "the gilded grave b has its gold")


func test_the_data_wish_list() -> void:
	var wish := Database.wishlist() as WishlistData
	assert_not_null(wish, "data/economy/wishlist.tres")
	if wish == null:
		return
	var ids := {}
	var kinds := {}
	for e: WishlistEntryData in wish.entries:
		assert_false(ids.has(e.id), "unique id %s" % e.id)
		ids[e.id] = true
		kinds[e.kind] = true
		assert_true(e.kind in WishlistEntryData.KINDS and e.coins > 0 and e.max_count >= 1, String(e.id))
		assert_true(e.available_flag != &"", "%s: available from a chapter flag" % e.id)
		match e.kind:
			&"station":
				var st := Database.station(e.ref) as StationData
				assert_not_null(st, "%s: station %s" % [e.id, e.ref])
				if st != null:
					assert_eq(e.coins, st.build_coins, "%s = the station's coins" % e.id)
			&"building":
				var b := load("res://data/buildings/%s.tres" % e.ref) as BuildingData
				assert_not_null(b, "%s: building %s" % [e.id, e.ref])
				if b != null:
					assert_eq(e.coins, int(b.levels[e.max_count - 1].get(&"coins")), "%s = level %d's coins" % [e.id, e.max_count])
			_:
				assert_true(Database.has_item(e.ref) or e.ref in Phase10Fixtures.ITEM_IDS, "%s: item %s" % [e.id, e.ref])
	# §2.3 Grundsatz 2: stations, levels, tools, decor, mortsafes, gold, roses, market goods.
	for k: StringName in WishlistEntryData.KINDS:
		assert_true(kinds.has(k), "kind %s in the list" % k)
	for id: StringName in [&"wl_rose", &"wl_brass_lantern", &"wl_gold", &"wl_mortsafe", &"wl_forge", &"wl_chapel_3"]:
		assert_true(ids.has(id), String(id))
	# The prices of the per-grave / market entries are the shop and contract prices.
	var per := {}
	for e: WishlistEntryData in wish.entries:
		per[e.id] = e.coins
	assert_eq([per.wl_rose, per.wl_brass_lantern, per.wl_mortsafe, per.wl_gold, per.wl_watering_can], [12, 10,
			int((Database.shop(&"smith") as ShopData).sells[&"mortsafe"].price), int((Database.config(&"trader_config") as TraderConfig).shop[&"gold_leaf"].price),
			int((Database.shop(&"smith") as ShopData).sells[&"watering_can"].price)])
