extends Node
## V2.2 NPC 상호작용: 설득 / 위협 / 뇌물 / 부탁 / 거래 / 정보.
##  - NPC 마다 성격(용기, 욕심, 권위, 친절)을 역할 글에서 읽어 오고,
##    관계(우호/중립/의심/경계/적대)는 신뢰도와 도시 경계 단계, 주변 감시에서 정합니다.
##  - 결과는 확률로 정해지며, 위협한다고 늘 보상을 주지 않습니다. 신고하거나 도와주는 NPC 도 있습니다.
##  - 대화 그래프에 "특별 행동" 선택지를 붙이고, 선택은 "v22_act" 등의 효과로 이 모듈에 들어옵니다.
## (Godot 실행 미검증)

const VData = preload("res://scripts/v22/v22_data.gd")

var hub = null
var mgr = null
## npc_id -> 설득/뇌물에 실패한 횟수 (쌓이면 의심)
var suspicion: Dictionary = {}
## npc_id -> 다음에 알려 줄 정보 순번
var intel_idx: Dictionary = {}

var _rng = RandomNumberGenerator.new()
var _help_cd: Dictionary = {}
var _report_cd: float = 0.0
var _tick: float = 0.0


func setup(p_hub, p_mgr) -> void:
	hub = p_hub
	mgr = p_mgr
	_rng.randomize()


# ---------------------------------------------------------------- 성격 / 관계

func profile(npc) -> Dictionary:
	var p: Dictionary = {"courage": 0.5, "greed": 0.4, "authority": 0.0, "kind": 0.35}
	if npc == null:
		return p
	var role: String = str(npc.role)
	var id: String = str(npc.npc_id)
	var hv: float = float(absi(hash(id)) % 100) / 100.0
	p["courage"] = 0.35 + hv * 0.3
	p["greed"] = 0.25 + (1.0 - hv) * 0.3
	for k in ["경비", "군인", "장교", "경찰", "순찰", "검문"]:
		if role.find(k) >= 0:
			p["authority"] = 0.85
			p["courage"] = 0.9
			p["greed"] = 0.35
	for k2 in ["상인", "상점", "장사", "암거래", "중개", "매점", "주인"]:
		if role.find(k2) >= 0:
			p["greed"] = 0.8
			p["courage"] = minf(float(p["courage"]), 0.5)
	for k3 in ["소심", "겁", "조용", "수줍", "소년", "아이"]:
		if role.find(k3) >= 0:
			p["courage"] = 0.12
	for k4 in ["친절", "따뜻", "다정"]:
		if role.find(k4) >= 0:
			p["kind"] = 0.8
	for k5 in ["엄격", "냉정", "강직"]:
		if role.find(k5) >= 0:
			p["authority"] = minf(1.0, float(p["authority"]) + 0.3)
			p["greed"] = float(p["greed"]) * 0.5
	return p


func trust(id: String) -> int:
	var v1 = hub.get("v1")
	if v1 != null and v1.social != null:
		return int(v1.social.get_trust(id))
	return 0


func alert_level() -> int:
	var v1 = hub.get("v1")
	if v1 != null and v1.alert != null:
		return int(v1.alert.level)
	return 0


## 우호 / 중립 / 의심 / 경계 / 적대
func relation(npc) -> String:
	if npc == null:
		return "중립"
	var id: String = str(npc.npc_id)
	var t: int = trust(id)
	var pr: Dictionary = profile(npc)
	var lvl: int = alert_level()
	if t <= -2 or (lvl >= 4 and float(pr["authority"]) > 0.5):
		return "적대"
	if t == -1:
		return "의심"
	if t >= 2:
		return "우호"
	if lvl >= 2 or int(suspicion.get(id, 0)) >= 2:
		return "경계"
	return "중립"


## 대화창 머리글에 보일 역할 글 (관계 포함)
func role_label(npc) -> String:
	var base: String = str(npc.role)
	if base == "":
		base = "시민"
	return base + " · " + relation(npc)


## 주변의 감시자(경비/경찰) 수에 따른 0~1 값
func watchers(npc) -> float:
	var n: int = 0
	var pos: Vector3 = npc.global_position
	for grp in ["guards", "police"]:
		for g in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(g) or g == npc:
				continue
			if absf(g.global_position.y - pos.y) > 4.0:
				continue
			if Vector2(g.global_position.x - pos.x, g.global_position.z - pos.z).length() < 22.0:
				n += 1
	var w: float = clampf(float(n) / 2.0, 0.0, 1.0)
	if alert_level() >= 3:
		w = minf(1.0, w + 0.4)
	return w


