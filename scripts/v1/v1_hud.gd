extends Control
## V1 화면 덧그리기: 미니맵, 도시 경계 표시, 운전 계기판/시점 버튼, '위협' 버튼.
## 기존 hud_ui.gd 위에 따로 겹쳐서 그려지며, 이 파일에 문제가 있어도 기본 HUD 는 그대로 동작합니다.
## 터치는 이 노드가 버튼 위에서만 가져가고 나머지는 아래 UI/조이스틱으로 넘깁니다.

const Settings = preload("res://scripts/v1/game_settings.gd")

const MAP_SIZE: float = 150.0
const MAP_RANGE: float = 70.0

var hub = null
var v1 = null
var show_minimap: bool = true

var _font: Font = null
var _acc: float = 0.0
var _cand = null
var _cand_t: float = 0.0
var _owned: Dictionary = {}
var _t_prev: bool = false
var _v_prev: bool = false


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
	show_minimap = Settings.minimap(true)


func _driving() -> bool:
	return hub != null and hub.mode == 5


func _process(delta: float) -> void:
	if hub == null:
		return
	_acc += delta
	var interval: float = 0.05 if _driving() else 0.12
	if _acc >= interval:
		_acc = 0.0
		queue_redraw()
	_cand_t -= delta
	if _cand_t <= 0.0:
		_cand_t = 0.2
		_find_candidate()
	# PC 테스트용 키: V = 시점, T = 위협
	var v_now: bool = Input.is_physical_key_pressed(KEY_V)
	if v_now and not _v_prev and _driving() and v1 != null and v1.drive != null:
		v1.drive.toggle_view()
	_v_prev = v_now
	var t_now: bool = Input.is_physical_key_pressed(KEY_T)
	if t_now and not _t_prev:
		_do_threaten()
	_t_prev = t_now


func _find_candidate() -> void:
	_cand = null
	if hub == null or hub.mode != 0 or hub.player == null or v1 == null or v1.alert == null:
		return
	var pp: Vector3 = hub.player.global_position
	var best: float = 3.2
	for n in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(n) or not n.visible or n.riding != null:
			continue
		var d: float = Vector2(n.global_position.x - pp.x, n.global_position.z - pp.z).length()
		if d < best and absf(n.global_position.y - pp.y) < 2.0:
			best = d
			_cand = n


func _do_threaten() -> void:
	if _cand != null and is_instance_valid(_cand) and hub != null and hub.mode == 0 and v1 != null and v1.alert != null:
		v1.alert.threaten(_cand)
		_cand = null


# ---------------------------------------------------------------- 터치

func _view_center() -> Vector2:
	var s: Vector2 = get_viewport_rect().size
	return Vector2(s.x - 300.0, s.y - 260.0)


func _input(event: InputEvent) -> void:
	if hub == null:
		return
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


func _handle_down(pos: Vector2) -> bool:
	if hub.hud != null and hub.hud.panel_open():
		return false
	var c: Vector2 = _view_center()
	if pos.distance_to(c) > 52.0:
		return false
	if _driving():
		if v1 != null and v1.drive != null:
			v1.drive.toggle_view()
		return true
	if hub.mode == 0 and _cand != null:
		_do_threaten()
		return true
	return false


# ---------------------------------------------------------------- 그리기

func _draw() -> void:
	if hub == null or _font == null:
		return
	var s: Vector2 = get_viewport_rect().size
	var panel_open: bool = hub.hud != null and hub.hud.panel_open()
	if panel_open:
		return
	if hub.mode == 1 or hub.mode == 3:
		return
	if show_minimap:
		_draw_minimap()
	_draw_alert()
	if _driving():
		_draw_drive(s)
	elif hub.mode == 0 and _cand != null and is_instance_valid(_cand):
		_button(_view_center(), 44.0, "위협", Color(1.0, 0.5, 0.45))


func _w2m(p: Vector3, center_world: Vector3, c: Vector2) -> Vector2:
	var k: float = (MAP_SIZE * 0.5) / MAP_RANGE
	return c + Vector2(p.x - center_world.x, p.z - center_world.z) * k


