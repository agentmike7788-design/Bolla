class_name AnatomyConfig
extends Resource
## Anatomy – specimens at the crypt table, Quast, the lecture (docs/PHASE7_DESIGN.md §2.6, §2.6.4,
## §3.4): data/config/anatomy_config.tres. W0: the class defaults hold the contract values of §2.6
## (organs table, lecture block) so data == fixture == class default until the hand-over.

const ORGANS: Array[StringName] = [&"heart", &"lung", &"stomach", &"liver", &"kidneys", &"eyes", &"hand"]

## organ → {label, containers [jar|bundle], minutes, base_price, quality, reputation_event, piety,
## mood, return_piety, sell_rel {priest, washer, oldwoman}, lecture_bonus, medicine, res_tag,
## res_weight (+ res_role for the hand)} – §2.6 table, §2.6.4 Organzuschlag, §2.7 medicine, Phase-13 hooks.
@export var organs: Dictionary[StringName, Dictionary] = {
	&"heart": {"label": "Herz", "containers": [&"jar", &"bundle"], "minutes": 20, "base_price": 7, "quality": -2,
			"reputation_event": &"organ_taken", "piety": -8, "mood": -5, "return_piety": 3,
			"sell_rel": {&"priest": -4, &"washer": -3, &"oldwoman": -2}, "lecture_bonus": 2, "medicine": false,
			"res_tag": &"will", "res_weight": 3},
	&"lung": {"label": "Lunge", "containers": [&"jar", &"bundle"], "minutes": 20, "base_price": 4, "quality": -2,
			"reputation_event": &"organ_taken", "piety": -6, "mood": -5, "return_piety": 3,
			"sell_rel": {&"priest": -4, &"washer": -3, &"oldwoman": -2}, "lecture_bonus": 1, "medicine": true,
			"res_tag": &"breath", "res_weight": 1},
	&"stomach": {"label": "Magen", "containers": [&"jar", &"bundle"], "minutes": 20, "base_price": 5, "quality": -2,
			"reputation_event": &"organ_taken", "piety": -6, "mood": -5, "return_piety": 3,
			"sell_rel": {&"priest": -4, &"washer": -3, &"oldwoman": -2}, "lecture_bonus": 1, "medicine": true,
			"res_tag": &"hunger", "res_weight": 1},
	&"liver": {"label": "Leber", "containers": [&"jar", &"bundle"], "minutes": 20, "base_price": 5, "quality": -2,
			"reputation_event": &"organ_taken", "piety": -6, "mood": -5, "return_piety": 3,
			"sell_rel": {&"priest": -4, &"washer": -3, &"oldwoman": -2}, "lecture_bonus": 1, "medicine": true,
			"res_tag": &"blood_heat", "res_weight": 1},
	&"kidneys": {"label": "Nieren", "containers": [&"jar", &"bundle"], "minutes": 20, "base_price": 4, "quality": -2,
			"reputation_event": &"organ_taken", "piety": -6, "mood": -5, "return_piety": 3,
			"sell_rel": {&"priest": -4, &"washer": -3, &"oldwoman": -2}, "lecture_bonus": 1, "medicine": true,
			"res_tag": &"water", "res_weight": 1},
	&"eyes": {"label": "Augen", "containers": [&"jar"], "minutes": 25, "base_price": 9, "quality": -3,
			"reputation_event": &"organ_taken_grave", "piety": -12, "mood": -8, "return_piety": 5,
			"sell_rel": {&"priest": -6, &"washer": -5, &"oldwoman": -2}, "lecture_bonus": 3, "medicine": false,
			"res_tag": &"sight", "res_weight": 2},
	&"hand": {"label": "Hand", "containers": [&"bundle"], "minutes": 30, "base_price": 10, "quality": -3,
			"reputation_event": &"organ_taken_grave", "piety": -12, "mood": -8, "return_piety": 5,
			"sell_rel": {&"priest": -6, &"washer": -5, &"oldwoman": -2}, "lecture_bonus": 4, "medicine": false,
			"res_tag": &"grip", "res_weight": 3, "res_role": &"frame"},
}
## „Mehr nimmst du ihr nicht." – organs per corpse (hair / teeth do not count).
@export var max_per_corpse: int = 3
## Jar for the eyes: the small dark jar with two seals.
@export var small_jar_inputs: Dictionary[StringName, int] = {&"prep_jar_small": 1, &"spirits": 1}
## Bundle for the hand: linen + wax.
@export var hand_inputs: Dictionary[StringName, int] = {&"linen": 1, &"beeswax": 1}
## Sound hook of the tool (Agent 17 inactive – nothing plays in Phase 7).
@export var sound_cue: StringName = &"anatomy_tool"
## Pult: inspect (Begutachten) minutes; Quast's expertise (Gutachten) minutes; minimum clarity.
@export var inspect_minutes: int = 20
@export var expertise_minutes: int = 30
@export var inspect_min_clarity: float = 0.5
## Pult: bone specimen of the hand (minutes).
@export var bone_minutes: int = 60
## §2.6.4: every_days, start (minute of day), window (minutes from start the door is open: 23:00–00:30),
## minutes (the TimedAction), fee, standing_bonus, piety, rumor_chance(_esteemed), rumor_rep,
## rumor_rel {priest, washer}, veil_alpha.
@export var lecture: Dictionary = {"every_days": 3, "start": 1380, "window": 90, "minutes": 60, "fee": 4, "standing_bonus": 1,
		"piety": -3, "rumor_chance": 0.25, "rumor_chance_esteemed": 0.10, "rumor_rep": -4,
		"rumor_rel": {&"priest": -3, &"washer": -2}, "veil_alpha": 0.6}
@export var tool_item: StringName = &"anatomy_case"
## The morgue table of this room only (the crypt).
@export var room_id: StringName = &"crypt"
## „Zu spät. Daran lässt sich nichts mehr zeigen." below this freshness.
@export var min_freshness: float = 0.3
@export var jar_inputs: Dictionary[StringName, int] = {&"prep_jar": 1, &"spirits": 1}
@export var bundle_inputs: Dictionary[StringName, int] = {&"linen": 1}
## A bundle's clarity falls linearly to 0 over these effective minutes (× pult_cold_factor in the cold box).
@export var bundle_minutes: int = 600
@export var pult_cold_factor: float = 0.25
## Clarity words: ≥ [0] „sehr gut", ≥ [1] „gut", ≥ [2] „trüb", below „kaum lesbar".
@export var clarity_words: PackedFloat32Array = [0.8, 0.6, 0.45]
## Teachings that come with the case (§2.6.5).
@export var basic_teachings: Array[StringName] = [&"l_lung", &"l_liver"]
## §2.6.1 prices: bundle × 0.5; display × 1.5 + 2; Quast „Befreundet" +1.
@export var bundle_price_factor: float = 0.5
@export var display_price_factor: float = 1.5
@export var display_price_bonus: int = 2
@export var friend_price_bonus: int = 1
## Minutes: return to the grave, seal a bundle, prepare a display specimen.
@export var return_minutes: int = 10
@export var seal_minutes: int = 5
@export var display_minutes: int = 40
## The veil during a specimen (§2.6, §7).
@export var veil_seconds: float = 0.6
@export var veil_alpha: float = 0.85
@export var known_flag: StringName = &"anatomy_known"


## The organ's row ({} if unknown).
func organ(id: StringName) -> Dictionary:
	return organs.get(id, {})
