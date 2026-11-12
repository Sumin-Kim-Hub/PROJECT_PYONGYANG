extends Node
## 도시 경계 시스템 (V1).
##  - 플레이어의 소란(위협, 밀침, 차량 충돌 등)을 report() 로 받으면 "경계 수치(heat)"가 오릅니다.
##  - 목격한 시민은 도망치거나 웅크리고, 일부는 신고합니다. 경비/경찰은 소리 난 곳으로 확인하러 옵니다.
##  - 수치가 오르면 단계가 올라가고(평온→주의→경계→수색→비상), 시간이 지나거나 건물 안에 숨으면 내려갑니다.
##  - 짧은 시간에 반복하면 도시 전체 비상, 정부청사·광장 같은 장소에서는 더 크게 반응합니다.
##  - 잡히면(경찰이 곁에 오면) 허브의 _caught() 로 안전한 곳에 돌아가며 수치가 크게 줄어듭니다.
## 폭력 표현은 위협/밀치기 수준이며 상처나 유혈은 없습니다 (가상의 게임 내 소란 시스템).

const NpcScript = preload("res://scripts/npc/npc.gd")
const Placement = preload("res://scripts/interaction/placement.gd")

const LEVEL_NAMES: Array = ["평온", "주의", "경계", "수색", "비상"]
const LEVEL_AT: Array = [0.0, 12.0, 32.0, 58.0, 82.0]
const POLICE_WANTED: Array = [0, 0, 1, 3, 5]
const BASE_HEAT: Dictionary = {"threaten": 8.0, "shove": 12.0, "vehicle_hit": 16.0, "crash": 9.0, "trespass": 6.0, "attack": 20.0}
const HOT_MARKERS: Array = ["lm_gov", "lm_square", "lm_hill"]

var hub = null
var v1 = null
var world: Node3D = null
var heat: float = 0.0
var baseline: float = 0.0
var level: int = 0
var streak: int = 0
var arrests: int = 0
var police: Array = []
var last_pos: Vector3 = Vector3.ZERO
var hot_zone: bool = false
var max_police: int = 5
## V2: 날씨에 따른 목격 거리 배율 (비/안개에서는 짧아짐)
var vision_scale: float = 1.0

var _streak_t: float = 0.0
var _tick: float = 0.0
var _panic_t: float = 0.0
var _calls: Array = []
var _serial: int = 0
var _idle_t: float = 0.0


func setup(p_hub, p_v1, p_world: Node3D) -> void:
	hub = p_hub
	v1 = p_v1
	world = p_world


func level_name() -> String:
	return str(LEVEL_NAMES[clampi(level, 0, 4)])


func level_color() -> Color:
	match level:
		0:
			return Color(0.6, 0.9, 0.6)
		1:
			return Color(1.0, 0.95, 0.5)
		2:
			return Color(1.0, 0.75, 0.3)
		3:
			return Color(1.0, 0.45, 0.25)
	return Color(1.0, 0.2, 0.2)


# ---------------------------------------------------------------- 소란 보고

## kind: threaten / shove / vehicle_hit / crash / trespass / attack
func report(kind: String, pos: Vector3, severity: float, witness) -> void:
	if hub == null or hub.player == null:
		return
	var base: float = float(BASE_HEAT.get(kind, 6.0))
	var wits: Array = _witnesses(pos, witness)
	var mult: float = _place_mult(pos)
	var n: int = wits.size()
	var gain: float = base * severity * mult * (0.3 + 0.35 * float(mini(n, 4)))
	if _streak_t > 0.0:
		streak += 1
	else:
		streak = 1
	_streak_t = 60.0
	if streak >= 3:
		gain *= 1.5
	last_pos = pos
	hot_zone = mult > 1.5
	heat = minf(100.0, heat + gain)
	if streak >= 4:
		heat = maxf(heat, float(LEVEL_AT[4]))

	for w in wits:
		if not is_instance_valid(w):
			continue
		if w.is_police or w.vision_range > 0.0:
			if w.is_police and hub.player.global_position.distance_to(w.global_position) < 30.0:
				w.chase(hub.player, 25.0)
			else:
				w.investigate(pos, 14.0)
		else:
			w.scare(pos, 8.0 + severity * 4.0, randf() < 0.75)
			if randf() < 0.6:
				_calls.append({"t": randf_range(2.0, 4.0), "pos": pos})
			if v1 != null and v1.social != null:
				v1.social.add_trust(w.npc_id, -1)

	# 가까운 경비/경찰은 소리를 듣고 확인하러 옴
	for g in get_tree().get_nodes_in_group("guards"):
		if is_instance_valid(g) and g.global_position.distance_to(pos) < 45.0 and g.react != "chase":
			g.investigate(pos, 14.0)
	for p in get_tree().get_nodes_in_group("police"):
		if is_instance_valid(p) and p.global_position.distance_to(pos) < 55.0 and p.react != "chase":
			p.investigate(pos, 16.0)
	_update_level(true)


