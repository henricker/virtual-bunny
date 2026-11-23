extends SceneTree
## Headless helper: capture one frame after the main scene loads.

const OUT_PATH := "/cursor/stores/bc-65967614-8776-4b81-8e3a-7adc35a893b6/media/godot-mvp.png"

var _frames := 0


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	get_root().add_child(packed.instantiate())


func _iteration() -> bool:
	_frames += 1
	if _frames >= 60:
		var win: Window = get_root()
		var tex := win.get_texture()
		if tex:
			var img := tex.get_image()
			if img and not img.is_empty():
				img.save_png(OUT_PATH)
				print("Screenshot saved at ", OUT_PATH)
		quit()
		return false
	return true