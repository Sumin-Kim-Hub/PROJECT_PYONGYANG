# RESUME — 다음 세션 시작용 (이 파일만 읽고 시작)

## 프로젝트
개인 AI 자동화 시스템. 폰(Telegram)으로 명령·보고·승인. 설계 문서: ROADMAP.md(단계), ARCHITECTURE.md(구조). 필요한 부분만 찾아 읽을 것.

## 위치 / 브랜치
- 현재: 게임 저장소 `Sumin-Kim-Hub/PROJECT_PYONGYANG` 의 브랜치 `ccr-ee575a8d-m3vizl`, 폴더 `ai-command-center/` (임시)
- 게임 파일·`main` 수정 금지. 이전 절차: MIGRATION.md
- 신규 저장소 `ai-command-center`: 2026-11-12 기준 **미생성/미접근**

## 완료 (ROADMAP 1~3단계 코드, STATUS.md 참고)
`app/` config · logging_setup(비밀 가림) · db(SQLite) · tasks(작업+승인게이트) · llm/router(안전장치, FakeProvider만) · telegram/{client,bot,poller} · api(FastAPI) · __main__(CLI) · selftest
테스트: `python -m pytest` → 30 passed

## 실행
```
python -m venv .venv && .venv/bin/pip install -r requirements.txt   # Windows: scripts\windows\setup.ps1
python -m app selftest | init-db | serve | run-task ping | telegram-check | telegram-whoami | telegram-send-test | telegram-poll-once
```

## 사용자 대기 항목
1. Private 저장소 `ai-command-center` 생성 (빈 저장소)
2. @BotFather 봇 생성 → 저장소 Secrets: `TELEGRAM_BOT_TOKEN`, (whoami 후) `TELEGRAM_ALLOWED_USER_IDS`

## 다음 할 일
1. 저장소 이전 (MIGRATION.md 명령) → CI 초록불 확인
2. Actions `telegram-test` 실행: check → whoami → send-test (실제 Telegram 검증)
3. ROADMAP 4단계(대시보드 HTML) / 5단계(Gemini 연결) / 6-1(아침 뉴스 브리핑, Actions cron)

## 설계 결정 메모
- Telegram: 프레임워크 없이 httpx 직접 호출, 폴링 방식(포트 개방 없음). dev/test는 dry-run(발송 대신 outbox 기록)
- 외부 행동은 `@registry.task(..., requires_approval=True)` 필수
- AI: `LLMRouter.ask(sensitivity=public|personal|secret)`. secret=로컬만. 기본 LLM_ENABLED=false
- 환경별 DB: data/{env}.db. prod는 토큰·허용목록 없으면 시작 거부(fail closed)
