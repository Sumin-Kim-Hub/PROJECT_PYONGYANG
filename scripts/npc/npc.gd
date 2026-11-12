extends CharacterBody3D
## 시민 / 경비 NPC (v2).
##  - 외형: data 의 look 값으로 키, 피부, 옷, 머리, 모자, 소품을 바꾼 간단한 입체 캐릭터 + 걷기/앉기 포즈
##  - 일과: routine(시간대별 행동)에 따라 돌아다니기 / 서 있기 / 벤치에 앉기 / 집에 들어가기(사라짐)
##  - 대화: 플레이어가 가까이 가면 대화 버튼 (대화 중에는 멈추고 플레이어를 바라봄)
##  - 잠입: vision_range > 0 이면 시야 안(벽에 가려지지 않은)의 플레이어를 보고 suspicion(의심)이 오름
## 충돌 레이어 2 = NPC. 월드/플레이어(레이어 1)와는 부딪히고 NPC끼리는 서로 통과합니다(길막 방지).

const InteractableScript = preload("res://scripts/interaction/interactable.gd")
const Flags = preload("res://scripts/data/feature_flags.gd")

const GRAVITY: float = 16.0
const TURN_SPEED: float = 8.0
const SIT_DROP: float = 0.35
const FAR_ANIM_DIST: float = 70.0
const VIEW_END: float = 90.0

static var _mat_cache: Dictionary = {}

var hub = null
var npc_id: String = ""
var display_name: String = "시민"
var role: String = ""
var dialogue: Dictionary = {}
var home: Vector3 = Vector3.ZERO
var speed: float = 1.3
var look: Dictionary = {}
var routine: Array = []
## routine 이 없을 때 바라보는 방향(라디안)
var facing_yaw: float = 0.0
## 이 값이 0보다 크면 경비 역할: 시야 거리(m), 시야각(도)
var vision_range: float = 0.0
var vision_fov: float = 100.0
## true 면 대화 불가 (순찰 경비)
var no_talk: bool = false
## 순찰 경로(월드 좌표). 있으면 routine 이 없어도 순찰함
var patrol_path: Array = []

var talking: bool = false
var suspicion: float = 0.0

var _visual: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
## 사실적 인체 모델 사용 시 관절 애니메이터 (null 이면 예전 상자 모델)
var _gfx_anim = null
var _interactable = null

## --- V1: 도시 반응 / 차량 ---
## "" 평소 / "flee" 도망 / "cower" 웅크림 / "chase" 추적(경찰) / "investigate" 확인하러 감(경비)
var react: String = ""
var react_t: float = 0.0
var react_from: Vector3 = Vector3.ZERO
var react_target = null
var riding = null
var is_police: bool = false

var _cur_speed: float = 1.3
var _shove: Vector3 = Vector3.ZERO
var _fear_hide: float = 0.0
## V2: 맞거나 밀렸을 때 비틀거리는 동작 시간
var _hit_t: float = 0.0
var _last_door: Vector3 = Vector3.ZERO
var _chatting: bool = false

var _entry: Dictionary = {}
var _entry_idx: int = -2
var _mode: String = "static"
var _hidden: bool = false
var _sitting: bool = false
var _anchor = null
var _arrived: bool = false
var _walking: bool = false
var _rest: float = 1.0
var _goal: Vector3 = Vector3.ZERO
var _patrol_i: int = 0
var _pause: float = 0.0
var _check_timer: float = 0.0
var _check_pos: Vector3 = Vector3.ZERO
var _stuck_count: int = 0
var _face_point: Vector3 = Vector3.ZERO
var _anchor_retry: float = 0.0
var _sched_timer: float = 0.0
var _phase: float = 0.0
var _rng = RandomNumberGenerator.new()


