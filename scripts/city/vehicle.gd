extends AnimatableBody3D
## 큰길을 오가는 차량 (승용차 / 버스). 가까운 앞에 플레이어가 있으면 멈춰서 부딪히지 않습니다.
## 충돌체가 있어 걸어서 통과할 수 없습니다. 장식용 교통이며 상호작용은 없습니다.

const Flags = preload("res://scripts/data/feature_flags.gd")

const LIMIT_X: float = 215.0

var hub = null
var dir_sign: float = 1.0
var cruise: float = 7.0
var length: float = 4.2
var kind: String = "car"
var body_color: Color = Color(0.6, 0.2, 0.2)

## 버스 정류장 정차(V1): 정차 중 타고 있는 시민
var passengers: Array = []

const BUS_STOPS_X: Array = [-104.0, 104.0]

var _speed: float = 0.0
var _dwell: float = 0.0
var _last_stop_x: float = 9999.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("vehicles")
	_build()


func _build() -> void:
	var w: float = 1.8
	var body_h: float = 0.8
	var cabin_len: float = length * 0.5
	var body_y: float = 0.65
	if kind == "bus":
		w = 2.6
		body_h = 2.2
		body_y = 1.45
		cabin_len = 0.0

	var shape = BoxShape3D.new()
	shape.size = Vector3(length, body_h + 0.5, w)
	var cs = CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, body_y + 0.15, 0.0)
	add_child(cs)

	# 그래픽 개선: 하나로 합친 사실적인 차량 메시. 실패하면 아래 예전 상자 모델을 그대로 씀
	if _build_gfx():
		rotation.y = 0.0 if dir_sign > 0.0 else PI
		return

	_box(Vector3(0.0, body_y, 0.0), Vector3(length, body_h, w), body_color)
	if kind == "bus":
		# 창문 띠
		_box(Vector3(0.0, body_y + 0.3, 0.0), Vector3(length - 0.4, 0.7, w + 0.04), Color(0.15, 0.2, 0.28))
		_box(Vector3(0.0, body_y + body_h * 0.5 + 0.05, 0.0), Vector3(length - 0.2, 0.1, w - 0.2), body_color.darkened(0.25))
	else:
		_box(Vector3(-0.2, body_y + body_h * 0.5 + 0.3, 0.0), Vector3(cabin_len, 0.6, w - 0.2), Color(0.15, 0.2, 0.28))
	# 바퀴
	var wx: float = length * 0.5 - 0.8
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(wx * sx, 0.35, (w * 0.5) * sz), Vector3(0.7, 0.7, 0.2), Color(0.06, 0.06, 0.07))
	# 앞/뒤 등 (진행 방향이 +X 일 때 앞은 +X)
	_box(Vector3(length * 0.5, body_y, w * 0.3), Vector3(0.06, 0.2, 0.3), Color(1.0, 0.95, 0.7), 1.5)
	_box(Vector3(length * 0.5, body_y, -w * 0.3), Vector3(0.06, 0.2, 0.3), Color(1.0, 0.95, 0.7), 1.5)
	_box(Vector3(-length * 0.5, body_y, w * 0.3), Vector3(0.06, 0.2, 0.3), Color(0.9, 0.1, 0.1), 1.0)
	_box(Vector3(-length * 0.5, body_y, -w * 0.3), Vector3(0.06, 0.2, 0.3), Color(0.9, 0.1, 0.1), 1.0)
	# 진행 방향에 맞춰 돌림 (-X 로 가는 차는 180도)
	rotation.y = 0.0 if dir_sign > 0.0 else PI


func _build_gfx() -> bool:
	if not Flags.ENABLE_GFX or not Flags.GFX_ENVIRONMENT or not Flags.gfx_enabled():
		return false
	var vm = load("res://scripts/gfx/vehicle_model.gd")
	if vm == null or not vm.can_instantiate():
		return false
	var mesh = vm.build(kind, length, body_color)
	if mesh == null or not (mesh is ArrayMesh):
		return false
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 200.0
	add_child(mi)
	return true


func _box(pos: Vector3, size: Vector3, color: Color, emissive: float = 0.0) -> void:
	var mesh = BoxMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 160.0
	add_child(mi)


func _physics_process(delta: float) -> void:
	var target: float = cruise
	if hub != null and hub.player != null:
		var pp: Vector3 = hub.player.global_position
		var ahead: float = (pp.x - global_position.x) * dir_sign
		var side: float = absf(pp.z - global_position.z)
		if side < 3.2 and ahead > 0.0 and ahead < length * 0.5 + 8.0 and absf(pp.y - global_position.y) < 3.0:
			target = 0.0
	# 플레이어가 운전 중인(또는 움직이는) 차량 앞에서도 멈춤
	for dv in get_tree().get_nodes_in_group("drivables"):
		if not (dv.occupied or absf(dv.speed) > 1.0):
			continue
		var ahead2: float = (dv.global_position.x - global_position.x) * dir_sign
		var side2: float = absf(dv.global_position.z - global_position.z)
		if side2 < 3.4 and ahead2 > 0.0 and ahead2 < (length + dv.length) * 0.5 + 4.0:
			target = 0.0
	target = _bus_stop_logic(target, delta)
	# 같은 차선 앞차와 간격 유지 (서로 통과하지 않게)
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v == self or absf(v.global_position.z - global_position.z) > 1.0:
			continue
		var gap: float = (v.global_position.x - global_position.x) * dir_sign
		if gap > 0.0 and gap < (length + v.length) * 0.5 + 3.5:
			target = 0.0
	_speed = move_toward(_speed, target, (10.0 if target == 0.0 else 3.0) * delta)
	var p: Vector3 = global_position
	p.x += dir_sign * _speed * delta
	if absf(p.x) > LIMIT_X:
		p.x = -dir_sign * LIMIT_X
	global_position = p


## 버스: 정류장 앞에서 천천히 서고 6초 정차하며 승객을 태우고 내림
func _bus_stop_logic(target: float, delta: float) -> float:
	if kind != "bus" or not (Flags.ENABLE_V1 and Flags.V1_TRAFFIC) or hub == null:
		return target
	if absf(global_position.x - _last_stop_x) > 20.0:
		_last_stop_x = 9999.0
	if _dwell > 0.0:
		_dwell -= delta
		return 0.0
	for sx in BUS_STOPS_X:
		if absf(float(sx) - _last_stop_x) < 1.0:
			continue
		var gap: float = (float(sx) - global_position.x) * dir_sign
		if gap > -0.5 and gap < 11.0:
			var t2: float = minf(target, maxf(0.0, gap * 0.7))
			if gap < 2.5:
				_dwell = 6.0
				_last_stop_x = float(sx)
				var v1 = hub.get("v1")
				if v1 != null and v1.get("drive") != null:
					v1.drive.on_bus_stop(self, Vector3(float(sx), 0.0, -dir_sign * 11.5))
				return 0.0
			return t2
	return target
