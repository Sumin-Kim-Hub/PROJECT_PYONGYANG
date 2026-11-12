extends Control
## V3.0 화면 (통치 버튼, 지표 표시, 통치 메뉴 8개, 건설 버튼, 도시 조망 버튼, 컷씬 글 카드).
## 기존 HUD 와 같은 방식: _draw 로 직접 그리고, 화면 터치(ScreenTouch)를 직접 받는다. (진짜 Button 노드 없음)
## 버튼은 모두 손가락으로 누르기 쉬운 크기(높이 54 이상)로 만들었다. (Godot 실행 미검증)

const Flags = preload("res://scripts/data/feature_flags.gd")
const D = preload("res://scripts/v3/v3_data.gd")
const FONT_PATH: String = "res://assets/fonts/NanumGothic.ttf"

signal cards_finished

const TABS: Array = [
	{"id": "status", "name": "국가 현황"},
	{"id": "budget", "name": "국가 예산"},
	{"id": "policy", "name": "정책"},
	{"id": "city", "name": "도시 개발"},
	{"id": "people", "name": "주요 인물"},
	{"id": "meeting", "name": "회의"},
	{"id": "mission", "name": "임무"},
	{"id": "save", "name": "저장·불러오기"},
]

var man = null
var gov = null
var build = null

var panel: String = ""
var poli_cat: int = 0
var ppl_sel: String = "aide"
var msg: String = ""
var msg_t: float = 0.0

var cards: Array = []
var card_i: int = 0
var cards_active: bool = false
var _card_t: float = 0.0

