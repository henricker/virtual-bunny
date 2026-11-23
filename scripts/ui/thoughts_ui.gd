extends PanelContainer
class_name ThoughtsUI
## Rabbit thought captions (in-game PT-BR strings).

@onready var _label: Label = $Margin/Label


func _ready() -> void:
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.text = "…"
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_bottom = -12
	offset_top = -120
	offset_left = 24
	offset_right = -24


func show_thought(text: String) -> void:
	_label.text = text