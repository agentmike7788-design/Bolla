class_name MorgueTablePanelState
extends RefCounted
## Read-only view model of the Phase-4 examination panel (docs/PHASE4_DESIGN.md §7): what the
## tabs Untersuchen / Herrichten / Verwerten show for the corpse on the table. Built by
## MorgueTable.panel_state(); the buttons call the MorgueTable.request_* methods.
##
## {
##   corpse_id, story_id, freshness, stage, examined, needs_valuables_decision,
##   steps: [{id, label, verb, minutes, done, reason}],        # config order; reason "" = possible
##   open_steps: Array[StringName], exam_all_minutes: int,
##   finds: [{id, step, label, text, state (&"revealed" | &"lost"), clue_id}],   # resolved only
##   nothing_steps: Array[StringName], nothing_text,           # done steps without any find
##   next_loss: CorpseExam.next_loss dict | {},
##   prep: {wash: {minutes, done, reason}, lay_out: {…}, balm: {minutes, active, until, reason},
##          dress: {current, shroud: {minutes, reason, item}, gown: {…}}, dress_warning},
##   harvest_visible: bool,
##   harvest: {hair: {label, verb, minutes, item, done, reason}, teeth: {…}},   # reason "-" = hidden
## }

const STATE_REVEALED := &"revealed"
const STATE_LOST := &"lost"
const DRESS_WARNING := "Nach dem Einkleiden sind Kleidung und Taschen nicht mehr zugänglich."


static func build(record: CorpseRecord, care: CorpseCare, inv: Inventory) -> Dictionary:
	if record == null or care == null:
		return {}
	var id := record.id
	var exam := care.get_exam_config()
	var prep := care.get_prep_config()
	var now := TimeManager.total_minutes()
	var steps: Array[Dictionary] = []
	var nothing: Array[StringName] = []
	var finds: Array[Dictionary] = []
	for s: Dictionary in exam.steps:
		var step := StringName(s.get("id", &""))
		steps.append({"id": step, "label": String(s.get("label", "")), "verb": String(s.get("verb", "")),
				"minutes": int(s.get("minutes", 0)), "done": record.is_step_done(step), "reason": care.step_block_reason(id, step)})
		if not record.is_step_done(step):
			continue
		var any := false
		for f: FindData in care.step_finds(id, step):
			var revealed := record.finds_revealed.has(f.id)
			if not revealed and not record.finds_lost.has(f.id):
				continue
			any = true
			finds.append({"id": f.id, "step": step, "label": f.label, "text": care.find_text(id, f.id),
					"state": STATE_REVEALED if revealed else STATE_LOST, "clue_id": f.clue_id})
		if not any:
			nothing.append(step)
	var dress := {"current": record.dress}
	for kind: StringName in prep.dress:
		dress[kind] = {"minutes": CorpsePrep.minutes(CorpsePrep.ACTION_DRESS, prep, kind), "item": prep.dress_item(kind),
				"reason": care.prep_block_reason(id, CorpsePrep.ACTION_DRESS, inv, kind)}
	var harvest := {}
	var util := care.get_utilization_config()
	var visible := false
	for kind: StringName in util.kinds:
		var entry := util.kind(kind)
		var reason := care.harvest_block_reason(id, kind, inv)
		visible = visible or reason != UtilizationRules.HIDDEN
		harvest[kind] = {"label": String(entry.get("label", "")), "verb": String(entry.get("verb", "")),
				"minutes": int(entry.get("minutes", 0)), "item": StringName(entry.get("item", &"")),
				"done": record.is_harvested(kind), "reason": reason}
	return {
		"corpse_id": id,
		"story_id": record.story_id,
		"freshness": record.freshness,
		"stage": record.freshness_stage(),
		"examined": record.examined,
		"needs_valuables_decision": record.needs_valuables_decision(),
		"steps": steps,
		"open_steps": care.open_steps(id),
		"exam_all_minutes": care.exam_all_minutes(id),
		"finds": finds,
		"nothing_steps": nothing,
		"nothing_text": exam.nothing_text,
		"next_loss": care.next_loss(id),
		"prep": {
			"wash": {"minutes": prep.wash_minutes, "done": record.washed, "reason": care.prep_block_reason(id, CorpsePrep.ACTION_WASH, inv)},
			"dress": dress,
			"dress_warning": DRESS_WARNING,
			"lay_out": {"minutes": prep.lay_out_minutes, "done": record.laid_out, "reason": care.prep_block_reason(id, CorpsePrep.ACTION_LAY_OUT, inv)},
			"balm": {"minutes": prep.balm_minutes, "active": CorpsePrep.is_balm_active(record, now),
					"until": CorpsePrep.balm_end(record, now), "reason": care.prep_block_reason(id, CorpsePrep.ACTION_BALM, inv)},
		},
		"harvest_visible": visible,
		"harvest": harvest,
	}
