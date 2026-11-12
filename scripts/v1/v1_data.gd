extends RefCounted
## V1.0 에서 추가된 NPC, 소문, 택시 목적지 데이터. (모두 가상의 인물/장소입니다)
## 형식은 scripts/data/npc_data.gd 와 같습니다. 건물 안 NPC(옥류관 안내원, 지하철 직원)는
## v1/interior_extra.gd 가 해당 건물을 만들 때 함께 놓습니다.

## 택시 목적지: 키 -> [표시 이름, 위치를 찾는 방법]
## 위치는 v1_manager.dest_position(key) 가 실행 중에 찾습니다 (랜드마크 위치가 빈 자리 검사로 달라질 수 있으므로).
const TAXI_DESTS = {
	"plaza": "광장",
	"hotel": "호텔",
	"okryu": "옥류관",
	"metro": "지하철역",
	"arch": "개선문",
	"tower": "석탑",
	"station": "평양역",
}

const TAXI_DRIVER = {
	"id": "taxi_driver", "name": "정태수", "role": "택시 기사 · 수다스러움",
	"speed": 1.0, "home": Vector3(27.0, 0.0, 14.0),
	"look": {"sex": "m", "height": 1.02, "skin": Color(0.84, 0.68, 0.56), "shirt": Color(0.78, 0.74, 0.62), "pants": Color(0.18, 0.18, 0.2), "hair": Color(0.2, 0.18, 0.17), "hat": true, "hat_color": Color(0.2, 0.22, 0.28), "acc": ""},
	"routine": [
		{"from": 6.0, "to": 12.0, "mode": "wander", "pos": Vector3(27.0, 0.0, 14.0), "radius": 3.0},
		{"from": 12.0, "to": 13.0, "mode": "sit", "pos": Vector3(30.0, 0.0, 44.0), "radius": 0.0},
		{"from": 13.0, "to": 22.0, "mode": "wander", "pos": Vector3(27.0, 0.0, 14.0), "radius": 3.0},
		{"from": 22.0, "to": 6.0, "mode": "home", "pos": Vector3(27.0, 0.0, 14.0), "radius": 0.0},
	],
	"dialogue": {
		"start": {
			"text": "택시 필요하세요? 시내 어디든 금방 모셔다 드립니다.",
			"variants": {"밤": "이 시간에 돌아다니세요? 밤길은 제가 안전하게 모십니다.", "아침": "출근 시간대라 길이 붐벼요. 그래도 목적지만 말씀하세요."},
			"choices": [
				{"label": "택시 타기", "next": "dest1"},
				{"label": "요즘 어때요?", "next": "chat"},
				{"label": "다음에요", "next": ""},
			],
		},
		"chat": {
			"text": "요즘은 옥류관 쪽 손님이 많아요. 점심엔 줄이 길어서 못 들어가는 사람도 있다니까요.",
			"variants": {"밤": "밤엔 지하철역 앞에서 내리는 손님이 이상하게 많아요. 다들 말이 없고요."},
			"choices": [
				{"label": "택시 타기", "next": "dest1"},
				{"label": "안녕히 계세요", "next": ""},
			],
		},
		"dest1": {
			"text": "어디로 갈까요? (잠깐 암전 후 도착합니다. 시간이 조금 흐릅니다.)",
			"choices": [
				{"label": "광장", "next": "", "effects": [{"op": "taxi", "dest": "plaza"}]},
				{"label": "호텔", "next": "", "effects": [{"op": "taxi", "dest": "hotel"}]},
				{"label": "다른 곳", "next": "dest2"},
			],
		},
		"dest2": {
			"text": "그럼 이쪽 중에서 골라 주세요.",
			"choices": [
				{"label": "옥류관", "next": "", "effects": [{"op": "taxi", "dest": "okryu"}]},
				{"label": "지하철역", "next": "", "effects": [{"op": "taxi", "dest": "metro"}]},
				{"label": "개선문", "next": "", "effects": [{"op": "taxi", "dest": "arch"}]},
				{"label": "평양역", "next": "", "effects": [{"op": "taxi", "dest": "station"}], "if": {"flag": "v2_on"}},
			],
		},
	},
}

