extends RefCounted
## V2.2 새 NPC 목록과 대화. 형식은 data/npc_data.gd 와 같습니다.
## 이 도시와 인물은 모두 가상입니다. (Godot 실행 미검증)
##  - 대화 선택지 라벨은 짧게(약 8자). 한 노드의 선택지는 최대 4개.
##  - "gate": "north"|"base" 가 있는 NPC 는 world 가 검문소 경비 대화로 바꿔 줍니다.

const NpcData = preload("res://scripts/data/npc_data.gd")

const SK_A: Color = Color(0.86, 0.70, 0.58)
const SK_B: Color = Color(0.84, 0.68, 0.56)
const SK_C: Color = Color(0.80, 0.64, 0.52)
const UNI: Color = Color(0.30, 0.34, 0.24)
const UNI_D: Color = Color(0.20, 0.24, 0.16)


static func _look(sex: String, shirt: Color, pants: Color, hat: bool = false, hat_color: Color = Color(0.2, 0.2, 0.2), acc: String = "", height: float = 1.0, skin: Color = SK_A) -> Dictionary:
	return {"sex": sex, "height": height, "skin": skin, "shirt": shirt, "pants": pants,
		"hair": Color(0.09, 0.08, 0.08), "hat": hat, "hat_color": hat_color, "acc": acc}


static func _stay(pos: Vector3, mode: String = "stand", radius: float = 0.0) -> Array:
	return [{"from": 0.0, "to": 24.0, "mode": mode, "pos": pos, "radius": radius}]


static func _npc(id: String, nm: String, role: String, pos: Vector3, look: Dictionary, routine: Array, dialogue: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"id": id, "name": nm, "role": role, "speed": 1.1, "home": pos, "look": look, "routine": routine, "dialogue": dialogue}
	for k in extra.keys():
		d[k] = extra[k]
	return d


static func _bye() -> Dictionary:
	return {"label": "안녕히 계세요", "next": ""}


static func all() -> Array:
	var out: Array = []
	out.append_array(start_area())
	out.append_array(market())
	out.append_array(ruins_and_river())
	out.append_array(slum())
	out.append_array(plaza_south())
	out.append_array(zone())
	return out


# ---------------------------------------------------------------- 시작 지점 / 도시 중심

static func start_area() -> Array:
	var d_sun: Dictionary = {
		"entry": [
			{"if": {"quest": "q_v22_pass", "state": "active", "step": 0}, "node": "intro"},
		],
		"start": {
			"text": "안녕하세요. 이 동네 사람은 아니죠? 요즘은 어딜 가나 통행증, 통행증 하네요.",
			"choices": [
				{"label": "이 동네는요?", "next": "area"},
				{"label": "통행증 신청", "next": "apply"},
				_bye(),
			],
		},
		"intro": {
			"text": "처음 보는 얼굴이네요. 이 도시는 구역마다 통행증을 봐요. 북쪽 통제구역은 통행증 없이는 검문소를 못 지나가요. 서쪽 장마당의 한옥분 아주머니가 이런 일에 밝으니 한번 가 보세요. 값은 좀 불러도 믿을 만한 분이에요.",
			"effects": [
				{"op": "quest_step", "id": "q_v22_pass", "step": 1},
				{"op": "v22_intel", "key": "pass"},
				{"op": "v22_intel", "key": "market"},
			],
			"choices": [
				{"label": "통행증은 어떻게?", "next": "apply"},
				{"label": "고마워요", "next": ""},
			],
		},
		"area": {
			"text": "남쪽으로 쭉 내려가면 큰 광장이 새로 생겼어요. 서쪽 끝은 장마당과 낡은 폐건물, 동쪽 끝은 배급소와 판잣집 동네고요. 북쪽은 군인들이 지키는 통제구역이에요.",
			"choices": [{"label": "알겠어요", "next": "start"}],
		},
		"apply": {
			"text": "일반 통행증은 소개장과 수수료 50원이 있으면 제가 대신 신청해 줄 수 있어요. 찻집에서 받은 소개장 있죠?",
			"choices": [
				{"label": "신청(50원)", "next": "apply_ok", "if": [{"item": "intro_letter"}, {"item_min": ["won", 50]}, {"not_item": "pass_general"}]},
				{"label": "가진 게 없어요", "next": "apply_no"},
				{"label": "다음에요", "next": ""},
			],
		},
		"apply_ok": {
			"text": "자, 도장 받았어요. 기간 제한 없는 일반 통행증이에요. 다만 군사시설 안쪽은 이걸로 안 되니 조심하세요.",
			"effects": [
				{"op": "take_item", "id": "won", "count": 50},
				{"op": "take_item", "id": "intro_letter"},
				{"op": "v22_grant_pass", "id": "pass_general"},
			],
			"choices": [{"label": "감사합니다", "next": ""}],
		},
		"apply_no": {
			"text": "소개장은 찻집 주인 한미정 씨가 써 줘요. 돈은 장마당에서 물건을 팔아 마련할 수 있고요.",
			"choices": [{"label": "알겠어요", "next": ""}],
		},
	}
	return [
		_npc("lee_sunhui", "리순희", "주민 · 친절함", Vector3(14.0, 0.0, 40.0), _look("f", Color(0.55, 0.42, 0.40), Color(0.22, 0.2, 0.24), false, Color(0, 0, 0), "bag", 0.97),
			_stay(Vector3(14.0, 0.0, 40.0), "wander", 5.0), d_sun),
	]


