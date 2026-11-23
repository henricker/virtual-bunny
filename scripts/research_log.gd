extends Node

signal entry_added(entry: Dictionary)

var entries: Array[Dictionary] = []


func add_entry(
		query: String,
		title: String,
		excerpt: String,
		source: String = "offline-wiki",
		url: String = ""
) -> void:
	var entry := {
		"id": entries.size(),
		"query": query,
		"title": title,
		"excerpt": excerpt,
		"source": source,
		"url": url,
		"time": Time.get_datetime_string_from_system(true),
	}
	entries.append(entry)
	entry_added.emit(entry)


func get_all() -> Array:
	return entries