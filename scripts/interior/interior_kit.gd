extends RefCounted
## 건물 내부 만들기 도우미(정적 함수 모음). 방, 벽, 조명, 가구를 코드로 만듭니다.
## 내부 물체는 시각 레이어 2 에 올려, 바깥 태양빛(레이어 1만 비춤)의 영향을 받지 않게 합니다.
## 좌표는 모두 부모 노드 기준(지역 좌표)입니다. 바닥 높이 = pos.y.

const LAYER_INTERIOR: int = 2

static var _mats: Dictionary = {}


static func mat(color: Color, emissive: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s_%s" % [str(color), str(emissive)]
	if _mats.has(key):
		return _mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m


## 상자 하나. collide 가 true 면 충돌체가 있는 StaticBody3D, 아니면 MeshInstance3D 를 돌려줌
static func box(parent: Node, pos: Vector3, size: Vector3, color: Color, collide: bool = true, layer: int = LAYER_INTERIOR, emissive: float = 0.0) -> Node3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, emissive)
	mi.layers = layer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not collide:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body = StaticBody3D.new()
	body.position = pos
	var cs = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	parent.add_child(body)
	return body


static func _piece(parent: Node, along_x: bool, lo: float, hi: float, fixed: float, y0: float, y1: float, t: float, color: Color, layer: int) -> void:
	if hi - lo < 0.01 or y1 - y0 < 0.01:
		return
	var mid: float = (lo + hi) * 0.5
	var ym: float = (y0 + y1) * 0.5
	if along_x:
		box(parent, Vector3(mid, ym, fixed), Vector3(hi - lo, y1 - y0, t), color, true, layer)
	else:
		box(parent, Vector3(fixed, ym, mid), Vector3(t, y1 - y0, hi - lo), color, true, layer)


## 축에 나란한 벽. a, b 는 바닥 높이의 양 끝점.
## gap = Vector2(구멍 중심 오프셋, 구멍 너비) 또는 그 배열이면 문 구멍을 뚫음 (오프셋은 벽 중앙 기준)
static func wall(parent: Node, a: Vector3, b: Vector3, h: float, t: float, color: Color, gap = null, layer: int = LAYER_INTERIOR) -> void:
	var along_x: bool = absf(b.x - a.x) >= absf(b.z - a.z)
	var lo: float = minf(a.x, b.x) if along_x else minf(a.z, b.z)
	var hi: float = maxf(a.x, b.x) if along_x else maxf(a.z, b.z)
	var fixed: float = a.z if along_x else a.x
	var y0: float = a.y
	var gaps: Array = []
	if gap is Vector2:
		if gap.y > 0.0:
			gaps.append(gap)
	elif gap is Array:
		for g in gap:
			if g is Vector2 and g.y > 0.0:
				gaps.append(g)
	gaps.sort_custom(func(p, q): return p.x < q.x)
	var mid: float = (lo + hi) * 0.5
	var door_h: float = minf(2.4, h - 0.2)
	var cursor: float = lo
	for g in gaps:
		var g0: float = mid + g.x - g.y * 0.5
		var g1: float = mid + g.x + g.y * 0.5
		_piece(parent, along_x, cursor, g0, fixed, y0, y0 + h, t, color, layer)
		_piece(parent, along_x, g0, g1, fixed, y0 + door_h, y0 + h, t, color, layer)
		cursor = g1
	_piece(parent, along_x, cursor, hi, fixed, y0, y0 + h, t, color, layer)


