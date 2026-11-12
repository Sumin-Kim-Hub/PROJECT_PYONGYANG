extends Node3D
## 도시 보강: 벤치(앉을 수 있음, 시민도 이용), 다양한 추가 건물(장식용), 큰길 차량.
## 사용자가 손본 world_builder.gd 는 건드리지 않고, 충돌 검사로 빈 곳에만 추가합니다.
## 추가 건물은 겉모습만 있고 들어갈 수 없습니다. (들어갈 수 있는 건물은 interior_manager 의 4곳)

const Kit = preload("res://scripts/interior/interior_kit.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")
const NpcData = preload("res://scripts/data/npc_data.gd")
const Flags = preload("res://scripts/data/feature_flags.gd")
const VehicleScript = preload("res://scripts/city/vehicle.gd")

const PI_: float = 3.14159265

var hub = null
var _world: Node3D = null
var _rng = RandomNumberGenerator.new()

## 이름, 크기(가로, 높이, 깊이), 색
const KINDS = [
	{"sign": "상점", "size": Vector3(8.0, 5.0, 7.0), "color": Color(0.7, 0.55, 0.4)},
	{"sign": "식당", "size": Vector3(9.0, 5.5, 8.0), "color": Color(0.62, 0.35, 0.3)},
	{"sign": "약국", "size": Vector3(6.0, 4.5, 6.0), "color": Color(0.6, 0.72, 0.62)},
	{"sign": "서점", "size": Vector3(7.0, 5.0, 7.0), "color": Color(0.5, 0.48, 0.62)},
	{"sign": "이발소", "size": Vector3(5.0, 4.0, 6.0), "color": Color(0.72, 0.68, 0.5)},
	{"sign": "시장", "size": Vector3(14.0, 4.5, 9.0), "color": Color(0.55, 0.6, 0.45)},
	{"sign": "", "size": Vector3(10.0, 14.0, 9.0), "color": Color(0.66, 0.66, 0.7)},
	{"sign": "", "size": Vector3(8.0, 9.0, 8.0), "color": Color(0.7, 0.62, 0.55)},
	{"sign": "공작소", "size": Vector3(12.0, 6.0, 10.0), "color": Color(0.5, 0.52, 0.55)},
	{"sign": "", "size": Vector3(6.0, 3.5, 6.0), "color": Color(0.74, 0.66, 0.5)},
]

## 건물을 놓아 보려는 대략적인 위치 (큰길을 피하고, 빈 자리는 충돌 검사로 정함)
const PREFS = [
	Vector3(26.0, 0.0, 75.0), Vector3(-26.0, 0.0, 85.0), Vector3(28.0, 0.0, 110.0), Vector3(-30.0, 0.0, 125.0),
	Vector3(70.0, 0.0, 26.0), Vector3(-72.0, 0.0, 28.0), Vector3(100.0, 0.0, -26.0), Vector3(-100.0, 0.0, -28.0),
	Vector3(60.0, 0.0, -30.0), Vector3(-62.0, 0.0, -34.0), Vector3(36.0, 0.0, 150.0), Vector3(-38.0, 0.0, 160.0),
]


func build(world: Node3D, hub_ref) -> void:
	hub = hub_ref
	_world = world
	_rng.seed = 2026
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _build_benches()
	await _build_buildings()
	if Flags.ENABLE_VEHICLES:
		_build_vehicles()
	print("[PYONGYANG] 도시 보강(벤치/건물/차량)을 만들었습니다.")


# ---------------------------------------------------------------- 벤치

func _build_benches() -> void:
	var pts: Array = []
	for p in NpcData.BENCH_POINTS:
		pts.append(p)
	pts.append(Vector3(-12.0, 0.0, 46.0))
	pts.append(Vector3(12.0, 0.0, -46.0))
	for p in pts:
		var spot: Vector3 = Placement.find_free_box(get_world_3d(), p, Vector3(2.8, 1.2, 1.6))
		spot.y = 0.0
		# 광장 가운데를 향해 앉도록: z 가 양수이면 북쪽(-Z)을 봄
		var face_north: bool = spot.z > 0.0
		var yaw: float = 0.0 if face_north else PI_
		var fwd: Vector3 = Vector3(0.0, 0.0, -1.0) if face_north else Vector3(0.0, 0.0, 1.0)
		var root = Node3D.new()
		root.position = spot
		root.rotation.y = yaw
		_world.add_child(root)
		var wood: Color = Color(0.5, 0.36, 0.22)
		Kit.box(root, Vector3(0.0, 0.45, 0.0), Vector3(2.0, 0.1, 0.5), wood, true, 1)
		Kit.box(root, Vector3(0.0, 0.8, 0.22), Vector3(2.0, 0.45, 0.08), wood, false, 1)
		Kit.box(root, Vector3(-0.85, 0.22, 0.0), Vector3(0.1, 0.44, 0.45), Color(0.2, 0.2, 0.22), false, 1)
		Kit.box(root, Vector3(0.85, 0.22, 0.0), Vector3(0.1, 0.44, 0.45), Color(0.2, 0.2, 0.22), false, 1)
		var it = InteractableScript.new()
		it.kind = "sit"
		it.prompt = "벤치에 앉기"
		it.radius = 1.6
		it.data = {"pos": spot, "yaw": yaw, "stand_pos": spot + fwd * 1.3 + Vector3(0.0, 0.1, 0.0),
			"outdoor": true, "occupied_by": null, "effects": []}
		it.position = Vector3(0.0, 0.5, 0.0)
		root.add_child(it)
		await get_tree().physics_frame


