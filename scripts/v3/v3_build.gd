extends Node
## V3.0 도시 개발 (건설). 기존 도시를 부수지 않고, 빈 땅에 새 건물/공원/도로를 "추가"한다.
##  - 건설 모드: 플레이어 앞쪽에 반투명 건물이 따라온다. 초록=건설 가능, 빨강=불가. 확정/회전/취소 버튼은 UI 가 그린다.
##  - 건설 가능 조건: 지도 안, 큰길·중앙 광장·청사 구역 밖, 다른 건물/장애물과 안 겹침, 출입구 근처 아님, 예산 충분.
##  - 지은 건물은 저장되고 불러오면 다시 세워진다. (Godot 실행 미검증)

const D = preload("res://scripts/v3/v3_data.gd")
const Kit = preload("res://scripts/interior/interior_kit.gd")
const Placement = preload("res://scripts/interaction/placement.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")

const GRID: float = 2.0
const MAP_LIMIT: float = 370.0

var hub = null
var mgr = null
var gov = null
var root: Node3D = null

## 지은 건물 기록: {"t": 종류, "x": float, "z": float, "r": 0|1}
var placed: Array = []
var _nodes: Array = []

## 건설 모드 상태
var placing: bool = false
var place_type: String = ""
var place_rot: int = 0
var ghost_pos: Vector3 = Vector3.ZERO
var ghost_ok: bool = false
var ghost_reason: String = ""
var _ghost: Node3D = null
var _ghost_mesh: MeshInstance3D = null
var _ghost_mat: StandardMaterial3D = null
var _check_t: float = 0.0
var _last_size: Vector3 = Vector3.ZERO


func setup(hub_ref, mgr_ref, gov_ref) -> void:
	hub = hub_ref
	mgr = mgr_ref
	gov = gov_ref
	root = Node3D.new()
	root.name = "V3_City"
	if hub != null and hub.world != null:
		hub.world.add_child(root)
	else:
		add_child(root)


func count() -> int:
	return placed.size()


func count_of(tid: String) -> int:
	var n: int = 0
	for r in placed:
		if str(r["t"]) == tid:
			n += 1
	return n


## 정산에 필요한 건물 합계
func totals() -> Dictionary:
	var up: float = 0.0
	var inc: float = 0.0
	var pt: Dictionary = {}
	for r in placed:
		var def: Dictionary = D.building_by_id(str(r["t"]))
		if def.is_empty():
			continue
		up += float(def["upkeep"])
		inc += float(def["income"])
		var p: Dictionary = def["ptick"]
		for k in p.keys():
			pt[k] = float(pt.get(k, 0.0)) + float(p[k])
	return {"upkeep": up, "income": inc, "ptick": pt}


func last_position() -> Vector3:
	if placed.is_empty():
		return Vector3(60.0, 0.0, 60.0)
	var r: Dictionary = placed[placed.size() - 1]
	return Vector3(float(r["x"]), 0.0, float(r["z"]))


# ================================================================ 자리 검사

func _rect(x: float, z: float, def: Dictionary, rot: int) -> Rect2:
	var w: float = float(def["w"])
	var d: float = float(def["d"])
	if rot == 1:
		var t: float = w
		w = d
		d = t
	return Rect2(x - w * 0.5, z - d * 0.5, w, d)


