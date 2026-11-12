extends Node3D
## 건물 5곳(찻집, 아파트 3동 12호, 호텔(로비+2층), 행정사무소, 비밀 지하시설)의 겉모습과 내부를 만듭니다.
## 겉모습은 빈 자리를 검사해서 도시 안에 놓고(직접 배치하신 건물과 겹치지 않게),
## 내부는 도시에서 멀리 떨어진 높은 곳(y=300)에 따로 만들어 문을 통해 순간이동으로 연결합니다.
## 이 세계와 인물은 모두 가상입니다.

const Kit = preload("res://scripts/interior/interior_kit.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")
const DoorScript = preload("res://scripts/interior/door.gd")
const NpcScript = preload("res://scripts/npc/npc.gd")
const NpcData = preload("res://scripts/data/npc_data.gd")

const BASE_Y: float = 300.0
const SLOT: float = 100.0
const WALL_H: float = 3.2
const PI_: float = 3.14159265

## 슬롯 번호 -> 내부 공간
const S_TEA: int = 0
const S_APT: int = 1
const S_HOTEL: int = 2
const S_HOTEL2: int = 3
const S_OFFICE: int = 4
const S_UG: int = 5

var hub = null
var _world: Node3D = null
var _roots: Dictionary = {}
var _ext: Dictionary = {}


func _origin(slot: int) -> Vector3:
	return Vector3(float(slot) * SLOT, BASE_Y, 0.0)


func _slot_root(slot: int, nm: String) -> Node3D:
	var r = Node3D.new()
	r.name = nm
	r.position = _origin(slot)
	add_child(r)
	_roots[slot] = r
	return r


func build(world: Node3D, hub_ref) -> void:
	hub = hub_ref
	_world = world
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 1) 겉모습 (빈 자리 검사 때문에 하나 만들 때마다 물리 프레임을 기다림)
	_ext["tea"] = await _make_exterior({
		"id": "tea", "name": "찻집", "sign": "찻집", "pref": Vector3(22.0, 0.0, 26.0),
		"size": Vector3(9.0, 5.5, 8.0), "color": Color(0.62, 0.42, 0.3), "roof": Color(0.3, 0.2, 0.16)})
	_ext["hotel"] = await _make_exterior({
		"id": "hotel", "name": "호텔", "sign": "호텔", "pref": Vector3(-28.0, 0.0, 28.0),
		"size": Vector3(14.0, 17.0, 11.0), "color": Color(0.72, 0.7, 0.64), "roof": Color(0.28, 0.3, 0.34)})
	_ext["apt"] = await _make_exterior({
		"id": "apt", "name": "아파트 3동", "sign": "3동 12호", "pref": Vector3(-42.0, 0.0, -24.0),
		"size": Vector3(12.0, 19.0, 10.0), "color": Color(0.66, 0.68, 0.7), "roof": Color(0.32, 0.34, 0.36)})
	_ext["office"] = await _make_exterior({
		"id": "office", "name": "행정사무소", "sign": "행정사무소", "pref": Vector3(32.0, 0.0, -28.0),
		"size": Vector3(16.0, 9.0, 10.0), "color": Color(0.74, 0.72, 0.62), "roof": Color(0.35, 0.3, 0.28)})

	# 2) 내부
	_build_teahouse()
	_build_apartment()
	_build_hotel()
	_build_hotel_floor2()
	_build_office()
	_build_underground()

	# 3) 건물 입구 (바깥 -> 안)
	_enter_portal("tea", _origin(S_TEA) + Vector3(0.0, 0.1, 3.0), 0.0, "찻집 입장", "찻집", {}, [
		{"op": "quest_step", "id": "q_tea", "step": 1, "if": {"quest": "q_tea", "state": "active", "step": 0}}])
	_enter_portal("hotel", _origin(S_HOTEL) + Vector3(0.0, 0.1, 3.8), 0.0, "호텔 입장", "호텔 로비", {}, [])
	_enter_portal("apt", _origin(S_APT) + Vector3(3.5, 0.1, 2.8), 0.0, "아파트 3동 12호 입장", "아파트 3동 12호",
		{"requires": {"item": "apartment_key"}, "locked_text": "현관이 잠겨 있다. 12호 열쇠가 필요하다."}, [
		{"op": "quest_step", "id": "q_contact", "step": 3, "if": {"quest": "q_contact", "state": "active", "step": 2}}])
	_enter_portal("office", _origin(S_OFFICE) + Vector3(0.0, 0.1, 3.4), 0.0, "행정사무소 입장", "행정사무소", {}, [])

	if hub != null:
		hub.respawn = {"pos": _origin(S_APT) + Vector3(-2.5, 0.1, -2.0), "yaw": PI_, "location": "아파트 3동 12호"}
	print("[PYONGYANG] 건물 내부 6곳을 만들었습니다.")