const POLICE_A = {
	"id": "police_a", "name": "조영철", "role": "경찰 · 무뚝뚝함",
	"speed": 1.1, "home": Vector3(-6.0, 0.0, 22.0),
	"look": {"sex": "m", "height": 1.04, "skin": Color(0.84, 0.68, 0.56), "shirt": Color(0.18, 0.24, 0.34), "pants": Color(0.14, 0.17, 0.24), "hair": Color(0.06, 0.06, 0.06), "hat": true, "hat_color": Color(0.18, 0.24, 0.34), "acc": ""},
	"routine": [
		{"from": 7.0, "to": 21.0, "mode": "wander", "pos": Vector3(-6.0, 0.0, 22.0), "radius": 14.0},
		{"from": 21.0, "to": 7.0, "mode": "home", "pos": Vector3(-6.0, 0.0, 22.0), "radius": 0.0},
	],
	"dialogue": {
		"start": {
			"text": "순찰 중입니다. 무슨 일이죠?",
			"variants": {"밤": "늦은 시간입니다. 일 없으면 숙소로 돌아가세요."},
			"choices": [
				{"label": "길을 물을게요", "next": "road"},
				{"label": "요즘 치안은요?", "next": "safe"},
				{"label": "수고하세요", "next": ""},
			],
		},
		"road": {
			"text": "광장에서 북쪽이 대회관과 석탑, 서쪽 대로를 따라 가면 옥류관입니다. 동쪽에는 지하철역이 있고요.",
			"choices": [{"label": "고맙습니다", "next": ""}],
		},
		"safe": {
			"text": "대체로 조용합니다. 다만 소란이 생기면 곧바로 사람들이 모이니 조심하세요. 우리는 신고를 받으면 바로 움직입니다.",
			"choices": [{"label": "알겠습니다", "next": ""}],
		},
	},
}

const POLICE_B = {
	"id": "police_b", "name": "한성호", "role": "경찰 · 친절함",
	"speed": 1.1, "home": Vector3(36.0, 0.0, -12.0),
	"look": {"sex": "m", "height": 1.0, "skin": Color(0.86, 0.7, 0.58), "shirt": Color(0.18, 0.24, 0.34), "pants": Color(0.14, 0.17, 0.24), "hair": Color(0.08, 0.07, 0.07), "hat": true, "hat_color": Color(0.18, 0.24, 0.34), "acc": ""},
	"routine": [
		{"from": 7.0, "to": 21.0, "mode": "wander", "pos": Vector3(36.0, 0.0, -12.0), "radius": 12.0},
		{"from": 21.0, "to": 7.0, "mode": "home", "pos": Vector3(36.0, 0.0, -12.0), "radius": 0.0},
	],
	"dialogue": {
		"start": {
			"text": "안녕하세요. 길 잃으셨나요? 이 구역은 처음이시죠?",
			"choices": [
				{"label": "이 동네 어때요?", "next": "town"},
				{"label": "아니에요", "next": ""},
			],
		},
		"town": {
			"text": "광장 주변은 낮에 사람이 많아요. 지하철역 쪽은 해가 지면 조용해지니, 밤에 가실 땐 조심하세요.",
			"choices": [{"label": "고맙습니다", "next": ""}],
		},
	},
}

## 서로 마주 보고 이야기하는 두 사람 (chat 일과). face 는 마주 보는 상대 위치
const CHAT_A = {
	"id": "chat_a", "name": "한순애", "role": "주민 · 수다스러움",
	"speed": 1.0, "home": Vector3(-24.0, 0.0, 38.0),
	"look": {"sex": "f", "height": 0.96, "skin": Color(0.88, 0.72, 0.6), "shirt": Color(0.55, 0.35, 0.5), "pants": Color(0.22, 0.2, 0.22), "hair": Color(0.1, 0.09, 0.09), "hat": false, "hat_color": Color(0, 0, 0), "acc": "bag"},
	"routine": [
		{"from": 7.0, "to": 11.0, "mode": "chat", "pos": Vector3(-24.0, 0.0, 38.0), "face": Vector3(-22.4, 0.0, 38.0)},
		{"from": 11.0, "to": 14.0, "mode": "wander", "pos": Vector3(-24.0, 0.0, 38.0), "radius": 10.0},
		{"from": 14.0, "to": 18.0, "mode": "chat", "pos": Vector3(-24.0, 0.0, 38.0), "face": Vector3(-22.4, 0.0, 38.0)},
		{"from": 18.0, "to": 21.0, "mode": "wander", "pos": Vector3(0.0, 0.0, 22.0), "radius": 16.0},
		{"from": 21.0, "to": 7.0, "mode": "home", "pos": Vector3(-24.0, 0.0, 38.0), "radius": 0.0},
	],
	"dialogue": {
		"start": {
			"text": "어머, 이야기하던 중이었는데! 괜찮아요, 말씀하세요.",
			"choices": [
				{"label": "무슨 얘기였죠?", "next": "gossip"},
				{"label": "방해했네요", "next": ""},
			],
		},
		"gossip": {
			"text": "별거 아니에요. 요즘 옥류관 앞에 줄이 길다는 얘기요. 아, 그리고 지하철역 직원이 갑자기 근무를 바꿨다던데…",
			"choices": [{"label": "그렇군요", "next": ""}],
		},
	},
}