var _font: Font = null
var _hits: Array = []
var _owned: Dictionary = {}
var _look_touch: int = -1


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _font = ThemeDB.fallback_font
	if ClassDB.class_exists(\"Node\"):
		var _kfe = load(\"res://scripts/core/korean_font_enforcer.gd\")
		if _kfe:
			_font = _kfe.get_korean_font()

    print("[KFONT] path=", FONT_PATH)
    print("[KFONT] exists=", ResourceLoader.exists(FONT_PATH))

    if ResourceLoader.exists(FONT_PATH):
        var f = load(FONT_PATH)
        print("[KFONT] loaded=", f is Font)
        if f is Font:
            _font = f
            print("[KFONT] Korean glyph=", _font.has_char(0xD55C))

func setup(man_ref, gov_ref, build_ref) -> void:
	man = man_ref
	gov = gov_ref
	build = build_ref


func say(text: String) -> void:
	msg = text
	msg_t = 4.0


func panel_open() -> bool:
	return panel != ""


func open_panel(id: String) -> void:
	panel = id
	msg = ""
	if man != null:
		man.on_panel_changed(true)


func close_panel() -> void:
	panel = ""
	if man != null:
		man.on_panel_changed(false)


## 컷씬 글 카드를 보여 주고, 모두 넘기면 cards_finished 신호를 보낸다
func show_cards(list: Array) -> void:
	cards = list
	card_i = 0
	cards_active = true
	_card_t = 0.0


func _process(delta: float) -> void:
	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0:
			msg = ""
	if cards_active:
		_card_t += delta
	queue_redraw()


# ================================================================ 터치

func _input(event: InputEvent) -> void:
	if cards_active:
		if event is InputEventScreenTouch:
			var tc = event as InputEventScreenTouch
			if tc.pressed and _card_t > 0.35:
				card_i += 1
				_card_t = 0.0
				if card_i >= cards.size():
					cards_active = false
					cards = []
					cards_finished.emit()
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var t = event as InputEventScreenTouch
		if t.pressed:
			if _handle_down(t.position, t.index):
				_owned[t.index] = true
				get_viewport().set_input_as_handled()
		else:
			if _look_touch == t.index:
				_look_touch = -1
			if _owned.has(t.index):
				_owned.erase(t.index)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d = event as InputEventScreenDrag
		if _look_touch == d.index and man != null and man.leader != null:
			man.leader.overlook_drag(d.relative)
		if _owned.has(d.index):
			get_viewport().set_input_as_handled()


func _handle_down(pos: Vector2, index: int) -> bool:
	if man == null:
		return false
	for h in _hits:
		var r: Rect2 = h["rect"]
		if r.has_point(pos):
			_on_hit(str(h["id"]))
			return true
	if man.leader != null and man.leader.overlook_active:
		_look_touch = index
		return true
	# 패널이 열려 있으면 바깥 터치도 소비 (뒤의 조이스틱이 반응하지 않게)
	return panel != ""


func _on_hit(id: String) -> void:
	if id == "open":
		if man.can_open_menu():
			open_panel("status")
		elif int(man.hub.mode) == 5:
			# 운전 중에는 열리지 않는다. 아무 반응이 없으면 고장으로 오해하기 쉬우므로 안내
			man.hub.toast("차에서 내린 뒤에 통치 메뉴를 열 수 있어요.")
		return
	if id == "close":
		close_panel()
		return
	if id.begins_with("tab:"):
		panel = id.substr(4)
		msg = ""
		return
	if id.begins_with("pcat:"):
		poli_cat = int(id.substr(5))
		msg = ""
		return
	if id.begins_with("pol:"):
		say(man.act_policy(id.substr(4)))
		return
	if id.begins_with("alloc:"):
		var parts: PackedStringArray = id.split(":")
		man.act_alloc(parts[1], int(parts[2]))
		return
	if id.begins_with("bld:"):
		var res: String = man.act_build_start(id.substr(4))
		if res != "":
			say(res)
		return
	if id == "demolish":
		say(man.act_demolish())
		return
	if id == "meet_open":
		man.act_meet_open()
		return
	if id.begins_with("meet:"):
		man.act_meet_pick(int(id.substr(5)))
		return
	if id == "meet_close":
		man.act_meet_close()
		return
	if id.begins_with("ppl:"):
		ppl_sel = id.substr(4)
		msg = ""
		return
	if id.begins_with("cheer:"):
		say(man.act_cheer(id.substr(6)))
		return
	if id.begins_with("gift:"):
		say(man.act_gift(id.substr(5)))
		return
	if id == "save":
		say(man.act_save())
		return
	if id == "load":
		man.act_load()
		return
	if id.begins_with("go:"):
		var where: String = id.substr(3)
		close_panel()
		man.act_travel(where)
		return
	if id == "b_ok":
		say(man.act_build_confirm())
		return
	if id == "b_rot":
		man.act_build_rotate()
		return
	if id == "b_cancel":
		man.act_build_cancel()
		return
	if id == "ov_next":
		man.leader.overlook_next()
		return
	if id == "ov_close":
		man.leader.overlook_close()
		return
	if id == "ov_in":
		man.leader.overlook_zoom(-12.0)
		return
	if id == "ov_out":
		man.leader.overlook_zoom(12.0)
		return


# ================================================================ 그리기 도우미

func _btn(r: Rect2, id: String, label: String, size: int = 22, enabled: bool = true, tint: Color = Color(0.18, 0.28, 0.40)) -> void:
	var bg: Color = Color(tint.r, tint.g, tint.b, 0.95) if enabled else Color(0.16, 0.16, 0.18, 0.9)
	draw_rect(r, bg, true)
	draw_rect(r, Color(1, 1, 1, 0.45 if enabled else 0.18), false, 2.0)
	var fg: Color = Color(1, 1, 1, 0.96) if enabled else Color(1, 1, 1, 0.4)
	draw_string(_font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + float(size) * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, fg)
	_hits.append({"rect": r, "id": id})


func _txt(pos: Vector2, text: String, size: int, color: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font, pos, text, align, width, size, color)


func _mtxt(pos: Vector2, text: String, size: int, color: Color, width: float, max_lines: int = -1) -> void:
	draw_multiline_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, color)


func _pill(cx: float, y: float, text: String, size: int, fg: Color, bg: Color) -> void:
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var r: Rect2 = Rect2(cx - tw * 0.5 - 16.0, y, tw + 32.0, float(size) + 18.0)
	draw_rect(r, bg, true)
	draw_string(_font, Vector2(r.position.x + 16.0, r.position.y + float(size) + 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, fg)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.55), true)
	var f: float = clampf(frac, 0.0, 1.0)
	draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, (r.size.x - 4.0) * f, r.size.y - 4.0), col, true)


func _ind_color(k: String, v: float) -> Color:
	if k == "budget":
		if v < 0.0:
			return Color(0.95, 0.30, 0.25)
		return Color(0.95, 0.82, 0.35)
	if v < 25.0:
		return Color(0.95, 0.30, 0.25)
	if v < 45.0:
		return Color(0.95, 0.70, 0.25)
	return Color(0.40, 0.80, 0.45)


func _fmt(k: String, v: float) -> String:
	if k == "budget":
		return _commas(int(v))
	return "%.1f" % v


func _commas(n: int) -> String:
	var neg: bool = n < 0
	var s: String = str(absi(n))
	var out: String = ""
	var cnt: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if neg else out


# ================================================================ 그리기

func _draw() -> void:
	_hits.clear()
	if _font == null or man == null:
		return
	var s: Vector2 = get_viewport_rect().size
	if cards_active:
		_draw_cards(s)
		return
	if not man.ui_visible():
		return
	if man.leader != null and man.leader.overlook_active:
		_draw_overlook(s)
		return
	if build != null and build.placing:
		_draw_build(s)
		return
	if panel != "":
		_draw_panel(s)
		return
	if man.is_leader and Flags.V3_UI:
		_draw_hud(s)