func check_site(tid: String, x: float, z: float, rot: int) -> String:
	var def: Dictionary = D.building_by_id(tid)
	if def.is_empty():
		return "알 수 없는 건물입니다."
	if placed.size() >= D.MAX_BUILDINGS:
		return "더 이상 지을 수 없습니다. (최대 %d채)" % D.MAX_BUILDINGS
	if hub == null or hub.player == null:
		return "준비 중입니다."
	if hub.player.global_position.y > 100.0:
		return "건물 안에서는 지을 수 없습니다."
	var r: Rect2 = _rect(x, z, def, rot)
	if absf(x) + r.size.x * 0.5 > MAP_LIMIT or absf(z) + r.size.y * 0.5 > MAP_LIMIT:
		return "지도 가장자리입니다."
	# 청사 구역(담 안팎)
	if r.intersects(Rect2(-318.0, -390.0, 140.0, 118.0)):
		return "중앙 청사 구역 근처에는 지을 수 없습니다."
	# 큰길(동서/남북)과 중앙 광장
	if r.intersects(Rect2(-252.0, -20.0, 504.0, 40.0)):
		return "큰길 위에는 지을 수 없습니다."
	if r.intersects(Rect2(-20.0, -52.0, 40.0, 304.0)):
		return "큰길 위에는 지을 수 없습니다."
	if r.intersects(Rect2(-52.0, -52.0, 104.0, 104.0)):
		return "중앙 광장 구역입니다."
	# 이미 지은 건물
	for rec in placed:
		var od: Dictionary = D.building_by_id(str(rec["t"]))
		if od.is_empty():
			continue
		var orc: Rect2 = _rect(float(rec["x"]), float(rec["z"]), od, int(rec["r"]))
		var margin: float = 0.0 if (tid == "road" and str(rec["t"]) == "road") else 2.0
		if r.grow(margin).intersects(orc):
			return "다른 개발 시설과 겹칩니다."
	# 플레이어가 안에 갇히지 않게
	var pp: Vector3 = hub.player.global_position
	if r.grow(1.0).has_point(Vector2(pp.x, pp.z)):
		return "플레이어가 서 있는 자리입니다. 조금 물러나세요."
	# 출입구/상호작용 지점 근처
	var near: Rect2 = r.grow(3.0)
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D):
			continue
		var gp: Vector3 = (n as Node3D).global_position
		if gp.y > 100.0:
			continue
		if near.has_point(Vector2(gp.x, gp.z)):
			return "출입구나 상호작용 지점 근처입니다."
	# 물리 충돌 검사(기존 건물, 나무 등)
	if hub.world != null:
		var w3: World3D = hub.world.get_world_3d()
		if w3 != null:
			var sz: Vector3 = Vector3(r.size.x, minf(float(def["h"]), 4.0), r.size.y)
			var test_h: float = maxf(sz.y, 1.0)
			if not Placement.is_free_box(w3, Vector3(x, 0.0, z), Vector3(sz.x, test_h, sz.z)):
				return "다른 건물이나 장애물과 겹칩니다."
	return ""


func can_afford(tid: String) -> bool:
	var def: Dictionary = D.building_by_id(tid)
	if def.is_empty() or gov == null:
		return false
	return float(gov.ind.get("budget", 0.0)) >= float(def["cost"])


# ================================================================ 건설 모드(미리보기)

func start_placing(tid: String) -> bool:
	var def: Dictionary = D.building_by_id(tid)
	if def.is_empty():
		return false
	place_type = tid
	place_rot = 0
	placing = true
	_make_ghost(def)
	_check_t = 0.0
	update_ghost(0.0, true)
	return true


func cancel_placing() -> void:
	placing = false
	place_type = ""
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_mesh = null
	_ghost_mat = null


func rotate_ghost() -> void:
	if not placing:
		return
	place_rot = 1 - place_rot
	update_ghost(0.0, true)


func _make_ghost(def: Dictionary) -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = Node3D.new()
	_ghost.name = "V3_Ghost"
	if hub != null and hub.world != null:
		hub.world.add_child(_ghost)
	else:
		add_child(_ghost)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.45)
	var mesh: BoxMesh = BoxMesh.new()
	var h: float = maxf(float(def["h"]), 0.4)
	mesh.size = Vector3(float(def["w"]), h, float(def["d"]))
	_ghost_mesh = MeshInstance3D.new()
	_ghost_mesh.mesh = mesh
	_ghost_mesh.material_override = _ghost_mat
	_ghost_mesh.position = Vector3(0.0, h * 0.5, 0.0)
	_ghost_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(_ghost_mesh)