func configure(d: Dictionary, p_hub) -> void:
	hub = p_hub
	npc_id = str(d.get("id", ""))
	display_name = str(d.get("name", "시민"))
	role = str(d.get("role", ""))
	dialogue = d.get("dialogue", {})
	home = d.get("home", Vector3.ZERO)
	speed = float(d.get("speed", 1.3))
	look = d.get("look", {})
	routine = d.get("routine", [])
	facing_yaw = deg_to_rad(float(d.get("yaw_deg", 0.0)))
	vision_range = float(d.get("vision_range", 0.0))
	vision_fov = float(d.get("vision_fov", 100.0))
	no_talk = bool(d.get("no_talk", false))
	patrol_path = d.get("patrol_path", [])


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	_rng.randomize()
	_build_collision()
	_build_visual()

	if not no_talk:
		var it = InteractableScript.new()
		it.kind = "talk"
		it.prompt = "%s에게 말 걸기" % display_name
		it.radius = 2.4
		it.data = {"npc": self}
		add_child(it)
		_interactable = it

	add_to_group("npcs")
	is_police = role.find("경찰") >= 0 or role.find("군인") >= 0 or role.find("장교") >= 0
	if is_police:
		add_to_group("police")
	_cur_speed = speed

	if vision_range > 0.0:
		add_to_group("guards")

	_check_pos = global_position
	_rest = _rng.randf_range(0.3, 2.5)
	_visual.rotation.y = facing_yaw
	_update_schedule()


# ---------------------------------------------------------------- 바깥에서 부르는 함수

func begin_talk(face_point: Vector3) -> void:
	talking = true
	_face_point = face_point
	_walking = false


func end_talk() -> void:
	talking = false
	_rest = 1.5


## 발각된 뒤 경비를 처음 순찰 위치로 되돌림
func reset_guard() -> void:
	suspicion = 0.0
	if react != "":
		calm_down()
	_patrol_i = 0
	_pause = 1.0
	if patrol_path.size() > 0:
		global_position = patrol_path[0]
		velocity = Vector3.ZERO


# ---------------------------------------------------------------- 매 프레임

