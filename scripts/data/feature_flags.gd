extends RefCounted
## 기능 on/off 스위치. 어떤 기능 때문에 게임이 실행되지 않으면 해당 값을 false 로 바꾸면
## 그 기능만 빠지고 나머지 게임은 그대로 실행됩니다. (game_config.gd 와는 별개의 파일)

const ENABLE_INTERACTION: bool = true   # 상호작용 허브(대화, 입장, 앉기, 퀘스트, 저장 등) 전체
const ENABLE_NPCS: bool = true          # 시민 NPC
const ENABLE_INTERIORS: bool = true     # 건물 내부 + 지하시설
const ENABLE_SITTING: bool = true       # 앉기
const ENABLE_CITY_EXTRAS: bool = true   # 추가 건물, 벤치, 차량
const ENABLE_CLOCK: bool = true         # 낮/밤 시간 흐름과 조명 변화
const ENABLE_VEHICLES: bool = true      # 도로 위 차량 (눈으로 보기만 하는 장식)
const SHOW_DEBUG_STATE: bool = true     # 화면 왼쪽 위 디버그 줄

## --- 그래픽 개선 (v0.2.0) : 문제가 생기면 해당 줄만 false 로 바꾸세요 ---
const ENABLE_GFX: bool = true             # 그래픽 모듈 전체 (false 면 v0.1.0 모습)
const GFX_CHARACTERS: bool = true         # 사실적인 인체 모델 (플레이어/NPC)
const GFX_BUILDINGS: bool = true          # 건물 외벽/발코니/옥상 등 덧붙이기
const GFX_ENVIRONMENT: bool = true        # 도로·인도·잔디 텍스처, 횡단보도, 버스정류장, 강, 랜드마크
const GFX_SKY: bool = true                # 구름, 대기 효과, 밤 가로등 빛
## 그래픽 품질 0=낮음(빠름) 1=보통 2=높음. 느리면 0 으로.
const GFX_QUALITY: int = 1

## --- V1.0 확장 (차량 운전, 도시 경계/NPC 반응, 랜드마크, 사회 시스템, 새 UI) ---
## 문제가 생기면 해당 줄만 false 로 바꾸세요. ENABLE_V1=false 면 v0.2.0 상태와 같습니다.
const ENABLE_V1: bool = true
const V1_LANDMARKS: bool = true    # 평양 풍 랜드마크 (류경호텔, 개선문, 주체탑, 만수대 ...)
const V1_DRIVING: bool = true      # 탑승/운전 가능한 차량, 택시
const V1_ALERT: bool = true        # 위협 버튼, 도시 경계 단계, 경찰 출동, 시민 반응
const V1_SOCIAL: bool = true       # 신뢰도, 소문, 새 NPC/임무
const V1_INTERIORS: bool = true    # 옥류관, 지하철역, 상점 내부
const V1_UI: bool = true           # 미니맵, 설정 화면, 운전 화면
const V1_TRAFFIC: bool = true      # 버스 정차와 승객

## --- V2.0 확장 (평양역, 날씨, 새 랜드마크, 부가 임무, 이어하기 화면) ---
## 문제가 생기면 해당 줄만 false 로 바꾸세요. ENABLE_V2=false 면 V1.0 상태와 같습니다. (ENABLE_V1=false 면 V2 도 꺼짐)
const ENABLE_V2: bool = true
const V2_LANDMARKS: bool = true    # 평양역, 주차장, 창전거리 풍/미래과학자거리 풍
const V2_STATION: bool = true      # 평양역 내부 + 평양역 임무 (V2_LANDMARKS 필요)
const V2_WEATHER: bool = true      # 맑음/흐림/비/안개
const V2_QUESTS: bool = true       # 부가 임무 자동 진행 (택시 손님, 마음을 얻다, 추적 따돌리기)
const V2_TITLE: bool = true        # 시작 화면 (새 게임 / 이어하기)

## --- V2.2 확장 (출구 추락 방지, 통행증/검문소, NPC 상호작용, 새 지역, 비밀통로, 미션) ---
## 문제가 생기면 해당 줄만 false 로 바꾸세요. ENABLE_V22=false 면 V2.1 상태와 같습니다.
const ENABLE_V22: bool = true
const V22_SAFE_EXIT: bool = true   # 실내 → 바깥 이동 때 바닥을 찾아 정확히 내려놓기 + 추락 복구
const V22_WORLD: bool = true       # 새 지역 (남쪽 광장, 강변, 장마당, 빈민 주거지, 통제구역, 군사시설 ...)
const V22_PASS: bool = true        # 통행증과 검문소
const V22_SOCIAL: bool = true      # NPC 설득/위협/뇌물/부탁/거래/정보
const V22_INTERIORS: bool = true   # 비밀 지하 통로 + 버려진 건물 내부
const V22_QUESTS: bool = true      # 새 임무와 랜덤 이벤트
const V22_AUDIO: bool = true       # 방송 자막과 합성 배경음 (소리는 폰에서 확인 필요)

