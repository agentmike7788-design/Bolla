class_name CorpseExamOrgans
extends RefCounted
## State of the specimen card „Präparate" at the crypt table (docs/PHASE7_DESIGN.md §2.6, §7) for
## CorpseExamTabs – read-only, from CorpseCare.organ_block_reason (per organ and allowed container; "-" =
## no card at all: anatomy unknown, not the crypt), the corpse record (taken / returned), Specimens (where
## each piece is now) and the AnatomyConfig (minutes, inputs). The card shows seven rows; nothing here
## changes game state.

const CARE_GROUP := &"corpse_care"
const SPECIMENS_GROUP := &"specimens"
const SHELF_GROUP := &"saveable"


## {visible, taken, max, clarity_word, rows: {organ: {organ, label, containers, reasons {container: reason},
## minutes, inputs {container: {item: n}}, taken, returned, where, consequence}}}.
static func state(tree: SceneTree, record: CorpseRecord, inv: Inventory) -> Dictionary:
	var out := {"visible": false, "taken": 0, "max": 3, "rows": {}, "clarity_word": ""}
	if tree == null or record == null:
		return out
	var care := tree.get_first_node_in_group(CARE_GROUP) as CorpseCare
	if care == null:
		return out
	var cfg := care.get_anatomy_config()
	out["max"] = cfg.max_per_corpse
	out["taken"] = SpecimenRules.organs_taken(record)
	out["clarity_word"] = SpecimenRules.clarity_word(record.freshness, cfg)
	var specimens := tree.get_first_node_in_group(SPECIMENS_GROUP) as Specimens
	var rows := {}
	var any := false
	for organ: StringName in AnatomyConfig.ORGANS:
		var row := cfg.organ(organ)
		if row.is_empty():
			continue
		var containers: Array[StringName] = []
		for c: Variant in row.get("containers", []):
			containers.append(StringName(str(c)))
		var reasons := {}
		var inputs := {}
		for c: StringName in containers:
			var reason := care.organ_block_reason(record.id, organ, c, inv)
			reasons[c] = reason
			if reason != SpecimenRules.REASON_NO_CARD:
				any = true
			inputs[c] = SpecimenRules.harvest_inputs(organ, c, cfg)
		rows[organ] = {"organ": organ, "label": str(row.get("label", organ)), "containers": containers, "reasons": reasons,
				"minutes": int(row.get("minutes", 20)), "inputs": inputs, "taken": record.is_harvested(organ),
				"returned": record.returned.has(organ), "where": where(tree, specimens, record.id, organ),
				"consequence": Phase7Texts.organ_consequence(organ, cfg)}
	out["rows"] = rows
	out["visible"] = any
	return out


## Where the piece of `organ` of this dead person is now („im Glas, in der Sammlung", „an Quast verkauft").
static func where(tree: SceneTree, specimens: Specimens, corpse_id: String, organ: StringName) -> String:
	if specimens == null:
		return ""
	for uid: String in specimens.of_corpse(corpse_id):
		var spec := specimens.get_record(uid)
		if spec == null or spec.organ != organ:
			continue
		var on_shelf := false
		var in_cold := false
		for node: Node in tree.get_nodes_in_group(SHELF_GROUP):
			if node is CollectionShelf and (node as CollectionShelf).storage.has_uid(uid):
				on_shelf = true
			elif node is PultStore and (node as PultStore).storage.has_uid(uid):
				in_cold = true
		return Phase7Texts.whereabouts(spec, on_shelf, in_cold)
	return ""
