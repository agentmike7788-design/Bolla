class_name CorpseGenerator
extends RefCounted
## Deterministic corpse generation (local RNG only, no autoloads).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

static func generate(seed: int, tables: CorpseTables, day: int) -> CorpseRecord:
	push_warning("STUB CorpseGenerator.generate")
	return null


static func seed_for(day: int, spawn_index: int) -> int:
	push_warning("STUB CorpseGenerator.seed_for")
	return 0
