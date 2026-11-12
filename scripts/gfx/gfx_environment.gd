extends RefCounted
## 도시 환경 덧씌우기 (world_builder.gd 는 수정하지 않음).
##  - 이미 만들어진 지면/도로/인도/광장 상자를 찾아 텍스처 재질로 교체
##  - 차선, 갓길선, 연석, 횡단보도, 표지판, 버스 정류장, 전봇대와 전선
##  - 화단, 침엽수, 관목, 강과 다리, 랜드마크(승리문, 피라미드 타워, 기념탑 장식)
## 모든 색 물체는 gfx_details.gd 의 MultiMesh 로 묶여 그려집니다.

const Tex = preload("res://scripts/gfx/gfx_textures.gd")
const Cfg = preload("res://scripts/game_config.gd")
const Flags = preload("res://scripts/data/feature_flags.gd")

var lamp_positions: Array = []
var lamp_mat: StandardMaterial3D = null
var water_mat: StandardMaterial3D = null

var _world: Node3D = null
var _details = null
var _quality: int = 1
var _rng = RandomNumberGenerator.new()

var _road_half: float = 8.0
var _walk_w: float = 5.0
var _plaza_half: float = 50.0
var _map_half: float = Cfg.MAP_HALF_SIZE
var _tree_mms: Array = []
var _leaf_mat: StandardMaterial3D = null

const RIVER_Z: float = -150.0
const RIVER_W: float = 18.0
const BRIDGE_X: float = 60.0


func build(world: Node3D, details, quality: int) -> void:
	_world = world
	_details = details
	_quality = quality
	_rng.seed = 424242
	var tree: SceneTree = world.get_tree()

	_retexture()
	_find_special()
	await tree.process_frame
	_roadwork()
	await tree.process_frame
	_landscape()
	_river()
	await tree.process_frame
	_landmarks()


# ---------------------------------------------------------------- 재질 교체

func _tri_mat(tex: Texture2D, scale: float, rough: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _near(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol


func _box_instances() -> Array:
	var out: Array = []
	for child in _world.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			out.append(child)
		elif child is StaticBody3D:
			for c in child.get_children():
				if c is MeshInstance3D and c.mesh is BoxMesh:
					out.append(c)
	return out


func _retexture() -> void:
	var asphalt: StandardMaterial3D = _tri_mat(Tex.asphalt(), 0.25, 0.95)
	var sidewalk: StandardMaterial3D = _tri_mat(Tex.sidewalk(), 0.25, 0.9)
	var plaza: StandardMaterial3D = _tri_mat(Tex.plaza_stone(), 0.25, 0.85)
	var plaza_dark: StandardMaterial3D = _tri_mat(Tex.plaza_stone(), 0.25, 0.85)
	plaza_dark.albedo_color = Color(0.80, 0.80, 0.80)
	var grass: StandardMaterial3D = _tri_mat(Tex.grass(), 0.125, 1.0)

	for mi in _box_instances():
		var bm: BoxMesh = mi.mesh
		var s: Vector3 = bm.size
		var col = Color(0, 0, 0)
		var old = mi.material_override
		if old is StandardMaterial3D:
			col = old.albedo_color
		var mn: float = minf(s.x, s.z)
		var mx: float = maxf(s.x, s.z)
		if s.y >= 0.9 and mn >= 400.0:
			mi.material_override = grass
		elif s.y <= 0.15:
			if mn >= 30.0 and mx <= 200.0:
				mi.material_override = plaza_dark if col.r < 0.66 else plaza
				if mn > 90.0:
					_plaza_half = mn * 0.5
			elif mx >= 100.0 and mn <= 20.0:
				if _near(col, Color(0.16, 0.16, 0.17), 0.06):
					mi.material_override = asphalt
					if mn > 10.0:
						_road_half = mn * 0.5
				elif _near(col, Color(0.62, 0.61, 0.58), 0.06):
					mi.material_override = sidewalk
					_walk_w = mn


## 나무(잎/줄기)와 가로등 머리 찾기
func _find_special() -> void:
	_leaf_mat = StandardMaterial3D.new()
	_leaf_mat.albedo_texture = Tex.foliage()
	_leaf_mat.uv1_triplanar = true
	_leaf_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	_leaf_mat.roughness = 0.95
	_leaf_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	for c in _world.get_children():
		if not (c is MultiMeshInstance3D) or c.multimesh == null:
			continue
		var m: Mesh = c.multimesh.mesh
		if m is SphereMesh:
			var r: float = (m as SphereMesh).radius
			if absf(r - 1.9) < 0.3:
				c.material_override = _leaf_mat
				_tree_mms.append(c)
			elif absf(r - 0.35) < 0.06:
				if c.material_override is StandardMaterial3D:
					lamp_mat = c.material_override
				for i in range(c.multimesh.instance_count):
					lamp_positions.append(c.multimesh.get_instance_transform(i).origin)
		elif m is CylinderMesh:
			if absf((m as CylinderMesh).height - 2.5) < 0.3:
				_tree_mms.append(c)


## 반경 안의 나무를 숨김 (크기를 0 으로)
func _clear_trees(centre: Vector2, half: Vector2) -> void:
	for mmi in _tree_mms:
		var mm: MultiMesh = mmi.multimesh
		for i in range(mm.instance_count):
			var t: Transform3D = mm.get_instance_transform(i)
			if absf(t.origin.x - centre.x) < half.x and absf(t.origin.z - centre.y) < half.y:
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 0.0001)), t.origin))


