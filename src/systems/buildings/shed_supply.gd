class_name ShedSupply
extends RefCounted
## Fetching missing ingredients from the shed / storing the surplus (docs/PHASE6_DESIGN.md §2.5,
## §3.4). Pure rules over two inventories plus the shared request flow of the stations, build sites
## and the stone panel (run_fetch / run_store: Workbench, BuildSite, BuildingSite call them).
## - Fetch (shed ≥ fetch_min_level): moves exactly the missing amounts of `needs` from the shed into
##   the player's inventory, atomically – only when the shed has all of it and the inventory has
##   room, else nothing. A TimedAction of fetch_minutes_by_level (0 → at once), then
##   EventBus.shed_supply_moved(items, &"fetch").
## - Store (shed ≥ store_min_level): all RESOURCE / MATERIAL items of the player (never tools,
##   coins or excluded_items) into the shed, as far as they fit; shed_supply_moved(items, &"store").
## Coins in `needs` are ignored (they are never in the shed).

const DIRECTION_FETCH := &"fetch"
const DIRECTION_STORE := &"store"
const COIN := &"coin"
const BUILDINGS_GROUP := &"buildings"
const SHED := &"shed"
const ANIM := &"interact"
const TEXT_SHED_MISSING := "Im Schuppen fehlt: %s"
const TEXT_NO_ROOM := "Kein Platz im Inventar"
const TEXT_NO_SHED := "Der Schuppen ist noch nicht angeschlossen."
const TEXT_NOTHING_MISSING := "Es fehlt nichts."
const TEXT_NOTHING_TO_STORE := "Nichts einzulagern."
const TEXT_BUSY := "Gerade nicht möglich."
const TEXT_FAILED := "Holen fehlgeschlagen."
## Labels / notes („Fehlendes aus dem Schuppen holen (10 Min)" is the UI's button).
const LABEL_FETCH := "Aus dem Schuppen holen"
const TEXT_FETCHED := "Aus dem Schuppen: %s"
const TEXT_STORED := "Eingelagert: %s"


## {id: missing in the player's inventory} (coins excluded), in `needs` order.
static func shortfall(needs: Dictionary, inv: Inventory) -> Dictionary:
	var out: Dictionary = {}
	var valid := is_instance_valid(inv)
	for key: Variant in needs:
		var id := StringName(str(key))
		if id == COIN:
			continue
		var need := int(needs[key])
		var have := inv.count(id) if valid else 0
		if need > have:
			out[id] = need - have
	return out


## {id: amount in the shed} for every item of `needs` (coins excluded; 0 when none).
static func available(needs: Dictionary, shed: Inventory) -> Dictionary:
	var out: Dictionary = {}
	var valid := is_instance_valid(shed)
	for key: Variant in needs:
		var id := StringName(str(key))
		if id == COIN:
			continue
		out[id] = shed.count(id) if valid else 0
	return out


## "" or why fetching is not possible: TEXT_NO_SHED (level < fetch_min_level / no shed),
## TEXT_NOTHING_MISSING, „Im Schuppen fehlt: 2 Werkstein", „Kein Platz im Inventar".
static func fetch_block_reason(needs: Dictionary, player_inv: Inventory, shed: Inventory, level: int, cfg: ShedConfig) -> String:
	if cfg == null or level < cfg.fetch_min_level or not is_instance_valid(shed) or not is_instance_valid(player_inv):
		return TEXT_NO_SHED
	var gaps := shortfall(needs, player_inv)
	if gaps.is_empty():
		return TEXT_NOTHING_MISSING
	var lacking := _shed_lacking(gaps, shed)
	if not lacking.is_empty():
		return TEXT_SHED_MISSING % WorkshopRules.describe(lacking)
	if not fits(gaps, player_inv):
		return TEXT_NO_ROOM
	return ""


## Atomic: moves the shortfall of `needs` from the shed into the player's inventory; {id: moved},
## or {} (and no change) when nothing is missing, the shed lacks anything or it does not fit.
static func fetch(needs: Dictionary, player_inv: Inventory, shed: Inventory) -> Dictionary:
	if not is_instance_valid(player_inv) or not is_instance_valid(shed):
		return {}
	var gaps := shortfall(needs, player_inv)
	if gaps.is_empty() or not _shed_lacking(gaps, shed).is_empty() or not fits(gaps, player_inv):
		return {}
	var shed_before := shed.save_state()
	var inv_before := player_inv.save_state()
	for id: Variant in gaps:
		var n := int(gaps[id])
		if not shed.remove_item(id, n) or player_inv.add_item(id, n) > 0:
			push_warning("[ShedSupply] fetching %s failed midway – both inventories restored" % id)
			shed.load_state(shed_before)
			player_inv.load_state(inv_before)
			return {}
	return gaps


## All RESOURCE / MATERIAL items of the player (cfg.stack_categories; never tools, coins or
## cfg.excluded_items) into the shed, as far as they fit; {id: moved}. The caller checks the level.
static func store_surplus(player_inv: Inventory, shed: Inventory, cfg: ShedConfig) -> Dictionary:
	var out: Dictionary = {}
	if cfg == null or not is_instance_valid(player_inv) or not is_instance_valid(shed):
		return out
	var ids: Array[StringName] = []
	for slot: Dictionary in player_inv.get_slots():
		if slot.is_empty():
			continue
		var id := StringName(slot["id"])
		if not ids.has(id) and storable(id, cfg):
			ids.append(id)
	for id: StringName in ids:
		var amount := player_inv.count(id)
		if amount <= 0:
			continue
		var rest := shed.add_item(id, amount)
		var moved := amount - rest
		if moved <= 0:
			continue
		if not player_inv.remove_item(id, moved):
			push_warning("[ShedSupply] storing %s: removing from the player failed – taken back" % id)
			shed.remove_item(id, moved)
			continue
		out[id] = moved
	return out


