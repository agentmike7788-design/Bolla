class_name ClueData
extends Resource
## A clue in the journal (docs/PHASE4_DESIGN.md §2.12): data/journal/clues/<id>.tres.

## §3.4 lists mark … note; &"talk" (Ilse's answers, "Gespräch" in §2.12) added in W0.
const KINDS: Array[StringName] = [&"mark", &"letter", &"page", &"object", &"place", &"note", &"talk"]

@export var id: StringName
@export var title: String = ""
@export_multiline var text: String = ""
## One of KINDS.
@export var kind: StringName = &"note"
@export var order: int = 0
