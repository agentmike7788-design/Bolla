class_name ShedSupply
extends RefCounted
## STUB (P1) – fetching missing ingredients from the shed / storing the surplus
## (docs/PHASE6_DESIGN.md §2.5, §3.4). W1 (P1) fills the bodies; the signatures are the contract.

const DIRECTION_FETCH := &"fetch"
const DIRECTION_STORE := &"store"


## {id: missing in the player's inventory} (coins excluded).
static func shortfall(_needs: Dictionary, _inv: Inventory) -> Dictionary:
	return {}


## {id: amount in the shed}.
static func available(_needs: Dictionary, _shed: Inventory) -> Dictionary:
	return {}


## "" or why fetching is not possible („Im Schuppen fehlt: 2 Werkstein" · „Kein Platz im Inventar").
static func fetch_block_reason(_needs: Dictionary, _player_inv: Inventory, _shed: Inventory, _level: int, _cfg: ShedConfig) -> String:
	return ""


## Atomic; {id: moved} | {}.
static func fetch(_needs: Dictionary, _player_inv: Inventory, _shed: Inventory) -> Dictionary:
	return {}


## Level 3; all RESOURCE / MATERIAL of the player into the shed (no tools, coins, excluded items).
static func store_surplus(_player_inv: Inventory, _shed: Inventory, _cfg: ShedConfig) -> Dictionary:
	return {}
