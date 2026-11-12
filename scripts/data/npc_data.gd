extends RefCounted
## NPC 설정, 일과(루틴), 대화 내용.
## 새 NPC는 NPCS 목록에 항목을 복사해 붙이고 값만 바꾸면 됩니다. 이 도시와 인물은 모두 가상입니다.
##
## ── 항목 ─────────────────────────────────────────────
##  id, name, role, speed, home(밤에 들어가는 곳 / 처음 놓이는 곳)
##  look      : sex("m"/"f", 선택), height(키 배율), skin, shirt, pants, hair, hat(true/false), hat_color, acc("scarf","bag","glasses","")
##  routine   : 시간대별 행동 목록. 각 항목 = {"from": 시작시각, "to": 끝시각, "mode": 행동, "pos": 위치, "radius": 반경}
##     mode  "wander" pos 주변을 돌아다님 / "stand" pos 에 서 있음 / "sit" pos 근처 벤치에 앉음
##           "home"   pos 로 돌아가 건물 안으로 들어감(화면에서 사라짐)
##     시각은 0~24 (예: 21.0 ~ 5.0 은 밤새)
##  dialogue  : 대화 그래프. 시작 노드는 "start" (아래 entry 조건이 맞으면 그 노드부터)
##     "entry": [ {"if": 조건, "node": 노드이름}, ... ]  위에서부터 처음 맞는 것
##     노드 = {"text": 대사, "variants": {"아침"/"낮"/"저녁"/"밤": 대사}, "effects": [...],
##             "choices": [ {"label": 선택지(14자 이내), "next": 다음노드, "if": 조건, "effects": [...]} ], "next": 노드}
##     next 가 "" 이면 대화 종료. 선택지가 없으면 화면을 탭해 next 로 진행. 한 노드에 선택지는 최대 3개 권장.
##  조건(if)  : {"flag":..}, {"not_flag":..}, {"item":..}, {"not_item":..}, {"quest":id,"state":"active","step":N,"min_step":N}, {"night":true}
##  효과(op)  : set_flag, give_item, take_item, quest_start, quest_step, quest_complete, toast, unlock_door, open_door
##             (효과에도 "if" 조건을 붙일 수 있음)