# ---------------------------------------------------------------- 공통 도우미

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
	# 창문
	var rows: int = int((h - 1.5) / 3.4)
	var cols: int = maxi(2, int(w / 3.0))
	for r in range(rows):
		for c in range(cols):
			var x: float = -w * 0.5 + (float(c) + 0.5) * w / float(cols)
			var y: float = 2.2 + float(r) * 3.4
			if r == 0 and absf(x) < 1.8:
				continue
			Kit.box(root, Vector3(x, y, d * 0.5 + 0.04), Vector3(1.3, 1.5, 0.1), Color(0.16, 0.22, 0.3), false, 1)
	# 출입문, 차양, 간판
	Kit.box(root, Vector3(0.0, 1.3, d * 0.5 + 0.06), Vector3(1.9, 2.6, 0.14), Color(0.22, 0.14, 0.1), false, 1)
	Kit.box(root, Vector3(0.0, 2.9, d * 0.5 + 0.7), Vector3(3.2, 0.12, 1.4), spec["roof"], false, 1)
	Kit.label(root, Vector3(0.0, 3.55, d * 0.5 + 0.2), str(spec["sign"]), 1.3, Color(1.0, 0.95, 0.75), 1)

	var front: Vector3 = spot + Vector3(0.0, 0.1, d * 0.5 + 4.0)
	var res: Dictionary = {"root": root, "spot": spot, "front": front, "depth": d, "name": spec["name"]}
	if hub != null:
		hub.register_poi(str(spec["id"]), str(spec["name"]), front)
	# 다음 건물이 이 자리를 피하도록 물리 엔진에 등록될 때까지 기다림
	await get_tree().physics_frame
	await get_tree().physics_frame
	return res


func _enter_portal(ext_id: String, dest: Vector3, dest_yaw: float, prompt: String, location: String, extra: Dictionary, effects: Array) -> void:
	var e: Dictionary = _ext[ext_id]
	var it = InteractableScript.new()
	it.kind = "enter"
	it.prompt = prompt
	it.radius = 2.4
	var data: Dictionary = {"dest": dest, "dest_yaw": dest_yaw, "location": location, "effects": effects}
	for k in extra.keys():
		data[k] = extra[k]
	it.data = data
	it.position = Vector3(0.0, 1.0, float(e["depth"]) * 0.5 + 1.4)
	e["root"].add_child(it)


func _portal(root: Node3D, local_pos: Vector3, prompt: String, button: String, dest: Vector3, dest_yaw: float, location: String, effects: Array = [], radius: float = 1.9, kind: String = "portal", requires_flag: String = "") -> void:
	var it = InteractableScript.new()
	it.kind = kind
	it.prompt = prompt
	it.button_text = button
	it.radius = radius
	it.requires_flag = requires_flag
	it.data = {"dest": dest, "dest_yaw": dest_yaw, "location": location, "effects": effects}
	it.position = local_pos + Vector3(0.0, 1.0, 0.0)
	root.add_child(it)


func _exit_portal(root: Node3D, local_pos: Vector3, ext_id: String, location: String = "") -> void:
	var e: Dictionary = _ext[ext_id]
	_portal(root, local_pos, "밖으로 나가기", "나가기", e["front"], PI_, location, [], 2.0, "exit")


func _sit(slot: int, root: Node3D, local_pos: Vector3, yaw: float, stand_local: Vector3, prompt: String, effects: Array = []) -> void:
	var it = InteractableScript.new()
	it.kind = "sit"
	it.prompt = prompt
	it.radius = 1.5
	var o: Vector3 = _origin(slot)
	it.data = {"pos": o + local_pos, "yaw": yaw, "stand_pos": o + stand_local + Vector3(0.0, 0.1, 0.0),
		"outdoor": false, "occupied_by": null, "effects": effects}
	it.position = local_pos + Vector3(0.0, 0.5, 0.0)
	root.add_child(it)


## 침대에 눕기(V1). foot_local 은 발 쪽 위치(침대 윗면 높이), yaw 는 머리가 향하는 방향의 침대 회전값
func _lie(slot: int, root: Node3D, foot_local: Vector3, yaw: float, stand_local: Vector3, prompt: String) -> void:
	var it = InteractableScript.new()
	it.kind = "sit"
	it.prompt = prompt
	it.button_text = "눕기"
	it.radius = 1.9
	var o: Vector3 = _origin(slot)
	it.data = {"pos": o + foot_local, "yaw": yaw, "stand_pos": o + stand_local + Vector3(0.0, 0.1, 0.0),
		"outdoor": false, "occupied_by": null, "effects": [], "lie": true}
	it.position = foot_local + Vector3(0.0, 0.6, 0.0) + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 0.8)
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
	# 바닥/책상 위에 보이는 작은 물건 표시
	var mark = Kit.box(root, local_pos + Vector3(0.0, -0.08, 0.0), Vector3(0.28, 0.06, 0.2), Color(0.95, 0.85, 0.35), false, 2, 1.2)
	mark.add_to_group("pk_mark_" + item)


