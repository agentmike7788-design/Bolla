class_name LetterData
extends Resource
## One letter (docs/PHASE9_DESIGN.md §2.4, §3.4): data/letters/<id>.tres. Pocket letters (from the dead to the
## living) and post (to the dead). The choice keys: deliver, read, read_grave, answer, burn, bury.

const KIND_POCKET := &"pocket"
const KIND_POST := &"post"
const KINDS: Array[StringName] = [KIND_POCKET, KIND_POST]
const CHOICES: Array[StringName] = [&"deliver", &"read", &"read_grave", &"answer", &"burn", &"bury"]
const ASKS: Array[StringName] = [&"", &"burn", &"grave", &"read"]

@export var id: StringName
## &"pocket" | &"post"
@export var kind: StringName = &"pocket"
## The address on the outside („An Rosine Wackernagel, Holderkrug").
@export var outside: String
@export_multiline var text: String
@export var sealed: bool = true
## Who wrote it (shown text).
@export var sender: String
## npc_id | kin_id | &"town" | &"none" | &"grave"
@export var recipient: StringName = &""
## &"" | &"burn" | &"grave" | &"read" – what the letter asks for.
@export var asks: StringName = &""
## Pool conditions (robber_fate:let_go …).
@export var conditions: PackedStringArray = []
## deliver/read/read_grave/answer/burn/bury → DialogueActions.
@export var choice_actions: Dictionary[StringName, PackedStringArray] = {}
@export var choice_texts: Dictionary[StringName, String] = {}
@export_multiline var reply_text: String = ""
## post: to which dead (StoryCorpseData id).
@export var story_id: StringName = &""
