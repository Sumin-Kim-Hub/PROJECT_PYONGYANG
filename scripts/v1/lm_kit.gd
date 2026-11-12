extends RefCounted
## 랜드마크용 도우미 (정적 함수 모음): 메시 조립, 절차 텍스처, 충돌체, 간판.
## 메시 조립(MB)은 면의 "바깥 방향"을 알려 주면 감기는 순서(앞면)를 스스로 맞춥니다.
## (Godot 는 시계방향이 앞면: (b-a)x(c-a) 가 바깥 방향의 반대를 가리키면 올바름)

# ---------------------------------------------------------------- 메시 조립

class MB:
	var v = PackedVector3Array()
	var n = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()

	func tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
		var cn: Vector3 = (b - a).cross(c - a)
		if cn.length() < 0.000001:
			return
		var nn: Vector3 = out.normalized()
		var base: int = v.size()
		if cn.dot(nn) > 0.0:
			v.append(a)
			v.append(c)
			v.append(b)
			uv.append(ua)
			uv.append(uc)
			uv.append(ub)
		else:
			v.append(a)
			v.append(b)
			v.append(c)
			uv.append(ua)
			uv.append(ub)
			uv.append(uc)
		n.append(nn)
		n.append(nn)
		n.append(nn)
		idx.append(base)
		idx.append(base + 1)
		idx.append(base + 2)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
		tri(a, b, c, out, ua, ub, uc)
		tri(a, c, d, out, ua, uc, ud)

	func empty() -> bool:
		return v.size() == 0

	func to_mesh(m: Material) -> ArrayMesh:
		var mesh = ArrayMesh.new()
		if v.size() == 0:
			return mesh
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, m)
		return mesh


## 정다각 기둥/뿔대. base = 바닥 중심. r0/r1 = 아래/위 외접 반지름. rot = 시작 각도
static func frustum(mb: MB, base: Vector3, sides: int, r0: float, r1: float, h: float, rot: float,
		us: float, vs: float, top_cap: bool = true) -> void:
	var slope: float = (r0 - r1) / maxf(h, 0.001)
	for i in range(sides):
		var a0: float = rot + TAU * float(i) / float(sides)
		var a1: float = rot + TAU * float(i + 1) / float(sides)
		var p0 = base + Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
		var p1 = base + Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
		var q0 = base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var q1 = base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		var mid: float = (a0 + a1) * 0.5
		var out = Vector3(cos(mid), slope, sin(mid))
		var lb: float = p0.distance_to(p1)
		var u0: float = float(i) * lb / us
		var u1: float = u0 + lb / us
		var vv: float = h / vs
		mb.quad(q0, q1, p1, p0, out, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, vv), Vector2(u0, vv))
	if top_cap and r1 > 0.001:
		var c = base + Vector3(0.0, h, 0.0)
		for i2 in range(sides):
			var b0: float = rot + TAU * float(i2) / float(sides)
			var b1: float = rot + TAU * float(i2 + 1) / float(sides)
			var t0 = c + Vector3(cos(b0) * r1, 0.0, sin(b0) * r1)
			var t1 = c + Vector3(cos(b1) * r1, 0.0, sin(b1) * r1)
			mb.tri(c, t0, t1, Vector3.UP, Vector2(0.5, 0.5), Vector2(0.5 + cos(b0) * 0.5, 0.5 + sin(b0) * 0.5), Vector2(0.5 + cos(b1) * 0.5, 0.5 + sin(b1) * 0.5))


## 직사각형 뿔대(지붕 등). 위 크기(w1,d1) 아래 크기(w0,d0). 바닥 중심 base
static func rect_frustum(mb: MB, base: Vector3, w0: float, d0: float, w1: float, d1: float, h: float, us: float, vs: float, yaw: float = 0.0) -> void:
	var b = Basis(Vector3.UP, yaw)
	var cs: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var lo: Array = []
	var hi: Array = []
	for e in cs:
		var c2: Vector2 = e
		lo.append(base + b * Vector3(c2.x * w0 * 0.5, 0.0, c2.y * d0 * 0.5))
		hi.append(base + b * Vector3(c2.x * w1 * 0.5, h, c2.y * d1 * 0.5))
	for i in range(4):
		var j: int = (i + 1) % 4
		var mid: Vector3 = ((lo[i] as Vector3) + (lo[j] as Vector3)) * 0.5 - base
		var out = Vector3(mid.x, 0.0, mid.z).normalized() + Vector3(0.0, 0.0, 0.0)
		var lw: float = (lo[i] as Vector3).distance_to(lo[j])
		var up_t: float = 0.0
		if h > 0.001:
			up_t = (maxf(w0, d0) - maxf(w1, d1)) / h * 0.5
		out.y = up_t
		var uu: float = lw / us
		var vv: float = sqrt(h * h + pow(maxf(w0, d0) - maxf(w1, d1), 2.0) * 0.25) / vs
		mb.quad(hi[i], hi[j], lo[j], lo[i], out, Vector2(0.0, 0.0), Vector2(uu, 0.0), Vector2(uu, vv), Vector2(0.0, vv))
	if w1 > 0.01 and d1 > 0.01:
		mb.quad(hi[0], hi[1], hi[2], hi[3], Vector3.UP, Vector2(0, 0), Vector2(w1 / us, 0), Vector2(w1 / us, d1 / vs), Vector2(0, d1 / vs))


