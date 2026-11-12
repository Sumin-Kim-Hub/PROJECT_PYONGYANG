extends Node3D
## V2 추가 랜드마크 (모두 "가상 재현"이며 실제 건축물의 정확한 복제나 실제 치수가 아닙니다).
##  - 평양역 풍 역사(시계탑 + 넓은 본관, 입장 가능) + 주차장
##  - 창전거리 풍 고층 아파트 거리
##  - 미래과학자거리 풍 독특한 형태의 탑들 (원자 고리 탑, 비틀린 탑, 물결 탑, 돛 모양 유리 건물)
## v1 의 landmarks.gd 가 가진 도우미(_spot, _root, _mark, clear_trees, _details)를 그대로 빌려 씁니다.
## 어느 하나가 실패해도 나머지는 계속 만들도록 순서대로 호출합니다. (Godot 실행 미검증)

const K = preload("res://scripts/v1/lm_kit.gd")

var hub = null
var lm = null
## 들어갈 수 있는 건물 겉모습: id -> {"root","front","depth","name"}
var exits: Dictionary = {}
## 주차장 자리: [{"pos": Vector3, "yaw": 도(deg), "kind": "car"/"taxi"/...}]
var parking: Array = []
var markers: Array = []

var _world: Node3D = null
var _details = null


func build(world: Node3D, hub_ref, landmarks) -> void:
	hub = hub_ref
	_world = world
	lm = landmarks
	if lm == null:
		return
	_details = lm._details
	await get_tree().physics_frame
	await _station(Vector3(-95.0, 0.0, 190.0))
	await get_tree().process_frame
	await _parking(Vector3(-40.0, 0.0, 168.0))
	await get_tree().process_frame
	await _changjeon(Vector3(170.0, 0.0, 168.0))
	await get_tree().process_frame
	await _future_street(Vector3(-170.0, 0.0, 168.0))
	if _details != null:
		_details.flush(_world, "Landmark2")
	print("[PYONGYANG] V2 랜드마크 %d곳을 만들었습니다." % markers.size())


func _reg(id: String, nm: String, pos: Vector3, kind: String = "landmark") -> void:
	lm._mark(id, nm, pos, kind)
	markers.append(id)


# ---------------------------------------------------------------- 평양역 풍 역사 (입장 가능)

