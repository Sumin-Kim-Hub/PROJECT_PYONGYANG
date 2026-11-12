"""Guards that run in every test pass: no secrets or private data committed."""
import re
import subprocess
from pathlib import Path

from app.logging_setup import _PATTERNS

ROOT = Path(__file__).resolve().parent.parent
ALLOW = {"tests/conftest.py", "tests/test_core.py", "tests/test_telegram_api.py"}  # fake test tokens only


def _tracked_files():
    try:
        out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
        return [ROOT / p for p in out.splitlines()]
    except (OSError, subprocess.CalledProcessError):
        return [p for p in ROOT.rglob("*") if p.is_file() and ".git" not in p.parts]


def test_no_secret_shaped_strings_in_repo():
    hits = []
    for f in _tracked_files():
        rel = f.relative_to(ROOT).as_posix()
        if rel in ALLOW or not f.is_file() or f.suffix in {".png", ".jpg", ".zip", ".db"}:
            continue
        text = f.read_text(encoding="utf-8", errors="ignore")
        hits += [f"{rel}: {m.group(0)[:12]}…" for p in _PATTERNS[:3] for m in p.finditer(text)]
    assert not hits, f"possible secrets committed: {hits}"


def test_private_files_are_ignored():
    gi = (ROOT / ".gitignore").read_text(encoding="utf-8")
    for pattern in (".env", "data/*", "logs/*", "*.db"):
        assert pattern in gi
    tracked = [f.relative_to(ROOT).as_posix() for f in _tracked_files()]
    assert not [t for t in tracked if re.match(r"(\.env($|\.(?!example))|.*\.db$)", t)]
