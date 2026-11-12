# MIGRATION — 신규 Private 저장소로 이전하는 절차

## 현재 상태 (2026-11-12)
- ❌ **이전 미완료.** 신규 저장소 `Sumin-Kim-Hub/ai-command-center` 가 아직 없거나 이 세션에서 접근할 수 없음 (`add_repo` 확인 결과 "not found / no access").
- 이 폴더는 게임 저장소의 **작업 브랜치 `ccr-ee575a8d-m3vizl` 에만** 존재. `main` 과 게임 파일은 변경 없음.
- 이 폴더는 **그 자체로 완결된 프로젝트**(루트 기준 경로 사용)라서 폴더째 새 저장소의 루트가 되면 바로 동작.

## 이전 방법 (이력 보존, 검증 완료)
`git subtree split` 으로 이 폴더의 커밋 이력만 뽑아 새 저장소의 `main` 으로 보냄.
2026-11-12에 로컬에서 시험 실행 → 결과 브랜치에 게임 파일 없이 이 폴더 내용만 루트에 위치함을 확인 (푸시는 안 함).

### 👤 사용자 (폰, 3분)
1. GitHub 앱/웹 → **New repository**
   - 이름: `ai-command-center` · **Private** · README/라이선스/.gitignore **추가하지 않음** (빈 저장소여야 충돌 없음)
2. Claude Code 새 세션을 열 때 이 저장소도 선택하거나, 세션에서 "ai-command-center 저장소 연결해줘"라고 요청

### 🤖 Claude (명령)
```bash
cd PROJECT_PYONGYANG
git subtree split --prefix=ai-command-center -b acc-export
git push https://github.com/Sumin-Kim-Hub/ai-command-center.git acc-export:main
git branch -D acc-export
```
그 다음 새 저장소에서: 테스트 실행 → CI 초록불 확인 → 그 결과를 보고.

### 이전 후 정리
- 새 저장소에서 정상 동작 확인 **후에만** 게임 저장소 작업 브랜치에서 `ai-command-center/` 제거 (사용자 확인 후)
- `main` 은 처음부터 끝까지 건드리지 않음

### 이전 후 활성화되는 것
- `.github/workflows/ci.yml` (테스트 + gitleaks 비밀 검사) — 저장소 루트에 있어야 동작하므로 **지금은 비활성**
- `.github/workflows/telegram-test.yml` (수동 실행 Telegram 점검)
