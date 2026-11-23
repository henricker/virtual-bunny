extends Node3D
## Low-poly spherical rabbit with ears.


func _ready() -> void:
	var body_mi := MeshInstance3D.new()
	var body := SphereMesh.new()
	body.radius = 0.45
	body.height = 0.9
	body.radial_segments = 10
	body.rings = 8
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.92, 0.9, 0.88)
	body_mi.mesh = body
	body_mi.material_override = body_mat
	add_child(body_mi)

	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.55, 0.06)
		var ear_mat := StandardMaterial3D.new()
		ear_mat.albedo_color = Color(0.88, 0.82, 0.8)
		ear.mesh = box
		ear.material_override = ear_mat
		ear.position = Vector3(0.18 * side, 0.42, 0)
		ear.rotation_degrees = Vector3(0, 0, 18 * side)
		add_child(ear)

	var eye_l := _dot_eye(Vector3(0.16, 0.12, 0.38))
	var eye_r := _dot_eye(Vector3(-0.16, 0.12, 0.38))
	add_child(eye_l)
	add_child(eye_r)


func _dot_eye(pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.1, 0.12)
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	return mi