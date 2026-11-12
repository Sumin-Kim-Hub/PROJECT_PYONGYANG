# CHANGELOG

## 3.0.5 — 2026-11-12 한글 글꼴 수정 (Godot 4.7.2 로 헤드리스 검사·웹 내보내기·PC 크롬 실행 확인)
- 원인 1: V3.0.4 까지 코드가 찾던 `assets/fonts/ui_ko.otf` 는 존재하지 않아 기본 글꼴로 돌아감 → 웹(시스템 글꼴 없음)에서 한글이 □. 웹 워크플로는 `ui_ko.ttf` 로 받아 확장자도 달랐음.
- 원인 2: 이후 시도에서 project.godot `gui/theme/custom(_font)` 로 .ttf 를 엔진 시작 시 읽게 해, 가져오기 전(.godot/ 없음)에 `No loader found`·Theme ext_resource 오류 → godot-check 1단계 실패.
- 원인 3: 이후 시도에서 GDScript 4곳에 `\"Node\"` (역슬래시 따옴표), v3_ui.gd 에 탭/공백 혼용 → `Parse Error: Expected new line after "\"`. (`tools/godot_check.sh` 자체의 bash 문법은 정상)
- 수정: 6개 UI 스크립트를 V3.0.4 원본으로 되돌리고 글꼴 경로만 `NanumGothic.ttf` 로. `project.godot` 의 `[gui]` 제거, 자동 로드 `KoreanFontEnforcer` 가 Theme 을 읽어 전역 기본 글꼴 지정(Label3D 포함). `NanumGothic.ttf.import`·`OFL.txt` 추가, 중복 `ui_ko.ttf` 삭제. 웹 워크플로의 글꼴 내려받기 단계 → 포함 파일 확인으로 교체. `godot_check.sh` 에 한글 글꼴 적용 로그 검사 추가.
- 확인: 깨끗한 복사본에서 `tools/godot_check.sh` 통과(자체 점검 48/0/0, V3.0.4 와 같은 게임 로그), Web 내보내기 성공, PC 크롬(소프트웨어 렌더링)에서 시작 화면 한글 정상 표시(수정 전 빌드는 □). 실제 안드로이드/아이폰 브라우저는 미확인.

## 3.0.4 — 2026-11-12 웹(HTML5) 배포 준비 2차 (**웹 빌드 생성·실행 0회, 미검증**)
- 변경(GDScript 1곳): `scripts/v1/game_settings.gd` — `OS.has_feature("web")` 이고 설정 파일이 없을 때만 저사양 기본값(품질0·그림자 끔·시민4·차량4·시야보통·경찰3). 앱/PC 동작 불변.
- 설정: `export_presets.cfg` 모바일 텍스처 압축 켬 + 세로 화면이면 "가로로 눕혀 주세요" 안내(head_include).
- 워크플로: itch.io 용 ZIP 아티팩트, PC 크롬 점검 결과 아티팩트, Pages 배포 실패해도 ZIP 은 받을 수 있게 분리.
- 도구: `tools/web_smoke_test.py`, `tools/make_itch_zip.sh` (가짜 폴더/페이지로만 동작 확인).
- 문서: `docs/WEB_COMPAT_ANALYSIS.md`, `docs/WEB_ITCH_DEPLOY.md`.
## 3.0.3 — 2026-11-12 웹 실행 준비 (코드 변경 없음, **미검증**)
- 추가: `export_presets.cfg`(Web 설정), `.github/workflows/web-export.yml`(GitHub Pages 자동 배포), `docs/WEB_PLAY_GUIDE.md`. `.gitignore` 에서 export_presets.cfg 제외 항목 제거. GDScript 파일은 V3.0.2 와 동일.
- 웹 버전은 만들어 보지도 돌려 보지도 못했음 (Godot 없음).
## 3.0.2 — 2026-11-12 하차 수정 보정 (**미검증**)
- V3.0.1 의 하차 후 물리 대기가 강제 하차(체포/불러오기)까지 비동기로 만들던 문제를 되돌림(일반 하차에만 적용). 운전 중 통치 버튼 안내 추가. `V3.0.1_EXIT_FIX_REPORT.md` 8번
## 3.0.1 — 2026-11-12 택시 하차 수정 (**Godot 실행 0회, 미검증**)
- 원인: 화면 "내리기" 터치 → `interaction_system._on_interact_pressed()` 에 DRIVING 분기가 없어 하차 함수가 호출되지 않음 (E 키 경로에만 연결). V1 때부터 있던 누락.
- 수정: `interaction_system.gd`(DRIVING 분기, E 키 입구 통일), `v1/drive_system.gd`(`request_exit`, 하차 위치 후보 10곳·검사, 연속 입력 방지, 불일치 복구·감시, 로그). 보고서: `V3.0.1_EXIT_FIX_REPORT.md`
## 3.0.0 — 2026-11-12 스토리 캠페인 + 최고지도자 통치 샌드박스 (**Godot 컴파일/실행 0회, 전부 미검증**)
- 새 폴더 `scripts/v3/` (파일 8개, 약 3,680줄): 4막 스토리·집무실 대면 장면·4가지 승계 엔딩 / 지도자 모드(복장, 경호·수행, 전용 차량, 도시 조망) / 국가 지표 6개·정책 15·회의 12·목표 12 / 도시 건설 12종 / 8탭 통치 메뉴 / 자체 점검 추가
- 기존 5개 수정: `v22_manager.gd`(후크·저장 `"v3"`), `character_builder.gd`(`player_override`), `quest_data.gd`(`q_v3_story`), `feature_flags.gd`(`ENABLE_V3` 외 6개), `v23_selftest.gd`
- 보호 파일 6개 수정 없음. V2.1/V2.2/V2.3 ZIP 보존.
- 문서: `V3.0_CHANGELOG.md`, `V3.0_VERIFICATION_REPORT.md`, `docs/V3.0_STORY_DESIGN.md`, `docs/V3.0_USER_TEST_GUIDE.md`
- 못 한 것: 컴파일·실행·FPS·APK, 모든 V3 기능의 실제 동작 확인

