class_name SketchGenerator
extends RefCounted

const SIZE := Vector2i(128, 128)


static func caption_from_graph(nodes: Array) -> String:
	if nodes.is_empty():
		return "A ilha vista de cima"
	var labels: PackedStringArray = []
	for n: Variant in nodes:
		if typeof(n) == TYPE_DICTIONARY:
			labels.append(str(n.get("label", "")))
	var pick := labels.slice(0, mini(3, labels.size()))
	if pick.is_empty():
		return "Rabisco do momento"
	return " / ".join(pick)


static func make_texture(caption: String, seed_extra: int = 0) -> ImageTexture:
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.96, 0.93, 0.86))
	var lower := caption.to_lower()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(caption) + seed_extra

	var ink := Color(0.12, 0.1, 0.15)
	_draw_scribble(img, ink, rng)

	if "sol" in lower or "calor" in lower:
		_fill_circle(img, Vector2i(88, 32), 12, Color(0.9, 0.75, 0.2))
	if "pedra" in lower or "rocha" in lower:
		_fill_circle(img, Vector2i(42, 78), 16, Color(0.55, 0.52, 0.5))
	if "grama" in lower or "planta" in lower:
		for i in 6:
			var x := 20 + i * 14
			_line(img, Vector2i(x, 110), Vector2i(x - 4, 70), Color(0.2, 0.55, 0.25))
	if "gota" in lower or "água" in lower:
		for i in 4:
			_fill_circle(img, Vector2i(30 + i * 18, 55 + i * 6), 3, Color(0.3, 0.5, 0.85))

	return ImageTexture.create_from_image(img)


static func _draw_scribble(img: Image, ink: Color, rng: RandomNumberGenerator) -> void:
	for _i in 8 + rng.randi() % 6:
		var a := Vector2i(rng.randi_range(16, 112), rng.randi_range(24, 112))
		var b := Vector2i(rng.randi_range(16, 112), rng.randi_range(24, 112))
		_line(img, a, b, ink)


static func _line(img: Image, a: Vector2i, b: Vector2i, col: Color) -> void:
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx - dy
	var x := a.x
	var y := a.y
	while true:
		if x >= 0 and x < SIZE.x and y >= 0 and y < SIZE.y:
			img.set_pixel(x, y, col)
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy


static func _fill_circle(img: Image, center: Vector2i, radius: int, col: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if (Vector2i(x, y) - center).length_squared() <= radius * radius:
				if x >= 0 and x < SIZE.x and y >= 0 and y < SIZE.y:
					img.set_pixel(x, y, col)