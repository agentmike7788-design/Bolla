class_name MapConfig
extends Resource
## The map (G7 Änderungsrunde 1, key M): data/config/map_config.tres. Everything the map draws comes
## from the layout files (MapLayout); this resource only names, frames and colours it.

## Region → layout file (region-local coordinates, x = east, z = south).
@export var layouts: Dictionary[StringName, String] = {
	&"graveyard": "res://data/world/graveyard_layout.json",
	&"village": "res://data/world/village_layout.json",
}
## Region → tab title.
@export var tab_titles: Dictionary[StringName, String] = {&"graveyard": "Friedhof", &"village": "Hollerbrück"}
## Region → title in the map's cartouche.
@export var map_titles: Dictionary[StringName, String] = {&"graveyard": "Der Friedhof am Hügel", &"village": "Hollerbrück"}
## Region → the region-local rect [x, z, w, d] the sheet shows (fit, north up).
@export var views: Dictionary[StringName, Rect2] = {
	&"graveyard": Rect2(-18.0, -34.0, 54.0, 62.0),
	&"village": Rect2(-37.0, -28.0, 68.0, 48.0),
}
## The tab of a region is offered only while this GameState flag is on (&"" = always).
@export var tab_flags: Dictionary[StringName, StringName] = {&"village": &"village_open"}
## One Schritt in metres and the length of the scale bar in Schritt.
@export var step_metres: float = 0.75
@export var scale_steps: int = 10
@export var scale_text: String = "%d Schritt"

## Layout id → label (buildings, building sites, landmarks). A building without a label here falls back
## to fallback_building_label.
@export var labels: Dictionary[String, String] = {
	"hut": "Hütte",
	"site_crypt": "Gruft",
	"site_chapel": "Kapelle",
	"site_shed": "Schuppen",
	"obs_c_gate": "Kirchpforte",
	"road_exit": "Wegstein",
	"notice_board": "Friedhofstafel",
	"v_church": "Kirche",
	"v_office": "Amtshaus",
	"v_inn": "Holderkrug",
	"v_smithy": "Schmiede",
	"v_shop": "Krämerladen",
	"v_surgery": "Wundarztstube",
	"v_remise": "Remise",
	"v_inn2": "Zum Stumpf",
	"cottage_hagedorn": "Kate Hagedorn",
	"cottage_dorn": "Kate Dorn",
	"house_kehr": "Wohnhaus",
	"house_brandt": "Wohnhaus",
	"house_ott": "Wohnhaus",
	"house_sieber": "Wohnhaus",
	"well": "Brunnen",
	"linden": "Linde",
	"board": "Gemeindetafel",
	"bridge": "Holderbrücke",
	"wash_stones": "Waschplatz",
	"shrine": "Bildstock",
}
@export var fallback_building_label: String = "Haus"
## Where a section or area name is written (region-local, m) when the middle of its area is taken by
## graves, buildings or the player's usual spot; others are centred.
@export var label_at: Dictionary[String, Vector2] = {
	"yard": Vector2(7.4, -5.8), "north": Vector2(4.75, -13.6), "churchyard": Vector2(4.75, -31.2),
	"elder": Vector2(-6.75, -16.6), "workyard": Vector2(-1.4, -10.4), "road_village": Vector2(-33.2, -0.7),
	"anger": Vector2(0.0, 2.4),
}
## Area names drawn large and letter-spaced: feature → text (road, forest, workyard, anger, brook).
@export var feature_labels: Dictionary[String, String] = {
	"road": "Kutschweg",
	"forest": "Wald",
	"workyard": "Werkhof",
	"anger": "Anger",
	"brook": "Hollerbach",
	"road_village": "← Zum Friedhof",
}
## Village props shown as landmarks (prop id → glyph).
@export var village_landmarks: Dictionary[String, StringName] = {
	"well": &"well", "linden": &"linden", "board": &"board", "bridge": &"bridge", "wash_stones": &"wash",
	"shrine": &"shrine",
}
## Buildings with a glyph on the roof (cross, anvil …).
@export var building_glyphs: Dictionary[String, StringName] = {
	"v_church": &"cross", "site_chapel": &"cross", "site_crypt": &"crypt", "v_smithy": &"anvil", "v_inn": &"mug",
	"v_surgery": &"bowl", "v_shop": &"scales", "v_office": &"seal",
}
## Sections hidden entirely while their SectionData.requires_flag is off (the Lindenacker is still
## Gemeindewald before linden_granted); other locked sections are drawn faded with "?".
@export var hidden_sections: PackedStringArray = ["linden"]
@export var unknown_section_text: String = "?"
## Graveyard buildings (sites) show only while this flag is on (Phase 6).
@export var buildings_flag: StringName = &"buildings_open"
## Interior room → the building it lies in (layout id) and that building's region.
@export var room_places: Dictionary[StringName, String] = {
	&"hut": "hut", &"crypt": "site_crypt", &"chapel": "site_chapel", &"shed": "site_shed",
	&"inn": "v_inn", &"surgery": "v_surgery", &"office": "v_office",
}
@export var room_regions: Dictionary[StringName, StringName] = {
	&"hut": &"graveyard", &"crypt": &"graveyard", &"chapel": &"graveyard", &"shed": &"graveyard",
	&"inn": &"village", &"surgery": &"village", &"office": &"village",
}
## Half extent (m) around an interior origin within which a position counts as inside that room.
@export var room_radius: float = 30.0
## Where a villager is at home / takes deliveries (order markers): npc_id → layout id.
@export var npc_places: Dictionary[StringName, String] = {
	&"innkeeper": "v_inn", &"smith": "v_smithy", &"grocer": "v_shop", &"priest": "v_church", &"mayor": "v_office",
	&"surgeon": "v_surgery", &"washer": "cottage_dorn", &"oldwoman": "cottage_hagedorn", &"council": "board",
	&"carter": "v_remise",
}
## Shop → the place whose tooltip shows its opening hours.
@export var shop_places: Dictionary[StringName, String] = {
	&"grocer": "v_shop", &"inn": "v_inn", &"priest": "v_church", &"smith": "v_smithy", &"surgeon": "v_surgery",
	&"washer": "wash_stones",
}
## Order kinds whose target lies on the graveyard: where the marker goes when the target is no grave or
## section (a story corpse, the next delivery).
@export var burial_fallback_place: String = "dropoff"
## Non-villagers shown by name (always known): npc_id → kind (carter = Osric with his cart).
@export var known_people: Dictionary[StringName, StringName] = {&"carter": &"carter", &"trader": &"trader"}

