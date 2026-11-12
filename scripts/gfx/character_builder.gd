extends RefCounted
## 절차적 인체 모델 만들기 (외부 모델 파일 없음).
## 몸통/머리/팔/다리를 "단면을 쌓아 올리는 방식(loft)"으로 매끈하게 만들고,
## 관절(어깨·팔꿈치·엉덩이·무릎·발목·허리·머리)마다 Node3D 를 두어 character_animator.gd 가 움직입니다.
## 같은 모양을 한 덩어리로 합친 "먼 거리용" 메시도 함께 만들어 멀리서는 그리기 호출을 줄입니다.
##
## 주의: 이것은 Skeleton3D 스키닝이 아니라 "관절 노드 계층" 방식입니다. 팔다리가 구부러지는 부분은
## 메시가 늘어나지 않고 서로 겹쳐 보이므로, 가까이서 보면 완벽한 스키닝 캐릭터보다는 거칠 수 있습니다.
##
## 좌표: 발바닥 y=0, 몸은 -Z 쪽을 바라봄, 캐릭터의 왼쪽 = -X, 오른쪽 = +X.

# ---------------------------------------------------------------- 메시 모으기

class Surf:
	var mat = null
	var v = PackedVector3Array()
	var n = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()


class Acc:
	var surfs: Dictionary = {}

	func get_surf(key: String, mat):
		if not surfs.has(key):
			var s = Surf.new()
			s.mat = mat
			surfs[key] = s
		return surfs[key]

	func to_mesh() -> ArrayMesh:
		var mesh = ArrayMesh.new()
		for k in surfs.keys():
			var s = surfs[k]
			if s.v.size() == 0:
				continue
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = s.v
			arrays[Mesh.ARRAY_NORMAL] = s.n
			arrays[Mesh.ARRAY_TEX_UV] = s.uv
			arrays[Mesh.ARRAY_INDEX] = s.idx
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, s.mat)
		return mesh


## 관절 하나에 붙는 메시 모음. rest = 몸 기준(발바닥) 쉬는 자세에서의 관절 위치
class Part:
	var acc = null
	var lod = null
	var rest: Vector3 = Vector3.ZERO
	var node: Node3D = null


static var _mats: Dictionary = {}
## 시민(NPC)처럼 많이 만들 때는 단면의 분할 수를 줄여 생성 시간과 정점 수를 아낌
static var _lowpoly: bool = false
## V3.0: 비어 있지 않으면 플레이어 외형으로 사용 (최고지도자 전용 의상). 비우면 원래 외형.
static var player_override: Dictionary = {}


static func _mat(color: Color, rough: float = 0.88, spec: float = 0.4) -> StandardMaterial3D:
	var key: String = "%s_%d_%d" % [color.to_html(false), int(rough * 100.0), int(spec * 100.0)]
	if _mats.has(key):
		return _mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic_specular = spec
	m.resource_name = key
	_mats[key] = m
	return m


# ---------------------------------------------------------------- 기본 형태

## rings: Vector4(y, 가로반지름, 세로(앞뒤)반지름, z중심) 목록. y 순서는 위/아래 아무래도 상관없음.
static func _loft(acc, mat: StandardMaterial3D, xf: Transform3D, rings_in: Array, seg_in: int,
		cap_top: bool, cap_bot: bool, fold: float) -> void:
	if rings_in.size() < 2:
		return
	var seg: int = seg_in
	if _lowpoly:
		seg = maxi(5, seg_in - 3)
	var rings: Array = rings_in
	if rings[0].x > rings[rings.size() - 1].x:
		rings = rings_in.duplicate()
		rings.reverse()
	var s = acc.get_surf(mat.resource_name, mat)
	var base: int = s.v.size()
	var nr: int = rings.size()

	var rxs: Array = []
	var rzs: Array = []
	for i in range(nr):
		var rr: Vector4 = rings[i]
		var f: float = 1.0 + fold * sin(rr.x * 55.0)
		rxs.append(rr.y * f)
		rzs.append(rr.z * f)

	for i in range(nr):
		var r: Vector4 = rings[i]
		var ia: int = maxi(i - 1, 0)
		var ib: int = mini(i + 1, nr - 1)
		var ra: Vector4 = rings[ia]
		var rb: Vector4 = rings[ib]
		var dy: float = rb.x - ra.x
		if absf(dy) < 0.000001:
			dy = 0.000001
		var drx: float = (float(rxs[ib]) - float(rxs[ia])) / dy
		var drz: float = (float(rzs[ib]) - float(rzs[ia])) / dy
		var dcz: float = (rb.w - ra.w) / dy
		var rx: float = rxs[i]
		var rz: float = rzs[i]
		for j in range(seg):
			var a: float = TAU * float(j) / float(seg)
			var ca: float = cos(a)
			var sa: float = sin(a)
			var p = Vector3(rx * ca, r.x, r.w + rz * sa)
			var dpdy = Vector3(drx * ca, 1.0, dcz + drz * sa)
			var dpda = Vector3(-rx * sa, 0.0, rz * ca)
			var nn: Vector3 = dpdy.cross(dpda)
			if nn.length() < 0.000001:
				nn = Vector3(ca, 0.0, sa)
			nn = nn.normalized()
			s.v.append(xf * p)
			s.n.append((xf.basis * nn).normalized())
			s.uv.append(Vector2(float(j) / float(seg), float(i) / float(nr - 1)))

	for i in range(nr - 1):
		for j in range(seg):
			var j2: int = (j + 1) % seg
			var b0: int = base + i * seg + j
			var b1: int = base + i * seg + j2
			var t0: int = base + (i + 1) * seg + j
			var t1: int = base + (i + 1) * seg + j2
			s.idx.append(t1)
			s.idx.append(t0)
			s.idx.append(b0)
			s.idx.append(t1)
			s.idx.append(b0)
			s.idx.append(b1)

	if cap_top:
		var top: Vector4 = rings[nr - 1]
		var ci: int = s.v.size()
		s.v.append(xf * Vector3(0.0, top.x, top.w))
		s.n.append((xf.basis * Vector3.UP).normalized())
		s.uv.append(Vector2(0.5, 1.0))
		var tb: int = base + (nr - 1) * seg
		for j in range(seg):
			var j2: int = (j + 1) % seg
			s.idx.append(ci)
			s.idx.append(tb + j)
			s.idx.append(tb + j2)
	if cap_bot:
		var bot: Vector4 = rings[0]
		var cj: int = s.v.size()
		s.v.append(xf * Vector3(0.0, bot.x, bot.w))
		s.n.append((xf.basis * Vector3.DOWN).normalized())
		s.uv.append(Vector2(0.5, 0.0))
		for j in range(seg):
			var j2: int = (j + 1) % seg
			s.idx.append(cj)
			s.idx.append(base + j2)
			s.idx.append(base + j)


