extends PanelContainer

@onready var _list: ItemList = $Margin/VBox/SketchList
@onready var _preview: TextureRect = $Margin/VBox/Preview
@onready var _caption: Label = $Margin/VBox/Caption


func _ready() -> void:
	_list.item_selected.connect(_on_item_selected)
	SketchArchive.sketch_added.connect(_on_sketch_added)
	_refresh()


func _on_sketch_added(_s: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	_list.clear()
	for sketch: Variant in SketchArchive.get_all():
		if typeof(sketch) != TYPE_DICTIONARY:
			continue
		var cap: String = str(sketch.get("caption", "Sem título"))
		_list.add_item("#%d — %s" % [sketch.get("id", 0), cap])
	if _list.item_count > 0:
		_list.select(_list.item_count - 1)
		_on_item_selected(_list.item_count - 1)
	else:
		_caption.text = "Nenhum desenho ainda. Espere o ritual (PC + quadro)."


func _on_item_selected(idx: int) -> void:
	var all: Array = SketchArchive.get_all()
	if idx < 0 or idx >= all.size():
		return
	var sketch: Dictionary = all[idx]
	_preview.texture = sketch.get("texture")
	_caption.text = str(sketch.get("caption", ""))