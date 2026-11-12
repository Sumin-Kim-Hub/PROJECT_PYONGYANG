extends Node3D
## V1 추가 건물 내부: 옥류관(식당), 지하철역(매표 홀 → 걸어 내려가는 경사 계단 → 승강장 → 점검실), 상점.
##  - 옥류관과 지하철역의 겉모습은 landmarks.gd 가 만든 것을 쓰고(exits), 상점은 여기서 겉모습까지 만듭니다.
##  - 내부는 기존 interior_manager 와 같은 방식으로 도시 위쪽(y=300) 멀리에 따로 만들고 문으로 이동합니다.
##  - 지하철역은 경사로(걸어서 내려감)와 승강기(순간이동) 두 가지가 있어 한쪽이 문제여도 갈 수 있습니다.
## 이 세계의 인물과 장소는 모두 가상입니다.

const Kit = preload("res://scripts/interior/interior_kit.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")
const DoorScript = preload("res://scripts/interior/door.gd")
const NpcScript = preload("res://scripts/npc/npc.gd")
const NpcData = preload("res://scripts/data/npc_data.gd")

const BASE_Y: float = 300.0
const SLOT: float = 100.0
const PI_: float = 3.14159265

const S_OKRYU: int = 6
const S_METRO: int = 7
const S_SHOP: int = 8

var hub = null
var _world: Node3D = null
var _lm = null
var _roots: Dictionary = {}
var _ext: Dictionary = {}
var built: Array = []

const HOSTESS = {
	"id": "okryu_host", "name": "송미경", "role": "옥류관 안내원 · 친절함", "speed": 0.0,
	"look": {"sex": "f", "height": 0.99, "skin": Color(0.88, 0.72, 0.6), "shirt": Color(0.62, 0.16, 0.18), "pants": Color(0.16, 0.14, 0.16), "hair": Color(0.08, 0.07, 0.07), "hat": false, "hat_color": Color(0, 0, 0), "acc": ""},
	"dialogue": {
		"entry": [
			{"if": {"flag": "okryu_kitchen_ok"}, "node": "after_kitchen"},
			{"if": {"quest": "q_okryu", "state": "active"}, "node": "quest"},
			{"if": {"flag": "rumor_okryu"}, "node": "quest"},
			{"if": {"flag": "trust_okryu_host"}, "node": "friend"},
		],
		"start": {
			"text": "어서 오세요, 옥류관입니다. 오늘은 냉면이 잘 나가요.",
			"variants": {"저녁": "저녁 손님이 많아서 정신이 없네요. 그래도 어서 오세요.", "밤": "곧 마감이에요. 마지막 손님이시군요."},
			"choices": [
				{"label": "메뉴는요?", "next": "menu"},
				{"label": "주방이 궁금해요", "next": "kitchen"},
				{"label": "안녕히 계세요", "next": ""},
			],
		},
		"menu": {
			"text": "냉면과 온반, 녹두전이 대표예요. 처음 오셨으면 냉면을 권해요. 육수가 깊거든요.",
			"choices": [{"label": "다른 얘기도요", "next": "start"}, {"label": "고마워요", "next": ""}],
		},
		"kitchen": {
			"text": "주방은 직원 전용이라 안 돼요. …왜요, 무슨 용건이라도 있으세요?",
			"choices": [{"label": "아니에요", "next": ""}],
		},
		"quest": {
			"text": "혹시 '메뉴 수첩' 얘기를 듣고 오셨어요? …좋아요, 저는 못 들은 걸로 할게요. 주방 문은 열어 둘 테니 선반 쪽을 보세요. 오래 있지는 마시고요.",
			"effects": [
				{"op": "quest_start", "id": "q_okryu"},
				{"op": "unlock_door", "id": "okryu_kitchen"},
				{"op": "set_flag", "key": "okryu_kitchen_ok"},
				{"op": "quest_step", "id": "q_okryu", "step": 2, "if": {"quest": "q_okryu", "state": "active", "step": 0}},
				{"op": "quest_step", "id": "q_okryu", "step": 2, "if": {"quest": "q_okryu", "state": "active", "step": 1}},
			],
			"choices": [{"label": "고마워요", "next": ""}],
		},
		"after_kitchen": {
			"text": "주방 문은 열어 뒀어요. 휴게실 근무표도 한번 보세요. 누가 밤마다 어디로 가는지 적혀 있거든요.",
			"choices": [{"label": "알겠어요", "next": ""}],
		},
		"friend": {
			"text": "아, 오셨네요. 사실 직원 중 한 명이 매일 밤 지하철역으로 간다는 얘기가 있어요. 저도 이유는 몰라요.",
			"choices": [{"label": "고마워요", "next": ""}],
		},
	},
}

