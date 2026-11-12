"""Command line entry: python -m app <command>

  init-db            create/upgrade the database for the current APP_ENV
  selftest           check config, DB, tasks, AI guard, Telegram logic (offline)
  serve              start the API on API_HOST:API_PORT
  run-task NAME      run a registered task (e.g. ping)
  telegram-check     verify the bot token with Telegram (getMe)        [needs token]
  telegram-whoami    print user IDs that recently messaged the bot     [needs token]
  telegram-send-test send a test message to every allowed user         [needs token]
  telegram-poll-once process pending messages once                     [needs token]
  telegram-run       poll forever (always-on machine only)             [needs token]
"""
from __future__ import annotations

import json
import sys

from app.errors import AppError


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    cmd, args = argv[0], argv[1:]
    from app.core import build_services
    try:
        svc = build_services()
        if cmd == "init-db":
            print(f"OK database ready: {svc.settings.db_path}")
        elif cmd == "selftest":
            from app.selftest import run_selftest
            return run_selftest(svc)
        elif cmd == "serve":
            import uvicorn
            from app.api import create_app
            uvicorn.run(create_app(svc), host=svc.settings.api_host, port=svc.settings.api_port)
        elif cmd == "run-task":
            print(json.dumps(svc.tasks.submit(args[0], {}, actor="cli"), ensure_ascii=False, indent=2))
        elif cmd == "telegram-check":
            me = svc.telegram.get_me()
            print(f"OK bot: @{me.get('username')} (id {me.get('id')})")
        elif cmd == "telegram-whoami":
            seen = {(u["message"]["from"]["id"], u["message"]["from"].get("first_name", ""))
                    for u in svc.telegram.get_updates() if u.get("message", {}).get("from")}
            print("\n".join(f"user_id={i} name={n}" for i, n in seen) or
                  "No messages yet. Send any message to your bot first, then run again.")
        elif cmd == "telegram-send-test":
            svc.settings.validate_for("telegram")
            for uid in svc.settings.telegram_allowed_user_ids:
                sent = svc.telegram.send_message(uid, "✅ AI Command Center 연결 테스트 메시지입니다.")
                print(f"user {uid}: {'sent' if sent else 'dry-run (not sent)'}")
        elif cmd == "telegram-poll-once":
            from app.telegram.poller import poll_once
            print(f"processed {poll_once(svc)} update(s)")
        elif cmd == "telegram-run":
            from app.telegram.poller import run_forever
            svc.settings.validate_for("telegram")
            run_forever(svc)
        else:
            print(f"unknown command: {cmd}\n{__doc__}")
            return 2
        return 0
    except AppError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
