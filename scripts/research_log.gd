extends Node

signal entry_added(entry: Dictionary)

var entries: Array[Dictionary] = []
var last_search_tick_msec: int = 0


func add_entry(
		query: String,
		title: String,
		excerpt: String,
		source: String = "offline-snippets",
		url: String = "",
		results: Array = []
) -> void:
	var entry := {
		"id": entries.size(),
		"query": query,
		"title": title,
		"excerpt": excerpt,
		"source": source,
		"url": url,
		"results": results,
		"time": Time.get_datetime_string_from_system(true),
	}
	entries.append(entry)
	last_search_tick_msec = Time.get_ticks_msec()
	entry_added.emit(entry)


func get_all() -> Array:
	return entries


func search_count() -> int:
	return entries.size()


func seconds_since_last_search() -> float:
	if last_search_tick_msec == 0:
		return 99999.0
	return (Time.get_ticks_msec() - last_search_tick_msec) / 1000.0


func get_reflect_context(max_entries: int = 4) -> String:
	if entries.is_empty():
		return "Ainda não li nada no computador."
	var parts: PackedStringArray = []
	var start := maxi(0, entries.size() - max_entries)
	for i in range(start, entries.size()):
		var e: Dictionary = entries[i]
		parts.append(
			"- %s: %s"
			% [str(e.get("title", "")), str(e.get("excerpt", "")).substr(0, 200)]
		)
	return "\n".join(parts)


func is_novel_query(query: String, similarity_threshold: float = 0.5) -> bool:
	var q := _tokenize(query)
	if q.is_empty():
		return false
	for entry: Dictionary in entries:
		var past := _tokenize(str(entry.get("query", "")))
		if _overlap_ratio(q, past) >= similarity_threshold:
			return false
	return true


func _tokenize(text: String) -> Array[String]:
	var stop := {
		"o": true,
		"a": true,
		"e": true,
		"de": true,
		"da": true,
		"do": true,
		"em": true,
		"um": true,
		"uma": true,
		"que": true,
		"será": true,
		"como": true,
		"pra": true,
		"para": true,
		"no": true,
		"na": true,
		"eu": true,
		"vou": true,
	}
	var out: Array[String] = []
	for raw in text.to_lower().split(" ", false):
		var w := raw.strip_edges().trim_suffix("?").trim_suffix(".")
		if w.length() > 2 and not stop.has(w):
			out.append(w)
	return out


func _overlap_ratio(a: Array[String], b: Array[String]) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	var shared := 0
	for w in a:
		if b.has(w):
			shared += 1
	return float(shared) / float(maxi(a.size(), b.size()))