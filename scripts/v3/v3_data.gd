extends RefCounted
## V3.0 데이터 모음 (정책, 건물, 회의 카드, 목표, 주요 인물, 승계 경로, 대화).
## 이 게임의 모든 인물·단체·사건은 가상의 설정이며 실제 사건을 재현하지 않습니다.
## 값만 들어 있는 파일이라, 숫자를 고쳐서 균형을 바꿀 수 있습니다. (Godot 실행 미검증)

const IND_KEYS: Array = ["budget", "economy", "satisfaction", "development", "resources", "stability"]
const IND_NAMES: Dictionary = {
	"budget": "국가 예산",
	"economy": "경제 상태",
	"satisfaction": "주민 만족도",
	"development": "도시 발전도",
	"resources": "식량·자원",
	"stability": "국가 안정도",
}
const IND_SHORT: Dictionary = {
	"budget": "예산",
	"economy": "경제",
	"satisfaction": "만족",
	"development": "발전",
	"resources": "식량",
	"stability": "안정",
}
const CATS: Array = [
	{"id": "dev", "name": "도시 개발"},
	{"id": "life", "name": "생활 개선"},
	{"id": "eco", "name": "경제"},
	{"id": "bud", "name": "예산 배분"},
	{"id": "pub", "name": "공공시설"},
	{"id": "inf", "name": "교통·인프라"},
]
const ALLOC_KEYS: Array = ["welfare", "security", "invest"]
const ALLOC_NAMES: Dictionary = {"welfare": "복지", "security": "치안", "invest": "투자"}
const ALLOC_LEVEL_NAMES: Array = ["축소", "보통", "확대"]
const ALLOC_COST_PER_LEVEL: float = 20.0
const TICK_GAME_MINUTES: float = 120.0     # 게임 시간 2시간마다 한 번 정산 (실제 약 1분)
const BASE_EXPENSE: float = 70.0
const BASE_INCOME: float = 60.0
const MAX_BUILDINGS: int = 40


static func clean_ind() -> Dictionary:
	return {"budget": 1500.0, "economy": 50.0, "satisfaction": 50.0, "development": 40.0, "resources": 50.0, "stability": 50.0}


## 승계 경로별 시작 지표 (방식에 따라 나라의 시작 상태가 달라진다)
static func route_info(route: String) -> Dictionary:
	match route:
		"reform":
			return {"name": "공개 개혁", "ending": "엔딩 A — 광장의 낭독",
				"ind": {"budget": 1200.0, "economy": 45.0, "satisfaction": 68.0, "development": 40.0, "resources": 45.0, "stability": 42.0},
				"loy": {"aide": 55, "econ": 50, "mil": 35, "ppl": 75, "guard": 50}}
		"army":
			return {"name": "군부 합의", "ending": "엔딩 B — 질서의 이름으로",
				"ind": {"budget": 1800.0, "economy": 52.0, "satisfaction": 40.0, "development": 42.0, "resources": 50.0, "stability": 72.0},
				"loy": {"aide": 50, "econ": 50, "mil": 75, "ppl": 35, "guard": 60}}
		"deal":
			return {"name": "조용한 거래", "ending": "엔딩 C — 닫힌 문 뒤의 서명",
				"ind": {"budget": 3000.0, "economy": 55.0, "satisfaction": 48.0, "development": 45.0, "resources": 52.0, "stability": 52.0},
				"loy": {"aide": 70, "econ": 65, "mil": 50, "ppl": 40, "guard": 50}}
		_:
			return {"name": "유언 승계", "ending": "엔딩 D — 마지막 부탁",
				"ind": {"budget": 1500.0, "economy": 45.0, "satisfaction": 52.0, "development": 40.0, "resources": 48.0, "stability": 55.0},
				"loy": {"aide": 60, "econ": 50, "mil": 50, "ppl": 50, "guard": 55}}


