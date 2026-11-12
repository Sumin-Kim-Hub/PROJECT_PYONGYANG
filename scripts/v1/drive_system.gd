extends Node
## 차량 시스템 총괄.
##  - 탑승/운전 가능한 차량(승용차, 택시, 버스, 트럭, 군용 차량)을 도시에 세워 둠
##  - 탑승 버튼 → 암전 전환 → 카메라가 차를 따라감 → 내리기
##  - 조작: 왼쪽 조이스틱 위=가속, 아래=브레이크/후진, 좌우=핸들. JUMP 버튼=핸드브레이크. 시점 버튼=추적/운전석 시점
##  - 달리는 중 시민과 부딪히면 도시 경계 시스템(alert_system.gd)에 알림
##  - 택시 빠른 이동(fast_travel), 버스 정류장 승객 태우기/내리기
## 기존 player.gd / camera_rig.gd 는 수정하지 않고, rig.target 값만 차량으로 바꿔 줍니다.

const Drivable = preload("res://scripts/v1/drivable.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const Settings = preload("res://scripts/v1/game_settings.gd")

const MODE_FREE: int = 0
const MODE_TRANSITION: int = 3
const MODE_DRIVING: int = 5

var hub = null
var v1 = null
var vehicles: Array = []
var current = null
var cam_mode: int = 0
var driven_m: float = 0.0

var _spring_saved: float = 6.5
var _hit_timer: float = 0.0
var _hit_cool: Dictionary = {}
var _last_pos: Vector3 = Vector3.ZERO
var _busy: bool = false
## V3.0.1 하차 수리: 중복 입력 방지, 막힘 감시, 디버그 기록
var _last_exit_ms: int = 0
var _no_enter_until_ms: int = 0
var _busy_since_ms: int = 0
var _free_with_car_t: float = 0.0
var last_exit_report: String = ""


func build(world: Node3D, hub_ref, v1_ref) -> void:
	hub = hub_ref
	v1 = v1_ref
	await get_tree().physics_frame
	var plan: Array = [
		# 종류, 위치, 방향(도), 색, 이름표
		["car", Vector3(-4.2, 0.1, 54.0), 0.0, Color(0.22, 0.34, 0.52), "v_car1"],
		["taxi", Vector3(24.0, 0.1, 18.0), 90.0, Color(0.95, 0.78, 0.15), "v_taxi1"],
		["car", Vector3(4.2, 0.1, 100.0), 0.0, Color(0.55, 0.18, 0.18), "v_car2"],
		["truck", Vector3(-5.0, 0.1, 132.0), 0.0, Color(0.30, 0.42, 0.34), "v_truck1"],
		["military", Vector3(-92.0, 0.1, -10.6), -90.0, Color(0.30, 0.34, 0.20), "v_mil1"],
		["bus", Vector3(60.0, 0.1, -10.8), -90.0, Color(0.72, 0.30, 0.22), "v_bus1"],
		["taxi", Vector3(-60.0, 0.1, 10.6), 90.0, Color(0.95, 0.78, 0.15), "v_taxi2"],
		["police", Vector3(4.2, 0.1, 160.0), 180.0, Color(0.93, 0.94, 0.96), "v_police1"],
		["police", Vector3(40.0, 0.1, -10.6), 90.0, Color(0.93, 0.94, 0.96), "v_police2"],
	]
	var n: int = 0
	for e in plan:
		var kind: String = str(e[0])
		var car = Drivable.new()
		car.hub = hub
		car.setup_kind(kind)
		car.vid = str(e[4])
		car.body_color = e[3]
		car.name = "Drive_" + car.vid
		var p: Vector3 = e[1]
		# 건물/장식과 겹치지 않는 가까운 빈 자리
		var spot: Vector3 = Placement.find_free_box(world.get_world_3d(), p, Vector3(car.width + 1.0, 2.0, car.length + 1.0))
		car.position = Vector3(spot.x, 0.1, spot.z)
		car.rotation.y = deg_to_rad(float(e[2]))
		car.crashed.connect(_on_crashed)
		world.add_child(car)
		vehicles.append(car)
		n += 1
		if n % 3 == 0:
			await get_tree().physics_frame
	print("[PYONGYANG] 탑승 가능한 차량 %d대를 세웠습니다." % vehicles.size())


## V2: 추가 차량 한 대를 세움 (주차장 등). 빈 자리 검사로 건물과 겹치지 않게 위치를 조금 옮김
func spawn_one(world: Node3D, kind: String, pos: Vector3, yaw_deg: float, color: Color, vid: String):
	var car = Drivable.new()
	car.hub = hub
	car.setup_kind(kind)
	car.vid = vid
	car.body_color = color
	car.name = "Drive_" + vid
	var spot: Vector3 = Placement.find_free_box(world.get_world_3d(), pos, Vector3(car.width + 1.0, 2.0, car.length + 1.0))
	car.position = Vector3(spot.x, 0.1, spot.z)
	car.rotation.y = deg_to_rad(yaw_deg)
	car.crashed.connect(_on_crashed)
	world.add_child(car)
	vehicles.append(car)
	return car


# ---------------------------------------------------------------- 탑승 / 내리기

func enter(car) -> void:
	if car == null or _busy or current != null:
		return
	if hub == null or hub.mode != MODE_FREE:
		return
	# 방금 내린 직후의 연속 터치가 같은 자리의 '탑승' 버튼을 다시 누르는 것을 막음
	if Time.get_ticks_msec() < _no_enter_until_ms:
		print("[PYONGYANG][하차] 하차 직후라 탑승 입력을 무시했습니다.")
		return
	_set_busy(true)
	hub.mode = MODE_TRANSITION
	hub.player.velocity = Vector3.ZERO
	hub.player.set_physics_process(false)
	hub.ui.clear_prompt()
	await hub.ui.fade_to(1.0, 0.18)
	current = car
	car.set_occupied(true)
	_player_hidden(true)
	var rig = hub.rig
	rig.target = car
	var arm = rig.get("_arm")
	if arm != null and arm is SpringArm3D:
		_spring_saved = arm.spring_length
		arm.add_excluded_object(car.get_rid())
		arm.spring_length = _chase_len(car)
	cam_mode = 0
	if "yaw" in rig:
		rig.yaw = car.rotation.y
	if "pitch" in rig:
		rig.pitch = -0.22
	hub.player.global_position = car.global_position
	_last_pos = car.global_position
	_update_headlights()
	await hub.ui.fade_to(0.0, 0.18)
	hub.mode = MODE_DRIVING
	_set_busy(false)
	hub.toast("%s 탑승 · 조이스틱 위/아래=가속/브레이크, 좌우=핸들, JUMP=핸드브레이크" % car.display_name)
	if v1 != null:
		v1.on_vehicle_entered(car)


## 화면 '내리기' 버튼(터치)과 E 키가 함께 부르는 입구. 입력 수신부터 결과까지 로그를 남긴다.
func request_exit(source: String) -> bool:
	var now: int = Time.get_ticks_msec()
	var mode_now: int = -1
	if hub != null:
		mode_now = int(hub.mode)
	print("[PYONGYANG][하차] 입력 수신 (%s) · mode=%d · 탑승중=%s · busy=%s" % [source, mode_now, str(current != null), str(_busy)])
	if hub == null:
		return false
	if now - _last_exit_ms < 350:
		print("[PYONGYANG][하차] 거부: 연속 입력 (350ms 안)")
		return false
	_last_exit_ms = now
	# 화면은 DRIVING 인데 차량 정보가 없는 불일치 → 자유 상태로 복구
	if current != null and not is_instance_valid(current):
		current = null
	if current == null:
		if hub.mode == MODE_DRIVING and not _busy:
			print("[PYONGYANG][하차] 불일치 발견: 운전 모드인데 탑승 차량이 없음 → 자유 상태로 복구")
			_recover_free_state()
			return true
		print("[PYONGYANG][하차] 거부: 탑승 중인 차량이 없음")
		return false
	if _busy:
		print("[PYONGYANG][하차] 거부: 다른 전환이 진행 중 (busy)")
		return false
	if hub.mode != MODE_DRIVING:
		print("[PYONGYANG][하차] 경고: 탑승 중인데 mode=%d (DRIVING 아님) → 그래도 하차 진행" % hub.mode)
	# exit_vehicle 은 중간에 기다림(await)이 있어서 결과 값을 받지 않고 시작만 시킨다 (결과는 로그로 확인)
	exit_vehicle(false)
	return true


func exit_vehicle(force: bool = false) -> void:
	if current == null:
		print("[PYONGYANG][하차] 거부: current 가 null")
		return
	if _busy:
		print("[PYONGYANG][하차] 거부: busy")
		return
	var car = current
	print("[PYONGYANG][하차] 함수 호출 · force=%s · 차량=%s · 속도=%.2f · 차량 위치=%s · 플레이어 위치=%s" % [str(force), str(car.vid), car.speed, str(car.global_position), str(hub.player.global_position)])
	if not force and absf(car.speed) > 5.0:
		print("[PYONGYANG][하차] 거부: 속도 %.1f > 5.0" % car.speed)
		hub.toast("차를 세운 뒤에 내릴 수 있어요. (조이스틱 아래 또는 JUMP 로 멈춤)")
		return
	_set_busy(true)
	hub.mode = MODE_TRANSITION
	if not force:
		await hub.ui.fade_to(1.0, 0.18)
	# 어두운 화면 동안 차가 완전히 서도록 하고, 하차 자리를 계산
	car.throttle_input = 0.0
	car.steer_input = 0.0
	if absf(car.speed) <= 5.0:
		car.speed = 0.0
	var spot: Vector3 = _exit_spot(car)
	print("[PYONGYANG][하차] 계산된 하차 위치=%s" % str(spot))
	car.set_occupied(false)
	car.set_body_visible(true)
	current = null
	_player_hidden(false)
	hub._teleport(spot, car.rotation.y)
	var rig = hub.rig
	rig.target = hub.player
	var arm = rig.get("_arm")
	if arm != null and arm is SpringArm3D:
		arm.spring_length = _spring_saved
		arm.remove_excluded_object(car.get_rid())
	if "pitch" in rig:
		rig.pitch = -0.35
	# 일반 하차만: 플레이어 충돌체가 (deferred 로) 켜진 뒤에 물리를 다시 켜서 바닥을 뚫지 않게 함.
	# 강제 하차(체포/불러오기)는 호출한 쪽이 곧바로 이어서 처리하므로 예전처럼 기다리지 않고 즉시 끝낸다.
	if not force:
		await get_tree().physics_frame
		await get_tree().physics_frame
		await hub.ui.fade_to(0.0, 0.18)
	hub.player.velocity = Vector3.ZERO
	hub.player.set_physics_process(true)
	hub.mode = MODE_FREE
	_set_busy(false)
	_no_enter_until_ms = Time.get_ticks_msec() + 700
	last_exit_report = "하차 성공 · 위치 %s · 탑승상태 %s" % [str(hub.player.global_position), str(current != null)]
	print("[PYONGYANG][하차] 성공 · 하차 후 플레이어 위치=%s · 차량 위치=%s · 탑승 상태(current!=null)=%s · mode=%d · 물리=%s" % [
		str(hub.player.global_position), str(car.global_position), str(current != null), hub.mode, str(hub.player.is_physics_processing())])
	if v1 != null:
		v1.on_vehicle_exited(car)


## 기절/체포 등으로 강제로 내림 (암전 중이라고 가정)
func force_exit() -> void:
	if current != null:
		exit_vehicle(true)


func exit_position() -> Vector3:
	if current == null:
		return hub.player.global_position
	return _exit_spot(current)


## 상태 불일치(운전 모드인데 차량 없음 등)에서 플레이어를 걷는 상태로 되돌림
func _recover_free_state() -> void:
	_player_hidden(false)
	var rig = hub.rig
	rig.target = hub.player
	var arm = rig.get("_arm")
	if arm != null and arm is SpringArm3D:
		arm.spring_length = _spring_saved
	var q: Vector3 = Placement.find_free_capsule(hub.player.get_world_3d(), Vector3(hub.player.global_position.x, 0.0, hub.player.global_position.z), 0.35, 1.8)
	hub._teleport(Vector3(q.x, 0.15, q.z), hub.player.rotation.y)
	hub.player.set_physics_process(true)
	hub.mode = MODE_FREE
	_set_busy(false)
	_no_enter_until_ms = Time.get_ticks_msec() + 700
	print("[PYONGYANG][하차] 복구 완료 · 플레이어 위치=%s" % str(hub.player.global_position))


func _set_busy(v: bool) -> void:
	_busy = v
	_busy_since_ms = Time.get_ticks_msec() if v else 0


## 하차 후보 자리: 왼쪽/오른쪽 문 옆을 가까운 곳부터, 막히면 더 먼 옆자리, 앞/뒤, 마지막으로 주변 탐색
func _exit_spot(car) -> Vector3:
	var world3d: World3D = car.get_world_3d()
	var base: float = car.width * 0.5 + 1.1
	var cands: Array = []
	for extra in [0.0, 0.9, 1.9]:
		var sd: float = base + float(extra)
		cands.append(["왼쪽 %.1fm" % sd, car.global_position - car.right() * sd])
		cands.append(["오른쪽 %.1fm" % sd, car.global_position + car.right() * sd])
	var fb: float = car.length * 0.5 + 1.2
	cands.append(["뒤쪽", car.global_position - car.forward() * fb])
	cands.append(["앞쪽", car.global_position + car.forward() * fb])
	cands.append(["왼쪽 뒤", car.global_position - car.right() * base - car.forward() * (car.length * 0.3)])
	cands.append(["오른쪽 뒤", car.global_position + car.right() * base - car.forward() * (car.length * 0.3)])
	for e in cands:
		var c: Vector3 = e[1]
		var p: Vector3 = Vector3(c.x, 0.0, c.z)
		var why: String = _spot_problem(world3d, p, car)
		if why == "":
			print("[PYONGYANG][하차] 후보 채택: %s → %s" % [str(e[0]), str(p)])
			return p + Vector3(0.0, 0.15, 0.0)
		print("[PYONGYANG][하차] 후보 탈락: %s → %s" % [str(e[0]), why])
	var q: Vector3 = Placement.find_free_capsule(world3d, car.global_position + car.right() * base, 0.35, 1.8)
	print("[PYONGYANG][하차] 모든 후보 탈락 → 주변 탐색 결과 %s" % str(q))
	return Vector3(q.x, 0.15, q.z)


## 문제가 없으면 "" , 있으면 이유. 충돌체가 있는지, 차량 안쪽인지, 발밑에 바닥이 있는지 본다.
func _spot_problem(world3d: World3D, p: Vector3, car) -> String:
	if absf(p.x) > 395.0 or absf(p.z) > 395.0:
		return "맵 밖"
	if not Placement.is_free_capsule(world3d, p, 0.35, 1.8):
		return "충돌체와 겹침"
	# 차량 몸통 안쪽이면 안 됨 (차량 기준 좌표로 확인)
	var rel: Vector3 = car.global_transform.affine_inverse() * p
	if absf(rel.x) < car.width * 0.5 + 0.3 and absf(rel.z) < car.length * 0.5 + 0.3:
		return "차량 몸통 안"
	# 발밑에 바닥이 있는지
	var space: PhysicsDirectSpaceState3D = world3d.direct_space_state
	var q = PhysicsRayQueryParameters3D.create(Vector3(p.x, 2.0, p.z), Vector3(p.x, -2.0, p.z), 1)
	q.exclude = [car.get_rid(), hub.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return "발밑에 바닥 없음"
	var hp: Vector3 = hit["position"]
	if hp.y > 0.8:
		return "발밑이 높은 물체 위 (y=%.1f)" % hp.y
	return ""


func _player_hidden(h: bool) -> void:
	var p = hub.player
	p.visible = not h
	p.collision_layer = 0 if h else 1
	for c in p.get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", h)


func _chase_len(car) -> float:
	if car.kind == "bus" or car.kind == "truck" or car.kind == "military":
		return 10.5
	return 7.6


func toggle_view() -> void:
	if current == null:
		return
	var arm = hub.rig.get("_arm")
	if arm == null or not (arm is SpringArm3D):
		return
	if cam_mode == 0:
		cam_mode = 1
		arm.spring_length = 0.3
		current.set_body_visible(false)
	else:
		cam_mode = 0
		arm.spring_length = _chase_len(current)
		current.set_body_visible(true)


# ---------------------------------------------------------------- 매 프레임

func _physics_process(delta: float) -> void:
	if current == null or hub == null or hub.controls == null:
		return
	var car = current
	var panel_blocked: bool = hub.hud != null and hub.hud.panel_open()
	if hub.mode == MODE_DRIVING and not panel_blocked:
		var mv: Vector2 = hub.controls.get_move_vector()
		car.throttle_input = -mv.y
		car.steer_input = mv.x
		if hub.controls.consume_jump():
			car.handbrake_t = 0.5
	else:
		car.throttle_input = 0.0
		car.steer_input = 0.0
	hub.player.global_position = car.global_position + Vector3(0.0, 0.2, 0.0)
	hub.player.velocity = Vector3.ZERO
	driven_m += car.global_position.distance_to(_last_pos)
	_last_pos = car.global_position

	# 카메라: 달릴 때 차의 진행 방향 뒤로 천천히 돌아옴
	var rig = hub.rig
	if "yaw" in rig:
		var rate: float = 1.2 * clampf(absf(car.speed) / 8.0, 0.0, 1.0)
		if cam_mode == 1:
			rate = 10.0
		rig.yaw = lerp_angle(rig.yaw, car.rotation.y if car.speed >= -0.5 else car.rotation.y + PI, clampf(rate * delta, 0.0, 1.0))

	# 시민과 부딪힘 판정
	_hit_timer -= delta
	if _hit_timer <= 0.0:
		_hit_timer = 0.1
		_check_hits(car)


func _process(delta: float) -> void:
	_watchdog(delta)
	if _hit_cool.is_empty():
		return
	for k in _hit_cool.keys():
		_hit_cool[k] = float(_hit_cool[k]) - delta
		if float(_hit_cool[k]) <= 0.0:
			_hit_cool.erase(k)


## 하차/탑승이 중간에 멈춰 버튼이 영원히 안 먹는 상황을 스스로 풀어 줌
func _watchdog(delta: float) -> void:
	if hub == null or hub.player == null:
		return
	if _busy and _busy_since_ms > 0 and Time.get_ticks_msec() - _busy_since_ms > 8000:
		print("[PYONGYANG][하차] 감시: 전환이 8초 넘게 끝나지 않아 busy 를 풀었습니다 (mode=%d, 탑승중=%s)" % [hub.mode, str(current != null)])
		_set_busy(false)
		if current != null:
			hub.mode = MODE_DRIVING
		elif hub.mode == MODE_TRANSITION:
			_recover_free_state()
		return
	if current != null and not _busy and hub.mode == MODE_FREE:
		_free_with_car_t += delta
		if _free_with_car_t > 1.0:
			_free_with_car_t = 0.0
			print("[PYONGYANG][하차] 감시: 자유 상태인데 차량 탑승 정보가 남아 있어 정리합니다.")
			exit_vehicle(true)
	else:
		_free_with_car_t = 0.0


func _update_headlights() -> void:
	if current == null:
		return
	var night: bool = hub.clock != null and hub.clock.is_night()
	current.set_headlights(night)


func _check_hits(car) -> void:
	if absf(car.speed) < 4.5:
		return
	_update_headlights()
	var fwd: Vector3 = car.forward() * signf(car.speed)
	var front: Vector3 = car.global_position + fwd * (car.length * 0.5 + 0.4)
	for n in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(n) or not n.visible:
			continue
		var id: int = n.get_instance_id()
		if _hit_cool.has(id):
			continue
		var d: Vector3 = n.global_position - front
		d.y = 0.0
		var side: float = absf(d.dot(car.right()))
		if d.length() < 2.6 and side < car.width * 0.5 + 0.5:
			_hit_cool[id] = 3.0
			if n.has_method("shove"):
				n.shove(fwd * minf(absf(car.speed) * 0.5, 7.0))
			if n.has_method("scare"):
				n.scare(car.global_position, 12.0, true)
			if v1 != null and v1.alert != null:
				v1.alert.report("vehicle_hit", n.global_position, 1.0, n)


func _on_crashed(strength: float) -> void:
	if hub == null or current == null:
		return
	if strength > 9.0:
		hub.toast("충돌!")
		if v1 != null and v1.alert != null:
			v1.alert.report("crash", current.global_position, minf(strength / 14.0, 1.5), null)
	elif strength > 6.0:
		hub.toast("쿵!")


# ---------------------------------------------------------------- 택시 빠른 이동

func fast_travel(dest: Vector3, label: String) -> void:
	if _busy or hub == null or hub.mode == MODE_DRIVING:
		return
	_busy = true
	# 대화 효과에서 불려도 허브가 먼저 대화를 정리할 수 있게 한 프레임 기다림
	await get_tree().process_frame
	hub.mode = MODE_TRANSITION
	hub.player.set_physics_process(false)
	hub.ui.clear_prompt()
	await hub.ui.fade_to(1.0, 0.4)
	var spot: Vector3 = Placement.find_free_capsule(hub.player.get_world_3d(), dest, 0.35, 1.8)
	hub._teleport(Vector3(spot.x, 0.15, spot.z), 0.0)
	hub._set_location("")
	if hub.clock != null:
		hub.clock.set_minutes(fposmod(hub.clock.minutes + 7.0, 1440.0))
	await get_tree().create_timer(0.5).timeout
	await hub.ui.fade_to(0.0, 0.4)
	hub.player.set_physics_process(true)
	hub.mode = MODE_FREE
	_busy = false
	hub.toast("택시로 이동했다: " + label)
	hub.game.set_flag("taxi_used", true)


# ---------------------------------------------------------------- 버스 정류장 (ambient 버스 vehicle.gd 가 부름)

func on_bus_stop(bus, stop_pos: Vector3) -> void:
	if not is_instance_valid(bus):
		return
	# 내리는 승객
	var pax: Array = bus.passengers
	var i: int = 0
	for n in pax:
		if is_instance_valid(n) and n.has_method("alight_at"):
			var off: float = 3.0 + float(i) * 1.2
			var sidewalk_z: float = 11.5 if stop_pos.z > 0.0 else -11.5
			n.alight_at(Vector3(stop_pos.x + off - 3.0, 0.0, sidewalk_z))
		i += 1
	bus.passengers = []
	# 타는 승객 (정류장 근처 시민 최대 3명)
	var boarded: int = 0
	for n2 in get_tree().get_nodes_in_group("npcs"):
		if boarded >= 3:
			break
		if not is_instance_valid(n2) or not n2.has_method("can_board") or not n2.can_board():
			continue
		var d: float = Vector2(n2.global_position.x - stop_pos.x, n2.global_position.z - stop_pos.z).length()
		if d < 18.0:
			if n2.has_method("board_vehicle"):
				n2.board_vehicle(bus)
				bus.passengers.append(n2)
				boarded += 1
	if boarded > 0 and hub != null:
		var pd: float = hub.player.global_position.distance_to(stop_pos)
		if pd < 40.0:
			hub.toast("버스가 정차해 시민 %d명이 탑승했다." % boarded)


# ---------------------------------------------------------------- 저장 / 불러오기

func to_dict() -> Dictionary:
	var out: Array = []
	for c in vehicles:
		if is_instance_valid(c):
			out.append({"id": c.vid, "x": c.global_position.x, "y": c.global_position.y, "z": c.global_position.z, "yaw": c.rotation.y})
	return {"vehicles": out, "driven_m": driven_m}


func from_dict(d: Dictionary) -> void:
	if current != null:
		force_exit()
	if d.get("driven_m") is float or d.get("driven_m") is int:
		driven_m = float(d["driven_m"])
	var arr = d.get("vehicles", [])
	if not (arr is Array):
		return
	for e in arr:
		if not (e is Dictionary):
			continue
		for c in vehicles:
			if is_instance_valid(c) and c.vid == str(e.get("id", "")):
				var x = e.get("x")
				var y = e.get("y")
				var z = e.get("z")
				var yaw = e.get("yaw")
				if _num(x) and _num(y) and _num(z) and _num(yaw) and absf(float(x)) < 400.0 and absf(float(z)) < 400.0:
					c.global_position = Vector3(float(x), clampf(float(y), 0.0, 5.0), float(z))
					c.rotation.y = float(yaw)
					c.speed = 0.0


func _num(v) -> bool:
	if v is float or v is int:
		return not (is_nan(float(v)) or is_inf(float(v)))
	return false
