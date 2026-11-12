#!/bin/sh
# 웹으로 내보낸 폴더(기본 build/web)를 itch.io 업로드용 ZIP 으로 묶습니다. (PC/리눅스/맥, 터미널에서)
# 사용: sh tools/make_itch_zip.sh [내보낸폴더] [결과ZIP]
# 규칙: index.html 이 ZIP 맨 위(폴더 안이 아니라)에 있어야 itch.io 가 인식합니다.
set -e
SRC="${1:-build/web}"
OUT="${2:-pyongyang-web-itch.zip}"
[ -f "$SRC/index.html" ] || { echo "[실패] $SRC/index.html 이 없습니다. 먼저 Godot 에서 Web 으로 내보내세요."; exit 1; }
ls "$SRC"/*.wasm >/dev/null 2>&1 || { echo "[실패] .wasm 파일이 없습니다."; exit 1; }
ls "$SRC"/*.pck  >/dev/null 2>&1 || { echo "[실패] .pck 파일이 없습니다."; exit 1; }
OUT_ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
rm -f "$OUT_ABS"
( cd "$SRC" && zip -r -q "$OUT_ABS" . )
echo "만들었습니다: $OUT_ABS"
unzip -l "$OUT_ABS" | head -n 15
echo "크기 제한(itch.io 기준, 제 기억이며 공식 문서로 재확인): 파일 1,000개 이하, 압축 해제 후 합계 500MB 이하"
