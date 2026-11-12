extends Node
## 사회 시스템 (V1): 신뢰도, 소문, 대화 보강.
##  - NPC 마다 신뢰도(-3 ~ +5). 대화를 하면 조금씩 오르고, 소란을 일으키면 내려갑니다.
##    신뢰가 낮으면 말을 걸어도 거부하고, 높으면 비밀스러운 소문을 알려 줍니다.
##  - 기존 NPC 의 대화에 "요즘 소문은?" 선택지를 덧붙이고, 도시 경계 단계가 높으면 다른 말을 합니다.
##  - 들은 소문은 지도 화면의 '소문' 목록과 퀘스트/단서에 반영됩니다.
## 대화 데이터는 npc.dialogue (복사본)에만 덧붙이며, 원본 npc_data.gd 는 바꾸지 않습니다.

const VData = preload("res://scripts/v1/v1_data.gd")

var hub = null
var v1 = null
var trust: Dictionary = {}
var known: Dictionary = {}
var rumor_log: Array = []

var _last_period: Dictionary = {}
var _nervous: bool = false


func setup(p_hub, p_v1) -> void:
	hub = p_hub
	v1 = p_v1


# ---------------------------------------------------------------- 대화 보강

## 이미 만들어진 모든 NPC 의 대화에 소문/거부/경계 반응을 덧붙임 (여러 번 불러도 한 번만 적용)
func augment_all() -> void:
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n):
			augment(n)


func augment(npc) -> void:
	if npc.has_meta("v1_aug"):
		return
	npc.set_meta("v1_aug", true)
	if npc.no_talk or npc.dialogue.is_empty() or not npc.dialogue.has("start"):
		return
	var d: Dictionary = npc.dialogue
	var id: String = npc.npc_id
	d["v1_rumor"] = {
		"dyn": "rumor", "text": "...",
		"choices": [
			{"label": "고마워요", "next": ""},
			{"label": "또 다른 소문은요?", "next": "v1_rumor"},
		],
	}
	d["v1_refuse"] = {"text": "…말 걸지 마세요. 당신은 믿을 수 없어요.", "next": ""}
	d["v1_alert"] = {"dyn": "alert", "text": "...", "next": ""}

	var start: Dictionary = d["start"]
	var ch: Array = start.get("choices", [])
	if ch.size() > 0 and ch.size() < 3:
		ch.insert(ch.size() - 1, {"label": "요즘 소문은?", "next": "v1_rumor"})
		start["choices"] = ch

	var entry: Array = d.get("entry", [])
	entry.insert(0, {"if": {"flag": "distrust_" + id}, "node": "v1_refuse"})
	entry.insert(0, {"if": {"flag": "alert_l3"}, "node": "v1_alert"})
	d["entry"] = entry


## 대화 노드의 "dyn" 값에 따라 실행 중 만들어지는 대사
func dynamic_text(kind: String, npc) -> String:
	if kind == "alert":
		var lv: int = 0
		if v1 != null and v1.alert != null:
			lv = v1.alert.level
		return str(VData.ALERT_LINES.get(clampi(lv, 1, 4), "..."))
	if kind == "rumor":
		return _tell_rumor(npc)
	return "..."


func _tell_rumor(npc) -> String:
	var period: String = hub.clock.period_name() if hub != null and hub.clock != null else "낮"
	var t: int = get_trust(npc.npc_id) if npc != null else 0
	var fresh: Array = []
	for r in VData.RUMORS:
		if known.has(str(r["id"])):
			continue
		var w: Array = r.get("when", [])
		if w.size() > 0 and not w.has(period):
			continue
		if int(r.get("trust", 0)) > t:
			continue
		fresh.append(r)
	if fresh.is_empty():
		# 시간/신뢰 때문에 못 들은 소문이 남았는지 힌트
		for r2 in VData.RUMORS:
			if not known.has(str(r2["id"])):
				if int(r2.get("trust", 0)) > t:
					return "음… 더 해 줄 얘기가 있긴 한데, 아직은 당신을 잘 몰라서요."
				return "그 얘기는 아침, 낮, 저녁, 밤 중 다른 때에 들어 보는 게 좋겠어요."
		return "이제 해 줄 소문은 다 했어요."
	var pick: Dictionary = fresh[randi() % fresh.size()]
	_learn(pick)
	return str(pick["text"])


func _learn(r: Dictionary) -> void:
	var id: String = str(r["id"])
	known[id] = true
	rumor_log.append(str(r["text"]))
	var fl: String = str(r.get("flag", ""))
	if fl != "" and hub != null:
		hub.game.set_flag(fl, true)
	if bool(r.get("secret", false)):
		_nervous = true
	if hub != null:
		hub.toast("소문을 들었다 (%d/%d)" % [known.size(), VData.RUMORS.size()])


# ---------------------------------------------------------------- 신뢰도

func get_trust(id: String) -> int:
	return int(trust.get(id, 0))


func add_trust(id: String, delta: int) -> void:
	if id == "":
		return
	var v: int = clampi(get_trust(id) + delta, -3, 5)
	trust[id] = v
	if hub != null:
		hub.game.set_flag("distrust_" + id, v <= -2)
		hub.game.set_flag("trust_" + id, v >= 2)


## 대화 시작 때 불림: 시간대가 바뀐 뒤 처음 이야기하면 신뢰도 +1
func on_talk(npc) -> void:
	if npc == null or hub == null:
		return
	var period: String = hub.clock.period_name()
	if str(_last_period.get(npc.npc_id, "")) != period:
		_last_period[npc.npc_id] = period
		if get_trust(npc.npc_id) < 3:
			add_trust(npc.npc_id, 1)


## 대화가 끝난 뒤: 비밀 소문을 말한 NPC 는 잠깐 불안해 하며 웅크림
func on_dialogue_end(npc) -> void:
	if _nervous and npc != null and is_instance_valid(npc) and hub != null and hub.player != null:
		npc.scare(hub.player.global_position, 4.0, false)
	_nervous = false


## 경계 단계에 따라 NPC 대사 분기에 쓰는 전역 플래그
func refresh_alert_flags(level: int) -> void:
	if hub == null:
		return
	hub.game.set_flag("alert_l2", level >= 2)
	hub.game.set_flag("alert_l3", level >= 3)


# ---------------------------------------------------------------- 저장

func to_dict() -> Dictionary:
	return {"trust": trust.duplicate(), "known": known.duplicate(), "log": rumor_log.duplicate()}


func from_dict(d: Dictionary) -> void:
	trust = {}
	known = {}
	rumor_log = []
	var t = d.get("trust")
	if t is Dictionary:
		for k in t.keys():
			var v = t[k]
			if v is float or v is int:
				trust[str(k)] = clampi(int(v), -3, 5)
	var kn = d.get("known")
	if kn is Dictionary:
		for k2 in kn.keys():
			known[str(k2)] = true
	var lg = d.get("log")
	if lg is Array:
		for x in lg:
			rumor_log.append(str(x))