func _station(pref: Vector3) -> void:
	var pos: Vector3 = lm._spot(pref, Vector3(84.0, 4.0, 46.0))
	var yaw: float = PI   # 출입구가 북쪽(도심 쪽)을 봄
	var r: Node3D = lm._root("Ext_station", pos, yaw)
	var b = Basis(Vector3.UP, yaw)
	var stone = K.mat(Color(1, 1, 1), 0.88, 0.0, 0.0, K.tex_stone(Color(0.86, 0.84, 0.78)))
	var tile = K.mat(Color(1, 1, 1), 0.7, 0.0, 0.0, K.tex_tiles(Color(0.30, 0.38, 0.34)))
	var glass = lm._glass_mat(Color(0.34, 0.46, 0.56))
	var mb = K.MB.new()
	K.box(mb, Vector3(0.0, 5.5, 0.0), Vector3(56.0, 11.0, 18.0), 4.0, 4.0)
	K.box(mb, Vector3(-38.0, 4.0, 0.0), Vector3(20.0, 8.0, 14.0), 4.0, 4.0)
	K.box(mb, Vector3(38.0, 4.0, 0.0), Vector3(20.0, 8.0, 14.0), 4.0, 4.0)
	K.box(mb, Vector3(0.0, 20.0, -2.0), Vector3(11.0, 18.0, 11.0), 4.0, 4.0)
	K.mesh_node(r, "Walls", mb, stone)
	K.collider_box(r, Vector3(0.0, 5.5, 0.0), Vector3(56.0, 11.0, 18.0))
	K.collider_box(r, Vector3(-38.0, 4.0, 0.0), Vector3(20.0, 8.0, 14.0))
	K.collider_box(r, Vector3(38.0, 4.0, 0.0), Vector3(20.0, 8.0, 14.0))
	K.collider_box(r, Vector3(0.0, 20.0, -2.0), Vector3(11.0, 18.0, 11.0))
	var win = K.MB.new()
	K.box(win, Vector3(-14.0, 6.0, 9.05), Vector3(16.0, 6.0, 0.1), 4.0, 3.2)
	K.box(win, Vector3(14.0, 6.0, 9.05), Vector3(16.0, 6.0, 0.1), 4.0, 3.2)
	K.box(win, Vector3(-38.0, 4.5, 7.05), Vector3(16.0, 4.0, 0.1), 4.0, 3.2)
	K.box(win, Vector3(38.0, 4.5, 7.05), Vector3(16.0, 4.0, 0.1), 4.0, 3.2)
	K.mesh_node(r, "Windows", win, glass)
	var roof = K.MB.new()
	K.rect_frustum(roof, Vector3(0.0, 11.0, 0.0), 58.0, 20.0, 40.0, 8.0, 3.2, 4.0, 4.0)
	K.rect_frustum(roof, Vector3(-38.0, 8.0, 0.0), 22.0, 16.0, 14.0, 8.0, 2.4, 4.0, 4.0)
	K.rect_frustum(roof, Vector3(38.0, 8.0, 0.0), 22.0, 16.0, 14.0, 8.0, 2.4, 4.0, 4.0)
	K.rect_frustum(roof, Vector3(0.0, 29.0, -2.0), 12.4, 12.4, 0.6, 0.6, 9.0, 4.0, 4.0)
	K.mesh_node(r, "Roof", roof, tile)
	if _details != null:
		var pale = Color(0.88, 0.86, 0.80)
		for k in range(8):
			var cx: float = -14.0 + 4.0 * float(k)
			_details.cyl_xf(Transform3D(b, pos + b * Vector3(cx, 5.0, 10.6)), 0.55, 10.0, pale)
		_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 10.3, 11.0)), Vector3(34.0, 0.8, 3.6), Color(0.80, 0.78, 0.72))
		_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 0.3, 11.2)), Vector3(36.0, 0.6, 4.4), Color(0.74, 0.72, 0.68))
		_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 2.6, 9.08)), Vector3(6.0, 5.2, 0.2), Color(0.12, 0.10, 0.09))
		# 시계탑의 시계 (원판 + 시침/분침)
		var cb = Basis(Vector3.RIGHT, PI * 0.5)
		_details.cyl_xf(Transform3D(b * cb, pos + b * Vector3(0.0, 23.0, 3.62)), 2.4, 0.2, Color(0.96, 0.95, 0.90))
		_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 23.5, 3.78)), Vector3(0.22, 2.0, 0.08), Color(0.10, 0.10, 0.12))
		_details.box_xf(Transform3D(b, pos + b * Vector3(0.9, 23.0, 3.78)), Vector3(1.8, 0.18, 0.08), Color(0.10, 0.10, 0.12))
		# 택시 승강장 표시와 벤치
		_details.box_xf(Transform3D(b, pos + b * Vector3(-24.0, 0.1, 14.5)), Vector3(10.0, 0.2, 5.0), Color(0.55, 0.55, 0.53))
		for bx in [-8.0, 8.0]:
			_details.box_xf(Transform3D(b, pos + b * Vector3(bx, 0.5, 14.2)), Vector3(2.4, 0.5, 0.6), Color(0.45, 0.32, 0.2))
	K.label(r, Vector3(0.0, 12.6, 9.2), "평양역 (가상 재현)", 1.6, Color(1.0, 0.95, 0.8))
	var front: Vector3 = pos + b * Vector3(0.0, 0.1, 14.0)
	exits["station"] = {"root": r, "front": front, "depth": 18.0, "name": "평양역"}
	lm.clear_trees(Vector2(pos.x, pos.z), Vector2(46.0, 26.0))
	_reg("lm_station", "평양역 (가상 재현)", front, "station")
	await get_tree().physics_frame


