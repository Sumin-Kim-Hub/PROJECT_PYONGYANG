# PROJECT PYONGYANG RESUME PROMPT

(V3.0.4 메모: 웹 배포 2차. game_settings.gd 에 웹 전용 저사양 기본값 1곳만 코드 변경. 웹 파일은 아직 한 번도 만들어지지 않음(Godot 없음). 사용자가 Actions 실행 결과/폰 테스트 기록표를 가져오면 그것부터 처리. Android Chrome·iPhone Safari 는 둘 다 미확인이라고 구분해서 말할 것.)

(V3.0.3 메모: 코드 변경 없음. 설치 없이 브라우저로 실행하기 위한 웹 내보내기 준비 — export_presets.cfg(Web), .github/workflows/web-export.yml, docs/WEB_PLAY_GUIDE.md. 웹 빌드 생성·실행 0회, 전부 미검증. 사용자가 GitHub Pages 배포를 시도하면 실패 로그부터 처리. 아이폰 사파리 성능/메모리/소리/한글은 미확인.)

(V3.0.1 메모: 택시 하차 버그 수정판. 원인은 허브의 `_on_interact_pressed` 에 DRIVING 분기가 없던 것. 수정 후에도 Godot 실행 0회라 미확인 — 사용자의 출력 탭 `[PYONGYANG][하차]` 로그부터 확인할 것. 하차는 반드시 `drive.request_exit()` 입구를 쓴다.)

