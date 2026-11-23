class_name SketchGenerator
extends RefCounted
## Folhinhas: papel branco, caneta azul, alfinete — progressivo para animação no mural.

const SIZE := Vector2i(160, 160)
const PAPER := Color(0.99, 0.99, 1.0)
const INK := Color(0.15, 0.35, 0.78, 1.0)
const PIN := Color(0.85, 0.12, 0.1, 1.0)
const DRAW_STEPS := 8

enum Motif {
	ANIMAL_TALL,
	ANIMAL_SHORT,
	GRASS,
	ROCK,
	SUN,
	RAIN,
	MONITOR,
	BRUSH,
}

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
	return make_texture_progress(caption, seed_extra, 1.0)


static func make_texture_progress(caption: String, seed_extra: int, progress: float) -> ImageTexture:
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(PAPER)
	var lower := caption.to_lower()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(caption) + seed_extra
	var layer := clampi(int(progress * float(DRAW_STEPS)), 0, DRAW_STEPS)
	if layer > 0:
		_draw_pushpin(img)
	if layer > 0:
		var motif := _resolve_motif(lower, rng)
		_render_motif_layer(img, motif, rng, layer)
	return ImageTexture.create_from_image(img)


static func _resolve_motif(lower: String, rng: RandomNumberGenerator) -> Motif:
	if _has_any(lower, ["coelho", "eu ", "quem sou", "filhote", "orelha"]):
		return Motif.ANIMAL_TALL
	if _has_any(lower, ["grama", "planta", "vento", "folha", "campo"]):
		return Motif.GRASS
	if _has_any(lower, ["pedra", "rocha", "penhasco", "ilha"]):
		return Motif.ROCK
	if _has_any(lower, ["sol", "calor", "microclima", "clima"]):
		return Motif.SUN
	if _has_any(lower, ["água", "agua", "gota", "chuva", "umidade"]):
		return Motif.RAIN
	if _has_any(lower, ["computador", "crt", "tela", "pesquisa", "navegador"]):
		return Motif.MONITOR
	if _has_any(lower, ["desenho", "rabisco", "quadro", "pincel", "lápis", "lapis"]):
		return Motif.BRUSH
	match rng.randi() % 4:
		0:
			return Motif.ANIMAL_SHORT
		1:
			return Motif.GRASS
		2:
			return Motif.SUN
		_:
			return Motif.BRUSH


static func _render_motif_layer(img: Image, motif: Motif, rng: RandomNumberGenerator, layer: int) -> void:
	match motif:
		Motif.ANIMAL_TALL:
			_doodle_animal_head(img, INK, true, layer)
		Motif.ANIMAL_SHORT:
			_doodle_animal_head(img, INK, false, layer)
		Motif.GRASS:
			_doodle_vertical_strokes(img, INK, rng, 10, layer)
		Motif.ROCK:
			_doodle_rock_oval(img, INK, layer)
		Motif.SUN:
			_doodle_sun(img, INK, layer)
		Motif.RAIN:
			_doodle_rain(img, INK, rng, layer)
		Motif.MONITOR:
			_doodle_monitor(img, INK, layer)
		Motif.BRUSH:
			_doodle_paintbrush(img, INK, layer)


static func _has_any(text: String, words: PackedStringArray) -> bool:
	for w in words:
		if w in text:
			return true
	return false


static func _draw_pushpin(img: Image) -> void:
	var c := Vector2i(SIZE.x / 2, 10)
	_fill_circle(img, c, 5, PIN)
	_fill_circle(img, c + Vector2i(0, 3), 2, Color(0.5, 0.1, 0.08))


static func _doodle_animal_head(img: Image, ink: Color, tall_ears: bool, layer: int) -> void:
	var cx := SIZE.x / 2
	var cy := SIZE.y / 2 + 8
	if layer >= 2:
		_stroke_circle(img, Vector2i(cx, cy), 28, ink, 2)
	if layer >= 3:
		var ear_h := 22 if tall_ears else 16
		_line_wide(img, Vector2i(cx - 22, cy - 18), Vector2i(cx - 28, cy - 18 - ear_h), ink, 2)
		_line_wide(img, Vector2i(cx + 22, cy - 18), Vector2i(cx + 28, cy - 18 - ear_h), ink, 2)
	if layer >= 5:
		_fill_disk(img, Vector2i(cx - 10, cy - 4), 2, ink)
		_fill_disk(img, Vector2i(cx + 10, cy - 4), 2, ink)
		_line_wide(img, Vector2i(cx, cy + 6), Vector2i(cx, cy + 10), ink, 1)
	if layer >= 7:
		_line_wide(img, Vector2i(cx - 6, cy + 8), Vector2i(cx - 22, cy + 6), ink, 1)
		_line_wide(img, Vector2i(cx + 6, cy + 8), Vector2i(cx + 22, cy + 6), ink, 1)


static func _doodle_vertical_strokes(img: Image, ink: Color, rng: RandomNumberGenerator, count: int, layer: int) -> void:
	var base_y := SIZE.y - 36
	var strokes_to_draw := clampi(layer - 1, 0, count)
	for i in strokes_to_draw:
		var x := 28 + i * (104 / maxi(count, 1))
		var h := rng.randi_range(24, 70)
		_line_wide(img, Vector2i(x, base_y), Vector2i(x + rng.randi_range(-3, 3), base_y - h), ink, 2)