# ---------------------------------------------------------------- 도로 설비

func _roadwork() -> void:
	var white = Color(0.92, 0.92, 0.90)
	var start: float = _plaza_half + 0.5
	var end_v: float = _map_half - 2.0
	var length: float = end_v - start
	var mark_y: float = 0.071

	# 차선(점선)과 갓길선(실선) - 동서 대로 양쪽, 남북 대로 남쪽
	for sx in [-1.0, 1.0]:
		for lane in [-0.5, 0.5]:
			var x: float = start
			while x < end_v - 3.0:
				_details.box(Vector3(sx * (x + 1.5), mark_y, lane * _road_half), Vector3(3.0, 0.02, 0.15), white)
				x += 7.0
		for edge in [-1.0, 1.0]:
			_details.box(Vector3(sx * (start + length * 0.5), mark_y, edge * (_road_half - 0.4)), Vector3(length, 0.02, 0.15), white)
			_details.box(Vector3(sx * (start + length * 0.5), 0.08, edge * (_road_half + 0.1)), Vector3(length, 0.16, 0.2), Color(0.72, 0.72, 0.70))
	for lane2 in [-0.5, 0.5]:
		var z: float = start
		while z < end_v - 3.0:
			_details.box(Vector3(lane2 * _road_half, mark_y, z + 1.5), Vector3(0.15, 0.02, 3.0), white)
			z += 7.0
	for edge2 in [-1.0, 1.0]:
		_details.box(Vector3(edge2 * (_road_half - 0.4), mark_y, start + length * 0.5), Vector3(0.15, 0.02, length), white)
		_details.box(Vector3(edge2 * (_road_half + 0.1), 0.08, start + length * 0.5), Vector3(0.2, 0.16, length), Color(0.72, 0.72, 0.70))

	# 횡단보도 + 표지판
	for cx in [-150.0, -70.0, 70.0, 150.0]:
		_crosswalk_ew(cx)
		for sz in [-1.0, 1.0]:
			_sign_pole(Vector3(cx + 3.0 * signf(cx), 0.0, sz * (_road_half + 0.9)), PI * 0.5)
	for cz in [70.0, 150.0]:
		_crosswalk_ns(cz)
		for sx2 in [-1.0, 1.0]:
			_sign_pole(Vector3(sx2 * (_road_half + 0.9), 0.0, cz - 3.0), 0.0)

	# 버스 정류장
	var side: float = _road_half + _walk_w - 1.5
	_bus_stop(Vector3(104.0, 0.0, -side), PI)
	_bus_stop(Vector3(-104.0, 0.0, side), 0.0)
	_bus_stop(Vector3(side, 0.0, 104.0), PI * 0.5)
	_bus_stop(Vector3(-side, 0.0, 178.0), -PI * 0.5)

	# 전봇대와 전선
	var pole_z: float = _road_half + _walk_w + 0.8
	for sz2 in [-1.0, 1.0]:
		for sx4 in [-1.0, 1.0]:
			var prev_x: float = 0.0
			var first: bool = true
			for px2 in [100.0, 140.0, 180.0, 220.0]:
				var p = Vector3(sx4 * px2, 0.0, sz2 * pole_z)
				_utility_pole(p, PI * 0.5)
				if not first:
					for off in [-0.9, 0.0, 0.9]:
						_details.box(Vector3(sx4 * (px2 + prev_x) * 0.5, 8.35, sz2 * pole_z + off), Vector3(40.0, 0.03, 0.03), Color(0.08, 0.08, 0.09))
				prev_x = px2
				first = false


