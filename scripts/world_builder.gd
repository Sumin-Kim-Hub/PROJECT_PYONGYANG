extends RefCounted
## 가상 도시 구역 생성기 (PHASE 1 블록아웃 버전)
## 모든 건물과 도로는 코드로 만든 단순한 상자입니다.
## 실제 평양 지도를 재현한 것이 아니라 "대로 + 광장 + 아파트 단지" 분위기를 흉내 낸
## 가상의 구역이며, 실제 확인된 구조가 아닙니다.
##
## 좌표 규칙: 1 단위 = 1미터, Y가 위, 북쪽 = -Z, 동쪽 = +X
## 모바일 최적화: 가로등/나무는 MultiMesh(한 번에 그리기)로 묶어 그리는 호출 수를 줄입니다.

const Cfg = preload("res://scripts/game_config.gd")

const ROAD_HALF_WIDTH: float = 8.0
const SIDEWALK_WIDTH: float = 5.0
const PLAZA_HALF: float = 50.0

var _root: Node3D
var _rng := RandomNumberGenerator.new()
var _facade_materials: Array[StandardMaterial3D] = []
var _mat_cache: Dictionary = {}


func build(root: Node3D) -> void:
	_root = root
	_rng.seed = Cfg.RNG_SEED
	_make_facade_materials()
	_build_ground()
	_build_roads()
	_build_plaza()
	_build_monument()
	_build_grand_hall()
	_build_apartment_rows()
	_build_streetlights()
	_build_trees()
	_build_boundary()


# ---------------------------------------------------------------- 재료(머티리얼)

