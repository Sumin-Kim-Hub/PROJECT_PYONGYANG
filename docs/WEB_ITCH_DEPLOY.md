# itch.io / GitHub Pages 로 친구에게 링크 보내기 (V3.0.4, 미검증)

> 이 환경에는 Godot 가 없어서 **웹 게임 파일(index.html / .wasm / .pck)은 아직 만들어지지 않았습니다.** 아래 방법 중 하나로 만들어야 합니다. 만들어진 뒤에도 폰에서 도는지는 별개로 확인해야 합니다.

## 준비물 (이 ZIP 에 들어 있음)
| 파일 | 역할 |
|---|---|
| `export_presets.cfg` | "Web" 내보내기 설정 (스레드 없음, 세로 화면 안내 포함) |
| `.github/workflows/web-export.yml` | GitHub 가 Godot 4.7.2 로 웹 내보내기 → **itch.io 용 ZIP** + GitHub Pages 주소 + PC 크롬 점검 결과(스크린샷) |
| `tools/make_itch_zip.sh` | PC 에서 직접 내보낸 폴더를 itch.io 용 ZIP 으로 묶음 (가짜 폴더로 동작 확인함) |
| `tools/web_smoke_test.py` | 내보낸 폴더를 PC 크롬으로 열어 시작 로그 확인 (가짜 페이지로만 동작 확인함) |

## 방법 1 — GitHub Actions 로 자동 생성 (PC 없이 가능성 있음, 가장 추천)
1. GitHub 가입 → 새 저장소 만들기 (Private 도 빌드는 가능. Pages 는 무료 계정에서 Public 이 필요한 것으로 알고 있음 — 공식 확인 필요).
2. ZIP 을 풀어 `PROJECT_PYONGYANG` 폴더 **안의 내용 전체**(`project.godot` 가 맨 위)를 저장소에 올림. 숨김 폴더 `.github` 가 빠지지 않게 주의.
3. 저장소 > Actions > `web-export` > **Run workflow**.
4. 끝나면(수 분) 실행 화면 아래 **Artifacts** 에서
   - `pyongyang-web-itch` : itch.io 에 올릴 ZIP
   - `web-smoke-result` : PC 크롬 점검 스크린샷/콘솔 로그
   를 내려받습니다.
5. 빨간색 실패면 **실패한 단계의 로그를 복사해서 알려 주세요.** (다운로드 주소 이름, 내보내기 오류가 가장 의심되는 곳)

## 방법 2 — PC 에서 직접
1. Godot 4.7.2 + 같은 버전 내보내기 템플릿 설치 → 프로젝트 열기 → 프로젝트 > 내보내기 > **Web** > "프로젝트 내보내기"(경로 `build/web/index.html`).
2. `sh tools/make_itch_zip.sh` → `pyongyang-web-itch.zip` 생성.
3. 선택: `python3 tools/web_smoke_test.py build/web smoke_out` 으로 PC 크롬 점검.

## itch.io 에 올리기
1. itch.io 가입 > Dashboard > **Create new project**.
2. Kind of project = **HTML**. `pyongyang-web-itch.zip` 업로드 후 "This file will be played in the browser" 체크.
3. Embed options: 뷰포트 크기는 가로형(예: 960×540 이상), **Mobile friendly 체크**, **Fullscreen button 체크**, Click to launch 권장. *SharedArrayBuffer 는 켜지 않아도 됨(스레드 없는 빌드)* — 전부 제 기억이며 공식 문서(itch.io/docs/creators/html5)로 확인하지 못했습니다(조회 한도 때문).
4. **공개 범위를 "Restricted"(비밀번호/허용 목록) 또는 Draft** 로 두고 링크만 친구에게 전달. 공개 게시 전에 소스·설정 노출 여부 확인.
5. 제한: 파일 수/용량 제한이 있는 것으로 알고 있음(대략 1,000개 / 500MB). 이 게임은 파일이 4~6개라 해당 없을 것으로 예상.

## 친구에게 보낼 문구
> 링크를 폰에서 열고 **폰을 가로로** 눕혀 주세요. 처음엔 약 40MB 를 내려받아 오래 걸려요(와이파이 권장). 화면 왼쪽 위의 FPS 숫자와 시작 직후 위쪽에 뜨는 "자체 점검" 글씨를 스크린샷으로 보내 주세요. 저장은 브라우저 안에만 되고, 저장한 뒤 몇 초 기다렸다가 닫아 주세요.

## 폰 테스트 기록표 (친구/본인이 채워 알려 주기)
| 기종 | 브라우저 | 열림 | 로딩 시간 | FPS | 이동/버튼 | 소리 | 한글 | 튕김 |
|---|---|---|---|---|---|---|---|---|
| (안드로이드) | Chrome | | | | | | | |
| (아이폰) | Safari | | | | | | | |

## 지금 확실히 말할 수 있는 것 / 없는 것
- 확인됨: 소스에 웹을 막는 API 가 없음(정적 분석), 렌더러가 이미 호환성, 도구 스크립트가 가짜 폴더로 동작.
- **미확인:** Web 내보내기 성공, 크롬에서 시작, Android Chrome 실행, iPhone Safari 실행, FPS, 소리, 저장, 터치.