func _witnesses(pos: Vector3, extra) -> Array:
	var out: Array = []
	if extra != null and is_instance_valid(extra):
		out.append(extra)
	var space: PhysicsDirectSpaceState3D = hub.player.get_world_3d().direct_space_state
	for n in get_tree().get_nodes_in_group("npcs"):
		if out.size() >= 8:
			break
		if not is_instance_valid(n) or n == extra or not n.visible or n.riding != null:
			continue
		var d: float = n.global_position.distance_to(pos)
		if d > 22.0 * vision_scale:
			continue
		var from: Vector3 = n.global_position + Vector3(0.0, 1.5, 0.0)
		var to: Vector3 = pos + Vector3(0.0, 1.0, 0.0)
		var q = PhysicsRayQueryParameters3D.create(from, to, 1)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty() or hit.get("collider") == hub.player:
			out.append(n)
	return out


func _place_mult(pos: Vector3) -> float:
	var m: float = 1.0
	if pos.y > 100.0:
		m = 1.4
	if v1 != null and v1.landmarks != null:
		for mk in v1.landmarks.markers:
			if HOT_MARKERS.has(str(mk.get("id", ""))):
				var mp: Vector3 = mk["pos"]
				if Vector2(mp.x - pos.x, mp.z - pos.z).length() < 45.0:
					m = 1.8
	return m


## 플레이어가 시민을 위협 (HUD 의 '위협' 버튼)
func threaten(npc) -> void:
	if npc == null or not is_instance_valid(npc) or hub == null:
		return
	var from: Vector3 = hub.player.global_position
	var away: Vector3 = npc.global_position - from
	away.y = 0.0
	if npc.is_police:
		npc.chase(hub.player, 25.0)
	else:
		npc.scare(from, 10.0, true)
		if away.length() > 0.1:
			npc.shove(away.normalized() * 3.0)
	hub.toast("%s이(가) 놀라 물러선다." % npc.display_name)
	report("threaten", npc.global_position, 1.0, npc)
	# V2.2: 위협의 결과 (성격/관계/감시 상황에 따라 보상 또는 신고)
	var hub_v22 = hub.get("v22")
	if hub_v22 != null:
		hub_v22.on_threaten(npc)


# ---------------------------------------------------------------- 매 프레임

func _process(delta: float) -> void:
	if hub == null or hub.player == null:
		return
	_streak_t = maxf(0.0, _streak_t - delta)
	_tick += delta
	if _tick < 0.5:
		return
	var dt: float = _tick
	_tick = 0.0

	# 신고 처리: 몇 초 뒤 경비/경찰이 출동
	var i: int = _calls.size() - 1
	while i >= 0:
		_calls[i]["t"] = float(_calls[i]["t"]) - dt
		if float(_calls[i]["t"]) <= 0.0:
			var cp: Vector3 = _calls[i]["pos"]
			_calls.remove_at(i)
			_dispatch_call(cp)
		i -= 1

	# 경계 수치 감소
	var chasing: bool = false
	for p in police:
		if is_instance_valid(p) and p.react == "chase":
			chasing = true
	var rate: float = 0.9
	if chasing:
		rate = 0.15
	if hub.player.global_position.y > 100.0:
		rate *= 1.6
	if hub.mode == 5:
		rate *= 0.7
	if heat > baseline:
		heat = maxf(baseline, heat - rate * dt)
	_update_level(false)

	_manage_police(dt)

	# 비상: 가까운 시민들이 겁에 질려 흩어짐
	_panic_t -= dt
	if level >= 4 and _panic_t <= 0.0 and hub.player.global_position.y < 100.0:
		_panic_t = 2.0
		var pp: Vector3 = hub.player.global_position
		for n in get_tree().get_nodes_in_group("npcs"):
			if is_instance_valid(n) and n.visible and not n.is_police and n.vision_range <= 0.0 and n.react == "":
				if n.global_position.distance_to(pp) < 25.0 and randf() < 0.5:
					n.scare(pp, 6.0, true)


func _dispatch_call(cp: Vector3) -> void:
	var best = null
	var best_d: float = 1000000.0
	for g in get_tree().get_nodes_in_group("police"):
		if not is_instance_valid(g):
			continue
		var d: float = g.global_position.distance_to(cp)
		if d < best_d:
			best_d = d
			best = g
	for g2 in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g2):
			continue
		var d2: float = g2.global_position.distance_to(cp)
		if d2 < best_d:
			best_d = d2
			best = g2
	if best != null and best_d < 160.0:
		best.investigate(cp, 18.0)
	if level >= 1:
		heat = minf(100.0, heat + 1.5)


