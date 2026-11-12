extends Node
## V2 날씨 시스템: 맑음 / 흐림 / 비 / 안개.
##  - 햇빛 세기와 하늘 색(game_clock.gd 의 light_mult, sky_gray), 안개(Environment fog), 비 입자(CPUParticles3D)를 서서히 바꿉니다.
##  - 게임플레이 연결: 비/안개에서는 시민의 목격 거리(alert_system.vision_scale)와 경비 시야(npc.vision_range)가 짧아집니다.
##  - 실내(y > 100)에서는 비와 안개를 끕니다.
## 이 모듈이 실패해도 게임은 맑은 날씨로 그대로 동작합니다. (Godot 실행 미검증)

const NAMES: Dictionary = {"clear": "맑음", "cloudy": "흐림", "rain": "비", "fog": "안개"}
## 상태별 목표값: light(햇빛 배율) gray(하늘 회색) fog(안개 밀도) rain(비 세기 0~1) vision(시야 배율)
const PARAMS: Dictionary = {
	"clear": {"light": 1.0, "gray": 0.0, "fog": 0.0, "rain": 0.0, "vision": 1.0},
	"cloudy": {"light": 0.62, "gray": 0.45, "fog": 0.0008, "rain": 0.0, "vision": 0.95},
	"rain": {"light": 0.42, "gray": 0.8, "fog": 0.0035, "rain": 1.0, "vision": 0.7},
	"fog": {"light": 0.55, "gray": 0.6, "fog": 0.013, "rain": 0.0, "vision": 0.5},
}
## 다음 날씨를 고를 때의 가중치 (현재 상태 -> 다음 상태 확률표)
const NEXT: Dictionary = {
	"clear": {"clear": 5, "cloudy": 4, "rain": 1, "fog": 1},
	"cloudy": {"clear": 3, "cloudy": 2, "rain": 4, "fog": 1},
	"rain": {"clear": 1, "cloudy": 4, "rain": 2, "fog": 1},
	"fog": {"clear": 4, "cloudy": 3, "rain": 0, "fog": 1},
}

var hub = null
var state: String = "clear"
var enabled: bool = true
## 현재(부드럽게 변하는) 값
var cur: Dictionary = {"light": 1.0, "gray": 0.0, "fog": 0.0, "rain": 0.0, "vision": 1.0}

var _env: Environment = null
var _rain: CPUParticles3D = null
var _timer: float = 180.0
var _vis_timer: float = 0.0
var _last_vision: float = 1.0
var _rng = RandomNumberGenerator.new()


func setup(p_hub, quality: int = 1) -> void:
	hub = p_hub
	_rng.randomize()
	_timer = _rng.randf_range(120.0, 240.0)
	_build_rain(quality)


func state_name() -> String:
	return str(NAMES.get(state, "맑음"))


func is_raining() -> bool:
	return float(cur["rain"]) > 0.3


func _build_rain(quality: int) -> void:
	_rain = CPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = [140, 260, 420][clampi(quality, 0, 2)]
	_rain.lifetime = 0.9
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(15.0, 0.2, 15.0)
	_rain.direction = Vector3(0.0, -1.0, 0.0)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 20.0
	_rain.initial_velocity_max = 24.0
	_rain.gravity = Vector3(0.0, -4.0, 0.0)
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-18.0, -22.0, -18.0), Vector3(36.0, 30.0, 36.0))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bm = BoxMesh.new()
	bm.size = Vector3(0.012, 0.55, 0.012)
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.85, 0.96, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = m
	_rain.mesh = bm
	_rain.emitting = false
	add_child(_rain)


func set_state(s: String) -> void:
	if PARAMS.has(s):
		state = s
		_apply_gameplay()


func _pick_next() -> String:
	var table: Dictionary = NEXT.get(state, NEXT["clear"])
	var total: int = 0
	for k in table.keys():
		total += int(table[k])
	var r: int = _rng.randi_range(0, maxi(total - 1, 0))
	for k2 in table.keys():
		r -= int(table[k2])
		if r < 0:
			return str(k2)
	return "clear"


func _find_env() -> void:
	if _env != null:
		return
	var w = get_tree().root.find_child("WorldEnvironment", true, false)
	if w != null and w is WorldEnvironment and w.environment != null:
		_env = w.environment


func _process(delta: float) -> void:
	if hub == null or hub.player == null or hub.clock == null:
		return
	if not enabled:
		_apply_values(PARAMS["clear"], 1.0)
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(150.0, 300.0)
		var nxt: String = _pick_next()
		if nxt != state:
			state = nxt
			_apply_gameplay()
			if hub != null:
				hub.toast("날씨가 바뀐다: " + state_name())
	var target: Dictionary = PARAMS.get(state, PARAMS["clear"])
	var k: float = clampf(delta * 0.25, 0.0, 1.0)
	for key in target.keys():
		cur[key] = lerpf(float(cur[key]), float(target[key]), k)
	_apply_values(cur, 1.0)
	_vis_timer -= delta
	if _vis_timer <= 0.0:
		_vis_timer = 4.0
		if absf(float(cur["vision"]) - _last_vision) > 0.03:
			_last_vision = float(cur["vision"])
			_apply_gameplay()


func _apply_values(v: Dictionary, _k: float) -> void:
	var indoors: bool = hub.player.global_position.y > 100.0
	hub.clock.light_mult = float(v["light"])
	hub.clock.sky_gray = float(v["gray"])
	_find_env()
	if _env != null:
		var fd: float = 0.0 if indoors else float(v["fog"])
		_env.fog_enabled = fd > 0.0002
		_env.fog_density = fd
	if _rain != null:
		var amount: float = 0.0 if indoors else float(v["rain"])
		_rain.emitting = amount > 0.05
		_rain.global_position = hub.player.global_position + Vector3(0.0, 11.0, 0.0)


## 게임플레이 연결: 목격 거리 / 경비 시야 배율
func _apply_gameplay() -> void:
	var vs: float = float(cur["vision"])
	var v1 = hub.get("v1") if hub != null else null
	if v1 != null and v1.get("alert") != null:
		v1.alert.vision_scale = vs
	for n in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(n):
			continue
		if n.get("vision_range") == null or float(n.vision_range) <= 0.0 and not n.has_meta("base_vision"):
			continue
		if not n.has_meta("base_vision"):
			n.set_meta("base_vision", float(n.vision_range))
		# 실내 경비는 날씨와 상관없음 (y > 100)
		if n.global_position.y > 100.0:
			n.vision_range = float(n.get_meta("base_vision"))
		else:
			n.vision_range = float(n.get_meta("base_vision")) * clampf(vs + 0.25, 0.5, 1.0)


func to_dict() -> Dictionary:
	return {"state": state, "timer": _timer}


func from_dict(d: Dictionary) -> void:
	var s = d.get("state")
	if s is String and PARAMS.has(s):
		state = s
		# 저장 직후에는 값이 바로 적용되도록 현재값을 목표값으로
		var t: Dictionary = PARAMS[s]
		for key in t.keys():
			cur[key] = float(t[key])
		_apply_gameplay()
	var tm = d.get("timer")
	if tm is float or tm is int:
		_timer = clampf(float(tm), 30.0, 300.0)
