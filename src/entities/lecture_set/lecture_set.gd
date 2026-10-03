class_name LectureSet
extends Node3D
## The lecture in the surgery (docs/PHASE7_DESIGN.md §2.6.4, §3.4, §4.3), group &"lecture_set": three
## seated students (ph_chr_student_a/b/c, no rig) and the sealed jar on the lectern; show_lecture(organ)
## / hide_lecture() with a 0.6 s cross-fade (like MournerSet). The examination table stays empty under
## its cloth – nothing but the closed jar is ever shown. Presentation only, no Interactable, not saved.
## Figures: the Node3D children whose name starts with "Student" (in order), else one instance of
## student_scenes[i] per seat marker student_seat_<i+1> under seats_path (empty = the parent room).
## The jar: the child "Jar", else an instance of jar_scene at the marker lectern_jar.

const GROUP := &"lecture_set"
const FADE_SECONDS := 0.6
const STUDENTS := 3
const STUDENT_PREFIX := "Student"
const SEAT_PREFIX := "student_seat_"
const JAR_NAME := "Jar"
const JAR_MARKER := "lectern_jar"

## Seated students (ph_chr_student_a/b/c); used when the set has no Student children.
@export var student_scenes: Array[PackedScene] = []
## The sealed jar on the lectern (the dark jar of the specimens); used when there is no Jar child.
@export var jar_scene: PackedScene
## Where the seat / lectern markers are searched; empty = the parent (the surgery room).
@export var seats_path: NodePath

var _students: Array[Node3D] = []
var _jar: Node3D
var _organ: StringName = &""
var _shown: bool = false
var _tween: Tween


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	students()
	jar()


## Students and the jar fade in; `organ` is only remembered (the label on the jar, for the UI).
func show_lecture(organ: StringName) -> void:
	_kill_tween()
	_organ = organ
	_shown = true
	var nodes := _all_nodes()
	for n: Node3D in nodes:
		n.visible = true
	_fade(nodes, 1.0, 0.0, false)


func hide_lecture() -> void:
	_kill_tween()
	_shown = false
	_organ = &""
	var nodes: Array[Node3D] = []
	for n: Node3D in _all_nodes():
		if n.visible:
			nodes.append(n)
	_fade(nodes, 0.0, 1.0, true)


func is_shown() -> bool:
	return _shown


func organ() -> StringName:
	return _organ


## The students (collected or created on first use; hidden until a lecture).
func students() -> Array[Node3D]:
	_students = _students.filter(func(f: Node3D) -> bool: return is_instance_valid(f))
	if not _students.is_empty():
		return _students
	for child: Node in get_children():
		if child is Node3D and String(child.name).begins_with(STUDENT_PREFIX):
			_students.append(child as Node3D)
	if _students.is_empty() and not student_scenes.is_empty():
		for i: int in STUDENTS:
			var scene := student_scenes[i % student_scenes.size()]
			var fig := scene.instantiate() as Node3D if scene != null else null
			if fig == null:
				continue
			fig.name = "%s%d" % [STUDENT_PREFIX, i + 1]
			add_child(fig)
			var seat := _marker(SEAT_PREFIX + str(i + 1))
			if seat != null and fig.is_inside_tree():
				fig.global_transform = seat.global_transform
			_students.append(fig)
	for fig: Node3D in _students:
		if not _shown:
			fig.visible = false
	return _students


## The jar on the lectern (null = none yet).
func jar() -> Node3D:
	if is_instance_valid(_jar):
		return _jar
	_jar = get_node_or_null(JAR_NAME) as Node3D
	if _jar == null and jar_scene != null:
		_jar = jar_scene.instantiate() as Node3D
		if _jar != null:
			_jar.name = JAR_NAME
			add_child(_jar)
			var marker := _marker(JAR_MARKER)
			if marker != null and _jar.is_inside_tree():
				_jar.global_transform = marker.global_transform
	if _jar != null and not _shown:
		_jar.visible = false
	return _jar


func _all_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = students().duplicate()
	var j := jar()
	if j != null:
		out.append(j)
	return out


func _marker(marker_name: String) -> Node3D:
	var root: Node = get_node_or_null(seats_path) if not seats_path.is_empty() else get_parent()
	if root == null:
		return null
	return root.find_child(marker_name, true, false) as Node3D


func _fade(nodes: Array[Node3D], from: float, to: float, hide_at_end: bool) -> void:
	var geoms: Array[GeometryInstance3D] = []
	for n: Node3D in nodes:
		_collect_geometry(n, geoms)
	if not is_inside_tree() or FADE_SECONDS <= 0.0:
		_finish_fade(nodes, geoms, to, hide_at_end)
		return
	for g: GeometryInstance3D in geoms:
		g.transparency = from
	_tween = create_tween().set_parallel(true)
	for g: GeometryInstance3D in geoms:
		_tween.tween_property(g, ^"transparency", to, FADE_SECONDS)
	_tween.chain().tween_callback(_finish_fade.bind(nodes, geoms, to, hide_at_end))


func _finish_fade(nodes: Array[Node3D], geoms: Array[GeometryInstance3D], to: float, hide_at_end: bool) -> void:
	for g: GeometryInstance3D in geoms:
		if is_instance_valid(g):
			g.transparency = to
	if hide_at_end:
		for n: Node3D in nodes:
			if is_instance_valid(n):
				n.visible = false


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


static func _collect_geometry(node: Node, out: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		out.append(node as GeometryInstance3D)
	for child: Node in node.get_children():
		_collect_geometry(child, out)
