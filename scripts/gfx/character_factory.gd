extends RefCounted
## 캐릭터 모델 교체 지점 (GLB 대응 구조).
##  - res://assets/characters/ 폴더에 .glb 파일을 넣으면 코드 수정 없이 그 모델이 쓰입니다.
##      <npc_id>.glb  (예: taxi_driver.glb) → 그 NPC 전용
##      <outfit>.glb  (civilian / suit / student / worker / elder / guard / dress) → 옷차림별 공용
##      player.glb    → 플레이어
##  - GLB 안의 AnimationPlayer 에 idle / walk / run / sit 이름의 애니메이션이 있으면 자동으로 재생합니다.
##    없으면 모델은 서 있는 자세로 움직이기만 합니다.
##  - 파일이 없거나 불러오지 못하면 null 을 돌려주고, 호출한 쪽이 기존 절차적 인체 모델을 그대로 씁니다.
## 이 게임에는 GLB 파일이 포함되어 있지 않으므로 이 경로는 현재 실행되지 않습니다(미검증).

const DIR: String = "res://assets/characters/"


## 돌려주는 값: {"root": Node3D, "anim": 애니메이터(update(...) 지원)} 또는 null
static func try_glb(key: String, outfit: String) -> Variant:
	var names: Array = [key, outfit]
	for n in names:
		var path: String = DIR + str(n) + ".glb"
		if n == "" or not ResourceLoader.exists(path):
			continue
		var res = load(path)
		if res == null or not (res is PackedScene):
			continue
		var inst = res.instantiate()
		if inst == null or not (inst is Node3D):
			if inst != null:
				inst.queue_free()
			continue
		var anim = GlbAnimator.new()
		anim.setup(inst)
		return {"root": inst, "anim": anim}
	return null


## GLB 모델용 애니메이터. npc.gd / gfx_manager.gd 가 쓰는 update() 와 같은 인자를 받음
class GlbAnimator:
	extends RefCounted

	var stoop: float = 0.0
	var pose: String = ""
	var _player: AnimationPlayer = null
	var _current: String = ""

	func setup(root: Node) -> void:
		_player = _find_player(root)

	func _find_player(n: Node) -> AnimationPlayer:
		if n is AnimationPlayer:
			return n
		for c in n.get_children():
			var f = _find_player(c)
			if f != null:
				return f
		return null

	func update(_delta: float, speed: float, _on_floor: bool, _vy: float, sitting: bool, _talking: bool, _ybob: float) -> void:
		if _player == null:
			return
		var want: String = "idle"
		if sitting:
			want = "sit"
		elif speed > 2.2:
			want = "run"
		elif speed > 0.2:
			want = "walk"
		if want == _current:
			return
		if _player.has_animation(want):
			_current = want
			_player.play(want)
		elif want != "idle" and _player.has_animation("idle"):
			_current = want
			_player.play("idle")
