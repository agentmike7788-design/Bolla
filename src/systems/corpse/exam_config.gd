class_name ExamConfig
extends Resource
## Examination steps (docs/PHASE4_DESIGN.md §2.1): data/config/exam_config.tres.

const STEP_KEYS: PackedStringArray = ["id", "label", "verb", "minutes"]

## [{id: &"clothing", label: "Kleidung", verb: "Kleidung durchsehen", minutes: 10}, …] in the
## order of CorpseRecord.STEPS (clothing, hands, wounds, pockets).
@export var steps: Array[Dictionary] = []
## Steps that are closed once the corpse is dressed.
@export var locked_by_dress: Array[StringName] = [&"clothing", &"pockets"]
@export var nothing_text: String = "Nichts Auffälliges."
## Trait → the step whose completion reveals it.
@export var trait_steps: Dictionary[StringName, StringName] = {&"valuables": &"pockets", &"letter": &"pockets", &"tattoo": &"hands", &"strange_wound": &"wounds"}


## The step entry of `id`, {} if unknown.
func step(id: StringName) -> Dictionary:
	for s: Dictionary in steps:
		if StringName(s.get("id", &"")) == id:
			return s
	return {}


func step_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Dictionary in steps:
		out.append(StringName(s.get("id", &"")))
	return out


## Minutes of `id` (0 if unknown).
func step_minutes(id: StringName) -> int:
	return int(step(id).get("minutes", 0))
