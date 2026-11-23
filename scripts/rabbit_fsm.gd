extends CharacterBody3D
## FSM: idle → perceive → derive → (doubt) walk_to_pc → research → update_graph → sketch_on_board → idle

enum State {
	IDLE,
	PERCEIVE,
	DERIVE,
	WALK_TO_PC,
	RESEARCH,
	UPDATE_GRAPH,
	SKETCH_ON_BOARD,
}

const WALK_SPEED := 2.2

@export var thoughts_ui_path: NodePath
@export var graph_ui_path: NodePath
@export var walk_target_path: NodePath
@export var board_path: NodePath

var state: State = State.IDLE
var _thoughts: Node
var _graph: Node
var _walk_target: Node3D
var _board: Node3D
var _graph_nodes: Array = []
var _graph_edges: Array = []
var _sketch_plane: MeshInstance3D
var _busy: bool = false


func _ready() -> void:
	_thoughts = get_node(thoughts_ui_path)
	_graph = get_node(graph_ui_path)
	_walk_target = get_node(walk_target_path)
	_board = get_node(board_path)
	_create_sketch_plane()
	call_deferred("_begin_loop")


func _create_sketch_plane() -> void:
	_sketch_plane = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	_sketch_plane.mesh = mesh
	_sketch_plane.visible = false
	_board.add_child(_sketch_plane)
	_sketch_plane.position = Vector3(-0.35, 1.55, 0.12)


func _physics_process(delta: float) -> void:
	if state == State.WALK_TO_PC:
		var target := _walk_target.global_position
		var to := target - global_position
		to.y = 0
		if to.length() > 0.25:
			velocity = to.normalized() * WALK_SPEED
			look_at(global_position + to, Vector3.UP)
			move_and_slide()
		else:
			velocity = Vector3.ZERO
			_advance(State.RESEARCH)


func _begin_loop() -> void:
	await get_tree().create_timer(0.8).timeout
	_advance(State.PERCEIVE)


func _advance(next: State) -> void:
	if _busy:
		return
	state = next
	match state:
		State.IDLE:
			_thoughts.show_thought("…")
		State.PERCEIVE:
			_run_perceive()
		State.DERIVE:
			_run_derive()
		State.WALK_TO_PC:
			_thoughts.show_thought("Será que o computador sabe? Vou até lá.")
		State.RESEARCH:
			_run_research()
		State.UPDATE_GRAPH:
			_run_update_graph()
		State.SKETCH_ON_BOARD:
			_run_sketch()


func _run_perceive() -> void:
	_busy = true
	_thoughts.show_thought("Olhando a ilha…")
	var snap := PerceptionRegistry.snapshot()
	var data := await _call_brain_perceive(snap)
	_thoughts.show_thought(data.get("monologue", ""))
	_busy = false
	await get_tree().create_timer(1.2).timeout
	_advance(State.DERIVE)


func _run_derive() -> void:
	_busy = true
	var ctx := {"scene": PerceptionRegistry.snapshot(), "graph": {"nodes": _graph_nodes, "edges": _graph_edges}}
	var data := await _call_brain_derive(ctx)
	_thoughts.show_thought(data.get("monologue", ""))
	_merge_graph(data)
	_busy = false
	var needs := bool(data.get("needs_web_search", false))
	await get_tree().create_timer(1.0).timeout
	if needs:
		_advance(State.WALK_TO_PC)
	else:
		_advance(State.UPDATE_GRAPH)


func _run_research() -> void:
	_busy = true
	_thoughts.show_thought("Digitando na CRT…")
	var question := "O que é curioso nesta ilha?"
	var data := await _call_brain_research(question)
	_thoughts.show_thought(data.get("monologue", data.get("summary", "")))
	_merge_graph(data)
	_busy = false
	await get_tree().create_timer(1.2).timeout
	_advance(State.UPDATE_GRAPH)


func _run_update_graph() -> void:
	_graph.set_graph(_graph_nodes, _graph_edges)
	_thoughts.show_thought("Ligando ideias no grafo…")
	await get_tree().create_timer(1.0).timeout
	_advance(State.SKETCH_ON_BOARD)


func _run_sketch() -> void:
	var data := BrainClient.mock_sketch()
	_thoughts.show_thought(data.get("monologue", "Rabisco no quadro."))
	_sketch_plane.visible = true
	await get_tree().create_timer(2.0).timeout
	_advance(State.IDLE)
	await get_tree().create_timer(1.5).timeout
	_advance(State.PERCEIVE)


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


func _call_brain_perceive(scene: Array) -> Dictionary:
	if BrainClient.uses_mock():
		return BrainClient.mock_perceive(scene)
	return await BrainClient.perceive(scene)


func _call_brain_derive(ctx: Dictionary) -> Dictionary:
	if BrainClient.uses_mock():
		return BrainClient.mock_derive()
	return await BrainClient.derive(ctx)


func _call_brain_research(q: String) -> Dictionary:
	if BrainClient.uses_mock():
		return BrainClient.mock_research()
	return await BrainClient.research(q)