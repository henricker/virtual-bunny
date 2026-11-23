extends CharacterBody3D
## Wander → pause → think; reflection rituals; CRT search only for novel doubts.

const WALK_SPEED := 2.5
const ARRIVE_DIST := 0.35
const FLOOR_Y := 0.55
const STAND_OFF := 1.4
const ISLAND_HALF_X := 7.5
const ISLAND_HALF_Z := 6.0
const DEFAULT_STOPS_REFLECT := 5
const DEFAULT_STOPS_FORCE_CHECK := 12

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
var _stops_since_pause: int = 0
var _file_env: Dictionary = {}


func _ready() -> void:
	motion_mode = MOTION_MODE_GROUNDED
	floor_stop_on_slope = false
	floor_constant_speed = true
	collision_layer = 2
	collision_mask = 1
	_thoughts = get_node(thoughts_ui_path)
	_graph = get_node(graph_ui_path)
	_walk_target = get_node(walk_target_path)
	_board = get_node(board_path)
	_load_env_file()
	call_deferred("_life_loop")


func _load_env_file() -> void:
	for path in ["res://brain.env", "res://.env"]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		while f.get_position() < f.get_length():
			var line := f.get_line().strip_edges()
			if line.is_empty() or line.begins_with("#"):
				continue
			var parts := line.split("=", true, 1)
			if parts.size() == 2:
				_file_env[parts[0].strip_edges()] = parts[1].strip_edges().trim_prefix("\"").trim_suffix("\"")


func _env_int(key: String, default_val: int) -> int:
	var raw := str(_file_env.get(key, ""))
	if raw.is_empty():
		raw = OS.get_environment(key)
	if raw.is_empty() or not raw.is_valid_int():
		return default_val
	return maxi(2, int(raw))


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
	velocity = to.normalized() * WALK_SPEED
	velocity.y = 0.0
	move_and_slide()
	global_position.y = FLOOR_Y
	var face := global_position + Vector3(to.x, 0.0, to.z)
	if face.distance_squared_to(global_position) > 0.01:
		look_at(face, Vector3.UP)


func _life_loop() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await BrainClient.wait_ready()
	var reflect_every := _env_int("RITUAL_STOPS_REFLECT", DEFAULT_STOPS_REFLECT)
	while true:
		var dest := _pick_destination()
		var label := _label_near(dest)
		_thoughts.show_thought(_walk_line())
		await _walk_to(dest)
		await get_tree().create_timer(0.35).timeout
		_thoughts.show_thought(BrainClient.quick_thought(label))
		_stops_since_pause += 1
		await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
		if _stops_since_pause >= reflect_every:
			_stops_since_pause = 0
			await _ritual_curiosity()


func _pick_destination() -> Vector3:
	var objects: Array[Dictionary] = PerceptionRegistry.get_all()
	if not objects.is_empty():
		var pick: Dictionary = objects[_explore_index % objects.size()]
		_explore_index += 1
		var pos: Vector3 = pick["position"]
		return _approach_near(pos)
	return _random_island_point()


func _random_island_point() -> Vector3:
	var x := randf_range(-ISLAND_HALF_X, ISLAND_HALF_X)
	var z := randf_range(-ISLAND_HALF_Z, ISLAND_HALF_Z)
	return Vector3(x, FLOOR_Y, z)


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


func _approach_near(world_pos: Vector3, stand_off: float = STAND_OFF) -> Vector3:
	var center := Vector3(world_pos.x, FLOOR_Y, world_pos.z)
	var here := Vector3(global_position.x, FLOOR_Y, global_position.z)
	var dir := here - center
	if dir.length_squared() < 0.25:
		dir = Vector3(1.0, 0.0, 0.5)
	dir = dir.normalized()
	var point := center + dir * stand_off
	point.x = clampf(point.x, -ISLAND_HALF_X, ISLAND_HALF_X)
	point.z = clampf(point.z, -ISLAND_HALF_Z, ISLAND_HALF_Z)
	return Vector3(point.x, FLOOR_Y, point.z)


