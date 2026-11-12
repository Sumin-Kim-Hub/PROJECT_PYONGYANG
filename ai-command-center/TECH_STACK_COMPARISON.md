# TECH STACK COMPARISON — 오픈소스·기술 비교

조사일: 2026-11-12

**표시 규칙**
- ✅ **확인**: 이번에 웹 검색 결과로 확인 (단, 대부분 2차 자료. 공식 LICENSE 파일 원문은 다음 단계에서 직접 확인 예정)
- 🔶 **추정**: 일반적으로 알려진 내용 또는 이전 지식 기반. 사용 전 재확인 필요
- 💡 **판단**: 우리 프로젝트 기준의 Claude 의견

---

## 1. 한눈에 보는 결론

| 기술 | 역할 | 우리 프로젝트 채택 | 언제 |
|---|---|---|---|
| **Telegram Bot API** | 모바일 명령·보고 창구 | ⭐ **핵심 채택** | 3단계 |
| **GitHub Actions** | 클라우드 예약 실행 (폰 단계의 엔진) | ⭐ **핵심 채택** | 1~6단계 |
| **Python + FastAPI + SQLite** | 본체(코어), 대시보드, 데이터 저장 | ⭐ **핵심 채택** | 2단계부터 |
| **n8n** | 클릭으로 만드는 연동 작업(Gmail·캘린더 등) | ✅ **부분 채택** (노트북 이후, 선택) | 9단계 |
| **Tailscale** | 폰 → 노트북 안전 접속 | ✅ 채택 (노트북 이후) | 4·11단계 |
| **Ollama (로컬 AI)** | 개인정보용 AI (외부 전송 없음) | ✅ 조건부 (노트북 사양 확인 후) | 8·10단계 |
| **OpenClaw** | 올인원 개인 AI 비서 | ⏸️ **보류** (보안 위험) — 아이디어만 참고 | 9단계에 격리 테스트 |
| **Dify** | AI 앱·지식베이스 플랫폼 | ❌ 미채택 (너무 무거움) | — |
| **LangGraph** | 복잡한 AI 에이전트 프로그래밍 라이브러리 | ⏸️ 보류 (필요해지면) | 9단계 이후 |
| **Activepieces** | n8n 대안 (MIT) | 예비 후보 | — |

---

## 2. 항목별 상세 비교 (10개 기준)

### 2-1. OpenClaw (구 Clawdbot / Moltbot)

| 기준 | 내용 |
|---|---|
| 1. 실제 기능 | Telegram·WhatsApp 등 메신저로 대화하는 개인 AI 비서. 스킬(플러그인) 마켓 ClawHub, 예약 작업, 컴퓨터 조작. 🔶 |
| 2. 오픈소스 | ✅ 예 (github.com/openclaw/openclaw) |
| 3. 라이선스 | ✅ MIT. 창시자가 2026년 2월 OpenAI 합류 후 OpenClaw Foundation으로 이관 |
| 4. 무료 범위 | 프로그램은 무료. **AI 모델 사용료는 별도** 🔶 |
| 5. 추가 비용 | 🔶 대화·작업마다 큰 AI 모델을 많이 호출 → API 비용이 커지기 쉬움 |
| 6. Windows | 🔶 Node.js 기반, WSL2 권장으로 알려짐 |
| 7. 모바일 운영 | Telegram으로 조작 가능 (단, 본체는 PC/서버에서 상시 실행 필요) |
| 8. 유지보수 | ✅ 매우 활발 (GitHub 별 수십만 개, 2026년 기준) |
| 9. 보안 위험 | ✅ **높음**. 2026년 2월 치명적 취약점 CVE-2026-25253(CVSS 8.8), ClawHub 악성 스킬 341개 발견(정보 탈취 악성코드 유포). 패치 여부는 **미확인** |
| 10. 재사용할 부분 | 💡 설계 아이디어: "메신저 = 리모컨", DM 페어링(허락된 사람만 대화), 스킬 구조, 예약 작업. **코드는 지금 도입하지 않음** |

