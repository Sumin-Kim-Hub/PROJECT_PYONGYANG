extends RefCounted
## V2 데이터: 평양역 안내원 대화(선택에 따라 결과가 갈림), 추가 NPC 정의.
## 이 세계의 인물과 장소는 모두 가상입니다.

## 평양역 안내원 김혜정 (역 대합실 안내 데스크).
## 경비실 문을 여는 방법이 네 가지: 선물 / 신뢰 / 위협 / 포기 → flag 로 뒤의 이야기가 달라짐
const STATION_CLERK = {
	"id": "station_clerk", "name": "김혜정", "role": "평양역 안내원 · 신중함", "speed": 0.0,
	"look": {"sex": "f", "height": 0.98, "skin": Color(0.88, 0.72, 0.6), "shirt": Color(0.18, 0.28, 0.42), "pants": Color(0.14, 0.14, 0.18), "hair": Color(0.1, 0.08, 0.08), "hat": true, "hat_color": Color(0.18, 0.28, 0.42), "acc": "scarf"},
	"dialogue": {
		"entry": [
			{"if": [{"quest": "q_station", "state": "done"}, {"flag": "station_ending_take"}], "node": "after_take"},
			{"if": [{"quest": "q_station", "state": "done"}, {"flag": "station_ending_leave"}], "node": "after_leave"},
			{"if": [{"flag": "station_threat"}, {"quest": "q_station", "state": "active"}], "node": "hostile"},
			{"if": {"flag": "unlock_station_guard"}, "node": "after_open"},
		],
		"start": {
			"text": "어서 오세요, 평양역입니다. 열차 시간은 저쪽 전광판에 있어요.",
			"variants": {"저녁": "저녁 열차 손님이 많아지는 시간이에요.", "밤": "야간 열차는 몇 편 없어요. 대합실은 조용하죠."},
			"choices": [
				{"label": "역에 대해 알려 주세요", "next": "about"},
				{"label": "경비실이 궁금해요", "next": "guard_q"},
				{"label": "안녕히 계세요", "next": ""},
			],
		},
		"about": {
			"text": "이 역은 오래된 건물이에요. 시계탑이 상징이죠. 지하에 화물 창고가 있다는 얘기도 있지만, 저는 가 본 적 없어요.",
			"choices": [{"label": "고마워요", "next": ""}],
		},
		"guard_q": {
			"text": "경비실이요? 직원 전용이에요. …왜 물으시죠? 야간 열차 얘기를 어디서 들으셨나 보네요.",
			"effects": [{"op": "quest_start", "id": "q_station"}],
			"choices": [
				{"label": "호의를 보인다", "next": "g_kind"},
				{"label": "사정을 솔직히 말한다", "next": "g_trust", "if": {"flag": "trust_station_clerk"}},
				{"label": "문을 열라고 위협한다", "next": "g_threat"},
				{"label": "그만두기", "next": ""},
			],
		},
		"g_kind": {
			"text": "…빈손으로 오신 건 아니죠? 작은 성의라도 있으면 얘기가 달라질 수 있어요.",
			"choices": [
				{"label": "사탕을 건넨다", "next": "g_gift", "if": {"item": "gift_sweets"}},
				{"label": "차를 건넨다", "next": "g_gift2", "if": {"item": "gift_tea"}},
				{"label": "아무것도 없다", "next": "g_nothing", "if": [{"not_item": "gift_sweets"}, {"not_item": "gift_tea"}]},
			],
		},
		"g_gift": {
			"text": "어머, 사탕이네요. 고마워요. …좋아요, 저도 그 얘기는 마음에 걸렸어요. 경비실 문은 열어 둘게요. 오래 있지는 마세요.",
			"effects": [
				{"op": "take_item", "id": "gift_sweets"},
				{"op": "trust", "id": "station_clerk", "delta": 2},
				{"op": "unlock_door", "id": "station_guard"},
				{"op": "set_flag", "key": "station_kind_path"},
				{"op": "quest_step", "id": "q_station", "step": 1, "if": {"quest": "q_station", "state": "active", "step": 0}},
			],
			"choices": [{"label": "고마워요", "next": ""}],
		},
		"g_gift2": {
			"text": "이 차, 제가 좋아하는 거예요. …알겠어요. 경비실 문은 열어 둘게요. 오래 있지는 마세요.",
			"effects": [
				{"op": "take_item", "id": "gift_tea"},
				{"op": "trust", "id": "station_clerk", "delta": 2},
				{"op": "unlock_door", "id": "station_guard"},
				{"op": "set_flag", "key": "station_kind_path"},
				{"op": "quest_step", "id": "q_station", "step": 1, "if": {"quest": "q_station", "state": "active", "step": 0}},
			],
			"choices": [{"label": "고마워요", "next": ""}],
		},
		"g_nothing": {
			"text": "그럼 안 돼요. 다음에는 작은 선물이라도 가져오세요. 상점이나 역 매점에서 구할 수 있을 거예요.",
			"choices": [{"label": "알겠어요", "next": ""}],
		},
		"g_trust": {
			"text": "…당신이 그동안 보여 준 걸 보면 나쁜 사람은 아닌 것 같아요. 경비실 문, 열어 둘게요. 사물함에 창고 열쇠가 있다고 들었어요.",
			"effects": [
				{"op": "unlock_door", "id": "station_guard"},
				{"op": "set_flag", "key": "station_kind_path"},
				{"op": "trust", "id": "station_clerk", "delta": 1},
				{"op": "quest_step", "id": "q_station", "step": 1, "if": {"quest": "q_station", "state": "active", "step": 0}},
			],
			"choices": [{"label": "고맙습니다", "next": ""}],
		},
		"g_threat": {
			"text": "(안색이 굳는다) …알겠어요, 알겠다고요. 문은 열어 줄 테니 소리 지르지 마세요. 하지만 나는 당신을 기억할 거예요.",
			"effects": [
				{"op": "unlock_door", "id": "station_guard"},
				{"op": "set_flag", "key": "station_threat"},
				{"op": "trust", "id": "station_clerk", "delta": -3},
				{"op": "alert", "kind": "threaten", "severity": 1.2},
				{"op": "quest_step", "id": "q_station", "step": 1, "if": {"quest": "q_station", "state": "active", "step": 0}},
			],
			"choices": [{"label": "…", "next": ""}],
		},
		"hostile": {
			"text": "또 오셨군요. 문은 이미 열어 드렸잖아요. 더 이상 말 걸지 마세요.",
			"choices": [{"label": "…", "next": ""}],
		},
		"after_open": {
			"text": "경비실 문은 열려 있어요. 안쪽 일은 저는 모르는 걸로 할게요.",
			"choices": [{"label": "알겠어요", "next": ""}],
		},
		"after_take": {
			"text": "…기록을 가져가셨군요. 이제 이 역이 예전 같지 않을 거예요. 부디 조심하세요.",
			"choices": [{"label": "고마웠어요", "next": ""}],
		},
		"after_leave": {
			"text": "아무것도 건드리지 않고 나오셨다는 얘기를 들었어요. 그래서 믿어요. 저도 언젠가 용기가 나면 직접 말할게요.",
			"choices": [{"label": "고마워요", "next": ""}],
		},
	},
}


