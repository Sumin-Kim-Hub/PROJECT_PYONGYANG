extends Node
## V2.2 총괄. 허브(interaction_system.gd)가 불러 쓰는 창구입니다.
##  - 실내에서 나올 때 공중에서 떨어지는 문제를 막는 안전 착지 (바닥 찾기, 착지 감시, 낙하 복구)
##  - 새 지역(v22_world.gd) / 새 실내(v22_interiors.gd) / 통행증(pass_system.gd) / NPC 상호작용(npc_social.gd)
##  - 대화 효과(v22_* 연산), 임무 자동 진행, 랜덤 이벤트, 탐험 보상, 방송/소리, 목표 안내, 지도 덧그리기, 저장
## 모듈 하나가 실패해도 게임이 멈추지 않도록, 각 단계는 시간 제한을 두고 기다립니다. (Godot 실행 미검증)

const Flags = preload("res://scripts/data/feature_flags.gd")
const VData = preload("res://scripts/v22/v22_data.gd")
const Placement = preload("res://scripts/interaction/placement.gd")

var hub = null
var world: Node3D = null
var pass_sys = null
var social = null
var vworld = null
var interiors = null
var audio = null
## V2.3 중앙 청사 + 사저 (v23/v23_leader.gd). 꺼져 있으면 null
var v23 = null
## V3.0 스토리 캠페인 + 최고지도자 통치 (v3/v3_manager.gd). 꺼져 있으면 null
var v3 = null
var selftest = null

## 대화창에 보여 줄 마지막 결과 문장 (효과가 채우고 dyn 노드가 읽음)
var last_text: String = ""
## 날짜(게임 속) — 임시 통행증 기한 계산용
var day: int = 0
var fall_recoveries: int = 0
var events_seen: int = 0

var _last_minutes: float = -1.0
var _last_safe_out: Vector3 = Vector3(0.0, 0.1, 6.0)
var _last_safe_in: Vector3 = Vector3.ZERO
var _safe_t: float = 0.0
var _land_t: float = 0.0
var _pad: StaticBody3D = null
var _tick1: float = 0.0
var _tick_cull: float = 0.0
var _tick_obj: float = 0.0
var _event_t: float = 60.0
var _rng = RandomNumberGenerator.new()
var _obj_text: String = ""
var _obj_target: Vector3 = Vector3.ZERO
var _obj_has: bool = false
var _status_text: String = ""
var _known: Dictionary = {}
var _ready_done: bool = false
var _siren_t: float = 0.0
var _vault_fail: int = 0


func _ready() -> void:
	_rng.randomize()


# ================================================================ 만들기

func build_world(world_ref: Node3D, hub_ref) -> void:
	world = world_ref
	hub = hub_ref
	if Flags.V22_PASS:
		var ps = load("res://scripts/v22/pass_system.gd")
		if ps != null and ps.can_instantiate():
			pass_sys = ps.new()
			pass_sys.name = "PassSystem"
			add_child(pass_sys)
			pass_sys.setup(hub, self)
		else:
			push_error("V2.2: pass_system.gd 를 불러오지 못했습니다.")
	if Flags.V22_SOCIAL:
		var ns = load("res://scripts/v22/npc_social.gd")
		if ns != null and ns.can_instantiate():
			social = ns.new()
			social.name = "NpcSocial"
			add_child(social)
			social.setup(hub, self)
		else:
			push_error("V2.2: npc_social.gd 를 불러오지 못했습니다.")
	if Flags.V22_WORLD:
		var ws = load("res://scripts/v22/v22_world.gd")
		if ws != null and ws.can_instantiate():
			vworld = ws.new()
			vworld.name = "V22World"
			add_child(vworld)
			vworld.build(world, hub, self)
			await _wait_flag(vworld, 10.0)
		else:
			push_error("V2.2: v22_world.gd 를 불러오지 못했습니다.")
	if Flags.V22_INTERIORS:
		var isr = load("res://scripts/v22/v22_interiors.gd")
		if isr != null and isr.can_instantiate():
			interiors = isr.new()
			interiors.name = "V22Interiors"
			add_child(interiors)
			interiors.build(hub, self)
			await _wait_flag(interiors, 6.0)
		else:
			push_error("V2.2: v22_interiors.gd 를 불러오지 못했습니다.")
	if Flags.V23_LEADER and Flags.V22_WORLD and Flags.V22_INTERIORS:
		var ld = load("res://scripts/v23/v23_leader.gd")
		if ld != null and ld.can_instantiate():
			v23 = ld.new()
			v23.name = "V23Leader"
			add_child(v23)
			v23.build(hub, self)
			await _wait_flag(v23, 8.0)
		else:
			push_error("V2.3: v23_leader.gd 를 불러오지 못했습니다.")


