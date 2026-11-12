extends Control
## 게임 HUD. 모두 직접 그리고 터치를 처리합니다.
##  - 상단 중앙: 시계, 현재 임무 한 줄, 경계(잠입) 게이지
##  - 상단 오른쪽: 지도 / 가방 / 임무 / 메뉴 버튼, 시점 가까이(+) / 멀리(-)
##  - 알림(toast)
##  - 전체 화면 패널: 가방, 임무, 지도, 메뉴(저장/불러오기)
## 이 노드는 interaction_ui.gd 보다 나중에 만들어져서 터치를 먼저 받습니다.
## 대화나 암전 중(blocked=true)에는 터치를 가져가지 않고 아래 UI 에 넘깁니다.

signal menu_action(id: String)

const ItemData = preload("res://scripts/data/item_data.gd")
const QuestData = preload("res://scripts/data/quest_data.gd")
const Flags = preload("res://scripts/data/feature_flags.gd")
const FONT_PATH: String = "res://assets/fonts/NanumGothic.ttf"
## 설정 화면의 항목 id (hub → v1_manager.on_menu_action 이 처리)
const SETTING_ROWS: Array = ["setting:gfx_quality", "setting:gfx_enabled", "setting:shadows", "setting:crowd", "setting:traffic", "setting:minimap", "setting:weather", "setting:fps", "setting:view", "setting:lowend"]

# hub 가 채워 주는 값
var game = null
var clock = null
var player_pos: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var location_name: String = "광장 일대"
var alert: float = 0.0
var blocked: bool = false
## V1 확장 총괄 (지도의 임무 표시, 소문 목록용). 없으면 null
var v1_ref = null
## V2.2 확장 총괄 (목표 안내, 상태 표시, 지도 덧그리기). 없으면 null
var v22_ref = null
## 지도에 나타내는 가로/세로 길이(m). V2.2 가 켜지면 760
var map_span: float = 480.0

## "", "inventory", "quests", "map", "menu"
var panel: String = ""

var _toasts: Array = []
var _selected_item: String = ""
var _hits: Array = []
var _owned: Dictionary = {}
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = _load_kr_font_safe(FONT_PATH)


func panel_open() -> bool:
	return panel != ""


func show_toast(text: String) -> void:
	_toasts.append({"text": text, "age": 0.0})
	if _toasts.size() > 4:
		_toasts.pop_front()


func open_panel(id: String) -> void:
	panel = id
	queue_redraw()


func close_panel() -> void:
	panel = ""
	queue_redraw()


func _process(delta: float) -> void:
	var i: int = _toasts.size() - 1
	while i >= 0:
		_toasts[i]["age"] = float(_toasts[i]["age"]) + delta
		if float(_toasts[i]["age"]) > 3.8:
			_toasts.remove_at(i)
		i -= 1
	queue_redraw()


# ---------------------------------------------------------------- 터치

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


func _handle_down(pos: Vector2) -> bool:
	if blocked and panel == "":
		return false
	_layout()
	for h in _hits:
		var r: Rect2 = h["rect"]
		if r.has_point(pos):
			_on_hit(str(h["id"]))
			return true
	# 패널이 열려 있으면 바깥 터치도 소비 (뒤의 조이스틱이 반응하지 않게)
	return panel != ""


func _on_hit(id: String) -> void:
	if id == "close":
		close_panel()
	elif id in ["map", "inventory", "quests", "menu"]:
		if panel == id:
			close_panel()
		else:
			open_panel(id)
	elif id == "zoom_in" or id == "zoom_out" or id == "newgame":
		menu_action.emit(id)
	elif id == "open_settings":
		open_panel("settings")
	elif id == "settings_back":
		open_panel("menu")
	elif id.begins_with("setting:"):
		menu_action.emit(id)
	elif id == "save" or id == "load":
		menu_action.emit(id)
		close_panel()
	elif id.begins_with("item:"):
		_selected_item = id.substr(5)