func _examine(root: Node3D, local_pos: Vector3, prompt: String, text: String, effects: Array = [], once_flag: String = "", radius: float = 1.8, hide_flag: String = "") -> void:
	var it = InteractableScript.new()
	it.kind = "examine"
	it.prompt = prompt
	it.radius = radius
	it.hide_flag = hide_flag
	it.data = {"text": text, "effects": effects, "once_flag": once_flag}
	it.position = local_pos + Vector3(0.0, 1.0, 0.0)
	root.add_child(it)


func _door(root: Node3D, local_hinge: Vector3, rot_y: float, door_id: String, locked: bool, key_item: String, locked_text: String, width: float = 1.3) -> Node3D:
	var dr = DoorScript.new()
	dr.door_id = door_id
	dr.width = width
	dr.locked = locked
	dr.key_item = key_item
	dr.locked_text = locked_text
	dr.position = local_hinge
	dr.rotation.y = rot_y
	root.add_child(dr)
	dr.setup(hub)
	return dr


func _npc(root: Node3D, base: Dictionary, local_pos: Vector3, yaw_deg: float) -> void:
	var cfg: Dictionary = base.duplicate(true)
	cfg["home"] = local_pos
	cfg["yaw_deg"] = yaw_deg
	var npc = NpcScript.new()
	npc.name = "NPC_" + str(cfg["id"])
	npc.configure(cfg, hub)
	npc.position = local_pos + Vector3(0.0, 0.05, 0.0)
	root.add_child(npc)


func _plant(root: Node3D, p: Vector3) -> void:
	Kit.box(root, p + Vector3(0.0, 0.25, 0.0), Vector3(0.5, 0.5, 0.5), Color(0.4, 0.28, 0.2))
	Kit.box(root, p + Vector3(0.0, 0.85, 0.0), Vector3(0.7, 0.8, 0.7), Color(0.2, 0.45, 0.22), false)


func _window_glow(root: Node3D, p: Vector3, size: Vector2, yaw: float = 0.0) -> void:
	var b = Kit.box(root, p, Vector3(size.x, size.y, 0.06), Color(0.75, 0.88, 1.0), false, 2, 1.6)
	b.rotation.y = yaw


# ---------------------------------------------------------------- 1) 찻집

func _build_teahouse() -> void:
	var r: Node3D = _slot_root(S_TEA, "Int_Teahouse")
	Kit.room(r, Vector3.ZERO, 12.0, 9.0, WALL_H, Color(0.5, 0.38, 0.26), Color(0.84, 0.76, 0.62), Color(0.68, 0.6, 0.48), {"s": Vector2(0.0, 1.8)})
	Kit.rug(r, Vector3(0.5, 0.0, 0.5), 4.5, 3.2, Color(0.55, 0.22, 0.2))
	Kit.lamp(r, Vector3(-3.0, WALL_H - 0.3, -1.0), 1.1, 9.0)
	Kit.lamp(r, Vector3(3.0, WALL_H - 0.3, 0.5), 1.1, 9.0)
	Kit.lamp(r, Vector3(0.0, WALL_H - 0.3, 3.0), 0.7, 7.0)
	_window_glow(r, Vector3(-1.0, 1.9, -4.33), Vector2(1.8, 1.2))
	_window_glow(r, Vector3(1.8, 1.9, -4.33), Vector2(1.8, 1.2))
	Kit.label(r, Vector3(-3.5, 2.5, -4.3), "찻집 · 차 한 잔", 0.8, Color(1.0, 0.92, 0.7))
	_plant(r, Vector3(5.2, 0.0, 3.4))

	# 카운터 + 주인
	Kit.counter(r, Vector3(-3.5, 0.0, -2.9), 0.0, 2.6)
	Kit.box(r, Vector3(-3.5, 1.9, -4.3), Vector3(2.4, 0.9, 0.3), Color(0.38, 0.26, 0.18))
	_npc(r, NpcData.SHOPKEEPER, Vector3(-3.5, 0.0, -3.85), 180.0)

	# 창가 소파 (퀘스트: 앉기 -> 임무 완료)
	Kit.sofa(r, Vector3(3.8, 0.0, -3.7), PI_)
	Kit.table(r, Vector3(3.8, 0.0, -2.3), 1.2, 0.7, 0.45, Color(0.45, 0.32, 0.2))
	_sit(S_TEA, r, Vector3(3.8, 0.0, -3.7), PI_, Vector3(3.8, 0.0, -1.2), "창가 소파에 앉기", [
		{"op": "quest_complete", "id": "q_tea", "if": {"quest": "q_tea", "state": "active", "step": 2}}])
	# 서쪽 소파
	Kit.sofa(r, Vector3(-5.2, 0.0, 1.2), -PI_ * 0.5, Color(0.25, 0.38, 0.35))
	_sit(S_TEA, r, Vector3(-5.2, 0.0, 1.2), -PI_ * 0.5, Vector3(-3.6, 0.0, 1.2), "소파에 앉기", [
		{"op": "quest_complete", "id": "q_tea", "if": {"quest": "q_tea", "state": "active", "step": 2}}])
	# 둥근 탁자와 의자
	Kit.table(r, Vector3(-1.2, 0.0, 1.8), 1.0, 1.0)
	Kit.chair(r, Vector3(-1.2, 0.0, 2.9), 0.0)
	Kit.chair(r, Vector3(-1.2, 0.0, 0.7), PI_)
	Kit.chair(r, Vector3(0.0, 0.0, 1.8), PI_ * 0.5)
	var qe: Array = [{"op": "quest_complete", "id": "q_tea", "if": {"quest": "q_tea", "state": "active", "step": 2}}]
	_sit(S_TEA, r, Vector3(-1.2, 0.0, 2.9), 0.0, Vector3(-1.2, 0.0, 3.6), "의자에 앉기", qe)
	_sit(S_TEA, r, Vector3(-1.2, 0.0, 0.7), PI_, Vector3(-1.2, 0.0, -0.1), "의자에 앉기", qe)
	_sit(S_TEA, r, Vector3(0.0, 0.0, 1.8), PI_ * 0.5, Vector3(0.9, 0.0, 1.8), "의자에 앉기", qe)

	_exit_portal(r, Vector3(0.0, 0.0, 3.9), "tea")


