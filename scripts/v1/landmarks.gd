extends Node3D
## 평양 풍 랜드마크 (모두 "가상 재현"이며 실제 건축물의 정확한 복제품이 아닙니다).
##  류경호텔 풍 피라미드 타워 · 개선문 풍 아치 · 주체탑 풍 석탑 · 광장 연단과 대회관 지붕 ·
##  만수대 풍 기념 구역 · 옥류관 풍 전통 식당(입장 가능) · 지하철역 입구(입장 가능) ·
##  아파트 단지 2곳 · 대형 호텔 타워 · 정부청사 · 버스 정류장 추가
## world_builder.gd 는 수정하지 않고, 실행 중에 빈 자리를 검사해서 도시 주변에 덧붙입니다.
## 큰 건물 1개가 실패해도 가능한 한 나머지는 계속 만들도록 순서대로 호출합니다.

const K = preload("res://scripts/v1/lm_kit.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const Cfg = preload("res://scripts/game_config.gd")

var hub = null
## {"id","name","pos":Vector3,"kind":"landmark"/"station"/...}
var markers: Array = []
## 들어갈 수 있는 건물 겉모습: id -> {"root","front","depth","door_local"}
var exits: Dictionary = {}
var night_lights: Array = []

var _world: Node3D = null
var _details = null
var _tree_mms: Array = []


func build(world: Node3D, hub_ref) -> void:
	hub = hub_ref
	_world = world
	var dscript = load("res://scripts/gfx/gfx_details.gd")
	if dscript != null and dscript.can_instantiate():
		_details = dscript.new()
	_find_trees()
	await get_tree().physics_frame
	await get_tree().physics_frame

	_square_dressing()
	await get_tree().process_frame
	_juche_tower(Vector3(0.0, 0.0, -122.0))
	await get_tree().process_frame
	_arch(Vector3(0.0, 0.0, 228.0))
	await get_tree().process_frame
	_ryugyong(Vector3(-70.0, 0.0, -203.0))
	await get_tree().process_frame
	_island_hotel(Vector3(118.0, 0.0, -206.0))
	await get_tree().process_frame
	await _okryugwan(Vector3(-72.0, 0.0, -124.0))
	await _metro_entrance(Vector3(57.0, 0.0, -24.0))
	await _mansudae(Vector3(-140.0, 0.0, -62.0))
	await _government(Vector3(140.0, 0.0, -64.0))
	await _housing_complex(Vector3(130.0, 0.0, 80.0), "동부 아파트 단지", "housing_e", 0)
	await _housing_complex(Vector3(-130.0, 0.0, 80.0), "서부 아파트 단지", "housing_w", 1)
	_extra_bus_shelters()
	if _details != null:
		_details.flush(_world, "Landmark")
	print("[PYONGYANG] 랜드마크 %d곳을 만들었습니다." % markers.size())


## 낮밤에 맞춰 랜드마크 조명을 켜고 끔
func set_night(night: float) -> void:
	for l in night_lights:
		if is_instance_valid(l):
			l.visible = night > 0.35
			l.light_energy = 1.8 * clampf(night, 0.0, 1.0)


# ---------------------------------------------------------------- 공통 도우미

func _spot(pref: Vector3, footprint: Vector3) -> Vector3:
	var p: Vector3 = Placement.find_free_box(get_world_3d(), pref, Vector3(footprint.x, 4.0, footprint.z))
	p.y = 0.0
	return p


func _root(node_name: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var r = Node3D.new()
	r.name = node_name
	r.position = pos
	r.rotation.y = yaw
	_world.add_child(r)
	return r


func _mark(id: String, mname: String, pos: Vector3, kind: String = "landmark") -> void:
	markers.append({"id": id, "name": mname, "pos": pos, "kind": kind})
	if hub != null:
		hub.register_poi(id, mname, pos)


func _find_trees() -> void:
	_tree_mms = []
	for c in _world.get_children():
		if not (c is MultiMeshInstance3D):
			continue
		if str(c.name).begins_with("Details") or str(c.name).begins_with("Landmark"):
			continue
		var mm: MultiMesh = c.multimesh
		if mm == null or mm.mesh == null:
			continue
		if mm.mesh is SphereMesh and absf((mm.mesh as SphereMesh).radius - 1.9) < 0.05:
			_tree_mms.append(c)
		elif mm.mesh is CylinderMesh and absf((mm.mesh as CylinderMesh).height - 2.5) < 0.05:
			_tree_mms.append(c)


## 사각형 영역(중심, 반 크기) 안의 나무를 숨김
func clear_trees(centre: Vector2, half: Vector2) -> void:
	for mmi in _tree_mms:
		var mm: MultiMesh = mmi.multimesh
		for i in range(mm.instance_count):
			var t: Transform3D = mm.get_instance_transform(i)
			if absf(t.origin.x - centre.x) < half.x and absf(t.origin.z - centre.y) < half.y:
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 0.0001)), t.origin))