## 승계 장면 글 (한 장에 한 덩어리). 탭하면 다음 장으로 넘어간다.
static func succession_cards(route: String) -> Array:
	var common_end: Array = [
		"새벽, 중앙 청사 집무실.\n책상 위에는 아직 식지 않은 찻잔과 펼쳐진 장부가 놓여 있다.",
		"창밖으로 도시가 천천히 깨어난다.\n수많은 불빛 하나하나가 이제 당신이 책임져야 할 삶이다.",
	]
	var mid: Array = []
	match route:
		"reform":
			mid = [
				"며칠 뒤 이른 아침, 광장.\n장부의 일부가 사람들 앞에서 낭독되었다. 웅성거림이 파도처럼 번졌다.",
				"노인은 조용히 자리에서 물러났다.\n환호와 불안이 한꺼번에 도시를 덮었다. 길은 열렸지만, 아직 아무도 그 끝을 모른다.",
			]
		"army":
			mid = [
				"며칠 뒤, 사령부 회의실.\n장성들은 긴 침묵 끝에 하나둘 서명했다. 질서는 지켜질 것이다. 대가가 따를 뿐.",
				"거리는 평소와 다름없이 조용했다.\n그 조용함이 안심인지 억눌림인지는, 아직 알 수 없었다.",
			]
		"deal":
			mid = [
				"며칠 뒤, 닫힌 문 뒤의 방.\n측근들은 장부를 덮고 서류에 서명했다. 누구의 이름도 신문에 오르지 않았다.",
				"모든 것이 매끄럽게 넘어갔다.\n그래서 더 불안했다. 이 서명 하나하나가 언젠가 되돌아올 빚이라는 것을 안다.",
			]
		_:
			mid = [
				"노인은 마지막 서류에 직접 서명했다.\n\"이 도시를 부탁한다. 내가 하지 못한 것을… 네가 하거라.\"",
				"그는 사저의 조용한 방으로 물러났다.\n배웅하는 사람은 많지 않았다. 새로운 시대는 그렇게 조용히 시작되었다.",
			]
	var out: Array = []
	for m in mid:
		out.append(m)
	for c in common_end:
		out.append(c)
	return out


static func intro_cards() -> Array:
	return [
		"깊은 밤, 중앙 청사.\n복도 끝 집무실의 문틈으로 불빛이 새어 나온다.",
		"비서관은 분명 말했다. 지도자는 지방 시찰 중이라고.\n그런데 책상 앞 의자에, 누군가 앉아 있다.",
		"한 노인이 장부를 든 당신을 바라본다.\n놀라지도, 경비를 부르지도 않은 채. 마치 오래전부터 이 순간을 기다려 온 사람처럼.",
	]


static func tutorial_cards() -> Array:
	return [
		"당신은 이제 국가를 이끄는 지도자입니다.\n이야기는 끝나지 않았습니다. 지금부터는 당신의 도시입니다.",
		"화면 오른쪽의 '통치' 버튼을 누르면\n국가 현황 · 예산 · 정책 · 도시 개발 · 인물 · 회의 · 임무 · 저장 메뉴가 열립니다.",
		"집무실 책상, 회의실 탁자, 사저와 도시 곳곳은\n지금도 자유롭게 오갈 수 있습니다. 차량 운전도 그대로 가능합니다.",
	]


# ================================================================ 정책

static func _p(id: String, cat: String, nm: String, cost: int, instant: Dictionary, ptick: Dictionary, ticks: int, cd: int, desc: String) -> Dictionary:
	return {"id": id, "cat": cat, "name": nm, "cost": cost, "instant": instant, "ptick": ptick, "ticks": ticks, "cd": cd, "desc": desc}