## RESOURCE / MATERIAL (cfg.stack_categories) and not excluded; never tools or coins.
static func storable(id: StringName, cfg: ShedConfig) -> bool:
	if id == COIN or cfg == null or cfg.excluded_items.has(id) or not Database.has_item(id):
		return false
	var item := Database.item(id) as ItemData
	if item == null or item.category == ItemData.Category.TOOL or item.category == ItemData.Category.CURRENCY:
		return false
	return cfg.stack_categories.has(int(item.category))


## True if all of {id: amount} fit into `inv` together (probe copy; the inventory is unchanged).
static func fits(items: Dictionary, inv: Inventory) -> bool:
	if not is_instance_valid(inv):
		return false
	var probe := inv.duplicate(Node.DUPLICATE_SCRIPTS) as Inventory
	if probe == null:
		return false
	probe.load_state(inv.save_state())
	var ok := true
	for id: Variant in items:
		if probe.add_item(StringName(str(id)), int(items[id])) > 0:
			ok = false
			break
	probe.free()
	return ok


## Minutes of fetching at shed `level` (0 → at once).
static func fetch_minutes(level: int, cfg: ShedConfig) -> int:
	if cfg == null or level < 0 or level >= cfg.fetch_minutes_by_level.size():
		return 0
	return maxi(cfg.fetch_minutes_by_level[level], 0)


## The resolved ShedConfig (data/config/shed_config.tres; class defaults when missing).
static func config() -> ShedConfig:
	var cfg := Database.config(&"shed_config") as ShedConfig
	return cfg if cfg != null else ShedConfig.new()


## Shed level from Systems/Buildings (0 without it).
static func shed_level(tree: SceneTree) -> int:
	var b := tree.get_first_node_in_group(BUILDINGS_GROUP) if tree != null else null
	return int(b.call(&"level", SHED)) if b != null and b.has_method(&"level") else 0


## The shed's inventory (ShedStore in the tree) or null.
static func shed_inventory(tree: SceneTree) -> Inventory:
	var store := ShedStore.find(tree)
	return store.store() if store != null else null


## "" or why `player` cannot fetch `needs` now (level, shed, shortfall, room).
static func fetch_reason_for(tree: SceneTree, player: Player, needs: Dictionary) -> String:
	if player == null:
		return TEXT_BUSY
	return fetch_block_reason(needs, player.inventory, shed_inventory(tree), shed_level(tree), config())


## The request flow of a station / build site / the stone panel: checks, then a TimedAction of
## fetch_minutes (not cancellable; 0 → at once) → fetch → shed_supply_moved(&"fetch") + a note.
## Returns false (with a warning) when refused.
static func run_fetch(tree: SceneTree, player: Player, needs: Dictionary) -> bool:
	if player == null or player.is_busy() or is_instance_valid(player.carried):
		_warn(TEXT_BUSY)
		return false
	var reason := fetch_reason_for(tree, player, needs)
	if reason != "":
		_warn(reason)
		return false
	var wanted := needs.duplicate()
	var inv := player.inventory
	var finish := func() -> void: ShedSupply._finish_fetch(tree, wanted, inv)
	var minutes := fetch_minutes(shed_level(tree), config())
	if minutes <= 0:
		finish.call()
		return true
	return player.start_timed_action(LABEL_FETCH, minutes, finish, false, ANIM)


## Store the player's surplus at once (shed ≥ store_min_level); shed_supply_moved(&"store").
static func run_store(tree: SceneTree, player: Player) -> Dictionary:
	var cfg := config()
	var shed := shed_inventory(tree)
	if player == null or player.is_busy() or shed == null or shed_level(tree) < cfg.store_min_level:
		_warn(TEXT_BUSY if player == null or player.is_busy() else TEXT_NO_SHED)
		return {}
	var moved := store_surplus(player.inventory, shed, cfg)
	if moved.is_empty():
		EventBus.notification_requested.emit(TEXT_NOTHING_TO_STORE, &"info")
		return moved
	EventBus.shed_supply_moved.emit(moved, DIRECTION_STORE)
	EventBus.notification_requested.emit(TEXT_STORED % WorkshopRules.describe(moved), &"info")
	return moved


static func _finish_fetch(tree: SceneTree, needs: Dictionary, inv: Inventory) -> void:
	var moved := fetch(needs, inv, shed_inventory(tree))
	if moved.is_empty():
		_warn(TEXT_FAILED)
		return
	EventBus.shed_supply_moved.emit(moved, DIRECTION_FETCH)
	EventBus.notification_requested.emit(TEXT_FETCHED % WorkshopRules.describe(moved), &"info")


## {id: what the shed lacks of `gaps`}.
static func _shed_lacking(gaps: Dictionary, shed: Inventory) -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in gaps:
		var have := shed.count(StringName(str(id)))
		if have < int(gaps[id]):
			out[id] = int(gaps[id]) - have
	return out


static func _warn(text: String) -> void:
	EventBus.notification_requested.emit(text, &"warning")