# ---------------------------------------------------------------- 2) 아파트 3동 12호

func _build_apartment() -> void:
	var r: Node3D = _slot_root(S_APT, "Int_Apartment")
	# 거실: 남쪽 벽에 현관, 동쪽 벽에 침실 문, 북쪽 벽에 책장 뒤 통로 틈
	Kit.room(r, Vector3.ZERO, 10.0, 8.0, WALL_H, Color(0.62, 0.52, 0.4), Color(0.86, 0.84, 0.78), Color(0.8, 0.8, 0.76),
		{"s": Vector2(3.5, 1.4), "e": Vector2(-1.0, 1.4), "n": Vector2(-2.5, 1.5)})
	# 침실
	Kit.room(r, Vector3(8.75, 0.0, 0.0), 7.0, 8.0, WALL_H, Color(0.55, 0.5, 0.45), Color(0.8, 0.78, 0.84), Color(0.78, 0.78, 0.78),
		{"w": Vector2(-1.0, 1.4)})
	_door(r, Vector3(5.2, 0.0, -1.7), -PI_ * 0.5, "bedroom", false, "", "")

	Kit.lamp(r, Vector3(-2.0, WALL_H - 0.3, 0.0), 1.0, 9.0)
	Kit.lamp(r, Vector3(2.5, WALL_H - 0.3, -1.0), 0.9, 8.0)
	Kit.lamp(r, Vector3(8.75, WALL_H - 0.3, 0.0), 0.9, 8.0)
	Kit.rug(r, Vector3(-2.0, 0.0, 1.6), 3.4, 2.4, Color(0.3, 0.38, 0.5))
	_window_glow(r, Vector3(1.0, 1.7, 3.85), Vector2(1.6, 1.3), PI_)

	# 거실 가구
	Kit.sofa(r, Vector3(-2.0, 0.0, 3.1), 0.0, Color(0.4, 0.3, 0.26))
	Kit.table(r, Vector3(-2.0, 0.0, 1.4), 1.2, 0.6, 0.42)
	_sit(S_APT, r, Vector3(-2.0, 0.0, 3.1), 0.0, Vector3(-3.8, 0.0, 2.4), "소파에 앉기")
	Kit.table(r, Vector3(2.8, 0.0, -0.4), 1.6, 0.9)
	Kit.chair(r, Vector3(2.8, 0.0, 0.6), 0.0)
	Kit.chair(r, Vector3(2.8, 0.0, -1.4), PI_)
	_sit(S_APT, r, Vector3(2.8, 0.0, 0.6), 0.0, Vector3(2.8, 0.0, 1.5), "의자에 앉기")
	Kit.box(r, Vector3(2.5, 1.4, -3.8), Vector3(1.6, 0.9, 0.1), Color(0.05, 0.05, 0.07), false)
	Kit.box(r, Vector3(2.5, 0.35, -3.5), Vector3(1.8, 0.7, 0.5), Color(0.35, 0.28, 0.22))

	# 책장 = 비밀 통로 입구. 처음엔 책장이 틈을 막고 있음
	var shelf: Node3D = Kit.shelf(r, Vector3(-2.5, 0.0, -3.62), PI_, 1.6, 2.4)
	shelf.add_to_group("reveal_shelf")
	# 벽 구멍을 막는 어두운 판(충돌 있음): 책장이 치워진 뒤 "어두운 계단 입구"로 보임
	Kit.box(r, Vector3(-2.5, 1.6, -4.0), Vector3(1.5, 3.2, 0.3), Color(0.03, 0.03, 0.04))
	Kit.label(r, Vector3(-2.5, 1.0, -3.84), "▼ 계단", 0.6, Color(0.7, 0.9, 0.8))
	_examine(r, Vector3(-2.5, 0.0, -2.6), "책장 살펴보기",
		"책장 앞에 서니 바닥에 긁힌 자국이 보인다. 책 한 권이 유난히 반들거려서 당겨 보니, 책장이 옆으로 밀리며 어두운 계단이 드러났다!",
		[
			{"op": "set_flag", "key": "passage_found"},
			{"op": "reveal", "id": "shelf"},
			{"op": "quest_step", "id": "q_contact", "step": 4, "if": {"quest": "q_contact", "state": "active", "step": 3}},
		], "", 1.9, "passage_found")
	_portal(r, Vector3(-2.5, 0.0, -2.9), "비밀 통로로 내려가기", "내려가기",
		_origin(S_UG) + Vector3(-8.5, 0.1, 0.0), -PI_ * 0.5, "비밀 지하시설",
		[{"op": "quest_step", "id": "q_contact", "step": 5, "if": {"quest": "q_contact", "state": "active", "step": 4}}],
		1.6, "portal", "passage_found")

	# 침실
	Kit.bed(r, Vector3(10.6, 0.0, 2.5), 0.0)
	_lie(S_APT, r, Vector3(10.6, 0.53, 1.6), 0.0, Vector3(9.3, 0.0, 2.2), "침대에 눕기")
	Kit.table(r, Vector3(7.5, 0.0, -3.2), 1.4, 0.7)
	Kit.chair(r, Vector3(7.5, 0.0, -2.4), 0.0)
	_sit(S_APT, r, Vector3(7.5, 0.0, -2.4), 0.0, Vector3(7.5, 0.0, -1.5), "의자에 앉기")
	Kit.shelf(r, Vector3(11.2, 0.0, -3.5), PI_, 1.4, 1.8)
	Kit.crate(r, Vector3(9.2, 0.0, 3.2), Vector3(0.5, 0.7, 0.5), Color(0.45, 0.35, 0.26))
	_examine(r, Vector3(11.2, 0.0, -2.5), "서랍장 열어 보기", "서랍장 서랍을 하나씩 열어 본다. 오래된 양말과 단추, 접힌 영수증뿐이다. 맨 아래 서랍만 유난히 가볍다.", [], "", 1.8)
	_pickup(r, Vector3(7.5, 0.83, -3.2), "hint_note", "책상 위 쪽지", "책상 위의 쪽지: '거실 책장, 세 번째 칸. 바람이 샌다면 그 뒤를 봐.' 연필 글씨가 급하게 휘갈겨져 있다.")
	_pickup(r, Vector3(9.2, 0.78, 3.2), "old_photo", "침대 옆 사진", "빛바랜 가족사진이다. 뒷면에는 '3동 12호, 잊지 말 것'이라고 적혀 있다.")

	_exit_portal(r, Vector3(3.5, 0.0, 3.5), "apt")


