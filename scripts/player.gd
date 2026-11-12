extends CharacterBody3D
## 플레이어. 몸통/충돌 모양을 코드로 만들고, 카메라 방향 기준으로 이동합니다.
## controls, camera_rig 는 main.gd 가 setup()으로 연결해 줍니다.
## (일부러 타입을 적지 않은 변수입니다. 다른 스크립트의 함수를 불러야 하기 때문입니다.)

const Cfg = preload("res://scripts/game_config.gd")

const WALK_SPEED: float = 3.2
const RUN_SPEED: float = 6.8
const ACCEL: float = 16.0
const JUMP_VELOCITY: float = 5.2
const GRAVITY: float = 16.0
const TURN_SPEED: float = 12.0
const KILL_Y: float = -20.0

var controls = null
var camera_rig = null

var _visual: Node3D = null


func _ready() -> void:
	floor_snap_length = 0.3
	_build_collision()
	_build_visual()


func setup(p_controls, p_camera_rig) -> void:
	controls = p_controls
	camera_rig = p_camera_rig


func _physics_process(delta: float) -> void:
	if controls == null or camera_rig == null:
		return

	if global_position.y < KILL_Y:
		_respawn()
		return

	var input_vec: Vector2 = controls.get_move_vector()
	var running: bool = controls.is_running()
	var want_jump: bool = controls.consume_jump()
	var yaw: float = camera_rig.yaw

	# 화면 위쪽 = 카메라가 바라보는 방향
	var cam_basis := Basis(Vector3.UP, yaw)
	var wish: Vector3 = cam_basis * Vector3(input_vec.x, 0.0, input_vec.y)

	var speed: float = RUN_SPEED if running else WALK_SPEED
	var target_vel: Vector3 = wish * speed
	velocity.x = move_toward(velocity.x, target_vel.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, ACCEL * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif want_jump:
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	# 이동 방향으로 몸 돌리기
	var flat_speed: float = Vector2(velocity.x, velocity.z).length()
	if flat_speed > 0.3:
		var target_angle: float = atan2(-velocity.x, -velocity.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_angle, clampf(TURN_SPEED * delta, 0.0, 1.0))

	if Cfg.SHOW_DEBUG:
		controls.debug_text = "X %.0f  Z %.0f" % [global_position.x, global_position.z]


func _respawn() -> void:
	global_position = Cfg.PLAYER_SPAWN
	velocity = Vector3.ZERO


func _build_collision() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, 0.9, 0.0)
	add_child(cs)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.22, 0.27, 0.24)
	cloth.roughness = 0.9
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.86, 0.70, 0.58)
	skin.roughness = 0.8
	var pack := StandardMaterial3D.new()
	pack.albedo_color = Color(0.15, 0.15, 0.17)
	pack.roughness = 0.9

	# 몸통
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.2
	body_mesh.radial_segments = 12
	body_mesh.rings = 4
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = cloth
	body.position = Vector3(0.0, 0.8, 0.0)
	_visual.add_child(body)

	# 머리
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	head_mesh.radial_segments = 12
	head_mesh.rings = 6
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.material_override = skin
	head.position = Vector3(0.0, 1.58, 0.0)
	_visual.add_child(head)

	# 앞쪽 표시(코). 몸이 -Z 방향을 바라봅니다.
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.1, 0.1, 0.18)
	var nose := MeshInstance3D.new()
	nose.mesh = nose_mesh
	nose.material_override = skin
	nose.position = Vector3(0.0, 1.56, -0.22)
	_visual.add_child(nose)

	# 등 뒤 가방 (뒤쪽을 구분하기 위함)
	var pack_mesh := BoxMesh.new()
	pack_mesh.size = Vector3(0.36, 0.5, 0.2)
	var pack_node := MeshInstance3D.new()
	pack_node.mesh = pack_mesh
	pack_node.material_override = pack
	pack_node.position = Vector3(0.0, 0.95, 0.3)
	_visual.add_child(pack_node)
