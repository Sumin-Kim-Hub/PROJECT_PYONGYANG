# TECHNICAL_ARCHITECTURE (2.0.0-v2)

## 기술 선택
- 엔진: Godot 4.3+ / GDScript, 렌더러 Compatibility (gl_compatibility)
- 화면: 가로, 기준 해상도 1280x720, stretch = canvas_items, aspect = expand
- 외부 서버/유료 API/유료 에셋: 사용 안 함. 모든 인물·장소·사건은 창작(가상)

## 노드 구조 (실행 중)
```
Main (Node3D, main.gd)
├─ WorldEnvironment, Sun            ← GameClock 이 이름으로 찾아 낮밤 조정
├─ World (Node3D)                   world_builder.gd (사용자 수정본)
│   ├─ Ext_tea / Ext_hotel / Ext_apt / Ext_office   들어갈 수 있는 건물 겉모습 (interior_manager)
│   ├─ Extra_N                       장식용 추가 건물 (city_extras)
│   ├─ 벤치, 차량(AnimatableBody3D), NPC_*   (city_extras, npc_manager)
├─ UI (CanvasLayer) → TouchControls   조이스틱/카메라/JUMP/RUN
├─ CameraRig (SpringArm3D → Camera3D) camera_rig.gd (사용자 수정본)
├─ Player (CharacterBody3D)           player.gd (그대로)
└─ InteractionSystem (Node, 허브)
    ├─ GameState, GameClock
    ├─ InteractionLayer(CanvasLayer 3) → InteractionUI   안내 버튼/대화창/암전
    ├─ HudLayer(CanvasLayer 2) → HUD                      시계/임무/경계/버튼/패널
    ├─ InteriorManager → Int_Teahouse, Int_Apartment, Int_HotelLobby, Int_HotelFloor2, Int_Office, Int_Underground (y=300)
    ├─ CityExtras
    └─ NpcManager
```

## 스크립트
| 파일 | 역할 |
|---|---|
| main.gd | 조립. 끝에서 허브를 load() 로 불러와 연결 |
| interaction/interaction_system.gd | **허브**: 상태/시계/UI 생성, 가까운 상호작용 찾기, 대화·출입·앉기·문·조사·줍기, 효과/퀘스트, 경비 발각, 저장/불러오기, 카메라 거리 |
| interaction/interactable.gd | 상호작용 지점 표식 (kind, prompt, radius, data) |
| interaction/placement.gd | 물리 충돌 검사로 빈 자리 찾기 |
| interaction/interaction_ui.gd | 안내 문구/버튼, 대화창, 암전 (직접 그림) |
| ui/hud_ui.gd | HUD와 전체 화면 패널(가방, 임무, 지도, 메뉴) |
| core/game_state.gd | 인벤토리, 플래그, 퀘스트 상태, 발견 장소, 조건 검사 `check()`, 저장용 dict |
| core/game_clock.gd | 게임 시간(실제 12분=하루), 낮밤 조명, 시간대 이름 |
| data/npc_data.gd | NPC 정의, 일과, 대화 그래프, 군중 생성 |
| data/quest_data.gd, item_data.gd | 임무, 아이템 |
| data/feature_flags.gd | 기능 on/off, 군중 수, 추가 건물 수 |
| npc/npc.gd | NPC 본체: 외모, 일과 엔진, 앉기, 사라지기, 길막힘 감지, 경비 시야 |
| npc/npc_manager.gd | NPC 배치 |
| interior/interior_kit.gd | 방·벽(문 구멍)·조명·가구 만드는 정적 도우미 |
| interior/door.gd | 여닫는 문, 잠금(key_item) |
| interior/interior_manager.gd | 건물 겉모습 + 내부 6공간 + 출입구 + 비밀 통로 + 지하시설 + 경비 |
| city/city_extras.gd, vehicle.gd | 벤치, 장식 건물, 차량 |

