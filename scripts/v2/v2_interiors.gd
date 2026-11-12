extends "res://scripts/v1/interior_extra.gd"
## V2 건물 내부: 평양역 (대합실 → 경비실 → 창고 → 숨겨진 방).
##  - 부모(interior_extra.gd)의 도우미 함수(_slot_root, _portal, _sit, _pickup, _examine, _npc, _diner)를 그대로 씁니다.
##  - 내부는 도시 위 y=300, 슬롯 9 (x=900) 에 따로 만들고 문으로 이동합니다.
## 이 세계의 인물과 장소는 모두 가상입니다. (Godot 실행 미검증)

const VData2 = preload("res://scripts/v2/v2_data.gd")
const S_STATION: int = 9


## exit_info = v2_landmarks 가 만든 평양역 겉모습 {"root","front","depth","name"}
func build_station(world: Node3D, hub_ref, exit_info: Dictionary) -> bool:
	hub = hub_ref
	_world = world
	_ext["station"] = exit_info
	await get_tree().physics_frame
	_build_station()
	_enter_portal("station", _origin(S_STATION) + Vector3(0.0, 0.1, 5.2), 0.0, "평양역 입장", "평양역", [
		{"op": "set_flag", "key": "visited_station"}])
	print("[PYONGYANG] V2 평양역 내부를 만들었습니다.")
	return true


## 열쇠(key_item)로 열리는 문 (부모의 _door 는 열쇠가 없어서 따로 만듦)
func _door_k(root: Node3D, local_hinge: Vector3, rot_y: float, door_id: String, locked: bool, key_item: String, locked_text: String, width: float = 1.3) -> void:
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


