class_name CraftingSystem
extends RefCounted
## Pure crafting rules. Time is handled by the caller (timed action).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

static func missing(recipe: RecipeData, inv: Inventory) -> Dictionary:
	push_warning("STUB CraftingSystem.missing")
	return {}


static func can_craft(recipe: RecipeData, inv: Inventory) -> bool:
	push_warning("STUB CraftingSystem.can_craft")
	return false


static func craft(recipe: RecipeData, inv: Inventory) -> bool:
	push_warning("STUB CraftingSystem.craft")
	return false