static func policies() -> Array:
	return [
		_p("dev_plan", "dev", "도시 재개발 계획", 400, {"development": 2.0}, {"development": 0.30, "satisfaction": -0.10}, 12, 24, "낡은 구역을 정비한다. 공사 동안 소음으로 만족이 조금 줄어든다."),
		_p("dev_housing", "dev", "주택 공급 확대", 600, {"satisfaction": 3.0}, {"development": 0.20, "satisfaction": 0.20}, 12, 24, "새 주택을 공급해 살 곳 걱정을 덜어 준다."),
		_p("life_ration", "life", "배급 확대", 300, {"satisfaction": 6.0, "resources": -6.0}, {"stability": 0.10}, 6, 18, "당장 식탁이 풍성해지지만 비축 식량이 줄어든다."),
		_p("life_health", "life", "보건 환경 개선", 350, {"satisfaction": 4.0}, {"satisfaction": 0.20, "stability": 0.10}, 12, 24, "진료소와 위생을 손본다. 오래 효과가 이어진다."),
		_p("life_edu", "life", "교육 지원", 400, {"satisfaction": 2.0}, {"development": 0.15, "economy": 0.15}, 18, 30, "학교와 기술 교육을 지원한다. 효과는 천천히 쌓인다."),
		_p("eco_market", "eco", "시장 활성화", 250, {"economy": 3.0, "satisfaction": 1.0}, {"economy": 0.30, "stability": -0.10}, 8, 18, "장마당 거래를 장려한다. 경제는 살지만 통제는 느슨해진다."),
		_p("eco_industry", "eco", "산업 육성", 700, {"economy": 2.0}, {"economy": 0.50, "resources": -0.20}, 12, 30, "공장과 설비에 투자한다. 자원 소모가 늘어난다."),
		_p("eco_tax_up", "eco", "세금 인상", 0, {"budget": 800.0, "satisfaction": -6.0, "stability": -3.0, "economy": -1.0}, {}, 0, 36, "예산을 바로 채운다. 주민의 불만이 쌓인다."),
		_p("eco_tax_down", "eco", "세금 감면", 200, {"satisfaction": 5.0, "economy": 2.0}, {"economy": 0.10}, 6, 24, "주민 부담을 덜어 준다. 나라 곳간이 잠시 가벼워진다."),
		_p("bud_agri", "bud", "농업 예산 집중", 500, {"resources": 6.0}, {"resources": 0.40}, 10, 24, "농장과 창고에 예산을 몰아준다. 식량 사정이 좋아진다."),
		_p("bud_security", "bud", "치안 예산 집중", 450, {"stability": 5.0}, {"stability": 0.20, "satisfaction": -0.05}, 12, 24, "순찰과 질서 유지에 힘을 싣는다. 답답함을 느끼는 이도 있다."),
		_p("bud_austerity", "bud", "긴축 재정", 0, {"budget": 500.0, "economy": -2.0, "satisfaction": -3.0}, {}, 0, 30, "지출을 줄여 곳간을 채운다. 곳곳에서 불편이 생긴다."),
		_p("pub_facility", "pub", "공공시설 확충", 800, {"satisfaction": 3.0, "development": 2.0}, {"satisfaction": 0.15}, 12, 30, "도서관, 목욕탕, 체육관을 늘린다."),
		_p("inf_transit", "inf", "대중교통 확충", 700, {"economy": 2.0, "development": 2.0}, {"economy": 0.20, "satisfaction": 0.10}, 12, 30, "버스와 전차 노선을 늘린다."),
		_p("inf_energy", "inf", "전력 인프라 개선", 900, {"economy": 1.0, "resources": 3.0, "development": 2.0}, {"economy": 0.25}, 12, 36, "발전과 송전 설비를 정비한다."),
	]


static func policy_by_id(id: String) -> Dictionary:
	for p in policies():
		if str(p["id"]) == id:
			return p
	return {}


## 효과 한 줄 요약 (UI 에 보여 줌)
static func effect_line(d: Dictionary) -> String:
	var parts: Array = []
	for k in IND_KEYS:
		if d.has(k):
			var v: float = float(d[k])
			if absf(v) < 0.005:
				continue
			var sgn: String = "+" if v > 0.0 else ""
			if k == "budget":
				parts.append("%s %s%d" % [IND_SHORT[k], sgn, int(v)])
			elif absf(v) < 1.0:
				parts.append("%s %s%.2f" % [IND_SHORT[k], sgn, v])
			else:
				parts.append("%s %s%.0f" % [IND_SHORT[k], sgn, v])
	return " · ".join(parts)


# ================================================================ 건물

static func _b(id: String, nm: String, cost: int, w: float, d: float, h: float, col: Color, style: String, instant: Dictionary, ptick: Dictionary, upkeep: float, income: float, desc: String) -> Dictionary:
	return {"id": id, "name": nm, "cost": cost, "w": w, "d": d, "h": h, "color": col, "style": style,
		"instant": instant, "ptick": ptick, "upkeep": upkeep, "income": income, "desc": desc}


