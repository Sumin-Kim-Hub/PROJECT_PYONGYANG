extends Node
## V2.2 통행증과 검문소.
##  - 통행증 4종: 일반 / 특별 / 임시(하루) / 위조(성공 확률)
##  - 검문소 2곳: north(통제구역 입구, 레벨 1), base(군사시설 안쪽 문, 레벨 2)
##  - 검문소 경비는 일반 NPC 대화창으로 말을 겁니다. 선택하면 "v22_gate" 효과가 이 모듈로 들어옵니다.
##  - 실패하면 압수 / 경계 상승 / 경비 추적, 체포되면 일부 통행증을 잃습니다.
## (Godot 실행 미검증)

const VData = preload("res://scripts/v22/v22_data.gd")

var hub = null
var mgr = null
## id -> {"level","name","pos","body","arm","open_until","guards"}
var gates: Dictionary = {}
var stats: Dictionary = {"checks": 0, "passed": 0, "caught": 0, "confiscated": 0}
## 위조 통행증의 완성도 (0~1)
var forged_q: float = 0.55
## 임시 통행증이 끝나는 시각 (게임 속 절대 분). -1 이면 없음
var temp_expire: float = -1.0

var _rng = RandomNumberGenerator.new()
var _tick: float = 0.0


func setup(p_hub, p_mgr) -> void:
	hub = p_hub
	mgr = p_mgr
	_rng.randomize()


# ---------------------------------------------------------------- 검문소 등록 / 대화 만들기

func register_gate(id: String, level: int, gate_name: String, pos: Vector3, body, arm) -> void:
	gates[id] = {"level": level, "name": gate_name, "pos": pos, "body": body, "arm": arm, "open_until": -1.0, "guards": []}


func add_guard(id: String, npc) -> void:
	if gates.has(id):
		gates[id]["guards"].append(npc)


## 경비가 걸 대화 그래프. gate_id 는 register_gate 의 id
func make_dialogue(gate_id: String, level: int) -> Dictionary:
	var ask: String = "정지. 여기는 통제구역입니다. 통행증을 제시하십시오."
	if level >= 2:
		ask = "군사시설 구역이다. 특별 통행증이 아니면 한 발짝도 들어올 수 없다. 제시하라."
	var d: Dictionary = {}
	d["start"] = {
		"text": ask,
		"variants": {"밤": "야간 통행이다. 통행증 확인이 더 엄격하다. 제시하십시오."},
		"choices": [
			{"label": "통행증 제시", "next": "g_show"},
			{"label": "슬쩍 건넨다", "next": "g_bribe", "if": {"item_min": ["won", 30]}},
			{"label": "돌아간다", "next": ""},
		],
	}
	d["g_show"] = {
		"text": "어느 통행증입니까?",
		"choices": [
			{"label": "일반", "next": "g_use_pass_general", "if": {"item": "pass_general"}},
			{"label": "특별", "next": "g_use_pass_special", "if": {"item": "pass_special"}},
			{"label": "임시", "next": "g_use_pass_temp", "if": {"item": "pass_temp"}},
			{"label": "위조", "next": "g_use_pass_forged", "if": {"item": "pass_forged"}},
			{"label": "없습니다", "next": "g_use_none"},
		],
	}
	for pid in ["pass_general", "pass_special", "pass_temp", "pass_forged", "none"]:
		d["g_use_" + pid] = {
			"dyn": "v22_gate", "text": "...",
			"effects": [{"op": "v22_gate", "gate": gate_id, "pass": pid}],
			"choices": [{"label": "알겠습니다", "next": ""}],
		}
	d["g_bribe"] = {
		"text": "(경비가 주변을 한 번 살핀다) …얼마입니까?",
		"choices": [
			{"label": "30원", "next": "g_bribe_30", "if": {"item_min": ["won", 30]}},
			{"label": "80원", "next": "g_bribe_80", "if": {"item_min": ["won", 80]}},
			{"label": "그만둔다", "next": ""},
		],
	}
	for amt in [30, 80]:
		d["g_bribe_" + str(amt)] = {
			"dyn": "v22_gate", "text": "...",
			"effects": [{"op": "v22_gate", "gate": gate_id, "pass": "bribe", "amount": amt}],
			"choices": [{"label": "알겠습니다", "next": ""}],
		}
	return d