## 2.3.0 — 2026-11-12 최고지도자 집무실·사저 + 자체 점검 (**Godot 컴파일/실행 0회, 전부 미검증**)
- 새 폴더 `scripts/v23/` (3개 파일): 가상의 중앙 청사(집무동)+사저+지하 대피소(실내 칸 13·14, 정문 검문소 `leader`, 임무 `q_v23_leader`, 아이템 3, NPC 3) / 자체 점검 모듈
- 기존 5개 수정: `pass_system.gd`(주 임무 갱신을 north/base 로 제한), `v22_manager.gd`(후크), `feature_flags.gd`(`V23_LEADER`, `V23_SELFTEST`), `item_data.gd`, `quest_data.gd`
- 지도자 본인은 이름·모습·대사 없음, 해를 입지도 않음. 보호 파일 6개 수정 없음.
- 문서: `V2.3_CHANGELOG.md`, `V2.3_RECOVERY_REPORT.md`, `docs/V2.1_V2.2_COMPARISON.md`, `docs/V2.3_USER_TEST_GUIDE.md`, `docs/V2.3_DISTRIBUTION_FEASIBILITY.md`, `tools/godot_check.sh`, `.github/workflows/godot-check.yml`
- 못 한 것: V2.2 컴파일·실행·실제 테스트(환경에 Godot 없음), APK/IPA 생성

## 2.2.0 — 2026-11-12 게임플레이 확장 (**Godot 컴파일/실행 0회, 전부 미검증**)
- 새 폴더 `scripts/v22/` (9개 파일), 변경된 기존 파일 8개. 자세한 목록: `V2.2_CHANGELOG.md`, 보고서: `V2.2_RECOVERY_REPORT.md`
- 실내→바깥 추락 방지(지면 탐색·받침판·착지 감시·낙하 복구), 새 지역 8곳 + 실내 3곳(슬롯 10~12), 월드 ±380, 통행증 4종·검문소 2곳, NPC 상호작용·관계 5단계, 비밀 지하 통로 콘텐츠, 임무 5개·랜덤 이벤트 6종·탐험 보상, 목표/상태/지도 UI, 합성 배경음·사이렌
- 보호 파일 6개 수정 없음. 끄는 스위치: `ENABLE_V22`, `V22_*`
- 미구현: 자전거/옛 차량, 메쉬 LOD, 소리 끄기 설정, 방송 음성, 2막

## 2.1.0 — 2026-11-12 긴급 복구 (**Godot 컴파일/실행 0회, 미검증**)
- 원인: `var glass := lm._glass_mat(...)` 등 타입 없는 변수의 호출 결과에 `:=` 사용 → "Cannot infer the type of ... variable" (v2_landmarks.gd 57:18 보고)
- 조치: world_builder/player/touch_controls/camera_rig/game_config/main 을 뺀 모든 .gd 에서 `var x := ...` 349줄을 `var x = ...` 로 변경 (실행 동작 동일)
- 기능 추가 없음. 보호 파일 바이트 동일. 사용자 보고 29개 중 57:18 만 특정, 나머지는 연쇄 오류로 추정(미확인)
- 새 문서 `V2.1_RECOVERY_REPORT.md`