# ---------------------------------------------------------------- 주차장 (실제로 타고 갈 수 있는 차량이 세워짐)

func _parking(pref: Vector3) -> void:
	var pos: Vector3 = lm._spot(pref, Vector3(36.0, 2.0, 20.0))
	if _details != null:
		_details.box(pos + Vector3(0.0, 0.05, 0.0), Vector3(34.0, 0.1, 18.0), Color(0.24, 0.24, 0.26))
		for i in range(7):
			_details.box(pos + Vector3(-15.0 + 5.0 * float(i), 0.12, -3.5), Vector3(0.18, 0.04, 6.0), Color(0.9, 0.9, 0.85))
			_details.box(pos + Vector3(-15.0 + 5.0 * float(i), 0.12, 4.5), Vector3(0.18, 0.04, 6.0), Color(0.9, 0.9, 0.85))
		_details.box(pos + Vector3(0.0, 1.6, 8.6), Vector3(0.12, 3.2, 0.12), Color(0.4, 0.4, 0.42))
		_details.box(pos + Vector3(0.0, 3.2, 8.6), Vector3(2.2, 0.8, 0.1), Color(0.15, 0.3, 0.6))
	var kinds: Array = ["car", "taxi", "car", "truck", "car", "police"]
	var cols: Array = [Color(0.55, 0.58, 0.62), Color(0.95, 0.78, 0.15), Color(0.2, 0.3, 0.22), Color(0.4, 0.36, 0.28), Color(0.62, 0.2, 0.2), Color(0.93, 0.94, 0.96)]
	for i2 in range(kinds.size()):
		var px: float = -12.5 + 5.0 * float(i2)
		var south: bool = i2 % 2 == 0
		parking.append({"pos": pos + Vector3(px, 0.1, -3.5 if south else 4.5), "yaw": 0.0 if south else 180.0,
			"kind": kinds[i2], "color": cols[i2], "id": "v_park%d" % i2})
	_reg("lm_parking", "역 앞 주차장", pos)
	await get_tree().physics_frame


# ---------------------------------------------------------------- 창전거리 풍 고층 아파트 거리

