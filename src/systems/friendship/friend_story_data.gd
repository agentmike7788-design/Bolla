class_name FriendStoryData
extends Resource
## The three-step friendship story of a villager (docs/PHASE8_DESIGN.md §2.4, §3.4):
## data/friendship/stories/<npc_id>.tres.

@export var npc_id: StringName
## Steps 1, 2, 3 in order (FriendStepData).
@export var steps: Array[FriendStepData] = []
## The favour this story opens after step 3 (FavorData.id).
@export var favor_id: StringName