# ---------------------------------------------------------------- 레이아웃 (그리기와 터치가 같은 값을 씀)

func _panel_rect() -> Rect2:
	var s: Vector2 = get_viewport_rect().size
	var w: float = minf(s.x - 60.0, 960.0)
	var h: float = minf(s.y - 50.0, 620.0)
	return Rect2((s.x - w) * 0.5, (s.y - h) * 0.5, w, h)


func _layout() -> void:
	_hits.clear()
	var s: Vector2 = get_viewport_rect().size
	if panel == "":
		var names: Array = ["menu", "quests", "inventory", "map"]
		for i in range(names.size()):
			var c = Vector2(s.x - 48.0 - float(i) * 78.0, 46.0)
			_hits.append({"rect": Rect2(c - Vector2(34, 34), Vector2(68, 68)), "id": names[i]})
		_hits.append({"rect": Rect2(Vector2(s.x - 48.0, 128.0) - Vector2(30, 30), Vector2(60, 60)), "id": "zoom_in"})
		_hits.append({"rect": Rect2(Vector2(s.x - 48.0, 196.0) - Vector2(30, 30), Vector2(60, 60)), "id": "zoom_out"})
		return

	var p: Rect2 = _panel_rect()
	_hits.append({"rect": Rect2(p.position.x + p.size.x - 70.0, p.position.y + 10.0, 60.0, 50.0), "id": "close"})
	# 패널별 터치 영역. 패널이 열려 있는 동안엔 상단 버튼이 눌리지 않고, X 로 닫은 뒤 사용함
	if panel == "inventory":
		var ids: Array = game.inventory.keys() if game != null else []
		for i in range(ids.size()):
			_hits.append({"rect": Rect2(p.position.x + 20.0, p.position.y + 86.0 + float(i) * 54.0, 300.0, 50.0), "id": "item:" + str(ids[i])})
	elif panel == "menu":
		_hits.append({"rect": Rect2(p.position.x + 40.0, p.position.y + 100.0, 280.0, 64.0), "id": "save"})
		_hits.append({"rect": Rect2(p.position.x + 40.0, p.position.y + 180.0, 280.0, 64.0), "id": "load"})
		_hits.append({"rect": Rect2(p.position.x + 40.0, p.position.y + 260.0, 130.0, 64.0), "id": "zoom_in"})
		_hits.append({"rect": Rect2(p.position.x + 190.0, p.position.y + 260.0, 130.0, 64.0), "id": "zoom_out"})
		_hits.append({"rect": Rect2(p.position.x + 40.0, p.position.y + 340.0, 280.0, 64.0), "id": "newgame"})
		_hits.append({"rect": Rect2(p.position.x + 40.0, p.position.y + 420.0, 280.0, 64.0), "id": "open_settings"})
	elif panel == "settings":
		# 두 줄(열)로 배치: 왼쪽 5개 + 오른쪽 5개
		for i in range(SETTING_ROWS.size()):
			var col_i: int = i / 5
			var row_i: int = i % 5
			_hits.append({"rect": Rect2(p.position.x + 24.0 + float(col_i) * 306.0, p.position.y + 84.0 + float(row_i) * 66.0, 296.0, 58.0), "id": SETTING_ROWS[i]})
		_hits.append({"rect": Rect2(p.position.x + 40.0, p.position.y + p.size.y - 76.0, 200.0, 56.0), "id": "settings_back"})


# ---------------------------------------------------------------- 그리기

func _draw() -> void:
	var font: Font = _font
	if font == null:
		return
	var s: Vector2 = get_viewport_rect().size
	_layout()

	if panel == "":
		_draw_top(font, s)
	else:
		_draw_panel(font, s)
	_draw_toasts(font, s)