const METRO_STAFF = {
	"id": "metro_staff", "name": "문철민", "role": "지하철 직원 · 무뚝뚝함", "speed": 0.0,
	"look": {"sex": "m", "height": 1.02, "skin": Color(0.84, 0.68, 0.56), "shirt": Color(0.2, 0.3, 0.42), "pants": Color(0.14, 0.16, 0.2), "hair": Color(0.1, 0.09, 0.09), "hat": true, "hat_color": Color(0.2, 0.3, 0.42), "acc": ""},
	"dialogue": {
		"entry": [
			{"if": [{"quest": "q_okryu", "state": "active", "step": 3}, {"item": "menu_note"}], "node": "show_note"},
			{"if": {"flag": "metro_unlocked"}, "node": "after"},
		],
		"start": {
			"text": "이 역은 늘 조용합니다. 열차는 하루에 몇 번 서지도 않아요.",
			"variants": {"밤": "야간 점검 시간입니다. 승강장은 한산해요."},
			"choices": [
				{"label": "점검실은요?", "next": "maint"},
				{"label": "승강장은요?", "next": "plat"},
				{"label": "수고하세요", "next": ""},
			],
		},
		"maint": {
			"text": "점검실은 관계자 외 출입 금지입니다. 물어보셔도 열어 드릴 수 없어요.",
			"choices": [{"label": "알겠어요", "next": ""}],
		},
		"plat": {
			"text": "오른쪽 경사 계단으로 내려가시거나, 왼쪽 승강기를 타세요. 안전선 밖으로 나가지 마시고요.",
			"choices": [{"label": "고마워요", "next": ""}],
		},
		"show_note": {
			"text": "…그 수첩. 어디서 났습니까? (한참 들여다보다 한숨을 쉰다) 알겠습니다. 점검실 문을 열어 두겠습니다. 오래 있지는 마세요.",
			"effects": [
				{"op": "unlock_door", "id": "metro_maint"},
				{"op": "set_flag", "key": "metro_unlocked"},
				{"op": "quest_complete", "id": "q_okryu"},
				{"op": "quest_step", "id": "q_metro", "step": 1, "if": {"quest": "q_metro", "state": "active", "step": 0}},
			],
			"choices": [{"label": "고맙습니다", "next": ""}],
		},
		"after": {
			"text": "점검실은 열어 뒀습니다. 다 보면 문은 닫아 주세요.",
			"choices": [{"label": "네", "next": ""}],
		},
	},
}

const SHOP_OWNER = {
	"id": "shop_owner", "name": "오영순", "role": "상점 주인 · 수다스러움", "speed": 0.0,
	"look": {"sex": "f", "height": 0.96, "skin": Color(0.88, 0.72, 0.6), "shirt": Color(0.3, 0.5, 0.4), "pants": Color(0.22, 0.2, 0.22), "hair": Color(0.2, 0.18, 0.17), "hat": false, "hat_color": Color(0, 0, 0), "acc": "scarf"},
	"dialogue": {
		"start": {
			"text": "어서 오세요! 필요한 거 있으면 말해요. 간단한 먹거리랑 생활용품이 있어요.",
			"variants": {"밤": "늦었네요! 문 닫기 전에 구경하세요."},
			"choices": [
				{"label": "무엇을 파세요?", "next": "goods"},
				{"label": "안녕히 계세요", "next": ""},
			],
		},
		"goods": {
			"text": "과자, 음료, 건전지, 우산 같은 거요. 아, 우산은 '푸른 우산'이 제일 잘 나가요. 왜 그런지는 몰라도요.",
			"choices": [{"label": "그렇군요", "next": ""}],
		},
	},
}


func _origin(slot: int) -> Vector3:
	return Vector3(float(slot) * SLOT, BASE_Y, 0.0)


func _slot_root(slot: int, nm: String) -> Node3D:
	var r = Node3D.new()
	r.name = nm
	r.position = _origin(slot)
	add_child(r)
	_roots[slot] = r
	return r


func build(world: Node3D, hub_ref, landmarks) -> void:
	hub = hub_ref
	_world = world
	_lm = landmarks
	await get_tree().physics_frame

	var ok_count: int = 0
	if _lm != null and _lm.exits.has("okryu"):
		_ext["okryu"] = _lm.exits["okryu"]
		_build_okryu()
		_enter_portal("okryu", _origin(S_OKRYU) + Vector3(0.0, 0.1, 5.2), 0.0, "옥류관 입장", "옥류관", [
			{"op": "quest_step", "id": "q_okryu", "step": 1, "if": {"quest": "q_okryu", "state": "active", "step": 0}}])
		ok_count += 1
	if _lm != null and _lm.exits.has("metro"):
		_ext["metro"] = _lm.exits["metro"]
		_build_metro()
		_enter_portal("metro", _origin(S_METRO) + Vector3(0.0, 0.1, 3.4), 0.0, "지하철역 입장", "지하철역", [])
		ok_count += 1

	_ext["shop"] = await _make_exterior({
		"id": "shop", "name": "상점", "sign": "상점", "pref": Vector3(46.0, 0.0, 36.0),
		"size": Vector3(9.0, 5.0, 8.0), "color": Color(0.74, 0.66, 0.5), "roof": Color(0.32, 0.26, 0.22)})
	_build_shop()
	_enter_portal("shop", _origin(S_SHOP) + Vector3(0.0, 0.1, 3.2), 0.0, "상점 입장", "상점", [])
	ok_count += 1
	print("[PYONGYANG] V1 건물 내부 %d곳을 만들었습니다." % ok_count)


