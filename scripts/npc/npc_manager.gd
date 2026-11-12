extends Node3D
## NPC 배치 담당. npc_data.gd 의 이름 있는 시민 + 자동 생성 군중을 만듭니다.
## 건물 배치를 바꾸셨어도 NPC가 건물에 박히지 않도록 충돌 검사로 빈 자리를 먼저 찾습니다.

const NpcScript = preload("res://scripts/npc/npc.gd")
const NpcData = preload("res://scripts/data/npc_data.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const Flags = preload("res://scripts/data/feature_flags.gd")

var npcs: Array = []


func spawn_all(parent: Node3D, hub) -> void:
	# 월드의 충돌체가 물리 엔진에 등록될 때까지 두 프레임 기다린 뒤 빈 자리를 검사
	await get_tree().physics_frame
	await get_tree().physics_frame
	var world: World3D = get_world_3d()
	var hour: float = 9.0
	if hub != null and hub.clock != null:
		hour = hub.clock.hour_float()

	var all: Array = []
	for d in NpcData.NPCS:
		all.append(d)
	# V1: 새 NPC (택시 기사, 경찰, 대화하는 주민 ...). 파일에 문제가 있으면 건너뜀
	if Flags.ENABLE_V1 and Flags.V1_SOCIAL:
		var vd = load("res://scripts/v1/v1_data.gd")
		if vd != null and vd.can_instantiate():
			for d1 in vd.NPCS:
				all.append(d1)
		else:
			push_error("v1_data.gd 를 불러오지 못해 V1 NPC 를 건너뜁니다.")
	var crowd_n: int = Flags.crowd_count()
	if crowd_n > 0:
		for d in NpcData.make_crowd(crowd_n, 7):
			all.append(d)

	var count: int = 0
	for d in all:
		var cfg: Dictionary = d.duplicate(true)
		var start: Vector3 = _start_position(cfg, hour)
		var spot: Vector3 = Placement.find_free_capsule(world, start, 0.35, 1.8)
		cfg["home"] = Placement.find_free_capsule(world, cfg.get("home", start), 0.35, 1.8)
		var npc = NpcScript.new()
		npc.name = "NPC_" + str(cfg["id"])
		npc.configure(cfg, hub)
		npc.position = spot + Vector3(0.0, 0.05, 0.0)
		parent.add_child(npc)
		npcs.append(npc)
		count += 1
		# 한 프레임에 너무 많이 만들어 멈칫하지 않도록 몇 명마다 쉼
		if count % 4 == 0:
			await get_tree().process_frame
	print("[PYONGYANG] 시민 NPC %d명을 배치했습니다." % count)


## 지금 시각의 일과 위치에서 시작하도록 처음 놓을 자리를 정함 (밤이면 집)
func _start_position(cfg: Dictionary, hour: float) -> Vector3:
	var home: Vector3 = cfg.get("home", Vector3.ZERO)
	var routine: Array = cfg.get("routine", [])
	for e in routine:
		var a: float = float(e.get("from", 0.0))
		var b: float = float(e.get("to", 24.0))
		var inside: bool = false
		if a <= b:
			inside = hour >= a and hour < b
		else:
			inside = hour >= a or hour < b
		if inside:
			if str(e.get("mode", "")) == "home":
				return home
			var p: Vector3 = e.get("pos", home)
			var r: float = float(e.get("radius", 0.0))
			if r > 1.0:
				p += Vector3(randf_range(-r, r) * 0.5, 0.0, randf_range(-r, r) * 0.5)
			return p
	return home
