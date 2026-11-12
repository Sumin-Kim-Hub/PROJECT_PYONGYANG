extends Node
## 그래픽 개선 모듈의 총괄. 허브(interaction_system.gd)가 가장 먼저 불러서 build() 를 기다립니다.
## 각 하위 모듈은 load() + can_instantiate() 로 불러오므로, 한 모듈에 문법 오류가 있어도
## 나머지(그리고 기본 게임)는 계속 실행됩니다.

const Flags = preload("res://scripts/data/feature_flags.gd")

var hub = null
var _player = null
var _clock = null
var _anim = null
var _vis: Node3D = null
var _buildings = null
var _env = null
var _sky = null
var _acc: float = 0.0
## build() 가 끝까지 실행됐는지 (중간에 오류로 멈추면 false 로 남음)
var done: bool = false


func _make(path: String):
	var s = load(path)
	if s == null or not s.can_instantiate():
		push_error("그래픽 모듈을 불러오지 못했습니다(해당 효과만 빠집니다): " + path)
		return null
	return s.new()


## 허브가 기다리지 않고 시작시키는 진입점
func start(world: Node3D, p_hub) -> void:
	await build(world, p_hub)
	done = true


## 최대 max_sec 초까지 build 완료를 기다림 (오류로 멈춘 경우 그냥 넘어가기 위함)
func wait_done(max_sec: float) -> void:
	var t: float = 0.0
	while not done and t < max_sec:
		await get_tree().process_frame
		t += get_process_delta_time()


func build(world: Node3D, p_hub) -> void:
	hub = p_hub
	_player = hub.player
	_clock = hub.clock
	var qual: int = Flags.gfx_quality()
	if not Flags.ENABLE_GFX or not Flags.gfx_enabled():
		return
	var tree: SceneTree = get_tree()

	if Flags.GFX_CHARACTERS:
		_swap_player()
		await tree.process_frame

	var details = null
	if Flags.GFX_BUILDINGS or Flags.GFX_ENVIRONMENT:
		details = _make("res://scripts/gfx/gfx_details.gd")

	if details != null and Flags.GFX_ENVIRONMENT:
		_env = _make("res://scripts/gfx/gfx_environment.gd")
		if _env != null:
			await _env.build(world, details, qual)

	if details != null and Flags.GFX_BUILDINGS:
		_buildings = _make("res://scripts/gfx/gfx_buildings.gd")
		if _buildings != null:
			_buildings.setup_materials()
			await _buildings.build(world, details, qual)

	if details != null:
		details.flush(world)

	if Flags.GFX_SKY:
		_sky = _make("res://scripts/gfx/gfx_sky.gd")
		if _sky != null:
			var lamps: Array = []
			if _env != null:
				lamps = _env.lamp_positions
			_sky.setup(world, _player, _clock, lamps, qual)


func _swap_player() -> void:
	var cb = load("res://scripts/gfx/character_builder.gd")
	var an = load("res://scripts/gfx/character_animator.gd")
	if cb == null or an == null or not cb.can_instantiate() or not an.can_instantiate():
		push_error("캐릭터 모듈을 불러오지 못했습니다. 기존 캐릭터를 그대로 씁니다.")
		return
	var vis = _player.get_node_or_null("Visual")
	if vis == null:
		return
	var built = cb.build(cb.player_spec(), 0.0, 90.0, true)
	if built == null or not (built is Dictionary) or not built.has("root"):
		push_error("플레이어 모델 생성에 실패했습니다. 기존 캐릭터를 그대로 씁니다.")
		return
	for c in vis.get_children():
		c.queue_free()
	vis.add_child(built["root"])
	var a = an.new()
	a.setup(built, 0.0)
	_anim = a
	_vis = vis


func _process(delta: float) -> void:
	if _anim != null and _player != null and is_instance_valid(_player) and _vis != null:
		var vel: Vector3 = _player.velocity
		var sp: float = Vector2(vel.x, vel.z).length()
		# 허브 모드: FREE=0, DIALOGUE=1, SITTING=2, TRANSITION=3, MENU=4
		var sitting: bool = hub != null and int(hub.mode) == 2
		_anim.update(delta, sp, _player.is_on_floor(), vel.y, sitting, false, _vis.position.y)

	if _sky != null:
		_sky.update(delta)

	if _env != null and _env.water_mat != null:
		_env.water_mat.uv1_offset = Vector3(fmod(Time.get_ticks_msec() * 0.00002, 1.0), 0.0, 0.0)

	_acc += delta
	if _acc >= 0.5:
		_acc = 0.0
		_slow_update()


func _slow_update() -> void:
	if _clock == null:
		return
	var h: float = _clock.hour_float()
	var night: float = 0.0
	if h >= 20.0 or h <= 4.5:
		night = 1.0
	elif h >= 17.0:
		night = (h - 17.0) / 3.0
	elif h < 7.0:
		night = (7.0 - h) / 2.5
	if _buildings != null:
		_buildings.set_night_glow(night * 1.6)
	if _env != null and _env.lamp_mat != null:
		_env.lamp_mat.emission_energy_multiplier = 0.4 + 2.2 * night
