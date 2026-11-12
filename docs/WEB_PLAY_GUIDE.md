# 웹(브라우저)으로 실행하기 — 설치 없이 링크 하나로 (미검증)

> **결론:** 가능합니다. Godot 는 게임을 웹페이지로 내보낼 수 있고, 그러면 아이폰(사파리)과 안드로이드(크롬) 친구가 **링크 하나**만 열면 됩니다. 앱 설치도 APK 도 필요 없습니다.
> **하지만 이 환경에는 Godot 가 없어서 제가 웹 버전을 만들어 보지도, 돌려 보지도 못했습니다.** 아래 장치(내보내기 설정 + 자동 빌드 워크플로)는 "시도할 준비"일 뿐이며 **전부 미검증**입니다. 이 3D 도시가 폰 브라우저에서 실제로 도는지는 해 봐야 압니다.

> **V3.0.4 추가 문서:** 호환성 분석 → `docs/WEB_COMPAT_ANALYSIS.md`, itch.io/링크 배포 → `docs/WEB_ITCH_DEPLOY.md`.

## 준비해 둔 것 (이 ZIP 에 들어 있음)
| 파일 | 역할 |
|---|---|
| `export_presets.cfg` | Godot 의 "Web" 내보내기 설정 (스레드 끔 = 아이폰 호환에 유리, 호환성 렌더러는 이미 사용 중) |
| `.github/workflows/web-export.yml` | GitHub 가 대신 Godot 4.7.2 를 내려받아 웹으로 내보내고 GitHub Pages 에 올려 주는 자동 작업 |

## 방법 A — PC 가 있을 때 (가장 쉬움, 약 15분)
1. GitHub 가입 → 새 저장소(Public) 만들기.
2. ZIP 을 풀어서 **`PROJECT_PYONGYANG` 폴더 안의 내용 전체**(`project.godot` 가 저장소 맨 위에 오도록)를 저장소에 올립니다. (웹에서 "Add file → Upload files" 에 폴더째 끌어다 놓기 가능)
3. 저장소 Settings → Pages → Build and deployment → Source 를 **GitHub Actions** 로 바꿉니다.
4. Actions 탭 → `web-export` → **Run workflow**. 몇 분 뒤 초록색이 되면 끝.
5. 주소는 `https://<내 GitHub 이름>.github.io/<저장소 이름>/` 입니다. 이 링크를 친구에게 보냅니다.
6. 빨간색(실패)이면 **실패한 단계의 로그를 그대로 복사해서** 보내 주세요. 다운로드 주소나 내보내기 설정이 틀렸을 가능성이 있습니다.

## 방법 B — 폰만 있을 때 (복잡함, 비추천)
- 폰 브라우저는 "폴더째 업로드"가 안 되어 3번 단계가 어렵습니다. 대안으로 GitHub **Codespaces**(브라우저 안의 작은 컴퓨터, 무료 사용량 제한 있음)를 열어 ZIP 을 올리고 터미널에서 `unzip` 후 `git push` 하는 방법이 있습니다. 해 본 적 없고 단계가 많아서, **친구나 가족의 PC 를 15분 빌리는 쪽을 권합니다.**

## 친구에게 알려 줄 것
- 링크를 **폰을 가로로** 돌려서 엽니다. 처음엔 약 40MB 를 내려받아 **로딩이 오래 걸립니다**(Wi-Fi 권장).
- 저장은 브라우저 안에 됩니다. **브라우저 데이터를 지우면 저장이 사라집니다.**
- 아이폰 사파리는 전체 화면을 지원하지 않아 주소창이 보일 수 있습니다.

## 알려진 위험 (모두 미검증)
- **성능/메모리:** 이 게임은 건물·NPC·차량이 많은 3D 도시입니다. 웹(WebGL 2, 스레드 없음)에서는 앱보다 느리고, 아이폰에서는 메모리 부족으로 꺼질 수 있습니다. 느리면 `feature_flags.gd` 의 `CROWD_COUNT` 를 낮추세요.
- **소리:** 배경음/사이렌은 코드로 합성합니다(`V22_AUDIO`). 브라우저에서 안 나오거나 끊기면 `V22_AUDIO=false`. 브라우저는 첫 터치 뒤에야 소리를 허용합니다.
- **한글 글꼴:** 기본 글꼴에서 한글이 보이는지 확인된 적이 없습니다.
- **Pages 공개 범위:** 무료 GitHub Pages 는 보통 공개 저장소를 요구합니다(제 기억 기준, 요금 정책은 공식 확인 필요). 소스 코드가 공개됩니다. 공개가 싫으면 itch.io 에 "비공개 주소"로 올리는 방법이 있습니다(웹 내보내기 폴더를 ZIP 으로 올림, 제한: 파일 1,000개/500MB).
- **다운로드 주소:** 워크플로는 `github.com/godotengine/godot/releases` 의 4.7.2 파일 이름 규칙(`Godot_v4.7.2-stable_linux.x86_64.zip`, `..._export_templates.tpz`)을 가정합니다. 틀리면 첫 단계에서 실패합니다.

## 근거 (열어 본 글)
- Ziva: [How to export a Godot game to the web and share a playable link](https://ziva.sh/blogs/godot-web-export) — Compatibility 렌더러만 웹 지원, 4.3 이후 단일 스레드가 기본, HTTPS 필요, itch.io 업로드 방법, `index.wasm` 약 39.5MB. 저자도 사파리는 테스트하지 않았다고 적음.
- Godot 4.7.2 출시: [godotengine.org 아카이브](https://godotengine.org/download/archive/4.7.2-stable/)
