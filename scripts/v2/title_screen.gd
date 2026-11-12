extends Control
## V2 시작 화면: 새 게임 / 이어하기. 저장이 있으면 '이어하기'와 '새 게임'(한 번 더 눌러 확인), 없으면 '시작'만 나옵니다.
## 기존 HUD 와 같은 방식으로 직접 그리고 터치를 처리합니다 (Button 노드를 쓰지 않음).
## 선택하면 chosen 신호를 한 번 보냅니다: "continue" / "new" / "start".

signal chosen(id: String)

var has_save: bool = false

var _font: Font = null
var _hits: Array = []
var _t: float = 0.0
var _confirm: float = 0.0
var _done: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	if ClassDB.class_exists(\"Node\"):
		var _kfe = load(\"res://scripts/core/korean_font_enforcer.gd\")
		if _kfe:
			_font = _kfe.get_korean_font()
	var path: String = "res://assets/fonts/NanumGothic.ttf"
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font:
			_font = f


func _process(delta: float) -> void:
	_t += delta
	if _confirm > 0.0:
		_confirm -= delta
	queue_redraw()


func _layout() -> void:
	_hits.clear()
	var s: Vector2 = get_viewport_rect().size
	var w: float = minf(s.x - 80.0, 520.0)
	var x: float = (s.x - w) * 0.5
	var y: float = s.y * 0.5 - 20.0
	if has_save:
		_hits.append({"rect": Rect2(x, y, w, 72.0), "id": "continue"})
		_hits.append({"rect": Rect2(x, y + 92.0, w, 72.0), "id": "new"})
	else:
		_hits.append({"rect": Rect2(x, y, w, 72.0), "id": "start"})


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch:
		var t = event as InputEventScreenTouch
		if t.pressed:
			_layout()
			for h in _hits:
				var r: Rect2 = h["rect"]
				if r.has_point(t.position):
					_pick(str(h["id"]))
					break
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var k = event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE):
			_pick("continue" if has_save else "start")
			get_viewport().set_input_as_handled()


func _pick(id: String) -> void:
	if id == "new" and has_save:
		# 기존 저장이 지워지므로 4초 안에 한 번 더 눌러야 함
		if _confirm <= 0.0:
			_confirm = 4.0
			return
	_done = true
	chosen.emit(id)


func _draw() -> void:
	var font: Font = _font
	if font == null:
		return
	var s: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.04, 0.07, 0.86), true)
	var pulse: float = 0.75 + 0.25 * sin(_t * 1.6)
	draw_string(font, Vector2(0.0, s.y * 0.5 - 150.0), "PROJECT PYONGYANG", HORIZONTAL_ALIGNMENT_CENTER, s.x, 52, Color(1.0, 0.92, 0.7, pulse))
	draw_string(font, Vector2(0.0, s.y * 0.5 - 100.0), "가상의 도시에서 펼쳐지는 탐험과 잠입 이야기", HORIZONTAL_ALIGNMENT_CENTER, s.x, 22, Color(1, 1, 1, 0.8))
	_layout()
	for h in _hits:
		var r: Rect2 = h["rect"]
		var id: String = str(h["id"])
		var label: String = "게임 시작"
		var bg = Color(0.20, 0.36, 0.58, 0.85)
		if id == "continue":
			label = "이어하기"
		elif id == "new":
			label = "새 게임"
			bg = Color(0.30, 0.26, 0.30, 0.85)
			if _confirm > 0.0:
				label = "저장이 지워집니다. 한 번 더 누르면 새로 시작"
				bg = Color(0.55, 0.2, 0.2, 0.9)
		draw_rect(r, bg, true)
		draw_rect(r, Color(0.8, 0.9, 1.0, 0.85), false, 2.0)
		draw_string(font, r.position + Vector2(0.0, 46.0), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26 if label.length() < 12 else 20, Color(1, 1, 1, 0.97))
	draw_string(font, Vector2(0.0, s.y - 48.0), "이 게임의 도시, 인물, 사건, 조직은 모두 가상이며 실제와 관계가 없습니다.", HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(1, 1, 1, 0.55))