# ---------------------------------------------------------------- 3) 호텔 로비 + 2층

func _build_hotel() -> void:
	var r: Node3D = _slot_root(S_HOTEL, "Int_HotelLobby")
	Kit.room(r, Vector3.ZERO, 14.0, 10.0, WALL_H + 0.4, Color(0.62, 0.58, 0.52), Color(0.88, 0.84, 0.76), Color(0.8, 0.78, 0.74), {"s": Vector2(0.0, 2.0)})
	Kit.rug(r, Vector3(0.0, 0.0, 1.0), 6.0, 4.0, Color(0.5, 0.18, 0.2))
	Kit.lamp(r, Vector3(-4.0, WALL_H, -1.0), 1.2, 10.0)
	Kit.lamp(r, Vector3(4.0, WALL_H, -1.0), 1.2, 10.0)
	Kit.lamp(r, Vector3(0.0, WALL_H, 2.5), 1.0, 9.0)
	Kit.label(r, Vector3(0.0, 2.6, -4.7), "프런트", 0.9, Color(1.0, 0.92, 0.7))
	Kit.counter(r, Vector3(0.0, 0.0, -2.5), 0.0, 3.8, Color(0.3, 0.22, 0.18))
	_npc(r, NpcData.RECEPTIONIST, Vector3(0.0, 0.0, -3.6), 180.0)
	Kit.sofa(r, Vector3(-6.0, 0.0, 1.5), -PI_ * 0.5, Color(0.3, 0.3, 0.42))
	_sit(S_HOTEL, r, Vector3(-6.0, 0.0, 1.5), -PI_ * 0.5, Vector3(-4.3, 0.0, 1.5), "소파에 앉기")
	Kit.sofa(r, Vector3(-6.0, 0.0, -1.5), -PI_ * 0.5, Color(0.3, 0.3, 0.42))
	_sit(S_HOTEL, r, Vector3(-6.0, 0.0, -1.5), -PI_ * 0.5, Vector3(-4.3, 0.0, -1.5), "소파에 앉기")
	_plant(r, Vector3(5.8, 0.0, 3.6))
	_plant(r, Vector3(-5.8, 0.0, 3.6))
	# 엘리베이터 (동쪽 벽)
	Kit.box(r, Vector3(6.8, 1.25, 0.0), Vector3(0.12, 2.5, 1.8), Color(0.62, 0.64, 0.68), false, 2, 0.3)
	Kit.label(r, Vector3(6.6, 2.8, 0.0), "엘리베이터", 0.5, Color(0.9, 0.9, 0.9), 2, -PI_ * 0.5)
	_portal(r, Vector3(6.0, 0.0, 0.0), "엘리베이터로 2층에 가기", "타기",
		_origin(S_HOTEL2) + Vector3(-5.5, 0.1, 0.0), -PI_ * 0.5, "호텔 2층", [], 1.8)
	_exit_portal(r, Vector3(0.0, 0.0, 4.2), "hotel")


