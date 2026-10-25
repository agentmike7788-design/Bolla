extends TestCase
## Lead / W0 (docs/PHASE10_DESIGN.md §2.7.1, §3.4, §10.1): CalendarRules – day 1 = Friday, 3. Gilbhart 1834; the
## Saturdays / Sundays, the month's firsts 30 / 60 / 91 / 122, the month lengths, the turn of the year, next_weekday;
## StoneCalendar unchanged.


func test_day_one_is_a_friday() -> void:
	assert_eq(CalendarRules.DAY1_WEEKDAY, 4)
	assert_eq(CalendarRules.weekday(1), 4)
	assert_eq(CalendarRules.weekday_name(1), "Freitag")
	assert_eq(CalendarRules.weekday_name(1, true), "Fr")
	assert_eq(CalendarRules.WEEKDAY_NAMES, PackedStringArray(["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag",
			"Samstag", "Sonntag"]))
	assert_eq(StoneCalendar.date_text(1, null), "3. Gilbhart 1834", "StoneCalendar unchanged")


func test_saturdays_and_sundays() -> void:
	for day: int in [2, 9, 16, 23, 30, 79, 86]:
		assert_eq(CalendarRules.weekday(day), CalendarRules.SATURDAY, "day %d is a Saturday" % day)
		assert_eq(CalendarRules.weekday_name(day, true), "Sa")
	for day: int in [3, 10, 80, 87]:
		assert_eq(CalendarRules.weekday(day), CalendarRules.SUNDAY, "day %d is a Sunday" % day)
	# §1.4: day 75 = Tuesday (16. Julmond 1834), 81 Monday, 84 Thursday (Christmas), 91 Thursday.
	assert_eq([CalendarRules.weekday_name(75), CalendarRules.weekday_name(81), CalendarRules.weekday_name(84),
			CalendarRules.weekday_name(91)], ["Dienstag", "Montag", "Donnerstag", "Donnerstag"])
	assert_eq(StoneCalendar.date_text(75, null), "16. Julmond 1834")
	assert_eq(StoneCalendar.date_text(84, null), "25. Julmond 1834")


func test_weeks_run_monday_to_sunday() -> void:
	assert_eq([CalendarRules.week_of(1), CalendarRules.week_of(2), CalendarRules.week_of(3)], [0, 0, 0], "days 1–3 = week 0")
	assert_eq([CalendarRules.week_of(4), CalendarRules.week_of(10), CalendarRules.week_of(11)], [1, 1, 2])
	assert_eq(CalendarRules.week_of(80), 11, "§5.1 example: the inspection of day 80 is week 11")
	assert_eq(CalendarRules.week_of(81), 12)
	assert_eq([CalendarRules.week_of(0), CalendarRules.week_of(-3), CalendarRules.week_of(-4)], [0, 0, -1],
			"days before the start count on (day −3 = Monday of week 0)")
	for day: int in range(1, 130):
		if CalendarRules.weekday(day) == CalendarRules.MONDAY:
			assert_eq(CalendarRules.week_of(day), CalendarRules.week_of(day - 1) + 1, "a new week on Monday %d" % day)
		else:
			assert_eq(CalendarRules.week_of(day), CalendarRules.week_of(day - 1), "same week on day %d" % day)


func test_firsts_of_month() -> void:
	var firsts := []
	for day: int in range(1, 160):
		if CalendarRules.is_first_of_month(day):
			firsts.append(day)
	assert_eq(firsts, [30, 60, 91, 122, 150], "§2.7.1: 1. Nebelung, Julmond, Hartung 1835, Hornung, Lenzing")
	assert_eq([CalendarRules.weekday_name(30), CalendarRules.weekday_name(60), CalendarRules.weekday_name(91)],
			["Samstag", "Montag", "Donnerstag"])
	assert_false(CalendarRules.is_first_of_month(0))
	assert_false(CalendarRules.is_first_of_month(-1))


func test_month_keys_and_titles() -> void:
	assert_eq(CalendarRules.month_key(1), "1834-10")
	assert_eq(CalendarRules.month_key(29), "1834-10")
	assert_eq(CalendarRules.month_key(30), "1834-11")
	assert_eq(CalendarRules.month_key(75), "1834-12")
	assert_eq(CalendarRules.month_key(90), "1834-12", "Silvester")
	assert_eq(CalendarRules.month_key(91), "1835-01", "the turn of the year")
	assert_eq(CalendarRules.month_key(0), "1834-10", "days < 1 = day 1 (StoneCalendar)")
	assert_eq(CalendarRules.month_title("1834-12"), "Julmond 1834")
	assert_eq(CalendarRules.month_title("1835-01"), "Hartung 1835")
	assert_eq(CalendarRules.month_title("1834-13"), "", "malformed")
	assert_eq(CalendarRules.month_title("Julmond"), "", "malformed")


func test_first_day_and_length_of_a_month() -> void:
	assert_eq(CalendarRules.first_day_of_month("1834-10"), -1, "1. Gilbhart 1834 lies before the start")
	assert_eq(CalendarRules.first_day_of_month("1834-11"), 30)
	assert_eq(CalendarRules.first_day_of_month("1834-12"), 60)
	assert_eq(CalendarRules.first_day_of_month("1835-01"), 91)
	assert_eq(CalendarRules.first_day_of_month("1835-02"), 122)
	assert_eq(CalendarRules.first_day_of_month("1834-09"), -31)
	assert_eq(CalendarRules.first_day_of_month("x"), 0, "malformed")
	assert_eq([CalendarRules.days_in_month("1834-10"), CalendarRules.days_in_month("1834-11"),
			CalendarRules.days_in_month("1834-12"), CalendarRules.days_in_month("1835-02")], [31, 30, 31, 28])
	assert_eq(CalendarRules.days_in_month("nope"), 0)
	for key: String in ["1834-11", "1834-12", "1835-01", "1835-02", "1835-06"]:
		var first := CalendarRules.first_day_of_month(key)
		assert_true(CalendarRules.is_first_of_month(first), key)
		assert_eq(CalendarRules.month_key(first), key)
		assert_eq(CalendarRules.month_key(first - 1) != key, true, key)
		assert_eq(CalendarRules.month_key(first + CalendarRules.days_in_month(key) - 1), key, key)


func test_next_weekday() -> void:
	assert_eq(CalendarRules.next_weekday(75, CalendarRules.SATURDAY), 79, "§1.4: B5")
	assert_eq(CalendarRules.next_weekday(79, CalendarRules.SATURDAY), 79, "≥ day")
	assert_eq(CalendarRules.next_weekday(80, CalendarRules.SATURDAY), 86, "B12")
	assert_eq(CalendarRules.next_weekday(75, CalendarRules.SUNDAY), 80, "B6")
	assert_eq(CalendarRules.next_weekday(80, CalendarRules.MONDAY), 81, "B7: Osric brings the cemetery money")
	assert_eq(CalendarRules.next_weekday(1, CalendarRules.SATURDAY), 2)


func test_uses_the_stone_config_calendar() -> void:
	var cfg := Database.config(&"stone_config") as StoneConfig
	assert_not_null(cfg)
	for day: int in [1, 29, 30, 60, 75, 91, 122]:
		assert_eq(CalendarRules.month_key(day, cfg), CalendarRules.month_key(day), "data = class default (%d)" % day)
	assert_eq(CalendarRules.month_title("1834-12", cfg), "Julmond 1834")
	assert_eq(CalendarRules.first_day_of_month("1835-01", cfg), 91)
