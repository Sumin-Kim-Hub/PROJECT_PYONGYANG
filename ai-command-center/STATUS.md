# STATUS — 실제로 무엇이 동작하는가

마지막 갱신: 2026-11-12 · 버전 0.1.0 · 테스트 30/30 통과 (Linux, Python 3.13)

| 기능 | 상태 | 근거 |
|---|---|---|
| 설정 관리 (.env, 환경 분리 dev/test/prod) | ✅ 동작 | 테스트 |
| SQLite DB (작업·승인·감사로그·AI사용량·캐시·발송함) | ✅ 동작 | 테스트, CLI `init-db` |
| 로그 + 비밀 자동 가림 | ✅ 동작 | 테스트 (URL 속 토큰 가림 버그 발견·수정) |
| 작업 관리 + 재시도 + 오류 기록 | ✅ 동작 | 테스트, CLI `run-task ping` |
| 승인 게이트 (승인/거절/24시간 만료) | ✅ 동작 | 테스트 |
| AI 라우터 안전장치 (기본 꺼짐, 민감도별 차단, 일일·월 한도, 캐시) | ✅ 동작 (가짜 모델로만) | 테스트 |
| 실제 AI 모델 (Gemini/Claude/Ollama) | ❌ 미구현 | 5단계 |
| FastAPI (/health, 토큰 인증 /api/status·tasks·approvals) | ✅ 동작 | 테스트 + 실제 서버 기동 후 curl |
| Telegram 명령 처리 /start /help /status /today | ✅ 로직 동작 | 테스트 (가짜 Telegram 서버) |
| Telegram 사용자 인증 (허용 ID + 1:1 대화만, 미허가자 무응답·기록) | ✅ 로직 동작 | 테스트 |
| Telegram 실제 발송·수신 | ⏸️ **미검증** — 봇 토큰 없음 | 0단계(사용자) 필요 |
| 상시 수신 (`telegram-run`) | ⏸️ 코드만 있음, 실행 안 함 | 상시 서버 확보 후 (9·11단계) |
| GitHub Actions (CI, Telegram 점검) | ⏸️ 파일만 준비, **비활성** | 저장소 이전 후 |
| Windows 스크립트 (setup.ps1, run.ps1) | ⏸️ 작성만, **Windows에서 실행 안 해 봄** | 노트북 확보 후 |
| 모바일 대시보드 화면 | ❌ 미구현 (API만 있음) | 4단계 |