func _build_hotel_floor2() -> void:
	var r: Node3D = _slot_root(S_HOTEL2, "Int_HotelFloor2")
	# 복도 16x4, 남쪽 벽에 201호 문 구멍
	Kit.room(r, Vector3.ZERO, 16.0, 4.0, WALL_H, Color(0.5, 0.2, 0.22), Color(0.88, 0.84, 0.74), Color(0.8, 0.78, 0.74), {"s": Vector2(3.0, 1.4)})
	Kit.lamp(r, Vector3(-4.0, WALL_H - 0.2, 0.0), 1.0, 8.0)
	Kit.lamp(r, Vector3(2.0, WALL_H - 0.2, 0.0), 1.0, 8.0)
	Kit.lamp(r, Vector3(6.0, WALL_H - 0.2, 0.0), 0.8, 8.0)
	Kit.box(r, Vector3(-7.8, 1.25, 0.0), Vector3(0.12, 2.5, 1.8), Color(0.62, 0.64, 0.68), false, 2, 0.3)
	Kit.label(r, Vector3(-7.6, 2.8, 0.0), "엘리베이터", 0.5, Color(0.9, 0.9, 0.9), 2, PI_ * 0.5)
	Kit.label(r, Vector3(3.0, 2.7, 1.8), "201", 0.9, Color(1.0, 0.9, 0.6), 2, PI_)
	_portal(r, Vector3(-7.0, 0.0, 0.0), "엘리베이터로 1층에 가기", "타기",
		_origin(S_HOTEL) + Vector3(6.0, 0.1, 0.0), PI_ * 0.5, "호텔 로비", [], 1.8)
	# 201호
	Kit.room(r, Vector3(3.0, 0.0, 4.65), 6.0, 5.0, WALL_H, Color(0.55, 0.45, 0.38), Color(0.82, 0.8, 0.86), Color(0.8, 0.8, 0.8), {"n": Vector2(0.0, 1.4)})
	_door(r, Vector3(2.3, 0.0, 2.0), 0.0, "room201", false, "", "")
	Kit.lamp(r, Vector3(3.0, WALL_H - 0.2, 4.65), 1.0, 7.0)
	Kit.bed(r, Vector3(5.2, 0.0, 5.6), -PI_ * 0.5, Color(0.5, 0.35, 0.3))
	_lie(S_HOTEL2, r, Vector3(5.9, 0.53, 5.6), -PI_ * 0.5, Vector3(5.2, 0.0, 4.4), "침대에 눕기")
	Kit.table(r, Vector3(0.9, 0.0, 6.5), 1.3, 0.6)
	Kit.chair(r, Vector3(1.8, 0.0, 6.5), PI_ * 0.5)
	_sit(S_HOTEL2, r, Vector3(1.8, 0.0, 6.5), PI_ * 0.5, Vector3(2.7, 0.0, 6.5), "의자에 앉기")
	_window_glow(r, Vector3(3.0, 1.8, 7.12), Vector2(2.0, 1.3), PI_)
	_pickup(r, Vector3(0.9, 0.82, 6.5), "hotel_log", "책상 위 투숙 기록부", "서랍 속 투숙 기록부다. '푸른 우산'이라는 메모와 함께 몇 개의 날짜가 적혀 있다. 최근 날짜 옆에는 '3동'이라고만 쓰여 있다.")


# ---------------------------------------------------------------- 4) 행정사무소

