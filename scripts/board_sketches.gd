extends Node3D
## Pinned sketch quads on the cork board (3D).

const MAX_VISIBLE := 4
const SLOT_OFFSETS := [
	Vector3(-0.55, 1.55, 0.14),
	Vector3(-0.05, 1.55, 0.14),
	Vector3(0.45, 1.35, 0.14),
	Vector3(-0.3, 1.15, 0.14),
]


func _ready() -> void:
	SketchArchive.sketch_added.connect(_on_sketch_added)


func _on_sketch_added(_sketch: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	for c in get_children():
		c.queue_free()
	var all: Array = SketchArchive.get_all()
	var start := maxi(0, all.size() - MAX_VISIBLE)
	for i in range(all.size() - start):
		var sketch: Dictionary = all[start + i]
		var tex: Texture2D = sketch.get("texture")
		if tex == null:
			continue
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.42, 0.42)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = mat
		mi.mesh = quad
		mi.position = SLOT_OFFSETS[i % SLOT_OFFSETS.size()]
		add_child(mi)