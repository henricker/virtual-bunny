extends Node
## Wikipedia lookup: Wikimedia Enterprise On-demand API (ptwiki) + offline fallback.

const API_BASE := "https://api.enterprise.wikimedia.com/v2"
const SNIPPETS_PATH := "res://brain/wiki_snippets.json"
const DEFAULT_PROJECT := "ptwiki"

var _snippets: Array = []
var _http: HTTPRequest
var _file_env: Dictionary = {}


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_load_env_file()
	_load_snippets()


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


func _load_snippets() -> void:
	if not FileAccess.file_exists(SNIPPETS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SNIPPETS_PATH))
	if typeof(parsed) == TYPE_ARRAY:
		_snippets = parsed


func search(query: String) -> Dictionary:
	# Sync fallback only (offline). Prefer search_async from game code.
	return _search_offline(query)


func search_async(query: String) -> Dictionary:
	var token := _access_token()
	if token.is_empty():
		print("[WikiLookup] sem token Enterprise — usando wiki_snippets.json")
		return _search_offline(query)
	var titles := _candidate_titles(query)
	for title in titles:
		var hit := await _fetch_article(title, token)
		if not hit.is_empty():
			return hit
	push_warning("[WikiLookup] Enterprise sem match para: %s" % query)
	return _search_offline(query)


func _access_token() -> String:
	for key in ["WIKIMEDIA_ENTERPRISE_TOKEN", "ACCESS_TOKEN", "WME_ACCESS_TOKEN"]:
		var from_file := str(_file_env.get(key, ""))
		if not from_file.is_empty():
			return from_file
		var from_env := OS.get_environment(key)
		if not from_env.is_empty():
			return from_env
	return ""


func _wiki_project() -> String:
	var p := str(_file_env.get("WIKIMEDIA_ENTERPRISE_PROJECT", ""))
	if p.is_empty():
		p = OS.get_environment("WIKIMEDIA_ENTERPRISE_PROJECT")
	if p.is_empty():
		p = DEFAULT_PROJECT
	return p


func _candidate_titles(query: String) -> Array[String]:
	var q := query.to_lower()
	var out: Array[String] = []
	var map := {
		"grama": "Grama",
		"pedra": "Rocha",
		"penhasco": "Rocha",
		"rocha": "Rocha",
		"microclima": "Clima",
		"clima": "Clima",
		"árvore": "Árvore",
		"arvore": "Árvore",
		"pinheiro": "Pinheiro",
		"ilha": "Ilha",
		"coelho": "Coelho",
		"planta": "Planta",
		"natureza": "Natureza",
	}
	for key in map:
		if key in q:
			out.append(map[key])
	for word in q.split(" ", false):
		var w := word.strip_edges()
		if w.length() > 4 and not out.has(w.capitalize()):
			out.append(w.capitalize())
	if out.is_empty():
		out.append("Natureza")
	return out


func _article_path_title(title: String) -> String:
	return title.strip_edges().replace(" ", "_")


func _fetch_article(title: String, token: String) -> Dictionary:
	var path_title := _article_path_title(title)
	var url := "%s/articles/%s" % [API_BASE, path_title.uri_encode()]
	var body := {
		"filters": [{"field": "is_part_of.identifier", "value": _wiki_project()}],
		"fields": ["name", "abstract", "url", "date_modified"],
	}
	var headers := [
		"Authorization: Bearer %s" % token,
		"Content-Type: application/json",
	]
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		return {}
	var args: Array = await _http.request_completed
	if args[0] != HTTPRequest.RESULT_SUCCESS or args[1] != 200:
		return {}
	var parsed: Variant = JSON.parse_string(args[3].get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY or parsed.is_empty():
		return {}
	var article: Dictionary = parsed[0]
	var abstract := str(article.get("abstract", ""))
	if abstract.is_empty():
		return {}
	return {
		"title": str(article.get("name", title)),
		"excerpt": abstract.substr(0, mini(abstract.length(), 600)),
		"url": str(article.get("url", "")),
		"source": "wikimedia-enterprise",
	}


func _search_offline(query: String) -> Dictionary:
	var q := query.to_lower()
	var best: Dictionary = {}
	var best_score := 0
	for item: Variant in _snippets:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var score := 0
		for kw: Variant in item.get("keywords", []):
			var k := str(kw).to_lower()
			if k in q:
				score += 2
		if score > best_score:
			best_score = score
			best = item
	if best_score == 0 and not _snippets.is_empty():
		best = _snippets[randi() % _snippets.size()]
	return {
		"title": str(best.get("title", "Nota local")),
		"excerpt": str(best.get("excerpt", "")),
		"url": "",
		"source": "offline-wiki",
	}