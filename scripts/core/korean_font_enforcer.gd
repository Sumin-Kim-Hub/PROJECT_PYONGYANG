extends Node

const FONT_PATH := "res://assets/fonts/NanumGothic.ttf"
var _kr_font: Font = null

func _init() -> void:
	_kr_font = get_korean_font()

static func get_korean_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		var res = load(FONT_PATH)
		if res is Font and res.has_char(0xD55C):
			return res
	if FileAccess.file_exists(FONT_PATH):
		var ff := FontFile.new()
		var err := ff.load_dynamic_font(FONT_PATH)
		if err == OK and ff.has_char(0xD55C):
			return ff
		push_error("[KoreanFont] load_dynamic_font failed: %s" % err)
	else:
		push_error("[KoreanFont] Font file missing: %s" % FONT_PATH)
	return ThemeDB.fallback_font

func _ready() -> void:
	if _kr_font == null:
		_kr_font = get_korean_font()
	print("[KoreanFont] Active font=", _kr_font, " has_hangul=", _kr_font.has_char(0xD55C))
	get_tree().node_added.connect(_on_node_added)
	_apply_recursive(get_tree().root)

func _apply_recursive(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_apply_recursive(child)

func _on_node_added(node: Node) -> void:
	if _kr_font == null:
		return
	if node is RichTextLabel:
		for k in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
			node.add_theme_font_override(k, _kr_font)
	elif node is Control:
		node.add_theme_font_override("font", _kr_font)
	elif node is Window:
		var t := Theme.new()
		t.default_font = _kr_font
		node.theme = t