func _forward() -> Vector3:
	var yaw: float = 0.0
	if hub != null and hub.rig != null and "yaw" in hub.rig:
		yaw = float(hub.rig.yaw)
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func update_ghost(delta: float, force: bool = false) -> void:
	if not placing or _ghost == null or hub == null or hub.player == null:
		return
	var def: Dictionary = D.building_by_id(place_type)
	if def.is_empty():
		return
	var half: float = maxf(float(def["w"]), float(def["d"])) * 0.5
	var pp: Vector3 = hub.player.global_position
	var f: Vector3 = _forward()
	var target: Vector3 = pp + f * (half + 4.0)
	target.x = snappedf(target.x, GRID)
	target.z = snappedf(target.z, GRID)
	target.y = 0.0
	ghost_pos = target
	_ghost.position = target
	_ghost.rotation.y = float(place_rot) * PI * 0.5
	_check_t -= delta
	if force or _check_t <= 0.0:
		_check_t = 0.15
		ghost_reason = check_site(place_type, target.x, target.z, place_rot)
		if ghost_reason == "" and not can_afford(place_type):
			ghost_reason = "예산이 부족합니다. (필요 %d)" % int(def["cost"])
		ghost_ok = ghost_reason == ""
		if _ghost_mat != null:
			_ghost_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.45) if ghost_ok else Color(1.0, 0.25, 0.2, 0.45)


## 확정: 성공하면 true
func confirm_place() -> Dictionary:
	if not placing:
		return {"ok": false, "text": "건설 모드가 아닙니다."}
	update_ghost(0.0, true)
	if not ghost_ok:
		return {"ok": false, "text": ghost_reason}
	var def: Dictionary = D.building_by_id(place_type)
	gov.ind["budget"] = float(gov.ind["budget"]) - float(def["cost"])
	gov.apply_delta(def["instant"])
	var rec: Dictionary = {"t": place_type, "x": ghost_pos.x, "z": ghost_pos.z, "r": place_rot}
	placed.append(rec)
	_spawn(rec)
	var msg: String = "건설 완료: %s (예산 -%d)" % [str(def["name"]), int(def["cost"])]
	var eff: String = D.effect_line(def["instant"])
	if eff != "":
		msg += " → " + eff
	gov._check_goals()
	# 같은 건물을 이어서 짓기 쉽도록 모드는 유지
	update_ghost(0.0, true)
	return {"ok": true, "text": msg}


func demolish_last() -> Dictionary:
	if placed.is_empty():
		return {"ok": false, "text": "철거할 개발 시설이 없습니다."}
	var rec: Dictionary = placed.pop_back()
	var def: Dictionary = D.building_by_id(str(rec["t"]))
	var n = _nodes.pop_back()
	if n != null and is_instance_valid(n):
		n.queue_free()
	var refund: int = 0
	if not def.is_empty():
		refund = int(float(def["cost"]) * 0.5)
		gov.ind["budget"] = float(gov.ind["budget"]) + float(refund)
	return {"ok": true, "text": "철거했습니다. (환급 +%d)" % refund}


# ================================================================ 건물 모델

func rebuild_all() -> void:
	for n in _nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_nodes = []
	for rec in placed:
		_spawn(rec)


func clear_all() -> void:
	cancel_placing()
	for n in _nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_nodes = []
	placed = []


func _spawn(rec: Dictionary) -> void:
	var def: Dictionary = D.building_by_id(str(rec["t"]))
	if def.is_empty() or root == null:
		return
	var b: Node3D = Node3D.new()
	b.name = "V3_%s_%d" % [str(rec["t"]), _nodes.size()]
	b.position = Vector3(float(rec["x"]), 0.0, float(rec["z"]))
	b.rotation.y = float(int(rec["r"])) * PI * 0.5
	root.add_child(b)
	_nodes.append(b)
	var w: float = float(def["w"])
	var d: float = float(def["d"])
	var h: float = float(def["h"])
	var col: Color = def["color"]
	match str(def["style"]):
		"park":
			_style_park(b, w, d, col)
		"plaza":
			_style_plaza(b, w, d, col)
		"road":
			_style_road(b, w, d, col)
		"farm":
			_style_farm(b, w, d, h, col)
		"market":
			_style_market(b, w, d, h, col)
		"factory":
			_style_block(b, w, d, h, col, true)
		"tower":
			_style_block(b, w, d, h, col, false)
		_:
			_style_block(b, w, d, h, col, false)
	if str(def["style"]) in ["block", "tower", "factory", "market", "farm"]:
		Kit.label(b, Vector3(0.0, h + 1.2, d * 0.5 + 0.2), str(def["name"]), 1.4, Color(1.0, 0.95, 0.8), 1)
		var it = InteractableScript.new()
		it.kind = "examine"
		it.prompt = "%s 살펴보기" % str(def["name"])
		it.radius = 2.6
		it.data = {"text": "%s — %s\n%s" % [str(def["name"]), str(def["desc"]), D.effect_line(def["instant"])], "effects": [], "once_flag": ""}
		it.position = Vector3(0.0, 1.0, d * 0.5 + 1.8)
		b.add_child(it)


