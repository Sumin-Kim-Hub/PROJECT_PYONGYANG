extends Control
## 상호작용 UI. 아래 세 가지를 직접 그리고 터치를 처리합니다.
##  1) 가까이 갔을 때: 안내 문구 + 오른쪽의 상호작용 버튼 (JUMP 버튼 위)
##  2) 대화창: 이름, 대사, 선택지 (선택지를 누르거나, 선택지가 없으면 대화창을 탭)
##  3) 화면 암전(건물 출입 시)
## 이 노드는 터치 조작 UI(touch_controls.gd)보다 나중에 만들어져 터치를 먼저 받습니다.
## 이 UI 위에서 시작된 터치는 여기서 소비하여 조이스틱/카메라가 반응하지 않게 합니다.

signal interact_pressed
signal choice_selected(index: int)
signal advance_pressed
signal close_pressed

const BTN_RADIUS: float = 58.0
const FONT_PATH: String = "res://assets/fonts/ui_ko.otf"

var fade_alpha: float = 0.0:
	set(value):
		fade_alpha = value
		queue_redraw()

## 좌상단 검수용 문구 (interaction_system.gd 가 채움)
var debug_line: String = ""

var _prompt_visible: bool = false
var _prompt_text: String = ""
var _button_label: String = ""

var _dialogue_open: bool = false
var _dlg_name: String = ""
var _dlg_role: String = ""
var _dlg_text: String = ""
var _dlg_choices: Array = []
var _text_lines: int = 4

var _owned: Dictionary = {}
var _rect_panel: Rect2 = Rect2()
var _rect_close: Rect2 = Rect2()
var _rects_choices: Array = []
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	# 한글이 네모로 나올 경우를 대비한 선택 사항: 이 경로에 한글 글꼴을 넣으면 자동 사용
	if ResourceLoader.exists(FONT_PATH):
		var f = load(FONT_PATH)
		if f is Font:
			_font = f


func _process(_delta: float) -> void:
	if debug_line != "":
		queue_redraw()


# ---------------------------------------------------------------- 바깥에서 부르는 함수

func set_prompt(text: String, button_label: String) -> void:
	if _prompt_visible and text == _prompt_text and button_label == _button_label:
		return
	_prompt_visible = true
	_prompt_text = text
	_button_label = button_label
	queue_redraw()


func clear_prompt() -> void:
	if not _prompt_visible:
		return
	_prompt_visible = false
	queue_redraw()


func open_dialogue(npc_name: String, role: String, text: String, choices: Array) -> void:
	_dialogue_open = true
	_dlg_name = npc_name
	_dlg_role = role
	_dlg_text = text
	_dlg_choices = choices
	_prompt_visible = false
	queue_redraw()


func close_dialogue() -> void:
	_dialogue_open = false
	_dlg_choices = []
	queue_redraw()


func is_dialogue_open() -> bool:
	return _dialogue_open


func fade_to(target: float, duration: float) -> void:
	var tw = create_tween()
	tw.tween_property(self, "fade_alpha", target, duration)
	await tw.finished


