extends Node
## V3.0 최고지도자 플레이 모드.
##  - 전용 의상(외형 교체), 경호원·수행 비서 따라오기, 회의실 인물, 사저의 전 지도자
##  - 지도자 특권: 검문소 자동 통과, 경비의 의심 없음, 잠긴 문 열림, 전용 차량 호출
##  - 집무실 책상/회의 탁자/창가(도시 조망), 사저 침대/서재 상호작용
##  - 도시 조망 카메라 (집무실 창가에서 도시를 내려다봄)
## 이 모듈이 켜져 있어도 기존 자유 이동·차량 운전·건물 출입은 그대로 쓸 수 있다. (Godot 실행 미검증)

const D = preload("res://scripts/v3/v3_data.gd")
const Kit = preload("res://scripts/interior/interior_kit.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")
const NpcScript = preload("res://scripts/npc/npc.gd")
const VNpcs3 = preload("res://scripts/v23/v23_npcs.gd")

const SLOT: float = 100.0
const BASE_Y: float = 300.0
const S_OFFICE: int = 13
const S_RESIDENCE: int = 14
const CAR_HOME: Vector3 = Vector3(-248.0, 0.1, -300.0)

var hub = null
var mgr = null
var man = null

var active: bool = false
var followers: Array = []
var advisors: Array = []
var exleader = null
var holder: Node3D = null
var car = null
var car_vid: String = "v3_leader_car"

var overlook_active: bool = false
var _ov_cam: Camera3D = null
var _ov_idx: int = 0
var _ov_yaw: float = 0.0
var _ov_pitch: float = -0.55
var _ov_dist: float = 80.0
var _ov_focus: Vector3 = Vector3.ZERO
var _ov_t: float = 0.0

var _follow_t: float = 0.0
var _gate_t: float = 0.0
var _heat_t: float = 0.0
var _static_done: bool = false
var _outfit_pending: int = -1


func setup(hub_ref, mgr_ref, man_ref) -> void:
	hub = hub_ref
	mgr = mgr_ref
	man = man_ref
	holder = Node3D.new()
	holder.name = "V3_Entourage"
	if hub != null and hub.world != null:
		hub.world.add_child(holder)
	else:
		add_child(holder)


func origin(slot: int) -> Vector3:
	return Vector3(float(slot) * SLOT, BASE_Y, 0.0)


# ================================================================ 지도자 전용 상호작용 지점

func _interact(parent: Node3D, kind: String, prompt: String, pos: Vector3, radius: float, data: Dictionary, requires_flag: String = "", button: String = "") -> void:
	var it = InteractableScript.new()
	it.kind = kind
	it.prompt = prompt
	it.radius = radius
	it.data = data
	it.requires_flag = requires_flag
	it.button_text = button
	it.position = pos
	parent.add_child(it)


func _do_spot(parent: Node3D, local_pos: Vector3, prompt: String, text: String, key: String, button: String) -> void:
	_interact(parent, "examine", prompt, local_pos + Vector3(0.0, 1.0, 0.0), 1.9,
		{"text": text, "effects": [{"op": "v3_do", "key": key}], "once_flag": ""}, "v3_leader", button)