## 그래픽 모듈 (scripts/gfx/, v0.2.0 — 미실행)
| 파일 | 역할 |
|---|---|
| gfx_manager.gd | 총괄 노드. `start()` 로 비동기 시작, 허브는 `wait_done(8.0)` 로만 기다림. 플레이어 Visual 교체, 매 프레임 플레이어 애니메이션/하늘 갱신, 0.5초마다 밤 창문·가로등 밝기 |
| character_builder.gd | 단면을 쌓는 loft 메시로 몸·머리·옷·머리카락·모자를 만들고 관절 Node3D 계층 구성. 같은 모양 합본 LOD 메시. `spec_from_npc()`, `player_spec()` |
| character_animator.gd | 관절 회전으로 걷기/달리기/점프/앉기/대기/대화. 더 길게 뻗은 다리 기준으로 골반 높이 계산(발 고정) |
| gfx_buildings.gd | `world` 아래 StaticBody3D+BoxMesh 건물을 찾아(높이≥10, 바닥≥8) 외벽 UV 메시·지붕·디테일을 덧씌움. 기존 박스 메시는 숨김 |
| gfx_environment.gd | 땅/도로/인도/광장 재질 교체, 차선·횡단보도·표지판·정류장·전신주·화단·강·다리·랜드마크 |
| gfx_sky.gd | 구름 돔(플레이어 따라다님), 가로등 근처 OmniLight 풀 6개, 환경 보정 |
| gfx_textures.gd | 절차 텍스처(캐시): 외벽 아틀라스, 아스팔트, 인도, 잔디, 지붕, 잎, 물, 구름 |
| gfx_details.gd | 색 지정 MultiMesh 모음 (box/cylinder/cone/sphere) → flush |
| vehicle_model.gd | 승용차/버스 단일 메시 |

- 연결: 허브 `_start_modules()` 맨 앞. NPC(`npc.gd _build_gfx_body`)와 차량(`vehicle.gd _build_gfx`)은 실패 시 기존 박스 모습으로 되돌아감.
- 렌더러: Compatibility 에서 되는 StandardMaterial3D 만 사용(커스텀 셰이더 없음). 그림자는 플레이어만.
- 좌표 규칙: 캐릭터 앞 = −Z, 캐릭터 왼쪽 = −X, +X 회전 = 앞으로 흔들기, 무릎은 −X 회전이 구부림.


## V2.0 모듈 (scripts/v2/, 미실행)
- **연결:** 허브(`interaction_system.gd`)가 `v1.build_world` 직후 `v2 = v2_manager.new()` → `v2.build_world()`(랜드마크), `v1.build_systems` 직후 `v2.build_systems()`(평양역 내부, 주차장 차량, 날씨, FPS 표시, 대화 추가). 저장은 `data["v2"] = v2.to_dict()`. `_try_autoload` 는 `v2.show_title()` 이 true 를 돌려주면 자동 불러오기를 건너뜀.
- `v2_manager.gd`: 1초마다 부가 임무(q_taxi/q_trust/q_escape) 판정과 시야 거리 적용, 매 프레임 메뉴 일시정지·FPS 갱신. 시작 화면 동안 허브 모드 = TRANSITION(자동 저장 차단), 선택 후 FREE.
- `v2_landmarks.gd`: v1 `landmarks.gd`의 `_spot`(빈 자리), `_root`, `_mark`, `clear_trees`, `_details`, `_glass_mat` 와 `lm_kit.gd` 도우미 재사용. `exits["station"]`(root/front/depth/name)을 `v2_interiors` 에 넘김. `parking` 목록은 매니저가 `drive.spawn_one` 으로 차량 생성.
- `v2_interiors.gd`: `interior_extra.gd` 상속(방/문/상호작용/NPC/포털 도우미 재사용), 슬롯 9. 문 `station_guard`(안내원이 풀어 줌), `station_warehouse`(열쇠 `warehouse_key`), 숨겨진 선반 그룹 `reveal_station_panel`(플래그 `station_panel_found`, 불러올 때 `_apply_world_flags` 가 다시 숨김).
- `weather_system.gd`: 상태 clear/cloudy/rain/fog, 값(light, gray, fog, rain, vision)을 부드럽게 보간 → `game_clock.light_mult/sky_gray`, Environment 안개, CPUParticles3D 비, `alert.vision_scale` 와 경비 시야 배율. 설정 `weather` 로 끔.
- `title_screen.gd`: Control 한 장을 직접 그리고 `_input` 으로 터치 처리(HUD 와 같은 방식), `chosen` 신호.
- 설정 키 추가: `weather`, `fps`, `view_step`(0 가깝게 150m / 1 보통 350m / 2 원래 값). 카메라 `far` 만 조절(camera_rig.gd 미수정).
- NPC 대화 확장은 `npc.dialogue` 사본에 `v2_menu`, `v2_gift*`, `v2_help*`, `v2_warn*` 노드를 넣고 첫 화면에 '마음 나누기' 선택지를 삽입(이미 4개면 생략).