func _update_level(announce: bool) -> void:
	var nl: int = 0
	for k in range(LEVEL_AT.size()):
		if heat >= float(LEVEL_AT[k]):
			nl = k
	# 올라갈 땐 바로, 내려갈 땐 경계선에서 조금 여유(깜빡임 방지)
	if nl < level and heat > float(LEVEL_AT[level]) - 3.0:
		nl = level
	if nl != level:
		var up: bool = nl > level
		level = nl
		if hub != null:
			if up:
				hub.toast("도시 경계 단계: %s" % level_name())
			elif level == 0:
				hub.toast("도시가 평온을 되찾았다.")
			else:
				hub.toast("도시 경계가 내려갔다: %s" % level_name())
		if level >= 3:
			hub.game.set_flag("alert_peak", true)


func _manage_police(dt: float) -> void:
	var i: int = police.size() - 1
	while i >= 0:
		if not is_instance_valid(police[i]):
			police.remove_at(i)
		i -= 1
	var outdoors: bool = hub.player.global_position.y < 100.0
	var want: int = int(POLICE_WANTED[level])
	if hot_zone and level >= 2:
		want += 2
	want = mini(want, max_police)
	if outdoors and police.size() < want:
		_spawn_police()
	var pp: Vector3 = hub.player.global_position
	for p in police:
		if level >= 3 and outdoors:
			if p.react != "chase" and p.global_position.distance_to(pp) < 90.0:
				p.chase(hub.player, 20.0)
		elif level == 2 and p.react == "":
			p.investigate(last_pos, 15.0)
		elif level < 2 and p.react != "":
			p.calm_down()
	# 평온해지면 천천히 철수
	if level == 0:
		_idle_t += dt
		if _idle_t > 12.0:
			_idle_t = 0.0
			for p2 in police:
				if is_instance_valid(p2):
					p2.queue_free()
			police.clear()
	else:
		_idle_t = 0.0


func _spawn_police() -> void:
	if world == null:
		return
	_serial += 1
	var pp: Vector3 = hub.player.global_position
	var ang: float = randf() * TAU
	var c: Vector3 = Vector3(pp.x + cos(ang) * randf_range(38.0, 52.0), 0.0, pp.z + sin(ang) * randf_range(38.0, 52.0))
	c.x = clampf(c.x, -300.0, 300.0)
	c.z = clampf(c.z, -230.0, 330.0)
	var spot: Vector3 = Placement.find_free_capsule(world.get_world_3d(), c, 0.35, 1.8)
	var cfg: Dictionary = {
		"id": "police_x%d" % _serial, "name": "경찰", "role": "경찰 · 출동", "speed": 1.6,
		"home": spot, "no_talk": true,
		"look": {"sex": "m", "height": 1.03, "skin": Color(0.84, 0.68, 0.56), "shirt": Color(0.18, 0.24, 0.34), "pants": Color(0.14, 0.17, 0.24),
			"hair": Color(0.06, 0.06, 0.06), "hat": true, "hat_color": Color(0.18, 0.24, 0.34), "acc": ""},
	}
	var n = NpcScript.new()
	n.name = "NPC_police_x%d" % _serial
	n.configure(cfg, hub)
	n.position = spot + Vector3(0.0, 0.05, 0.0)
	world.add_child(n)
	police.append(n)
	if police.size() == 1:
		hub.toast("경찰이 출동했다!")


# ---------------------------------------------------------------- 체포 후 / 저장

func on_caught() -> void:
	arrests += 1
	baseline = minf(12.0, baseline + 2.0)
	heat = maxf(baseline, heat * 0.3)
	level = 0
	_calls.clear()
	for p in police:
		if is_instance_valid(p):
			p.queue_free()
	police.clear()
	_update_level(false)


func to_dict() -> Dictionary:
	return {"heat": heat, "baseline": baseline, "arrests": arrests}


func from_dict(d: Dictionary) -> void:
	var h = d.get("heat")
	var b = d.get("baseline")
	var a = d.get("arrests")
	heat = clampf(float(h), 0.0, 100.0) if (h is float or h is int) else 0.0
	baseline = clampf(float(b), 0.0, 12.0) if (b is float or b is int) else 0.0
	arrests = int(a) if (a is float or a is int) else 0
	for p in police:
		if is_instance_valid(p):
			p.queue_free()
	police.clear()
	_calls.clear()
	level = 0
	_update_level(false)