func build_static() -> void:
	if _static_done:
		return
	_static_done = true
	var v23 = null
	if mgr != null:
		v23 = mgr.v23
	if v23 != null and v23.get("_r_office") != null:
		var ro: Node3D = v23._r_office
		# 창가(도시를 내려다보는 창): 보이는 창틀 + 상호작용
		Kit.box(ro, Vector3(-2.8, 2.0, -28.82), Vector3(2.6, 1.7, 0.06), Color(0.55, 0.72, 0.92), false, 2, 0.5)
		Kit.box(ro, Vector3(-2.8, 2.0, -28.78), Vector3(2.8, 1.9, 0.04), Color(0.2, 0.18, 0.16), false, 2)
		_do_spot(ro, Vector3(-2.8, 0.0, -27.6), "창가에서 도시 내려다보기", "높은 창 너머로 도시가 펼쳐져 있다. 저 불빛 하나하나가 내가 책임질 삶이다.", "overlook", "조망")
		_do_spot(ro, Vector3(1.8, 0.0, -23.4), "집무 책상: 국정 보고서", "책상 위에 국정 보고서가 쌓여 있다. 숫자 하나하나가 도시의 오늘이다.", "menu_status", "국정")
		_do_spot(ro, Vector3(8.2, 0.0, -23.2), "회의 탁자: 회의 소집", "회의 탁자 위에 오늘의 안건 서류가 놓여 있다.", "menu_meeting", "회의")
	if v23 != null and v23.get("_r_res") != null:
		var rr: Node3D = v23._r_res
		_do_spot(rr, Vector3(-11.0, 0.0, -8.6), "침대에서 쉬기 (다음 날 아침까지)", "침대에 몸을 눕혔다. 눈을 감자 도시의 소리가 멀어진다.", "sleep", "쉬기")
		_do_spot(rr, Vector3(8.6, 0.0, -8.6), "서재 책상: 연설 준비", "서재 책상에 앉아 연설문을 가다듬었다.", "speech", "연설")
	# 바깥: 전용 차량 주차 자리
	if hub != null and hub.world != null:
		var park: Node3D = Node3D.new()
		park.name = "V3_CarPark"
		park.position = Vector3(CAR_HOME.x, 0.0, CAR_HOME.z)
		hub.world.add_child(park)
		Kit.box(park, Vector3(0.0, 0.09, 0.0), Vector3(3.4, 0.04, 6.4), Color(0.88, 0.86, 0.5), false, 1)
		Kit.label(park, Vector3(0.0, 0.16, 3.6), "전용 차량 주차 (가상)", 0.8, Color(1.0, 0.95, 0.7), 1, 3.14159265)
		_interact(park, "examine", "전용 차량 호출하기", Vector3(2.4, 1.0, 0.0), 3.0,
			{"text": "경호원이 무전을 보냈다. 곧 차가 도착한다.", "effects": [{"op": "v3_do", "key": "car"}], "once_flag": ""}, "v3_leader", "호출")


# ================================================================ 지도자 모드 켜기 / 끄기

func enter_mode(silent: bool) -> void:
	if active:
		return
	active = true
	hub.game.set_flag("v3_leader", true)
	_apply_outfit(true)
	_unlock_privileges()
	_spawn_entourage()
	_spawn_advisors()
	_spawn_exleader()
	_ensure_car()
	if not silent:
		hub.toast("지도자 전용 권한: 청사·사저·검문소를 자유롭게 드나들 수 있다.")


func exit_mode() -> void:
	if not active and followers.is_empty() and advisors.is_empty() and exleader == null and car == null:
		hub.game.set_flag("v3_leader", false)
		_apply_outfit(false)
		return
	active = false
	hub.game.set_flag("v3_leader", false)
	_apply_outfit(false)
	for n in followers:
		if n != null and is_instance_valid(n):
			n.queue_free()
	followers = []
	for n2 in advisors:
		if n2 != null and is_instance_valid(n2):
			n2.queue_free()
	advisors = []
	if exleader != null and is_instance_valid(exleader):
		exleader.queue_free()
	exleader = null
	_remove_car()
	if overlook_active:
		overlook_close()


func _find_gfx():
	if hub == null:
		return null
	for c in hub.get_children():
		if c.has_method("_swap_player"):
			return c
	return null


func _apply_outfit(on: bool) -> void:
	var cb = load("res://scripts/gfx/character_builder.gd")
	if cb == null:
		return
	if on:
		cb.player_override = D.leader_outfit()
	else:
		cb.player_override = {}
	if int(hub.mode) == 5:
		_outfit_pending = 1 if on else 0
		return
	var g = _find_gfx()
	if g != null:
		g._swap_player()
	_outfit_pending = -1


func _unlock_privileges() -> void:
	var g = hub.game
	if not g.has_item("v23_res_key"):
		g.add_item("v23_res_key", 1)
	g.set_flag("v23_bunker_open", true)
	g.set_flag("v23_shelf_open", true)
	hub.apply_effects([
		{"op": "unlock_door", "id": "v23_res_door"},
		{"op": "open_door", "id": "v23_res_door"},
		{"op": "reveal", "id": "v23_shelf"},
	])


# ================================================================ 수행원 / 경호원 / 인물

func _look_guard() -> Dictionary:
	return VNpcs3._look("m", Color(0.12, 0.14, 0.18), Color(0.08, 0.09, 0.12), true, Color(0.10, 0.11, 0.14), "", 1.04, VNpcs3.SK_B)


