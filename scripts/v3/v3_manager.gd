extends Node
## V3.0 총괄. v22_manager 가 만들어서 붙이는 모듈 묶음:
##   v3_story.gd  (ACT 진행, 지도자 대면, 권력 승계 장면)
##   v3_leader.gd (지도자 모드: 의상, 경호원, 차량, 특권, 조망 카메라)
##   v3_gov.gd    (국가 지표, 정산, 정책, 예산 배분, 회의, 목표)
##   v3_build.gd  (도시 개발: 건설)
##   v3_ui.gd     (통치 메뉴, 지표, 건설 버튼, 컷씬 카드)
## 기존 코드는 거의 건드리지 않는다: 효과(v3_*)와 대화 글(v22_v3_*)은 v22_manager 가 이 모듈로 넘겨 주고,
## 저장은 v22 저장 안에 "v3" 칸으로 들어간다. (Godot 실행 미검증)

const Flags = preload("res://scripts/data/feature_flags.gd")
const D = preload("res://scripts/v3/v3_data.gd")

var hub = null
var mgr = null

var story = null
var gov = null
var build = null
var leader = null
var ui = null
var layer: CanvasLayer = null

var done: bool = false
var is_leader: bool = false
var route: String = ""

var _pending: Array = []
var _speech_day: int = -1
var _travel_busy: bool = false
var _menu_mode_set: bool = false
var _test_t: float = 0.0
var _test_done: bool = false


func build_all(hub_ref, mgr_ref) -> void:
	hub = hub_ref
	mgr = mgr_ref
	_reset_leftover_outfit()

	var gov_s = load("res://scripts/v3/v3_gov.gd")
	var bld_s = load("res://scripts/v3/v3_build.gd")
	var sty_s = load("res://scripts/v3/v3_story.gd")
	var ldr_s = load("res://scripts/v3/v3_leader.gd")
	var ui_s = load("res://scripts/v3/v3_ui.gd")
	if gov_s == null or bld_s == null or sty_s == null or ldr_s == null or ui_s == null \
			or not gov_s.can_instantiate() or not bld_s.can_instantiate() or not sty_s.can_instantiate() \
			or not ldr_s.can_instantiate() or not ui_s.can_instantiate():
		push_error("V3.0: 모듈 파일 하나 이상을 불러오지 못했습니다. V3.0 기능은 꺼집니다.")
		done = true
		return

	gov = gov_s.new()
	gov.name = "V3Gov"
	add_child(gov)
	gov.setup(hub, mgr)
	gov.notice.connect(_on_notice)

	build = bld_s.new()
	build.name = "V3Build"
	add_child(build)
	build.setup(hub, mgr, gov)
	gov.build = build

	story = sty_s.new()
	story.name = "V3Story"
	add_child(story)
	story.setup(hub, mgr, self)

	leader = ldr_s.new()
	leader.name = "V3Leader"
	add_child(leader)
	leader.setup(hub, mgr, self)
	leader.build_static()

	layer = CanvasLayer.new()
	layer.name = "V3Layer"
	layer.layer = 6
	add_child(layer)
	ui = ui_s.new()
	ui.name = "V3UI"
	layer.add_child(ui)
	ui.setup(self, gov, build)

	done = true
	print("[PYONGYANG] V3.0 준비 완료 (스토리 %s, 통치 %s, 건설 %s)." % [
		"켬" if Flags.V3_STORY else "꺼짐", "켬" if Flags.V3_GOVERN else "꺼짐", "켬" if Flags.V3_BUILD else "꺼짐"])


## 새 게임으로 장면을 다시 불렀을 때 이전 지도자 의상이 남아 있지 않게 정리
func _reset_leftover_outfit() -> void:
	var cb = load("res://scripts/gfx/character_builder.gd")
	if cb == null:
		return
	if not cb.player_override.is_empty():
		cb.player_override = {}
		for c in hub.get_children():
			if c.has_method("_swap_player"):
				c._swap_player()
				break


func _on_notice(text: String) -> void:
	if hub != null:
		hub.toast(text)


func route_name() -> String:
	if route == "":
		return "—"
	return str(D.route_info(route)["name"])


# ================================================================ 지도자 되기 / 끝내기

func become_leader(r: String) -> void:
	is_leader = true
	route = r
	var g = hub.game
	g.set_flag("v3_ending_" + r, true)
	g.set_flag("v3_ending_seen", true)
	if g.quest_state("q_v3_story") == "active":
		g.set_quest_step("q_v3_story", 5)
		hub._complete_quest("q_v3_story")
	gov.start_new(r)
	build.clear_all()
	leader.enter_mode(true)


func _apply_loaded(was_leader: bool, car_arr) -> void:
	build.cancel_placing()
	if is_leader:
		story.remove_leader_npc()
		leader.enter_mode(true)
		if car_arr is Array and car_arr.size() >= 4:
			leader.restore_car(car_arr)
	else:
		if was_leader or leader.active:
			leader.exit_mode()
		gov.stop()


