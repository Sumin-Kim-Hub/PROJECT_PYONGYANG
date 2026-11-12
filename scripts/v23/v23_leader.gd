extends Node
## V2.3 가상의 "중앙 청사"(집무실) + 사저. 기존 V2.2 코드는 건드리지 않고 이 파일 하나가 새로 만듭니다.
##  - 바깥: 통제구역 서쪽 깊은 곳(약 -245, -331)의 담으로 둘러싸인 구역. 남쪽 정문은 특별 통행증 검문(레벨 2).
##  - 실내 칸 13: 청사 (로비 → 복도 → 집무실 / 비서실 / 회의실 → 잠긴 문 → 사저 통로)
##  - 실내 칸 14: 사저 (현관 → 거실 / 침실 / 서재 → 숨겨진 책장 → 지하 대피소 → 비상 갱도)
##  - 지도자 본인은 등장하지 않습니다 (모습, 이름, 대사 모두 없음). 모든 장소·인물·문서는 이 게임을 위한 가상 설정입니다.
## 불러오기에 실패해도 게임은 그대로 진행됩니다. (Godot 실행 미검증)

const Kit = preload("res://scripts/interior/interior_kit.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")
const DoorScript = preload("res://scripts/interior/door.gd")
const NpcScript = preload("res://scripts/npc/npc.gd")
const VNpcs3 = preload("res://scripts/v23/v23_npcs.gd")

const SLOT: float = 100.0
const BASE_Y: float = 300.0
const S_OFFICE: int = 13
const S_RESIDENCE: int = 14
const PI_: float = 3.14159265
const QID: String = "q_v23_leader"

## 바깥 배치 (월드 좌표)
const GATE_X: float = -245.0
const GATE_Z: float = -290.0
const X0: float = -300.0
const X1: float = -190.0
const Z0: float = -372.0
const OFFICE_DOOR: Vector3 = Vector3(-262.0, 0.0, -322.4)
const RES_DOOR: Vector3 = Vector3(-212.0, 0.0, -347.4)
const BUNKER_OUT: Vector3 = Vector3(-314.0, 0.0, -335.0)

var hub = null
var mgr = null
var root: Node3D = null
var npcs: Array = []
var done: bool = false
var guard_count: int = 0
var _tick: float = 0.0
var _r_office: Node3D = null
var _r_res: Node3D = null


func _origin(slot: int) -> Vector3:
	return Vector3(float(slot) * SLOT, BASE_Y, 0.0)


func _slot_root(slot: int, nm: String) -> Node3D:
	var r = Node3D.new()
	r.name = nm
	r.position = _origin(slot)
	add_child(r)
	return r


func build(hub_ref, mgr_ref) -> void:
	hub = hub_ref
	mgr = mgr_ref
	root = Node3D.new()
	root.name = "V23_Compound"
	add_child(root)
	_build_outside()
	await get_tree().process_frame
	_build_office()
	await get_tree().process_frame
	_build_residence()
	await get_tree().process_frame
	_spawn_inner_npcs()
	if mgr != null and mgr.vworld != null:
		mgr.vworld.regions.append({"name": "LeaderCompound", "node": root, "center": Vector3(-245.0, 0.0, -331.0), "radius": 75.0})
	print("[PYONGYANG] V2.3 중앙 청사/사저를 만들었습니다 (경비 %d명)." % guard_count)
	done = true


# ================================================================ 도우미

func _cb(pos: Vector3, size: Vector3, color: Color) -> Node3D:
	return Kit.box(root, pos, size, color, true, 1)


func _db(pos: Vector3, size: Vector3, color: Color) -> void:
	Kit.box(root, pos, size, color, false, 1)


func _lab(pos: Vector3, text: String, size: float, color: Color, yaw: float = 0.0) -> void:
	Kit.label(root, pos, text, size, color, 1, yaw)


func _wallx(x0: float, x1: float, z: float, h: float, t: float, color: Color) -> void:
	_cb(Vector3((x0 + x1) * 0.5, h * 0.5, z), Vector3(x1 - x0, h, t), color)
	_db(Vector3((x0 + x1) * 0.5, h + 0.12, z), Vector3(x1 - x0, 0.24, t + 0.2), Color(0.18, 0.18, 0.2))


func _wallz(x: float, z0: float, z1: float, h: float, t: float, color: Color) -> void:
	_cb(Vector3(x, h * 0.5, (z0 + z1) * 0.5), Vector3(t, h, z1 - z0), color)
	_db(Vector3(x, h + 0.12, (z0 + z1) * 0.5), Vector3(t + 0.2, 0.24, z1 - z0), Color(0.18, 0.18, 0.2))


func _tree(x: float, z: float) -> void:
	_db(Vector3(x, 1.6, z), Vector3(0.4, 3.2, 0.4), Color(0.30, 0.22, 0.16))
	_db(Vector3(x, 4.0, z), Vector3(2.4, 2.2, 2.4), Color(0.22, 0.40, 0.22))


func _lamp_post(x: float, z: float) -> void:
	_db(Vector3(x, 2.2, z), Vector3(0.16, 4.4, 0.16), Color(0.25, 0.25, 0.28))
	_db(Vector3(x, 4.5, z), Vector3(0.5, 0.18, 0.5), Color(1.0, 0.95, 0.75))


func _interact(parent: Node3D, kind: String, prompt: String, pos: Vector3, radius: float, data: Dictionary, hide_flag: String = "", requires_flag: String = "", button: String = "") -> void:
	var it = InteractableScript.new()
	it.kind = kind
	it.prompt = prompt
	it.radius = radius
	it.data = data
	it.hide_flag = hide_flag
	it.requires_flag = requires_flag
	it.button_text = button
	it.position = pos
	parent.add_child(it)


func _portal(r: Node3D, local_pos: Vector3, prompt: String, button: String, dest: Vector3, dest_yaw: float, location: String, effects: Array = [], radius: float = 1.8, kind: String = "portal", requires_flag: String = "") -> void:
	var data: Dictionary = {"dest": dest, "dest_yaw": dest_yaw, "location": location, "effects": effects}
	_interact(r, kind, prompt, local_pos + Vector3(0.0, 1.0, 0.0), radius, data, "", requires_flag, button)


