extends Node3D
## Pinned sketch quads on the cork board — animação traço a traço.

const MAX_VISIBLE := 4
const DRAW_FRAME_SEC := 0.11
const SLOT_OFFSETS := [
	Vector3(-0.55, 1.55, 0.14),
	Vector3(-0.05, 1.55, 0.14),
	Vector3(0.45, 1.35, 0.14),
	Vector3(-0.3, 1.15, 0.14),
]

signal draw_animation_finished

var _drawing: bool = false


func _ready() -> void:
	SketchArchive.sketch_added.connect(_on_sketch_added)
	call_deferred("_refresh")


func wait_for_draw_animation() -> void:
	if not _drawing:
		return
	await draw_animation_finished


func _on_sketch_added(sketch: Dictionary) -> void:
	if _drawing:
		_refresh()
		return
	_drawing = true
	await _animate_new_sketch(sketch)
	_drawing = false
	draw_animation_finished.emit()
	_refresh()


func _animate_new_sketch(sketch: Dictionary) -> void:
	var cap := str(sketch.get("caption", ""))
	var seed := int(sketch.get("id", 0))
	var final_tex: Texture2D = sketch.get("texture")
	var all: Array = SketchArchive.get_all()
	var global_idx := all.size() - 1
	var slot_i := global_idx % MAX_VISIBLE
	if global_idx >= MAX_VISIBLE:
		slot_i = MAX_VISIBLE - 1

	var mi := _make_quad(SLOT_OFFSETS[slot_i])
	add_child(mi)

	for step in SketchGenerator.DRAW_STEPS:
		var prog := float(step + 1) / float(SketchGenerator.DRAW_STEPS)
		_set_mesh_texture(mi, SketchGenerator.make_texture_progress(cap, seed, prog))
		await get_tree().create_timer(DRAW_FRAME_SEC).timeout

	if final_tex:
		_set_mesh_texture(mi, final_tex)
	await get_tree().create_timer(0.08).timeout
	mi.queue_free()


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
		var mi := _make_quad(SLOT_OFFSETS[i % SLOT_OFFSETS.size()])
		_set_mesh_texture(mi, tex)
		add_child(mi)


func _make_quad(offset: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.38, 0.38)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.02, 1.02, 1.05)
	quad.material = mat
	mi.mesh = quad
	mi.position = offset
	return mi


func _set_mesh_texture(mi: MeshInstance3D, tex: Texture2D) -> void:
	var quad: QuadMesh = mi.mesh
	var mat: StandardMaterial3D = quad.material
	mat.albedo_texture = tex