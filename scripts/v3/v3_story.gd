extends Node
## V3.0 스토리 캠페인 (ACT 1~4). 기존 V2.x 진행 상태(통행증, 검문소, 청사 잠입, 장부)를 읽어 단계를 정하고,
## 장부를 들고 집무실에 들어가면 지도자와 대면하는 장면 → 선택에 따른 권력 승계 장면으로 이어진다.
## 모든 인물과 사건은 가상의 게임 설정이며 실제 사건을 재현하지 않는다. (Godot 실행 미검증)
##
##  ACT 1  평양 잠입      : 도시 탐험, 정보 수집, 통행증, 검문소 (q_v22_pass)
##  ACT 2  도시의 비밀    : 통제구역, 중앙 청사/사저 잠입, 장부 확보 (q_v23_leader)
##  ACT 3  최고지도자 관저 : 장부를 들고 집무실로 → 지도자와 대면 (이 파일)
##  ACT 4  권력 승계      : 선택(공개 개혁 / 군부 합의 / 조용한 거래 / 유언 승계) → 지도자 모드 (이 파일)

const Flags = preload("res://scripts/data/feature_flags.gd")
const D = preload("res://scripts/v3/v3_data.gd")
const NpcScript = preload("res://scripts/npc/npc.gd")
const VNpcs3 = preload("res://scripts/v23/v23_npcs.gd")

const QID: String = "q_v3_story"
const SLOT: float = 100.0
const BASE_Y: float = 300.0
const S_OFFICE: int = 13
const GATE_POS: Vector3 = Vector3(-245.0, 0.0, -284.0)
const OFFICE_DOOR: Vector3 = Vector3(-262.0, 0.0, -322.4)

var hub = null
var mgr = null
var man = null

var leader_npc = null
var busy: bool = false
var support: Dictionary = {"people": 0, "army": 0, "court": 0}
var _t1: float = 0.0
var _t2: float = 0.0


func setup(hub_ref, mgr_ref, man_ref) -> void:
	hub = hub_ref
	mgr = mgr_ref
	man = man_ref


func office_origin() -> Vector3:
	return Vector3(float(S_OFFICE) * SLOT, BASE_Y, 0.0)


# ================================================================ 단계(막) 계산

func step_target() -> int:
	var g = hub.game
	if man.is_leader:
		return 5
	var s: int = 0
	if g.get_flag("passed_north") or g.has_item("pass_special"):
		s = 1
	var qs: String = g.quest_state("q_v23_leader")
	if qs == "done" or (qs == "active" and g.quest_step("q_v23_leader") >= 2):
		s = maxi(s, 2)
	if g.has_item("doc_v23_ledger"):
		s = maxi(s, 3)
	if g.get_flag("v3_confront_seen"):
		s = maxi(s, 4)
	return s


func current_act() -> int:
	if man.is_leader:
		return 4
	var s: int = int(hub.game.quest_step(QID))
	if s <= 0:
		return 1
	if s <= 2:
		return 2
	return 3


func act_name() -> String:
	match current_act():
		1:
			return "ACT 1 · 평양 잠입"
		2:
			return "ACT 2 · 도시의 비밀"
		3:
			return "ACT 3 · 최고지도자 관저"
	return "ACT 4 · 권력 승계"


func _process(delta: float) -> void:
	if not Flags.V3_STORY or hub == null or hub.game == null or hub.player == null or man == null:
		return
	_t1 += delta
	_t2 += delta
	if _t1 >= 1.0:
		_t1 = 0.0
		_progress()
	if _t2 >= 0.5:
		_t2 = 0.0
		_check_office()


func _progress() -> void:
	var g = hub.game
	if man.is_leader:
		return
	var st: String = g.quest_state(QID)
	if st == "inactive":
		if g.start_quest(QID):
			hub.toast("새 임무: " + g.quest_title(QID))
		return
	if st != "active":
		return
	var tgt: int = step_target()
	var cur: int = int(g.quest_step(QID))
	if tgt > cur:
		if g.set_quest_step(QID, tgt):
			hub.toast("임무 갱신: " + g.quest_step_text(QID))


