extends Node
## 한글 글꼴을 게임 전체의 기본 글꼴로 지정하는 자동 로드(autoload).
##
## 왜 project.godot 의 gui/theme/custom(_font) 을 쓰지 않는가:
##   그 설정은 엔진이 켜지는 즉시(리소스 가져오기 전에) 글꼴을 읽는다. 저장소를 막 받은 상태(.godot/ 없음)에서는
##   .ttf 가 아직 가져오기 전이라 "No loader found for resource" 오류가 나고, godot-check 1단계가 실패한다.
##   그래서 가져오기가 끝난 뒤 실행되는 이 자동 로드에서 Theme 을 읽어 적용한다.
##
## 적용 범위:
##   - ThemeDB.fallback_font      : touch_controls 등 직접 그리는 UI, 각 HUD 의 대체 글꼴
##   - 엔진 기본 Theme 의 default_font : Label·Button 등 Control, 그리고 Label3D(건물 '동' 번호판, 실내 표지)

const THEME_PATH: String = "res://assets/theme/default_korean_theme.tres"
const FONT_PATH: String = "res://assets/fonts/NanumGothic.ttf"
const HANGUL_HAN: int = 0xD55C  # '한'

var korean_font: Font = null


func _enter_tree() -> void:
	korean_font = _load_font()
	if korean_font == null:
		push_error("[KoreanFont] 한글 글꼴을 불러오지 못함 — 한글이 □ 로 보일 수 있음: %s" % FONT_PATH)
		return
	ThemeDB.fallback_font = korean_font
	var default_theme: Theme = ThemeDB.get_default_theme()
	if default_theme != null:
		default_theme.default_font = korean_font
	print("[KoreanFont] 한글 글꼴 적용: %s (한글 글리프 %s)" % [FONT_PATH, str(korean_font.has_char(HANGUL_HAN))])


func _load_font() -> Font:
	# 1) Theme 리소스 (ext_resource 로 NanumGothic.ttf 를 참조)
	if ResourceLoader.exists(THEME_PATH):
		var th = load(THEME_PATH)
		if th is Theme and th.default_font != null and th.default_font.has_char(HANGUL_HAN):
			return th.default_font
		push_warning("[KoreanFont] Theme 에서 글꼴을 얻지 못함, 글꼴 파일을 직접 읽음: %s" % THEME_PATH)
	# 2) 글꼴 파일 직접
	if ResourceLoader.exists(FONT_PATH):
		var f = load(FONT_PATH)
		if f is Font and f.has_char(HANGUL_HAN):
			return f
	return null