const NPCS = [
	{
		"id": "cleaner", "name": "박영미", "role": "거리 청소원 · 친절함",
		"speed": 1.2, "home": Vector3(-45.0, 0.0, 62.0),
		"look": {"sex": "f", "height": 0.97, "skin": Color(0.88, 0.72, 0.60), "shirt": Color(0.25, 0.45, 0.35), "pants": Color(0.2, 0.22, 0.26), "hair": Color(0.12, 0.10, 0.09), "hat": true, "hat_color": Color(0.92, 0.92, 0.86), "acc": ""},
		"routine": [
			{"from": 5.0, "to": 11.0, "mode": "wander", "pos": Vector3(-18.0, 0.0, 28.0), "radius": 14.0},
			{"from": 11.0, "to": 13.0, "mode": "sit", "pos": Vector3(-30.0, 0.0, 44.0), "radius": 0.0},
			{"from": 13.0, "to": 19.5, "mode": "wander", "pos": Vector3(10.0, 0.0, 20.0), "radius": 16.0},
			{"from": 19.5, "to": 5.0, "mode": "home", "pos": Vector3(-45.0, 0.0, 62.0), "radius": 0.0},
		],
		"dialogue": {
			"start": {
				"text": "안녕하세요. 새벽부터 길을 쓸고 있어요. 광장이 깨끗해야 하루가 기분 좋거든요.",
				"variants": {"저녁": "하루 종일 쓸었더니 어깨가 뻐근하네요. 그래도 저녁 광장이 제일 예뻐요."},
				"choices": [
					{"label": "여긴 어떤 동네예요?", "next": "area"},
					{"label": "힘든 일은 없으세요?", "next": "hard"},
					{"label": "안녕히 계세요", "next": ""},
				],
			},
			"area": {
				"text": "저 큰 건물 앞이 광장이고, 큰길을 따라 아파트 단지가 쭉 이어져요. 광장 근처에는 찻집도 있고 행정사무소도 있답니다.",
				"choices": [
					{"label": "다른 얘기도 할래요", "next": "start"},
					{"label": "감사합니다", "next": ""},
				],
			},
			"hard": {
				"text": "해 뜨기 전이 제일 바빠요. 그래도 지나가던 분들이 인사해 주면 힘이 나죠.",
				"choices": [
					{"label": "다른 얘기도 할래요", "next": "start"},
					{"label": "수고하세요", "next": ""},
				],
			},
		},
	},
	{
		"id": "student", "name": "최민호", "role": "대학생 · 호기심",
		"speed": 1.6, "home": Vector3(40.0, 0.0, 62.0),
		"look": {"sex": "m", "height": 1.03, "skin": Color(0.86, 0.70, 0.58), "shirt": Color(0.30, 0.34, 0.55), "pants": Color(0.18, 0.18, 0.22), "hair": Color(0.08, 0.07, 0.07), "hat": false, "hat_color": Color(0, 0, 0), "acc": "bag"},
		"routine": [
			{"from": 6.0, "to": 22.0, "mode": "wander", "pos": Vector3(24.0, 0.0, 42.0), "radius": 12.0},
			{"from": 22.0, "to": 6.0, "mode": "home", "pos": Vector3(40.0, 0.0, 62.0), "radius": 0.0},
		],
		"dialogue": {
			"entry": [
				{"if": [{"quest": "q_contact", "step": 7}, {"item": "secret_doc"}], "node": "deliver"},
				{"if": {"quest": "q_contact", "state": "done"}, "node": "after_done"},
				{"if": {"quest": "q_contact", "state": "active", "min_step": 1}, "node": "again"},
			],
			"start": {
				"text": "어, 처음 보는 얼굴이네요. 이 근처 분은 아닌 것 같은데, 어디서 오셨어요?",
				"choices": [
					{"label": "여행 중이에요", "next": "travel"},
					{"label": "그냥 둘러봐요", "next": "look"},
					{"label": "비밀이에요", "next": "secret"},
				],
			},
			"travel": {
				"text": "여행이요? 요즘 이 구역에서 외지 분 만나기가 쉽지 않은데… 어쨌든 환영해요.",
				"next": "ask",
			},
			"look": {
				"text": "그러세요. 저는 시험 기간이라 도서관 가는 길이에요. 쉬고 싶을 땐 광장 근처 찻집에 가요.",
				"next": "ask",
			},
			"secret": {
				"text": "하하, 수상한데요? 농담이에요. 그래도 길 잃으면 큰길을 따라 광장으로 오세요.",
				"next": "ask",
			},
			"ask": {
				"text": "…저기, 혹시 부탁 하나 해도 될까요? 잠깐이면 돼요.",
				"choices": [
					{"label": "뭔데요?", "next": "task"},
					{"label": "지금은 바빠요", "next": ""},
				],
			},
			"task": {
				"text": "호텔 로비의 안내원 윤서현 씨를 찾아가서 '푸른 우산'이라고 말해 주세요. 제가 가면 눈에 띄어서요.",
				"effects": [
					{"op": "quest_start", "id": "q_contact"},
					{"op": "set_flag", "key": "met_student"},
					{"op": "quest_step", "id": "q_contact", "step": 1},
				],
				"choices": [
					{"label": "알겠어요", "next": ""},
				],
			},
			"again": {
				"text": "호텔 로비의 윤서현 씨에게 '푸른 우산'이라고 하면 돼요. 조심하세요.",
				"choices": [
					{"label": "알겠어요", "next": ""},
				],
			},
			"deliver": {
				"text": "그 문서… 정말 찾아오셨군요! (주위를 살피며) 여기서 이야기하긴 위험해요. 제가 안전한 곳에 맡길게요. 정말 고마워요.",
				"effects": [
					{"op": "take_item", "id": "secret_doc"},
					{"op": "quest_complete", "id": "q_contact"},
				],
				"choices": [
					{"label": "무사해서 다행이에요", "next": ""},
				],
			},
			"after_done": {
				"text": "덕분에 한시름 놓았어요. 이 도시에는 아직 알려지지 않은 곳이 많으니, 계속 둘러보세요.",
				"choices": [
					{"label": "그럴게요", "next": ""},
				],
			},
		},
	},
	{
		"id": "fruit_seller", "name": "김순옥", "role": "과일 상인 · 수다스러움",
		"speed": 0.9, "home": Vector3(-74.0, 0.0, -16.0),
		"look": {"sex": "f", "height": 0.95, "skin": Color(0.88, 0.72, 0.60), "shirt": Color(0.62, 0.30, 0.25), "pants": Color(0.25, 0.22, 0.22), "hair": Color(0.35, 0.33, 0.33), "hat": true, "hat_color": Color(0.85, 0.75, 0.45), "acc": "scarf"},
		"routine": [
			{"from": 6.0, "to": 19.0, "mode": "wander", "pos": Vector3(-62.0, 0.0, -11.0), "radius": 6.0},
			{"from": 19.0, "to": 6.0, "mode": "home", "pos": Vector3(-74.0, 0.0, -16.0), "radius": 0.0},
		],
		"dialogue": {
			"start": {
				"text": "어서 오세요! 오늘 사과가 정말 달아요.",
				"choices": [
					{"label": "사과 하나 주세요", "next": "buy"},
					{"label": "장사는 잘 돼요?", "next": "biz"},
					{"label": "안녕히 계세요", "next": ""},
				],
			},
			"buy": {
				"text": "아이고, 오늘은 다 팔렸네요. 내일 일찍 오시면 제일 좋은 걸로 드릴게요.",
				"choices": [
					{"label": "내일 올게요", "next": ""},
					{"label": "다른 얘기도 할래요", "next": "start"},
				],
			},
			"biz": {
				"text": "아침엔 출근하는 사람들로 붐비고, 저녁엔 산책하는 사람들이 많아요. 아, 그리고 호텔 안내원이 요즘 이상하게 바쁘다던데, 들었어요?",
				"choices": [
					{"label": "다른 얘기도 할래요", "next": "start"},
					{"label": "수고하세요", "next": ""},
				],
			},
		},
	},
	{
		"id": "clerk", "name": "이철수", "role": "회사원 · 무뚝뚝함",
		"speed": 1.6, "home": Vector3(55.0, 0.0, -40.0),
		"look": {"sex": "m", "height": 1.02, "skin": Color(0.84, 0.68, 0.56), "shirt": Color(0.22, 0.24, 0.30), "pants": Color(0.12, 0.12, 0.15), "hair": Color(0.07, 0.06, 0.06), "hat": false, "hat_color": Color(0, 0, 0), "acc": "glasses"},
		"routine": [
			{"from": 6.0, "to": 9.0, "mode": "wander", "pos": Vector3(60.0, 0.0, 12.0), "radius": 8.0},
			{"from": 9.0, "to": 17.0, "mode": "wander", "pos": Vector3(40.0, 0.0, -28.0), "radius": 10.0},
			{"from": 17.0, "to": 21.0, "mode": "wander", "pos": Vector3(0.0, 0.0, 20.0), "radius": 20.0},
			{"from": 21.0, "to": 6.0, "mode": "home", "pos": Vector3(55.0, 0.0, -40.0), "radius": 0.0},
		],
		"dialogue": {
			"start": {
				"text": "죄송해요, 지금 좀 바빠서요. 보고서를 오늘까지 내야 하는데…",
				"variants": {"저녁": "퇴근 시간이라 마음은 급한데 발걸음은 무겁네요."},
				"choices": [
					{"label": "무슨 일 하세요?", "next": "job"},
					{"label": "잠깐만요", "next": "wait"},
					{"label": "죄송해요", "next": ""},
				],
			},
			"job": {
				"text": "근처 사무실에서 서류 정리하는 일을 해요. 퇴근길엔 늘 광장을 가로질러 걷죠.",
				"choices": [
					{"label": "수고하세요", "next": ""},
				],
			},
			"wait": {
				"text": "네, 잠깐은 괜찮아요. 길을 찾으시는 거면 큰길을 따라가시면 돼요.",
				"choices": [
					{"label": "고마워요", "next": ""},
				],
			},
		},
	},
	{
		"id": "guard", "name": "정광호", "role": "경비원 · 무뚝뚝함",
		"speed": 0.9, "home": Vector3(0.0, 0.0, -47.0),
		"look": {"sex": "m", "height": 1.05, "skin": Color(0.84, 0.68, 0.56), "shirt": Color(0.28, 0.33, 0.22), "pants": Color(0.20, 0.24, 0.16), "hair": Color(0.07, 0.06, 0.06), "hat": true, "hat_color": Color(0.20, 0.24, 0.16), "acc": ""},
		"routine": [
			{"from": 5.0, "to": 23.0, "mode": "wander", "pos": Vector3(0.0, 0.0, -47.0), "radius": 4.0},
			{"from": 23.0, "to": 5.0, "mode": "stand", "pos": Vector3(0.0, 0.0, -47.0), "radius": 0.0},
		],
		"dialogue": {
			"start": {
				"text": "거기 멈추세요. 이 건물 안쪽은 출입 허가가 필요합니다. 광장은 자유롭게 보셔도 됩니다.",
				"variants": {"밤": "밤에는 광장 출입을 삼가 주세요. …아, 산책이면 괜찮습니다."},
				"choices": [
					{"label": "안엔 뭐가 있죠?", "next": "inside"},
					{"label": "허가는 어떻게?", "next": "permit"},
					{"label": "알겠습니다", "next": ""},
				],
			},
			"inside": {
				"text": "저도 자세히는 모릅니다. 저는 문 앞을 지키는 게 일이라서요.",
				"choices": [
					{"label": "알겠습니다", "next": ""},
				],
			},
			"permit": {
				"text": "행정사무소에서 신청서를 받아야 합니다. 지금은 돌아가 주세요.",
				"choices": [
					{"label": "알겠습니다", "next": ""},
				],
			},
		},
	},
	{
		"id": "elder", "name": "오복순", "role": "산책하는 어르신 · 친절함",
		"speed": 0.7, "home": Vector3(-35.0, 0.0, 62.0),
		"look": {"sex": "f", "height": 0.92, "skin": Color(0.88, 0.74, 0.62), "shirt": Color(0.55, 0.42, 0.55), "pants": Color(0.25, 0.22, 0.26), "hair": Color(0.80, 0.80, 0.80), "hat": false, "hat_color": Color(0, 0, 0), "acc": "scarf"},
		"routine": [
			{"from": 6.0, "to": 10.0, "mode": "wander", "pos": Vector3(-30.0, 0.0, 40.0), "radius": 6.0},
			{"from": 10.0, "to": 12.0, "mode": "sit", "pos": Vector3(-30.0, 0.0, 44.0), "radius": 0.0},
			{"from": 12.0, "to": 18.0, "mode": "wander", "pos": Vector3(-30.0, 0.0, 40.0), "radius": 6.0},
			{"from": 18.0, "to": 20.0, "mode": "sit", "pos": Vector3(30.0, 0.0, 44.0), "radius": 0.0},
			{"from": 20.0, "to": 6.0, "mode": "home", "pos": Vector3(-35.0, 0.0, 62.0), "radius": 0.0},
		],
		"dialogue": {
			"start": {
				"text": "허허, 다리가 아파서 천천히 걷고 있다오. 젊은이는 어딜 가는 길이우?",
				"variants": {"저녁": "저녁 바람이 시원하구려. 이맘때 벤치에 앉아 있는 게 낙이라오."},
				"choices": [
					{"label": "산책 중이에요", "next": "walk"},
					{"label": "쉴 만한 곳 있나요?", "next": "rest"},
					{"label": "건강하세요", "next": ""},
				],
			},
			"walk": {
				"text": "좋은 일이지. 걸으면 도시가 새롭게 보인다오. 매일 같은 길도 계절마다 다르거든.",
				"choices": [
					{"label": "다른 얘기도 할래요", "next": "start"},
					{"label": "건강하세요", "next": ""},
				],
			},
			"rest": {
				"text": "광장 가장자리에 벤치가 있고, 근처에 작은 찻집도 있다오. 소파가 푹신해서 다리 쉬기 좋지.",
				"choices": [
					{"label": "가 볼게요", "next": ""},
					{"label": "다른 얘기도 할래요", "next": "start"},
				],
			},
		},
	},
]

