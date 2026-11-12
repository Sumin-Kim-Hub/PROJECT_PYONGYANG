extends Node
## V2.2 실내 세 곳. 건물 칸(slot) 10, 11, 12 에 만듭니다 (기존 칸 0~9 와 겹치지 않음).
##  - 칸 10: 비밀 지하 통로 (맨홀 방 → 복도 → 보관실(열쇠) / 거래처(표식) / 암호 금고 / 강변·통제구역 출구)
##  - 칸 11: 버려진 건물 (일기 쪽지, 낡은 직인, 녹슨 열쇠)
##  - 칸 12: 군사시설 사령부 (접수대 출입 카드 → 사령관실 문서 → 비상 사이렌 → 비상 해치로 탈출)
## 모든 장소와 문서는 이 게임을 위한 가상의 설정입니다. (Godot 실행 미검증)

const Kit = preload("res://scripts/interior/interior_kit.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")
const DoorScript = preload("res://scripts/interior/door.gd")
const NpcScript = preload("res://scripts/npc/npc.gd")
const TalkerScript = preload("res://scripts/v22/talker.gd")
const VNpcs = preload("res://scripts/v22/v22_npcs.gd")

const SLOT: float = 100.0
const BASE_Y: float = 300.0
const S_TUNNEL: int = 10
const S_RUINS: int = 11
const S_HQ: int = 12
const WALL_H: float = 3.0
const PI_: float = 3.14159265

var hub = null
var mgr = null
var talkers: Array = []
var done: bool = false


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
	_build_tunnel()
	await get_tree().process_frame
	_build_ruins()
	await get_tree().process_frame
	_build_hq()
	await get_tree().process_frame
	print("[PYONGYANG] V2.2 실내 3곳을 만들었습니다.")
	done = true


# ---------------------------------------------------------------- 도우미

func _portal(root: Node3D, local_pos: Vector3, prompt: String, button: String, dest: Vector3, dest_yaw: float, location: String, effects: Array = [], radius: float = 1.8, kind: String = "portal", requires_flag: String = "", requires = null, locked_text: String = "") -> void:
	var it = InteractableScript.new()
	it.kind = kind
	it.prompt = prompt
	it.button_text = button
	it.radius = radius
	it.requires_flag = requires_flag
	var data: Dictionary = {"dest": dest, "dest_yaw": dest_yaw, "location": location, "effects": effects}
	if requires != null:
		data["requires"] = requires
		data["locked_text"] = locked_text
	it.data = data
	it.position = local_pos + Vector3(0.0, 1.0, 0.0)
	root.add_child(it)


## 살펴보기. once_flag 가 있으면 한 번만 (끝나면 숨김). effects 는 살펴본 뒤 적용
func _examine(root: Node3D, local_pos: Vector3, prompt: String, text: String, effects: Array = [], once_flag: String = "", radius: float = 1.8, hide_flag: String = "", requires_flag: String = "") -> void:
	var it = InteractableScript.new()
	it.kind = "examine"
	it.prompt = prompt
	it.radius = radius
	it.hide_flag = hide_flag
	it.requires_flag = requires_flag
	it.data = {"text": text, "effects": effects, "once_flag": once_flag}
	it.position = local_pos + Vector3(0.0, 1.0, 0.0)
	root.add_child(it)


## 얻을 수 있는 물건/돈. flag 는 "pk_v22_..." 로 시작해야 저장/표식 숨김과 맞습니다.
func _loot(root: Node3D, local_pos: Vector3, prompt: String, text: String, effects: Array, flag: String, requires_flag: String = "", mark: bool = true) -> void:
	_examine(root, local_pos, prompt, text, effects, flag, 1.7, flag, requires_flag)
	if mark and requires_flag == "":
		var m = Kit.box(root, local_pos + Vector3(0.0, 0.0, 0.0), Vector3(0.26, 0.07, 0.2), Color(0.95, 0.85, 0.35), false, 2, 1.2)
		m.add_to_group("pk_mark_" + flag.substr(3))


func _door(root: Node3D, hinge: Vector3, rot_y: float, door_id: String, key_item: String, locked_text: String, width: float = 1.4) -> void:
	var dr = DoorScript.new()
	dr.door_id = door_id
	dr.width = width
	dr.locked = key_item != ""
	dr.key_item = key_item
	dr.locked_text = locked_text
	dr.position = hinge
	dr.rotation.y = rot_y
	root.add_child(dr)
	dr.setup(hub)