static func _ellipsoid(acc, mat: StandardMaterial3D, xf: Transform3D, radii: Vector3, seg: int, nrings_in: int) -> void:
	var nrings: int = nrings_in
	if _lowpoly:
		nrings = maxi(2, nrings_in - 1)
	var rings: Array = []
	for k in range(1, nrings + 1):
		var phi: float = PI * float(k) / float(nrings + 1)
		var sr: float = sin(phi)
		rings.append(Vector4(-radii.y * cos(phi), radii.x * sr, radii.z * sr, 0.0))
	_loft(acc, mat, xf, rings, seg, true, true, 0.0)


const _BOX_FACES: Array = [
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
]


static func _box(acc, mat: StandardMaterial3D, xf: Transform3D, size: Vector3) -> void:
	var h: Vector3 = size * 0.5
	var s = acc.get_surf(mat.resource_name, mat)
	for f in _BOX_FACES:
		var n: Vector3 = f[0]
		var t: Vector3 = f[1]
		var u: Vector3 = f[2]
		var c = Vector3(n.x * h.x, n.y * h.y, n.z * h.z)
		var a: float = absf(t.x) * h.x + absf(t.y) * h.y + absf(t.z) * h.z
		var b: float = absf(u.x) * h.x + absf(u.y) * h.y + absf(u.z) * h.z
		var base: int = s.v.size()
		var tl: Vector3 = c - t * a + u * b
		var tr: Vector3 = c + t * a + u * b
		var br: Vector3 = c + t * a - u * b
		var bl: Vector3 = c - t * a - u * b
		var nw: Vector3 = (xf.basis * n).normalized()
		s.v.append(xf * tl)
		s.v.append(xf * tr)
		s.v.append(xf * br)
		s.v.append(xf * bl)
		for q in range(4):
			s.n.append(nw)
		s.uv.append(Vector2(0, 0))
		s.uv.append(Vector2(1, 0))
		s.uv.append(Vector2(1, 1))
		s.uv.append(Vector2(0, 1))
		s.idx.append(base)
		s.idx.append(base + 1)
		s.idx.append(base + 2)
		s.idx.append(base)
		s.idx.append(base + 2)
		s.idx.append(base + 3)


## 관절 Part 에 형태를 추가. 먼 거리용 합본 메시에는 계산을 다시 하지 않고 정점만 복사(위치 이동)한다.
static func _copy_to_lod(p, mat: StandardMaterial3D, v0: int, i0: int) -> void:
	var src = p.acc.get_surf(mat.resource_name, mat)
	var dst = p.lod.get_surf(mat.resource_name, mat)
	var base: int = dst.v.size()
	for k in range(v0, src.v.size()):
		dst.v.append(src.v[k] + p.rest)
		dst.n.append(src.n[k])
		dst.uv.append(src.uv[k])
	for k2 in range(i0, src.idx.size()):
		dst.idx.append(src.idx[k2] - v0 + base)


static func _pl(p, mat: StandardMaterial3D, xf: Transform3D, rings: Array, seg: int = 8,
		cap_top: bool = false, cap_bot: bool = false, fold: float = 0.0) -> void:
	var s = p.acc.get_surf(mat.resource_name, mat)
	var v0: int = s.v.size()
	var i0: int = s.idx.size()
	_loft(p.acc, mat, xf, rings, seg, cap_top, cap_bot, fold)
	_copy_to_lod(p, mat, v0, i0)


static func _pe(p, mat: StandardMaterial3D, xf: Transform3D, radii: Vector3, seg: int = 8, nrings: int = 5) -> void:
	var s = p.acc.get_surf(mat.resource_name, mat)
	var v0: int = s.v.size()
	var i0: int = s.idx.size()
	_ellipsoid(p.acc, mat, xf, radii, seg, nrings)
	_copy_to_lod(p, mat, v0, i0)


static func _pb(p, mat: StandardMaterial3D, xf: Transform3D, size: Vector3) -> void:
	var s = p.acc.get_surf(mat.resource_name, mat)
	var v0: int = s.v.size()
	var i0: int = s.idx.size()
	_box(p.acc, mat, xf, size)
	_copy_to_lod(p, mat, v0, i0)


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


