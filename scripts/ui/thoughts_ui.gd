extends PanelContainer
class_name ThoughtsUI
## Encaminha pensamentos para o balão 3D acima do coelho.

@export var bubble_path: NodePath = NodePath("../../Rabbit/ThoughtBubble")

var _bubble: Node = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bubble_path.is_empty() and has_node(bubble_path):
		_bubble = get_node(bubble_path)
	elif get_tree().has_group("rabbit_thought_bubble"):
		var nodes := get_tree().get_nodes_in_group("rabbit_thought_bubble")
		if not nodes.is_empty():
			_bubble = nodes[0]


func show_thought(text: String) -> void:
	if _bubble != null and _bubble.has_method("set_thought"):
		_bubble.set_thought(text)
		return
	push_warning("[ThoughtsUI] ThoughtBubble não encontrado")