# ---------------------------------------------------------------- 서쪽 장마당

static func market() -> Array:
	var d_han: Dictionary = {
		"entry": [
			{"if": {"quest": "q_v22_pass", "state": "active", "step": 1}, "node": "intro"},
		],
		"start": {
			"text": "어서 와요. 쌀, 약, 부품… 필요하면 다 있어요. 대신 외상은 안 받아요.",
			"choices": [
				{"label": "거래", "next": "v22_trade"},
				{"label": "장부 · 표식", "next": "goods"},
				{"label": "소문은요?", "next": "rumor"},
				_bye(),
			],
		},
		"intro": {
			"text": "리순희가 보냈다고요? …좋아요. 통행증은 내가 못 만들어요. 하지만 이 장마당 뒤 창고 바닥에 낡은 맨홀이 있죠. 아래에 돈 되는 문서가 있다는 소문이에요. 금고는 세 자리 암호, 폐건물과 강변과 내 장부에 숫자가 있고요.",
			"effects": [
				{"op": "quest_step", "id": "q_v22_pass", "step": 2},
				{"op": "v22_intel", "key": "manhole"},
				{"op": "v22_intel", "key": "code"},
			],
			"choices": [
				{"label": "장부를 보여줘요", "next": "goods"},
				{"label": "고마워요", "next": ""},
			],
		},
		"goods": {
			"text": "장부 한 장은 30원, 지하 사람들이 알아보는 '두더지 표식'은 40원이에요. 어디까지나 호기심 많은 손님께만요.",
			"choices": [
				{"label": "장부(30원)", "next": "buy_ledger", "if": [{"item_min": ["won", 30]}, {"not_item": "clue_c"}]},
				{"label": "표식(40원)", "next": "buy_token", "if": [{"item_min": ["won", 40]}, {"not_item": "mole_token"}, {"flag": "intel_manhole"}]},
				{"label": "다음에요", "next": ""},
			],
		},
		"buy_ledger": {
			"text": "자, 한 장 뜯어 줄게요. 마지막 줄을 잘 봐요.",
			"effects": [{"op": "take_item", "id": "won", "count": 30}, {"op": "give_item", "id": "clue_c"}, {"op": "set_flag", "key": "pk_clue_c"}],
			"choices": [{"label": "고마워요", "next": ""}],
		},
		"buy_token": {
			"text": "이걸 지하 문 앞에서 보여 주면 알아볼 거예요. 내가 줬다는 말은 하지 말고요.",
			"effects": [{"op": "take_item", "id": "won", "count": 40}, {"op": "give_item", "id": "mole_token"}],
			"choices": [{"label": "알겠어요", "next": ""}],
		},
		"rumor": {
			"text": "북쪽 보급관이 요즘 부쩍 돈이 많대요. 배급소는 늘 모자란다는데 말이죠.",
			"effects": [{"op": "v22_intel", "key": "oh"}],
			"choices": [{"label": "그렇군요", "next": ""}],
		},
	}
	var d_b: Dictionary = NpcData.generic_dialogue("chatty")
	var d_c: Dictionary = NpcData.generic_dialogue("grumpy")
	var d_porter: Dictionary = {
		"start": {
			"text": "짐이 무거워서 말 걸지 마쇼. …뒤쪽 창고에는 가지 마쇼. 거기 바닥이 좀 이상해.",
			"effects": [{"op": "v22_intel", "key": "manhole"}],
			"choices": [{"label": "알겠어요", "next": ""}],
		},
	}
	return [
		_npc("han_okbun", "한옥분", "장마당 상인 · 욕심 많음", Vector3(-300.0, 0.0, 0.0), _look("f", Color(0.62, 0.35, 0.30), Color(0.22, 0.2, 0.2), false, Color(0, 0, 0), "scarf", 0.96, SK_C),
			_stay(Vector3(-300.0, 0.0, 0.0)), d_han, {"yaw_deg": 0.0}),
		_npc("market_b", "차말순", "포목 상인 · 수다쟁이", Vector3(-318.0, 0.0, -2.0), _look("f", Color(0.30, 0.45, 0.55), Color(0.2, 0.2, 0.24), false, Color(0, 0, 0), "", 0.97),
			_stay(Vector3(-318.0, 0.0, -2.0)), d_b),
		_npc("market_c", "노병철", "생선 상인 · 무뚝뚝함", Vector3(-282.0, 0.0, 18.0), _look("m", Color(0.45, 0.45, 0.40), Color(0.22, 0.24, 0.2), true, Color(0.5, 0.5, 0.45), "", 1.0, SK_C),
			_stay(Vector3(-282.0, 0.0, 18.0)), d_c),
		_npc("porter_kim", "김만복", "짐꾼 · 소심함", Vector3(-310.0, 0.0, 38.0), _look("m", Color(0.4, 0.38, 0.3), Color(0.25, 0.25, 0.22), true, Color(0.35, 0.32, 0.25), "", 1.0, SK_C),
			_stay(Vector3(-310.0, 0.0, 36.0), "wander", 6.0), d_porter),
	]