func _pill(font: Font, center_x: float, y: float, text: String, size: int, fg: Color, bg: Color) -> void:
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var r = Rect2(center_x - tw * 0.5 - 16.0, y, tw + 32.0, float(size) + 18.0)
	draw_rect(r, bg, true)
	draw_string(font, Vector2(r.position.x + 16.0, r.position.y + float(size) + 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, fg)


func _draw_top(font: Font, s: Vector2) -> void:
	# 시계
	if clock != null:
		var ctext: String = "%s  %s" % [clock.time_label(), clock.period_name()]
		_pill(font, s.x * 0.5, 10.0, ctext, 22, Color(1, 1, 1, 0.95), Color(0, 0, 0, 0.45))

	# 현재 임무 한 줄
	if game != null:
		var ids: Array = game.active_quest_ids()
		if ids.size() > 0:
			var qid: String = str(ids[0])
			var line: String = "%s: %s" % [game.quest_title(qid), game.quest_step_text(qid)]
			if v22_ref != null:
				var ol: String = str(v22_ref.objective_text())
				if ol != "":
					line = ol
			_pill(font, s.x * 0.5, 54.0, line, 18, Color(1.0, 0.92, 0.6), Color(0, 0, 0, 0.45))

	# V2.2: 소지금 / 통행증 / 경계 단계
	if v22_ref != null:
		var st: String = str(v22_ref.status_line())
		if st != "":
			_pill(font, 190.0, 10.0, st, 18, Color(0.9, 1.0, 0.9), Color(0, 0, 0, 0.45))

	# 경계(잠입) 게이지
	if alert > 0.02:
		var bw: float = 260.0
		var bx: float = s.x * 0.5 - bw * 0.5
		draw_rect(Rect2(bx, 100.0, bw, 14.0), Color(0, 0, 0, 0.55), true)
		var col: Color = Color(1.0, 0.8, 0.2).lerp(Color(1.0, 0.2, 0.15), clampf(alert, 0.0, 1.0))
		draw_rect(Rect2(bx + 2.0, 102.0, (bw - 4.0) * clampf(alert, 0.0, 1.0), 10.0), col, true)
		draw_string(font, Vector2(bx, 134.0), "경계", HORIZONTAL_ALIGNMENT_CENTER, bw, 16, Color(1, 0.8, 0.8, 0.95))

	# 버튼
	var names: Array = ["menu", "quests", "inventory", "map"]
	var labels: Array = ["메뉴", "임무", "가방", "지도"]
	for i in range(names.size()):
		var c = Vector2(s.x - 48.0 - float(i) * 78.0, 46.0)
		_round_button(font, c, 31.0, str(labels[i]), 20, Color(1, 1, 1))
	_round_button(font, Vector2(s.x - 48.0, 128.0), 27.0, "+", 30, Color(0.8, 1.0, 0.8))
	_round_button(font, Vector2(s.x - 48.0, 196.0), 27.0, "-", 30, Color(0.8, 1.0, 0.8))


func _round_button(font: Font, c: Vector2, r: float, label: String, size: int, tint: Color) -> void:
	draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.40))
	draw_arc(c, r, 0.0, TAU, 32, Color(tint.r, tint.g, tint.b, 0.8), 2.5, true)
	draw_string(font, c + Vector2(-r, float(size) * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, size, Color(1, 1, 1, 0.95))


func _draw_toasts(font: Font, s: Vector2) -> void:
	var y: float = 150.0
	for t in _toasts:
		var age: float = float(t["age"])
		var a: float = 1.0
		if age > 3.0:
			a = clampf((3.8 - age) / 0.8, 0.0, 1.0)
		_pill(font, s.x * 0.5, y, str(t["text"]), 22, Color(1, 1, 1, a), Color(0.05, 0.1, 0.2, 0.75 * a))
		y += 46.0


func _draw_panel(font: Font, s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.45), true)
	var p: Rect2 = _panel_rect()
	draw_rect(p, Color(0.05, 0.06, 0.09, 0.95), true)
	draw_rect(p, Color(1, 1, 1, 0.4), false, 2.0)
	var cr = Rect2(p.position.x + p.size.x - 70.0, p.position.y + 10.0, 60.0, 50.0)
	draw_rect(cr, Color(1, 1, 1, 0.14), true)
	draw_string(font, cr.position + Vector2(0, 34), "X", HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 26, Color(1, 1, 1, 0.95))

	if panel == "inventory":
		_draw_inventory(font, p)
	elif panel == "quests":
		_draw_quests(font, p)
	elif panel == "map":
		_draw_map(font, p)
	elif panel == "menu":
		_draw_menu(font, p)
	elif panel == "settings":
		_draw_settings(font, p)