func _draw_cards(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.0, 1.0), true)
	if card_i >= cards.size():
		return
	var a: float = clampf(_card_t / 0.6, 0.0, 1.0)
	var w: float = minf(s.x - 120.0, 900.0)
	var text: String = str(cards[card_i])
	_mtxt(Vector2((s.x - w) * 0.5, s.y * 0.38), text, 30, Color(1, 1, 1, a), w, 9)
	_txt(Vector2(0.0, s.y - 60.0), "화면을 눌러 계속  (%d/%d)" % [card_i + 1, cards.size()], 20, Color(1, 1, 1, 0.5 * a), s.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_hud(s: Vector2) -> void:
	# 통치 버튼 (오른쪽, 확대/축소 버튼 아래)
	var c: Vector2 = Vector2(s.x - 48.0, 264.0)
	draw_circle(c, 31.0, Color(0.05, 0.12, 0.25, 0.65))
	draw_arc(c, 31.0, 0.0, TAU, 32, Color(1.0, 0.86, 0.45, 0.9), 2.5, true)
	_txt(Vector2(c.x - 31.0, c.y + 8.0), "통치", 22, Color(1.0, 0.92, 0.6), 62.0, HORIZONTAL_ALIGNMENT_CENTER)
	_hits.append({"rect": Rect2(c - Vector2(34, 34), Vector2(68, 68)), "id": "open"})
	if gov == null or gov.ind.is_empty():
		return
	# 지표 막대 (오른쪽 가운데)
	var x: float = s.x - 214.0
	var y: float = 316.0
	draw_rect(Rect2(x - 6.0, y - 4.0, 206.0, 6.0 * 26.0 + 8.0), Color(0, 0, 0, 0.38), true)
	for i in range(D.IND_KEYS.size()):
		var k: String = str(D.IND_KEYS[i])
		var v: float = gov.value(k)
		var ry: float = y + float(i) * 26.0
		_txt(Vector2(x, ry + 17.0), str(D.IND_SHORT[k]), 16, Color(1, 1, 1, 0.9))
		if k == "budget":
			_txt(Vector2(x + 44.0, ry + 17.0), _commas(int(v)), 17, _ind_color(k, v), 150.0)
		else:
			_bar(Rect2(x + 44.0, ry + 4.0, 110.0, 14.0), v / 100.0, _ind_color(k, v))
			_txt(Vector2(x + 158.0, ry + 17.0), "%d" % int(v), 16, Color(1, 1, 1, 0.9))


func _panel_rect(s: Vector2) -> Rect2:
	var w: float = minf(s.x - 40.0, 1040.0)
	var h: float = minf(s.y - 30.0, 640.0)
	return Rect2((s.x - w) * 0.5, (s.y - h) * 0.5, w, h)


func _draw_panel(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.5), true)
	var p: Rect2 = _panel_rect(s)
	draw_rect(p, Color(0.05, 0.06, 0.09, 0.97), true)
	draw_rect(p, Color(1.0, 0.86, 0.45, 0.55), false, 2.0)
	_txt(p.position + Vector2(18.0, 44.0), "통치", 30, Color(1.0, 0.86, 0.45))
	_btn(Rect2(p.position.x + p.size.x - 74.0, p.position.y + 8.0, 64.0, 52.0), "close", "X", 26)
	# 왼쪽 탭
	var th: float = minf(56.0, (p.size.y - 80.0) / float(TABS.size()) - 4.0)
	for i in range(TABS.size()):
		var tab: Dictionary = TABS[i]
		var r: Rect2 = Rect2(p.position.x + 10.0, p.position.y + 70.0 + float(i) * (th + 4.0), 152.0, th)
		var sel: bool = str(tab["id"]) == panel
		_btn(r, "tab:" + str(tab["id"]), str(tab["name"]), 19, true, Color(0.55, 0.40, 0.10) if sel else Color(0.14, 0.20, 0.30))
	var cx: float = p.position.x + 176.0
	var cy: float = p.position.y + 70.0
	var cw: float = p.size.x - 190.0
	var ch: float = p.size.y - 82.0
	var area: Rect2 = Rect2(cx, cy, cw, ch)
	match panel:
		"status":
			_tab_status(area)
		"budget":
			_tab_budget(area)
		"policy":
			_tab_policy(area)
		"city":
			_tab_city(area)
		"people":
			_tab_people(area)
		"meeting":
			_tab_meeting(area)
		"mission":
			_tab_mission(area)
		"save":
			_tab_save(area)
	if msg != "":
		_txt(Vector2(cx, p.position.y + p.size.y - 10.0), msg, 20, Color(1.0, 0.9, 0.5), cw)


# ---------------------------------------------------------------- 국가 현황

