extends TestCase
## P2 (docs/PHASE8_DESIGN.md §2.2.4, §3.4, §10): GraveView – the precedence disturbed > neglected > bare > kept,
## the bonus (fresh flowers / wax wreath, a candle last night, a vase ≤ 1.5 m), the specimen rumour (sold
## counts, returned does not); the effects in Visitors – reputation (visit_pleased at most twice a day,
## visit_neglected, visit_disturbed, visit_specimen_rumor once per dead), goodwill, Rosine's shield.

const Harness := preload("res://tests/unit/visitors_harness.gd")


## Specimens read by GraveView: of_corpse / get_record.
class SpecimensDouble extends Specimens:
	var recs: Dictionary = {}

	func _ready() -> void:
		pass

	func of_corpse(corpse_id: String) -> PackedStringArray:
		var out := PackedStringArray()
		for uid: Variant in recs:
			if (recs[uid] as SpecimenRecord).corpse_id == corpse_id:
				out.append(String(uid))
		return out

	func get_record(uid: String) -> SpecimenRecord:
		return recs.get(uid) as SpecimenRecord


var h: Harness
var cfg: VisitorConfig


func before_each() -> void:
	GameState.reset()
	cfg = Phase8Fixtures.visitor_config()
	TimeManager.load_state({"day": 55, "minute_of_day": 600})
	h = Harness.new()
	h.setup(tree)
	h.households_only()


func after_each() -> void:
	h.teardown()
	await wait_frames(1)
	GameState.reset()


func _view(grave: String) -> Dictionary:
	return GraveView.view(grave, tree, cfg)


func test_precedence() -> void:
	h.bury("l_01", &"house_kehr", 50)
	assert_eq(_view("l_01").view, &"kept", "cross, clean")
	h.graveyard.get_grave("l_01").state = GraveRecord.State.FILLED
	assert_eq(_view("l_01").view, &"bare", "no marker yet")
	h.clean.levels["dirt_l_01"] = 2
	assert_eq(_view("l_01").view, &"neglected", "care spot ≥ 2 before bare")
	h.clean.levels["dirt_l_01"] = 1
	assert_eq(_view("l_01").view, &"bare", "level 1 still kept / bare")
	h.care.set_disturbed("l_01")
	h.clean.levels["dirt_l_01"] = 3
	assert_eq(_view("l_01").view, &"disturbed", "first")
	assert_eq(GraveView.VIEWS, [&"disturbed", &"neglected", &"bare", &"kept"])


func test_bonus_flowers_wreath_candle_vase() -> void:
	h.bury("l_01", &"house_kehr", 50)
	assert_false(_view("l_01").bonus)
	h.inv.add_item(&"flower_seedlings", 1)
	h.care.plant("l_01", h.inv)
	assert_true(_view("l_01").bonus, "fresh grave flowers")
	h.care.remove_flowers("l_01")
	h.inv.add_item(&"wax_wreath", 1)
	h.care.lay_wreath("l_01", h.inv)
	assert_true(_view("l_01").bonus, "a wax wreath counts as flowers")
	h.care.remove_flowers("l_01")
	h.care.place_bouquet("l_01")
	assert_false(_view("l_01").bonus, "a visitor's own bouquet is no bonus")
	TimeManager.load_state({"day": 55, "minute_of_day": 1000})
	h.care.light_free("l_01")
	TimeManager.load_state({"day": 56, "minute_of_day": 600})
	assert_true(_view("l_01").bonus, "a candle last night")
	TimeManager.load_state({"day": 58, "minute_of_day": 600})
	assert_false(_view("l_01").bonus)
	h.vase("l_01", Vector2(0.0, -2.4))
	assert_true(_view("l_01").bonus, "a vase 1.4 m from the head")
	h.decor.list.clear()
	h.vase("l_01", Vector2(2.2, 0.0))
	assert_false(_view("l_01").bonus, "1.7 m from the side")


func test_specimen_rumour_sold_not_returned() -> void:
	var r := h.bury("l_01", &"house_kehr", 50)
	var specs := SpecimensDouble.new()
	h.root.add_child(specs)
	var s := SpecimenRecord.new()
	s.uid = "sp_1"
	s.corpse_id = r.id
	s.state = Specimens.STATE_RETURNED
	specs.recs["sp_1"] = s
	assert_eq(_view("l_01").specimen_rumor, "", "returned ones do not count")
	s.state = Specimens.STATE_SOLD
	assert_eq(_view("l_01").specimen_rumor, r.id)


func test_effects_of_the_look() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	h.clock(1000)
	assert_eq(h.rep.events, [&"visit_pleased"], "kept: +1")
	assert_eq(h.visitors.goodwill(&"kin_kehr"), 6, "goodwill +1")


func test_pleased_at_most_twice_a_day() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.bury("l_02", &"house_brandt", 54)
	h.bury("l_03", &"house_ott", 54)
	h.plan(55)
	h.clock(1200)
	assert_eq(h.rep.count(&"visit_pleased"), 2, "cap 2 a day")
	assert_eq(h.visitors.goodwill(&"kin_ott"), 6, "goodwill still +1")


func test_neglected_and_disturbed() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.bury("l_02", &"house_brandt", 54)
	h.clean.levels["dirt_l_01"] = 2
	h.care.set_disturbed("l_02")
	h.plan(55)
	h.clock(1200)
	assert_eq(h.rep.count(&"visit_neglected"), 1)
	assert_eq(h.rep.count(&"visit_disturbed"), 1)
	assert_eq(h.visitors.goodwill(&"kin_kehr"), 4, "−1")
	assert_eq(h.visitors.goodwill(&"kin_brandt"), 1, "−4")


func test_shield_cancels_a_minus() -> void:
	var shield := Harness.ShieldDouble.new()
	shield.shields = 1
	h.root.add_child(shield)
	h.bury("l_01", &"house_kehr", 54)
	h.clean.levels["dirt_l_01"] = 2
	h.plan(55)
	h.clock(1200)
	assert_eq(h.rep.count(&"visit_neglected"), 0, "Rosine talks it small")
	assert_eq(shield.shields, 0)


func test_specimen_rumour_once_per_dead() -> void:
	var r := h.bury("l_01", &"house_kehr", 54)
	var specs := SpecimensDouble.new()
	h.root.add_child(specs)
	var s := SpecimenRecord.new()
	s.uid = "sp_1"
	s.corpse_id = r.id
	s.state = Specimens.STATE_SOLD
	specs.recs["sp_1"] = s
	h.plan(55)
	h.clock(1200)
	assert_eq(h.rep.count(&"visit_specimen_rumor"), 1)
	assert_eq(h.visitors.goodwill(&"kin_kehr"), 3, "+1 kept −3 rumour")
	var next := VisitRules.next_due("l_01", 54, 55, 53, cfg)
	h.plan(next)
	h.clock(1200)
	assert_eq(h.rep.count(&"visit_specimen_rumor"), 1, "once per dead")
	assert_true((h.visitors.save_state().rumor_seen as Array).has(r.id))
