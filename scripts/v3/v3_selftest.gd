extends RefCounted
## V3.0 자체 점검 (v23_selftest.gd 가 불러서 한 번 실행). 게임 상태는 바꾸지 않는다.
##  - V3 데이터(정책/건물/회의/목표/대화)의 오타와 연결 점검
##  - 임시 통치 모델을 따로 만들어 4가지 승계 경로로 시뮬레이션 (지표가 범위를 벗어나거나 NaN 이 되지 않는지)
##  - 건설 자리 검사가 큰길/광장을 막는지, 모듈이 연결됐는지
## 이 파일 자체도 Godot 에서 실행해 본 적이 없다. 첫 실행 결과가 곧 검증이다. (Godot 실행 미검증)

const D = preload("res://scripts/v3/v3_data.gd")
const ItemData = preload("res://scripts/data/item_data.gd")
const QuestData = preload("res://scripts/data/quest_data.gd")

var st = null


func run(selftest) -> void:
	st = selftest
	st.lines.append("— V3.0 점검 —")
	_check_modules()
	_check_data()
	_check_dialogues()
	_check_simulation()
	_check_build_rules()


func _check_modules() -> void:
	var v3 = st.mgr.v3
	st._check(v3 != null and bool(v3.done), "V3.0 모듈 묶음 만들어짐", "V3.0 모듈 묶음이 없거나 끝나지 않았습니다")
	if v3 == null:
		return
	st._check(v3.gov != null and v3.build != null and v3.story != null and v3.leader != null and v3.ui != null,
		"V3 하위 모듈 5개 연결 (통치/건설/스토리/지도자/화면)", "V3 하위 모듈 중 빠진 것이 있습니다")
	st._check(QuestData.QUESTS.has("q_v3_story") and QuestData.QUESTS["q_v3_story"]["steps"].size() == 6,
		"임무 q_v3_story 단계 6개", "임무 q_v3_story 가 없거나 단계 수가 다릅니다")
	st._check(not v3.is_leader or v3.gov.running, "지도자 상태와 통치 모델이 일치", "지도자인데 통치 모델이 멈춰 있습니다")
	st._check(v3.leader.hub != null and v3.leader.holder != null, "지도자 모듈 연결 (수행원 보관 노드)", "지도자 모듈 연결이 덜 됐습니다")


func _check_data() -> void:
	var bad: int = 0
	var seen: Dictionary = {}
	for p in D.policies():
		var pid: String = str(p["id"])
		if seen.has(pid):
			st._fail("정책 id 중복: " + pid)
			bad += 1
		seen[pid] = true
		var cat_ok: bool = false
		for c in D.CATS:
			if str(c["id"]) == str(p["cat"]):
				cat_ok = true
		if not cat_ok:
			st._fail("정책 %s: 없는 분류 %s" % [pid, str(p["cat"])])
			bad += 1
		for dk in ["instant", "ptick"]:
			for k in p[dk].keys():
				if not (str(k) in D.IND_KEYS):
					st._fail("정책 %s: 알 수 없는 지표 %s" % [pid, str(k)])
					bad += 1
		if int(p["ticks"]) > 0 and p["ptick"].is_empty():
			st._warn("정책 %s: 지속 효과가 없는데 기간이 있습니다" % pid)
	st._check(bad == 0, "정책 %d개 데이터 점검" % D.policies().size(), "정책 데이터에 문제가 있습니다")
	# 분류마다 정책이 하나 이상
	for c in D.CATS:
		var has_one: bool = false
		for p2 in D.policies():
			if str(p2["cat"]) == str(c["id"]):
				has_one = true
		st._check(has_one, "정책 분류 '%s' 에 정책 있음" % str(c["name"]), "정책 분류 '%s' 가 비어 있습니다" % str(c["name"]), false)
	var bbad: int = 0
	for b in D.buildings():
		for dk2 in ["instant", "ptick"]:
			for k2 in b[dk2].keys():
				if not (str(k2) in D.IND_KEYS):
					st._fail("건물 %s: 알 수 없는 지표 %s" % [str(b["id"]), str(k2)])
					bbad += 1
		if float(b["w"]) <= 0.0 or float(b["d"]) <= 0.0 or int(b["cost"]) < 0:
			st._fail("건물 %s: 크기/비용이 이상합니다" % str(b["id"]))
			bbad += 1
	st._check(bbad == 0, "건물 %d종 데이터 점검" % D.buildings().size(), "건물 데이터에 문제가 있습니다")
	var mbad: int = 0
	var pids: Dictionary = {}
	for pe in D.people():
		pids[str(pe["id"])] = true
	for card in D.meeting_cards():
		if card["opts"].size() < 2:
			st._fail("회의 %s: 선택지가 2개 미만" % str(card["id"]))
			mbad += 1
		for o in card["opts"]:
			for k3 in o["eff"].keys():
				if not (str(k3) in D.IND_KEYS):
					st._fail("회의 %s: 알 수 없는 지표 %s" % [str(card["id"]), str(k3)])
					mbad += 1
			for pk in o["loy"].keys():
				if not pids.has(str(pk)):
					st._fail("회의 %s: 알 수 없는 인물 %s" % [str(card["id"]), str(pk)])
					mbad += 1
	st._check(mbad == 0, "회의 카드 %d장 점검" % D.meeting_cards().size(), "회의 카드에 문제가 있습니다")
	var gbad: int = 0
	for g in D.goals():
		if str(g["kind"]) == "ind" and not (str(g["key"]) in D.IND_KEYS):
			st._fail("목표 %s: 알 수 없는 지표" % str(g["id"]))
			gbad += 1
	st._check(gbad == 0, "국정 목표 %d개 점검" % D.goals().size(), "국정 목표에 문제가 있습니다")
	for r in ["reform", "army", "deal", "will"]:
		var info: Dictionary = D.route_info(r)
		var ok: bool = info.has("ind") and info.has("loy") and D.succession_cards(r).size() >= 3
		st._check(ok, "승계 경로 %s: 시작 지표/충성도/장면 글 있음" % r, "승계 경로 %s 데이터가 모자랍니다" % r)


