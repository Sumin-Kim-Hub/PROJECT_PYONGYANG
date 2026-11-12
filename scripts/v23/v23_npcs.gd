extends RefCounted
## V2.3 새 NPC 와 대화 (중앙 청사 / 사저). 형식은 v22/v22_npcs.gd 와 같습니다.
## 이 도시와 인물은 모두 가상입니다. 최고지도자는 이 게임에 등장하지 않습니다 (모습·이름·대사 없음).
##  - 선택지 라벨은 짧게(9자 이하), 한 노드의 선택지는 최대 4개, 본문은 150자 이하. (Godot 실행 미검증)

const SK_A: Color = Color(0.86, 0.70, 0.58)
const SK_B: Color = Color(0.84, 0.68, 0.56)
const SK_C: Color = Color(0.80, 0.64, 0.52)


static func _look(sex: String, shirt: Color, pants: Color, hat: bool = false, hat_color: Color = Color(0.2, 0.2, 0.2), acc: String = "", height: float = 1.0, skin: Color = SK_A) -> Dictionary:
	return {"sex": sex, "height": height, "skin": skin, "shirt": shirt, "pants": pants,
		"hair": Color(0.09, 0.08, 0.08), "hat": hat, "hat_color": hat_color, "acc": acc}


static func _stay(pos: Vector3) -> Array:
	return [{"from": 0.0, "to": 24.0, "mode": "stand", "pos": pos, "radius": 0.0}]


static func _npc(id: String, nm: String, role: String, pos: Vector3, look: Dictionary, routine: Array, dialogue: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"id": id, "name": nm, "role": role, "speed": 1.1, "home": pos, "look": look, "routine": routine, "dialogue": dialogue}
	for k in extra.keys():
		d[k] = extra[k]
	return d


