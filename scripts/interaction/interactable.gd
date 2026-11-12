extends Node3D
## 상호작용 지점 표식. 만들어지면 "interactable" 그룹에 등록되고,
## InteractionSystem(허브)이 플레이어가 가까이 갔을 때 안내를 띄웁니다.
##   kind: "talk"(대화) / "enter"(입장) / "exit"(나가기) / "portal"(이동: 엘리베이터 등) / "sit"(앉기)
##         "door"(문 열기/닫기) / "examine"(살펴보기) / "pickup"(줍기)
##   data: 종류별 추가 정보
##     talk    {"npc": NPC}
##     enter/exit/portal {"dest": Vector3, "dest_yaw": float, "requires": 조건, "locked_text": String,
##                        "effects": [...], "location": String, "interior": bool}
##     sit     {"pos", "yaw", "stand_pos", "outdoor", "occupied_by", "effects"}
##     door    {"door": Door 노드}
##     examine {"text": String, "effects": [...], "once_flag": String}
##     pickup  {"item": id, "text": String, "flag": 줍기 완료 표시}
##   requires_flag / hide_flag : 게임 플래그에 따라 보이거나 숨겨짐

var kind: String = ""
var prompt: String = ""
var radius: float = 2.0
var data: Dictionary = {}
var enabled: bool = true
## 비어 있지 않으면 kind 기본 버튼 이름 대신 사용
var button_text: String = ""
var requires_flag: String = ""
var hide_flag: String = ""


func _ready() -> void:
	add_to_group("interactable")


func button_label() -> String:
	if button_text != "":
		return button_text
	match kind:
		"talk":
			return "대화"
		"enter":
			return "입장"
		"exit":
			return "나가기"
		"portal":
			return "이동"
		"sit":
			return "앉기"
		"door":
			return "문"
		"examine":
			return "살펴보기"
		"pickup":
			return "줍기"
	return "확인"


## 지금 상호작용 가능한 상태인지 (game: GameState)
func available(game) -> bool:
	if not enabled:
		return false
	if kind == "sit" and data.get("occupied_by") != null:
		return false
	if game != null:
		if requires_flag != "" and not game.get_flag(requires_flag):
			return false
		if hide_flag != "" and game.get_flag(hide_flag):
			return false
	return true