## 직사각형 방. c = 바닥 중심. gaps: {"n","s","e","w"} -> Vector2(오프셋, 너비)
## n = -Z 쪽, s = +Z 쪽, e = +X 쪽, w = -X 쪽 벽. 값은 Vector2 한 개 또는 Vector2 배열.
static func room(parent: Node, c: Vector3, w: float, d: float, h: float, floor_col: Color, wall_col: Color, ceil_col: Color, gaps: Dictionary = {}) -> void:
	var t: float = 0.3
	box(parent, c + Vector3(0.0, -0.15, 0.0), Vector3(w + t, 0.3, d + t), floor_col)
	box(parent, c + Vector3(0.0, h + 0.15, 0.0), Vector3(w + t, 0.3, d + t), ceil_col)
	var x0: float = c.x - w * 0.5
	var x1: float = c.x + w * 0.5
	var z0: float = c.z - d * 0.5
	var z1: float = c.z + d * 0.5
	var y: float = c.y
	wall(parent, Vector3(x0 - t * 0.5, y, z0), Vector3(x1 + t * 0.5, y, z0), h, t, wall_col, gaps.get("n"))
	wall(parent, Vector3(x0 - t * 0.5, y, z1), Vector3(x1 + t * 0.5, y, z1), h, t, wall_col, gaps.get("s"))
	wall(parent, Vector3(x1, y, z0), Vector3(x1, y, z1), h, t, wall_col, gaps.get("e"))
	wall(parent, Vector3(x0, y, z0), Vector3(x0, y, z1), h, t, wall_col, gaps.get("w"))


static func lamp(parent: Node, pos: Vector3, energy: float = 1.3, light_range: float = 9.0, color: Color = Color(1.0, 0.92, 0.75), fixture: bool = true) -> void:
	var l = OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.omni_range = light_range
	l.light_color = color
	# 레이어 1(플레이어/NPC)과 2(내부 물체)를 모두 비춤. 내부는 도시에서 멀리 떨어져 있어 바깥에 영향 없음
	l.light_cull_mask = 3
	l.shadow_enabled = false
	parent.add_child(l)
	if fixture:
		box(parent, pos + Vector3(0.0, 0.12, 0.0), Vector3(0.5, 0.06, 0.5), Color(1.0, 0.95, 0.8), false, LAYER_INTERIOR, 2.0)


static func label(parent: Node, pos: Vector3, text: String, size: float = 0.5, color: Color = Color(1, 1, 1), layer: int = LAYER_INTERIOR, yaw: float = 0.0) -> Label3D:
	var l = Label3D.new()
	l.text = text
	l.pixel_size = 0.01 * size
	l.font_size = 64
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos
	l.rotation.y = yaw
	l.layers = layer
	l.shaded = false
	l.double_sided = true
	parent.add_child(l)
	return l


# ---------------------------------------------------------------- 가구
# 가구의 앞쪽(앉는 사람이 바라보는 쪽)은 지역 -Z 방향. yaw 는 그 방향을 돌리는 각도.

static func _furn(parent: Node, pos: Vector3, yaw: float) -> Node3D:
	var n = Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


static func sofa(parent: Node, pos: Vector3, yaw: float, color: Color = Color(0.45, 0.22, 0.22)) -> Node3D:
	var n: Node3D = _furn(parent, pos, yaw)
	box(n, Vector3(0.0, 0.22, 0.0), Vector3(2.0, 0.44, 0.9), color)
	box(n, Vector3(0.0, 0.72, 0.38), Vector3(2.0, 0.55, 0.2), color.darkened(0.15))
	box(n, Vector3(-0.95, 0.4, 0.0), Vector3(0.2, 0.6, 0.9), color.darkened(0.1))
	box(n, Vector3(0.95, 0.4, 0.0), Vector3(0.2, 0.6, 0.9), color.darkened(0.1))
	return n


static func chair(parent: Node, pos: Vector3, yaw: float, color: Color = Color(0.45, 0.32, 0.2)) -> Node3D:
	var n: Node3D = _furn(parent, pos, yaw)
	box(n, Vector3(0.0, 0.42, 0.0), Vector3(0.5, 0.08, 0.5), color)
	box(n, Vector3(0.0, 0.2, 0.0), Vector3(0.1, 0.4, 0.1), color.darkened(0.3))
	box(n, Vector3(0.0, 0.75, 0.22), Vector3(0.5, 0.55, 0.06), color)
	return n