## world 아래에서 BoxMesh 크기가 비슷한 건물(StaticBody3D)을 찾음. 없으면 null
func _find_box(size: Vector3, tol: float) -> Node3D:
	for c in _world.get_children():
		if not (c is StaticBody3D):
			continue
		for m in c.get_children():
			if m is MeshInstance3D and m.mesh is BoxMesh:
				var s: Vector3 = (m.mesh as BoxMesh).size
				if absf(s.x - size.x) < tol and absf(s.y - size.y) < tol and absf(s.z - size.z) < tol:
					return c
	return null


func _glass_mat(tint: Color) -> StandardMaterial3D:
	return K.mat(Color(1, 1, 1), 0.22, 0.5, 0.0, K.tex_glass(tint))


# ---------------------------------------------------------------- 1) 류경호텔 풍 피라미드 타워

func _ryugyong(pref: Vector3) -> void:
	var pos: Vector3 = _spot(pref, Vector3(78.0, 4.0, 78.0))
	var r: Node3D = _root("Landmark_PyramidHotel", pos)
	var stone = K.mat(Color(1, 1, 1), 0.9, 0.0, 0.0, K.tex_stone(Color(0.72, 0.72, 0.70)))
	var steel = K.mat(Color(0.78, 0.80, 0.84), 0.3, 0.8)

	var plinth = K.MB.new()
	K.box(plinth, Vector3(0.0, 2.5, 0.0), Vector3(66.0, 5.0, 66.0), 4.0, 4.0)
	K.mesh_node(r, "Plinth", plinth, stone)
	K.collider_box(r, Vector3(0.0, 2.5, 0.0), Vector3(66.0, 5.0, 66.0))

	var rot: float = deg_to_rad(30.0)
	var body = K.MB.new()
	K.frustum(body, Vector3(0.0, 5.0, 0.0), 3, 36.0, 12.0, 92.0, rot, 4.0, 3.2, true)
	K.mesh_node(r, "Body", body, _glass_mat(Color(0.40, 0.56, 0.68)))
	K.collider_convex(r, K.frustum_points(Vector3(0.0, 5.0, 0.0), 3, 36.0, 12.0, 92.0, rot))

	var crown = K.MB.new()
	K.frustum(crown, Vector3(0.0, 97.0, 0.0), 12, 13.5, 13.5, 10.0, 0.0, 4.0, 3.2, false)
	K.frustum(crown, Vector3(0.0, 107.0, 0.0), 12, 14.2, 5.0, 12.0, 0.0, 4.0, 3.2, true)
	K.mesh_node(r, "Crown", crown, steel)
	var mast = K.MB.new()
	K.frustum(mast, Vector3(0.0, 119.0, 0.0), 6, 0.7, 0.2, 26.0, 0.0, 1.0, 1.0, true)
	K.mesh_node(r, "Mast", mast, steel)
	var ring = K.MB.new()
	K.frustum(ring, Vector3(0.0, 96.4, 0.0), 12, 14.0, 14.0, 0.8, 0.0, 4.0, 1.0, true)
	K.mesh_node(r, "GlowRing", ring, K.mat(Color(0.7, 0.9, 1.0), 0.5, 0.0, 2.2))

	# 정면(남쪽) 출입구 차양과 간판
	K.label(r, Vector3(0.0, 9.5, 18.6), "류경호텔 (가상 재현)", 1.8, Color(0.95, 0.97, 1.0))
	if _details != null:
		_details.box(pos + Vector3(0.0, 5.2, 24.0), Vector3(14.0, 0.5, 8.0), Color(0.2, 0.22, 0.26))
		for k in range(4):
			_details.cyl(pos + Vector3(-5.25 + 3.5 * float(k), 2.6, 27.0), 0.35, 5.2, Color(0.8, 0.8, 0.82))
	clear_trees(Vector2(pos.x, pos.z), Vector2(44.0, 44.0))
	_mark("lm_pyramid", "류경호텔 (가상 재현)", pos + Vector3(0.0, 0.0, 40.0))


# ---------------------------------------------------------------- 2) 개선문 풍 아치

