extends TestCase
## P2 (docs/PHASE3_DESIGN.md §3.4, §10): BuildGrid – footprint rotation, mask flags, every
## rejection in its test order, gravel vs. bench on the same cell. Mask: build_mask_fixture
## (12 × 8, see Phase3Fixtures): row 0 blocked, grave x 2–3 z 3–4, ring x 1–4 z 2–5,
## row 7 route, columns 0–5 section 1, 6–11 section 2.

var grid: BuildGrid
var bench: DecorData
var gravel: DecorData
var vase: DecorData
var lantern: DecorData
var bed: DecorData
var none: Array[Rect2] = []
var yard := PackedInt32Array([1])
var both := PackedInt32Array([1, 2])


func before_each() -> void:
	grid = BuildGrid.new(Phase3Fixtures.build_mask())
	bench = Phase3Fixtures.decor(&"decor_bench_wood")
	gravel = Phase3Fixtures.decor(&"decor_path_gravel")
	vase = Phase3Fixtures.decor(&"decor_grave_vase")
	lantern = Phase3Fixtures.decor(&"decor_lantern")
	bed = Phase3Fixtures.decor(&"decor_flowerbed")


func test_footprint_rotation() -> void:
	var c := Vector2i(1, 1)
	assert_eq(BuildGrid.footprint_cells(c, Vector2i(3, 1), 0), [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)])
	assert_eq(BuildGrid.footprint_cells(c, Vector2i(3, 1), 1), [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)], "rot 1 swaps X/Z")
	assert_eq(BuildGrid.footprint_cells(c, Vector2i(3, 1), 2), BuildGrid.footprint_cells(c, Vector2i(3, 1), 0))
	assert_eq(BuildGrid.footprint_cells(c, Vector2i(3, 1), 3), BuildGrid.footprint_cells(c, Vector2i(3, 1), 1))
	assert_eq(BuildGrid.footprint_cells(Vector2i(4, 5), Vector2i(2, 2), 1),
			[Vector2i(4, 5), Vector2i(5, 5), Vector2i(4, 6), Vector2i(5, 6)], "anchor = bottom-left")
	assert_eq(BuildGrid.footprint_cells(c, Vector2i.ONE, 0), [c])
	assert_eq(BuildGrid.rotated_size(Vector2i(3, 1), 1), Vector2i(1, 3))
	assert_eq(BuildGrid.rotated_size(Vector2i(3, 1), -1), Vector2i(1, 3), "negative rot wraps")
	assert_eq(grid.footprint_rect(c, Vector2i(3, 1), 0), Rect2(0.5, 0.5, 1.5, 0.5))
	assert_eq(grid.footprint_rect(c, Vector2i(3, 1), 1), Rect2(0.5, 0.5, 0.5, 1.5))


func test_plain_cells_are_ok() -> void:
	assert_eq(grid.check(bench, Vector2i(1, 1), 0, {}, none, yard), &"ok")
	assert_eq(grid.check(bench, Vector2i(0, 1), 1, {}, none, yard), &"ok", "column 0 rows 1–3")
	assert_eq(grid.check(bed, Vector2i(6, 1), 0, {}, none, both), &"ok")


func test_blocked_cells() -> void:
	assert_eq(grid.check(bench, Vector2i(1, 0), 0, {}, none, both), &"blocked", "fence row")
	assert_eq(grid.check(vase, Vector2i(2, 3), 0, {}, none, both), &"blocked", "grave footprint")
	assert_eq(grid.check(bench, Vector2i(10, 1), 0, {}, none, both), &"blocked", "leaves the mask")
	assert_eq(grid.check(vase, Vector2i(-1, 3), 0, {}, none, both), &"blocked", "outside")
	assert_eq(grid.check(bench, Vector2i(4, 1), 0, {}, none, both), &"blocked", "spans yard and east")
	assert_eq(grid.check(null, Vector2i(1, 1), 0, {}, none, both), &"blocked", "no decor")
	assert_eq(BuildGrid.new(null).check(vase, Vector2i(1, 1), 0, {}, none, both), &"blocked", "no mask")


