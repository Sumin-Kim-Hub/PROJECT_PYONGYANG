extends Node3D
## V2.2 새 지역을 만듭니다. 기존 도시는 그대로 두고, 바깥쪽 고리(±240m ~ ±380m)와 남쪽 광장을 더합니다.
##  - 남쪽 신도심 광장 + 신축 아파트 단지 + 강변 산책로(기존 강의 남쪽 둑)
##  - 서쪽 장마당 + 폐건물, 동쪽 판잣집 동네 + 배급소
##  - 북쪽 통제구역(검문소 A) + 군사시설(안쪽 문 B)
##  - 비밀 통로(맨홀) 입구 4곳, 폐건물/사령부 입구
## 지역마다 자체 노드를 두어 멀면 숨깁니다(거리 기반 활성화). 장식은 MultiMesh 로 묶어 그립니다.
## 모든 건물은 이 게임을 위한 가상의 구조물이며 실제 장소를 재현한 것이 아닙니다. (Godot 실행 미검증)

const Kit = preload("res://scripts/interior/interior_kit.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")
const NpcScript = preload("res://scripts/npc/npc.gd")
const VData = preload("res://scripts/v22/v22_data.gd")
const VNpcs = preload("res://scripts/v22/v22_npcs.gd")

const SLOT: float = 100.0
const BASE_Y: float = 300.0
const S_TUNNEL: int = 10
const S_RUINS: int = 11
const S_HQ: int = 12

var hub = null
var mgr = null
var world: Node3D = null
## {"name","node","center","radius"}
var regions: Array = []
## 목표 표시용 위치 {키: Vector3}
var poi_pos: Dictionary = {}
var npcs: Array = []
var walls_moved: int = 0
## 만들기가 끝났는지 (매니저가 기다림)
var done: bool = false
var npcs_done: bool = false

var _cur: Node3D = null
var _det = null
var _rng = RandomNumberGenerator.new()


# ---------------------------------------------------------------- 도우미

func _origin(slot: int) -> Vector3:
	return Vector3(float(slot) * SLOT, BASE_Y, 0.0)


func _begin(region_name: String, center: Vector3, radius: float) -> void:
	var r = Node3D.new()
	r.name = "V22_" + region_name
	add_child(r)
	_cur = r
	var ds = load("res://scripts/gfx/gfx_details.gd")
	if ds != null and ds.can_instantiate():
		_det = ds.new()
	else:
		_det = null
	regions.append({"name": region_name, "node": r, "center": center, "radius": radius})


func _end() -> void:
	if _det != null:
		_det.flush(_cur, "Deco")
	_det = null


## 충돌이 있는 상자 (center 는 상자의 가운데)
func _cb(pos: Vector3, size: Vector3, color: Color) -> Node3D:
	return Kit.box(_cur, pos, size, color, true, 1)


