class_name SaveMigration
extends RefCounted
## STUB (P6) – docs/PHASE3_DESIGN.md §5.2, §3.4 "Speichern". Upgrades a decoded save state
## ({autoloads, nodes}) to the CURRENT format. Applied by SaveFileIO.read_doc after
## decode_state; the next save writes CURRENT.
## W0 scaffold (fail-safe): the version chain is final, migrate_1_to_2 is still the identity –
## a Phase-2 save loads exactly as before. P6 implements steps 1–7 of §5.2.

const CURRENT := 2


## Chain from_version → CURRENT. Unknown / newer versions → {} (= corrupt).
## `meta` (optional, W0 addition) is the save's meta block – migrate_1_to_2 needs meta.day.
static func migrate(state: Dictionary, from_version: int, meta: Dictionary = {}) -> Dictionary:
	if from_version < 1 or from_version > CURRENT:
		return {}
	var out := state
	if from_version <= 1:
		out = migrate_1_to_2(out, meta)
	return out


## §5.2 steps 1–7 (P6). Stub: deep copy, unchanged.
static func migrate_1_to_2(state: Dictionary, _meta: Dictionary) -> Dictionary:
	return state.duplicate(true)
