extends CharacterBody3D
## 탑승/운전할 수 있는 차량 (간단한 아케이드 물리).
## 차량의 앞쪽은 -Z. 모델(vehicle_model.gd)은 +X 가 앞이라 90도 돌려서 붙입니다.
## 가속/브레이크/후진/핸들은 drive_system.gd 가 throttle_input, steer_input 으로 넣어 줍니다.
## 월드(레이어 1)와 부딪히며, NPC(레이어 2)는 통과하지만 drive_system 이 거리로 충돌을 판정합니다.

signal crashed(strength: float)

const VehicleModel = preload("res://scripts/gfx/vehicle_model.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")

const SPECS = {
	"car": {"name": "승용차", "len": 4.2, "w": 1.8, "max": 22.0, "acc": 7.0, "turn": 1.9, "seats": 4},
	"taxi": {"name": "택시", "len": 4.4, "w": 1.8, "max": 20.0, "acc": 7.0, "turn": 1.9, "seats": 4},
	"bus": {"name": "버스", "len": 9.0, "w": 2.6, "max": 13.0, "acc": 3.2, "turn": 1.0, "seats": 20},
	"truck": {"name": "트럭", "len": 7.2, "w": 2.3, "max": 15.0, "acc": 4.0, "turn": 1.2, "seats": 3},
	"military": {"name": "군용 차량", "len": 6.6, "w": 2.3, "max": 17.0, "acc": 5.0, "turn": 1.4, "seats": 8},
	"police": {"name": "경찰차", "len": 4.4, "w": 1.8, "max": 25.0, "acc": 8.5, "turn": 2.0, "seats": 4},
}

var hub = null
var kind: String = "car"
var vid: String = ""
var display_name: String = "승용차"
var body_color: Color = Color(0.25, 0.35, 0.5)
var length: float = 4.2
var width: float = 1.8
var max_speed: float = 22.0
var accel: float = 7.0
var turn_rate: float = 1.9
var seats: int = 4

var speed: float = 0.0
var throttle_input: float = 0.0
var steer_input: float = 0.0
var handbrake_t: float = 0.0
var occupied: bool = false
## 타고 있는 NPC (운전자 외 승객)
var occupants: Array = []

var _mesh: MeshInstance3D = null
var _interact = null
var _light: SpotLight3D = null
var _crash_cool: float = 0.0
## V2: 경찰차 경광등 (켜져 있으면 빨강/파랑 번갈아 깜박임)
var siren: bool = false
var _siren_light: OmniLight3D = null
var _siren_t: float = 0.0


func setup_kind(k: String) -> void:
	kind = k
	var s: Dictionary = SPECS.get(k, SPECS["car"])
	display_name = str(s["name"])
	length = float(s["len"])
	width = float(s["w"])
	max_speed = float(s["max"])
	accel = float(s["acc"])
	turn_rate = float(s["turn"])
	seats = int(s["seats"])


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.4
	add_to_group("drivables")
	var shape = BoxShape3D.new()
	shape.size = Vector3(width, 1.2, length)
	var cs = CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, 0.85, 0.0)
	add_child(cs)
	_build_visual()

	_interact = InteractableScript.new()
	_interact.kind = "vehicle"
	_interact.prompt = "%s에 타기" % display_name
	_interact.button_text = "탑승"
	_interact.radius = maxf(2.6, width * 0.5 + 1.8)
	_interact.data = {"vehicle": self}
	_interact.position = Vector3(0.0, 1.0, 0.0)
	add_child(_interact)

	_light = SpotLight3D.new()
	_light.position = Vector3(0.0, 0.9, -length * 0.5 - 0.1)
	_light.spot_range = 26.0
	_light.spot_angle = 32.0
	_light.light_energy = 2.2
	_light.light_cull_mask = 1
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)

	if kind == "police":
		_siren_light = OmniLight3D.new()
		_siren_light.position = Vector3(0.0, 2.1, 0.0)
		_siren_light.omni_range = 12.0
		_siren_light.light_energy = 2.5
		_siren_light.light_cull_mask = 1
		_siren_light.shadow_enabled = false
		_siren_light.visible = false
		add_child(_siren_light)