## V1.0 모듈 (scripts/v1/, 미실행)
허브 `_start_modules()`: gfx_manager.start() → `v1_manager.build_world()`(랜드마크) → interior_manager → city_extras → npc_manager → `v1_manager.build_systems()`. `hub.v1` 이 v1_manager. 모든 모듈은 `load()` + `can_instantiate()`.

| 파일 | 역할 |
|---|---|
| v1_manager.gd | 총괄. build_world/build_systems, on_vehicle_entered/exited, on_dialogue_start/end, dynamic_text, on_caught, on_effect(op: taxi/trust/alert/calm), dest_position(key), on_menu_action("setting:*"), 밤 조명, 자동 퀘스트(q_drive/q_okryu/q_collect), 저장 to_dict/from_dict |
| landmarks.gd, lm_kit.gd | 랜드마크 생성. lm_kit = 메시 조립기(MB; 바깥 방향을 주면 감김 순서 자동 맞춤), frustum/rect_frustum/box/extrude_poly, 절차 텍스처(유리/돌/기와/아파트), 충돌체, Label3D 간판. `exits{}`: 들어갈 수 있는 건물 겉모습 |
| interior_extra.gd | 슬롯 6 옥류관, 7 지하철(경사로+점검실), 8 상점 + 대사/아이템 |
| drivable.gd | 아케이드 CharacterBody3D 차량(가속/브레이크/핸들/핸드브레이크), 종류별 모델(car/taxi/truck/military/bus), 충돌 신호 |
| drive_system.gd | 차량 배치, 타기/내리기(암전), 카메라(추적/운전석), 택시 fast_travel, 버스 정류장 승하차, 시민 충돌 검출 |
| alert_system.gd | heat/단계/streak/감소, report(kind,pos,severity,witness), threaten(npc), 목격자(시야+레이캐스트), 신고, 경찰 생성/제거, on_caught |
| social_system.gd | 신뢰도(−3~+5)/소문/대화 증강(augment_all), 경계 플래그 갱신 |
| v1_hud.gd | 미니맵, 경계 배지, 운전 화면, 위협/시점 버튼 (터치는 자기 버튼에서만 소비) |
| game_settings.gd | `user://pyongyang_settings.json` 정적 접근 (gfx_quality/gfx_enabled/crowd_step/traffic_step/shadows/minimap) |
| v1_data.gd | 택시 목적지/기사, 경찰, 주민 대화, NPC 정의, 소문 10개, 경계 대사 |
| gfx/character_factory.gd | GLB 교체 지점. `try_glb(key, outfit)` → {root, anim} 또는 null |

- **허브 모드:** FREE 0 / DIALOGUE 1 / SITTING 2 / TRANSITION 3 / MENU 4 / **DRIVING 5**
- **카메라 연결(카메라 파일 무수정):** `rig.target`(추적 대상), `rig.yaw`, `rig.pitch`, `rig._arm.spring_length`, `_arm.add_excluded_object`
- **효과 op 추가:** taxi, trust, alert, calm (v1_manager.on_effect). 대화 노드 id "v1_rumor"/"v1_refuse"/"v1_alert" 는 social_system 이 사본에 삽입
- **NPC 반응:** react 상태(flee/cower/chase/investigate) + react_t/react_from/react_target. 경찰은 "police" 그룹, 추적 중엔 "guards" 에도 가입 → 기존 의심 게이지/체포 재사용. `can_board/board_vehicle/alight_at`(버스 승객), `state_dict/apply_state`(저장)
- **경계 단계:** 평온/주의/경계/수색/비상 = heat 0/12/32/58/82 이상. streak≥3 가중 ×1.5, ≥4 비상. 핫존 lm_gov/lm_square/lm_hill
- **실내 슬롯:** 6 옥류관(x=600), 7 지하철(x=700), 8 상점(x=800), 모두 y=300. 지하철 경사로는 rotation.x=−atan2(4,14) 상자 충돌체
- **저장:** 기존 JSON 에 `v1: {alert, social, drive, npcs}` 추가
- **설정 흐름:** hud_ui 설정 행 → hub → `v1.on_menu_action("setting:*")` → `game_settings.set_value` → `apply_runtime_settings`(그림자/미니맵 즉시, 품질·군중·교통은 다시 시작 시 적용)
- 정적 점검 도구는 작업 환경 scratchpad 에만 있으며 프로젝트에는 포함되지 않음

