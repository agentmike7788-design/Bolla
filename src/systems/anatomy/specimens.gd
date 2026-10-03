class_name Specimens
extends Node
## Systems/Specimens (docs/PHASE7_DESIGN.md §2.6, §3.1, §3.3, §3.4, §5.1), groups &"specimens",
## &"saveable": the records of every specimen (uid → SpecimenRecord); the inventory slot carries the
## uid (Inventory.add_unique). harvest / sell / expertise / inspect / consume / seal / make_display /
## make_bone / return_to_grave; bundles spoil (check_spoiled on hour_changed / time_skipped).
## A specimen only ever exists as a sealed jar, a linen bundle, a display jar or a bone specimen in
## linen – the label carries the name; nothing else is shown.
## Other systems are called directly through their groups (corpse_manager, piety, relationships,
## deductions, lectures, journal, graveyard); listeners never change state here.

const GROUP := &"specimens"
## The four item ids every specimen shares (the organ is in the record).
const ITEM_JAR := &"specimen_jar"
const ITEM_BUNDLE := &"specimen_bundle"
const ITEM_DISPLAY := &"display_specimen"
const ITEM_BONE := &"bone_specimen"
const ITEMS: Array[StringName] = [ITEM_JAR, ITEM_BUNDLE, ITEM_DISPLAY, ITEM_BONE]
const UID_FORMAT := "sp_%04d"
const COIN_ITEM := &"coin"
const SURGEON := &"surgeon"
const FRIEND_TIER := &"friend"
const STATE_SOLD := &"sold"
const STATE_RESEARCHED := &"researched"
const STATE_LECTURED := &"lectured"
const STATE_USED := &"used"
const STATE_RETURNED := &"returned"
## specimen_changed states without a record state of their own.
const CHANGE_TAKEN := &"taken"
const CHANGE_SEALED := &"sealed"
const CHANGE_DISPLAYED := &"displayed"
const CHANGE_BONED := &"boned"
const CHANGE_SPOILED := &"spoiled"
## Pult inputs (§2.7) not in AnatomyConfig: display = 1 beeswax + 1 ink, bone = 1 beeswax + 1 linen.
const DISPLAY_INPUTS: Dictionary[StringName, int] = {&"beeswax": 1, &"ink": 1}
const BONE_INPUTS: Dictionary[StringName, int] = {&"beeswax": 1, &"linen": 1}
## University standing (CollectionShelf, P7) adds +1 per level to a sale, at most +2 (§2.6.1, §2.7).
const STAT_STANDING := &"university_standing"
const STANDING_PRICE_MAX := 2
const STAT_TAKEN := &"specimens_taken"
const STAT_SOLD := &"specimens_sold"
const STAT_RESEARCHED := &"specimens_researched"
const STAT_RETURNED := &"specimens_returned"
const EXPERTISE_REL := 3
const TEXT_SPOILED := "Das Bündel von %s ist verdorben."
const TEXT_GONE := "Das Präparat ist nicht mehr da."
const TEXT_NOT_HERE := "Das gehört nicht in dieses Grab."
const TEXT_GRAVE := "Erst bestatten, dann beisetzen."
const REASON_SALE := "Präparat an Quast: %s"
const REASON_RETURN := "Präparat beigesetzt: %s"
const REASON_EXPERTISE := "Gutachten: %s"
const SELL_REL_BASE := &"heart"

@export var save_id: String = "specimens"
@export var save_order: int = 54

## Rules; null = data/config/anatomy_config.tres (resolved lazily).
var config: AnatomyConfig
## Findings in the order of §2.6.3; empty = Database.findings().
var findings: Array[SpecimenFindingData] = []

var _records: Dictionary[String, SpecimenRecord] = {}
var _next: int = 1
## uids whose „verdorben" note was shown (saved, so a load does not repeat it).
var _spoiled_noted: PackedStringArray = []


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.time_skipped.connect(_on_time_skipped)