func _arch(pos: Vector3) -> void:
	var r: Node3D = _root("Landmark_Arch", pos)
	var stone = K.mat(Color(1, 1, 1), 0.88, 0.0, 0.0, K.tex_stone(Color(0.82, 0.80, 0.74)))
	var tile = K.mat(Color(1, 1, 1), 0.7, 0.0, 0.0, K.tex_tiles(Color(0.26, 0.46, 0.42)))
	var half: float = 13.5
	var hole: float = 7.5
	var pts = PackedVector2Array()
	pts.append(Vector2(-half, 0.0))
	pts.append(Vector2(-hole, 0.0))
	var arc_n: int = 10
	for i in range(arc_n + 1):
		var th: float = PI - PI * float(i) / float(arc_n)
		pts.append(Vector2(cos(th) * hole, 14.0 + sin(th) * 7.0))
	pts.append(Vector2(hole, 0.0))
	pts.append(Vector2(half, 0.0))
	pts.append(Vector2(half, 33.0))
	pts.append(Vector2(-half, 33.0))
	var mb = K.MB.new()
	var ok: bool = K.extrude_poly(mb, Vector3.ZERO, pts, 12.0, 4.0, 4.0)
	if ok:
		K.mesh_node(r, "ArchBody", mb, stone)
	else:
		var fallback = K.MB.new()
		K.box(fallback, Vector3(0.0, 27.0, 0.0), Vector3(27.0, 12.0, 12.0), 4.0, 4.0)
		K.box(fallback, Vector3(-10.5, 10.5, 0.0), Vector3(6.0, 21.0, 12.0), 4.0, 4.0)
		K.box(fallback, Vector3(10.5, 10.5, 0.0), Vector3(6.0, 21.0, 12.0), 4.0, 4.0)
		K.mesh_node(r, "ArchBody", fallback, stone)
	var top = K.MB.new()
	K.box(top, Vector3(0.0, 33.6, 0.0), Vector3(28.6, 1.2, 13.2), 4.0, 4.0)
	K.box(top, Vector3(0.0, 36.6, 0.0), Vector3(25.0, 4.8, 10.6), 4.0, 4.0)
	K.box(top, Vector3(0.0, 39.3, 0.0), Vector3(27.0, 0.6, 11.8), 4.0, 4.0)
	K.mesh_node(r, "ArchTop", top, stone)
	var roof = K.MB.new()
	K.rect_frustum(roof, Vector3(0.0, 39.6, 0.0), 26.0, 11.0, 14.0, 6.0, 4.0, 4.0, 4.0)
	K.rect_frustum(roof, Vector3(0.0, 43.6, 0.0), 14.0, 6.0, 4.0, 2.0, 3.0, 4.0, 4.0)
	K.mesh_node(r, "ArchRoof", roof, tile)
	K.collider_box(r, Vector3(-10.5, 10.5, 0.0), Vector3(6.0, 21.0, 12.0))
	K.collider_box(r, Vector3(10.5, 10.5, 0.0), Vector3(6.0, 21.0, 12.0))
	K.collider_box(r, Vector3(0.0, 27.5, 0.0), Vector3(27.0, 13.0, 12.0))
	if _details != null:
		var gold = Color(0.80, 0.66, 0.24)
		var dark = Color(0.55, 0.53, 0.48)
		_details.box(pos + Vector3(0.0, 30.5, 6.08), Vector3(14.0, 2.4, 0.2), gold)
		_details.box(pos + Vector3(0.0, 30.5, -6.08), Vector3(14.0, 2.4, 0.2), gold)
		for k in range(5):
			for sx in [-1.0, 1.0]:
				_details.box(pos + Vector3(sx * (8.6 + 1.1 * float(k)), 9.0, 6.06), Vector3(0.5, 17.0, 0.16), dark)
				_details.box(pos + Vector3(sx * (8.6 + 1.1 * float(k)), 9.0, -6.06), Vector3(0.5, 17.0, 0.16), dark)
	clear_trees(Vector2(pos.x, pos.z), Vector2(18.0, 10.0))
	_mark("lm_arch", "개선문 (가상 재현)", pos + Vector3(0.0, 0.0, -18.0))


# ---------------------------------------------------------------- 3) 주체탑 풍 석탑

func _juche_tower(pos: Vector3) -> void:
	var r: Node3D = _root("Landmark_StoneTower", pos)
	var stone = K.mat(Color(1, 1, 1), 0.9, 0.0, 0.0, K.tex_stone(Color(0.84, 0.82, 0.78)))
	var base = K.MB.new()
	K.box(base, Vector3(0.0, 0.5, 0.0), Vector3(36.0, 1.0, 36.0), 4.0, 4.0)
	K.box(base, Vector3(0.0, 1.5, 0.0), Vector3(30.0, 1.0, 30.0), 4.0, 4.0)
	K.box(base, Vector3(0.0, 2.5, 0.0), Vector3(24.0, 1.0, 24.0), 4.0, 4.0)
	K.box(base, Vector3(0.0, 4.0, 0.0), Vector3(18.0, 2.0, 18.0), 4.0, 4.0)
	K.mesh_node(r, "Base", base, stone)
	K.collider_box(r, Vector3(0.0, 1.0, 0.0), Vector3(36.0, 2.0, 36.0))
	K.collider_box(r, Vector3(0.0, 3.5, 0.0), Vector3(24.0, 3.0, 24.0))
	var shaft = K.MB.new()
	K.frustum(shaft, Vector3(0.0, 5.0, 0.0), 4, 8.6, 5.2, 66.0, PI * 0.25, 4.0, 4.0, true)
	K.mesh_node(r, "Shaft", shaft, stone)
	K.collider_box(r, Vector3(0.0, 38.0, 0.0), Vector3(11.0, 66.0, 11.0))
	var flame_mat = K.mat(Color(1.0, 0.45, 0.12), 0.5, 0.0, 2.6)
	var lantern = K.MB.new()
	K.box(lantern, Vector3(0.0, 73.0, 0.0), Vector3(7.0, 6.0, 7.0), 3.0, 3.0)
	K.mesh_node(r, "Lantern", lantern, K.mat(Color(1.0, 0.82, 0.55), 0.5, 0.0, 1.6))
	var flame = K.MB.new()
	K.frustum(flame, Vector3(0.0, 76.0, 0.0), 8, 3.4, 0.2, 11.0, 0.0, 2.0, 2.0, true)
	K.mesh_node(r, "Flame", flame, flame_mat)
	var light = OmniLight3D.new()
	light.position = Vector3(0.0, 80.0, 0.0)
	light.omni_range = 70.0
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 0.0
	light.visible = false
	light.light_cull_mask = 1
	r.add_child(light)
	night_lights.append(light)
	if _details != null:
		var dark = Color(0.6, 0.58, 0.54)
		for k in range(6):
			for sx in [-1.0, 1.0]:
				_details.box(pos + Vector3(sx * 5.55, 38.0, -3.0 + 1.2 * float(k)), Vector3(0.1, 62.0, 0.3), dark)
		# 기단 옆 낮은 조형 벽
		for sz in [-1.0, 1.0]:
			_details.box(pos + Vector3(0.0, 4.0, sz * 14.5), Vector3(14.0, 3.0, 1.2), Color(0.5, 0.48, 0.44))
	K.label(r, Vector3(0.0, 8.5, 12.2), "석탑 (주체탑 풍 · 가상 재현)", 1.2, Color(1.0, 0.95, 0.8))
	clear_trees(Vector2(pos.x, pos.z), Vector2(26.0, 26.0))
	_mark("lm_tower", "석탑 (주체탑 풍)", pos + Vector3(0.0, 0.0, 22.0))


