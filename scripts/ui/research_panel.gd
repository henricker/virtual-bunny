extends PanelContainer

@onready var _list: ItemList = $Margin/VBox/List
@onready var _body: RichTextLabel = $Margin/VBox/Body


func _ready() -> void:
	_list.item_selected.connect(_on_item_selected)
	ResearchLog.entry_added.connect(_on_entry_added)
	_refresh()


func _on_entry_added(_e: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	_list.clear()
	for entry: Variant in ResearchLog.get_all():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_list.add_item("%s — %s" % [entry.get("time", ""), entry.get("title", "")])
	if _list.item_count > 0:
		_list.select(_list.item_count - 1)
		_on_item_selected(_list.item_count - 1)
	else:
		_body.text = (
			"[i]Nenhuma pesquisa ainda.[/i]\n\n"
			+ "Coloque [b]BRAVE_SEARCH_API_KEY[/b] em brain.env (https://brave.com/search/api/). "
			+ "Sem chave Brave, usa trechos locais [b]wiki_snippets.json[/b]."
		)


func _on_item_selected(idx: int) -> void:
	var all: Array = ResearchLog.get_all()
	if idx < 0 or idx >= all.size():
		return
	var entry: Dictionary = all[idx]
	var url := str(entry.get("url", ""))
	var link := ("\n\n[url=%s]%s[/url]" % [url, url]) if not url.is_empty() else ""
	var serp := ""
	var results: Variant = entry.get("results", [])
	if typeof(results) == TYPE_ARRAY and results.size() > 1:
		var lines: PackedStringArray = ["\n\n[b]Resultados (navegador):[/b]"]
		for r: Variant in results:
			if typeof(r) != TYPE_DICTIONARY:
				continue
			var ru := str(r.get("url", ""))
			lines.append("• [url=%s]%s[/url] — %s" % [ru, r.get("title", ""), r.get("snippet", "")])
		serp = "\n".join(lines)
	_body.text = (
		"[b]%s[/b]\nPergunta: %s\n\n%s\n\n[i]Fonte: %s (%s)[/i]%s%s"
		% [
			entry.get("title", ""),
			entry.get("query", ""),
			entry.get("excerpt", ""),
			entry.get("source", ""),
			entry.get("time", ""),
			link,
			serp,
		]
	)