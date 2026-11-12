extends Node
## V2.3 자체 점검. 게임이 켜진 뒤 한 번, 게임 상태를 바꾸지 않고 읽기만 하면서 점검합니다.
##  - 모듈이 만들어졌는지, 검문소/구역/NPC 수, 대화·임무·아이템 데이터의 오타,
##  - 모든 이동 지점(출입구/사다리/맨홀 등)의 도착 자리에 바닥이 있는지, 벽 안에 끼지 않는지 (실내에서 나올 때 추락 진단)
## 결과: 화면 위쪽에 잠시 표시 + 로그 출력 + user://v22_selftest.txt 저장.
## 이 파일 자체도 Godot 에서 실행해 본 적이 없습니다. 점검 결과가 곧 첫 실행 기록입니다. (Godot 실행 미검증)

const Flags = preload("res://scripts/data/feature_flags.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const ItemData = preload("res://scripts/data/item_data.gd")
const QuestData = preload("res://scripts/data/quest_data.gd")
const VNpcs = preload("res://scripts/v22/v22_npcs.gd")
const VNpcs3 = preload("res://scripts/v23/v23_npcs.gd")

const VERSION: String = "V3.0"
const START_DELAY: float = 9.0
const SHOW_SECONDS: float = 40.0
const KNOWN_OPS: Array = ["set_flag", "give_item", "take_item", "quest_start", "quest_step", "quest_complete", "toast",
	"unlock_door", "open_door", "reveal", "trust"]
const KNOWN_COND: Array = ["flag", "not_flag", "item", "not_item", "item_min", "quest", "state", "step", "min_step", "night"]

var hub = null
var mgr = null
var lines: Array = []
var n_ok: int = 0
var n_warn: int = 0
var n_fail: int = 0
var finished: bool = false

var _t: float = 0.0
var _started: bool = false
var _layer: CanvasLayer = null
var _label: Label = null
var _show_left: float = 0.0


func setup(p_hub, p_mgr) -> void:
	hub = p_hub
	mgr = p_mgr


func _process(delta: float) -> void:
	if finished:
		if _show_left > 0.0:
			_show_left -= delta
			if _show_left <= 0.0 and _layer != null:
				_layer.visible = false
		return
	_t += delta
	if _t < START_DELAY or _started:
		return
	if hub == null or hub.player == null or hub.game == null or mgr == null:
		return
	_started = true
	_run()


# ---------------------------------------------------------------- 기록 도우미

func _ok(msg: String) -> void:
	n_ok += 1
	lines.append("[OK] " + msg)


func _warn(msg: String) -> void:
	n_warn += 1
	lines.append("[주의] " + msg)


func _fail(msg: String) -> void:
	n_fail += 1
	lines.append("[실패] " + msg)


func _check(cond: bool, ok_msg: String, bad_msg: String, as_fail: bool = true) -> bool:
	if cond:
		_ok(ok_msg)
	elif as_fail:
		_fail(bad_msg)
	else:
		_warn(bad_msg)
	return cond


# ---------------------------------------------------------------- 점검 본체

func _run() -> void:
	lines.append("PROJECT PYONGYANG 자체 점검 %s" % VERSION)
	_check_modules()
	_check_gates()
	_check_data()
	_check_npc_dialogues()
	_check_portals()
	_check_doors_and_npcs()
	if mgr.v3 != null:
		var t3 = load("res://scripts/v3/v3_selftest.gd")
		if t3 != null and t3.can_instantiate():
			var inst = t3.new()
			inst.run(self)
		else:
			_warn("V3.0 자체 점검 파일을 불러오지 못했습니다")
	finished = true
	var summary: String = "자체 점검 %s: 통과 %d / 주의 %d / 실패 %d" % [VERSION, n_ok, n_warn, n_fail]
	lines.append(summary)
	_save_and_show(summary)


func _check_modules() -> void:
	_check(mgr.pass_sys != null, "통행증 시스템 켜짐", "통행증 시스템이 없습니다 (불러오기 실패 가능)", Flags.V22_PASS)
	_check(mgr.social != null, "NPC 상호작용 켜짐", "NPC 상호작용이 없습니다", Flags.V22_SOCIAL)
	if mgr.vworld != null:
		_check(bool(mgr.vworld.done), "새 지역 만들기 끝남 (지역 %d곳)" % mgr.vworld.regions.size(), "새 지역 만들기가 끝나지 않았습니다")
		_check(int(mgr.vworld.walls_moved) >= 4, "경계 벽 이동 %d개" % int(mgr.vworld.walls_moved), "경계 벽을 %d개만 찾았습니다 (새 지역에 못 갈 수 있음)" % int(mgr.vworld.walls_moved))
	else:
		_check(not Flags.V22_WORLD, "새 지역 꺼짐(설정)", "새 지역 모듈이 없습니다")
	if mgr.interiors != null:
		_check(bool(mgr.interiors.done), "새 실내 3곳 만들기 끝남", "새 실내 만들기가 끝나지 않았습니다")
	else:
		_check(not Flags.V22_INTERIORS, "새 실내 꺼짐(설정)", "새 실내 모듈이 없습니다")
	if Flags.V23_LEADER:
		_check(mgr.v23 != null and bool(mgr.v23.done), "중앙 청사/사저 만들기 끝남", "중앙 청사/사저 모듈이 없거나 끝나지 않았습니다")
	_check(mgr.audio != null, "소리 모듈 켜짐", "소리 모듈이 없습니다", false)
	_check(hub.game.pois.size() > 0, "장소 표식 %d개" % hub.game.pois.size(), "장소 표식이 없습니다", false)


func _check_gates() -> void:
	if mgr.pass_sys == null:
		return
	for gid in ["north", "base", "leader"]:
		if gid == "leader" and not Flags.V23_LEADER:
			continue
		if not mgr.pass_sys.gates.has(gid):
			_fail("검문소 '%s' 가 등록되지 않았습니다" % gid)
			continue
		var g: Dictionary = mgr.pass_sys.gates[gid]
		var body = g["body"]
		var guards: Array = g["guards"]
		var valid_guards: int = 0
		for n in guards:
			if is_instance_valid(n):
				valid_guards += 1
		_check(body != null and is_instance_valid(body) and valid_guards >= 1, "검문소 %s: 차단기와 경비 %d명" % [gid, valid_guards], "검문소 %s: 차단기 또는 경비가 없습니다 (경비 %d명)" % [gid, valid_guards])


func _check_data() -> void:
	for qid in ["q_v22_pass", "q_v22_market", "q_v22_ruins", "q_v22_river", "q_v22_slum", "q_v23_leader"]:
		if not QuestData.QUESTS.has(qid):
			if qid == "q_v23_leader" and not Flags.V23_LEADER:
				continue
			_fail("임무 데이터 없음: " + qid)
			continue
		var q: Dictionary = QuestData.QUESTS[qid]
		var steps: Array = q.get("steps", [])
		_check(steps.size() > 0, "임무 %s: 단계 %d개" % [qid, steps.size()], "임무 %s: 단계가 없습니다" % qid)
		for it in q.get("reward_items", []):
			if not ItemData.ITEMS.has(str(it)):
				_fail("임무 %s 보상 아이템이 없습니다: %s" % [qid, str(it)])
	var missing: Array = []
	for id in ["won", "pass_general", "pass_special", "pass_temp", "pass_forged", "forged_blank", "forge_ink", "old_stamp",
			"food_ration", "medicine", "radio_part", "scrap", "old_watch", "rare_medal", "old_key", "mole_token",
			"clue_a", "clue_b", "clue_c", "doc_shipping", "doc_roster", "doc_orders", "doc_tunnel_map", "base_keycard",
			"v23_res_key", "doc_v23_decree", "doc_v23_ledger", "gift_sweets", "gift_tea"]:
		if not ItemData.ITEMS.has(id):
			missing.append(id)
	_check(missing.is_empty(), "아이템 데이터 29종 확인", "아이템 데이터가 없습니다: " + ", ".join(missing))


func _check_npc_dialogues() -> void:
	var all_npcs: Array = []
	all_npcs.append_array(VNpcs.all())
	all_npcs.append_array(VNpcs3.all())
	var bad: int = 0
	var checked: int = 0
	for cfg in all_npcs:
		var d = cfg.get("dialogue", {})
		if not (d is Dictionary) or d.is_empty():
			continue
		checked += 1
		var nid: String = str(cfg.get("id", "?"))
		if not d.has("start"):
			_fail("대화 %s: start 노드가 없습니다" % nid)
			bad += 1
			continue
		for k in d.keys():
			if str(k) == "entry":
				for en in d[k]:
					if not d.has(str(en.get("node", ""))):
						_fail("대화 %s: entry 노드 없음 %s" % [nid, str(en.get("node", ""))])
						bad += 1
				continue
			var nd: Dictionary = d[k]
			var txt: String = str(nd.get("text", ""))
			if txt.length() > 150:
				_warn("대화 %s:%s 본문이 깁니다 (%d자, 화면에서 잘릴 수 있음)" % [nid, str(k), txt.length()])
			bad += _check_effects(nd.get("effects", []), nid + ":" + str(k))
			var ch: Array = nd.get("choices", [])
			if ch.size() > 4:
				_fail("대화 %s:%s 선택지가 %d개 (최대 4개)" % [nid, str(k), ch.size()])
				bad += 1
			if ch.is_empty() and not nd.has("next"):
				_fail("대화 %s:%s 끝이 막혔습니다 (선택지도 next도 없음)" % [nid, str(k)])
				bad += 1
			for c in ch:
				var nx: String = str(c.get("next", ""))
				if nx != "" and not d.has(nx) and not nx.begins_with("v22_"):
					_fail("대화 %s:%s 선택지가 없는 노드를 가리킵니다: %s" % [nid, str(k), nx])
					bad += 1
				if str(c.get("label", "")).length() > 9:
					_warn("대화 %s:%s 선택지 라벨이 깁니다: %s" % [nid, str(k), str(c.get("label", ""))])
				bad += _check_effects(c.get("effects", []), nid + ":" + str(k))
	if bad == 0:
		_ok("NPC 대화 %d개 구조 점검 (노드 연결, 아이템/임무 이름)" % checked)


func _check_effects(effs, where: String) -> int:
	var bad: int = 0
	for e in effs:
		var op: String = str(e.get("op", ""))
		if not (op in KNOWN_OPS) and not op.begins_with("v22_") and not op.begins_with("v23_") and not op.begins_with("v3_"):
			_fail("효과 %s: 알 수 없는 연산 %s" % [where, op])
			bad += 1
		if op == "give_item" or op == "take_item":
			if not ItemData.ITEMS.has(str(e.get("id", ""))):
				_fail("효과 %s: 없는 아이템 %s" % [where, str(e.get("id", ""))])
				bad += 1
		if op == "quest_step" or op == "quest_start" or op == "quest_complete":
			if not QuestData.QUESTS.has(str(e.get("id", ""))):
				_fail("효과 %s: 없는 임무 %s" % [where, str(e.get("id", ""))])
				bad += 1
	return bad


## 모든 이동 지점의 도착 자리를 점검. 실내에서 나올 때 떨어지는 문제를 진단하는 핵심 항목
func _check_portals() -> void:
	var w3d: World3D = hub.player.get_world_3d()
	if w3d == null:
		_fail("월드를 얻지 못해 이동 지점 점검을 건너뜁니다")
		return
	var space: PhysicsDirectSpaceState3D = w3d.direct_space_state
	var total: int = 0
	var outdoor_total: int = 0
	var raw_no_ground: int = 0
	var fixed_ok: int = 0
	var blocked: int = 0
	var indoor_bad: int = 0
	for it in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(it):
			continue
		var data = it.data
		if not (data is Dictionary) or not data.has("dest"):
			continue
		var dest = data["dest"]
		if not (dest is Vector3):
			continue
		var dv: Vector3 = dest
		total += 1
		var label: String = "%s (%s)" % [str(it.prompt), str(data.get("location", ""))]
		var req = data.get("requires")
		if req is Dictionary and req.has("item") and not ItemData.ITEMS.has(str(req["item"])):
			_fail("이동 지점 '%s': 필요한 아이템 이름이 없습니다 (%s)" % [label, str(req["item"])])
		if dv.y < 100.0:
			outdoor_total += 1
			# 바깥 도착: 원래 좌표에 바닥이 있는지 / 매니저가 고른 안전 좌표가 바닥 위인지
			var q = PhysicsRayQueryParameters3D.create(Vector3(dv.x, maxf(3.0, dv.y + 2.0), dv.z), Vector3(dv.x, -6.0, dv.z), 1)
			q.exclude = [hub.player.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				raw_no_ground += 1
				lines.append("[참고] 바깥 도착 좌표에 바닥이 없습니다: %s %s" % [label, str(dv)])
			var safe: Vector3 = mgr.safe_outdoor_pos(dv)
			var q2 = PhysicsRayQueryParameters3D.create(safe + Vector3(0.0, 1.0, 0.0), safe + Vector3(0.0, -2.0, 0.0), 1)
			q2.exclude = [hub.player.get_rid()]
			var hit2: Dictionary = space.intersect_ray(q2)
			if hit2.is_empty():
				_fail("이동 지점 '%s': 안전 좌표 %s 아래에 바닥이 없습니다 (떨어질 수 있음)" % [label, str(safe)])
			else:
				fixed_ok += 1
			if not Placement.is_free_capsule(w3d, Vector3(safe.x, safe.y, safe.z), 0.4, 1.8):
				blocked += 1
				_warn("이동 지점 '%s': 도착 자리가 물체와 겹칩니다 %s" % [label, str(safe)])
		else:
			# 실내 도착: 바닥 위에 서고 벽에 끼지 않는지
			var qi = PhysicsRayQueryParameters3D.create(dv + Vector3(0.0, 1.5, 0.0), dv + Vector3(0.0, -2.0, 0.0), 1)
			qi.exclude = [hub.player.get_rid()]
			var hi: Dictionary = space.intersect_ray(qi)
			if hi.is_empty():
				indoor_bad += 1
				_fail("이동 지점 '%s': 실내 도착 %s 아래에 바닥이 없습니다" % [label, str(dv)])
			else:
				var hp: Vector3 = hi["position"]
				if absf(hp.y - dv.y) > 0.8:
					_warn("이동 지점 '%s': 도착 높이와 바닥 높이가 다릅니다 (바닥 %.2f, 도착 %.2f)" % [label, hp.y, dv.y])
			if not Placement.is_free_capsule(w3d, dv + Vector3(0.0, 0.05, 0.0), 0.4, 1.8):
				_warn("이동 지점 '%s': 실내 도착 자리가 물체와 겹칩니다 %s" % [label, str(dv)])
	_check(total > 0, "이동 지점 %d곳 점검" % total, "이동 지점을 하나도 찾지 못했습니다", false)
	lines.append("[요약] 바깥 도착 %d곳: 원래 좌표에 바닥 없음 %d / 안전 좌표 바닥 확인 %d / 겹침 %d. 실내 도착 문제 %d" % [
		outdoor_total, raw_no_ground, fixed_ok, blocked, indoor_bad])


func _check_doors_and_npcs() -> void:
	var doors: Array = get_tree().get_nodes_in_group("doors")
	var bad_keys: int = 0
	for d in doors:
		if is_instance_valid(d) and str(d.key_item) != "" and not ItemData.ITEMS.has(str(d.key_item)):
			_fail("문 %s: 열쇠 아이템 이름이 없습니다 (%s)" % [str(d.door_id), str(d.key_item)])
			bad_keys += 1
	if bad_keys == 0:
		_ok("문 %d개의 열쇠 이름 확인" % doors.size())
	var npcs: Array = get_tree().get_nodes_in_group("npcs")
	var fallen: int = 0
	for n in npcs:
		if is_instance_valid(n):
			var y: float = n.global_position.y
			if y < -3.0 or (y > 100.0 and y < 292.0):
				fallen += 1
				lines.append("[참고] 떨어진 것 같은 NPC: %s (y=%.1f)" % [str(n.npc_id), y])
	_check(fallen == 0, "NPC %d명 모두 정상 높이" % npcs.size(), "NPC %d명이 비정상 높이에 있습니다" % fallen, false)
	var p: Vector3 = hub.player.global_position
	_check(p.y > -3.0, "플레이어 높이 정상 (y=%.1f)" % p.y, "플레이어가 아래로 떨어졌습니다 (y=%.1f)" % p.y)


# ---------------------------------------------------------------- 결과 저장 / 표시

func _save_and_show(summary: String) -> void:
	var text: String = "\n".join(PackedStringArray(lines))
	print("[PYONGYANG] " + summary)
	for l in lines:
		if str(l).begins_with("[실패]") or str(l).begins_with("[주의]"):
			print("[PYONGYANG] " + str(l))
	var f = FileAccess.open("user://v22_selftest.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
		f.close()
	else:
		push_warning("자체 점검 결과 파일을 쓰지 못했습니다.")
	hub.toast(summary)
	# 화면 표시 (실패/주의 먼저, 최대 14줄). 스크린샷으로 확인할 수 있게 40초간 보입니다.
	var show: Array = [summary]
	for l in lines:
		var s: String = str(l)
		if s.begins_with("[실패]"):
			show.append(s)
	for l2 in lines:
		var s2: String = str(l2)
		if s2.begins_with("[주의]") or s2.begins_with("[참고]"):
			show.append(s2)
	for l3 in lines:
		var s3: String = str(l3)
		if s3.begins_with("[요약]"):
			show.append(s3)
	if show.size() > 15:
		show = show.slice(0, 15)
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.62)
	bg.position = Vector2(8, 60)
	bg.size = Vector2(760, 24.0 * float(show.size()) + 14.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bg)
	_label = Label.new()
	_label.text = "\n".join(PackedStringArray(show))
	_label.position = Vector2(16, 66)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85) if n_fail == 0 else Color(1.0, 0.8, 0.75))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_label)
	_show_left = SHOW_SECONDS