func _crosswalk_ew(x: float) -> void:
	var z: float = -_road_half + 0.9
	while z <= _road_half - 0.8:
		_details.box(Vector3(x, 0.072, z), Vector3(3.2, 0.02, 0.5), Color(0.93, 0.93, 0.91))
		z += 1.0


func _crosswalk_ns(z: float) -> void:
	var x: float = -_road_half + 0.9
	while x <= _road_half - 0.8:
		_details.box(Vector3(x, 0.072, z), Vector3(0.5, 0.02, 3.2), Color(0.93, 0.93, 0.91))
		x += 1.0


func _collider(pos: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var cs = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	_world.add_child(body)


func _sign_pole(pos: Vector3, yaw: float) -> void:
	var b = Basis(Vector3.UP, yaw)
	_details.box_xf(Transform3D(b, pos + Vector3(0, 1.5, 0)), Vector3(0.07, 3.0, 0.07), Color(0.55, 0.56, 0.58))
	_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 2.65, 0.06)), Vector3(0.75, 0.75, 0.04), Color(0.10, 0.28, 0.62))
	_details.box_xf(Transform3D(b, pos + b * Vector3(0.0, 2.65, 0.09)), Vector3(0.40, 0.40, 0.03), Color(0.95, 0.95, 0.95))
	_collider(pos + Vector3(0, 1.5, 0), Vector3(0.2, 3.0, 0.2))


func _utility_pole(pos: Vector3, yaw: float) -> void:
	var b = Basis(Vector3.UP, yaw)
	var wood = Color(0.30, 0.22, 0.15)
	_details.box_xf(Transform3D(b, pos + Vector3(0, 4.5, 0)), Vector3(0.22, 9.0, 0.22), wood)
	_details.box_xf(Transform3D(b, pos + Vector3(0, 8.4, 0)), Vector3(2.2, 0.12, 0.12), wood)
	_details.box_xf(Transform3D(b, pos + Vector3(0, 7.6, 0)), Vector3(1.6, 0.10, 0.10), wood)
	_collider(pos + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3))


## yaw: 로컬 -Z 가 도로 쪽(앞)이 되도록 돌림. 로컬 +Z 쪽이 뒷벽
func _bus_stop(pos: Vector3, yaw: float) -> void:
	var b = Basis(Vector3.UP, yaw)
	var glass = Color(0.45, 0.58, 0.64)
	var steel = Color(0.35, 0.36, 0.38)
	_details.box_xf(Transform3D(b, pos + b * Vector3(0, 2.6, 0.1)), Vector3(4.8, 0.12, 2.0), Color(0.22, 0.24, 0.28))
	_details.box_xf(Transform3D(b, pos + b * Vector3(0, 1.4, 0.7)), Vector3(4.4, 1.9, 0.06), glass)
	_details.box_xf(Transform3D(b, pos + b * Vector3(-2.2, 1.4, 0.1)), Vector3(0.06, 1.9, 1.4), glass)
	_details.box_xf(Transform3D(b, pos + b * Vector3(2.2, 1.4, 0.1)), Vector3(0.06, 1.9, 1.4), glass)
	for px in [-2.3, 2.3]:
		_details.box_xf(Transform3D(b, pos + b * Vector3(px, 1.3, -0.8)), Vector3(0.08, 2.6, 0.08), steel)
		_details.box_xf(Transform3D(b, pos + b * Vector3(px, 1.3, 0.7)), Vector3(0.08, 2.6, 0.08), steel)
	_details.box_xf(Transform3D(b, pos + b * Vector3(0, 0.5, 0.4)), Vector3(3.0, 0.08, 0.45), Color(0.55, 0.40, 0.25))
	_details.box_xf(Transform3D(b, pos + b * Vector3(0, 0.25, 0.4)), Vector3(2.8, 0.5, 0.1), steel)
	# 정류장 표지
	_details.box_xf(Transform3D(b, pos + b * Vector3(3.2, 1.6, 0.3)), Vector3(0.07, 3.2, 0.07), Color(0.55, 0.56, 0.58))
	_details.box_xf(Transform3D(b, pos + b * Vector3(3.2, 3.0, 0.3)), Vector3(0.7, 0.5, 0.05), Color(0.15, 0.45, 0.25))
	_details.cyl_xf(Transform3D(b, pos + b * Vector3(-3.0, 0.45, 0.2)), 0.25, 0.9, Color(0.20, 0.30, 0.22))
	_collider(pos + b * Vector3(0, 1.3, 0.3), Vector3(4.8, 2.6, 1.2), yaw)