func _build_visual() -> void:
	var holder = Node3D.new()
	holder.name = "Model"
	holder.rotation.y = PI * 0.5
	add_child(holder)
	var mesh = null
	if VehicleModel != null:
		mesh = VehicleModel.build(kind, length, body_color)
	if mesh != null and mesh is ArrayMesh and mesh.get_surface_count() > 0:
		_mesh = MeshInstance3D.new()
		_mesh.mesh = mesh
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(_mesh)
	else:
		# 모델 생성에 실패하면 단순 상자
		var bm = BoxMesh.new()
		bm.size = Vector3(length, 1.2, width)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = body_color
		_mesh = MeshInstance3D.new()
		_mesh.mesh = bm
		_mesh.material_override = mat
		_mesh.position = Vector3(0.0, 0.85, 0.0)
		holder.add_child(_mesh)


func _process(delta: float) -> void:
	if _siren_light == null:
		return
	var on: bool = siren or (occupied and absf(speed) > 6.0)
	_siren_light.visible = on
	if on:
		_siren_t += delta
		var phase: bool = int(_siren_t * 4.0) % 2 == 0
		_siren_light.light_color = Color(1.0, 0.1, 0.1) if phase else Color(0.15, 0.3, 1.0)


func set_body_visible(v: bool) -> void:
	if _mesh != null:
		_mesh.visible = v


func set_headlights(on: bool) -> void:
	if _light != null:
		_light.visible = on


func forward() -> Vector3:
	return -global_transform.basis.z


func right() -> Vector3:
	return global_transform.basis.x


func set_occupied(v: bool) -> void:
	occupied = v
	if _interact != null:
		_interact.enabled = not v
	if not v:
		throttle_input = 0.0
		steer_input = 0.0
		set_headlights(false)


func _physics_process(delta: float) -> void:
	_crash_cool = maxf(0.0, _crash_cool - delta)
	handbrake_t = maxf(0.0, handbrake_t - delta)
	var t: float = throttle_input if occupied else 0.0
	if handbrake_t > 0.0:
		speed = move_toward(speed, 0.0, 26.0 * delta)
	elif t > 0.05:
		if speed < -0.5:
			speed = move_toward(speed, 0.0, 18.0 * delta)
		else:
			var gear: float = 1.0 - 0.6 * clampf(speed / max_speed, 0.0, 1.0)
			speed = move_toward(speed, max_speed * t, accel * gear * delta + 0.01)
	elif t < -0.05:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, 17.0 * absf(t) * delta)
		else:
			speed = move_toward(speed, -max_speed * 0.3 * absf(t), accel * 0.6 * delta)
	else:
		speed = move_toward(speed, 0.0, (3.0 if occupied else 14.0) * delta)

	var steer_f: float = clampf(absf(speed) / 4.0, 0.0, 1.0) * signf(speed)
	var load_f: float = 1.0 - 0.45 * clampf(absf(speed) / max_speed, 0.0, 1.0)
	rotation.y += -steer_input * turn_rate * steer_f * load_f * delta

	var fwd: Vector3 = forward()
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if not is_on_floor():
		velocity.y -= 16.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()

	var after: float = Vector3(velocity.x, 0.0, velocity.z).dot(fwd)
	var lost: float = absf(speed) - absf(after)
	if lost > 5.0 and _crash_cool <= 0.0 and get_slide_collision_count() > 0:
		_crash_cool = 0.8
		crashed.emit(lost)
	speed = after
	rotation.x = 0.0
	rotation.z = 0.0


## 승객 NPC 태우기 (NPC 는 숨겨지고 차와 함께 이동한 것처럼 처리됨)
func add_passenger(npc) -> bool:
	if occupants.size() >= seats - 1:
		return false
	occupants.append(npc)
	if npc.has_method("board_vehicle"):
		npc.board_vehicle(self)
	return true


func unload_passengers(base: Vector3) -> void:
	var i: int = 0
	for n in occupants:
		if is_instance_valid(n) and n.has_method("alight_at"):
			n.alight_at(base + Vector3(float(i) * 0.9, 0.0, 0.0))
		i += 1
	occupants.clear()