func _make_npc(parent: Node, cfg0: Dictionary, pos: Vector3, yaw_deg: float) -> Node:
	var cfg: Dictionary = cfg0.duplicate(true)
	cfg["home"] = pos
	cfg["yaw_deg"] = yaw_deg
	var n = NpcScript.new()
	n.name = "NPC_" + str(cfg["id"])
	n.configure(cfg, hub)
	n.position = pos + Vector3(0.0, 0.05, 0.0)
	parent.add_child(n)
	return n


func _stay(pos: Vector3) -> Array:
	return [{"from": 0.0, "to": 24.0, "mode": "stand", "pos": pos, "radius": 0.0}]


func _spawn_entourage() -> void:
	if not followers.is_empty() or hub.player == null:
		return
	var base: Vector3 = hub.player.global_position
	var defs: Array = [
		{"id": "v3_guard1", "name": "경호원 서도현", "role": "경호 경비 · 과묵", "kind": "guard", "look": _look_guard()},
		{"id": "v3_guard2", "name": "경호원 차민규", "role": "경호 경비 · 과묵", "kind": "guard", "look": _look_guard()},
		{"id": "v3_attend", "name": "수행 비서 한서윤", "role": "수행 직원 · 단정",  "kind": "attend",
			"look": VNpcs3._look("f", Color(0.22, 0.24, 0.30), Color(0.14, 0.15, 0.18), false, Color(0.2, 0.2, 0.2), "", 0.97, VNpcs3.SK_A)},
	]
	for i in range(defs.size()):
		var df: Dictionary = defs[i]
		var pos: Vector3 = base + Vector3(float(i) * 1.2 - 1.2, 0.0, 2.0)
		var cfg: Dictionary = {
			"id": df["id"], "name": df["name"], "role": df["role"], "speed": 2.8, "look": df["look"],
			"routine": _stay(pos), "dialogue": D.attendant_dialogue(str(df["kind"])),
		}
		var n = _make_npc(holder, cfg, pos, 0.0)
		n.set_meta("v3_follow_i", i)
		followers.append(n)


func _spawn_advisors() -> void:
	if not advisors.is_empty():
		return
	var v23 = mgr.v23 if mgr != null else null
	if v23 == null or v23.get("_r_office") == null:
		return
	var ro: Node3D = v23._r_office
	var defs: Array = [
		{"id": "econ", "nm": "경제 고문 윤하진", "role": "경제 고문 · 실무형", "pos": Vector3(8.6, 0.0, -21.0), "yaw": 270.0, "sex": "m", "shirt": Color(0.26, 0.28, 0.34)},
		{"id": "mil", "nm": "군부 대표 강태식", "role": "군부 대표 · 원칙주의", "pos": Vector3(14.4, 0.0, -21.0), "yaw": 90.0, "sex": "m", "shirt": Color(0.30, 0.34, 0.24)},
		{"id": "ppl", "nm": "인민 대표 오순금", "role": "인민 대표 · 현장형", "pos": Vector3(11.5, 0.0, -18.0), "yaw": 0.0, "sex": "f", "shirt": Color(0.50, 0.30, 0.26)},
	]
	for df in defs:
		var cfg: Dictionary = {
			"id": "v3_adv_" + str(df["id"]), "name": df["nm"], "role": df["role"], "speed": 1.1,
			"look": VNpcs3._look(str(df["sex"]), df["shirt"], Color(0.14, 0.15, 0.18), false, Color(0.2, 0.2, 0.2), "", 1.0, VNpcs3.SK_B),
			"routine": _stay(df["pos"]), "dialogue": D.advisor_dialogue(str(df["id"])),
		}
		var n = _make_npc(ro, cfg, df["pos"], float(df["yaw"]))
		advisors.append(n)


func _spawn_exleader() -> void:
	if exleader != null:
		return
	var v23 = mgr.v23 if mgr != null else null
	if v23 == null or v23.get("_r_res") == null:
		return
	var rr: Node3D = v23._r_res
	var look: Dictionary = VNpcs3._look("m", Color(0.34, 0.30, 0.28), Color(0.18, 0.17, 0.18), false, Color(0.2, 0.2, 0.2), "", 0.97, VNpcs3.SK_C)
	look["hair"] = Color(0.78, 0.78, 0.80)
	var pos: Vector3 = Vector3(2.5, 0.0, -12.6)
	var cfg: Dictionary = {
		"id": "v3_exleader", "name": "전 지도자 (가상)", "role": "은퇴한 노인 · 담담함", "speed": 1.0, "look": look,
		"routine": _stay(pos), "dialogue": D.exleader_dialogue(),
	}
	exleader = _make_npc(rr, cfg, pos, 180.0)