func _walk_to(position: Vector3) -> void:
	_walk_goal = Vector3(position.x, FLOOR_Y, position.z)
	_is_walking = true
	while _is_walking:
		await get_tree().physics_frame


func _should_search_web(derive: Dictionary, query: String) -> bool:
	if query.strip_edges().is_empty():
		return false
	if not ResearchLog.is_novel_query(query):
		print("[Rabbit] dúvida parecida com pesquisa anterior — só reflexão")
		return false
	if ResearchLog.seconds_since_last_search() < BrainClient.min_search_interval_sec():
		print("[Rabbit] cooldown de pesquisa — só reflexão")
		return false
	if not bool(derive.get("needs_web_search", false)):
		return false
	# Primeira pesquisa: permitir se ele formou pergunta.
	if ResearchLog.search_count() == 0 and "?" in str(derive.get("monologue", "")):
		return true
	# Depois: precisa de pergunta explícita + sorte moderada (menos ansiedade).
	if "?" not in str(derive.get("monologue", "")):
		return false
	return randf() < BrainClient.research_search_chance()


func _ritual_curiosity() -> void:
	var focus := _label_near(global_position)
	var derive: Dictionary = await BrainClient.derive_thought(
		PerceptionRegistry.snapshot(), _graph_nodes, _graph_edges
	)
	_thoughts.show_thought(derive.get("monologue", ""))
	_merge_graph(derive)
	var research_q := _research_query(derive)
	if _should_search_web(derive, research_q):
		await _ritual_search(research_q)
	else:
		await _ritual_reflect(focus)
	_graph.set_graph(_graph_nodes, _graph_edges)


func _ritual_reflect(focus: String) -> void:
	var ctx := ResearchLog.get_reflect_context()
	var reflection: Dictionary = await BrainClient.reflect_thought(focus, ctx)
	_thoughts.show_thought(reflection.get("monologue", ""))
	_merge_graph(reflection)
	await get_tree().create_timer(randf_range(0.6, 1.4)).timeout
	# Esboço no mural sem pesquisa — consolida memória visual, sem Brave.
	if _graph_nodes.size() >= 2 and randf() < 0.35:
		await _walk_to(_approach_near(_board.global_position, 1.0))
		_thoughts.show_thought("Vou rabiscar no quadro…")
		var sketch: Dictionary = await BrainClient.sketch_thought(_graph_nodes)
		_thoughts.show_thought(sketch.get("monologue", ""))
		var tex: Texture2D = sketch.get("texture")
		if tex:
			SketchArchive.add_sketch(str(sketch.get("caption", "")), tex)
			if _board.has_method("wait_for_draw_animation"):
				await _board.wait_for_draw_animation()
		await get_tree().create_timer(0.4).timeout


func _ritual_search(question: String) -> void:
	_thoughts.show_thought("Surgiu uma dúvida nova… vou até o CRT.")
	await _walk_to(_approach_near(_walk_target.global_position, 0.9))
	_thoughts.show_thought("Digitando na CRT…")
	var research: Dictionary = await BrainClient.research_thought(question)
	_thoughts.show_thought(research.get("monologue", ""))
	_merge_graph(research)
	await get_tree().create_timer(0.8).timeout
	await _walk_to(_approach_near(_board.global_position, 1.0))
	_thoughts.show_thought("Vou rabiscar no quadro…")
	var sketch: Dictionary = await BrainClient.sketch_thought(_graph_nodes)
	_thoughts.show_thought(sketch.get("monologue", ""))
	var tex: Texture2D = sketch.get("texture")
	if tex:
		SketchArchive.add_sketch(str(sketch.get("caption", "")), tex)
		if _board.has_method("wait_for_draw_animation"):
			await _board.wait_for_draw_animation()
	await get_tree().create_timer(0.5).timeout


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