func _title(font: Font, p: Rect2, text: String) -> void:
	draw_string(font, p.position + Vector2(24, 52), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, Color(1.0, 0.86, 0.45))


func _draw_inventory(font: Font, p: Rect2) -> void:
	_title(font, p, "가방")
	var ids: Array = game.inventory.keys() if game != null else []
	if ids.is_empty():
		draw_string(font, p.position + Vector2(24, 120), "아직 가진 물건이 없습니다.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(1, 1, 1, 0.7))
		return
	if _selected_item == "" or not game.inventory.has(_selected_item):
		_selected_item = str(ids[0])
	for i in range(ids.size()):
		var id: String = str(ids[i])
		var r = Rect2(p.position.x + 20.0, p.position.y + 86.0 + float(i) * 54.0, 300.0, 50.0)
		var sel: bool = id == _selected_item
		draw_rect(r, Color(0.2, 0.36, 0.58, 0.8) if sel else Color(1, 1, 1, 0.08), true)
		var label: String = ItemData.item_name(id)
		var cnt: int = int(game.inventory[id])
		if cnt > 1:
			label += " x%d" % cnt
		draw_string(font, r.position + Vector2(14, 34), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(1, 1, 1, 0.95))
	var dx: float = p.position.x + 350.0
	draw_string(font, Vector2(dx, p.position.y + 118.0), ItemData.item_name(_selected_item), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(1.0, 0.86, 0.45))
	draw_multiline_string(font, Vector2(dx, p.position.y + 162.0), ItemData.item_desc(_selected_item), HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 380.0, 24, 12, Color(1, 1, 1, 0.9))


func _draw_quests(font: Font, p: Rect2) -> void:
	_title(font, p, "임무")
	if game == null:
		return
	var y: float = p.position.y + 100.0
	var active: Array = game.active_quest_ids()
	if active.is_empty():
		draw_string(font, Vector2(p.position.x + 24, y), "진행 중인 임무가 없습니다.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(1, 1, 1, 0.7))
		y += 44.0
	for qid in active:
		if y > p.position.y + p.size.y - 120.0:
			draw_string(font, Vector2(p.position.x + 24, y), "… (임무가 더 있습니다)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(1, 1, 1, 0.5))
			y += 30.0
			break
		var q: Dictionary = QuestData.QUESTS.get(str(qid), {})
		draw_string(font, Vector2(p.position.x + 24, y), game.quest_title(str(qid)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color(1.0, 0.86, 0.45))
		y += 32.0
		var steps: Array = q.get("steps", [])
		var cur: int = game.quest_step(str(qid))
		for i in range(steps.size()):
			if i > cur + 0:
				continue
			var done: bool = i < cur
			var mark: String = "[x] " if done else "[ ] "
			var col: Color = Color(1, 1, 1, 0.45) if done else Color(1, 1, 1, 0.95)
			draw_string(font, Vector2(p.position.x + 40, y), mark + str(steps[i]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, col)
			y += 30.0
		y += 14.0
	var done_ids: Array = game.done_quest_ids()
	if done_ids.size() > 0:
		draw_string(font, Vector2(p.position.x + 24, y), "완료한 임무", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.7, 1.0, 0.7))
		y += 32.0
		for qid in done_ids:
			if y > p.position.y + p.size.y - 60.0:
				break
			draw_string(font, Vector2(p.position.x + 40, y), "[x] " + game.quest_title(str(qid)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1, 1, 1, 0.55))
			y += 30.0
	var failed_ids: Array = game.failed_quest_ids()
	for qid2 in failed_ids:
		if y > p.position.y + p.size.y - 60.0:
			break
		draw_string(font, Vector2(p.position.x + 40, y), "[실패] " + game.quest_title(str(qid2)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1.0, 0.5, 0.45, 0.85))
		y += 30.0
	_draw_rumors(font, p, y)


func _draw_map(font: Font, p: Rect2) -> void:
	_title(font, p, "지도")
	var size: float = minf(p.size.y - 110.0, p.size.x * 0.56)
	var mr = Rect2(p.position.x + 24.0, p.position.y + 84.0, size, size)
	draw_rect(mr, Color(0.28, 0.36, 0.25, 1.0), true)
	var sc: float = size / map_span
	var c: Vector2 = mr.position + mr.size * 0.5
	# 대로 (동서, 남북은 광장에서 남쪽으로)
	draw_rect(Rect2(c.x - 240.0 * sc, c.y - 8.0 * sc, 480.0 * sc, 16.0 * sc), Color(0.2, 0.2, 0.22), true)
	draw_rect(Rect2(c.x - 8.0 * sc, c.y - 50.0 * sc, 16.0 * sc, 290.0 * sc), Color(0.2, 0.2, 0.22), true)
	# 광장
	draw_rect(Rect2(c.x - 50.0 * sc, c.y - 50.0 * sc, 100.0 * sc, 100.0 * sc), Color(0.72, 0.72, 0.70), true)
	draw_rect(mr, Color(1, 1, 1, 0.5), false, 2.0)

	# 발견한 장소
	if game != null:
		for id in game.discovered.keys():
			if not game.pois.has(id):
				continue
			var poi: Dictionary = game.pois[id]
			var pp: Vector3 = poi["pos"]
			var pt = Vector2(c.x + pp.x * sc, c.y + pp.z * sc)
			if mr.has_point(pt):
				draw_rect(Rect2(pt - Vector2(6, 6), Vector2(12, 12)), Color(1.0, 0.8, 0.3), true)
				draw_string(font, pt + Vector2(10, 5), str(poi["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1, 1, 1, 0.95))

	# V2.2: 검문소, 목표 표시, 새 지역 이름
	if v22_ref != null:
		v22_ref.draw_map_overlay(self, font, mr, c, sc)

	# V1: 임무 목표 / 차량
	if v1_ref != null:
		for car in get_tree().get_nodes_in_group("drivables"):
			if is_instance_valid(car):
				var cp: Vector3 = car.global_position
				var cq = Vector2(c.x + cp.x * sc, c.y + cp.z * sc)
				if mr.has_point(cq):
					draw_rect(Rect2(cq - Vector2(3, 3), Vector2(6, 6)), Color(0.5, 0.75, 1.0), true)
		for qm in v1_ref.quest_marks:
			var qq = Vector2(c.x + qm.x * sc, c.y + qm.z * sc)
			qq.x = clampf(qq.x, mr.position.x + 8.0, mr.position.x + mr.size.x - 8.0)
			qq.y = clampf(qq.y, mr.position.y + 8.0, mr.position.y + mr.size.y - 8.0)
			draw_colored_polygon(PackedVector2Array([qq + Vector2(0, -9), qq + Vector2(9, 0), qq + Vector2(0, 9), qq + Vector2(-9, 0)]), Color(1.0, 0.95, 0.2))
			draw_polyline(PackedVector2Array([qq + Vector2(0, -9), qq + Vector2(9, 0), qq + Vector2(0, 9), qq + Vector2(-9, 0), qq + Vector2(0, -9)]), Color(0, 0, 0, 0.8), 2.0)

	# 플레이어 (실내에 있으면 지도에 표시하지 않음)
	var outdoors: bool = player_pos.y < 100.0
	if outdoors:
		var pt2 = Vector2(c.x + player_pos.x * sc, c.y + player_pos.z * sc)
		pt2.x = clampf(pt2.x, mr.position.x + 4.0, mr.position.x + mr.size.x - 4.0)
		pt2.y = clampf(pt2.y, mr.position.y + 4.0, mr.position.y + mr.size.y - 4.0)
		var dir = Vector2(-sin(player_yaw), -cos(player_yaw))
		var perp = Vector2(-dir.y, dir.x)
		var tri = PackedVector2Array([pt2 + dir * 12.0, pt2 - dir * 7.0 + perp * 7.0, pt2 - dir * 7.0 - perp * 7.0])
		draw_colored_polygon(tri, Color(1.0, 0.25, 0.2))

	var tx: float = mr.position.x + mr.size.x + 24.0
	var ty: float = p.position.y + 120.0
	draw_string(font, Vector2(tx, ty), "현재 위치", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1.0, 0.86, 0.45))
	draw_string(font, Vector2(tx, ty + 32.0), location_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(1, 1, 1, 0.95))
	if outdoors:
		draw_string(font, Vector2(tx, ty + 64.0), "X %.0f   Z %.0f" % [player_pos.x, player_pos.z], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(1, 1, 1, 0.75))
	else:
		draw_string(font, Vector2(tx, ty + 64.0), "(실내에서는 위치가 표시되지 않음)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1, 1, 1, 0.6))
	var yy: float = ty + 112.0
	draw_string(font, Vector2(tx, yy), "발견한 장소", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1.0, 0.86, 0.45))
	yy += 32.0
	var found: int = 0
	if game != null:
		for id in game.discovered.keys():
			if game.pois.has(id):
				draw_string(font, Vector2(tx, yy), "- " + str(game.pois[id]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(1, 1, 1, 0.9))
				yy += 28.0
				found += 1
	if found == 0:
		draw_string(font, Vector2(tx, yy), "(아직 없음)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(1, 1, 1, 0.6))
	draw_multiline_string(font, Vector2(tx, p.position.y + p.size.y - 90.0), "노란 마름모=임무 목표 · 파란 점=차량 · 노란 네모=발견한 장소(랜드마크 포함). 다가가면 장소가 지도에 기록됩니다.", HORIZONTAL_ALIGNMENT_LEFT, p.position.x + p.size.x - tx - 20.0, 16, 4, Color(1, 1, 1, 0.5))


func _draw_menu(font: Font, p: Rect2) -> void:
	_title(font, p, "메뉴")
	for h in _hits:
		var id: String = str(h["id"])
		if id == "close":
			continue
		var r: Rect2 = h["rect"]
		var label: String = ""
		if id == "save":
			label = "저장하기"
		elif id == "load":
			label = "불러오기"
		elif id == "zoom_in":
			label = "시점 가까이"
		elif id == "zoom_out":
			label = "시점 멀리"
		elif id == "newgame":
			label = "새 게임 (2번 누름)"
		elif id == "open_settings":
			label = "설정 (그래픽/성능)"
		draw_rect(r, Color(0.20, 0.36, 0.58, 0.7), true)
		draw_rect(r, Color(0.7, 0.85, 1.0, 0.8), false, 2.0)
		draw_string(font, r.position + Vector2(0, 42), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color(1, 1, 1, 0.97))
	var tx: float = p.position.x + 380.0
	var lines: Array = [
		"조작 안내",
		"- 왼쪽 화면 끌기: 이동",
		"- 오른쪽 화면 끌기: 카메라 회전",
		"- JUMP: 점프 / RUN: 달리기 켜기·끄기",
		"- 가까이 가면 노란 버튼이 나타남",
		"  (대화, 입장, 앉기, 문, 조사)",
		"- 저장 파일은 이 기기 안에만 저장됩니다.",
		"- 앱을 나가면 자동 저장됩니다.",
	]
	for i in range(lines.size()):
		var col: Color = Color(1.0, 0.86, 0.45) if i == 0 else Color(1, 1, 1, 0.88)
		draw_string(font, Vector2(tx, p.position.y + 110.0 + float(i) * 34.0), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22 if i > 0 else 26, col)


func _draw_rumors(font: Font, p: Rect2, y0: float) -> void:
	if v1_ref == null:
		return
	var lines: Array = v1_ref.rumor_lines()
	var y: float = y0 + 10.0
	draw_string(font, Vector2(p.position.x + 24, y), "들은 소문 %d건" % lines.size(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.7, 0.85, 1.0))
	y += 30.0
	var start: int = maxi(0, lines.size() - 3)
	for i in range(start, lines.size()):
		if y > p.position.y + p.size.y - 40.0:
			break
		draw_multiline_string(font, Vector2(p.position.x + 40, y), "- " + str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 90.0, 18, 2, Color(1, 1, 1, 0.7))
		y += 48.0


func _setting_label(id: String) -> String:
	match id:
		"setting:gfx_quality":
			return "그래픽 품질: %s" % ["낮음", "보통", "높음"][clampi(Flags.gfx_quality(), 0, 2)]
		"setting:gfx_enabled":
			return "사실적 그래픽: %s" % ("켜짐" if Flags.gfx_enabled() else "꺼짐 (가벼운 모드)")
		"setting:shadows":
			return "그림자: %s" % ("켜짐" if Flags.shadows_on(true) else "꺼짐")
		"setting:crowd":
			return "시민 수: %d명" % Flags.crowd_count()
		"setting:traffic":
			return "도로 차량 수: %d대" % Flags.traffic_count(8)
		"setting:minimap":
			return "미니맵: %s" % ("켜짐" if Flags.minimap_on() else "꺼짐")
		"setting:weather":
			return "날씨 변화: %s" % ("켜짐" if Flags.weather_on() else "꺼짐")
		"setting:fps":
			return "FPS 표시: %s" % ("켜짐" if Flags.fps_on() else "꺼짐")
		"setting:view":
			return "시야 거리: %s" % ["가깝게", "보통", "멀리"][clampi(Flags.view_step(), 0, 2)]
		"setting:lowend":
			return "저사양 모드(한 번에)"
	return id


func _draw_settings(font: Font, p: Rect2) -> void:
	_title(font, p, "설정 (그래픽 / 성능)")
	for h in _hits:
		var id: String = str(h["id"])
		var r: Rect2 = h["rect"]
		if id == "close":
			continue
		var label: String = "뒤로" if id == "settings_back" else _setting_label(id)
		draw_rect(r, Color(0.20, 0.36, 0.58, 0.7), true)
		draw_rect(r, Color(0.7, 0.85, 1.0, 0.8), false, 2.0)
		draw_string(font, r.position + Vector2(0, 37), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 21, Color(1, 1, 1, 0.97))
	var tx: float = p.position.x + 660.0
	var lines: Array = [
		"안내",
		"- 눌러서 값이 순서대로 바뀝니다.",
		"- 미니맵·그림자·날씨·FPS·시야는",
		"  바로 적용됩니다.",
		"- 그래픽 품질·시민·차량 수는",
		"  앱을 다시 켜면 적용됩니다.",
		"- 폰이 느리면 '저사양 모드'를",
		"  누른 뒤 앱을 다시 켜세요.",
	]
	for i in range(lines.size()):
		var col: Color = Color(1.0, 0.86, 0.45) if i == 0 else Color(1, 1, 1, 0.85)
		draw_string(font, Vector2(tx, p.position.y + 110.0 + float(i) * 34.0), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20 if i > 0 else 24, col)


func _load_kr_font_safe(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font and f.has_char(0xD55C):
			return f
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK and ff.has_char(0xD55C):
			return ff
	push_error("[FontLoader] Failed to load Korean font: " + path)
	return ThemeDB.fallback_font