## 평양역 대합실의 순찰 경비 (창고 근처를 오감)
static func station_guard(origin: Vector3) -> Dictionary:
	return {
		"id": "station_guard_npc", "name": "경비", "role": "역 경비 · 순찰", "speed": 1.3,
		"look": {"height": 1.03, "skin": Color(0.84, 0.68, 0.56), "shirt": Color(0.22, 0.26, 0.3), "pants": Color(0.14, 0.16, 0.2),
			"hair": Color(0.06, 0.06, 0.06), "hat": true, "hat_color": Color(0.22, 0.26, 0.3), "acc": ""},
		"vision_range": 9.0, "vision_fov": 80.0, "no_talk": true,
		"home": origin + Vector3(16.3, 0.05, -3.0),
		# 밤(20~6시)에만 창고를 순찰하고, 낮에는 퇴근해서 보이지 않음
		"routine": [
			{"from": 20.0, "to": 6.0, "mode": "patrol", "pos": origin + Vector3(16.3, 0.05, -9.5), "radius": 0.0,
				"path": [origin + Vector3(14.5, 0.05, -9.5), origin + Vector3(18.5, 0.05, -9.5)], "pause": 2.0},
			{"from": 6.0, "to": 20.0, "mode": "home", "pos": origin + Vector3(16.3, 0.05, -3.0), "radius": 0.0},
		],
	}