## 충돌 없는 장식 상자
func _db(pos: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	if _det != null:
		_det.box(pos, size, color, yaw)
	else:
		Kit.box(_cur, pos, size, color, false, 1)


func _dc(pos: Vector3, radius: float, height: float, color: Color) -> void:
	if _det != null:
		_det.cyl(pos, radius, height, color)
	else:
		Kit.box(_cur, pos, Vector3(radius * 2.0, height, radius * 2.0), color, false, 1)


func _ds(pos: Vector3, radii: Vector3, color: Color) -> void:
	if _det != null:
		_det.sphere(pos, radii, color)


func _lab(pos: Vector3, text: String, size: float, color: Color, yaw: float = 0.0) -> void:
	Kit.label(_cur, pos, text, size, color, 1, yaw)


func _poi(id: String, poi_name: String, pos: Vector3) -> void:
	poi_pos[id] = pos
	if hub != null:
		hub.register_poi("v22_" + id, poi_name, pos)


func _tree(x: float, z: float, h: float = 4.5) -> void:
	_dc(Vector3(x, h * 0.35, z), 0.22, h * 0.7, Color(0.30, 0.22, 0.16))
	_ds(Vector3(x, h * 0.85, z), Vector3(1.8, 1.5, 1.8), Color(0.22 + _rng.randf() * 0.06, 0.40 + _rng.randf() * 0.1, 0.22))


func _lamp_post(x: float, z: float) -> void:
	_dc(Vector3(x, 2.2, z), 0.08, 4.4, Color(0.25, 0.25, 0.28))
	_db(Vector3(x, 4.5, z), Vector3(0.5, 0.18, 0.5), Color(1.0, 0.95, 0.75))


func _interact(kind: String, prompt: String, pos: Vector3, radius: float, data: Dictionary, hide_flag: String = "", requires_flag: String = "", button: String = ""):
	var it = InteractableScript.new()
	it.kind = kind
	it.prompt = prompt
	it.radius = radius
	it.data = data
	it.hide_flag = hide_flag
	it.requires_flag = requires_flag
	it.button_text = button
	it.position = pos
	_cur.add_child(it)
	return it


## x 방향 벽 (z 고정). x0 < x1
func _wallx(x0: float, x1: float, z: float, h: float, t: float, color: Color) -> void:
	_cb(Vector3((x0 + x1) * 0.5, h * 0.5, z), Vector3(x1 - x0, h, t), color)
	_db(Vector3((x0 + x1) * 0.5, h + 0.12, z), Vector3(x1 - x0, 0.24, t + 0.2), Color(0.18, 0.18, 0.2))


## z 방향 벽 (x 고정). z0 < z1
func _wallz(x: float, z0: float, z1: float, h: float, t: float, color: Color) -> void:
	_cb(Vector3(x, h * 0.5, (z0 + z1) * 0.5), Vector3(t, h, z1 - z0), color)
	_db(Vector3(x, h + 0.12, (z0 + z1) * 0.5), Vector3(t + 0.2, 0.24, z1 - z0), Color(0.18, 0.18, 0.2))


# ---------------------------------------------------------------- 전체 만들기

func build(world_ref: Node3D, hub_ref, mgr_ref) -> void:
	world = world_ref
	hub = hub_ref
	mgr = mgr_ref
	_rng.seed = 2201
	_boundary()
	await get_tree().process_frame
	_south_square()
	await get_tree().process_frame
	_south_apartments()
	await get_tree().process_frame
	_riverside()
	await get_tree().process_frame
	_market()
	await get_tree().process_frame
	_ruins()
	await get_tree().process_frame
	_slum()
	await get_tree().process_frame
	_north_zone()
	await get_tree().process_frame
	_base()
	await get_tree().process_frame
	print("[PYONGYANG] V2.2 새 지역 %d곳을 만들었습니다 (경계 벽 이동 %d개)." % [regions.size(), walls_moved])
	done = true


## 기존 보이지 않는 경계 벽(±241m)을 ±381m 로 옮김. 못 찾으면 새 지역에 갈 수 없음
func _boundary() -> void:
	var lim: float = VData.MAP_LIMIT
	var span: float = lim * 2.0 + 4.0
	for c in world.get_children():
		if not (c is StaticBody3D):
			continue
		if c.get_child_count() != 1 or not (c.get_child(0) is CollisionShape3D):
			continue
		var shp = c.get_child(0).shape
		if not (shp is BoxShape3D):
			continue
		if absf(shp.size.y - 20.0) > 0.01:
			continue
		if absf(shp.size.z - 2.0) < 0.01 and shp.size.x > 100.0:
			c.position.z = signf(c.position.z) * (lim + 1.0)
			shp.size = Vector3(span, 20.0, 2.0)
			walls_moved += 1
		elif absf(shp.size.x - 2.0) < 0.01 and shp.size.z > 100.0:
			c.position.x = signf(c.position.x) * (lim + 1.0)
			shp.size = Vector3(2.0, 20.0, span)
			walls_moved += 1
	if walls_moved < 4:
		push_warning("V2.2: 기존 경계 벽을 %d개만 찾았습니다. 새 지역에 못 갈 수 있습니다." % walls_moved)


# ---------------------------------------------------------------- 1) 남쪽 신도심 광장

func _south_square() -> void:
	var c: Vector3 = Vector3(0.0, 0.0, 300.0)
	_begin("SouthSquare", c, 110.0)
	_db(Vector3(0.0, 0.07, 300.0), Vector3(130.0, 0.12, 70.0), Color(0.74, 0.73, 0.70))
	_db(Vector3(0.0, 0.09, 300.0), Vector3(44.0, 0.12, 44.0), Color(0.62, 0.60, 0.57))
	# 광장 연결 도로 (기존 남북 대로 끝에서 이어짐)
	_db(Vector3(0.0, 0.05, 252.0), Vector3(16.0, 0.08, 30.0), Color(0.16, 0.16, 0.17))
	# 기념탑 (이 도시의 가상 기념탑)
	_cb(Vector3(0.0, 0.6, 300.0), Vector3(12.0, 1.2, 12.0), Color(0.82, 0.80, 0.76))
	_cb(Vector3(0.0, 2.2, 300.0), Vector3(8.0, 2.0, 8.0), Color(0.78, 0.76, 0.72))
	_cb(Vector3(0.0, 14.2, 300.0), Vector3(3.2, 22.0, 3.2), Color(0.86, 0.84, 0.80))
	_db(Vector3(0.0, 26.8, 300.0), Vector3(7.0, 3.6, 0.5), Color(0.72, 0.10, 0.10))
	_db(Vector3(0.0, 26.8, 300.0), Vector3(0.5, 3.6, 7.0), Color(0.72, 0.10, 0.10))
	_lab(Vector3(0.0, 6.0, 297.8), "승리", 2.0, Color(0.95, 0.85, 0.5), PI)
	_lab(Vector3(0.0, 6.0, 302.2), "승리", 2.0, Color(0.95, 0.85, 0.5))
	# 선전 간판 (가상의 구호)
	for sx in [-46.0, 46.0]:
		_dc(Vector3(sx - 7.0, 2.5, 272.0), 0.12, 5.0, Color(0.3, 0.3, 0.32))
		_dc(Vector3(sx + 7.0, 2.5, 272.0), 0.12, 5.0, Color(0.3, 0.3, 0.32))
		_cb(Vector3(sx, 4.6, 272.0), Vector3(16.0, 3.4, 0.4), Color(0.66, 0.10, 0.10))
	_lab(Vector3(-46.0, 4.6, 271.7), "함께 건설하자", 1.6, Color(1.0, 0.95, 0.8), PI)
	_lab(Vector3(46.0, 4.6, 271.7), "전진하는 도시", 1.6, Color(1.0, 0.95, 0.8), PI)
	_lab(Vector3(-46.0, 4.6, 272.3), "함께 건설하자", 1.6, Color(1.0, 0.95, 0.8))
	_lab(Vector3(46.0, 4.6, 272.3), "전진하는 도시", 1.6, Color(1.0, 0.95, 0.8))
	# 양쪽 대형 건물
	_big_hall(Vector3(-80.0, 0.0, 306.0), "인민문화궁 (가상)", 1.0)
	_big_hall(Vector3(80.0, 0.0, 306.0), "과학기술회관 (가상)", -1.0)
	# 가로등, 나무, 벤치
	for k in range(-5, 6):
		_lamp_post(float(k) * 11.0, 268.0)
		_lamp_post(float(k) * 11.0, 332.0)
	for k2 in range(0, 14):
		_tree(-62.0 + float(k2) * 9.5, 336.0)
	for bx in [-22.0, 22.0]:
		_cb(Vector3(bx, 0.3, 312.0), Vector3(3.0, 0.6, 0.8), Color(0.45, 0.32, 0.2))
	_poi("south_square", "신도심 광장", Vector3(0.0, 0.0, 280.0))
	_poi("south_square_c", "승리 기념탑", Vector3(0.0, 0.0, 308.0))
	_end()


## 정면이 광장 쪽(dir>0 이면 +x 쪽)을 향한 대형 건물
func _big_hall(pos: Vector3, label_text: String, dir: float) -> void:
	_cb(pos + Vector3(0.0, 11.0, 0.0), Vector3(36.0, 22.0, 22.0), Color(0.78, 0.74, 0.66))
	_db(pos + Vector3(0.0, 22.4, 0.0), Vector3(38.0, 0.8, 24.0), Color(0.40, 0.36, 0.34))
	var fx: float = pos.x + dir * 18.2
	for i in range(-4, 5):
		_dc(Vector3(fx + dir * 1.2, 5.0, pos.z + float(i) * 2.4), 0.45, 10.0, Color(0.88, 0.86, 0.80))
	_db(Vector3(fx + dir * 0.1, 15.0, pos.z), Vector3(0.4, 9.0, 16.0), Color(0.68, 0.10, 0.10))
	for r in range(0, 3):
		for cc in range(-3, 4):
			_db(Vector3(fx + dir * 0.1, 3.0 + float(r) * 3.4, pos.z + float(cc) * 2.6), Vector3(0.2, 1.8, 1.4), Color(0.16, 0.22, 0.30))
	_lab(Vector3(fx + dir * 0.4, 15.0, pos.z), label_text, 1.5, Color(1.0, 0.92, 0.7), dir * PI * 0.5)
	# 입구 계단
	_db(Vector3(fx + dir * 2.0, 0.3, pos.z), Vector3(4.0, 0.6, 10.0), Color(0.7, 0.7, 0.68))


# ---------------------------------------------------------------- 2) 남동쪽 신축 아파트 단지

func _south_apartments() -> void:
	var c: Vector3 = Vector3(195.0, 0.0, 300.0)
	_begin("SouthApts", c, 90.0)
	_db(Vector3(195.0, 0.06, 300.0), Vector3(100.0, 0.1, 100.0), Color(0.55, 0.55, 0.52))
	var cols: Array = [Color(0.80, 0.78, 0.70), Color(0.66, 0.72, 0.78), Color(0.78, 0.70, 0.66)]
	var n: int = 0
	for ix in range(2):
		for iz in range(3):
			var px: float = 168.0 + float(ix) * 54.0
			var pz: float = 262.0 + float(iz) * 38.0
			var col: Color = cols[n % 3]
			n += 1
			_cb(Vector3(px, 13.0, pz), Vector3(34.0, 26.0, 12.0), col)
			_db(Vector3(px, 26.3, pz), Vector3(35.0, 0.7, 13.0), Color(0.62, 0.14, 0.12))
			# 창문 줄 (남/북 면)
			for fl in range(0, 7):
				for wc in range(-7, 8):
					var wx: float = px + float(wc) * 2.2
					var wy: float = 3.0 + float(fl) * 3.5
					_db(Vector3(wx, wy, pz + 6.06), Vector3(1.2, 1.6, 0.1), Color(0.16, 0.22, 0.32))
					_db(Vector3(wx, wy, pz - 6.06), Vector3(1.2, 1.6, 0.1), Color(0.16, 0.22, 0.32))
			_db(Vector3(px, 1.2, pz + 6.1), Vector3(3.0, 2.4, 0.2), Color(0.2, 0.14, 0.1))
	# 놀이터와 나무
	_cb(Vector3(150.0, 0.5, 322.0), Vector3(4.0, 1.0, 4.0), Color(0.6, 0.5, 0.2))
	_dc(Vector3(156.0, 1.2, 322.0), 0.08, 2.4, Color(0.8, 0.2, 0.2))
	for t in range(0, 8):
		_tree(150.0 + float(t) * 12.0, 345.0)
	_lab(Vector3(195.0, 7.0, 255.0), "신축 아파트 단지", 1.6, Color(1.0, 0.95, 0.8), PI)
	_poi("south_apts", "신축 아파트 단지", Vector3(195.0, 0.0, 285.0))
	_end()


# ---------------------------------------------------------------- 3) 강변 산책로 (기존 강의 남쪽 둑)

func _riverside() -> void:
	_begin("Riverside", Vector3(0.0, 0.0, -136.0), 260.0)
	for seg in [[-235.0, -90.0], [90.0, 235.0]]:
		var a: float = seg[0]
		var b: float = seg[1]
		var cx: float = (a + b) * 0.5
		_db(Vector3(cx, 0.1, -135.5), Vector3(b - a, 0.12, 6.0), Color(0.70, 0.66, 0.58))
		var x: float = a + 8.0
		while x < b:
			_lamp_post(x, -132.0)
			if int(x) % 3 == 0:
				_cb(Vector3(x + 5.0, 0.28, -137.5), Vector3(2.2, 0.56, 0.7), Color(0.45, 0.32, 0.2))
			_tree(x + 10.0, -129.0, 5.5)
			x += 26.0
	# 낚시꾼 마씨 자리: 둑 옆 낚싯대
	_dc(Vector3(-158.0, 1.2, -139.0), 0.03, 2.4, Color(0.3, 0.2, 0.1))
	_cb(Vector3(-162.0, 0.35, -136.0), Vector3(0.8, 0.7, 0.6), Color(0.35, 0.3, 0.22))
	_lab(Vector3(-160.0, 3.4, -135.0), "강변 산책로", 1.2, Color(1.0, 0.95, 0.8), PI)
	# 하수 배출구 (비밀 통로 출구: 안에서 열기 전에는 숨김)
	_db(Vector3(-192.0, 0.25, -138.0), Vector3(2.4, 0.5, 2.4), Color(0.2, 0.2, 0.22))
	_dc(Vector3(-192.0, 0.45, -138.0), 0.9, 0.12, Color(0.12, 0.12, 0.14))
	var dest: Vector3 = _origin(S_TUNNEL) + Vector3(-8.0, 0.1, -17.4)
	_interact("enter", "배수구 철망 열기 (지하 통로)", Vector3(-192.0, 1.0, -138.0), 2.4,
		{"dest": dest, "dest_yaw": -PI * 0.5, "location": "비밀 지하 통로", "effects": []}, "", "tunnel_exit_river")
	_interact("examine", "배수구 철망 살펴보기", Vector3(-192.0, 1.0, -138.0), 2.2,
		{"text": "녹슨 철망 틈으로 서늘한 바람이 올라온다. 안쪽에서만 열리는 것 같다.", "effects": [], "once_flag": ""}, "tunnel_exit_river")
	_poi("riverside", "강변 산책로", Vector3(-150.0, 0.0, -134.0))
	_poi("river_outlet", "하수 배출구", Vector3(-192.0, 0.0, -136.0))
	_end()


# ---------------------------------------------------------------- 4) 서쪽 장마당

func _market() -> void:
	var c: Vector3 = Vector3(-300.0, 0.0, 10.0)
	_begin("Market", c, 75.0)
	_db(Vector3(-300.0, 0.06, 12.0), Vector3(84.0, 0.1, 74.0), Color(0.58, 0.52, 0.42))
	# 입구 간판
	_dc(Vector3(-258.0, 2.6, 6.0), 0.18, 5.2, Color(0.3, 0.22, 0.16))
	_dc(Vector3(-258.0, 2.6, 18.0), 0.18, 5.2, Color(0.3, 0.22, 0.16))
	_db(Vector3(-258.0, 5.2, 12.0), Vector3(0.4, 1.4, 14.0), Color(0.62, 0.12, 0.10))
	_lab(Vector3(-257.6, 5.2, 12.0), "장마당", 2.0, Color(1.0, 0.95, 0.8), PI * 0.5)
	# 노점 3줄
	var cloth: Array = [Color(0.72, 0.3, 0.25), Color(0.3, 0.45, 0.6), Color(0.75, 0.62, 0.25), Color(0.4, 0.55, 0.35), Color(0.6, 0.4, 0.55)]
	var n: int = 0
	for row in range(3):
		var z: float = -14.0 + float(row) * 22.0
		for col in range(6):
			var x: float = -332.0 + float(col) * 11.0
			if row == 1 and col == 3:
				continue
			_cb(Vector3(x, 0.5, z), Vector3(3.0, 1.0, 1.4), Color(0.45, 0.34, 0.22))
			_db(Vector3(x, 2.5, z), Vector3(3.8, 0.12, 2.6), cloth[n % cloth.size()])
			_dc(Vector3(x - 1.7, 1.25, z - 1.0), 0.06, 2.5, Color(0.3, 0.25, 0.2))
			_dc(Vector3(x + 1.7, 1.25, z - 1.0), 0.06, 2.5, Color(0.3, 0.25, 0.2))
			_db(Vector3(x - 0.7, 1.15, z), Vector3(0.7, 0.3, 0.6), cloth[(n + 2) % cloth.size()])
			_db(Vector3(x + 0.6, 1.1, z), Vector3(0.5, 0.2, 0.5), Color(0.8, 0.7, 0.4))
			n += 1
	# 한옥분의 큰 노점 (가운데)
	_cb(Vector3(-299.0, 0.55, 8.0), Vector3(4.4, 1.1, 1.6), Color(0.5, 0.36, 0.22))
	_db(Vector3(-299.0, 2.7, 8.0), Vector3(5.2, 0.14, 3.0), Color(0.62, 0.12, 0.10))
	_dc(Vector3(-301.2, 1.35, 7.0), 0.07, 2.7, Color(0.3, 0.25, 0.2))
	_dc(Vector3(-296.8, 1.35, 7.0), 0.07, 2.7, Color(0.3, 0.25, 0.2))
	_interact("pickup", "한옥분 노점 위의 장부 한 장", Vector3(-299.0, 1.2, 8.8), 2.0,
		{"item": "clue_c", "text": "'칠일장이 열리는 날'이라는 메모가 붙은 장부 한 장. 마지막 줄에 큰 글씨로 7이 적혀 있다. (암호 단서)", "flag": "pk_clue_c", "effects": []},
		"pk_clue_c", "intel_code")
	# 게시판
	_cb(Vector3(-264.0, 1.2, -30.0), Vector3(4.0, 2.4, 0.3), Color(0.5, 0.4, 0.3))
	_interact("examine", "장마당 게시판 읽기", Vector3(-264.0, 1.0, -28.5), 2.4,
		{"text": "'칠일장: 7일마다 큰 장이 섭니다.' '배급표 교환 금지.' 가장자리에는 '창고 뒤 바닥을 조심할 것'이라는 낙서가 적혀 있다.", "effects": [{"op": "v22_intel", "key": "manhole"}], "once_flag": ""})
	# 뒤쪽 창고 (한쪽이 열린 □ 모양)
	_cb(Vector3(-320.0, 2.0, 56.0), Vector3(16.0, 4.0, 0.5), Color(0.40, 0.38, 0.34))
	_cb(Vector3(-328.0, 2.0, 50.0), Vector3(0.5, 4.0, 12.0), Color(0.40, 0.38, 0.34))
	_cb(Vector3(-312.0, 2.0, 50.0), Vector3(0.5, 4.0, 12.0), Color(0.40, 0.38, 0.34))
	_db(Vector3(-320.0, 4.2, 50.0), Vector3(17.0, 0.4, 13.0), Color(0.34, 0.24, 0.2))
	_cb(Vector3(-325.0, 0.6, 53.0), Vector3(1.4, 1.2, 1.4), Color(0.5, 0.4, 0.28))
	_cb(Vector3(-315.0, 0.5, 54.0), Vector3(1.2, 1.0, 1.2), Color(0.45, 0.36, 0.25))
	_cb(Vector3(-322.0, 0.4, 44.0), Vector3(0.9, 0.8, 0.9), Color(0.5, 0.4, 0.28))
	_lab(Vector3(-320.0, 3.4, 43.6), "창고", 1.0, Color(0.9, 0.85, 0.7), PI)
	# 맨홀 (비밀 통로 입구)
	var mh: Vector3 = Vector3(-318.0, 0.0, 49.0)
	_dc(mh + Vector3(0.0, 0.07, 0.0), 0.8, 0.12, Color(0.18, 0.18, 0.2))
	_interact("examine", "낡은 맨홀 덮개 살펴보기", mh + Vector3(0.0, 1.0, 0.0), 2.0,
		{"text": "바닥에 둥근 쇠 덮개가 묻혀 있다. 가장자리에 최근 긁힌 자국이 있고, 틈 사이로 서늘한 바람이 올라온다. 아래로 내려갈 수 있을 것 같다.", "effects": [{"op": "v22_intel", "key": "manhole"}], "once_flag": ""}, "intel_manhole")
	_interact("enter", "맨홀 아래로 내려가기", mh + Vector3(0.0, 1.0, 0.0), 2.2,
		{"dest": _origin(S_TUNNEL) + Vector3(0.0, 0.1, 1.4), "dest_yaw": 0.0, "location": "비밀 지하 통로",
			"effects": [{"op": "quest_step", "id": "q_v22_pass", "step": 3, "if": {"quest": "q_v22_pass", "state": "active", "min_step": 2}}]},
		"", "intel_manhole")
	_poi("market", "장마당", Vector3(-286.0, 0.0, 8.0))
	_poi("manhole", "창고 뒤 맨홀", Vector3(-318.0, 0.0, 46.0))
	# 나무와 가로등
	for t in range(0, 6):
		_lamp_post(-330.0 + float(t) * 14.0, 36.0)
	_end()


# ---------------------------------------------------------------- 5) 폐건물

func _ruins() -> void:
	var c: Vector3 = Vector3(-300.0, 0.0, 95.0)
	_begin("Ruins", c, 60.0)
	# 폐건물 A (들어갈 수 있음): 어둡고 낡은 색, 군데군데 비어 있는 창문
	var bpos: Vector3 = Vector3(-310.0, 0.0, 100.0)
	_cb(bpos + Vector3(0.0, 8.0, 0.0), Vector3(20.0, 16.0, 12.0), Color(0.42, 0.40, 0.38))
	_db(bpos + Vector3(-4.0, 16.3, 0.0), Vector3(12.0, 0.8, 13.0), Color(0.30, 0.28, 0.27))
	for fl in range(0, 4):
		for cc in range(-4, 5):
			var broken: bool = (fl * 7 + cc * 3) % 4 == 0
			var col: Color = Color(0.08, 0.08, 0.1) if broken else Color(0.20, 0.24, 0.28)
			_db(bpos + Vector3(float(cc) * 2.1, 3.0 + float(fl) * 3.5, 6.06), Vector3(1.2, 1.7, 0.1), col)
	_db(bpos + Vector3(0.0, 1.2, 6.1), Vector3(2.4, 2.4, 0.2), Color(0.10, 0.08, 0.07))
	_lab(bpos + Vector3(0.0, 5.6, 6.3), "출입 금지", 1.2, Color(0.9, 0.3, 0.25))
	# 무너진 폐건물 B
	var bp2: Vector3 = Vector3(-270.0, 0.0, 108.0)
	_cb(bp2 + Vector3(0.0, 3.0, 0.0), Vector3(14.0, 6.0, 10.0), Color(0.46, 0.43, 0.40))
	_db(bp2 + Vector3(4.0, 7.5, 0.0), Vector3(5.0, 3.0, 9.0), Color(0.40, 0.37, 0.35), 0.1)
	_cb(bp2 + Vector3(-9.0, 0.5, 6.0), Vector3(3.0, 1.0, 2.0), Color(0.5, 0.45, 0.4))
	_cb(bp2 + Vector3(-6.0, 0.4, 8.0), Vector3(2.0, 0.8, 3.0), Color(0.45, 0.4, 0.36))
	# 녹슨 자동차, 잔해, 불 피운 통
	_cb(Vector3(-292.0, 0.7, 118.0), Vector3(4.2, 1.4, 1.9), Color(0.5, 0.3, 0.2))
	_db(Vector3(-292.0, 1.6, 118.0), Vector3(2.4, 0.8, 1.7), Color(0.38, 0.26, 0.2))
	_cb(Vector3(-286.0, 0.5, 80.0), Vector3(0.9, 1.0, 0.9), Color(0.3, 0.3, 0.32))
	_db(Vector3(-286.0, 1.05, 80.0), Vector3(0.5, 0.2, 0.5), Color(1.0, 0.55, 0.2))
	# 낡은 철조망 담
	_wallx(-322.0, -258.0, 128.0, 2.0, 0.3, Color(0.35, 0.34, 0.32))
	# 입구
	_interact("enter", "폐건물 입장", bpos + Vector3(0.0, 1.0, 8.4), 2.6,
		{"dest": _origin(S_RUINS) + Vector3(0.0, 0.1, 3.0), "dest_yaw": 0.0, "location": "버려진 건물",
			"effects": [{"op": "set_flag", "key": "visited_ruins"}, {"op": "quest_step", "id": "q_v22_ruins", "step": 1, "if": {"quest": "q_v22_ruins", "state": "active"}}]})
	_poi("ruins", "버려진 건물", bpos + Vector3(0.0, 0.0, 14.0))
	for t in range(0, 5):
		_tree(-330.0 + float(t) * 15.0, 120.0, 3.5)
	_end()


# ---------------------------------------------------------------- 6) 동쪽 판잣집 동네와 배급소

func _slum() -> void:
	var c: Vector3 = Vector3(310.0, 0.0, 20.0)
	_begin("Slum", c, 100.0)
	_db(Vector3(310.0, 0.06, 20.0), Vector3(110.0, 0.1, 150.0), Color(0.48, 0.42, 0.34))
	var rust: Array = [Color(0.52, 0.30, 0.20), Color(0.46, 0.34, 0.26), Color(0.40, 0.40, 0.38), Color(0.55, 0.42, 0.30)]
	var n: int = 0
	for row in range(5):
		for col in range(6):
			var x: float = 276.0 + float(col) * 14.0 + _rng.randf_range(-2.0, 2.0)
			var z: float = -40.0 + float(row) * 26.0 + _rng.randf_range(-3.0, 3.0)
			if col == 2 and row == 1:
				continue
			var w: float = 3.2 + _rng.randf() * 1.6
			var d: float = 3.0 + _rng.randf() * 1.4
			var h: float = 2.2 + _rng.randf() * 0.7
			_cb(Vector3(x, h * 0.5, z), Vector3(w, h, d), rust[n % rust.size()])
			_db(Vector3(x, h + 0.12, z), Vector3(w + 0.8, 0.2, d + 0.8), Color(0.34, 0.26, 0.22))
			_db(Vector3(x, 1.0, z + d * 0.5 + 0.06), Vector3(0.9, 1.9, 0.1), Color(0.14, 0.1, 0.08))
			if n % 3 == 0:
				_db(Vector3(x + w * 0.5 + 1.6, 0.6, z + 1.0), Vector3(2.0, 1.2, 1.6), Color(0.45, 0.4, 0.32))
			n += 1
	# 빨랫줄
	for k in range(4):
		var lz: float = -28.0 + float(k) * 40.0
		_dc(Vector3(282.0, 1.6, lz), 0.05, 3.2, Color(0.3, 0.28, 0.25))
		_dc(Vector3(354.0, 1.6, lz), 0.05, 3.2, Color(0.3, 0.28, 0.25))
		_db(Vector3(318.0, 3.0, lz), Vector3(72.0, 0.04, 0.04), Color(0.6, 0.6, 0.6))
		for q in range(8):
			var cc: Color = [Color(0.8, 0.8, 0.75), Color(0.5, 0.6, 0.7), Color(0.7, 0.45, 0.4)][q % 3]
			_db(Vector3(288.0 + float(q) * 8.0, 2.5, lz), Vector3(1.2, 1.0, 0.05), cc)
	# 불 피운 통과 물탱크
	for fp in [Vector3(300.0, 0.0, -2.0), Vector3(330.0, 0.0, 24.0), Vector3(312.0, 0.0, 52.0)]:
		_cb(fp + Vector3(0.0, 0.5, 0.0), Vector3(0.8, 1.0, 0.8), Color(0.3, 0.3, 0.32))
		_db(fp + Vector3(0.0, 1.05, 0.0), Vector3(0.5, 0.15, 0.5), Color(1.0, 0.5, 0.18))
	_dc(Vector3(348.0, 4.0, -40.0), 1.6, 3.0, Color(0.4, 0.45, 0.5))
	for lx in [-1.4, 1.4]:
		_dc(Vector3(348.0 + lx, 1.2, -40.0 + lx * 0.5), 0.1, 2.4, Color(0.3, 0.3, 0.3))
	# 배급소
	var rp: Vector3 = Vector3(262.0, 0.0, 30.0)
	_cb(rp + Vector3(0.0, 2.5, 0.0), Vector3(9.0, 5.0, 14.0), Color(0.60, 0.58, 0.50))
	_db(rp + Vector3(0.0, 5.2, 0.0), Vector3(10.0, 0.5, 15.0), Color(0.34, 0.30, 0.28))
	_cb(rp + Vector3(5.5, 0.6, 0.0), Vector3(1.4, 1.2, 8.0), Color(0.45, 0.34, 0.22))
	_db(rp + Vector3(5.2, 3.0, 0.0), Vector3(3.2, 0.14, 9.0), Color(0.4, 0.42, 0.40))
	_lab(rp + Vector3(4.6, 4.2, 0.0), "배급소", 1.6, Color(1.0, 0.95, 0.8), PI * 0.5)
	for k in range(6):
		_db(Vector3(266.0 + float(k) * 2.4, 0.07, 52.0), Vector3(1.2, 0.04, 0.4), Color(0.9, 0.85, 0.3))
	# 빈민촌 숨겨진 상자 (탐험 보상)
	_cb(Vector3(350.0, 0.4, 80.0), Vector3(1.2, 0.8, 0.8), Color(0.36, 0.3, 0.22))
	_interact("pickup", "숨겨진 나무 상자", Vector3(350.0, 1.0, 80.0), 2.0,
		{"item": "medicine", "text": "판잣집 뒤에 감춰진 상자 안에 약품 상자가 하나 남아 있다. 누군가 급할 때 쓰려고 숨겨 둔 모양이다.", "flag": "pk_medicine_slum", "effects": []},
		"pk_medicine_slum")
	_poi("slum", "외곽 주거지", Vector3(300.0, 0.0, 10.0))
	_poi("ration", "배급소", Vector3(258.0, 0.0, 42.0))
	_end()


# ---------------------------------------------------------------- 7) 북쪽 통제구역 (검문소 A)

## 검문소 하나를 만듭니다. z 위치의 가운데(x=0) 차선을 차단기로 막고, 양옆에 초소를 둡니다.
func _checkpoint(id: String, level: int, gate_name: String, z: float, lane: float) -> void:
	var body_col: Color = Color(0.40, 0.44, 0.38)
	_cb(Vector3(-lane - 3.0, 1.8, z), Vector3(5.0, 3.6, 4.0), body_col)
	_cb(Vector3(lane + 3.0, 1.8, z), Vector3(5.0, 3.6, 4.0), body_col)
	_db(Vector3(-lane - 3.0, 3.8, z), Vector3(5.8, 0.4, 4.8), Color(0.24, 0.26, 0.24))
	_db(Vector3(lane + 3.0, 3.8, z), Vector3(5.8, 0.4, 4.8), Color(0.24, 0.26, 0.24))
	_db(Vector3(-lane - 3.0, 2.2, z + 2.06), Vector3(2.4, 1.2, 0.1), Color(0.16, 0.22, 0.28))
	_db(Vector3(lane + 3.0, 2.2, z + 2.06), Vector3(2.4, 1.2, 0.1), Color(0.16, 0.22, 0.28))
	# 차선 위쪽 간판
	_dc(Vector3(-lane - 0.5, 3.0, z), 0.12, 6.0, Color(0.3, 0.3, 0.32))
	_dc(Vector3(lane + 0.5, 3.0, z), 0.12, 6.0, Color(0.3, 0.3, 0.32))
	_db(Vector3(0.0, 6.0, z), Vector3(lane * 2.0 + 1.2, 1.8, 0.4), Color(0.62, 0.10, 0.10))
	var sign_text: String = "통제구역 · 통행증 확인" if level <= 1 else "군사시설 · 특별 통행증"
	_lab(Vector3(0.0, 6.0, z + 0.3), sign_text, 1.6, Color(1.0, 0.95, 0.8))
	_lab(Vector3(0.0, 6.0, z - 0.3), sign_text, 1.6, Color(1.0, 0.95, 0.8), PI)
	# 차단기: 충돌 몸체(열리면 충돌 끔) + 줄무늬 팔
	var body = StaticBody3D.new()
	body.position = Vector3(0.0, 2.0, z)
	var cs = CollisionShape3D.new()
	var shp = BoxShape3D.new()
	shp.size = Vector3(lane * 2.0, 4.0, 0.5)
	cs.shape = shp
	body.add_child(cs)
	_cur.add_child(body)
	var arm = Node3D.new()
	arm.position = Vector3(-lane, 1.1, z)
	_cur.add_child(arm)
	var segs: int = 8
	for i in range(segs):
		var col: Color = Color(0.9, 0.9, 0.9) if i % 2 == 0 else Color(0.78, 0.12, 0.10)
		var seg_w: float = lane * 2.0 / float(segs)
		Kit.box(arm, Vector3(seg_w * (float(i) + 0.5), 0.0, 0.0), Vector3(seg_w, 0.22, 0.22), col, false, 1)
	if mgr != null and mgr.pass_sys != null:
		mgr.pass_sys.register_gate(id, level, gate_name, Vector3(0.0, 0.0, z), body, arm)
	_poi("gate_" + id, gate_name, Vector3(0.0, 0.0, z + 8.0))


func _north_zone() -> void:
	var lim: float = VData.MAP_LIMIT
	_begin("NorthZone", Vector3(0.0, 0.0, -310.0), 190.0)
	var wc: Color = Color(0.42, 0.44, 0.40)
	# 통제구역 바깥 담: z=-250. 가운데 차선(±7)만 비움
	_wallx(-lim, -7.0, -250.0, 3.4, 0.6, wc)
	_wallx(7.0, lim, -250.0, 3.4, 0.6, wc)
	# 도로 (검문소에서 군사시설까지)
	_db(Vector3(0.0, 0.05, -250.0), Vector3(14.0, 0.08, 130.0), Color(0.16, 0.16, 0.17))
	_db(Vector3(0.0, 0.05, -300.0), Vector3(14.0, 0.08, 40.0), Color(0.16, 0.16, 0.17))
	_checkpoint("north", 1, "북부 검문소", -250.0, 7.0)
	# 담 앞쪽(바깥) 보급 초소 + 가림막
	_cb(Vector3(-30.0, 1.6, -240.0), Vector3(7.0, 3.2, 5.0), Color(0.46, 0.42, 0.34))
	_db(Vector3(-30.0, 3.4, -240.0), Vector3(8.0, 0.4, 6.0), Color(0.3, 0.26, 0.22))
	_lab(Vector3(-30.0, 2.2, -237.3), "보급 초소", 0.9, Color(1.0, 0.95, 0.8), PI)
	for k in range(5):
		_cb(Vector3(-36.0 + float(k) * 1.5, 0.45, -234.0), Vector3(1.0, 0.9, 1.0), Color(0.5, 0.42, 0.28))
	# 담 안쪽 구역: 창고, 통신탑, 감시탑, 연락장교 사무소
	_cb(Vector3(-70.0, 4.0, -285.0), Vector3(30.0, 8.0, 14.0), Color(0.46, 0.46, 0.42))
	_db(Vector3(-70.0, 8.3, -285.0), Vector3(31.0, 0.6, 15.0), Color(0.28, 0.28, 0.28))
	_cb(Vector3(80.0, 4.0, -280.0), Vector3(26.0, 8.0, 16.0), Color(0.44, 0.44, 0.40))
	_db(Vector3(80.0, 8.3, -280.0), Vector3(27.0, 0.6, 17.0), Color(0.28, 0.28, 0.28))
	_cb(Vector3(-30.0, 2.0, -292.0), Vector3(8.0, 4.0, 6.0), Color(0.40, 0.46, 0.38))
	_lab(Vector3(-30.0, 3.0, -288.8), "연락 사무소", 0.9, Color(1.0, 0.95, 0.8), PI)
	_dc(Vector3(-120.0, 15.0, -262.0), 0.3, 30.0, Color(0.55, 0.55, 0.58))
	_db(Vector3(-120.0, 24.0, -262.0), Vector3(6.0, 0.2, 0.2), Color(0.55, 0.55, 0.58))
	_db(Vector3(-120.0, 18.0, -262.0), Vector3(4.0, 0.2, 0.2), Color(0.55, 0.55, 0.58))
	_db(Vector3(-120.0, 30.4, -262.0), Vector3(0.6, 0.6, 0.6), Color(1.0, 0.2, 0.2))
	for tp in [Vector3(-45.0, 0.0, -258.0), Vector3(45.0, 0.0, -258.0), Vector3(-150.0, 0.0, -300.0), Vector3(150.0, 0.0, -300.0)]:
		for dx in [-1.5, 1.5]:
			for dz in [-1.5, 1.5]:
				_dc(tp + Vector3(dx, 3.0, dz), 0.12, 6.0, Color(0.32, 0.30, 0.26))
		_cb(tp + Vector3(0.0, 6.6, 0.0), Vector3(4.2, 2.0, 4.2), Color(0.34, 0.36, 0.30))
		_db(tp + Vector3(0.0, 7.8, 0.0), Vector3(4.8, 0.3, 4.8), Color(0.2, 0.2, 0.2))
	# 안내판과 철조망 느낌의 띠
	for sx in [-60.0, 60.0, -160.0, 160.0]:
		_db(Vector3(sx, 4.4, -250.4), Vector3(8.0, 1.4, 0.15), Color(0.62, 0.1, 0.1))
		_lab(Vector3(sx, 4.4, -250.8), "무단 접근 금지", 0.9, Color(1.0, 0.95, 0.8), PI)
	# 비밀 통로 출구(배수구) : 안에서 열기 전에는 숨김
	var z1: Vector3 = Vector3(70.0, 0.0, -300.0)
	_dc(z1 + Vector3(0.0, 0.07, 0.0), 0.9, 0.12, Color(0.14, 0.14, 0.16))
	_interact("enter", "배수구 덮개 열기 (지하 통로)", z1 + Vector3(0.0, 1.0, 0.0), 2.4,
		{"dest": _origin(S_TUNNEL) + Vector3(3.0, 0.1, -26.4), "dest_yaw": PI, "location": "비밀 지하 통로", "effects": []}, "", "tunnel_exit_zone")
	_interact("examine", "배수구 덮개 살펴보기", z1 + Vector3(0.0, 1.0, 0.0), 2.2,
		{"text": "무거운 쇠 덮개다. 안쪽에서 빗장이 걸려 있는 듯 열리지 않는다.", "effects": [], "once_flag": ""}, "tunnel_exit_zone")
	_poi("zone", "통제구역", Vector3(0.0, 0.0, -285.0))
	_poi("zone_drain", "통제구역 배수구", Vector3(70.0, 0.0, -297.0))
	_poi("officer_office", "연락 사무소", Vector3(-30.0, 0.0, -286.0))
	_end()


# ---------------------------------------------------------------- 8) 군사시설 (안쪽 문 B)

func _base() -> void:
	_begin("Base", Vector3(0.0, 0.0, -352.0), 140.0)
	var wc: Color = Color(0.36, 0.38, 0.34)
	_wallx(-120.0, -7.0, -325.0, 3.6, 0.6, wc)
	_wallx(7.0, 120.0, -325.0, 3.6, 0.6, wc)
	_wallz(-120.0, -380.0, -325.0, 3.6, 0.6, wc)
	_wallz(120.0, -380.0, -325.0, 3.6, 0.6, wc)
	_checkpoint("base", 2, "군사시설 안쪽 문", -325.0, 7.0)
	# 연병장과 도로
	_db(Vector3(0.0, 0.06, -350.0), Vector3(200.0, 0.1, 50.0), Color(0.40, 0.40, 0.38))
	_db(Vector3(0.0, 0.08, -350.0), Vector3(40.0, 0.1, 22.0), Color(0.48, 0.48, 0.44))
	# 병영 4동
	for bx in [-85.0, -55.0, 55.0, 85.0]:
		_cb(Vector3(bx, 3.0, -366.0), Vector3(20.0, 6.0, 9.0), Color(0.40, 0.44, 0.36))
		_db(Vector3(bx, 6.3, -366.0), Vector3(21.0, 0.6, 10.0), Color(0.24, 0.26, 0.24))
		for wi in range(-3, 4):
			_db(Vector3(bx + float(wi) * 2.6, 3.2, -361.46), Vector3(1.2, 1.2, 0.1), Color(0.16, 0.22, 0.28))
	# 사령부 (들어갈 수 있음)
	var hq: Vector3 = Vector3(0.0, 0.0, -362.0)
	_cb(hq + Vector3(0.0, 4.5, 0.0), Vector3(30.0, 9.0, 16.0), Color(0.62, 0.60, 0.54))
	_db(hq + Vector3(0.0, 9.3, 0.0), Vector3(32.0, 0.7, 18.0), Color(0.30, 0.28, 0.28))
	_db(hq + Vector3(0.0, 1.3, 8.06), Vector3(3.0, 2.6, 0.2), Color(0.12, 0.10, 0.09))
	for wi2 in range(-5, 6):
		if absi(wi2) <= 1:
			continue
		_db(hq + Vector3(float(wi2) * 2.4, 5.0, 8.06), Vector3(1.4, 1.6, 0.1), Color(0.16, 0.22, 0.30))
	_db(hq + Vector3(0.0, 7.6, 8.1), Vector3(12.0, 1.6, 0.2), Color(0.64, 0.10, 0.10))
	_lab(hq + Vector3(0.0, 7.6, 8.3), "사령부 (가상)", 1.4, Color(1.0, 0.95, 0.8))
	# 깃대
	_dc(Vector3(18.0, 7.0, -344.0), 0.12, 14.0, Color(0.7, 0.7, 0.72))
	_db(Vector3(21.0, 12.5, -344.0), Vector3(5.0, 3.0, 0.1), Color(0.7, 0.1, 0.1))
	# 차고 쪽 장식 트럭 상자
	for tx in [-35.0, -28.0]:
		_cb(Vector3(tx, 1.4, -336.0), Vector3(5.0, 2.8, 2.4), Color(0.30, 0.38, 0.28))
	# 입구
	_interact("enter", "사령부 입장", hq + Vector3(0.0, 1.0, 10.0), 2.6,
		{"dest": _origin(S_HQ) + Vector3(0.0, 0.1, 3.4), "dest_yaw": 0.0, "location": "군사시설 사령부",
			"requires": {"item": "pass_special"}, "locked_text": "경비가 막는다. 특별 통행증 없이는 사령부에 들어갈 수 없다.",
			"effects": [{"op": "quest_step", "id": "q_v22_pass", "step": 8, "if": {"quest": "q_v22_pass", "state": "active", "min_step": 7}}]})
	# 사령부 뒤편의 배수구 (비상 시 탈출용, 사이렌 후에 보임)
	var z2: Vector3 = Vector3(100.0, 0.0, -372.0)
	_dc(z2 + Vector3(0.0, 0.07, 0.0), 0.9, 0.12, Color(0.14, 0.14, 0.16))
	_interact("enter", "비상 배수구로 내려가기", z2 + Vector3(0.0, 1.0, 0.0), 2.4,
		{"dest": _origin(S_TUNNEL) + Vector3(3.0, 0.1, -26.4), "dest_yaw": PI, "location": "비밀 지하 통로", "effects": []}, "", "v22_siren")
	_poi("base", "군사시설", Vector3(0.0, 0.0, -335.0))
	_poi("hq", "사령부", hq + Vector3(0.0, 0.0, 12.0))
	_end()


# ---------------------------------------------------------------- NPC 배치

func spawn_npcs() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var w3d: World3D = get_world_3d()
	var count: int = 0
	for cfg0 in VNpcs.all():
		if cfg0.has("slot_npc"):
			continue
		var cfg: Dictionary = cfg0.duplicate(true)
		var gate_id: String = ""
		if cfg.has("gate"):
			gate_id = str(cfg["gate"])
			if bool(cfg.get("no_dialogue", false)):
				cfg["no_talk"] = true
			elif mgr != null and mgr.pass_sys != null:
				cfg["dialogue"] = mgr.pass_sys.make_dialogue(gate_id, 1 if gate_id == "north" else 2)
			else:
				cfg["no_talk"] = true
		var start: Vector3 = cfg["home"]
		var spot: Vector3 = Placement.find_free_capsule(w3d, start, 0.35, 1.8)
		if cfg.has("patrol_path"):
			spot = start
		var npc = NpcScript.new()
		npc.name = "NPC_" + str(cfg["id"])
		npc.configure(cfg, hub)
		npc.position = spot + Vector3(0.0, 0.05, 0.0)
		add_child(npc)
		npcs.append(npc)
		if gate_id != "":
			npc.set_meta("v22_gate", true)
			if mgr != null and mgr.pass_sys != null:
				mgr.pass_sys.add_guard(gate_id, npc)
		count += 1
		if count % 4 == 0:
			await get_tree().process_frame
	print("[PYONGYANG] V2.2 NPC %d명을 배치했습니다." % count)
	npcs_done = true


# ---------------------------------------------------------------- 거리 기반 활성화

## 플레이어에서 먼 지역은 그리지 않고, 먼 NPC 는 움직이지 않게 합니다.
func cull(player_pos: Vector3, include_npcs: bool) -> void:
	if player_pos.y > 100.0:
		return
	for r in regions:
		var n = r["node"]
		if not is_instance_valid(n):
			continue
		var c: Vector3 = r["center"]
		var d: float = Vector2(c.x - player_pos.x, c.z - player_pos.z).length()
		var show: bool = d < float(r["radius"]) + 170.0
		if n.visible != show:
			n.visible = show
	if not include_npcs:
		return
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		var d2: float = Vector2(npc.global_position.x - player_pos.x, npc.global_position.z - player_pos.z).length()
		var near: bool = d2 < 150.0
		if near != npc.is_physics_processing():
			npc.set_physics_process(near)
			npc.visible = near