# ---------------------------------------------------------------- 폐건물, 강변

static func ruins_and_river() -> Array:
	var d_jo: Dictionary = {
		"start": {
			"text": "…여기 3층에 살았지. 우리 식구가 처음 이사 온 층수는 잊어버릴 수가 없어. 지금은 아무도 안 와.",
			"effects": [{"op": "quest_start", "id": "q_v22_ruins"}],
			"choices": [
				{"label": "무슨 일이었죠?", "next": "past"},
				{"label": "금고를 아세요?", "next": "safe"},
				_bye(),
			],
		},
		"past": {
			"text": "어느 날 갑자기 사람들이 하나둘 떠났어. 물이 끊기고, 배급이 끊기고. 서랍 속 일기장은 아직 거기 있을걸.",
			"choices": [{"label": "알겠어요", "next": "start"}],
		},
		"safe": {
			"text": "아랫방 금고? 열쇠는 낡은 금고 밑에 숨겼지. 일기에 첫 숫자를 적어 뒀어. 가 보든가.",
			"effects": [{"op": "v22_intel", "key": "code"}],
			"choices": [{"label": "고맙습니다", "next": ""}],
		},
	}
	var d_ma: Dictionary = {
		"entry": [
			{"if": [{"quest": "q_v22_river", "state": "active", "step": 1}, {"item": "radio_part"}], "node": "fix"},
			{"if": {"quest": "q_v22_river", "state": "done"}, "node": "after"},
		],
		"start": {
			"text": "쉿, 낚싯대 흔들려요. …라디오가 고장 나서 심심하던 참이었는데, 진공관 하나만 구해다 줄래요?",
			"effects": [{"op": "quest_start", "id": "q_v22_river"}, {"op": "quest_step", "id": "q_v22_river", "step": 1}],
			"choices": [
				{"label": "구해 볼게요", "next": ""},
				{"label": "강은 어때요?", "next": "river"},
				_bye(),
			],
		},
		"river": {
			"text": "이 강 건너편은 군인들 구역이죠. 가끔 밤에 하수 배출구로 사람이 나왔다가 들어가요. 못 본 걸로 하세요.",
			"effects": [{"op": "v22_intel", "key": "boat"}],
			"choices": [{"label": "알겠어요", "next": "start"}],
		},
		"fix": {
			"text": "오오, 이거 맞아요! 잠깐만… (라디오에서 잡음이 사라지고 느린 음악이 흐른다) 고마워요. 이건 사례예요. 아주 오래된 훈장인데, 값이 꽤 나갈 거예요.",
			"effects": [
				{"op": "take_item", "id": "radio_part"},
				{"op": "quest_complete", "id": "q_v22_river"},
			],
			"choices": [{"label": "받을게요", "next": "after"}],
		},
		"after": {
			"text": "덕분에 라디오가 살아났어요. 낚시 수첩도 드릴게요. 거기 숫자 하나는 제가 적은 건데, 어디다 쓰는지는 몰라요.",
			"effects": [
				{"op": "give_item", "id": "clue_b", "if": {"not_flag": "pk_clue_b"}},
				{"op": "set_flag", "key": "pk_clue_b"},
				{"op": "v22_intel", "key": "base"},
			],
			"choices": [{"label": "고마워요", "next": ""}],
		},
	}
	return [
		_npc("old_man_jo", "조형배", "폐건물 노인 · 쓸쓸함", Vector3(-286.0, 0.0, 78.0), _look("m", Color(0.4, 0.38, 0.36), Color(0.2, 0.2, 0.2), true, Color(0.3, 0.3, 0.3), "", 0.95, SK_C),
			_stay(Vector3(-286.0, 0.0, 78.0)), d_jo),
		_npc("fisher_ma", "마두식", "낚시꾼 · 입이 무거움", Vector3(-160.0, 0.0, -137.0), _look("m", Color(0.32, 0.4, 0.36), Color(0.22, 0.24, 0.26), true, Color(0.55, 0.5, 0.4), "", 1.0, SK_C),
			_stay(Vector3(-160.0, 0.0, -137.0)), d_ma, {"yaw_deg": 0.0}),
	]


