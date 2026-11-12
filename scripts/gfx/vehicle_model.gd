extends RefCounted
## 승용차 / 버스 모델을 하나의 메시(재질별 면)로 만든다. 진행 방향 +X, 폭 방향 Z.
## character_builder.gd 의 메시 모으기 도구를 그대로 씁니다.

const CB = preload("res://scripts/gfx/character_builder.gd")


static func _emis(color: Color, energy: float, key: String) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.resource_name = key
	return m


static func _bx(acc, mat: StandardMaterial3D, pos: Vector3, size: Vector3) -> void:
	CB._box(acc, mat, Transform3D(Basis.IDENTITY, pos), size)


static func _wheel(acc, tire: StandardMaterial3D, hub: StandardMaterial3D, pos: Vector3, radius: float, width: float) -> void:
	var lay = Basis(Vector3.RIGHT, PI * 0.5)
	var xf = Transform3D(lay, pos)
	CB._loft(acc, tire, xf, [Vector4(-width * 0.5, radius, radius, 0.0), Vector4(width * 0.5, radius, radius, 0.0)], 12, true, true, 0.0)
	var xf2 = Transform3D(lay, pos + Vector3(0.0, 0.0, signf(pos.z) * (width * 0.5 + 0.005)))
	CB._loft(acc, hub, xf2, [Vector4(-0.01, radius * 0.55, radius * 0.55, 0.0), Vector4(0.01, radius * 0.55, radius * 0.55, 0.0)], 8, true, true, 0.0)