func _npc_at(root: Node3D, cfg0: Dictionary, local_pos: Vector3, yaw_deg: float) -> void:
	var cfg: Dictionary = cfg0.duplicate(true)
	cfg["home"] = local_pos
	cfg["yaw_deg"] = yaw_deg
	cfg["routine"] = []
	var npc = NpcScript.new()
	npc.name = "NPC_" + str(cfg["id"])
	npc.configure(cfg, hub)
	npc.position = local_pos + Vector3(0.0, 0.05, 0.0)
	root.add_child(npc)


func _patrol(root: Node3D, nid: String, nm: String, path_local: Array, slot: int) -> void:
	var o: Vector3 = _origin(slot)
	var path: Array = []
	for p in path_local:
		path.append(o + p + Vector3(0.0, 0.05, 0.0))
	var cfg: Dictionary = {
		"id": nid, "name": nm, "role": "순찰 경비", "speed": 1.3,
		"look": {"height": 1.04, "skin": Color(0.84, 0.68, 0.56), "shirt": Color(0.26, 0.32, 0.22), "pants": Color(0.18, 0.22, 0.15),
			"hair": Color(0.06, 0.06, 0.06), "hat": true, "hat_color": Color(0.22, 0.28, 0.18), "acc": ""},
		"vision_range": 9.0, "vision_fov": 80.0, "no_talk": true, "patrol_path": path,
	}
	var g = NpcScript.new()
	g.name = "NPC_" + nid
	g.configure(cfg, hub)
	g.position = path_local[0] + Vector3(0.0, 0.05, 0.0)
	root.add_child(g)


func _talker(root: Node3D, local_pos: Vector3, tid: String, nm: String, role_text: String, prompt: String, dlg: Dictionary, btn: String, radius: float = 1.8, hide_flag: String = "") -> void:
	var t = TalkerScript.new()
	t.npc_id = tid
	t.display_name = nm
	t.role = role_text
	t.dialogue = dlg
	t.prompt_text = prompt
	t.button_text = btn
	t.radius = radius
	t.hide_flag = hide_flag
	t.position = local_pos
	root.add_child(t)
	talkers.append(t)


func _wall_glow(root: Node3D, p: Vector3, size: Vector2, yaw: float, color: Color) -> void:
	var b = Kit.box(root, p, Vector3(size.x, size.y, 0.06), color, false, 2, 1.4)
	b.rotation.y = yaw


# ================================================================ 칸 10: 비밀 지하 통로

