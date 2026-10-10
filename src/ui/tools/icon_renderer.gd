extends SceneTree
## Renders the item models to UI icons: res://assets/ui/icons/<id>.png (128×128, transparent,
## same 3/4 camera and lighting for all). Needs a real renderer:
##   GODOT=<godot> tools/godot_run.sh -s res://src/ui/tools/icon_renderer.gd [-- --filter=<id>[,<id>…]]
## then: godot --headless --path . --import

const OUT_DIR := "res://assets/ui/icons"
const ICON_SIZE := 128
## Rendered larger, then downscaled (smooth edges).
const RENDER_SCALE := 3
const SETTLE_FRAMES := 12
const FOV := 24.0
## Share of the frame the model's projected bounds may fill.
const FILL := 0.92
const FIT_ITERATIONS := 4
## Camera direction (3/4 view from the front right, looking down ~32°).
const VIEW_DIR := Vector3(0.62, 0.62, 1.0)
const MODELS: Dictionary[StringName, String] = {
	&"coin": "res://assets/models/items/ph_item_coin.glb",
	&"wood": "res://assets/models/items/ph_item_log.glb",
	&"stone": "res://assets/models/items/ph_item_stone.glb",
	&"linen": "res://assets/models/items/ph_item_linen.glb",
	&"shroud": "res://assets/models/items/ph_item_shroud.glb",
	&"wooden_cross": "res://assets/models/props/ph_prop_cross_wood.glb",
	&"gravestone_simple": "res://assets/models/props/ph_prop_gravestone_round.glb",
	# Phase 3 (docs/PHASE3_DESIGN.md §8: decor icons from the models).
	&"iron_fittings": "res://assets/models/items/ph_item_iron_fittings.glb",
	&"seeds": "res://assets/models/items/ph_item_seeds.glb",
	&"rake": "res://assets/models/items/ph_item_rake.glb",
	&"decor_bench_wood": "res://assets/models/decor/ph_deco_bench_wood.glb",
	&"decor_bench_stone": "res://assets/models/decor/ph_deco_bench_stone.glb",
	&"decor_flowerbed": "res://assets/models/decor/ph_deco_flowerbed.glb",
	&"decor_grave_vase": "res://assets/models/decor/ph_deco_grave_vase.glb",
	&"decor_lantern": "res://assets/models/decor/ph_deco_lantern_small.glb",
	&"decor_path_gravel": "res://assets/models/decor/ph_deco_path_gravel.glb",
	# Phase 4 (docs/PHASE4_DESIGN.md §2.13, §8: tools, goods and the gown from the P5 models).
	&"scrub_brush": "res://assets/models/items/ph_item_scrub_brush.glb",
	&"comb": "res://assets/models/items/ph_item_comb.glb",
	&"burial_gown": "res://assets/models/items/ph_item_burial_gown.glb",
	&"juniper": "res://assets/models/items/ph_item_juniper.glb",
	&"shears": "res://assets/models/items/ph_item_shears.glb",
	&"pliers": "res://assets/models/items/ph_item_pliers.glb",
	&"hair_braid": "res://assets/models/items/ph_item_hair_braid.glb",
	&"teeth_pouch": "res://assets/models/items/ph_item_teeth_pouch.glb",
	# Phase 5 (docs/PHASE5_DESIGN.md §7, §8: materials, tool tiers, the stations of the build-site panel).
	&"flax": "res://assets/models/items/ph_item_flax.glb",
	&"yarn": "res://assets/models/items/ph_item_yarn.glb",
	&"clay": "res://assets/models/items/ph_item_clay.glb",
	&"iron_ore": "res://assets/models/items/ph_item_iron_ore.glb",
	&"iron_bar": "res://assets/models/items/ph_item_iron_bar.glb",
	&"charcoal": "res://assets/models/items/ph_item_charcoal.glb",
	&"workstone": "res://assets/models/items/ph_item_workstone.glb",
	&"elderberries": "res://assets/models/items/ph_item_elderberries.glb",
	&"herbs": "res://assets/models/items/ph_item_herbs.glb",
	&"ink": "res://assets/models/items/ph_item_ink.glb",
	&"herb_bundle": "res://assets/models/items/ph_item_herb_bundle.glb",
	&"gold_leaf": "res://assets/models/items/ph_item_gold_leaf.glb",
	&"steel_rod": "res://assets/models/items/ph_item_steel_rod.glb",
	&"shovel_iron": "res://assets/models/items/ph_item_shovel_iron.glb",
	&"shovel_master": "res://assets/models/items/ph_item_shovel_master.glb",
	&"axe_iron": "res://assets/models/items/ph_item_axe_iron.glb",
	&"axe_master": "res://assets/models/items/ph_item_axe_master.glb",
	&"pickaxe_iron": "res://assets/models/items/ph_item_pickaxe_iron.glb",
	&"pickaxe_master": "res://assets/models/items/ph_item_pickaxe_master.glb",
	&"station_mason": "res://assets/models/buildings/ph_bld_mason_bench.glb",
	&"station_loom": "res://assets/models/buildings/ph_bld_loom.glb",
	&"station_forge": "res://assets/models/buildings/ph_bld_forge.glb",
	# Phase 6 (docs/PHASE6_DESIGN.md §7, §8: the new items and every level of the building panel).
	&"altar_candle": "res://assets/models/items/ph_item_altar_candle.glb",
	&"bone_box": "res://assets/models/items/ph_item_bone_box.glb",
	&"bone_box_full": "res://assets/models/items/ph_item_bone_box_full.glb",
	&"building_crypt_0": "res://assets/models/buildings/ph_bld_crypt_site.glb",
	&"building_crypt_1": "res://assets/models/buildings/ph_bld_crypt_l1.glb",
	&"building_crypt_2": "res://assets/models/buildings/ph_bld_crypt_l2.glb",
	&"building_crypt_3": "res://assets/models/buildings/ph_bld_crypt_l3.glb",
	&"building_chapel_0": "res://assets/models/buildings/ph_bld_chapel_ruin.glb",
	&"building_chapel_1": "res://assets/models/buildings/ph_bld_chapel_l1.glb",
	&"building_chapel_2": "res://assets/models/buildings/ph_bld_chapel_l2.glb",
	&"building_chapel_3": "res://assets/models/buildings/ph_bld_chapel_l3.glb",
	&"building_shed_0": "res://assets/models/buildings/ph_bld_shed_site.glb",
	&"building_shed_1": "res://assets/models/buildings/ph_bld_shed_l1.glb",
	&"building_shed_2": "res://assets/models/buildings/ph_bld_shed_l2.glb",
	&"building_shed_3": "res://assets/models/buildings/ph_bld_shed_l3.glb",
	# Phase 7 (docs/PHASE7_DESIGN.md §2.8, §8: the new items – sealed jars, linen, boxes, labelled bottles).
	&"prep_jar": "res://assets/models/items/ph_item_prep_jar.glb",
	&"prep_jar_small": "res://assets/models/items/ph_item_prep_jar_small.glb",
	&"spirits": "res://assets/models/items/ph_item_spirits.glb",
	&"beeswax": "res://assets/models/items/ph_item_beeswax.glb",
	&"anatomy_case": "res://assets/models/items/ph_item_anatomy_case.glb",
	&"specimen_jar": "res://assets/models/items/ph_item_specimen_jar.glb",
	&"specimen_bundle": "res://assets/models/items/ph_item_specimen_bundle.glb",
	&"bone_specimen": "res://assets/models/items/ph_item_bone_specimen.glb",
	&"display_specimen": "res://assets/models/items/ph_item_display_specimen.glb",
	&"antidote": "res://assets/models/items/ph_item_antidote.glb",
	&"bitter_drops": "res://assets/models/items/ph_item_bitter_drops.glb",
	&"dropsy_powder": "res://assets/models/items/ph_item_dropsy_powder.glb",
	&"fever_tincture": "res://assets/models/items/ph_item_fever_tincture.glb",
	&"wound_salve": "res://assets/models/items/ph_item_wound_salve.glb",
	&"corpse_balm": "res://assets/models/items/ph_item_corpse_balm.glb",
	&"honey_cake": "res://assets/models/items/ph_item_honey_cake.glb",
	&"elder_wine": "res://assets/models/items/ph_item_elder_wine.glb",
	# Phase 7 §7: portraits of the Merkbuch page „Hollerbrück" (head and shoulders, see PORTRAITS).
	&"villager_innkeeper": "res://assets/models/characters/ph_chr_v_innkeeper.glb",
	&"villager_smith": "res://assets/models/characters/ph_chr_v_smith.glb",
	&"villager_grocer": "res://assets/models/characters/ph_chr_v_grocer.glb",
	&"villager_priest": "res://assets/models/characters/ph_chr_v_priest.glb",
	&"villager_mayor": "res://assets/models/characters/ph_chr_v_mayor.glb",
	&"villager_surgeon": "res://assets/models/characters/ph_chr_v_surgeon.glb",
	&"villager_washer": "res://assets/models/characters/ph_chr_v_washer.glb",
	&"villager_oldwoman": "res://assets/models/characters/ph_chr_v_oldwoman.glb",
	# Phase 8 (docs/PHASE8_DESIGN.md §8.4): the ten new items (models of P5) …
	&"flower_seedlings": "res://assets/models/items/ph_item_flower_seedlings.glb",
	&"grave_candle": "res://assets/models/items/ph_item_grave_candle.glb",
	&"watering_can": "res://assets/models/items/ph_item_watering_can.glb",
	&"apprentice_rake": "res://assets/models/items/ph_item_apprentice_rake.glb",
	&"mortsafe": "res://assets/models/items/ph_item_mortsafe.glb",
	&"wax_wreath": "res://assets/models/items/ph_item_wax_wreath.glb",
	&"register_extract": "res://assets/models/items/ph_item_register_extract.glb",
	&"memorial_plate": "res://assets/models/items/ph_item_memorial_plate.glb",
	&"quast_crate": "res://assets/models/items/ph_item_quast_crate.glb",
	&"lorenz_ledger_2": "res://assets/models/items/ph_item_lorenz_ledger_2.glb",
	# … and the portraits of the new people (Merkbuch „Hollerbrück" / „Angehörige", wish card, favour panel).
	&"villager_apprentice": "res://assets/models/characters/ph_chr_apprentice.glb",
	&"villager_beggar": "res://assets/models/characters/ph_chr_beggar.glb",
	&"villager_peddler": "res://assets/models/characters/ph_chr_peddler.glb",
	&"kin_kehr": "res://assets/models/characters/ph_chr_mourner_w_a.glb",
	&"kin_brandt": "res://assets/models/characters/ph_chr_mourner_m_a.glb",
	&"kin_ott": "res://assets/models/characters/ph_chr_mourner_w_b.glb",
	&"kin_sieber": "res://assets/models/characters/ph_chr_mourner_m_b.glb",
}
## Ids framed as a portrait: only the top PORTRAIT_SHARE of the model, seen from the front
## (villager_<id>; Phase 8: also the households kin_<house>).
const PORTRAIT_PREFIX := "villager_"
const PORTRAIT_PREFIX_KIN := "kin_"
## The one prop mesh a portrait keeps: the hat on the head (hat_head; not hat_hand).
const PORTRAIT_KEEP := "hat_head"
const PORTRAIT_SHARE := 0.26
## Width (m) the portrait frame may span at most (head and shoulders).
const PORTRAIT_WIDTH := 0.46
const PORTRAIT_DIR := Vector3(0.3, 0.12, 1.0)