## 상자(바깥 면만). 크기에 맞춰 UV 가 반복됨
static func box(mb: MB, c: Vector3, s: Vector3, us: float, vs: float, yaw: float = 0.0, bottom: bool = false) -> void:
	var b = Basis(Vector3.UP, yaw)
	var hx: float = s.x * 0.5
	var hy: float = s.y * 0.5
	var hz: float = s.z * 0.5
	_face(mb, c, b, Vector3(0, 0, hz), Vector3(0, 0, 1), Vector3(1, 0, 0), hx, Vector3(0, 1, 0), hy, us, vs)
	_face(mb, c, b, Vector3(0, 0, -hz), Vector3(0, 0, -1), Vector3(-1, 0, 0), hx, Vector3(0, 1, 0), hy, us, vs)
	_face(mb, c, b, Vector3(hx, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), hz, Vector3(0, 1, 0), hy, us, vs)
	_face(mb, c, b, Vector3(-hx, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), hz, Vector3(0, 1, 0), hy, us, vs)
	_face(mb, c, b, Vector3(0, hy, 0), Vector3(0, 1, 0), Vector3(1, 0, 0), hx, Vector3(0, 0, -1), hz, us, vs)
	if bottom:
		_face(mb, c, b, Vector3(0, -hy, 0), Vector3(0, -1, 0), Vector3(1, 0, 0), hx, Vector3(0, 0, 1), hz, us, vs)


static func _face(mb: MB, c: Vector3, b: Basis, off: Vector3, out: Vector3, tdir: Vector3, hw: float, vdir: Vector3, hh: float, us: float, vs: float) -> void:
	var p: Vector3 = c + b * off
	var t: Vector3 = b * tdir * hw
	var vv: Vector3 = b * vdir * hh
	var nn: Vector3 = b * out
	var uu: float = 2.0 * hw / us
	var wv: float = 2.0 * hh / vs
	mb.quad(p - t + vv, p + t + vv, p + t - vv, p - t - vv, nn, Vector2(0, 0), Vector2(uu, 0), Vector2(uu, wv), Vector2(0, wv))


## XY 평면의 다각형을 z 방향으로 두께를 줘서 세움. c = 중심. 실패하면 false
static func extrude_poly(mb: MB, c: Vector3, pts: PackedVector2Array, depth: float, us: float, vs: float) -> bool:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	if tris.size() < 3:
		return false
	var hz: float = depth * 0.5
	var miny: float = pts[0].y
	var maxy: float = pts[0].y
	for p in pts:
		miny = minf(miny, p.y)
		maxy = maxf(maxy, p.y)
	var area: float = 0.0
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var bq: Vector2 = pts[(i + 1) % pts.size()]
		area += a.x * bq.y - bq.x * a.y
	var k: int = 0
	while k + 2 < tris.size():
		var ia: int = tris[k]
		var ib: int = tris[k + 1]
		var ic: int = tris[k + 2]
		var pa: Vector2 = pts[ia]
		var pb: Vector2 = pts[ib]
		var pc: Vector2 = pts[ic]
		mb.tri(c + Vector3(pa.x, pa.y, hz), c + Vector3(pb.x, pb.y, hz), c + Vector3(pc.x, pc.y, hz), Vector3(0, 0, 1),
			Vector2(pa.x / us, (maxy - pa.y) / vs), Vector2(pb.x / us, (maxy - pb.y) / vs), Vector2(pc.x / us, (maxy - pc.y) / vs))
		mb.tri(c + Vector3(pa.x, pa.y, -hz), c + Vector3(pb.x, pb.y, -hz), c + Vector3(pc.x, pc.y, -hz), Vector3(0, 0, -1),
			Vector2(pa.x / us, (maxy - pa.y) / vs), Vector2(pb.x / us, (maxy - pb.y) / vs), Vector2(pc.x / us, (maxy - pc.y) / vs))
		k += 3
	for i2 in range(pts.size()):
		var p0: Vector2 = pts[i2]
		var p1: Vector2 = pts[(i2 + 1) % pts.size()]
		var d: Vector2 = p1 - p0
		var out2 = Vector3(d.y, -d.x, 0.0)
		if area < 0.0:
			out2 = -out2
		var el: float = d.length() / us
		mb.quad(c + Vector3(p0.x, p0.y, hz), c + Vector3(p1.x, p1.y, hz), c + Vector3(p1.x, p1.y, -hz), c + Vector3(p0.x, p0.y, -hz), out2,
			Vector2(0, 0), Vector2(el, 0), Vector2(el, depth / vs), Vector2(0, depth / vs))
	return true


# ---------------------------------------------------------------- 재질 / 텍스처

static var _mats: Dictionary = {}
static var _texs: Dictionary = {}


