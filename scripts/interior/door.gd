extends Node3D
## 열고 닫을 수 있는 문. 닫혀 있으면 충돌체가 있어 지나갈 수 없고(경비 시야도 막음),
## 열리면 충돌체가 사라집니다. 잠긴 문은 key_item 이 있으면 열리고, 효과(unlock_door)로도 풀립니다.
## 문의 힌지(경첩)가 이 노드의 원점이고, 닫힌 문은 지역 +X 방향으로 width 만큼 뻗습니다.

const InteractableScript = preload("res://scripts/interaction/interactable.gd")

var door_id: String = ""
var width: float = 1.3
var height: float = 2.3
var locked: bool = false
var key_item: String = ""
var locked_text: String = "잠겨 있다."
var color: Color = Color(0.45, 0.32, 0.2)
var interior: bool = true
var open_angle: float = -100.0

var is_open: bool = false
var hub = null

var _pivot: Node3D = null
var _body: StaticBody3D = null
var _it = null
var _tween: Tween = null


func _ready() -> void:
	add_to_group("doors")
	_pivot = Node3D.new()
	add_child(_pivot)

	_body = StaticBody3D.new()
	_body.position = Vector3(width * 0.5, height * 0.5, 0.0)
	var cs = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(width, height, 0.12)
	cs.shape = shape
	_body.add_child(cs)
	var mesh = BoxMesh.new()
	mesh.size = Vector3(width, height, 0.1)
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if interior:
		mi.layers = 2
	_body.add_child(mi)
	# 손잡이
	var hm = BoxMesh.new()
	hm.size = Vector3(0.1, 0.06, 0.2)
	var handle = MeshInstance3D.new()
	handle.mesh = hm
	var hmat = StandardMaterial3D.new()
	hmat.albedo_color = Color(0.8, 0.7, 0.3)
	handle.material_override = hmat
	handle.position = Vector3(width * 0.5 - 0.15, -0.05, 0.0)
	if interior:
		handle.layers = 2
	_body.add_child(handle)
	_pivot.add_child(_body)

	_it = InteractableScript.new()
	_it.kind = "door"
	_it.radius = 1.9
	_it.position = Vector3(width * 0.5, 1.0, 0.0)
	_it.data = {"door": self}
	add_child(_it)
	_refresh_prompt()


## 허브가 연결될 때(또는 저장된 해금 상태를 읽을 때) 호출
func setup(p_hub) -> void:
	hub = p_hub
	if hub != null and hub.game != null and door_id != "":
		if hub.game.get_flag("unlock_" + door_id):
			locked = false
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _it == null:
		return
	if locked:
		_it.prompt = "잠긴 문"
		_it.button_text = "문 확인"
	elif is_open:
		_it.prompt = "문 닫기"
		_it.button_text = "닫기"
	else:
		_it.prompt = "문 열기"
		_it.button_text = "열기"


func unlock() -> void:
	locked = false
	_refresh_prompt()


## 플레이어가 상호작용 버튼을 눌렀을 때 허브가 부름. 화면에 띄울 메시지를 돌려줌(없으면 "").
func interact() -> String:
	if locked:
		if key_item != "" and hub != null and hub.game != null and hub.game.has_item(key_item):
			locked = false
			if door_id != "":
				hub.game.set_flag("unlock_" + door_id, true)
			set_open(true)
			return "%s(으)로 문을 열었다." % hub.game_item_name(key_item)
		return locked_text
	if is_open:
		if hub != null and hub.player != null:
			var d: Vector3 = hub.player.global_position - _it.global_position
			d.y = 0.0
			if d.length() < 0.9:
				return "문 바로 앞이라 닫을 수 없다."
		set_open(false)
		return ""
	set_open(true)
	return ""


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	_refresh_prompt()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	var target: float = deg_to_rad(open_angle) if is_open else 0.0
	_tween.tween_property(_pivot, "rotation:y", target, 0.35)
	if is_open:
		# 열리는 동안 바로 충돌을 꺼서 문에 끼지 않게 함
		_body.collision_layer = 0
	else:
		_tween.tween_callback(_enable_collision)


func _enable_collision() -> void:
	_body.collision_layer = 1
