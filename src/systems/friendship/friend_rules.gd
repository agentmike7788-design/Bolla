class_name FriendRules
extends RefCounted
## Pure friendship rules (docs/PHASE8_DESIGN.md §2.4, §3.2.1): which step is offerable (threshold, the day
## gap after the step before, the step's conditions, not when „gereizt"), which order variant
## (of_<npc>_<n>[_alt]) applies. Deterministic, no tree – the caller (Friendship) builds the context:
##   value      int         relationship value with the villager
##   mood       StringName  today's mood (&"cross" offers nothing)
##   day        int         today
##   done       int         steps done (0…3)
##   step_day   int         day the last step was done (0 = none)
##   running    bool        an order of the next step is accepted (no second offer)
##   open       bool        Phase 8 is open (p8_open)
##   conditions Callable    func(cond: String) -> bool for the step conditions (dialogue syntax)
##   order_ok   Callable    func(order_id: StringName) -> bool – the order variant may be taken (its flag)

const STEPS := 3
const MOOD_CROSS := &"cross"
const TEXT_DONE := "Die Geschichte ist erzählt."
const TEXT_CLOSED := "Noch nicht."
const TEXT_THRESHOLD := "Ihr kennt euch noch nicht gut genug."
const TEXT_GAP := "Nicht heute. Erst morgen wieder."
const TEXT_MOOD := "Heute nicht. Die Laune ist schlecht."
const TEXT_RUNNING := "Die Bitte läuft schon."
const TEXT_CONDITIONS := "Dafür ist es noch zu früh."
const TEXT_NO_ORDER := "Noch nicht."


## The step offered now (1…3) or 0 (see step_block_reason).
static func offerable_step(story: FriendStoryData, ctx: Dictionary) -> int:
	return int(ctx.get("done", 0)) + 1 if step_block_reason(story, ctx) == "" else 0


## "" = the next step can be offered now; else why not (§2.4: Schwellen 40 / 55 / 70, frühestens einen
## Tag nach dem Schritt davor, nicht bei Laune „gereizt").
static func step_block_reason(story: FriendStoryData, ctx: Dictionary) -> String:
	if story == null or not bool(ctx.get("open", false)):
		return TEXT_CLOSED
	var done := clampi(int(ctx.get("done", 0)), 0, STEPS)
	if done >= mini(STEPS, story.steps.size()):
		return TEXT_DONE
	var step := story.steps[done]
	if step == null:
		return TEXT_CLOSED
	if bool(ctx.get("running", false)):
		return TEXT_RUNNING
	if int(ctx.get("value", 0)) < step.min_value:
		return TEXT_THRESHOLD
	if done > 0 and int(ctx.get("day", 0)) < int(ctx.get("step_day", 0)) + maxi(0, step.gap_days):
		return TEXT_GAP
	if StringName(str(ctx.get("mood", ""))) == MOOD_CROSS:
		return TEXT_MOOD
	var check: Variant = ctx.get("conditions")
	for cond: String in step.conditions:
		if check is Callable and not bool((check as Callable).call(cond)):
			return TEXT_CONDITIONS
	if order_for(step, ctx.get("order_ok")) == &"":
		return TEXT_NO_ORDER
	return ""


## The first order variant of `step` whose order may be taken (Liesel 1: of_liesel_1 with
## insight_not_lorenz, else of_liesel_1_alt); &"" = none.
static func order_for(step: FriendStepData, order_ok: Variant) -> StringName:
	if step == null:
		return &""
	for id: StringName in step.order_ids:
		if not (order_ok is Callable) or bool((order_ok as Callable).call(id)):
			return id
	return &""


## The step (1…3) of `story` whose order variants contain `order_id`; 0 = none.
static func step_of_order(story: FriendStoryData, order_id: StringName) -> int:
	if story == null:
		return 0
	for i: int in story.steps.size():
		var st := story.steps[i]
		if st != null and st.order_ids.has(order_id):
			return i + 1
	return 0


## The relationship reward of a step: the step's reward_rel, else the gain friend_step_<n>.
static func reward_rel(step: FriendStepData, n: int, gains: Dictionary) -> int:
	if step != null and step.reward_rel != 0:
		return step.reward_rel
	return int(gains.get(StringName("friend_step_%d" % n), 0))


## Conditions Friendship answers itself (the dialogue syntax has them with other arities):
## apprentice_level_gte:<n> – Jakob is at level n in any task (Rosine 3, „Geübt in einer Aufgabe").
## Returns -1 = not one of these (ask DialogueConditions), 0 = false, 1 = true. `levels` {task: level}.
static func own_condition(cond: String, levels: Dictionary) -> int:
	var text := cond.strip_edges()
	var negate := text.begins_with("!")
	if negate:
		text = text.substr(1).strip_edges()
	var parts := text.split(":")
	if parts.size() == 2 and parts[0] == "apprentice_level_gte" and parts[1].is_valid_int():
		var need := int(parts[1])
		var ok := false
		for task: Variant in levels:
			if int(levels[task]) >= need:
				ok = true
		return int(ok != negate)
	return -1