static func mat(color: Color, rough: float = 0.85, metal: float = 0.0, emit: float = 0.0, tex: Texture2D = null) -> StandardMaterial3D:
	var key: String = "%s_%d_%d_%d_%d" % [color.to_html(true), int(rough * 100.0), int(metal * 100.0), int(emit * 100.0), 0 if tex == null else tex.get_rid().get_id()]
	if _mats.has(key):
		return _mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if metal > 0.0:
		m.metallic_specular = 0.7
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if tex != null:
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[key] = m
	return m


static func _finish(img: Image, key: String) -> ImageTexture:
	img.generate_mipmaps()
	var t = ImageTexture.create_from_image(img)
	_texs[key] = t
	return t


## 유리 커튼월 한 칸 (가로 4m x 세로 3.2m 에 한 장)
static func tex_glass(tint: Color) -> ImageTexture:
	var key: String = "glass_" + tint.to_html(false)
	if _texs.has(key):
		return _texs[key]
	var img = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(tint.darkened(0.45))
	img.fill_rect(Rect2i(3, 3, 58, 58), tint)
	img.fill_rect(Rect2i(3, 3, 58, 20), tint.lightened(0.22))
	img.fill_rect(Rect2i(3, 44, 58, 17), tint.darkened(0.12))
	return _finish(img, key)


## 돌 블록 벽 (한 장 = 4m x 4m)
static func tex_stone(base: Color) -> ImageTexture:
	var key: String = "stone_" + base.to_html(false)
	if _texs.has(key):
		return _texs[key]
	var img = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(base)
	var line: Color = base.darkened(0.18)
	for row in range(4):
		var y: int = row * 16
		img.fill_rect(Rect2i(0, y, 64, 1), line)
		var off: int = 0 if row % 2 == 0 else 16
		img.fill_rect(Rect2i(off, y, 1, 16), line)
		img.fill_rect(Rect2i((off + 32) % 64, y, 1, 16), line)
		img.fill_rect(Rect2i(0, y + 1, 64, 3), base.lightened(0.04))
	return _finish(img, key)


## 기와 지붕 (세로 골)
static func tex_tiles(base: Color) -> ImageTexture:
	var key: String = "tiles_" + base.to_html(false)
	if _texs.has(key):
		return _texs[key]
	var img = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for x in range(0, 32, 4):
		img.fill_rect(Rect2i(x, 0, 1, 32), base.darkened(0.25))
		img.fill_rect(Rect2i(x + 1, 0, 1, 32), base.lightened(0.08))
	for y in range(0, 32, 8):
		img.fill_rect(Rect2i(0, y, 32, 1), base.darkened(0.12))
	return _finish(img, key)


## 아파트 단지용 외벽 (칸 4m x 3m: 창 + 발코니 띠 + 색)
static func tex_housing(wall: Color, accent: Color) -> ImageTexture:
	var key: String = "housing_%s_%s" % [wall.to_html(false), accent.to_html(false)]
	if _texs.has(key):
		return _texs[key]
	var img = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(wall)
	img.fill_rect(Rect2i(10, 14, 22, 28), Color(0.20, 0.27, 0.35))
	img.fill_rect(Rect2i(10, 14, 22, 8), Color(0.34, 0.44, 0.54))
	img.fill_rect(Rect2i(8, 12, 26, 2), wall.lightened(0.2))
	img.fill_rect(Rect2i(8, 42, 26, 2), wall.lightened(0.2))
	img.fill_rect(Rect2i(40, 14, 16, 28), Color(0.20, 0.27, 0.35))
	img.fill_rect(Rect2i(38, 12, 20, 2), wall.lightened(0.2))
	img.fill_rect(Rect2i(0, 46, 64, 10), accent)
	img.fill_rect(Rect2i(0, 46, 64, 2), accent.darkened(0.25))
	img.fill_rect(Rect2i(0, 60, 64, 4), wall.darkened(0.1))
	return _finish(img, key)


# ---------------------------------------------------------------- 충돌체 / 장식

static func collider_box(parent: Node, pos: Vector3, size: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var cs = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


static func collider_convex(parent: Node, points: PackedVector3Array) -> StaticBody3D:
	var body = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var shape = ConvexPolygonShape3D.new()
	shape.points = points
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


static func frustum_points(base: Vector3, sides: int, r0: float, r1: float, h: float, rot: float) -> PackedVector3Array:
	var pts = PackedVector3Array()
	for i in range(sides):
		var a: float = rot + TAU * float(i) / float(sides)
		pts.append(base + Vector3(cos(a) * r0, 0.0, sin(a) * r0))
		pts.append(base + Vector3(cos(a) * r1, h, sin(a) * r1))
	return pts


static func mesh_node(parent: Node, node_name: String, mb: MB, m: Material, shadows: bool = false) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mb.to_mesh(m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func label(parent: Node, pos: Vector3, text: String, size: float, color: Color, yaw: float = 0.0) -> Label3D:
	var l = Label3D.new()
	l.text = text
	l.pixel_size = 0.01 * size
	l.font_size = 64
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos
	l.rotation.y = yaw
	l.shaded = false
	l.double_sided = true
	parent.add_child(l)
	return l
