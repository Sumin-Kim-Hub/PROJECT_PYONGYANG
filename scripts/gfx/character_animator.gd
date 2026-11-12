extends RefCounted
## 절차적 걷기/달리기/점프/앉기/대기/대화 동작.
## character_builder.gd 가 만든 관절 노드들을 매 프레임 회전시킵니다.
## 발이 땅에 닿도록 "더 아래로 뻗은 다리"를 기준으로 골반 높이를 계산합니다(간이 발 고정).
##
## 부호 규칙: 팔다리의 +X 회전 = 앞(-Z)으로 흔들기. 무릎은 -X 회전이 구부리기.

var j: Dictionary = {}
var L1: float = 0.44
var L2: float = 0.44
var ankle: float = 0.08
var stoop: float = 0.0   # 노인처럼 등이 굽은 정도
## V2 몸짓: "", "phone"(전화), "cower"(웅크림), "hit"(휘청), "panic"(허둥지둥 도망), "look"(두리번)
var pose: String = ""

var _t: float = 0.0
var _phase: float = 0.0
var _p: Dictionary = {
	"hl": 0.0, "hr": 0.0, "kl": 0.03, "kr": 0.03, "sl": 0.0, "sr": 0.0, "el": 0.12, "er": 0.12,
	"lean": 0.0, "twist": 0.0, "spread": 0.06, "roll": 0.0, "headp": 0.0,
}


func setup(built: Dictionary, p_seed: float = 0.0) -> void:
	j = built["joints"]
	L1 = float(built["L1"])
	L2 = float(built["L2"])
	ankle = float(built["ankle"])
	_t = p_seed
	_phase = p_seed


