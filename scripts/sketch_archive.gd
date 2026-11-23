extends Node

signal sketch_added(sketch: Dictionary)

var items: Array[Dictionary] = []


func add_sketch(caption: String, texture: Texture2D) -> Dictionary:
	var item := {
		"id": items.size(),
		"caption": caption,
		"texture": texture,
		"time": Time.get_datetime_string_from_system(true),
	}
	items.append(item)
	sketch_added.emit(item)
	return item


func get_all() -> Array:
	return items