# ---------------------------------------------------------------- 통행증 상태

func now_abs() -> float:
	if mgr != null:
		return float(mgr.abs_minutes())
	return 0.0


func grant(pass_id: String) -> void:
	hub.game.add_item(pass_id, 1)
	if pass_id == "pass_temp":
		temp_expire = now_abs() + VData.TEMP_PASS_MINUTES
	hub.toast("획득: " + VData.item_label(pass_id))


func _remove(pass_id: String) -> void:
	if hub.game.has_item(pass_id):
		hub.game.remove_item(pass_id, hub.game.inventory.get(pass_id, 1))
	if pass_id == "pass_temp":
		temp_expire = -1.0


## 임시 통행증이 기한을 넘기면 지움. 지웠으면 true
func expire_check() -> bool:
	if hub.game.has_item("pass_temp") and temp_expire >= 0.0 and now_abs() > temp_expire:
		_remove("pass_temp")
		hub.toast("임시 통행증의 기한이 지나 효력을 잃었다.")
		return true
	return false


func temp_left_minutes() -> int:
	if hub.game.has_item("pass_temp") and temp_expire >= 0.0:
		return maxi(0, int(temp_expire - now_abs()))
	return 0


## 화면에 보일 현재 통행증 요약
func summary() -> String:
	var parts: Array = []
	if hub.game.has_item("pass_special"):
		parts.append("특별")
	if hub.game.has_item("pass_general"):
		parts.append("일반")
	if hub.game.has_item("pass_temp"):
		var m: int = temp_left_minutes()
		parts.append("임시(%d시간 남음)" % int(ceil(float(m) / 60.0)))
	if hub.game.has_item("pass_forged"):
		parts.append("위조")
	if parts.is_empty():
		return "통행증 없음"
	return "통행증: " + " · ".join(parts)


# ---------------------------------------------------------------- 검문 처리

## 대화 효과 {"op":"v22_gate","gate":id,"pass":pid,"amount":n} 처리. 결과 문장은 mgr.last_text 에 담김
func handle_gate(e: Dictionary) -> void:
	var gid: String = str(e.get("gate", ""))
	var pid: String = str(e.get("pass", "none"))
	if not gates.has(gid):
		mgr.last_text = "(검문소 정보를 찾지 못했다.)"
		return
	var g: Dictionary = gates[gid]
	var level: int = int(g["level"])
	stats["checks"] = int(stats["checks"]) + 1
	expire_check()
	if pid == "bribe":
		mgr.last_text = _bribe(gid, g, int(e.get("amount", 30)))
		return
	var night: bool = hub.clock.is_night()
	var alert_lv: int = _alert_level()
	match pid:
		"pass_general":
			if not hub.game.has_item(pid):
				mgr.last_text = "…가지고 있지 않잖습니까."
			elif level >= 2:
				mgr.last_text = "일반 통행증으로는 안 된다. 특별 통행증을 가져오라."
			else:
				mgr.last_text = _allow(gid, g, "확인했습니다. 통과하십시오. 기간 제한은 없는 증입니다.")
		"pass_special":
			if not hub.game.has_item(pid):
				mgr.last_text = "…가지고 있지 않잖습니까."
			else:
				mgr.last_text = _allow(gid, g, "특별 통행증… 확인했습니다. 통과하십시오.")
		"pass_temp":
			if not hub.game.has_item(pid):
				mgr.last_text = "…가지고 있지 않잖습니까."
			elif temp_expire >= 0.0 and now_abs() > temp_expire:
				_remove(pid)
				mgr.last_text = "기한이 지난 증입니다. 압수하겠습니다."
				_confiscate_note()
			elif level >= 2:
				mgr.last_text = "임시 통행증으로는 이 안으로 못 들어간다."
			else:
				mgr.last_text = _allow(gid, g, "임시 통행증이군요. 오늘 안에는 자유롭게 오가십시오.")
		"pass_forged":
			if not hub.game.has_item(pid):
				mgr.last_text = "…가지고 있지 않잖습니까."
			else:
				var chance: float = forged_q * (0.9 if level <= 1 else 0.55)
				chance -= 0.12 * float(maxi(alert_lv - 1, 0))
				if night:
					chance += 0.08
				chance += _guard_laxness(g) * 0.12
				chance = clampf(chance, 0.05, 0.92)
				if _rng.randf() < chance:
					mgr.last_text = _allow(gid, g, "…흠. 도장이 조금 흐린 것 같지만 통과하십시오.")
					hub.game.set_flag("forged_used_ok", true)
				else:
					_remove(pid)
					stats["caught"] = int(stats["caught"]) + 1
					stats["confiscated"] = int(stats["confiscated"]) + 1
					hub.game.set_flag("forged_caught", true)
					_punish(g, 1.4)
					mgr.last_text = "이 도장은 가짜다! 증을 압수한다. 거기 서라!"
		_:
			mgr.last_text = "통행증이 없다면 지나갈 수 없습니다. 돌아가십시오."
			hub.toast("통행증이 필요하다.")


