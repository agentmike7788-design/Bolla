class_name RegisterCopy
extends Node3D
## The copy of the death register on the lectern in the office (docs/PHASE7_DESIGN.md §1.6, §3.4, §4.3):
## „[E] Die Abschrift lesen" (Fenner present ∧ (trusted ∨ a donation today)) →
## JournalManager.add_clue(c_v_deathbook); else „Das ist Gemeindesache, Totengräber."

const PROMPT := "[E] Die Abschrift lesen"
const TEXT_REFUSED := "Das ist Gemeindesache, Totengräber."
const TEXT_READ := "Am Rand, neben fünf Namen, ein kleiner Dreistrich. Die Tinte ist älter als die Einträge daneben."
const TEXT_KNOWN := "Du hast die Seite schon gelesen. Der Dreistrich steht immer noch da."
const CLUE := &"c_v_deathbook"
const MAYOR := &"mayor"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return GameState.flag_on(&"village_open")


func get_interaction_prompt(_player: Player) -> String:
	return PROMPT if GameState.flag_on(&"village_open") else ""


## Fenner present and (relationship „Vertraut" or a donation today).
func allowed() -> bool:
	var village := _first(&"village") as Village
	if village != null and not village.villager_present(MAYOR):
		return false
	var rel := _first(&"relationships")
	var value := int(rel.call(&"value", MAYOR)) if rel != null and rel.has_method(&"value") else 0
	var cfg := Database.config(&"relationship_config") as RelationshipConfig
	if OrderRules.tier_index(OrderRules.rel_tier(value, cfg)) >= OrderRules.tier_index(&"trusted"):
		return true
	return village != null and village.donations_today() > 0


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	if not allowed():
		EventBus.notification_requested.emit(TEXT_REFUSED, &"info")
		return
	var journal := _first(&"journal")
	if journal != null and journal.has_method(&"has_clue") and bool(journal.call(&"has_clue", CLUE)):
		EventBus.notification_requested.emit(TEXT_KNOWN, &"info")
		return
	EventBus.notification_requested.emit(TEXT_READ, &"info")
	if journal != null and journal.has_method(&"add_clue"):
		journal.call(&"add_clue", CLUE, "", false)


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null
