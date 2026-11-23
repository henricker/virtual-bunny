extends Node
## HTTP client for Ollama-compatible API. Uses local mock when offline.

const DEFAULT_URL := "http://127.0.0.1:11434"
const DEFAULT_MODEL := "llama3.2:1b"
const MOCK_PATH := "res://brain/mock_responses.json"

var _mock: Dictionary = {}
var _probe_http: HTTPRequest
var _chat_http: HTTPRequest
var _use_mock: bool = true
var _resolved_model: String = ""
var _probe_finished: bool = false
var _file_env: Dictionary = {}


func _ready() -> void:
	_probe_http = HTTPRequest.new()
	_chat_http = HTTPRequest.new()
	_chat_http.timeout = 5.0
	_probe_http.timeout = 5.0
	add_child(_probe_http)
	add_child(_chat_http)
	_load_env_file()
	_load_mock()
	call_deferred("_boot")


func wait_ready() -> void:
	var frames := 0
	while not _probe_finished and frames < 120:
		frames += 1
		await get_tree().process_frame
	if not _probe_finished:
		_probe_finished = true
		_use_mock = true


func api_url() -> String:
	var from_file: String = str(_file_env.get("BRAIN_API_URL", ""))
	if not from_file.is_empty():
		return from_file.rstrip("/")
	var from_env := OS.get_environment("BRAIN_API_URL")
	if not from_env.is_empty():
		return from_env.rstrip("/")
	return DEFAULT_URL


func model_name() -> String:
	# After probe, _resolved_model is an Ollama tag that actually exists.
	if not _resolved_model.is_empty():
		return _resolved_model
	var from_file: String = str(_file_env.get("BRAIN_MODEL", ""))
	if not from_file.is_empty():
		return from_file
	var from_env := OS.get_environment("BRAIN_MODEL")
	if not from_env.is_empty():
		return from_env
	return DEFAULT_MODEL


func _load_env_file() -> void:
	for path in ["res://.env", "res://brain.env"]:
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
		print("[BrainClient] loaded env from ", path)


