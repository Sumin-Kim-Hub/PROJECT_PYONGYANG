extends Node
## 게임 총괄(허브). main.gd 가 setup() 으로 연결합니다.
##  - 게임 상태(GameState), 게임 시계(GameClock), 화면 UI(상호작용 UI + HUD)를 만들고
##  - 플레이어 가까이의 "interactable" 을 찾아 안내/버튼을 띄우며
##  - 대화, 출입(암전 이동), 앉기, 문, 조사, 줍기, 퀘스트 효과, 경비 발각, 저장/불러오기를 처리합니다.
##  - NPC / 건물 내부 / 도시 보강 모듈은 실행 중에 load() 로 불러와, 하나가 실패해도 나머지는 계속 동작합니다.
## 기존 player.gd / camera_rig.gd / world_builder.gd 는 수정하지 않습니다.

const Flags = preload("res://scripts/data/feature_flags.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const GameClockScript = preload("res://scripts/core/game_clock.gd")
const ItemData = preload("res://scripts/data/item_data.gd")
const QuestData = preload("res://scripts/data/quest_data.gd")

enum Mode { FREE, DIALOGUE, SITTING, TRANSITION, MENU, DRIVING }

const SAVE_PATH: String = "user://pyongyang_save.json"
const SAVE_VERSION: int = 1
## 앉았을 때 몸을 아래로 내리는 높이(m)
const SIT_DROP: float = 0.4
const ZOOM_MIN: float = 2.5
const ZOOM_MAX: float = 13.0

# main.gd 가 넘겨 주는 것들. 다른 스크립트의 함수를 불러야 해서 타입을 적지 않음
var player = null
var rig = null
var controls = null
var world = null

var ui = null
var hud = null
var game = null
var clock = null

var mode: int = Mode.FREE
## V1.0 확장 총괄 (v1/v1_manager.gd). 없으면 null → v0.2.0 과 같게 동작
var v1 = null
## V2.0 확장 총괄 (v2/v2_manager.gd). 없으면 null → V1.0 과 같게 동작
var v2 = null
## V2.2 확장 총괄 (v22/v22_manager.gd). 없으면 null → V2.1 과 같게 동작
var v22 = null
## 발각되었을 때 돌아가는 곳 {"pos","yaw","location"} (interior_manager 가 채움)
var respawn: Dictionary = {}

var _spawn_pos: Vector3 = Vector3.ZERO
var _target = null
var _npc = null
var _dlg: Dictionary = {}
var _dlg_node: Dictionary = {}
var _dlg_choices: Array = []
var _speaker: String = ""
var _role: String = ""
var _sit_anchor = null
var _stand_pos: Vector3 = Vector3.ZERO
var _vis: Node3D = null
var _e_prev: bool = false
var _poi_timer: float = 0.0
var _autosave_timer: float = 0.0
var _newgame_armed: float = 0.0
var _autoloaded: bool = false
var _modules_done: bool = false
## 새 게임 처리 중에는 자동 저장이 저장 파일을 다시 만들지 않도록 끔
var _saving_enabled: bool = true
var _panel_was_open: bool = false
var _location: String = ""
var _boot_time: float = 0.0


func setup(p_player, p_rig, p_controls, p_world: Node3D) -> void:
	player = p_player
	rig = p_rig
	controls = p_controls
	world = p_world
	_spawn_pos = player.global_position
	_vis = player.get_node_or_null("Visual")

	# NPC(충돌 레이어 2)와 부딪히도록 플레이어의 충돌 대상에 레이어 2를 추가
	player.collision_mask = 3

	# 게임 상태 + 시계
	game = GameStateScript.new()
	game.name = "GameState"
	add_child(game)
	clock = GameClockScript.new()
	clock.name = "GameClock"
	add_child(clock)
	game.clock = clock
	if not Flags.ENABLE_CLOCK:
		clock.paused = true
		clock.minutes = 10.0 * 60.0
	clock.speed = 2.0

	# 내부 조명이 태양 영향을 받지 않도록 태양은 레이어 1만 비춤
	var sun = get_tree().root.find_child("Sun", true, false)
	if sun != null and sun is DirectionalLight3D:
		sun.light_cull_mask = 1

	var ui_script = load("res://scripts/interaction/interaction_ui.gd")
	if ui_script == null or not ui_script.can_instantiate():
		push_error("interaction_ui.gd 를 불러오지 못했습니다. 상호작용 없이 기본 게임만 실행합니다.")
		set_process(false)
		return

	var layer = CanvasLayer.new()
	layer.name = "InteractionLayer"
	layer.layer = 3
	add_child(layer)
	ui = ui_script.new()
	ui.name = "InteractionUI"
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.interact_pressed.connect(_on_interact_pressed)
	ui.choice_selected.connect(_on_choice_selected)
	ui.advance_pressed.connect(_on_advance_pressed)
	ui.close_pressed.connect(_end_dialogue)

	# HUD: 트리에서 UI 보다 나중에 만들어 터치를 먼저 받고, 화면에서는 한 층 아래(암전이 위를 덮음)
	var hud_script = load("res://scripts/ui/hud_ui.gd")
	if hud_script != null and hud_script.can_instantiate():
		var hud_layer = CanvasLayer.new()
		hud_layer.name = "HudLayer"
		hud_layer.layer = 2
		add_child(hud_layer)
		hud = hud_script.new()
		hud.name = "HUD"
		hud_layer.add_child(hud)
		hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud.game = game
		hud.clock = clock
		hud.menu_action.connect(_on_menu_action)
	else:
		push_error("hud_ui.gd 를 불러오지 못했습니다. HUD 없이 실행합니다.")

	game.start_quest("q_tea")
	_start_modules()


## 모듈은 한 번에 하나씩 순서대로 만듭니다 (건물 자리를 서로 침범하지 않도록)
func _start_modules() -> void:
	# 그래픽 개선 모듈: 가장 먼저 시작 (충돌 있는 장식이 먼저 놓여야 아래 모듈들이 피해서 배치함)
	# 오류로 중간에 멈추더라도 최대 8초만 기다리고 다음으로 넘어감
	if Flags.ENABLE_GFX:
		var gfx = _spawn_module("res://scripts/gfx/gfx_manager.gd")
		if gfx != null:
			gfx.start(world, self)
			await gfx.wait_done(8.0)
	if Flags.ENABLE_V1:
		v1 = _spawn_module("res://scripts/v1/v1_manager.gd")
		if v1 != null:
			await v1.build_world(world, self)
		if v1 != null and Flags.ENABLE_V2:
			v2 = _spawn_module("res://scripts/v2/v2_manager.gd")
			if v2 != null:
				await v2.build_world(world, self)
	if Flags.ENABLE_V22:
		v22 = _spawn_module("res://scripts/v22/v22_manager.gd")
		if v22 != null:
			await v22.build_world(world, self)
	if Flags.ENABLE_INTERIORS:
		var interiors = _spawn_module("res://scripts/interior/interior_manager.gd")
		if interiors != null:
			await interiors.build(world, self)
	if Flags.ENABLE_CITY_EXTRAS:
		var extras = _spawn_module("res://scripts/city/city_extras.gd")
		if extras != null:
			await extras.build(world, self)
	if Flags.ENABLE_NPCS:
		var npcs = _spawn_module("res://scripts/npc/npc_manager.gd")
		if npcs != null:
			await npcs.spawn_all(world, self)
	if v1 != null:
		await v1.build_systems(world, self)
	if v2 != null:
		await v2.build_systems(world, self)
	if v22 != null:
		await v22.build_systems(world, self)
	_modules_done = true
	_try_autoload()


## 모듈 스크립트를 실행 중에 불러온다. 문법 오류가 있어도 다른 기능은 계속 동작하게 하기 위함.
func _spawn_module(path: String) -> Node:
	var script = load(path)
	if script == null or not script.can_instantiate():
		push_error("모듈을 불러오지 못했습니다: " + path)
		return null
	var n = script.new()
	add_child(n)
	return n


func _try_autoload() -> void:
	if _autoloaded:
		return
	_autoloaded = true
	_apply_world_flags()
	# V2: 시작 화면(새 게임 / 이어하기). 보여 줬다면 선택 뒤에 불러오기를 합니다.
	if v2 != null and v2.has_method("show_title"):
		if v2.show_title(FileAccess.file_exists(SAVE_PATH)):
			return
	if FileAccess.file_exists(SAVE_PATH):
		if load_game(true):
			toast("저장된 게임을 이어서 시작합니다.")


# ---------------------------------------------------------------- 도우미 (다른 모듈이 사용)

func toast(text: String) -> void:
	if hud != null:
		hud.show_toast(text)


func register_poi(id: String, poi_name: String, pos: Vector3) -> void:
	game.pois[id] = {"name": poi_name, "pos": pos}


func game_item_name(id: String) -> String:
	return ItemData.item_name(id)


func _set_location(loc: String) -> void:
	_location = loc
	if hud != null:
		hud.location_name = loc if loc != "" else "광장 일대"


# ---------------------------------------------------------------- 매 프레임

func _process(delta: float) -> void:
	if ui == null or player == null:
		return

	# 안전장치: 모듈 생성이 15초 안에 끝나지 않아도 저장 불러오기를 시도
	_boot_time += delta
	if not _autoloaded and _boot_time > 15.0:
		_try_autoload()

	var e_now: bool = Input.is_physical_key_pressed(KEY_E)
	var e_edge: bool = e_now and not _e_prev
	_e_prev = e_now

	_sync_hud(delta)

	var panel_open: bool = hud != null and hud.panel_open()
	if panel_open != _panel_was_open:
		_panel_was_open = panel_open
		if panel_open and mode == Mode.FREE:
			mode = Mode.MENU
			player.set_physics_process(false)
			player.velocity = Vector3.ZERO
		elif not panel_open and mode == Mode.MENU:
			mode = Mode.FREE
			player.set_physics_process(true)

	match mode:
		Mode.FREE:
			_target = _find_nearest()
			if _target != null:
				ui.set_prompt(_target.prompt, _target.button_label())
				if e_edge:
					_activate(_target)
			else:
				ui.clear_prompt()
		Mode.SITTING:
			if panel_open:
				ui.clear_prompt()
			else:
				ui.set_prompt("자리에서 일어나기", "일어서기")
				if e_edge:
					_stand_up()
		Mode.DRIVING:
			if panel_open or v1 == null or v1.drive == null:
				ui.clear_prompt()
			else:
				ui.set_prompt("차에서 내리기", "내리기")
				if e_edge:
					v1.drive.request_exit("E 키")
		_:
			ui.clear_prompt()

	if mode == Mode.FREE or mode == Mode.SITTING or mode == Mode.DRIVING:
		_update_stealth()

	_poi_timer -= delta
	if _poi_timer <= 0.0:
		_poi_timer = 0.5
		_check_pois()

	_autosave_timer += delta
	if _autosave_timer >= 60.0:
		_autosave_timer = 0.0
		if mode == Mode.FREE:
			save_game(true)

	if _newgame_armed > 0.0:
		_newgame_armed -= delta

	if Flags.SHOW_DEBUG_STATE:
		var mv: Vector2 = controls.get_move_vector()
		ui.debug_line = "mv(%.1f,%.1f) run:%s floor:%s mode:%s %s" % [
			mv.x, mv.y, str(controls.is_running()), str(player.is_on_floor()), _mode_name(), clock.time_label()]
	else:
		ui.debug_line = ""


func _mode_name() -> String:
	var names: Array = ["FREE", "DIALOGUE", "SITTING", "TRANSITION", "MENU", "DRIVING"]
	return str(names[mode])


func _sync_hud(_delta: float) -> void:
	if hud == null:
		return
	hud.player_pos = player.global_position
	if _vis != null:
		hud.player_yaw = _vis.rotation.y
	hud.blocked = mode == Mode.DIALOGUE or mode == Mode.TRANSITION


## 플레이어와 가장 가까운(반경 안의) 상호작용 지점
func _find_nearest():
	var best = null
	var best_d: float = 1000000.0
	var pp: Vector3 = player.global_position
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n.available(game):
			continue
		if not n.is_visible_in_tree():
			continue
		var dv: Vector3 = n.global_position - pp
		if absf(dv.y) > 2.5:
			continue
		var d: float = Vector2(dv.x, dv.z).length()
		if d <= n.radius and d < best_d:
			best_d = d
			best = n
	return best


func _check_pois() -> void:
	if player.global_position.y > 100.0:
		return
	var pp: Vector3 = player.global_position
	for id in game.pois.keys():
		if game.discovered.has(id):
			continue
		var p: Vector3 = game.pois[id]["pos"]
		if Vector2(p.x - pp.x, p.z - pp.z).length() < 26.0:
			game.discovered[id] = true
			toast("새 장소 발견: " + str(game.pois[id]["name"]))


# ---------------------------------------------------------------- 버튼 처리

func _on_interact_pressed() -> void:
	print("[PYONGYANG] 상호작용 버튼 입력 · mode=%s · 대상=%s" % [_mode_name(), str(_target != null)])
	if mode == Mode.FREE and _target != null:
		_activate(_target)
	elif mode == Mode.SITTING:
		_stand_up()
	elif mode == Mode.DRIVING:
		# V3.0.1: 화면의 '내리기' 버튼은 터치로 여기에 들어온다. 예전에는 이 분기가 없어 아무 일도 하지 않았다 (E 키만 하차됨).
		if v1 != null and v1.drive != null:
			v1.drive.request_exit("터치 버튼")


func _activate(t) -> void:
	match t.kind:
		"talk":
			_start_dialogue(t)
		"enter", "exit", "portal":
			_use_portal(t)
		"sit":
			_sit(t)
		"door":
			var door = t.data.get("door")
			if door != null:
				var msg: String = door.interact()
				if msg != "":
					toast(msg)
		"examine":
			_examine(t)
		"pickup":
			_pickup(t)
		"vehicle":
			if v1 != null and v1.drive != null:
				v1.drive.enter(t.data.get("vehicle"))


func _on_menu_action(id: String) -> void:
	if id.begins_with("setting:"):
		if v1 != null:
			v1.on_menu_action(id)
		return
	match id:
		"zoom_in":
			_zoom(-1.5)
		"zoom_out":
			_zoom(1.5)
		"save":
			if save_game(false):
				toast("저장했습니다.")
			else:
				toast("저장에 실패했습니다.")
		"load":
			if FileAccess.file_exists(SAVE_PATH):
				if load_game(false):
					toast("불러왔습니다.")
				else:
					toast("저장 파일을 읽지 못했습니다.")
			else:
				toast("저장된 파일이 없습니다.")
		"newgame":
			if _newgame_armed > 0.0:
				_new_game()
			else:
				_newgame_armed = 4.0
				toast("진행 내용이 모두 지워집니다. 4초 안에 한 번 더 누르면 새로 시작합니다.")


func _zoom(delta_m: float) -> void:
	var arm = rig.get("_arm")
	if arm != null and arm is SpringArm3D:
		arm.spring_length = clampf(arm.spring_length + delta_m, ZOOM_MIN, ZOOM_MAX)


# ---------------------------------------------------------------- 1) 대화

func _start_dialogue(t) -> void:
	var npc = t.data.get("npc")
	if npc == null or npc.dialogue.is_empty():
		return
	_npc = npc
	_dlg = npc.dialogue
	_speaker = npc.display_name
	_role = npc.role
	if v22 != null:
		_role = str(v22.role_label(npc))
	_enter_dialogue_mode()
	if v1 != null:
		v1.on_dialogue_start(npc)
	npc.begin_talk(player.global_position)
	# 플레이어도 NPC 쪽을 바라보게 함
	if _vis != null:
		var v: Vector3 = npc.global_position - player.global_position
		_vis.rotation.y = atan2(-v.x, -v.z)
	var start: String = "start"
	for e in _dlg.get("entry", []):
		if game.check(e.get("if")):
			start = str(e.get("node", "start"))
			break
	_show_node(start)


func _enter_dialogue_mode() -> void:
	mode = Mode.DIALOGUE
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	ui.clear_prompt()


## 설명문(조사/줍기)을 대화창으로 보여 줌. 화면을 탭하면 닫힘
func _show_text(title: String, text: String, effects: Array = []) -> void:
	_npc = null
	_speaker = title
	_role = ""
	_dlg = {"t": {"text": text, "effects": effects, "next": ""}}
	_enter_dialogue_mode()
	_show_node("t")


func _show_node(id: String) -> void:
	if not _dlg.has(id):
		_end_dialogue()
		return
	_dlg_node = _dlg[id]
	apply_effects(_dlg_node.get("effects", []))
	var text: String = str(_dlg_node.get("text", ""))
	if _dlg_node.has("dyn"):
		var dyn_kind: String = str(_dlg_node["dyn"])
		if dyn_kind.begins_with("v22_") and v22 != null:
			text = v22.dynamic_text(dyn_kind, _npc)
		elif v1 != null:
			text = v1.dynamic_text(dyn_kind, _npc)
	var variants: Dictionary = _dlg_node.get("variants", {})
	var period: String = clock.period_name()
	if variants.has(period):
		text = str(variants[period])
	_dlg_choices = []
	var labels: Array = []
	for c in _dlg_node.get("choices", []):
		if c.has("if") and not game.check(c["if"]):
			continue
		_dlg_choices.append(c)
		labels.append(str(c.get("label", "...")))
	ui.open_dialogue(_speaker, _role, text, labels)


func _on_choice_selected(index: int) -> void:
	if mode != Mode.DIALOGUE:
		return
	if index < 0 or index >= _dlg_choices.size():
		return
	var c: Dictionary = _dlg_choices[index]
	apply_effects(c.get("effects", []))
	var nxt: String = str(c.get("next", ""))
	if nxt == "":
		_end_dialogue()
	else:
		_show_node(nxt)


func _on_advance_pressed() -> void:
	if mode != Mode.DIALOGUE:
		return
	var nxt: String = str(_dlg_node.get("next", ""))
	if nxt == "":
		_end_dialogue()
	else:
		_show_node(nxt)


func _end_dialogue() -> void:
	if mode != Mode.DIALOGUE:
		return
	ui.close_dialogue()
	var ended_npc = _npc
	if _npc != null:
		_npc.end_talk()
	_npc = null
	if v1 != null:
		v1.on_dialogue_end(ended_npc)
	_dlg = {}
	_dlg_node = {}
	_dlg_choices = []
	player.set_physics_process(true)
	mode = Mode.FREE


# ---------------------------------------------------------------- 2) 건물 출입 / 이동

func _use_portal(t) -> void:
	var req = t.data.get("requires")
	if req != null and not game.check(req):
		toast(str(t.data.get("locked_text", "잠겨 있다.")))
		return
	mode = Mode.TRANSITION
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	ui.clear_prompt()
	var dest: Vector3 = t.data["dest"]
	var dest_yaw: float = float(t.data.get("dest_yaw", 0.0))
	var location: String = str(t.data.get("location", ""))
	var effects: Array = t.data.get("effects", [])
	await ui.fade_to(1.0, 0.3)
	_teleport(dest, dest_yaw)
	_set_location(location)
	apply_effects(effects)
	await get_tree().create_timer(0.15).timeout
	await ui.fade_to(0.0, 0.3)
	player.set_physics_process(true)
	mode = Mode.FREE


## 플레이어와 카메라를 함께 옮긴다. (카메라 코드는 수정하지 않고, 위치/방향 값만 맞춰 줌)
func _teleport(pos: Vector3, yaw: float) -> void:
	# V2.2: 바깥으로 나올 때는 바닥을 찾아 정확히 내려놓음 (공중 생성/추락 방지)
	if v22 != null and pos.y < 100.0:
		pos = v22.safe_outdoor_pos(pos)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	if "yaw" in rig:
		rig.yaw = yaw
	rig.global_position = pos + Vector3(0.0, 1.6, 0.0)
	if _vis != null:
		_vis.rotation.y = yaw
	if v22 != null:
		v22.after_teleport()


# ---------------------------------------------------------------- 3) 앉기

func _sit(t) -> void:
	if not Flags.ENABLE_SITTING:
		return
	mode = Mode.SITTING
	_sit_anchor = t
	t.data["occupied_by"] = player
	_stand_pos = t.data["stand_pos"]
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.global_position = t.data["pos"]
	if _vis != null:
		_vis.rotation.y = float(t.data.get("yaw", 0.0))
		if bool(t.data.get("lie", false)):
			# 침대에 눕기: 몸을 뒤로 눕힘 (발 쪽이 pos, 머리는 yaw 의 뒤쪽)
			_vis.rotation.x = PI * 0.5
			_vis.position.y = 0.17
		else:
			_vis.position.y = -SIT_DROP
	apply_effects(t.data.get("effects", []))


func _stand_up() -> void:
	if _vis != null:
		_vis.position.y = 0.0
		_vis.rotation.x = 0.0
	if _sit_anchor != null:
		_sit_anchor.data["occupied_by"] = null
		_sit_anchor = null
	player.global_position = _stand_pos
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	mode = Mode.FREE


# ---------------------------------------------------------------- 4) 조사 / 줍기

func _examine(t) -> void:
	var once: String = str(t.data.get("once_flag", ""))
	_show_text("살펴보기", str(t.data.get("text", "")), t.data.get("effects", []))
	if once != "":
		game.set_flag(once, true)


func _pickup(t) -> void:
	var item: String = str(t.data.get("item", ""))
	var flag: String = str(t.data.get("flag", ""))
	if item == "":
		return
	game.add_item(item)
	if flag != "":
		game.set_flag(flag, true)
	for m in get_tree().get_nodes_in_group("pk_mark_" + item):
		m.visible = false
	toast("획득: " + ItemData.item_name(item))
	_show_text(ItemData.item_name(item), str(t.data.get("text", "")), t.data.get("effects", []))


# ---------------------------------------------------------------- 효과 / 퀘스트

func apply_effects(effects: Array) -> void:
	for e in effects:
		if e.has("if") and not game.check(e["if"]):
			continue
		var op: String = str(e.get("op", ""))
		match op:
			"set_flag":
				game.set_flag(str(e.get("key", "")), bool(e.get("value", true)))
			"give_item":
				var gid: String = str(e.get("id", ""))
				game.add_item(gid, int(e.get("count", 1)))
				toast("획득: " + ItemData.item_name(gid))
			"take_item":
				var tid: String = str(e.get("id", ""))
				if game.has_item(tid):
					game.remove_item(tid, int(e.get("count", 1)))
					toast("건넴: " + ItemData.item_name(tid))
			"quest_start":
				var qid: String = str(e.get("id", ""))
				if game.start_quest(qid):
					toast("새 임무: " + game.quest_title(qid))
			"quest_step":
				var sid: String = str(e.get("id", ""))
				if game.set_quest_step(sid, int(e.get("step", 0))):
					toast("임무 갱신: " + game.quest_step_text(sid))
			"quest_complete":
				_complete_quest(str(e.get("id", "")))
			"toast":
				toast(str(e.get("text", "")))
			"unlock_door":
				var did: String = str(e.get("id", ""))
				game.set_flag("unlock_" + did, true)
				for d in get_tree().get_nodes_in_group("doors"):
					if d.door_id == did:
						d.unlock()
			"open_door":
				var oid: String = str(e.get("id", ""))
				for d2 in get_tree().get_nodes_in_group("doors"):
					if d2.door_id == oid:
						d2.set_open(true)
			"reveal":
				_reveal(str(e.get("id", "")))
			_:
				var handled: bool = false
				if v22 != null:
					handled = bool(v22.on_effect(op, e))
				if not handled and v1 != null:
					v1.on_effect(op, e)


func _complete_quest(qid: String) -> void:
	if not game.complete_quest(qid):
		return
	toast("임무 완료: " + game.quest_title(qid))
	var q: Dictionary = QuestData.QUESTS.get(qid, {})
	for it in q.get("reward_items", []):
		game.add_item(str(it))
		toast("보상: " + ItemData.item_name(str(it)))
	var nxt: String = str(q.get("next", ""))
	if nxt != "" and game.start_quest(nxt):
		toast("새 임무: " + game.quest_title(nxt))


## 책장 같은 가림막을 치움 (그룹 "reveal_<id>" 의 노드를 숨기고 충돌을 끔)
func _reveal(id: String) -> void:
	for n in get_tree().get_nodes_in_group("reveal_" + id):
		n.visible = false
		_disable_collision(n)


func _disable_collision(n: Node) -> void:
	if n is CollisionObject3D:
		n.collision_layer = 0
	for c in n.get_children():
		_disable_collision(c)


## 저장/불러오기 뒤에 월드 모습을 상태에 맞게 맞춤
func _apply_world_flags() -> void:
	if game.get_flag("passage_found"):
		_reveal("shelf")
	if game.get_flag("station_panel_found"):
		_reveal("station_panel")
	for k in game.flags.keys():
		var ks: String = str(k)
		if ks.begins_with("pk_") and game.get_flag(ks):
			for m in get_tree().get_nodes_in_group("pk_mark_" + ks.substr(3)):
				m.visible = false
	for d in get_tree().get_nodes_in_group("doors"):
		d.setup(self)
	if v22 != null:
		v22.apply_world_flags()


# ---------------------------------------------------------------- 5) 잠입 / 발각

func _update_stealth() -> void:
	var worst: float = 0.0
	for g in get_tree().get_nodes_in_group("guards"):
		worst = maxf(worst, g.suspicion)
	if hud != null:
		hud.alert = clampf(worst, 0.0, 1.0)
	if worst >= 1.0:
		_caught()


func _caught() -> void:
	if mode == Mode.TRANSITION:
		return
	if mode == Mode.DRIVING and v1 != null and v1.drive != null:
		v1.drive.force_exit()
	if mode == Mode.SITTING:
		_stand_up()
	mode = Mode.TRANSITION
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	ui.clear_prompt()
	toast("경비에게 발각되었다!")
	await ui.fade_to(1.0, 0.4)
	for g in get_tree().get_nodes_in_group("guards"):
		g.reset_guard()
	var pos: Vector3 = _spawn_pos
	var yaw: float = 0.0
	var loc: String = ""
	if respawn.has("pos"):
		pos = respawn["pos"]
		yaw = float(respawn.get("yaw", 0.0))
		loc = str(respawn.get("location", ""))
	_teleport(pos, yaw)
	_set_location(loc)
	if v1 != null:
		v1.on_caught()
	if v22 != null:
		v22.on_caught()
	if hud != null:
		hud.alert = 0.0
	await get_tree().create_timer(0.4).timeout
	await ui.fade_to(0.0, 0.4)
	toast("들킨 뒤 안전한 곳으로 돌아왔다. 다시 시도해 보자.")
	player.set_physics_process(true)
	mode = Mode.FREE


# ---------------------------------------------------------------- 6) 저장 / 불러오기

func save_game(silent: bool) -> bool:
	if game == null or clock == null or player == null or not _saving_enabled:
		return false
	var p: Vector3 = player.global_position
	# 앉아 있으면 일어선 자리를 저장
	if mode == Mode.SITTING:
		p = _stand_pos
	# 운전 중이면 차에서 내릴 자리를 저장
	if mode == Mode.DRIVING and v1 != null and v1.drive != null:
		p = v1.drive.exit_position()
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"game": game.to_dict(),
		"minutes": clock.minutes,
		"pos": [p.x, p.y, p.z],
		"yaw": _vis.rotation.y if _vis != null else 0.0,
		"location": _location,
		"zoom": _current_zoom(),
	}
	if v1 != null:
		data["v1"] = v1.to_dict()
	if v2 != null:
		data["v2"] = v2.to_dict()
	if v22 != null:
		data["v22"] = v22.to_dict()
	var text: String = JSON.stringify(data)
	# 임시 파일에 먼저 쓰고 이름을 바꿔서, 쓰는 도중 앱이 꺼져도 기존 저장이 깨지지 않게 함
	var tmp_path: String = SAVE_PATH + ".tmp"
	var f = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
		var err: int = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(SAVE_PATH))
		if err == OK:
			return true
	# 이름 바꾸기가 안 되면 직접 쓰기
	var f2 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f2 == null:
		if not silent:
			push_warning("저장 파일을 열 수 없습니다.")
		return false
	f2.store_string(text)
	f2.close()
	return true


