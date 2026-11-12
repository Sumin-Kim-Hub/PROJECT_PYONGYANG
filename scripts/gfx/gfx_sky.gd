extends RefCounted
## 하늘 구름 돔, 대기 보정, 밤 가로등 빛(가까운 가로등 몇 개에만 진짜 조명).
## Compatibility 렌더러에서 쓸 수 있는 기능만 사용합니다 (셰이더 없이 StandardMaterial3D 만).

const Tex = preload("res://scripts/gfx/gfx_textures.gd")

const DOME_RADIUS: float = 280.0
const LAMP_COUNT: int = 6

var _dome: MeshInstance3D = null
var _dome_mat: StandardMaterial3D = null
var _lights: Array = []
var _lamp_pos: Array = []
var _player = null
var _clock = null
var _timer: float = 0.0
var _scroll: float = 0.0


## 시각(시) → 밤 정도 0~1 (해질녘/새벽에는 중간값)
static func night_amount(h: float) -> float:
	if h >= 20.0 or h <= 4.5:
		return 1.0
	if h >= 17.0:
		return (h - 17.0) / 3.0
	if h < 7.0:
		return (7.0 - h) / 2.5
	return 0.0


func setup(parent: Node, player, clock, lamp_positions: Array, quality: int) -> void:
	_player = player
	_clock = clock
	_lamp_pos = lamp_positions

	_dome_mat = StandardMaterial3D.new()
	_dome_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dome_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dome_mat.vertex_color_use_as_albedo = true
	_dome_mat.albedo_texture = Tex.cloud()
	_dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dome_mat.disable_fog = true
	_dome_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	_dome_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_dome = MeshInstance3D.new()
	_dome.name = "CloudDome"
	_dome.mesh = _make_dome()
	_dome.material_override = _dome_mat
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(_dome)

	var n: int = LAMP_COUNT if quality >= 1 else 3
	if _lamp_pos.size() > 0:
		for i in range(n):
			var l = OmniLight3D.new()
			l.omni_range = 15.0
			l.omni_attenuation = 1.2
			l.light_color = Color(1.0, 0.86, 0.62)
			l.light_energy = 0.0
			l.shadow_enabled = false
			l.light_cull_mask = 1
			l.visible = false
			parent.add_child(l)
			_lights.append(l)

	# 대기: 약한 대비/채도 보정 (Compatibility 에서도 지원되는 항목만)
	var we = parent.get_tree().root.find_child("WorldEnvironment", true, false)
	if we != null and we is WorldEnvironment and we.environment != null:
		var env: Environment = we.environment
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.05
		env.adjustment_saturation = 1.08
		env.fog_density = 0.0014


func _make_dome() -> ArrayMesh:
	var seg: int = 28
	var rings: int = 8
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var cols = PackedColorArray()
	var idx = PackedInt32Array()
	for i in range(rings + 1):
		var e: float = (PI * 0.5) * float(i) / float(rings)
		var ce: float = cos(e)
		var se: float = sin(e)
		for j in range(seg):
			var a: float = TAU * float(j) / float(seg)
			var p = Vector3(ce * cos(a) * DOME_RADIUS, se * DOME_RADIUS, ce * sin(a) * DOME_RADIUS)
			verts.append(p)
			uvs.append(Vector2(p.x / DOME_RADIUS * 0.5 + 0.5, p.z / DOME_RADIUS * 0.5 + 0.5))
			cols.append(Color(1, 1, 1, smoothstep(0.06, 0.45, se)))
	for i2 in range(rings):
		for j2 in range(seg):
			var jn: int = (j2 + 1) % seg
			var a0: int = i2 * seg + j2
			var a1: int = i2 * seg + jn
			var b0: int = (i2 + 1) * seg + j2
			var b1: int = (i2 + 1) * seg + jn
			idx.append(a0)
			idx.append(a1)
			idx.append(b1)
			idx.append(a0)
			idx.append(b1)
			idx.append(b0)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func update(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pp: Vector3 = _player.global_position
	var outdoors: bool = pp.y < 100.0
	if _dome != null:
		_dome.visible = outdoors
		_dome.global_position = Vector3(pp.x, 0.0, pp.z)
		_scroll += delta * 0.004
		_dome_mat.uv1_offset = Vector3(_scroll, _scroll * 0.4, 0.0)

	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	var h: float = 12.0
	if _clock != null:
		h = _clock.hour_float()
	var night: float = night_amount(h)
	if _dome_mat != null:
		var day_c = Color(1.0, 1.0, 1.0, 1.0)
		var dusk_c = Color(1.0, 0.78, 0.68, 1.0)
		var night_c = Color(0.16, 0.19, 0.28, 1.0)
		var c: Color = day_c
		if night > 0.0 and night < 1.0:
			c = day_c.lerp(dusk_c, night * 2.0) if night < 0.5 else dusk_c.lerp(night_c, (night - 0.5) * 2.0)
		elif night >= 1.0:
			c = night_c
		_dome_mat.albedo_color = c

	# 플레이어에서 가까운 가로등 몇 개에만 진짜 불빛을 켬
	if _lights.is_empty():
		return
	var used: Array = []
	for light in _lights:
		var best: int = -1
		var best_d: float = 60.0 * 60.0
		for k in range(_lamp_pos.size()):
			if used.has(k):
				continue
			var lp: Vector3 = _lamp_pos[k]
			var d2: float = (lp.x - pp.x) * (lp.x - pp.x) + (lp.z - pp.z) * (lp.z - pp.z)
			if d2 < best_d:
				best_d = d2
				best = k
		if best < 0 or night <= 0.02 or not outdoors:
			light.visible = false
			light.light_energy = 0.0
		else:
			used.append(best)
			var pos: Vector3 = _lamp_pos[best]
			light.global_position = Vector3(pos.x, pos.y - 0.4, pos.z)
			light.light_energy = 1.7 * night
			light.visible = true