var _filter: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE) * RENDER_SCALE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	_add_lighting(viewport)
	var cam := Camera3D.new()
	cam.fov = FOV
	viewport.add_child(cam)
	var failures := 0
	for id: StringName in MODELS:
		if not _matches(id):
			continue
		var scene := load(MODELS[id]) as PackedScene
		if scene == null:
			push_error("[IconRenderer] missing model for %s: %s" % [id, MODELS[id]])
			failures += 1
			continue
		var model := scene.instantiate() as Node3D
		viewport.add_child(model)
		var portrait := String(id).begins_with(PORTRAIT_PREFIX) or String(id).begins_with(PORTRAIT_PREFIX_KIN)
		if portrait:
			# Phase 8: props carried as child meshes (glTF extras: rake, can, lantern, kiepe, hat in hand)
			# stay out of a head-and-shoulders portrait and out of its frame.
			for child: Node in model.find_children("*", "MeshInstance3D", true, false):
				if child.has_meta(&"extras") and not String(child.name).begins_with(PORTRAIT_KEEP):
					(child as Node3D).visible = false
		var box := _aabb(model)
		if portrait:
			box.position.y += box.size.y * (1.0 - PORTRAIT_SHARE)
			box.size.y *= PORTRAIT_SHARE
			# head and shoulders only: arms, staffs and bags must not widen the frame
			var c := box.get_center()
			box.size.x = minf(box.size.x, PORTRAIT_WIDTH)
			box.size.z = minf(box.size.z, PORTRAIT_WIDTH)
			box.position.x = c.x - box.size.x * 0.5
			box.position.z = c.z - box.size.z * 0.5
		_frame(cam, box, PORTRAIT_DIR if portrait else VIEW_DIR)
		for i: int in SETTLE_FRAMES:
			await process_frame
		var img := viewport.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path(OUT_DIR.path_join(String(id) + ".png"))
		var err := img.save_png(path)
		print("[IconRenderer] %s -> %s (%s)" % [id, path, error_string(err)])
		if err != OK:
			failures += 1
		model.queue_free()
		await process_frame
	quit(1 if failures > 0 else 0)


