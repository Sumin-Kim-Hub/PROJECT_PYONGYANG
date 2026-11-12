extends Node
## V2.0 확장 총괄. 허브(interaction_system.gd)가 V1 매니저 뒤에서 두 단계로 부릅니다.
##   build_world()   : 평양역 · 주차장 · 창전거리 풍 · 미래과학자거리 풍 (v2_landmarks.gd)
##   build_systems() : 평양역 내부, 주차장 차량, 날씨, FPS 표시, 시민 대화(선물/도움/경고) 추가
## 이 노드가 없거나 ENABLE_V2=false 면 게임은 V1.0 과 같게 동작합니다.
## 하위 모듈은 load() + can_instantiate() 로 불러와서 하나가 실패해도 나머지는 계속 동작합니다. (Godot 실행 미검증)

const Flags = preload("res://scripts/data/feature_flags.gd")
const Settings = preload("res://scripts/v1/game_settings.gd")

var hub = null
var landmarks2 = null
var interiors2 = null
var weather = null
var title = null

var _world: Node3D = null
var _title_layer: CanvasLayer = null
var _fps_layer: CanvasLayer = null
var _fps_label: Label = null
var _tick: float = 0.0
var _fps_t: float = 0.0
var _ready_systems: bool = false
var _menu_paused: bool = false
var _paused_npcs: Array = []
var _clock_was_paused: bool = false
var _far_default: float = -1.0
var _esc_arrests: int = -1
var _title_clock_paused: bool = false


func _make(path: String):
	var s = load(path)
	if s == null or not s.can_instantiate():
		push_error("V2 모듈을 불러오지 못했습니다(해당 기능만 빠집니다): " + path)
		return null
	return s.new()


# ---------------------------------------------------------------- 1단계: 랜드마크

func build_world(world: Node3D, hub_ref) -> void:
	hub = hub_ref
	_world = world
	var v1 = hub.get("v1")
	if Flags.V2_LANDMARKS and v1 != null and v1.landmarks != null:
		landmarks2 = _make("res://scripts/v2/v2_landmarks.gd")
		if landmarks2 != null:
			add_child(landmarks2)
			await landmarks2.build(world, hub, v1.landmarks)


# ---------------------------------------------------------------- 2단계: 나머지

func build_systems(world: Node3D, hub_ref) -> void:
	hub = hub_ref
	_world = world
	var v1 = hub.get("v1")

	if Flags.V2_STATION and landmarks2 != null and landmarks2.exits.has("station"):
		interiors2 = _make("res://scripts/v2/v2_interiors.gd")
		if interiors2 != null:
			add_child(interiors2)
			await interiors2.build_station(world, hub, landmarks2.exits["station"])

	# 주차장에 실제로 탈 수 있는 차량을 세움
	if landmarks2 != null and v1 != null and v1.drive != null:
		for e in landmarks2.parking:
			v1.drive.spawn_one(world, str(e["kind"]), e["pos"], float(e["yaw"]), e["color"], str(e["id"]))

	if Flags.V2_WEATHER:
		weather = _make("res://scripts/v2/weather_system.gd")
		if weather != null:
			add_child(weather)
			weather.setup(hub, Flags.gfx_quality())

	_build_fps_label()

	# 새로 만든 시민(평양역 안내원 등)에게도 소문/신뢰 대화를 붙이고, V2 대화(선물/도움/경고)를 모든 시민에게 추가
	if v1 != null and v1.social != null:
		v1.social.augment_all()
	_augment_all_dialogue()

	hub.game.set_flag("v2_on", true)
	apply_settings()
	_ready_systems = true
	print("[PYONGYANG] V2.0 시스템 준비 완료 (평양역:%s 날씨:%s)" % [str(interiors2 != null), str(weather != null)])


# ---------------------------------------------------------------- 설정 반영

func apply_settings() -> void:
	if hub == null:
		return
	if weather != null:
		var on: bool = Flags.weather_on()
		if weather.enabled and not on:
			weather.set_state("clear")
			weather.cur = {"light": 1.0, "gray": 0.0, "fog": 0.0, "rain": 0.0, "vision": 1.0}
			weather._apply_gameplay()
		weather.enabled = on
	if _fps_label != null:
		_fps_label.visible = Flags.fps_on()
	_apply_view_distance()


