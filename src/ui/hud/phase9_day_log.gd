class_name Phase9DayLog
extends Node
## What happened since the last day summary for its Phase-9 rows (docs/PHASE9_DESIGN.md §7.6): „Briefe" (letter_changed:
## found, decided, post received), „Bitten" (hill_request_part done, hill_request_changed completed / half / failed) and
## „Der Herr mit dem Koffer" (stranger_event: asked, sold – the offer's label –, bribed, case, left / expelled). Pure
## bookkeeping of the UI – it listens only and never changes game state. take() hands the values over and starts anew;
## a load or a new game starts anew as well.

const DECIDED: Array[StringName] = [&"posted", &"delivered", &"read_grave", &"answered", &"burned", &"buried"]
const ENDED: Array[StringName] = [&"completed", &"half", &"failed"]

var letters: Dictionary = {}
var requests: Dictionary = {}
var stranger: Dictionary = {}


func _init() -> void:
	name = "Phase9DayLog"


func _ready() -> void:
	EventBus.letter_changed.connect(_on_letter)
	EventBus.hill_request_part.connect(_on_part)
	EventBus.hill_request_changed.connect(_on_request)
	EventBus.stranger_event.connect(_on_stranger)
	EventBus.game_loaded.connect(reset.unbind(1))
	EventBus.new_game_started.connect(reset)
	reset()


func _exit_tree() -> void:
	for pair: Array in [[EventBus.letter_changed, _on_letter], [EventBus.hill_request_part, _on_part],
			[EventBus.hill_request_changed, _on_request], [EventBus.stranger_event, _on_stranger]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func reset() -> void:
	letters = {"found": 0, "decided": 0, "post": 0}
	requests = {"parts": 0, "completed": 0, "half": 0, "failed": 0}
	stranger = {"asked": false, "sold": [], "bribed": false, "case": false, "left": false}


## {letters, requests, stranger} and a fresh start.
func take() -> Dictionary:
	var out := {"letters": letters.duplicate(), "requests": requests.duplicate(), "stranger": stranger.duplicate(true)}
	reset()
	return out


func _on_letter(_uid: String, _letter_id: StringName, state: StringName) -> void:
	if state == &"found":
		letters.found = int(letters.found) + 1
	elif state == &"received":
		letters.post = int(letters.post) + 1
	elif state in DECIDED:
		letters.decided = int(letters.decided) + 1


func _on_part(_id: StringName, _part: int, done: bool) -> void:
	if done:
		requests.parts = int(requests.parts) + 1


func _on_request(_id: StringName, state: StringName) -> void:
	if state in ENDED:
		requests[String(state)] = int(requests.get(String(state), 0)) + 1


func _on_stranger(kind: StringName, detail: String) -> void:
	match kind:
		&"asked":
			stranger.asked = true
		&"sold":
			var offer := Database.stranger_offer(StringName(detail)) as StrangerOfferData
			(stranger.sold as Array).append(offer.label if offer != null and offer.label != "" else detail)
		&"bribed":
			stranger.bribed = detail == "yes"
		&"case":
			stranger.case = true
		&"left", &"expelled":
			stranger.left = true