## --- V2.3 확장 (가상의 중앙 청사 + 사저, 자체 점검) ---
## 문제가 생기면 해당 줄만 false 로 바꾸세요. ENABLE_V22=false 면 둘 다 꺼짐.
const V23_LEADER: bool = true      # 중앙 청사(집무실) + 사저 + 정문 검문 + 임무 q_v23_leader
const V23_SELFTEST: bool = true    # 게임 시작 때 한 번 자동 점검 → user://v22_selftest.txt 저장

## --- V3.0 확장 (스토리 캠페인, 최고지도자 통치 모드, 국가 지표/정책/도시 개발) ---
## 문제가 생기면 해당 줄만 false 로 바꾸세요. V23_LEADER=false 면 V3 도 꺼짐 (청사가 없으면 대면 장면이 없음).
const ENABLE_V3: bool = true       # V3.0 전체 (false 면 V2.3 상태와 같음)
const V3_STORY: bool = true        # ACT 진행, 지도자 대면, 권력 승계 장면
const V3_GOVERN: bool = true       # 국가 지표, 정책, 회의, 목표
const V3_BUILD: bool = true        # 도시 개발(건설)
const V3_UI: bool = true           # 통치 버튼/지표 표시 (통치 메뉴 자체는 지도자가 된 뒤 열림)
## 시험용 지름길 (보통은 false). 한 번만 적용되며, 시작 7초 뒤 자유 상태일 때 실행됩니다.
const V3_TEST_LEDGER: bool = false  # true: 특별 통행증 + 장부를 지급하고 청사 정문 앞으로 이동 (집무실 대면 장면을 바로 시험)
const V3_TEST_LEADER: bool = false  # true: 곧바로 승계 장면(유언 승계)을 거쳐 지도자가 됨 (통치 메뉴를 바로 시험)

## 자동 생성 시민 수. 폰이 느리면 줄이세요 (0 이면 이름 있는 시민 6명만)
const CROWD_COUNT: int = 10
## 추가 건물 수
const EXTRA_BUILDINGS: int = 10


## ── 사용자 설정(설정 화면)이 반영된 값. v1/game_settings.gd 를 실행 중에 불러오며,
##    그 파일에 문제가 있어도 위의 기본값으로 동작합니다. ──
static func _gs():
	var sc = load("res://scripts/v1/game_settings.gd")
	if sc != null and sc.can_instantiate():
		return sc
	return null


static func gfx_enabled() -> bool:
	var sc = _gs()
	if sc == null:
		return ENABLE_GFX
	return bool(sc.gfx_enabled(ENABLE_GFX))


static func gfx_quality() -> int:
	var sc = _gs()
	if sc == null:
		return GFX_QUALITY
	return int(sc.gfx_quality(GFX_QUALITY))


static func crowd_count() -> int:
	var sc = _gs()
	if sc == null:
		return CROWD_COUNT
	return int(sc.crowd_count(CROWD_COUNT))


static func traffic_count(default_n: int) -> int:
	var sc = _gs()
	if sc == null:
		return default_n
	return int(sc.traffic_count(default_n))


static func shadows_on(default_on: bool) -> bool:
	var sc = _gs()
	if sc == null:
		return default_on
	return bool(sc.shadows(default_on))


static func minimap_on() -> bool:
	var sc = _gs()
	if sc == null:
		return true
	return bool(sc.minimap(true))


## ── V2 설정 값 (설정 화면) ──
static func setting_bool(key: String, default_v: bool) -> bool:
	var sc = _gs()
	if sc == null:
		return default_v
	return bool(sc.get_bool(key, default_v))


static func setting_int(key: String, default_v: int) -> int:
	var sc = _gs()
	if sc == null:
		return default_v
	return int(sc.get_int(key, default_v))


static func weather_on() -> bool:
	return setting_bool("weather", V2_WEATHER)


static func fps_on() -> bool:
	return setting_bool("fps", true)


## 시야 거리 0=가깝게 1=보통 2=멀리(기본, 카메라 원래 값 그대로)
static func view_step() -> int:
	return clampi(setting_int("view_step", 2), 0, 2)