# ---------------------------------------------------------------- 동쪽 판잣집 동네

static func slum() -> Array:
	var d_bong: Dictionary = {
		"start": {
			"text": "아이가 사흘째 제대로 못 먹었어요. 배급은 늘 모자라고… 혹시 남는 식량이 있으세요?",
			"effects": [{"op": "quest_start", "id": "q_v22_slum"}],
			"choices": [
				{"label": "식량 건네기", "next": "feed", "if": [{"item": "food_ration"}, {"not_flag": "slum_fed_bong"}]},
				{"label": "사정이 어때요?", "next": "story"},
				_bye(),
			],
		},
		"feed": {
			"text": "(눈시울이 붉어진다) 정말… 정말 고마워요. 이 은혜 잊지 않을게요. 필요하면 부탁하세요.",
			"effects": [
				{"op": "take_item", "id": "food_ration"},
				{"op": "set_flag", "key": "slum_fed_bong"},
				{"op": "trust", "id": "bong_sun", "delta": 2},
			],
			"choices": [{"label": "별말씀을요", "next": ""}],
		},
		"story": {
			"text": "배급소 담당이 물자를 빼돌린대요. 북쪽 보급관과 한패라는 말도 있고요. 증거가 없으니 아무도 말을 못 해요.",
			"effects": [{"op": "v22_intel", "key": "oh"}],
			"choices": [{"label": "알아볼게요", "next": "start"}],
		},
	}
	var d_cho: Dictionary = {
		"start": {
			"text": "형, 누나! 쉿, 작게 말해요. 장마당 뒤 창고 맨홀, 알아요? 어른들은 모르는 척하는데.",
			"effects": [{"op": "v22_intel", "key": "manhole"}],
			"choices": [
				{"label": "식량 건네기", "next": "feed", "if": [{"item": "food_ration"}, {"not_flag": "slum_fed_cho"}]},
				{"label": "다른 길은?", "next": "path"},
				_bye(),
			],
		},
		"feed": {
			"text": "우와, 진짜 먹어도 돼요?! 고마워요! 비밀 하나 알려 줄게요. 강가 낚시 아저씨가 밤에 사람들을 몰래 건네줘요.",
			"effects": [
				{"op": "take_item", "id": "food_ration"},
				{"op": "set_flag", "key": "slum_fed_cho"},
				{"op": "trust", "id": "cho_boy", "delta": 2},
				{"op": "v22_intel", "key": "boat"},
			],
			"choices": [{"label": "고마워", "next": ""}],
		},
		"path": {
			"text": "북쪽 군인 구역 바깥 담벼락 밑에 하수구가 있어요. 맨홀로 이어진대요.",
			"choices": [{"label": "그렇구나", "next": "start"}],
		},
	}
	var d_lee: Dictionary = {
		"start": {
			"text": "…허리가 아파서 줄을 서 있을 수가 없구려. 오늘도 굶는 건가 싶었는데.",
			"choices": [
				{"label": "식량 건네기", "next": "feed", "if": [{"item": "food_ration"}, {"not_flag": "slum_fed_old"}]},
				_bye(),
			],
		},
		"feed": {
			"text": "이렇게 고마울 수가… 젊은이, 복 받을 게요.",
			"effects": [
				{"op": "take_item", "id": "food_ration"},
				{"op": "set_flag", "key": "slum_fed_old"},
				{"op": "trust", "id": "slum_old", "delta": 2},
			],
			"choices": [{"label": "건강하세요", "next": ""}],
		},
	}
	var d_clerk: Dictionary = {
		"start": {
			"text": "배급 담당입니다. 줄 서서 순서를 기다리세요. 물자는 늘 한정적이에요.",
			"choices": [
				{"label": "배급 받기", "next": "ration", "if": [{"flag": "ration_open"}, {"not_flag": "ration_taken"}]},
				{"label": "왜 모자라죠?", "next": "why"},
				_bye(),
			],
		},
		"ration": {
			"text": "오늘 몫은 이겁니다. 한 번만 가져가세요.",
			"effects": [{"op": "give_item", "id": "food_ration"}, {"op": "set_flag", "key": "ration_taken"}],
			"choices": [{"label": "고맙습니다", "next": ""}],
		},
		"why": {
			"text": "…위에서 내려오는 양이 정해져 있어요. 장부는 보급관 쪽에서 쥐고 있고요. 더는 묻지 마세요.",
			"effects": [{"op": "v22_intel", "key": "oh"}],
			"choices": [{"label": "알겠어요", "next": ""}],
		},
	}
	return [
		_npc("bong_sun", "봉순이네", "판잣집 주민 · 지침", Vector3(300.0, 0.0, 14.0), _look("f", Color(0.50, 0.40, 0.34), Color(0.26, 0.24, 0.22), false, Color(0, 0, 0), "scarf", 0.95, SK_C),
			_stay(Vector3(300.0, 0.0, 14.0), "wander", 4.0), d_bong),
		_npc("cho_boy", "철이", "소년 · 소심함 · 호기심", Vector3(318.0, 0.0, 30.0), _look("m", Color(0.42, 0.40, 0.32), Color(0.28, 0.26, 0.24), false, Color(0, 0, 0), "", 0.7, SK_C),
			_stay(Vector3(318.0, 0.0, 30.0), "wander", 5.0), d_cho),
		_npc("slum_old", "이노인", "판잣집 노인 · 허약함", Vector3(332.0, 0.0, -2.0), _look("m", Color(0.36, 0.34, 0.32), Color(0.22, 0.22, 0.22), true, Color(0.3, 0.3, 0.3), "", 0.92, SK_C),
			_stay(Vector3(332.0, 0.0, -2.0)), d_lee),
		_npc("ration_clerk", "방금자", "배급 담당 · 냉정", Vector3(266.0, 0.0, 34.0), _look("f", Color(0.30, 0.34, 0.30), Color(0.2, 0.22, 0.2), true, Color(0.3, 0.34, 0.3), "", 0.98),
			_stay(Vector3(266.0, 0.0, 34.0)), d_clerk, {"yaw_deg": 90.0}),
		_npc("queue_a", "줄 선 주민", "주민 · 지침", Vector3(262.0, 0.0, 44.0), _look("f", Color(0.45, 0.4, 0.4), Color(0.25, 0.24, 0.24)),
			_stay(Vector3(262.0, 0.0, 44.0)), NpcData.generic_dialogue("shy")),
		_npc("queue_b", "줄 선 노동자", "노동자 · 무뚝뚝함", Vector3(262.0, 0.0, 49.0), _look("m", Color(0.4, 0.4, 0.36), Color(0.24, 0.24, 0.22), true, Color(0.4, 0.4, 0.36)),
			_stay(Vector3(262.0, 0.0, 49.0)), NpcData.generic_dialogue("grumpy")),
	]


