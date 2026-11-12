extends RefCounted
## 건물 겉모습 덧씌우기.
## world_builder.gd 는 건드리지 않고, 이미 만들어진 건물(큰 상자)을 실행 중에 찾아서
##  - 벽 메시를 "창문 칸이 정확히 맞는 UV 의 메시"로 교체 (유리 반사, 창틀, 커튼, 야간 불빛 텍스처)
##  - 지붕을 따로 지붕 재질로 분리
##  - 발코니, 난간, 실외기, 배수관, 기단, 처마, 옥상 구조물, 출입구, 관목, 동 번호판을 덧붙입니다.
## 건물 위치/크기는 읽기만 하므로 사용자가 고친 배치가 그대로 유지됩니다.

const Tex = preload("res://scripts/gfx/gfx_textures.gd")

const MIN_HEIGHT: float = 10.0
const MIN_FOOTPRINT: float = 8.0

var facade_mats: Array = []
var roof_mat: StandardMaterial3D = null
var building_count: int = 0

var _details = null
var _world: Node3D = null
var _quality: int = 1
var _rng = RandomNumberGenerator.new()


func setup_materials() -> void:
	for v in range(6):
		var m = StandardMaterial3D.new()
		m.albedo_texture = Tex.facade(v)
		m.roughness = 1.0
		m.roughness_texture = Tex.facade_rough()
		m.metallic_specular = 0.6
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_texture = Tex.facade_emission()
		m.emission_energy_multiplier = 0.0
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		facade_mats.append(m)
	roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_texture = Tex.roof()
	roof_mat.roughness = 0.95
	roof_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## 야간 불빛 세기를 바꿈 (0 = 꺼짐)
func set_night_glow(amount: float) -> void:
	for m in facade_mats:
		m.emission_energy_multiplier = amount


# ---------------------------------------------------------------- 건물 찾기

func _find_buildings(world: Node3D) -> Array:
	var out: Array = []
	for child in world.get_children():
		if not (child is StaticBody3D):
			continue
		var mi: MeshInstance3D = null
		for c in child.get_children():
			if c is MeshInstance3D and c.mesh is BoxMesh:
				mi = c
				break
		if mi == null:
			continue
		var bm: BoxMesh = mi.mesh
		var gt: Transform3D = mi.global_transform
		var sc: Vector3 = gt.basis.get_scale()
		var sw = Vector3(bm.size.x * sc.x, bm.size.y * sc.y, bm.size.z * sc.z)
		if sw.y < MIN_HEIGHT or minf(sw.x, sw.z) < MIN_FOOTPRINT:
			continue
		out.append({
			"mi": mi, "size_local": bm.size, "scale": sc, "size": sw,
			"xf": Transform3D(gt.basis.orthonormalized(), gt.origin),
		})
	return out


# ---------------------------------------------------------------- 메인

func build(world: Node3D, details, quality: int) -> void:
	_world = world
	_details = details
	_quality = quality
	_rng.seed = 90210
	var list: Array = _find_buildings(world)
	var tree: SceneTree = world.get_tree()
	var n: int = 0
	for b in list:
		_decorate(b, n)
		n += 1
		building_count += 1
		if n % 5 == 0:
			await tree.process_frame


