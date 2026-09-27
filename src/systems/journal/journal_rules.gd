class_name JournalRules
extends RefCounted
## STUB (P6) – docs/PHASE4_DESIGN.md §2.12, §3.4. Pure journal rules (linking clues).


## The insight whose `requires` equals `selected` exactly (order irrelevant), not yet in
## `unlocked`; &"" = no match.
static func match_insight(_selected: Array[StringName], _insights: Array[InsightData], _unlocked: Dictionary) -> StringName:
	return &""


## Insights with at least one found clue, not unlocked (column "Offene Fragen").
static func open_questions(_found: Dictionary, _insights: Array[InsightData], _unlocked: Dictionary) -> Array[InsightData]:
	return []


## All required clues found, not linked yet (objective line).
static func ready_insights(_found: Dictionary, _insights: Array[InsightData], _unlocked: Dictionary) -> Array[InsightData]:
	return []
