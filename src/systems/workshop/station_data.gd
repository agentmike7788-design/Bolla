class_name StationData
extends Resource
## One crafting station of the workyard (docs/PHASE5_DESIGN.md §2.1, §3.4): data/stations/<id>.tres.
## The workbench is prebuilt; mason, loom and forge are built on their site (BuildSite).

@export var id: StringName
@export var display_name: String = ""
## Layout id of the build site (&"" for the prebuilt workbench), e.g. "site_mason".
@export var site_id: String = ""
## Items consumed at the end of the build (atomic with build_coins).
@export var build_inputs: Dictionary[StringName, int] = {}
@export var build_coins: int = 0
@export var build_minutes: int = 90
## &"crafting" | &"stone_design"
@export var panel: StringName = &"crafting"
## "[E] Steinmetzbank benutzen"
@export var prompt_use: String = ""
## Build site description.
@export_multiline var build_text: String = ""
## What the coins stand for: "Meißelsatz aus Hollerbrück".
@export var coin_part_label: String = ""
## workbench: true (never built, always there).
@export var prebuilt: bool = false