func _decorate(b: Dictionary, index: int) -> void:
	var mi: MeshInstance3D = b["mi"]
	var bs: Vector3 = b["size_local"]
	var sc: Vector3 = b["scale"]
	var S: Vector3 = b["size"]
	var xf: Transform3D = b["xf"]
	var centre: Vector3 = xf.origin

	var variant: int = absi(int(centre.x * 7.3 + centre.z * 3.1) + index * 5) % 6
	var floors: int = maxi(2, roundi(S.y / 3.2))
	var fh: float = S.y / float(floors)

	var front: int = _front_face(centre, xf)
	mi.mesh = _make_mesh(bs, sc, floors, variant, 0.25 * float(index % 4), -0.25 * float((index / 4) % 4))
	mi.material_override = null
	mi.set_surface_override_material(0, null)

	var is_hall: bool = S.x > 60.0 or S.z > 60.0
	var cols: Array = _face_table()
	var detail_col: Color = Color(0.74, 0.73, 0.70)
	var wall_c: Color = Tex.FACADE_PALETTES[variant]
	var plinth_c: Color = Color(0.40, 0.40, 0.41)
	var corn_c: Color = wall_c.lightened(0.18)

	for fi in range(4):
		var f: Array = cols[fi]
		var n: Vector3 = f[0]
		var t: Vector3 = f[1]
		var L: float = _len_along(t, S)
		var half_n: float = _len_along(n, S) * 0.5
		var fb: Basis = xf.basis * Basis(t, Vector3.UP, n)
		var is_front: bool = fi == front
		var is_back: bool = fi == (front ^ 1)

		# 기단, 처마, 옥상 난간
		_face_box(xf, fb, n, t, half_n, L, 0.5 * L, 0.45, 0.06, Vector3(L + 0.08, 0.9, 0.12), S, plinth_c)
		_face_box(xf, fb, n, t, half_n, L, 0.5 * L, S.y - 0.15, 0.10, Vector3(L + 0.4, 0.30, 0.36), S, corn_c)
		_face_box(xf, fb, n, t, half_n, L, 0.5 * L, S.y + 0.3, -0.125, Vector3(L, 0.6, 0.25), S, wall_c.darkened(0.12))

		# 배수관 (앞면 양 끝)
		if is_front or is_back:
			_face_box(xf, fb, n, t, half_n, L, 0.3, S.y * 0.5, 0.07, Vector3(0.12, S.y, 0.12), S, Color(0.46, 0.47, 0.48))
			_face_box(xf, fb, n, t, half_n, L, L - 0.3, S.y * 0.5, 0.07, Vector3(0.12, S.y, 0.12), S, Color(0.46, 0.47, 0.48))

		var margin: float = 0.9
		var cells: int = maxi(1, roundi((L - 2.0 * margin) / 4.0))
		var cw: float = (L - 2.0 * margin) / float(cells)

		if not is_hall and _quality >= 1:
			# 발코니 (앞면은 많이, 뒷면은 적게)
			if is_front or is_back:
				var prob: float = 0.55 if is_front else 0.30
				var budget: int = 120
				for k in range(1, floors):
					for c in range(cells):
						if budget <= 0:
							break
						if _rng.randf() > prob:
							continue
						var d: float = margin + cw * (float(c) + 0.5)
						var yb: float = float(k) * fh
						_balcony(xf, fb, n, t, half_n, L, d, yb, S)
						budget -= 5
			else:
				# 옆면: 실외기
				var ac_n: int = 0
				for k in range(1, floors):
					for c in range(cells):
						if ac_n > 14:
							break
						if _rng.randf() > 0.16:
							continue
						var d2: float = margin + cw * (float(c) + 0.5)
						var ya: float = float(k) * fh + 0.45
						_face_box(xf, fb, n, t, half_n, L, d2 + 0.9, ya, 0.20, Vector3(0.80, 0.55, 0.34), S, Color(0.82, 0.83, 0.84))
						_face_box(xf, fb, n, t, half_n, L, d2 + 0.9, ya, 0.38, Vector3(0.56, 0.40, 0.04), S, Color(0.15, 0.16, 0.17))
						ac_n += 1

		if is_front and not is_hall:
			_entrance(xf, fb, n, t, half_n, L, S, index, wall_c)
			if _quality >= 1:
				_bushes(xf, fb, n, t, half_n, L, S)

	_rooftop(xf, S, wall_c, is_hall)


func _face_table() -> Array:
	return [
		[Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1)],
	]


## 면 번호 f 의 반대쪽 면 번호는 f ^ 1 (0<->1, 2<->3)
func _front_face(centre: Vector3, xf: Transform3D) -> int:
	var dir = Vector3(0, 0, 1)
	if centre.z < -50.0 and absf(centre.x) < 45.0:
		dir = Vector3(0, 0, 1)
	elif absf(centre.z) <= absf(centre.x):
		dir = Vector3(0, 0, -signf(centre.z))
	else:
		dir = Vector3(-signf(centre.x), 0, 0)
	var table: Array = _face_table()
	var best: int = 0
	var best_d: float = -2.0
	for i in range(4):
		var wn: Vector3 = xf.basis * table[i][0]
		var d: float = wn.dot(dir)
		if d > best_d:
			best_d = d
			best = i
	return best


func _len_along(axis: Vector3, S: Vector3) -> float:
	return absf(axis.x) * S.x + absf(axis.y) * S.y + absf(axis.z) * S.z


# ---------------------------------------------------------------- 벽 메시

