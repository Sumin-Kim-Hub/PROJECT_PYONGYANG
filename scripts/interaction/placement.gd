extends RefCounted
## 배치 도우미. 물리 충돌 검사로 "아무것도 없는 빈 자리"를 찾습니다.
## 건물 배치를 직접 바꾸셨어도 NPC나 새 건물이 건물 안에 박히지 않도록 하기 위한 것입니다.


static func is_free_capsule(world: World3D, pos: Vector3, radius: float, height: float) -> bool:
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var shape = CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	# 바닥(y=0)과 겹치지 않도록 0.2m 띄워서 검사
	params.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0.0, height * 0.5 + 0.2, 0.0))
	params.collision_mask = 1
	var hits: Array = space.intersect_shape(params, 1)
	return hits.is_empty()


static func is_free_box(world: World3D, pos: Vector3, size: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var shape = BoxShape3D.new()
	shape.size = size
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0.0, size.y * 0.5 + 0.3, 0.0))
	params.collision_mask = 1
	var hits: Array = space.intersect_shape(params, 1)
	return hits.is_empty()


## center 에서 가까운 순서로 비어 있는 자리를 찾아 반환. 못 찾으면 center 그대로.
static func find_free_capsule(world: World3D, center: Vector3, radius: float, height: float) -> Vector3:
	for ring in range(0, 9):
		var count: int = 1 if ring == 0 else 8
		for k in range(count):
			var ang: float = TAU * float(k) / float(count)
			var p: Vector3 = center + Vector3(cos(ang), 0.0, sin(ang)) * (float(ring) * 2.0)
			if is_free_capsule(world, p, radius, height):
				return p
	push_warning("빈 자리를 찾지 못해 원래 위치를 사용합니다: %s" % str(center))
	return center


## 상자 모양 건물이 들어갈 빈 자리를 찾는다. size 는 여유 공간을 포함한 크기.
static func find_free_box(world: World3D, center: Vector3, size: Vector3) -> Vector3:
	for ring in range(0, 11):
		var count: int = 1 if ring == 0 else 8
		for k in range(count):
			var ang: float = TAU * float(k) / float(count)
			var p: Vector3 = center + Vector3(cos(ang), 0.0, sin(ang)) * (float(ring) * 5.0)
			if is_free_box(world, p, size):
				return p
	push_warning("건물을 놓을 빈 자리를 찾지 못해 원래 위치를 사용합니다: %s" % str(center))
	return center