## 건물 안 고정 NPC (interior_manager 가 위치를 정해 줌)
const SHOPKEEPER = {
	"id": "teahouse_owner", "name": "한미정", "role": "찻집 주인 · 친절함", "speed": 0.0,
	"look": {"sex": "f", "height": 0.98, "skin": Color(0.88, 0.72, 0.60), "shirt": Color(0.80, 0.72, 0.60), "pants": Color(0.30, 0.25, 0.22), "hair": Color(0.10, 0.08, 0.07), "hat": false, "hat_color": Color(0, 0, 0), "acc": ""},
	"dialogue": {
		"entry": [
			{"if": {"quest": "q_tea", "state": "done"}, "node": "after_done"},
			{"if": {"quest": "q_tea", "state": "active", "step": 2}, "node": "again"},
		],
		"start": {
			"text": "어서 오세요. 편한 자리에 앉으세요. 따뜻한 차 한 잔 드릴까요?",
			"effects": [
				{"op": "quest_step", "id": "q_tea", "step": 2, "if": {"quest": "q_tea", "state": "active", "step": 1}},
			],
			"choices": [
				{"label": "차 한 잔 주세요", "next": "tea"},
				{"label": "여긴 오래됐나요?", "next": "shop"},
				{"label": "나중에 올게요", "next": ""},
			],
		},
		"tea": {
			"text": "곧 준비할게요. 소파에서 편히 기다리세요. 창가 쪽 자리가 제일 좋아요.",
			"choices": [
				{"label": "감사합니다", "next": ""},
				{"label": "다른 얘기도 할래요", "next": "start"},
			],
		},
		"shop": {
			"text": "작년에 문을 열었어요. 광장 산책하다 들르시는 손님이 많아요. 창가 쪽 소파가 인기 자리랍니다.",
			"choices": [
				{"label": "다른 얘기도 할래요", "next": "start"},
				{"label": "좋은 곳이네요", "next": ""},
			],
		},
		"again": {
			"text": "편한 자리에 앉아서 좀 쉬어 가세요. 소파든 의자든 괜찮아요.",
			"choices": [
				{"label": "그럴게요", "next": ""},
			],
		},
		"after_done": {
			"text": "소개장은 잘 쓰고 계세요? 행정사무소는 광장 근처에 있어요. 문서실을 보시려면 허가증이 필요하죠.",
			"choices": [
				{"label": "고마워요", "next": ""},
				{"label": "나중에 올게요", "next": ""},
			],
		},
	},
}