func _apply_view_distance() -> void:
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	if _far_default < 0.0:
		_far_default = cam.far
	var step: int = Flags.view_step()
	if step == 0:
		cam.far = minf(150.0, _far_default)
	elif step == 1:
		cam.far = minf(350.0, _far_default)
	else:
		cam.far = _far_default


func _build_fps_label() -> void:
	_fps_layer = CanvasLayer.new()
	_fps_layer.name = "V2FpsLayer"
	_fps_layer.layer = 3
	hub.add_child(_fps_layer)
	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.position = Vector2(16.0, 6.0)
	_fps_label.add_theme_font_size_override("font_size", 18)
	_fps_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 0.95))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fps_label.add_theme_constant_override("outline_size", 5)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = "res://assets/fonts/ui_ko.ttf"
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font:
			_fps_label.add_theme_font_override("font", f)
	_fps_layer.add_child(_fps_label)


# ---------------------------------------------------------------- 시작 화면 (새 게임 / 이어하기)

## 허브의 _try_autoload 가 부름. 시작 화면을 보여 주면 true (그러면 허브는 자동 불러오기를 하지 않음)
func show_title(has_save: bool) -> bool:
	if not Flags.V2_TITLE or hub == null:
		return false
	var t = _make("res://scripts/v2/title_screen.gd")
	if t == null:
		return false
	title = t
	title.has_save = has_save
	_title_layer = CanvasLayer.new()
	_title_layer.name = "V2TitleLayer"
	_title_layer.layer = 10
	hub.add_child(_title_layer)
	_title_layer.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.chosen.connect(_on_title_chosen)
	# 화면이 떠 있는 동안 플레이어/시계를 멈추고 저장을 막음 (모드 TRANSITION = 자동 저장 안 함)
	hub.mode = 3
	if hub.player != null:
		hub.player.set_physics_process(false)
		hub.player.velocity = Vector3.ZERO
	if hub.clock != null:
		_title_clock_paused = hub.clock.paused
		hub.clock.paused = true
	return true