func _allow(gid: String, g: Dictionary, line: String) -> String:
	stats["passed"] = int(stats["passed"]) + 1
	open_gate(gid, 14.0)
	hub.game.set_flag("passed_" + gid, true)
	var step: int = 5 if int(g["level"]) <= 1 else 7
	var effs: Array = []
	# 주 임무 단계는 검문소 A(north)와 문 B(base)에서만 올림 (V2.3 의 중앙 청사 검문은 제외)
	if gid == "north" or gid == "base":
		effs.append({"op": "quest_step", "id": "q_v22_pass", "step": step, "if": {"quest": "q_v22_pass", "state": "active"}})
	effs.append({"op": "toast", "text": "차단기가 올라간다: " + str(g["name"])})
	hub.apply_effects(effs)
	return line


func _bribe(gid: String, g: Dictionary, amount: int) -> String:
	if int(hub.game.inventory.get("won", 0)) < amount:
		return "…돈이 모자라는군요."
	var level: int = int(g["level"])
	var greed: float = 0.5
	var guards: Array = g["guards"]
	var gnpc = null
	for n in guards:
		if is_instance_valid(n):
			gnpc = n
			break
	if gnpc != null and mgr.social != null:
		greed = float(mgr.social.profile(gnpc)["greed"])
	var chance: float = 0.20 + greed * 0.35 + float(amount - 30) / 140.0
	if level >= 2:
		chance -= 0.25
	chance -= 0.1 * float(maxi(_alert_level() - 1, 0))
	if hub.clock.is_night():
		chance += 0.08
	chance = clampf(chance, 0.05, 0.85)
	hub.game.remove_item("won", amount)
	if _rng.randf() < chance:
		hub.game.set_flag("bribed_" + gid, true)
		_heat(g, 0.4)
		return _allow(gid, g, "(돈을 주머니에 넣는다) …오늘은 못 본 걸로 하죠. 빨리 지나가십시오.")
	stats["caught"] = int(stats["caught"]) + 1
	_punish(g, 1.1)
	return "뇌물이라고? 이 자를 붙잡아라!"


func _guard_laxness(g: Dictionary) -> float:
	var guards: Array = g["guards"]
	for n in guards:
		if is_instance_valid(n) and mgr.social != null:
			return 1.0 - float(mgr.social.profile(n)["authority"])
	return 0.3


func _alert_level() -> int:
	var v1 = hub.get("v1")
	if v1 != null and v1.alert != null:
		return int(v1.alert.level)
	return 0


func _heat(g: Dictionary, severity: float) -> void:
	var v1 = hub.get("v1")
	if v1 != null and v1.alert != null:
		v1.alert.report("trespass", g["pos"], severity, null)


## 실패의 대가: 경계 상승 + 경비 추적
func _punish(g: Dictionary, severity: float) -> void:
	_heat(g, severity)
	for n in g["guards"]:
		if is_instance_valid(n) and n.has_method("chase"):
			n.chase(hub.player, 22.0)
	hub.toast("검문소 경비가 쫓아온다!")


func _confiscate_note() -> void:
	stats["confiscated"] = int(stats["confiscated"]) + 1


# ---------------------------------------------------------------- 차단기

func open_gate(gid: String, seconds: float) -> void:
	if not gates.has(gid):
		return
	var g: Dictionary = gates[gid]
	g["open_until"] = Time.get_ticks_msec() / 1000.0 + seconds
	_set_barrier(g, true)


