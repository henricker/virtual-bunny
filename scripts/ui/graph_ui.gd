extends Control
class_name GraphUI
## Simple graph (circles + lines) in the @or1cinho style.

var nodes: Array = []:
	set(v):
		nodes = v
		queue_redraw()

var edges: Array = []:
	set(v):
		edges = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0


func set_graph(graph_nodes: Array, graph_edges: Array) -> void:
	nodes = graph_nodes
	edges = graph_edges


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.35
	var count := maxi(nodes.size(), 1)
	var placed: Dictionary = {}

	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var id: String = str(n.get("id", "n%d" % i))
		var angle := (TAU * i) / count - PI / 2
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		placed[id] = pos
		draw_circle(pos, 10.0, Color(1, 1, 1, 0.9))
		var label: String = str(n.get("label", id))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-20, -16), label, HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(1, 1, 1, 0.85))

	for e in edges:
		var from_id := str(e.get("from", ""))
		var to_id := str(e.get("to", ""))
		if not placed.has(from_id) or not placed.has(to_id):
			continue
		draw_line(placed[from_id], placed[to_id], Color(1, 1, 1, 0.5), 2.0)

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.08, 0.55), false, 2.0)