💡 **판단**: 기능은 우리 목표와 가장 비슷하지만, 컴퓨터 전체 권한 + 외부 스킬 + 금융 데이터 조합은 위험합니다. 노트북 이전 후 **격리 환경에서 외부 스킬 없이** 시험해 보고 결정합니다.

### 2-2. n8n

| 기준 | 내용 |
|---|---|
| 1. 실제 기능 | 블록을 연결해 자동화를 만드는 도구. Gmail·Google 캘린더·Telegram·RSS·AI 연결 블록 다수 |
| 2. 오픈소스 | ✅ 정확히는 "소스 공개(fair-code)". 일반 오픈소스 라이선스는 아님 |
| 3. 라이선스 | ✅ Sustainable Use License. 개인·내부 사용 허용, **n8n 자체를 재판매·호스팅 서비스로 제공 금지** |
| 4. 무료 범위 | ✅ 직접 설치(self-host) 시 실행 횟수·워크플로 수 제한 없음 (컴퓨터 성능이 한계) |
| 5. 추가 비용 | 클라우드 버전은 유료. SSO 등 기업 기능 유료. 개인 사용엔 불필요 |
| 6. Windows | 🔶 Docker Desktop 또는 Node.js(npx)로 실행 가능 |
| 7. 모바일 운영 | 🔶 편집 화면은 폰에서 불편. 실행 결과는 Telegram으로 받으면 됨 |
| 8. 유지보수 | 🔶 매우 활발 |
| 9. 보안 위험 | 🔶 중간. 연결 계정 비밀번호를 n8n이 보관 → 외부 공개 금지, 최신 버전 유지 필요. ⚠️ Telegram Trigger 블록은 **외부에서 접속 가능한 주소(webhook)** 가 필요 → 노트북을 인터넷에 노출해야 하는 문제 |
| 10. 재사용할 부분 | 💡 Gmail·캘린더처럼 "로그인 연동이 귀찮은 작업"만 n8n에 맡김. Telegram 창구는 우리 Python 봇이 담당하고 n8n은 노트북 내부에서만 호출 |

### 2-3. Dify

| 기준 | 내용 |
|---|---|
| 1. 실제 기능 | 챗봇·AI 워크플로·문서 검색(RAG) 앱을 화면에서 만드는 플랫폼 |
| 2. 오픈소스 | ✅ 소스 공개 |
| 3. 라이선스 | ✅ "Dify Open Source License" = Apache 2.0 + 추가 조건 (다중 사용자 SaaS 운영 금지, 로고 제거 금지) |
| 4. 무료 범위 | 직접 설치 시 개인 사용 무료 (2차 자료 기준) |
| 5. 추가 비용 | AI 모델 사용료 별도 |
| 6. Windows | 🔶 Docker Compose로 여러 개 프로그램(DB, Redis, 벡터DB 등)을 띄움 → 메모리 4GB 이상 필요로 알려짐 |
| 7. 모바일 운영 | 🔶 만든 챗봇은 웹으로 접근 가능, 관리 화면은 PC용 |
| 8. 유지보수 | 🔶 활발 |
| 9. 보안 위험 | 🔶 중간 (구성요소가 많아 관리할 것이 많음) |
| 10. 재사용할 부분 | 💡 없음(현재). 개인 지식 검색은 SQLite 전문 검색으로 충분히 시작 가능 |

💡 **판단**: 기능은 좋지만 1인 개인용으로는 무겁습니다. 노트북 사양이 넉넉하고 지식베이스가 커지면 그때 재검토.

### 2-4. LangGraph