# ---------------------------------------------------------------- 대화 그래프에 붙이기

func augment_all() -> void:
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n):
			augment(n)


func augment(npc) -> void:
	if npc.has_meta("v22_aug"):
		return
	npc.set_meta("v22_aug", true)
	if npc.no_talk or npc.has_meta("v22_gate") or npc.dialogue.is_empty() or not npc.dialogue.has("start"):
		return
	# 원본 데이터(상수일 수 있음)를 건드리지 않도록 복사본에 덧붙임
	npc.dialogue = npc.dialogue.duplicate(true)
	var d: Dictionary = npc.dialogue
	d["v22_menu"] = {
		"text": "(말을 고른다) …어떤 방식으로 이야기를 풀어 볼까?",
		"choices": [
			{"label": "설득", "next": "v22_do_persuade"},
			{"label": "위협", "next": "v22_do_threaten"},
			{"label": "뇌물", "next": "v22_bribe"},
			{"label": "더 보기", "next": "v22_menu2"},
		],
	}
	d["v22_menu2"] = {
		"text": "(말을 고른다) …다른 방식도 있다.",
		"choices": [
			{"label": "부탁", "next": "v22_do_request"},
			{"label": "거래", "next": "v22_trade"},
			{"label": "정보", "next": "v22_do_info"},
			{"label": "뒤로", "next": "v22_menu"},
		],
	}
	d["v22_bribe"] = {
		"text": "(주머니의 돈을 만지작거린다) 얼마를 건넬까?",
		"choices": [
			{"label": "20원", "next": "v22_do_bribe20", "if": {"item_min": ["won", 20]}},
			{"label": "50원", "next": "v22_do_bribe50", "if": {"item_min": ["won", 50]}},
			{"label": "취소", "next": "v22_menu"},
		],
	}
	for kind in ["persuade", "threaten", "bribe20", "bribe50", "request", "info"]:
		d["v22_do_" + kind] = {
			"dyn": "v22_result", "text": "...",
			"effects": [{"op": "v22_act", "kind": kind}],
			"choices": [
				{"label": "더 이야기한다", "next": "v22_menu", "if": {"not_flag": "v22_walkaway"}},
				{"label": "끝낸다", "next": ""},
			],
		}
	var vendor: bool = VData.VENDORS.has(str(npc.npc_id))
	if vendor:
		d["v22_trade"] = {
			"text": "필요한 게 있으면 말해요. 살 수도, 팔 수도 있어요.",
			"choices": [
				{"label": "식량(30)", "next": "v22_buy_food_ration"},
				{"label": "약품(60)", "next": "v22_buy_medicine"},
				{"label": "물건 팔기", "next": "v22_sell"},
				{"label": "그만", "next": ""},
			],
		}
		for item in ["food_ration", "medicine"]:
			d["v22_buy_" + item] = {
				"dyn": "v22_result", "text": "...",
				"effects": [{"op": "v22_buy", "item": item}],
				"choices": [{"label": "계속 거래", "next": "v22_trade"}, {"label": "끝낸다", "next": ""}],
			}
		d["v22_sell"] = {
			"dyn": "v22_result", "text": "...",
			"effects": [{"op": "v22_sell"}],
			"choices": [{"label": "계속 거래", "next": "v22_trade"}, {"label": "끝낸다", "next": ""}],
		}
	else:
		d["v22_trade"] = {
			"text": "나는 장사하는 사람이 아니에요. 팔 물건도, 살 돈도 없어요.",
			"choices": [{"label": "알겠어요", "next": "v22_menu2"}],
		}
	var start: Dictionary = d["start"]
	var ch: Array = start.get("choices", [])
	if ch.size() >= 1 and ch.size() < 5:
		ch.insert(maxi(ch.size() - 1, 0), {"label": "특별 행동", "next": "v22_menu"})
		start["choices"] = ch


# ---------------------------------------------------------------- 행동 처리

func _take_won(n: int) -> bool:
	if int(hub.game.inventory.get("won", 0)) < n:
		return false
	hub.game.remove_item("won", n)
	return true