# ================================================================ v22_manager 연결 고리

func on_effect(op: String, e: Dictionary) -> bool:
	match op:
		"v3_eval":
			if story != null:
				story.evaluate_support()
			return true
		"v3_succeed":
			if story != null:
				story.run_succession(str(e.get("route", "will")))
			return true
		"v3_do":
			_pending.append(str(e.get("key", "")))
			return true
		"v3_loyal":
			if gov != null:
				gov.add_loyalty(str(e.get("id", "")), int(e.get("d", 1)))
			return true
	return false


func dynamic_text(kind: String, _npc) -> String:
	if kind == "v22_v3_support":
		if story != null:
			return story.support_text()
		return ""
	if kind == "v22_v3_advice_ex":
		return _ex_advice()
	if kind.begins_with("v22_v3_advice_") and gov != null:
		var pid: String = kind.substr(14)
		return D.advice(pid, gov.ind, gov.get_loyalty(pid))
	return ""


func _ex_advice() -> String:
	if gov == null or gov.ind.is_empty():
		return "숫자만 보지 마라. 숫자 뒤에는 늘 사람이 있다."
	var worst_k: String = ""
	var worst_v: float = 999.0
	for k in D.IND_KEYS:
		if k == "budget":
			continue
		var v: float = gov.value(k)
		if v < worst_v:
			worst_v = v
			worst_k = k
	return "지금 가장 약한 곳은 '%s'(%d)다. 숫자 뒤에는 늘 사람이 있다. 거기부터 살펴라." % [str(D.IND_NAMES[worst_k]), int(worst_v)]


func objective() -> Dictionary:
	if story == null:
		return {}
	return story.objective()


func apply_world_flags() -> void:
	pass


# ================================================================ 매 프레임

func _process(delta: float) -> void:
	if not done or hub == null:
		return
	if build != null and build.placing:
		build.update_ghost(delta)
	if not _pending.is_empty() and int(hub.mode) == 0:
		var key: String = str(_pending.pop_front())
		_run_action(key)
	if not _test_done and (Flags.V3_TEST_LEDGER or Flags.V3_TEST_LEADER):
		_test_t += delta
		if _test_t > 7.0 and hub.player != null and int(hub.mode) == 0 and not is_leader:
			_test_done = true
			_apply_test_shortcut()


## 시험용 지름길 (feature_flags.gd 의 V3_TEST_LEDGER / V3_TEST_LEADER). 보통은 꺼져 있다.
func _apply_test_shortcut() -> void:
	var g = hub.game
	if Flags.V3_TEST_LEADER:
		hub.toast("시험용 지름길: 승계 장면으로 바로 이동합니다.")
		story.run_succession("will")
		return
	g.add_item("pass_special", 1)
	g.add_item("doc_v23_ledger", 1)
	g.set_flag("passed_north", true)
	hub.toast("시험용 지름길: 특별 통행증과 장부를 지급했습니다. 청사 정문 경비와 대화해 통과한 뒤 집무실로 가세요.")
	_travel(Vector3(-245.0, 0.1, -278.0), 0.0, "중앙 청사 정문 앞")


func _run_action(key: String) -> void:
	if not is_leader:
		return
	match key:
		"menu_status":
			ui.open_panel("status")
		"menu_meeting":
			ui.open_panel("meeting")
		"overlook":
			_do_overlook()
		"sleep":
			_do_sleep()
		"speech":
			_do_speech()
		"car":
			hub.toast(leader.summon_car())


# ================================================================ 화면 상태

func ui_visible() -> bool:
	if hub == null:
		return false
	var m: int = int(hub.mode)
	if m == 1 or m == 3:
		return false
	return true


func can_open_menu() -> bool:
	return int(hub.mode) == 0 and not (build != null and build.placing)


func on_panel_changed(opened: bool) -> void:
	if opened:
		if int(hub.mode) == 0:
			hub.mode = 4
			hub.player.velocity = Vector3.ZERO
			hub.player.set_physics_process(false)
			_menu_mode_set = true
	else:
		if _menu_mode_set and int(hub.mode) == 4 and not (leader != null and leader.overlook_active):
			hub.mode = 0
			hub.player.set_physics_process(true)
		_menu_mode_set = false


func on_overlook(opened: bool) -> void:
	if opened:
		if int(hub.mode) == 0:
			hub.mode = 4
			hub.player.velocity = Vector3.ZERO
			hub.player.set_physics_process(false)
			_menu_mode_set = true
	else:
		if _menu_mode_set and int(hub.mode) == 4 and ui.panel == "":
			hub.mode = 0
			hub.player.set_physics_process(true)
		_menu_mode_set = false


# ================================================================ UI 가 부르는 동작

func act_policy(pid: String) -> String:
	var r: Dictionary = gov.exec_policy(pid)
	if bool(r["ok"]):
		hub.toast(str(r["text"]))
	return str(r["text"])


