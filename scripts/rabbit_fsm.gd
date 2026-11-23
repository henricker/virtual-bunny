extends CharacterBody3D
## Wander → pause → think; periodic CRT / graph ritual.

const WALK_SPEED := 2.5
const ARRIVE_DIST := 0.35
const ISLAND_HALF_X := 7.5
const ISLAND_HALF_Z := 6.0

@export var thoughts_ui_path: NodePath
@export var graph_ui_path: NodePath
@export var walk_target_path: NodePath
@export var board_path: NodePath

var _thoughts: Node
var _graph: Node
var _walk_target: Node3D
var _board: Node3D
var _graph_nodes: Array = []
var _graph_edges: Array = []

var _is_walking: bool = false
var _walk_goal: Vector3 = Vector3.ZERO
var _explore_index: int = 0
var _stops_since_ritual: int = 0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	_thoughts = get_node(thoughts_ui_path)
	_graph = get_node(graph_ui_path)
	_walk_target = get_node(walk_target_path)
	_board = get_node(board_path)
	call_deferred("_life_loop")


func _physics_process(delta: float) -> void:
	if not _is_walking:
		return
	var to := _walk_goal - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= ARRIVE_DIST:
		_is_walking = false
		velocity = Vector3.ZERO
		return
	var step := minf(WALK_SPEED * delta, dist)
	global_position += to.normalized() * step
	var face := global_position + Vector3(to.x, 0.0, to.z)
	if face.distance_squared_to(global_position) > 0.01:
		look_at(face, Vector3.UP)


func _life_loop() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await BrainClient.wait_ready()
	while true:
		var dest := _pick_destination()
		var label := _label_near(dest)
		_thoughts.show_thought(_walk_line())
		await _walk_to(dest)
		await get_tree().create_timer(0.35).timeout
		_thoughts.show_thought(BrainClient.quick_thought(label))
		_stops_since_ritual += 1
		await get_tree().create_timer(randf_range(1.2, 2.4)).timeout
		if _stops_since_ritual >= 3:
			_stops_since_ritual = 0
			await _ritual_curiosity()


func _pick_destination() -> Vector3:
	var objects: Array[Dictionary] = PerceptionRegistry.get_all()
	if not objects.is_empty():
		var pick: Dictionary = objects[_explore_index % objects.size()]
		_explore_index += 1
		var pos: Vector3 = pick["position"]
		pos.y = global_position.y
		return pos
	return _random_island_point()


func _random_island_point() -> Vector3:
	var x := randf_range(-ISLAND_HALF_X, ISLAND_HALF_X)
	var z := randf_range(-ISLAND_HALF_Z, ISLAND_HALF_Z)
	return Vector3(x, global_position.y, z)


func _label_near(point: Vector3) -> String:
	var best := ""
	var best_d := 999.0
	for o in PerceptionRegistry.get_all():
		var p: Vector3 = o["position"]
		var d := point.distance_to(p)
		if d < best_d:
			best_d = d
			best = str(o.get("label", ""))
	return best if not best.is_empty() else "ilha"


func _walk_line() -> String:
	var lines := [
		"Andar um pouco…",
		"Vou dar uma volta.",
		"Tem coisa pra ver ali.",
		"Hmm…",
	]
	return lines[randi() % lines.size()]


func _walk_to(position: Vector3) -> void:
	_walk_goal = position
	_walk_goal.y = global_position.y
	_is_walking = true
	while _is_walking:
		await get_tree().physics_frame


func _ritual_curiosity() -> void:
	var derive: Dictionary = await BrainClient.derive_thought(PerceptionRegistry.snapshot(), _graph_nodes, _graph_edges)
	_thoughts.show_thought(derive.get("monologue", ""))
	_merge_graph(derive)
	if not bool(derive.get("needs_web_search", true)):
		return
	_thoughts.show_thought("Será que o computador sabe? Vou até lá.")
	await _walk_to(_walk_target.global_position)
	_thoughts.show_thought("Digitando na CRT…")
	var research_q := _research_query(derive)
	var research: Dictionary = await BrainClient.research_thought(research_q)
	_thoughts.show_thought(research.get("monologue", ""))
	_merge_graph(research)
	_graph.set_graph(_graph_nodes, _graph_edges)
	await get_tree().create_timer(0.8).timeout
	var sketch: Dictionary = await BrainClient.sketch_thought(_graph_nodes)
	_thoughts.show_thought(sketch.get("monologue", ""))
	var tex: Texture2D = sketch.get("texture")
	var cap: String = str(sketch.get("caption", ""))
	if tex:
		SketchArchive.add_sketch(cap, tex)
	await _walk_to(_board.global_position + Vector3(0.9, 0.0, 0.6))
	await get_tree().create_timer(1.2).timeout


func _research_query(derive: Dictionary) -> String:
	var bits: PackedStringArray = []
	for n: Variant in _graph_nodes:
		if typeof(n) == TYPE_DICTIONARY:
			bits.append(str(n.get("label", "")))
	bits.append(str(derive.get("monologue", "")))
	return " ".join(bits).strip_edges()


func _merge_graph(data: Dictionary) -> void:
	for n in data.get("nodes", []):
		if not _has_node(str(n.get("id", ""))):
			_graph_nodes.append(n)
	for e in data.get("edges", []):
		_graph_edges.append(e)


func _has_node(id: String) -> bool:
	for n in _graph_nodes:
		if str(n.get("id", "")) == id:
			return true
	return false