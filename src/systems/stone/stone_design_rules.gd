class_name StoneDesignRules
extends RefCounted
## STUB (P4) – docs/PHASE5_DESIGN.md §2.5, §3.4: pure rules of a designed gravestone: fitting
## inscriptions, the rendered text, marker points, breakdown lines, material and minutes.
## W1 (P4) fills the bodies; the signatures are the contract.


## Template fits the dead (cause, age or story); i_rest never fits.
static func fits(_ins: InscriptionData, _corpse: CorpseRecord) -> bool:
	return false


## Lines with {name} {born} {died} {age} filled in (names > 22 characters wrap, ≤ max_lines).
static func render_text(_ins: InscriptionData, _corpse: CorpseRecord, _cfg: StoneConfig) -> PackedStringArray:
	return PackedStringArray()


## Shape points + inscription + fitting + gilded + ornament (stele ≤ 7, arch ≤ 8, master ≤ 9).
static func marker_points(_design: StoneDesign, _corpse: CorpseRecord, _economy: EconomyConfig, _cfg: StoneConfig) -> int:
	return 0


## [{label, points}] – "Meisterstein +5", "Inschrift +1", "Passende Inschrift +1", …
static func breakdown_lines(_design: StoneDesign, _corpse: CorpseRecord, _economy: EconomyConfig, _cfg: StoneConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


## {item_id: amount} of shape + ink + gold leaf.
static func inputs(_design: StoneDesign, _cfg: StoneConfig) -> Dictionary:
	return {}


## Shape + inscription + gilding + ornament minutes.
static func minutes(_design: StoneDesign, _cfg: StoneConfig) -> int:
	return 0


## Marker points of the grave's current marker (cross 1, gravestone 3, designed = its sum).
static func current_marker_points(_grave: GraveRecord, _corpse: CorpseRecord, _economy: EconomyConfig, _cfg: StoneConfig) -> int:
	return 0