func act_alloc(key: String, d: int) -> void:
	gov.change_alloc(key, d)


func act_build_start(tid: String) -> String:
	if build == null or not Flags.V3_BUILD:
		return "도시 개발 기능이 꺼져 있습니다."
	if not build.can_afford(tid):
		return "예산이 부족합니다."
	if build.count() >= D.MAX_BUILDINGS:
		return "더 이상 지을 수 없습니다."
	ui.close_panel()
	build.start_placing(tid)
	hub.toast("건설 모드: 걸어서 위치를 정하고 '건설 확정'을 누르세요.")
	return ""


func act_build_confirm() -> String:
	var r: Dictionary = build.confirm_place()
	if bool(r["ok"]):
		hub.toast(str(r["text"]))
	return str(r["text"])


func act_build_rotate() -> void:
	build.rotate_ghost()


func act_build_cancel() -> void:
	build.cancel_placing()


func act_demolish() -> String:
	var r: Dictionary = build.demolish_last()
	return str(r["text"])


func act_meet_open() -> void:
	gov.open_meeting()


func act_meet_pick(i: int) -> void:
	gov.choose_option(i)
	if gov.current_card.get("done", false):
		hub.toast("회의 결정: " + str(gov.current_card.get("result", "")))


func act_meet_close() -> void:
	gov.close_meeting()


func act_cheer(pid: String) -> String:
	return gov.cheer(pid)


func act_gift(pid: String) -> String:
	return gov.gift(pid)


func act_save() -> String:
	if hub.save_game(false):
		return "저장했습니다."
	return "저장에 실패했습니다."


func act_load() -> void:
	ui.close_panel()
	hub._on_menu_action("load")


func act_travel(where: String) -> void:
	if _travel_busy or int(hub.mode) != 0:
		hub.toast("지금은 이동할 수 없습니다.")
		return
	match where:
		"office":
			_travel(Vector3(1300.0, 300.1, -22.4), 0.0, "중앙 청사 집무실")
		"res":
			_travel(Vector3(1400.0, 300.1, 2.6), 0.0, "사저")
		"car":
			hub.toast(leader.summon_car())
		"view":
			_do_overlook()


func _travel(dest: Vector3, yaw: float, loc: String) -> void:
	_travel_busy = true
	hub.mode = 3
	hub.player.velocity = Vector3.ZERO
	hub.player.set_physics_process(false)
	hub.ui.clear_prompt()
	await hub.ui.fade_to(1.0, 0.3)
	hub._teleport(dest, yaw)
	hub._set_location(loc)
	await get_tree().create_timer(0.15).timeout
	await hub.ui.fade_to(0.0, 0.3)
	hub.player.set_physics_process(true)
	hub.mode = 0
	_travel_busy = false


func _do_overlook() -> void:
	if int(hub.mode) != 0 or leader == null:
		return
	await hub.ui.fade_to(1.0, 0.25)
	leader.overlook_start()
	await hub.ui.fade_to(0.0, 0.25)


func _do_sleep() -> void:
	if int(hub.mode) != 0:
		return
	hub.mode = 3
	hub.player.set_physics_process(false)
	hub.ui.clear_prompt()
	await hub.ui.fade_to(1.0, 0.6)
	leader.sleep_until_morning()
	await get_tree().create_timer(0.6).timeout
	await hub.ui.fade_to(0.0, 0.8)
	hub.player.set_physics_process(true)
	hub.mode = 0
	hub.toast("아침이 밝았다. 도시는 밤사이에도 움직였다.")


func _do_speech() -> void:
	var day: int = gov.current_day_index()
	if _speech_day == day:
		hub.toast("오늘은 이미 연설을 준비했다.")
		return
	_speech_day = day
	gov.apply_delta({"satisfaction": 1.0, "stability": 1.0})
	hub.toast("연설을 준비했다. (만족 +1, 안정 +1)")


# ================================================================ 저장 / 불러오기

func to_dict() -> Dictionary:
	var d: Dictionary = {"leader": is_leader, "route": route, "speech": _speech_day}
	if gov != null:
		d["gov"] = gov.to_dict()
	if build != null:
		d["build"] = build.to_dict()
	if leader != null:
		d["car"] = leader.car_state()
	return d


func from_dict(d: Dictionary) -> void:
	if not done or gov == null:
		return
	var was: bool = is_leader
	is_leader = bool(d.get("leader", false))
	route = str(d.get("route", ""))
	_speech_day = int(d.get("speech", -1))
	var dg = d.get("gov")
	if dg is Dictionary:
		gov.from_dict(dg)
	else:
		gov.stop()
	var db = d.get("build")
	if db is Dictionary:
		build.from_dict(db)
	else:
		build.clear_all()
	if is_leader and not gov.running:
		# 지도자 상태인데 지표가 없으면(손상된 저장) 승계 경로의 시작값으로 복구
		gov.start_new(route if route != "" else "will")
	_apply_loaded(was, d.get("car"))
