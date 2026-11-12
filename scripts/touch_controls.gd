extends Control
## 모바일 터치 조작 UI. 버튼 노드를 쓰지 않고 터치 이벤트를 직접 처리합니다.
##  - 화면 왼쪽 42%: 누른 자리에 가상 조이스틱이 생김 (이동)
##  - 화면 오른쪽 빈 곳: 드래그하면 카메라 회전
##  - JUMP 버튼: 점프 / RUN 버튼: 달리기 켜기·끄기
## PC 테스트: WASD 이동, Shift 달리기, Space 점프, 방향키 카메라
## (PC에서는 마우스가 터치로 변환되므로 마우스로도 조이스틱을 끌 수 있습니다.)

const Cfg = preload("res://scripts/game_config.gd")

const JOY_RADIUS: float = 90.0
const BTN_RADIUS: float = 58.0
const LEFT_ZONE_RATIO: float = 0.42
const DEAD_ZONE: float = 0.12

## 조이스틱 값. 길이 0~1, 위로 밀면 y가 음수(앞으로)
var move_vector: Vector2 = Vector2.ZERO
var run_toggled: bool = false
## 좌상단에 표시할 추가 문구 (player.gd 가 좌표를 넣어 줍니다)
var debug_text: String = ""

var _joy_touch: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_pos: Vector2 = Vector2.ZERO
var _look_touch: int = -1
var _look_accum: Vector2 = Vector2.ZERO
var _jump_touch: int = -1
var _run_touch: int = -1
var _jump_queued: bool = false
var _space_prev: bool = false
var _age: float = 0.0


func _ready() -> void:
	# 이 노드가 마우스 입력을 가로채지 않도록 함 (입력은 _input에서 직접 처리)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_age += delta
	var space: bool = Input.is_physical_key_pressed(KEY_SPACE)
	if space and not _space_prev:
		_jump_queued = true
	_space_prev = space
	queue_redraw()


# ---------------------------------------------------------------- 다른 스크립트가 읽는 값

func get_move_vector() -> Vector2:
	var kb := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		kb.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		kb.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		kb.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		kb.x += 1.0
	if kb != Vector2.ZERO:
		return kb.normalized()
	return move_vector


func is_running() -> bool:
	return run_toggled or Input.is_physical_key_pressed(KEY_SHIFT)


func consume_jump() -> bool:
	var j: bool = _jump_queued
	_jump_queued = false
	return j


func consume_look() -> Vector2:
	var v: Vector2 = _look_accum
	_look_accum = Vector2.ZERO
	return v


# ---------------------------------------------------------------- 터치 처리

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_drag(d.index, d.position, d.relative)


func _jump_center() -> Vector2:
	var s: Vector2 = get_viewport_rect().size
	return Vector2(s.x - 130.0, s.y - 150.0)


func _run_center() -> Vector2:
	var s: Vector2 = get_viewport_rect().size
	return Vector2(s.x - 290.0, s.y - 90.0)


func _touch_down(index: int, pos: Vector2) -> void:
	if _jump_touch == -1 and pos.distance_to(_jump_center()) <= BTN_RADIUS * 1.2:
		_jump_touch = index
		_jump_queued = true
		return
	if _run_touch == -1 and pos.distance_to(_run_center()) <= BTN_RADIUS * 1.2:
		_run_touch = index
		run_toggled = not run_toggled
		return

	var s: Vector2 = get_viewport_rect().size
	if pos.x < s.x * LEFT_ZONE_RATIO:
		if _joy_touch == -1:
			_joy_touch = index
			_joy_center = pos
			_joy_pos = pos
			move_vector = Vector2.ZERO
	else:
		if _look_touch == -1:
			_look_touch = index


func _touch_up(index: int) -> void:
	if index == _joy_touch:
		_joy_touch = -1
		move_vector = Vector2.ZERO
	elif index == _look_touch:
		_look_touch = -1
	elif index == _jump_touch:
		_jump_touch = -1
	elif index == _run_touch:
		_run_touch = -1


func _touch_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _joy_touch:
		var offset: Vector2 = pos - _joy_center
		if offset.length() > JOY_RADIUS:
			offset = offset.normalized() * JOY_RADIUS
		_joy_pos = _joy_center + offset
		var v: Vector2 = offset / JOY_RADIUS
		if v.length() < DEAD_ZONE:
			v = Vector2.ZERO
		move_vector = v
	elif index == _look_touch:
		_look_accum += relative


# ---------------------------------------------------------------- 그리기

func _draw() -> void:
	var s: Vector2 = get_viewport_rect().size

	# 조이스틱
	if _joy_touch != -1:
		draw_circle(_joy_center, JOY_RADIUS, Color(1, 1, 1, 0.10))
		draw_arc(_joy_center, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
		draw_circle(_joy_pos, 34.0, Color(1, 1, 1, 0.45))
	else:
		var idle_center := Vector2(s.x * 0.14, s.y * 0.74)
		draw_arc(idle_center, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 3.0, true)
		draw_circle(idle_center, 30.0, Color(1, 1, 1, 0.14))

	_draw_button(_jump_center(), "JUMP", _jump_touch != -1, Color(1.0, 1.0, 1.0))
	_draw_button(_run_center(), "RUN", run_toggled, Color(0.55, 1.0, 0.6))

	var font: Font = ThemeDB.fallback_font

	if Cfg.SHOW_DEBUG:
		var txt: String = "FPS %d   %s" % [Engine.get_frames_per_second(), debug_text]
		draw_string(font, Vector2(17.0, 31.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(16.0, 30.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(1, 1, 1, 0.9))

	# 처음 12초 동안만 조작 안내
	if _age < 12.0:
		var alpha: float = clampf((12.0 - _age) / 3.0, 0.0, 1.0)
		var hint: String = "LEFT: move   RIGHT: look   PC: WASD / Arrows / Space / Shift"
		draw_string(font, Vector2(1.0, 71.0), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(0, 0, 0, 0.6 * alpha))
		draw_string(font, Vector2(0.0, 70.0), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(1, 1, 1, 0.85 * alpha))


func _draw_button(center: Vector2, label: String, active: bool, tint: Color) -> void:
	var fill_alpha: float = 0.38 if active else 0.14
	draw_circle(center, BTN_RADIUS, Color(tint.r, tint.g, tint.b, fill_alpha))
	draw_arc(center, BTN_RADIUS, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.6), 3.0, true)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 22
	var text_pos := center + Vector2(-BTN_RADIUS, font_size * 0.35)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, BTN_RADIUS * 2.0, font_size, Color(1, 1, 1, 0.9))