func _changjeon(centre: Vector3) -> void:
	var palettes: Array = [
		[Color(0.94, 0.88, 0.74), Color(0.80, 0.40, 0.30)],
		[Color(0.82, 0.90, 0.92), Color(0.28, 0.56, 0.66)],
		[Color(0.92, 0.82, 0.86), Color(0.66, 0.32, 0.46)],
		[Color(0.86, 0.92, 0.80), Color(0.38, 0.58, 0.32)],
		[Color(0.96, 0.92, 0.78), Color(0.86, 0.62, 0.20)],
		[Color(0.84, 0.86, 0.94), Color(0.34, 0.40, 0.68)],
	]
	var heights: Array = [38.0, 52.0, 44.0, 56.0, 40.0, 48.0]
	var placed: int = 0
	for i in range(6):
		var west: bool = i % 2 == 0
		var row: int = i / 2
		var size = Vector3(16.0, float(heights[i]), 12.0)
		var pref = Vector3(centre.x + (-20.0 if west else 20.0), 0.0, centre.z - 33.0 + 33.0 * float(row))
		var spot: Vector3 = lm._spot(pref, Vector3(size.x + 4.0, 4.0, size.z + 4.0))
		var pal: Array = palettes[i]
		var m = K.mat(Color(1, 1, 1), 0.9, 0.0, 0.0, K.tex_housing(pal[0], pal[1]))
		var mb = K.MB.new()
		K.box(mb, Vector3(0.0, size.y * 0.5, 0.0), size, 4.0, 3.2)
		var mi = K.mesh_node(_world, "Changjeon_%d" % i, mb, m)
		mi.position = spot
		K.collider_box(_world, spot + Vector3(0.0, size.y * 0.5, 0.0), size)
		# 계단식 꼭대기
		var cap = K.MB.new()
		K.box(cap, Vector3(0.0, size.y + 3.0, 0.0), Vector3(size.x * 0.62, 6.0, size.z * 0.62), 4.0, 3.2)
		var cmi = K.mesh_node(_world, "ChangjeonCap_%d" % i, cap, K.mat(pal[1], 0.85))
		cmi.position = spot
		if _details != null:
			_details.cyl(spot + Vector3(0.0, size.y + 8.0, 0.0), 0.12, 5.0, Color(0.8, 0.8, 0.82))
			_details.box(spot + Vector3(0.0, 0.1, size.z * 0.5 + 1.6), Vector3(10.0, 0.2, 3.0), Color(0.7, 0.68, 0.64))
		lm.clear_trees(Vector2(spot.x, spot.z), Vector2(size.x * 0.5 + 3.0, size.z * 0.5 + 3.0))
		placed += 1
		await get_tree().physics_frame
	if _details != null and placed > 0:
		# 가운데 대로(보행자 거리)와 가로수, 가로등
		_details.box(centre + Vector3(0.0, 0.06, 0.0), Vector3(14.0, 0.12, 100.0), Color(0.60, 0.58, 0.54))
		for k in range(11):
			var zz: float = centre.z - 45.0 + 9.0 * float(k)
			_details.cyl(Vector3(centre.x - 4.0, 1.2, zz), 0.16, 2.4, Color(0.35, 0.25, 0.15))
			_details.sphere(Vector3(centre.x - 4.0, 3.5, zz), Vector3(1.7, 1.7, 1.7), Color(0.26, 0.5, 0.26))
			_details.cyl(Vector3(centre.x + 4.0, 1.2, zz), 0.16, 2.4, Color(0.35, 0.25, 0.15))
			_details.sphere(Vector3(centre.x + 4.0, 3.5, zz), Vector3(1.7, 1.7, 1.7), Color(0.26, 0.5, 0.26))
		for k2 in range(6):
			var lz: float = centre.z - 40.0 + 16.0 * float(k2)
			_details.box(Vector3(centre.x, 2.5, lz), Vector3(0.12, 5.0, 0.12), Color(0.3, 0.3, 0.33))
			_details.box(Vector3(centre.x, 5.1, lz), Vector3(0.7, 0.14, 0.4), Color(1.0, 0.95, 0.7))
	if placed > 0:
		_reg("lm_changjeon", "창전거리 풍 아파트 거리 (가상)", centre)


# ---------------------------------------------------------------- 미래과학자거리 풍 탑들