static func buildings() -> Array:
	return [
		_b("park", "공원", 300, 16.0, 16.0, 0.3, Color(0.30, 0.52, 0.30), "park", {"development": 0.8, "satisfaction": 2.5}, {"satisfaction": 0.04}, 3.0, 0.0, "나무와 벤치가 있는 쉼터"),
		_b("plaza", "광장", 500, 20.0, 20.0, 0.3, Color(0.70, 0.69, 0.65), "plaza", {"development": 1.5, "satisfaction": 2.0}, {"satisfaction": 0.03, "stability": 0.02}, 4.0, 0.0, "분수와 가로등이 있는 만남의 장소"),
		_b("road", "도로 확장", 80, 10.0, 28.0, 0.2, Color(0.16, 0.16, 0.18), "road", {"development": 0.4, "economy": 0.5}, {}, 0.5, 2.0, "새 도로 한 구간. 회전해 이어 붙인다"),
		_b("shop", "상점가", 700, 18.0, 10.0, 7.0, Color(0.78, 0.62, 0.40), "block", {"development": 1.2, "economy": 1.5}, {"economy": 0.05}, 3.0, 10.0, "작은 가게들이 늘어선 거리"),
		_b("market", "시장", 900, 24.0, 16.0, 6.0, Color(0.62, 0.50, 0.34), "market", {"economy": 2.0, "resources": 1.5}, {"economy": 0.04}, 5.0, 14.0, "식료품과 생활용품 장터"),
		_b("apartment", "주택 단지", 1200, 22.0, 12.0, 15.0, Color(0.74, 0.72, 0.66), "tower", {"development": 2.5, "satisfaction": 3.0}, {"economy": 0.04, "resources": -0.03}, 8.0, 6.0, "여러 가구가 사는 아파트"),
		_b("clinic", "병원·보건소", 1100, 18.0, 14.0, 8.0, Color(0.88, 0.90, 0.92), "block", {"satisfaction": 3.5, "stability": 1.0}, {"satisfaction": 0.03}, 10.0, 0.0, "주민 진료소"),
		_b("school", "학교", 1000, 22.0, 14.0, 9.0, Color(0.80, 0.72, 0.52), "block", {"development": 2.0, "satisfaction": 1.5}, {"development": 0.03, "economy": 0.02}, 8.0, 0.0, "배움터"),
		_b("farm", "온실 농장", 800, 24.0, 20.0, 4.5, Color(0.62, 0.82, 0.66), "farm", {"resources": 4.0}, {"resources": 0.12}, 6.0, 0.0, "식량을 늘리는 큰 온실"),
		_b("factory", "공장", 1500, 26.0, 18.0, 10.0, Color(0.52, 0.54, 0.58), "factory", {"economy": 3.5, "development": 1.5}, {"resources": -0.05, "satisfaction": -0.02}, 12.0, 30.0, "생산 설비. 자원을 쓰고 소음이 난다"),
		_b("power", "변전소", 1800, 14.0, 14.0, 9.0, Color(0.48, 0.50, 0.46), "factory", {"economy": 2.0, "development": 2.0}, {"economy": 0.06}, 14.0, 0.0, "전력 공급 설비"),
		_b("station", "교통 거점", 1300, 24.0, 14.0, 7.0, Color(0.55, 0.62, 0.70), "block", {"economy": 2.0, "development": 2.5, "satisfaction": 1.5}, {"economy": 0.03}, 10.0, 8.0, "버스와 전차가 모이는 정류장"),
	]


static func building_by_id(id: String) -> Dictionary:
	for b in buildings():
		if str(b["id"]) == id:
			return b
	return {}


# ================================================================ 주요 인물

static func people() -> Array:
	return [
		{"id": "aide", "name": "비서관 고성진", "role": "비서관 · 국정 총괄"},
		{"id": "econ", "name": "경제 고문 윤하진", "role": "경제 고문 · 실무형"},
		{"id": "mil", "name": "군부 대표 강태식", "role": "군부 대표 · 원칙주의"},
		{"id": "ppl", "name": "인민 대표 오순금", "role": "인민 대표 · 현장형"},
		{"id": "guard", "name": "경호대장 마준호", "role": "경호대장 · 과묵"},
	]


static func person_name(id: String) -> String:
	for p in people():
		if str(p["id"]) == id:
			return str(p["name"])
	return id