func _build_office() -> void:
	var r: Node3D = _slot_root(S_OFFICE, "Int_Office")
	Kit.room(r, Vector3.ZERO, 14.0, 9.0, WALL_H, Color(0.6, 0.6, 0.58), Color(0.86, 0.86, 0.82), Color(0.82, 0.82, 0.8),
		{"s": Vector2(0.0, 2.0), "e": Vector2(-1.0, 1.4)})
	Kit.lamp(r, Vector3(-3.0, WALL_H - 0.2, -1.0), 1.2, 10.0, Color(0.95, 0.97, 1.0))
	Kit.lamp(r, Vector3(3.0, WALL_H - 0.2, 0.0), 1.2, 10.0, Color(0.95, 0.97, 1.0))
	Kit.label(r, Vector3(-2.5, 2.7, -4.3), "접수", 0.9, Color(1.0, 0.95, 0.8))
	Kit.label(r, Vector3(4.5, 2.4, -4.3), "공지: 문서실 열람은 허가증 필요", 0.45, Color(0.95, 0.95, 0.8))
	Kit.counter(r, Vector3(-2.5, 0.0, -1.6), 0.0, 4.0, Color(0.5, 0.5, 0.48))
	_npc(r, NpcData.OFFICE_CLERK, Vector3(-2.5, 0.0, -2.8), 180.0)
	# 대기 의자
	for i in range(3):
		var cx: float = 3.0 + 1.3 * float(i)
		Kit.chair(r, Vector3(cx, 0.0, 1.5), 0.0, Color(0.3, 0.34, 0.4))
		_sit(S_OFFICE, r, Vector3(cx, 0.0, 1.5), 0.0, Vector3(cx, 0.0, 2.4), "대기 의자에 앉기")
	_plant(r, Vector3(-6.0, 0.0, 3.6))

	# 문서실 (잠긴 문, 허가증 필요)
	Kit.room(r, Vector3(10.4, 0.0, -1.0), 6.0, 6.0, WALL_H, Color(0.5, 0.46, 0.4), Color(0.78, 0.76, 0.7), Color(0.74, 0.74, 0.72), {"w": Vector2(0.0, 1.4)})
	_door(r, Vector3(7.2, 0.0, -1.7), -PI_ * 0.5, "file_room", true, "office_pass", "문서실 문이 잠겨 있다. 열람 허가증이 필요하다.")
	Kit.lamp(r, Vector3(10.4, WALL_H - 0.2, -1.0), 1.0, 8.0, Color(0.95, 0.97, 1.0))
	Kit.shelf(r, Vector3(10.4, 0.0, -3.6), PI_, 4.0, 2.4)
	Kit.shelf(r, Vector3(13.0, 0.0, -1.0), PI_ * 0.5, 3.0, 2.4)
	Kit.table(r, Vector3(10.4, 0.0, 0.8), 1.8, 0.8)
	_pickup(r, Vector3(10.4, 0.85, 0.8), "ledger", "낡은 장부", "먼지 쌓인 낡은 장부다. 오래전 시설 반입 목록이 적혀 있다. 한 줄이 눈에 띈다: '지하 환기 통로 – 3동 연결'.",
		[
			{"op": "quest_complete", "id": "q_office", "if": {"quest": "q_office", "state": "active", "step": 1}},
		])

	_exit_portal(r, Vector3(0.0, 0.0, 4.0), "office")


# ---------------------------------------------------------------- 5) 비밀 지하시설

