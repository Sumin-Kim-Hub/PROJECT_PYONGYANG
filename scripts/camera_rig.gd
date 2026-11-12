extends Node3D
## 3인칭 카메라 장치. 플레이어를 부드럽게 따라가고, 화면 오른쪽 드래그로 회전합니다.
## 카메라와 플레이어 사이에 벽이 있으면 SpringArm3D가 카메라를 앞으로 당겨 줍니다.

const Cfg = preload("res://scripts/game_config.gd")

const DISTANCE: float = 6.5
const PIVOT_HEIGHT: float = 1.6
const LOOK_SENSITIVITY: float = 0.0045  # 드래그 1픽셀당 회전량(라디안)
const KEY_TURN_SPEED: float = 1.8       # PC 테스트용 방향키 회전 속도
const FOLLOW_SPEED: float = 14.0
const PITCH_MIN: float = -1.25
const PITCH_MAX: float = 0.35

## 카메라가 바라보는 좌우 각도. player.gd 가 이동 방향 계산에 사용합니다.
var yaw: float = 0.0
var pitch: float = -0.35

var target = null
var controls = null

var _arm: SpringArm3D
var _cam: Camera3D


func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.spring_length = DISTANCE
	_arm.margin = 0.3
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	_arm.shape = shape
	add_child(_arm)

	_cam = Camera3D.new()
	_cam.near = 0.3
	_cam.far = Cfg.CAMERA_FAR
	_cam.fov = 70.0
	_arm.add_child(_cam)
	_cam.make_current()


func setup(p_target, p_controls) -> void:
	target = p_target
	controls = p_controls
	_arm.add_excluded_object(p_target.get_rid())
	global_position = p_target.global_position + Vector3(0.0, PIVOT_HEIGHT, 0.0)
	rotation = Vector3(pitch, yaw, 0.0)


func _process(delta: float) -> void:
	if target == null or controls == null:
		return

	var look: Vector2 = controls.consume_look()
	yaw -= look.x * LOOK_SENSITIVITY
	pitch -= look.y * LOOK_SENSITIVITY

	# PC 테스트용: 방향키로 카메라 회전
	if Input.is_physical_key_pressed(KEY_LEFT):
		yaw += KEY_TURN_SPEED * delta
	if Input.is_physical_key_pressed(KEY_RIGHT):
		yaw -= KEY_TURN_SPEED * delta
	if Input.is_physical_key_pressed(KEY_UP):
		pitch += KEY_TURN_SPEED * delta
	if Input.is_physical_key_pressed(KEY_DOWN):
		pitch -= KEY_TURN_SPEED * delta

	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)

	var goal: Vector3 = target.global_position + Vector3(0.0, PIVOT_HEIGHT, 0.0)
	global_position = global_position.lerp(goal, clampf(delta * FOLLOW_SPEED, 0.0, 1.0))
	rotation = Vector3(pitch, yaw, 0.0)