# ---------------------------------------------------------------- 4) 광장 연단 + 대회관 지붕

func _square_dressing() -> void:
	if _details == null:
		return
	var stone = Color(0.80, 0.78, 0.74)
	# 연단(사열대)
	_details.box(Vector3(0.0, 0.7, -46.0), Vector3(40.0, 1.4, 6.0), stone)
	_details.box(Vector3(0.0, 1.5, -46.5), Vector3(36.0, 0.2, 4.5), Color(0.5, 0.15, 0.14))
	K.collider_box(_world, Vector3(0.0, 0.7, -46.0), Vector3(40.0, 1.4, 6.0))
	# 광장 바닥 점 무늬 (집단 체조 위치 표시 풍)
	var dot = Color(0.62, 0.61, 0.58)
	for ix in range(-8, 9):
		for iz in range(-6, 8):
			var x: float = float(ix) * 5.5
			var z: float = float(iz) * 5.5
			if absf(x) < 9.0 and absf(z) < 9.0:
				continue
			if absf(x) > 46.0 or absf(z) > 46.0:
				continue
			_details.box(Vector3(x, 0.125, z), Vector3(0.7, 0.02, 0.7), dot)
	# 깃대
	for ix2 in range(-4, 5):
		var fx: float = float(ix2) * 10.0
		if absf(fx) < 15.0:
			continue
		_details.box(Vector3(fx, 7.0, 47.5), Vector3(0.14, 14.0, 0.14), Color(0.8, 0.8, 0.82))
		_details.box(Vector3(fx + 1.0, 12.9, 47.5), Vector3(2.0, 1.2, 0.05), Color(0.75, 0.18, 0.16))
	_mark("lm_square", "광장 (김일성광장 풍)", Vector3(0.0, 0.0, 30.0))

	# 대회관 지붕 (인민대학습당 풍): 건물 위치를 찾아서 올린다. 못 찾으면 건너뜀.
	var hall = _find_box(Vector3(30.0, 28.0, 22.0), 0.6)
	var wings = _find_box(Vector3(80.0, 18.0, 24.0), 0.6)
	if hall != null and wings != null:
		var tile = K.mat(Color(1, 1, 1), 0.7, 0.0, 0.0, K.tex_tiles(Color(0.22, 0.48, 0.44)))
		var mb = K.MB.new()
		var hp: Vector3 = hall.global_position
		K.rect_frustum(mb, Vector3(hp.x, 28.9, hp.z), 34.0, 26.0, 16.0, 8.0, 7.5, 4.0, 4.0)
		var wp: Vector3 = wings.global_position
		for sx in [-1.0, 1.0]:
			K.rect_frustum(mb, Vector3(wp.x + sx * 27.0, 18.7, wp.z), 26.0, 28.0, 12.0, 8.0, 5.0, 4.0, 4.0)
		K.mesh_node(_world, "Landmark_HallRoof", mb, tile)
		_mark("lm_hall", "대회관 (인민대학습당 풍)", Vector3(wp.x, 0.0, wp.z + 30.0))


# ---------------------------------------------------------------- 5) 만수대 풍 기념 구역 (추상 조형, 인물상 없음)