## Key (warm, upper left), fill (cool, right) and rim (behind) – readable on dark UI.
func _add_lighting(viewport: SubViewport) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	key.light_color = Color(1.0, 0.94, 0.84)
	key.light_energy = 1.6
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 70.0, 0.0)
	fill.light_color = Color(0.7, 0.78, 0.9)
	fill.light_energy = 0.45
	viewport.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25.0, 160.0, 0.0)
	rim.light_color = Color(1.0, 0.86, 0.62)
	rim.light_energy = 0.9
	viewport.add_child(rim)


## Places the camera along VIEW_DIR so the projected bounds fill FILL of the frame.
func _frame(cam: Camera3D, box: AABB, view_dir: Vector3 = VIEW_DIR) -> void:
	var center := box.get_center()
	var dir := view_dir.normalized()
	var distance := box.size.length() / tan(deg_to_rad(FOV * 0.5))
	for i: int in FIT_ITERATIONS:
		cam.look_at_from_position(center + dir * distance, center, Vector3.UP)
		var extent := 0.0
		var view := cam.global_transform.affine_inverse()
		for corner: int in 8:
			var p := view * box.get_endpoint(corner)
			var depth := maxf(-p.z, 0.001)
			extent = maxf(extent, maxf(absf(p.x), absf(p.y)) / depth)
		var wanted := tan(deg_to_rad(FOV * 0.5)) * FILL
		distance *= extent / wanted
	cam.look_at_from_position(center + dir * distance, center, Vector3.UP)
	cam.near = maxf(distance * 0.05, 0.01)
	cam.far = distance * 4.0 + box.size.length()


func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if not mesh.visible:
			continue
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## --filter=<a,b,…>: every id containing one of the parts ("" = all).
func _matches(id: StringName) -> bool:
	if _filter == "":
		return true
	for part: String in _filter.split(",", false):
		if String(id).contains(part):
			return true
	return false