## 2.0.0-v2 FIXED — 패키징 수정
- 첫 V2.0 ZIP 은 main.gd 가 preload 하는 world_builder/camera_rig/player/touch_controls/game_config 를 scripts/ 에서 빠뜨려 실행 불가였음 → scripts/ 에 복원, `_baseline_user_files/` 제거. 코드 변경 없음(이 5개는 수정하지 않은 사본). 파일명: `PROJECT_PYONGYANG_V2.0_FIXED_COMPLETE.zip`

## 2.0.0-v2 — 2026-11-12 (V2.0 GRAND OVERHAUL · 통합본 · **신규 코드 전부 미실행**)
- 새 폴더 `scripts/v2/` (6개 파일): v2_manager(총괄), v2_landmarks(평양역 풍 역사·주차장·창전거리 풍·미래과학자거리 풍), v2_interiors(평양역 내부 슬롯 9), v2_data(대사/경비 NPC), weather_system(날씨), title_screen(시작 화면)
- 평양역 이야기: 임무 q_station 6단계, 선물/신뢰/위협/포기 4갈래, 결말 2가지(기록을 가져감/그대로 둠), 열쇠 문·숨겨진 선반 통로·야간 순찰 경비
- 부가 임무 3개 자동 진행: q_taxi, q_trust, q_escape(잡히면 실패 표시)
- 날씨 4종(맑음/흐림/비/안개): 햇빛·하늘 회색·안개·비 입자·목격 거리 반영, 저장/불러오기
- 차량: 경찰차(사이렌 불빛) 추가, 주차장 6대, 택시 목적지에 평양역 → 탈 수 있는 차 총 15대
- NPC: 버스 대기/전화 통화 일과, 포즈(휴대폰/웅크림/피격/공황/둘러보기), 시민 대화에 선물·도와주기·경고(시민마다 1회 신뢰 증가), 새 아이템 7개
- 시스템: 시작 화면(새 게임/이어하기), 메뉴 열면 세계 일시정지, 설정 확장(날씨/FPS 표시/시야 거리, 두 열 배치), FPS·날씨·메모리 표시
- 변경된 기존 파일(17개): game_clock, game_state(fail_quest), feature_flags(V2 스위치+설정 도우미), item_data, npc_data, quest_data, character_animator, character_factory, vehicle_model, interaction_system(v2 연결·저장·시작 화면), npc.gd, hud_ui(설정 화면), alert_system(시야 배율), drivable, drive_system, v1_data(택시 목적지), v1_manager(설정 처리, 평양역 목적지)
- **일부러 수정하지 않은 파일:** world_builder.gd, camera_rig.gd, player.gd, touch_controls.gd, game_config.gd, main.gd (V1.0 사본과 바이트 단위로 동일함을 확인)
- 안전장치: `ENABLE_V2=false` 로 V1.0 상태, 각 `V2_*` 스위치, 모든 모듈 `load()`+`can_instantiate()`
- **하지 못한 것:** 실제 Godot 실행, APK, FPS 측정, 스키닝/GLB 에셋, 차량 문·엔진 소리·탑승 애니메이션, 경찰차 추격 주행, NPC 건물 걸어 들어가기, 골목/원경 확장