# ---------------------------------------------------------------- 터치 처리

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t = event as InputEventScreenTouch
		if t.pressed:
			if _handle_down(t.position):
				_owned[t.index] = true
				get_viewport().set_input_as_handled()
		elif _owned.has(t.index):
			_owned.erase(t.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d = event as InputEventScreenDrag
		if _owned.has(d.index):
			get_viewport().set_input_as_handled()


func _button_center() -> Vector2:
	var s: Vector2 = get_viewport_rect().size
	return Vector2(s.x - 130.0, s.y - 310.0)


## 이 UI가 터치를 가져가면 true
func _handle_down(pos: Vector2) -> bool:
	if fade_alpha > 0.01:
		return true
	if _dialogue_open:
		_compute_layout()
		if _rect_close.has_point(pos):
			close_pressed.emit()
			return true
		for i in range(_rects_choices.size()):
			if _rects_choices[i].has_point(pos):
				choice_selected.emit(i)
				return true
		if _dlg_choices.is_empty() and _rect_panel.has_point(pos):
			advance_pressed.emit()
		return true
	if _prompt_visible:
		if pos.distance_to(_button_center()) <= BTN_RADIUS * 1.2:
			interact_pressed.emit()
			return true
	return false


# ---------------------------------------------------------------- 그리기

func _compute_layout() -> void:
	var s: Vector2 = get_viewport_rect().size
	var pw: float = minf(s.x - 60.0, 1040.0)
	var n: int = _dlg_choices.size()
	# V2.2: 글이 길면 최대 9줄까지 칸을 늘림 (기본 4줄)
	_text_lines = 4
	if _font != null and _dlg_text.length() > 60:
		var tsz: Vector2 = _font.get_multiline_string_size(_dlg_text, HORIZONTAL_ALIGNMENT_LEFT, pw - 48.0, 26)
		_text_lines = clampi(int(ceil(tsz.y / maxf(_font.get_height(26), 1.0))), 4, 9)
	var ph: float = 56.0 + 124.0 + float(_text_lines - 4) * 31.0 + (82.0 if n > 0 else 44.0)
	var px: float = (s.x - pw) * 0.5
	var py: float = s.y - ph - 20.0
	_rect_panel = Rect2(px, py, pw, ph)
	_rect_close = Rect2(px + pw - 60.0, py + 8.0, 52.0, 42.0)
	_rects_choices.clear()
	if n > 0:
		var gap: float = 12.0
		var bw: float = (pw - 40.0 - gap * float(n - 1)) / float(n)
		for i in range(n):
			_rects_choices.append(Rect2(px + 20.0 + (bw + gap) * float(i), py + ph - 74.0, bw, 58.0))


func _draw() -> void:
	var s: Vector2 = get_viewport_rect().size
	var font: Font = _font
	if font == null:
		return

	if debug_line != "":
		draw_string(font, Vector2(17.0, 61.0), debug_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(16.0, 60.0), debug_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.8, 1.0, 0.8, 0.9))

	if _dialogue_open:
		_compute_layout()
		_draw_dialogue(font)
	elif _prompt_visible:
		_draw_prompt(font, s)

	if fade_alpha > 0.001:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.0, clampf(fade_alpha, 0.0, 1.0)), true)


func _draw_prompt(font: Font, s: Vector2) -> void:
	var tint = Color(1.0, 0.85, 0.4)
	var center: Vector2 = _button_center()
	draw_circle(center, BTN_RADIUS, Color(tint.r, tint.g, tint.b, 0.32))
	draw_arc(center, BTN_RADIUS, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.85), 3.0, true)
	draw_string(font, center + Vector2(-BTN_RADIUS, 9.0), _button_label, HORIZONTAL_ALIGNMENT_CENTER, BTN_RADIUS * 2.0, 26, Color(1, 1, 1, 0.95))

	var tw: float = font.get_string_size(_prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24).x
	var pill = Rect2((s.x - tw - 44.0) * 0.5, s.y - 96.0, tw + 44.0, 50.0)
	draw_rect(pill, Color(0, 0, 0, 0.58), true)
	draw_rect(pill, Color(1, 0.85, 0.4, 0.8), false, 2.0)
	draw_string(font, Vector2(pill.position.x + 22.0, pill.position.y + 34.0), _prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(1, 1, 1, 0.95))


func _draw_dialogue(font: Font) -> void:
	var r: Rect2 = _rect_panel
	draw_rect(r, Color(0.04, 0.05, 0.07, 0.84), true)
	draw_rect(r, Color(1, 1, 1, 0.35), false, 2.0)

	draw_string(font, r.position + Vector2(24.0, 40.0), _dlg_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(1.0, 0.86, 0.45))
	var name_w: float = font.get_string_size(_dlg_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x
	draw_string(font, r.position + Vector2(24.0 + name_w + 14.0, 40.0), _dlg_role, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(0.75, 0.78, 0.82))

	draw_rect(_rect_close, Color(1, 1, 1, 0.14), true)
	draw_string(font, _rect_close.position + Vector2(0.0, 30.0), "X", HORIZONTAL_ALIGNMENT_CENTER, _rect_close.size.x, 24, Color(1, 1, 1, 0.9))

	draw_multiline_string(font, r.position + Vector2(24.0, 86.0), _dlg_text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 48.0, 26, _text_lines, Color(1, 1, 1, 0.95))

	if _dlg_choices.is_empty():
		draw_string(font, Vector2(r.position.x, r.position.y + r.size.y - 14.0), "화면을 탭하면 계속", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24.0, 18, Color(1, 1, 1, 0.6))
	else:
		for i in range(_rects_choices.size()):
			var cr: Rect2 = _rects_choices[i]
			draw_rect(cr, Color(0.20, 0.36, 0.58, 0.65), true)
			draw_rect(cr, Color(0.7, 0.85, 1.0, 0.8), false, 2.0)
			draw_string(font, Vector2(cr.position.x + 6.0, cr.position.y + cr.size.y * 0.5 + 8.0), str(_dlg_choices[i]), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x - 12.0, 22, Color(1, 1, 1, 0.97))