| 기준 | 내용 |
|---|---|
| 1. 실제 기능 | AI 에이전트의 "생각 → 도구 사용 → 사람 승인 → 계속" 흐름을 코드로 만드는 라이브러리 |
| 2. 오픈소스 | ✅ 예 |
| 3. 라이선스 | ✅ 라이브러리는 MIT. ⚠️ 단, 개발 서버 패키지 `langgraph-api`는 Elastic License 2.0 (2차 자료) |
| 4. 무료 범위 | 라이브러리 무료. 관리형 호스팅(LangSmith 등)은 유료 |
| 5. 추가 비용 | AI 모델 사용료 별도 |
| 6. Windows | 🔶 Python 라이브러리라 문제 없음 |
| 7. 모바일 운영 | 해당 없음 (라이브러리) |
| 8. 유지보수 | ✅ 활발 (2026년 8월 1.2.x 릴리스) |
| 9. 보안 위험 | 🔶 낮음 (우리가 허락한 도구만 사용) |
| 10. 재사용할 부분 | 💡 9단계 "개인 AI 비서"에서 여러 단계 작업 + 승인 흐름이 복잡해지면 도입. 그 전에는 단순 Python으로 충분 |

### 2-5. Telegram Bot API

| 기준 | 내용 |
|---|---|
| 1. 실제 기능 | 봇이 메시지·사진·파일 전송, 버튼(승인/거절), 명령어 수신 |
| 2~3. 오픈소스/라이선스 | 서비스 API (무료). Python 라이브러리 `python-telegram-bot`은 🔶 LGPL-3.0 (개인 사용 문제 없음) |
| 4~5. 무료/비용 | 🔶 무료. 추가 비용 없음 |
| 6. Windows | 🔶 문제 없음 |
| 7. 모바일 | ⭐ Telegram 앱 그대로 사용 |
| 8. 유지보수 | 🔶 안정적 |
| 9. 보안 위험 | 🔶 봇 토큰 유출 시 봇 탈취. 봇 대화는 **종단간 암호화가 아님** → 민감한 금액·건강 상세는 보내지 않음. 내 chat_id만 허용 |
| 10. 재사용할 부분 | 💡 모든 명령·보고·승인의 단일 창구 |

**폴링 방식** 사용: 봇이 텔레그램 서버에 "새 메시지 있어?"라고 주기적으로 묻는 방식 → 노트북을 인터넷에 열어 둘 필요가 없음 (보안상 큰 장점).

### 2-6. 모바일 웹 대시보드 후보

| 후보 | 장점 | 단점 | 판단 |
|---|---|---|---|
| **FastAPI + 간단한 HTML** | 가볍고, 승인·상태 API와 한 몸 | 화면을 직접 만들어야 함 | ⭐ 추천 |
| Streamlit | 차트가 쉬움 | 무겁고 폰 화면에서 어색 | 예비 |
| Telegram Mini App | Telegram 안에서 열림 | 공개 HTTPS 주소 필요 | 나중 검토 |
| GitHub Pages | 무료 | 비공개 저장소는 유료 플랜 필요🔶, 개인정보 못 올림 | ❌ |

접속: **Tailscale**(🔶 개인 무료 요금제 존재) — 폰과 노트북을 나만의 비공개 네트워크로 묶음. 인터넷에 포트를 열지 않음.

### 2-7. Windows 자동화 도구

| 도구 | 용도 | 판단 |
|---|---|---|
| **작업 스케줄러** (Windows 내장) | 로그인 시 봇 자동 실행, 매일 작업 | ⭐ 채택 |
| **winget** (내장) | Git·Python 등 설치 명령 한 줄 | ⭐ 채택 |
| Docker Desktop + WSL2 | n8n 실행 | 선택 (🔶 개인 사용 무료) |
| Playwright | 웹페이지 읽기·이미지 생성 (카드뉴스 HTML→PNG) | 채택 (로그인 필요한 사이트 자동조작에는 사용 안 함) |
| AutoHotkey / Power Automate Desktop | 화면 클릭 자동화 | ❌ 약관 위반·오작동 위험 |