## speed: 수평 속도(m/s), grounded: 바닥에 서 있는지, vy: 수직 속도
## sitting/talking: 상태, vis_y: 부모 Visual 노드의 y 위치(앉을 때 허브가 내려 놓은 값)
func update(delta: float, speed: float, grounded: bool, vy: float, sitting: bool, talking: bool, vis_y: float) -> void:
	if j.is_empty() or delta <= 0.0:
		return
	_t += delta

	var hl: float = 0.0
	var hr: float = 0.0
	var kl: float = 0.03
	var kr: float = 0.03
	var sl: float = 0.0
	var sr: float = 0.0
	var el: float = 0.12
	var er: float = 0.12
	var lean: float = stoop
	var twist: float = 0.0
	var spread: float = 0.06
	var roll: float = 0.0
	var headp: float = 0.0
	var rate: float = 12.0

	if sitting:
		hl = 1.5
		hr = 1.5
		kl = 1.5
		kr = 1.5
		sl = 0.42
		sr = 0.42
		el = 1.15
		er = 1.15
		lean = 0.05 + stoop
		spread = 0.10
		if talking:
			er = 1.5
			sr = 0.9 + 0.2 * sin(_t * 2.1)
			headp = 0.05 * sin(_t * 3.0)
	elif not grounded:
		var up: float = clampf(vy / 5.0, -1.0, 1.0)
		hl = 0.55 + 0.1 * up
		hr = -0.15
		kl = 0.95
		kr = 0.40
		sl = 1.1 + 0.3 * up
		sr = 1.1 + 0.3 * up
		el = 0.5
		er = 0.5
		lean = 0.06
		spread = 0.30
		rate = 18.0
	elif speed > 0.25:
		var run_f: float = clampf((speed - 2.6) / 3.4, 0.0, 1.0)
		var cycle_len: float = lerpf(0.9 + 0.2 * speed, 2.5, run_f)
		_phase += delta * speed / cycle_len * TAU
		var amp: float = lerpf(clampf(speed / 3.2, 0.35, 1.0) * 0.45, 0.9, run_f)
		var s: float = sin(_phase)
		var c: float = cos(_phase)
		hl = amp * s
		hr = -amp * s
		var kmin: float = lerpf(0.06, 0.35, run_f)
		var kamp: float = lerpf(0.55, 1.15, run_f) * clampf(speed / 3.2, 0.5, 1.0)
		kl = kmin + kamp * maxf(0.0, c)
		kr = kmin + kamp * maxf(0.0, -c)
		var arm: float = amp * lerpf(0.85, 1.0, run_f)
		sl = -arm * s
		sr = arm * s
		var eb: float = lerpf(0.25, 1.5, run_f)
		el = eb + 0.25 * maxf(0.0, -s)
		er = eb + 0.25 * maxf(0.0, s)
		lean = lerpf(0.03, 0.20, run_f) + stoop
		twist = -0.10 * s * (0.5 + 0.5 * run_f)
		roll = 0.03 * s
		spread = lerpf(0.06, 0.12, run_f)
		rate = 30.0
	else:
		lean = stoop + 0.012 * sin(_t * 1.7)
		roll = 0.012 * sin(_t * 0.6)
		twist = 0.02 * sin(_t * 0.5)
		sl = 0.02 * sin(_t * 1.1)
		sr = -0.02 * sin(_t * 1.1)
		if talking:
			er = 0.95 + 0.2 * sin(_t * 2.3)
			sr = 0.55 + 0.25 * sin(_t * 1.7)
			el = 0.45
			sl = 0.15
			headp = 0.05 * sin(_t * 3.1)

	if pose != "" and not sitting:
		match pose:
			"phone":
				if speed < 0.25 and grounded:
					er = 2.35
					sr = 1.05
					el = 0.4
					sl = 0.1
					headp = 0.12 + 0.05 * sin(_t * 0.8)
					twist = 0.18 * sin(_t * 0.5)
			"cower":
				hl = 1.35
				hr = 1.35
				kl = 1.7
				kr = 1.7
				sl = 2.4
				sr = 2.4
				el = 2.1
				er = 2.1
				lean = 0.55
				headp = 0.4
				spread = 0.15
				rate = 16.0
			"hit":
				lean = -0.3
				sl = 1.1
				sr = 1.0
				el = 0.9
				er = 0.8
				headp = -0.2
				spread = 0.5
				rate = 22.0
			"panic":
				if speed > 0.25:
					sl += 1.1
					sr += 1.1
					el = 1.4
					er = 1.4
					lean += 0.1
					spread = 0.3
			"look":
				if speed < 0.25 and grounded:
					twist = 0.5 * sin(_t * 1.1)
					headp = 0.05 * sin(_t * 0.7)

	var a: float = 1.0 - exp(-rate * delta)
	_p["hl"] = lerpf(_p["hl"], hl, a)
	_p["hr"] = lerpf(_p["hr"], hr, a)
	_p["kl"] = lerpf(_p["kl"], kl, a)
	_p["kr"] = lerpf(_p["kr"], kr, a)
	_p["sl"] = lerpf(_p["sl"], sl, a)
	_p["sr"] = lerpf(_p["sr"], sr, a)
	_p["el"] = lerpf(_p["el"], el, a)
	_p["er"] = lerpf(_p["er"], er, a)
	_p["lean"] = lerpf(_p["lean"], lean, a)
	_p["twist"] = lerpf(_p["twist"], twist, a)
	_p["spread"] = lerpf(_p["spread"], spread, a)
	_p["roll"] = lerpf(_p["roll"], roll, a)
	_p["headp"] = lerpf(_p["headp"], headp, a)

	var ph_l: float = _p["hl"]
	var ph_r: float = _p["hr"]
	var pk_l: float = _p["kl"]
	var pk_r: float = _p["kr"]
	# 발이 땅에 닿도록: 더 길게 뻗은 다리 기준으로 골반 높이를 정함
	var v_l: float = L1 * cos(ph_l) + L2 * cos(ph_l - pk_l)
	var v_r: float = L1 * cos(ph_r) + L2 * cos(ph_r - pk_r)
	var py: float = ankle + maxf(v_l, v_r)

	var root: Node3D = j["root"]
	if sitting:
		root.position.y = -vis_y
	else:
		root.position.y = 0.0

	var pelvis: Node3D = j["pelvis"]
	pelvis.position.y = py
	pelvis.rotation.z = _p["roll"]
	var spine: Node3D = j["spine"]
	spine.rotation = Vector3(-float(_p["lean"]), float(_p["twist"]), 0.0)
	var head: Node3D = j["head"]
	head.rotation = Vector3(float(_p["lean"]) * 0.6 + float(_p["headp"]), -float(_p["twist"]) * 0.7, 0.0)

	_rx(j["hip_l"], ph_l)
	_rx(j["hip_r"], ph_r)
	_rx(j["kn_l"], -pk_l)
	_rx(j["kn_r"], -pk_r)
	_rx(j["ft_l"], pk_l - ph_l)
	_rx(j["ft_r"], pk_r - ph_r)

	var sp: float = _p["spread"]
	(j["sh_l"] as Node3D).rotation = Vector3(float(_p["sl"]), 0.0, -sp)
	(j["sh_r"] as Node3D).rotation = Vector3(float(_p["sr"]), 0.0, sp)
	_rx(j["el_l"], float(_p["el"]))
	_rx(j["el_r"], float(_p["er"]))


## 회전의 x 값만 바꿈 (Vector3 를 통째로 복사해서 대입 — 문법/동작이 가장 확실한 방법)
func _rx(n, v: float) -> void:
	var node: Node3D = n as Node3D
	if node == null:
		return
	var r: Vector3 = node.rotation
	r.x = v
	node.rotation = r