func _build_station() -> void:
	var r: Node3D = _slot_root(S_STATION, "Int_Station")
	var H: float = 4.6
	var wall_c: Color = Color(0.86, 0.84, 0.78)
	# ── 대합실 24 x 14 (입구 남쪽, 경비실 문은 동쪽 벽 z=-3)
	Kit.room(r, Vector3.ZERO, 24.0, 14.0, H, Color(0.56, 0.54, 0.5), wall_c, Color(0.88, 0.86, 0.82),
		{"s": Vector2(0.0, 2.6), "e": Vector2(-3.0, 1.4)})
	Kit.lamp(r, Vector3(-7.0, H - 0.3, 0.0), 1.2, 12.0)
	Kit.lamp(r, Vector3(0.0, H - 0.3, 0.0), 1.2, 12.0)
	Kit.lamp(r, Vector3(7.0, H - 0.3, 0.0), 1.2, 12.0)
	Kit.label(r, Vector3(0.0, 3.7, -6.7), "평양역 (가상 재현)", 1.1, Color(1.0, 0.94, 0.75))
	Kit.rug(r, Vector3(0.0, 0.0, 3.0), 4.0, 8.0, Color(0.42, 0.16, 0.16))
	for px in [-5.0, 5.0]:
		Kit.box(r, Vector3(px, H * 0.5, -2.0), Vector3(0.8, H, 0.8), Color(0.8, 0.78, 0.72))
	# 전광판
	Kit.box(r, Vector3(-8.0, 3.2, -6.84), Vector3(5.0, 1.3, 0.08), Color(0.08, 0.1, 0.18), false, 2, 0.3)
	Kit.label(r, Vector3(-8.0, 3.45, -6.78), "열차 시각표", 0.6, Color(0.9, 0.95, 1.0))
	Kit.label(r, Vector3(-8.0, 3.0, -6.78), "야간 열차  23:10  (운행 여부 확인 요망)", 0.4, Color(1.0, 0.85, 0.4))
	_examine(r, Vector3(-8.0, 0.0, -5.6), "전광판 살펴보기",
		"낮 열차는 정확하게 표시돼 있다. 맨 아래 '야간 열차 23:10' 줄만 글씨가 희미하고, 운행 여부가 비어 있다.", [], "", 2.4)

	# 안내 데스크와 안내원
	Kit.counter(r, Vector3(3.5, 0.0, 1.0), 0.0, 3.0, Color(0.38, 0.26, 0.18))
	_npc(r, VData2.STATION_CLERK, Vector3(3.5, 0.0, 0.2), 180.0)

	# 대기 의자와 승객 2명
	Kit.sofa(r, Vector3(-6.0, 0.0, 2.0), 0.0, Color(0.30, 0.34, 0.42))
	Kit.sofa(r, Vector3(-9.0, 0.0, 2.0), 0.0, Color(0.30, 0.34, 0.42))
	_sit(S_STATION, r, Vector3(-6.0, 0.0, 2.0), 0.0, Vector3(-6.0, 0.0, 3.6), "대합실 의자에 앉기", true)
	_sit(S_STATION, r, Vector3(-9.0, 0.0, 2.0), 0.0, Vector3(-9.0, 0.0, 3.6), "대합실 의자에 앉기", true)
	_diner(S_STATION, r, 0, Vector3(-6.0, 0.0, 2.0), Vector3(-6.0, 0.0, 3.8), 180.0)
	_diner(S_STATION, r, 1, Vector3(-9.0, 0.0, 2.0), Vector3(-9.0, 0.0, 3.8), 180.0)

	# 매점
	Kit.counter(r, Vector3(-2.0, 0.0, -5.6), 0.0, 2.6, Color(0.5, 0.36, 0.22))
	Kit.shelf(r, Vector3(-4.2, 0.0, -6.5), 0.0, 1.8, 2.0, Color(0.5, 0.4, 0.3))
	_pickup(r, Vector3(-2.0, 1.12, -5.6), "gift_tea", "매점의 시음용 차 상자",
		"'시음용 — 가져가세요' 팻말이 붙은 작은 차 상자가 놓여 있다. 시민에게 건넬 작은 선물로 쓸 수 있을 것 같다.")
	_pickup(r, Vector3(-3.0, 1.12, -5.6), "gift_sweets", "매점의 사탕 바구니",
		"계산대 위 바구니에 포장된 사탕이 담겨 있다. 시민에게 건넬 작은 선물로 쓸 수 있을 것 같다.")
	_examine(r, Vector3(6.0, 0.0, 5.2), "벽 노선도 살펴보기",
		"벽에 노선도가 붙어 있다. 지하철 노선과 달리 이 역에서 출발하는 선은 두 갈래뿐이고, 한 선은 도중에서 끊겨 있다.", [], "", 2.2)

	# ── 경비실 8 x 6 (대합실 동쪽, 문 station_guard: 안내원에게 부탁해야 열림)
	var gx: float = 16.3
	var H2: float = 3.2
	Kit.room(r, Vector3(gx, 0.0, -3.0), 8.0, 6.0, H2, Color(0.46, 0.44, 0.4), Color(0.78, 0.78, 0.74), Color(0.8, 0.8, 0.78),
		{"w": Vector2(0.0, 1.4), "n": Vector2(2.0, 1.4)})
	_door_k(r, Vector3(12.0, 0.0, -3.65), -PI_ * 0.5, "station_guard", true, "", "경비실 문이 잠겨 있다. 안내원에게 이야기해 보자.")
	_door_k(r, Vector3(gx + 1.35, 0.0, -6.0), 0.0, "station_warehouse", true, "warehouse_key", "창고 문이 잠겨 있다. 열쇠가 필요하다.")
	Kit.lamp(r, Vector3(gx, H2 - 0.2, -3.0), 1.0, 9.0, Color(0.95, 0.97, 1.0))
	Kit.table(r, Vector3(gx, 0.0, -4.9), 2.2, 0.9, 0.8, Color(0.34, 0.34, 0.38))
	Kit.chair(r, Vector3(gx, 0.0, -3.9), 0.0, Color(0.2, 0.2, 0.24))
	Kit.box(r, Vector3(gx, 1.15, -5.2), Vector3(0.7, 0.45, 0.06), Color(0.3, 0.7, 1.0), false, 2, 1.4)
	Kit.box(r, Vector3(gx, 0.84, -4.8), Vector3(0.5, 0.03, 0.18), Color(0.12, 0.12, 0.14), false)
	_examine(r, Vector3(gx, 0.0, -4.3), "경비실 컴퓨터 확인",
		"모니터에 근무 일지가 떠 있다. 매일 밤 23시, '화물 승강기 사용' 항목이 같은 필체로 반복된다. 책상 옆 사물함 열쇠 구멍 옆에는 '창고'라고 적힌 꼬리표가 붙어 있다.",
		[{"op": "set_flag", "key": "guard_log_read"},
		 {"op": "quest_step", "id": "q_station", "step": 2, "if": {"quest": "q_station", "state": "active", "min_step": 1}}], "", 1.9)
	Kit.box(r, Vector3(gx + 3.4, 1.0, -1.6), Vector3(0.7, 2.0, 0.9), Color(0.3, 0.36, 0.4))
	_pickup(r, Vector3(gx + 3.0, 1.1, -1.6), "warehouse_key", "사물함 안의 열쇠",
		"사물함 안쪽 고리에 낡은 열쇠가 걸려 있다. 꼬리표에는 '화물 창고'라고 적혀 있다.",
		[{"op": "quest_step", "id": "q_station", "step": 3, "if": {"quest": "q_station", "state": "active", "min_step": 2}}])
	Kit.sofa(r, Vector3(gx - 2.6, 0.0, -1.0), PI_ * 0.5, Color(0.36, 0.3, 0.26))
	_sit(S_STATION, r, Vector3(gx - 2.6, 0.0, -1.0), PI_ * 0.5, Vector3(gx - 1.4, 0.0, -1.0), "경비실 소파에 앉기", false)
	_examine(r, Vector3(gx - 3.2, 0.0, -4.6), "서류 선반 살펴보기",
		"서류 선반에는 열차 편성표가 가득하다. 야간 열차 칸만 수정 펜으로 여러 번 덧칠되어 있다.", [], "", 1.8)

	# ── 창고 8 x 8 (경비실 북쪽, 문 station_warehouse: 열쇠 필요)
	var wz: float = -10.3
	Kit.room(r, Vector3(gx, 0.0, wz), 8.0, 8.0, 3.6, Color(0.4, 0.38, 0.35), Color(0.66, 0.64, 0.6), Color(0.7, 0.7, 0.68),
		{"s": Vector2(2.0, 1.4), "n": Vector2(0.0, 2.0)})
	Kit.lamp(r, Vector3(gx, 3.4, wz), 0.9, 10.0, Color(0.95, 0.9, 0.8))
	Kit.crate(r, Vector3(gx - 3.0, 0.0, wz + 2.0), Vector3(1.1, 1.1, 1.1))
	Kit.crate(r, Vector3(gx - 3.0, 1.1, wz + 2.0), Vector3(0.8, 0.7, 0.8), Color(0.4, 0.34, 0.26))
	Kit.crate(r, Vector3(gx + 3.0, 0.0, wz + 1.0), Vector3(1.2, 1.0, 1.2))
	Kit.crate(r, Vector3(gx - 1.0, 0.0, wz - 1.5), Vector3(1.0, 0.9, 1.0), Color(0.4, 0.36, 0.3))
	Kit.shelf(r, Vector3(gx - 3.8, 0.0, wz - 1.0), PI_ * 0.5, 3.0, 2.0, Color(0.45, 0.45, 0.45))
	_examine(r, Vector3(gx + 3.0, 0.0, wz + 2.2), "화물 상자 살펴보기",
		"상자 겉면에 같은 도장이 찍혀 있고, 수신처는 지워져 있다. 안은 비어 있다.", [], "", 1.8)
	# 숨겨진 방 입구를 가린 선반 (살펴보면 옆으로 밀려남)
	var panel = Kit.shelf(r, Vector3(gx, 0.0, wz - 3.55), PI_, 2.4, 2.2, Color(0.4, 0.32, 0.24))
	panel.add_to_group("reveal_station_panel")
	var pit = InteractableScript.new()
	pit.kind = "examine"
	pit.prompt = "벽 앞의 선반 살펴보기"
	pit.radius = 2.0
	pit.hide_flag = "station_panel_found"
	pit.data = {"text": "선반 아래 바닥에 긁힌 자국이 호를 그리며 나 있다. 옆으로 밀어 보니 선반이 가볍게 밀려나고, 뒤에서 차가운 공기가 흘러나온다. 벽에 숨겨진 통로가 있었다.",
		"effects": [
			{"op": "reveal", "id": "station_panel"},
			{"op": "set_flag", "key": "station_panel_found"},
			{"op": "quest_step", "id": "q_station", "step": 4, "if": {"quest": "q_station", "state": "active", "min_step": 3}}],
		"once_flag": "station_panel_found"}
	pit.position = Vector3(gx, 1.0, wz - 2.4)
	r.add_child(pit)

	# ── 숨겨진 방 8 x 7 (창고 북쪽)
	var hz: float = -18.1
	Kit.room(r, Vector3(gx, 0.0, hz), 8.0, 7.0, 3.4, Color(0.3, 0.32, 0.34), Color(0.5, 0.54, 0.56), Color(0.5, 0.52, 0.54),
		{"s": Vector2(0.0, 2.0)})
	Kit.lamp(r, Vector3(gx, 3.2, hz), 0.8, 9.0, Color(0.7, 0.88, 1.0))
	for i in range(3):
		var rx: float = gx - 3.2 + 1.5 * float(i)
		Kit.box(r, Vector3(rx, 1.0, hz - 3.0), Vector3(1.0, 2.0, 0.7), Color(0.12, 0.13, 0.16))
		Kit.box(r, Vector3(rx, 1.5, hz - 2.63), Vector3(0.8, 0.07, 0.04), Color(0.2, 1.0, 0.5), false, 2, 2.0)
	Kit.table(r, Vector3(gx + 1.5, 0.0, hz + 0.6), 2.4, 1.0, 0.8, Color(0.3, 0.3, 0.34))
	Kit.box(r, Vector3(gx + 1.0, 1.15, hz + 0.9), Vector3(0.8, 0.5, 0.06), Color(0.3, 0.8, 1.0), false, 2, 1.6)
	Kit.box(r, Vector3(gx + 2.0, 1.15, hz + 0.9), Vector3(0.8, 0.5, 0.06), Color(0.3, 1.0, 0.6), false, 2, 1.6)
	Kit.chair(r, Vector3(gx + 1.5, 0.0, hz + 1.7), PI_, Color(0.2, 0.2, 0.24))
	# 단말기 → (기록 가져가기 | 두고 나가기) : 둘 중 하나를 고르면 둘 다 사라짐
	var tit = InteractableScript.new()
	tit.kind = "examine"
	tit.prompt = "단말기 열람"
	tit.radius = 2.0
	tit.data = {"text": "단말기에는 야간 열차 승객 명단이 열려 있다. 같은 이름들이 여러 날 밤 반복해 적혀 있고, 마지막 칸은 모두 '확인 불가'다. 출력 장치에서 기록을 가져갈 수도 있고, 아무것도 건드리지 않고 단말기를 끌 수도 있다.",
		"effects": [
			{"op": "set_flag", "key": "station_terminal_read"},
			{"op": "quest_step", "id": "q_station", "step": 5, "if": {"quest": "q_station", "state": "active", "min_step": 4}}],
		"once_flag": ""}
	tit.position = Vector3(gx + 1.5, 1.0, hz + 1.5)
	r.add_child(tit)
	_pickup(r, Vector3(gx - 0.2, 1.0, hz + 0.9), "station_files", "출력 장치의 기록철 (가져가기)",
		"출력 장치에서 기록철이 나왔다. 가져가면 이 역의 비밀을 밖으로 알릴 수 있지만, 누군가는 기록이 사라진 것을 알아챌 것이다.",
		[{"op": "set_flag", "key": "station_ending_take"},
		 {"op": "set_flag", "key": "station_ending_done"},
		 {"op": "trust", "id": "station_clerk", "delta": -2},
		 {"op": "alert", "kind": "trespass", "severity": 1.6},
		 {"op": "quest_complete", "id": "q_station"}])
	_set_requires(r, "station_files", "station_terminal_read")
	var lit = InteractableScript.new()
	lit.kind = "examine"
	lit.prompt = "단말기 끄고 그대로 두기"
	lit.radius = 2.0
	lit.requires_flag = "station_terminal_read"
	lit.hide_flag = "station_ending_done"
	lit.data = {"text": "아무것도 가져가지 않고 단말기를 껐다. 기록은 그대로 남았지만, 당신이 이곳을 알고 있다는 사실도 비밀로 남는다.",
		"effects": [
			{"op": "set_flag", "key": "pk_station_files"},
			{"op": "set_flag", "key": "station_ending_leave"},
			{"op": "set_flag", "key": "station_ending_done"},
			{"op": "trust", "id": "station_clerk", "delta": 2},
			{"op": "quest_complete", "id": "q_station"}],
		"once_flag": ""}
	lit.position = Vector3(gx + 3.0, 1.0, hz + 1.2)
	r.add_child(lit)

	# 밤에 창고를 도는 순찰 경비 (낮에는 퇴근)
	_npc(r, VData2.station_guard(_origin(S_STATION)), Vector3(gx, 0.0, -3.0), 0.0)

	_exit_portal(r, Vector3(0.0, 0.0, 6.0), "station")
	built.append("station")


## 방금 만든 줍기 지점(item)에 '이 플래그가 있어야 보임' 조건을 붙임
func _set_requires(root: Node3D, item: String, flag: String) -> void:
	for c in root.get_children():
		if c.get("kind") == "pickup" and c.get("data") is Dictionary and str(c.data.get("item", "")) == item:
			c.requires_flag = flag