# ---------------------------------------------------------------- 공통 도우미 (interior_manager 와 같은 방식)

func _make_exterior(spec: Dictionary) -> Dictionary:
	var size: Vector3 = spec["size"]
	var spot: Vector3 = Placement.find_free_box(get_world_3d(), spec["pref"], Vector3(size.x + 4.0, size.y, size.z + 8.0))
	spot.y = 0.0
	var root = Node3D.new()
	root.name = "Ext_" + str(spec["id"])
	root.position = spot
	_world.add_child(root)
	var w: float = size.x
	var h: float = size.y
	var d: float = size.z
	Kit.box(root, Vector3(0.0, h * 0.5, 0.0), size, spec["color"], true, 1)
	Kit.box(root, Vector3(0.0, h + 0.2, 0.0), Vector3(w + 0.8, 0.4, d + 0.8), spec["roof"], false, 1)
	Kit.box(root, Vector3(-w * 0.25, 1.6, d * 0.5 + 0.05), Vector3(3.0, 2.2, 0.1), Color(0.16, 0.22, 0.3), false, 1)
	Kit.box(root, Vector3(w * 0.25, 1.3, d * 0.5 + 0.06), Vector3(1.6, 2.6, 0.14), Color(0.22, 0.14, 0.1), false, 1)
	Kit.box(root, Vector3(0.0, 3.4, d * 0.5 + 0.5), Vector3(w * 0.9, 0.12, 1.0), spec["roof"], false, 1)
	Kit.label(root, Vector3(0.0, 4.0, d * 0.5 + 0.2), str(spec["sign"]), 1.3, Color(1.0, 0.95, 0.75), 1)
	var front: Vector3 = spot + Vector3(w * 0.25, 0.1, d * 0.5 + 4.0)
	var res: Dictionary = {"root": root, "front": front, "depth": d, "name": spec["name"], "door_x": w * 0.25}
	if hub != null:
		hub.register_poi(str(spec["id"]), str(spec["name"]), front)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return res


func _away_yaw(root: Node3D) -> float:
	var fwd: Vector3 = Basis(Vector3.UP, root.rotation.y) * Vector3(0.0, 0.0, 1.0)
	return atan2(-fwd.x, -fwd.z)


func _enter_portal(ext_id: String, dest: Vector3, dest_yaw: float, prompt: String, location: String, effects: Array) -> void:
	var e: Dictionary = _ext[ext_id]
	var it = InteractableScript.new()
	it.kind = "enter"
	it.prompt = prompt
	it.radius = 2.4
	it.data = {"dest": dest, "dest_yaw": dest_yaw, "location": location, "effects": effects}
	it.position = Vector3(float(e.get("door_x", 0.0)), 1.0, float(e["depth"]) * 0.5 + 1.4)
	e["root"].add_child(it)


func _portal(root: Node3D, local_pos: Vector3, prompt: String, button: String, dest: Vector3, dest_yaw: float, location: String, effects: Array = [], radius: float = 1.9, kind: String = "portal") -> void:
	var it = InteractableScript.new()
	it.kind = kind
	it.prompt = prompt
	it.button_text = button
	it.radius = radius
	it.data = {"dest": dest, "dest_yaw": dest_yaw, "location": location, "effects": effects}
	it.position = local_pos + Vector3(0.0, 1.0, 0.0)
	root.add_child(it)


func _exit_portal(root: Node3D, local_pos: Vector3, ext_id: String) -> void:
	var e: Dictionary = _ext[ext_id]
	_portal(root, local_pos, "밖으로 나가기", "나가기", e["front"], _away_yaw(e["root"]), "", [], 2.0, "exit")


func _sit(slot: int, root: Node3D, local_pos: Vector3, yaw: float, stand_local: Vector3, prompt: String, npc_ok: bool = false, effects: Array = []) -> void:
	var it = InteractableScript.new()
	it.kind = "sit"
	it.prompt = prompt
	it.radius = 1.5
	var o: Vector3 = _origin(slot)
	it.data = {"pos": o + local_pos, "yaw": yaw, "stand_pos": o + stand_local + Vector3(0.0, 0.1, 0.0),
		"outdoor": npc_ok, "occupied_by": null, "effects": effects}
	it.position = local_pos + Vector3(0.0, 0.5, 0.0)
	root.add_child(it)


