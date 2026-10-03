class_name PultRules
extends RefCounted
## Rules of the preparation desk in the crypt (docs/PHASE7_DESIGN.md §2.6, §2.7, §3.4): a medicine from a
## specimen in a jar (allowed organs – never heart, eyes or hand –, clarity ≥ min_clarity, ingredients),
## sealing a bundle into a jar, a display specimen (jar + wax + ink), the bone specimen of the hand
## (hand bundle + wax + linen), inspecting (jar / bone / display, clarity ≥ inspect_min_clarity, once).
## The *_block_reason functions are pure ("" = possible). make_medicine runs a medicine at the end of
## its TimedAction: Specimens.consume(uid, inv, &"used"), ingredients gone, the output into the
## inventory, stats.medicines_made. The pult itself is the Phase-5 station `pult` (Workbench in the
## crypt, built from village_open with crypt level ≥ 1 – site_block_reason).
## Spoiled = SpecimenRules.is_spoiled or a clarity of 0 (a bundle at the end of its 600 minutes).

const STATION_ID := &"pult"
const SITE_FLAG := &"village_open"
const SITE_BUILDING := &"crypt"
const SITE_MIN_LEVEL := 1
const STATE_USED := &"used"
const STAT_MEDICINES := &"medicines_made"
const NOTE_KIND := &"info"
## Further ingredients of the display / bone specimen (§1.3, §2.7) – Specimens.make_display / make_bone
## take them together with the piece.
const DISPLAY_INPUTS: Dictionary[StringName, int] = {&"beeswax": 1, &"ink": 1}
const BONE_INPUTS: Dictionary[StringName, int] = {&"beeswax": 1, &"linen": 1}

const TEXT_NO_PIECE := "Kein Präparat gewählt."
const TEXT_GONE := "Das Stück ist nicht mehr da."
const TEXT_NOT_HELD := "Das Präparat musst du dabeihaben."
const TEXT_UNKNOWN := "Kein Rezept dafür."
const TEXT_NO_MEDICINE := "Daraus macht Quasts Rezeptbuch keine Arznei."
const FORMAT_WRONG_ORGAN := "Dafür braucht es: %s."
const TEXT_JAR_ONLY := "Nur ein Präparat im Glas."
const TEXT_SEAL_FIRST := "Erst einlegen – Quasts Rezept will ein Glas."
const TEXT_TOO_DIM := "Zu trüb dafür."
const TEXT_SPOILED := "Verdorben. Es bleibt nur das Grab."
const FORMAT_MISSING := "Es fehlt: %s"
const TEXT_NO_ROOM := "Kein Platz im Inventar"
const TEXT_NOT_BUNDLE := "Nur ein Bündel lässt sich einlegen."
const TEXT_HAND_NO_SEAL := "Die Hand wird nicht eingelegt. Mach ein Knochenpräparat daraus."
const TEXT_HAND_ONLY := "Nur die Hand im Bündel wird zum Knochenpräparat."
const TEXT_INSPECT_BUNDLE := "Ein Bündel lässt sich nicht begutachten. Erst einlegen."
const TEXT_INSPECT_DIM := "Zu trüb, um etwas zu erkennen."
const TEXT_INSPECTED := "Schon begutachtet."
const TEXT_NO_BOOK := "Quasts Rezeptbuch fehlt."
const TEXT_SITE_CLOSED := "Hier ist noch kein Platz für ein Pult."
const FORMAT_MADE := "%d × %s, nach Quast."


static func medicine_block_reason(med: MedicineData, spec: SpecimenRecord, inv: Inventory, now_total: int, cfg: AnatomyConfig) -> String:
	if med == null:
		return TEXT_UNKNOWN
	var reason := _piece_reason(spec, inv)
	if reason != "":
		return reason
	var c := _cfg(cfg)
	if not bool(c.organ(spec.organ).get("medicine", false)):
		return TEXT_NO_MEDICINE
	if not med.organs.has(spec.organ):
		return FORMAT_WRONG_ORGAN % _organ_list(med.organs, c)
	if spec.container == SpecimenRecord.CONTAINER_BUNDLE:
		return TEXT_SEAL_FIRST
	if spec.container != SpecimenRecord.CONTAINER_JAR:
		return TEXT_JAR_ONLY
	if spoiled(spec, now_total, c):
		return TEXT_SPOILED
	if SpecimenRules.clarity(spec, now_total, c) < med.min_clarity:
		return TEXT_TOO_DIM
	var gaps := missing(med.inputs, inv)
	if not gaps.is_empty():
		return FORMAT_MISSING % WorkshopRules.describe(gaps)
	if med.output == &"" or not inv.can_add(med.output, maxi(med.amount, 1)):
		return TEXT_NO_ROOM
	return ""


static func seal_block_reason(spec: SpecimenRecord, inv: Inventory, now_total: int, cfg: AnatomyConfig) -> String:
	var reason := _piece_reason(spec, inv)
	if reason != "":
		return reason
	if spec.container != SpecimenRecord.CONTAINER_BUNDLE:
		return TEXT_NOT_BUNDLE
	if spec.organ == &"hand":
		return TEXT_HAND_NO_SEAL
	var c := _cfg(cfg)
	if spoiled(spec, now_total, c):
		return TEXT_SPOILED
	var gaps := missing(c.jar_inputs, inv)
	if not gaps.is_empty():
		return FORMAT_MISSING % WorkshopRules.describe(gaps)
	return ""