func _make_mesh(bs: Vector3, sc: Vector3, floors: int, variant: int, ushift: float, vshift: float) -> ArrayMesh:
	var side_v = PackedVector3Array()
	var side_n = PackedVector3Array()
	var side_uv = PackedVector2Array()
	var side_i = PackedInt32Array()
	var v_top: float = -float(floors) / 4.0 + vshift
	var v_bot: float = vshift

	var table: Array = _face_table()
	for fi in range(4):
		var n: Vector3 = table[fi][0]
		var t: Vector3 = table[fi][1]
		var L_local: float = absf(t.x) * bs.x + absf(t.z) * bs.z
		var L_m: float = absf(t.x) * bs.x * sc.x + absf(t.z) * bs.z * sc.z
		var half_n: float = (absf(n.x) * bs.x + absf(n.z) * bs.z) * 0.5
		var p0: Vector3 = n * half_n - t * (L_local * 0.5) + Vector3(0.0, -bs.y * 0.5, 0.0)
		var margin: float = 0.9
		var cells: int = maxi(1, roundi((L_m - 2.0 * margin) / 4.0))
		var s1: float = margin / L_m
		var s2: float = 1.0 - margin / L_m
		# 세 조각: 왼쪽 여백 / 창문 구간 / 오른쪽 여백
		var segs: Array = [
			[0.0, s1, ushift + 0.205, ushift + 0.245],
			[s1, s2, ushift, ushift + float(cells) / 4.0],
			[s2, 1.0, ushift + 0.205, ushift + 0.245],
		]
		for sg in segs:
			var a: float = sg[0]
			var b: float = sg[1]
			var base: int = side_v.size()
			var bl: Vector3 = p0 + t * (L_local * a)
			var br: Vector3 = p0 + t * (L_local * b)
			var up = Vector3(0.0, bs.y, 0.0)
			side_v.append(bl + up)
			side_v.append(br + up)
			side_v.append(br)
			side_v.append(bl)
			for q in range(4):
				side_n.append(n)
			side_uv.append(Vector2(sg[2], v_top))
			side_uv.append(Vector2(sg[3], v_top))
			side_uv.append(Vector2(sg[3], v_bot))
			side_uv.append(Vector2(sg[2], v_bot))
			side_i.append(base)
			side_i.append(base + 1)
			side_i.append(base + 2)
			side_i.append(base)
			side_i.append(base + 2)
			side_i.append(base + 3)

	# 지붕 (위를 향한 면)
	var roof_v = PackedVector3Array()
	var roof_n = PackedVector3Array()
	var roof_uv = PackedVector2Array()
	var roof_i = PackedInt32Array()
	var hx: float = bs.x * 0.5
	var hz: float = bs.z * 0.5
	var ty: float = bs.y * 0.5
	roof_v.append(Vector3(-hx, ty, -hz))
	roof_v.append(Vector3(hx, ty, -hz))
	roof_v.append(Vector3(hx, ty, hz))
	roof_v.append(Vector3(-hx, ty, hz))
	for q in range(4):
		roof_n.append(Vector3.UP)
	var ux: float = bs.x * sc.x / 6.0
	var uz: float = bs.z * sc.z / 6.0
	roof_uv.append(Vector2(0.0, 0.0))
	roof_uv.append(Vector2(ux, 0.0))
	roof_uv.append(Vector2(ux, uz))
	roof_uv.append(Vector2(0.0, uz))
	# 위에서 볼 때 시계 방향: (-x,-z) -> (+x,-z) -> (+x,+z)
	roof_i.append(0)
	roof_i.append(1)
	roof_i.append(2)
	roof_i.append(0)
	roof_i.append(2)
	roof_i.append(3)

	var mesh = ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = side_v
	arr[Mesh.ARRAY_NORMAL] = side_n
	arr[Mesh.ARRAY_TEX_UV] = side_uv
	arr[Mesh.ARRAY_INDEX] = side_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, facade_mats[variant])

	var arr2: Array = []
	arr2.resize(Mesh.ARRAY_MAX)
	arr2[Mesh.ARRAY_VERTEX] = roof_v
	arr2[Mesh.ARRAY_NORMAL] = roof_n
	arr2[Mesh.ARRAY_TEX_UV] = roof_uv
	arr2[Mesh.ARRAY_INDEX] = roof_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
	mesh.surface_set_material(1, roof_mat)
	return mesh


# ---------------------------------------------------------------- 덧붙임 도우미