# ---------------------------------------------------------------- 남쪽 신도심 광장

static func plaza_south() -> Array:
	var d_guard: Dictionary = {
		"start": {
			"text": "광장 질서 유지 중입니다. 통제구역은 북쪽에 있으니 이쪽은 걱정 마십시오.",
			"choices": [
				{"label": "통제구역이요?", "next": "zone"},
				_bye(),
			],
		},
		"zone": {
			"text": "북쪽 끝 검문소에서 통행증을 확인합니다. 통행증이 없으면 아무리 부탁해도 소용없습니다.",
			"effects": [{"op": "v22_intel", "key": "pass"}],
			"choices": [{"label": "알겠습니다", "next": ""}],
		},
	}
	return [
		_npc("plaza_guard", "광장 경비 도현", "광장 경비 · 엄격함", Vector3(0.0, 0.0, 280.0), _look("m", UNI, UNI_D, true, UNI_D, "", 1.04, SK_B),
			_stay(Vector3(0.0, 0.0, 280.0), "wander", 4.0), d_guard),
		_npc("sq_a", "신도심 주민 연희", "주민 · 호기심", Vector3(-30.0, 0.0, 300.0), _look("f", Color(0.55, 0.3, 0.35), Color(0.2, 0.2, 0.26), false, Color(0, 0, 0), "bag"),
			_stay(Vector3(-30.0, 0.0, 300.0), "wander", 14.0), NpcData.generic_dialogue("curious")),
		_npc("sq_b", "신도심 주민 태수", "주민 · 수다쟁이", Vector3(32.0, 0.0, 306.0), _look("m", Color(0.34, 0.4, 0.5), Color(0.22, 0.22, 0.26)),
			_stay(Vector3(32.0, 0.0, 306.0), "wander", 14.0), NpcData.generic_dialogue("chatty")),
		_npc("apt_res", "아파트 주민 은정", "아파트 주민 · 친절함", Vector3(190.0, 0.0, 280.0), _look("f", Color(0.4, 0.5, 0.4), Color(0.22, 0.22, 0.24)),
			_stay(Vector3(190.0, 0.0, 282.0), "wander", 12.0), NpcData.generic_dialogue("default")),
	]