# ================================================================ 매 프레임 처리

func _process(delta: float) -> void:
	if overlook_active:
		_ov_t += delta
		if _ov_t > 1.0:
			_ov_t = 0.0
			if mgr != null and mgr.vworld != null:
				mgr.vworld.cull(Vector3(_ov_focus.x, 0.0, _ov_focus.z), false)
	if not active or hub == null or hub.player == null:
		return
	# 경비의 의심 없음 (지도자는 체포되지 않는다)
	for g in get_tree().get_nodes_in_group("guards"):
		if g.suspicion > 0.0:
			g.suspicion = 0.0
	_heat_t += delta
	if _heat_t >= 0.5:
		_heat_t = 0.0
		var v1 = hub.get("v1")
		if v1 != null and v1.alert != null and v1.alert.heat > 0.0:
			v1.alert.heat = maxf(0.0, v1.alert.heat - 6.0)
	_gate_t += delta
	if _gate_t >= 10.0:
		_gate_t = 0.0
		if mgr != null and mgr.pass_sys != null:
			for gid in mgr.pass_sys.gates.keys():
				mgr.pass_sys.open_gate(str(gid), 40.0)
	_follow_t += delta
	if _follow_t >= 0.6:
		_follow_t = 0.0
		_update_followers()
	if _outfit_pending >= 0 and int(hub.mode) != 5:
		_apply_outfit(_outfit_pending == 1)


func _update_followers() -> void:
	if hub.mode == 3:
		return
	var pp: Vector3 = hub.player.global_position
	var indoors: bool = pp.y > 100.0
	var yaw: float = 0.0
	if hub.rig != null and "yaw" in hub.rig:
		yaw = float(hub.rig.yaw)
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var back_d: float = 1.8 if indoors else 3.2
	var side_d: float = 1.0 if indoors else 1.8
	for i in range(followers.size()):
		var n = followers[i]
		if n == null or not is_instance_valid(n):
			continue
		var idx: int = int(n.get_meta("v3_follow_i", i))
		var side: float = 0.0
		var back: float = back_d
		if idx == 0:
			side = -side_d
		elif idx == 1:
			side = side_d
		else:
			side = 0.0
			back = back_d + 1.6
		var want: Vector3 = pp - fwd * back + right * side
		want.y = pp.y
		if not indoors:
			want.y = 0.0
		var far: bool = n.global_position.distance_to(pp) > 22.0 or absf(n.global_position.y - pp.y) > 30.0
		if far or int(hub.mode) == 5:
			var spot: Vector3 = want
			if not indoors and hub.world != null:
				spot = Placement.find_free_capsule(hub.world.get_world_3d(), want, 0.4, 1.7)
			n.global_position = Vector3(spot.x, want.y + 0.1, spot.z)
			n.velocity = Vector3.ZERO
		if n.routine.size() > 0:
			n.routine[0]["pos"] = Vector3(want.x, want.y, want.z)
			n._arrived = false
		# 가까우면 플레이어 쪽을 보게
		n.facing_yaw = yaw


# ================================================================ 전용 차량

func _ensure_car() -> void:
	if car != null and is_instance_valid(car):
		return
	var v1 = hub.get("v1")
	if v1 == null or v1.drive == null or hub.world == null:
		return
	car = v1.drive.spawn_one(hub.world, "car", CAR_HOME, 0.0, Color(0.06, 0.06, 0.08), car_vid)


func _remove_car() -> void:
	if car != null and is_instance_valid(car):
		var v1 = hub.get("v1")
		if v1 != null and v1.drive != null:
			if v1.drive.current == car:
				v1.drive.force_exit()
			v1.drive.vehicles.erase(car)
		car.queue_free()
	car = null