## 1.0.0-v1 — 2026-11-12 (V1.0 월드 확장 · 통합본 · **신규 코드 전부 미실행**)
- 새 폴더 `scripts/v1/` (13개 파일): v1_manager(총괄), landmarks + lm_kit(랜드마크), drivable + drive_system(운전), alert_system(도시 경계), social_system(신뢰/소문), interior_extra(옥류관/지하철/상점), v1_hud(미니맵/운전 화면), v1_data(대사/소문), game_settings(설정 파일)
- `scripts/gfx/character_factory.gd`: GLB 캐릭터 교체 지점 (res://assets/characters/*.glb, 파일 없으면 기존 절차적 모델)
- 랜드마크 11곳(류경호텔 풍, 개선문 풍, 주체탑 풍, 광장, 만수대 풍, 정부청사, 대형 호텔, 아파트 단지 2, 옥류관 풍, 지하철역 입구, 버스 정류장)
- 탑승/운전 가능 차량 7대, 택시 빠른 이동, 버스 정차와 승객
- 위협 버튼 · 도시 경계 5단계 · 목격자/신고/경찰 출동 · 시민 반응(도망/웅크림/조사) — 허구 연출만
- NPC 신뢰도, 소문 10개, 새 NPC 8명(택시기사, 경찰 2, 주민 2, 옥류관 안내원, 지하철 직원, 상점 주인)과 경계 단계별 대사
- 새 실내 3곳(옥류관, 지하철, 상점), 침대에 눕기, 문서 수집
- UI: 미니맵, 경계 배지, 운전 화면, 설정 화면(품질/그림자/군중/교통/미니맵/저사양), 지도 확장
- 저장에 v1 상태 추가 (없거나 깨져도 기본값)
- 변경된 기존 파일: feature_flags.gd(V1 스위치 + 설정 반영 도우미), interaction_system.gd(DRIVING 모드, V1 연결, 눕기, 저장), hud_ui.gd(설정/지도 확장), npc.gd(반응 상태, 경찰, 승객, GLB 훅, 상태 저장), npc_manager.gd, gfx_manager.gd, city_extras.gd, vehicle.gd(버스 정차), interior_manager.gd, npc_data.gd, quest_data.gd, item_data.gd, character_builder.gd
- **일부러 수정하지 않은 파일:** world_builder.gd, camera_rig.gd, player.gd, touch_controls.gd, game_config.gd, main.gd
- 안전장치: `ENABLE_V1=false` 로 v0.2.0 상태, 각 V1_* 스위치로 부분 끄기, 모든 모듈 `load()`+`can_instantiate()`

## 0.2.0-gfx — 2026-11-12 (그래픽 전면 리뉴얼 · **신규 코드 전부 미실행**)
- 새 폴더 `scripts/gfx/` (9개 파일): 절차적 사실형 인체 모델, 관절 애니메이션, 건물 외벽/디테일, 도로·인도·횡단보도·정류장·전신주·강·다리·랜드마크, 구름·가로등 불빛·대기 보정, 차량 모델
- 플레이어/NPC 모델 교체 (비율, 얼굴, 머리 모양 7종, 직업별 옷, 모자, 소품, 걷기/달리기/점프/앉기/대기/대화 동작, 먼 거리용 합본 메시)
- 건물: 층별 창문·창틀·유리 반사·밤 점등 텍스처, 발코니·난간·에어컨 실외기·배관·처마·옥상 구조물·입구·간판, 건물마다 다른 색/무늬
- 환경: 아스팔트·차선·인도·연석·잔디 텍스처, 횡단보도, 표지판, 버스 정류장, 전신주와 전선, 화단·침엽수·덤불, 강+다리, 개선문 비슷한 문·피라미드형 탑(가상 랜드마크)
- 하늘/조명: 흐르는 구름 돔, 밤에 가까운 가로등 6개에 실제 불빛, 가로등 램프 밝기 변화, 약한 대비/채도 보정
- 변경 파일: `feature_flags.gd`(그래픽 스위치 6개), `interaction_system.gd`(`_start_modules` 맨 앞에서 그래픽 시작, 8초 제한 대기), `npc.gd`, `npc_data.gd`("sex" 값), `vehicle.gd`
- 안전장치: 모든 그래픽 모듈은 `load()` 로 불러오며 실패하면 기존(v0.1.x) 모습으로 되돌아감. `ENABLE_GFX=false` 로 전체 끄기
- **일부러 수정하지 않은 파일:** world_builder.gd, camera_rig.gd (건물 기존 박스 위에 덧씌우는 방식)

## 0.1.1-qa — 2026-11-12 (안정화 점검, 기능 추가 없음 · 실행 미검증)
- 밤 조명 개선, NPC 중복 앉기 방지
- 저장/불러오기 강화: 깨진 저장 파일 방어, 임시 파일 후 이름 변경 방식 저장, 새 게임 시 자동 저장 차단

## 0.1.0 — 2026-11-12 (대규모 확장, 신규 코드 미실행)
- 상호작용 시스템: 안내 문구+버튼, 대화, 앉기, 건물 출입(암전 이동), 문, 조사, 줍기
- NPC v2: 외모 다양화, 시간대 일과(돌아다니기/서기/벤치 앉기/집으로), 걷기·앉기 동작, 길막힘 감지, 군중 자동 생성
- 대화 데이터 시스템: 조건/효과/시간대별 대사/퀘스트 연동
- 건물 4곳(찻집, 호텔, 아파트 3동 12호, 행정사무소)과 비밀 지하시설 내부, 열쇠로 잠긴 문, 엘리베이터, 비밀 통로
- 임무 3개(찻집 → 문서실 → 정보원 접촉), 아이템 10종, 가방/임무/지도 화면
- 잠입: 경비 시야·경계 게이지·발각 처리
- 게임 시간·낮밤 조명
- 저장/불러오기/자동 저장/새 게임
- 도시 보강: 벤치, 추가 건물(장식), 큰길 차량
- 카메라 거리 조절 버튼
- 변경된 기존 파일: main.gd (허브 연결 2곳). 사용자가 손본 world_builder.gd, camera_rig.gd 는 그대로.

## 0.0.1 — 2026-11-12 (프로토타입)
- 프로젝트 초기 생성 (Godot 4.3+, Compatibility 렌더러)
- 가상 도시 구역 생성, 플레이어 이동/달리기/점프, 3인칭 카메라, 모바일 터치 UI
- 사용자가 휴대폰에서 실행해 3D 도시와 플레이어 표시 확인