## 안쪽 NPC 3명 (slot 필드로 어느 실내인지 알려 줌: 13 청사 로비 / 13 비서실 / 14 사저 거실)
static func all() -> Array:
	var aide: Dictionary = {
		"entry": [
			{"if": {"flag": "pk_v23_aide_key"}, "node": "after_key"},
		],
		"start": {
			"text": "(서류에서 눈을 들지 않은 채) 접견 시간은 끝났습니다. 용무 없는 분이 올라올 수 있는 층이 아닌 줄 압니다만.",
			"choices": [
				{"label": "접견을 청한다", "next": "aud"},
				{"label": "사저가 궁금해", "next": "res"},
				{"label": "물러난다", "next": ""},
			],
		},
		"aud": {
			"text": "지도자께서는 오늘 지방 시찰 중이십니다. 돌아오시는 날은 저도 모릅니다. 늘 그렇습니다.",
			"choices": [{"label": "그렇군요", "next": ""}],
		},
		"res": {
			"text": "사저요? 열쇠 없이는 아무도 못 들어갑니다. 열쇠는 이 방 서랍에 있고, 서랍은 제가 지킵니다. …값을 칠 줄 아는 분이라면 이야기가 다르겠지요.",
			"choices": [
				{"label": "80원을 건넨다", "next": "bribe_ok", "if": [{"item_min": ["won", 80]}, {"not_item": "v23_res_key"}]},
				{"label": "돈이 없다", "next": ""},
			],
		},
		"bribe_ok": {
			"text": "(돈을 세어 서랍에 넣고, 작은 열쇠를 꺼내 책상 위에 둔다) 저는 아무것도 못 봤습니다. 사저에는 오래 계시지 마십시오.",
			"effects": [
				{"op": "take_item", "id": "won", "count": 80},
				{"op": "give_item", "id": "v23_res_key"},
				{"op": "set_flag", "key": "pk_v23_aide_key"},
				{"op": "quest_step", "id": "q_v23_leader", "step": 3},
			],
			"choices": [{"label": "고맙소", "next": ""}],
		},
		"after_key": {
			"text": "서랍은 이미 비어 있습니다. 저는 아무것도 못 봤고, 아무것도 모릅니다. 서두르십시오.",
			"choices": [{"label": "알겠소", "next": ""}],
		},
	}
	var guide: Dictionary = {
		"start": {
			"text": "어서 오십시오. 오늘은 접견이 없습니다. 청사 안내가 필요하십니까?",
			"choices": [
				{"label": "청사 안내", "next": "info"},
				{"label": "소문을 묻는다", "next": "rumor"},
				{"label": "물러난다", "next": ""},
			],
		},
		"info": {
			"text": "복도 끝이 집무실, 그 서쪽이 비서실입니다. 사저로 가는 문은 늘 잠겨 있고, 열쇠는 비서관님이 가지고 계시지요.",
			"choices": [{"label": "알겠소", "next": ""}],
		},
		"rumor": {
			"text": "사저 서재에는 일가만 아는 책장이 있다는 소문이 있어요. 저는 본 적 없습니다. 이런 얘기는 안 한 걸로 해 주세요.",
			"effects": [{"op": "set_flag", "key": "v23_hint_shelf"}, {"op": "toast", "text": "소문: 사저 서재의 책장이 수상하다."}],
			"choices": [{"label": "흥미롭군", "next": ""}],
		},
	}
	var steward: Dictionary = {
		"start": {
			"text": "(걸레질을 하던 노인이 흠칫 놀란다) …누구십니까. 여긴 사람이 오는 곳이 아닌데요.",
			"choices": [
				{"label": "길을 잃었소", "next": "lost"},
				{"label": "이 집은 어때요", "next": "house"},
				{"label": "조용히 해줘", "next": "quiet"},
			],
		},
		"lost": {
			"text": "길을 잃으셨다니… 모른 척하겠습니다. 이 나이에 참견할 일이 아닙니다.",
			"choices": [{"label": "고맙소", "next": ""}],
		},
		"house": {
			"text": "크고 넓은 집이지요. 그런데 사람은 거의 없습니다. 한 사람이 쓰는 방이 열 칸이 넘는데, 그 얼굴은 저도 못 본 지 오래입니다.",
			"choices": [
				{"label": "서재는요?", "next": "study"},
				{"label": "그렇군요", "next": ""},
			],
		},
		"study": {
			"text": "서재는 동쪽입니다. …책장 하나는 늘 먼지가 없지요. 아무것도 묻지 마세요. 저는 닦으라는 대로 닦을 뿐입니다.",
			"effects": [{"op": "set_flag", "key": "v23_hint_shelf"}, {"op": "toast", "text": "단서: 동쪽 서재의 먼지 없는 책장."}],
			"choices": [{"label": "알겠소", "next": ""}],
		},
		"quiet": {
			"text": "조용히 하라니… 알겠습니다. 저는 부엌에 있겠습니다. 오늘은 아무도 못 봤습니다.",
			"choices": [{"label": "고맙소", "next": ""}],
		},
	}
	return [
		_npc("v23_aide", "비서관 고성진", "청사 비서관 · 신중함", Vector3.ZERO,
			_look("m", Color(0.22, 0.24, 0.30), Color(0.14, 0.15, 0.18), false, Color(0.2, 0.2, 0.2), "glasses", 1.0, SK_B),
			_stay(Vector3.ZERO), aide, {"slot": 13, "at": Vector3(-12.5, 0.0, -22.5), "yaw_deg": 90.0}),
		_npc("v23_guide", "접견 안내원 배은하", "접견 안내원 · 친절함", Vector3.ZERO,
			_look("f", Color(0.62, 0.20, 0.20), Color(0.16, 0.16, 0.20), false, Color(0.2, 0.2, 0.2), "", 0.97, SK_A),
			_stay(Vector3.ZERO), guide, {"slot": 13, "at": Vector3(-4.6, 0.0, 3.4), "yaw_deg": 180.0}),
		_npc("v23_steward", "관리인 문덕수", "사저 관리인 · 소심함", Vector3.ZERO,
			_look("m", Color(0.55, 0.52, 0.46), Color(0.26, 0.24, 0.22), false, Color(0.2, 0.2, 0.2), "", 0.96, SK_C),
			_stay(Vector3.ZERO), steward, {"slot": 14, "at": Vector3(3.0, 0.0, -9.0), "yaw_deg": 180.0}),
	]