func _examine(r: Node3D, local_pos: Vector3, prompt: String, text: String, effects: Array = [], once_flag: String = "", radius: float = 1.8, hide_flag: String = "", requires_flag: String = "") -> void:
	var data: Dictionary = {"text": text, "effects": effects, "once_flag": once_flag}
	_interact(r, "examine", prompt, local_pos + Vector3(0.0, 1.0, 0.0), radius, data, hide_flag, requires_flag)


## 얻을 수 있는 물건/돈. flag 는 "pk_v23_..." 로 시작해야 저장/표식 숨김과 맞습니다.
func _loot(r: Node3D, local_pos: Vector3, prompt: String, text: String, effects: Array, flag: String) -> void:
	_examine(r, local_pos, prompt, text, effects, flag, 1.7, flag, "")
	var m = Kit.box(r, local_pos, Vector3(0.26, 0.07, 0.2), Color(0.95, 0.85, 0.35), false, 2, 1.2)
	m.add_to_group("pk_mark_" + flag.substr(3))


func _door(r: Node3D, hinge: Vector3, rot_y: float, door_id: String, key_item: String, locked_text: String, width: float = 1.4) -> void:
	var dr = DoorScript.new()
	dr.door_id = door_id
	dr.width = width
	dr.locked = key_item != ""
	dr.key_item = key_item
	dr.locked_text = locked_text
	dr.position = hinge
	dr.rotation.y = rot_y
	r.add_child(dr)
	dr.setup(hub)


func _quest(step: int) -> Dictionary:
	return {"op": "quest_step", "id": QID, "step": step}


func _make_npc(cfg0: Dictionary, parent: Node3D, pos: Vector3, yaw_deg: float, track: bool) -> Node:
	var cfg: Dictionary = cfg0.duplicate(true)
	cfg["home"] = pos
	cfg["yaw_deg"] = yaw_deg
	var npc = NpcScript.new()
	npc.name = "NPC_" + str(cfg["id"])
	npc.configure(cfg, hub)
	npc.position = pos + Vector3(0.0, 0.05, 0.0)
	parent.add_child(npc)
	if track:
		npcs.append(npc)
		if mgr != null and mgr.vworld != null:
			mgr.vworld.npcs.append(npc)
	return npc


func _guard_look() -> Dictionary:
	return VNpcs3._look("m", Color(0.30, 0.34, 0.24), Color(0.20, 0.24, 0.16), true, Color(0.20, 0.24, 0.16), "", 1.05, VNpcs3.SK_B)


func _patrol(nid: String, nm: String, path: Array) -> void:
	var cfg: Dictionary = {
		"id": nid, "name": nm, "role": "순찰 군인 · 경계", "speed": 1.3, "look": _guard_look(),
		"vision_range": 13.0, "vision_fov": 90.0, "no_talk": true, "patrol_path": path,
		"routine": [{"from": 0.0, "to": 24.0, "mode": "patrol", "pos": path[0], "radius": 0.0, "path": path, "pause": 2.0}],
	}
	var g = NpcScript.new()
	g.name = "NPC_" + nid
	g.configure(cfg, hub)
	g.position = path[0] + Vector3(0.0, 0.05, 0.0)
	root.add_child(g)
	npcs.append(g)
	guard_count += 1
	if mgr != null and mgr.vworld != null:
		mgr.vworld.npcs.append(g)


func _indoor_patrol(r: Node3D, nid: String, nm: String, path_local: Array, slot: int) -> void:
	var o: Vector3 = _origin(slot)
	var path: Array = []
	for p in path_local:
		path.append(o + p + Vector3(0.0, 0.05, 0.0))
	var cfg: Dictionary = {
		"id": nid, "name": nm, "role": "순찰 경비", "speed": 1.3, "look": _guard_look(),
		"vision_range": 9.0, "vision_fov": 80.0, "no_talk": true, "patrol_path": path,
	}
	var g = NpcScript.new()
	g.name = "NPC_" + nid
	g.configure(cfg, hub)
	g.position = path_local[0] + Vector3(0.0, 0.05, 0.0)
	r.add_child(g)
	guard_count += 1


# ================================================================ 바깥: 담으로 둘러싸인 청사 구역