func _style_block(b: Node3D, w: float, d: float, h: float, col: Color, industrial: bool) -> void:
	Kit.box(b, Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), col, true, 1)
	Kit.box(b, Vector3(0.0, h + 0.25, 0.0), Vector3(w + 0.8, 0.5, d + 0.8), col.darkened(0.35), false, 1)
	# 앞면 창문 줄
	var rows: int = maxi(1, int(h / 3.2))
	var cols: int = maxi(2, int(w / 4.0))
	for ry in range(rows):
		for cx in range(cols):
			var px: float = -w * 0.5 + (float(cx) + 0.5) * (w / float(cols))
			var py: float = 2.6 + float(ry) * 3.2
			if py > h - 0.8:
				continue
			Kit.box(b, Vector3(px, py, d * 0.5 + 0.06), Vector3(1.3, 1.5, 0.1), Color(0.55, 0.72, 0.88), false, 1, 0.25)
	Kit.box(b, Vector3(0.0, 1.25, d * 0.5 + 0.08), Vector3(2.4, 2.5, 0.12), Color(0.18, 0.14, 0.12), false, 1)
	if industrial:
		Kit.box(b, Vector3(w * 0.3, h + 4.0, -d * 0.2), Vector3(1.8, 8.0, 1.8), Color(0.42, 0.40, 0.38), true, 1)
		Kit.box(b, Vector3(-w * 0.3, 2.2, -d * 0.5 - 1.8), Vector3(3.0, 4.4, 3.0), Color(0.62, 0.64, 0.66), true, 1)


func _style_park(b: Node3D, w: float, d: float, col: Color) -> void:
	Kit.box(b, Vector3(0.0, 0.12, 0.0), Vector3(w, 0.24, d), col, false, 1)
	Kit.box(b, Vector3(0.0, 0.26, 0.0), Vector3(2.0, 0.06, d), Color(0.72, 0.68, 0.58), false, 1)
	var spots: Array = [Vector2(-w * 0.3, -d * 0.3), Vector2(w * 0.3, -d * 0.3), Vector2(-w * 0.3, d * 0.3), Vector2(w * 0.3, d * 0.3), Vector2(0.0, -d * 0.4)]
	for s in spots:
		Kit.box(b, Vector3(s.x, 1.4, s.y), Vector3(0.4, 2.8, 0.4), Color(0.30, 0.22, 0.16), false, 1)
		Kit.box(b, Vector3(s.x, 3.4, s.y), Vector3(2.6, 2.2, 2.6), Color(0.20, 0.42, 0.22), false, 1)
	Kit.box(b, Vector3(-3.0, 0.5, 0.0), Vector3(1.8, 0.5, 0.6), Color(0.40, 0.28, 0.18), false, 1)
	Kit.box(b, Vector3(3.0, 0.5, 0.0), Vector3(1.8, 0.5, 0.6), Color(0.40, 0.28, 0.18), false, 1)


func _style_plaza(b: Node3D, w: float, d: float, col: Color) -> void:
	Kit.box(b, Vector3(0.0, 0.12, 0.0), Vector3(w, 0.24, d), col, false, 1)
	Kit.box(b, Vector3(0.0, 0.4, 0.0), Vector3(6.0, 0.5, 6.0), Color(0.60, 0.60, 0.58), true, 1)
	Kit.box(b, Vector3(0.0, 0.7, 0.0), Vector3(5.0, 0.1, 5.0), Color(0.30, 0.52, 0.72), false, 1)
	Kit.box(b, Vector3(0.0, 1.6, 0.0), Vector3(0.6, 2.0, 0.6), Color(0.78, 0.78, 0.76), false, 1)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var px: float = sx * (w * 0.5 - 1.2)
			var pz: float = sz * (d * 0.5 - 1.2)
			Kit.box(b, Vector3(px, 2.2, pz), Vector3(0.16, 4.4, 0.16), Color(0.25, 0.25, 0.28), false, 1)
			Kit.box(b, Vector3(px, 4.5, pz), Vector3(0.5, 0.18, 0.5), Color(1.0, 0.95, 0.75), false, 1, 1.0)