func _mansudae(pref: Vector3) -> void:
	var pos: Vector3 = _spot(pref, Vector3(70.0, 4.0, 44.0))
	var r: Node3D = _root("Landmark_Hill", pos)
	var stone = K.mat(Color(1, 1, 1), 0.9, 0.0, 0.0, K.tex_stone(Color(0.78, 0.76, 0.70)))
	var bronze = K.mat(Color(0.46, 0.34, 0.20), 0.45, 0.65)
	var mb = K.MB.new()
	K.box(mb, Vector3(0.0, 0.6, 0.0), Vector3(64.0, 1.2, 36.0), 4.0, 4.0)
	K.box(mb, Vector3(0.0, 1.8, -2.0), Vector3(52.0, 1.2, 28.0), 4.0, 4.0)
	K.box(mb, Vector3(0.0, 3.0, -5.0), Vector3(40.0, 1.2, 20.0), 4.0, 4.0)
	K.mesh_node(r, "Terraces", mb, stone)
	K.collider_box(r, Vector3(0.0, 0.6, 0.0), Vector3(64.0, 1.2, 36.0))
	K.collider_box(r, Vector3(0.0, 1.8, -2.0), Vector3(52.0, 1.2, 28.0))
	K.collider_box(r, Vector3(0.0, 3.0, -5.0), Vector3(40.0, 1.2, 20.0))
	# 계단: 앞(+Z) 중앙은 낮은 경사 대신 얕은 계단 박스
	for k in range(3):
		K.collider_box(r, Vector3(0.0, 0.2 + 0.4 * float(k), 18.0 + 1.2 - 1.2 * float(k)), Vector3(10.0, 0.4 + 0.4 * float(k), 1.2))
	var steps = K.MB.new()
	for k2 in range(3):
		K.box(steps, Vector3(0.0, 0.2 + 0.4 * float(k2), 19.2 - 1.2 * float(k2)), Vector3(10.0, 0.4 + 0.4 * float(k2), 1.2), 4.0, 4.0)
	K.mesh_node(r, "Steps", steps, stone)
	# 추상 조형 벽 (청동색 세로 리브)
	var wall = K.MB.new()
	K.box(wall, Vector3(0.0, 7.0, -12.0), Vector3(30.0, 8.0, 1.6), 2.0, 2.0)
	K.mesh_node(r, "ReliefWall", wall, bronze)
	K.collider_box(r, Vector3(0.0, 7.0, -12.0), Vector3(30.0, 8.0, 1.6))
	if _details != null:
		for i in range(15):
			var h: float = 3.0 + 3.5 * absf(sin(float(i) * 0.9))
			_details.box(pos + Vector3(-14.0 + 2.0 * float(i), 4.6 + h * 0.5, -11.0), Vector3(0.7, h, 0.5), Color(0.62, 0.48, 0.28))
		for j in range(9):
			var fx: float = -24.0 + 6.0 * float(j)
			_details.box(pos + Vector3(fx, 7.0, 8.0), Vector3(0.14, 8.0, 0.14), Color(0.8, 0.8, 0.82))
			_details.box(pos + Vector3(fx + 0.9, 10.4, 8.0), Vector3(1.8, 1.1, 0.05), Color(0.75, 0.18, 0.16))
	K.label(r, Vector3(0.0, 13.0, -10.8), "만수대 기념 구역 (가상 재현)", 1.4, Color(1.0, 0.93, 0.7))
	clear_trees(Vector2(pos.x, pos.z), Vector2(38.0, 24.0))
	_mark("lm_hill", "만수대 (가상 재현)", pos + Vector3(0.0, 0.0, 26.0))
	await get_tree().physics_frame


# ---------------------------------------------------------------- 6) 정부청사

func _government(pref: Vector3) -> void:
	var pos: Vector3 = _spot(pref, Vector3(76.0, 4.0, 34.0))
	var r: Node3D = _root("Landmark_Government", pos)
	var stone = K.mat(Color(1, 1, 1), 0.88, 0.0, 0.0, K.tex_stone(Color(0.84, 0.82, 0.74)))
	var tile = K.mat(Color(1, 1, 1), 0.7, 0.0, 0.0, K.tex_tiles(Color(0.28, 0.40, 0.46)))
	var glass = _glass_mat(Color(0.30, 0.42, 0.52))
	var mb = K.MB.new()
	K.box(mb, Vector3(0.0, 10.0, 0.0), Vector3(70.0, 20.0, 24.0), 4.0, 4.0)
	K.box(mb, Vector3(0.0, 24.0, -2.0), Vector3(30.0, 8.0, 18.0), 4.0, 4.0)
	K.mesh_node(r, "Hall", mb, stone)
	K.collider_box(r, Vector3(0.0, 10.0, 0.0), Vector3(70.0, 20.0, 24.0))
	K.collider_box(r, Vector3(0.0, 24.0, -2.0), Vector3(30.0, 8.0, 18.0))
	var win = K.MB.new()
	K.box(win, Vector3(0.0, 12.0, 12.05), Vector3(60.0, 12.0, 0.1), 4.0, 3.2)
	K.mesh_node(r, "Windows", win, glass)
	var roof = K.MB.new()
	K.rect_frustum(roof, Vector3(0.0, 20.0, 0.0), 72.0, 26.0, 40.0, 14.0, 3.5, 4.0, 4.0)
	K.rect_frustum(roof, Vector3(0.0, 28.0, -2.0), 32.0, 20.0, 12.0, 6.0, 6.0, 4.0, 4.0)
	K.mesh_node(r, "Roof", roof, tile)
	if _details != null:
		for k in range(9):
			_details.cyl(pos + Vector3(-24.0 + 6.0 * float(k), 7.0, 14.5), 0.8, 14.0, Color(0.88, 0.86, 0.80))
		_details.box(pos + Vector3(0.0, 14.5, 14.5), Vector3(54.0, 1.2, 3.4), Color(0.80, 0.78, 0.72))
		for fx in [-30.0, 30.0]:
			_details.box(pos + Vector3(fx, 8.0, 18.0), Vector3(0.14, 16.0, 0.14), Color(0.8, 0.8, 0.82))
			_details.box(pos + Vector3(fx + 1.0, 14.6, 18.0), Vector3(2.0, 1.3, 0.05), Color(0.75, 0.18, 0.16))
	K.label(r, Vector3(0.0, 17.5, 14.6), "정부청사 (가상)", 1.4, Color(1.0, 0.95, 0.8))
	clear_trees(Vector2(pos.x, pos.z), Vector2(40.0, 20.0))
	_mark("lm_gov", "정부청사 (가상)", pos + Vector3(0.0, 0.0, 26.0))
	await get_tree().physics_frame