## 면 좌표(앞으로 off, 면 따라 d, 바닥에서 높이 y)에 상자 하나를 놓음
func _face_box(xf: Transform3D, fb: Basis, n: Vector3, t: Vector3, half_n: float, L: float,
		d: float, y: float, off: float, size: Vector3, S: Vector3, color: Color) -> void:
	var local: Vector3 = n * (half_n + off) + t * (d - L * 0.5) + Vector3(0.0, y - S.y * 0.5, 0.0)
	var world_pos: Vector3 = xf * local
	_details.box_xf(Transform3D(fb, world_pos), size, color)


func _face_cyl(xf: Transform3D, n: Vector3, t: Vector3, half_n: float, L: float,
		d: float, y: float, off: float, radius: float, height: float, S: Vector3, color: Color) -> void:
	var local: Vector3 = n * (half_n + off) + t * (d - L * 0.5) + Vector3(0.0, y - S.y * 0.5, 0.0)
	_details.cyl_xf(Transform3D(xf.basis, xf * local), radius, height, color)


func _balcony(xf: Transform3D, fb: Basis, n: Vector3, t: Vector3, half_n: float, L: float,
		d: float, y: float, S: Vector3) -> void:
	var slab_c: Color = Color(0.74, 0.73, 0.70)
	_face_box(xf, fb, n, t, half_n, L, d, y + 0.07, 0.5, Vector3(2.3, 0.14, 1.0), S, slab_c)
	var glazed: bool = _rng.randf() < 0.30
	if glazed:
		_face_box(xf, fb, n, t, half_n, L, d, y + 0.14 + 0.8, 0.96, Vector3(2.3, 1.6, 0.06), S, Color(0.30, 0.45, 0.55))
		_face_box(xf, fb, n, t, half_n, L, d - 1.1, y + 0.14 + 0.8, 0.5, Vector3(0.08, 1.6, 1.0), S, Color(0.82, 0.82, 0.80))
		_face_box(xf, fb, n, t, half_n, L, d + 1.1, y + 0.14 + 0.8, 0.5, Vector3(0.08, 1.6, 1.0), S, Color(0.82, 0.82, 0.80))
	else:
		var rail_c: Color = Color(0.80, 0.79, 0.75)
		_face_box(xf, fb, n, t, half_n, L, d, y + 0.14 + 0.47, 0.96, Vector3(2.3, 0.94, 0.10), S, rail_c)
		_face_box(xf, fb, n, t, half_n, L, d - 1.1, y + 0.14 + 0.47, 0.5, Vector3(0.10, 0.94, 1.0), S, rail_c)
		_face_box(xf, fb, n, t, half_n, L, d + 1.1, y + 0.14 + 0.47, 0.5, Vector3(0.10, 0.94, 1.0), S, rail_c)
		if _rng.randf() < 0.25:
			# 빨래 / 화분 느낌의 색 띠
			var col = Color.from_hsv(_rng.randf(), 0.35, 0.8)
			_face_box(xf, fb, n, t, half_n, L, d, y + 0.14 + 1.05, 0.9, Vector3(1.2, 0.35, 0.05), S, col)


func _entrance(xf: Transform3D, fb: Basis, n: Vector3, t: Vector3, half_n: float, L: float,
		S: Vector3, index: int, wall_c: Color) -> void:
	var d: float = L * 0.5
	var frame_c: Color = Color(0.20, 0.20, 0.22)
	_face_box(xf, fb, n, t, half_n, L, d, 1.55, 0.09, Vector3(3.4, 3.1, 0.18), S, frame_c)
	_face_box(xf, fb, n, t, half_n, L, d, 1.40, 0.19, Vector3(2.8, 2.7, 0.06), S, Color(0.10, 0.17, 0.24))
	_face_box(xf, fb, n, t, half_n, L, d, 1.40, 0.23, Vector3(0.08, 2.7, 0.05), S, frame_c)
	_face_box(xf, fb, n, t, half_n, L, d, 3.35, 0.9, Vector3(4.4, 0.18, 1.8), S, Color(0.66, 0.65, 0.62))
	_face_cyl(xf, n, t, half_n, L, d - 2.0, 1.65, 1.65, 0.08, 3.3, S, Color(0.55, 0.55, 0.57))
	_face_cyl(xf, n, t, half_n, L, d + 2.0, 1.65, 1.65, 0.08, 3.3, S, Color(0.55, 0.55, 0.57))
	_face_box(xf, fb, n, t, half_n, L, d, 0.075, 0.9, Vector3(4.2, 0.15, 1.5), S, Color(0.58, 0.58, 0.56))
	# 동 번호판
	var label = Label3D.new()
	label.text = "%d동" % (index + 1)
	label.pixel_size = 0.012
	label.font_size = 64
	label.outline_size = 8
	label.modulate = Color(0.95, 0.95, 0.90)
	label.outline_modulate = Color(0.1, 0.1, 0.12)
	label.double_sided = false
	var local: Vector3 = n * (half_n + 0.25) + t * (d - L * 0.5) + Vector3(0.0, 3.95 - S.y * 0.5, 0.0)
	label.transform = Transform3D(fb, xf * local)
	_world.add_child(label)