static func _atb(pos: Vector3, b: Basis) -> Transform3D:
	return Transform3D(b, pos)


## 같은 반지름 목록(y, r)을 원형 단면 Vector4 로
static func _circ(list: Array, sc: float, wmul: float, cz: float = 0.0) -> Array:
	var out: Array = []
	for e in list:
		out.append(Vector4(float(e[0]) * sc, float(e[1]) * wmul, float(e[1]) * wmul, cz))
	return out


static func _scaled_rings(list: Array, k: float, bw: float, bd: float, grow: float) -> Array:
	var out: Array = []
	for e in list:
		out.append(Vector4(float(e[0]) * k, float(e[1]) * bw + grow, float(e[2]) * bd + grow, 0.0))
	return out


static func _ring_at(rings: Array, y: float) -> Vector4:
	var n: int = rings.size()
	if y <= rings[0].x:
		return rings[0]
	if y >= rings[n - 1].x:
		return rings[n - 1]
	for i in range(n - 1):
		var a: Vector4 = rings[i]
		var b: Vector4 = rings[i + 1]
		if y >= a.x and y <= b.x:
			var t: float = (y - a.x) / maxf(b.x - a.x, 0.000001)
			return a.lerp(b, t)
	return rings[n - 1]


## 머리 표면의 z (앞쪽이 -z). 가로 위치 x 에서의 값
static func _face_z(rings: Array, y: float, x: float) -> float:
	var r: Vector4 = _ring_at(rings, y)
	var q: float = clampf(absf(x) / maxf(r.y, 0.001), 0.0, 0.98)
	return r.w - r.z * sqrt(1.0 - q * q)


# ---------------------------------------------------------------- 외형 데이터

const TORSO_M: Array = [
	[-0.04, 0.158, 0.108], [0.06, 0.150, 0.104], [0.17, 0.142, 0.100], [0.28, 0.158, 0.108],
	[0.38, 0.178, 0.114], [0.45, 0.186, 0.108], [0.50, 0.165, 0.092], [0.535, 0.075, 0.060],
]
const TORSO_F: Array = [
	[-0.04, 0.168, 0.112], [0.06, 0.150, 0.104], [0.17, 0.124, 0.092], [0.28, 0.140, 0.108],
	[0.38, 0.158, 0.118], [0.45, 0.166, 0.104], [0.50, 0.150, 0.088], [0.535, 0.072, 0.058],
]
const HEAD_RINGS: Array = [
	[-0.115, 0.026, 0.040, -0.008], [-0.100, 0.050, 0.062, -0.006], [-0.065, 0.066, 0.082, -0.002],
	[-0.010, 0.077, 0.098, 0.0], [0.045, 0.079, 0.100, 0.002], [0.090, 0.071, 0.092, 0.004],
	[0.120, 0.050, 0.066, 0.005], [0.135, 0.017, 0.030, 0.005],
]
const UARM: Array = [[0.02, 0.052], [-0.04, 0.050], [-0.15, 0.043], [-0.27, 0.040], [-0.30, 0.039]]
const FARM: Array = [[0.02, 0.040], [-0.05, 0.040], [-0.15, 0.034], [-0.25, 0.028], [-0.26, 0.027]]
const THIGH: Array = [[0.03, 0.088], [-0.05, 0.088], [-0.20, 0.072], [-0.38, 0.056], [-0.44, 0.052]]
const SHIN: Array = [[0.0, 0.053], [-0.10, 0.056], [-0.28, 0.042], [-0.42, 0.034], [-0.44, 0.033]]
const HAND: Array = [[0.0, 0.028, 0.016], [-0.04, 0.036, 0.019], [-0.085, 0.030, 0.014], [-0.10, 0.012, 0.008]]
const SHOE: Array = [
	[-0.07, 0.030, 0.032], [-0.03, 0.042, 0.036], [0.06, 0.047, 0.034], [0.13, 0.040, 0.025], [0.18, 0.020, 0.015],
]


static func _hash(s: String) -> int:
	return absi(s.hash())


# ---------------------------------------------------------------- 조립

static func _make_part(parent: Node3D, node_name: String, local_pos: Vector3, parent_rest: Vector3, lod) -> Part:
	var n = Node3D.new()
	n.name = node_name
	n.position = local_pos
	parent.add_child(n)
	var p = Part.new()
	p.acc = Acc.new()
	p.lod = lod
	p.rest = parent_rest + local_pos
	p.node = n
	return p