static func advice(id: String, ind: Dictionary, loyalty: int) -> String:
	var sat: float = float(ind.get("satisfaction", 50.0))
	var eco: float = float(ind.get("economy", 50.0))
	var res: float = float(ind.get("resources", 50.0))
	var stab: float = float(ind.get("stability", 50.0))
	var bud: float = float(ind.get("budget", 0.0))
	var dev: float = float(ind.get("development", 0.0))
	match id:
		"econ":
			if bud < 300.0:
				return "곳간이 비어 갑니다. 세금 인상이나 긴축 재정을 검토하셔야 합니다. 하지만 후폭풍은 각오하십시오."
			if eco < 40.0:
				return "경제가 가라앉았습니다. 시장 활성화나 산업 육성에 투자할 때입니다."
			if dev < 50.0:
				return "도시를 더 키우십시오. 상점가와 교통 거점이 세수를 늘려 줍니다."
			return "숫자는 나쁘지 않습니다. 이럴 때 투자를 늘리면 오래 갑니다."
		"mil":
			if stab < 40.0:
				return "안정도가 위험합니다. 치안 예산을 집중하고, 필요하면 질서를 세워야 합니다."
			if loyalty < 35:
				return "군은 아직 지도자를 완전히 믿지 못합니다. 대화와 존중이 필요합니다."
			return "질서는 유지되고 있습니다. 다만 주민의 불만이 쌓이면 이것도 오래 못 갑니다."
		"ppl":
			if sat < 40.0:
				return "주민들은 지쳐 있습니다. 배급과 생활 개선이 급합니다. 직접 거리를 걸어 보십시오."
			if res < 35.0:
				return "식량이 부족하다는 말이 장마당에 돕니다. 농업에 힘을 주십시오."
			return "요즘은 표정이 조금 나아졌습니다. 이 분위기를 놓치지 마십시오."
		"guard":
			return "지도자의 신변은 걱정하지 마십시오. 다만 도시를 다니실 때는 반드시 저희를 곁에 두십시오."
		_:
			if bud < 0.0:
				return "나라 곳간이 빚을 지고 있습니다. 오늘 안에 정책을 정리하셔야 합니다."
			if sat < 40.0 or stab < 40.0:
				return "상황이 위태롭습니다. 회의를 열어 우선순위를 정하시지요."
			return "오늘 일정은 회의 1건입니다. 도시 곳곳에서 개발 요청도 올라와 있습니다."


# ================================================================ 회의 카드

static func _o(label: String, effects: Dictionary, loy: Dictionary = {}, result: String = "") -> Dictionary:
	return {"label": label, "eff": effects, "loy": loy, "result": result}