func _style_road(b: Node3D, w: float, d: float, col: Color) -> void:
	Kit.box(b, Vector3(0.0, 0.05, 0.0), Vector3(w, 0.1, d), col, false, 1)
	var n: int = maxi(2, int(d / 4.0))
	for i in range(n):
		var pz: float = -d * 0.5 + (float(i) + 0.5) * (d / float(n))
		Kit.box(b, Vector3(0.0, 0.11, pz), Vector3(0.25, 0.04, d / float(n) * 0.5), Color(0.85, 0.80, 0.45), false, 1)
	Kit.box(b, Vector3(-w * 0.5 + 0.8, 0.09, 0.0), Vector3(1.4, 0.14, d), Color(0.62, 0.61, 0.58), false, 1)
	Kit.box(b, Vector3(w * 0.5 - 0.8, 0.09, 0.0), Vector3(1.4, 0.14, d), Color(0.62, 0.61, 0.58), false, 1)


func _style_farm(b: Node3D, w: float, d: float, h: float, col: Color) -> void:
	Kit.box(b, Vector3(0.0, 0.1, 0.0), Vector3(w, 0.2, d), Color(0.36, 0.30, 0.22), false, 1)
	var n: int = 3
	for i in range(n):
		var px: float = -w * 0.5 + (float(i) + 0.5) * (w / float(n))
		Kit.box(b, Vector3(px, h * 0.5, 0.0), Vector3(w / float(n) - 1.2, h, d - 2.0), col, true, 1)
		Kit.box(b, Vector3(px, h + 0.3, 0.0), Vector3(w / float(n) - 2.0, 0.6, d - 3.0), col.lightened(0.15), false, 1)
		Kit.box(b, Vector3(px, h * 0.45, d * 0.5 - 0.95), Vector3(w / float(n) - 2.4, h * 0.7, 0.1), Color(0.4, 0.62, 0.44), false, 1, 0.2)


func _style_market(b: Node3D, w: float, d: float, h: float, col: Color) -> void:
	Kit.box(b, Vector3(0.0, 0.1, 0.0), Vector3(w, 0.2, d), Color(0.58, 0.56, 0.52), false, 1)
	var n: int = maxi(3, int(w / 6.0))
	var colors: Array = [Color(0.78, 0.30, 0.24), Color(0.28, 0.52, 0.72), Color(0.86, 0.72, 0.28), Color(0.38, 0.62, 0.38)]
	for i in range(n):
		var px: float = -w * 0.5 + (float(i) + 0.5) * (w / float(n))
		Kit.box(b, Vector3(px - 1.6, 1.4, d * 0.2), Vector3(0.2, 2.8, 0.2), Color(0.34, 0.26, 0.2), false, 1)
		Kit.box(b, Vector3(px + 1.6, 1.4, d * 0.2), Vector3(0.2, 2.8, 0.2), Color(0.34, 0.26, 0.2), false, 1)
		Kit.box(b, Vector3(px, 2.9, d * 0.2), Vector3(4.2, 0.2, 4.0), colors[i % colors.size()], false, 1)
		Kit.box(b, Vector3(px, 0.6, d * 0.2), Vector3(3.0, 1.0, 1.2), col, true, 1)
	Kit.box(b, Vector3(0.0, h * 0.5, -d * 0.5 + 0.5), Vector3(w, h, 1.0), col.darkened(0.2), true, 1)


# ================================================================ 저장

func to_dict() -> Dictionary:
	var arr: Array = []
	for r in placed:
		arr.append({"t": str(r["t"]), "x": float(r["x"]), "z": float(r["z"]), "r": int(r["r"])})
	return {"placed": arr}


func from_dict(dd: Dictionary) -> void:
	clear_all()
	var arr = dd.get("placed")
	if arr is Array:
		for r in arr:
			if r is Dictionary and r.has("t") and D.building_by_id(str(r["t"])).size() > 0:
				placed.append({"t": str(r["t"]), "x": float(r.get("x", 0.0)), "z": float(r.get("z", 0.0)), "r": clampi(int(r.get("r", 0)), 0, 1)})
	rebuild_all()