const RECEPTIONIST = {
	"id": "hotel_desk", "name": "윤서현", "role": "호텔 안내원 · 수줍음", "speed": 0.0,
	"look": {"sex": "f", "height": 0.99, "skin": Color(0.88, 0.72, 0.60), "shirt": Color(0.18, 0.25, 0.42), "pants": Color(0.12, 0.14, 0.2), "hair": Color(0.08, 0.07, 0.07), "hat": false, "hat_color": Color(0, 0, 0), "acc": "scarf"},
	"dialogue": {
		"entry": [
			{"if": {"flag": "got_key"}, "node": "after"},
			{"if": {"flag": "met_student"}, "node": "ask_code"},
		],
		"start": {
			"text": "어서 오세요. 투숙 문의신가요? 지금은 빈 객실이 많아요.",
			"choices": [
				{"label": "2층은 어떤가요?", "next": "floor2"},
				{"label": "그냥 구경 왔어요", "next": ""},
			],
		},
		"floor2": {
			"text": "엘리베이터로 올라가시면 객실 복도예요. 201호는 지금 비어 있어서 둘러보셔도 돼요.",
			"choices": [
				{"label": "고마워요", "next": ""},
			],
		},
		"ask_code": {
			"text": "어서 오세요. 무엇을 도와드릴까요?",
			"choices": [
				{"label": "푸른 우산입니다", "next": "code"},
				{"label": "2층은 어떤가요?", "next": "floor2"},
				{"label": "아니에요", "next": ""},
			],
		},
		"code": {
			"text": "…잠시만요. (목소리를 낮추며) 최민호 학생의 심부름이군요. 이 열쇠를 가져가세요. 아파트 3동 12호예요. 집 안에서 '틈'을 찾아보세요.",
			"effects": [
				{"op": "give_item", "id": "apartment_key"},
				{"op": "set_flag", "key": "got_key"},
				{"op": "quest_step", "id": "q_contact", "step": 2, "if": {"quest": "q_contact", "state": "active", "step": 1}},
			],
			"choices": [
				{"label": "조심할게요", "next": ""},
			],
		},
		"after": {
			"text": "열쇠는 잘 쓰시길 바랄게요. 눈에 띄지 않게 조심하세요.",
			"choices": [
				{"label": "네", "next": ""},
			],
		},
	},
}