(V3.0 메모: 3.0.0 은 V2.3 위에 scripts/v3/* — 4막 스토리·집무실 대면·승계 4길, 지도자 모드, 통치 지표 6개·정책·회의·목표, 도시 건설 12종, 8탭 메뉴. 허브(interaction_system.gd) 수정 없이 v22_manager 후크로 연결, 저장은 v22 안 "v3". 시험용 스위치 V3_TEST_LEDGER / V3_TEST_LEADER. Godot 실행 0회라 전부 미검증. 사용자가 보내는 것: 오류 글씨 + 자체 점검 스크린샷 + docs/V3.0_USER_TEST_GUIDE.md 표. 새 기능보다 그 결과 처리가 먼저. 보호 6개 파일 수정 금지, 새 코드에 `:=` 금지, 실내 칸 다음 빈 칸은 15, V2.1_STABLE/V2.2/V2.3 ZIP 은 수정 금지.)

(V2.3 메모: 2.3.0 은 V2.2 위에 scripts/v23/* — 가상의 중앙 청사+사저(지도자 비등장), 자체 점검(`v23_selftest.gd`, 화면+로그+user://v22_selftest.txt). Godot 실행 0회라 전부 미검증. 사용자가 보내는 것: 오류 글씨 + 자체 점검 스크린샷 + docs/V2.3_USER_TEST_GUIDE.md 표. 새 기능보다 그 결과 처리가 먼저. 보호 6개 파일 수정 금지, 새 코드에 `:=` 금지, 실내 칸 다음 빈 칸은 15, 허브(interaction_system.gd)는 V2.3 에서 건드리지 않음.)

(V2.2 메모: 2.2.0 은 scripts/v22/* 를 추가한 게임플레이 확장. Godot 실행 0회라 전부 미검증. 새 기능보다 사용자의 실행 오류 글씨 처리가 먼저. 보호 6개 파일은 수정 금지. 새 코드에 `:=` 금지. 구조 설명은 TECHNICAL_ARCHITECTURE.md "V2.2" 절, 테스트 목록은 TODO.md.)

(V2.1 메모: 2.1.0 은 `:=` 타입 추론 오류를 전부 제거한 긴급 복구본. Godot 실행 0회라 미검증. 새 기능 만들기 전에 사용자의 실행 오류 글씨부터 처리할 것. 코딩 규칙: 타입 없는 변수의 호출 결과에는 `:=` 를 쓰지 말고 `var x = ...` 또는 `var x: Type = ...` 를 쓴다.)


다음 대화를 시작할 때 아래 따옴표 안의 글을 그대로 붙여 넣고, 프로젝트 ZIP(또는 파일들)과 함께 보내세요.
(실행 중 오류가 있었다면 오류 글씨도 같이 붙여 넣으세요.)

"이전 PROJECT_STATE.md, DEVELOPMENT_LOG.md, TODO.md 및 현재 프로젝트 파일을 확인하라.

기존 구현과 파일 구조를 파악하고 이전 작업을 반복하지 말라.

현재 상태와 마지막 작업을 확인한 후 미완성 작업부터 이어서 진행하라.

기존에 정상 작동하는 기능은 유지하라.

world_builder.gd 와 camera_rig.gd 는 내가 직접 손본 파일이므로 수정하지 말라.

파일을 수정하기 전에 현재 파일을 검토하라.

수정 후 실제 실행과 테스트가 가능한 범위에서 검증하라. 실행하지 않은 기능을 작동한다고 말하지 말라.

작업 종료 시 프로젝트 상태 문서를 업데이트하라."

## 현재 상태 한 줄 요약 (2026-11-12, V2.0)
**V2.0 (2.0.0-v2):** V1.0 위에 scripts/v2/* 추가 — 평양역 풍 역사+내부(슬롯 9)+평양역 임무, 주차장, 창전거리 풍·미래과학자거리 풍, 날씨, 부가 임무 3개, 경찰차, 시민 선물/도움/경고 대화, 시작 화면, 설정(날씨/FPS/시야 거리), 메뉴 일시정지. 끄는 스위치: ENABLE_V2 / V2_*. **Godot 실행 0회, APK·FPS 없음, 전부 미검증.** 보호 파일 6개(world_builder, camera_rig, player, touch_controls, game_config, main) 수정 없음. 하지 못한 것은 TODO.md "V2.0 이후" 참고. 다음: 폰에서 실행 → 오류 글씨 → 수정 → TODO.md 의 V2.0 체크리스트.

## (이전) 현재 상태 한 줄 요약 (V1.0)
**V1.0 (1.0.0-v1):** v0.2.0-gfx 위에 랜드마크(류경호텔 풍·개선문 풍·주체탑 풍·광장·만수대·정부청사 등), 차량 운전/택시/버스, 도시 경계+시민 반응+경찰, 신뢰도·소문, 옥류관/지하철/상점 실내, 미니맵·설정·운전 UI, GLB 교체 구조(scripts/gfx/character_factory.gd)를 추가함(scripts/v1/*). **사용자가 실행 확인한 것은 v0.0.1 뿐이고 그 뒤 모든 코드는 미실행.** 끄는 스위치는 feature_flags.gd 의 ENABLE_V1 / V1_* / ENABLE_GFX. 보호 파일(world_builder.gd, camera_rig.gd, player.gd, touch_controls.gd, game_config.gd, main.gd)은 수정하지 않았음. 다음: 휴대폰 실행 → 오류 글씨 → 수정 → TODO.md 체크리스트.

## 이어서 작업할 때 규칙 (사용자 지시)
- 질문/승인 요청 없이 합리적인 기본값으로 진행, 실행하지 않은 것은 "미검증"으로 명시
- 사용자 소유 파일 5개(world_builder.gd, camera_rig.gd, player.gd, touch_controls.gd, game_config.gd)는 덮어쓰지 말 것. 새 시스템은 호환 인터페이스로 연결. ZIP 을 만들 때는 이 5개를 scripts/ 안에 반드시 포함(빠지면 main.gd preload 실패) 하고 자동 경로 검사를 돌릴 것
- 오류 로그를 받으면 고치고 ZIP 을 다시 만들 것. APK 가 만들어졌다고 말하지 말 것
- 설명은 쉬운 한국어로 (사용자는 코딩 경험이 없고 안드로이드 폰의 Godot 에디터로 개발)

## (이전) v0.2.0-gfx
그래픽 전면 리뉴얼 모듈(scripts/gfx/*, 절차적 인체 모델·건물 덧씌우기·환경·하늘). 전부 미실행.

## (이전) v0.1.0 + QA 수정
상호작용·NPC·건물 내부·퀘스트·잠입·저장·낮밤·도시 보강 + 안정화. 전부 미실행.

## 파일 구조 요약
- scripts/main.gd 가 허브(interaction/interaction_system.gd)를 연결 → 허브가 core(GameState, GameClock), UI(interaction_ui, hud_ui), 모듈(gfx_manager, v1_manager, interior_manager, city_extras, npc_manager)을 생성
- 데이터: scripts/data/ (npc_data, quest_data, item_data, feature_flags)
- scripts/gfx/: gfx_manager(총괄) → character_builder/animator, gfx_buildings, gfx_environment, gfx_sky, gfx_textures, gfx_details, vehicle_model, character_factory(GLB 훅)
- scripts/v2/: v2_manager(총괄: build_world → build_systems, 허브의 `v2`) → v2_landmarks, v2_interiors(interior_extra 상속), v2_data, weather_system, title_screen
- scripts/v1/: v1_manager(총괄: build_world → build_systems) → landmarks/lm_kit, interior_extra, alert_system, social_system, drive_system/drivable, v1_hud, game_settings, v1_data
- 새 NPC/대사/소문은 npc_data.gd, v1/v1_data.gd 데이터만 고치면 됨