func get_record(uid: String) -> SpecimenRecord:
	return _records.get(uid)


## uids in state held (sorted).
func held() -> PackedStringArray:
	var out := PackedStringArray()
	for uid: String in _sorted_uids():
		if _records[uid].state == SpecimenRecord.STATE_HELD:
			out.append(uid)
	return out


func of_corpse(corpse_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for uid: String in _sorted_uids():
		if _records[uid].corpse_id == corpse_id:
			out.append(uid)
	return out


## „Herz – Hedwig Lamprecht, 58 – Klarheit gut" („verdorben" for a spoiled bundle).
func label(uid: String) -> String:
	var spec := get_record(uid)
	if spec == null:
		return ""
	var organ := String(_cfg().organ(spec.organ).get("label", String(spec.organ)))
	var who := spec.corpse_name
	var record := _corpse(spec.corpse_id)
	if record != null and record.age > 0:
		who = "%s, %d" % [who, record.age]
	var now := TimeManager.total_minutes()
	var word := SpecimenRules.WORD_SPOILED if SpecimenRules.is_spoiled(spec, now, _cfg()) \
			else "Klarheit " + SpecimenRules.clarity_word(clarity(uid), _cfg())
	return "%s – %s – %s" % [organ, who, word]


## Clarity of now (0 for an unknown uid).
func clarity(uid: String) -> float:
	return SpecimenRules.clarity(get_record(uid), TimeManager.total_minutes(), _cfg())


func is_spoiled(uid: String) -> bool:
	return SpecimenRules.is_spoiled(get_record(uid), TimeManager.total_minutes(), _cfg())


## uid | ""; takes the inputs, add_unique; specimen_changed(taken). The corpse's own bookkeeping
## (harvested, piety, reputation, stats) is CorpseCare.harvest_organ's – this only makes the piece.
## Clarity = the corpse's freshness now (the end of the harvest).
func harvest(corpse_id: String, organ: StringName, container: StringName, inv: Inventory) -> String:
	var record := _corpse(corpse_id)
	var cfg := _cfg()
	if record == null or inv == null or cfg.organ(organ).is_empty() or not SpecimenRules.allows(organ, container, cfg):
		return ""
	var inputs := SpecimenRules.harvest_inputs(organ, container, cfg)
	var item := SpecimenRules.item_for(container)
	for id: StringName in inputs:
		if not inv.has(id, inputs[id]):
			return ""
	if not inv.can_add(item, 1):
		return ""
	var uid := _new_uid()
	for id: StringName in inputs:
		inv.remove_item(id, inputs[id])
	if not inv.add_unique(item, uid):
		for id: StringName in inputs:
			inv.add_item(id, inputs[id])
		return ""
	var spec := SpecimenRecord.new()
	spec.uid = uid
	spec.corpse_id = corpse_id
	spec.corpse_name = record.display_name
	spec.organ = organ
	spec.container = container
	spec.clarity_at_harvest = clampf(record.freshness, 0.0, 1.0)
	spec.harvest_total = TimeManager.total_minutes()
	spec.day = TimeManager.day
	_records[uid] = spec
	EventBus.specimen_changed.emit(uid, CHANGE_TAKEN)
	return uid


## Quast's price of now incl. the university standing (+1 per level, at most +2) and „Befreundet".
func sale_price(uid: String) -> int:
	var spec := get_record(uid)
	if spec == null or spec.state != SpecimenRecord.STATE_HELD:
		return 0
	var base := SpecimenRules.price(spec, TimeManager.total_minutes(), _friend(), _cfg())
	return base + standing_bonus() if base > 0 else 0


## min(stats.university_standing, 2).
func standing_bonus() -> int:
	return clampi(GameState.get_stat(STAT_STANDING), 0, STANDING_PRICE_MAX)


## "" = Quast takes it: held, in `inv`, not spoiled.
func sell_block_reason(uid: String, inv: Inventory) -> String:
	var spec := get_record(uid)
	if spec == null or spec.state != SpecimenRecord.STATE_HELD or inv == null or not inv.has_uid(uid):
		return TEXT_GONE
	if is_spoiled(uid):
		return "Verdorben. Das nimmt Quast nicht."
	return ""


## Quast's panel only opens in his dialogue (he is there). remove_uid; coins; the village hears of it
## (Relationships.on_specimen_sold + the heavier eyes / hand deltas); stats.specimens_sold; state sold.
func sell(uid: String, inv: Inventory) -> int:
	if sell_block_reason(uid, inv) != "":
		return 0
	var spec := get_record(uid)
	var coins := sale_price(uid)
	if coins <= 0 or not inv.remove_uid(uid):
		return 0
	inv.add_item(COIN_ITEM, coins)
	spec.state = STATE_SOLD
	GameState.add_stat(STAT_SOLD, 1)
	var organ := organ_label(spec.organ)
	EventBus.payment_received.emit(coins, REASON_SALE % organ)
	var rel := _first(&"relationships") as Relationships
	if rel != null:
		rel.on_specimen_sold()
		var row := _cfg().organ(spec.organ).get("sell_rel", {}) as Dictionary
		var base := _cfg().organ(SELL_REL_BASE).get("sell_rel", {}) as Dictionary
		for npc: Variant in row:
			var extra := int(row[npc]) - int(base.get(npc, 0))
			if extra != 0:
				rel.add(StringName(str(npc)), extra, REASON_SALE % organ)
	EventBus.specimen_changed.emit(uid, STATE_SOLD)
	_notify(spec.corpse_id)
	return coins


## "" = Quast can give his expertise: held, in `inv`, not spoiled.
func expertise_block_reason(uid: String, inv: Inventory) -> String:
	return sell_block_reason(uid, inv)


## Quast's expertise after the TimedAction: the piece stays with him (remove_uid, state researched);
## finding card (Deductions.add_card, its clue), the organ's teaching (Lectures.learn), Quast +3,
## stats.specimens_researched. {finding, text, teaching, learned, reveals_cause} ({} = refused).
func expertise(uid: String, inv: Inventory) -> Dictionary:
	if expertise_block_reason(uid, inv) != "":
		return {}
	var spec := get_record(uid)
	var finding := _finding(spec)
	if not inv.remove_uid(uid):
		return {}
	spec.state = STATE_RESEARCHED
	spec.finding_id = finding.id if finding != null else &""
	_add_card(spec, finding)
	var teaching := Lectures.teaching_of(spec.organ)
	var lectures := _first(&"lectures") as Lectures
	var learned := lectures.learn(teaching) if lectures != null and teaching != &"" else false
	var rel := _first(&"relationships") as Relationships
	if rel != null:
		rel.add(SURGEON, EXPERTISE_REL, REASON_EXPERTISE % organ_label(spec.organ))
	GameState.add_stat(STAT_RESEARCHED, 1)
	EventBus.specimen_changed.emit(uid, STATE_RESEARCHED)
	_notify(spec.corpse_id)
	return {"finding": spec.finding_id, "text": finding.text if finding != null else "", "teaching": teaching,
			"learned": learned, "reveals_cause": finding.reveals_cause if finding != null else &""}


## Inspect at the pult: the finding id (finding_for), the piece stays; Deductions.add_card. A jar, bone
## or display specimen with clarity ≥ inspect_min_clarity; &"" = refused.
func inspect(uid: String) -> StringName:
	var spec := get_record(uid)
	if spec == null or spec.state != SpecimenRecord.STATE_HELD or spec.container == SpecimenRecord.CONTAINER_BUNDLE:
		return &""
	if clarity(uid) < _cfg().inspect_min_clarity:
		return &""
	var finding := _finding(spec)
	if finding == null:
		return &""
	spec.finding_id = finding.id
	_add_card(spec, finding)
	_notify(spec.corpse_id)
	return finding.id


## Lecture (lectured) and medicine (used): remove_uid, state, specimen_changed.
func consume(uid: String, inv: Inventory, state: StringName) -> bool:
	var spec := get_record(uid)
	if spec == null or spec.state != SpecimenRecord.STATE_HELD or not state in [STATE_LECTURED, STATE_USED]:
		return false
	if inv == null or not inv.remove_uid(uid):
		return false
	spec.state = state
	EventBus.specimen_changed.emit(uid, state)
	_notify(spec.corpse_id)
	return true


## Hand bundle (not spoiled) + 1 beeswax + 1 linen → bone_specimen (new item id, same uid); it no
## longer spoils (sealed_* freeze the clarity of now).
func make_bone(uid: String, inv: Inventory) -> bool:
	var spec := get_record(uid)
	if spec == null or spec.organ != CorpseRecord.HARVEST_HAND or spec.container != SpecimenRecord.CONTAINER_BUNDLE:
		return false
	return _convert(spec, inv, BONE_INPUTS, SpecimenRecord.CONTAINER_BONE, CHANGE_BONED)


## Bundle (not the hand, not spoiled) + jar inputs → jar with the clarity of this moment (same uid).
func seal(uid: String, inv: Inventory) -> bool:
	var spec := get_record(uid)
	if spec == null or spec.organ == CorpseRecord.HARVEST_HAND or spec.container != SpecimenRecord.CONTAINER_BUNDLE:
		return false
	return _convert(spec, inv, _cfg().jar_inputs, SpecimenRecord.CONTAINER_JAR, CHANGE_SEALED)


## Jar + 1 beeswax + 1 ink → display specimen (same uid, same clarity).
func make_display(uid: String, inv: Inventory) -> bool:
	var spec := get_record(uid)
	if spec == null or spec.container != SpecimenRecord.CONTAINER_JAR:
		return false
	return _convert(spec, inv, DISPLAY_INPUTS, SpecimenRecord.CONTAINER_DISPLAY, CHANGE_DISPLAYED)


## "" = it can go back into `grave_id`: held (a spoiled bundle too), the grave of this dead person,
## FILLED or MARKED. Sold, lectured, used or researched pieces are gone for good.
func return_block_reason(uid: String, grave_id: String) -> String:
	var spec := get_record(uid)
	if spec == null or spec.state != SpecimenRecord.STATE_HELD:
		return TEXT_GONE
	var graveyard := _first(&"graveyard") as Graveyard
	var grave := graveyard.get_grave(grave_id) if graveyard != null else null
	if grave == null or grave.corpse_id != spec.corpse_id:
		return TEXT_NOT_HERE
	if grave.state != GraveRecord.State.FILLED and grave.state != GraveRecord.State.MARKED:
		return TEXT_GRAVE
	return ""


## „Präparat beisetzen" after the TimedAction: remove_uid; record.returned + organ (the ghost no
## longer counts it as robbed); piety + return_piety; Relationships.on_specimen_returned;
## stats.specimens_returned; state returned. Quality and reputation stay.
func return_to_grave(uid: String, grave_id: String, inv: Inventory) -> bool:
	if return_block_reason(uid, grave_id) != "" or inv == null or not inv.has_uid(uid):
		return false
	var spec := get_record(uid)
	if not inv.remove_uid(uid):
		return false
	spec.state = STATE_RETURNED
	var record := _corpse(spec.corpse_id)
	if record != null and record.harvested.has(spec.organ) and not record.returned.has(spec.organ):
		record.returned.append(spec.organ)
	var label_text := REASON_RETURN % organ_label(spec.organ)
	var piety := _first(&"piety") as Piety
	if piety != null:
		piety.change(int(_cfg().organ(spec.organ).get("return_piety", 0)), label_text)
	var rel := _first(&"relationships") as Relationships
	if rel != null:
		rel.on_specimen_returned()
	GameState.add_stat(STAT_RETURNED, 1)
	EventBus.specimen_changed.emit(uid, STATE_RETURNED)
	_notify(spec.corpse_id)
	return true


## PultStore on in / out: a bundle's cold window opens (factor pult_cold_factor) / closes.
func note_cold(uid: String, entering: bool) -> void:
	var spec := get_record(uid)
	if spec == null or spec.container != SpecimenRecord.CONTAINER_BUNDLE:
		return
	var now := TimeManager.total_minutes()
	var w := spec.cold_windows
	var open := -1
	for i: int in range(0, w.size() - 2, 3):
		if w[i + 1] < 0:
			open = i
	if entering and open < 0:
		w.append(now)
		w.append(-1)
		w.append(roundi(clampf(_cfg().pult_cold_factor, 0.0, 1.0) * 1000.0))
	elif not entering and open >= 0:
		w[open + 1] = now
	spec.cold_windows = w


## hour_changed: a note once per spoiled bundle, specimen_changed(spoiled).
func check_spoiled(now_total: int) -> void:
	for uid: String in _sorted_uids():
		var spec := _records[uid]
		if spec.state != SpecimenRecord.STATE_HELD or _spoiled_noted.has(uid):
			continue
		if SpecimenRules.is_spoiled(spec, now_total, _cfg()):
			_spoiled_noted.append(uid)
			EventBus.notification_requested.emit(TEXT_SPOILED % spec.corpse_name, &"info")
			EventBus.specimen_changed.emit(uid, CHANGE_SPOILED)


## Phase-13 hook (only counted): held, not spoiled specimens of `organ`, the collection included.
func kept(organ: StringName) -> int:
	var n := 0
	var now := TimeManager.total_minutes()
	for uid: String in _records:
		var spec := _records[uid]
		if spec.organ == organ and spec.state == SpecimenRecord.STATE_HELD and not SpecimenRules.is_spoiled(spec, now, _cfg()):
			n += 1
	return n


## {next, records: [SpecimenRecord.to_dict()]} (§5.1) + spoiled_noted while any; {} without records.
func save_state() -> Dictionary:
	if _records.is_empty() and _next <= 1:
		return {}
	var list: Array = []
	for uid: String in _sorted_uids():
		list.append(_records[uid].to_dict())
	var out := {"next": _next, "records": list}
	if not _spoiled_noted.is_empty():
		out["spoiled_noted"] = Array(_spoiled_noted)
	return out


func load_state(data: Dictionary) -> void:
	_records.clear()
	_spoiled_noted = PackedStringArray()
	_next = maxi(int(data.get("next", 1)) if (data.get("next") is int or data.get("next") is float) else 1, 1)
	var list: Variant = data.get("records")
	if list is Array:
		for d: Variant in list:
			if d is Dictionary:
				var r := SpecimenRecord.from_dict(d)
				if r.uid != "":
					_records[r.uid] = r
					_next = maxi(_next, _uid_number(r.uid) + 1)
	var noted: Variant = data.get("spoiled_noted")
	if noted is Array or noted is PackedStringArray:
		for v: Variant in noted:
			if _records.has(str(v)) and not _spoiled_noted.has(str(v)):
				_spoiled_noted.append(str(v))


## A held uid without an inventory slot anywhere → a warning, the state stays (fuzzer).
func post_load() -> void:
	if not is_inside_tree() or _records.is_empty():
		return
	var found := {}
	for node: Node in get_tree().root.find_children("*", "Inventory", true, false):
		for uid: String in (node as Inventory).uids():
			found[uid] = true
	for uid: String in held():
		if not found.has(uid):
			push_warning("[Specimens] held specimen %s has no inventory slot" % uid)


# --- helpers ------------------------------------------------------------------------------------

func _convert(spec: SpecimenRecord, inv: Inventory, inputs: Dictionary[StringName, int], container: StringName,
		change: StringName) -> bool:
	var now := TimeManager.total_minutes()
	if inv == null or spec.state != SpecimenRecord.STATE_HELD or not inv.has_uid(spec.uid):
		return false
	if SpecimenRules.is_spoiled(spec, now, _cfg()):
		return false
	for id: StringName in inputs:
		if not inv.has(id, inputs[id]):
			return false
	var value := SpecimenRules.clarity(spec, now, _cfg())
	var old_item := inv.uid_item(spec.uid)
	if not inv.remove_uid(spec.uid):
		return false
	if not inv.add_unique(SpecimenRules.item_for(container), spec.uid):
		inv.add_unique(old_item, spec.uid)
		return false
	for id: StringName in inputs:
		inv.remove_item(id, inputs[id])
	if spec.container == SpecimenRecord.CONTAINER_BUNDLE:
		spec.sealed_total = now
		spec.sealed_clarity = value
		_close_cold(spec, now)
	spec.container = container
	EventBus.specimen_changed.emit(spec.uid, change)
	_notify(spec.corpse_id)
	return true


func _close_cold(spec: SpecimenRecord, now: int) -> void:
	var w := spec.cold_windows
	for i: int in range(0, w.size() - 2, 3):
		if w[i + 1] < 0:
			w[i + 1] = now
	spec.cold_windows = w


func _finding(spec: SpecimenRecord) -> SpecimenFindingData:
	return SpecimenRules.finding_for(spec, _corpse(spec.corpse_id), _findings())


## The card goes to Deductions (and its clue to the journal).
func _add_card(spec: SpecimenRecord, finding: SpecimenFindingData) -> void:
	if finding == null:
		return
	var deductions := _first(&"deductions") as Deductions
	if deductions != null:
		deductions.add_card(spec.corpse_id, finding.id)
	if finding.clue_id != &"":
		var journal := _first(&"journal") as JournalManager
		if journal != null:
			journal.add_clue(finding.clue_id, spec.corpse_id)


func _findings() -> Array[SpecimenFindingData]:
	if findings.is_empty():
		for res: Resource in Database.findings():
			if res is SpecimenFindingData:
				findings.append(res as SpecimenFindingData)
	return findings


func _friend() -> bool:
	var rel := _first(&"relationships") as Relationships
	return rel != null and rel.tier(SURGEON) == FRIEND_TIER


func _new_uid() -> String:
	var uid := UID_FORMAT % _next
	while _records.has(uid):
		_next += 1
		uid = UID_FORMAT % _next
	_next += 1
	return uid


static func _uid_number(uid: String) -> int:
	var digits := uid.get_slice("_", 1)
	return int(digits) if digits.is_valid_int() else 0


func _sorted_uids() -> Array[String]:
	var keys: Array[String] = []
	keys.assign(_records.keys())
	keys.sort()
	return keys


## „Herz", „Augen" … (AnatomyConfig label).
func organ_label(organ: StringName) -> String:
	return String(_cfg().organ(organ).get("label", String(organ)))


func get_config() -> AnatomyConfig:
	return _cfg()


func _corpse(corpse_id: String) -> CorpseRecord:
	var manager := _first(&"corpse_manager") as CorpseManager
	return manager.get_record(corpse_id) if manager != null and corpse_id != "" else null


func _notify(corpse_id: String) -> void:
	var manager := _first(&"corpse_manager") as CorpseManager
	if manager != null and manager.get_record(corpse_id) != null:
		manager.notify_changed(corpse_id)


func _cfg() -> AnatomyConfig:
	if config == null:
		config = Database.config(&"anatomy_config") as AnatomyConfig
		if config == null:
			config = AnatomyConfig.new()
	return config


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _on_hour_changed(_day: int, _hour: int) -> void:
	check_spoiled(TimeManager.total_minutes())


func _on_time_skipped(_from_total: int, to_total: int) -> void:
	check_spoiled(to_total)