### 2-8. AI 모델

| 모델 | 비용 | 개인정보 | 용도 |
|---|---|---|---|
| **Gemini Flash 무료 등급** | ✅ 무료(카드 불필요). 한도는 자주 축소되고 AI Studio에서 확인해야 함. Pro는 유료 전용 | 🔶 무료 등급 입력은 **Google 서비스 개선에 쓰일 수 있음** | 뉴스·트렌드 등 **공개 정보만** |
| **Claude API (Haiku/Sonnet)** | 사용한 만큼 과금, 월 상한 설정 | 🔶 API 입력은 기본적으로 학습에 미사용 | 블로그 초안 등 품질 필요 작업 (선택) |
| **Ollama 로컬 모델** | 무료(전기료) | 외부 전송 없음 | 금융·건강·개인 메모 |
| Claude Code 구독 | 이미 사용 중 | — | **개발 전용**. 매일 자동 실행용으로 쓰지 않음 (사용량 아끼기) |

### 2-9. 기타 데이터 소스

| 소스 | 확인 상태 | 비고 |
|---|---|---|
| 네이버 블로그 글쓰기 API | ✅ **2020년 5월 종료** | 자동 게시 불가 → 초안 + 직접 붙여넣기 |
| 네이버 데이터랩 검색어 트렌드 API | 🔶 무료, 네이버 개발자센터 앱 등록 필요 | 트렌드 분석 |
| 네이버 검색 API (뉴스/블로그) | 🔶 무료 일일 한도 | 2026년 API 허브 이관 공지 있음 → 재확인 |
| RSS (연합뉴스, BBC, Variety, Deadline 등) | 🔶 무료 | 뉴스 수집의 기본 |
| TMDB API | 🔶 무료(비상업), 출처 표기 필수 | OTT 추천, 한국 제공 서비스 정보 |
| Instagram Graph API 게시 | 🔶 비즈니스/크리에이터 계정 + Facebook 페이지 + Meta 앱 필요 | 초기엔 수동 업로드 |
| 공공데이터포털 공공서비스(혜택) API | 🔶 **존재·조건 확인 필요** | 공공지원금 탐색 |
| Google Calendar / Gmail API | 🔶 무료, OAuth 설정 필요 | 일정·메일 |

---

## 3. 참고한 자료 (이번 조사)

- OpenClaw: [nxcode 가이드](https://www.nxcode.io/blog/openclaw-complete-guide-2026), [catalaize](https://catalaize.substack.com/p/openclaw-from-viral-prototype-to), [elephas 보안 분석](https://elephas.app/blog/opean-claw-clawdbot-viral-launch), [rywalker](https://rywalker.com/research/openclaw)
- n8n: [공식 라이선스 FAQ](https://docs.n8n.io/n8n-community-license/community-license/license-faq), [toolradar 가격](https://toolradar.com/blog/n8n-pricing-2026)
- Dify: [dev.co](https://dev.co/ai/frameworks/dify), [vibecoding 리뷰](https://vibecoding.app/blog/dify-review)
- LangGraph: [agentsindex 라이선스](https://agentsindex.ai/pricing/langgraph), [aiwiki](https://aiwiki.ai/wiki/langgraph)
- Activepieces: [공식 라이선스 문서](https://activepieces.com/docs/about/license)
- Gemini 무료 등급: [apidog](https://apidog.com/blog/gemini-api-free-tier/), [agentdeals 가격 변경](https://agentdeals.dev/gemini-api-pricing-changes)
- 네이버 블로그 API 종료: [뉴스핌 2020-04-13](https://newspim.com/news/view/20200413000737)

⚠️ 위 자료 대부분은 블로그·리뷰 등 2차 자료입니다. 실제 도입 직전에 각 프로젝트의 **공식 LICENSE 파일과 공식 문서**를 다시 확인합니다 (ROADMAP 각 단계의 "검증" 항목에 포함).