func _tab_status(a: Rect2) -> void:
	if gov == null or gov.ind.is_empty():
		_txt(a.position + Vector2(0, 40), "아직 국가를 운영하고 있지 않습니다.", 24, Color(1, 1, 1, 0.8))
		return
	_txt(a.position + Vector2(0, 26), "국가 현황 — %s" % man.route_name(), 24, Color(1.0, 0.9, 0.6))
	for i in range(D.IND_KEYS.size()):
		var k: String = str(D.IND_KEYS[i])
		var v: float = gov.value(k)
		var pv: float = float(gov.prev.get(k, v))
		var ry: float = a.position.y + 44.0 + float(i) * 46.0
		_txt(Vector2(a.position.x, ry + 28.0), str(D.IND_NAMES[k]), 22, Color(1, 1, 1, 0.95))
		if k == "budget":
			_txt(Vector2(a.position.x + 180.0, ry + 28.0), _commas(int(v)), 26, _ind_color(k, v), 300.0)
		else:
			_bar(Rect2(a.position.x + 180.0, ry + 8.0, 300.0, 26.0), v / 100.0, _ind_color(k, v))
			_txt(Vector2(a.position.x + 490.0, ry + 28.0), "%.1f" % v, 22, Color(1, 1, 1, 0.95))
		var dv: float = v - pv
		if absf(dv) >= 0.05 and k != "budget":
			_txt(Vector2(a.position.x + 570.0, ry + 28.0), "(%s%.1f)" % ["+" if dv > 0.0 else "", dv], 18, Color(0.5, 1.0, 0.6) if dv > 0.0 else Color(1.0, 0.55, 0.5))
		elif k == "budget" and absf(dv) >= 1.0:
			_txt(Vector2(a.position.x + 570.0, ry + 28.0), "(%s%d)" % ["+" if dv > 0.0 else "", int(dv)], 18, Color(0.5, 1.0, 0.6) if dv > 0.0 else Color(1.0, 0.55, 0.5))
	var iy: float = a.position.y + 44.0 + 6.0 * 46.0 + 6.0
	var line1: String = "정산 %d회 · 정산당 소득 %d / 지출 %d · 진행 중 정책 %d개 · 개발 시설 %d채" % [gov.tick_count, int(gov.last_income), int(gov.last_expense), gov.active.size(), build.count() if build != null else 0]
	_txt(Vector2(a.position.x, iy + 16.0), line1, 18, Color(0.85, 0.9, 1.0, 0.9), a.size.x)
	if not gov.last_notes.is_empty():
		_txt(Vector2(a.position.x, iy + 40.0), str(gov.last_notes[0]), 18, Color(1.0, 0.7, 0.5), a.size.x)
	# 특권 이동
	var by: float = a.position.y + a.size.y - 62.0
	var bw: float = (a.size.x - 24.0) / 4.0
	var ids: Array = ["office", "res", "car", "view"]
	var names: Array = ["집무실로", "사저로", "전용 차량", "도시 조망"]
	for i in range(4):
		_btn(Rect2(a.position.x + float(i) * (bw + 8.0), by, bw, 56.0), "go:" + str(ids[i]), str(names[i]), 21)


# ---------------------------------------------------------------- 국가 예산

func _tab_budget(a: Rect2) -> void:
	if gov == null or gov.ind.is_empty():
		return
	var pv: Dictionary = gov.preview()
	_txt(a.position + Vector2(0, 36), "국가 예산", 26, Color(1.0, 0.9, 0.6))
	_txt(a.position + Vector2(0, 84), _commas(int(gov.value("budget"))), 44, _ind_color("budget", gov.value("budget")), 400.0)
	_txt(a.position + Vector2(300, 60), "정산당 소득  +%d" % int(pv["income"]), 21, Color(0.6, 1.0, 0.7))
	_txt(a.position + Vector2(300, 88), "정산당 지출  -%d" % int(pv["expense"]), 21, Color(1.0, 0.7, 0.6))
	var net: int = int(pv["income"]) - int(pv["expense"])
	_txt(a.position + Vector2(560, 74), "순이익 %s%d" % ["+" if net >= 0 else "", net], 24, Color(0.6, 1.0, 0.7) if net >= 0 else Color(1.0, 0.6, 0.5))
	_txt(a.position + Vector2(0, 118), "다음 정산까지 약 %d초 · 소득은 경제·발전도·상점/공장에서, 지출은 기본비·예산 배분·건물 유지비에서 나옵니다." % int(gov.seconds_to_tick()), 16, Color(1, 1, 1, 0.65), a.size.x)
	var descs: Dictionary = {
		"welfare": "확대: 만족도↑ 식량 소모↑ / 축소: 만족도↓",
		"security": "확대: 안정도↑ 만족도 약간↓ / 축소: 안정도↓",
		"invest": "확대: 경제·발전도 천천히↑ / 축소: 정체",
	}
	for i in range(D.ALLOC_KEYS.size()):
		var k: String = str(D.ALLOC_KEYS[i])
		var ry: float = a.position.y + 140.0 + float(i) * 96.0
		draw_rect(Rect2(a.position.x, ry, a.size.x, 88.0), Color(1, 1, 1, 0.06), true)
		_txt(Vector2(a.position.x + 14.0, ry + 36.0), "%s 예산" % str(D.ALLOC_NAMES[k]), 26, Color(1, 1, 1, 0.96))
		_txt(Vector2(a.position.x + 14.0, ry + 68.0), str(descs[k]), 17, Color(1, 1, 1, 0.65), 460.0)
		var lv: int = int(gov.alloc.get(k, 1))
		var bx: float = a.position.x + a.size.x - 330.0
		_btn(Rect2(bx, ry + 12.0, 74.0, 64.0), "alloc:%s:-1" % k, "-", 32, lv > 0)
		draw_rect(Rect2(bx + 82.0, ry + 12.0, 94.0, 64.0), Color(0, 0, 0, 0.4), true)
		_txt(Vector2(bx + 82.0, ry + 52.0), str(D.ALLOC_LEVEL_NAMES[lv]), 24, Color(1.0, 0.9, 0.5), 94.0, HORIZONTAL_ALIGNMENT_CENTER)
		_btn(Rect2(bx + 184.0, ry + 12.0, 74.0, 64.0), "alloc:%s:1" % k, "+", 32, lv < 2)
		_txt(Vector2(bx + 262.0, ry + 52.0), "-%d" % int(D.ALLOC_COST_PER_LEVEL * float(lv)), 18, Color(1.0, 0.75, 0.6), 60.0)


