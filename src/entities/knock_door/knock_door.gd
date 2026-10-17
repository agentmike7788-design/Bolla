class_name KnockDoor
extends Node3D
## A house door to knock at, without an interior (docs/PHASE9_DESIGN.md §2.2.3 H4, §3.1, §3.4, §4.3, §4.6 D8): door_sieber
## at the Siebers' house door. „[E] Bei den Siebers anklopfen" → dialogue sieber_door (Anna answers as a voice behind
## the door; the door is the speaker); at night with the nameless_letter while ending A is still open: „[E] Brief an die
## Tür stecken" → WhoKnows.post_letter. Phase 9 only (p9_open); a free player with empty hands.

const PROMPT_KNOCK := "[E] Bei den Siebers anklopfen"
const PROMPT_LETTER := "[E] Brief an die Tür stecken"
const OPEN_FLAG := &"p9_open"
const NAMELESS_ITEM := &"nameless_letter"
const WHO_KNOWS_GROUP := &"who_knows"

@export var door_id: StringName = &""
## Dialogue of the voice behind the door.
@export var dialogue_id: StringName = &"sieber_door"
## The household behind the door (DialogueActions / Conditions read the speaker's npc_id – kin conditions).
@export var npc_id: StringName = &"kin_sieber"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	if player == null or player.is_busy() or is_instance_valid(player.carried):
		return false
	return GameState.flag_on(OPEN_FLAG)


func get_interaction_prompt(player: Player) -> String:
	if not can_interact(player):
		return ""
	return PROMPT_LETTER if letter_possible(player) else PROMPT_KNOCK


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	if letter_possible(player):
		var who := _who_knows()
		if who != null:
			who.post_letter(player.inventory)
		return
	EventBus.dialogue_requested.emit(dialogue_id, self)


## At night, with the nameless letter, while WhoKnows still waits for it (ending A not decided yet).
func letter_possible(player: Player) -> bool:
	if player == null or player.inventory == null or not player.inventory.has(NAMELESS_ITEM) or not TimeManager.is_night():
		return false
	var who := _who_knows()
	return who != null and not who.letter_posted()


func _who_knows() -> WhoKnows:
	return get_tree().get_first_node_in_group(WHO_KNOWS_GROUP) as WhoKnows if is_inside_tree() else null