func _future_street(centre: Vector3) -> void:
	var placed: int = 0
	# 1) 원자 고리 탑
	var p1: Vector3 = lm._spot(centre + Vector3(-6.0, 0.0, -34.0), Vector3(26.0, 4.0, 26.0))
	var glass1 = lm._glass_mat(Color(0.30, 0.55, 0.62))
	var t1 = K.MB.new()
	K.frustum(t1, Vector3.ZERO, 12, 6.0, 5.0, 46.0, 0.0, 4.0, 3.2, true)
	var m1 = K.mesh_node(_world, "Future_Atom", t1, glass1)
	m1.position = p1
	K.collider_convex(_world, K.frustum_points(p1, 12, 6.0, 5.0, 46.0, 0.0))
	var ring_m = K.mat(Color(0.85, 0.95, 1.0), 0.35, 0.4, 0.8)
	for ry in [16.0, 28.0, 40.0]:
		var ring = K.MB.new()
		K.frustum(ring, Vector3(0.0, float(ry), 0.0), 20, 10.5, 10.5, 0.9, 0.0, 4.0, 1.0, true)
		var rmi = K.mesh_node(_world, "Future_Ring_%d" % int(ry), ring, ring_m)
		rmi.position = p1
	placed += 1
	await get_tree().physics_frame

	# 2) 비틀린 탑 (층마다 조금씩 돌아간 상자)
	var p2: Vector3 = lm._spot(centre + Vector3(8.0, 0.0, 2.0), Vector3(22.0, 4.0, 22.0))
	var glass2 = lm._glass_mat(Color(0.52, 0.40, 0.66))
	var t2 = K.MB.new()
	for lv in range(6):
		var sz = Vector3(15.0 - 1.4 * float(lv), 7.0, 12.0 - 1.2 * float(lv))
		var cc = Vector3(0.0, 3.5 + 7.0 * float(lv), 0.0)
		var yw: float = 0.22 * float(lv)
		K.box(t2, cc, sz, 4.0, 3.2, yw)
		K.collider_box(_world, p2 + cc, sz, yw)
	var m2 = K.mesh_node(_world, "Future_Twist", t2, glass2)
	m2.position = p2
	placed += 1
	await get_tree().physics_frame

	# 3) 물결 탑 (아래가 넓고 위로 좁아짐)
	var p3: Vector3 = lm._spot(centre + Vector3(-8.0, 0.0, 34.0), Vector3(24.0, 4.0, 20.0))
	var t3 = K.MB.new()
	K.rect_frustum(t3, Vector3.ZERO, 18.0, 14.0, 7.0, 6.0, 52.0, 4.0, 3.2)
	var m3 = K.mesh_node(_world, "Future_Wave", t3, lm._glass_mat(Color(0.86, 0.56, 0.32)))
	m3.position = p3
	var cp = PackedVector3Array()
	for sx in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			cp.append(p3 + Vector3(sx * 9.0, 0.0, sz2 * 7.0))
			cp.append(p3 + Vector3(sx * 3.5, 52.0, sz2 * 3.0))
	K.collider_convex(_world, cp)
	placed += 1
	await get_tree().physics_frame

	# 4) 돛 모양 유리 건물 (옆모습을 다각형으로 세움)
	var p4: Vector3 = lm._spot(centre + Vector3(30.0, 0.0, -14.0), Vector3(22.0, 4.0, 14.0))
	var pts = PackedVector2Array([Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Vector2(8.0, 14.0), Vector2(3.0, 38.0), Vector2(-8.0, 26.0)])
	var t4 = K.MB.new()
	if K.extrude_poly(t4, Vector3.ZERO, pts, 8.0, 4.0, 3.2):
		var m4 = K.mesh_node(_world, "Future_Sail", t4, lm._glass_mat(Color(0.34, 0.62, 0.74)))
		m4.position = p4
		K.collider_box(_world, p4 + Vector3(0.0, 19.0, 0.0), Vector3(16.0, 38.0, 8.0))
		placed += 1
	await get_tree().physics_frame

	if _details != null and placed > 0:
		# 거리 바닥 장식과 가로등
		_details.box(centre + Vector3(0.0, 0.06, 0.0), Vector3(10.0, 0.12, 96.0), Color(0.62, 0.60, 0.58))
		for k in range(7):
			var lz: float = centre.z - 42.0 + 14.0 * float(k)
			_details.box(Vector3(centre.x + 3.0, 2.5, lz), Vector3(0.12, 5.0, 0.12), Color(0.3, 0.3, 0.33))
			_details.sphere(Vector3(centre.x + 3.0, 5.2, lz), Vector3(0.7, 0.7, 0.7), Color(0.7, 0.95, 1.0))
	if placed > 0:
		lm.clear_trees(Vector2(centre.x, centre.z), Vector2(44.0, 56.0))
		_reg("lm_future", "미래과학자거리 풍 (가상)", centre)
