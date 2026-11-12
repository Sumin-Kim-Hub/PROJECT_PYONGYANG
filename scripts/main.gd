extends Node3D
## 게임 진입점. 하늘/조명, 도시, 플레이어, 카메라, 터치 UI를 코드로 조립합니다.
## (씬 파일에는 이 노드 하나만 있고, 나머지는 실행할 때 만들어집니다.)

const Cfg = preload("res://scripts/game_config.gd")
const WorldBuilder = preload("res://scripts/world_builder.gd")
const PlayerScript = preload("res://scripts/player.gd")
const CameraRigScript = preload("res://scripts/camera_rig.gd")
const TouchControlsScript = preload("res://scripts/touch_controls.gd")
const Flags = preload("res://scripts/data/feature_flags.gd")


func _ready() -> void:
	Engine.max_fps = Cfg.TARGET_FPS
	_setup_environment()

	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	var builder = WorldBuilder.new()
	builder.build(world)

	# 터치 UI (화면 위에 겹쳐서 그려지는 층)
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var controls = TouchControlsScript.new()
	controls.name = "TouchControls"
	layer.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 카메라와 플레이어
	var rig = CameraRigScript.new()
	rig.name = "CameraRig"
	add_child(rig)

	var player = PlayerScript.new()
	player.name = "Player"
	player.position = Cfg.PLAYER_SPAWN
	add_child(player)

	rig.setup(player, controls)
	player.setup(controls, rig)

	# 상호작용 / 시민 / 건물 내부 / 퀘스트 / 저장 등을 담당하는 허브.
	# load() 로 불러와서, 이 모듈에 문제가 있어도 위의 기본 게임(이동, 카메라, 도시)은 그대로 실행됩니다.
	if Flags.ENABLE_INTERACTION:
		var sys_script = load("res://scripts/interaction/interaction_system.gd")
		if sys_script != null and sys_script.can_instantiate():
			var sys = sys_script.new()
			sys.name = "InteractionSystem"
			add_child(sys)
			sys.setup(player, rig, controls, world)
		else:
			push_error("InteractionSystem 스크립트를 불러오지 못했습니다. 기본 게임은 계속 실행됩니다.")


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.50, 0.78)
	sky_mat.sky_horizon_color = Color(0.70, 0.78, 0.88)
	sky_mat.ground_horizon_color = Color(0.70, 0.78, 0.88)
	sky_mat.ground_bottom_color = Color(0.35, 0.40, 0.36)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.79, 0.88)
	env.fog_density = 0.0018

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = Cfg.SHADOWS
	sun.directional_shadow_max_distance = Cfg.SHADOW_DISTANCE
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
