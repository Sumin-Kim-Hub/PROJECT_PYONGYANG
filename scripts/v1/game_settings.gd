extends RefCounted
## 사용자 설정 (user://pyongyang_settings.json). 메뉴 > 설정 에서 바꾸며, 앱을 다시 켜면 적용되는 항목도 있습니다.
## 파일이 없거나 깨져 있으면 기본값을 씁니다. 모든 접근은 정적 함수입니다.

const PATH: String = "user://pyongyang_settings.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {}
	if not FileAccess.file_exists(PATH):
		# V3.0.4: 브라우저(웹) 버전의 첫 실행에서만 가벼운 기본값을 씁니다. (앱/PC 에서는 아무 영향 없음)
		# 사용자가 설정 화면에서 바꾸면 그 값이 우선합니다. 설정을 바꾸기 전까지는 파일에 저장되지 않습니다.
		if OS.has_feature("web"):
			_data = {
				"gfx_quality": 0, "shadows": false, "crowd_step": 1,
				"traffic_step": 1, "view_step": 1, "max_police": 3,
			}
		return
	var f = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		for k in parsed.keys():
			_data[str(k)] = parsed[k]


static func get_int(key: String, default_v: int) -> int:
	_load()
	var v = _data.get(key, default_v)
	if v is int or v is float:
		return int(v)
	return default_v


static func get_bool(key: String, default_v: bool) -> bool:
	_load()
	var v = _data.get(key, default_v)
	if v is bool:
		return v
	return default_v


static func set_value(key: String, value) -> void:
	_load()
	_data[key] = value
	save()


static func save() -> void:
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_data))
	f.close()


## 그래픽 품질 0/1/2 (feature_flags 값이 기본)
static func gfx_quality(default_v: int) -> int:
	return clampi(get_int("gfx_quality", default_v), 0, 2)


## 그래픽 모듈 전체 사용 여부
static func gfx_enabled(default_v: bool) -> bool:
	return get_bool("gfx_enabled", default_v)


## 군중 수 배율 단계 0~3 -> 0, 4, 10, 18명
static func crowd_count(default_v: int) -> int:
	var step: int = get_int("crowd_step", -1)
	if step < 0:
		return default_v
	var table: Array = [0, 4, 10, 18]
	return int(table[clampi(step, 0, 3)])


static func shadows(default_v: bool) -> bool:
	return get_bool("shadows", default_v)


static func minimap(default_v: bool) -> bool:
	return get_bool("minimap", default_v)


static func traffic_count(default_v: int) -> int:
	var step: int = get_int("traffic_step", -1)
	if step < 0:
		return default_v
	var table: Array = [0, 4, 8, 12]
	return int(table[clampi(step, 0, 3)])