func give_won(n: int) -> void:
	if n <= 0:
		return
	hub.game.add_item("won", n)
	hub.toast("+%d원" % n)


## 다음 정보 조각을 알려 줌. 알려 줄 게 없으면 "" 를 돌려줌
func _give_intel(npc) -> String:
	var id: String = str(npc.npc_id)
	var list: Array = VData.INFO_BY_NPC.get(id, ["pass"])
	var idx: int = int(intel_idx.get(id, 0))
	while idx < list.size():
		var key: String = str(list[idx])
		idx += 1
		intel_idx[id] = idx
		if not hub.game.get_flag("intel_" + key):
			hub.game.set_flag("intel_" + key, true)
			var text: String = str(VData.INTEL.get(key, ""))
			hub.toast("정보 획득")
			return text
	intel_idx[id] = idx
	return ""


func _no_news(npc) -> String:
	var hint: String = ""
	if mgr != null:
		hint = str(mgr.objective_text())
	if hint != "":
		return "더 해 줄 이야기는 없어요. 다만 지금은 '%s' 쪽을 알아보는 게 좋겠어요." % hint
	return "아는 건 이게 전부예요."


func _report(npc, severity: float) -> void:
	var v1 = hub.get("v1")
	if v1 != null and v1.alert != null:
		v1.alert.report("trespass", npc.global_position, severity, npc)


