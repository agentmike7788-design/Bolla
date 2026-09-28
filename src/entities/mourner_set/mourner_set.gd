class_name MournerSet
extends Node3D
## Up to 4 silent mourners at the markers pew_seat_1…4 inside the chapel (docs/PHASE6_DESIGN.md
## §2.4, §3.4, §4.8), group &"mourner_set": shown with a 0.6 s fade at the start of a service,
## hidden at its end; no names, no dialogue, not saved (a load mid-rite is locked, §5.1).
## Figures: the Node3D children the builder placed (in order), else one instance of
## figure_scenes[i % size] per seat, put on the seat marker pew_seat_<i+1> found under seats_path
## (empty = the parent room). The fade tweens GeometryInstance3D.transparency.

const GROUP := &"mourner_set"
const FADE_SECONDS := 0.6
const SEAT_PREFIX := "pew_seat_"
const MAX_MOURNERS := 4
const FIGURE_PREFIX := "Mourner"

## Seated figures (ph_chr_mourner_a…d); used when the set has no figure children.
@export var figure_scenes: Array[PackedScene] = []
## Where the seat markers are searched; empty = the parent (the chapel room).
@export var seats_path: NodePath

var _figures: Array[Node3D] = []
var _shown: int = 0
var _tween: Tween


func _init() -> void:
	add_to_group(GROUP, true)


## The figures start hidden.
func _ready() -> void:
	figures()


## Shows the first `count` figures (clamped to 0…4 and to the figures there are) with a fade in;
## the others are hidden. count 0 = hide_mourners().
func show_mourners(count: int) -> void:
	var figs := figures()
	var n := clampi(count, 0, mini(MAX_MOURNERS, figs.size()))
	if n == 0:
		hide_mourners()
		return
	_kill_tween()
	_shown = n
	for i: int in figs.size():
		figs[i].visible = i < n
	_fade(figs.slice(0, n), 1.0, 0.0, false)


## Fades all figures out and hides them.
func hide_mourners() -> void:
	_kill_tween()
	_shown = 0
	var visible_figs: Array[Node3D] = []
	for fig: Node3D in figures():
		if fig.visible:
			visible_figs.append(fig)
	_fade(visible_figs, 0.0, 1.0, true)


## Number of mourners shown (0 while hidden).
func shown_count() -> int:
	return _shown


## The figures (created on first use, see the class comment).
func figures() -> Array[Node3D]:
	_figures = _figures.filter(func(f: Node3D) -> bool: return is_instance_valid(f))
	if not _figures.is_empty():
		return _figures
	for child: Node in get_children():
		if child is Node3D:
			_figures.append(child as Node3D)
	if _figures.is_empty() and not figure_scenes.is_empty():
		for i: int in MAX_MOURNERS:
			var scene := figure_scenes[i % figure_scenes.size()]
			var fig := scene.instantiate() as Node3D if scene != null else null
			if fig == null:
				continue
			fig.name = "%s%d" % [FIGURE_PREFIX, i + 1]
			add_child(fig)
			var seat := seat(i + 1)
			if seat != null and fig.is_inside_tree():
				fig.global_transform = seat.global_transform
			_figures.append(fig)
	# Freshly collected: hidden until a service.
	for fig: Node3D in _figures:
		fig.visible = false
	return _figures


## Marker pew_seat_<index> under seats_path (null = none).
func seat(index: int) -> Node3D:
	var root: Node = get_node_or_null(seats_path) if not seats_path.is_empty() else get_parent()
	if root == null:
		return null
	return root.find_child(SEAT_PREFIX + str(index), true, false) as Node3D


func _fade(figs: Array[Node3D], from: float, to: float, hide_at_end: bool) -> void:
	var geoms: Array[GeometryInstance3D] = []
	for fig: Node3D in figs:
		_collect_geometry(fig, geoms)
	if not is_inside_tree() or FADE_SECONDS <= 0.0:
		_finish_fade(figs, geoms, to, hide_at_end)
		return
	for g: GeometryInstance3D in geoms:
		g.transparency = from
	_tween = create_tween().set_parallel(true)
	for g: GeometryInstance3D in geoms:
		_tween.tween_property(g, ^"transparency", to, FADE_SECONDS)
	_tween.chain().tween_callback(_finish_fade.bind(figs, geoms, to, hide_at_end))


func _finish_fade(figs: Array[Node3D], geoms: Array[GeometryInstance3D], to: float, hide_at_end: bool) -> void:
	for g: GeometryInstance3D in geoms:
		if is_instance_valid(g):
			g.transparency = to
	if hide_at_end:
		for fig: Node3D in figs:
			if is_instance_valid(fig):
				fig.visible = false


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


static func _collect_geometry(node: Node, out: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		out.append(node as GeometryInstance3D)
	for child: Node in node.get_children():
		_collect_geometry(child, out)
