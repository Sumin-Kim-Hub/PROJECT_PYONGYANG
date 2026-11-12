extends Node3D
## 사람이 아닌 대화 상대 (금고 숫자판, 게시판 등). 허브의 대화창이 NPC 처럼 다룰 수 있게
## 필요한 이름/함수만 갖춘 가짜 NPC 입니다. 화면에는 아무것도 그리지 않습니다. (Godot 실행 미검증)

const InteractableScript = preload("res://scripts/interaction/interactable.gd")

var npc_id: String = ""
var display_name: String = ""
var role: String = ""
var dialogue: Dictionary = {}
var no_talk: bool = false
var is_police: bool = false
var talking: bool = false
var prompt_text: String = ""
var radius: float = 1.8
var hide_flag: String = ""
var requires_flag: String = ""
var button_text: String = "조작"


func _ready() -> void:
	var it = InteractableScript.new()
	it.kind = "talk"
	it.prompt = prompt_text
	it.radius = radius
	it.hide_flag = hide_flag
	it.requires_flag = requires_flag
	it.button_text = button_text
	it.data = {"npc": self}
	it.position = Vector3(0.0, 1.0, 0.0)
	add_child(it)


func begin_talk(_face_point: Vector3) -> void:
	talking = true


func end_talk() -> void:
	talking = false


func scare(_from: Vector3, _seconds: float, _run: bool) -> void:
	pass
