extends Node
## V1.0 확장 총괄. 허브(interaction_system.gd)가 두 단계로 부릅니다.
##   build_world()   : 랜드마크 (그래픽 모듈 다음, 건물 내부 모듈 앞 → 이후 모듈이 랜드마크를 피해서 배치됨)
##   build_systems() : 추가 건물 내부, 운전/차량, 도시 경계, 사회 시스템, V1 화면
## 각 하위 모듈은 load() + can_instantiate() 로 불러와서, 하나가 실패해도 나머지는 계속 동작합니다.
## 이 노드가 없거나 ENABLE_V1=false 면 게임은 v0.2.0 과 같게 동작합니다.

const Flags = preload("res://scripts/data/feature_flags.gd")
const Settings = preload("res://scripts/v1/game_settings.gd")
const VData = preload("res://scripts/v1/v1_data.gd")

var hub = null
var landmarks = null
var extra = null
var drive = null
var alert = null
var social = null
var hud_v1 = null
## 지도/미니맵에 표시할 현재 임무 목표 위치들
var quest_marks: Array = []
## 지도 화면에 보여 줄 지도 마커 [{"pos","name","kind"}]
var extra_markers: Array = []

var _world: Node3D = null
var _tick: float = 0.0
var _night_last: float = -1.0
var _ready_systems: bool = false


func _make(path: String):
	var s = load(path)
	if s == null or not s.can_instantiate():
		push_error("V1 모듈을 불러오지 못했습니다(해당 기능만 빠집니다): " + path)
		return null
	return s.new()


# ---------------------------------------------------------------- 1단계: 랜드마크

func build_world(world: Node3D, hub_ref) -> void:
	hub = hub_ref
	_world = world
	if Flags.V1_LANDMARKS:
		landmarks = _make("res://scripts/v1/landmarks.gd")
		if landmarks != null:
			add_child(landmarks)
			await landmarks.build(world, hub)


# ---------------------------------------------------------------- 2단계: 나머지 시스템

func build_systems(world: Node3D, hub_ref) -> void:
	hub = hub_ref
	_world = world

	if Flags.V1_INTERIORS:
		extra = _make("res://scripts/v1/interior_extra.gd")
		if extra != null:
			add_child(extra)
			await extra.build(world, hub, landmarks)

	if Flags.V1_ALERT:
		alert = _make("res://scripts/v1/alert_system.gd")
		if alert != null:
			add_child(alert)
			alert.setup(hub, self, world)
			alert.max_police = Settings.get_int("max_police", 5)

	if Flags.V1_SOCIAL:
		social = _make("res://scripts/v1/social_system.gd")
		if social != null:
			add_child(social)
			social.setup(hub, self)
			social.augment_all()

	if Flags.V1_DRIVING:
		drive = _make("res://scripts/v1/drive_system.gd")
		if drive != null:
			add_child(drive)
			await drive.build(world, hub, self)

	if Flags.V1_UI:
		var hs = load("res://scripts/v1/v1_hud.gd")
		if hs != null and hs.can_instantiate():
			var layer = CanvasLayer.new()
			layer.name = "V1HudLayer"
			layer.layer = 2
			hub.add_child(layer)
			hud_v1 = hs.new()
			hud_v1.name = "V1HUD"
			layer.add_child(hud_v1)
			hud_v1.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hud_v1.hub = hub
			hud_v1.v1 = self
		else:
			push_error("v1_hud.gd 를 불러오지 못했습니다. 미니맵/운전 화면 없이 실행합니다.")

	if hub.hud != null:
		hub.hud.v1_ref = self
	apply_runtime_settings()
	_ready_systems = true
	print("[PYONGYANG] V1.0 시스템 준비 완료 (랜드마크:%s 운전:%s 경계:%s 사회:%s)" % [
		str(landmarks != null), str(drive != null), str(alert != null), str(social != null)])


# ---------------------------------------------------------------- 허브 연결 지점