# ---------------------------------------------------------------- 7) 대형 호텔 타워 (강북쪽)

func _island_hotel(pref: Vector3) -> void:
	var pos: Vector3 = _spot(pref, Vector3(56.0, 4.0, 34.0))
	var r: Node3D = _root("Landmark_TowerHotel", pos)
	var concrete = K.mat(Color(1, 1, 1), 0.85, 0.0, 0.0, K.tex_stone(Color(0.78, 0.78, 0.76)))
	var glass = _glass_mat(Color(0.36, 0.5, 0.62))
	var podium = K.MB.new()
	K.box(podium, Vector3(0.0, 4.0, 0.0), Vector3(52.0, 8.0, 28.0), 4.0, 4.0)
	K.mesh_node(r, "Podium", podium, concrete)
	K.collider_box(r, Vector3(0.0, 4.0, 0.0), Vector3(52.0, 8.0, 28.0))
	var tower = K.MB.new()
	K.box(tower, Vector3(0.0, 48.0, 0.0), Vector3(24.0, 80.0, 13.0), 4.0, 3.2)
	K.mesh_node(r, "Tower", tower, glass)
	K.collider_box(r, Vector3(0.0, 48.0, 0.0), Vector3(24.0, 80.0, 13.0))
	var disc = K.MB.new()
	K.frustum(disc, Vector3(0.0, 88.0, 0.0), 16, 12.5, 12.5, 5.0, 0.0, 4.0, 3.2, true)
	K.frustum(disc, Vector3(0.0, 93.0, 0.0), 16, 12.5, 2.0, 2.5, 0.0, 4.0, 3.2, true)
	K.mesh_node(r, "Disc", disc, K.mat(Color(0.9, 0.95, 1.0), 0.35, 0.4, 0.9))
	var mast = K.MB.new()
	K.frustum(mast, Vector3(0.0, 95.5, 0.0), 6, 0.5, 0.15, 18.0, 0.0, 1.0, 1.0, true)
	K.mesh_node(r, "Mast", mast, K.mat(Color(0.8, 0.82, 0.86), 0.3, 0.8))
	K.label(r, Vector3(0.0, 11.0, 14.3), "섬 호텔 (양각도 호텔 풍 · 가상)", 1.3, Color(1.0, 0.95, 0.8))
	clear_trees(Vector2(pos.x, pos.z), Vector2(30.0, 20.0))
	_mark("lm_island_hotel", "대형 호텔 (양각도 호텔 풍)", pos + Vector3(0.0, 0.0, 26.0))


# ---------------------------------------------------------------- 8) 옥류관 풍 전통 식당 (입장 가능)

