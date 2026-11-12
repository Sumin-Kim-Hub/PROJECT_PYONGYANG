extends Node
## V3.0 국가 통치 시뮬레이션 (지표, 정산, 정책, 예산 배분, 회의, 목표).
##  - 게임 시간 2시간(실제 약 1분)마다 한 번 "정산"이 일어나 지표가 변한다.
##  - 정책은 시행하면 즉시 효과 + 여러 번의 정산 동안 이어지는 효과를 낸다.
##  - 건설한 건물(v3_build.gd)의 효과와 유지비도 정산에 들어간다.
## 저장은 to_dict / from_dict 로 한다. (Godot 실행 미검증)

const D = preload("res://scripts/v3/v3_data.gd")

signal notice(text: String)

var mgr = null
var hub = null
var build = null           # v3_build.gd (건물 수/유지비 조회용)

var running: bool = false
var ind: Dictionary = {}
var prev: Dictionary = {}
var alloc: Dictionary = {"welfare": 1, "security": 1, "invest": 1}
var loyalty: Dictionary = {}
var active: Dictionary = {}
var cooldown: Dictionary = {}
var goals_done: Dictionary = {}
var tick_count: int = 0
var policy_runs: int = 0
var meetings_held: int = 0
var meeting_day: int = -1
var current_card: Dictionary = {}
var meeting_log: Array = []
var cheer_day: Dictionary = {}
var last_income: float = 0.0
var last_expense: float = 0.0
var last_notes: Array = []

var _acc: float = 0.0
var _last_abs: float = -1.0
var _last_card_id: String = ""


func setup(hub_ref, mgr_ref) -> void:
	hub = hub_ref
	mgr = mgr_ref


func start_new(route: String) -> void:
	var info: Dictionary = D.route_info(route)
	ind = {}
	var base: Dictionary = info["ind"]
	for k in D.IND_KEYS:
		ind[k] = float(base.get(k, 50.0))
	prev = ind.duplicate()
	alloc = {"welfare": 1, "security": 1, "invest": 1}
	loyalty = {}
	var lo: Dictionary = info["loy"]
	for k in lo.keys():
		loyalty[str(k)] = int(lo[k])
	active = {}
	cooldown = {}
	goals_done = {}
	tick_count = 0
	policy_runs = 0
	meetings_held = 0
	meeting_day = -1
	current_card = {}
	meeting_log = []
	cheer_day = {}
	last_income = 0.0
	last_expense = 0.0
	last_notes = []
	_acc = 0.0
	_last_abs = -1.0
	_last_card_id = ""
	running = true


func stop() -> void:
	running = false


func value(k: String) -> float:
	return float(ind.get(k, 0.0))


func _clamp_all() -> void:
	for k in D.IND_KEYS:
		var v: float = float(ind.get(k, 0.0))
		if k == "budget":
			ind[k] = clampf(v, -3000.0, 999999.0)
		else:
			ind[k] = clampf(v, 0.0, 100.0)


## 지표에 변화량을 더한다. 70 을 넘은 지표는 올리기 어려워진다 (100 에 가까울수록 효과가 줄어듦)
func apply_delta(d: Dictionary) -> void:
	for k in D.IND_KEYS:
		if d.has(k):
			var dv: float = float(d[k])
			if k != "budget" and dv > 0.0:
				var cur: float = float(ind.get(k, 0.0))
				if cur > 70.0:
					dv *= clampf((100.0 - cur) / 30.0, 0.15, 1.0)
			ind[k] = float(ind.get(k, 0.0)) + dv
	_clamp_all()


func add_loyalty(pid: String, d: int) -> void:
	loyalty[pid] = clampi(int(loyalty.get(pid, 50)) + d, 0, 100)


func get_loyalty(pid: String) -> int:
	return int(loyalty.get(pid, 50))


# ================================================================ 시간 흐름 → 정산

func _process(delta: float) -> void:
	if not running or mgr == null or hub == null or hub.clock == null:
		return
	var a: float = float(mgr.abs_minutes())
	if _last_abs < 0.0:
		_last_abs = a
		return
	var dm: float = a - _last_abs
	_last_abs = a
	if dm < 0.0:
		return
	_acc += dm
	var guard: int = 0
	while _acc >= D.TICK_GAME_MINUTES and guard < 12:
		_acc -= D.TICK_GAME_MINUTES
		guard += 1
		tick()
	if guard >= 12:
		_acc = 0.0


func current_day_index() -> int:
	if mgr == null:
		return 0
	return int(float(mgr.abs_minutes()) / 1440.0)


