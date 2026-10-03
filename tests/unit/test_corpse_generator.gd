extends TestCase
## P4 (docs/PHASE7_DESIGN.md §2.6.3, §3.4, §10): CorpseGenerator – the hidden cause of a random corpse
## comes deterministically from its seed (CorpseTables.hidden_causes: fever → arsenic 12 %,
## drowned_millpond → dead_before_water 15 %, old_age → drink 15 %), from its own RNG so every other draw
## stays bit-identical; story corpses have none; the real corpse tables carry the contract values.


func test_hidden_cause_is_deterministic_and_leaves_the_other_draws_alone() -> void:
	var tables := Phase7Fixtures.corpse_tables()
	var plain := tables.duplicate(true) as CorpseTables
	plain.hidden_causes = {} as Dictionary[StringName, Array]
	for day: int in range(1, 60):
		var seed := CorpseGenerator.seed_for(day, 0)
		var a := CorpseGenerator.generate(seed, tables, day)
		var b := CorpseGenerator.generate(seed, tables, day)
		var old := CorpseGenerator.generate(seed, plain, day)
		assert_eq(a.hidden_cause, b.hidden_cause, "deterministic")
		assert_eq(old.hidden_cause, &"", "no table, no hidden cause")
		var da := a.to_dict()
		var dold := old.to_dict()
		da.erase("hidden_cause")
		dold.erase("hidden_cause")
		assert_eq(da, dold, "every other draw unchanged (day %d)" % day)
		if a.hidden_cause != &"":
			assert_eq(a.hidden_cause, {&"fever": &"arsenic", &"drowned_millpond": &"dead_before_water", &"old_age": &"drink"}[a.cause_id])


func test_hidden_cause_rates() -> void:
	var tables := Phase7Fixtures.corpse_tables()
	var hits := 0
	for s: int in 2000:
		if CorpseGenerator.hidden_cause_for(s * 104729 + 17, &"fever", tables) == &"arsenic":
			hits += 1
	assert_true(hits > 170 and hits < 310, "≈ 12 %% of the fevers (%d / 2000)" % hits)
	assert_eq(CorpseGenerator.hidden_cause_for(5, &"coach_accident", tables), &"", "no hidden cause for others")
	assert_eq(CorpseGenerator.hidden_cause_for(5, &"fever", null), &"")
	var sure := tables.duplicate(true) as CorpseTables
	sure.hidden_causes[&"fever"] = [{"id": &"arsenic", "chance": 1.0}]
	assert_eq(CorpseGenerator.hidden_cause_for(5, &"fever", sure), &"arsenic", "chance 1 always hits")


func test_story_corpses_have_no_hidden_cause() -> void:
	var story := StoryCorpseData.new()
	story.id = &"s1_test"
	story.cause_id = &"fever"
	assert_eq(StoryDirector.make_record(story, 12345).hidden_cause, &"")


func test_real_corpse_tables_carry_the_hidden_causes() -> void:
	var real := Database.corpse_tables() as CorpseTables
	assert_eq(real.hidden_causes, Phase7Fixtures.corpse_tables().hidden_causes, "§2.6.3")