func _okryugwan(pref: Vector3) -> void:
	var pos: Vector3 = _spot(pref, Vector3(44.0, 4.0, 30.0))
	var r: Node3D = _root("Ext_okryu", pos)
	var wall = K.mat(Color(0.93, 0.91, 0.86), 0.9)
	var tile = K.mat(Color(1, 1, 1), 0.65, 0.0, 0.0, K.tex_tiles(Color(0.25, 0.32, 0.36)))
	var mb = K.MB.new()
	K.box(mb, Vector3(0.0, 3.5, 0.0), Vector3(30.0, 7.0, 16.0), 4.0, 4.0)
	K.box(mb, Vector3(0.0, 10.0, 0.0), Vector3(22.0, 6.0, 12.0), 4.0, 4.0)
	K.box(mb, Vector3(0.0, 0.4, 0.0), Vector3(32.0, 0.8, 18.0), 4.0, 4.0)
	K.mesh_node(r, "Walls", mb, wall)
	K.collider_box(r, Vector3(0.0, 3.5, 0.0), Vector3(30.0, 7.0, 16.0))
	K.collider_box(r, Vector3(0.0, 10.0, 0.0), Vector3(22.0, 6.0, 12.0))
	var roof = K.MB.new()
	K.rect_frustum(roof, Vector3(0.0, 6.8, 0.0), 38.0, 24.0, 28.0, 16.0, 2.4, 4.0, 4.0)
	K.rect_frustum(roof, Vector3(0.0, 13.0, 0.0), 30.0, 18.0, 6.0, 3.0, 6.5, 4.0, 4.0)
	K.mesh_node(r, "Roof", roof, tile)
	if _details != null:
		var red = Color(0.62, 0.14, 0.10)
		for k in range(8):
			_details.cyl(pos + Vector3(-12.6 + 3.6 * float(k), 3.5, 8.4), 0.32, 7.0, red)
		for k2 in range(5):
			_details.cyl(pos + Vector3(-8.0 + 4.0 * float(k2), 10.0, 6.4), 0.26, 5.6, red)
		# 처마 끝이 살짝 들린 모서리
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_details.box(pos + Vector3(sx * 19.0, 9.4, sz * 12.0), Vector3(1.6, 0.35, 1.6), Color(0.2, 0.26, 0.30))
				_details.box(pos + Vector3(sx * 14.6, 15.8, sz * 9.0), Vector3(1.4, 0.3, 1.4), Color(0.2, 0.26, 0.30))
		_details.box(pos + Vector3(0.0, 1.3, 8.15), Vector3(3.2, 2.6, 0.2), Color(0.20, 0.12, 0.08))
		_details.box(pos + Vector3(0.0, 0.2, 10.0), Vector3(8.0, 0.4, 3.0), Color(0.7, 0.68, 0.64))
		for sxx in [-1.0, 1.0]:
			_details.box(pos + Vector3(sxx * 10.0, 3.5, 8.12), Vector3(5.0, 2.2, 0.1), Color(0.18, 0.24, 0.32))
	K.label(r, Vector3(0.0, 6.0, 8.5), "옥류관 (가상 재현)", 1.5, Color(1.0, 0.95, 0.8))
	var front: Vector3 = pos + Vector3(0.0, 0.1, 8.0 + 5.0)
	exits["okryu"] = {"root": r, "front": front, "depth": 16.0, "name": "옥류관"}
	clear_trees(Vector2(pos.x, pos.z), Vector2(26.0, 20.0))
	_mark("lm_okryu", "옥류관 (가상 재현)", front)
	await get_tree().physics_frame


# ---------------------------------------------------------------- 9) 지하철역 입구 (입장 가능)

func _metro_entrance(pref: Vector3) -> void:
	var pos: Vector3 = _spot(pref, Vector3(14.0, 4.0, 14.0))
	var r: Node3D = _root("Ext_metro", pos, -PI * 0.5)
	var wall = K.mat(Color(0.90, 0.90, 0.88), 0.85)
	var mb = K.MB.new()
	K.box(mb, Vector3(0.0, 2.4, 0.0), Vector3(9.0, 4.8, 6.0), 4.0, 4.0)
	K.box(mb, Vector3(0.0, 5.0, 0.4), Vector3(10.0, 0.5, 8.0), 4.0, 4.0)
	K.mesh_node(r, "Walls", mb, wall)
	K.collider_box(r, Vector3(0.0, 2.4, 0.0), Vector3(9.0, 4.8, 6.0))
	if _details != null:
		var b = Basis(Vector3.UP, -PI * 0.5)
		_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 1.5, 3.05)), Vector3(2.6, 3.0, 0.2), Color(0.10, 0.10, 0.12))
		_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 3.4, 3.1)), Vector3(3.2, 0.5, 0.2), Color(0.70, 0.12, 0.12))
		_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 0.15, 4.0)), Vector3(4.0, 0.3, 2.0), Color(0.6, 0.6, 0.58))
		_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 0.1, 5.2)), Vector3(4.0, 0.2, 1.0), Color(0.55, 0.55, 0.53))
	K.label(r, Vector3(0.0, 6.0, 3.3), "지하철", 1.6, Color(1.0, 0.9, 0.5))
	var fwd: Vector3 = Basis(Vector3.UP, -PI * 0.5) * Vector3(0.0, 0.0, 1.0)
	var front: Vector3 = pos + fwd * 6.5 + Vector3(0.0, 0.1, 0.0)
	exits["metro"] = {"root": r, "front": front, "depth": 6.0, "name": "지하철역"}
	_mark("lm_metro", "지하철역 입구", front, "station")
	await get_tree().physics_frame


# ---------------------------------------------------------------- 10) 아파트 단지

