class_name ShedStore
extends Chest
## The shelves with the store book inside the shed (docs/PHASE6_DESIGN.md §2.5, §3.4, §4.8): a Chest
## with its own Inventory (save_id "shed_store", save_order 61, group &"shed_store"); [E] opens the
## &"chest" panel {storage, inventory, chest} (ChestTransfer moves the items). Slots 24 / 32 / 40 by
## shed level (ShedConfig.slots_by_level), level 3 doubles the stacks of RESOURCE / MATERIAL
## (stack_mult_by_level, stack_categories); a level change never shrinks, nothing is ever lost.
## Buildings.apply_levels calls apply_level; load_state first catches up with the shed level
## (Buildings loads earlier, save_order 32), so a saved store never loses slots.

const GROUP := &"shed_store"
const BUILDINGS_GROUP := &"buildings"
const SHED := &"shed"
const PROMPT_STORE := "[E] Lager öffnen"

## Rules; null = data/config/shed_config.tres (resolved lazily).
var config: ShedConfig


func _init() -> void:
	save_id = "shed_store"
	save_order = 61
	add_to_group(GROUP, true)


func _ready() -> void:
	# The empty store starts at the slots of the current level (0 while the shed is a site).
	storage.slot_count = _at(_cfg().slots_by_level, _shed_level(), 0)
	apply_level(_shed_level())


## slot_count and stack_multiplier of the level; never shrinks.
func apply_level(level: int) -> void:
	if storage == null:
		return
	var cfg := _cfg()
	storage.stack_categories = cfg.stack_categories.duplicate()
	var slots := _at(cfg.slots_by_level, level, 0)
	if slots > storage.slot_count:
		storage.slot_count = slots
	var mult := maxi(_at(cfg.stack_mult_by_level, level, 1), 1)
	if mult > storage.stack_multiplier:
		storage.stack_multiplier = mult


## The shed inventory (= storage).
func store() -> Inventory:
	return storage


func get_interaction_prompt(player: Player) -> String:
	if player != null and is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	return PROMPT_STORE


## {storage: Inventory.save_state()} (Chest) – the slot count follows the level (never below the
## saved number of slots).
func load_state(data: Dictionary) -> void:
	apply_level(_shed_level())
	var saved: Variant = data.get("storage")
	if saved is Dictionary and (saved as Dictionary).get("slots") is Array:
		var n := ((saved as Dictionary).slots as Array).size()
		if n > storage.slot_count:
			storage.slot_count = n
	super.load_state(data)


## The ShedStore in the tree (group shed_store) or null.
static func find(tree: SceneTree) -> ShedStore:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as ShedStore


func _shed_level() -> int:
	var b := get_tree().get_first_node_in_group(BUILDINGS_GROUP) if is_inside_tree() else null
	return int(b.call(&"level", SHED)) if b != null and b.has_method(&"level") else 0


func _cfg() -> ShedConfig:
	if config == null:
		config = Database.config(&"shed_config") as ShedConfig
		if config == null:
			config = ShedConfig.new()
	return config


static func _at(values: PackedInt32Array, index: int, fallback: int) -> int:
	if values.is_empty():
		return fallback
	return values[clampi(index, 0, values.size() - 1)]
