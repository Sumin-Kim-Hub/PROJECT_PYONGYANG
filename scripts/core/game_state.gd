extends Node
## 게임 진행 상태: 인벤토리, 플래그, 퀘스트, 발견한 장소.
## 저장 파일에 들어가는 내용은 to_dict()/from_dict() 로 변환합니다.

const ItemData = preload("res://scripts/data/item_data.gd")
const QuestData = preload("res://scripts/data/quest_data.gd")

signal changed

## 선택: 시계 (조건 검사에서 밤/낮 확인용). hub 가 연결해 줌.
var clock = null

var inventory: Dictionary = {}
var flags: Dictionary = {}
## id -> {"state": "active" | "done", "step": int}
var quests: Dictionary = {}
## 이번 실행에서 등록된 장소 id -> {"name": String, "pos": Vector3}
var pois: Dictionary = {}
## 발견한 장소 id -> true (저장됨)
var discovered: Dictionary = {}


# ---------------------------------------------------------------- 아이템

func has_item(id: String) -> bool:
	return int(inventory.get(id, 0)) > 0


func add_item(id: String, count: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count
	changed.emit()


func remove_item(id: String, count: int = 1) -> void:
	var left: int = int(inventory.get(id, 0)) - count
	if left <= 0:
		inventory.erase(id)
	else:
		inventory[id] = left
	changed.emit()


# ---------------------------------------------------------------- 플래그

func get_flag(key: String) -> bool:
	return bool(flags.get(key, false))


func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value
	changed.emit()


# ---------------------------------------------------------------- 퀘스트

func quest_state(id: String) -> String:
	if quests.has(id):
		return str(quests[id].get("state", "inactive"))
	return "inactive"


func quest_step(id: String) -> int:
	if quests.has(id):
		return int(quests[id].get("step", 0))
	return -1


func start_quest(id: String) -> bool:
	if quests.has(id) or not QuestData.QUESTS.has(id):
		return false
	quests[id] = {"state": "active", "step": 0}
	changed.emit()
	return true


## 앞 단계로만 진행. 진행됐으면 true
func set_quest_step(id: String, step: int) -> bool:
	if quest_state(id) != "active":
		return false
	if step <= quest_step(id):
		return false
	quests[id]["step"] = step
	changed.emit()
	return true


func complete_quest(id: String) -> bool:
	if quest_state(id) != "active":
		return false
	quests[id]["state"] = "done"
	changed.emit()
	return true


## V2: 임무 실패. 실패한 임무는 "실패한 임무" 목록에 남고 다시 시작할 수 없다
func fail_quest(id: String) -> bool:
	if quest_state(id) != "active":
		return false
	quests[id]["state"] = "failed"
	changed.emit()
	return true


func failed_quest_ids() -> Array:
	var out: Array = []
	for id in quests.keys():
		if str(quests[id].get("state", "")) == "failed":
			out.append(str(id))
	return out


func quest_title(id: String) -> String:
	if QuestData.QUESTS.has(id):
		return str(QuestData.QUESTS[id].get("title", id))
	return id


func quest_step_text(id: String) -> String:
	if not QuestData.QUESTS.has(id):
		return ""
	var steps: Array = QuestData.QUESTS[id].get("steps", [])
	var i: int = quest_step(id)
	if i >= 0 and i < steps.size():
		return str(steps[i])
	return ""


func active_quest_ids() -> Array:
	var out: Array = []
	for id in quests.keys():
		if str(quests[id].get("state", "")) == "active":
			out.append(str(id))
	return out


func done_quest_ids() -> Array:
	var out: Array = []
	for id in quests.keys():
		if str(quests[id].get("state", "")) == "done":
			out.append(str(id))
	return out


# ---------------------------------------------------------------- 조건 검사

## cond: Dictionary 또는 Dictionary 배열(모두 만족해야 함). null/빈 값이면 true.
## 지원 키: flag, not_flag, item, not_item, item_min([id, 개수]), quest(+state, step, min_step), night
func check(cond) -> bool:
	if cond == null:
		return true
	if cond is Array:
		for c in cond:
			if not check(c):
				return false
		return true
	if not (cond is Dictionary):
		return true
	if cond.has("flag") and not get_flag(str(cond["flag"])):
		return false
	if cond.has("not_flag") and get_flag(str(cond["not_flag"])):
		return false
	if cond.has("item") and not has_item(str(cond["item"])):
		return false
	if cond.has("not_item") and has_item(str(cond["not_item"])):
		return false
	if cond.has("item_min"):
		var im = cond["item_min"]
		if im is Array and im.size() >= 2 and int(inventory.get(str(im[0]), 0)) < int(im[1]):
			return false
	if cond.has("quest"):
		var qid: String = str(cond["quest"])
		var want: String = str(cond.get("state", "active"))
		if quest_state(qid) != want:
			return false
		if cond.has("step") and quest_step(qid) != int(cond["step"]):
			return false
		if cond.has("min_step") and quest_step(qid) < int(cond["min_step"]):
			return false
	if cond.has("night") and clock != null:
		if bool(cond["night"]) != clock.is_night():
			return false
	return true


# ---------------------------------------------------------------- 저장 / 불러오기

func to_dict() -> Dictionary:
	return {
		"inventory": inventory.duplicate(true),
		"flags": flags.duplicate(true),
		"quests": quests.duplicate(true),
		"discovered": discovered.duplicate(true),
	}


## 저장 파일이 깨져 있어도 오류로 멈추지 않도록, 각 항목의 형식을 확인하며 읽음
func from_dict(d: Dictionary) -> void:
	inventory = {}
	var inv = d.get("inventory", {})
	if inv is Dictionary:
		for k in inv.keys():
			var n: int = int(inv[k])
			if n > 0:
				inventory[str(k)] = n
	flags = {}
	var fl = d.get("flags", {})
	if fl is Dictionary:
		for k in fl.keys():
			flags[str(k)] = bool(fl[k])
	quests = {}
	var qs = d.get("quests", {})
	if qs is Dictionary:
		for k in qs.keys():
			var q = qs[k]
			if q is Dictionary and QuestData.QUESTS.has(str(k)):
				quests[str(k)] = {"state": str(q.get("state", "active")), "step": int(q.get("step", 0))}
	discovered = {}
	var ds = d.get("discovered", {})
	if ds is Dictionary:
		for k in ds.keys():
			discovered[str(k)] = true
	changed.emit()