func _physics_process(delta: float) -> void:
	_sched_timer -= delta
	if _sched_timer <= 0.0:
		_sched_timer = 0.5
		_update_schedule()
		_refresh_talk_enabled()

	if _hidden:
		if _fear_hide > 0.0:
			_fear_hide -= delta
			if _fear_hide <= 0.0 and riding == null:
				_appear_at(_last_door if _last_door != Vector3.ZERO else home)
		return

	_cur_speed = speed
	if _hit_t > 0.0:
		_hit_t -= delta
	var move_dir = Vector3.ZERO
	var reacting: bool = react != "" and react_t > 0.0
	if reacting:
		react_t -= delta
		move_dir = _react_move(delta)
		if react_t <= 0.0:
			_end_react()
	elif talking:
		_face(_face_point - global_position, delta)
	elif _sitting:
		pass
	else:
		move_dir = _run_mode(delta)

	if _sitting:
		velocity = Vector3.ZERO
	else:
		var target_vel: Vector3 = move_dir * _cur_speed
		velocity.x = move_toward(velocity.x, target_vel.x, 6.0 * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, 6.0 * delta)
		if _shove.length() > 0.1:
			velocity.x = _shove.x
			velocity.z = _shove.z
			_shove = _shove.move_toward(Vector3.ZERO, 14.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		if Vector2(velocity.x, velocity.z).length() > 0.2 and not talking:
			_face(Vector3(velocity.x, 0.0, velocity.z), delta)

	_animate(delta)

	if vision_range > 0.0 and not talking:
		_check_vision(delta)


# ---------------------------------------------------------------- V1: 반응 (도망 / 추적 / 확인 / 밀침)

## 놀라서 from_pos 에서 멀어짐. panic=false 면 그 자리에서 웅크림. 경비/경찰은 놀라지 않고 확인하러 감
func scare(from_pos: Vector3, seconds: float = 8.0, panic: bool = true) -> void:
	if _hidden or riding != null:
		return
	if vision_range > 0.0 or is_police:
		investigate(from_pos, seconds)
		return
	if talking:
		return
	if _sitting:
		_stand_up()
	react = "flee" if panic else "cower"
	react_t = maxf(react_t, seconds)
	react_from = from_pos
	_walking = false
	_refresh_talk_enabled()


## 경비/경찰이 지점으로 가서 확인
func investigate(pos: Vector3, seconds: float = 12.0) -> void:
	if _hidden or riding != null or talking:
		return
	if react == "chase" and react_t > 0.0:
		return
	if _sitting:
		_stand_up()
	react = "investigate"
	react_t = maxf(react_t, seconds)
	react_from = pos
	_walking = false


## 대상(플레이어)을 추적
func chase(target, seconds: float = 25.0) -> void:
	if _hidden or riding != null:
		return
	if _sitting:
		_stand_up()
	react = "chase"
	react_t = maxf(react_t, seconds)
	react_target = target
	_walking = false
	# 추격 중에는 경비처럼 잡을 수 있게 guards 그룹에 들어감 (허브가 suspicion 을 보고 체포 처리)
	if not is_in_group("guards"):
		add_to_group("guards")


func calm_down() -> void:
	react = ""
	react_t = 0.0
	react_target = null
	_end_react()


## 밀려남 (충돌/위협)
func shove(impulse: Vector3) -> void:
	if _hidden or _sitting:
		return
	_shove = Vector3(impulse.x, 0.0, impulse.z)
	_hit_t = 0.7


func _end_react() -> void:
	if is_police and vision_range <= 0.0 and is_in_group("guards"):
		remove_from_group("guards")
		suspicion = 0.0
	react = ""
	react_t = 0.0
	react_target = null
	_walking = false
	_rest = 1.0
	if _visual != null:
		_visual.position.y = 0.0
	_refresh_talk_enabled()


func _refresh_talk_enabled() -> void:
	if _interactable != null:
		_interactable.enabled = not (_hidden or riding != null or (react != "" and react_t > 0.0))


func _react_move(delta: float) -> Vector3:
	match react:
		"flee":
			_cur_speed = clampf(speed * 2.4, 2.6, 4.2)
			var away: Vector3 = global_position - react_from
			away.y = 0.0
			if away.length() < 0.2:
				away = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
			var goal: Vector3 = global_position + away.normalized() * 12.0
			# 집이 가까우면 집으로 달려가 숨음
			var dh: Vector3 = home - global_position
			dh.y = 0.0
			if dh.length() < 45.0 and react_t < 18.0:
				goal = home
				if dh.length() < 1.6:
					_fear_hide = 30.0
					_last_door = global_position
					_hide_now()
					_end_react()
					return Vector3.ZERO
			var d: Vector3 = goal - global_position
			d.y = 0.0
			return d.normalized()
		"cower":
			_visual.position.y = move_toward(_visual.position.y, -0.35, 2.0 * delta)
			return Vector3.ZERO
		"chase":
			_cur_speed = 3.6
			if react_target == null or not is_instance_valid(react_target):
				return Vector3.ZERO
			var to: Vector3 = react_target.global_position - global_position
			to.y = 0.0
			if to.length() < 1.9:
				suspicion = minf(1.2, suspicion + 1.2 * delta)
				_face(to, delta)
				return Vector3.ZERO
			return to.normalized()
		"investigate":
			_cur_speed = 2.6
			var t2: Vector3 = react_from - global_position
			t2.y = 0.0
			if t2.length() < 2.5:
				_face(t2, delta)
				return Vector3.ZERO
			return t2.normalized()
	return Vector3.ZERO


# ---------------------------------------------------------------- V1: 차량 탑승(버스 등)

func can_board() -> bool:
	return not _hidden and riding == null and not talking and react == "" and vision_range <= 0.0 \
		and not no_talk and (_mode == "wander" or _mode == "wait") and not _sitting


func board_vehicle(v) -> void:
	riding = v
	_hidden = true
	visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	_refresh_talk_enabled()


func alight_at(pos: Vector3) -> void:
	riding = null
	_appear_at(pos)
	_entry_idx = -2


func _appear_at(pos: Vector3) -> void:
	_hidden = false
	visible = true
	collision_layer = 2
	global_position = pos + Vector3(0.0, 0.05, 0.0)
	velocity = Vector3.ZERO
	_refresh_talk_enabled()


## 저장용 상태 (이름 있는 NPC 위치 등)
func state_dict() -> Dictionary:
	return {"id": npc_id, "x": global_position.x, "z": global_position.z, "hidden": _hidden}


func apply_state(d: Dictionary) -> void:
	if _hidden or riding != null:
		return
	var x = d.get("x")
	var z = d.get("z")
	if (x is float or x is int) and (z is float or z is int):
		if absf(float(x)) < 400.0 and absf(float(z)) < 400.0 and global_position.y < 100.0:
			global_position = Vector3(float(x), global_position.y, float(z))


# ---------------------------------------------------------------- 일과

func _update_schedule() -> void:
	var h: float = 12.0
	if hub != null and hub.clock != null:
		h = hub.clock.hour_float()
	var idx: int = -1
	if routine.size() > 0:
		idx = _pick_entry(h)
	elif patrol_path.size() > 0:
		idx = -3
	if idx == _entry_idx:
		return
	_enter_entry(idx)


func _pick_entry(h: float) -> int:
	for i in range(routine.size()):
		var e: Dictionary = routine[i]
		var a: float = float(e.get("from", 0.0))
		var b: float = float(e.get("to", 24.0))
		var inside: bool = false
		if a <= b:
			inside = h >= a and h < b
		else:
			inside = h >= a or h < b
		if inside:
			return i
	return 0


func _enter_entry(idx: int) -> void:
	_entry_idx = idx
	_chatting = false
	if _sitting:
		_stand_up()
	var m: String = "static"
	if idx >= 0:
		_entry = routine[idx]
		m = str(_entry.get("mode", "wander"))
	elif idx == -3:
		_entry = {"mode": "patrol", "path": patrol_path, "pause": 1.5}
		m = "patrol"
	else:
		_entry = {}
	if _hidden and m != "home" and riding == null:
		_appear()
	_mode = m
	_walking = false
	_arrived = false
	_stuck_count = 0
	_patrol_i = 0
	_rest = _rng.randf_range(0.2, 1.5)
	_anchor = null
	if m == "sit":
		_anchor = _find_anchor(_entry.get("pos", global_position))


func _run_mode(delta: float) -> Vector3:
	match _mode:
		"wander":
			return _wander(delta, _entry.get("pos", home), float(_entry.get("radius", 8.0)))
		"stand":
			var p: Vector3 = _entry.get("pos", home)
			if global_position.distance_to(p) > 1.2 and not _arrived:
				return _walk_to(p, delta, 0.8)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, facing_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
			return Vector3.ZERO
		"sit":
			if _anchor == null:
				# 벤치가 아직 없거나 이미 차 있으면 가끔 다시 찾아보며 그동안 근처를 돌아다님
				_anchor_retry -= delta
				if _anchor_retry <= 0.0:
					_anchor_retry = 3.0
					_anchor = _find_anchor(_entry.get("pos", global_position))
				if _anchor == null:
					return _wander(delta, _entry.get("pos", home), 6.0)
			var ap: Vector3 = _anchor.data["pos"]
			var dir: Vector3 = _walk_to(ap, delta, 1.0)
			if _arrived:
				_sit_down()
			return dir
		"home":
			var hp: Vector3 = _entry.get("pos", home)
			var dir2: Vector3 = _walk_to(hp, delta, 1.0)
			if _arrived:
				_hide_now()
			return dir2
		"patrol":
			return _patrol(delta)
		"wait", "phone":
			# V2: 버스 기다리기 / 전화하기 (제자리에 서서 동작만 다름)
			var wp0: Vector3 = _entry.get("pos", home)
			if global_position.distance_to(wp0) > 1.2 and not _arrived:
				return _walk_to(wp0, delta, 0.8)
			var fp0: Vector3 = _entry.get("face", Vector3(wp0.x, 0.0, 0.0))
			_face(fp0 - global_position, delta)
			return Vector3.ZERO
		"chat":
			var cp: Vector3 = _entry.get("pos", home)
			if global_position.distance_to(cp) > 1.2 and not _arrived:
				return _walk_to(cp, delta, 0.8)
			var fp: Vector3 = _entry.get("face", cp + Vector3(0.0, 0.0, -1.0))
			_chatting = true
			_face(fp - global_position, delta)
			return Vector3.ZERO
	# static
	_visual.rotation.y = lerp_angle(_visual.rotation.y, facing_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
	return Vector3.ZERO


func _wander(delta: float, center: Vector3, radius: float) -> Vector3:
	if radius < 0.5:
		var d0: Vector3 = _walk_to(center, delta, 0.8)
		return d0
	if not _walking:
		_rest -= delta
		if _rest <= 0.0:
			var ang: float = _rng.randf_range(0.0, TAU)
			var dist: float = sqrt(_rng.randf()) * radius
			_goal = center + Vector3(cos(ang), 0.0, sin(ang)) * dist
			_walking = true
			_stuck_count = 0
			_check_pos = global_position
			_check_timer = 0.0
		return Vector3.ZERO
	var d: Vector3 = _walk_to(_goal, delta, 0.7)
	if _arrived:
		_walking = false
		_rest = _rng.randf_range(2.0, 7.0)
	return d


func _patrol(delta: float) -> Vector3:
	var path: Array = _entry.get("path", [])
	if path.is_empty():
		return Vector3.ZERO
	if _pause > 0.0:
		_pause -= delta
		return Vector3.ZERO
	var wp: Vector3 = path[_patrol_i % path.size()]
	var d: Vector3 = _walk_to(wp, delta, 0.6)
	if _arrived:
		_patrol_i = (_patrol_i + 1) % path.size()
		_pause = float(_entry.get("pause", 1.5))
		_arrived = false
	return d


## target 쪽으로 가야 할 방향(길이 1)을 돌려주고, 도착하면 _arrived 를 true 로 함.
## 벽에 막혀 오래 못 움직이면 포기하고 도착한 것으로 처리함.
func _walk_to(target: Vector3, delta: float, stop: float) -> Vector3:
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() <= stop:
		_arrived = true
		return Vector3.ZERO
	_arrived = false
	_check_timer += delta
	if _check_timer >= 0.8:
		if global_position.distance_to(_check_pos) < 0.25:
			_stuck_count += 1
		else:
			_stuck_count = 0
		_check_pos = global_position
		_check_timer = 0.0
		if _stuck_count >= 4:
			_stuck_count = 0
			_arrived = true
			return Vector3.ZERO
	return to.normalized()


func _find_anchor(pos: Vector3):
	var best = null
	var best_d: float = 30.0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.kind != "sit" or not bool(n.data.get("outdoor", false)):
			continue
		if n.data.get("occupied_by") != null:
			continue
		var d: float = Vector2(n.global_position.x - pos.x, n.global_position.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = n
	return best


func _sit_down() -> void:
	if _anchor == null or _sitting:
		return
	# 가는 사이에 다른 NPC나 플레이어가 먼저 앉았으면 다른 자리를 찾음
	var occ = _anchor.data.get("occupied_by")
	if occ != null and occ != self:
		_anchor = null
		_anchor_retry = 0.0
		_arrived = false
		return
	_sitting = true
	_anchor.data["occupied_by"] = self
	global_position = _anchor.data["pos"]
	_visual.rotation.y = float(_anchor.data.get("yaw", 0.0))
	_visual.position.y = -SIT_DROP
	velocity = Vector3.ZERO


func _stand_up() -> void:
	_sitting = false
	_visual.position.y = 0.0
	if _anchor != null:
		_anchor.data["occupied_by"] = null
		global_position = _anchor.data.get("stand_pos", global_position)
	_anchor = null


func _hide_now() -> void:
	_last_door = global_position
	_hidden = true
	visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	if _interactable != null:
		_interactable.enabled = false


func _appear() -> void:
	_hidden = false
	visible = true
	collision_layer = 2
	global_position = home + Vector3(0.0, 0.05, 0.0)
	velocity = Vector3.ZERO
	if _interactable != null:
		_interactable.enabled = true


# ---------------------------------------------------------------- 시야 (잠입)

func _check_vision(delta: float) -> void:
	if hub == null or hub.player == null:
		return
	var player = hub.player
	var eye: Vector3 = global_position + Vector3(0.0, 1.5, 0.0)
	var target: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	var to: Vector3 = target - eye
	var dist: float = to.length()
	var seen: bool = false
	if dist <= vision_range:
		var flat: Vector3 = Vector3(to.x, 0.0, to.z)
		if flat.length() > 0.1:
			var fwd: Vector3 = Basis(Vector3.UP, _visual.rotation.y) * Vector3(0.0, 0.0, -1.0)
			var ang: float = rad_to_deg(fwd.angle_to(flat.normalized()))
			if ang <= vision_fov * 0.5:
				var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
				var q = PhysicsRayQueryParameters3D.create(eye, target, 1)
				var hit: Dictionary = space.intersect_ray(q)
				seen = hit.is_empty() or hit.get("collider") == player
	if seen:
		var rate: float = 0.9 * (1.0 - 0.5 * dist / vision_range)
		if hub.controls != null and hub.controls.is_running():
			rate *= 1.7
		if dist < 2.5:
			rate *= 2.0
		suspicion = minf(1.2, suspicion + rate * delta)
	else:
		suspicion = maxf(0.0, suspicion - 0.5 * delta)


# ---------------------------------------------------------------- 몸 방향, 애니메이션

func _face(dir: Vector3, delta: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.05:
		return
	var a: float = atan2(-dir.x, -dir.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, a, clampf(TURN_SPEED * delta, 0.0, 1.0))


## V2: 지금 상황에 맞는 몸짓 이름 (character_animator.gd 의 pose)
func _pose_name() -> String:
	if react == "cower" and react_t > 0.0:
		return "cower"
	if _hit_t > 0.0:
		return "hit"
	if react == "flee" and react_t > 0.0:
		return "panic"
	if react == "investigate" and react_t > 0.0:
		return "look"
	if _mode == "phone" and not _sitting and not talking:
		return "phone"
	if _mode == "wait" and not talking:
		return "look"
	return ""


func _animate(delta: float) -> void:
	if hub != null and hub.player != null:
		if global_position.distance_to(hub.player.global_position) > FAR_ANIM_DIST:
			return
	if _gfx_anim != null:
		var gsp: float = Vector2(velocity.x, velocity.z).length()
		if talking:
			gsp = 0.0
		_gfx_anim.set("pose", _pose_name())
		_gfx_anim.update(delta, gsp, true, 0.0, _sitting, talking or _chatting, _visual.position.y)
		return
	if _sitting:
		_leg_l.rotation.x = 1.45
		_leg_r.rotation.x = 1.45
		_arm_l.rotation.x = 0.4
		_arm_r.rotation.x = 0.4
		return
	var sp: float = Vector2(velocity.x, velocity.z).length()
	if sp > 0.2 and not talking:
		_phase += delta * (5.0 + sp * 2.0)
		var amp: float = clampf(sp / 1.6, 0.35, 1.0) * 0.65
		_leg_l.rotation.x = sin(_phase) * amp
		_leg_r.rotation.x = -sin(_phase) * amp
		_arm_l.rotation.x = -sin(_phase) * amp * 0.8
		_arm_r.rotation.x = sin(_phase) * amp * 0.8
		_visual.position.y = absf(sin(_phase)) * 0.03
	else:
		var s: float = 4.0 * delta
		_leg_l.rotation.x = move_toward(_leg_l.rotation.x, 0.0, s)
		_leg_r.rotation.x = move_toward(_leg_r.rotation.x, 0.0, s)
		_arm_l.rotation.x = move_toward(_arm_l.rotation.x, 0.0, s)
		_arm_r.rotation.x = move_toward(_arm_r.rotation.x, 0.0, s)
		_visual.position.y = move_toward(_visual.position.y, 0.0, 0.3 * delta)


# ---------------------------------------------------------------- 모양 만들기

static func _mat(color: Color) -> StandardMaterial3D:
	var key: String = str(color)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	_mat_cache[key] = m
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VIEW_END
	parent.add_child(mi)
	return mi


func _limb(pivot_pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot = Node3D.new()
	pivot.position = pivot_pos
	_visual.add_child(pivot)
	_box(pivot, Vector3(0.0, -size.y * 0.5, 0.0), size, color)
	return pivot


## 절차적 인체 모델을 만들어 _visual 에 붙인다. 성공하면 true
func _build_gfx_body() -> bool:
	if not Flags.ENABLE_GFX or not Flags.GFX_CHARACTERS or not Flags.gfx_enabled():
		return false
	var cb = load("res://scripts/gfx/character_builder.gd")
	var an = load("res://scripts/gfx/character_animator.gd")
	if cb == null or an == null or not cb.can_instantiate() or not an.can_instantiate():
		return false
	var spec = cb.spec_from_npc(look, npc_id, role, vision_range > 0.0)
	# 교체용 GLB 모델이 있으면 그것을 우선 사용 (res://assets/characters/<id>.glb 또는 <옷차림>.glb)
	var cf = load("res://scripts/gfx/character_factory.gd")
	if cf != null and cf.can_instantiate():
		var glb = cf.try_glb(npc_id, str(spec.get("outfit", "")))
		if glb != null and glb is Dictionary:
			_visual.add_child(glb["root"])
			_gfx_anim = glb["anim"]
			return true
	var detail_end: float = 38.0 if Flags.gfx_quality() >= 1 else 26.0
	var built = cb.build(spec, detail_end, VIEW_END, false)
	if built == null or not (built is Dictionary) or not built.has("root"):
		return false
	_visual.add_child(built["root"])
	var a = an.new()
	a.setup(built, _rng.randf() * 20.0)
	if str(spec.get("outfit", "")) == "elder":
		a.stoop = 0.10
	_gfx_anim = a
	return true


func _build_collision() -> void:
	var shape = CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.75
	var cs = CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, 0.875, 0.0)
	add_child(cs)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	var h: float = float(look.get("height", 1.0))
	_visual.scale = Vector3(h, h, h)
	add_child(_visual)

	# 그래픽 개선: 사실적 인체 모델. 실패하면 아래의 예전 상자 모델을 그대로 씀
	if _build_gfx_body():
		return

	var skin: Color = look.get("skin", Color(0.86, 0.70, 0.58))
	var shirt: Color = look.get("shirt", Color(0.3, 0.3, 0.35))
	var pants: Color = look.get("pants", Color(0.18, 0.18, 0.22))
	var hair: Color = look.get("hair", Color(0.08, 0.07, 0.07))
	var hat_color: Color = look.get("hat_color", Color(0.9, 0.9, 0.9))
	var has_hat: bool = bool(look.get("hat", false))
	var acc: String = str(look.get("acc", ""))

	_leg_l = _limb(Vector3(-0.12, 0.8, 0.0), Vector3(0.16, 0.8, 0.18), pants)
	_leg_r = _limb(Vector3(0.12, 0.8, 0.0), Vector3(0.16, 0.8, 0.18), pants)
	_box(_visual, Vector3(0.0, 1.1, 0.0), Vector3(0.46, 0.6, 0.26), shirt)
	_arm_l = _limb(Vector3(-0.3, 1.38, 0.0), Vector3(0.12, 0.55, 0.14), shirt)
	_arm_r = _limb(Vector3(0.3, 1.38, 0.0), Vector3(0.12, 0.55, 0.14), shirt)

	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	head_mesh.radial_segments = 10
	head_mesh.rings = 5
	var head = MeshInstance3D.new()
	head.mesh = head_mesh
	head.material_override = _mat(skin)
	head.position = Vector3(0.0, 1.62, 0.0)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.visibility_range_end = VIEW_END
	_visual.add_child(head)

	if has_hat:
		var hat_mesh = CylinderMesh.new()
		hat_mesh.top_radius = 0.2
		hat_mesh.bottom_radius = 0.22
		hat_mesh.height = 0.1
		hat_mesh.radial_segments = 10
		hat_mesh.rings = 1
		var hat = MeshInstance3D.new()
		hat.mesh = hat_mesh
		hat.material_override = _mat(hat_color)
		hat.position = Vector3(0.0, 1.78, 0.0)
		hat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hat.visibility_range_end = VIEW_END
		_visual.add_child(hat)
	else:
		_box(_visual, Vector3(0.0, 1.76, 0.02), Vector3(0.32, 0.12, 0.32), hair)

	if acc == "scarf":
		_box(_visual, Vector3(0.0, 1.43, 0.0), Vector3(0.42, 0.1, 0.3), shirt.lightened(0.35))
	elif acc == "bag":
		_box(_visual, Vector3(0.0, 1.05, 0.2), Vector3(0.3, 0.4, 0.12), pants.darkened(0.2))
	elif acc == "glasses":
		_box(_visual, Vector3(0.0, 1.64, -0.17), Vector3(0.26, 0.05, 0.04), Color(0.05, 0.05, 0.05))