## 대상의 done 값이 true 가 되거나 시간이 지날 때까지 기다림 (모듈 오류로 멈추는 것을 방지)
func _wait_flag(target, seconds: float, prop: String = "done") -> void:
	var t0: int = Time.get_ticks_msec()
	while not bool(target.get(prop)) and float(Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame
	if not bool(target.get(prop)):
		push_warning("V2.2: 모듈 하나가 제한 시간 안에 끝나지 않아 건너뜁니다.")


func build_systems(world_ref: Node3D, hub_ref) -> void:
	world = world_ref
	hub = hub_ref
	if vworld != null:
		vworld.spawn_npcs()
		await _wait_flag(vworld, 8.0, "npcs_done")
	if social != null:
		social.augment_all()
	if Flags.V22_AUDIO:
		var au = load("res://scripts/v22/v22_audio.gd")
		if au != null and au.can_instantiate():
			audio = au.new()
			audio.name = "V22Audio"
			add_child(audio)
			audio.setup(hub)
	if Flags.ENABLE_V3 and Flags.V23_LEADER and v23 != null:
		var v3s = load("res://scripts/v3/v3_manager.gd")
		if v3s != null and v3s.can_instantiate():
			v3 = v3s.new()
			v3.name = "V3Manager"
			add_child(v3)
			v3.build_all(hub, self)
		else:
			push_warning("V3.0: v3_manager.gd 를 불러오지 못했습니다. V3.0 기능 없이 계속합니다.")
	if Flags.V23_SELFTEST:
		var stc = load("res://scripts/v23/v23_selftest.gd")
		if stc != null and stc.can_instantiate():
			selftest = stc.new()
			selftest.name = "V23SelfTest"
			add_child(selftest)
			selftest.setup(hub, self)
		else:
			push_warning("V2.3: 자체 점검 모듈을 불러오지 못했습니다.")
	if hub.hud != null:
		hub.hud.v22_ref = self
		hub.hud.map_span = VData.MAP_LIMIT * 2.0 + 20.0
	if hub.player != null:
		_last_safe_out = Vector3(hub.player.global_position.x, 0.1, hub.player.global_position.z)
	_ready_done = true
	print("[PYONGYANG] V2.2 준비 완료 (통행증 %s, 상호작용 %s, 지역 %d, 소리 %s)." % [
		"켬" if pass_sys != null else "꺼짐", "켬" if social != null else "꺼짐",
		vworld.regions.size() if vworld != null else 0, "켬" if audio != null else "꺼짐"])


# ================================================================ 안전 착지 (실내에서 나올 때 추락 방지)

## 바깥(y<100)으로 옮길 때, 그 자리의 지면을 찾아 정확히 내려놓음.
## 막힌 자리면 가까운 빈 자리로 비키고, 지면이 아예 없으면 보이지 않는 받침판을 깔아 줌.
func safe_outdoor_pos(pos: Vector3) -> Vector3:
	if hub == null or hub.player == null or not Flags.V22_SAFE_EXIT:
		return pos
	var w3d: World3D = hub.player.get_world_3d()
	if w3d == null:
		return pos
	var out: Vector3 = Vector3(pos.x, maxf(pos.y, 0.0), pos.z)
	if not Placement.is_free_capsule(w3d, Vector3(out.x, 0.0, out.z), 0.4, 1.8):
		out = Placement.find_free_capsule(w3d, Vector3(out.x, 0.0, out.z), 0.4, 1.8)
	var space: PhysicsDirectSpaceState3D = w3d.direct_space_state
	var q = PhysicsRayQueryParameters3D.create(Vector3(out.x, maxf(3.0, out.y + 2.0), out.z), Vector3(out.x, -6.0, out.z), 1)
	q.exclude = [hub.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		out.y = 0.1
		_ensure_pad(out)
	else:
		var hp: Vector3 = hit["position"]
		out.y = hp.y + 0.1
	return out


## 지면이 없는 곳에 내려야 할 때를 위한 보이지 않는 받침판 (바닥이 있으면 쓰이지 않음)
func _ensure_pad(at: Vector3) -> void:
	if _pad == null or not is_instance_valid(_pad):
		_pad = StaticBody3D.new()
		_pad.name = "V22SafetyPad"
		var cs = CollisionShape3D.new()
		var shp = BoxShape3D.new()
		shp.size = Vector3(8.0, 0.4, 8.0)
		cs.shape = shp
		_pad.add_child(cs)
		_pad.collision_layer = 1
		_pad.collision_mask = 0
		add_child(_pad)
	_pad.global_position = Vector3(at.x, -0.22, at.z)
	push_warning("V2.2: %s 아래에서 지면을 찾지 못해 받침판을 깔았습니다." % str(at))


func after_teleport() -> void:
	_land_t = 2.5
	_safe_t = 0.0
	if hub != null and hub.player != null:
		var p: Vector3 = hub.player.global_position
		if p.y < 100.0:
			_last_safe_out = p
		else:
			_last_safe_in = p


func _physics_process(delta: float) -> void:
	if hub == null or hub.player == null or not _ready_done:
		return
	var pl = hub.player
	var pos: Vector3 = pl.global_position
	if _land_t > 0.0:
		_land_t -= delta
		# 착지 감시: 공중에서 빠르게 떨어지면 아래 지면으로 다시 내려놓음
		if pos.y < 100.0 and pos.y > 1.8 and pl.velocity.y < -6.0 and not pl.is_on_floor():
			var fixed: Vector3 = safe_outdoor_pos(Vector3(pos.x, 0.0, pos.z))
			if fixed.y < pos.y - 1.0:
				pl.global_position = fixed
				pl.velocity = Vector3.ZERO
				fall_recoveries += 1
	# 낙하 복구: 세계 바닥 아래로 떨어지거나 실내 바닥 아래로 빠졌을 때
	var fell_out: bool = pos.y < -3.0 and pos.y > -19.0
	var fell_in: bool = pos.y > 100.0 and pos.y < 292.0
	if fell_out or fell_in:
		var target: Vector3 = _last_safe_out
		if fell_in and _last_safe_in != Vector3.ZERO:
			target = _last_safe_in
		pl.global_position = target + Vector3(0.0, 0.3, 0.0)
		pl.velocity = Vector3.ZERO
		fall_recoveries += 1
		hub.toast("떨어진 것을 감지해 안전한 곳으로 되돌렸다.")
		return
	_safe_t += delta
	if _safe_t >= 0.5:
		_safe_t = 0.0
		if hub.mode == 0 and pl.is_on_floor():
			if pos.y < 100.0 and pos.y > -1.0 and absf(pos.x) < 400.0 and absf(pos.z) < 400.0:
				_last_safe_out = pos
			elif pos.y > 296.0:
				_last_safe_in = pos


# ================================================================ 매 프레임 (가벼운 주기 작업)

func _process(delta: float) -> void:
	if hub == null or hub.player == null or not _ready_done:
		return
	_track_day()
	_tick1 += delta
	_tick_cull += delta
	_tick_obj += delta
	if _tick_cull >= 0.5:
		_tick_cull = 0.0
		if vworld != null:
			vworld.cull(hub.player.global_position, hub.mode != 4)
	if _tick1 >= 1.0:
		_tick1 = 0.0
		_progress()
		_refresh_marks()
		if pass_sys != null:
			pass_sys.expire_check()
	if _tick_obj >= 0.5:
		_tick_obj = 0.0
		_update_objective()
		_update_status()
	if _siren_t > 0.0:
		_siren_t -= delta
	if hub.mode == 0:
		_event_t -= delta
		if _event_t <= 0.0:
			_event_t = _rng.randf_range(80.0, 170.0)
			_random_event()


func _track_day() -> void:
	var m: float = hub.clock.minutes
	if _last_minutes >= 0.0 and m < _last_minutes - 600.0:
		day += 1
	_last_minutes = m


## 게임 속 절대 분 (날짜 * 1440 + 오늘 시각)
func abs_minutes() -> float:
	return float(day) * 1440.0 + hub.clock.minutes


# ================================================================ 임무 자동 진행 / 탐험 보상

func _progress() -> void:
	var g = hub.game
	if g == null:
		return
	if Flags.V22_QUESTS:
		if g.quest_state("q_v22_pass") == "inactive":
			g.start_quest("q_v22_pass")
		if not g.get_flag("v22_start_money"):
			g.set_flag("v22_start_money", true)
			g.add_item("won", 60)
			hub.toast("주머니에 남은 돈 60원이 있다.")
		if g.get_flag("intel_market") and g.quest_state("q_v22_market") == "inactive":
			if g.start_quest("q_v22_market"):
				hub.toast("새 임무: " + g.quest_title("q_v22_market"))
		if g.quest_state("q_v22_market") == "active" and int(g.inventory.get("won", 0)) >= 100:
			hub._complete_quest("q_v22_market")
		if g.quest_state("q_v22_slum") == "active" and g.get_flag("slum_fed_bong") and g.get_flag("slum_fed_cho") and g.get_flag("slum_fed_old"):
			hub._complete_quest("q_v22_slum")
		if g.quest_state("q_v22_pass") == "active":
			var st: int = g.quest_step("q_v22_pass")
			if st == 3 and (g.has_item("doc_shipping") or g.has_item("doc_roster")):
				hub.apply_effects([{"op": "quest_step", "id": "q_v22_pass", "step": 4}])
			if st >= 9 and g.get_flag("v22_siren") and hub.player.global_position.y < 100.0 and hub.player.global_position.z > -240.0:
				hub._complete_quest("q_v22_pass")
				g.set_flag("v22_act1_done", true)
				hub.game.add_item("won", 200)
				hub.toast("탈출 성공! 1막 완료 (+200원)")
				hub.toast("도시의 다른 곳에서도 일이 벌어지고 있다. 장마당·폐건물·강변·동쪽 외곽을 더 둘러보자.")
	# 탐험 보상: 새 지역을 처음 발견할 때마다 작은 보상
	for id in g.discovered.keys():
		var ks: String = str(id)
		if ks.begins_with("v22_") and not _known.has(ks):
			_known[ks] = true
			if _ready_done and _known.size() > 1:
				var reward: int = 8 + _rng.randi_range(0, 8)
				if social != null:
					social.give_won(reward)
				hub.toast("탐험 보상: 새 장소를 발견했다")
				if _known.size() == 8:
					hub.game.add_item("gift_sweets", 1)
					hub.toast("탐험 보상: 사탕을 얻었다")


## 주운 물건의 표식을 숨김 (저장 후 불러오기와 같은 칸에 여러 개일 때도 맞게)
func _refresh_marks() -> void:
	for k in hub.game.flags.keys():
		var ks: String = str(k)
		if (ks.begins_with("pk_v22_") or ks.begins_with("pk_v23_")) and hub.game.get_flag(ks):
			for m in get_tree().get_nodes_in_group("pk_mark_" + ks.substr(3)):
				if m.visible:
					m.visible = false


# ================================================================ 효과 / 대화

## 허브의 apply_effects 가 모르는 연산을 이쪽으로 넘김. 처리했으면 true
func on_effect(op: String, e: Dictionary) -> bool:
	if op.begins_with("v23_"):
		if v23 != null:
			return bool(v23.on_effect(op, e))
		return false
	if op.begins_with("v3_"):
		if v3 != null:
			return bool(v3.on_effect(op, e))
		return false
	if not op.begins_with("v22_"):
		return false
	var npc = hub.get("_npc")
	match op:
		"v22_intel":
			var key: String = str(e.get("key", ""))
			if key != "":
				give_intel(key)
		"v22_grant_pass":
			if pass_sys != null:
				pass_sys.grant(str(e.get("id", "pass_temp")))
		"v22_gate":
			if pass_sys != null:
				pass_sys.handle_gate(e)
			else:
				last_text = "(검문 시스템이 꺼져 있다.)"
		"v22_act":
			if social != null:
				social.act(str(e.get("kind", "")), npc)
		"v22_buy":
			if social != null:
				social.buy(str(e.get("item", "")), npc)
		"v22_sell":
			if social != null:
				social.sell(npc)
		"v22_forge":
			if pass_sys != null and pass_sys.forge(int(e.get("cost", 40))):
				last_text = "(솜씨 좋게 도장을 찍어 낸다) 됐다. 완성도는 운에 달렸지. 걸리면 내 이름은 대지 마라."
			else:
				last_text = "재료나 돈이 모자란다. 용지, 잉크, 40원을 가져와라."
		"v22_vault":
			_try_vault(str(e.get("code", "")))
		"v22_siren":
			start_siren()
		_:
			return false
	return true


func give_intel(key: String) -> void:
	var flag: String = "intel_" + key
	if hub.game.get_flag(flag):
		return
	hub.game.set_flag(flag, true)
	var text: String = str(VData.INTEL.get(key, ""))
	hub.toast("정보 획득: " + text)


func _try_vault(code: String) -> void:
	if hub.game.get_flag("v22_vault_open"):
		last_text = "문은 이미 열려 있다."
		return
	if code == "417":
		hub.game.set_flag("v22_vault_open", true)
		hub._reveal("v22_vault")
		last_text = "찰칵. 안쪽에서 묵직한 빗장이 풀리는 소리가 난다. 금고 문이 열렸다."
		hub.toast("금고가 열렸다")
		hub.apply_effects([{"op": "quest_step", "id": "q_v22_pass", "step": 3, "if": {"quest": "q_v22_pass", "state": "active"}}])
		return
	_vault_fail += 1
	last_text = "삑— 틀렸다. 숫자판에 붉은 불이 들어온다."
	if _vault_fail % 3 == 0:
		last_text = "삑삑삑— 경보음이 낮게 울렸다. 위쪽 통제구역까지 들렸을지도 모른다."
		var v1 = hub.get("v1")
		if v1 != null and v1.alert != null:
			v1.alert.report("trespass", hub.player.global_position, 0.8, null)


func dynamic_text(kind: String, _npc) -> String:
	if kind.begins_with("v22_v3_") and v3 != null:
		return str(v3.dynamic_text(kind, _npc))
	match kind:
		"v22_keypad_hint":
			var lines: Array = []
			lines.append("첫째 숫자: " + ("4 (낡은 일기 쪽지)" if hub.game.has_item("clue_a") else "아직 단서가 없다 (폐건물?)"))
			lines.append("둘째 숫자: " + ("1 (낚시 수첩)" if hub.game.has_item("clue_b") else "아직 단서가 없다 (강변?)"))
			lines.append("셋째 숫자: " + ("7 (장마당 장부)" if hub.game.has_item("clue_c") else "아직 단서가 없다 (장마당?)"))
			return "\n".join(lines)
		"v22_result", "v22_gate":
			return last_text
	return last_text


func role_label(npc) -> String:
	if social != null and npc != null:
		return str(social.role_label(npc))
	return str(npc.role)


# ================================================================ 사이렌 / 체포 / 월드 상태

func start_siren() -> void:
	if hub.game.get_flag("v22_siren"):
		return
	hub.game.set_flag("v22_siren", true)
	_siren_t = 90.0
	hub.toast("비상 사이렌! 사령관실의 비상 해치 또는 사령부 뒤 배수구로 도망쳐라.")
	if audio != null:
		audio.siren(30.0)
	var v1 = hub.get("v1")
	if v1 != null and v1.alert != null:
		v1.alert.report("attack", hub.player.global_position, 1.5, null)
		v1.alert.heat = maxf(v1.alert.heat, 85.0)


func on_caught() -> void:
	if pass_sys != null:
		pass_sys.on_caught()
	if hub.game.get_flag("v22_siren"):
		# 붙잡혀도 사이렌 상태는 풀림
		hub.game.set_flag("v22_siren", false)
		_siren_t = 0.0


func apply_world_flags() -> void:
	if hub.game.get_flag("v22_vault_open"):
		hub._reveal("v22_vault")
	if v23 != null:
		v23.apply_world_flags()
	if v3 != null:
		v3.apply_world_flags()
	_refresh_marks()
	for k in hub.game.discovered.keys():
		var ks: String = str(k)
		if ks.begins_with("v22_"):
			_known[ks] = true


# ================================================================ 랜덤 이벤트

func _random_event() -> void:
	if hub.player.global_position.y > 100.0:
		return
	var in_zone: bool = hub.player.global_position.z < -250.0
	var pick: String = str(VData.EVENTS[_rng.randi() % VData.EVENTS.size()])
	if in_zone and _rng.randf() < 0.45:
		pick = "inspect"
	events_seen += 1
	match pick:
		"wallet":
			var amt: int = _rng.randi_range(10, 35)
			if social != null:
				social.give_won(amt)
			hub.toast("길바닥에 떨어진 지갑을 주웠다.")
		"inspect":
			if pass_sys != null and (in_zone or hub.game.has_item("pass_forged")):
				pass_sys.random_inspection()
		"whisper":
			var keys: Array = []
			for k in VData.INTEL.keys():
				if not hub.game.get_flag("intel_" + str(k)):
					keys.append(str(k))
			if keys.size() > 0:
				var kk: String = str(keys[_rng.randi() % keys.size()])
				hub.toast("지나가는 사람들의 소문: " + str(VData.INTEL[kk]))
		"ration":
			hub.toast("[방송] 동쪽 배급소에서 오늘의 배급이 시작되었습니다.")
			if audio != null:
				audio.chime()
		"patrol_alert":
			var v1 = hub.get("v1")
			if v1 != null and v1.alert != null and in_zone:
				v1.alert.heat = minf(100.0, v1.alert.heat + 6.0)
				hub.toast("순찰이 강화되었다는 소문이 돈다.")
		"radio_tip":
			var line: String = str(VData.PA_LINES[_rng.randi() % VData.PA_LINES.size()])
			hub.toast(line)
			if audio != null:
				audio.chime()


# ================================================================ 목표 안내 / 상태 표시

func _npc_pos(npc_id: String) -> Variant:
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n) and str(n.npc_id) == npc_id and n.global_position.y < 100.0:
			return n.global_position
	return null


func _poi_pos(key: String) -> Variant:
	if vworld != null and vworld.poi_pos.has(key):
		return vworld.poi_pos[key]
	return null


func _update_objective() -> void:
	_obj_has = false
	_obj_text = ""
	var g = hub.game
	if g.quest_state("q_v22_pass") != "active":
		var o: Dictionary = {}
		if v23 != null:
			o = v23.objective()
		if o.is_empty() and v3 != null:
			o = v3.objective()
		if not o.is_empty():
			_obj_text = str(o["text"])
			if o.has("pos"):
				_obj_target = o["pos"]
				_obj_has = true
		return
	var st: int = g.quest_step("q_v22_pass")
	var title: String = g.quest_title("q_v22_pass")
	var step_text: String = g.quest_step_text("q_v22_pass")
	var tgt: Variant = null
	match st:
		0:
			tgt = _npc_pos("lee_sunhui")
		1:
			tgt = _npc_pos("han_okbun")
		2:
			tgt = _poi_pos("manhole")
		3, 4:
			if st == 4:
				tgt = _npc_pos("supply_oh")
			else:
				tgt = _poi_pos("manhole")
		5:
			tgt = _npc_pos("officer_ryu")
			if tgt == null:
				tgt = _poi_pos("officer_office")
		6:
			tgt = _npc_pos("officer_ryu")
		7:
			tgt = _poi_pos("base")
		8:
			tgt = _poi_pos("hq")
		9:
			tgt = _poi_pos("zone_drain")
	var line: String = "%s: %s" % [title, step_text]
	if hub.player.global_position.y > 100.0:
		_obj_text = line
		return
	if tgt != null:
		var tp: Vector3 = tgt
		_obj_target = tp
		_obj_has = true
		var d: Vector3 = tp - hub.player.global_position
		line += " (%s %dm)" % [_compass(d), int(Vector2(d.x, d.z).length())]
	_obj_text = line


func _compass(d: Vector3) -> String:
	# 북쪽은 -z, 동쪽은 +x
	var ang: float = rad_to_deg(atan2(d.x, -d.z))
	var names: Array = ["북", "북동", "동", "남동", "남", "남서", "서", "북서"]
	var idx: int = int(round(fposmod(ang, 360.0) / 45.0)) % 8
	return str(names[idx])


func objective_text() -> String:
	return _obj_text


func _update_status() -> void:
	var parts: Array = []
	parts.append("소지금 %d원" % int(hub.game.inventory.get("won", 0)))
	if pass_sys != null:
		parts.append(pass_sys.summary())
	var v1 = hub.get("v1")
	if v1 != null and v1.alert != null:
		parts.append("경계 " + str(v1.alert.level_name()))
	_status_text = " · ".join(parts)


func status_line() -> String:
	return _status_text


## 검문소 위험도 글자
func gate_risk(gid: String) -> String:
	var score: float = 0.0
	var v1 = hub.get("v1")
	if v1 != null and v1.alert != null:
		score += float(v1.alert.level) * 0.6
	if hub.clock.is_night():
		score -= 0.4
	if hub.game.has_item("pass_forged") and not (hub.game.has_item("pass_general") or hub.game.has_item("pass_special") or hub.game.has_item("pass_temp")):
		score += 0.8
	if pass_sys != null and pass_sys.gates.has(gid) and int(pass_sys.gates[gid]["level"]) >= 2:
		score += 0.8
	if score < 0.8:
		return "낮음"
	if score < 1.8:
		return "보통"
	return "높음"


## 지도에 덧그림: 검문소, 목표, 새 지역 이름
func draw_map_overlay(canvas, font: Font, mr: Rect2, c: Vector2, sc: float) -> void:
	if pass_sys != null:
		for gid in pass_sys.gates.keys():
			if not hub.game.discovered.has("v22_gate_" + str(gid)):
				continue
			var gp: Vector3 = pass_sys.gates[gid]["pos"]
			var pt = Vector2(c.x + gp.x * sc, c.y + gp.z * sc)
			if mr.has_point(pt):
				canvas.draw_rect(Rect2(pt - Vector2(7, 4), Vector2(14, 8)), Color(0.9, 0.2, 0.2), true)
				canvas.draw_string(font, pt + Vector2(10, -4), "%s (위험 %s)" % [str(pass_sys.gates[gid]["name"]), gate_risk(str(gid))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 0.8, 0.8, 0.95))
	if _obj_has:
		var tp: Vector3 = _obj_target
		var q = Vector2(c.x + tp.x * sc, c.y + tp.z * sc)
		q.x = clampf(q.x, mr.position.x + 8.0, mr.position.x + mr.size.x - 8.0)
		q.y = clampf(q.y, mr.position.y + 8.0, mr.position.y + mr.size.y - 8.0)
		canvas.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -10), q + Vector2(10, 0), q + Vector2(0, 10), q + Vector2(-10, 0)]), Color(1.0, 0.95, 0.2))
		canvas.draw_polyline(PackedVector2Array([q + Vector2(0, -10), q + Vector2(10, 0), q + Vector2(0, 10), q + Vector2(-10, 0), q + Vector2(0, -10)]), Color(0, 0, 0, 0.85), 2.0)


