class_name CorpseNodePlacement
extends RefCounted
## Corpse node helpers of CorpseManager: instantiating the corpse scene for a record, moving a
## node under a parent at a world transform, freeing it, and the record <-> transform mapping.
## Stateless – the manager keeps the id -> node table.


## Instance of `scene` named after the record (corpse_id set); null (warned) when the root
## is no Node3D.
static func instantiate(scene: PackedScene, record: CorpseRecord) -> Node3D:
	var instance := scene.instantiate()
	var node := instance as Node3D
	if node == null:
		push_warning("[CorpseManager] corpse scene root is no Node3D")
		instance.free()
		return null
	node.name = record.id
	node.set("corpse_id", record.id)
	return node


## Moves `node` under `target` so that it ends up at the world transform `xform`.
static func place(node: Node3D, target: Node, xform: Transform3D) -> void:
	var local := xform
	var target_3d := target as Node3D
	if target_3d != null and target_3d.is_inside_tree():
		local = target_3d.global_transform.affine_inverse() * xform
	var current := node.get_parent()
	if current != null and current != target:
		current.remove_child(node)
	node.transform = local
	if node.get_parent() == null:
		target.add_child(node)


## Detaches `node` from its parent and queues it for deletion.
static func free_node(node: Node3D) -> void:
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


static func record_transform(record: CorpseRecord) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, record.rot_y), record.position)


static func store_transform(record: CorpseRecord, xform: Transform3D) -> void:
	record.position = xform.origin
	record.rot_y = xform.basis.orthonormalized().get_euler().y