func _flat_material(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var key: String = "%s_%s" % [str(color), str(rough)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	_mat_cache[key] = m
	return m


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _make_facade_materials() -> void:
	var palettes: Array[Color] = [
		Color(0.86, 0.84, 0.76),
		Color(0.74, 0.80, 0.85),
		Color(0.89, 0.79, 0.73),
		Color(0.80, 0.86, 0.78),
	]
	for wall in palettes:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _make_facade_texture(wall)
		# 삼면 매핑: 상자 모든 면에 크기에 맞게 창문이 반복됨 (가로 4m, 세로 3m마다 1칸)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.3333, 0.25)
		m.roughness = 0.95
		_facade_materials.append(m)


func _make_facade_texture(wall: Color) -> ImageTexture:
	var n: int = 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(wall)
	var band: Color = wall.darkened(0.12)
	for y in range(58, 64):
		for x in range(0, n):
			img.set_pixel(x, y, band)
	var glass := Color(0.17, 0.23, 0.31)
	var frame: Color = wall.lightened(0.15)
	for y in range(16, 48):
		for x in range(14, 50):
			var edge: bool = (x < 16 or x >= 48 or y < 18 or y >= 46)
			img.set_pixel(x, y, frame if edge else glass)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- 기본 도형 도우미

func _add_box(pos: Vector3, size: Vector3, mat: Material, collide: bool) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		body.add_child(mi)
		_root.add_child(body)
		return body
	mi.position = pos
	_root.add_child(mi)
	return mi


func _add_column(pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	_root.add_child(body)


func _add_invisible_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	_root.add_child(body)


func _add_multimesh(mesh: Mesh, mat: Material, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	_root.add_child(mmi)


# ---------------------------------------------------------------- 지면, 도로, 광장

func _build_ground() -> void:
	var grass := _flat_material(Color(0.33, 0.42, 0.28), 1.0)
	# 윗면이 y=0 이 되도록 두께 1m 상자를 아래로 배치
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(800.0, 1.0, 800.0), grass, true)


func _build_roads() -> void:
	var road := _flat_material(Color(0.16, 0.16, 0.17), 0.95)
	var walk := _flat_material(Color(0.62, 0.61, 0.58), 0.95)
	var line := _flat_material(Color(0.85, 0.80, 0.45), 0.9)
	var half: float = Cfg.MAP_HALF_SIZE
	var side_off: float = ROAD_HALF_WIDTH + SIDEWALK_WIDTH * 0.5

	# 동서 대로 (X축 방향)
	var len_ew: float = half * 2.0
	_add_box(Vector3(0.0, 0.03, 0.0), Vector3(len_ew, 0.06, ROAD_HALF_WIDTH * 2.0), road, false)
	_add_box(Vector3(0.0, 0.04, -side_off), Vector3(len_ew, 0.08, SIDEWALK_WIDTH), walk, false)
	_add_box(Vector3(0.0, 0.04, side_off), Vector3(len_ew, 0.08, SIDEWALK_WIDTH), walk, false)
	_add_box(Vector3(0.0, 0.055, 0.0), Vector3(len_ew, 0.05, 0.25), line, false)

	# 남북 대로 (광장 북쪽 끝에서 남쪽 지도 끝까지)
	var z0: float = -PLAZA_HALF
	var len_ns: float = half - z0
	var zc: float = (half + z0) * 0.5
	_add_box(Vector3(0.0, 0.03, zc), Vector3(ROAD_HALF_WIDTH * 2.0, 0.06, len_ns), road, false)
	_add_box(Vector3(-side_off, 0.04, zc), Vector3(SIDEWALK_WIDTH, 0.08, len_ns), walk, false)
	_add_box(Vector3(side_off, 0.04, zc), Vector3(SIDEWALK_WIDTH, 0.08, len_ns), walk, false)
	_add_box(Vector3(0.0, 0.055, zc), Vector3(0.25, 0.05, len_ns), line, false)


func _build_plaza() -> void:
	var stone := _flat_material(Color(0.72, 0.72, 0.70), 0.85)
	var stone_dark := _flat_material(Color(0.60, 0.59, 0.57), 0.85)
	# 눈에 보이는 높이만 다르고, 실제 걷는 바닥(충돌)은 지면 하나입니다.
	_add_box(Vector3(0.0, 0.05, 0.0), Vector3(PLAZA_HALF * 2.0, 0.1, PLAZA_HALF * 2.0), stone, false)
	_add_box(Vector3(0.0, 0.06, 0.0), Vector3(60.0, 0.12, 60.0), stone_dark, false)


func _build_monument() -> void:
	var stone := _flat_material(Color(0.82, 0.80, 0.76), 0.8)
	var dark := _flat_material(Color(0.35, 0.36, 0.38), 0.7)
	_add_box(Vector3(0.0, 0.6, 0.0), Vector3(14.0, 1.2, 14.0), stone, true)
	_add_box(Vector3(0.0, 2.2, 0.0), Vector3(10.0, 2.0, 10.0), stone, true)
	_add_box(Vector3(0.0, 15.2, 0.0), Vector3(5.0, 24.0, 5.0), stone, true)
	_add_box(Vector3(0.0, 27.95, 0.0), Vector3(6.4, 1.5, 6.4), dark, false)

	var sm := SphereMesh.new()
	sm.radius = 2.0
	sm.height = 4.0
	sm.radial_segments = 10
	sm.rings = 5
	var flame := MeshInstance3D.new()
	flame.mesh = sm
	flame.material_override = _emissive_material(Color(1.0, 0.45, 0.1), 2.5)
	flame.position = Vector3(0.0, 30.3, 0.0)
	_root.add_child(flame)


func _build_grand_hall() -> void:
	# 광장 북쪽의 큰 공공건물 (외관만 있는 가상 건물, 내부는 PHASE 3에서)
	var wall := _flat_material(Color(0.88, 0.85, 0.76), 0.9)
	var roof := _flat_material(Color(0.30, 0.42, 0.50), 0.8)
	var door := _flat_material(Color(0.12, 0.10, 0.09), 0.9)
	var cz: float = -68.0

	_add_box(Vector3(0.0, 9.0, cz), Vector3(80.0, 18.0, 24.0), wall, true)
	_add_box(Vector3(0.0, 14.0, cz - 1.0), Vector3(30.0, 28.0, 22.0), wall, true)
	_add_box(Vector3(0.0, 28.4, cz - 1.0), Vector3(32.0, 0.8, 24.0), roof, false)
	_add_box(Vector3(0.0, 18.3, cz), Vector3(82.0, 0.6, 26.0), roof, false)

	var front_z: float = cz + 12.0
	for i in range(6):
		var x: float = -30.0 + i * 12.0
		_add_column(Vector3(x, 5.0, front_z + 2.5), 0.9, 10.0, wall)
	_add_box(Vector3(0.0, 10.5, front_z + 2.5), Vector3(70.0, 1.0, 5.0), wall, false)
	_add_box(Vector3(0.0, 2.5, front_z + 0.1), Vector3(9.0, 5.0, 0.3), door, false)


# ---------------------------------------------------------------- 아파트 단지

func _build_apartment_rows() -> void:
	# 동쪽, 서쪽, 남쪽 대로 양옆에 아파트를 줄지어 배치 (x,z 평면의 방향 벡터)
	var arms: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)]
	for dir in arms:
		var perp := Vector2(-dir.y, dir.x)
		var along_x: bool = absf(dir.x) > 0.5
		for side in [-1.0, 1.0]:
			for k in range(6):
				var along: float = 64.0 + k * 28.0 + _rng.randf_range(-2.0, 2.0)
				var w: float = _rng.randf_range(16.0, 22.0)   # 도로를 따라가는 길이
				var d: float = _rng.randf_range(12.0, 16.0)   # 도로에서 멀어지는 깊이
				var h: float = _rng.randf_range(22.0, 50.0)
				var off: float = ROAD_HALF_WIDTH + SIDEWALK_WIDTH + 3.0 + d * 0.5
				var c2: Vector2 = dir * along + perp * (side * off)
				var size: Vector3
				if along_x:
					size = Vector3(w, h, d)
				else:
					size = Vector3(d, h, w)
				var mat: StandardMaterial3D = _facade_materials[_rng.randi() % _facade_materials.size()]
				_add_box(Vector3(c2.x, h * 0.5, c2.y), size, mat, true)


# ---------------------------------------------------------------- 가로등, 나무

func _build_streetlights() -> void:
	var spots: Array[Vector3] = []
	var lamp_off: float = ROAD_HALF_WIDTH + SIDEWALK_WIDTH * 0.5
	var limit: float = Cfg.MAP_HALF_SIZE - 8.0

	var x: float = 80.0
	while x <= limit:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				spots.append(Vector3(sx * x, 0.0, sz * lamp_off))
		x += 32.0

	var z: float = 80.0
	while z <= limit:
		for sx in [-1.0, 1.0]:
			spots.append(Vector3(sx * lamp_off, 0.0, z))
		z += 32.0

	# 광장 모서리
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			spots.append(Vector3(sx * 46.0, 0.0, sz * 46.0))

	var poles: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	for p in spots:
		poles.append(Transform3D(Basis.IDENTITY, p + Vector3(0.0, 3.0, 0.0)))
		heads.append(Transform3D(Basis.IDENTITY, p + Vector3(0.0, 6.2, 0.0)))

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = 6.0
	pole_mesh.radial_segments = 6
	pole_mesh.rings = 1
	_add_multimesh(pole_mesh, _flat_material(Color(0.25, 0.26, 0.28), 0.7), poles)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.35
	head_mesh.height = 0.7
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	_add_multimesh(head_mesh, _emissive_material(Color(1.0, 0.92, 0.7), 1.5), heads)


func _build_trees() -> void:
	var spots: Array[Vector3] = []
	var scales: Array[float] = []
	var tree_off: float = ROAD_HALF_WIDTH + 4.2
	var limit: float = Cfg.MAP_HALF_SIZE - 8.0

	# 대로 가장자리 가로수 (가로등 사이 16m 지점)
	var x: float = 64.0
	while x <= limit:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				spots.append(Vector3(sx * x, 0.0, sz * tree_off))
				scales.append(_rng.randf_range(0.9, 1.2))
		x += 32.0

	var z: float = 64.0
	while z <= limit:
		for sx in [-1.0, 1.0]:
			spots.append(Vector3(sx * tree_off, 0.0, z))
			scales.append(_rng.randf_range(0.9, 1.2))
		z += 32.0

	# 북쪽 공원 지대에 흩어진 나무
	for i in range(45):
		var px: float = _rng.randf_range(-200.0, 200.0)
		var pz: float = _rng.randf_range(-210.0, -95.0)
		spots.append(Vector3(px, 0.0, pz))
		scales.append(_rng.randf_range(0.8, 1.4))

	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for i in range(spots.size()):
		var s: float = scales[i]
		var basis := Basis.IDENTITY.scaled(Vector3(s, s, s))
		trunks.append(Transform3D(basis, spots[i] + Vector3(0.0, 1.25 * s, 0.0)))
		crowns.append(Transform3D(basis, spots[i] + Vector3(0.0, 3.9 * s, 0.0)))

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 2.5
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	_add_multimesh(trunk_mesh, _flat_material(Color(0.35, 0.25, 0.15), 1.0), trunks)

	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.9
	crown_mesh.height = 3.8
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5
	_add_multimesh(crown_mesh, _flat_material(Color(0.20, 0.42, 0.20), 1.0), crowns)


# ---------------------------------------------------------------- 지도 경계

func _build_boundary() -> void:
	var h: float = Cfg.MAP_HALF_SIZE + 1.0
	var span: float = h * 2.0 + 4.0
	_add_invisible_wall(Vector3(0.0, 10.0, -h), Vector3(span, 20.0, 2.0))
	_add_invisible_wall(Vector3(0.0, 10.0, h), Vector3(span, 20.0, 2.0))
	_add_invisible_wall(Vector3(-h, 10.0, 0.0), Vector3(2.0, 20.0, span))
	_add_invisible_wall(Vector3(h, 10.0, 0.0), Vector3(2.0, 20.0, span))