func _build_outside() -> void:
	var wc: Color = Color(0.50, 0.50, 0.46)
	var lane: float = 7.0
	# 담: 남쪽은 정문 차선(±7)을 비움
	_wallx(X0, GATE_X - lane, GATE_Z, 4.0, 0.7, wc)
	_wallx(GATE_X + lane, X1, GATE_Z, 4.0, 0.7, wc)
	_wallx(X0, X1, Z0, 4.0, 0.7, wc)
	_wallz(X0, Z0, GATE_Z, 4.0, 0.7, wc)
	_wallz(X1, Z0, GATE_Z, 4.0, 0.7, wc)
	_gate()
	# 안뜰 바닥과 중앙 대로
	_db(Vector3(-245.0, 0.05, -331.0), Vector3(108.0, 0.08, 80.0), Color(0.62, 0.61, 0.57))
	_db(Vector3(GATE_X, 0.07, -306.0), Vector3(14.0, 0.08, 32.0), Color(0.40, 0.40, 0.42))
	_db(Vector3(-262.0, 0.07, -322.0), Vector3(12.0, 0.08, 6.0), Color(0.40, 0.40, 0.42))
	_db(Vector3(-238.0, 0.07, -336.0), Vector3(3.0, 0.08, 26.0), Color(0.52, 0.50, 0.46))
	_db(Vector3(-225.0, 0.07, -348.0), Vector3(26.0, 0.08, 3.0), Color(0.52, 0.50, 0.46))
	_db(Vector3(-212.0, 0.07, -343.0), Vector3(5.0, 0.08, 8.0), Color(0.40, 0.40, 0.42))
	# 연못과 정원
	_db(Vector3(-218.0, 0.04, -312.0), Vector3(20.0, 0.06, 10.0), Color(0.22, 0.38, 0.52))
	for tp2 in [Vector2(-290.0, -300.0), Vector2(-283.0, -300.0), Vector2(-276.0, -300.0), Vector2(-214.0, -324.0), Vector2(-205.0, -324.0), Vector2(-196.0, -300.0), Vector2(-196.0, -324.0), Vector2(-290.0, -324.0)]:
		_tree(tp2.x, tp2.y)
	for tz in [-300.0, -310.0, -320.0]:
		_lamp_post(-253.0, tz)
		_lamp_post(-237.0, tz)
	# 기념 석비 (글귀만 있는 평범한 석비, 인물 조각 없음)
	_cb(Vector3(-274.0, 1.2, -312.0), Vector3(4.0, 2.4, 2.0), Color(0.72, 0.70, 0.66))
	_lab(Vector3(-274.0, 1.4, -310.9), "함께 지키자 (가상의 구호)", 0.7, Color(0.2, 0.15, 0.1), PI_)
	# 깃대
	_db(Vector3(-253.0, 5.0, -293.0), Vector3(0.14, 10.0, 0.14), Color(0.7, 0.7, 0.72))
	_db(Vector3(-250.0, 9.0, -293.0), Vector3(5.0, 2.4, 0.1), Color(0.7, 0.1, 0.1))
	# 모퉁이 감시탑 4개
	for tp in [Vector3(X0 + 4.0, 0.0, GATE_Z - 4.0), Vector3(X1 - 4.0, 0.0, GATE_Z - 4.0), Vector3(X0 + 4.0, 0.0, Z0 + 4.0), Vector3(X1 - 4.0, 0.0, Z0 + 4.0)]:
		_cb(tp + Vector3(0.0, 3.5, 0.0), Vector3(3.6, 7.0, 3.6), Color(0.40, 0.42, 0.36))
		_db(tp + Vector3(0.0, 7.4, 0.0), Vector3(4.4, 0.5, 4.4), Color(0.2, 0.2, 0.2))
		_db(tp + Vector3(0.0, 6.0, 1.82), Vector3(2.0, 0.9, 0.1), Color(0.16, 0.22, 0.28))
	_office_exterior()
	_residence_exterior()
	_bunker_exit_outside()
	# 정문 표지와 안내 표지
	_lab(Vector3(GATE_X, 8.0, GATE_Z + 0.4), "중앙 청사 (가상) · 특별 통행증", 1.5, Color(1.0, 0.95, 0.8))
	_lab(Vector3(GATE_X, 8.0, GATE_Z - 0.4), "중앙 청사 (가상)", 1.5, Color(1.0, 0.95, 0.8), PI_)
	if hub != null:
		hub.register_poi("v23_leader_compound", "중앙 청사 일대", Vector3(GATE_X, 0.0, -300.0))
	# 순찰 경비
	_patrol("v23_pat1", "청사 순찰병 하동", [Vector3(-280.0, 0.0, -300.0), Vector3(-256.0, 0.0, -300.0), Vector3(-256.0, 0.0, -316.0), Vector3(-280.0, 0.0, -316.0)])
	_patrol("v23_pat2", "청사 순찰병 오진", [Vector3(-232.0, 0.0, -300.0), Vector3(-200.0, 0.0, -300.0), Vector3(-200.0, 0.0, -330.0), Vector3(-232.0, 0.0, -330.0)])
	_patrol("v23_pat3", "사저 경계병 주만", [Vector3(-236.0, 0.0, -346.0), Vector3(-200.0, 0.0, -346.0), Vector3(-200.0, 0.0, -340.0), Vector3(-236.0, 0.0, -340.0)])


func _gate() -> void:
	var lane: float = 7.0
	var z: float = GATE_Z
	var body_col: Color = Color(0.40, 0.44, 0.38)
	_cb(Vector3(GATE_X - lane - 3.0, 1.8, z), Vector3(5.0, 3.6, 4.0), body_col)
	_cb(Vector3(GATE_X + lane + 3.0, 1.8, z), Vector3(5.0, 3.6, 4.0), body_col)
	_db(Vector3(GATE_X - lane - 3.0, 3.8, z), Vector3(5.8, 0.4, 4.8), Color(0.24, 0.26, 0.24))
	_db(Vector3(GATE_X + lane + 3.0, 3.8, z), Vector3(5.8, 0.4, 4.8), Color(0.24, 0.26, 0.24))
	_db(Vector3(GATE_X, 6.0, z), Vector3(lane * 2.0 + 1.2, 1.8, 0.4), Color(0.62, 0.10, 0.10))
	_db(Vector3(GATE_X - lane - 0.5, 3.0, z), Vector3(0.24, 6.0, 0.24), Color(0.3, 0.3, 0.32))
	_db(Vector3(GATE_X + lane + 0.5, 3.0, z), Vector3(0.24, 6.0, 0.24), Color(0.3, 0.3, 0.32))
	# 차단기: 충돌 몸체(열리면 충돌 끔) + 줄무늬 팔
	var body = StaticBody3D.new()
	body.position = Vector3(GATE_X, 2.0, z)
	var cs = CollisionShape3D.new()
	var shp = BoxShape3D.new()
	shp.size = Vector3(lane * 2.0, 4.0, 0.5)
	cs.shape = shp
	body.add_child(cs)
	root.add_child(body)
	var arm = Node3D.new()
	arm.position = Vector3(GATE_X - lane, 1.1, z)
	root.add_child(arm)
	var segs: int = 8
	for i in range(segs):
		var col: Color = Color(0.9, 0.9, 0.9) if i % 2 == 0 else Color(0.78, 0.12, 0.10)
		var seg_w: float = lane * 2.0 / float(segs)
		Kit.box(arm, Vector3(seg_w * (float(i) + 0.5), 0.0, 0.0), Vector3(seg_w, 0.22, 0.22), col, false, 1)
	if mgr != null and mgr.pass_sys != null:
		mgr.pass_sys.register_gate("leader", 2, "중앙 청사 정문", Vector3(GATE_X, 0.0, z), body, arm)
	if hub != null:
		hub.register_poi("v22_gate_leader", "중앙 청사 정문", Vector3(GATE_X, 0.0, z + 8.0))
	# 정문 경비 (남쪽, 접근하는 쪽을 바라봄)
	if mgr != null and mgr.pass_sys != null:
		var dlg: Dictionary = mgr.pass_sys.make_dialogue("leader", 2)
		var g1: Dictionary = {
			"id": "v23_gate1", "name": "청사 정문 병사 태수", "role": "정문 군인 · 엄격함", "speed": 1.1,
			"look": _guard_look(), "routine": [], "dialogue": dlg,
		}
		var g2: Dictionary = {
			"id": "v23_gate2", "name": "청사 정문 병사 민욱", "role": "정문 군인 · 냉정", "speed": 1.1,
			"look": _guard_look(), "routine": [], "dialogue": {}, "no_talk": true,
		}
		var n1 = _make_npc(g1, root, Vector3(GATE_X + 4.0, 0.0, z + 3.5), 180.0, true)
		var n2 = _make_npc(g2, root, Vector3(GATE_X - 4.0, 0.0, z + 3.5), 180.0, true)
		n1.set_meta("v22_gate", true)
		n2.set_meta("v22_gate", true)
		mgr.pass_sys.add_guard("leader", n1)
		mgr.pass_sys.add_guard("leader", n2)
		guard_count += 2


