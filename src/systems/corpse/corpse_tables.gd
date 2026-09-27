class_name CorpseTables
extends Resource
## Generation tables for corpses (data/corpses/corpse_tables.tres).
## causes: [{id: StringName, label: String, description: String, weight: float, decay_mult: float, base_payment: int}]
## traits: [{id: StringName, label: String, reveal_text: String, chance: float}]

@export var first_names: PackedStringArray = []
@export var last_names: PackedStringArray = []
## First names that belong to women – the corpse's look follows name and age (Corpse.variant_for_record).
@export var female_first_names: PackedStringArray = []
## From this age a man is shown with the "old man" look.
@export var old_age: int = 60
@export var age_min: int = 18
@export var age_max: int = 88
@export var causes: Array[Dictionary] = []
@export var traits: Array[Dictionary] = []
## Day -> trait ids that are forced (and the only random-free traits) that day. Missing day = random.
@export var forced_traits_by_day: Dictionary[int, PackedStringArray] = {}
@export var base_decay_per_hour: float = 0.05
## Minute of day at which the carter delivers (07:40).
@export var delivery_minute: int = 460
@export var valuables_coins_min: int = 5
@export var valuables_coins_max: int = 8


func get_cause(id: StringName) -> Dictionary:
	for c: Dictionary in causes:
		if StringName(c.get("id", &"")) == id:
			return c
	return {}


func get_trait(id: StringName) -> Dictionary:
	for t: Dictionary in traits:
		if StringName(t.get("id", &"")) == id:
			return t
	return {}
