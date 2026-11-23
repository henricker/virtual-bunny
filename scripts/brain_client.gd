extends Node
## HTTP client for Ollama-compatible API. Uses local mock when offline.

const DEFAULT_URL := "http://127.0.0.1:11434"
const MOCK_PATH := "res://brain/mock_responses.json"

var _mock: Dictionary = {}
var _probe_http: HTTPRequest
var _chat_http: HTTPRequest
var _use_mock: bool = true


func _ready() -> void:
	_probe_http = HTTPRequest.new()
	_chat_http = HTTPRequest.new()
	add_child(_probe_http)
	add_child(_chat_http)
	_probe_http.request_completed.connect(_on_probe_done)
	_load_mock()
	call_deferred("_probe_api")


func api_url() -> String:
	var from_env := OS.get_environment("BRAIN_API_URL")
	if from_env.is_empty():
		return DEFAULT_URL
	return from_env.rstrip("/")


func _load_mock() -> void:
	if not FileAccess.file_exists(MOCK_PATH):
		push_warning("Mock file not found: %s" % MOCK_PATH)
		return
	var f := FileAccess.open(MOCK_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_mock = parsed


func _probe_api() -> void:
	if _mock.is_empty():
		return
	var err := _probe_http.request("%s/api/tags" % api_url(), [], HTTPClient.METHOD_GET)
	if err != OK:
		_use_mock = true


func _on_probe_done(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		_use_mock = false
	else:
		_use_mock = true


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


func perceive(scene_objects: Array) -> Dictionary:
	if _use_mock or _mock.is_empty():
		return mock_perceive(scene_objects)
	var prompt := "Você é um coelho curioso na ilha. Descreva em PT-BR o que percebe nestes objetos: %s" % JSON.stringify(scene_objects)
	var reply := await _chat(prompt)
	return {
		"monologue": reply,
		"perceptions": [],
		"source": "ollama",
	}


func derive(context: Dictionary) -> Dictionary:
	if _use_mock:
		return mock_derive()
	var prompt := "Derive hipóteses em PT-BR a partir de: %s. Responda JSON com needs_web_search bool." % JSON.stringify(context)
	var reply := await _chat(prompt)
	return {
		"monologue": reply,
		"needs_web_search": false,
		"nodes": [],
		"edges": [],
		"source": "ollama",
	}


func research(question: String) -> Dictionary:
	if _use_mock:
		return mock_research()
	var prompt := "Responda em PT-BR de forma curta: %s" % question
	var reply := await _chat(prompt)
	return {
		"monologue": reply,
		"summary": reply,
		"nodes": [],
		"edges": [],
		"source": "ollama",
	}


func _chat(user_prompt: String) -> String:
	var body := {
		"model": "llama3.2:1b",
		"messages": [
			{"role": "system", "content": "Coelho virtual, PT-BR, tom curioso e seco."},
			{"role": "user", "content": user_prompt},
		],
		"stream": false,
	}
	var headers := ["Content-Type: application/json"]
	var err := _chat_http.request("%s/api/chat" % api_url(), headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_use_mock = true
		return "(Cérebro offline — usando mock.)"
	var args: Array = await _chat_http.request_completed
	var code: int = args[1]
	var raw: PackedByteArray = args[3]
	if code != 200:
		_use_mock = true
		return "(Erro do cérebro — usando mock.)"
	var data: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return str(data)
	var msg: Dictionary = data.get("message", {})
	return str(msg.get("content", ""))


func uses_mock() -> bool:
	return _use_mock