@export_group("Look")
@export var paper: Color = Color(0.89, 0.83, 0.69)
@export var paper_dark: Color = Color(0.62, 0.5, 0.33)
@export var ink: Color = Color(0.24, 0.16, 0.1)
@export var ink_faded: Color = Color(0.42, 0.33, 0.23, 0.72)
@export var sepia: Color = Color(0.48, 0.32, 0.18)
@export var roof: Color = Color(0.64, 0.33, 0.24)
@export var roof_site: Color = Color(0.55, 0.47, 0.36, 0.5)
@export var meadow: Color = Color(0.58, 0.64, 0.42, 0.32)
@export var tree: Color = Color(0.45, 0.52, 0.32, 0.5)
@export var tree_dark: Color = Color(0.24, 0.3, 0.18, 0.62)
@export var tuft: Color = Color(0.38, 0.4, 0.22, 0.5)
## Grass tufts scattered over the sheet (per 100 m2).
@export var tuft_density: float = 2.6
## Regions drawn inside a wood: the paper beyond the walkable bounds is filled with small trees this many
## metres apart (not on the ways, the sections and the buildings).
@export var surround_forest: Dictionary[StringName, float] = {&"graveyard": 2.7}
@export var water: Color = Color(0.36, 0.52, 0.62, 0.5)
@export var road: Color = Color(0.74, 0.6, 0.4, 0.55)
@export var paving: Color = Color(0.7, 0.62, 0.5, 0.45)
@export var locked_wash: Color = Color(0.45, 0.38, 0.3, 0.22)
@export var grave_tended: Color = Color(0.36, 0.48, 0.28)
@export var objective: Color = Color(0.62, 0.17, 0.13)
@export var player_mark: Color = Color(0.13, 0.09, 0.06)
@export var player_ring: Color = Color(0.95, 0.74, 0.32)
@export var person: Color = Color(0.33, 0.25, 0.42)
@export var carter: Color = Color(0.45, 0.25, 0.12)
@export_group("Sizes")
## Font sizes at the 1920×1080 base.
@export var font_area: int = 24
@export var font_building: int = 17
@export var font_small: int = 14
@export var font_title: int = 30
@export var grave_radius: float = 4.0
@export var player_radius: float = 15.0
@export var person_radius: float = 6.5
@export var hotspot_radius: float = 16.0
