class_name ItemData
extends Resource
## One item type (data/items/<id>.tres). Icons are resolved at runtime via Database.icon(id).

enum Category { RESOURCE, CRAFTED, CURRENCY }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.RESOURCE
## Ignored for CURRENCY (currency has no slot and no stack limit).
@export var max_stack: int = 50