func on_vehicle_entered(car) -> void:
	if hub == null:
		return
	if hub.game.quest_state("q_drive") == "inactive":
		hub.game.start_quest("q_drive")
	hub.game.set_quest_step("q_drive", 1)
	if alert != null and car != null and car.kind == "military":
		hub.toast("군용 차량이다. 눈에 띄지 않게 조심하자.")
	if alert != null and car != null and car.kind == "police":
		hub.toast("경찰차를 탔다. 누군가 보았다면 곤란해진다!")
		alert.report("trespass", car.global_position, 2.0, null)


func on_vehicle_exited(_car) -> void:
	if hub == null or drive == null:
		return
	_check_drive_quest()


func on_dialogue_start(npc) -> void:
	if social != null:
		social.on_talk(npc)


func on_dialogue_end(npc) -> void:
	if social != null:
		social.on_dialogue_end(npc)


func dynamic_text(kind: String, npc) -> String:
	if social != null:
		return social.dynamic_text(kind, npc)
	return "..."


func on_caught() -> void:
	if alert != null:
		alert.on_caught()
	if social != null:
		social.refresh_alert_flags(0)


## 허브의 apply_effects 가 모르는 op 를 넘겨 줌
func on_effect(op: String, e: Dictionary) -> void:
	match op:
		"taxi":
			var key: String = str(e.get("dest", "plaza"))
			var pos: Vector3 = dest_position(key)
			if drive != null:
				drive.fast_travel(pos, str(VData.TAXI_DESTS.get(key, key)))
		"trust":
			if social != null:
				social.add_trust(str(e.get("id", "")), int(e.get("delta", 1)))
		"alert":
			if alert != null:
				alert.report(str(e.get("kind", "trespass")), hub.player.global_position, float(e.get("severity", 1.0)), null)
		"calm":
			if alert != null:
				alert.heat = maxf(alert.baseline, alert.heat - float(e.get("amount", 20.0)))


func dest_position(key: String) -> Vector3:
	match key:
		"hotel":
			if hub.game.pois.has("hotel"):
				var hp: Vector3 = hub.game.pois["hotel"]["pos"]
				return hp
		"okryu":
			if landmarks != null and landmarks.exits.has("okryu"):
				var op: Vector3 = landmarks.exits["okryu"]["front"]
				return op
		"metro":
			if landmarks != null and landmarks.exits.has("metro"):
				var mp: Vector3 = landmarks.exits["metro"]["front"]
				return mp
		"arch":
			var ap = _marker_pos("lm_arch")
			if ap != null:
				return ap
		"tower":
			var tp = _marker_pos("lm_tower")
			if tp != null:
				return tp
		"station":
			var v2m = hub.get("v2")
			if v2m != null and v2m.landmarks2 != null and v2m.landmarks2.exits.has("station"):
				var stp: Vector3 = v2m.landmarks2.exits["station"]["front"]
				return stp
	var sp = _marker_pos("lm_square")
	if sp != null:
		return sp
	return Vector3(0.0, 0.0, 30.0)


func _marker_pos(id: String):
	if landmarks == null:
		return null
	for mk in landmarks.markers:
		if str(mk.get("id", "")) == id:
			return mk["pos"]
	return null


# ---------------------------------------------------------------- 메뉴: 설정