const OFFICE_CLERK = {
	"id": "office_clerk", "name": "박정숙", "role": "행정사무소 직원 · 무뚝뚝함", "speed": 0.0,
	"look": {"sex": "f", "height": 0.98, "skin": Color(0.86, 0.70, 0.58), "shirt": Color(0.75, 0.78, 0.82), "pants": Color(0.20, 0.20, 0.24), "hair": Color(0.09, 0.08, 0.08), "hat": false, "hat_color": Color(0, 0, 0), "acc": "glasses"},
	"dialogue": {
		"entry": [
			{"if": [{"item": "intro_letter"}, {"not_flag": "got_pass"}], "node": "letter"},
			{"if": {"flag": "got_pass"}, "node": "after"},
		],
		"start": {
			"text": "접수 창구입니다. 어떤 용무이신가요?",
			"choices": [
				{"label": "문서실 열람이요", "next": "need"},
				{"label": "그냥 구경 왔어요", "next": ""},
			],
		},
		"need": {
			"text": "문서실은 허가증이 있어야 들어갈 수 있어요. 누군가의 소개장이 있으면 발급해 드릴 수 있습니다.",
			"choices": [
				{"label": "알겠습니다", "next": ""},
			],
		},
		"letter": {
			"text": "소개장을 가져오셨네요. 한미정 씨 소개군요. 열람 허가증을 드리겠습니다. 문서실은 안쪽 문이에요.",
			"effects": [
				{"op": "take_item", "id": "intro_letter"},
				{"op": "give_item", "id": "office_pass"},
				{"op": "set_flag", "key": "got_pass"},
				{"op": "quest_step", "id": "q_office", "step": 1, "if": {"quest": "q_office", "state": "active", "step": 0}},
			],
			"choices": [
				{"label": "감사합니다", "next": ""},
			],
		},
		"after": {
			"text": "문서실은 안쪽 문입니다. 나올 땐 문을 닫아 주세요.",
			"choices": [
				{"label": "알겠습니다", "next": ""},
			],
		},
	},
}