func _on_title_chosen(id: String) -> void:
	hub.mode = 0
	if hub.player != null:
		hub.player.set_physics_process(true)
	if hub.clock != null:
		hub.clock.paused = _title_clock_paused
	if _title_layer != null:
		_title_layer.queue_free()
		_title_layer = null
	title = null
	if id == "continue":
		if hub.load_game(true):
			hub.toast("저장된 게임을 이어서 시작합니다.")
		else:
			hub.toast("저장 파일을 읽지 못해 새로 시작합니다.")
	elif id == "new":
		for path in [hub.SAVE_PATH, hub.SAVE_PATH + ".tmp"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		hub.toast("새 게임을 시작합니다.")
	else:
		hub.toast("게임을 시작합니다.")


# ---------------------------------------------------------------- 매 프레임

func _process(delta: float) -> void:
	if not _ready_systems or hub == null or hub.game == null:
		return
	_update_menu_pause()

	_fps_t += delta
	if _fps_t >= 0.5:
		_fps_t = 0.0
		if _fps_label != null and _fps_label.visible:
			var mem: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
			var wname: String = weather.state_name() if weather != null else "-"
			_fps_label.text = "FPS %d · %s · 메모리 %dMB" % [Engine.get_frames_per_second(), wname, int(mem)]

	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	if not hub.game.get_flag("v2_on"):
		hub.game.set_flag("v2_on", true)
	if Flags.V2_QUESTS:
		_auto_quests()
	_apply_view_distance()


## 메뉴가 열려 있는 동안 세계(시계, 시민, 날씨)를 멈춤
func _update_menu_pause() -> void:
	var open: bool = hub.mode == 4 and hub.hud != null and hub.hud.panel_open()
	if open and not _menu_paused:
		_menu_paused = true
		_clock_was_paused = hub.clock.paused
		hub.clock.paused = true
		_paused_npcs = []
		for n in get_tree().get_nodes_in_group("npcs"):
			if is_instance_valid(n) and n.is_physics_processing():
				n.set_physics_process(false)
				_paused_npcs.append(n)
		if weather != null:
			weather.set_process(false)
	elif not open and _menu_paused:
		_menu_paused = false
		hub.clock.paused = _clock_was_paused
		for n2 in _paused_npcs:
			if is_instance_valid(n2):
				n2.set_physics_process(true)
		_paused_npcs = []
		if weather != null:
			weather.set_process(true)


# ---------------------------------------------------------------- 부가 임무 자동 진행

func _auto_quests() -> void:
	var g = hub.game
	var v1 = hub.get("v1")
	# 택시 손님: 택시 근처에 가면 시작, 택시를 타 보면 완료
	if g.quest_state("q_taxi") == "inactive" and hub.player != null:
		var near_taxi: bool = g.get_flag("taxi_used")
		if not near_taxi and v1 != null and v1.drive != null:
			for c in v1.drive.vehicles:
				if is_instance_valid(c) and c.kind == "taxi" and c.global_position.distance_to(hub.player.global_position) < 10.0:
					near_taxi = true
					break
		if near_taxi and g.start_quest("q_taxi"):
			hub.toast("새 임무: " + g.quest_title("q_taxi"))
	if g.quest_state("q_taxi") == "active" and g.get_flag("taxi_used"):
		hub._complete_quest("q_taxi")

	# 마음을 얻다: 시민과 신뢰가 쌓이면 시작, 한 명이 3 이상이면 완료
	if v1 != null and v1.social != null:
		var best: int = -3
		for k in v1.social.trust.keys():
			best = maxi(best, int(v1.social.trust[k]))
		if g.quest_state("q_trust") == "inactive" and best >= 1:
			if g.start_quest("q_trust"):
				hub.toast("새 임무: " + g.quest_title("q_trust"))
		if g.quest_state("q_trust") == "active" and best >= 3:
			hub._complete_quest("q_trust")

	# 추적 따돌리기: 경계가 높아지면 시작. 가라앉히면 완료, 잡히면 실패
	if v1 != null and v1.alert != null:
		var al = v1.alert
		var st: String = g.quest_state("q_escape")
		if st == "inactive" and al.level >= 2:
			if g.start_quest("q_escape"):
				_esc_arrests = al.arrests
				hub.toast("새 임무: " + g.quest_title("q_escape"))
		elif st == "active":
			if _esc_arrests < 0:
				_esc_arrests = al.arrests
			if al.arrests > _esc_arrests:
				if g.fail_quest("q_escape"):
					hub.toast("임무 실패: " + g.quest_title("q_escape"))
			elif al.level == 0:
				hub._complete_quest("q_escape")


# ---------------------------------------------------------------- 시민 대화 추가 (선물 / 도움 / 경고)

func _augment_all_dialogue() -> void:
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n):
			_augment_dialogue(n)