func _office_exterior() -> void:
	var c: Vector3 = Vector3(-262.0, 0.0, -335.0)
	_cb(c + Vector3(0.0, 5.0, 0.0), Vector3(40.0, 10.0, 20.0), Color(0.78, 0.76, 0.70))
	_db(c + Vector3(0.0, 10.4, 0.0), Vector3(42.0, 0.8, 22.0), Color(0.30, 0.34, 0.36))
	_db(c + Vector3(0.0, 11.4, 0.0), Vector3(20.0, 1.2, 12.0), Color(0.26, 0.30, 0.32))
	# 포르티코: 기둥 6개 + 지붕
	for px in [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]:
		_db(c + Vector3(px, 4.0, 11.5), Vector3(1.0, 8.0, 1.0), Color(0.88, 0.86, 0.80))
	_db(c + Vector3(0.0, 8.4, 11.0), Vector3(24.0, 0.8, 3.0), Color(0.55, 0.53, 0.48))
	_db(c + Vector3(0.0, 1.4, 10.06), Vector3(3.2, 2.8, 0.2), Color(0.12, 0.10, 0.09))
	for wx in range(-8, 9):
		if absi(wx) <= 1:
			continue
		_db(c + Vector3(float(wx) * 2.2, 3.0, 10.06), Vector3(1.2, 1.6, 0.1), Color(0.16, 0.22, 0.30))
		_db(c + Vector3(float(wx) * 2.2, 6.4, 10.06), Vector3(1.2, 1.6, 0.1), Color(0.16, 0.22, 0.30))
	_db(c + Vector3(0.0, 9.0, 10.1), Vector3(10.0, 1.2, 0.2), Color(0.64, 0.10, 0.10))
	_lab(c + Vector3(0.0, 9.0, 10.3), "중앙 청사 (가상)", 1.2, Color(1.0, 0.95, 0.8))
	_interact(root, "enter", "중앙 청사 입장", OFFICE_DOOR + Vector3(0.0, 1.0, 0.0), 2.6,
		{"dest": _origin(S_OFFICE) + Vector3(0.0, 0.1, 3.4), "dest_yaw": 0.0, "location": "중앙 청사",
			"effects": [_quest(2)]})
	if hub != null:
		hub.register_poi("v23_office", "중앙 청사", OFFICE_DOOR)


func _residence_exterior() -> void:
	var c: Vector3 = Vector3(-212.0, 0.0, -358.0)
	_cb(c + Vector3(0.0, 4.0, 0.0), Vector3(36.0, 8.0, 16.0), Color(0.66, 0.60, 0.52))
	_db(c + Vector3(0.0, 8.3, 0.0), Vector3(38.0, 0.7, 18.0), Color(0.34, 0.26, 0.22))
	_db(c + Vector3(0.0, 1.3, 8.06), Vector3(2.6, 2.6, 0.2), Color(0.12, 0.10, 0.09))
	for wx in range(-7, 8):
		if absi(wx) <= 1:
			continue
		_db(c + Vector3(float(wx) * 2.2, 3.6, 8.06), Vector3(1.2, 1.5, 0.1), Color(0.16, 0.22, 0.30))
	_lab(c + Vector3(0.0, 6.0, 8.3), "사저 (가상)", 1.0, Color(1.0, 0.95, 0.8))
	# 관리용 울타리
	_db(Vector3(-231.0, 0.7, -343.0), Vector3(12.0, 1.4, 0.2), Color(0.28, 0.28, 0.3))
	_db(Vector3(-193.0, 0.7, -343.0), Vector3(6.0, 1.4, 0.2), Color(0.28, 0.28, 0.3))
	_interact(root, "enter", "사저 정문 열기", RES_DOOR + Vector3(0.0, 1.0, 0.0), 2.4,
		{"dest": _origin(S_RESIDENCE) + Vector3(0.0, 0.1, 2.6), "dest_yaw": 0.0, "location": "사저",
			"requires": {"item": "v23_res_key"}, "locked_text": "사저 정문은 굳게 잠겨 있다. 열쇠가 필요하다. (청사 비서실을 살펴보자)",
			"effects": [_quest(4)]})
	if hub != null:
		hub.register_poi("v23_residence", "사저", RES_DOOR)


## 담 서쪽 바깥의 비상 갱도 출구. 대피소에서 나오면 열려 안으로도 들어갈 수 있음
func _bunker_exit_outside() -> void:
	_db(BUNKER_OUT + Vector3(0.0, 0.07, 0.0), Vector3(1.8, 0.12, 1.8), Color(0.14, 0.14, 0.16))
	_interact(root, "enter", "비상 갱도로 내려가기 (사저 지하)", BUNKER_OUT + Vector3(0.0, 1.0, 0.0), 2.4,
		{"dest": _origin(S_RESIDENCE) + Vector3(12.5, 0.1, -23.4), "dest_yaw": 0.0, "location": "사저 지하 대피소", "effects": []},
		"", "v23_bunker_open")
	_interact(root, "examine", "철판 덮개 살펴보기", BUNKER_OUT + Vector3(0.0, 1.0, 0.0), 2.2,
		{"text": "무거운 철판이 땅에 박혀 있다. 안쪽에서 빗장이 걸려 있는 듯 열리지 않는다.", "effects": [], "once_flag": ""},
		"v23_bunker_open")


# ================================================================ 칸 13: 중앙 청사

