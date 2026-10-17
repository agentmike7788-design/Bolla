class_name QuestLog
extends RefCounted
## STUB (P1) – the reader of the journal tab „Vorhaben" and the HUD (docs/PHASE9_DESIGN.md §2.1, §7.1, §3.4):
## groups main chain, side chains, large requests, requests (G8 Runde 6), orders (Phase 7), friendship (Phase 8),
## „Was du schuldest"; reads states only (never changes one).
## W1 (P1) fills the bodies; the signatures are the contract.

const GROUP_MAIN := &"main"
const GROUP_SIDE := &"side"
const GROUP_LARGE := &"large"
const GROUP_HILL := &"hill"
const GROUP_ORDERS := &"orders"
const GROUP_FRIEND := &"friend"
const GROUP_OWED := &"owed"
const GROUPS: Array[StringName] = [GROUP_MAIN, GROUP_SIDE, GROUP_LARGE, GROUP_HILL, GROUP_ORDERS, GROUP_FRIEND, GROUP_OWED]


## {group, id, title, giver, line, days_left, steps, pinned}
static func entries(_tree: SceneTree) -> Array[Dictionary]:
	return []


## The pinned entry → HUD line.
static func objective(_tree: SceneTree) -> Dictionary:
	return {}