func test_locked_section() -> void:
	assert_eq(grid.check(bench, Vector2i(7, 1), 0, {}, none, yard), &"locked_section")
	assert_eq(grid.check(bench, Vector2i(7, 1), 0, {}, none, both), &"ok")
	assert_eq(grid.check(bench, Vector2i(7, 1), 0, {}, none, PackedInt32Array()), &"locked_section")


func test_obstacle() -> void:
	var rects: Array[Rect2] = [Rect2(0.0, 0.5, 1.0, 1.0)]  # cells x 0–1, z 1–2
	assert_eq(grid.check(bench, Vector2i(0, 1), 0, {}, rects, yard), &"obstacle")
	assert_eq(grid.check(bench, Vector2i(2, 1), 0, {}, rects, yard), &"ok", "touching the edge is fine")
	assert_eq(grid.check(gravel, Vector2i(0, 7), 0, {}, [Rect2(0.0, 3.4, 0.3, 0.3)] as Array[Rect2], yard), &"obstacle",
			"obstacle before route")


func test_route() -> void:
	assert_eq(grid.check(bench, Vector2i(0, 7), 0, {}, none, yard), &"route")
	assert_eq(grid.check(vase, Vector2i(0, 7), 0, {}, none, yard), &"route")
	assert_eq(grid.check(gravel, Vector2i(0, 7), 0, {}, none, yard), &"ok", "gravel may go on paths")
	assert_eq(grid.check(bench, Vector2i(0, 5), 1, {}, none, yard), &"route", "rotated into the path row")


func test_grave_ring() -> void:
	assert_eq(grid.check(bench, Vector2i(1, 2), 0, {}, none, yard), &"grave_ring")
	assert_eq(grid.check(gravel, Vector2i(1, 2), 0, {}, none, yard), &"grave_ring", "gravel not in the ring")
	assert_eq(grid.check(vase, Vector2i(1, 2), 0, {}, none, yard), &"ok")
	assert_eq(grid.check(lantern, Vector2i(4, 5), 0, {}, none, yard), &"ok")


func test_occupied_and_gravel_vs_bench() -> void:
	var occ := {Vector2i(2, 1): "d_1"}
	assert_eq(grid.check(bench, Vector2i(1, 1), 0, occ, none, yard), &"occupied")
	assert_eq(grid.check(bench, Vector2i(0, 1), 1, occ, none, yard), &"ok", "rotated past it")
	assert_eq(grid.check(gravel, Vector2i(2, 1), 0, occ, none, yard), &"occupied", "gravel never under a bench")
	var gravel_occ := {Vector2i(0, 7): "d_2"}
	assert_eq(grid.check(gravel, Vector2i(0, 7), 0, gravel_occ, none, yard), &"occupied", "gravel on gravel")
	var bench_on_gravel := {Vector2i(0, 1): "d_3"}
	assert_eq(grid.check(bench, Vector2i(0, 1), 0, bench_on_gravel, none, yard), &"occupied", "bench never on gravel")


func test_check_order() -> void:
	var rects: Array[Rect2] = [Rect2(0.0, 0.0, 6.0, 4.0)]  # everything
	var occ := {}
	for x: int in 12:
		for z: int in 8:
			occ[Vector2i(x, z)] = "d_x"
	# route + ring + obstacle + occupied, section locked → locked_section
	assert_eq(grid.check(bench, Vector2i(7, 7), 0, occ, rects, yard), &"locked_section")
	assert_eq(grid.check(bench, Vector2i(0, 7), 0, occ, rects, yard), &"obstacle")
	assert_eq(grid.check(bench, Vector2i(0, 7), 0, occ, none, yard), &"route")
	assert_eq(grid.check(bench, Vector2i(1, 2), 0, occ, none, yard), &"grave_ring")
	assert_eq(grid.check(bench, Vector2i(1, 1), 0, occ, none, yard), &"occupied")
	assert_eq(grid.check(bench, Vector2i(5, 0), 0, occ, rects, PackedInt32Array()), &"blocked", "blocked first")