## 메뉴 화면의 설정 버튼. id 는 "setting:키". 바뀐 값 이름을 토스트로 알림
func on_menu_action(id: String) -> void:
	if not id.begins_with("setting:"):
		return
	var key: String = id.substr(8)
	match key:
		"gfx_quality":
			var q: int = (Settings.gfx_quality(Flags.GFX_QUALITY) + 1) % 3
			Settings.set_value("gfx_quality", q)
			hub.toast("그래픽 품질: %s (다음 실행부터 적용)" % ["낮음", "보통", "높음"][q])
		"gfx_enabled":
			var on: bool = not Settings.gfx_enabled(Flags.ENABLE_GFX)
			Settings.set_value("gfx_enabled", on)
			hub.toast("사실적 그래픽: %s (다음 실행부터 적용)" % ("켜짐" if on else "꺼짐 (가벼운 모드)"))
		"shadows":
			var sh: bool = not Settings.shadows(true)
			Settings.set_value("shadows", sh)
			apply_runtime_settings()
			hub.toast("그림자: %s" % ("켜짐" if sh else "꺼짐"))
		"crowd":
			var cs: int = (Settings.get_int("crowd_step", 2) + 1) % 4
			Settings.set_value("crowd_step", cs)
			hub.toast("시민 수: %d명 (다음 실행부터 적용)" % [0, 4, 10, 18][cs])
		"traffic":
			var ts: int = (Settings.get_int("traffic_step", 2) + 1) % 4
			Settings.set_value("traffic_step", ts)
			hub.toast("도로 차량 수: %d대 (다음 실행부터 적용)" % [0, 4, 8, 12][ts])
		"minimap":
			var mm: bool = not Settings.minimap(true)
			Settings.set_value("minimap", mm)
			apply_runtime_settings()
			hub.toast("미니맵: %s" % ("켜짐" if mm else "꺼짐"))
		"weather":
			var wo: bool = not Flags.weather_on()
			Settings.set_value("weather", wo)
			apply_runtime_settings()
			hub.toast("날씨 변화: %s" % ("켜짐" if wo else "꺼짐 (항상 맑음)"))
		"fps":
			var fo: bool = not Flags.fps_on()
			Settings.set_value("fps", fo)
			apply_runtime_settings()
			hub.toast("FPS 표시: %s" % ("켜짐" if fo else "꺼짐"))
		"view":
			var vs: int = (Flags.view_step() + 1) % 3
			Settings.set_value("view_step", vs)
			apply_runtime_settings()
			hub.toast("시야 거리: %s" % ["가깝게 (가벼움)", "보통", "멀리 (기본)"][vs])
		"lowend":
			# 저사양 한 번에 설정
			Settings.set_value("view_step", 0)
			Settings.set_value("gfx_quality", 0)
			Settings.set_value("shadows", false)
			Settings.set_value("crowd_step", 1)
			Settings.set_value("traffic_step", 1)
			Settings.set_value("max_police", 2)
			apply_runtime_settings()
			hub.toast("저사양 모드로 설정했습니다. 앱을 다시 켜면 모두 적용됩니다.")


func apply_runtime_settings() -> void:
	if hub == null:
		return
	var sun = get_tree().root.find_child("Sun", true, false)
	if sun != null and sun is DirectionalLight3D:
		sun.shadow_enabled = Settings.shadows(sun.shadow_enabled)
	if hud_v1 != null:
		hud_v1.show_minimap = Settings.minimap(true)
	if alert != null:
		alert.max_police = Settings.get_int("max_police", 5)
	var v2m = hub.get("v2")
	if v2m != null and v2m.has_method("apply_settings"):
		v2m.apply_settings()


# ---------------------------------------------------------------- 저장 / 불러오기

func to_dict() -> Dictionary:
	var d: Dictionary = {"version": 1}
	if alert != null:
		d["alert"] = alert.to_dict()
	if social != null:
		d["social"] = social.to_dict()
	if drive != null:
		d["drive"] = drive.to_dict()
	var npcs: Array = []
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n) and n.has_method("state_dict") and not n.is_police and n.npc_id != "" and not n.npc_id.begins_with("police_x"):
			if n.global_position.y < 100.0 and n.npc_id.find("diner_") < 0:
				npcs.append(n.state_dict())
	d["npcs"] = npcs
	return d


func from_dict(d: Dictionary) -> void:
	var a = d.get("alert")
	if alert != null and a is Dictionary:
		alert.from_dict(a)
	var so = d.get("social")
	if social != null and so is Dictionary:
		social.from_dict(so)
		for n in get_tree().get_nodes_in_group("npcs"):
			if is_instance_valid(n):
				var sid: String = n.npc_id
				if social.trust.has(sid):
					social.add_trust(sid, 0)
	var dr = d.get("drive")
	if drive != null and dr is Dictionary:
		drive.from_dict(dr)
	var nl = d.get("npcs")
	if nl is Array:
		var by_id: Dictionary = {}
		for e in nl:
			if e is Dictionary:
				by_id[str(e.get("id", ""))] = e
		for n2 in get_tree().get_nodes_in_group("npcs"):
			if is_instance_valid(n2) and by_id.has(n2.npc_id) and n2.has_method("apply_state"):
				n2.apply_state(by_id[n2.npc_id])
	if social != null and alert != null:
		social.refresh_alert_flags(alert.level)