static func meeting_cards() -> Array:
	return [
		{"id": "m_ration", "title": "식량 배급 논쟁", "text": "인민 대표가 배급 기준을 올려 달라고 요청한다. 경제 고문은 비축이 줄어든다며 반대한다.",
			"opts": [
				_o("배급 확대", {"budget": -300.0, "satisfaction": 5.0, "resources": -4.0}, {"ppl": 6, "econ": -3}, "배급소 앞 줄이 짧아졌다."),
				_o("현행 유지", {"satisfaction": -1.0}, {"ppl": -3}, "달라진 것은 없었다."),
				_o("식량 수입", {"budget": -500.0, "resources": 8.0}, {"econ": 2}, "수입 식량이 창고를 채웠다."),
			]},
		{"id": "m_factory", "title": "공장 증설 요구", "text": "경제 고문이 공장 증설을 건의한다. 생산은 늘겠지만 자원 소모와 소음이 따른다.",
			"opts": [
				_o("승인", {"budget": -600.0, "economy": 4.0, "resources": -3.0, "satisfaction": -1.0, "development": 1.0}, {"econ": 6}, "굴뚝에서 연기가 올랐다."),
				_o("보류", {"economy": -1.0}, {"econ": -4}, "경제 고문은 아쉬운 표정을 지었다."),
			]},
		{"id": "m_army", "title": "군부 예산 증액 요청", "text": "군부 대표가 치안과 방위 예산을 늘려 달라고 한다. 거절하면 서운해할 것이다.",
			"opts": [
				_o("전액 승인", {"budget": -400.0, "stability": 4.0}, {"mil": 8}, "군부는 흡족해했다."),
				_o("절충안", {"budget": -200.0, "stability": 1.0}, {"mil": 2}, "서로 한 걸음씩 물러섰다."),
				_o("거절", {"stability": -2.0}, {"mil": -8}, "회의장에 찬 공기가 돌았다."),
			]},
		{"id": "m_petition", "title": "주민 청원", "text": "여러 구역 주민이 물 사정과 난방 문제로 청원서를 보내왔다. 인민 대표가 직접 와서 호소한다.",
			"opts": [
				_o("직접 청취", {"satisfaction": 4.0, "stability": 1.0}, {"ppl": 6}, "지도자가 직접 들었다는 소문이 퍼졌다."),
				_o("공개 사과", {"satisfaction": 2.0, "stability": -1.0}, {"ppl": 3}, "사과는 놀라움과 의심을 함께 낳았다."),
				_o("무시", {"satisfaction": -4.0}, {"ppl": -5}, "청원서는 서랍에 들어갔다."),
			]},
		{"id": "m_flood", "title": "폭우 피해 복구", "text": "며칠간의 폭우로 강변 구역이 잠겼다. 복구 방식을 정해야 한다.",
			"opts": [
				_o("전면 복구", {"budget": -700.0, "satisfaction": 3.0, "development": 1.0}, {"ppl": 4}, "거리가 깨끗해졌다."),
				_o("최소 복구", {"budget": -250.0, "satisfaction": -2.0}, {"ppl": -2}, "임시 복구로 버텨야 한다."),
			]},
		{"id": "m_export", "title": "수출 협상", "text": "이웃 나라의 가상 상인단이 광물 수출을 제안한다. 대가로 큰 돈을 내겠다고 한다.",
			"opts": [
				_o("수락", {"budget": 900.0, "economy": 2.0, "resources": -4.0}, {"econ": 4}, "곳간이 두둑해졌다."),
				_o("거절", {"satisfaction": 1.0}, {"econ": -2}, "자원은 지켰지만 기회를 놓쳤다."),
			]},
		{"id": "m_traffic", "title": "교통 혼잡", "text": "아침마다 대로가 막힌다. 도로 보수와 신호 정비 예산이 올라왔다.",
			"opts": [
				_o("도로 보수", {"budget": -350.0, "economy": 2.0, "development": 1.0}, {"econ": 3}, "출근길이 한결 수월해졌다."),
				_o("방치", {"economy": -1.0}, {}, "불평만 늘었다."),
			]},
		{"id": "m_jobs", "title": "청년 일자리", "text": "일자리가 없는 청년이 늘고 있다. 공공 사업으로 일감을 만들자는 안이 올라왔다.",
			"opts": [
				_o("사업 추진", {"budget": -450.0, "economy": 2.0, "satisfaction": 2.0}, {"ppl": 4}, "작업장에 활기가 돌았다."),
				_o("보류", {"satisfaction": -1.0}, {"ppl": -2}, "청년들의 한숨이 늘었다."),
			]},
		{"id": "m_audit", "title": "부패 의혹 보고", "text": "비서관이 일부 관리의 비리 의혹을 보고한다. 조사를 하면 내부가 시끄러워질 수 있다.",
			"opts": [
				_o("감사 착수", {"satisfaction": 3.0, "stability": -1.0}, {"aide": 4, "mil": -2}, "몇몇 관리가 자리를 잃었다."),
				_o("조용히 덮기", {"stability": 1.0, "satisfaction": -2.0}, {"aide": -3}, "문제는 덮였지만 사라지진 않았다."),
			]},
		{"id": "m_festival", "title": "문화 행사", "text": "가을 행사를 열자는 제안이 있다. 비용은 들지만 주민들의 기분이 달라질 것이다.",
			"opts": [
				_o("개최", {"budget": -300.0, "satisfaction": 5.0, "stability": 1.0}, {"ppl": 3}, "거리에 음악이 흘렀다."),
				_o("취소", {"satisfaction": -2.0}, {"ppl": -2}, "행사장은 조용했다."),
			]},
		{"id": "m_winter", "title": "겨울 대비", "text": "겨울이 다가온다. 난방 연료와 비상 식량을 미리 비축해야 한다.",
			"opts": [
				_o("충분히 비축", {"budget": -500.0, "resources": 7.0, "stability": 1.0}, {"econ": -2, "ppl": 3}, "창고가 가득 찼다."),
				_o("최소 비축", {"budget": -200.0, "resources": 2.0}, {}, "겨울을 넘기기엔 빠듯하다."),
			]},
		{"id": "m_envoy", "title": "외부 사절단", "text": "먼 나라에서 가상의 사절단이 방문한다. 환대하면 비용이 들지만 신뢰를 얻을 수 있다.",
			"opts": [
				_o("성대한 환대", {"budget": -350.0, "economy": 2.0, "stability": 2.0}, {"aide": 2}, "사절단이 만족하고 돌아갔다."),
				_o("간소한 접대", {"budget": -100.0, "stability": 0.0}, {}, "무난하게 끝났다."),
			]},
	]


