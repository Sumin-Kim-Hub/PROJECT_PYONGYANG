# V2_VERIFICATION_REPORT (2.0.0-v2, 2026-11-12)

## 1. 한 줄 결론
**V2.0 은 "코드 작성 + 정적 점검"까지만 했습니다. Godot 에서 실행한 횟수는 0회이고, APK 는 만들지 못했고, FPS 는 측정하지 못했습니다.** 아래 표의 "작동"은 한 줄도 없습니다. 사용자가 실제로 실행해 본 것은 맨 처음 버전(v0.0.1)뿐입니다.

## 2. 이 환경에서 한 검증
| 검증 | 결과 |
|---|---|
| Godot 실행 / 컴파일 | **못 함** (환경에 Godot 없음, 네트워크 차단, 설치 거부) |
| 정적 점검 5종 (들여쓰기·괄호·블록 / 스크립트 간 호출 / 인자 개수 / 미선언 이름 / res:// 경로) | 남은 경고는 모두 알려진 오인(player·camera_rig 동적 호출, 상속 멤버, 여러 줄 함수 선언, 선택 자산 경로). 새 오류 없음 |
| res:// 경로 | 없는 경로는 선택 자산(`assets/fonts/ui_ko.otf`, `assets/characters/`)뿐이며 `ResourceLoader.exists` 로 보호됨 |
| 보호 파일 | world_builder, camera_rig, player, touch_controls, game_config, main 은 V1.0 사본과 **바이트 단위로 동일**(수정 안 함) |
| 산출물 존재·압축 상태 | ZIP 생성 후 `testzip()` 와 목록 대조로 확인 (아래 7절) |
이것은 "컴파일 통과"를 뜻하지 않습니다. 정적 점검기는 제가 만든 간이 도구이고 GDScript 컴파일러가 아닙니다.

## 3. 요청 항목별 구현·검증 상태
상태: 구현=코드 작성됨, 부분=일부만, 미구현=못 함. **모든 "구현"은 실행 미검증.**
| 영역 | 상태 | 비고 |
|---|---|---|
| 캐릭터 포즈(통화/웅크림/피격/공황/둘러보기) | 구현 | 스키닝·실제 GLB·제스처 대사·차량 탑승 동작은 미구현 |
| 랜드마크: 평양역 풍, 창전거리 풍, 미래과학자거리 풍, 주차장 | 구현 | V1 의 류경호텔·개선문·주체탑 등과 합쳐 요청 목록 대부분 포함. 전부 가상 재현, 실제 치수 아님 |
| 날씨(맑음/흐림/비/안개) | 구현 | 눈, 골목, 먼 배경은 미구현 |
| NPC 생활(버스 대기, 통화) | 부분 | 건물 문으로 걸어 들어가기, 쇼핑, 방문 미구현 |
| NPC 상호작용(선물/도움/경고/소문/신뢰/신고) | 구현 | |
| 위협→반응 연쇄 | 구현(V1+V2 포즈) | 유혈 묘사 없음 |
| 차량(경찰차, 주차장 6대, 택시 평양역) | 부분 | 문·엔진음·탑승 애니메이션·경찰차 추격 미구현, 바닥 높이/끼임 미확인 |
| 실내(평양역: 대합실/경비실/창고/비밀 방, 열쇠 문, 숨겨진 선반) | 구현 | 방 사이 0.3m 틈, 충돌 제거 동작 미확인. 엘리베이터는 V1 지하철의 대체 포털뿐 |
| 퀘스트/분기/엔딩 | 구현 | 평양역 4갈래·결말 2개, 부가 임무 3개 |
| 시작 화면 / 이어하기 / 일시정지 / 설정 | 구현 | 터치 입력 경로 미확인 |
| 날씨·FPS·시야 거리·저사양 | 구현 | **FPS 수치는 기기에서 처음 알 수 있음** |
| 저장/불러오기(v2 항목) | 구현 | 없거나 깨져도 기본값으로 시작하도록 작성(미확인) |

## 4. 변경 파일 목록 (V1.0 대비)
**신규 (6)** scripts/v2/: v2_manager.gd, v2_landmarks.gd, v2_interiors.gd, v2_data.gd, weather_system.gd, title_screen.gd
**신규 문서** V2_VERIFICATION_REPORT.md
**수정 (17)** core/game_clock.gd, core/game_state.gd, data/feature_flags.gd, data/item_data.gd, data/npc_data.gd, data/quest_data.gd, gfx/character_animator.gd, gfx/character_factory.gd, gfx/vehicle_model.gd, interaction/interaction_system.gd, npc/npc.gd, ui/hud_ui.gd, v1/alert_system.gd, v1/drivable.gd, v1/drive_system.gd, v1/v1_data.gd, v1/v1_manager.gd
**문서 수정** README_KO, PROJECT_STATE, DEVELOPMENT_LOG, TODO, CHANGELOG, TECHNICAL_ARCHITECTURE, RESUME_PROMPT
**수정하지 않음** world_builder.gd, camera_rig.gd, player.gd, touch_controls.gd, game_config.gd, main.gd

## 5. APK 빌드 가능성
- 이 환경: Godot 엔진, Android 내보내기 템플릿, Android SDK/JDK, 키스토어가 없고 네트워크가 막혀 **APK 를 만들 수 없었고, 시도하지도 못했습니다.**
- 프로젝트 쪽 준비: 렌더러 Compatibility, 외부 의존성 없음, 오프라인, 유료 에셋 없음 → 구조상 막는 요소는 모르지만 **실제로 내보내 본 적이 없으므로 "가능하다"고 확인된 것은 없습니다.**
- 시도 방법(PC Godot 공식 절차): Project → Export → Add → Android → 내보내기 템플릿 설치 → 디버그 키스토어 지정 → Export With Debug. Android 에디터에서 같은 과정이 되는지는 확인하지 못했습니다. 막히면 화면의 오류 문장을 보내 주세요.

## 6. Android 에서 실행하는 방법
1. `PROJECT_PYONGYANG_V2.0_FIXED_COMPLETE.zip` 을 폰에서 `PROJECT_PYONGYANG` 폴더가 있는 바로 윗 폴더에 풀고 병합/덮어쓰기.
2. 보호 5개 파일은 ZIP 의 `scripts/` 안에 들어 있습니다(실행 필수). 이미 손본 버전이 있으면 그 5개만 덮어쓰지 마세요.
3. Godot 에서 프로젝트 열기(처음엔 가져오기로 오래 걸림) → ▶.
4. 빨간 오류가 나면 글씨 전체를 보내 주세요. 임시 조치: `feature_flags.gd` 의 `V2_*` → `ENABLE_V2` → `V1_*` → `ENABLE_V1` 순서로 false.
5. 느리면 메뉴 > 설정 > 저사양 모드(시야 거리까지 낮춤), 왼쪽 위 FPS 숫자를 알려 주세요.

## 7. 알려진 위험 (실행 전 예상)
시작 화면 터치, 메뉴 일시정지 시 NPC 복구, 날씨의 환경 노드 탐색, 평양역 방 사이 벽·열쇠 문·선반 충돌 제거, 새 랜드마크의 볼록 껍질 충돌 근사와 배치 겹침, 주차장 차량의 지면 높이, 설정 화면 글자 잘림, 첫 실행의 문법/타입 오류 가능성(신규 코드 전부 미실행).

## 8. 패키징 오류 수정 기록 (V2.0_FIXED)
- 첫 `PROJECT_PYONGYANG_V2.0_COMPLETE.zip` 은 `main.gd` 가 preload 하는 5개 파일을 `scripts/` 에서 빼고 `_baseline_user_files/` 에만 넣어 **그대로는 실행 불가**였습니다(V1.0 ZIP 도 같은 문제). 사용자 검사로 발견되었고, 5개를 `scripts/` 로 복원하고 `_baseline_user_files/` 를 제거했습니다.
- 복원한 5개는 이 환경 사본(V1.0 기준 사본과 바이트 동일, 이번 작업에서 수정 안 함). 사용자의 최신 손본 파일은 이 환경에 없으므로 비교할 수 없었습니다.
- 자동 검사(`main.gd` 의 preload/load, 모든 `.gd`/`.tscn`/`project.godot` 의 `res://` 경로)를 **ZIP 을 새 폴더에 풀어서** 다시 실행한 결과는 최종 보고를 참고하세요. 선택 자산(글꼴/GLB)만 없고 모두 `ResourceLoader.exists` 로 보호됩니다.
- Godot 실행/headless 컴파일: 환경에 Godot 없음 → **미검증**.


## 9. V2.1 추가 (2026-11-12)
이 보고서의 V2.0 내용은 V2.1 에서도 "미실행"입니다. `:=` 오류 수정 내용과 현재 검증 상태는 `V2.1_RECOVERY_REPORT.md` 를 보세요. 사용자 실행 보고에서 컴파일 오류가 확인되었으므로, 위 정적 점검이 "새 오류 없음"이라 해도 컴파일 성공을 뜻하지 않았음이 증명되었습니다.