func _build_tunnel() -> void:
	var r: Node3D = _slot_root(S_TUNNEL, "V22_Int_Tunnel")
	var wc: Color = Color(0.30, 0.31, 0.30)
	var fc: Color = Color(0.20, 0.20, 0.21)
	var cc: Color = Color(0.24, 0.24, 0.25)
	var lamp_col: Color = Color(1.0, 0.82, 0.55)
	var h: float = WALL_H

	# 1) 맨홀 방
	Kit.room(r, Vector3(0.0, 0.0, 0.0), 5.0, 6.0, h, fc, wc, cc, {"n": Vector2(0.0, 2.4)})
	Kit.lamp(r, Vector3(0.0, h - 0.2, 0.0), 0.8, 7.0, lamp_col)
	Kit.box(r, Vector3(0.0, 1.5, 2.8), Vector3(0.08, 3.0, 0.08), Color(0.35, 0.3, 0.25), false, 2)
	Kit.box(r, Vector3(-0.3, 1.5, 2.8), Vector3(0.08, 3.0, 0.08), Color(0.35, 0.3, 0.25), false, 2)
	for i in range(6):
		Kit.box(r, Vector3(-0.15, 0.4 + float(i) * 0.5, 2.8), Vector3(0.32, 0.05, 0.05), Color(0.4, 0.34, 0.28), false, 2)
	Kit.crate(r, Vector3(-1.8, 0.0, -2.0), Vector3(0.9, 0.9, 0.9))
	Kit.crate(r, Vector3(1.9, 0.0, -2.2), Vector3(0.8, 0.8, 0.8), Color(0.38, 0.34, 0.26))
	Kit.label(r, Vector3(0.0, 2.4, -2.8), "하수 3호선 (가상)", 0.5, Color(0.9, 0.85, 0.7), 2)
	_portal(r, Vector3(0.0, 0.0, 2.3), "사다리를 타고 올라가기", "올라가기", Vector3(-318.0, 0.1, 46.2), 0.0, "서쪽 장마당", [], 1.7, "exit")
	_loot(r, Vector3(-1.8, 1.0, -2.0), "상자 위의 지폐", "상자 위에 접힌 지폐가 놓여 있다. 누군가 급히 두고 간 모양이다.",
		[{"op": "give_item", "id": "won", "count": 20}], "pk_v22_shaft_cash")

	# 2) 복도
	Kit.room(r, Vector3(0.0, 0.0, -14.0), 3.0, 22.0, h, fc, wc, cc,
		{"s": Vector2(0.0, 2.4), "n": Vector2(0.0, 2.4), "e": [Vector2(8.0, 1.4), Vector2(-4.0, 1.4)], "w": Vector2(-3.4, 2.0)})
	for lz in [-8.0, -14.0, -20.0]:
		Kit.lamp(r, Vector3(0.0, h - 0.2, lz), 0.7, 7.0, lamp_col)
	for pz in range(-23, -4, 3):
		Kit.box(r, Vector3(1.3, 2.6, float(pz)), Vector3(0.12, 0.12, 2.6), Color(0.28, 0.22, 0.2), false, 2)
	Kit.label(r, Vector3(-1.38, 2.0, -14.0), "← 강변 출구", 0.45, Color(0.8, 0.9, 1.0), 2, PI_ * 0.5)
	Kit.label(r, Vector3(1.38, 2.0, -10.0), "금고 ↑", 0.45, Color(1.0, 0.8, 0.6), 2, -PI_ * 0.5)
	_loot(r, Vector3(-1.2, 1.1, -10.5), "벽에 붙은 약도", "습기에 부푼 종이에 세 개의 출구가 그려진 약도가 붙어 있다. 맨홀, 강변 배수구, 북쪽 통제구역 배수구. 떼어서 챙겼다.",
		[{"op": "give_item", "id": "doc_tunnel_map"}], "pk_v22_tunnel_map")
	_examine(r, Vector3(1.2, 0.0, -22.5), "벽의 낙서", "벽에 분필로 휘갈긴 글씨. '앞은 금고, 뒤는 출구. 숫자는 흩어져 있다. 일기, 낚시, 장.' 누군가 다녀간 흔적이다.",
		[{"op": "v22_intel", "key": "code"}], "", 1.7)

	# 3) 북쪽 방 (암호 금고 앞 + 통제구역 출구)
	Kit.room(r, Vector3(0.0, 0.0, -28.0), 8.0, 6.0, h, fc, wc, cc, {"s": Vector2(0.0, 2.4), "e": Vector2(0.0, 1.6)})
	Kit.lamp(r, Vector3(0.0, h - 0.2, -28.0), 0.8, 8.0, lamp_col)
	Kit.label(r, Vector3(0.0, 2.3, -30.8), "통제구역 지하 · 접근 금지", 0.5, Color(1.0, 0.5, 0.45), 2)
	Kit.crate(r, Vector3(-3.0, 0.0, -26.0), Vector3(1.0, 1.0, 1.0))
	var vault_door = Kit.box(r, Vector3(4.0, 1.2, -28.0), Vector3(0.3, 2.4, 1.6), Color(0.25, 0.27, 0.3), true, 2)
	vault_door.add_to_group("reveal_v22_vault")
	var dlg_keypad: Dictionary = _keypad_dialogue()
	_talker(r, Vector3(3.3, 0.0, -26.7), "v22_keypad", "금고 숫자판", "세 자리 암호", "금고 숫자판", dlg_keypad, "입력", 1.8, "v22_vault_open")
	_portal(r, Vector3(-2.5, 0.0, -29.7), "철제 사다리로 올라가기 (통제구역)", "올라가기", Vector3(70.0, 0.1, -297.5), PI_, "북부 통제구역", [], 1.7, "exit", "tunnel_exit_zone")
	_examine(r, Vector3(-2.5, 0.0, -29.7), "녹슨 빗장", "위로 오르는 사다리 끝에 빗장이 걸려 있다. 안쪽에서라면 쉽게 풀 수 있다. 빗장을 밀어 열었다.",
		[{"op": "set_flag", "key": "tunnel_exit_zone"}, {"op": "toast", "text": "통제구역 쪽 출구가 열렸다."}], "", 1.7, "tunnel_exit_zone")

	# 4) 금고
	Kit.room(r, Vector3(9.0, 0.0, -28.0), 10.0, 6.0, h, fc, Color(0.26, 0.28, 0.3), cc, {"w": Vector2(0.0, 1.6)})
	Kit.lamp(r, Vector3(9.0, h - 0.2, -28.0), 1.0, 9.0, Color(0.8, 0.95, 1.0))
	Kit.table(r, Vector3(9.0, 0.0, -28.0), 2.6, 1.0, 0.8, Color(0.3, 0.3, 0.34))
	for i in range(4):
		Kit.box(r, Vector3(12.0, 0.5 + float(i) * 0.6, -30.4), Vector3(1.6, 0.5, 0.5), Color(0.45, 0.4, 0.3))
	_loot(r, Vector3(8.2, 0.85, -28.0), "책상 위 반출 명세서", "배급 물자가 매달 같은 사람의 이름으로 빠져나간 기록이다. 이 장부 하나로 누군가의 목이 달아날 수 있다. (이 게임 속 가상의 문서)",
		[{"op": "give_item", "id": "doc_shipping"}, {"op": "quest_step", "id": "q_v22_pass", "step": 4, "if": {"quest": "q_v22_pass", "state": "active", "min_step": 2}}], "pk_v22_v_ship")
	_loot(r, Vector3(9.8, 0.85, -28.0), "책상 위 교대 명단", "통제구역 경비의 교대 명단. 누가 언제 자리를 비우는지 적혀 있다. (가상)",
		[{"op": "give_item", "id": "doc_roster"}, {"op": "quest_step", "id": "q_v22_pass", "step": 4, "if": {"quest": "q_v22_pass", "state": "active", "min_step": 2}}], "pk_v22_v_roster")
	_loot(r, Vector3(12.0, 2.5, -30.2), "선반 위 낡은 훈장", "먼지가 앉은 훈장이다. 값을 매기기 어려운 희귀품 같다.",
		[{"op": "give_item", "id": "rare_medal"}], "pk_v22_v_medal")
	_loot(r, Vector3(12.0, 1.0, -26.0), "금속 상자 속 현금", "금속 상자에 묶인 지폐 뭉치가 들어 있다.",
		[{"op": "give_item", "id": "won", "count": 120}], "pk_v22_v_cash")
	_loot(r, Vector3(6.0, 1.0, -30.2), "벽 틈의 사령부 출입 카드", "벽 틈에 끼워 둔 출입 카드. 군사시설 사령부 뒷문 단말기에 맞는 듯하다. (가상)",
		[{"op": "give_item", "id": "base_keycard"}], "pk_v22_v_keycard")

	# 5) 서쪽 곁가지 (강변 출구)
	Kit.room(r, Vector3(-6.25, 0.0, -17.4), 9.5, 3.0, h, fc, wc, cc, {"e": Vector2(0.0, 2.0)})
	Kit.lamp(r, Vector3(-6.0, h - 0.2, -17.4), 0.6, 7.0, Color(0.7, 0.85, 1.0))
	Kit.box(r, Vector3(-10.8, 1.2, -17.4), Vector3(0.1, 2.4, 1.6), Color(0.3, 0.26, 0.22), false, 2)
	_wall_glow(r, Vector3(-10.9, 2.5, -17.4), Vector2(0.8, 0.3), PI_ * 0.5, Color(0.7, 0.85, 1.0))
	_portal(r, Vector3(-10.0, 0.0, -17.4), "배수구 철망을 밀고 나가기 (강변)", "나가기", Vector3(-192.0, 0.1, -134.2), PI_, "강변 산책로", [], 1.7, "exit", "tunnel_exit_river")
	_examine(r, Vector3(-10.0, 0.0, -17.4), "녹슨 빗장", "철망 안쪽에 빗장이 걸려 있다. 빗장을 풀었다. 이제 강변에서 이쪽으로 드나들 수 있다.",
		[{"op": "set_flag", "key": "tunnel_exit_river"}, {"op": "toast", "text": "강변 쪽 출구가 열렸다."}], "", 1.7, "tunnel_exit_river")
	_loot(r, Vector3(-4.0, 0.7, -16.4), "물 젖은 고철", "녹슨 고철 덩어리. 장마당에서 푼돈은 받을 수 있겠다.",
		[{"op": "give_item", "id": "scrap"}], "pk_v22_west_scrap")

	# 6) 보관실 (녹슨 열쇠 필요)
	Kit.room(r, Vector3(5.0, 0.0, -6.0), 7.0, 5.0, h, fc, wc, cc, {"w": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(5.0, h - 0.2, -6.0), 0.8, 7.0, lamp_col)
	_door(r, Vector3(1.5, 0.0, -6.7), -PI_ * 0.5, "v22_cache", "old_key", "녹슨 자물쇠가 걸려 있다. 열쇠가 필요하다.")
	Kit.shelf(r, Vector3(7.8, 0.0, -7.6), 0.0, 1.6, 2.0)
	Kit.shelf(r, Vector3(5.6, 0.0, -7.6), 0.0, 1.6, 2.0)
	Kit.crate(r, Vector3(7.8, 0.0, -4.4), Vector3(1.0, 1.0, 1.0))
	_loot(r, Vector3(5.6, 1.5, -7.2), "선반 위 비상 식량", "기름종이로 싼 건조 식량이다. 아직 먹을 수 있다.",
		[{"op": "give_item", "id": "food_ration", "count": 2}], "pk_v22_cache_food")
	_loot(r, Vector3(7.8, 1.5, -7.2), "선반 위 약품", "유리병에 든 약품이다. 라벨은 번져 읽을 수 없지만 병은 온전하다.",
		[{"op": "give_item", "id": "medicine"}], "pk_v22_cache_med")
	_loot(r, Vector3(7.8, 1.1, -4.4), "상자 속 라디오 부품", "상자 속에 기판과 진공관이 들어 있다. 낚시꾼 마씨가 찾던 것일지도 모른다.",
		[{"op": "give_item", "id": "radio_part"}], "pk_v22_cache_radio")
	_loot(r, Vector3(3.0, 0.9, -4.2), "벽 틈의 지폐", "벽 틈에 말아 넣은 지폐 뭉치다.",
		[{"op": "give_item", "id": "won", "count": 60}], "pk_v22_cache_cash")

	# 7) 거래처 (두더지 표식 필요)
	Kit.room(r, Vector3(6.0, 0.0, -18.0), 9.0, 6.0, h, fc, Color(0.32, 0.28, 0.26), cc, {"w": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(6.0, h - 0.2, -18.0), 0.9, 8.0, Color(1.0, 0.75, 0.5))
	_door(r, Vector3(1.5, 0.0, -18.7), -PI_ * 0.5, "v22_den", "mole_token", "문 앞에서 낮은 목소리가 들린다. '표식을 보여라.' (두더지 표식이 필요하다)")
	Kit.table(r, Vector3(7.5, 0.0, -19.2), 2.2, 1.0, 0.8, Color(0.34, 0.26, 0.2))
	Kit.chair(r, Vector3(7.5, 0.0, -17.9), PI_, Color(0.3, 0.24, 0.2))
	Kit.bed(r, Vector3(9.4, 0.0, -16.2), 0.0, Color(0.3, 0.3, 0.36))
	Kit.crate(r, Vector3(3.2, 0.0, -20.2), Vector3(1.1, 1.1, 1.1))
	Kit.crate(r, Vector3(4.4, 0.0, -20.4), Vector3(0.9, 0.9, 0.9), Color(0.38, 0.34, 0.26))
	Kit.rug(r, Vector3(6.0, 0.02, -18.0), 4.0, 3.0, Color(0.4, 0.18, 0.16))
	Kit.label(r, Vector3(6.0, 2.4, -20.8), "두더지의 가게", 0.5, Color(1.0, 0.85, 0.6), 2)
	var mole_cfg: Dictionary = {}
	for c in VNpcs.all():
		if str(c.get("slot_npc", "")) == "mole":
			mole_cfg = c
	if not mole_cfg.is_empty():
		_npc_at(r, mole_cfg, Vector3(7.5, 0.0, -20.1), 0.0)
	_examine(r, Vector3(9.0, 0.0, -19.6), "벽에 걸린 군사시설 배치도", "손으로 그린 배치도. 사령부 뒤편에 비상 배수구가 있고, 안쪽 문은 특별 통행증이 아니면 열리지 않는다고 적혀 있다.",
		[{"op": "v22_intel", "key": "base"}], "", 1.8)


## 암호 입력 대화 (선택지 4개 중 하나 고르기)
func _keypad_dialogue() -> Dictionary:
	var d: Dictionary = {}
	d["start"] = {
		"text": "철제 문 옆에 낡은 숫자판이 붙어 있다. 세 자리 암호를 눌러야 열릴 것 같다.",
		"choices": [
			{"label": "암호 입력", "next": "pick"},
			{"label": "단서 정리", "next": "hint", "if": {"flag": "intel_code"}},
			{"label": "그만둔다", "next": ""},
		],
	}
	d["hint"] = {
		"dyn": "v22_keypad_hint", "text": "...",
		"choices": [{"label": "입력해 본다", "next": "pick"}, {"label": "그만둔다", "next": ""}],
	}
	d["pick"] = {
		"text": "어떤 숫자를 누를까?",
		"choices": [
			{"label": "4 - 1 - 7", "next": "res", "effects": [{"op": "v22_vault", "code": "417"}]},
			{"label": "4 - 7 - 1", "next": "res", "effects": [{"op": "v22_vault", "code": "471"}]},
			{"label": "1 - 4 - 7", "next": "res", "effects": [{"op": "v22_vault", "code": "147"}]},
			{"label": "7 - 1 - 4", "next": "res", "effects": [{"op": "v22_vault", "code": "714"}]},
		],
	}
	d["res"] = {
		"dyn": "v22_result", "text": "...",
		"choices": [
			{"label": "다시 입력", "next": "pick", "if": {"not_flag": "v22_vault_open"}},
			{"label": "끝낸다", "next": ""},
		],
	}
	return d


# ================================================================ 칸 11: 버려진 건물

func _build_ruins() -> void:
	var r: Node3D = _slot_root(S_RUINS, "V22_Int_Ruins")
	var wc: Color = Color(0.40, 0.38, 0.35)
	var fc: Color = Color(0.26, 0.24, 0.22)
	var cc: Color = Color(0.30, 0.29, 0.28)
	var h: float = WALL_H
	var dim: Color = Color(0.85, 0.75, 0.6)

	# 현관 홀
	Kit.room(r, Vector3(0.0, 0.0, 0.0), 10.0, 8.0, h, fc, wc, cc, {"n": Vector2(0.0, 1.4), "w": Vector2(0.0, 1.4), "e": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(0.0, h - 0.2, 0.0), 0.45, 7.0, dim)
	Kit.crate(r, Vector3(3.6, 0.0, 2.6), Vector3(1.0, 0.8, 1.0), Color(0.36, 0.3, 0.24))
	Kit.chair(r, Vector3(-3.4, 0.0, 2.4), 2.4, Color(0.3, 0.24, 0.2))
	Kit.label(r, Vector3(0.0, 2.3, 3.7), "이 건물은 안전 점검 후 철거 예정 (가상)", 0.4, Color(1.0, 0.55, 0.5), 2, PI_)
	_portal(r, Vector3(-3.0, 0.0, 3.2), "밖으로 나가기", "나가기", Vector3(-310.0, 0.1, 109.6), PI_, "서쪽 외곽", [], 2.0, "exit")
	_examine(r, Vector3(-4.5, 0.0, -2.5), "벽의 낙서", "벽에 크레용으로 그린 가족 그림. 아래에 서툰 글씨로 '우리 집 4층'이라고 적혀 있다.",
		[], "", 1.8)

	# 서쪽 방: 일기 쪽지
	Kit.room(r, Vector3(-9.0, 0.0, 0.0), 8.0, 6.0, h, fc, wc, cc, {"e": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(-9.0, h - 0.2, 0.0), 0.4, 6.0, dim)
	Kit.bed(r, Vector3(-11.4, 0.0, -1.6), 0.0, Color(0.32, 0.3, 0.34))
	Kit.table(r, Vector3(-9.0, 0.0, 1.8), 1.6, 0.8, 0.75, Color(0.36, 0.28, 0.2))
	Kit.shelf(r, Vector3(-7.4, 0.0, -2.7), 0.0, 1.6, 2.0)
	_loot(r, Vector3(-9.0, 0.85, 1.8), "탁자 서랍의 일기 쪽지", "서랍 속에서 접힌 쪽지가 나왔다. '금고 첫 숫자는 4. 우리 가족이 처음 이사 온 층수.' 글씨가 번져 있다.",
		[{"op": "give_item", "id": "clue_a"}, {"op": "quest_step", "id": "q_v22_ruins", "step": 2, "if": {"quest": "q_v22_ruins", "state": "active"}}], "pk_v22_clue_a")
	_loot(r, Vector3(-7.4, 1.4, -2.6), "선반 위 낡은 직인", "먼지 쌓인 직인이다. 손잡이에 오래된 관청 이름이 새겨져 있다. 위조 증서의 도장을 흉내 낼 때 쓸 수 있겠다. (가상)",
		[{"op": "give_item", "id": "old_stamp"}], "pk_v22_old_stamp")

	# 북쪽 방: 벽 속 열쇠 (일기를 읽은 뒤에만 보임)
	Kit.room(r, Vector3(0.0, 0.0, -8.0), 8.0, 8.0, h, fc, wc, cc, {"s": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(0.0, h - 0.2, -8.0), 0.4, 6.0, dim)
	Kit.crate(r, Vector3(-2.8, 0.0, -10.6), Vector3(1.2, 1.2, 1.2), Color(0.34, 0.28, 0.22))
	Kit.crate(r, Vector3(2.4, 0.0, -10.8), Vector3(0.9, 0.9, 0.9))
	Kit.label(r, Vector3(0.0, 2.2, -11.8), "4층", 0.8, Color(0.9, 0.8, 0.6), 2)
	_examine(r, Vector3(0.0, 0.0, -11.5), "벽의 금 간 자리", "벽 한 곳이 이상하게 갈라져 있다. 일기에 적힌 '4층'과 관련이 있을까?",
		[], "", 1.8, "pk_v22_old_key", "")
	_loot(r, Vector3(0.0, 0.9, -11.5), "벽 속에 숨긴 녹슨 열쇠", "벽돌 한 장을 빼내자 천에 싼 열쇠가 나왔다. 어느 지하 문의 열쇠일 것이다.",
		[{"op": "give_item", "id": "old_key"}, {"op": "quest_complete", "id": "q_v22_ruins"}], "pk_v22_old_key", "pk_v22_clue_a")

	# 동쪽 방: 은닉 물자
	Kit.room(r, Vector3(9.0, 0.0, 0.0), 8.0, 6.0, h, fc, wc, cc, {"w": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(9.0, h - 0.2, 0.0), 0.4, 6.0, dim)
	Kit.crate(r, Vector3(11.4, 0.0, -1.8), Vector3(1.0, 1.0, 1.0))
	Kit.table(r, Vector3(9.0, 0.0, 1.8), 1.8, 0.8, 0.75, Color(0.36, 0.28, 0.2))
	_loot(r, Vector3(11.4, 1.1, -1.8), "상자 속 지폐", "상자 바닥에 접힌 지폐가 깔려 있다.",
		[{"op": "give_item", "id": "won", "count": 40}], "pk_v22_ruins_cash")
	_loot(r, Vector3(9.0, 0.85, 1.8), "탁자 위 고철", "쓸 만한 금속 조각들이다.",
		[{"op": "give_item", "id": "scrap"}], "pk_v22_ruins_scrap")
	_examine(r, Vector3(7.0, 0.0, -2.6), "구석의 낡은 침낭", "누군가 최근까지 이곳에서 지낸 것 같다. 식은 재와 빈 깡통이 있다. 이 도시에는 갈 곳 없는 사람이 많다.",
		[], "", 1.8)


# ================================================================ 칸 12: 사령부

func _build_hq() -> void:
	var r: Node3D = _slot_root(S_HQ, "V22_Int_HQ")
	var wc: Color = Color(0.56, 0.54, 0.48)
	var fc: Color = Color(0.30, 0.28, 0.26)
	var cc: Color = Color(0.62, 0.60, 0.56)
	var h: float = 3.2
	var warm: Color = Color(1.0, 0.94, 0.78)

	# 로비
	Kit.room(r, Vector3(0.0, 0.0, 0.0), 12.0, 10.0, h, fc, wc, cc, {"n": Vector2(0.0, 1.4), "e": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(-3.0, h - 0.2, 0.0), 1.0, 8.0, warm)
	Kit.lamp(r, Vector3(3.0, h - 0.2, 0.0), 1.0, 8.0, warm)
	Kit.rug(r, Vector3(0.0, 0.02, 0.5), 5.0, 8.0, Color(0.5, 0.12, 0.12))
	Kit.box(r, Vector3(0.0, 2.2, 4.8), Vector3(5.0, 1.2, 0.1), Color(0.6, 0.1, 0.1), false, 2)
	Kit.label(r, Vector3(0.0, 2.2, 4.7), "경계를 늦추지 말라 (가상의 표어)", 0.5, Color(1.0, 0.95, 0.8), 2, PI_)
	Kit.counter(r, Vector3(-3.6, 0.0, 2.2), 0.0, 2.8, Color(0.34, 0.28, 0.22))
	Kit.chair(r, Vector3(-3.6, 0.0, 3.2), PI_, Color(0.26, 0.22, 0.2))
	Kit.table(r, Vector3(3.6, 0.0, 2.2), 2.0, 0.9, 0.75, Color(0.34, 0.28, 0.22))
	_portal(r, Vector3(0.0, 0.0, 4.2), "밖으로 나가기", "나가기", Vector3(0.0, 0.1, -350.5), PI_, "군사시설", [], 1.8, "exit")
	_loot(r, Vector3(-3.6, 1.15, 2.2), "접수대 서랍의 출입 카드", "접수대 서랍에서 출입 카드를 꺼냈다. 사령관실 문의 단말기에 맞는 것 같다. 순찰 경비의 시선을 조심하라. (가상)",
		[{"op": "give_item", "id": "base_keycard"}], "pk_v22_hq_keycard", "", true)
	_patrol(r, "hq_guard", "사령부 경비", [Vector3(-4.5, 0.0, -2.0), Vector3(4.5, 0.0, -2.0), Vector3(4.5, 0.0, 1.0), Vector3(-4.5, 0.0, 1.0)], S_HQ)

	# 사령관실
	Kit.room(r, Vector3(0.0, 0.0, -9.5), 10.0, 9.0, h, fc, wc, cc, {"s": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(0.0, h - 0.2, -9.5), 1.1, 9.0, warm)
	_door(r, Vector3(-0.7, 0.0, -5.0), 0.0, "v22_hq_office", "base_keycard", "단말기가 붉게 깜박인다. 출입 카드가 필요하다.")
	Kit.table(r, Vector3(0.0, 0.0, -12.2), 3.0, 1.2, 0.8, Color(0.3, 0.22, 0.16))
	Kit.chair(r, Vector3(0.0, 0.0, -13.2), 0.0, Color(0.2, 0.18, 0.18))
	Kit.shelf(r, Vector3(-3.4, 0.0, -13.6), 0.0, 1.8, 2.2)
	Kit.shelf(r, Vector3(3.4, 0.0, -13.6), 0.0, 1.8, 2.2)
	Kit.box(r, Vector3(0.0, 2.1, -13.9), Vector3(3.2, 1.4, 0.08), Color(0.6, 0.1, 0.1), false, 2)
	Kit.label(r, Vector3(0.0, 2.1, -13.8), "비상 상황 대응 지침 (가상)", 0.5, Color(1.0, 0.95, 0.8), 2)
	_loot(r, Vector3(0.0, 0.95, -12.2), "책상 위 비상 명령서", "도시 전체의 출입을 막을 때 쓰는 비상 명령서다. 손에 쥐는 순간 책상 아래의 경보 스위치가 눌린 듯 사이렌이 울리기 시작한다! (이 게임 속 가상의 문서)",
		[{"op": "give_item", "id": "doc_orders"}, {"op": "quest_step", "id": "q_v22_pass", "step": 9, "if": {"quest": "q_v22_pass", "state": "active"}}, {"op": "v22_siren"}], "pk_v22_hq_orders")
	_loot(r, Vector3(-3.4, 1.5, -13.4), "서가 속 약품", "선반에 군용 약품이 놓여 있다.",
		[{"op": "give_item", "id": "medicine"}], "pk_v22_hq_med")
	_loot(r, Vector3(3.4, 1.5, -13.4), "서가 속 훈장 상자", "상자 안에서 낡은 훈장이 나왔다.",
		[{"op": "give_item", "id": "rare_medal"}], "pk_v22_hq_medal")
	# 비상 해치: 사이렌이 울린 뒤에만 사용
	Kit.box(r, Vector3(-4.3, 1.1, -11.0), Vector3(0.1, 2.2, 1.2), Color(0.35, 0.3, 0.2), false, 2)
	_portal(r, Vector3(-4.0, 0.0, -11.0), "비상 해치로 뛰어내리기 (지하 통로)", "탈출", _origin(S_TUNNEL) + Vector3(3.0, 0.1, -26.4), PI_, "비밀 지하 통로",
		[{"op": "toast", "text": "사이렌을 뒤로 하고 해치 아래 통로로 내려왔다."}], 1.8, "portal", "v22_siren")

	# 창고
	Kit.room(r, Vector3(11.0, 0.0, 0.0), 10.0, 6.0, h, fc, wc, cc, {"w": Vector2(0.0, 1.4)})
	Kit.lamp(r, Vector3(11.0, h - 0.2, 0.0), 0.8, 8.0, warm)
	for i in range(3):
		Kit.crate(r, Vector3(14.2, 0.0, -1.8 + float(i) * 1.7), Vector3(1.1, 1.1, 1.1), Color(0.34, 0.38, 0.28))
	Kit.crate(r, Vector3(9.0, 0.0, -2.2), Vector3(1.2, 1.2, 1.2), Color(0.34, 0.38, 0.28))
	_loot(r, Vector3(14.2, 1.3, -0.1), "군용 상자 속 식량", "군용 식량 상자다. 두 끼 정도는 되겠다.",
		[{"op": "give_item", "id": "food_ration", "count": 2}], "pk_v22_hq_food")
	_loot(r, Vector3(9.0, 1.3, -2.2), "군용 상자 속 지폐", "봉투에 묶인 지폐가 들어 있다. 병사들의 급여로 보인다.",
		[{"op": "give_item", "id": "won", "count": 90}], "pk_v22_hq_cash")