static func display_block_reason(spec: SpecimenRecord, inv: Inventory, _cfg_unused: AnatomyConfig) -> String:
	var reason := _piece_reason(spec, inv)
	if reason != "":
		return reason
	if spec.container == SpecimenRecord.CONTAINER_BUNDLE:
		return TEXT_SEAL_FIRST
	if spec.container != SpecimenRecord.CONTAINER_JAR:
		return TEXT_JAR_ONLY
	var gaps := missing(DISPLAY_INPUTS, inv)
	if not gaps.is_empty():
		return FORMAT_MISSING % WorkshopRules.describe(gaps)
	return ""


static func bone_block_reason(spec: SpecimenRecord, inv: Inventory, now_total: int, cfg: AnatomyConfig) -> String:
	var reason := _piece_reason(spec, inv)
	if reason != "":
		return reason
	if spec.organ != &"hand" or spec.container != SpecimenRecord.CONTAINER_BUNDLE:
		return TEXT_HAND_ONLY
	if spoiled(spec, now_total, _cfg(cfg)):
		return TEXT_SPOILED
	var gaps := missing(BONE_INPUTS, inv)
	if not gaps.is_empty():
		return FORMAT_MISSING % WorkshopRules.describe(gaps)
	return ""


## Inspect at the pult: jar / bone / display with clarity ≥ inspect_min_clarity, not spoiled, once
## (the finding card exists afterwards). The piece stays (Specimens.inspect).
static func inspect_block_reason(spec: SpecimenRecord, now_total: int, cfg: AnatomyConfig) -> String:
	if spec == null:
		return TEXT_NO_PIECE
	if spec.state != SpecimenRecord.STATE_HELD:
		return TEXT_GONE
	if spec.container == SpecimenRecord.CONTAINER_BUNDLE:
		return TEXT_INSPECT_BUNDLE
	var c := _cfg(cfg)
	if spoiled(spec, now_total, c):
		return TEXT_SPOILED
	if SpecimenRules.clarity(spec, now_total, c) < c.inspect_min_clarity:
		return TEXT_INSPECT_DIM
	if spec.finding_id != &"":
		return TEXT_INSPECTED
	return ""


## Quast's recipe book came with the case (flag anatomy_known).
static func book_known(cfg: AnatomyConfig) -> bool:
	return GameState.flag_on(_cfg(cfg).known_flag)


## The medicine at the end of its TimedAction (§2.7): "" check again, then Specimens.consume(uid, inv,
## used), the ingredients, the output into `inv`, stats.medicines_made, a note. false = nothing changed.
static func make_medicine(med: MedicineData, uid: String, inv: Inventory, specimens: Specimens, now_total: int,
		cfg: AnatomyConfig) -> bool:
	if specimens == null or inv == null or not book_known(cfg):
		return false
	var spec := specimens.get_record(uid)
	if medicine_block_reason(med, spec, inv, now_total, cfg) != "":
		return false
	if not specimens.consume(uid, inv, STATE_USED):
		return false
	for id: StringName in med.inputs:
		inv.remove_item(id, int(med.inputs[id]))
	var n := maxi(med.amount, 1)
	var rest := inv.add_item(med.output, n)
	if rest > 0:
		push_warning("[PultRules] make_medicine: %d × %s did not fit" % [rest, med.output])
	GameState.add_stat(STAT_MEDICINES, 1)
	EventBus.notification_requested.emit(FORMAT_MADE % [n, WorkshopRules.amount_name(med.output, n)], NOTE_KIND)
	return true


## The medicines one specimen could become (MedicineData whose organs include it), Database order.
static func medicines_for(organ: StringName, meds: Array[MedicineData]) -> Array[MedicineData]:
	var out: Array[MedicineData] = []
	for m: MedicineData in meds:
		if m != null and m.organs.has(organ):
			out.append(m)
	return out


## The pult site in the crypt: open from village_open with the crypt on level ≥ 1.
static func site_block_reason(village_open: bool, crypt_level: int) -> String:
	if not village_open or crypt_level < SITE_MIN_LEVEL:
		return TEXT_SITE_CLOSED
	return ""


static func spoiled(spec: SpecimenRecord, now_total: int, cfg: AnatomyConfig) -> bool:
	if spec == null:
		return false
	var c := _cfg(cfg)
	if SpecimenRules.is_spoiled(spec, now_total, c):
		return true
	return spec.container == SpecimenRecord.CONTAINER_BUNDLE and SpecimenRules.clarity(spec, now_total, c) <= 0.0


## {item: missing amount} of `inputs` in `inv` ({} = all there).
static func missing(inputs: Dictionary[StringName, int], inv: Inventory) -> Dictionary:
	var gaps := {}
	for id: StringName in inputs:
		var need := int(inputs[id])
		var have := inv.count(id) if inv != null else 0
		if have < need:
			gaps[id] = need - have
	return gaps


static func _piece_reason(spec: SpecimenRecord, inv: Inventory) -> String:
	if spec == null:
		return TEXT_NO_PIECE
	if spec.state != SpecimenRecord.STATE_HELD:
		return TEXT_GONE
	if inv == null or not inv.has_uid(spec.uid):
		return TEXT_NOT_HELD
	return ""


static func _organ_list(organs: Array[StringName], c: AnatomyConfig) -> String:
	var names: PackedStringArray = []
	for o: StringName in organs:
		names.append(str(c.organ(o).get("label", String(o))))
	return " oder ".join(names)


static func _cfg(cfg: AnatomyConfig) -> AnatomyConfig:
	if cfg != null:
		return cfg
	var loaded := Database.config(&"anatomy_config") as AnatomyConfig
	return loaded if loaded != null else AnatomyConfig.new()
