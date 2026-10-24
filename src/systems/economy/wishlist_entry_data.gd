class_name WishlistEntryData
extends Resource
## One lasting purchase of the open wish list (docs/PHASE10_DESIGN.md §2.3 Grundsatz 2, §3.4; sub-resource of
## WishlistData.entries, P1): what it is (kind &"station" | &"building" | &"tool" | &"item" | &"per_grave"), what it
## refers to (station / building / item id), what it costs, from which flag it is available, how often it counts
## (per_grave: per occupied grave, at most max_count).

const KINDS: Array[StringName] = [&"station", &"building", &"tool", &"item", &"per_grave"]

@export var id: StringName
@export var kind: StringName
@export var ref: StringName
@export var coins: int
@export var available_flag: StringName = &""
@export var max_count: int = 1