## spec 키: sex("m"/"f"), build(0~1), skin, hair, hair_style, outfit, top, bottom, shoes,
##   long_sleeve, hat, hat_color, acc, collar, seed
## detail_end: 이 거리(m) 안에서만 자세한 몸을 그림. 0 이면 항상 자세히.
## far_end: 먼 거리용 합본 메시를 그리는 최대 거리 (detail_end > 0 일 때만 의미)
## shadows: 그림자를 만들지
static func build(spec: Dictionary, detail_end: float = 0.0, far_end: float = 90.0, shadows: bool = false) -> Dictionary:
	var female: bool = str(spec.get("sex", "m")) == "f"
	var k: float = 0.94 if female else 1.0
	var build_v: float = float(spec.get("build", 0.5))
	var bw: float = 0.92 + 0.22 * build_v
	var bd: float = 0.94 + 0.16 * build_v
	var sw: float = 0.90 if female else 1.0
	var hw: float = 1.06 if female else 1.0

	var skin_c: Color = spec.get("skin", Color(0.86, 0.70, 0.58))
	var hair_c: Color = spec.get("hair", Color(0.08, 0.07, 0.07))
	var top_c: Color = spec.get("top", Color(0.30, 0.32, 0.38))
	var bot_c: Color = spec.get("bottom", Color(0.18, 0.18, 0.22))
	var shoe_c: Color = spec.get("shoes", Color(0.10, 0.09, 0.09))
	var outfit: String = str(spec.get("outfit", "civilian"))
	var hair_style: String = str(spec.get("hair_style", "short"))
	var acc_name: String = str(spec.get("acc", ""))
	var has_hat: bool = bool(spec.get("hat", false))
	var hat_c: Color = spec.get("hat_color", Color(0.2, 0.2, 0.2))
	var long_sleeve: bool = bool(spec.get("long_sleeve", true))
	var jacket: bool = outfit == "suit" or outfit == "guard" or outfit == "worker" or outfit == "elder"
	var skirt: bool = outfit == "dress" or (female and outfit == "student")
	var seed_v: int = int(spec.get("seed", 1))
	_lowpoly = bool(spec.get("lowpoly", false))

	var skin_m: StandardMaterial3D = _mat(skin_c, 0.72, 0.35)
	var skin_dark_m: StandardMaterial3D = _mat(skin_c.darkened(0.12), 0.72, 0.3)
	var hair_m: StandardMaterial3D = _mat(hair_c, 0.55, 0.5)
	var top_m: StandardMaterial3D = _mat(top_c, 0.92, 0.2)
	var bot_m: StandardMaterial3D = _mat(bot_c, 0.92, 0.2)
	var shoe_m: StandardMaterial3D = _mat(shoe_c, 0.5, 0.5)
	var dark_m: StandardMaterial3D = _mat(Color(0.06, 0.05, 0.05), 0.5, 0.4)
	var white_m: StandardMaterial3D = _mat(Color(0.90, 0.90, 0.88), 0.9, 0.2)

	# ----- 치수
	var L1: float = 0.44 * k
	var L2: float = 0.44 * k
	var ANK: float = 0.08 * k
	var hip_h: float = ANK + L1 + L2
	var UA: float = 0.29 * k
	var FA: float = 0.26 * k

	var root = Node3D.new()
	root.name = "Body"
	var rig = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)

	var lod_acc = Acc.new()
	var pelvis: Part = _make_part(rig, "Pelvis", Vector3(0.0, hip_h, 0.0), Vector3.ZERO, lod_acc)
	var spine: Part = _make_part(pelvis.node, "Spine", Vector3.ZERO, pelvis.rest, lod_acc)
	var head: Part = _make_part(spine.node, "Head", Vector3(0.0, 0.55 * k, 0.0), spine.rest, lod_acc)
	var shx: float = (0.19 if not female else 0.17) * bw * sw
	var sh_l: Part = _make_part(spine.node, "ShoulderL", Vector3(-shx, 0.46 * k, 0.0), spine.rest, lod_acc)
	var sh_r: Part = _make_part(spine.node, "ShoulderR", Vector3(shx, 0.46 * k, 0.0), spine.rest, lod_acc)
	var el_l: Part = _make_part(sh_l.node, "ElbowL", Vector3(0.0, -UA, 0.0), sh_l.rest, lod_acc)
	var el_r: Part = _make_part(sh_r.node, "ElbowR", Vector3(0.0, -UA, 0.0), sh_r.rest, lod_acc)
	var hipx: float = 0.09 * bw * hw
	var hip_l: Part = _make_part(pelvis.node, "HipL", Vector3(-hipx, 0.0, 0.0), pelvis.rest, lod_acc)
	var hip_r: Part = _make_part(pelvis.node, "HipR", Vector3(hipx, 0.0, 0.0), pelvis.rest, lod_acc)
	var kn_l: Part = _make_part(hip_l.node, "KneeL", Vector3(0.0, -L1, 0.0), hip_l.rest, lod_acc)
	var kn_r: Part = _make_part(hip_r.node, "KneeR", Vector3(0.0, -L1, 0.0), hip_r.rest, lod_acc)
	var ft_l: Part = _make_part(kn_l.node, "FootL", Vector3(0.0, -L2, 0.0), kn_l.rest, lod_acc)
	var ft_r: Part = _make_part(kn_r.node, "FootR", Vector3(0.0, -L2, 0.0), kn_r.rest, lod_acc)

	# ----- 골반 (바지 또는 치마)
	var pelv_rings: Array = _scaled_rings([
		[-0.12, 0.120 * hw, 0.092], [-0.06, 0.150 * hw, 0.106], [0.0, 0.156 * hw, 0.108], [0.07, 0.146, 0.102],
	], k, bw, bd, 0.0)
	if skirt:
		var sk_rings: Array = _scaled_rings([
			[-0.42, 0.265, 0.205], [-0.30, 0.235, 0.18], [-0.12, 0.185, 0.14], [0.0, 0.16 * hw, 0.114], [0.07, 0.146, 0.102],
		], k, bw, bd, 0.0)
		_pl(pelvis, bot_m, _at(0, 0, 0), sk_rings, 12, false, false, 0.02)
	else:
		_pl(pelvis, bot_m, _at(0, 0, 0), pelv_rings, 10, false, true, 0.0)
	if outfit == "guard":
		var belt_m: StandardMaterial3D = _mat(Color(0.10, 0.08, 0.06), 0.5, 0.5)
		_pl(pelvis, belt_m, _at(0, 0, 0), _scaled_rings([[0.035, 0.158, 0.110], [0.075, 0.158, 0.110]], k, bw, bd, 0.012), 10, false, false, 0.0)
		_pb(pelvis, _mat(Color(0.78, 0.65, 0.20), 0.4, 0.8), _at(0.0, 0.055 * k, -0.125 * bd), Vector3(0.045, 0.04, 0.012))
		_pb(pelvis, belt_m, _at(0.17 * bw, -0.03 * k, 0.0), Vector3(0.05, 0.14, 0.075))

	# ----- 몸통
	var torso_list: Array = TORSO_F if female else TORSO_M
	var grow: float = 0.0
	if jacket:
		grow = 0.010
	var hem: float = -0.04
	if jacket:
		hem = -0.10
	var torso_rings: Array = _scaled_rings(torso_list, k, bw, bd, grow)
	torso_rings[0] = Vector4(hem * k, torso_rings[0].y + (0.006 if jacket else 0.006), torso_rings[0].z + 0.004, 0.0)
	var torso_m: StandardMaterial3D = top_m
	if outfit == "student" and not skirt:
		torso_m = _mat(Color(0.88, 0.88, 0.86), 0.9, 0.2)
	_pl(spine, torso_m, _at(0, 0, 0), torso_rings, 10, true, true, 0.0)
	# 목
	_pl(spine, skin_m, _at(0, 0, 0), _circ([[0.49, 0.054], [0.54, 0.047], [0.60, 0.045]], k, 1.0), 8, true, false, 0.0)
	# 옷깃
	if outfit == "suit" or outfit == "guard" or outfit == "student" or outfit == "worker":
		var collar_c: Color = Color(0.92, 0.92, 0.90)
		if outfit == "guard":
			collar_c = top_c.darkened(0.15)
		var collar_m: StandardMaterial3D = _mat(collar_c, 0.9, 0.2)
		_pl(spine, collar_m, _at(0, 0, 0), _circ([[0.50, 0.064], [0.545, 0.057]], k, 1.0), 10, false, false, 0.0)
	if outfit == "suit":
		var tie_c: Color = Color(0.55, 0.08, 0.10) if (seed_v % 2 == 0) else Color(0.12, 0.14, 0.30)
		_pb(spine, white_m, _at(0.0, 0.38 * k, -0.108 * bd), Vector3(0.075, 0.22, 0.010))
		_pb(spine, _mat(tie_c, 0.6, 0.3), _at(0.0, 0.37 * k, -0.114 * bd), Vector3(0.026, 0.22, 0.008))
	if jacket:
		# 주머니와 단추
		var pk_m: StandardMaterial3D = _mat(top_c.darkened(0.25), 0.9, 0.2)
		_pb(spine, pk_m, _at(-0.08, 0.30 * k, -0.116 * bd), Vector3(0.06, 0.012, 0.006))
		_pb(spine, pk_m, _at(0.08, 0.06 * k, -0.118 * bd), Vector3(0.07, 0.014, 0.006))
		_pb(spine, pk_m, _at(-0.08, 0.06 * k, -0.118 * bd), Vector3(0.07, 0.014, 0.006))
		var btn_m: StandardMaterial3D = _mat(Color(0.75, 0.62, 0.2) if outfit == "guard" else top_c.darkened(0.45), 0.4, 0.7)
		for bi in range(3):
			_pe(spine, btn_m, _at(0.0, (0.10 + 0.10 * float(bi)) * k, -0.116 * bd), Vector3(0.007, 0.007, 0.004), 6, 3)
	if outfit == "guard":
		var gold_m: StandardMaterial3D = _mat(Color(0.78, 0.65, 0.20), 0.4, 0.8)
		_pb(spine, gold_m, _atb(Vector3(-0.15 * bw, 0.50 * k, 0.0), Basis(Vector3.FORWARD, -0.25)), Vector3(0.075, 0.012, 0.045))
		_pb(spine, gold_m, _atb(Vector3(0.15 * bw, 0.50 * k, 0.0), Basis(Vector3.FORWARD, 0.25)), Vector3(0.075, 0.012, 0.045))
		_pe(spine, gold_m, _at(0.07, 0.36 * k, -0.118 * bd), Vector3(0.016, 0.016, 0.005), 6, 3)
	if acc_name == "scarf":
		var scarf_m: StandardMaterial3D = _mat(top_c.lightened(0.35), 0.95, 0.1)
		_pl(spine, scarf_m, _at(0, 0, 0), _circ([[0.48, 0.072], [0.53, 0.066], [0.585, 0.060]], k, 1.0), 10, false, false, 0.05)
	if acc_name == "bag":
		var bag_m: StandardMaterial3D = _mat(bot_c.darkened(0.2), 0.85, 0.2)
		_pb(spine, bag_m, _at(0.0, 0.27 * k, 0.15 * bd), Vector3(0.30, 0.36, 0.13))
		_pb(spine, bag_m, _at(-0.10 * bw, 0.38 * k, -0.002), Vector3(0.035, 0.012, 0.22))
		_pb(spine, bag_m, _at(0.10 * bw, 0.38 * k, -0.002), Vector3(0.035, 0.012, 0.22))
		_pb(spine, bag_m, _at(-0.10 * bw, 0.30 * k, -0.105 * bd), Vector3(0.03, 0.2, 0.01))
		_pb(spine, bag_m, _at(0.10 * bw, 0.30 * k, -0.105 * bd), Vector3(0.03, 0.2, 0.01))

	# ----- 머리
	var hs: float = 0.96 if female else 1.0
	var head_rings: Array = []
	for e in HEAD_RINGS:
		head_rings.append(Vector4(float(e[0]) * hs, float(e[1]) * hs, float(e[2]) * hs, float(e[3]) * hs))
	var hc_y: float = 0.125 * k
	_pl(head, skin_m, _at(0, hc_y, 0), head_rings, 10, true, true, 0.0)
	# 얼굴 부위
	var ey: float = 0.012 * hs
	var ex: float = 0.031 * hs
	var eye_m: StandardMaterial3D = dark_m
	_pe(head, eye_m, _at(-ex, hc_y + ey, _face_z(head_rings, ey, ex) + 0.002), Vector3(0.0105, 0.0062, 0.006), 6, 3)
	_pe(head, eye_m, _at(ex, hc_y + ey, _face_z(head_rings, ey, ex) + 0.002), Vector3(0.0105, 0.0062, 0.006), 6, 3)
	var brow_m: StandardMaterial3D = _mat(hair_c.darkened(0.1), 0.7, 0.2)
	var by: float = 0.036 * hs
	_pb(head, brow_m, _at(-ex, hc_y + by, _face_z(head_rings, by, ex) + 0.001), Vector3(0.032, 0.006, 0.008))
	_pb(head, brow_m, _at(ex, hc_y + by, _face_z(head_rings, by, ex) + 0.001), Vector3(0.032, 0.006, 0.008))
	_pe(head, skin_dark_m, _at(0.0, hc_y - 0.022 * hs, _face_z(head_rings, -0.022, 0.0) - 0.004), Vector3(0.011, 0.020, 0.018), 6, 4)
	var mouth_m: StandardMaterial3D = _mat(Color(0.52, 0.27, 0.27), 0.6, 0.3)
	_pb(head, mouth_m, _at(0.0, hc_y - 0.062 * hs, _face_z(head_rings, -0.062, 0.0) + 0.001), Vector3(0.034, 0.006, 0.006))
	var earr: Vector4 = _ring_at(head_rings, 0.0)
	_pe(head, skin_dark_m, _at(-(earr.y + 0.001), hc_y + 0.0, 0.008), Vector3(0.007, 0.020, 0.013), 6, 3)
	_pe(head, skin_dark_m, _at((earr.y + 0.001), hc_y + 0.0, 0.008), Vector3(0.007, 0.020, 0.013), 6, 3)

	# 머리카락
	if hair_style != "bald":
		var hx: float = 0.092 * hs
		var hy: float = 0.115 * hs
		var hz: float = 0.113 * hs
		if hair_style == "crew":
			hx *= 0.97
			hy *= 0.97
			hz *= 0.97
		_pe(head, hair_m, _at(0.0, hc_y + 0.035 * hs, 0.012 * hs), Vector3(hx, hy, hz), 10, 6)
		if hair_style == "side":
			_pb(head, hair_m, _atb(Vector3(0.025, hc_y + 0.128 * hs, -0.062 * hs), Basis(Vector3.RIGHT, -0.35)), Vector3(0.09, 0.025, 0.05))
		elif hair_style == "long":
			_pl(head, hair_m, _at(0.0, hc_y, 0.0), [
				Vector4(-0.30 * hs, 0.060, 0.032, 0.088), Vector4(-0.18 * hs, 0.082, 0.040, 0.092),
				Vector4(-0.05 * hs, 0.092, 0.046, 0.082), Vector4(0.03 * hs, 0.090, 0.050, 0.070)], 10, false, true, 0.0)
		elif hair_style == "bob":
			_pe(head, hair_m, _at(-0.083 * hs, hc_y - 0.035 * hs, 0.022), Vector3(0.024, 0.075, 0.078), 8, 4)
			_pe(head, hair_m, _at(0.083 * hs, hc_y - 0.035 * hs, 0.022), Vector3(0.024, 0.075, 0.078), 8, 4)
			_pe(head, hair_m, _at(0.0, hc_y - 0.040 * hs, 0.070), Vector3(0.085, 0.075, 0.04), 8, 4)
		elif hair_style == "bun":
			_pe(head, hair_m, _at(0.0, hc_y + 0.125 * hs, 0.082 * hs), Vector3(0.036, 0.036, 0.036), 8, 4)

	# 모자
	if has_hat:
		var hm: StandardMaterial3D = _mat(hat_c, 0.85, 0.2)
		var band_m: StandardMaterial3D = _mat(hat_c.darkened(0.35), 0.8, 0.2)
		if outfit == "guard" or outfit == "suit":
			# 챙 달린 정모
			_pl(head, band_m, _at(0, hc_y, 0), [Vector4(0.070, 0.094, 0.104, 0.006), Vector4(0.100, 0.094, 0.104, 0.006)], 12, false, false, 0.0)
			_pl(head, hm, _at(0, hc_y, 0), [Vector4(0.100, 0.096, 0.106, 0.006), Vector4(0.140, 0.104, 0.112, 0.004), Vector4(0.158, 0.108, 0.116, 0.004)], 12, true, false, 0.0)
			_pe(head, dark_m, _at(0.0, hc_y + 0.082, -0.112), Vector3(0.075, 0.006, 0.055), 10, 2)
			if outfit == "guard":
				_pe(head, _mat(Color(0.78, 0.65, 0.20), 0.4, 0.8), _at(0.0, hc_y + 0.125, -0.113), Vector3(0.014, 0.014, 0.004), 6, 3)
		else:
			# 부드러운 모자
			_pe(head, hm, _at(0.0, hc_y + 0.060, 0.006), Vector3(0.100, 0.075, 0.110), 10, 4)
			_pe(head, hm, _at(0.0, hc_y + 0.070, -0.100), Vector3(0.062, 0.006, 0.045), 8, 2)

	if acc_name == "glasses":
		var gl_m: StandardMaterial3D = _mat(Color(0.04, 0.04, 0.05), 0.3, 0.7)
		var gz: float = _face_z(head_rings, ey, ex) - 0.003
		_pe(head, gl_m, _at(-ex, hc_y + ey, gz), Vector3(0.024, 0.017, 0.004), 8, 3)
		_pe(head, gl_m, _at(ex, hc_y + ey, gz), Vector3(0.024, 0.017, 0.004), 8, 3)
		_pb(head, gl_m, _at(0.0, hc_y + ey + 0.006, gz), Vector3(0.020, 0.004, 0.004))

	# ----- 팔
	var sleeve_m: StandardMaterial3D = top_m
	if outfit == "student" and not skirt:
		sleeve_m = torso_m
	var ua_rings: Array = _circ(UARM, k, bw)
	var fa_rings: Array = _circ(FARM, k, bw)
	var arm_grow: float = 0.004 if jacket else 0.002
	for side in [-1, 1]:
		var shp = sh_l if side < 0 else sh_r
		var elp = el_l if side < 0 else el_r
		var ua_cloth: Array = _circ(UARM, k, bw)
		for i in range(ua_cloth.size()):
			var q: Vector4 = ua_cloth[i]
			ua_cloth[i] = Vector4(q.x, q.y + arm_grow, q.z + arm_grow, 0.0)
		if long_sleeve or jacket:
			_pl(shp, sleeve_m, _at(0, 0, 0), ua_cloth, 8, true, false, 0.03)
			var fa_cloth: Array = _circ(FARM, k, bw)
			for i in range(fa_cloth.size()):
				var q2: Vector4 = fa_cloth[i]
				fa_cloth[i] = Vector4(q2.x, q2.y + arm_grow, q2.z + arm_grow, 0.0)
			# 소매 끝은 손목 바로 위까지
			_pl(elp, sleeve_m, _at(0, 0, 0), fa_cloth.slice(0, 4), 8, false, false, 0.03)
			_pl(elp, skin_m, _at(0, 0, 0), fa_rings, 8, false, true, 0.0)
		else:
			var short_part: Array = ua_cloth.slice(0, 3)
			_pl(shp, skin_m, _at(0, 0, 0), ua_rings, 8, true, false, 0.0)
			_pl(shp, sleeve_m, _at(0, 0, 0), short_part, 8, true, true, 0.03)
			_pl(elp, skin_m, _at(0, 0, 0), fa_rings, 8, false, true, 0.0)
		# 손
		var hand_rings: Array = []
		for e in HAND:
			hand_rings.append(Vector4(float(e[0]) * k - FA, float(e[1]) * k, float(e[2]) * k, 0.0))
		_pl(elp, skin_m, _at(0, 0, 0), hand_rings, 8, false, true, 0.0)
		_pe(elp, skin_m, _at(float(side) * -0.02 * k, -FA - 0.035 * k, -0.018 * k), Vector3(0.011, 0.028, 0.012), 6, 3)

	# ----- 다리
	var th_rings: Array = _circ(THIGH, k, bw * hw)
	var sh_rings: Array = _circ(SHIN, k, bw)
	var leg_m: StandardMaterial3D = bot_m
	if skirt:
		leg_m = _mat(Color(0.12, 0.11, 0.12) if (seed_v % 2 == 0) else skin_c.darkened(0.04), 0.7, 0.3)
	var th_cloth: Array = []
	for q3 in th_rings:
		th_cloth.append(Vector4(q3.x, q3.y + 0.003, q3.z + 0.003, 0.0))
	var sh_cloth: Array = []
	for q4 in sh_rings:
		sh_cloth.append(Vector4(q4.x, q4.y + 0.003, q4.z + 0.003, 0.0))
	for side2 in [-1, 1]:
		var hp = hip_l if side2 < 0 else hip_r
		var kp = kn_l if side2 < 0 else kn_r
		var fp = ft_l if side2 < 0 else ft_r
		_pl(hp, leg_m, _at(0, 0, 0), th_cloth, 8, true, false, 0.035)
		_pl(kp, leg_m, _at(0, 0, 0), sh_cloth, 8, false, true, 0.03)
		if outfit == "guard":
			# 장화 목
			var boot_m: StandardMaterial3D = _mat(Color(0.07, 0.06, 0.05), 0.45, 0.5)
			var boot_rings: Array = []
			for e in SHIN:
				if float(e[0]) <= -0.24:
					boot_rings.append(Vector4(float(e[0]) * k, float(e[1]) * k * bw / k + 0.008, float(e[1]) * bw + 0.008, 0.0))
			if boot_rings.size() >= 2:
				_pl(kp, boot_m, _at(0, 0, 0), boot_rings, 8, true, false, 0.0)
		# 신발: 고리를 +Y 방향으로 쌓은 뒤 -90도 눕혀서 앞(-Z)을 향하게 함
		var shoe_rings: Array = []
		for e in SHOE:
			shoe_rings.append(Vector4(float(e[0]) * k, float(e[1]) * k * bw, float(e[2]) * k, -0.045 * k))
		var lay = Basis(Vector3.RIGHT, -PI * 0.5)
		_pl(fp, shoe_m, _atb(Vector3.ZERO, lay), shoe_rings, 8, true, true, 0.0)
		_pb(fp, _mat(Color(0.05, 0.05, 0.05), 0.8, 0.2), _at(0.0, -0.076 * k, -0.045 * k), Vector3(0.088 * bw, 0.012, 0.25 * k))

	# ----- 메시 인스턴스 만들기
	var parts: Array = [pelvis, spine, head, sh_l, sh_r, el_l, el_r, hip_l, hip_r, kn_l, kn_r, ft_l, ft_r]
	var cast: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for p in parts:
		var m: ArrayMesh = p.acc.to_mesh()
		if m.get_surface_count() == 0:
			continue
		var mi = MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = cast
		if detail_end > 0.0:
			mi.visibility_range_end = detail_end
		p.node.add_child(mi)
	if detail_end > 0.0:
		var lod_mesh: ArrayMesh = lod_acc.to_mesh()
		var lod_mi = MeshInstance3D.new()
		lod_mi.name = "Lod"
		lod_mi.mesh = lod_mesh
		lod_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lod_mi.visibility_range_begin = detail_end
		lod_mi.visibility_range_end = far_end
		root.add_child(lod_mi)

	var joints: Dictionary = {
		"root": root, "rig": rig, "pelvis": pelvis.node, "spine": spine.node, "head": head.node,
		"sh_l": sh_l.node, "sh_r": sh_r.node, "el_l": el_l.node, "el_r": el_r.node,
		"hip_l": hip_l.node, "hip_r": hip_r.node, "kn_l": kn_l.node, "kn_r": kn_r.node,
		"ft_l": ft_l.node, "ft_r": ft_r.node,
	}
	return {"root": root, "joints": joints, "L1": L1, "L2": L2, "ankle": ANK, "hip_h": hip_h}


