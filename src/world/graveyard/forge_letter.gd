class_name ForgeLetter
extends Node3D
## Phase 9 W-Welt (docs/PHASE9_DESIGN.md §1.3, §2.4.2 „Verbrennen: Hüttenofen oder Esse", W1-Anschlüsse 6): burning a
## letter at the forge (child of Entities/station_forge, built by graveyard_build_phase9.gd). No state of its own.
## W3 QA-Fix QA9-01: the forge's [E] stays the forge (charcoal, smithing) – this node has no prompt of its own any
## more (before it won the focus with priority 6 and [E] burned the first letter of the bag at once). Once the forge
## stands and a letter of the bag may be burned there, the forge's crafting panel shows „Brief verbrennen …"
## (CraftingPanel.letter_button) → open_choice: one row per such letter (&"action_choice", LetterBurning) → the chosen
## letter burns (2 Min, clip burn_letter, Letters.decide burn with place forge).

const LETTERS_GROUP := &"letters"
const PLACE := &"forge"
const TITLE_CHOICE := "An der Esse"
const LABEL := LetterBurning.LABEL
const ANIM := LetterBurning.ANIM
const CLIP_KEY := LetterBurning.CLIP_KEY

## Kept for the built scene (graveyard.tscn sets them); the forge's own Interactable is the only reach now.
@export var reach_size: Vector3 = Vector3(2.4, 1.2, 2.4)
@export var reach_center: Vector3 = Vector3(0.0, 0.6, 0.0)

## The player of the last open_choice (the choice runs for them).
var _player: Player


## Never focusable by itself: the station's prompt stays.
func get_interaction_prompt(_player_arg: Player) -> String:
	return ""


## The crafting panel's button: there is a letter to burn here.
func can_burn(player: Player) -> bool:
	return player != null and not player.is_busy() and burnable_letter(player) != ""


## Opens the choice of the letters that may be burned here (false = none).
func open_choice(player: Player) -> bool:
	if not can_burn(player):
		return false
	_player = player
	EventBus.ui_panel_requested.emit(LetterBurning.PANEL, choice_context(player))
	return true


func choice_context(player: Player) -> Dictionary:
	return {"title": TITLE_CHOICE, "question": LetterBurning.QUESTION, "target": self, "player": player,
			"options": LetterBurning.options(_letters(), player.inventory if player != null else null, PLACE)}


## The choice's answer burn:<uid>.
func request_action(id: StringName) -> void:
	var player := _player if is_instance_valid(_player) else null
	if player == null or not forge_ready() or not LetterBurning.start(_letters(), player, LetterBurning.uid_of(id), PLACE):
		EventBus.notification_requested.emit(GravePlot.TEXT_CARE_FAILED, &"warning")


## The forge stands (the parent station is built).
func forge_ready() -> bool:
	var station := get_parent()
	return station != null and station.has_method(&"is_available") and bool(station.call(&"is_available"))


## The first letter in the bag that may be burned at the forge ("" = none / no forge / no Letters).
func burnable_letter(player: Player) -> String:
	if player == null or not forge_ready():
		return ""
	var all := LetterBurning.burnable(_letters(), player.inventory, PLACE)
	return all[0] if not all.is_empty() else ""


func _letters() -> Letters:
	return get_tree().get_first_node_in_group(LETTERS_GROUP) as Letters if is_inside_tree() else null
