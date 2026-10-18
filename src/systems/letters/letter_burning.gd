class_name LetterBurning
extends RefCounted
## Phase 9 W3 QA-Fix (QA9-01, QA9-03): burning a letter at the hut's stove or the forge only after the gravekeeper
## chose *which* letter – a short choice (&"action_choice") with one row per letter of the bag that may be burned
## there („Verbrennen: An Rosine Wackernagel, Holderkrug (2 Min)"). Before, [E] burned the first such letter at once
## and could not be undone (the forge's own [E] and „Am Ofen wärmen" were gone while one was in the bag).
## Shared by Stove and ForgeLetter; the burn itself stays Letters.decide(uid, burn, {place}) at the end of the timed
## action with the clip burn_letter.

const PANEL := &"action_choice"
const PREFIX := "burn:"
const OPTION := "Verbrennen: %s (%d Min)"
const LABEL := "Brief verbrennen"
const ANIM := &"burn_letter"
const CLIP_KEY := &"stove_burn_letter"
const QUESTION := "Welcher Brief soll ins Feuer? Das lässt sich nicht zurücknehmen."


## The letters of `inv` that may be burned at `place` (&"stove" | &"forge"), in the order of Letters.open_uids.
static func burnable(letters: Letters, inv: Inventory, place: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	if letters == null or inv == null:
		return out
	var ctx := {"inventory": inv, "place": place}
	for uid: String in letters.open_uids():
		if not inv.has_uid(uid):
			continue
		for c: Dictionary in letters.choices(uid, ctx):
			if StringName(str(c.id)) == LetterRules.CHOICE_BURN and str(c.reason) == "":
				out.append(uid)
	return out


## One option {id burn:<uid>, label} per burnable letter.
static func options(letters: Letters, inv: Inventory, place: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for uid: String in burnable(letters, inv, place):
		out.append({"id": StringName(PREFIX + uid), "label": OPTION % [letters.label_of(uid), letters.get_config().burn_minutes]})
	return out


## The uid of a burn option ("" = not a burn option).
static func uid_of(option_id: StringName) -> String:
	var s := String(option_id)
	return s.substr(PREFIX.length()) if s.begins_with(PREFIX) else ""


## Starts the timed burn of `uid` at `place` (only if it may still be burned there). Returns true when started.
static func start(letters: Letters, player: Player, uid: String, place: StringName) -> bool:
	if letters == null or player == null or player.is_busy() or not uid in burnable(letters, player.inventory, place):
		return false
	return player.start_timed_action(LABEL, letters.get_config().burn_minutes, finish.bind(letters, uid, player, place), false,
			ToolAnimConfig.clip_for(CLIP_KEY, ANIM))


static func finish(letters: Letters, uid: String, player: Player, place: StringName) -> void:
	if is_instance_valid(letters) and is_instance_valid(player):
		letters.decide(uid, LetterRules.CHOICE_BURN, {"inventory": player.inventory, "place": place})
