class_name WishData
extends Resource
## One wish template of a visitor (docs/PHASE8_DESIGN.md §2.2.5, §3.4): data/visitors/wishes/<id>.tres.

const KINDS: Array[StringName] = [&"tend", &"flowers", &"candle", &"line", &"vase"]

@export var id: StringName
## &"tend" | &"flowers" | &"candle" | &"line" | &"vase".
@export var kind: StringName
@export_multiline var ask_text: String
@export_multiline var done_text: String
@export_multiline var failed_text: String
## Only kind line: the line for the stone (6 templates).
@export var line_text: String = ""