static func build(kind: String, length: float, color: Color) -> ArrayMesh:
	CB._lowpoly = false
	var acc = CB.Acc.new()
	var paint: StandardMaterial3D = CB._mat(color, 0.30, 0.85)
	var paint_dark: StandardMaterial3D = CB._mat(color.darkened(0.30), 0.40, 0.7)
	var glass: StandardMaterial3D = CB._mat(Color(0.10, 0.15, 0.20), 0.08, 0.95)
	var tire: StandardMaterial3D = CB._mat(Color(0.05, 0.05, 0.06), 0.95, 0.1)
	var chrome: StandardMaterial3D = CB._mat(Color(0.74, 0.75, 0.78), 0.2, 0.95)
	var dark: StandardMaterial3D = CB._mat(Color(0.07, 0.07, 0.08), 0.8, 0.2)
	var plate: StandardMaterial3D = CB._mat(Color(0.92, 0.92, 0.90), 0.6, 0.3)
	var head: StandardMaterial3D = _emis(Color(1.0, 0.95, 0.72), 1.4, "veh_head")
	var tail: StandardMaterial3D = _emis(Color(0.9, 0.08, 0.08), 1.0, "veh_tail")

	var L: float = length
	var h: float = L * 0.5
	if kind == "bus":
		var w: float = 2.6
		_bx(acc, paint, Vector3(0, 0.85, 0), Vector3(L, 1.0, w))                     # 아래 차체
		_bx(acc, glass, Vector3(0, 1.80, 0), Vector3(L - 0.3, 0.9, w + 0.03))         # 창문 띠
		_bx(acc, paint, Vector3(0, 2.42, 0), Vector3(L, 0.16, w))                    # 지붕
		var px: float = -h + 0.9
		while px < h - 0.8:
			_bx(acc, paint, Vector3(px, 1.80, 0), Vector3(0.10, 0.92, w + 0.06))     # 창 기둥
			px += 1.6
		_bx(acc, glass, Vector3(h + 0.01, 1.65, 0), Vector3(0.05, 1.25, w - 0.3))     # 앞 유리
		_bx(acc, head, Vector3(h + 0.02, 0.75, w * 0.32), Vector3(0.06, 0.22, 0.4))
		_bx(acc, head, Vector3(h + 0.02, 0.75, -w * 0.32), Vector3(0.06, 0.22, 0.4))
		_bx(acc, tail, Vector3(-h - 0.02, 0.85, w * 0.32), Vector3(0.06, 0.22, 0.4))
		_bx(acc, tail, Vector3(-h - 0.02, 0.85, -w * 0.32), Vector3(0.06, 0.22, 0.4))
		_bx(acc, _emis(Color(1.0, 0.6, 0.1), 1.2, "veh_sign"), Vector3(h + 0.02, 2.2, 0), Vector3(0.05, 0.22, 1.2))
		_bx(acc, dark, Vector3(h + 0.1, 0.40, 0), Vector3(0.22, 0.25, w + 0.04))     # 범퍼
		_bx(acc, dark, Vector3(-h - 0.1, 0.40, 0), Vector3(0.22, 0.25, w + 0.04))
		_bx(acc, dark, Vector3(1.2, 1.1, w * 0.5 + 0.02), Vector3(1.1, 1.7, 0.03))   # 승차문
		for wx in [-h * 0.62, h * 0.62]:
			for sz in [-1.0, 1.0]:
				_wheel(acc, tire, chrome, Vector3(wx, 0.5, sz * (w * 0.5 - 0.12)), 0.5, 0.3)
	elif kind == "truck" or kind == "military":
		var w3: float = 2.3
		var cargo: StandardMaterial3D = paint_dark
		if kind == "military":
			cargo = CB._mat(color.darkened(0.15), 0.95, 0.1)
		_bx(acc, paint, Vector3(h - 1.2, 1.35, 0), Vector3(2.4, 1.5, w3))                 # 운전석
		_bx(acc, glass, Vector3(h - 0.3, 1.75, 0), Vector3(0.9, 0.75, w3 - 0.2))          # 앞유리
		_bx(acc, glass, Vector3(h - 1.2, 1.9, 0), Vector3(1.6, 0.6, w3 + 0.03))           # 옆유리
		_bx(acc, dark, Vector3(-0.2, 0.62, 0), Vector3(L - 2.8, 0.3, w3 - 0.3))           # 차대
		_bx(acc, cargo, Vector3(-1.4, 1.75, 0), Vector3(L - 3.4, 2.0, w3))               # 짐칸
		if kind == "military":
			_bx(acc, cargo, Vector3(-1.4, 2.9, 0), Vector3(L - 3.8, 0.4, w3 - 0.5))      # 덮개 윗부분
		else:
			_bx(acc, paint_dark, Vector3(-1.4, 2.82, 0), Vector3(L - 3.3, 0.12, w3 + 0.08))
		_bx(acc, dark, Vector3(h + 0.1, 0.45, 0), Vector3(0.22, 0.3, w3 + 0.04))
		_bx(acc, dark, Vector3(-h - 0.1, 0.45, 0), Vector3(0.22, 0.3, w3 + 0.04))
		_bx(acc, head, Vector3(h + 0.02, 0.95, w3 * 0.34), Vector3(0.06, 0.2, 0.34))
		_bx(acc, head, Vector3(h + 0.02, 0.95, -w3 * 0.34), Vector3(0.06, 0.2, 0.34))
		_bx(acc, tail, Vector3(-h - 0.02, 0.95, w3 * 0.34), Vector3(0.06, 0.2, 0.3))
		_bx(acc, tail, Vector3(-h - 0.02, 0.95, -w3 * 0.34), Vector3(0.06, 0.2, 0.3))
		for wx3 in [h - 1.3, -h + 1.0, -h + 2.5]:
			for sz4 in [-1.0, 1.0]:
				_wheel(acc, tire, chrome, Vector3(wx3, 0.5, sz4 * (w3 * 0.5 - 0.12)), 0.5, 0.34)
	else:
		var w2: float = 1.8
		_bx(acc, paint, Vector3(0, 0.55, 0), Vector3(L, 0.55, w2))                    # 차체
		_bx(acc, paint, Vector3(h * 0.62, 0.90, 0), Vector3(L * 0.28, 0.14, w2 - 0.08))  # 본네트
		_bx(acc, paint, Vector3(-h * 0.70, 0.90, 0), Vector3(L * 0.22, 0.14, w2 - 0.08)) # 트렁크
		_bx(acc, glass, Vector3(-0.1, 1.12, 0), Vector3(L * 0.46, 0.46, w2 - 0.14))      # 유리 캐빈
		_bx(acc, paint, Vector3(-0.1, 1.38, 0), Vector3(L * 0.40, 0.07, w2 - 0.2))       # 지붕
		for sx in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				_bx(acc, paint_dark, Vector3(-0.1 + sx * L * 0.21, 1.12, sz2 * (w2 * 0.5 - 0.08)), Vector3(0.07, 0.46, 0.07))
		_bx(acc, glass, Vector3(L * 0.17, 1.10, 0), Vector3(0.05, 0.40, w2 - 0.3))
		_bx(acc, dark, Vector3(h + 0.05, 0.38, 0), Vector3(0.14, 0.22, w2 + 0.02))       # 범퍼
		_bx(acc, dark, Vector3(-h - 0.05, 0.38, 0), Vector3(0.14, 0.22, w2 + 0.02))
		_bx(acc, dark, Vector3(h + 0.02, 0.60, 0), Vector3(0.05, 0.16, 0.7))             # 그릴
		_bx(acc, plate, Vector3(-h - 0.13, 0.42, 0), Vector3(0.03, 0.14, 0.45))
		_bx(acc, head, Vector3(h + 0.02, 0.66, w2 * 0.34), Vector3(0.06, 0.14, 0.3))
		_bx(acc, head, Vector3(h + 0.02, 0.66, -w2 * 0.34), Vector3(0.06, 0.14, 0.3))
		_bx(acc, tail, Vector3(-h - 0.02, 0.66, w2 * 0.34), Vector3(0.06, 0.12, 0.3))
		_bx(acc, tail, Vector3(-h - 0.02, 0.66, -w2 * 0.34), Vector3(0.06, 0.12, 0.3))
		_bx(acc, paint_dark, Vector3(0.35, 0.92, w2 * 0.5 + 0.06), Vector3(0.14, 0.1, 0.12)) # 사이드미러
		_bx(acc, paint_dark, Vector3(0.35, 0.92, -w2 * 0.5 - 0.06), Vector3(0.14, 0.1, 0.12))
		if kind == "taxi":
			_bx(acc, _emis(Color(1.0, 0.9, 0.4), 1.3, "veh_taxi"), Vector3(-0.1, 1.55, 0), Vector3(0.7, 0.18, 0.36))
			_bx(acc, dark, Vector3(L * 0.1, 0.74, w2 * 0.5 + 0.015), Vector3(L * 0.8, 0.05, 0.02))
		elif kind == "police":
			# V2: 경찰차 - 지붕 경광등(빨강/파랑)과 옆면 파란 띠
			_bx(acc, _emis(Color(0.95, 0.1, 0.1), 1.6, "veh_pl_r"), Vector3(-0.1, 1.5, w2 * 0.2), Vector3(0.24, 0.1, 0.34))
			_bx(acc, _emis(Color(0.15, 0.35, 1.0), 1.6, "veh_pl_b"), Vector3(-0.1, 1.5, -w2 * 0.2), Vector3(0.24, 0.1, 0.34))
			var stripe: StandardMaterial3D = CB._mat(Color(0.10, 0.22, 0.55), 0.5, 0.4)
			_bx(acc, stripe, Vector3(L * 0.05, 0.60, w2 * 0.5 + 0.015), Vector3(L * 0.8, 0.16, 0.02))
			_bx(acc, stripe, Vector3(L * 0.05, 0.60, -w2 * 0.5 - 0.015), Vector3(L * 0.8, 0.16, 0.02))
		for wx2 in [-h * 0.62, h * 0.62]:
			for sz3 in [-1.0, 1.0]:
				_wheel(acc, tire, chrome, Vector3(wx2, 0.34, sz3 * (w2 * 0.5 - 0.1)), 0.34, 0.24)
	return acc.to_mesh()
