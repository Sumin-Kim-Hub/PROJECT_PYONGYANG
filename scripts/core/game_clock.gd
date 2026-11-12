extends Node
## 게임 안의 시간과 낮·밤 조명.
## main.gd 가 만든 "Sun"(DirectionalLight3D) 과 "WorldEnvironment" 를 이름으로 찾아
## 시간에 따라 태양 방향/세기, 하늘 색, 주변광을 바꿉니다. (main.gd 는 수정하지 않음)
## 건물 내부는 태양 영향을 받지 않도록 별도로 처리되어 있습니다.

const DAY_MINUTES: float = 1440.0

## 게임 분 / 실제 초. 2.0 이면 하루가 실제 12분
var speed: float = 2.0
var paused: bool = false
## V2 날씨가 곱해 주는 값: 햇빛 세기 배율, 하늘 회색 정도(0~1)
var light_mult: float = 1.0
var sky_gray: float = 0.0
## 현재 시각 (분 단위, 0 ~ 1440)
var minutes: float = 8.5 * 60.0

var _sun: DirectionalLight3D = null
var _env: Environment = null
var _sky: ProceduralSkyMaterial = null
var _timer: float = 0.0


func _process(delta: float) -> void:
	if not paused:
		minutes = fposmod(minutes + speed * delta, DAY_MINUTES)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		_apply_lighting()


func hour_float() -> float:
	return minutes / 60.0


func is_night() -> bool:
	var h: float = hour_float()
	return h < 5.5 or h >= 20.5


func time_label() -> String:
	var total: int = int(minutes)
	return "%02d:%02d" % [total / 60, total % 60]


func period_name() -> String:
	var h: float = hour_float()
	if h >= 5.0 and h < 10.0:
		return "아침"
	if h >= 10.0 and h < 17.0:
		return "낮"
	if h >= 17.0 and h < 20.5:
		return "저녁"
	return "밤"


func set_minutes(m: float) -> void:
	minutes = fposmod(m, DAY_MINUTES)
	_apply_lighting()


func _find_nodes() -> void:
	if _sun == null:
		var s = get_tree().root.find_child("Sun", true, false)
		if s != null and s is DirectionalLight3D:
			_sun = s
	if _env == null:
		var w = get_tree().root.find_child("WorldEnvironment", true, false)
		if w != null and w is WorldEnvironment and w.environment != null:
			_env = w.environment
			if _env.sky != null and _env.sky.sky_material is ProceduralSkyMaterial:
				_sky = _env.sky.sky_material


func _apply_lighting() -> void:
	_find_nodes()
	var h: float = hour_float()
	# 6시 일출(0) → 12시 정오(1) → 18시 일몰(0)
	var day_t: float = clampf((h - 6.0) / 12.0, 0.0, 1.0)
	var elev: float = sin(day_t * PI)
	var day_amt: float = smoothstep(0.0, 0.35, elev)
	var twilight: float = 0.0
	if h > 4.5 and h < 19.5:
		twilight = 1.0 - day_amt

	if _sun != null:
		_sun.rotation_degrees = Vector3(-lerpf(8.0, 70.0, elev), lerpf(-110.0, 110.0, day_t), 0.0)
		_sun.light_energy = 1.1 * day_amt * light_mult
		_sun.light_color = Color(1.0, 0.72, 0.5).lerp(Color(1.0, 0.97, 0.92), clampf(elev * 2.5, 0.0, 1.0))
		_sun.visible = elev > 0.02

	var night_top = Color(0.04, 0.06, 0.14)
	var night_hor = Color(0.12, 0.15, 0.26)
	var day_top = Color(0.32, 0.50, 0.78)
	var day_hor = Color(0.70, 0.78, 0.88)
	var top: Color = night_top.lerp(day_top, day_amt)
	var hor: Color = night_hor.lerp(day_hor, day_amt).lerp(Color(0.95, 0.55, 0.35), twilight * 0.6)
	if sky_gray > 0.0:
		var gray_v: float = lerpf(0.10, 0.55, day_amt)
		var gray_c = Color(gray_v, gray_v + 0.02, gray_v + 0.05)
		top = top.lerp(gray_c, sky_gray)
		hor = hor.lerp(gray_c.lightened(0.1), sky_gray)

	if _sky != null:
		_sky.sky_top_color = top
		_sky.sky_horizon_color = hor
		_sky.ground_horizon_color = hor
		_sky.ground_bottom_color = Color(0.35, 0.40, 0.36).lerp(Color(0.04, 0.05, 0.07), 1.0 - day_amt)
	if _env != null:
		# 밤에 하늘 빛만으로는 거의 새까매지므로, 밤에는 푸른 달빛 색 주변광을 섞음
		# (ambient_light_sky_contribution 이 Compatibility 렌더러에서 어떻게 보이는지는 미검증)
		_env.ambient_light_color = Color(0.26, 0.31, 0.48)
		_env.ambient_light_sky_contribution = lerpf(0.0, 1.0, day_amt)
		_env.ambient_light_energy = 0.9
		_env.fog_light_color = hor