func _check_dialogues() -> void:
	var list: Array = [
		{"id": "v3_leader", "dialogue": D.leader_dialogue()},
		{"id": "v3_exleader", "dialogue": D.exleader_dialogue()},
		{"id": "v3_adv", "dialogue": D.advisor_dialogue("econ")},
		{"id": "v3_guard", "dialogue": D.attendant_dialogue("guard")},
		{"id": "v3_attend", "dialogue": D.attendant_dialogue("attend")},
	]
	var bad: int = 0
	for cfg in list:
		var d: Dictionary = cfg["dialogue"]
		var nid: String = str(cfg["id"])
		if not d.has("start"):
			st._fail("대화 %s: start 가 없습니다" % nid)
			bad += 1
			continue
		for k in d.keys():
			var nd: Dictionary = d[k]
			if str(nd.get("text", "")).length() > 150:
				st._warn("대화 %s:%s 본문이 깁니다" % [nid, str(k)])
			bad += st._check_effects(nd.get("effects", []), nid + ":" + str(k))
			var ch: Array = nd.get("choices", [])
			if ch.size() > 4:
				st._fail("대화 %s:%s 선택지 %d개" % [nid, str(k), ch.size()])
				bad += 1
			if ch.is_empty() and not nd.has("next"):
				st._fail("대화 %s:%s 끝이 막힘" % [nid, str(k)])
				bad += 1
			for c in ch:
				var nx: String = str(c.get("next", ""))
				if nx != "" and not d.has(nx):
					st._fail("대화 %s:%s → 없는 노드 %s" % [nid, str(k), nx])
					bad += 1
				if str(c.get("label", "")).length() > 9:
					st._warn("대화 %s:%s 라벨이 깁니다: %s" % [nid, str(k), str(c.get("label", ""))])
				bad += st._check_effects(c.get("effects", []), nid + ":" + str(k))
	if bad == 0:
		st._ok("V3 대화 %d개 구조 점검" % list.size())