func _pickup(root: Node3D, local_pos: Vector3, item: String, prompt: String, text: String, effects: Array = []) -> void:
	var it = InteractableScript.new()
	it.kind = "pickup"
	it.prompt = prompt
	it.radius = 1.7
	it.hide_flag = "pk_" + item
	it.data = {"item": item, "text": text, "flag": "pk_" + item, "effects": effects}
	it.position = local_pos
	root.add_child(it)
	var mark = Kit.box(root, local_pos + Vector3(0.0, -0.08, 0.0), Vector3(0.28, 0.06, 0.2), Color(0.95, 0.85, 0.35), false, 2, 1.2)
	mark.add_to_group("pk_mark_" + item)


func _examine(root: Node3D, local_pos: Vector3, prompt: String, text: String, effects: Array = [], once_flag: String = "", radius: float = 1.8) -> void:
	var it = InteractableScript.new()
	it.kind = "examine"
	it.prompt = prompt
	it.radius = radius
	it.data = {"text": text, "effects": effects, "once_flag": once_flag}
	it.position = local_pos + Vector3(0.0, 1.0, 0.0)
	root.add_child(it)


func _door(root: Node3D, local_hinge: Vector3, rot_y: float, door_id: String, locked: bool, locked_text: String, width: float = 1.3) -> void:
	var dr = DoorScript.new()
	dr.door_id = door_id
	dr.width = width
	dr.locked = locked
	dr.key_item = ""
	dr.locked_text = locked_text
	dr.position = local_hinge
	dr.rotation.y = rot_y
	root.add_child(dr)
	dr.setup(hub)


func _npc(root: Node3D, base: Dictionary, local_pos: Vector3, yaw_deg: float) -> void:
	var cfg: Dictionary = base.duplicate(true)
	cfg["home"] = root.position + local_pos
	cfg["yaw_deg"] = yaw_deg
	var npc = NpcScript.new()
	npc.name = "NPC_" + str(cfg["id"])
	npc.configure(cfg, hub)
	npc.position = local_pos + Vector3(0.0, 0.05, 0.0)
	root.add_child(npc)


## 손님: 점심/저녁 시간엔 지정 의자에 앉고 그 밖엔 서 있음 (좌표는 모두 지역 좌표, 내부에서 전역으로 바꿈)
func _diner(slot: int, root: Node3D, idx: int, chair_local: Vector3, stand_local: Vector3, yaw_deg: float) -> void:
	var o: Vector3 = _origin(slot)
	var seed_v: int = idx * 7 + slot
	var look: Dictionary = {
		"sex": "f" if seed_v % 2 == 0 else "m",
		"height": 0.95 + 0.02 * float(idx % 5),
		"skin": NpcData.SKINS[seed_v % NpcData.SKINS.size()],
		"shirt": NpcData.SHIRTS[(seed_v * 3) % NpcData.SHIRTS.size()],
		"pants": NpcData.PANTS[seed_v % NpcData.PANTS.size()],
		"hair": NpcData.HAIRS[seed_v % NpcData.HAIRS.size()],
		"hat": false, "hat_color": Color(0, 0, 0), "acc": "",
	}
	var base: Dictionary = {
		"id": "diner_%d_%d" % [slot, idx], "name": str(NpcData.SURNAMES[seed_v % NpcData.SURNAMES.size()]) + str(NpcData.GIVEN_M[seed_v % NpcData.GIVEN_M.size()]),
		"role": "손님 · 친절함", "speed": 1.0, "look": look,
		"dialogue": NpcData.generic_dialogue("friendly"),
		"routine": [
			{"from": 11.0, "to": 14.5, "mode": "sit", "pos": o + chair_local, "radius": 0.0},
			{"from": 14.5, "to": 17.5, "mode": "stand", "pos": o + stand_local, "radius": 0.0},
			{"from": 17.5, "to": 20.5, "mode": "sit", "pos": o + chair_local, "radius": 0.0},
			{"from": 20.5, "to": 11.0, "mode": "stand", "pos": o + stand_local, "radius": 0.0},
		],
	}
	_npc(root, base, stand_local, yaw_deg)


# ---------------------------------------------------------------- 1) 옥류관