# ---------------------------------------------------------------- 북쪽 통제구역, 군사시설

static func zone() -> Array:
	var d_oh: Dictionary = {
		"entry": [
			{"if": {"flag": "oh_arrested"}, "node": "gone"},
			{"if": {"flag": "oh_deal_done"}, "node": "deal_after"},
		],
		"start": {
			"text": "무슨 일이오? 나는 보급 업무로 바쁜 사람이오. 용건만 말하시오.",
			"choices": [
				{"label": "통행증이 필요해", "next": "pass_req"},
				{"label": "문서를 보인다", "next": "blackmail", "if": {"item": "doc_shipping"}},
				{"label": "떠나기", "next": ""},
			],
		},
		"pass_req": {
			"text": "통행증? 내가 정식으로 줄 수 있는 건 없소. …(주위를 살피며) 값에 따라 하루짜리 임시증은 마련해 볼 수도.",
			"choices": [
				{"label": "임시증(100원)", "next": "sell_temp", "if": [{"item_min": ["won", 100]}, {"not_item": "pass_temp"}]},
				{"label": "돈이 없어", "next": ""},
			],
		},
		"sell_temp": {
			"text": "(돈을 센 뒤 도장 찍힌 종이를 건넨다) 하루 안에 쓰시오. 나는 모르는 일이오.",
			"effects": [
				{"op": "take_item", "id": "won", "count": 100},
				{"op": "v22_grant_pass", "id": "pass_temp"},
			],
			"choices": [{"label": "알겠다", "next": ""}],
		},
		"blackmail": {
			"text": "…!! 그, 그건 어디서 났소. 무슨 짓을 하려는 거요. …알았소. 원하는 걸 말해 보시오.",
			"choices": [
				{"label": "통행증과 입막음", "next": "deal"},
				{"label": "아무것도 아니다", "next": ""},
			],
		},
		"deal": {
			"text": "(떨리는 손으로 임시 통행증과 돈을 건넨다) 이걸로 끝이오. 그 문서는… 제발 다른 데 보이지 마시오.",
			"effects": [
				{"op": "take_item", "id": "doc_shipping"},
				{"op": "v22_grant_pass", "id": "pass_temp"},
				{"op": "give_item", "id": "won", "count": 80},
				{"op": "set_flag", "key": "oh_deal_done"},
				{"op": "quest_step", "id": "q_v22_pass", "step": 5, "if": {"quest": "q_v22_pass", "state": "active", "min_step": 3}},
			],
			"choices": [{"label": "거래 성사", "next": ""}],
		},
		"deal_after": {
			"text": "또 무슨 일이오. 더는 줄 것도 없소. 나를 건드리지 마시오.",
			"choices": [{"label": "물러난다", "next": ""}],
		},
		"gone": {
			"text": "(초소는 비어 있고 다른 군인이 자리를 지키고 있다) 보급관은 조사 중입니다. 접근하지 마십시오.",
			"choices": [{"label": "알겠습니다", "next": ""}],
		},
	}
	var d_ryu: Dictionary = {
		"entry": [
			{"if": {"flag": "ryu_helped"}, "node": "after"},
		],
		"start": {
			"text": "민간인이 어떻게 이 구역에 들어왔소? …통행증은 확인했소만, 용건이 무엇이오.",
			"effects": [{"op": "quest_step", "id": "q_v22_pass", "step": 6, "if": {"quest": "q_v22_pass", "state": "active", "min_step": 4}}],
			"choices": [
				{"label": "반출 명세서", "next": "give_ship", "if": [{"item": "doc_shipping"}, {"not_flag": "oh_deal_done"}]},
				{"label": "교대 명단", "next": "give_roster", "if": {"item": "doc_roster"}},
				{"label": "도움이 필요하다", "next": "need"},
				{"label": "떠나기", "next": ""},
			],
		},
		"need": {
			"text": "서류도 없이 도움을 청하다니. 증거를 가져오시오. 지하 어딘가에 증거가 있다는 소문은 나도 들었소.",
			"effects": [{"op": "v22_intel", "key": "base"}],
			"choices": [{"label": "알겠다", "next": ""}],
		},
		"give_ship": {
			"text": "…이게 사실이라면 보급관은 끝이오. 협조에 감사하오. 약속하지. 특별 통행증을 내주겠소. 안쪽 문은 조심하시오. 사령부에는 믿을 수 없는 자들이 있소.",
			"effects": [
				{"op": "take_item", "id": "doc_shipping"},
				{"op": "set_flag", "key": "oh_arrested"},
				{"op": "set_flag", "key": "ryu_helped"},
				{"op": "give_item", "id": "won", "count": 120},
				{"op": "v22_grant_pass", "id": "pass_special"},
				{"op": "trust", "id": "officer_ryu", "delta": 3},
			],
			"choices": [{"label": "감사합니다", "next": ""}],
		},
		"give_roster": {
			"text": "경비 교대 명단이라… 누가 자리를 비우는지 아는 사람이라면 쓸모가 있겠소. 신세를 졌소. 이걸 가져가시오.",
			"effects": [
				{"op": "take_item", "id": "doc_roster"},
				{"op": "set_flag", "key": "ryu_helped"},
				{"op": "v22_grant_pass", "id": "pass_special"},
				{"op": "trust", "id": "officer_ryu", "delta": 2},
			],
			"choices": [{"label": "감사합니다", "next": ""}],
		},
		"after": {
			"text": "안쪽 문을 지나거든 사령부 쪽은 오래 머물지 마시오. 비상 사이렌이 울리면 뒷문과 배수구를 기억하시오.",
			"effects": [{"op": "v22_intel", "key": "boat"}],
			"choices": [{"label": "명심하겠다", "next": ""}],
		},
	}
	var d_mole: Dictionary = {
		"start": {
			"text": "표식을 가져왔군. 여긴 없는 곳이다. 무엇이 필요하지?",
			"choices": [
				{"label": "거래", "next": "v22_trade"},
				{"label": "위조 통행증", "next": "forge"},
				{"label": "정보", "next": "info"},
				_bye(),
			],
		},
		"forge": {
			"text": "용지 80원, 특수 잉크 40원, 만드는 값 40원이다. 낡은 직인이 있으면 완성도가 올라간다.",
			"choices": [
				{"label": "용지(80)", "next": "buy_blank", "if": [{"item_min": ["won", 80]}, {"not_item": "forged_blank"}]},
				{"label": "잉크(40)", "next": "buy_ink", "if": [{"item_min": ["won", 40]}, {"not_item": "forge_ink"}]},
				{"label": "만들기(40)", "next": "make", "if": [{"item": "forged_blank"}, {"item": "forge_ink"}, {"item_min": ["won", 40]}]},
				{"label": "그만둔다", "next": ""},
			],
		},
		"buy_blank": {
			"text": "빈 용지다. 흔적을 남기지 마라.",
			"effects": [{"op": "take_item", "id": "won", "count": 80}, {"op": "give_item", "id": "forged_blank"}],
			"choices": [{"label": "알겠다", "next": "forge"}],
		},
		"buy_ink": {
			"text": "마르기 전에 써라.",
			"effects": [{"op": "take_item", "id": "won", "count": 40}, {"op": "give_item", "id": "forge_ink"}],
			"choices": [{"label": "알겠다", "next": "forge"}],
		},
		"make": {
			"dyn": "v22_result", "text": "...",
			"effects": [{"op": "v22_forge", "cost": 40}],
			"choices": [{"label": "알겠다", "next": ""}],
		},
		"info": {
			"text": "검문소 경비도 사람이다. 밤에는 느슨하고, 돈을 좋아하는 놈이 있다. 안쪽 문은 다르다. 특별증이 아니면 위조는 절반도 안 통한다.",
			"effects": [{"op": "v22_intel", "key": "base"}],
			"choices": [{"label": "고맙다", "next": ""}],
		},
	}
	var gate_look: Dictionary = _look("m", UNI, UNI_D, true, UNI_D, "", 1.05, SK_B)
	var out: Array = [
		_npc("supply_oh", "오문철", "보급관 · 탐욕스러움", Vector3(-24.0, 0.0, -236.0), _look("m", Color(0.34, 0.38, 0.28), Color(0.22, 0.26, 0.2), true, Color(0.3, 0.34, 0.24), "", 1.02, SK_B),
			_stay(Vector3(-24.0, 0.0, -236.0)), d_oh, {"yaw_deg": 0.0}),
		_npc("officer_ryu", "류성진", "연락장교 · 강직 · 엄격함", Vector3(-34.0, 0.0, -292.0), _look("m", Color(0.26, 0.32, 0.22), Color(0.18, 0.22, 0.15), true, Color(0.22, 0.28, 0.18), "", 1.06, SK_B),
			_stay(Vector3(-34.0, 0.0, -292.0)), d_ryu, {"yaw_deg": 90.0}),
		_npc("mole", "두더지", "암거래상 · 눈치 빠름", Vector3.ZERO, _look("m", Color(0.2, 0.2, 0.24), Color(0.16, 0.16, 0.18), true, Color(0.14, 0.14, 0.16), "scarf", 0.98, SK_C),
			_stay(Vector3.ZERO), d_mole, {"slot_npc": "mole"}),
		# 검문소 A (일반 / 임시 / 특별 / 위조)
		_npc("gate_a1", "검문소 병사 석훈", "검문소 군인 · 엄격함", Vector3(4.0, 0.0, -246.0), gate_look,
			_stay(Vector3(4.0, 0.0, -246.0)), {}, {"gate": "north", "yaw_deg": 180.0}),
		_npc("gate_a2", "검문소 병사 재룡", "검문소 군인 · 무뚝뚝함", Vector3(-4.0, 0.0, -246.0), gate_look,
			_stay(Vector3(-4.0, 0.0, -246.0)), {}, {"gate": "north", "yaw_deg": 180.0, "no_dialogue": true}),
		# 군사시설 안쪽 문 B
		_npc("gate_b1", "정문 병사 용철", "정문 군인 · 엄격함", Vector3(4.0, 0.0, -322.0), gate_look,
			_stay(Vector3(4.0, 0.0, -322.0)), {}, {"gate": "base", "yaw_deg": 180.0}),
		_npc("gate_b2", "정문 병사 광민", "정문 군인 · 냉정", Vector3(-4.0, 0.0, -322.0), gate_look,
			_stay(Vector3(-4.0, 0.0, -322.0)), {}, {"gate": "base", "yaw_deg": 180.0, "no_dialogue": true}),
	]
	# 순찰병 (시야가 있어 들키면 붙잡힘)
	var pl: Dictionary = _look("m", UNI, UNI_D, true, UNI_D, "", 1.05, SK_B)
	out.append(_patrol("zone_p1", "순찰병 하준", Vector3(-80.0, 0.0, -270.0), [Vector3(-100.0, 0.0, -270.0), Vector3(-40.0, 0.0, -270.0), Vector3(-40.0, 0.0, -300.0), Vector3(-100.0, 0.0, -300.0)], pl))
	out.append(_patrol("zone_p2", "순찰병 지호", Vector3(90.0, 0.0, -275.0), [Vector3(60.0, 0.0, -270.0), Vector3(130.0, 0.0, -270.0), Vector3(130.0, 0.0, -305.0), Vector3(60.0, 0.0, -305.0)], pl))
	out.append(_patrol("base_p1", "경비병 도윤", Vector3(-60.0, 0.0, -345.0), [Vector3(-90.0, 0.0, -340.0), Vector3(-30.0, 0.0, -340.0), Vector3(-30.0, 0.0, -370.0), Vector3(-90.0, 0.0, -370.0)], pl))
	out.append(_patrol("base_p2", "경비병 시우", Vector3(60.0, 0.0, -345.0), [Vector3(30.0, 0.0, -340.0), Vector3(90.0, 0.0, -340.0), Vector3(90.0, 0.0, -370.0), Vector3(30.0, 0.0, -370.0)], pl))
	return out


static func _patrol(id: String, nm: String, start: Vector3, path: Array, look: Dictionary) -> Dictionary:
	var routine: Array = [{"from": 0.0, "to": 24.0, "mode": "patrol", "pos": start, "radius": 0.0, "path": path, "pause": 2.0}]
	var d: Dictionary = _npc(id, nm, "순찰 군인 · 경계", start, look, routine, {}, {"vision_range": 14.0, "vision_fov": 90.0, "no_talk": true})
	d["patrol_path"] = path
	return d