## 핵심 규칙
- **좌표:** 1단위=1m, 북=-Z, 동=+X. 방향각 yaw: 바라보는 방향 d 에 대해 `yaw = atan2(-d.x, -d.z)` (0 = 북쪽(-Z)을 봄). 카메라 `rig.yaw` 도 같은 값
- **실내 공간:** slot*100m 만큼 +X, y=300. slot 0 찻집, 1 아파트, 2 호텔 로비, 3 호텔 2층, 4 사무소, 5 지하시설, 6 옥류관, 7 지하철, 8 상점
- **레이어:** 물리 1=월드/플레이어, 2=NPC. 시각 1=도시, 2=실내. Sun `light_cull_mask=1`, 실내 전등 `3`
- **상호작용 종류(kind):** talk, enter, exit, portal, sit, door, examine, pickup
- **효과 op:** set_flag, give_item, take_item, quest_start, quest_step, quest_complete, toast, unlock_door, open_door, reveal
- **조건:** flag, not_flag, item, not_item, quest(+state/step/min_step), night (배열이면 모두 만족)
- **허브 모드:** FREE / DIALOGUE / SITTING / TRANSITION / MENU / DRIVING. 모드에 따라 HUD가 터치를 가져가거나(blocked) 플레이어 이동 잠금
- **입력:** 터치 `_input` 직접 처리. 새 UI는 트리에서 나중에 만들어 먼저 받고, 자기가 시작한 터치만 소비. 대화/암전 중에는 HUD가 터치를 아래 UI에 넘김

## 대화 데이터 형식 (요약)
```
"dialogue": {
  "entry": [ {"if": 조건, "node": "노드이름"}, ... ],   # 위에서부터 처음 맞는 것. 없으면 "start"
  "start": {"text": "...", "variants": {"밤": "..."}, "effects": [...],
            "choices": [ {"label": "...", "next": "node", "if": 조건, "effects": [...]} ], "next": "node"}
}
```

## 저장 형식 (`user://pyongyang_save.json`)
version, game(inventory, flags, quests, discovered), minutes, pos[x,y,z], yaw, location, zoom. 세계 모습(책장 치움, 주운 물건 표시, 문 해제)은 flags 로부터 복원.

## 모바일 최적화 (적용)
- Compatibility 렌더러, 가로등·나무 MultiMesh
- NPC 메시: 그림자 끔, `visibility_range_end` 90m, 재질 공유(캐시), 멀리 있는 NPC는 동작 갱신 생략(70m)
- NPC 일과 점검은 0.5초마다, 길막힘 점검 0.8초마다
- 차량 `visibility_range_end` 160m, 8대 이하
- 실내 전등 그림자 없음
- 모듈 생성 시 프레임을 나눠서(await) 시작 멈칫 줄임
- 조절 값: feature_flags.gd (CROWD_COUNT, EXTRA_BUILDINGS, ENABLE_VEHICLES …)