func _housing_complex(centre: Vector3, cname: String, id: String, style: int) -> void:
	var palettes: Array = [
		[Color(0.90, 0.86, 0.76), Color(0.78, 0.38, 0.30)],
		[Color(0.80, 0.86, 0.88), Color(0.28, 0.50, 0.62)],
	]
	var pal: Array = palettes[style % 2]
	var tex = K.tex_housing(pal[0], pal[1])
	var m = K.mat(Color(1, 1, 1), 0.9, 0.0, 0.0, tex)
	var offsets: Array = [Vector3(-24.0, 0.0, -18.0), Vector3(24.0, 0.0, -18.0), Vector3(-24.0, 0.0, 18.0), Vector3(24.0, 0.0, 18.0)]
	var placed: int = 0
	var cpos: Vector3 = centre
	for i in range(offsets.size()):
		var size = Vector3(34.0, 30.0 + 6.0 * float(i % 2), 11.0)
		var o: Vector3 = offsets[i]
		var spot: Vector3 = _spot(centre + o, Vector3(size.x + 4.0, 4.0, size.z + 4.0))
		var mb = K.MB.new()
		K.box(mb, Vector3(0.0, size.y * 0.5, 0.0), size, 4.0, 3.2)
		var mi = K.mesh_node(_world, "Housing_%s_%d" % [id, i], mb, m)
		mi.position = spot
		K.collider_box(_world, spot + Vector3(0.0, size.y * 0.5, 0.0), size)
		var roof = K.MB.new()
		K.box(roof, Vector3(0.0, size.y + 0.25, 0.0), Vector3(size.x + 0.6, 0.5, size.z + 0.6), 4.0, 4.0)
		var rmi = K.mesh_node(_world, "HousingRoof_%s_%d" % [id, i], roof, K.mat(pal[1], 0.9))
		rmi.position = spot
		if _details != null:
			_details.box(spot + Vector3(0.0, size.y + 1.2, 0.0), Vector3(6.0, 1.8, 4.0), Color(0.55, 0.55, 0.58))
			_details.cyl(spot + Vector3(10.0, size.y + 1.4, 1.0), 0.8, 2.4, Color(0.7, 0.7, 0.72))
		clear_trees(Vector2(spot.x, spot.z), Vector2(size.x * 0.5 + 3.0, size.z * 0.5 + 3.0))
		cpos = spot
		placed += 1
		await get_tree().physics_frame
	if _details != null and placed > 0:
		# 단지 가운데 놀이터와 나무
		var g = centre
		_details.box(g + Vector3(0.0, 0.08, 0.0), Vector3(14.0, 0.16, 10.0), Color(0.72, 0.62, 0.42))
		_details.box(g + Vector3(-3.0, 1.1, 0.0), Vector3(0.12, 2.2, 0.12), Color(0.7, 0.2, 0.2))
		_details.box(g + Vector3(3.0, 1.1, 0.0), Vector3(0.12, 2.2, 0.12), Color(0.7, 0.2, 0.2))
		_details.box(g + Vector3(0.0, 2.2, 0.0), Vector3(6.2, 0.12, 0.12), Color(0.7, 0.2, 0.2))
		_details.box(g + Vector3(0.0, 0.5, 3.5), Vector3(5.0, 0.5, 0.8), Color(0.2, 0.4, 0.7))
		for k in range(10):
			var ang: float = TAU * float(k) / 10.0
			var tp = g + Vector3(cos(ang) * 11.0, 0.0, sin(ang) * 8.0)
			_details.cyl(tp + Vector3(0.0, 1.2, 0.0), 0.18, 2.4, Color(0.35, 0.25, 0.15))
			_details.sphere(tp + Vector3(0.0, 3.6, 0.0), Vector3(1.8, 1.8, 1.8), Color(0.22, 0.46, 0.22))
	if placed > 0:
		_mark("lm_" + id, cname, centre)


# ---------------------------------------------------------------- 11) 버스 정류장 추가 (환경 모듈이 만든 2곳 맞은편)

func _extra_bus_shelters() -> void:
	if _details == null:
		return
	_shelter(Vector3(-104.0, 0.0, -11.5), PI)
	_shelter(Vector3(104.0, 0.0, 11.5), 0.0)


func _shelter(pos: Vector3, yaw: float) -> void:
	var b = Basis(Vector3.UP, yaw)
	var glass = Color(0.45, 0.58, 0.64)
	var steel = Color(0.35, 0.36, 0.38)
	_details.box_xf(Transform3D(b, pos + b * Vector3(0, 2.6, 0.1)), Vector3(4.8, 0.12, 2.0), Color(0.22, 0.24, 0.28))
	_details.box_xf(Transform3D(b, pos + b * Vector3(0, 1.4, 0.7)), Vector3(4.4, 1.9, 0.06), glass)
	for px in [-2.3, 2.3]:
		_details.box_xf(Transform3D(b, pos + b * Vector3(px, 1.3, -0.8)), Vector3(0.08, 2.6, 0.08), steel)
		_details.box_xf(Transform3D(b, pos + b * Vector3(px, 1.3, 0.7)), Vector3(0.08, 2.6, 0.08), steel)
	_details.box_xf(Transform3D(b, pos + b * Vector3(0, 0.5, 0.4)), Vector3(3.0, 0.08, 0.45), Color(0.55, 0.40, 0.25))
	K.collider_box(_world, pos + b * Vector3(0, 1.3, 0.3), Vector3(4.8, 2.6, 1.2), yaw)
