class_name SaveStateCollector
extends RefCounted
## Save state gathering / applying of the SaveManager autoload: the autoload states and the
## save_state() / load_state() / post_load() of all nodes in group "saveable" (sorted by
## save_order, save_id, tree order). Stateless – works on the given SceneTree.

const SAVEABLE_GROUP := &"saveable"
## Autoload states in the save, applied in this order.
const AUTOLOADS: PackedStringArray = ["TimeManager", "GameState"]


## {autoloads: {<name>: {...}}, nodes: {<save_id>: {...}}} – deep copies of every save_state().
static func collect(tree: SceneTree) -> Dictionary:
	var autoloads := {}
	for autoload_name: String in AUTOLOADS:
		autoloads[autoload_name] = (autoload(tree, autoload_name).call("save_state") as Dictionary).duplicate(true)
	var nodes := {}
	for node: Node in saveables(tree):
		var id := save_id(node)
		if nodes.has(id):
			push_warning("[SaveManager] duplicate save_id '%s' (%s) not saved" % [id, node.get_path()])
			continue
		if not node.has_method("save_state"):
			push_warning("[SaveManager] saveable '%s' has no save_state()" % id)
			continue
		nodes[id] = (node.call("save_state") as Dictionary).duplicate(true)
	return {"autoloads": autoloads, "nodes": nodes}


static func apply_autoloads(tree: SceneTree, autoloads: Dictionary) -> void:
	for autoload_name: String in AUTOLOADS:
		var data: Variant = autoloads.get(autoload_name)
		if data is Dictionary:
			autoload(tree, autoload_name).call("load_state", data)
		else:
			push_warning("[SaveManager] no saved state for autoload %s" % autoload_name)
	for key: Variant in autoloads:
		if not str(key) in AUTOLOADS:
			push_warning("[SaveManager] saved state for unknown autoload '%s' ignored" % str(key))


static func apply_nodes(tree: SceneTree, nodes: Dictionary) -> void:
	var seen := {}
	for node: Node in saveables(tree):
		var id := save_id(node)
		seen[id] = true
		var data: Variant = nodes.get(id)
		if not data is Dictionary:
			push_warning("[SaveManager] no saved state for '%s' – keeps its default state" % id)
		elif not node.has_method("load_state"):
			push_warning("[SaveManager] saveable '%s' has no load_state()" % id)
		else:
			node.call("load_state", data)
	for key: Variant in nodes:
		if not seen.has(str(key)):
			push_warning("[SaveManager] saved state for unknown save_id '%s' ignored" % str(key))


static func post_load(tree: SceneTree) -> void:
	for node: Node in saveables(tree):
		if node.has_method("post_load"):
			node.call("post_load")


## Saveable nodes with a save_id, sorted by save_order, then save_id, then tree order.
static func saveables(tree: SceneTree) -> Array[Node]:
	var out: Array[Node] = []
	var tree_index := {}
	for node: Node in tree.get_nodes_in_group(SAVEABLE_GROUP):
		if node.is_queued_for_deletion():
			continue
		if save_id(node) == "":
			push_warning("[SaveManager] saveable %s has no save_id – skipped" % node.get_path())
			continue
		tree_index[node] = out.size()
		out.append(node)
	out.sort_custom(func(a: Node, b: Node) -> bool:
		if save_order(a) != save_order(b):
			return save_order(a) < save_order(b)
		if save_id(a) != save_id(b):
			return save_id(a) < save_id(b)
		return int(tree_index[a]) < int(tree_index[b]))
	return out


static func save_id(node: Node) -> String:
	var id: Variant = node.get("save_id")
	return String(id) if id is String or id is StringName else ""


static func save_order(node: Node) -> int:
	var order: Variant = node.get("save_order")
	return int(order) if order is int or order is float else 0


static func autoload(tree: SceneTree, autoload_name: String) -> Node:
	return tree.root.get_node(autoload_name)


## data[key] if it is a Dictionary, else {} (warned).
static func sub_dict(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if value is Dictionary:
		return value
	push_warning("[SaveManager] state part '%s' is not a Dictionary" % key)
	return {}