func _build_office() -> void:
	var r: Node3D = _slot_root(S_OFFICE, "V23_Int_Office")
	_r_office = r
	var wc: Color = Color(0.74, 0.72, 0.66)
	var fc: Color = Color(0.34, 0.30, 0.28)
	var cc: Color = Color(0.82, 0.80, 0.76)
	var h: float = 3.4
	var warm: Color = Color(1.0, 0.94, 0.80)

	# 로비 (14 x 10)
	Kit.room(r, Vector3(0.0, 0.0, 0.0), 14.0, 10.0, h, fc, wc, cc, {"n": Vector2(0.0, 2.4)})
	Kit.lamp(r, Vector3(-3.5, h - 0.2, 0.0), 1.0, 9.0, warm)
	Kit.lamp(r, Vector3(3.5, h - 0.2, 0.0), 1.0, 9.0, warm)
	Kit.rug(r, Vector3(0.0, 0.02, -1.0), 5.0, 8.0, Color(0.5, 0.12, 0.12))
	Kit.counter(r, Vector3(-4.6, 0.0, 2.2), 0.0, 3.0, Color(0.36, 0.28, 0.22))
	Kit.sofa(r, Vector3(4.6, 0.0, 3.6), PI_, Color(0.38, 0.22, 0.22))
	Kit.table(r, Vector3(4.6, 0.0, 1.4), 1.6, 0.8, 0.5, Color(0.34, 0.28, 0.22))
	Kit.box(r, Vector3(0.0, 2.3, 4.8), Vector3(5.0, 1.2, 0.1), Color(0.6, 0.1, 0.1), false, 2)
	Kit.label(r, Vector3(0.0, 2.3, 4.7), "질서와 책임 (가상의 표어)", 0.5, Color(1.0, 0.95, 0.8), 2, PI_)
	_portal(r, Vector3(0.0, 0.0, 4.2), "밖으로 나가기", "나가기", Vector3(-262.0, 0.1, -320.6), PI_, "중앙 청사 앞", [], 1.8, "exit")
	_loot(r, Vector3(-4.6, 1.15, 2.2), "접수대 서랍의 지폐", "접수대 서랍에 방문객 안내비로 쓰는 지폐가 들어 있다.",
		[{"op": "give_item", "id": "won", "count": 40}], "pk_v23_lobby_cash")
	_examine(r, Vector3(4.6, 0.5, 1.4), "탁자 위 방문 기록부", "방문 기록부에는 지난 석 달간 단 두 줄만 적혀 있다. '시찰 보고 — 비서관', '수리 업자 — 비서관'.",
		[], "", 1.8)
	_indoor_patrol(r, "v23_in_guard1", "청사 경비", [Vector3(-5.0, 0.0, -2.5), Vector3(5.0, 0.0, -2.5), Vector3(5.0, 0.0, 0.5), Vector3(-5.0, 0.0, 0.5)], S_OFFICE)

	# 복도 (4 x 8)
	Kit.room(r, Vector3(0.0, 0.0, -9.0), 4.0, 8.0, h, fc, wc, cc, {"s": Vector2(0.0, 2.4), "n": Vector2(0.0, 2.4)})
	Kit.lamp(r, Vector3(0.0, h - 0.2, -9.0), 0.8, 8.0, warm)
	Kit.rug(r, Vector3(0.0, 0.02, -9.0), 2.0, 7.0, Color(0.5, 0.12, 0.12))

	# 집무실 (14 x 16) : 서쪽 비서실, 동쪽 회의실, 북쪽 잠긴 문
	Kit.room(r, Vector3(0.0, 0.0, -21.0), 14.0, 16.0, h, fc, wc, cc,
		{"s": Vector2(0.0, 2.4), "w": Vector2(0.0, 1.4), "e": Vector2(0.0, 1.4), "n": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(0.0, h - 0.2, -18.0), 1.2, 11.0, warm)
	Kit.lamp(r, Vector3(0.0, h - 0.2, -25.0), 1.0, 10.0, warm)
	Kit.rug(r, Vector3(0.0, 0.02, -22.0), 7.0, 8.0, Color(0.30, 0.14, 0.14))
	Kit.table(r, Vector3(0.0, 0.0, -25.0), 4.0, 1.4, 0.8, Color(0.30, 0.20, 0.14))
	Kit.chair(r, Vector3(0.0, 0.0, -26.4), 0.0, Color(0.20, 0.16, 0.16))
	Kit.chair(r, Vector3(-1.2, 0.0, -23.2), PI_, Color(0.26, 0.22, 0.2))
	Kit.chair(r, Vector3(1.2, 0.0, -23.2), PI_, Color(0.26, 0.22, 0.2))
	Kit.shelf(r, Vector3(-5.6, 0.0, -27.6), 0.0, 2.4, 2.2)
	Kit.shelf(r, Vector3(5.6, 0.0, -27.6), 0.0, 2.4, 2.2)
	# 벽의 큰 액자: 천으로 덮여 있어 보이지 않음
	Kit.box(r, Vector3(0.0, 2.0, -28.8), Vector3(3.0, 1.8, 0.08), Color(0.28, 0.26, 0.24), false, 2)
	_examine(r, Vector3(0.0, 0.2, -28.2), "천으로 덮인 큰 액자", "벽 한가운데 큰 액자가 천으로 덮여 있다. 안에 무엇이 있는지는 알 수 없고, 알 필요도 없어 보인다.", [], "", 1.8)
	_loot(r, Vector3(0.0, 0.95, -25.0), "책상 위 결재 문서철", "책상 위 문서철을 펼쳤다. 배급 감축 지시와 청사 수리비 지출이 같은 날짜로 적혀 있다. 이 방의 주인은 오늘 자리에 없다. (이 게임 속 가상의 문서)",
		[{"op": "give_item", "id": "doc_v23_decree"}, {"op": "v23_noise", "sev": 0.4}], "pk_v23_decree")
	_loot(r, Vector3(-5.6, 1.5, -27.2), "서가 속 현금 봉투", "서가 사이에 두툼한 봉투가 끼워져 있다.",
		[{"op": "give_item", "id": "won", "count": 200}], "pk_v23_study_cash")
	_loot(r, Vector3(5.6, 1.5, -27.2), "서가 속 훈장 상자", "상자 안에 번쩍이는 훈장이 가득하다. 하나쯤 없어져도 모를 것이다.",
		[{"op": "give_item", "id": "rare_medal"}], "pk_v23_medal")
	_examine(r, Vector3(-3.2, 0.5, -17.0), "벽에 걸린 구역 배치도", "청사와 사저, 지하로 이어지는 통로가 간단히 그려져 있다. 사저로 가는 문은 집무실 뒤쪽, 책장이 있는 서재는 사저 동쪽이다.",
		[{"op": "set_flag", "key": "v23_hint_shelf"}], "", 1.8)
	_indoor_patrol(r, "v23_in_guard2", "집무동 경비", [Vector3(-5.0, 0.0, -16.0), Vector3(5.0, 0.0, -16.0), Vector3(5.0, 0.0, -21.0), Vector3(-5.0, 0.0, -21.0)], S_OFFICE)

	# 비서실 (서쪽, 9 x 8)
	Kit.room(r, Vector3(-11.5, 0.0, -21.0), 9.0, 8.0, h, fc, wc, cc, {"e": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(-11.5, h - 0.2, -21.0), 0.9, 8.0, warm)
	Kit.table(r, Vector3(-12.5, 0.0, -23.0), 2.4, 1.0, 0.8, Color(0.32, 0.24, 0.18))
	Kit.chair(r, Vector3(-12.5, 0.0, -21.8), PI_, Color(0.24, 0.2, 0.18))
	Kit.shelf(r, Vector3(-15.2, 0.0, -19.0), PI_ * 0.5, 2.0, 2.0)
	Kit.crate(r, Vector3(-9.0, 0.0, -24.0), Vector3(1.0, 1.0, 1.0), Color(0.36, 0.3, 0.24))
	_loot(r, Vector3(-12.5, 0.95, -23.0), "서랍 속 사저 열쇠", "잠기지 않은 서랍 안쪽에 작은 열쇠가 들어 있다. 꼬리표에 '사저'라고 적혀 있다. 비서관이 이쪽을 보지 않는 동안 챙겼다.",
		[{"op": "give_item", "id": "v23_res_key"}, _quest(3), {"op": "v23_noise", "sev": 0.6}], "pk_v23_aide_key")
	_loot(r, Vector3(-9.0, 1.2, -24.0), "상자 속 비상 약품", "청사 상비약 상자다. 쓸 만한 약품이 들어 있다.",
		[{"op": "give_item", "id": "medicine"}], "pk_v23_med")

	# 회의실 (동쪽, 9 x 8)
	Kit.room(r, Vector3(11.5, 0.0, -21.0), 9.0, 8.0, h, fc, wc, cc, {"w": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(11.5, h - 0.2, -21.0), 0.9, 8.0, warm)
	Kit.table(r, Vector3(11.5, 0.0, -21.0), 5.0, 1.8, 0.8, Color(0.30, 0.22, 0.16))
	for cx in [-1.6, 0.0, 1.6]:
		Kit.chair(r, Vector3(11.5 + cx, 0.0, -19.4), PI_, Color(0.26, 0.22, 0.2))
		Kit.chair(r, Vector3(11.5 + cx, 0.0, -22.6), 0.0, Color(0.26, 0.22, 0.2))
	_loot(r, Vector3(14.3, 0.95, -21.0), "회의 탁자 서랍의 빈 용지", "회의 탁자 서랍에 도장이 찍히지 않은 용지 묶음이 들어 있다. 위조에 쓸 수 있겠다.",
		[{"op": "give_item", "id": "forged_blank"}], "pk_v23_blank")
	_examine(r, Vector3(11.5, 0.9, -21.0), "탁자 위 회의록", "회의록의 마지막 줄: '다음 회의 — 지도자 불참. 비서관이 대신 서명.' 이 청사는 오래전부터 주인 없이 돌아가는 듯하다.", [], "", 1.9)

	# 사저 통로 (3 x 8) : 열쇠로 잠긴 문
	Kit.room(r, Vector3(0.0, 0.0, -33.0), 3.0, 8.0, h, fc, wc, cc, {"s": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(0.0, h - 0.2, -33.0), 0.7, 7.0, warm)
	_door(r, Vector3(-0.7, 0.0, -29.0), 0.0, "v23_res_door", "v23_res_key", "사저로 가는 문이 잠겨 있다. 비서실 서랍의 열쇠가 필요하다.")
	Kit.label(r, Vector3(0.0, 2.4, -36.7), "사저 (관계자 외 출입 금지)", 0.4, Color(1.0, 0.85, 0.7), 2)
	_portal(r, Vector3(0.0, 0.0, -35.4), "사저로 이어지는 통로", "들어가기", _origin(S_RESIDENCE) + Vector3(0.0, 0.1, 2.6), 0.0, "사저", [_quest(4)], 1.8, "portal")


# ================================================================ 칸 14: 사저 + 지하 대피소

func _build_residence() -> void:
	var r: Node3D = _slot_root(S_RESIDENCE, "V23_Int_Residence")
	_r_res = r
	var wc: Color = Color(0.78, 0.72, 0.62)
	var fc: Color = Color(0.40, 0.30, 0.22)
	var cc: Color = Color(0.86, 0.84, 0.80)
	var h: float = 3.2
	var warm: Color = Color(1.0, 0.90, 0.72)

	# 현관 (10 x 8)
	Kit.room(r, Vector3(0.0, 0.0, 0.0), 10.0, 8.0, h, fc, wc, cc, {"n": Vector2(0.0, 2.0)})
	Kit.lamp(r, Vector3(0.0, h - 0.2, 0.0), 1.0, 8.0, warm)
	Kit.rug(r, Vector3(0.0, 0.02, 0.0), 3.0, 6.0, Color(0.42, 0.18, 0.16))
	_portal(r, Vector3(0.0, 0.0, 3.2), "사저 정문으로 나가기", "나가기", Vector3(-212.0, 0.1, -345.4), PI_, "중앙 청사 구역", [], 1.8, "exit")
	_portal(r, Vector3(-4.2, 0.0, 0.0), "청사로 이어지는 통로", "돌아가기", _origin(S_OFFICE) + Vector3(0.0, 0.1, -34.2), PI_, "중앙 청사", [], 1.6, "portal")
	Kit.box(r, Vector3(-4.85, 1.1, 0.0), Vector3(0.1, 2.2, 1.2), Color(0.30, 0.24, 0.18), false, 2)

	# 거실 (12 x 12)
	Kit.room(r, Vector3(0.0, 0.0, -10.0), 12.0, 12.0, h, fc, wc, cc,
		{"s": Vector2(0.0, 2.0), "w": Vector2(0.0, 1.4), "e": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(-2.5, h - 0.2, -10.0), 1.1, 10.0, warm)
	Kit.lamp(r, Vector3(2.5, h - 0.2, -10.0), 1.1, 10.0, warm)
	Kit.rug(r, Vector3(0.0, 0.02, -10.0), 7.0, 6.0, Color(0.36, 0.20, 0.20))
	Kit.sofa(r, Vector3(-3.0, 0.0, -13.4), 0.0, Color(0.36, 0.26, 0.22))
	Kit.sofa(r, Vector3(0.0, 0.0, -7.2), PI_, Color(0.36, 0.26, 0.22))
	Kit.table(r, Vector3(-1.0, 0.0, -10.2), 2.4, 1.0, 0.5, Color(0.30, 0.22, 0.16))
	Kit.shelf(r, Vector3(4.6, 0.0, -15.4), 0.0, 2.2, 2.0)
	Kit.box(r, Vector3(-5.9, 1.9, -10.0), Vector3(0.1, 1.3, 3.0), Color(0.3, 0.34, 0.4), false, 2, 0.4)
	_loot(r, Vector3(4.6, 1.5, -15.0), "장식장 속 사탕 상자", "고급 사탕 상자가 장식용으로 놓여 있다. 아무도 뜯지 않은 듯하다.",
		[{"op": "give_item", "id": "gift_sweets"}], "pk_v23_sweets")
	_examine(r, Vector3(-3.0, 0.6, -13.4), "소파 위 담요", "곱게 개어 둔 담요에서 오래 쓰지 않은 방 냄새가 난다. 누군가 이 집에서 살고는 있는 걸까.", [], "", 1.8)
	_indoor_patrol(r, "v23_in_guard3", "사저 경비", [Vector3(-3.5, 0.0, -6.0), Vector3(3.5, 0.0, -6.0), Vector3(3.5, 0.0, -13.0), Vector3(-3.5, 0.0, -13.0)], S_RESIDENCE)

	# 침실 (서쪽, 9 x 8)
	Kit.room(r, Vector3(-10.5, 0.0, -10.0), 9.0, 8.0, h, fc, wc, cc, {"e": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(-10.5, h - 0.2, -10.0), 0.9, 8.0, warm)
	Kit.bed(r, Vector3(-13.0, 0.0, -10.0), PI_ * 0.5, Color(0.40, 0.30, 0.34))
	Kit.table(r, Vector3(-13.6, 0.0, -7.6), 1.0, 0.6, 0.6, Color(0.30, 0.22, 0.16))
	Kit.shelf(r, Vector3(-9.0, 0.0, -13.7), 0.0, 2.2, 2.2)
	_loot(r, Vector3(-9.0, 1.5, -13.3), "옷장 속 낡은 손목시계", "옷장 선반 안쪽에 아직 가는 손목시계가 놓여 있다.",
		[{"op": "give_item", "id": "old_watch"}], "pk_v23_watch")
	_loot(r, Vector3(-13.6, 0.7, -7.6), "침대 옆 약품", "침대 옆 탁자의 약통에 상비약이 남아 있다.",
		[{"op": "give_item", "id": "medicine"}], "pk_v23_bed_med")
	_examine(r, Vector3(-13.0, 0.6, -10.0), "정돈된 침대", "침대는 빈틈없이 정돈되어 있다. 베개에 눌린 자국이 없다. 이 방의 주인은 오래 돌아오지 않은 것 같다.", [], "", 1.9)

	# 서재 (동쪽, 9 x 8). 북쪽 벽 오른쪽에 숨겨진 길 (책장이 가림)
	Kit.room(r, Vector3(10.5, 0.0, -10.0), 9.0, 8.0, h, fc, wc, cc, {"w": Vector2(0.0, 1.4), "n": Vector2(2.0, 1.6)})
	Kit.lamp(r, Vector3(10.5, h - 0.2, -10.0), 0.9, 8.0, warm)
	Kit.table(r, Vector3(10.5, 0.0, -8.4), 2.6, 1.1, 0.8, Color(0.30, 0.20, 0.14))
	Kit.chair(r, Vector3(10.5, 0.0, -7.0), PI_, Color(0.24, 0.2, 0.18))
	Kit.shelf(r, Vector3(8.2, 0.0, -13.7), 0.0, 1.8, 2.2)
	Kit.shelf(r, Vector3(14.8, 0.0, -13.7), 0.0, 1.8, 2.2)
	var hidden = Kit.box(r, Vector3(12.5, 1.1, -13.6), Vector3(1.8, 2.2, 0.5), Color(0.40, 0.28, 0.18), true, 2)
	hidden.add_to_group("reveal_v23_shelf")
	Kit.box(r, Vector3(12.5, 1.9, -13.3), Vector3(1.5, 0.12, 0.1), Color(0.55, 0.42, 0.28), false, 2)
	Kit.box(r, Vector3(12.5, 1.2, -13.3), Vector3(1.5, 0.12, 0.1), Color(0.55, 0.42, 0.28), false, 2)
	_examine(r, Vector3(12.5, 0.6, -13.0), "먼지 없는 책장의 닳은 책", "다른 책장은 먼지가 두껍게 앉았는데 이 책장만 깨끗하다. 닳은 책 한 권을 당기자 책장 뒤에서 낮은 소리가 났다. 책장이 옆으로 밀려난다!",
		[{"op": "set_flag", "key": "v23_shelf_open"}, {"op": "reveal", "id": "v23_shelf"}, _quest(5), {"op": "toast", "text": "책장 뒤에 숨겨진 길이 열렸다."}],
		"v23_shelf_open", 1.8, "v23_shelf_open")
	_examine(r, Vector3(10.5, 0.9, -8.4), "서재 책상 위 메모", "메모에는 숫자와 날짜만 빼곡하다. 맨 아래 한 줄: '아래층은 필요할 때만. 열쇠는 비서관.' 낙서처럼 급히 쓴 글씨다.", [], "", 1.9)

	# 숨겨진 통로 (3 x 8) + 지하 대피소 (10 x 8)
	Kit.room(r, Vector3(12.5, 0.0, -18.0), 3.0, 8.0, h, Color(0.26, 0.26, 0.27), Color(0.34, 0.34, 0.33), Color(0.26, 0.26, 0.27), {"s": Vector2(0.0, 1.6), "n": Vector2(0.0, 1.6)})
	Kit.lamp(r, Vector3(12.5, h - 0.2, -18.0), 0.7, 7.0, Color(1.0, 0.82, 0.55))
	Kit.room(r, Vector3(12.5, 0.0, -26.0), 10.0, 8.0, h, Color(0.26, 0.26, 0.27), Color(0.34, 0.34, 0.33), Color(0.26, 0.26, 0.27), {"s": Vector2(0.0, 1.6)})
	Kit.lamp(r, Vector3(12.5, h - 0.2, -26.0), 1.0, 9.0, Color(0.85, 0.95, 1.0))
	Kit.table(r, Vector3(12.5, 0.0, -27.5), 2.6, 1.0, 0.8, Color(0.28, 0.28, 0.32))
	for i in range(4):
		Kit.box(r, Vector3(16.8, 0.5 + float(i) * 0.6, -28.6), Vector3(1.6, 0.5, 0.5), Color(0.45, 0.4, 0.3))
	Kit.crate(r, Vector3(8.6, 0.0, -28.4), Vector3(1.0, 1.0, 1.0), Color(0.34, 0.38, 0.28))
	Kit.label(r, Vector3(12.5, 2.4, -29.7), "지하 대피소 (가상)", 0.5, Color(0.9, 0.9, 1.0), 2)
	_loot(r, Vector3(12.5, 0.95, -27.5), "책상 위 비공개 지출 장부", "장부를 넘기자 사치품 수입 내역과 배급 삭감 기록이 같은 달에 나란히 적혀 있다. 이 한 권이면 충분하다. (이 게임 속 가상의 문서)",
		[{"op": "give_item", "id": "doc_v23_ledger"}, _quest(6)], "pk_v23_ledger")
	_loot(r, Vector3(16.8, 1.0, -26.4), "금속 상자 속 비상금", "비상금으로 쌓아 둔 지폐 뭉치가 들어 있다.",
		[{"op": "give_item", "id": "won", "count": 250}], "pk_v23_bunker_cash")
	_loot(r, Vector3(8.6, 1.2, -28.4), "상자 속 비상 식량", "비상 식량 상자다. 오래 버틸 수 있는 양이다.",
		[{"op": "give_item", "id": "food_ration", "count": 3}], "pk_v23_bunker_food")
	# 비상 갱도 출구 (서쪽 벽): 빗장을 풀면 바깥에서도 드나들 수 있다
	Kit.box(r, Vector3(7.6, 1.1, -26.0), Vector3(0.1, 2.2, 1.6), Color(0.30, 0.26, 0.22), false, 2)
	_portal(r, Vector3(8.4, 0.0, -26.0), "비상 갱도로 빠져나가기", "빠져나가기", Vector3(-317.5, 0.1, -335.0), PI_ * 0.5, "중앙 청사 담 바깥",
		[{"op": "set_flag", "key": "v23_bunker_open"}, {"op": "toast", "text": "담 바깥 갱도 출구가 열렸다."}], 1.7, "exit")


func _spawn_inner_npcs() -> void:
	for cfg in VNpcs3.all():
		var slot: int = int(cfg["slot"])
		var parent: Node3D = _r_office if slot == S_OFFICE else _r_res
		if parent == null:
			continue
		var at: Vector3 = cfg["at"]
		_make_npc(cfg, parent, at, float(cfg.get("yaw_deg", 0.0)), false)


# ================================================================ 효과 / 진행

func on_effect(op: String, e: Dictionary) -> bool:
	match op:
		"v23_noise":
			var v1 = hub.get("v1")
			if v1 != null and v1.alert != null:
				v1.alert.report("trespass", hub.player.global_position, float(e.get("sev", 0.4)), null)
			return true
	return false


func apply_world_flags() -> void:
	if hub == null:
		return
	if hub.game.get_flag("v23_shelf_open"):
		hub._reveal("v23_shelf")


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	if hub == null or hub.player == null or hub.game == null:
		return
	_progress()


func _progress() -> void:
	var g = hub.game
	var st_state: String = g.quest_state(QID)
	if st_state == "inactive":
		if g.get_flag("passed_north") or g.has_item("pass_special"):
			if g.start_quest(QID):
				hub.toast("새 임무: " + g.quest_title(QID))
		return
	if st_state != "active":
		return
	if g.get_flag("passed_leader"):
		g.set_quest_step(QID, 1)
	var py: float = hub.player.global_position.y
	if int(g.quest_step(QID)) >= 6 and g.has_item("doc_v23_ledger") and py < 100.0:
		var gp: Vector3 = hub.player.global_position
		# 담 안쪽(청사 구역)이 아니라 바깥 갱도로 나왔거나, 정문 밖으로 나온 때에 완료
		var inside: bool = gp.x > X0 and gp.x < X1 and gp.z > Z0 and gp.z < GATE_Z
		if not inside:
			hub._complete_quest(QID)
			g.set_flag("v23_done", true)
			g.add_item("won", 250)
			hub.toast("잠입 성공! 사저의 장부를 손에 넣었다 (+250원)")


## 목표 안내 문장과 방향 (주 임무 q_v22_pass 가 끝났거나 없을 때 매니저가 부름)
func objective() -> Dictionary:
	var g = hub.game
	if g.quest_state(QID) != "active":
		return {}
	var st: int = int(g.quest_step(QID))
	var line: String = "%s: %s" % [g.quest_title(QID), g.quest_step_text(QID)]
	var out: Dictionary = {"text": line}
	if hub.player.global_position.y > 100.0:
		return out
	var tgt: Vector3 = Vector3.ZERO
	var has: bool = true
	match st:
		0, 1:
			tgt = Vector3(GATE_X, 0.0, GATE_Z + 6.0)
		2:
			tgt = OFFICE_DOOR
		3:
			tgt = OFFICE_DOOR
		4, 5:
			tgt = RES_DOOR
		6:
			tgt = BUNKER_OUT
		_:
			has = false
	if has:
		out["pos"] = tgt
	return out