# ---------------------------------------------------------------- 조경

func _landscape() -> void:
	# 광장 화단 4개
	var flower_cols: Array = [
		Color(0.85, 0.15, 0.15), Color(0.95, 0.80, 0.15), Color(0.95, 0.95, 0.92),
		Color(0.60, 0.25, 0.70), Color(0.95, 0.45, 0.65),
	]
	var n_grid: int = 8 if _quality >= 1 else 4
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c = Vector3(sx * 26.0, 0.0, sz * 26.0)
			var stone = Color(0.70, 0.69, 0.66)
			_details.box(c + Vector3(0, 0.2, -5.0), Vector3(10.4, 0.4, 0.5), stone)
			_details.box(c + Vector3(0, 0.2, 5.0), Vector3(10.4, 0.4, 0.5), stone)
			_details.box(c + Vector3(-5.0, 0.2, 0), Vector3(0.5, 0.4, 9.6), stone)
			_details.box(c + Vector3(5.0, 0.2, 0), Vector3(0.5, 0.4, 9.6), stone)
			_details.box(c + Vector3(0, 0.15, 0), Vector3(9.4, 0.3, 9.4), Color(0.22, 0.15, 0.10))
			for gx in range(n_grid):
				for gz in range(n_grid):
					var fx: float = -4.0 + (float(gx) + 0.5) * (8.0 / float(n_grid))
					var fz: float = -4.0 + (float(gz) + 0.5) * (8.0 / float(n_grid))
					var col: Color = flower_cols[_rng.randi() % flower_cols.size()]
					_details.sphere(c + Vector3(fx, 0.42, fz), Vector3(0.28, 0.22, 0.28), col)

	# 북쪽 공원: 침엽수와 관목
	var cone_n: int = 34 if _quality >= 1 else 16
	for i in range(cone_n):
		var p = Vector3(_rng.randf_range(-200.0, 200.0), 0.0, _rng.randf_range(-215.0, -92.0))
		if absf(p.z - RIVER_Z) < RIVER_W * 0.5 + 6.0:
			continue
		if absf(p.x - BRIDGE_X) < 8.0 and p.z < -120.0:
			continue
		if absf(p.x) < 42.0 and p.z > -86.0:
			continue
		var sc: float = _rng.randf_range(0.8, 1.35)
		var g: float = _rng.randf()
		var dark = Color(0.08 + 0.05 * g, 0.22 + 0.10 * g, 0.12 + 0.05 * g)
		_details.box(p + Vector3(0, 0.6 * sc, 0), Vector3(0.3 * sc, 1.2 * sc, 0.3 * sc), Color(0.30, 0.20, 0.12))
		_details.cone(p + Vector3(0, 2.2 * sc, 0), 1.9 * sc, 2.6 * sc, dark)
		_details.cone(p + Vector3(0, 3.7 * sc, 0), 1.45 * sc, 2.4 * sc, dark.lightened(0.04))
		_details.cone(p + Vector3(0, 5.0 * sc, 0), 0.95 * sc, 2.2 * sc, dark.lightened(0.08))
		_clear_trees(Vector2(p.x, p.z), Vector2(2.2, 2.2))
	var bush_n: int = 60 if _quality >= 1 else 20
	for j in range(bush_n):
		var q = Vector3(_rng.randf_range(-220.0, 220.0), 0.0, _rng.randf_range(-215.0, -92.0))
		if absf(q.z - RIVER_Z) < RIVER_W * 0.5 + 4.0:
			continue
		if absf(q.x) < 42.0 and q.z > -86.0:
			continue
		var g2: float = _rng.randf()
		_details.sphere(q + Vector3(0, 0.5, 0), Vector3(0.9, 0.55, 0.8), Color(0.16 + 0.12 * g2, 0.32 + 0.14 * g2, 0.12 + 0.06 * g2))

	# 광장 가장자리 관목 울타리
	var e: float = _plaza_half + 1.5
	var t: float = -_plaza_half + 6.0
	while t <= _plaza_half - 6.0:
		if absf(t) > _road_half + _walk_w + 2.0:
			var g3: float = _rng.randf()
			var col3 = Color(0.14 + 0.10 * g3, 0.30 + 0.12 * g3, 0.12)
			_details.sphere(Vector3(t, 0.5, -e), Vector3(0.9, 0.55, 0.8), col3)
			_details.sphere(Vector3(t, 0.5, e), Vector3(0.9, 0.55, 0.8), col3)
			_details.sphere(Vector3(-e, 0.5, t), Vector3(0.8, 0.55, 0.9), col3)
			_details.sphere(Vector3(e, 0.5, t), Vector3(0.8, 0.55, 0.9), col3)
		t += 3.0