## 임시 통치 모델로 시뮬레이션: 경로별로 정책을 돌려 가며 120번 정산했을 때 값이 정상 범위인지
func _check_simulation() -> void:
	var gs = load("res://scripts/v3/v3_gov.gd")
	if gs == null or not gs.can_instantiate():
		st._fail("v3_gov.gd 를 불러오지 못했습니다")
		return
	var all_ok: bool = true
	var detail: Array = []
	for r in ["reform", "army", "deal", "will"]:
		var g = gs.new()
		g.setup(st.hub, st.mgr)
		g.start_new(r)
		var policies: Array = D.policies()
		var budget_min: float = 1e9
		var finite: bool = true
		for i in range(120):
			if i % 6 == 0:
				var p: Dictionary = policies[(i / 6) % policies.size()]
				g.exec_policy(str(p["id"]))
			g.tick()
			for k in D.IND_KEYS:
				var v: float = float(g.ind[k])
				if is_nan(v) or is_inf(v):
					finite = false
				if k != "budget" and (v < -0.001 or v > 100.001):
					finite = false
			budget_min = minf(budget_min, float(g.ind["budget"]))
		var endline: String = "%s: 예산 %d 경제 %.0f 만족 %.0f 발전 %.0f 식량 %.0f 안정 %.0f" % [
			r, int(g.ind["budget"]), g.ind["economy"], g.ind["satisfaction"], g.ind["development"], g.ind["resources"], g.ind["stability"]]
		detail.append(endline)
		if not finite:
			all_ok = false
		g.free()
	st._check(all_ok, "통치 시뮬레이션 4경로 x 120회 정산: 값이 모두 정상 범위", "통치 시뮬레이션에서 범위를 벗어나거나 NaN 값이 나왔습니다")
	for dl in detail:
		st.lines.append("[참고] 120회 정산 뒤 " + str(dl))
	# 정책 효과가 실제로 지표를 바꾸는지
	var g2 = gs.new()
	g2.setup(st.hub, st.mgr)
	g2.start_new("deal")
	var before: float = float(g2.ind["satisfaction"])
	var res: Dictionary = g2.exec_policy("life_ration")
	var after: float = float(g2.ind["satisfaction"])
	st._check(bool(res["ok"]) and after > before, "정책 시행이 지표를 바꿈 (배급 확대: 만족 %.0f → %.0f)" % [before, after], "정책을 시행해도 지표가 변하지 않습니다")
	var res2: Dictionary = g2.exec_policy("life_ration")
	st._check(not bool(res2["ok"]), "같은 정책 연속 시행이 막힘 (대기 시간)", "같은 정책이 연속으로 시행됩니다")
	g2.free()


func _check_build_rules() -> void:
	var v3 = st.mgr.v3
	if v3 == null or v3.build == null:
		return
	var b = v3.build
	# 큰길, 중앙 광장, 청사 구역은 반드시 막혀야 한다
	var r1: String = b.check_site("shop", 0.0, 0.0, 0)
	var r2: String = b.check_site("shop", 120.0, 0.0, 0)
	var r3: String = b.check_site("shop", -245.0, -330.0, 0)
	st._check(r1 != "" and r2 != "" and r3 != "", "건설 규칙: 광장/큰길/청사 구역은 막힘", "건설 규칙이 큰길·광장·청사 구역을 막지 못합니다 (%s | %s | %s)" % [r1, r2, r3])
	# 건물 정의에서 면적이 모두 지도 안에 들어가는지
	var big_ok: bool = true
	for bd in D.buildings():
		if float(bd["w"]) > 60.0 or float(bd["d"]) > 60.0:
			big_ok = false
	st._check(big_ok, "건물 크기가 모두 60m 이하", "너무 큰 건물이 있습니다", false)
	# 참고: 실제로 지을 수 있는 빈 땅이 있는지 몇 군데 표본 검사 (정보용)
	var open_n: int = 0
	var samples: Array = [Vector2(120.0, 120.0), Vector2(-120.0, 120.0), Vector2(120.0, -120.0), Vector2(-120.0, -120.0), Vector2(200.0, 60.0), Vector2(-200.0, 60.0)]
	var why: Array = []
	for sp in samples:
		var r: String = b.check_site("park", sp.x, sp.y, 0)
		if r == "":
			open_n += 1
		else:
			why.append(r)
	st.lines.append("[참고] 표본 6곳 중 공원을 지을 수 있는 땅 %d곳 (막힌 이유: %s)" % [open_n, " / ".join(why) if not why.is_empty() else "없음"])
	if open_n == 0:
		st._warn("표본 6곳 모두 건설이 막혔습니다. 도시 개발 규칙이 너무 엄격할 수 있습니다")