## 한 번의 정산
func tick() -> void:
	tick_count += 1
	prev = ind.duplicate()
	last_notes = []
	var bt: Dictionary = {"upkeep": 0.0, "income": 0.0, "ptick": {}}
	if build != null:
		bt = build.totals()

	# 소득 / 지출
	var income: float = D.BASE_INCOME + float(ind["economy"]) * 1.2 + float(ind["development"]) * 0.6 + float(bt["income"])
	var expense: float = D.BASE_EXPENSE + float(bt["upkeep"])
	for k in D.ALLOC_KEYS:
		expense += D.ALLOC_COST_PER_LEVEL * float(int(alloc.get(k, 1)))
	if get_loyalty("aide") < 30:
		expense += 10.0
	last_income = income
	last_expense = expense

	# 예산 배분 효과 (보통=1 은 효과 없음, 축소=0 은 나빠지고, 확대=2 는 좋아짐)
	var lw: float = float(int(alloc.get("welfare", 1)) - 1)
	var ls: float = float(int(alloc.get("security", 1)) - 1)
	var li: float = float(int(alloc.get("invest", 1)) - 1)
	ind["satisfaction"] = float(ind["satisfaction"]) + 0.10 * lw - 0.03 * ls
	ind["resources"] = float(ind["resources"]) - 0.04 * lw
	ind["stability"] = float(ind["stability"]) + 0.10 * ls
	ind["economy"] = float(ind["economy"]) + 0.08 * li
	ind["development"] = float(ind["development"]) + 0.05 * li

	# 진행 중인 정책
	var done_ids: Array = []
	for pid in active.keys():
		var p: Dictionary = D.policy_by_id(str(pid))
		if not p.is_empty():
			apply_delta(p["ptick"])
		active[pid] = int(active[pid]) - 1
		if int(active[pid]) <= 0:
			done_ids.append(pid)
	for pid2 in done_ids:
		active.erase(pid2)
		var pn: Dictionary = D.policy_by_id(str(pid2))
		if not pn.is_empty():
			last_notes.append("정책 종료: " + str(pn["name"]))
	for cid in cooldown.keys():
		cooldown[cid] = int(cooldown[cid]) - 1
		if int(cooldown[cid]) <= 0:
			cooldown.erase(cid)

	# 건물의 지속 효과
	apply_delta(bt["ptick"])

	# 인물 충성도 영향
	var le: int = get_loyalty("econ")
	if le < 30:
		ind["economy"] = float(ind["economy"]) - 0.05
	elif le > 70:
		ind["economy"] = float(ind["economy"]) + 0.04
	var lm: int = get_loyalty("mil")
	if lm < 30:
		ind["stability"] = float(ind["stability"]) - 0.08
	elif lm > 70:
		ind["stability"] = float(ind["stability"]) + 0.05
	var lp: int = get_loyalty("ppl")
	if lp < 30:
		ind["satisfaction"] = float(ind["satisfaction"]) - 0.06
	elif lp > 70:
		ind["satisfaction"] = float(ind["satisfaction"]) + 0.04

	# 자연스러운 변화
	ind["resources"] = float(ind["resources"]) - 0.10 + (float(ind["economy"]) - 50.0) * 0.002
	var mood: float = 0.4 * float(ind["resources"]) + 0.3 * float(ind["economy"]) + 0.3 * float(ind["development"])
	ind["satisfaction"] = float(ind["satisfaction"]) + (mood - 50.0) * 0.01
	ind["stability"] = float(ind["stability"]) + (float(ind["satisfaction"]) - 50.0) * 0.008
	ind["development"] = float(ind["development"]) - 0.02
	if float(ind["resources"]) < 25.0:
		ind["satisfaction"] = float(ind["satisfaction"]) - 0.25
		ind["stability"] = float(ind["stability"]) - 0.15
		last_notes.append("식량난: 비축 식량이 모자랍니다.")
	if float(ind["budget"]) < 0.0:
		ind["stability"] = float(ind["stability"]) - 0.4
		ind["satisfaction"] = float(ind["satisfaction"]) - 0.1
		last_notes.append("재정 적자: 예산이 바닥났습니다.")
	if float(ind["stability"]) < 20.0:
		ind["satisfaction"] = float(ind["satisfaction"]) - 0.2

	ind["budget"] = float(ind["budget"]) + income - expense
	_clamp_all()

	# 비상 수습: 안정도가 0 이면 게임이 끝나지 않고 긴급 조치가 일어난다
	if float(ind["stability"]) <= 0.5:
		ind["budget"] = float(ind["budget"]) - 500.0
		ind["satisfaction"] = float(ind["satisfaction"]) - 10.0
		ind["stability"] = 25.0
		last_notes.append("비상 수습 조치: 혼란을 막기 위해 예산 500이 쓰이고 민심이 흔들렸습니다.")
		_clamp_all()

	_check_goals()
	for n in last_notes:
		notice.emit(str(n))