func _set_barrier(g: Dictionary, open: bool) -> void:
	var body = g["body"]
	if body != null and is_instance_valid(body):
		body.collision_layer = 0 if open else 1
	var arm = g["arm"]
	if arm != null and is_instance_valid(arm):
		arm.rotation.z = deg_to_rad(80.0) if open else 0.0


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.4:
		return
	_tick = 0.0
	if hub == null or hub.player == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	for id in gates.keys():
		var g: Dictionary = gates[id]
		if float(g["open_until"]) < 0.0:
			continue
		if now < float(g["open_until"]):
			continue
		# 플레이어가 차단기 바로 옆에 서 있으면 닫지 않음
		var gp: Vector3 = g["pos"]
		var pp: Vector3 = hub.player.global_position
		if Vector2(gp.x - pp.x, gp.z - pp.z).length() < 3.2:
			g["open_until"] = now + 1.5
			continue
		g["open_until"] = -1.0
		_set_barrier(g, false)


# ---------------------------------------------------------------- 이벤트 / 체포

## 불시 신분 검사 (랜덤 이벤트)
func random_inspection() -> void:
	expire_check()
	if hub.game.has_item("pass_forged") and _rng.randf() < forged_q_detect():
		_remove("pass_forged")
		stats["confiscated"] = int(stats["confiscated"]) + 1
		hub.toast("불시 검사: 위조 통행증이 발각되어 압수되었다!")
		var v1 = hub.get("v1")
		if v1 != null and v1.alert != null:
			v1.alert.report("trespass", hub.player.global_position, 1.0, null)
	elif hub.game.has_item("pass_general") or hub.game.has_item("pass_special") or hub.game.has_item("pass_temp"):
		hub.toast("불시 검사: 통행증을 확인받고 무사히 지나갔다.")
	else:
		hub.toast("불시 검사: 통행증은 없었지만 이번에는 그냥 지나갔다.")


func forged_q_detect() -> float:
	return clampf(0.55 - forged_q * 0.4, 0.15, 0.45)


## 체포되었을 때 일부 통행증을 잃음
func on_caught() -> void:
	var lost: Array = []
	if hub.game.has_item("pass_forged"):
		_remove("pass_forged")
		lost.append("위조")
	if hub.game.has_item("pass_temp"):
		_remove("pass_temp")
		lost.append("임시")
	if hub.game.has_item("pass_general") and _rng.randf() < 0.4:
		_remove("pass_general")
		lost.append("일반")
	if hub.game.has_item("pass_special") and _rng.randf() < 0.25:
		_remove("pass_special")
		lost.append("특별")
	if not lost.is_empty():
		stats["confiscated"] = int(stats["confiscated"]) + lost.size()
		hub.toast("체포 중 통행증을 압수당했다: " + ", ".join(lost))


# ---------------------------------------------------------------- 위조

## 암거래상에게서 위조 통행증을 만듦. 성공하면 true
func forge(cost: int) -> bool:
	var g = hub.game
	if not (g.has_item("forged_blank") and g.has_item("forge_ink")):
		return false
	if int(g.inventory.get("won", 0)) < cost:
		return false
	g.remove_item("won", cost)
	g.remove_item("forged_blank", 1)
	g.remove_item("forge_ink", 1)
	forged_q = 0.55
	if g.has_item("old_stamp"):
		forged_q = 0.78
	g.add_item("pass_forged", 1)
	hub.toast("위조 통행증이 만들어졌다 (완성도 %d%%)" % int(forged_q * 100.0))
	return true


# ---------------------------------------------------------------- 저장

func to_dict() -> Dictionary:
	return {"stats": stats.duplicate(), "forged_q": forged_q, "temp_expire": temp_expire}


func from_dict(d: Dictionary) -> void:
	var st = d.get("stats")
	if st is Dictionary:
		for k in stats.keys():
			if st.has(k) and (st[k] is float or st[k] is int):
				stats[k] = int(st[k])
	var fq = d.get("forged_q")
	if fq is float or fq is int:
		forged_q = clampf(float(fq), 0.0, 1.0)
	var te = d.get("temp_expire")
	if te is float or te is int:
		temp_expire = float(te)
