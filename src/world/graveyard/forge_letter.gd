class_name ForgeLetter
extends Node3D
## Phase 9 W-Welt (docs/PHASE9_DESIGN.md §1.3, §2.4.2 „Verbrennen: Hüttenofen oder Esse", W1-Anschlüsse 6): the letter
## prompt at the forge (child of Entities/station_forge, built by graveyard_build_phase9.gd). Once the forge stands and
## the gravekeeper carries a letter that may be burned there: „[E] Brief in der Esse verbrennen (2 Min)" (clip
## burn_letter like at the hut's stove) → Letters.decide(uid, burn, {place: forge}). Otherwise not focusable, the
## forge's own prompt stays. No state of its own.

const LETTERS_GROUP := &"letters"
const PLACE := &"forge"
const PROMPT := "[E] Brief in der Esse verbrennen (%d Min)"
const LABEL := "Brief verbrennen"
const ANIM := &"burn_letter"
const CLIP_KEY := &"stove_burn_letter"
## Above the station's own Interactable (5).
const PRIORITY := 6

## Size and centre of the reach box (station-local, the forge's footprint; set by the builder).
@export var reach_size: Vector3 = Vector3(2.4, 1.2, 2.4)
@export var reach_center: Vector3 = Vector3(0.0, 0.6, 0.0)

var interactable: Interactable


func _ready() -> void:
	interactable = get_node_or_null(^"Interactable") as Interactable
	if interactable == null:
		interactable = Interactable.new()
		interactable.name = "Interactable"
		interactable.priority = PRIORITY
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		box.size = reach_size
		shape.shape = box
		shape.position = reach_center
		interactable.add_child(shape)
		add_child(interactable)


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and burnable_letter(player) != ""


func get_interaction_prompt(player: Player) -> String:
	if burnable_letter(player) == "":
		return ""
	return PROMPT % _letters().get_config().burn_minutes


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var uid := burnable_letter(player)
	player.start_timed_action(LABEL, _letters().get_config().burn_minutes, _finish.bind(uid, player), false,
			ToolAnimConfig.clip_for(CLIP_KEY, ANIM))


## The forge stands (the parent station is built).
func forge_ready() -> bool:
	var station := get_parent()
	return station != null and station.has_method(&"is_available") and bool(station.call(&"is_available"))


## The first letter in the bag that may be burned at the forge ("" = none / no forge / no Letters).
func burnable_letter(player: Player) -> String:
	var letters := _letters()
	if letters == null or player == null or player.inventory == null or not forge_ready():
		return ""
	return letters.first_for(&"burn", player.inventory, {"place": PLACE})


func _finish(uid: String, player: Player) -> void:
	var letters := _letters()
	if letters != null and is_instance_valid(player):
		letters.decide(uid, &"burn", {"inventory": player.inventory, "place": PLACE})


func _letters() -> Letters:
	return get_tree().get_first_node_in_group(LETTERS_GROUP) as Letters if is_inside_tree() else null