# ---------------------------------------------------------------- 주기 처리

func _process(delta: float) -> void:
	if not _ready_systems or hub == null or hub.game == null:
		return
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0.0

	# 낮밤에 따른 랜드마크 조명
	if landmarks != null and hub.clock != null:
		var h: float = hub.clock.hour_float()
		var night: float = 0.0
		if h >= 20.0 or h <= 4.5:
			night = 1.0
		elif h >= 17.0:
			night = (h - 17.0) / 3.0
		elif h < 7.0:
			night = (7.0 - h) / 2.5
		if absf(night - _night_last) > 0.02:
			_night_last = night
			landmarks.set_night(night)

	if social != null and alert != null:
		social.refresh_alert_flags(alert.level)

	_auto_quests()
	_update_marks()


func _auto_quests() -> void:
	var g = hub.game
	# 운전: 차량 가까이 가면 안내
	if g.quest_state("q_drive") == "inactive" and drive != null and hub.player != null:
		var pp: Vector3 = hub.player.global_position
		for c in drive.vehicles:
			if is_instance_valid(c) and c.global_position.distance_to(pp) < 10.0:
				if g.start_quest("q_drive"):
					hub.toast("새 임무: " + g.quest_title("q_drive"))
				break
	if g.quest_state("q_drive") == "active":
		_check_drive_quest()
	# 옥류관: 근처에 가면 시작
	if g.quest_state("q_okryu") == "inactive" and g.quest_state("q_metro") == "inactive" and g.discovered.has("lm_okryu"):
		if g.start_quest("q_okryu"):
			hub.toast("새 임무: " + g.quest_title("q_okryu"))
	# 문서 수집
	var docs: int = count_docs()
	if docs >= 1 and g.quest_state("q_collect") == "inactive":
		if g.start_quest("q_collect"):
			hub.toast("새 임무: " + g.quest_title("q_collect"))
	if g.quest_state("q_collect") == "active" and docs >= 4:
		hub._complete_quest("q_collect")


func _check_drive_quest() -> void:
	var g = hub.game
	if g.quest_state("q_drive") != "active" or drive == null:
		return
	if drive.driven_m >= 200.0 and g.quest_step("q_drive") < 2:
		if g.set_quest_step("q_drive", 2):
			hub.toast("임무 갱신: " + g.quest_step_text("q_drive"))
	if g.quest_step("q_drive") >= 2 and drive.current == null:
		hub._complete_quest("q_drive")


func count_docs() -> int:
	var ids: Array = ["hotel_log", "ledger", "menu_note", "doc_schedule", "metro_blueprint", "doc_ticket", "secret_doc"]
	var n: int = 0
	for id in ids:
		if hub.game.has_item(id) or hub.game.get_flag("pk_" + id):
			n += 1
	return n


func _update_marks() -> void:
	quest_marks = []
	var g = hub.game
	for qid in g.active_quest_ids():
		var st: int = g.quest_step(qid)
		var target = null
		match qid:
			"q_tea":
				if st == 0:
					target = _poi_pos("tea")
			"q_office":
				if st == 0:
					target = _poi_pos("office")
			"q_contact":
				if st == 1:
					target = _poi_pos("hotel")
				elif st == 2:
					target = _poi_pos("apt")
			"q_okryu":
				if st <= 1 or st == 2:
					target = dest_position("okryu")
				elif st == 3:
					target = dest_position("metro")
			"q_metro":
				target = dest_position("metro")
			"q_drive":
				if st == 0 and drive != null and hub.player != null:
					var best = null
					var bd: float = 1000000.0
					for c in drive.vehicles:
						if is_instance_valid(c):
							var d: float = c.global_position.distance_to(hub.player.global_position)
							if d < bd:
								bd = d
								best = c.global_position
					target = best
		if target != null:
			quest_marks.append(target)


func _poi_pos(id: String):
	if hub.game.pois.has(id):
		var p: Vector3 = hub.game.pois[id]["pos"]
		return p
	return null


## 지도 화면용: 소문 목록과 차량/NPC 마커 (hud_ui 가 읽음)
func rumor_lines() -> Array:
	if social == null:
		return []
	return social.rumor_log