func act(kind: String, npc) -> void:
	hub.game.set_flag("v22_walkaway", false)
	if npc == null or not is_instance_valid(npc):
		mgr.last_text = "(아무도 대답하지 않는다.)"
		return
	var id: String = str(npc.npc_id)
	var pr: Dictionary = profile(npc)
	var tr: int = trust(id)
	var watch: float = watchers(npc)
	var lvl: int = alert_level()
	var v1 = hub.get("v1")
	var text: String = ""
	match kind:
		"persuade":
			var chance: float = 0.30 + 0.10 * float(tr) + 0.15 * float(pr["kind"]) - 0.25 * float(pr["authority"]) - 0.18 * watch - 0.10 * float(maxi(lvl - 1, 0))
			chance = clampf(chance, 0.05, 0.9)
			if _rng.randf() < chance:
				var info: String = _give_intel(npc)
				if v1 != null and v1.social != null and tr < 3:
					v1.social.add_trust(id, 1)
				if info != "":
					text = "…알겠어요. 당신 말이 맞는 것 같네요. 이건 말해 줄게요. " + info
				else:
					text = "…알겠어요. 당신 말을 믿어 볼게요. 조심하세요."
			else:
				suspicion[id] = int(suspicion.get(id, 0)) + 1
				if int(suspicion[id]) >= 2 and v1 != null and v1.social != null:
					v1.social.add_trust(id, -1)
				if watch > 0.5 and float(pr["authority"]) > 0.5:
					_report(npc, 0.5)
					text = "수상한 소리는 그만하십시오. 더 하면 보고하겠습니다."
					hub.game.set_flag("v22_walkaway", true)
				else:
					text = "글쎄요… 잘 모르겠어요. 그렇게 말한다고 믿을 수는 없죠."
		"threaten":
			var yield_c: float = 0.15 + 0.6 * (1.0 - float(pr["courage"])) - 0.35 * float(pr["authority"]) - 0.2 * watch
			yield_c = clampf(yield_c, 0.05, 0.85)
			if v1 != null and v1.alert != null:
				v1.alert.report("threaten", npc.global_position, 0.7, npc)
			if v1 != null and v1.social != null:
				v1.social.add_trust(id, -2)
			if _rng.randf() < yield_c:
				var roll: float = _rng.randf()
				if roll < 0.5:
					var amt: int = int((15.0 + _rng.randf() * 30.0) * (0.6 + float(pr["greed"])))
					give_won(amt)
					text = "(떨리는 손으로 돈을 꺼낸다) 이, 이거면 됩니까… 제발 그만하세요."
				else:
					var info2: String = _give_intel(npc)
					if info2 != "":
						text = "알았어요, 말할게요! " + info2
					else:
						give_won(10)
						text = "정말 아는 게 없어요! 이게 가진 전부예요."
				npc.scare(hub.player.global_position, 8.0, false)
				hub.game.set_flag("v22_walkaway", true)
			else:
				if float(pr["authority"]) > 0.5 or watch > 0.4:
					text = "감히 누구를 협박하는가! 지원을 부르겠다!"
					_report(npc, 1.2)
					if npc.has_method("chase") and npc.is_police:
						npc.chase(hub.player, 20.0)
				else:
					text = "(눈을 부릅뜬다) 소리 지를 거예요! 사람 살려!"
					_report(npc, 0.9)
					npc.scare(hub.player.global_position, 10.0, true)
				hub.game.set_flag("v22_walkaway", true)
		"bribe20", "bribe50":
			var cost: int = 20 if kind == "bribe20" else 50
			if not _take_won(cost):
				text = "…돈이 모자라는 것 같은데요."
			else:
				var c2: float = 0.22 + float(pr["greed"]) * 0.45 + (0.18 if cost >= 50 else 0.0) - float(pr["authority"]) * 0.2 - watch * 0.35
				c2 = clampf(c2, 0.04, 0.9)
				if _rng.randf() < c2:
					var parts: Array = []
					var i1: String = _give_intel(npc)
					if i1 != "":
						parts.append(i1)
					if float(pr["authority"]) > 0.5 and v1 != null and v1.alert != null:
						v1.alert.heat = maxf(v1.alert.baseline, v1.alert.heat - 18.0)
						parts.append("(경비가 눈을 감아 주겠다는 듯 고개를 끄덕인다. 경계가 조금 가라앉았다.)")
					if parts.is_empty():
						text = "(돈을 슬쩍 받는다) …고마워요. 필요하면 또 찾아와요."
						if v1 != null and v1.social != null and tr < 3:
							v1.social.add_trust(id, 1)
					else:
						text = "(돈을 슬쩍 받는다) 이건 비밀인데요. " + " ".join(parts)
				else:
					suspicion[id] = int(suspicion.get(id, 0)) + 1
					if float(pr["authority"]) > 0.5 or watch > 0.4:
						text = "뇌물?! 이 사람을 보고해야겠어!"
						_report(npc, 1.0)
						hub.game.set_flag("v22_walkaway", true)
					else:
						text = "(돈을 밀어낸다) 이런 건 받을 수 없어요. 넣어 두세요."
						give_won(cost / 2)
		"request":
			if tr < 1:
				text = "아직은 그런 부탁을 들어줄 만큼 서로 알지 못해요."
			elif hub.game.get_flag("v22_favor_" + id):
				text = "아까 도와드린 걸로 충분해요. 오늘은 더 못 해 드려요."
			else:
				var fav: Dictionary = VData.FAVOR_BY_NPC.get(id, {"won": 15})
				hub.game.set_flag("v22_favor_" + id, true)
				if fav.has("item"):
					var it: String = str(fav["item"])
					hub.game.add_item(it, 1)
					hub.toast("획득: " + hub.game_item_name(it))
					text = "알겠어요. 이거라도 가져가세요. 조심해서 쓰세요."
				else:
					give_won(int(fav.get("won", 15)))
					text = "큰 도움은 못 되지만 이거라도 보태세요."
		"info":
			if tr >= 1:
				var i2: String = _give_intel(npc)
				text = ("우리 사이니까 말해 줄게요. " + i2) if i2 != "" else _no_news(npc)
			elif _take_won(10):
				var i3: String = _give_intel(npc)
				text = ("(돈을 받고 목소리를 낮춘다) " + i3) if i3 != "" else _no_news(npc)
			else:
				text = "처음 본 사람한테 함부로 이야기하지 않아요. (신뢰를 쌓거나 10원을 건네면 이야기해 줄 수도 있다.)"
		_:
			text = "..."
	mgr.last_text = text


func buy(item: String, npc) -> void:
	var price: int = int(VData.BUY_PRICES.get(item, 999))
	# 우호적이면 조금 깎아 줌
	if npc != null and trust(str(npc.npc_id)) >= 2:
		price = maxi(1, int(float(price) * 0.85))
	if not _take_won(price):
		mgr.last_text = "돈이 모자라요. (%d원 필요)" % price
		return
	hub.game.add_item(item, 1)
	hub.toast("구입: %s (-%d원)" % [hub.game_item_name(item), price])
	mgr.last_text = "고마워요. 또 오세요."