func _build_okryu() -> void:
	var r: Node3D = _slot_root(S_OKRYU, "Int_Okryugwan")
	var H: float = 4.2
	# 큰 홀(입구는 남쪽 +Z) + 서쪽 주방
	Kit.room(r, Vector3.ZERO, 22.0, 14.0, H, Color(0.58, 0.44, 0.3), Color(0.9, 0.86, 0.78), Color(0.86, 0.82, 0.76),
		{"s": Vector2(0.0, 2.4), "w": Vector2(0.0, 1.4)})
	Kit.room(r, Vector3(-16.6, 0.0, 0.0), 11.0, 14.0, H, Color(0.6, 0.6, 0.58), Color(0.86, 0.86, 0.82), Color(0.8, 0.8, 0.78),
		{"e": Vector2(0.0, 1.4)})
	_door(r, Vector3(-11.0, 0.0, -0.65), -PI_ * 0.5, "okryu_kitchen", true, "주방은 직원 전용이라 잠겨 있다. 안내원에게 이야기해 보자.")
	Kit.lamp(r, Vector3(-6.0, H - 0.3, -2.0), 1.2, 11.0)
	Kit.lamp(r, Vector3(6.0, H - 0.3, -2.0), 1.2, 11.0)
	Kit.lamp(r, Vector3(0.0, H - 0.3, 3.0), 1.0, 10.0)
	Kit.lamp(r, Vector3(-16.6, H - 0.3, 0.0), 1.1, 11.0, Color(0.95, 0.97, 1.0))
	Kit.rug(r, Vector3(0.0, 0.0, 3.0), 3.0, 8.0, Color(0.5, 0.16, 0.16))
	Kit.label(r, Vector3(0.0, 3.4, -6.7), "옥류관 (가상 재현)", 1.0, Color(1.0, 0.92, 0.7))
	Kit.box(r, Vector3(0.0, 1.8, -6.82), Vector3(5.0, 2.4, 0.08), Color(0.22, 0.3, 0.38), false, 2, 0.4)

	# 안내 데스크와 안내원
	Kit.counter(r, Vector3(3.2, 0.0, 4.6), 0.0, 2.4, Color(0.4, 0.26, 0.18))
	_npc(r, HOSTESS, Vector3(3.2, 0.0, 3.8), 0.0)

	# 식탁 4개 (각 4석) : 출입 통로(x -1.5 ~ 1.5)는 비워 둠
	var table_pos: Array = [Vector3(-7.0, 0.0, -3.0), Vector3(-7.0, 0.0, 2.0), Vector3(6.0, 0.0, -3.0), Vector3(8.5, 0.0, 1.5)]
	var di: int = 0
	for tp in table_pos:
		Kit.table(r, tp, 1.8, 1.0, 0.75, Color(0.5, 0.34, 0.2))
		var cn: Vector3 = tp + Vector3(0.0, 0.0, -1.1)
		var cs: Vector3 = tp + Vector3(0.0, 0.0, 1.1)
		Kit.chair(r, cn, PI_, Color(0.4, 0.26, 0.2))
		Kit.chair(r, cs, 0.0, Color(0.4, 0.26, 0.2))
		_sit(S_OKRYU, r, cn, PI_, cn + Vector3(0.0, 0.0, -0.9), "의자에 앉기", true)
		_sit(S_OKRYU, r, cs, 0.0, cs + Vector3(0.0, 0.0, 0.9), "의자에 앉기", true)
		if di < 3:
			_diner(S_OKRYU, r, di, cn, cn + Vector3(0.0, 0.0, -1.2), 0.0)
		di += 1

	# 주방
	Kit.counter(r, Vector3(-16.6, 0.0, -2.0), 0.0, 5.0, Color(0.6, 0.6, 0.62))
	Kit.counter(r, Vector3(-16.6, 0.0, 3.0), 0.0, 5.0, Color(0.6, 0.6, 0.62))
	Kit.box(r, Vector3(-19.5, 0.6, -5.5), Vector3(1.2, 1.2, 1.2), Color(0.5, 0.5, 0.52))
	Kit.shelf(r, Vector3(-19.8, 0.0, 0.5), PI_ * 0.5, 4.0, 2.2, Color(0.5, 0.5, 0.5))
	Kit.crate(r, Vector3(-14.0, 0.0, -5.6), Vector3(0.9, 0.9, 0.9))
	Kit.crate(r, Vector3(-13.0, 0.0, -5.6), Vector3(0.7, 0.7, 0.7), Color(0.4, 0.36, 0.28))
	_pickup(r, Vector3(-19.2, 1.35, 0.5), "menu_note", "선반 위 메뉴 수첩",
		"선반 위에 낡은 수첩이 끼워져 있다. 메뉴 뒤쪽에 '지하철역 점검실, 매일 밤 열 시'라고 적혀 있다.",
		[{"op": "quest_step", "id": "q_okryu", "step": 3, "if": {"quest": "q_okryu", "state": "active", "step": 2}}])
	# 직원 휴게 코너
	Kit.table(r, Vector3(-14.0, 0.0, 5.3), 1.6, 0.8, 0.75, Color(0.45, 0.34, 0.24))
	_pickup(r, Vector3(-14.0, 0.85, 5.3), "doc_schedule", "휴게실 근무 교대표",
		"벽에 붙어 있던 근무 교대표다. 한 사람의 이름 옆에만 '야간–지하철역'이라고 적혀 있다.")
	_examine(r, Vector3(-19.5, 0.0, -5.5), "육수 솥 살펴보기",
		"커다란 솥에서 육수가 은은하게 끓고 있다. 구수한 냄새가 가득하다.", [], "", 2.0)
	_examine(r, Vector3(0.0, 0.0, -5.5), "벽의 서화 살펴보기",
		"홀 안쪽 벽에 붓글씨로 쓴 큰 글귀가 걸려 있다. 가상의 식당을 상징하는 장식일 뿐이다.", [], "", 2.2)
	Kit.box(r, Vector3(9.5, 1.9, -6.8), Vector3(2.0, 1.3, 0.06), Color(0.75, 0.88, 1.0), false, 2, 1.4)
	Kit.box(r, Vector3(-4.0, 1.9, -6.8), Vector3(2.0, 1.3, 0.06), Color(0.75, 0.88, 1.0), false, 2, 1.4)

	_exit_portal(r, Vector3(0.0, 0.0, 6.0), "okryu")
	built.append("okryu")


