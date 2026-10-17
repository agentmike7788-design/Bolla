class_name LightListData
extends Resource
## The list on the back of Lorenz' ledger (docs/PHASE9_DESIGN.md §2.2.1, §3.4): data/quests/who_knows/list.tres –
## six entries, the footer „Licht. Drei Wochen." and the struck-out „Wer weiß, wann?".

@export var entries: Array[LightEntryData] = []
@export var footer: String
@export var struck: String