func sell(npc) -> void:
	var total: int = 0
	var names: Array = []
	for id in VData.SELL_PRICES.keys():
		var n: int = int(hub.game.inventory.get(str(id), 0))
		# 낚시꾼 임무에 쓸 라디오 부품 한 개는 남겨 둠
		if str(id) == "radio_part" and hub.game.quest_state("q_v22_river") == "active":
			n -= 1
		if n > 0:
			total += n * int(VData.SELL_PRICES[id])
			names.append(hub.game_item_name(str(id)))
			hub.game.remove_item(str(id), n)
	if total <= 0:
		mgr.last_text = "팔 만한 물건이 없네요. (식량·약품·부품·시계 같은 것을 가져와 보세요.)"
		return
	give_won(total)
	mgr.last_text = "%s… 합쳐서 %d원 쳐 드릴게요." % [", ".join(names), total]


## 상단 위협 버튼으로 시민을 위협했을 때 (alert_system.threaten 뒤에 불림)
func on_threaten(npc) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var id: String = str(npc.npc_id)
	var pr: Dictionary = profile(npc)
	var watch: float = watchers(npc)
	var v1 = hub.get("v1")
	if v1 != null and v1.social != null:
		v1.social.add_trust(id, -1)
	var c: float = 0.12 + 0.5 * (1.0 - float(pr["courage"])) - 0.3 * float(pr["authority"]) - 0.25 * watch
	if _rng.randf() < clampf(c, 0.03, 0.7):
		var amt: int = int((8.0 + _rng.randf() * 20.0) * (0.6 + float(pr["greed"])))
		give_won(amt)
		hub.toast("%s이(가) 겁에 질려 주머니를 털어 주었다." % npc.display_name)
	elif watch > 0.4 or float(pr["authority"]) > 0.5:
		hub.toast("%s이(가) 도움을 청하는 소리를 질렀다!" % npc.display_name)
		_report(npc, 0.6)


# ---------------------------------------------------------------- 자발적인 도움 / 신고

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.5:
		return
	var dt: float = _tick
	_tick = 0.0
	_report_cd = maxf(0.0, _report_cd - dt)
	if hub == null or hub.player == null or hub.mode != 0:
		return
	var v1 = hub.get("v1")
	if v1 == null or v1.alert == null or v1.social == null:
		return
	var lvl: int = alert_level()
	var pp: Vector3 = hub.player.global_position
	var now: float = Time.get_ticks_msec() / 1000.0
	for n in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(n) or n.is_police or n.no_talk:
			continue
		if absf(n.global_position.y - pp.y) > 3.0:
			continue
		var d: float = Vector2(n.global_position.x - pp.x, n.global_position.z - pp.z).length()
		if d > 8.0:
			continue
		var id: String = str(n.npc_id)
		var t: int = int(v1.social.get_trust(id))
		# 우호적인 시민은 경계가 높을 때 시선을 돌려 줌
		if t >= 3 and lvl >= 2 and now > float(_help_cd.get(id, 0.0)):
			_help_cd[id] = now + 90.0
			v1.alert.heat = maxf(v1.alert.baseline, v1.alert.heat - 12.0)
			hub.toast("%s이(가) 경비의 시선을 다른 곳으로 돌려 주었다." % n.display_name)
			return
		# 적대적인 시민은 가끔 신고함
		if t <= -2 and lvl <= 2 and _report_cd <= 0.0 and _rng.randf() < 0.12:
			_report_cd = 60.0
			hub.toast("%s이(가) 당신을 신고했다!" % n.display_name)
			v1.alert.report("trespass", n.global_position, 0.7, n)
			return


# ---------------------------------------------------------------- 저장

func to_dict() -> Dictionary:
	return {"suspicion": suspicion.duplicate(), "intel_idx": intel_idx.duplicate()}


func from_dict(d: Dictionary) -> void:
	suspicion = {}
	intel_idx = {}
	var s = d.get("suspicion")
	if s is Dictionary:
		for k in s.keys():
			if s[k] is float or s[k] is int:
				suspicion[str(k)] = int(s[k])
	var ii = d.get("intel_idx")
	if ii is Dictionary:
		for k2 in ii.keys():
			if ii[k2] is float or ii[k2] is int:
				intel_idx[str(k2)] = int(ii[k2])