# ---------------------------------------------------------------- 2) 지하철역

func _build_metro() -> void:
	var r: Node3D = _slot_root(S_METRO, "Int_Metro")
	var H: float = 3.4
	var wall_c: Color = Color(0.82, 0.82, 0.8)
	# 매표 홀 (남쪽 입구, 북쪽 벽 오른쪽에 경사 계단 입구)
	Kit.room(r, Vector3.ZERO, 14.0, 10.0, H, Color(0.5, 0.5, 0.52), wall_c, Color(0.76, 0.76, 0.74),
		{"s": Vector2(0.0, 2.2), "n": Vector2(4.0, 3.0)})
	Kit.lamp(r, Vector3(-3.0, H - 0.2, 0.0), 1.1, 9.0, Color(0.95, 0.97, 1.0))
	Kit.lamp(r, Vector3(3.0, H - 0.2, 0.0), 1.1, 9.0, Color(0.95, 0.97, 1.0))
	Kit.label(r, Vector3(4.0, 2.9, -4.7), "승강장 ↓ (정부청사 방면)", 0.55, Color(1.0, 0.9, 0.5))
	Kit.label(r, Vector3(-1.0, 2.7, -4.75), "승강기", 0.6, Color(0.9, 0.95, 1.0))
	Kit.box(r, Vector3(-1.0, 1.25, -4.82), Vector3(1.8, 2.5, 0.1), Color(0.62, 0.64, 0.68), false, 2, 0.3)
	# 매표 창구와 직원
	Kit.counter(r, Vector3(-4.5, 0.0, -1.2), 0.0, 3.0, Color(0.42, 0.42, 0.46))
	_npc(r, METRO_STAFF, Vector3(-4.5, 0.0, -2.2), 180.0)
	# 개찰구 (통로는 열어 둠)
	for gx in [-2.0, -0.7, 0.6]:
		Kit.box(r, Vector3(gx, 0.5, 0.2), Vector3(0.14, 1.0, 1.0), Color(0.35, 0.36, 0.4))
	# 노선도와 광고판
	Kit.box(r, Vector3(-7.0 + 0.1, 1.7, 2.0), Vector3(0.06, 1.0, 2.4), Color(0.2, 0.4, 0.6), false, 2, 0.6)
	Kit.box(r, Vector3(6.95, 1.7, 2.0), Vector3(0.06, 1.0, 2.4), Color(0.6, 0.35, 0.2), false, 2, 0.6)
	Kit.sofa(r, Vector3(5.2, 0.0, 3.6), PI_, Color(0.3, 0.32, 0.38))
	_sit(S_METRO, r, Vector3(5.2, 0.0, 3.6), PI_, Vector3(5.2, 0.0, 2.4), "대합실 의자에 앉기", true)
	_examine(r, Vector3(-4.5, 0.0, 0.6), "운임표 살펴보기",
		"벽에 낡은 운임표가 붙어 있다. 요금보다 열차 시각표가 훨씬 단출하다. 심야 열차는 아예 없다.", [], "", 2.0)

	# 경사 계단: 홀 북쪽 벽(z=-5)에서 북쪽으로 14m 가며 4m 내려감 (걸어서 내려감)
	var drop: float = 4.0
	var run: float = 14.0
	var length: float = sqrt(run * run + drop * drop)
	var ang: float = atan2(drop, run)
	var ramp = Node3D.new()
	ramp.name = "StairRamp"
	ramp.position = Vector3(4.0, -drop * 0.5, -5.0 - run * 0.5)
	ramp.rotation.x = -ang
	r.add_child(ramp)
	Kit.box(ramp, Vector3(0.0, -0.2, 0.0), Vector3(3.0, 0.4, length + 0.4), Color(0.46, 0.46, 0.48), true)
	Kit.box(ramp, Vector3(-1.6, 1.2, 0.0), Vector3(0.2, 2.4, length), wall_c, true)
	Kit.box(ramp, Vector3(1.6, 1.2, 0.0), Vector3(0.2, 2.4, length), wall_c, true)
	Kit.box(ramp, Vector3(0.0, 2.6, 0.0), Vector3(3.4, 0.2, length), Color(0.74, 0.74, 0.72), true)
	var k: int = 0
	while k < 20:
		var zz: float = -length * 0.5 + 0.4 + float(k) * (length - 0.8) / 19.0
		Kit.box(ramp, Vector3(0.0, 0.012, zz), Vector3(2.9, 0.024, 0.08), Color(0.22, 0.22, 0.24), false)
		k += 1
	Kit.lamp(ramp, Vector3(0.0, 2.3, -length * 0.25), 0.9, 8.0, Color(0.95, 0.97, 1.0), false)
	Kit.lamp(ramp, Vector3(0.0, 2.3, length * 0.25), 0.9, 8.0, Color(0.95, 0.97, 1.0), false)

	# 승강장 (바닥 높이 -4)
	var py: float = -4.0
	Kit.room(r, Vector3(4.0, py, -25.0), 24.0, 13.0, 3.8, Color(0.52, 0.52, 0.5), Color(0.8, 0.8, 0.78), Color(0.72, 0.72, 0.7),
		{"s": Vector2(0.0, 3.2), "e": Vector2(1.0, 1.4)})
	Kit.lamp(r, Vector3(-2.0, py + 3.5, -23.0), 1.2, 11.0, Color(0.95, 0.97, 1.0))
	Kit.lamp(r, Vector3(6.0, py + 3.5, -23.0), 1.2, 11.0, Color(0.95, 0.97, 1.0))
	Kit.lamp(r, Vector3(12.0, py + 3.5, -23.0), 1.0, 10.0, Color(0.95, 0.97, 1.0))
	Kit.label(r, Vector3(4.0, py + 2.8, -31.3), "승강장 · 정부청사 방면", 0.8, Color(1.0, 0.9, 0.5))
	# 선로와 열차(장식), 안전선 울타리
	Kit.box(r, Vector3(4.0, py + 0.01, -30.0), Vector3(22.0, 0.02, 2.4), Color(0.12, 0.12, 0.14), false)
	Kit.box(r, Vector3(4.0, py + 0.04, -29.5), Vector3(22.0, 0.05, 0.1), Color(0.55, 0.55, 0.58), false)
	Kit.box(r, Vector3(4.0, py + 0.04, -30.5), Vector3(22.0, 0.05, 0.1), Color(0.55, 0.55, 0.58), false)
	Kit.box(r, Vector3(4.0, py + 1.8, -30.0), Vector3(17.0, 2.6, 2.3), Color(0.28, 0.42, 0.55), false, 2, 0.15)
	Kit.box(r, Vector3(4.0, py + 2.2, -28.82), Vector3(15.0, 0.7, 0.05), Color(0.8, 0.9, 1.0), false, 2, 0.9)
	Kit.box(r, Vector3(4.0, py + 0.5, -28.4), Vector3(22.0, 1.0, 0.2), Color(0.9, 0.78, 0.15))
	# 벤치와 줍는 물건
	Kit.sofa(r, Vector3(-2.0, py, -23.8), 0.0, Color(0.32, 0.34, 0.4))
	Kit.sofa(r, Vector3(10.0, py, -23.8), 0.0, Color(0.32, 0.34, 0.4))
	_sit(S_METRO, r, Vector3(-2.0, py, -23.8), 0.0, Vector3(-2.0, py, -22.4), "승강장 의자에 앉기", true)
	_sit(S_METRO, r, Vector3(10.0, py, -23.8), 0.0, Vector3(10.0, py, -22.4), "승강장 의자에 앉기", true)
	_pickup(r, Vector3(10.0, py + 0.2, -22.9), "doc_ticket", "의자 아래 승차권 묶음",
		"의자 아래에 낡은 승차권 묶음이 떨어져 있다. 모두 같은 시각이 찍혀 있다. 이 역에서 같은 열차를 계속 탄 사람이 있었던 것 같다.")
	# 승강기 (계단의 안전한 대체 이동 수단)
	Kit.box(r, Vector3(-6.0, py + 1.25, -20.0), Vector3(0.12, 2.5, 1.8), Color(0.62, 0.64, 0.68), false, 2, 0.3)
	Kit.label(r, Vector3(-5.9, py + 2.8, -20.0), "승강기", 0.5, Color(0.9, 0.9, 0.9), 2, -PI_ * 0.5)
	_portal(r, Vector3(-5.0, py, -20.0), "승강기로 매표 홀에 가기", "타기",
		_origin(S_METRO) + Vector3(-1.0, 0.1, -2.6), PI_, "지하철역", [], 1.8)
	_portal(r, Vector3(-1.0, 0.0, -3.8), "승강기로 승강장에 가기", "타기",
		_origin(S_METRO) + Vector3(-4.0, py + 0.1, -21.0), 0.0, "지하철 승강장", [], 1.8)

	# 점검실 (승강장 동쪽, 잠긴 문)
	Kit.room(r, Vector3(19.1, py, -25.0), 6.4, 6.0, 3.2, Color(0.4, 0.4, 0.4), Color(0.7, 0.7, 0.68), Color(0.62, 0.62, 0.6),
		{"w": Vector2(1.0, 1.4)})
	_door(r, Vector3(16.0, py, -24.7), -PI_ * 0.5, "metro_maint", true, "점검실은 잠겨 있다. 역 직원에게 이야기해 보자.")
	Kit.lamp(r, Vector3(19.1, py + 3.0, -25.0), 0.9, 8.0, Color(0.85, 0.95, 1.0))
	Kit.shelf(r, Vector3(21.8, py, -25.0), PI_ * 0.5, 3.4, 2.2, Color(0.45, 0.45, 0.45))
	Kit.table(r, Vector3(19.0, py, -27.2), 1.6, 0.8, 0.8, Color(0.36, 0.36, 0.4))
	Kit.crate(r, Vector3(17.6, py, -22.6), Vector3(0.8, 0.8, 0.8))
	_pickup(r, Vector3(19.0, py + 0.9, -27.2), "metro_blueprint", "책상 위 오래된 도면",
		"책상 서랍 아래에서 접힌 도면을 찾았다. 지하철 터널과 정부 구역 지하가 한 줄로 이어지는 가상의 설계도다. 종이 모서리에 작은 글씨: '아직 아무도 끝까지 가 보지 못했다.'",
		[
			{"op": "set_flag", "key": "metro_blueprint_found"},
			{"op": "quest_complete", "id": "q_metro", "if": {"quest": "q_metro", "state": "active", "min_step": 1}},
		])
	_examine(r, Vector3(21.2, py, -22.8), "벽의 환기구 살펴보기",
		"벽 아래쪽 환기구 너머로 차가운 바람이 분다. 멀리서 낮은 기계음이 이어진다. 지금은 들어갈 수 없다.", [], "", 1.9)

	_exit_portal(r, Vector3(0.0, 0.0, 4.0), "metro")
	built.append("metro")


