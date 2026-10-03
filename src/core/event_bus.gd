extends Node
## Global signal hub (docs/VERTICAL_SLICE_DESIGN.md §3.3).
## Signals are notifications only: listeners never change game state (inventory,
## stats, records) in response – the emitting system has already done that.
@warning_ignore_start("unused_signal")

signal game_booted
signal debug_mode_changed(enabled: bool)

# Time (TimeManager)
signal time_tick(day: int, minute_of_day: int)
signal hour_changed(day: int, hour: int)
signal day_started(day: int)
signal time_skipped(from_total: int, to_total: int)

# Game flow
signal new_game_started
signal world_ready(world: Node)
signal notification_requested(text: String, kind: StringName)
signal interaction_focus_changed(prompt: String, enabled: bool)
signal timed_action_started(label: String, duration_sec: float)
signal timed_action_progress(ratio: float)
signal timed_action_finished(completed: bool)
## Hut interior (§11): the player now is inside (true) / outside the hut – Player.set_in_interior
## (portal, load). Listeners switch presentation only (camera profile, sun, environment).
signal interior_changed(inside: bool)
## Short black fade-out-and-in over `duration` seconds, black at the midpoint (portal; UI draws it).
signal screen_fade_requested(duration: float)

# Corpses & graves (CorpseManager, Graveyard)
signal corpse_arrived(corpse_id: String)
signal corpse_updated(corpse_id: String)
signal corpse_buried(corpse_id: String, grave_id: String)
signal grave_state_changed(grave_id: String, state: int)
signal grave_completed(grave_id: String, corpse_id: String, quality: int, breakdown: Array)
## From Phase 3 on only CemeteryScore emits it (graves + decor − dirt), only on change.
signal cemetery_quality_changed(total: int, rating: StringName)
signal payment_received(amount: int, reason: String)
signal delivery_skipped(day: int, reason: String)
## Phase 2 only: declared, no longer emitted from Phase 3 on (docs/PHASE3_DESIGN.md §3.3).
signal slice_completed

# Cemetery expansion (ExpansionManager) – Phase 3 §3.3
signal obstacle_cleared(obstacle_id: String, section_id: StringName)
signal section_progress_changed(section_id: StringName, done: int, total: int)
## After Graveyard.unlock_section.
signal section_unlocked(section_id: StringName)
# Graves (Graveyard) – Phase 3
## Marker upgraded (MARKED → MARKED with a better marker).
signal grave_quality_changed(grave_id: String, quality: int)
## Phase goal (§1.3): every non-old grave MARKED and no section locked.
signal cemetery_completed
# Decor & build mode (DecorationManager, BuildMode)
## placed = true: set up, false: removed.
signal decor_changed(uid: String, decor_id: StringName, placed: bool)
signal build_mode_changed(active: bool)
# Tending (CleanlinessManager)
## Only when a spot's level changes.
signal dirt_changed(spot_id: String, level: int)
## dirty_spots = level ≥ 2; bundled (at most once per action / time skip).
signal cleanliness_changed(penalty: int, dirty_spots: int)
# Reputation (Reputation)
signal reputation_changed(value: int, tier: StringName, delta: int, reason: String)
# Ghosts (GhostManager)
signal ghost_spoke(grave_id: String, mood: StringName, text: String)
## 21:30 on / 04:30 off.
signal ghost_night_changed(active: bool)

# Phase 4 (docs/PHASE4_DESIGN.md §3.3) – in addition to corpse_updated; listeners never change
# game state (the changing system calls the others directly).
# Examination, preparation, harvesting (CorpseCare)
signal exam_step_done(corpse_id: String, step: StringName, revealed: Array[StringName], lost: Array[StringName])
## action: &"wash", &"dress", &"lay_out", &"balm"
signal corpse_prepared(corpse_id: String, action: StringName)
signal corpse_harvested(corpse_id: String, kind: StringName, item_id: StringName)
# Story (CorpseManager / StoryDirector)
signal story_corpse_arrived(story_id: StringName, corpse_id: String)
## &"six_pits" (Graveyard)
signal chapter_completed(chapter_id: StringName)
# Piety (Piety)
signal piety_changed(value: int, tier: StringName, delta: int, reason: String)
# Journal (JournalManager)
signal clue_found(clue_id: StringName, corpse_id: String)
signal insight_unlocked(insight_id: StringName)
# Night trader (NightTrade): one trade in the panel (coins positive = income).
signal trader_trade(coins: int, sold: Dictionary, bought: Dictionary)