func _build_underground() -> void:
	var r: Node3D = _slot_root(S_UG, "Int_Underground")
	var wc: Color = Color(0.42, 0.45, 0.45)
	var fc: Color = Color(0.3, 0.3, 0.32)
	var cc: Color = Color(0.34, 0.35, 0.36)
	# 복도 24x4: 북쪽에 통제실(x=-3), 서버실(x=6) 문 구멍
	Kit.room(r, Vector3.ZERO, 24.0, 4.0, WALL_H, fc, wc, cc, {"n": [Vector2(-3.0, 1.4), Vector2(6.0, 1.4)]})
	Kit.lamp(r, Vector3(-8.0, WALL_H - 0.2, 0.0), 0.7, 7.0, Color(0.7, 1.0, 0.85))
	Kit.lamp(r, Vector3(-1.0, WALL_H - 0.2, 0.0), 0.7, 7.0, Color(0.7, 1.0, 0.85))
	Kit.lamp(r, Vector3(6.0, WALL_H - 0.2, 0.0), 0.7, 7.0, Color(0.7, 1.0, 0.85))
	Kit.lamp(r, Vector3(11.0, WALL_H - 0.2, 0.0), 0.7, 7.0, Color(0.7, 1.0, 0.85))
	Kit.label(r, Vector3(-11.8, 2.4, 0.0), "계단 ↑", 0.6, Color(0.8, 1.0, 0.9), 2, PI_ * 0.5)
	Kit.label(r, Vector3(11.8, 2.4, 0.0), "비상 출구 →", 0.6, Color(1.0, 0.7, 0.6), 2, -PI_ * 0.5)

	# 통제실 (문 닫혀 있음, 열쇠 카드 보관)
	Kit.room(r, Vector3(-3.0, 0.0, -5.15), 7.0, 6.0, WALL_H, fc, wc, cc, {"s": Vector2(0.0, 1.4)})
	_door(r, Vector3(-3.7, 0.0, -2.0), 0.0, "control_room", false, "", "")
	Kit.lamp(r, Vector3(-3.0, WALL_H - 0.2, -5.15), 0.9, 7.0, Color(0.8, 0.95, 1.0))
	Kit.table(r, Vector3(-3.0, 0.0, -6.9), 2.2, 0.9, 0.8, Color(0.35, 0.36, 0.4))
	Kit.chair(r, Vector3(-3.0, 0.0, -5.9), 0.0, Color(0.2, 0.2, 0.24))
	Kit.box(r, Vector3(-3.6, 1.1, -7.0), Vector3(0.7, 0.45, 0.06), Color(0.3, 0.6, 1.0), false, 2, 1.5)
	Kit.box(r, Vector3(-2.4, 1.1, -7.0), Vector3(0.7, 0.45, 0.06), Color(0.3, 1.0, 0.6), false, 2, 1.5)
	Kit.crate(r, Vector3(-5.6, 0.0, -7.2), Vector3(0.9, 0.9, 0.9))
	Kit.crate(r, Vector3(-5.6, 0.9, -7.2), Vector3(0.6, 0.6, 0.6), Color(0.38, 0.34, 0.26))
	_pickup(r, Vector3(-3.0, 0.88, -6.8), "keycard", "책상 위 보안 카드", "서랍 아래에 보안 카드가 붙어 있다. 서버실 문에 쓸 수 있을 것 같다.")
	_pickup(r, Vector3(-5.6, 1.6, -7.2), "usb_drive", "상자 위 USB", "상자 위에 놓인 USB 저장장치다. 암호화되어 있어 지금은 열어 볼 수 없다.")

	# 서버실 (잠금: 보안 카드)
	Kit.room(r, Vector3(6.0, 0.0, -5.15), 8.0, 6.0, WALL_H, fc, wc, cc, {"s": Vector2(0.0, 1.4)})
	_door(r, Vector3(5.3, 0.0, -2.0), 0.0, "server_room", true, "keycard", "서버실 문이 잠겨 있다. 보안 카드가 필요하다.")
	Kit.lamp(r, Vector3(6.0, WALL_H - 0.2, -5.15), 0.9, 8.0, Color(0.7, 0.85, 1.0))
	for i in range(4):
		var rx: float = 3.0 + 1.8 * float(i)
		Kit.box(r, Vector3(rx, 1.0, -7.6), Vector3(1.2, 2.0, 0.7), Color(0.12, 0.13, 0.16))
		Kit.box(r, Vector3(rx, 1.5, -7.23), Vector3(0.9, 0.08, 0.04), Color(0.2, 1.0, 0.5), false, 2, 2.0)
		Kit.box(r, Vector3(rx, 1.2, -7.23), Vector3(0.9, 0.08, 0.04), Color(0.3, 0.6, 1.0), false, 2, 2.0)
	Kit.table(r, Vector3(6.0, 0.0, -4.6), 1.4, 0.8, 0.8, Color(0.3, 0.3, 0.34))
	_pickup(r, Vector3(6.0, 0.9, -4.6), "secret_doc", "서버실 기밀 문서", "봉인된 문서철이다. 이 도시 지하 설비와 반출 일정이 적혀 있다. 이제 들키지 않고 이곳을 빠져나가야 한다.",
		[
			{"op": "quest_step", "id": "q_contact", "step": 6, "if": {"quest": "q_contact", "state": "active", "step": 5}},
		])

	# 계단(위로)과 비상 출구 : 둘 다 아파트 책장 앞으로 연결
	var out_effects: Array = [
		{"op": "quest_step", "id": "q_contact", "step": 7, "if": [{"quest": "q_contact", "state": "active", "step": 6}, {"item": "secret_doc"}]},
		{"op": "toast", "text": "무사히 지하시설을 빠져나왔다.", "if": [{"quest": "q_contact", "state": "active", "step": 7}]},
	]
	var apt_out: Vector3 = _origin(S_APT) + Vector3(-2.5, 0.1, -2.0)
	_portal(r, Vector3(-11.0, 0.0, 0.0), "계단으로 올라가기", "올라가기", apt_out, PI_, "아파트 3동 12호", out_effects, 1.8)
	_portal(r, Vector3(11.0, 0.0, 0.0), "비상 출구로 나가기", "나가기", apt_out, PI_, "아파트 3동 12호", out_effects, 1.8)

	# 순찰 경비 (시야에 걸리면 의심도가 오르고, 가득 차면 발각)
	var o: Vector3 = _origin(S_UG)
	var guard: Dictionary = {
		"id": "ug_guard", "name": "경비", "role": "순찰 경비", "speed": 1.4,
		"look": {"height": 1.03, "skin": Color(0.84, 0.68, 0.56), "shirt": Color(0.2, 0.26, 0.2), "pants": Color(0.16, 0.2, 0.16),
			"hair": Color(0.06, 0.06, 0.06), "hat": true, "hat_color": Color(0.2, 0.26, 0.2), "acc": ""},
		"vision_range": 11.0, "vision_fov": 80.0, "no_talk": true,
		"patrol_path": [o + Vector3(0.0, 0.05, 0.0), o + Vector3(8.0, 0.05, 0.0)],
	}
	var g = NpcScript.new()
	g.name = "NPC_ug_guard"
	g.configure(guard, hub)
	g.position = Vector3(0.0, 0.05, 0.0)
	r.add_child(g)