# ---------------------------------------------------------------- 추가 건물 (장식)

func _on_road(p: Vector3, size: Vector3) -> bool:
	# 동서 큰길(z -8..8) 과 남북 큰길(x -8..8, z > 8) 위면 제외 (여유 포함)
	if absf(p.z) < 11.0 + size.z * 0.5:
		return true
	if p.z > 0.0 and absf(p.x) < 11.0 + size.x * 0.5:
		return true
	return false


func _build_buildings() -> void:
	var count: int = 0
	var want: int = int(Flags.EXTRA_BUILDINGS)
	for i in range(PREFS.size()):
		if count >= want:
			break
		var k: Dictionary = KINDS[(i * 7 + 3) % KINDS.size()]
		var size: Vector3 = k["size"]
		var spot: Vector3 = Placement.find_free_box(get_world_3d(), PREFS[i], Vector3(size.x + 3.0, size.y, size.z + 6.0))
		spot.y = 0.0
		if _on_road(spot, size):
			continue
		# 이미 있는 건물과 겹치는지 한 번 더 확인 (find_free_box 가 실패했을 때 대비)
		if not Placement.is_free_box(get_world_3d(), spot, Vector3(size.x + 1.0, size.y, size.z + 1.0)):
			continue
		_make_building(spot, size, k["color"], str(k["sign"]), i)
		count += 1
		await get_tree().physics_frame
		await get_tree().physics_frame
	print("[PYONGYANG] 추가 건물 %d채" % count)


func _make_building(spot: Vector3, size: Vector3, color: Color, sign_text: String, idx: int) -> void:
	var root = Node3D.new()
	root.name = "Extra_%d" % idx
	root.position = spot
	# 길 쪽(큰길)을 바라보게: 큰길과 가까운 쪽으로 정면을 돌림
	var face_pos_z: bool = spot.z < 0.0
	root.rotation.y = 0.0 if face_pos_z else PI_
	if spot.z > 0.0 and absf(spot.x) < 40.0:
		# 남북 큰길 옆이면 큰길(x=0) 쪽을 보게
		root.rotation.y = -PI_ * 0.5 if spot.x > 0.0 else PI_ * 0.5
	_world.add_child(root)

	var w: float = size.x
	var h: float = size.y
	var d: float = size.z
	Kit.box(root, Vector3(0.0, h * 0.5, 0.0), size, color, true, 1)
	Kit.box(root, Vector3(0.0, h + 0.2, 0.0), Vector3(w + 0.6, 0.4, d + 0.6), color.darkened(0.45), false, 1)
	var rows: int = maxi(1, int((h - 1.5) / 3.2))
	var cols: int = maxi(2, int(w / 3.0))
	for r in range(rows):
		for c in range(cols):
			var x: float = -w * 0.5 + (float(c) + 0.5) * w / float(cols)
			var y: float = 2.0 + float(r) * 3.2
			if r == 0 and absf(x) < 1.6:
				continue
			Kit.box(root, Vector3(x, y, d * 0.5 + 0.04), Vector3(1.2, 1.3, 0.1), Color(0.18, 0.24, 0.32), false, 1)
	Kit.box(root, Vector3(0.0, 1.2, d * 0.5 + 0.05), Vector3(1.7, 2.4, 0.12), Color(0.25, 0.17, 0.12), false, 1)
	if sign_text != "":
		Kit.box(root, Vector3(0.0, 3.3, d * 0.5 + 0.12), Vector3(minf(w - 1.0, 4.0), 0.9, 0.12), Color(0.12, 0.12, 0.14), false, 1)
		Kit.label(root, Vector3(0.0, 3.3, d * 0.5 + 0.22), sign_text, 1.0, Color(1.0, 0.92, 0.6), 1)


# ---------------------------------------------------------------- 차량

func _build_vehicles() -> void:
	var colors: Array = [Color(0.6, 0.2, 0.2), Color(0.25, 0.35, 0.5), Color(0.75, 0.72, 0.65), Color(0.2, 0.3, 0.25),
		Color(0.35, 0.35, 0.38), Color(0.7, 0.55, 0.2)]
	var plan: Array = [
		# 차선 z, 방향, 시작 x, 종류
		[3.5, -1.0, 40.0, "car"], [3.5, -1.0, 120.0, "bus"], [3.5, -1.0, -60.0, "car"], [3.5, -1.0, -150.0, "car"],
		[-3.5, 1.0, -30.0, "car"], [-3.5, 1.0, 70.0, "bus"], [-3.5, 1.0, 150.0, "car"], [-3.5, 1.0, -120.0, "car"],
	]
	var n: int = 0
	var max_n: int = Flags.traffic_count(plan.size())
	for e in plan:
		if n >= max_n:
			break
		var v = VehicleScript.new()
		v.hub = hub
		v.kind = str(e[3])
		v.dir_sign = float(e[1])
		v.length = 9.0 if v.kind == "bus" else 4.2
		v.cruise = 6.0
		v.body_color = colors[n % colors.size()] if v.kind == "car" else Color(0.75, 0.3, 0.2)
		v.position = Vector3(float(e[2]), 0.0, float(e[0]))
		_world.add_child(v)
		n += 1