# ================================================================ 미리보기 / 인물

## 다음 정산의 소득·지출 예상 (UI 표시용, 상태는 바꾸지 않음)
func preview() -> Dictionary:
	if ind.is_empty():
		return {"income": 0.0, "expense": 0.0}
	var bt: Dictionary = {"upkeep": 0.0, "income": 0.0, "ptick": {}}
	if build != null:
		bt = build.totals()
	var income: float = D.BASE_INCOME + float(ind["economy"]) * 1.2 + float(ind["development"]) * 0.6 + float(bt["income"])
	var expense: float = D.BASE_EXPENSE + float(bt["upkeep"])
	for k in D.ALLOC_KEYS:
		expense += D.ALLOC_COST_PER_LEVEL * float(int(alloc.get(k, 1)))
	if get_loyalty("aide") < 30:
		expense += 10.0
	return {"income": income, "expense": expense}


func seconds_to_tick() -> float:
	var speed: float = 2.0
	if hub != null and hub.clock != null:
		speed = maxf(float(hub.clock.speed), 0.1)
	return maxf(0.0, (D.TICK_GAME_MINUTES - _acc) / speed)


func can_cheer(pid: String) -> bool:
	return int(cheer_day.get(pid, -1)) != current_day_index()


func cheer(pid: String) -> String:
	if not can_cheer(pid):
		return "오늘은 이미 격려했습니다."
	cheer_day[pid] = current_day_index()
	add_loyalty(pid, 3)
	return "%s을(를) 격려했습니다. (충성 +3)" % D.person_name(pid)


func gift(pid: String) -> String:
	if float(ind.get("budget", 0.0)) < 100.0:
		return "예산이 부족합니다."
	ind["budget"] = float(ind["budget"]) - 100.0
	add_loyalty(pid, 5)
	return "%s에게 선물을 보냈습니다. (예산 -100, 충성 +5)" % D.person_name(pid)


# ================================================================ 정책

func policy_state(id: String) -> String:
	if active.has(id):
		return "진행 중 (%d)" % int(active[id])
	if cooldown.has(id):
		return "대기 (%d)" % int(cooldown[id])
	return ""


func can_exec(id: String) -> String:
	var p: Dictionary = D.policy_by_id(id)
	if p.is_empty():
		return "알 수 없는 정책입니다."
	if active.has(id):
		return "이미 진행 중입니다."
	if cooldown.has(id):
		return "다시 시행하려면 %d번의 정산을 기다려야 합니다." % int(cooldown[id])
	if float(p["cost"]) > float(ind["budget"]):
		return "예산이 부족합니다. (필요 %d)" % int(p["cost"])
	return ""


func exec_policy(id: String) -> Dictionary:
	var why: String = can_exec(id)
	if why != "":
		return {"ok": false, "text": why}
	var p: Dictionary = D.policy_by_id(id)
	ind["budget"] = float(ind["budget"]) - float(p["cost"])
	apply_delta(p["instant"])
	if int(p["ticks"]) > 0:
		active[id] = int(p["ticks"])
	cooldown[id] = int(p["cd"])
	policy_runs += 1
	_check_goals()
	var eff: String = D.effect_line(p["instant"])
	var txt: String = "정책 시행: %s" % str(p["name"])
	if int(p["cost"]) > 0:
		txt += " (예산 -%d)" % int(p["cost"])
	if eff != "":
		txt += " → " + eff
	return {"ok": true, "text": txt}


func change_alloc(key: String, d: int) -> void:
	if not alloc.has(key):
		return
	alloc[key] = clampi(int(alloc[key]) + d, 0, 2)


# ================================================================ 회의

func can_meet() -> bool:
	return meeting_day != current_day_index() and current_card.is_empty()


func open_meeting() -> bool:
	if meeting_day == current_day_index() and not current_card.is_empty():
		return true
	if meeting_day == current_day_index():
		return false
	var cards: Array = D.meeting_cards()
	var start: int = (current_day_index() * 7 + meetings_held * 3) % cards.size()
	var pick: Dictionary = cards[start]
	if str(pick["id"]) == _last_card_id:
		pick = cards[(start + 1) % cards.size()]
	current_card = pick.duplicate(true)
	current_card["done"] = false
	current_card["result"] = ""
	_last_card_id = str(pick["id"])
	meeting_day = current_day_index()
	return true