# ================================================================ 목표(임무)

static func goals() -> Array:
	return [
		{"id": "g_dev40", "title": "도시 발전도 40 달성", "kind": "ind", "key": "development", "val": 40.0, "reward": 500},
		{"id": "g_dev60", "title": "도시 발전도 60 달성", "kind": "ind", "key": "development", "val": 60.0, "reward": 900},
		{"id": "g_sat65", "title": "주민 만족도 65 이상", "kind": "ind", "key": "satisfaction", "val": 65.0, "reward": 600},
		{"id": "g_stab70", "title": "국가 안정도 70 이상", "kind": "ind", "key": "stability", "val": 70.0, "reward": 600},
		{"id": "g_res70", "title": "식량·자원 70 이상", "kind": "ind", "key": "resources", "val": 70.0, "reward": 500},
		{"id": "g_eco65", "title": "경제 상태 65 이상", "kind": "ind", "key": "economy", "val": 65.0, "reward": 700},
		{"id": "g_bud4000", "title": "국가 예산 4000 확보", "kind": "ind", "key": "budget", "val": 4000.0, "reward": 0, "stab": 3.0},
		{"id": "g_build3", "title": "건물 3채 건설", "kind": "built", "val": 3.0, "reward": 300},
		{"id": "g_build10", "title": "건물 10채 건설", "kind": "built", "val": 10.0, "reward": 1200},
		{"id": "g_pol5", "title": "정책 5회 시행", "kind": "policies", "val": 5.0, "reward": 400},
		{"id": "g_meet5", "title": "회의 5회 개최", "kind": "meetings", "val": 5.0, "reward": 400},
		{"id": "g_all50", "title": "모든 지표 50 이상 유지", "kind": "all", "val": 50.0, "reward": 1500},
	]


# ================================================================ 지도자 대화 (대면 장면)

static func leader_dialogue() -> Dictionary:
	return {
		"start": {
			"text": "…오래 걸렸군. 장부를 들고 여기까지 온 사람은 네가 처음이다. 경비를 부르기 전에, 이야기부터 하자.",
			"effects": [{"op": "v3_eval"}],
			"choices": [
				{"label": "장부를 내민다", "next": "ledger"},
				{"label": "당신은 누구요", "next": "who"},
				{"label": "물러난다", "next": ""},
			],
		},
		"who": {
			"text": "이 도시를 오래 맡아 온 늙은이다. 아무것도 모르는 척했지만, 장부도, 줄어든 배급도 다 알고 있었다.",
			"choices": [
				{"label": "왜 방치했소", "next": "why"},
				{"label": "장부를 내민다", "next": "ledger"},
			],
		},
		"why": {
			"text": "고치려 들면 나부터 치우려는 사람들이 주변에 많았다. 몸도 날로 약해지고. …네가 무엇을 하려는지가 궁금하다.",
			"choices": [
				{"label": "장부를 내민다", "next": "ledger"},
				{"label": "물러난다", "next": ""},
			],
		},
		"ledger": {
			"text": "지지 기반을 살핀다.",
			"dyn": "v22_v3_support",
			"choices": [
				{"label": "공개 개혁", "next": "c_reform", "if": {"flag": "v3_can_reform"}},
				{"label": "군부와 합의", "next": "c_army", "if": {"flag": "v3_can_army"}},
				{"label": "조용한 거래", "next": "c_deal", "if": {"flag": "v3_can_deal"}},
				{"label": "유언을 받는다", "next": "c_will"},
			],
		},
		"c_reform": {
			"text": "장부를 광장에서 읽겠다는 뜻이군. 사람들이 널 따른다면 가능한 길이다. 대신 한동안 나라가 흔들릴 것이다.",
			"choices": [
				{"label": "그렇게 하겠소", "next": "", "effects": [{"op": "v3_succeed", "route": "reform"}]},
				{"label": "다시 생각한다", "next": "ledger"},
			],
		},
		"c_army": {
			"text": "군이 널 받아들이면 질서는 지켜진다. 하지만 주민들은 오래 숨죽일 것이다. 그래도 하겠느냐?",
			"choices": [
				{"label": "그렇게 하겠소", "next": "", "effects": [{"op": "v3_succeed", "route": "army"}]},
				{"label": "다시 생각한다", "next": "ledger"},
			],
		},
		"c_deal": {
			"text": "측근들과 조용히 서명하는 방식이군. 매끄럽겠지만, 그 서명은 언젠가 빚으로 돌아온다. 괜찮겠느냐?",
			"choices": [
				{"label": "그렇게 하겠소", "next": "", "effects": [{"op": "v3_succeed", "route": "deal"}]},
				{"label": "다시 생각한다", "next": "ledger"},
			],
		},
		"c_will": {
			"text": "내가 직접 자리를 넘기마. 지지는 부족할지 몰라도, 가장 평화로운 길이다. …이 도시를 부탁한다.",
			"choices": [
				{"label": "받아들이겠소", "next": "", "effects": [{"op": "v3_succeed", "route": "will"}]},
				{"label": "다시 생각한다", "next": "ledger"},
			],
		},
	}