# ---------------------------------------------------------------- 강과 다리

func _river() -> void:
	var half: float = _map_half
	var zn: float = RIVER_Z - RIVER_W * 0.5
	var zs: float = RIVER_Z + RIVER_W * 0.5

	# 물
	var plane = PlaneMesh.new()
	plane.size = Vector2(half * 2.0, RIVER_W)
	water_mat = StandardMaterial3D.new()
	water_mat.albedo_texture = Tex.water()
	water_mat.albedo_color = Color(1, 1, 1, 0.88)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.05
	water_mat.metallic_specular = 0.9
	water_mat.uv1_scale = Vector3(half / 6.0, 1.5, 1.0)
	water_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var water = MeshInstance3D.new()
	water.name = "River"
	water.mesh = plane
	water.material_override = water_mat
	water.position = Vector3(0.0, 0.05, RIVER_Z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(water)

	# 둑 (충돌 있음): 다리 자리를 비움
	var gap0: float = BRIDGE_X - 4.7
	var gap1: float = BRIDGE_X + 4.7
	var stone = Color(0.62, 0.61, 0.58)
	var cap = Color(0.78, 0.77, 0.74)
	for zz in [zn - 0.5, zs + 0.5]:
		var segs: Array = [[-half, gap0], [gap1, half]]
		for sg in segs:
			var a: float = sg[0]
			var b: float = sg[1]
			var len_v: float = b - a
			var cx: float = (a + b) * 0.5
			_collider(Vector3(cx, 0.6, zz), Vector3(len_v, 1.2, 1.0))
			_details.box(Vector3(cx, 0.55, zz), Vector3(len_v, 1.1, 1.0), stone)
			_details.box(Vector3(cx, 1.15, zz), Vector3(len_v, 0.12, 1.2), cap)

	# 다리: 상판은 걷는 바닥 높이에 깔고 양옆 난간은 충돌 있음
	var deck_len: float = RIVER_W + 4.0
	_details.box(Vector3(BRIDGE_X, 0.09, RIVER_Z), Vector3(9.0, 0.08, deck_len), Color(0.55, 0.55, 0.57))
	for sx in [-1.0, 1.0]:
		var rx: float = BRIDGE_X + sx * 4.35
		_collider(Vector3(rx, 0.7, RIVER_Z), Vector3(0.3, 1.4, deck_len))
		_details.box(Vector3(rx, 0.55, RIVER_Z), Vector3(0.3, 1.1, deck_len), stone)
		_details.box(Vector3(rx, 1.15, RIVER_Z), Vector3(0.5, 0.14, deck_len), cap)
		var zk: float = -deck_len * 0.5 + 1.0
		while zk <= deck_len * 0.5:
			_details.box(Vector3(rx, 2.0, RIVER_Z + zk), Vector3(0.22, 1.6, 0.22), Color(0.30, 0.30, 0.33))
			zk += 5.0
	# 물이 보이도록 나무를 치움
	_clear_trees(Vector2(0.0, RIVER_Z), Vector2(half, RIVER_W * 0.5 + 3.0))


# ---------------------------------------------------------------- 랜드마크 (가상)

func _landmarks() -> void:
	# V1 랜드마크 모듈(v1/landmarks.gd)이 켜져 있으면 더 자세한 개선문/피라미드 타워가 대신 만들어짐
	if not (Flags.ENABLE_V1 and Flags.V1_LANDMARKS):
		_victory_gate()
		_pyramid_tower()
	_monument_dressing()


## 광장 남쪽 입구의 기념문 (반원 아치 + 위쪽 장식 블록)
func _victory_gate() -> void:
	var cz: float = _plaza_half - 10.0
	var stone = Color(0.80, 0.78, 0.72)
	var dark = Color(0.62, 0.60, 0.55)
	var gold = Color(0.78, 0.65, 0.22)
	var px: float = 19.0
	for sx in [-1.0, 1.0]:
		_details.box(Vector3(sx * px, 6.0, cz), Vector3(6.0, 12.0, 8.0), stone)
		_details.box(Vector3(sx * px, 0.4, cz), Vector3(7.0, 0.8, 9.0), dark)
		_collider(Vector3(sx * px, 6.0, cz), Vector3(6.0, 12.0, 8.0))
		# 기둥 장식 홈
		for k in range(3):
			_details.box(Vector3(sx * (px - 3.05), 6.0, cz - 2.5 + 2.5 * float(k)), Vector3(0.12, 10.0, 0.9), dark)
	# 반원 아치: 조각 상자를 이어 붙임
	var steps: int = 16
	var r_mid: float = 17.5
	for i in range(steps):
		var a0: float = PI * float(i) / float(steps)
		var a1: float = PI * float(i + 1) / float(steps)
		var am: float = (a0 + a1) * 0.5
		var cx: float = cos(am) * r_mid
		var cy: float = 12.0 + sin(am) * r_mid
		var seg_len: float = 2.0 * r_mid * sin((a1 - a0) * 0.5) + 0.25
		# 로컬 x 가 접선 방향이 되도록 z 축 둘레로 회전
		var bas = Basis(Vector3.BACK, am + PI * 0.5)
		_details.box_xf(Transform3D(bas, Vector3(cx, cy, cz)), Vector3(seg_len, 3.0, 8.0), stone)
	# 위쪽 블록(꼭대기 장식)
	_details.box(Vector3(0.0, 33.0, cz), Vector3(50.0, 5.0, 9.0), stone)
	_details.box(Vector3(0.0, 36.0, cz), Vector3(52.0, 1.2, 9.6), dark)
	_details.box(Vector3(0.0, 33.0, cz - 4.6), Vector3(30.0, 2.0, 0.3), gold)
	for k2 in range(9):
		_details.box(Vector3(-20.0 + 5.0 * float(k2), 33.0, cz - 4.7), Vector3(0.9, 4.4, 0.4), dark)


## 멀리서도 보이는 피라미드형 고층 타워 (가상의 호텔 타워)
func _pyramid_tower() -> void:
	var pos = Vector3(-135.0, 0.0, -110.0)
	var mesh = CylinderMesh.new()
	mesh.top_radius = 2.2
	mesh.bottom_radius = 26.0
	mesh.height = 105.0
	mesh.radial_segments = 4
	mesh.rings = 1
	var m = StandardMaterial3D.new()
	m.albedo_texture = Tex.facade(5)
	m.uv1_scale = Vector3(9.0, 9.0, 1.0)
	m.roughness = 0.35
	m.metallic = 0.35
	m.metallic_specular = 0.7
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mi = MeshInstance3D.new()
	mi.name = "PyramidTower"
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos + Vector3(0.0, 52.5, 0.0)
	mi.rotation.y = PI * 0.25
	_world.add_child(mi)
	_details.box(pos + Vector3(0, 0.5, 0), Vector3(40.0, 1.0, 40.0), Color(0.60, 0.60, 0.58))
	_details.cyl(pos + Vector3(0, 108.0, 0), 0.2, 12.0, Color(0.7, 0.7, 0.72))
	_collider(pos + Vector3(0, 12.0, 0), Vector3(34.0, 24.0, 34.0))
	_clear_trees(Vector2(pos.x, pos.z), Vector2(32.0, 32.0))


## 광장 기념탑 주변 장식 (원래 탑은 건드리지 않음)
func _monument_dressing() -> void:
	var stone = Color(0.84, 0.82, 0.78)
	_details.box(Vector3(0, 0.12, 0), Vector3(24.0, 0.24, 24.0), stone)
	_details.box(Vector3(0, 0.26, 0), Vector3(20.0, 0.12, 20.0), Color(0.78, 0.76, 0.72))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			# 모서리 기둥과 깃대
			_details.cyl(Vector3(sx * 11.0, 2.5, sz * 11.0), 0.5, 5.0, stone)
			_details.box(Vector3(sx * 11.0, 11.0, sz * 11.0), Vector3(0.14, 12.0, 0.14), Color(0.8, 0.8, 0.82))
			_details.box(Vector3(sx * 11.0 + 0.9, 15.8, sz * 11.0), Vector3(1.8, 1.1, 0.04), Color(0.75, 0.18, 0.16))
