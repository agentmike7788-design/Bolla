class_name CraftingSystem
extends RefCounted
## Pure crafting rules. Time is handled by the caller (timed action).
## Uses only the public Inventory API, so it works with any Inventory (also test doubles).


## {input id: amount still missing}; empty when every input is present.
static func missing(recipe: RecipeData, inv: Inventory) -> Dictionary:
	var out: Dictionary = {}
	if not _args_ok(recipe, inv, "missing"):
		return out
	for id: StringName in recipe.inputs:
		var need: int = recipe.inputs[id]
		var have := inv.count(id)
		if need > have:
			out[id] = need - have
	return out


## Inputs present AND the output fits once the inputs are removed (freed slots count).
static func can_craft(recipe: RecipeData, inv: Inventory) -> bool:
	if not _args_ok(recipe, inv, "can_craft") or not _has_valid_output(recipe):
		return false
	return missing(recipe, inv).is_empty() and _output_fits(recipe, inv)


## Atomic: either all inputs are removed and the output is added, or nothing changes.
static func craft(recipe: RecipeData, inv: Inventory) -> bool:
	if not can_craft(recipe, inv):
		return false
	var snapshot := inv.save_state()
	for id: StringName in recipe.inputs:
		if not inv.remove_item(id, recipe.inputs[id]):
			return _roll_back(recipe, inv, snapshot)
	if inv.add_item(recipe.output_id, recipe.output_amount) > 0:
		return _roll_back(recipe, inv, snapshot)
	return true


## Removing inputs only ever frees space, so a direct fit is enough; otherwise the
## removal is simulated on a signal-less copy (the real inventory is never touched).
static func _output_fits(recipe: RecipeData, inv: Inventory) -> bool:
	if inv.can_add(recipe.output_id, recipe.output_amount):
		return true
	var sim := inv.duplicate(Node.DUPLICATE_SCRIPTS) as Inventory
	if sim == null:
		return false
	sim.load_state(inv.save_state())
	var fits := true
	for id: StringName in recipe.inputs:
		if not sim.remove_item(id, recipe.inputs[id]):
			fits = false
			break
	fits = fits and sim.can_add(recipe.output_id, recipe.output_amount)
	sim.free()
	return fits


static func _roll_back(recipe: RecipeData, inv: Inventory, snapshot: Dictionary) -> bool:
	push_warning("[CraftingSystem] crafting '%s' failed midway – inventory restored" % recipe.id)
	inv.load_state(snapshot)
	return false


static func _args_ok(recipe: RecipeData, inv: Inventory, caller: String) -> bool:
	if recipe == null or not is_instance_valid(inv):
		push_warning("[CraftingSystem] %s: recipe or inventory missing" % caller)
		return false
	return true


static func _has_valid_output(recipe: RecipeData) -> bool:
	if recipe.output_id == &"" or recipe.output_amount <= 0:
		push_warning("[CraftingSystem] recipe '%s' has no valid output" % recipe.id)
		return false
	return true
