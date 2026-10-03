class_name SpecimenRecord
extends RefCounted
## One specimen – an individual piece with the dead person's name on its label (docs/PHASE7_DESIGN.md
## §2.6, §3.4, §5.1). Pure data: Specimens keeps the records, the inventory slot carries the uid.
## to_dict keeps native types (JSON.from_native saves); from_dict also accepts plain JSON values and
## falls back to the defaults for missing or malformed values (tolerant, save fuzzer).

const CONTAINER_JAR := &"jar"
const CONTAINER_BUNDLE := &"bundle"
const CONTAINER_DISPLAY := &"display"
const CONTAINER_BONE := &"bone"
const CONTAINERS: Array[StringName] = [CONTAINER_JAR, CONTAINER_BUNDLE, CONTAINER_DISPLAY, CONTAINER_BONE]
## researched = Quast's expertise (the piece stays with him), used = a medicine, lectured = stays in his cabinet.
const STATES: Array[StringName] = [&"held", &"sold", &"researched", &"lectured", &"used", &"returned"]
const STATE_HELD := &"held"

## "sp_0007".
var uid: String = ""
var corpse_id: String = ""
## Label name incl. age („Hedwig Lamprecht, 58" is built by Specimens.label from name + record).
var corpse_name: String = ""
## AnatomyConfig.ORGANS.
var organ: StringName = &""
var container: StringName = CONTAINER_JAR
## Freshness of the corpse at the end of the harvest (0.3…1.0).
var clarity_at_harvest: float = 1.0
## Total minutes at the end of the harvest.
var harvest_total: int = 0
## Total minutes / clarity when a bundle was sealed into a jar (-1 = never).
var sealed_total: int = -1
var sealed_clarity: float = -1.0
## Cold windows of a bundle in the pult's cold box: [start, end (-1 = open), factor‰, …].
var cold_windows: PackedInt32Array = []
var state: StringName = STATE_HELD
## Finding card once inspected / researched (&"" = none yet).
var finding_id: StringName = &""
## Game day of the harvest.
var day: int = 0


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"corpse_id": corpse_id,
		"corpse_name": corpse_name,
		"organ": organ,
		"container": container,
		"clarity_at_harvest": clarity_at_harvest,
		"harvest_total": harvest_total,
		"sealed_total": sealed_total,
		"sealed_clarity": sealed_clarity,
		"cold_windows": Array(cold_windows),
		"state": state,
		"finding_id": finding_id,
		"day": day,
	}


## Missing or malformed values fall back to the defaults of a new record; an unknown container /
## state falls back too.
static func from_dict(d: Dictionary) -> SpecimenRecord:
	var r := SpecimenRecord.new()
	r.uid = CorpseRecord._to_str(d.get("uid"), r.uid)
	r.corpse_id = CorpseRecord._to_str(d.get("corpse_id"), r.corpse_id)
	r.corpse_name = CorpseRecord._to_str(d.get("corpse_name"), r.corpse_name)
	r.organ = StringName(CorpseRecord._to_str(d.get("organ"), String(r.organ)))
	var c := StringName(CorpseRecord._to_str(d.get("container"), String(r.container)))
	r.container = c if c in CONTAINERS else r.container
	r.clarity_at_harvest = clampf(CorpseRecord._to_float(d.get("clarity_at_harvest"), r.clarity_at_harvest), 0.0, 1.0)
	r.harvest_total = CorpseRecord._to_int(d.get("harvest_total"), r.harvest_total)
	r.sealed_total = CorpseRecord._to_int(d.get("sealed_total"), r.sealed_total)
	r.sealed_clarity = CorpseRecord._to_float(d.get("sealed_clarity"), r.sealed_clarity)
	r.cold_windows = CorpseRecord._to_cold_windows(d.get("cold_windows"))
	var s := StringName(CorpseRecord._to_str(d.get("state"), String(r.state)))
	r.state = s if s in STATES else r.state
	r.finding_id = StringName(CorpseRecord._to_str(d.get("finding_id"), ""))
	r.day = CorpseRecord._to_int(d.get("day"), r.day)
	return r
