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
# Phase 5 (docs/PHASE5_DESIGN.md §2.5): by_reason gets &"nameless" (a stone without an
# inscription, after &"cross"). by_design: once per grave in the first night after a designed
# stone was set – keys &"default", &"gilded", &"master", &"s5_lorenz".
@export var by_design: Dictionary[StringName, PackedStringArray] = {}
# Phase 6 (docs/PHASE6_DESIGN.md §2.4): once per grave in the first night after the marker of a
# corpse with a funeral service (by_service) / after a devotion (by_devotion: &"default",
# &"robbed").
@export var by_service: PackedStringArray = PackedStringArray()
@export var by_devotion: Dictionary[StringName, PackedStringArray] = {}
# Phase 7 (docs/PHASE7_DESIGN.md §2.11): a ghost missing an organ (by_organ: before robbed) / the
# first night after a specimen was returned (by_returned).
@export var by_organ: PackedStringArray = PackedStringArray()
@export var by_returned: PackedStringArray = PackedStringArray()
