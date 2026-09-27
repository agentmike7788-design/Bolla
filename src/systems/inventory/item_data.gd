class_name ItemData
extends Resource
## One item type (data/items/<id>.tres). Icons are resolved at runtime via Database.icon(id).

## Phase 3 appends DECOR (3, build bar) and TOOL (4, inventory); Phase 4 appends GOODS (5,
## inventory only, not in the HUD resource bar) – existing values unchanged.
enum Category { RESOURCE, CRAFTED, CURRENCY, DECOR, TOOL, GOODS }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.RESOURCE
## Ignored for CURRENCY (currency has no slot and no stack limit).
@export var max_stack: int = 50
