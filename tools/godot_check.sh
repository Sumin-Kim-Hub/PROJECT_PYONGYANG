#!/usr/bin/env bash
# Godot 로 프로젝트를 헤드리스로 열어 스크립트 오류를 로그로 찾는 검사 (Godot 4.7.2 headless 로 실행 확인)
# 사용: tools/godot_check.sh /path/to/godot   (프로젝트 루트에서 실행)
#
# 주의: Godot 4 의 `--import` 나 `--quit` 은 스크립트 오류가 있어도 종료 코드 0 을 줄 수 있다는 보고가 있어,
#       종료 코드가 아니라 "로그 글씨"로 판정한다.
set -u
GODOT="${1:-godot}"
LOG="$(mktemp)"
FAIL=0

echo "== 1) 프로젝트 가져오기"
"$GODOT" --headless --path . --import >"$LOG" 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error|ERROR:" "$LOG" | grep -v "export_presets" ; then
  echo "-> 가져오기 중 오류 글씨가 있음"; FAIL=1
fi

echo "== 2) 메인 장면을 약 20초(가상 시간) 실행"
# --fixed-fps 로 프레임당 시간을 고정해, 빠르게 돌려도 게임 시간이 흐르게 함. 자체 점검은 9초 뒤 실행됨.
"$GODOT" --headless --path . --fixed-fps 60 --quit-after 1500 >"$LOG" 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error" "$LOG"; then
  echo "-> 실행 중 스크립트 오류"; FAIL=1
fi
for must in "V3.0 준비 완료" "자체 점검 V3.0" "[KoreanFont] 한글 글꼴 적용: res://assets/fonts/NanumGothic.ttf (한글 글리프 true)"; do
  if ! grep -qF "$must" "$LOG"; then
    echo "-> 기대한 로그가 없음: $must"; FAIL=1
  fi
done
grep -E "\[PYONGYANG\] .*(실패|주의)" "$LOG" || true
grep -E "\[PYONGYANG\] 자체 점검" "$LOG" || true
grep -F "[KoreanFont]" "$LOG" || true

if [ "$FAIL" -eq 0 ]; then echo "통과 (로그 기준)"; else echo "실패 — 위 글씨를 확인"; fi
exit "$FAIL"