# ---------------------------------------------------------------- 정책

func _tab_policy(a: Rect2) -> void:
	if gov == null or gov.ind.is_empty():
		return
	var cw: float = (a.size.x - 5.0 * 4.0) / 6.0
	for i in range(D.CATS.size()):
		var cat: Dictionary = D.CATS[i]
		_btn(Rect2(a.position.x + float(i) * (cw + 4.0), a.position.y, cw, 50.0), "pcat:%d" % i, str(cat["name"]), 18, true, Color(0.55, 0.40, 0.10) if i == poli_cat else Color(0.14, 0.20, 0.30))
	var cat_id: String = str(D.CATS[poli_cat]["id"])
	var row: int = 0
	for p in D.policies():
		if str(p["cat"]) != cat_id:
			continue
		var ry: float = a.position.y + 62.0 + float(row) * 104.0
		row += 1
		draw_rect(Rect2(a.position.x, ry, a.size.x, 96.0), Color(1, 1, 1, 0.06), true)
		var pid: String = str(p["id"])
		_txt(Vector2(a.position.x + 12.0, ry + 30.0), str(p["name"]), 24, Color(1.0, 0.92, 0.65))
		_mtxt(Vector2(a.position.x + 12.0, ry + 56.0), str(p["desc"]), 16, Color(1, 1, 1, 0.75), a.size.x - 200.0, 2)
		var eff: String = D.effect_line(p["instant"])
		var pt: String = D.effect_line(p["ptick"])
		var info: String = "비용 %d" % int(p["cost"])
		if eff != "":
			info += " · 즉시 " + eff
		if pt != "":
			info += " · 정산마다 " + pt + " (%d회)" % int(p["ticks"])
		_txt(Vector2(a.position.x + 12.0, ry + 88.0), info, 15, Color(0.7, 0.9, 1.0), a.size.x - 190.0)
		var st: String = gov.policy_state(pid)
		var can: bool = gov.can_exec(pid) == ""
		var br: Rect2 = Rect2(a.position.x + a.size.x - 170.0, ry + 20.0, 158.0, 58.0)
		if st != "":
			draw_rect(br, Color(0, 0, 0, 0.4), true)
			_txt(Vector2(br.position.x, br.position.y + 36.0), st, 19, Color(1.0, 0.85, 0.5), br.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_hits.append({"rect": br, "id": "pol:" + pid})
		else:
			_btn(br, "pol:" + pid, "시행", 24, can, Color(0.15, 0.40, 0.25))


# ---------------------------------------------------------------- 도시 개발

func _tab_city(a: Rect2) -> void:
	if gov == null or gov.ind.is_empty() or build == null:
		return
	_txt(a.position + Vector2(0, 30), "도시 개발 — 발전도 %.1f · 개발 시설 %d / %d채 · 예산 %s" % [gov.value("development"), build.count(), D.MAX_BUILDINGS, _commas(int(gov.value("budget")))], 20, Color(1.0, 0.9, 0.6), a.size.x)
	_txt(a.position + Vector2(0, 54), "고른 뒤 도시의 빈 땅으로 나가 위치를 정합니다. (큰길·광장·출입구 앞에는 지을 수 없음)", 16, Color(1, 1, 1, 0.65), a.size.x)
	var list: Array = D.buildings()
	var cols: int = 4
	var gap: float = 6.0
	var tw: float = (a.size.x - gap * float(cols - 1)) / float(cols)
	var th: float = 96.0
	for i in range(list.size()):
		var b: Dictionary = list[i]
		var col_i: int = i % cols
		var row_i: int = i / cols
		var r: Rect2 = Rect2(a.position.x + float(col_i) * (tw + gap), a.position.y + 68.0 + float(row_i) * (th + gap), tw, th)
		var ok: bool = float(gov.value("budget")) >= float(b["cost"])
		draw_rect(r, Color(0.14, 0.22, 0.32, 0.95) if ok else Color(0.16, 0.16, 0.18, 0.9), true)
		draw_rect(r, Color(1, 1, 1, 0.4 if ok else 0.15), false, 2.0)
		var fg: Color = Color(1, 1, 1, 0.96) if ok else Color(1, 1, 1, 0.45)
		_txt(Vector2(r.position.x + 8.0, r.position.y + 28.0), str(b["name"]), 21, fg, tw - 12.0)
		_txt(Vector2(r.position.x + 8.0, r.position.y + 54.0), "비용 %d · 유지 %d" % [int(b["cost"]), int(b["upkeep"])], 16, Color(1.0, 0.9, 0.55, 1.0 if ok else 0.4), tw - 12.0)
		_mtxt(Vector2(r.position.x + 8.0, r.position.y + 76.0), D.effect_line(b["instant"]), 14, Color(0.7, 0.95, 0.8, 1.0 if ok else 0.4), tw - 12.0, 1)
		_hits.append({"rect": r, "id": "bld:" + str(b["id"])})
	var by: float = a.position.y + a.size.y - 62.0
	_btn(Rect2(a.position.x, by, 240.0, 54.0), "demolish", "마지막 시설 철거", 19, build.count() > 0, Color(0.40, 0.20, 0.18))
	_txt(Vector2(a.position.x + 256.0, by + 34.0), "철거하면 건설비의 절반이 돌아옵니다.", 16, Color(1, 1, 1, 0.6), 420.0)


# ---------------------------------------------------------------- 주요 인물

func _tab_people(a: Rect2) -> void:
	if gov == null or gov.ind.is_empty():
		return
	var plist: Array = D.people()
	for i in range(plist.size()):
		var pe: Dictionary = plist[i]
		var pid: String = str(pe["id"])
		var r: Rect2 = Rect2(a.position.x, a.position.y + float(i) * 66.0, 340.0, 60.0)
		var sel: bool = pid == ppl_sel
		draw_rect(r, Color(0.35, 0.26, 0.08, 0.95) if sel else Color(0.14, 0.20, 0.30, 0.95), true)
		draw_rect(r, Color(1, 1, 1, 0.4), false, 2.0)
		_txt(Vector2(r.position.x + 10.0, r.position.y + 26.0), str(pe["name"]), 20, Color(1, 1, 1, 0.96), 320.0)
		var lv: int = gov.get_loyalty(pid)
		_bar(Rect2(r.position.x + 10.0, r.position.y + 36.0, 200.0, 16.0), float(lv) / 100.0, Color(0.95, 0.75, 0.3) if lv >= 30 else Color(0.95, 0.35, 0.3))
		_txt(Vector2(r.position.x + 218.0, r.position.y + 50.0), "충성 %d" % lv, 16, Color(1, 1, 1, 0.8), 110.0)
		_hits.append({"rect": r, "id": "ppl:" + pid})
	var rx: float = a.position.x + 356.0
	var rw: float = a.size.x - 356.0
	var sel_name: String = D.person_name(ppl_sel)
	_txt(Vector2(rx, a.position.y + 28.0), sel_name, 26, Color(1.0, 0.9, 0.6), rw)
	for pe2 in plist:
		if str(pe2["id"]) == ppl_sel:
			_txt(Vector2(rx, a.position.y + 54.0), str(pe2["role"]), 17, Color(1, 1, 1, 0.65), rw)
	var adv: String = D.advice(ppl_sel, gov.ind, gov.get_loyalty(ppl_sel))
	_mtxt(Vector2(rx, a.position.y + 100.0), "\"" + adv + "\"", 21, Color(1, 1, 1, 0.92), rw, 6)
	var by: float = a.position.y + 280.0
	var can_cheer: bool = gov.can_cheer(ppl_sel)
	_btn(Rect2(rx, by, 200.0, 58.0), "cheer:" + ppl_sel, "격려 (하루 1번)", 19, can_cheer, Color(0.15, 0.40, 0.25))
	_btn(Rect2(rx + 212.0, by, 200.0, 58.0), "gift:" + ppl_sel, "선물 (예산 -100)", 19, gov.value("budget") >= 100.0, Color(0.40, 0.30, 0.12))
	_mtxt(Vector2(rx, by + 90.0), "충성이 30 미만이면 그 분야 지표가 조금씩 나빠지고, 70을 넘으면 좋아집니다. 회의 선택과 대화로 바뀝니다.", 16, Color(1, 1, 1, 0.6), rw, 4)


# ---------------------------------------------------------------- 회의

func _tab_meeting(a: Rect2) -> void:
	if gov == null or gov.ind.is_empty():
		return
	var card: Dictionary = gov.current_card
	if card.is_empty():
		_txt(a.position + Vector2(0, 34), "회의", 26, Color(1.0, 0.9, 0.6))
		if gov.can_meet():
			_txt(a.position + Vector2(0, 76), "오늘의 안건이 준비되어 있습니다.", 21, Color(1, 1, 1, 0.9))
			_btn(Rect2(a.position.x, a.position.y + 100.0, 320.0, 72.0), "meet_open", "회의 소집", 28, true, Color(0.15, 0.40, 0.25))
		else:
			_txt(a.position + Vector2(0, 76), "오늘 회의는 이미 열었습니다. 하루가 지나면 새 안건이 올라옵니다.", 20, Color(1, 1, 1, 0.8), a.size.x)
		_txt(a.position + Vector2(0, 220), "지난 회의", 20, Color(1.0, 0.9, 0.6))
		var n: int = gov.meeting_log.size()
		for i in range(mini(n, 6)):
			var line: String = str(gov.meeting_log[n - 1 - i])
			_txt(Vector2(a.position.x, a.position.y + 250.0 + float(i) * 28.0), "· " + line, 18, Color(1, 1, 1, 0.75), a.size.x)
		return
	_txt(a.position + Vector2(0, 34), "안건: " + str(card["title"]), 26, Color(1.0, 0.9, 0.6), a.size.x)
	_mtxt(a.position + Vector2(0, 76), str(card["text"]), 21, Color(1, 1, 1, 0.92), a.size.x, 3)
	if bool(card.get("done", false)):
		_mtxt(a.position + Vector2(0, 190), "결과: " + str(card["result"]), 21, Color(0.7, 1.0, 0.8), a.size.x, 4)
		_btn(Rect2(a.position.x, a.position.y + 320.0, 260.0, 64.0), "meet_close", "회의 마치기", 24, true, Color(0.15, 0.40, 0.25))
		return
	var opts: Array = card["opts"]
	for i in range(opts.size()):
		var o: Dictionary = opts[i]
		var ry: float = a.position.y + 160.0 + float(i) * 96.0
		var need: float = -float(o["eff"].get("budget", 0.0))
		var ok: bool = not (need > 0.0 and need > gov.value("budget"))
		_btn(Rect2(a.position.x, ry, 260.0, 84.0), "meet:%d" % i, str(o["label"]), 22, ok, Color(0.18, 0.28, 0.40))
		_txt(Vector2(a.position.x + 276.0, ry + 36.0), D.effect_line(o["eff"]), 19, Color(0.75, 0.95, 1.0), a.size.x - 280.0)
		var loy: String = ""
		for pid in o["loy"].keys():
			var dv: int = int(o["loy"][pid])
			loy += "%s %s%d  " % [D.person_name(str(pid)).split(" ")[0] if D.person_name(str(pid)).find(" ") >= 0 else str(pid), "+" if dv > 0 else "", dv]
		_txt(Vector2(a.position.x + 276.0, ry + 66.0), "충성: " + loy, 15, Color(1, 1, 1, 0.5), a.size.x - 280.0)
	if str(card.get("result", "")) != "":
		_txt(Vector2(a.position.x, a.position.y + a.size.y - 20.0), str(card["result"]), 18, Color(1.0, 0.7, 0.5), a.size.x)


# ---------------------------------------------------------------- 임무

func _tab_mission(a: Rect2) -> void:
	var g = man.hub.game
	_txt(a.position + Vector2(0, 28), "스토리", 22, Color(1.0, 0.9, 0.6))
	var st: String = g.quest_state("q_v3_story")
	var story_line: String = "권력의 길: 완료 — 이야기는 이어집니다. (%s)" % man.route_name()
	if st == "active":
		story_line = "%s: %s" % [g.quest_title("q_v3_story"), g.quest_step_text("q_v3_story")]
	_mtxt(a.position + Vector2(0, 54), story_line, 18, Color(1, 1, 1, 0.9), a.size.x, 2)
	var aq: Array = g.active_quest_ids()
	var shown: int = 0
	for qid in aq:
		if str(qid) == "q_v3_story":
			continue
		if shown >= 2:
			break
		_txt(Vector2(a.position.x, a.position.y + 112.0 + float(shown) * 24.0), "· %s: %s" % [g.quest_title(str(qid)), g.quest_step_text(str(qid))], 16, Color(0.8, 0.9, 1.0, 0.85), a.size.x)
		shown += 1
	_txt(a.position + Vector2(0, 176), "국정 목표", 22, Color(1.0, 0.9, 0.6))
	if gov == null:
		return
	var goals: Array = D.goals()
	var half: int = (goals.size() + 1) / 2
	var cw: float = (a.size.x - 12.0) / 2.0
	for i in range(goals.size()):
		var gl: Dictionary = goals[i]
		var col_i: int = i / half
		var row_i: int = i % half
		var r: Rect2 = Rect2(a.position.x + float(col_i) * (cw + 12.0), a.position.y + 188.0 + float(row_i) * 54.0, cw, 50.0)
		var done: bool = gov.goals_done.has(str(gl["id"]))
		draw_rect(r, Color(0.10, 0.30, 0.18, 0.7) if done else Color(1, 1, 1, 0.06), true)
		var prog: float = gov.goal_progress(gl)
		var title: String = ("[완료] " if done else "") + str(gl["title"])
		_txt(Vector2(r.position.x + 8.0, r.position.y + 22.0), title, 17, Color(0.7, 1.0, 0.8) if done else Color(1, 1, 1, 0.9), cw - 90.0)
		var tg: float = float(gl["val"])
		_bar(Rect2(r.position.x + 8.0, r.position.y + 30.0, cw - 110.0, 12.0), prog / tg, Color(0.4, 0.8, 0.5) if done else Color(0.95, 0.75, 0.3))
		var rew: String = ("+%d" % int(gl["reward"])) if int(gl.get("reward", 0)) > 0 else "안정+3"
		_txt(Vector2(r.position.x + cw - 90.0, r.position.y + 40.0), "보상 " + rew, 14, Color(1.0, 0.9, 0.5, 0.9), 84.0)


# ---------------------------------------------------------------- 저장

func _tab_save(a: Rect2) -> void:
	_txt(a.position + Vector2(0, 34), "저장 · 불러오기", 26, Color(1.0, 0.9, 0.6))
	_btn(Rect2(a.position.x, a.position.y + 56.0, 300.0, 72.0), "save", "지금 저장하기", 26, true, Color(0.15, 0.40, 0.25))
	_btn(Rect2(a.position.x + 320.0, a.position.y + 56.0, 300.0, 72.0), "load", "불러오기", 26, true, Color(0.18, 0.28, 0.40))
	_mtxt(a.position + Vector2(0, 170), "저장되는 것: 지도자 상태, 스토리 진행, 국가 지표, 진행 중인 정책, 인물 충성도, 지은 건물, 회의 기록, 전용 차량 위치, 그리고 기존 게임 진행(소지품·임무·위치).\n자동 저장은 60초마다 이루어집니다. 불러오면 지도자 외형과 수행원도 함께 복원됩니다.", 18, Color(1, 1, 1, 0.75), a.size.x, 8)


# ---------------------------------------------------------------- 건설 / 조망 화면

func _draw_build(s: Vector2) -> void:
	var def: Dictionary = D.building_by_id(build.place_type)
	var title: String = "건설: %s  (비용 %d)" % [str(def.get("name", "")), int(def.get("cost", 0))]
	_pill(s.x * 0.5, 100.0, title, 22, Color(1.0, 0.95, 0.7), Color(0, 0, 0, 0.6))
	if build.ghost_ok:
		_pill(s.x * 0.5, 146.0, "건설할 수 있는 자리입니다. 걸어서 위치를 옮기세요.", 18, Color(0.7, 1.0, 0.75), Color(0, 0, 0, 0.55))
	else:
		_pill(s.x * 0.5, 146.0, str(build.ghost_reason), 18, Color(1.0, 0.7, 0.65), Color(0, 0, 0, 0.55))
	var y: float = s.y - 104.0
	var cx: float = s.x * 0.5
	_btn(Rect2(cx - 250.0, y, 200.0, 72.0), "b_ok", "건설 확정", 26, build.ghost_ok, Color(0.15, 0.45, 0.25))
	_btn(Rect2(cx - 40.0, y, 140.0, 72.0), "b_rot", "회전", 24)
	_btn(Rect2(cx + 110.0, y, 140.0, 72.0), "b_cancel", "끝내기", 24, true, Color(0.45, 0.20, 0.18))
	if msg != "":
		_pill(s.x * 0.5, 192.0, msg, 18, Color(1.0, 0.9, 0.5), Color(0.05, 0.1, 0.2, 0.7))


func _draw_overlook(s: Vector2) -> void:
	_pill(s.x * 0.5, 20.0, "도시 조망 — %s (화면을 끌면 돌아갑니다)" % str(man.leader.overlook_name()), 20, Color(1, 1, 1, 0.95), Color(0, 0, 0, 0.5))
	var y: float = s.y - 96.0
	var cx: float = s.x * 0.5
	_btn(Rect2(cx - 350.0, y, 160.0, 66.0), "ov_in", "가까이", 22)
	_btn(Rect2(cx - 180.0, y, 160.0, 66.0), "ov_out", "멀리", 22)
	_btn(Rect2(cx - 10.0, y, 180.0, 66.0), "ov_next", "다음 시점", 22)
	_btn(Rect2(cx + 180.0, y, 170.0, 66.0), "ov_close", "닫기", 22, true, Color(0.45, 0.20, 0.18))
	if gov != null and not gov.ind.is_empty():
		var parts: Array = []
		for k in D.IND_KEYS:
			parts.append("%s %s" % [str(D.IND_SHORT[k]), _fmt(str(k), gov.value(str(k)))])
		_pill(s.x * 0.5, 68.0, "  ".join(parts), 17, Color(1, 1, 1, 0.9), Color(0, 0, 0, 0.45))