func summon_car() -> String:
	if int(hub.mode) == 5:
		return "이미 차를 타고 있습니다."
	_ensure_car()
	if car == null or not is_instance_valid(car):
		return "전용 차량을 부를 수 없습니다. (차량 모듈이 꺼져 있음)"
	var pp: Vector3 = hub.player.global_position
	if pp.y > 100.0:
		return "건물 안에서는 부를 수 없습니다. 바깥으로 나가세요."
	var yaw: float = 0.0
	if hub.rig != null and "yaw" in hub.rig:
		yaw = float(hub.rig.yaw)
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var want: Vector3 = pp + fwd * 7.0
	var spot: Vector3 = Placement.find_free_box(hub.world.get_world_3d(), want, Vector3(car.width + 1.5, 2.0, car.length + 1.5))
	car.global_position = Vector3(spot.x, 0.1, spot.z)
	car.rotation = Vector3(0.0, yaw + PI * 0.5, 0.0)
	car.speed = 0.0
	return "전용 차량이 도착했다. 가까이 가서 탑승하세요."


func car_state() -> Array:
	if car != null and is_instance_valid(car):
		var p: Vector3 = car.global_position
		return [p.x, p.y, p.z, car.rotation.y]
	return []


func restore_car(arr: Array) -> void:
	_ensure_car()
	if car == null or not is_instance_valid(car) or arr.size() < 4:
		return
	car.global_position = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	car.rotation = Vector3(0.0, float(arr[3]), 0.0)
	car.speed = 0.0


# ================================================================ 도시 조망 카메라

func overlook_name() -> String:
	return ["청사 전경", "도시 중심", "개발 지구"][_ov_idx % 3]


func overlook_start() -> void:
	if overlook_active or hub == null:
		return
	overlook_active = true
	_ov_cam = Camera3D.new()
	_ov_cam.name = "V3_OverlookCam"
	_ov_cam.far = 1200.0
	_ov_cam.near = 0.5
	_ov_cam.fov = 62.0
	add_child(_ov_cam)
	_ov_idx = 0
	_apply_view()
	_ov_cam.make_current()
	if man != null:
		man.on_overlook(true)


func overlook_close() -> void:
	if not overlook_active:
		return
	overlook_active = false
	if hub != null and hub.rig != null:
		var rc = hub.rig.get("_cam")
		if rc != null and rc is Camera3D:
			rc.make_current()
	if _ov_cam != null and is_instance_valid(_ov_cam):
		_ov_cam.queue_free()
	_ov_cam = null
	if man != null:
		man.on_overlook(false)


func overlook_next() -> void:
	_ov_idx = (_ov_idx + 1) % 3
	_apply_view()


func overlook_zoom(d: float) -> void:
	_ov_dist = clampf(_ov_dist + d, 20.0, 320.0)
	_place_cam()


func overlook_drag(rel: Vector2) -> void:
	_ov_yaw -= rel.x * 0.006
	_ov_pitch = clampf(_ov_pitch - rel.y * 0.004, -1.35, -0.12)
	_place_cam()


func _apply_view() -> void:
	match _ov_idx % 3:
		0:
			_ov_focus = Vector3(-245.0, 6.0, -325.0)
			_ov_dist = 80.0
			_ov_yaw = 2.5
			_ov_pitch = -0.38
		1:
			_ov_focus = Vector3(0.0, 4.0, 0.0)
			_ov_dist = 170.0
			_ov_yaw = 0.4
			_ov_pitch = -0.6
		_:
			var bp: Vector3 = Vector3(60.0, 0.0, 60.0)
			if man != null and man.build != null:
				bp = man.build.last_position()
			_ov_focus = Vector3(bp.x, 2.0, bp.z)
			_ov_dist = 90.0
			_ov_yaw = 0.8
			_ov_pitch = -0.55
	_place_cam()
	if mgr != null and mgr.vworld != null:
		mgr.vworld.cull(Vector3(_ov_focus.x, 0.0, _ov_focus.z), false)


func _place_cam() -> void:
	if _ov_cam == null or not is_instance_valid(_ov_cam):
		return
	var pit: float = -_ov_pitch
	var hd: float = _ov_dist * cos(pit)
	var hgt: float = _ov_dist * sin(pit)
	var pos: Vector3 = _ov_focus + Vector3(sin(_ov_yaw) * hd, hgt, cos(_ov_yaw) * hd)
	_ov_cam.look_at_from_position(pos, _ov_focus, Vector3.UP)


# ================================================================ 휴식

func sleep_until_morning() -> void:
	var clock = hub.clock
	var m: float = clock.minutes
	if m >= 390.0:
		if m <= 990.0 and mgr != null:
			mgr.day += 1
	clock.set_minutes(390.0)
