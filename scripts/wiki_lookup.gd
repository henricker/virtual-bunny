extends Node
## Pesquisa na web: Brave Search API → trechos locais (offline).

const BRAVE_SEARCH_URL := "https://api.search.brave.com/res/v1/web/search"
const SNIPPETS_PATH := "res://brain/wiki_snippets.json"
const MAX_EXCERPT_CHARS := 1200
const MAX_PAGE_CHARS := 4500

var _snippets: Array = []
var _http: HTTPRequest
var _file_env: Dictionary = {}


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 12.0
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
	return _search_offline(query)


func search_async(query: String) -> Dictionary:
	var brave_key := _brave_api_key()
	if not brave_key.is_empty():
		var hit := await _search_brave(query, brave_key)
		if not hit.is_empty():
			return hit
		push_warning("[Research] Brave sem resultado — fallback offline")
	else:
		print("[Research] sem Brave — usando snippets locais")
	return _search_offline(query)


func _brave_api_key() -> String:
	for key in ["BRAVE_SEARCH_API_KEY", "BRAVE_API_KEY"]:
		var from_file := str(_file_env.get(key, ""))
		if not from_file.is_empty():
			return from_file
		var from_env := OS.get_environment(key)
		if not from_env.is_empty():
			return from_env
	return ""


func _env_bool(key: String, default: bool) -> bool:
	var raw := str(_file_env.get(key, "")).to_lower()
	if raw.is_empty():
		raw = OS.get_environment(key).to_lower()
	if raw.is_empty():
		return default
	return raw in ["1", "true", "yes", "on"]


func _brave_result_count() -> int:
	var raw := str(_file_env.get("BRAVE_SEARCH_COUNT", ""))
	if raw.is_empty():
		raw = OS.get_environment("BRAVE_SEARCH_COUNT")
	if raw.is_empty() or not raw.is_valid_int():
		return 5
	return clampi(int(raw), 1, 20)


func _search_brave(query: String, api_key: String) -> Dictionary:
	var count := _brave_result_count()
	var q := query.uri_encode()
	var url := "%s?q=%s&count=%d&search_lang=pt-br&country=BR&text_decorations=0" % [
		BRAVE_SEARCH_URL, q, count,
	]
	var headers := [
		"Accept: application/json",
		"X-Subscription-Token: %s" % api_key,
	]
	var err := _http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		return {}
	var args: Array = await _http.request_completed
	if args[0] != HTTPRequest.RESULT_SUCCESS or args[1] != 200:
		push_warning("[Research] Brave HTTP %s" % str(args[1]))
		return {}
	var root: Variant = JSON.parse_string(args[3].get_string_from_utf8())
	if typeof(root) != TYPE_DICTIONARY:
		return {}
	var web: Variant = root.get("web", {})
	if typeof(web) != TYPE_DICTIONARY:
		return {}
	var results: Variant = web.get("results", [])
	if typeof(results) != TYPE_ARRAY or results.is_empty():
		return {}
	var serp: Array[Dictionary] = []
	for item: Variant in results:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var u := str(item.get("url", ""))
		if u.is_empty() or not _url_allowed(u):
			continue
		serp.append({
			"title": str(item.get("title", "")),
			"url": u,
			"snippet": str(item.get("description", "")),
		})
	if serp.is_empty():
		return {}
	var top: Dictionary = serp[0]
	var excerpt := str(top.get("snippet", ""))
	if _env_bool("BRAVE_FETCH_TOP_PAGE", false):
		var body := await _fetch_page_text(str(top.get("url", "")))
		if not body.is_empty():
			excerpt = body
	elif excerpt.is_empty() and serp.size() > 1:
		var parts: PackedStringArray = []
		for i in mini(3, serp.size()):
			parts.append("%s: %s" % [serp[i].get("title"), serp[i].get("snippet")])
		excerpt = " ".join(parts)
	excerpt = excerpt.substr(0, mini(excerpt.length(), MAX_EXCERPT_CHARS))
	print("[Research] Brave → %s" % top.get("url", ""))
	return {
		"title": str(top.get("title", "Resultado")),
		"excerpt": excerpt,
		"url": str(top.get("url", "")),
		"source": "brave-search",
		"results": serp,
	}


func _allowlist_domains() -> Array[String]:
	var raw := str(_file_env.get("RESEARCH_URL_ALLOWLIST", ""))
	if raw.is_empty():
		raw = OS.get_environment("RESEARCH_URL_ALLOWLIST")
	if raw.is_empty():
		return []
	var out: Array[String] = []
	for part in raw.split(",", false):
		var d := part.strip_edges().to_lower()
		if not d.is_empty():
			out.append(d)
	return out


func _url_allowed(url: String) -> bool:
	var list := _allowlist_domains()
	if list.is_empty():
		return url.begins_with("http://") or url.begins_with("https://")
	var host := _host_from_url(url)
	for dom in list:
		if host == dom or host.ends_with("." + dom):
			return true
	return false


func _host_from_url(url: String) -> String:
	var u := url.strip_edges()
	if not "://" in u:
		return ""
	var rest := u.split("://", true, 1)[1]
	var host := rest.split("/", false)[0].split("?", false)[0].to_lower()
	if host.begins_with("www."):
		host = host.substr(4)
	return host


func _fetch_page_text(url: String) -> String:
	if url.is_empty() or not _url_allowed(url):
		return ""
	var headers := ["User-Agent: CoelhoVirtual/1.0 (Godot research ritual)"]
	var err := _http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		return ""
	var args: Array = await _http.request_completed
	if args[0] != HTTPRequest.RESULT_SUCCESS or args[1] != 200:
		return ""
	var html := args[3].get_string_from_utf8()
	return _html_to_plain(html)


func _html_to_plain(html: String) -> String:
	var text := html
	for tag in ["script", "style", "nav", "footer", "header"]:
		var open := "<%s" % tag
		var close := "</%s>" % tag
		while open in text.to_lower():
			var start := text.to_lower().find(open)
			var end_tag := text.to_lower().find(close, start)
			if end_tag < 0:
				break
			text = text.substr(0, start) + text.substr(end_tag + close.length())
	var re_tag := RegEx.new()
	re_tag.compile("<[^>]+>")
	text = re_tag.sub(text, " ", true)
	text = text.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
	text = text.replace("\t", " ")
	while "  " in text:
		text = text.replace("  ", " ")
	return text.strip_edges().substr(0, mini(text.length(), MAX_PAGE_CHARS))


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
		"source": "offline-snippets",
		"results": [],
	}