## 승계 뒤 사저에 머무는 이전 지도자의 대화
static func exleader_dialogue() -> Dictionary:
	return {
		"start": {
			"text": "자리가 어떠냐. 무겁지? 처음엔 누구나 그렇다.",
			"choices": [
				{"label": "조언을 구한다", "next": "advice"},
				{"label": "옛 이야기", "next": "old"},
				{"label": "물러난다", "next": ""},
			],
		},
		"advice": {
			"text": "숫자만 보지 마라. 숫자 뒤에는 늘 사람이 있다. 그리고 가끔은 직접 거리에 나가 보아라.",
			"dyn": "v22_v3_advice_ex",
			"choices": [{"label": "명심하겠소", "next": ""}],
		},
		"old": {
			"text": "나도 한때는 이 도시를 바꾸려 했다. 바꾸려는 마음보다 지키려는 마음이 커졌을 때, 모든 게 멈췄지.",
			"choices": [{"label": "…", "next": ""}],
		},
	}


## 회의실의 인물(경제 고문, 군부 대표, 인민 대표) 대화
static func advisor_dialogue(pid: String) -> Dictionary:
	return {
		"start": {
			"text": "무엇을 도와드릴까요, 지도자님.",
			"choices": [
				{"label": "조언을 구한다", "next": "advice"},
				{"label": "격려한다", "next": "cheer", "effects": [{"op": "v3_loyal", "id": pid, "d": 2}]},
				{"label": "물러난다", "next": ""},
			],
		},
		"advice": {
			"text": "조언",
			"dyn": "v22_v3_advice_" + pid,
			"choices": [{"label": "알겠소", "next": ""}],
		},
		"cheer": {
			"text": "감사합니다. 맡은 일은 끝까지 해내겠습니다.",
			"choices": [{"label": "수고하시오", "next": ""}],
		},
	}


## 수행 직원 / 경호원
static func attendant_dialogue(kind: String) -> Dictionary:
	if kind == "guard":
		return {
			"start": {
				"text": "지도자님, 곁을 지키겠습니다. 차량이 필요하시면 말씀만 하십시오.",
				"choices": [
					{"label": "차를 불러라", "next": "", "effects": [{"op": "v3_do", "key": "car"}]},
					{"label": "수고한다", "next": ""},
				],
			},
		}
	return {
		"start": {
			"text": "오늘 일정을 알려 드릴까요? 회의와 보고가 기다리고 있습니다.",
			"choices": [
				{"label": "국정 보고", "next": "", "effects": [{"op": "v3_do", "key": "menu_status"}]},
				{"label": "회의 소집", "next": "", "effects": [{"op": "v3_do", "key": "menu_meeting"}]},
				{"label": "필요 없다", "next": ""},
			],
		},
	}


# ================================================================ 지도자 전용 외형

static func leader_outfit() -> Dictionary:
	return {
		"sex": "m",
		"build": 0.5,
		"skin": Color(0.86, 0.70, 0.58),
		"hair": Color(0.10, 0.09, 0.09),
		"hair_style": "short",
		"outfit": "suit",
		"top": Color(0.14, 0.17, 0.22),
		"bottom": Color(0.10, 0.11, 0.14),
		"acc": "",
		"long_sleeve": true,
		"seed": 11,
	}