static func table(parent: Node, pos: Vector3, w: float, d: float, h: float = 0.75, color: Color = Color(0.5, 0.36, 0.22)) -> Node3D:
	var n: Node3D = _furn(parent, pos, 0.0)
	box(n, Vector3(0.0, h - 0.04, 0.0), Vector3(w, 0.08, d), color)
	box(n, Vector3(-w * 0.5 + 0.1, (h - 0.08) * 0.5, -d * 0.5 + 0.1), Vector3(0.08, h - 0.08, 0.08), color.darkened(0.3))
	box(n, Vector3(w * 0.5 - 0.1, (h - 0.08) * 0.5, -d * 0.5 + 0.1), Vector3(0.08, h - 0.08, 0.08), color.darkened(0.3))
	box(n, Vector3(-w * 0.5 + 0.1, (h - 0.08) * 0.5, d * 0.5 - 0.1), Vector3(0.08, h - 0.08, 0.08), color.darkened(0.3))
	box(n, Vector3(w * 0.5 - 0.1, (h - 0.08) * 0.5, d * 0.5 - 0.1), Vector3(0.08, h - 0.08, 0.08), color.darkened(0.3))
	return n


static func bed(parent: Node, pos: Vector3, yaw: float, color: Color = Color(0.35, 0.4, 0.55)) -> Node3D:
	var n: Node3D = _furn(parent, pos, yaw)
	box(n, Vector3(0.0, 0.2, 0.0), Vector3(1.3, 0.4, 2.1), Color(0.4, 0.3, 0.22))
	box(n, Vector3(0.0, 0.46, 0.05), Vector3(1.2, 0.14, 1.9), color)
	box(n, Vector3(0.0, 0.6, 0.78), Vector3(0.7, 0.12, 0.35), Color(0.9, 0.9, 0.88), false)
	return n


static func shelf(parent: Node, pos: Vector3, yaw: float, w: float = 1.6, h: float = 2.0, color: Color = Color(0.4, 0.28, 0.18)) -> Node3D:
	var n: Node3D = _furn(parent, pos, yaw)
	box(n, Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, 0.4), color)
	var cols: Array = [Color(0.6, 0.2, 0.2), Color(0.2, 0.4, 0.6), Color(0.3, 0.5, 0.3), Color(0.7, 0.6, 0.3), Color(0.5, 0.3, 0.5)]
	var rows: int = int(h / 0.45)
	for r in range(rows):
		var cx: float = -w * 0.5 + 0.12
		var i: int = 0
		while cx < w * 0.5 - 0.12:
			var bw: float = 0.06 + 0.02 * float((i * 7 + r * 3) % 4)
			box(n, Vector3(cx + bw * 0.5, 0.3 + 0.45 * float(r), -0.21), Vector3(bw, 0.32, 0.04), cols[(i + r) % cols.size()], false)
			cx += bw + 0.015
			i += 1
	return n


static func counter(parent: Node, pos: Vector3, yaw: float, w: float = 2.4, color: Color = Color(0.45, 0.33, 0.22)) -> Node3D:
	var n: Node3D = _furn(parent, pos, yaw)
	box(n, Vector3(0.0, 0.5, 0.0), Vector3(w, 1.0, 0.6), color)
	box(n, Vector3(0.0, 1.03, 0.0), Vector3(w + 0.1, 0.06, 0.7), color.lightened(0.15))
	return n


static func rug(parent: Node, pos: Vector3, w: float, d: float, color: Color) -> void:
	box(parent, pos + Vector3(0.0, 0.015, 0.0), Vector3(w, 0.03, d), color, false)


static func crate(parent: Node, pos: Vector3, size: Vector3, color: Color = Color(0.45, 0.38, 0.28)) -> void:
	box(parent, pos + Vector3(0.0, size.y * 0.5, 0.0), size, color)