# ---------------------------------------------------------------- 3) 상점

func _build_shop() -> void:
	var r: Node3D = _slot_root(S_SHOP, "Int_Shop")
	var H: float = 3.2
	Kit.room(r, Vector3.ZERO, 11.0, 8.0, H, Color(0.62, 0.55, 0.45), Color(0.9, 0.88, 0.8), Color(0.84, 0.84, 0.8), {"s": Vector2(0.0, 2.0)})
	Kit.lamp(r, Vector3(-2.5, H - 0.2, 0.0), 1.1, 9.0)
	Kit.lamp(r, Vector3(2.5, H - 0.2, 0.0), 1.1, 9.0)
	Kit.label(r, Vector3(0.0, 2.7, -3.7), "상점", 0.9, Color(1.0, 0.95, 0.75))
	Kit.counter(r, Vector3(3.2, 0.0, -1.8), 0.0, 3.0, Color(0.45, 0.33, 0.22))
	_npc(r, SHOP_OWNER, Vector3(3.2, 0.0, -2.8), 180.0)
	Kit.shelf(r, Vector3(-3.0, 0.0, -3.7), PI_, 3.6, 2.0, Color(0.5, 0.4, 0.3))
	Kit.shelf(r, Vector3(-5.2, 0.0, 0.0), PI_ * 0.5, 4.0, 1.9, Color(0.5, 0.4, 0.3))
	Kit.shelf(r, Vector3(-1.5, 0.0, 0.5), 0.0, 2.6, 1.5, Color(0.5, 0.4, 0.3))
	Kit.crate(r, Vector3(5.0, 0.0, 1.5), Vector3(0.9, 0.7, 0.9))
	Kit.crate(r, Vector3(4.0, 0.0, 2.5), Vector3(0.7, 0.6, 0.7), Color(0.4, 0.36, 0.28))
	_examine(r, Vector3(-3.0, 0.0, -2.6), "진열대 살펴보기",
		"과자와 음료, 건전지와 비누가 줄지어 놓여 있다. 맨 아래 칸에는 파란 우산이 몇 자루 꽂혀 있다.", [], "", 2.2)
	_examine(r, Vector3(3.2, 0.0, -0.9), "계산대 서랍 살펴보기",
		"계산대 서랍에는 영수증 묶음과 열쇠고리가 들어 있다. 영수증은 모두 같은 날짜인데, 몇 장은 시각이 거꾸로 적혀 있다.", [], "", 1.8)
	_exit_portal(r, Vector3(0.0, 0.0, 3.3), "shop")
	built.append("shop")