## 알려진 한계 / 위험
- **V1.0 전체 실행 미검증** (특히 경사로 물리, 차량 지면, 운전 카메라, 경찰/체포 연결, 택시 이동, 랜드마크 배치, 레이캐스트 비용)
- **그래픽 모듈 전부 실행 미검증** (특히 UV/법선 방향, 텍스처 생성 시간, 가로등 위치 검출, 건물 판별 규칙이 사용자 배치와 맞는지)
- 스키닝 없음(관절 겹침), 카메라 개선 없음, 실내 조명 그대로, 평양 실제 랜드마크 아님
- **신규 코드 전부 실행 미검증**
- 한글 글꼴: res://assets/fonts/NanumGothic.ttf 포함. 자동 로드 KoreanFontEnforcer 가 Theme(assets/theme/default_korean_theme.tres)을 읽어 ThemeDB.fallback_font 와 엔진 기본 Theme 의 default_font 로 지정 (project.godot 의 gui/theme/custom 은 가져오기 전에 읽혀 오류가 나므로 쓰지 않음)
- 플레이어/NPC는 레이어 1이라 실내에서도 태양빛을 받음 (낮에는 실내 캐릭터가 조금 밝을 수 있음)
- 밤에 NPC는 "집" 위치에서 사라질 뿐 건물로 걸어 들어가지 않음
- 추가 건물은 장식 (문 안 열림)
- 지도에 건물 미표시, 핀치 줌 없음
- 장식 차량은 동서 대로만 (V1 운전 차량은 어디든 갈 수 있음)
- APK 내보내기 미확인


## 코딩 규칙 (V2.1)
- `:=` 는 우변 타입이 확실할 때만(리터럴/생성자). 타입 없는 변수(`hub`, `lm`, `v1` 등)의 메서드 결과, 딕셔너리·배열 인덱싱, `.get()`, `load()` 결과에는 `var x = ...` 또는 `var x: Type = ...` 를 쓴다. (현재는 보호 5개 파일 외 전부 `=` 사용)
- 모듈은 `load()` + `can_instantiate()` 로 불러 한 모듈의 컴파일 실패가 게임 전체를 막지 않게 한다 (feature_flags 로 끄기 가능).


## V2.2 구조 (scripts/v22)
- **연결점(허브 interaction_system.gd):** `v22` 변수 / `build_world`·`build_systems` 호출 / `_teleport` 에서 `safe_outdoor_pos`(이동 전)·`after_teleport`(이동 후) / `apply_effects` 기본 분기에서 `v22.on_effect` / `_show_node` 의 `dyn` 이 `v22_` 로 시작하면 `v22.dynamic_text` / `_caught` → `on_caught` / 저장 `data["v22"]` / `_start_dialogue` 역할 글 `role_label`.
- **v22_manager:** 모듈 생성(시간 제한 대기), 안전 착지, 낙하 복구, 거리별 지역 숨김(0.5초), 매초 임무 진행·표식 정리, 랜덤 이벤트, 목표 글 캐시, 지도 덧그리기, 저장.
- **v22_world:** 지역마다 Node3D 를 만들어 `regions` 에 등록 → `cull()`. 기존 경계 벽 4개를 ±381 로 이동. `register_gate` 로 검문소 등록, `_interact`/`_poi` 도우미.
- **v22_interiors:** 슬롯 원점 `Vector3(slot*100, 300, 0)`. 10=지하통로(맨홀방·복도·보관실·거래처·금고방·금고·서쪽 곁가지), 11=폐건물, 12=사령부. 주울 물건은 `pk_v22_*` 플래그 + 살펴보기 효과(`give_item`).
- **pass_system:** 검문소(레벨), 통행증 검사·위조·뇌물, 차단기, 만료, 불시 검사. 대화는 `make_dialogue`, 효과는 `v22_gate`/`v22_grant_pass`/`v22_forge`.
- **npc_social:** 성격 프로필, 관계 5단계, `특별 행동` 메뉴(`v22_act`), 거래(`v22_buy`/`v22_sell`), 자발적 신고/도움.
- **talker:** 가짜 NPC (금고 숫자판). `v22_vault` 효과가 암호 확인 → `v22_vault_open` 플래그와 `reveal_v22_vault` 그룹 숨김.
- **효과 연산(v22_*):** intel, grant_pass, gate, act, buy, sell, forge, vault, siren. 대화 동적 글: v22_result, v22_gate, v22_keypad_hint.
- **좌표:** 광장 (0,300), 아파트 (195,300), 강변 z≈-135, 장마당 (-300,10), 폐건물 (-300,95), 빈민촌 (310,20), 검문소 A z=-250, 문 B z=-325, 사령부 (0,-362).