## 장부를 들고 집무실에 들어서면 지도자가 나타나고, 처음이라면 대면 장면이 시작된다
func _check_office() -> void:
	if man.is_leader or busy:
		return
	var g = hub.game
	if not g.has_item("doc_v23_ledger"):
		return
	var pp: Vector3 = hub.player.global_position
	if pp.y < 100.0:
		return
	var o: Vector3 = office_origin()
	var lx: float = pp.x - o.x
	var lz: float = pp.z - o.z
	var in_office: bool = absf(lx) < 6.5 and lz < -14.0 and lz > -29.0 and absf(pp.y - BASE_Y) < 20.0
	if not in_office:
		return
	_ensure_leader_npc()
	if not g.get_flag("v3_confront_seen") and int(hub.mode) == 0:
		run_confrontation()


# ================================================================ 지도자(대면 상대)

func _ensure_leader_npc() -> void:
	if leader_npc != null and is_instance_valid(leader_npc):
		return
	var v23 = mgr.v23 if mgr != null else null
	if v23 == null or v23.get("_r_office") == null:
		return
	var ro: Node3D = v23._r_office
	var look: Dictionary = VNpcs3._look("m", Color(0.16, 0.18, 0.22), Color(0.10, 0.11, 0.14), false, Color(0.2, 0.2, 0.2), "", 0.98, VNpcs3.SK_C)
	look["hair"] = Color(0.80, 0.80, 0.82)
	var pos: Vector3 = Vector3(0.0, 0.0, -27.4)
	var cfg: Dictionary = {
		"id": "v3_leader", "name": "지도자 (가상)", "role": "고령의 지도자 · 노인", "speed": 1.0, "look": look,
		"routine": [{"from": 0.0, "to": 24.0, "mode": "stand", "pos": pos, "radius": 0.0}],
		"dialogue": D.leader_dialogue(), "home": pos, "yaw_deg": 180.0,
	}
	var n = NpcScript.new()
	n.name = "NPC_v3_leader"
	n.configure(cfg, hub)
	n.position = pos + Vector3(0.0, 0.05, 0.0)
	ro.add_child(n)
	leader_npc = n


func remove_leader_npc() -> void:
	if leader_npc != null and is_instance_valid(leader_npc):
		leader_npc.queue_free()
	leader_npc = null


# ================================================================ 지지 기반 계산

func evaluate_support() -> Dictionary:
	var g = hub.game
	var done_n: int = g.done_quest_ids().size()
	var trust_sum: int = 0
	var v1 = hub.get("v1")
	if v1 != null and v1.social != null:
		for k in v1.social.trust.keys():
			trust_sum += maxi(int(v1.social.trust[k]), 0)
	var people: int = 20 + 5 * done_n + 3 * trust_sum
	var army: int = 10
	if g.has_item("pass_special"):
		army += 20
	if g.has_item("base_keycard"):
		army += 15
	if g.has_item("doc_roster"):
		army += 15
	if g.has_item("doc_orders"):
		army += 15
	if g.has_item("doc_tunnel_map"):
		army += 10
	if g.get_flag("passed_north"):
		army += 10
	var court: int = 10
	if g.has_item("doc_v23_ledger"):
		court += 25
	if g.has_item("doc_v23_decree"):
		court += 10
	if g.get_flag("pk_v23_aide_key"):
		court += 15
	if g.has_item("rare_medal"):
		court += 10
	if g.has_item("gift_sweets") or g.has_item("old_watch"):
		court += 10
	if g.get_flag("v23_hint_shelf"):
		court += 15
	support = {"people": clampi(people, 0, 100), "army": clampi(army, 0, 100), "court": clampi(court, 0, 100)}
	g.set_flag("v3_can_reform", int(support["people"]) >= 50)
	g.set_flag("v3_can_army", int(support["army"]) >= 50)
	g.set_flag("v3_can_deal", int(support["court"]) >= 50)
	return support