# ---------------------------------------------------------------- NPC 정보 → 외형

const HAIR_F: Array = ["long", "bob", "bun", "short"]
const HAIR_M: Array = ["short", "side", "crew", "short"]


static func spec_from_npc(look: Dictionary, npc_id: String, role: String, is_guard: bool) -> Dictionary:
	var h: int = _hash(npc_id)
	var sex: String = str(look.get("sex", ""))
	if sex == "":
		sex = "f" if (h % 2 == 1) else "m"
	var outfit: String = "civilian"
	if is_guard or role.find("경비") >= 0 or role.find("경찰") >= 0 or role.find("군인") >= 0 or role.find("장교") >= 0 or role.find("순찰") >= 0:
		outfit = "guard"
	elif role.find("학생") >= 0:
		outfit = "student"
	elif role.find("직원") >= 0 or role.find("안내") >= 0 or role.find("접수") >= 0 or role.find("관리") >= 0 \
			or role.find("공무") >= 0 or role.find("회사원") >= 0 or role.find("교사") >= 0:
		outfit = "suit"
	elif role.find("노인") >= 0 or role.find("어르신") >= 0:
		outfit = "elder"
	elif role.find("노동") >= 0 or role.find("정비") >= 0 or role.find("청소") >= 0 or role.find("배달") >= 0 or role.find("기술자") >= 0:
		outfit = "worker"
	elif sex == "f" and (h / 3) % 3 == 0:
		outfit = "dress"
	var hair_c: Color = look.get("hair", Color(0.08, 0.07, 0.07))
	var list: Array = HAIR_F if sex == "f" else HAIR_M
	var style: String = str(look.get("hair_style", list[(h / 7) % list.size()]))
	if hair_c.get_luminance() > 0.5 and sex == "m" and (h / 5) % 3 == 0:
		style = "bald"
	var sp: Dictionary = {
		"sex": sex,
		"build": float((h / 11) % 100) / 100.0,
		"skin": look.get("skin", Color(0.86, 0.70, 0.58)),
		"hair": hair_c,
		"hair_style": style,
		"outfit": outfit,
		"top": look.get("shirt", Color(0.3, 0.3, 0.35)),
		"bottom": look.get("pants", Color(0.18, 0.18, 0.22)),
		"hat": bool(look.get("hat", false)),
		"hat_color": look.get("hat_color", Color(0.2, 0.2, 0.2)),
		"acc": str(look.get("acc", "")),
		"long_sleeve": (h / 13) % 3 != 0,
		"seed": h,
		"lowpoly": true,
	}
	if outfit == "guard":
		sp["hat"] = true
	return sp


static func player_spec() -> Dictionary:
	if not player_override.is_empty():
		return player_override.duplicate()
	return {
		"sex": "m",
		"build": 0.45,
		"skin": Color(0.86, 0.70, 0.58),
		"hair": Color(0.06, 0.05, 0.05),
		"hair_style": "short",
		"outfit": "civilian",
		"top": Color(0.22, 0.27, 0.24),
		"bottom": Color(0.16, 0.17, 0.20),
		"acc": "bag",
		"long_sleeve": true,
		"seed": 7,
	}