func _current_zoom() -> float:
	var arm = rig.get("_arm")
	if arm != null and arm is SpringArm3D:
		return arm.spring_length
	return 6.5


func load_game(silent: bool) -> bool:
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text: String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		if not silent:
			push_warning("저장 파일 형식이 올바르지 않습니다.")
		return false
	var d: Dictionary = parsed
	if not d.has("game") or not (d["game"] is Dictionary):
		return false
	if mode == Mode.DIALOGUE:
		_end_dialogue()
	if mode == Mode.SITTING:
		_stand_up()
	if mode == Mode.DRIVING and v1 != null and v1.drive != null:
		v1.drive.force_exit()
	game.from_dict(d["game"])
	if _is_num(d.get("minutes")):
		clock.set_minutes(float(d["minutes"]))
	if _is_num(d.get("zoom")):
		var arm = rig.get("_arm")
		if arm != null and arm is SpringArm3D:
			arm.spring_length = clampf(float(d["zoom"]), ZOOM_MIN, ZOOM_MAX)
	var pa = d.get("pos")
	if pa is Array and pa.size() == 3:
		var ok: bool = true
		for v in pa:
			if not _is_num(v):
				ok = false
		var pos = Vector3.ZERO
		if ok:
			pos = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		var indoors: bool = pos.y > 100.0
		if indoors and not Flags.ENABLE_INTERIORS:
			ok = false
		if absf(pos.x) > 1000.0 or absf(pos.z) > 1000.0 or pos.y < -5.0:
			ok = false
		if ok:
			var yaw_v: float = 0.0
			if _is_num(d.get("yaw")):
				yaw_v = float(d["yaw"])
			_teleport(pos + Vector3(0.0, 0.15, 0.0), yaw_v)
			_set_location(str(d.get("location", "")))
	_apply_world_flags()
	if v1 != null and d.get("v1") is Dictionary:
		v1.from_dict(d["v1"])
	if v2 != null and d.get("v2") is Dictionary:
		v2.from_dict(d["v2"])
	if v22 != null and d.get("v22") is Dictionary:
		v22.from_dict(d["v22"])
	return true


## 숫자(정수/실수)이고 NaN/무한대가 아닌지 확인
func _is_num(v) -> bool:
	if v is float or v is int:
		return not (is_nan(float(v)) or is_inf(float(v)))
	return false


func _new_game() -> void:
	_saving_enabled = false
	for path in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().reload_current_scene()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _modules_done and mode != Mode.TRANSITION:
			save_game(true)