# ================================================================ 저장 / 불러오기

func to_dict() -> Dictionary:
	var d: Dictionary = {"day": day, "vault_fail": _vault_fail, "known": _known.keys(), "fall_recoveries": fall_recoveries}
	if pass_sys != null:
		d["pass"] = pass_sys.to_dict()
	if social != null:
		d["social"] = social.to_dict()
	if v3 != null:
		d["v3"] = v3.to_dict()
	return d


func from_dict(d: Dictionary) -> void:
	if d.get("day") is float or d.get("day") is int:
		day = int(d["day"])
	if d.get("vault_fail") is float or d.get("vault_fail") is int:
		_vault_fail = int(d["vault_fail"])
	if d.get("fall_recoveries") is float or d.get("fall_recoveries") is int:
		fall_recoveries = int(d["fall_recoveries"])
	var kn = d.get("known")
	if kn is Array:
		_known = {}
		for k in kn:
			_known[str(k)] = true
	if pass_sys != null and d.get("pass") is Dictionary:
		pass_sys.from_dict(d["pass"])
	if social != null and d.get("social") is Dictionary:
		social.from_dict(d["social"])
	if v3 != null:
		# 저장에 "v3" 칸이 없으면(V2.x 저장) 빈 값으로 불러와 지도자 상태를 초기화
		var d3 = d.get("v3")
		v3.from_dict(d3 if d3 is Dictionary else {})
	_last_minutes = hub.clock.minutes