# ---------------------------------------------------------------- 군중(자동 생성 시민)

const SURNAMES = ["김", "이", "박", "최", "정", "강", "조", "윤", "장", "임"]
const GIVEN_M = ["민수", "철호", "영진", "성민", "광수", "동현", "태영", "준호"]
const GIVEN_F = ["은정", "미란", "순희", "영희", "지현", "혜진", "수진", "정아"]
const JOBS = ["회사원", "학생", "상점 직원", "배달원", "교사", "기술자", "주민", "노동자"]
const PERSONALITIES = ["friendly", "grumpy", "chatty", "shy", "curious"]
const PERSONALITY_LABEL = {"friendly": "친절함", "grumpy": "무뚝뚝함", "chatty": "수다스러움", "shy": "수줍음", "curious": "호기심"}
const SKINS = [Color(0.88, 0.72, 0.60), Color(0.84, 0.68, 0.56), Color(0.80, 0.64, 0.52), Color(0.90, 0.76, 0.64)]
const SHIRTS = [Color(0.25, 0.45, 0.35), Color(0.30, 0.34, 0.55), Color(0.62, 0.30, 0.25), Color(0.55, 0.50, 0.30), Color(0.40, 0.40, 0.45), Color(0.70, 0.62, 0.50), Color(0.35, 0.50, 0.58), Color(0.55, 0.35, 0.50)]
const PANTS = [Color(0.15, 0.15, 0.18), Color(0.25, 0.22, 0.20), Color(0.20, 0.25, 0.32), Color(0.30, 0.30, 0.28)]
const HAIRS = [Color(0.07, 0.06, 0.06), Color(0.15, 0.12, 0.10), Color(0.30, 0.28, 0.27), Color(0.60, 0.60, 0.60)]
const ACCS = ["", "", "scarf", "bag", "glasses"]
const DISTRICTS = [
	Vector3(-70.0, 0.0, 12.0), Vector3(70.0, 0.0, -12.0), Vector3(-120.0, 0.0, -12.0), Vector3(120.0, 0.0, 12.0),
	Vector3(0.0, 0.0, 80.0), Vector3(0.0, 0.0, 140.0), Vector3(20.0, 0.0, 20.0), Vector3(-25.0, 0.0, -25.0),
]
const PLAZA_POINTS = [Vector3(0.0, 0.0, 20.0), Vector3(-25.0, 0.0, 20.0), Vector3(25.0, 0.0, 20.0), Vector3(0.0, 0.0, -20.0), Vector3(20.0, 0.0, -30.0)]
## V1: 출근/장보기 시민이 낮 동안 머무는 대략적인 장소 (빈 자리는 NPC 가 걷다가 막히면 알아서 멈춤)
const WORK_POINTS = [Vector3(34.0, 0.0, -12.0), Vector3(-26.0, 0.0, 16.0), Vector3(60.0, 0.0, -12.0), Vector3(0.0, 0.0, -56.0)]
const SHOP_POINTS = [Vector3(46.0, 0.0, 24.0), Vector3(-60.0, 0.0, -10.0), Vector3(22.0, 0.0, 20.0)]
## V2: 버스 정류장 앞 대기 지점 (버스가 서면 근처 시민이 탑승)
const BUS_WAIT_POINTS = [Vector3(-104.0, 0.0, 11.0), Vector3(104.0, 0.0, -11.0), Vector3(-101.0, 0.0, -11.0), Vector3(101.0, 0.0, 11.0)]
const BENCH_POINTS = [Vector3(-30.0, 0.0, 44.0), Vector3(30.0, 0.0, 44.0), Vector3(-30.0, 0.0, -44.0), Vector3(30.0, 0.0, -44.0)]