func _augment_dialogue(npc) -> void:
	if npc.has_meta("v2_aug"):
		return
	npc.set_meta("v2_aug", true)
	if npc.no_talk or npc.is_police or npc.dialogue.is_empty() or not npc.dialogue.has("start"):
		return
	var start: Dictionary = npc.dialogue["start"]
	var ch: Array = start.get("choices", [])
	if ch.size() < 1 or ch.size() >= 4:
		return
	var id: String = npc.npc_id
	var d: Dictionary = npc.dialogue
	d["v2_menu"] = {
		"text": "(잠시 말이 끊긴다) …무슨 이야기를 하고 싶으세요?",
		"choices": [
			{"label": "작은 선물", "next": "v2_gift"},
			{"label": "도와드릴까요?", "next": "v2_help"},
			{"label": "조심하라고 알린다", "next": "v2_warn"},
			{"label": "그만두기", "next": ""},
		],
	}
	d["v2_gift"] = {
		"text": "(주머니 속을 살핀다)",
		"choices": [
			{"label": "사탕을 건넨다", "next": "v2_gift_ok", "if": [{"item": "gift_sweets"}, {"not_flag": "v2_gift_" + id}]},
			{"label": "차를 건넨다", "next": "v2_gift_ok2", "if": [{"item": "gift_tea"}, {"not_flag": "v2_gift_" + id}]},
			{"label": "드릴 게 없다", "next": "v2_gift_none"},
		],
	}
	d["v2_gift_ok"] = {
		"text": "어머, 사탕이네요. 이런 걸 받아 본 지 오래예요. 고마워요.",
		"effects": [
			{"op": "take_item", "id": "gift_sweets"},
			{"op": "trust", "id": id, "delta": 1},
			{"op": "set_flag", "key": "v2_gift_" + id},
		],
		"choices": [{"label": "별말씀을요", "next": ""}],
	}
	d["v2_gift_ok2"] = {
		"text": "차를 다 주시네요. 따뜻하게 마실게요. 고마워요.",
		"effects": [
			{"op": "take_item", "id": "gift_tea"},
			{"op": "trust", "id": id, "delta": 1},
			{"op": "set_flag", "key": "v2_gift_" + id},
		],
		"choices": [{"label": "별말씀을요", "next": ""}],
	}
	d["v2_gift_none"] = {
		"text": "신경 써 주셔서 고마워요. 마음만 받을게요. (선물은 역 매점이나 상점에서 구할 수 있다.)",
		"choices": [{"label": "알겠어요", "next": ""}],
	}
	d["v2_help"] = {
		"text": "마침 들고 가던 짐이 좀 무거워서요. 잠깐만 들어 주실래요?",
		"choices": [
			{"label": "들어 드린다", "next": "v2_help_ok", "if": {"not_flag": "v2_help_" + id}},
			{"label": "오늘은 괜찮아요", "next": "v2_help_again", "if": {"flag": "v2_help_" + id}},
			{"label": "미안해요", "next": ""},
		],
	}
	d["v2_help_ok"] = {
		"text": "휴, 한결 가볍네요. 덕분에 살았어요. 정말 고마워요.",
		"effects": [
			{"op": "trust", "id": id, "delta": 1},
			{"op": "set_flag", "key": "v2_help_" + id},
			{"op": "toast", "text": "짐을 들어 주었다."},
		],
		"choices": [{"label": "또 봐요", "next": ""}],
	}
	d["v2_help_again"] = {
		"text": "오늘은 괜찮아요. 아까 도와주신 것만으로 충분해요.",
		"choices": [{"label": "네", "next": ""}],
	}
	d["v2_warn"] = {
		"text": "(귀를 기울인다) 무슨 일이죠?",
		"choices": [
			{"label": "근처에 순찰이 돌고 있어요", "next": "v2_warn_ok", "if": {"not_flag": "v2_warn_" + id}},
			{"label": "아무것도 아니에요", "next": ""},
		],
	}
	d["v2_warn_ok"] = {
		"text": "…알려 줘서 고마워요. 조심할게요. 당신도 눈에 띄지 않게 다녀요.",
		"effects": [
			{"op": "trust", "id": id, "delta": 1},
			{"op": "set_flag", "key": "v2_warn_" + id},
		],
		"choices": [{"label": "네", "next": ""}],
	}
	# 첫 화면에 '마음 나누기' 선택지 추가 (마지막 '떠나기' 앞)
	ch.insert(maxi(ch.size() - 1, 0), {"label": "마음 나누기", "next": "v2_menu"})
	start["choices"] = ch


# ---------------------------------------------------------------- 저장 / 불러오기

func to_dict() -> Dictionary:
	var d: Dictionary = {"version": 1, "esc_arrests": _esc_arrests}
	if weather != null:
		d["weather"] = weather.to_dict()
	return d


func from_dict(d: Dictionary) -> void:
	var w = d.get("weather")
	if weather != null and w is Dictionary:
		weather.from_dict(w)
	var ea = d.get("esc_arrests")
	if ea is float or ea is int:
		_esc_arrests = int(ea)