## V2.3 구조 (scripts/v23)
- `v23_leader.gd` : `v22_manager.build_world` 가 `V23_LEADER && V22_WORLD && V22_INTERIORS` 일 때 만들고 `_wait_flag(v23, 8.0)` 로 기다림. 바깥(담·정문·집무동·사저·감시탑·연못, 월드 좌표 -300..-190 x -372..-290), 실내 칸 13(청사)·14(사저). 정문은 `pass_sys.register_gate("leader", 2, ...)` + 경비 NPC 에 `make_dialogue("leader", 2)`. 지역 숨김 목록 `vworld.regions` 와 `vworld.npcs` 에 자기 노드/NPC 를 추가해 V2.2 의 거리 기반 정지에 편승.
- 진행: `_process` 1초마다 `_progress()` — 북부 검문소 통과(`passed_north`)나 특별 통행증이 있으면 `q_v23_leader` 시작, `passed_leader` 로 1단계, 장부를 들고 담 밖으로 나오면 완료(+250원). 단계 갱신은 대화/살펴보기 효과의 `quest_step` 로.
- 효과 `v23_noise` : `v22_manager.on_effect` 가 `v23_` 로 시작하는 연산을 `v23.on_effect` 로 전달. 목표 줄: 주 임무가 없을 때 `v22_manager._update_objective` 가 `v23.objective()` 를 사용.
- 저장: 별도 저장 항목 없음(플래그 `pk_v23_*`, `v23_shelf_open`, `v23_bunker_open`, `v23_done` 가 `game.flags` 에 저장됨). 불러오기 후 `apply_world_flags` 가 책장을 다시 치움.
- `v23_selftest.gd` : `v22_manager.build_systems` 가 `V23_SELFTEST` 일 때 만듦. 9초 뒤 한 번 읽기 전용 점검 → `print`, `user://v22_selftest.txt`, 토스트, CanvasLayer(90) 라벨 40초.
- 규칙: 새 코드에 `:=` 금지(우변이 확실한 경우만), 슬롯 다음 빈 칸은 15, 허브 수정 없이 `v22_manager` 후크만 사용.

## V3.0 구조 (scripts/v3/, 모두 미실행)
```
v22_manager.build_systems → v3_manager.build_all(hub, v22)   (조건: ENABLE_V3 and V23_LEADER and v23 != null)
 ├─ v3_gov     지표 6개/정책/회의/목표/충성도, 틱 = 게임 시간 120분 (abs_minutes 기준)
 ├─ v3_build   건물 배치·고스트·충돌 검사(Placement.is_free_box)·저장 복원
 ├─ v3_story   ACT 계산, 집무실 대면(run_confrontation), 승계(run_succession)
 ├─ v3_leader  지도자 모드: 옷(player_override), 면책, 수행원, 차량, 조망 카메라, 침대
 └─ v3_ui      CanvasLayer 6: 통치 버튼, 지표 줄, 8탭 패널, 건설/조망 HUD, 글 카드
```
- **연결 지점 (허브 수정 없음):** `v22_manager.on_effect` 가 `v3_*` 효과를, `dynamic_text` 가 `v22_v3_*` 동적 대사를 v3 로 전달. 목표 안내는 v23 다음 순서로 `v3.objective()`. 저장은 `to_dict()["v3"]` 중첩 (없으면 `from_dict({})` → 지도자 아님으로 초기화).
- **허브 API 사용:** `hub.mode`(0 자유, 1 대화, 3 전환, 4 메뉴, 5 운전), `ui.fade_to`, `_teleport`, `_start_dialogue`, `apply_effects`, `save_game`, `v1.drive.spawn_one`.
- **방향 규칙:** yaw θ 의 앞쪽 = (−sinθ, 0, −cosθ). 실내 칸 13 = 청사(원점 (1300,300,0)), 14 = 사저. 청사 구역 x −300..−190, z −372..−290.
- **통치 상수:** 기본 수입 60, 기본 지출 70, 배분 단계당 20, 70 이상 체감 감소, 건물 최대 40. 파이썬 모형: `tools/v3_gov_sim.py` (GDScript 상수를 손으로 옮긴 것이라 상수를 바꾸면 같이 고쳐야 함).
