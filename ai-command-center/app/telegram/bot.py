"""Command handling: authorization + /start /help /status /today.

Pure logic (update dict in -> reply text out), so it is fully testable without Telegram.
Unauthorized users get NO reply (the bot stays silent) and the attempt is audited.
"""
from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

from app.logging_setup import get_logger

log = get_logger("bot")
WEEKDAYS = "월화수목금토일"

HELP = (
    "📋 사용 가능한 명령\n"
    "/start - 시작 인사\n"
    "/help - 이 도움말\n"
    "/status - 시스템 상태\n"
    "/today - 오늘 요약\n\n"
    "⏳ 준비 중: 뉴스 브리핑(6단계), 일정 연동(9단계), 메모 저장·검색(9단계)"
)


def is_authorized(update: dict, allowed_user_ids: list[int]) -> bool:
    msg = update.get("message") or {}
    user_id = (msg.get("from") or {}).get("id")
    chat = msg.get("chat") or {}
    # Only private chats with an allow-listed user. Groups are refused even if a member is allowed.
    return bool(user_id) and user_id in allowed_user_ids and chat.get("type") == "private" \
        and chat.get("id") == user_id


class CommandBot:
    def __init__(self, services):
        self.svc = services
        self.commands = {"/start": self.cmd_start, "/help": self.cmd_help,
                         "/status": self.cmd_status, "/today": self.cmd_today}

    def handle_update(self, update: dict) -> str | None:
        """Process one update. Returns the reply that was sent (or None if ignored)."""
        msg = update.get("message")
        if not msg:
            return None
        user_id = (msg.get("from") or {}).get("id")
        if not is_authorized(update, self.svc.settings.telegram_allowed_user_ids):
            self.svc.db.audit(f"tg:{user_id}", "telegram.unauthorized",
                              chat_id=(msg.get("chat") or {}).get("id"))
            log.warning("ignored message from unauthorized user %s", user_id)
            return None
        text = (msg.get("text") or "").strip()
        reply = self.dispatch(text)
        self.svc.db.audit(f"tg:{user_id}", "telegram.command", command=text.split(" ")[0][:32])
        self.svc.telegram.send_message(msg["chat"]["id"], reply)
        return reply

    def dispatch(self, text: str) -> str:
        if not text:
            return "텍스트 메시지만 처리할 수 있어요. /help 를 보내 보세요."
        cmd = text.split()[0].split("@")[0].lower()  # "/status@MyBot" -> "/status"
        handler = self.commands.get(cmd)
        if handler:
            try:
                return handler()
            except Exception as e:
                log.exception("command %s failed", cmd)
                return f"⚠️ 명령 처리 중 오류가 났어요 ({type(e).__name__}). 로그에 기록했습니다."
        if cmd.startswith("/"):
            return f"모르는 명령이에요: {cmd}\n/help 로 목록을 확인하세요."
        return "아직 자유 대화는 지원하지 않아요(5·9단계 예정). /help 를 보내 보세요."

    def cmd_start(self) -> str:
        return "👋 MY PERSONAL AI COMMAND CENTER 입니다.\n허용된 사용자로 확인되었습니다.\n\n" + HELP

    def cmd_help(self) -> str:
        return HELP

    def cmd_status(self) -> str:
        s = self.svc.status()
        t = s["tasks"]
        llm = s["llm"]
        fail = s["last_failure"]
        lines = [
            "🖥️ 시스템 상태",
            f"버전 {s['version']} · 환경 {s['env']} · 텔레그램 {s['telegram_mode']}",
            f"가동 {s['uptime_sec'] // 60}분 · DB {'정상' if s['db_ok'] else '❌ 오류'}",
            f"작업: 성공 {t.get('succeeded', 0)} / 실패 {t.get('failed', 0)} / 승인대기 {s['pending_approvals']}",
            f"AI: {'켜짐' if llm['enabled'] else '꺼짐'} · 오늘 {llm['calls_today']}/{llm['daily_call_limit']}회"
            f" · 이번 달 {llm['cost_month_krw']:.0f}/{llm['monthly_budget_krw']}원",
        ]
        if fail:
            lines.append(f"최근 실패: #{fail['id']} {fail['name']} - {(fail['error'] or '')[:80]}")
        return "\n".join(lines)

    def cmd_today(self) -> str:
        now = datetime.now(ZoneInfo(self.svc.settings.timezone))
        approvals = self.svc.tasks.pending_approvals()
        lines = [f"📅 {now:%Y-%m-%d} ({WEEKDAYS[now.weekday()]}) {now:%H:%M}", ""]
        if approvals:
            lines.append(f"✅ 승인 대기 {len(approvals)}건")
            lines += [f"  #{a['id']} {a['summary']}" for a in approvals[:5]]
        else:
            lines.append("✅ 승인 대기 없음")
        lines += ["", "⏳ 아직 연결 안 됨: 뉴스 브리핑(6단계), 일정(9단계), 출석 체크리스트(7단계)"]
        return "\n".join(lines)
