extends Node3D
## Balão de pensamento acima do coelho (billboard 3D).

@export var bubble_height := 1.35
@export var bubble_width := 1.15

@onready var _viewport: SubViewport = $SubViewport
@onready var _label: Label = $SubViewport/Root/Margin/BubblePanel/Label
@onready var _root: Control = $SubViewport/Root
@onready var _quad: MeshInstance3D = $Quad


func _ready() -> void:
	position = Vector3(0.0, bubble_height * 0.35, 0.0)
	_quad.position = Vector3(0.0, bubble_height, 0.08)
	var mat: StandardMaterial3D = _quad.material_override
	mat.albedo_texture = _viewport.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var q: QuadMesh = _quad.mesh
	q.size = Vector2(bubble_width, bubble_width * 0.48)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(280, 0)
	set_thought("…")
	add_to_group("rabbit_thought_bubble")


func set_thought(text: String) -> void:
	var t := text.strip_edges()
	if t.is_empty():
		t = "…"
	_label.text = t
	_root.visible = t != "…" or t.length() > 1
	await get_tree().process_frame
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS