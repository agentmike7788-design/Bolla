class_name Phase5DayLog
extends Node
## What happened since the last day summary for its Phase-5 rows (docs/PHASE5_DESIGN.md §7):
## gathered items (resource_gathered), stations built (station_built), coins spent by purpose
## (coins_spent) and the number of crafts (the growth of stats.crafted). Pure bookkeeping of the
## UI – it listens only and never changes game state. take() hands the values over and starts
## anew; a load or a new game starts anew as well.
## Phase 6 (docs/PHASE6_DESIGN.md §7): building levels built (building_upgraded), services held
## (funeral_held) and boxes reinterred (bones_reinterred).

const STAT_CRAFTED := &"crafted"

## {item_id: amount}
var gathered: Dictionary = {}
var built: Array[StringName] = []
## {reason: coins}
var spent: Dictionary = {}
## [[building_id, level], …]
var buildings: Array = []
var services: int = 0
var reinterred: int = 0

var _crafted_base: int = 0


func _ready() -> void:
	EventBus.resource_gathered.connect(_on_gathered)
	EventBus.station_built.connect(_on_built)
	EventBus.coins_spent.connect(_on_spent)
	EventBus.building_upgraded.connect(_on_building_upgraded)
	EventBus.funeral_held.connect(_on_funeral_held)
	EventBus.bones_reinterred.connect(_on_bones_reinterred)
	EventBus.game_loaded.connect(reset.unbind(1))
	EventBus.new_game_started.connect(reset)
	reset()


func _exit_tree() -> void:
	for pair: Array in [[EventBus.resource_gathered, _on_gathered], [EventBus.station_built, _on_built],
			[EventBus.coins_spent, _on_spent], [EventBus.building_upgraded, _on_building_upgraded],
			[EventBus.funeral_held, _on_funeral_held], [EventBus.bones_reinterred, _on_bones_reinterred]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	for sig: Signal in [EventBus.game_loaded, EventBus.new_game_started]:
		for c: Dictionary in sig.get_connections():
			if c.callable.get_object() == self:
				sig.disconnect(c.callable)


func reset() -> void:
	gathered = {}
	built.clear()
	spent = {}
	buildings = []
	services = 0
	reinterred = 0
	_crafted_base = GameState.get_stat(STAT_CRAFTED)


func crafted() -> int:
	return maxi(GameState.get_stat(STAT_CRAFTED) - _crafted_base, 0)


## {gathered, crafted, built (Array[String] of station ids), spent} since the last take(); starts anew.
func take() -> Dictionary:
	var ids: Array[String] = []
	for id: StringName in built:
		ids.append(String(id))
	var out := {"gathered": gathered.duplicate(), "crafted": crafted(), "built": ids, "spent": spent.duplicate(),
			"buildings": buildings.duplicate(true), "services": services, "reinterred": reinterred}
	reset()
	return out


func _on_gathered(_node_id: String, item_id: StringName, amount: int) -> void:
	if amount > 0:
		gathered[item_id] = int(gathered.get(item_id, 0)) + amount


func _on_built(station_id: StringName) -> void:
	if not built.has(station_id):
		built.append(station_id)


func _on_spent(amount: int, reason: StringName) -> void:
	if amount > 0:
		spent[reason] = int(spent.get(reason, 0)) + amount


func _on_building_upgraded(building_id: StringName, level: int) -> void:
	buildings.append([String(building_id), level])


func _on_funeral_held(_corpse_id: String, _chapel_level: int, _fee: int) -> void:
	services += 1


func _on_bones_reinterred(_grave_id: String, count: int) -> void:
	reinterred += maxi(count, 1)
