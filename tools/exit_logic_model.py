"""하차 로직 모형 (파이썬). Godot 실행이 아니다. drive_system.gd 의 후보 자리 계산/상태 전환을 같은 식으로 옮겨 논리 오류만 점검한다.
사용: python3 tools/exit_logic_model.py"""
import math, itertools

def basis(yaw):  # Godot: rotation.y = yaw -> basis.x = right, -basis.z = forward
    return (math.cos(yaw), -math.sin(yaw)), (-math.sin(yaw), -math.cos(yaw))  # right(x,z), forward(x,z)

def candidates(pos, yaw, width, length):
    r, f = basis(yaw)
    base = width * 0.5 + 1.1
    out = []
    for extra in (0.0, 0.9, 1.9):
        sd = base + extra
        out.append(("L%.1f" % sd, (pos[0] - r[0]*sd, pos[1] - r[1]*sd)))
        out.append(("R%.1f" % sd, (pos[0] + r[0]*sd, pos[1] + r[1]*sd)))
    fb = length * 0.5 + 1.2
    out.append(("back", (pos[0] - f[0]*fb, pos[1] - f[1]*fb)))
    out.append(("front", (pos[0] + f[0]*fb, pos[1] + f[1]*fb)))
    return out

def in_body(p, pos, yaw, width, length):
    r, f = basis(yaw)
    dx, dz = p[0]-pos[0], p[1]-pos[1]
    rx = dx*r[0] + dz*r[1]
    rz = -(dx*f[0] + dz*f[1])  # local z (back positive)
    return abs(rx) < width*0.5 + 0.3 and abs(rz) < length*0.5 + 0.3

def blocked(p, boxes, rad=0.35):
    return any(abs(p[0]-b[0]) < b[2]+rad and abs(p[1]-b[1]) < b[3]+rad for b in boxes)

bad = 0
kinds = {"car": (1.8, 4.2), "taxi": (1.8, 4.4), "bus": (2.5, 11.0), "truck": (2.4, 7.0)}
for kind, (w, l) in kinds.items():
    for yawd in (0, 90, -90, 180, 37):
        yaw = math.radians(yawd)
        pos = (10.0, 5.0)
        for nm, p in candidates(pos, yaw, w, l):
            if in_body(p, pos, yaw, w, l):
                bad += 1; print("후보가 차 몸통 안:", kind, yawd, nm)
        # 장애물: 왼쪽 첫 후보와 오른쪽 첫 후보를 막은 경우 → 다른 후보가 선택되어야 함
        c = candidates(pos, yaw, w, l)
        for block_n in (0, 1, 2):
            boxes = [(c[i][1][0], c[i][1][1], 0.6, 0.6) for i in range(block_n)]
            pick = next((nm for nm, p in c if not blocked(p, boxes) and not in_body(p, pos, yaw, w, l)), None)
            if pick is None:
                bad += 1; print("선택 실패:", kind, yawd, block_n)
        # 양쪽 전부 막힌 경우에도 앞/뒤에서 선택되는지
        boxes = [(p[0], p[1], 0.6, 0.6) for nm, p in c if nm[0] in "LR"]
        pick = next((nm for nm, p in c if not blocked(p, boxes)), None)
        if pick not in ("back", "front"):
            bad += 1; print("앞/뒤 대체 실패:", kind, yawd, pick)

# ---- 상태 전환 모형
class Hub: mode = 0
FREE, TRANSITION, DRIVING = 0, 3, 5
class Drive:
    def __init__(s): s.current=None; s.busy=False; s.last_exit=-1e9; s.no_enter=0; s.hub=Hub(); s.log=[]; s.player_physics=True
    def enter(s, car, t):
        if car is None or s.busy or s.current or s.hub.mode != FREE: return
        if t < s.no_enter: s.log.append("enter 무시(직후)"); return
        s.busy=True; s.hub.mode=TRANSITION; s.player_physics=False
        s.current=car; s.hub.mode=DRIVING; s.busy=False
    def request_exit(s, src, t, speed=0.0):
        if t - s.last_exit < 0.35: s.log.append("중복 무시"); return False
        s.last_exit = t
        if s.current is None: s.log.append("차량 없음"); return False
        if s.busy: s.log.append("busy"); return False
        if abs(speed) > 5.0: s.log.append("속도 거부"); return False
        s.busy=True; s.hub.mode=TRANSITION
        return True
    def finish_exit(s, t):
        s.current=None; s.player_physics=True; s.hub.mode=FREE; s.busy=False; s.no_enter=t+0.7
d = Drive(); ok = True
d.enter("taxi", 0); assert d.hub.mode == DRIVING and d.current
assert d.request_exit("touch", 10.0) is True and d.hub.mode == TRANSITION      # 첫 터치
assert d.request_exit("touch", 10.1) is False                                   # 연속 터치
d.finish_exit(10.4); assert d.hub.mode == FREE and d.current is None and d.player_physics
d.enter("taxi", 10.6); assert d.current is None                                 # 직후 연타로 재탑승 안 됨
d.enter("taxi", 11.5); assert d.current == "taxi" and d.hub.mode == DRIVING      # 다시 탑승 가능
assert d.request_exit("touch", 12.0, speed=9.0) is False and d.hub.mode == DRIVING  # 달리는 중 거부
assert d.request_exit("key", 13.0) is True
print("논리 점검 결과: 문제 %d건" % bad, "· 상태 전환 모형 통과")