# Phase 5 (docs/PHASE5_DESIGN.md §3.3) – listeners never change game state (the changing system
# calls the others directly; coins_spent raises stats.coins_spent in the sender).
# Workshop (Workshop)
signal station_built(station_id: StringName)
## state: &"started", &"ready", &"collected"
signal workshop_job_changed(station_id: StringName, recipe_id: StringName, state: StringName)
# Gathering (GatherManager)
signal resource_gathered(node_id: String, item_id: StringName, amount: int)
## stage: &"full", &"partial", &"empty", &"regrowing"
signal gather_node_changed(node_id: String, charges: int, stage: StringName)
# Tools (Workbench after a tool recipe; not the Player on load)
signal tool_tier_changed(kind: StringName, tier: int)
# Stones (Stonemasonry / Graveyard); state: &"ready", &"set", &"discarded"
signal stone_order_changed(order_id: String, grave_id: String, state: StringName)
signal grave_stone_set(grave_id: String, shape_id: StringName, quality: int)
# Coins (every expense through a system: build, Osric, Ilse); reason: &"license", &"build", &"osric", &"ilse"
signal coins_spent(amount: int, reason: StringName)

# Phase 6 (docs/PHASE6_DESIGN.md §3.3) – listeners never change game state (Buildings, Ossuary,
# ChapelRites and the shed entities call the others directly).
# Buildings (Buildings.upgrade)
signal building_upgraded(building_id: StringName, level: int)
## Interiors (Player.set_in_interior): "" = outside; interior_changed(inside) stays and comes first.
signal interior_room_changed(room_id: StringName)
# Ossuary (Ossuary.lift / reinter)
signal bones_lifted(grave_id: String)
signal bones_reinterred(grave_id: String, count: int)
# Chapel (ChapelRites)
signal funeral_held(corpse_id: String, chapel_level: int, fee: int)
signal devotion_held(grave_id: String, bonus: int)
## Shed (ShedSupply through the entity); direction: &"fetch" | &"store"
signal shed_supply_moved(items: Dictionary, direction: StringName)

# Phase 7 (docs/PHASE7_DESIGN.md §3.3) – listeners never change game state (the changing system
# calls the others directly; coins_spent raises stats.coins_spent in the sender).
## Regions (Player.set_region) – after interior_changed / interior_room_changed when both change.
signal region_changed(region_id: StringName)
## Shops (VillageShops): coins positive = income of the player.
signal shop_trade(shop_id: StringName, coins: int, sold: Dictionary, bought: Dictionary)
# Relationships (Relationships)
signal relationship_changed(npc_id: StringName, value: int, tier: StringName, delta: int, reason: String)
signal villager_remarked(npc_id: StringName, text: String)
## Orders (Orders); state: &"offered" | &"accepted" | &"completed" | &"failed"
signal order_changed(order_id: StringName, state: StringName)
## Specimens (Specimens); state: &"taken" | &"sold" | &"researched" | &"lectured" | &"used" |
## &"returned" | &"sealed" | &"displayed" | &"boned" | &"spoiled"
signal specimen_changed(uid: String, state: StringName)
## Presentation: the dark veil during a specimen (MorgueTable).
signal screen_veil_changed(active: bool)
# Consecration (Village)
signal ground_consecrated(section_id: StringName)
# Specimen collection (CollectionShelf through CollectionRules), lecture (Lectures), deduction (Deductions)
signal collection_set_completed(set_id: StringName, standing: int)
signal lecture_held(day: int, organ: StringName, fee: int, rumor: bool)
signal cause_deduced(corpse_id: String, cause_id: StringName)

# UI
signal ui_panel_requested(panel: StringName, context: Dictionary)
signal ui_modal_changed(open: bool)

# Dialogue
signal dialogue_requested(dialogue_id: StringName, speaker: Node)
signal dialogue_ended(dialogue_id: StringName)

# Save
signal game_saved(slot: int)
signal game_loaded(slot: int)
