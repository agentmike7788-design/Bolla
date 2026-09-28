class_name GhostLines
extends Resource
## Ghost speech (docs/PHASE3_DESIGN.md §2.8): data/ghosts/ghost_lines.tres. Own texts (P4),
## each ≤ 90 characters.

## Thanks lines of content ghosts (8).
@export var content: PackedStringArray = PackedStringArray()
## Lines of calm ghosts without a main reason.
@export var calm: PackedStringArray = PackedStringArray()
## Hints by main reason: weeds, valuables, cold, cross, waited, bare (3 each).
@export var by_reason: Dictionary[StringName, PackedStringArray] = {}
## Trait lines of content ghosts: letter, tattoo, strange_wound (2 each).
@export var by_trait: Dictionary[StringName, PackedStringArray] = {}
@export var gift: String = "Der Geist deutet ins Moos – zwei Münzen."
# Phase 4 (docs/PHASE4_DESIGN.md §2.9)
## Lines of content / calm story ghosts by StoryCorpseData.id (2 each).
@export var by_story: Dictionary[StringName, PackedStringArray] = {}
## Lines by piety tier (devout, hardhearted: 2 each).
@export var by_piety: Dictionary[StringName, PackedStringArray] = {}
## Gift text by coin count when it differs from `gift` (Pietät "Andächtig": 3 coins, §2.7).
@export var gift_by_coins: Dictionary[int, String] = {}
## Once per night when a content ghost would give but Pietät allows no gift (§2.7, §3.4).
@export var no_gift: String = "Die Geister deuten nicht mehr ins Moos."
## QA (W3, G4): extra complaints of a robbed ghost by the kind taken (hair / teeth) – a ghost
## whose teeth were taken must not ask for its braid. Added to by_reason.robbed.
@export var by_harvest: Dictionary[StringName, PackedStringArray] = {}