static func _doodle_rock_oval(img: Image, ink: Color, layer: int) -> void:
	if layer >= 3:
		_stroke_oval(img, Vector2i(SIZE.x / 2, SIZE.y / 2 + 10), 36, 26, ink, 2)
	if layer >= 5:
		_line_wide(img, Vector2i(50, 95), Vector2i(110, 98), ink, 1)


static func _doodle_sun(img: Image, ink: Color, layer: int) -> void:
	var c := Vector2i(108, 52)
	if layer >= 2:
		_stroke_circle(img, c, 14, ink, 2)
	if layer >= 4:
		var rays := mini(8, maxi(0, layer - 3))
		for i in rays:
			var ang := float(i) / 8.0 * TAU
			var dir := Vector2i(int(cos(ang) * 22), int(sin(ang) * 22))
			_line_wide(img, c + dir / 3, c + dir, ink, 1)


static func _doodle_rain(img: Image, ink: Color, rng: RandomNumberGenerator, layer: int) -> void:
	_doodle_vertical_strokes(img, ink, rng, 12, layer)
	if layer >= 6:
		for _i in 3:
			var p := Vector2i(rng.randi_range(40, 120), rng.randi_range(50, 100))
			_teardrop(img, p, 6, ink)


static func _doodle_monitor(img: Image, ink: Color, layer: int) -> void:
	var tl := Vector2i(44, 56)
	var br := Vector2i(116, 108)
	if layer >= 2:
		_stroke_rect(img, tl, br, ink, 2)
	if layer >= 4:
		_line_wide(img, Vector2i(72, 108), Vector2i(88, 122), ink, 2)
		_line_wide(img, Vector2i(60, 122), Vector2i(100, 122), ink, 2)
	if layer >= 6:
		var cols := mini(4, maxi(0, layer - 5))
		for i in cols:
			_line_wide(img, Vector2i(52 + i * 14, 68), Vector2i(52 + i * 14, 98), ink, 1)


static func _doodle_paintbrush(img: Image, ink: Color, layer: int) -> void:
	if layer >= 2:
		_stroke_rect(img, Vector2i(52, 48), Vector2i(72, 100), ink, 2)
	if layer >= 4:
		_stroke_rect(img, Vector2i(72, 88), Vector2i(100, 108), ink, 2)
	if layer >= 6:
		var bristles := mini(5, maxi(0, layer - 5))
		for i in bristles:
			_line_wide(img, Vector2i(76 + i * 4, 92), Vector2i(76 + i * 4, 104), ink, 1)


static func _teardrop(img: Image, tip: Vector2i, h: int, col: Color) -> void:
	_line_wide(img, tip, tip + Vector2i(0, h), col, 2)
	_fill_disk(img, tip + Vector2i(0, h), 3, col)


static func _stroke_circle(img: Image, center: Vector2i, radius: int, col: Color, width: int) -> void:
	for a in 64:
		var ang0 := float(a) / 64.0 * TAU
		var ang1 := float(a + 1) / 64.0 * TAU
		var p0 := center + Vector2i(int(cos(ang0) * radius), int(sin(ang0) * radius))
		var p1 := center + Vector2i(int(cos(ang1) * radius), int(sin(ang1) * radius))
		_line_wide(img, p0, p1, col, width)


static func _stroke_oval(img: Image, center: Vector2i, rx: int, ry: int, col: Color, width: int) -> void:
	for a in 48:
		var ang0 := float(a) / 48.0 * TAU
		var ang1 := float(a + 1) / 48.0 * TAU
		var p0 := center + Vector2i(int(cos(ang0) * rx), int(sin(ang0) * ry))
		var p1 := center + Vector2i(int(cos(ang1) * rx), int(sin(ang1) * ry))
		_line_wide(img, p0, p1, col, width)


static func _stroke_rect(img: Image, tl: Vector2i, br: Vector2i, col: Color, width: int) -> void:
	_line_wide(img, tl, Vector2i(br.x, tl.y), col, width)
	_line_wide(img, Vector2i(br.x, tl.y), br, col, width)
	_line_wide(img, br, Vector2i(tl.x, br.y), col, width)
	_line_wide(img, Vector2i(tl.x, br.y), tl, col, width)


static func _line_wide(img: Image, a: Vector2i, b: Vector2i, col: Color, half_w: int) -> void:
	var dir := b - a
	var len := maxi(1, dir.length())
	var step := Vector2(dir) / float(len)
	var p := Vector2(a)
	for _i in len + 1:
		for dx in range(-half_w, half_w + 1):
			for dy in range(-half_w, half_w + 1):
				if absi(dx) + absi(dy) > half_w + 1:
					continue
				var px := int(p.x) + dx
				var py := int(p.y) + dy
				if px >= 0 and px < SIZE.x and py >= 0 and py < SIZE.y:
					img.set_pixel(px, py, col)
		p += step


static func _fill_disk(img: Image, center: Vector2i, r: int, col: Color) -> void:
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			if (Vector2i(x, y) - center).length_squared() <= r * r:
				if x >= 0 and x < SIZE.x and y >= 0 and y < SIZE.y:
					img.set_pixel(x, y, col)


static func _fill_circle(img: Image, center: Vector2i, radius: int, col: Color) -> void:
	_fill_disk(img, center, radius, col)