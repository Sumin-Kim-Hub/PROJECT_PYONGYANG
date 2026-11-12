# MY PERSONAL AI COMMAND CENTER — 설계 문서 묶음

> ⚠️ 이 폴더는 **임시 보관 장소**입니다. 게임 저장소(PROJECT_PYONGYANG)의 작업 브랜치에만 올라가 있고 `main`에는 합치지 않습니다.
> 새 비공개 저장소(`ai-command-center`, 이름은 예시)가 만들어지면 이 폴더째 그쪽으로 옮기고 여기서는 지웁니다.
> 게임 프로젝트의 기존 파일은 하나도 수정·삭제하지 않았습니다.

## 📱 모바일용 3줄 요약

1. **지금(폰만 있음)**: GitHub Actions(무료 자동 실행)가 매일 뉴스·트렌드·OTT를 정리해서 **Telegram으로 보내 주는 것**부터 만듭니다. 비용은 0원입니다.
2. **노트북 이후**: 노트북에서 Telegram 봇·대시보드·개인 데이터 저장소를 돌리고, 폰에서는 **Tailscale**(무료 개인 VPN)로 안전하게 접속합니다.
3. **금융·건강 데이터는 GitHub과 클라우드 AI에 절대 올리지 않고** 노트북 안에만 둡니다. 게시·결제처럼 밖으로 나가는 행동은 **반드시 Telegram 승인 버튼**을 거칩니다.

## 문서 목록

| 문서 | 내용 |
|---|---|
| [PROJECT_MASTER_PLAN.md](PROJECT_MASTER_PLAN.md) | 목표, 원칙, 현재 환경 확인 결과, 할 수 있는 것과 없는 것, 기능별 실현 방법 |
| [TECH_STACK_COMPARISON.md](TECH_STACK_COMPARISON.md) | OpenClaw·n8n·Dify·LangGraph 등 10개 항목 비교 (확인된 정보와 추정 구분) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 추천 시스템 구조, 각 프로그램의 역할, 데이터·보안·Telegram·대시보드 설계 |
| [ROADMAP.md](ROADMAP.md) | 12단계 개발 계획 (작업, 프로그램, 검증 방법, 위험) |
| [COST_AND_SECURITY.md](COST_AND_SECURITY.md) | 비용 절약 전략, 보안 규칙, 금융·건강 데이터 취급 원칙 |

## 상태

- 설계 단계 완료: 2026-11-12
- 실제로 구현된 기능: **아직 없음** (코드 0줄)