func _draw_minimap() -> void:
	var font: Font = _font
	var r = Rect2(16.0, 76.0, MAP_SIZE, MAP_SIZE)
	var c: Vector2 = r.position + r.size * 0.5
	draw_rect(r, Color(0.0, 0.0, 0.0, 0.5), true)
	var pp: Vector3 = hub.player.global_position
	if pp.y > 100.0:
		draw_rect(r, Color(0.3, 0.35, 0.4, 0.5), true)
		draw_string(font, r.position + Vector2(0.0, 80.0), "실내", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color(1, 1, 1, 0.85))
		draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
		return
	# 바닥 (잔디) -> 도로 -> 광장
	draw_rect(r, Color(0.28, 0.38, 0.26, 0.9), true)
	_map_rect(r, pp, c, -300.0, -8.0, 300.0, 8.0, Color(0.22, 0.22, 0.25))
	_map_rect(r, pp, c, -8.0, -50.0, 8.0, 260.0, Color(0.22, 0.22, 0.25))
	_map_rect(r, pp, c, -50.0, -50.0, 50.0, 50.0, Color(0.7, 0.7, 0.68))
	# 랜드마크
	if v1 != null and v1.landmarks != null:
		for mk in v1.landmarks.markers:
			var q: Vector2 = _w2m(mk["pos"], pp, c)
			if r.has_point(q):
				draw_rect(Rect2(q - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(1.0, 0.8, 0.3), true)
	# 차량
	for car in get_tree().get_nodes_in_group("drivables"):
		if is_instance_valid(car):
			var qc: Vector2 = _w2m(car.global_position, pp, c)
			if r.has_point(qc):
				draw_rect(Rect2(qc - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.5, 0.75, 1.0), true)
	# 시민 / 경찰
	for n in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(n) or not n.visible:
			continue
		if n.global_position.y > 100.0:
			continue
		var qn: Vector2 = _w2m(n.global_position, pp, c)
		if r.has_point(qn):
			var col: Color = Color(1, 1, 1, 0.75)
			if n.is_police:
				col = Color(1.0, 0.3, 0.3) if n.react == "chase" else Color(0.45, 0.6, 1.0)
			elif n.react == "flee":
				col = Color(1.0, 0.85, 0.3)
			draw_circle(qn, 2.0, col)
	# 임무 목표
	if v1 != null:
		for qm in v1.quest_marks:
			var qq: Vector2 = _w2m(qm, pp, c)
			qq.x = clampf(qq.x, r.position.x + 5.0, r.position.x + r.size.x - 5.0)
			qq.y = clampf(qq.y, r.position.y + 5.0, r.position.y + r.size.y - 5.0)
			var dm = PackedVector2Array([qq + Vector2(0, -6), qq + Vector2(6, 0), qq + Vector2(0, 6), qq + Vector2(-6, 0)])
			draw_colored_polygon(dm, Color(1.0, 0.95, 0.2))
	# 나 (화살표)
	var yaw: float = hub.hud.player_yaw if hub.hud != null else 0.0
	if _driving() and v1 != null and v1.drive != null and v1.drive.current != null:
		yaw = v1.drive.current.rotation.y
	var dir = Vector2(-sin(yaw), -cos(yaw))
	var perp = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c + dir * 8.0, c - dir * 5.0 + perp * 5.0, c - dir * 5.0 - perp * 5.0]), Color(1.0, 0.25, 0.2))
	draw_rect(r, Color(1, 1, 1, 0.65), false, 2.0)


func _map_rect(clip: Rect2, center_world: Vector3, c: Vector2, x0: float, z0: float, x1: float, z1: float, col: Color) -> void:
	var a: Vector2 = _w2m(Vector3(x0, 0.0, z0), center_world, c)
	var b: Vector2 = _w2m(Vector3(x1, 0.0, z1), center_world, c)
	var rr = Rect2(a, b - a).intersection(clip)
	if rr.size.x > 0.0 and rr.size.y > 0.0:
		draw_rect(rr, col, true)


func _draw_alert() -> void:
	if v1 == null or v1.alert == null:
		return
	var font: Font = _font
	var al = v1.alert
	var y: float = 76.0 + MAP_SIZE + 8.0 if show_minimap else 76.0
	var col: Color = al.level_color()
	draw_circle(Vector2(28.0, y + 12.0), 8.0, col)
	draw_string(font, Vector2(42.0, y + 19.0), "도시 경계: " + al.level_name(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1, 1, 1, 0.92))
	if al.heat > 1.0:
		var bw: float = 130.0
		draw_rect(Rect2(16.0, y + 28.0, bw, 8.0), Color(0, 0, 0, 0.5), true)
		draw_rect(Rect2(17.0, y + 29.0, (bw - 2.0) * clampf(al.heat / 100.0, 0.0, 1.0), 6.0), col, true)
	if al.police.size() > 0:
		draw_string(font, Vector2(16.0, y + 56.0), "출동 경찰 %d명" % al.police.size(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.7, 0.8, 1.0, 0.95))


func _draw_drive(s: Vector2) -> void:
	var font: Font = _font
	if v1 == null or v1.drive == null or v1.drive.current == null:
		return
	var car = v1.drive.current
	var kmh: int = int(absf(car.speed) * 3.6)
	var cx: float = s.x * 0.5
	var by: float = s.y - 110.0
	if v1.drive.cam_mode == 1:
		# 운전석 시점: 아래쪽 계기판 띠
		draw_rect(Rect2(0.0, s.y - 130.0, s.x, 130.0), Color(0.04, 0.04, 0.05, 0.85), true)
		draw_arc(Vector2(cx, s.y + 10.0), 120.0, PI * 1.1, PI * 1.9, 32, Color(0.7, 0.7, 0.72), 10.0, true)
		draw_arc(Vector2(cx, s.y + 10.0), 100.0, PI * 1.1, PI * 1.1 + clampf(absf(car.speed) / car.max_speed, 0.0, 1.0) * PI * 0.8, 32, Color(0.4, 1.0, 0.6), 6.0, true)
	var txt: String = "%d km/h" % kmh
	var ptxt: String = "%s  %s" % [car.display_name, "후진" if car.speed < -0.5 else ("정지" if absf(car.speed) < 0.5 else "주행")]
	draw_string(font, Vector2(cx - 150.0, by), txt, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 40, Color(1, 1, 1, 0.95))
	draw_string(font, Vector2(cx - 150.0, by + 28.0), ptxt, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 20, Color(0.8, 0.9, 1.0, 0.9))
	var hint: String = "조이스틱 위=가속 · 아래=브레이크/후진 · 좌우=핸들 · JUMP=핸드브레이크"
	draw_string(font, Vector2(0.0, s.y - 20.0), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color(1, 1, 1, 0.6))
	_button(_view_center(), 44.0, "시점", Color(0.7, 0.9, 1.0))


func _button(c: Vector2, r: float, label: String, tint: Color) -> void:
	draw_circle(c, r, Color(0, 0, 0, 0.45))
	draw_arc(c, r, 0.0, TAU, 36, Color(tint.r, tint.g, tint.b, 0.9), 3.0, true)
	draw_string(_font, c + Vector2(-r, 9.0), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 26, Color(1, 1, 1, 0.97))