func _bushes(xf: Transform3D, fb: Basis, n: Vector3, t: Vector3, half_n: float, L: float, S: Vector3) -> void:
	var d: float = 1.6
	while d < L - 1.2:
		if absf(d - L * 0.5) > 3.0:
			var local: Vector3 = n * (half_n + 1.3) + t * (d - L * 0.5) + Vector3(0.0, 0.45 - S.y * 0.5, 0.0)
			var g: float = _rng.randf()
			var col = Color(0.16 + 0.10 * g, 0.34 + 0.16 * g, 0.14 + 0.06 * g)
			_details.sphere(xf * local, Vector3(0.8, 0.5, 0.7), col)
		d += 2.4 + _rng.randf() * 0.8


func _rooftop(xf: Transform3D, S: Vector3, wall_c: Color, is_hall: bool) -> void:
	var gray = Color(0.62, 0.62, 0.63)
	var dark = Color(0.28, 0.29, 0.31)
	var top_y: float = S.y * 0.5
	var lim_x: float = maxf(S.x * 0.5 - 2.4, 0.5)
	var lim_z: float = maxf(S.z * 0.5 - 2.4, 0.5)
	if is_hall:
		# 큰 건물: 지붕 위 깃대 두 개
		for sx in [-1.0, 1.0]:
			var base = Vector3(sx * lim_x * 0.8, top_y, lim_z * 0.2)
			_details.box_xf(Transform3D(xf.basis, xf * (base + Vector3(0, 3.0, 0))), Vector3(0.12, 6.0, 0.12), Color(0.8, 0.8, 0.82))
		return
	# 계단실
	var sp = Vector3(_rng.randf_range(-lim_x, lim_x), top_y + 1.3, _rng.randf_range(-lim_z, lim_z))
	_details.box_xf(Transform3D(xf.basis, xf * sp), Vector3(3.2, 2.6, 3.0), gray)
	_details.box_xf(Transform3D(xf.basis, xf * (sp + Vector3(0, 1.35, 0))), Vector3(3.4, 0.14, 3.2), wall_c.darkened(0.2))
	# 안테나
	var ap = Vector3(_rng.randf_range(-lim_x, lim_x), top_y + 3.0, _rng.randf_range(-lim_z, lim_z))
	_details.box_xf(Transform3D(xf.basis, xf * ap), Vector3(0.08, 6.0, 0.08), dark)
	_details.box_xf(Transform3D(xf.basis, xf * (ap + Vector3(0, 1.8, 0))), Vector3(1.4, 0.06, 0.06), dark)
	_details.box_xf(Transform3D(xf.basis, xf * (ap + Vector3(0, 0.9, 0))), Vector3(1.0, 0.06, 0.06), dark)
	if _quality >= 1:
		# 물탱크
		var wp = Vector3(_rng.randf_range(-lim_x, lim_x), top_y + 1.5, _rng.randf_range(-lim_z, lim_z))
		_details.cyl_xf(Transform3D(xf.basis, xf * wp), 1.2, 2.2, Color(0.70, 0.72, 0.74))
		_details.box_xf(Transform3D(xf.basis, xf * (wp - Vector3(0, 1.3, 0))), Vector3(2.0, 0.4, 2.0), dark)
		# 옥상 환기구, 실외기
		for i in range(3):
			var ep = Vector3(_rng.randf_range(-lim_x, lim_x), top_y + 0.45, _rng.randf_range(-lim_z, lim_z))
			_details.box_xf(Transform3D(xf.basis, xf * ep), Vector3(1.0, 0.9, 0.8), Color(0.78, 0.79, 0.80))
		# 위성 안테나 (기울어진 납작한 원기둥)
		var dp = Vector3(_rng.randf_range(-lim_x, lim_x), top_y + 0.9, _rng.randf_range(-lim_z, lim_z))
		var tilt: Basis = xf.basis * Basis(Vector3.RIGHT, 1.0)
		_details.cyl_xf(Transform3D(tilt, xf * dp), 0.6, 0.06, Color(0.85, 0.86, 0.88))
