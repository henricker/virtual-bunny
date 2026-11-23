extends Node3D
## Builds the low-poly scene procedurally and registers perceptions.

const LOW_POLY_COLOR := Color(0.45, 0.78, 0.42)
const SAND_COLOR := Color(0.82, 0.72, 0.55)
const WOOD_COLOR := Color(0.55, 0.38, 0.22)
const CRT_COLOR := Color(0.75, 0.73, 0.68)

@export var rabbit_path: NodePath
@export var walk_target_path: NodePath

var _rabbit: Node3D


func _ready() -> void:
	PerceptionRegistry.clear()
	_build_island()
	_build_props()
	_rabbit = get_node_or_null(rabbit_path)


func _mesh_box(color: Color, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.mesh = mesh
	mi.material_override = mat
	return mi


func _mesh_sphere(color: Color, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 8
	mesh.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.mesh = mesh
	mi.material_override = mat
	return mi


func _add_labeled(parent: Node3D, perception_id: String, label: String, node: Node3D) -> void:
	parent.add_child(node)
	PerceptionRegistry.register(perception_id, label, node.global_position, node)


func _build_island() -> void:
	var ground := _mesh_box(LOW_POLY_COLOR, Vector3(18, 0.4, 14))
	ground.position = Vector3(0, -0.2, 0)
	add_child(ground)
	PerceptionRegistry.register("grass", "grama da ilha", ground.global_position, ground)

	var cliff := _mesh_box(SAND_COLOR, Vector3(5, 1.2, 4))
	cliff.position = Vector3(-6, 0.4, -4)
	cliff.rotation_degrees = Vector3(0, 18, 0)
	_add_labeled(self, "rock", "penhasco de areia", cliff)

	for i in 3:
		var tree_trunk := _mesh_box(WOOD_COLOR, Vector3(0.35, 1.6, 0.35))
		var tree_top := _mesh_box(LOW_POLY_COLOR.darkened(0.15), Vector3(1.2, 1.0, 1.2))
		var tree := Node3D.new()
		tree_trunk.position = Vector3(0, 0.8, 0)
		tree_top.position = Vector3(0, 1.8, 0)
		tree.add_child(tree_trunk)
		tree.add_child(tree_top)
		tree.position = Vector3(4 + i * 2.5, 0, -3 + i)
		_add_labeled(self, "tree_%d" % i, "pinheiro baixo", tree)

	var hut := Node3D.new()
	var hut_base := _mesh_box(WOOD_COLOR, Vector3(2.2, 1.4, 2.2))
	hut_base.position = Vector3(0, 0.7, 0)
	hut.add_child(hut_base)
	var roof := _mesh_box(SAND_COLOR.darkened(0.2), Vector3(2.6, 0.5, 2.6))
	roof.position = Vector3(0, 1.6, 0)
	roof.rotation_degrees = Vector3(0, 45, 0)
	hut.add_child(roof)
	hut.position = Vector3(7, 0, 4)
	_add_labeled(self, "hut", "cabana de madeira", hut)


func _build_props() -> void:
	var desk_root := Node3D.new()
	desk_root.name = "Desk"
	var top := _mesh_box(WOOD_COLOR, Vector3(2.4, 0.12, 1.0))
	top.position = Vector3(0, 0.75, 0)
	desk_root.add_child(top)
	for x in [-1.0, 1.0]:
		for z in [-0.35, 0.35]:
			var leg := _mesh_box(WOOD_COLOR.darkened(0.1), Vector3(0.12, 0.75, 0.12))
			leg.position = Vector3(x, 0.375, z)
			desk_root.add_child(leg)
	desk_root.position = Vector3(3, 0, 2)
	add_child(desk_root)
	PerceptionRegistry.register("pc_desk", "mesa de estudo", desk_root.global_position, desk_root)

	var monitor := _mesh_box(CRT_COLOR, Vector3(0.9, 0.65, 0.35))
	monitor.position = Vector3(3, 1.35, 2)
	add_child(monitor)
	PerceptionRegistry.register("crt_monitor", "monitor CRT", monitor.global_position, monitor)

	var tower := _mesh_box(CRT_COLOR.darkened(0.05), Vector3(0.35, 0.7, 0.35))
	tower.position = Vector3(2.2, 0.35, 2.2)
	add_child(tower)
	PerceptionRegistry.register("pc_tower", "torre do PC", tower.global_position, tower)

	var board := Node3D.new()
	board.name = "CorkBoard"
	var frame := _mesh_box(WOOD_COLOR.darkened(0.15), Vector3(2.2, 1.6, 0.12))
	frame.position = Vector3(0, 1.4, 0)
	board.add_child(frame)
	var surface := _mesh_box(Color(0.9, 0.85, 0.7), Vector3(1.9, 1.3, 0.08))
	surface.position = Vector3(0, 1.4, 0.06)
	board.add_child(surface)
	board.position = Vector3(-3.5, 0, 3)
	add_child(board)
	PerceptionRegistry.register("cork_board", "quadro de cortiça", board.global_position, board)

	var walk := Marker3D.new()
	walk.name = "WalkTargetPC"
	walk.position = Vector3(2.5, 0, 2.0)
	add_child(walk)