func choose_option(idx: int) -> void:
	if current_card.is_empty() or bool(current_card.get("done", false)):
		return
	var opts: Array = current_card["opts"]
	if idx < 0 or idx >= opts.size():
		return
	var o: Dictionary = opts[idx]
	var cost_need: float = -float(o["eff"].get("budget", 0.0))
	if cost_need > float(ind["budget"]) and cost_need > 0.0:
		current_card["result"] = "예산이 모자라 이 안은 택할 수 없습니다."
		return
	apply_delta(o["eff"])
	var lo: Dictionary = o["loy"]
	for pid in lo.keys():
		add_loyalty(str(pid), int(lo[pid]))
	meetings_held += 1
	current_card["done"] = true
	var line: String = str(o["result"])
	var eff: String = D.effect_line(o["eff"])
	if eff != "":
		line += "  [" + eff + "]"
	current_card["result"] = line
	meeting_log.append("%s → %s" % [str(current_card["title"]), str(o["label"])])
	if meeting_log.size() > 6:
		meeting_log.pop_front()
	_check_goals()


func close_meeting() -> void:
	if bool(current_card.get("done", false)):
		current_card = {}


# ================================================================ 목표

func goal_progress(g: Dictionary) -> float:
	var kind: String = str(g["kind"])
	var target: float = float(g["val"])
	match kind:
		"ind":
			return float(ind.get(str(g["key"]), 0.0))
		"built":
			return float(build.count()) if build != null else 0.0
		"policies":
			return float(policy_runs)
		"meetings":
			return float(meetings_held)
		"all":
			var m: float = 999.0
			for k in D.IND_KEYS:
				if k == "budget":
					continue
				m = minf(m, float(ind.get(k, 0.0)))
			return m
	return 0.0 * target


func _check_goals() -> void:
	for g in D.goals():
		var gid: String = str(g["id"])
		if goals_done.has(gid):
			continue
		if goal_progress(g) >= float(g["val"]):
			goals_done[gid] = true
			var reward: int = int(g.get("reward", 0))
			if reward > 0:
				ind["budget"] = float(ind["budget"]) + float(reward)
			if g.has("stab"):
				ind["stability"] = float(ind["stability"]) + float(g["stab"])
			_clamp_all()
			var txt: String = "국정 목표 달성: " + str(g["title"])
			if reward > 0:
				txt += " (예산 +%d)" % reward
			notice.emit(txt)


# ================================================================ 저장

func to_dict() -> Dictionary:
	return {
		"running": running,
		"ind": ind.duplicate(),
		"alloc": alloc.duplicate(),
		"loyalty": loyalty.duplicate(),
		"active": active.duplicate(),
		"cooldown": cooldown.duplicate(),
		"goals": goals_done.keys(),
		"tick": tick_count,
		"pruns": policy_runs,
		"meets": meetings_held,
		"mday": meeting_day,
		"log": meeting_log.duplicate(),
		"card": current_card.duplicate(true),
		"acc": _acc,
	}


func from_dict(d: Dictionary) -> void:
	running = bool(d.get("running", false))
	var di = d.get("ind")
	if di is Dictionary:
		ind = {}
		for k in D.IND_KEYS:
			ind[k] = float(di.get(k, 50.0))
	prev = ind.duplicate()
	var da = d.get("alloc")
	if da is Dictionary:
		for k in D.ALLOC_KEYS:
			alloc[k] = clampi(int(da.get(k, 1)), 0, 2)
	var dl = d.get("loyalty")
	if dl is Dictionary:
		loyalty = {}
		for k in dl.keys():
			loyalty[str(k)] = clampi(int(dl[k]), 0, 100)
	var dac = d.get("active")
	active = {}
	if dac is Dictionary:
		for k in dac.keys():
			active[str(k)] = int(dac[k])
	var dcd = d.get("cooldown")
	cooldown = {}
	if dcd is Dictionary:
		for k in dcd.keys():
			cooldown[str(k)] = int(dcd[k])
	goals_done = {}
	var dg = d.get("goals")
	if dg is Array:
		for k in dg:
			goals_done[str(k)] = true
	tick_count = int(d.get("tick", 0))
	policy_runs = int(d.get("pruns", 0))
	meetings_held = int(d.get("meets", 0))
	meeting_day = int(d.get("mday", -1))
	meeting_log = []
	var dlog = d.get("log")
	if dlog is Array:
		for s in dlog:
			meeting_log.append(str(s))
	current_card = {}
	var dc = d.get("card")
	if dc is Dictionary and not dc.is_empty():
		current_card = dc
	_acc = float(d.get("acc", 0.0))
	_last_abs = -1.0
	if ind.is_empty():
		running = false