func support_text() -> String:
	evaluate_support()
	var open: Array = []
	if hub.game.get_flag("v3_can_reform"):
		open.append("공개 개혁")
	if hub.game.get_flag("v3_can_army"):
		open.append("군부 합의")
	if hub.game.get_flag("v3_can_deal"):
		open.append("조용한 거래")
	open.append("유언 승계")
	return "지지 기반 — 주민 %d · 군부 %d · 측근 %d\n열린 길: %s\n(노인이 장부를 넘겨 보며 묻는다) 어떻게 하겠느냐?" % [int(support["people"]), int(support["army"]), int(support["court"]), ", ".join(open)]


# ================================================================ 대면 장면

func run_confrontation() -> void:
	if busy or man.is_leader:
		return
	busy = true
	_ensure_leader_npc()
	hub.mode = 3
	hub.player.velocity = Vector3.ZERO
	hub.player.set_physics_process(false)
	hub.ui.clear_prompt()
	await hub.ui.fade_to(1.0, 0.5)
	hub._teleport(office_origin() + Vector3(0.0, 0.1, -21.6), 0.0)
	man.ui.show_cards(D.intro_cards())
	await man.ui.cards_finished
	hub.game.set_flag("v3_confront_seen", true)
	await get_tree().create_timer(0.2).timeout
	await hub.ui.fade_to(0.0, 0.6)
	hub.player.set_physics_process(true)
	hub.mode = 0
	busy = false
	# 곧바로 대화 시작
	if leader_npc != null and is_instance_valid(leader_npc) and leader_npc.get("_interactable") != null:
		hub._start_dialogue(leader_npc._interactable)


# ================================================================ 권력 승계 장면

func run_succession(route: String) -> void:
	if busy or man.is_leader:
		return
	busy = true
	# 대화가 끝나 자유 상태로 돌아올 때까지 잠깐 기다림
	var guard: int = 0
	while int(hub.mode) != 0 and guard < 90:
		await get_tree().process_frame
		guard += 1
	hub.mode = 3
	hub.player.velocity = Vector3.ZERO
	hub.player.set_physics_process(false)
	hub.ui.clear_prompt()
	await hub.ui.fade_to(1.0, 0.8)
	# 까만 화면 뒤에서 상태를 바꿈
	remove_leader_npc()
	man.become_leader(route)
	hub._teleport(office_origin() + Vector3(0.0, 0.1, -22.4), 0.0)
	hub._set_location("중앙 청사 집무실")
	var info: Dictionary = D.route_info(route)
	var list: Array = D.succession_cards(route)
	list.append("— %s —\n새로운 지도자의 시대가 열렸다.\n이야기는 끝나지 않는다. 지금부터는 당신이 이 도시를 이끈다." % str(info["ending"]))
	for c in D.tutorial_cards():
		list.append(c)
	man.ui.show_cards(list)
	await man.ui.cards_finished
	await get_tree().create_timer(0.3).timeout
	await hub.ui.fade_to(0.0, 1.0)
	hub.player.set_physics_process(true)
	hub.mode = 0
	busy = false
	hub.toast("%s — 이제 당신이 지도자입니다. 우측 '통치' 버튼을 눌러 보세요." % str(info["name"]))
	hub.save_game(true)


# ================================================================ 목표 안내

func objective() -> Dictionary:
	var g = hub.game
	if man.is_leader:
		var title: String = ""
		for gl in D.goals():
			if not man.gov.goals_done.has(str(gl["id"])):
				title = str(gl["title"])
				break
		if title == "":
			return {"text": "통치 중: 모든 국정 목표를 달성했습니다. 도시를 마음껏 가꾸세요."}
		return {"text": "통치 중 · 다음 국정 목표: " + title}
	if g.quest_state(QID) != "active":
		return {}
	var st: int = int(g.quest_step(QID))
	var line: String = "%s: %s" % [g.quest_title(QID), g.quest_step_text(QID)]
	var out: Dictionary = {"text": line}
	if hub.player.global_position.y > 100.0:
		return out
	match st:
		1, 2:
			out["pos"] = GATE_POS
		3:
			out["pos"] = OFFICE_DOOR
	return out
