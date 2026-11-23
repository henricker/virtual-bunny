extends Node
## Registers scene objects for the perception loop (id, label, position).

var _objects: Array[Dictionary] = []


func clear() -> void:
	_objects.clear()


func register(perception_id: String, label: String, world_position: Vector3, source: Node3D = null) -> void:
	_objects.append({
		"id": perception_id,
		"label": label,
		"position": world_position,
		"node_path": source.get_path() if source else NodePath(),
	})


func snapshot() -> Array:
	var out: Array = []
	for o in _objects:
		var p: Vector3 = o["position"]
		out.append({
			"id": o["id"],
			"label": o["label"],
			"position": [p.x, p.y, p.z],
		})
	return out


func get_all() -> Array[Dictionary]:
	return _objects