const CHAT_B = {
	"id": "chat_b", "name": "윤미라", "role": "주민 · 호기심",
	"speed": 1.0, "home": Vector3(-22.0, 0.0, 38.0),
	"look": {"sex": "f", "height": 0.98, "skin": Color(0.86, 0.7, 0.58), "shirt": Color(0.3, 0.5, 0.58), "pants": Color(0.2, 0.22, 0.28), "hair": Color(0.12, 0.1, 0.1), "hat": false, "hat_color": Color(0, 0, 0), "acc": "scarf"},
	"routine": [
		{"from": 7.0, "to": 11.0, "mode": "chat", "pos": Vector3(-22.0, 0.0, 38.0), "face": Vector3(-23.6, 0.0, 38.0)},
		{"from": 11.0, "to": 14.0, "mode": "wander", "pos": Vector3(-22.0, 0.0, 38.0), "radius": 10.0},
		{"from": 14.0, "to": 18.0, "mode": "chat", "pos": Vector3(-22.0, 0.0, 38.0), "face": Vector3(-23.6, 0.0, 38.0)},
		{"from": 18.0, "to": 21.0, "mode": "wander", "pos": Vector3(3.0, 0.0, 22.0), "radius": 16.0},
		{"from": 21.0, "to": 7.0, "mode": "home", "pos": Vector3(-22.0, 0.0, 38.0), "radius": 0.0},
	],
	"dialogue": {
		"start": {
			"text": "안녕하세요! 순애 언니랑 수다 중이에요. 같이 얘기해요.",
			"choices": [
				{"label": "여기서 뭐 해요?", "next": "what"},
				{"label": "안녕히 계세요", "next": ""},
			],
		},
		"what": {
			"text": "저는 낮에 도서관에 다녀요. 밤엔 지하철역 쪽으로 가지 말라고들 해요. 이유는 모르겠지만요.",
			"choices": [{"label": "고마워요", "next": ""}],
		},
	},
}

const NPCS = [TAXI_DRIVER, POLICE_A, POLICE_B, CHAT_A, CHAT_B]

## 소문. when: 빈 배열이면 언제나 / ["밤"] 등 시간대 / trust: 필요한 신뢰도 / flag: 알게 되면 켜지는 플래그
## secret 이 true 면 말해 준 NPC 가 말을 마치고 잠시 불안해 함
const RUMORS = [
	{"id": "r_okryu_line", "text": "옥류관은 점심때 줄이 길어요. 직원 휴게실에 근무표가 붙어 있다던데, 그걸 보면 누가 언제 쉬는지 다 알 수 있대요.", "when": [], "trust": 0, "flag": "rumor_okryu"},
	{"id": "r_metro_night", "text": "밤에 지하철역 승강장 끝에서 불빛이 새어 나온대요. 점검실이라는데, 점검할 시간도 아닌데 말이죠.", "when": ["저녁", "밤"], "trust": 0, "flag": "rumor_metro"},
	{"id": "r_hotel_busy", "text": "호텔 안내원이 요즘 이상하게 바쁘대요. 손님도 별로 없는데 말이에요.", "when": [], "trust": 0, "flag": ""},
	{"id": "r_gov_gate", "text": "정부청사 앞 경비는 해 질 무렵에 교대한대요. 그때는 잠깐 앞이 어수선해진다던데요.", "when": ["저녁"], "trust": 1, "flag": "rumor_gov"},
	{"id": "r_taxi_secret", "text": "택시 기사들은 아는 길이 많죠. 지하철역 뒤편으로 가는 샛길이 있는데, 그리로 다니는 차는 아무도 안 세운대요.", "when": [], "trust": 2, "flag": "rumor_alley", "secret": true},
	{"id": "r_apt_light", "text": "아파트 단지 가장자리 동은 밤마다 같은 층만 불이 켜져 있어요. 사는 사람은 없다고 하는데…", "when": ["밤"], "trust": 1, "flag": "rumor_apt"},
	{"id": "r_police_call", "text": "소란이 나면 사람들이 곧바로 신고하고, 경찰은 몇 분 안에 모여든대요. 그러니 눈에 띄는 일은 피하는 게 좋아요.", "when": [], "trust": 0, "flag": ""},
	{"id": "r_archive", "text": "도시 곳곳에 옛 문서가 흩어져 있대요. 호텔 방, 문서실, 식당 휴게실, 역 승강장… 다 모으면 무슨 그림이 나온다나요.", "when": [], "trust": 2, "flag": "rumor_docs", "secret": true},
	{"id": "r_river", "text": "강가 산책로는 아침저녁으로 경치가 좋아요. 해 질 무렵 다리 위에서 보는 불빛이 일품이죠.", "when": ["저녁"], "trust": 0, "flag": ""},
	{"id": "r_tower", "text": "석탑 꼭대기 불빛은 밤새 켜져 있어요. 그 불빛을 보고 길을 찾는 택시 기사도 많다더군요.", "when": ["밤"], "trust": 0, "flag": ""},
]

## 도시 경계 단계별로 NPC 가 바꿔 말하는 한 줄
const ALERT_LINES = {
	1: "요즘 거리가 좀 어수선하죠…",
	2: "조심하세요. 경찰이 이 근처를 돌고 있어요.",
	3: "지금은 가까이 오지 마세요! 경찰이 누굴 찾고 있어요.",
	4: "제발 저리 가요! 온 도시가 난리예요!",
}
