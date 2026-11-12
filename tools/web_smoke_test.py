#!/usr/bin/env python3
"""웹 내보내기 결과(build/web)를 PC용 헤드리스 크롬으로 열어 "시작은 하는지" 확인하는 점검 도구.

사용: python3 tools/web_smoke_test.py build/web out_dir [대기초=150]
출력: out_dir/web_smoke.png (화면), out_dir/web_smoke_console.txt (브라우저 콘솔 전체), out_dir/web_smoke_report.txt
종료코드: 0 = 통과, 1 = 실패

!! 이 점검이 보장하는 것과 못 하는 것 !!
- 보장: 내보낸 파일이 있고, 크롬(소프트웨어 렌더링)에서 엔진이 켜지고, 게임의 시작 로그와 자체 점검 로그가 나오는지.
- 못 하는 것: 실제 안드로이드/아이폰에서 되는지, 속도(FPS), 메모리, 소리, 터치 조작. 그건 사람 폰으로만 확인할 수 있습니다.
- 소프트웨어 렌더링은 매우 느려서 프레임 수치를 해석하면 안 됩니다.
"""
import http.server
import os
import socketserver
import sys
import threading
import time
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    web = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]).resolve()
    wait = int(sys.argv[3]) if len(sys.argv) > 3 else 150
    out.mkdir(parents=True, exist_ok=True)
    report = []

    def say(msg: str) -> None:
        print(msg)
        report.append(msg)

    index = web / "index.html"
    if not index.exists():
        say("[실패] %s 가 없습니다. 내보내기가 되지 않았습니다." % index)
        (out / "web_smoke_report.txt").write_text("\n".join(report), encoding="utf-8")
        return 1
    files = sorted(p.name for p in web.iterdir())
    say("내보낸 파일: " + ", ".join(files))
    for p in sorted(web.iterdir()):
        if p.suffix in (".wasm", ".pck", ".js"):
            say("  %s  %.1f MB" % (p.name, p.stat().st_size / 1048576.0))
    if not any(p.suffix == ".wasm" for p in web.iterdir()):
        say("[실패] .wasm 파일이 없습니다.")
    if not any(p.suffix == ".pck" for p in web.iterdir()):
        say("[실패] .pck 파일이 없습니다.")

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=str(web), **k)

        def log_message(self, *a):
            pass

        def end_headers(self):
            # 단일 스레드 빌드는 필요 없지만, 켜 둬도 해가 없는 헤더
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
            super().end_headers()

    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(("127.0.0.1", 0), Handler)
    port = httpd.server_address[1]
    threading.Thread(target=httpd.serve_forever, daemon=True).start()

    from playwright.sync_api import sync_playwright

    console_lines = []
    errors = []
    started = False
    selftest_line = ""
    ok = True
    with sync_playwright() as pw:
        browser = pw.chromium.launch(args=[
            "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
            "--ignore-gpu-blocklist", "--enable-webgl",
        ])
        ctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True,
                                  device_scale_factor=1)
        page = ctx.new_page()

        def on_console(m):
            t = m.text
            console_lines.append("[%s] %s" % (m.type, t))

        page.on("console", on_console)
        page.on("pageerror", lambda e: errors.append(str(e)))
        t0 = time.time()
        page.goto("http://127.0.0.1:%d/index.html" % port, wait_until="load", timeout=60000)
        say("페이지 열림 (%.1fs)" % (time.time() - t0))
        has_canvas = False
        try:
            page.wait_for_selector("canvas", timeout=60000)
            has_canvas = True
        except Exception as e:  # noqa: BLE001
            say("[실패] canvas 가 나타나지 않았습니다: %s" % e)
        say("canvas 생성: %s" % has_canvas)
        # 시작 로그를 기다림
        deadline = time.time() + wait
        while time.time() < deadline:
            joined = "\n".join(console_lines)
            if "시스템 준비 완료" in joined:
                started = True
            for ln in console_lines:
                if "[PYONGYANG]" in ln and "점검" in ln:
                    selftest_line = ln
            if started and selftest_line:
                break
            page.wait_for_timeout(2000)  # time.sleep 은 콘솔 이벤트를 받지 못함
        page.wait_for_timeout(3000)
        page.screenshot(path=str(out / "web_smoke.png"))
        browser.close()
    httpd.shutdown()

    (out / "web_smoke_console.txt").write_text("\n".join(console_lines), encoding="utf-8")
    script_err = [c for c in console_lines if "SCRIPT ERROR" in c or "Parse Error" in c or "Parser Error" in c]
    gl_err = [c for c in console_lines if "WebGL" in c and ("not supported" in c or "failed" in c.lower())]
    say("게임 시작 로그(시스템 준비 완료): %s" % started)
    say("자체 점검 로그: %s" % (selftest_line or "못 찾음(대기 시간이 모자랐을 수 있음)"))
    say("페이지 오류 %d건, 스크립트 오류 로그 %d건, WebGL 오류 로그 %d건" % (len(errors), len(script_err), len(gl_err)))
    for e in (errors + script_err + gl_err)[:15]:
        say("  - " + e[:240])
    if not has_canvas or not started or errors or script_err:
        ok = False
    say("결과: %s" % ("통과(PC 크롬 소프트웨어 렌더링 기준)" if ok else "실패 또는 불완전"))
    say("주의: 이 결과는 안드로이드/아이폰 실행 성공을 뜻하지 않습니다.")
    (out / "web_smoke_report.txt").write_text("\n".join(report), encoding="utf-8")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
