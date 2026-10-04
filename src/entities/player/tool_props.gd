class_name ToolProps
extends RefCounted
## G7 Runde 2 (Werkzeuge): which tool meshes of the gravekeeper model are visible. All tools hang on
## the rig's "tool" bone (the chisel on arm_l); only the tool in use shows, the belt tools are hidden
## in the tool bag otherwise (ToolAnimConfig.resting_visible: the shovel stays on the back). While a
## belt tool uses the tool bone, the shovel is parked on a spine attachment at the tool bone's rest
## (its place on the back), so it does not follow the bone into his hands.

const PARK_NAME := "ShovelBack"

var _tools: ToolAnimConfig
## Tool kind → its mesh nodes.
var _meshes: Dictionary[StringName, Array] = {}
var _shovel: Node3D
var _shovel_home: Node
var _park: Node3D


func _init(model: Node3D, tools: ToolAnimConfig) -> void:
	_tools = tools
	for kind: StringName in tools.tool_meshes:
		var nodes: Array = []
		for mesh_name: String in tools.tool_meshes[kind]:
			var n := model.find_child(mesh_name, true, false) as Node3D
			if n != null:
				nodes.append(n)
		_meshes[kind] = nodes
	var shovel_nodes: Array = _meshes.get(&"shovel", [])
	_shovel = shovel_nodes[0] as Node3D if not shovel_nodes.is_empty() else null
	_shovel_home = _shovel.get_parent() if _shovel != null else null
	_park = _make_park(model)
	rest()


## True if the model carries the meshes of `kind` (a model without them plays no tool clips).
func has(kind: StringName) -> bool:
	return not (_meshes.get(kind, []) as Array).is_empty()


## Everything in its resting place: the shovel on the back, the belt tools hidden.
func rest() -> void:
	_park_shovel(false)
	for kind: StringName in _meshes:
		_set_visible(kind, kind in _tools.resting_visible)


## `kind` is drawn / held / stowed; `shown` = it is out of the bag (belt tools) right now.
func show(kind: StringName, shown: bool) -> void:
	_park_shovel(kind != &"shovel" and has(kind))
	for k: StringName in _meshes:
		if k != kind:
			_set_visible(k, k in _tools.resting_visible)
	# last, so a kind sharing a mesh with another (chisel: the hammer) wins
	_set_visible(kind, shown or kind in _tools.resting_visible)


## True if the mesh `mesh_name` is visible (tests, screenshots).
func is_shown(mesh_name: String) -> bool:
	for kind: StringName in _meshes:
		for n: Node3D in _meshes[kind]:
			if n.name == mesh_name:
				return n.visible
	return false


func _set_visible(kind: StringName, value: bool) -> void:
	for n: Node3D in _meshes.get(kind, []):
		n.visible = value


func _park_shovel(parked: bool) -> void:
	if _shovel == null or _park == null:
		return
	var parent := _park if parked else _shovel_home
	if _shovel.get_parent() != parent:
		_shovel.reparent(parent, false)


## A spine attachment holding the tool bone's rest transform (the shovel's place on the back).
func _make_park(model: Node3D) -> Node3D:
	if _shovel == null or not (_shovel_home is BoneAttachment3D):
		return null
	var sk := _shovel_home.get_parent() as Skeleton3D
	var bone := sk.find_bone((_shovel_home as BoneAttachment3D).bone_name) if sk != null else -1
	if bone < 0 or sk.get_bone_parent(bone) < 0:
		return null
	var spine := BoneAttachment3D.new()
	spine.name = PARK_NAME + "Bone"
	spine.bone_name = sk.get_bone_name(sk.get_bone_parent(bone))
	sk.add_child(spine)
	var park := Node3D.new()
	park.name = PARK_NAME
	park.transform = sk.get_bone_rest(bone)
	spine.add_child(park)
	return park
