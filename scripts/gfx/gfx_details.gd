extends RefCounted
## 작은 장식 물체(발코니, 난간, 실외기, 옥상 구조물, 횡단보도 줄무늬 등)를 모아서
## MultiMesh 3개(상자/원기둥/구)로 한꺼번에 그리는 도우미. → 그리기 호출이 몇 번으로 줄어듭니다.
## 색은 물체마다 따로 지정할 수 있습니다 (vertex color).

var _boxes: Array = []
var _cyls: Array = []
var _spheres: Array = []
var _cones: Array = []


func box(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	var b: Basis = Basis(Vector3.UP, yaw) * Basis.from_scale(size)
	_boxes.append([Transform3D(b, center), color])


## 월드 좌표계의 임의 변환(Transform3D)으로 상자를 놓음. 건물이 회전해 있을 때 사용.
func box_xf(xf: Transform3D, size: Vector3, color: Color) -> void:
	var t = Transform3D(xf.basis * Basis.from_scale(size), xf.origin)
	_boxes.append([t, color])


func cyl(center: Vector3, radius: float, height: float, color: Color) -> void:
	var b: Basis = Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0))
	_cyls.append([Transform3D(b, center), color])


func cyl_xf(xf: Transform3D, radius: float, height: float, color: Color) -> void:
	var t = Transform3D(xf.basis * Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0)), xf.origin)
	_cyls.append([t, color])


## 원뿔 (밑면 반지름 radius, 위는 뾰족)
func cone(center: Vector3, radius: float, height: float, color: Color) -> void:
	var b: Basis = Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0))
	_cones.append([Transform3D(b, center), color])


func sphere(center: Vector3, radii: Vector3, color: Color) -> void:
	var b: Basis = Basis.from_scale(radii * 2.0)
	_spheres.append([Transform3D(b, center), color])


func count() -> int:
	return _boxes.size() + _cyls.size() + _spheres.size() + _cones.size()


## 모은 물체들을 parent 아래에 MultiMeshInstance3D 로 만든다. 만든 뒤에는 목록을 비운다.
func flush(parent: Node3D, label: String = "Details") -> void:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.roughness = 0.85

	if not _boxes.is_empty():
		var m = BoxMesh.new()
		m.size = Vector3.ONE
		_make(parent, label + "_Box", m, mat, _boxes)
	if not _cyls.is_empty():
		var c = CylinderMesh.new()
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = 8
		c.rings = 1
		_make(parent, label + "_Cyl", c, mat, _cyls)
	if not _spheres.is_empty():
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 8
		s.rings = 4
		_make(parent, label + "_Sph", s, mat, _spheres)
	if not _cones.is_empty():
		var k = CylinderMesh.new()
		k.top_radius = 0.0
		k.bottom_radius = 0.5
		k.height = 1.0
		k.radial_segments = 8
		k.rings = 1
		_make(parent, label + "_Cone", k, mat, _cones)
	_boxes = []
	_cyls = []
	_spheres = []
	_cones = []


func _make(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, items: Array) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in range(items.size()):
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