static func make_crowd(count: int, seed_value: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for i in range(count):
		var female: bool = rng.randf() < 0.5
		var given: String = ""
		if female:
			given = str(GIVEN_F[rng.randi() % GIVEN_F.size()])
		else:
			given = str(GIVEN_M[rng.randi() % GIVEN_M.size()])
		var pers: String = str(PERSONALITIES[rng.randi() % PERSONALITIES.size()])
		var job: String = str(JOBS[rng.randi() % JOBS.size()])
		var center: Vector3 = DISTRICTS[rng.randi() % DISTRICTS.size()]
		var plaza_pt: Vector3 = PLAZA_POINTS[rng.randi() % PLAZA_POINTS.size()]
		var bench_pt: Vector3 = BENCH_POINTS[rng.randi() % BENCH_POINTS.size()]
		var rad: float = rng.randf_range(10.0, 16.0)
		var jit: float = rng.randf_range(-1.0, 1.0)
		var routine: Array = [
			{"from": fposmod(5.0 + jit, 24.0), "to": fposmod(9.0 + jit, 24.0), "mode": "wander", "pos": center, "radius": rad},
			{"from": fposmod(9.0 + jit, 24.0), "to": fposmod(12.0 + jit, 24.0), "mode": "wander", "pos": plaza_pt, "radius": 18.0},
		]
		if rng.randf() < 0.4:
			routine.append({"from": fposmod(12.0 + jit, 24.0), "to": fposmod(13.5 + jit, 24.0), "mode": "sit", "pos": bench_pt, "radius": 0.0})
		else:
			routine.append({"from": fposmod(12.0 + jit, 24.0), "to": fposmod(13.5 + jit, 24.0), "mode": "wander", "pos": center, "radius": rad})
		routine.append({"from": fposmod(13.5 + jit, 24.0), "to": fposmod(19.0 + jit, 24.0), "mode": "wander", "pos": center, "radius": rad})
		routine.append({"from": fposmod(19.0 + jit, 24.0), "to": fposmod(21.0 + jit, 24.0), "mode": "wander", "pos": plaza_pt, "radius": 20.0})
		routine.append({"from": fposmod(21.0 + jit, 24.0), "to": fposmod(5.0 + jit, 24.0), "mode": "home", "pos": center, "radius": 0.0})
		# V1: 생활 유형 - 0 출퇴근하는 직장인 / 1 장보는 사람 / 그 밖엔 기본 일과
		var life: int = rng.randi() % 4
		var wp: Vector3 = WORK_POINTS[rng.randi() % WORK_POINTS.size()]
		var sp: Vector3 = SHOP_POINTS[rng.randi() % SHOP_POINTS.size()]
		if life == 0:
			job = "회사원"
			routine[1]["pos"] = wp
			routine[1]["radius"] = 6.0
			routine[3]["pos"] = wp
			routine[3]["radius"] = 6.0
		elif life == 1:
			routine[1]["pos"] = sp
			routine[1]["radius"] = 7.0
			routine[3]["pos"] = sp
			routine[3]["radius"] = 8.0
		elif life == 2:
			# V2: 오전에 버스를 기다림
			var stop: Vector3 = BUS_WAIT_POINTS[rng.randi() % BUS_WAIT_POINTS.size()]
			_split_routine(routine, 1, 0.5, {"mode": "wait", "pos": stop, "radius": 0.0})
		else:
			# V2: 광장 한쪽에서 전화를 걸다가 다시 돌아다님
			_split_routine(routine, 1, 0.35, {"mode": "phone", "pos": plaza_pt, "radius": 0.0, "face": plaza_pt + Vector3(0.0, 0.0, 6.0)})
		var look: Dictionary = {
			"sex": "f" if female else "m",
			"height": rng.randf_range(0.93, 1.07),
			"skin": SKINS[rng.randi() % SKINS.size()],
			"shirt": SHIRTS[rng.randi() % SHIRTS.size()],
			"pants": PANTS[rng.randi() % PANTS.size()],
			"hair": HAIRS[rng.randi() % HAIRS.size()],
			"hat": rng.randf() < 0.2,
			"hat_color": SHIRTS[rng.randi() % SHIRTS.size()],
			"acc": ACCS[rng.randi() % ACCS.size()],
		}
		out.append({
			"id": "citizen_%d" % i,
			"name": str(SURNAMES[rng.randi() % SURNAMES.size()]) + given,
			"role": "%s · %s" % [job, str(PERSONALITY_LABEL[pers])],
			"speed": rng.randf_range(1.0, 1.7),
			"home": center,
			"look": look,
			"routine": routine,
			"dialogue": generic_dialogue(pers),
		})
	return out


## V2: 일과 한 칸(idx)의 앞부분(frac 비율)을 특별한 행동으로 바꾸고 나머지는 원래 행동을 이어 감
static func _split_routine(routine: Array, idx: int, frac: float, special: Dictionary) -> void:
	var e: Dictionary = routine[idx]
	var a: float = float(e["from"])
	var b: float = float(e["to"])
	var span: float = fposmod(b - a, 24.0)
	var mid: float = fposmod(a + span * frac, 24.0)
	var sp: Dictionary = special.duplicate()
	sp["from"] = a
	sp["to"] = mid
	e["from"] = mid
	routine.insert(idx, sp)


static func generic_dialogue(personality: String) -> Dictionary:
	match personality:
		"grumpy":
			return {
				"start": {
					"text": "…무슨 일이죠? 바쁘니까 짧게 해 주세요.",
					"choices": [
						{"label": "길 좀 물을게요", "next": "road"},
						{"label": "죄송합니다", "next": ""},
					],
				},
				"road": {
					"text": "큰길 따라가면 광장이에요. 더 묻지 마세요.",
					"choices": [{"label": "고마워요", "next": ""}],
				},
			}
		"chatty":
			return {
				"start": {
					"text": "어머, 처음 뵙네! 이리 와서 얘기 좀 해요. 요즘 소문이 얼마나 많은지!",
					"variants": {"저녁": "하루 종일 돌아다녔더니 할 얘기가 한가득이에요!"},
					"choices": [
						{"label": "무슨 소문이요?", "next": "rumor"},
						{"label": "바빠서요", "next": ""},
					],
				},
				"rumor": {
					"text": "호텔 안내원이 요즘 이상하게 바쁘대요. 손님도 별로 없는데 말이죠. 아, 이건 비밀이에요!",
					"choices": [{"label": "알겠어요", "next": ""}],
				},
			}
		"shy":
			return {
				"start": {
					"text": "아, 안녕하세요… (고개를 살짝 숙인다)",
					"choices": [
						{"label": "괜찮아요?", "next": "ok"},
						{"label": "안녕히 가세요", "next": ""},
					],
				},
				"ok": {
					"text": "네, 낯선 분이라 조금 긴장했어요. 천천히 구경하세요.",
					"choices": [{"label": "고마워요", "next": ""}],
				},
			}
		"curious":
			return {
				"start": {
					"text": "어디서 오셨어요? 이 근처에서 처음 봐요.",
					"choices": [
						{"label": "여행 중이에요", "next": "trav"},
						{"label": "그냥요", "next": ""},
					],
				},
				"trav": {
					"text": "와, 멋져요! 광장 북쪽의 큰 건물이 볼 만해요. 해 질 무렵이 특히 좋아요.",
					"choices": [{"label": "고마워요", "next": ""}],
				},
			}
	return {
		"start": {
			"text": "안녕하세요! 오늘 날씨 참 좋죠?",
			"variants": {"저녁": "안녕하세요! 저녁 공기가 시원해서 산책하기 좋네요.", "밤": "안녕하세요. 밤길 조심하세요."},
			"choices": [
				{"label": "이 동네 어때요?", "next": "town"},
				{"label": "안녕히 계세요", "next": ""},
			],
		},
		"town": {
			"text": "조용하고 살기 좋아요. 광장 근처 찻집은 꼭 가 보세요.",
			"choices": [{"label": "고마워요", "next": ""}],
		},
	}