func _load_mock() -> void:
	if not FileAccess.file_exists(MOCK_PATH):
		push_warning("Mock file not found: %s" % MOCK_PATH)
		return
	var f := FileAccess.open(MOCK_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_mock = parsed


func _boot() -> void:
	await _run_probe()
	_probe_finished = true
	_log_status()


func _run_probe() -> void:
	var url := "%s/api/tags" % api_url()
	var err := _probe_http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		_use_mock = true
		push_warning("[BrainClient] probe request failed err=%s" % err)
		return
	var args: Array = await _probe_http.request_completed
	var result: int = args[0]
	var code: int = args[1]
	var body: PackedByteArray = args[3]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_use_mock = true
		push_warning("[BrainClient] Ollama unreachable (%s) code=%s" % [url, code])
		return
	_use_mock = false
	_resolved_model = _pick_model_from_tags(body)
	print("[BrainClient] Ollama OK model=", model_name(), " url=", api_url())


func _pick_model_from_tags(body: PackedByteArray) -> String:
	var want := model_name()
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return want
	var models: Array = data.get("models", [])
	var names: PackedStringArray = []
	for m in models:
		if typeof(m) == TYPE_DICTIONARY:
			names.append(str(m.get("name", "")))
	for n in names:
		if n == want:
			return n
	var family := want.get_slice(":", 0)
	for n in names:
		if n.begins_with(family):
			return n
	if not names.is_empty():
		return names[0]
	return want


func _log_status() -> void:
	if _use_mock:
		print("[BrainClient] usando MOCK (Ollama offline ou probe falhou)")
	else:
		print("[BrainClient] usando Ollama model=", model_name())


func mock_perceive(scene_objects: Array) -> Dictionary:
	var base: Dictionary = _mock.get("perceive", {}).duplicate(true)
	base["scene"] = scene_objects
	return base


func mock_derive() -> Dictionary:
	return _mock.get("derive", {}).duplicate(true)


func mock_research() -> Dictionary:
	return _mock.get("research", {}).duplicate(true)


func mock_sketch() -> Dictionary:
	return _mock.get("sketch", {}).duplicate(true)


func quick_thought(focus_label: String) -> String:
	return _mock_wander_line(focus_label)


func think_at_scene(_scene: Array, focus_label: String) -> String:
	await wait_ready()
	if _use_mock:
		return _mock_wander_line(focus_label)
	var prompt := (
		"Coelho de desenho numa ilha com grama, árvores e um computador. "
		+ "Foco: %s. Responda UMA frase curta em português, só observação inocente." % focus_label
	)
	var reply := _sanitize(await _chat(prompt))
	if reply.is_empty():
		return _mock_wander_line(focus_label)
	return reply


func min_search_interval_sec() -> float:
	var raw := str(_file_env.get("RESEARCH_MIN_INTERVAL_SEC", ""))
	if raw.is_empty():
		raw = OS.get_environment("RESEARCH_MIN_INTERVAL_SEC")
	if raw.is_empty() or not raw.is_valid_float():
		return 1200.0
	return maxf(60.0, float(raw))


func research_search_chance() -> float:
	var raw := str(_file_env.get("RESEARCH_SEARCH_CHANCE", ""))
	if raw.is_empty():
		raw = OS.get_environment("RESEARCH_SEARCH_CHANCE")
	if raw.is_empty() or not raw.is_valid_float():
		return 0.3
	return clampf(float(raw), 0.05, 1.0)


func derive_thought(scene: Array, nodes: Array, edges: Array) -> Dictionary:
	await wait_ready()
	if _use_mock:
		var d: Dictionary = mock_derive().duplicate(true)
		# Com histórico, mock reflete mais do que pergunta de novo.
		if ResearchLog.search_count() >= 1 and randf() > 0.35:
			d["needs_web_search"] = false
			d["monologue"] = _mock_reflect_line()
		return d
	var prior := ResearchLog.get_reflect_context(3)
	var scene_blob: String = JSON.stringify({"scene": scene, "nodes": nodes.size()})
	var prompt := (
		"Coelho numa ilha. Cena: %s\n"
		+ "O que já leu:\n%s\n"
		+ "Responda UMA frase curta PT-BR: prefira refletir ligando o que já sabe ao que vê. "
		+ "Só faça pergunta nova se for dúvida bem diferente do que já leu."
		% [scene_blob, prior]
	)
	var reply := _sanitize(await _chat(prompt))
	var fallback: String = "Fico remoendo o que já li…"
	if reply.is_empty():
		reply = fallback
	var has_question := "?" in reply
	return {
		"monologue": reply,
		"needs_web_search": has_question,
		"nodes": mock_derive().get("nodes", []),
		"edges": mock_derive().get("edges", []),
	}


func reflect_thought(focus_label: String, prior_context: String) -> Dictionary:
	await wait_ready()
	if _use_mock:
		return {
			"monologue": _mock_reflect_line(),
			"nodes": [],
			"edges": [],
		}
	var prompt := (
		"Coelho pensativo perto de '%s'. Sem internet.\n"
		+ "Notas de leituras anteriores:\n%s\n"
		+ "Uma frase curta PT-BR: amadurecer ideia, comparar, lembrar — sem pedir pesquisa nova."
		% [focus_label, prior_context]
	)
	var reply := _sanitize(await _chat(prompt))
	if reply.is_empty():
		reply = "Isso combina com o que eu tinha lido antes…"
	return {"monologue": reply, "nodes": [], "edges": []}


func _mock_reflect_line() -> String:
	var lines := [
		"O que li no CRT ainda faz sentido perto da grama.",
		"Não preciso pesquisar de novo; só deixar a ideia descansar.",
		"Microclima… já tinha anotado isso. Agora é olhar o vento.",
		"Penso na pedra e no que a página disse ontem.",
		"Hmm. A resposta já está no quadro, só não encaixei ainda.",
	]
	return lines[randi() % lines.size()]


func research_thought(question: String) -> Dictionary:
	await wait_ready()
	var hit: Dictionary = await WikiLookup.search_async(question)
	var serp: Variant = hit.get("results", [])
	if typeof(serp) != TYPE_ARRAY:
		serp = []
	ResearchLog.add_entry(
		question,
		str(hit.get("title", "")),
		str(hit.get("excerpt", "")),
		str(hit.get("source", "offline-snippets")),
		str(hit.get("url", "")),
		serp
	)
	var summary := str(hit.get("excerpt", ""))
	if not _use_mock:
		var prompt := (
			"Reescreva em uma frase curta em português, como um coelho curioso, "
			+ "baseado só neste texto encontrado na web: %s"
			% summary
		)
		var reply := _sanitize(await _chat(prompt))
		if not reply.is_empty():
			summary = reply
	var mock: Dictionary = mock_research()
	return {
		"monologue": summary,
		"summary": summary,
		"nodes": mock.get("nodes", []),
		"edges": mock.get("edges", []),
	}


func sketch_thought(graph_nodes: Array) -> Dictionary:
	await wait_ready()
	var base_caption := SketchGenerator.caption_from_graph(graph_nodes)
	var caption := base_caption
	if not _use_mock:
		var prompt := (
			"Coelho desenha no quadro sobre: %s. "
			+ "UMA frase curta PT-BR (máx. 12 palavras)."
			% base_caption
		)
		var reply := _sanitize(await _chat(prompt))
		if not reply.is_empty():
			caption = reply
	var texture: Texture2D = SketchGenerator.make_texture(caption, randi())
	return {
		"caption": caption,
		"texture": texture,
		"monologue": "Vou rabiscar: %s" % caption,
	}


func _mock_wander_line(focus: String) -> String:
	var lines := [
		"Essa %s parece interessante…" % focus,
		"O ar aqui muda perto da %s." % focus,
		"Será que a %s sempre foi assim?" % focus,
		"Gosto de olhar a %s de perto.",
		"Hum… %s." % focus,
	]
	return lines[randi() % lines.size()]


func _sanitize(text: String) -> String:
	var t := text.strip_edges()
	if t.is_empty():
		return ""
	var lower := t.to_lower()
	if "não posso" in lower or "inapropri" in lower or "cannot" in lower:
		return ""
	if "peço desculpas" in lower and "conteúdo" in lower:
		return ""
	return t


func _chat(user_prompt: String) -> String:
	var body := {
		"model": model_name(),
		"messages": [
			{
				"role": "system",
				"content": "Você é um coelho de desenho animado numa ilha. Conteúdo infantil, grama, árvores, pedras. PT-BR. Sem conteúdo adulto, violência ou sexual. Só curiosidade inocente.",
			},
			{"role": "user", "content": user_prompt},
		],
		"stream": false,
		"options": {"temperature": 0.7, "num_predict": 80},
	}
	var headers := ["Content-Type: application/json"]
	var err := _chat_http.request("%s/api/chat" % api_url(), headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_warning("[BrainClient] chat request err=%s" % err)
		return ""
	var args: Array = await _chat_http.request_completed
	var code: int = args[1]
	var raw: PackedByteArray = args[3]
	if code != 200:
		push_warning("[BrainClient] chat HTTP %s: %s" % [code, raw.get_string_from_utf8().substr(0, 200)])
		return ""
	var data: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var msg: Dictionary = data.get("message", {})
	return str(msg.get("content", ""))


func uses_mock() -> bool:
	return _use_mock