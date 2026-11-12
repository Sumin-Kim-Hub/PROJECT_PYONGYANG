extends Node
## V2.2 소리: 파일 없이 코드로 만든 배경 선율, 방송 신호음, 비상 사이렌.
##  - 선율은 이 게임을 위해 새로 만든 간단한 오음계 행진곡풍 가락이며 실제 곡이 아닙니다.
##  - 소리 파일(.ogg 등)을 쓰지 않으므로 용량이 늘지 않습니다. (Godot 실행 미검증: 소리가 실제로 나는지, 안드로이드에서 끊기지 않는지 확인 필요)

const RATE: float = 11025.0
const BPM_STEP: float = 0.36
## 기준음에서의 반음 거리 (오음계)
const MELODY: Array = [0, 2, 4, 7, 4, 2, 0, -3, 0, 2, 4, 7, 9, 7, 4, 2, 4, 7, 9, 12, 9, 7, 4, 2, 0, 2, 4, 2, 0, -3, -5, -3]
const BASS: Array = [-12, -12, -17, -17, -12, -12, -19, -19]

var hub = null
var enabled: bool = true
var volume: float = 0.10

var _player: AudioStreamPlayer = null
var _pb: AudioStreamGeneratorPlayback = null
var _n: int = 0
var _ph_m: float = 0.0
var _ph_b: float = 0.0
var _ph_c: float = 0.0
var _chime_left: int = 0
var _chime_freq: float = 880.0
var _siren_left: int = 0
var _ph_s: float = 0.0
var _ok: bool = false


func setup(p_hub) -> void:
	hub = p_hub
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.4
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	var pb = _player.get_stream_playback()
	if pb is AudioStreamGeneratorPlayback:
		_pb = pb
		_ok = true
	else:
		push_warning("V2.2: 소리 재생 준비에 실패했습니다. 소리 없이 진행합니다.")


func set_enabled(on: bool) -> void:
	enabled = on


## 방송 신호음 (딩동)
func chime() -> void:
	_chime_left = int(RATE * 0.9)
	_chime_freq = 880.0


## 비상 사이렌 (초)
func siren(seconds: float) -> void:
	_siren_left = int(RATE * seconds)


func _process(_delta: float) -> void:
	if not _ok or _pb == null:
		return
	var frames: int = mini(_pb.get_frames_available(), 900)
	if frames <= 0:
		return
	var vol: float = volume if enabled else 0.0
	if hub != null and hub.player != null and hub.player.global_position.y > 100.0:
		vol *= 0.6
	var step_len: int = int(RATE * BPM_STEP)
	for i in range(frames):
		var s: float = 0.0
		if vol > 0.0:
			var idx: int = _n / step_len
			var pos_in: int = _n % step_len
			var env: float = exp(-3.2 * float(pos_in) / float(step_len))
			var note: int = int(MELODY[idx % MELODY.size()])
			var f: float = 220.0 * pow(2.0, float(note) / 12.0)
			_ph_m += f / RATE
			if _ph_m > 1.0:
				_ph_m -= 1.0
			var tone: float = sin(_ph_m * TAU) * 0.6 + sin(_ph_m * TAU * 2.0) * 0.2
			s += tone * env * vol
			var bnote: int = int(BASS[(idx / 4) % BASS.size()])
			var bf: float = 220.0 * pow(2.0, float(bnote) / 12.0)
			_ph_b += bf / RATE
			if _ph_b > 1.0:
				_ph_b -= 1.0
			s += sin(_ph_b * TAU) * 0.35 * vol * (0.6 + 0.4 * env)
		_n += 1
		if _chime_left > 0:
			var k: float = float(_chime_left) / (RATE * 0.9)
			var cf: float = _chime_freq if k > 0.5 else _chime_freq * 0.75
			_ph_c += cf / RATE
			if _ph_c > 1.0:
				_ph_c -= 1.0
			s += sin(_ph_c * TAU) * 0.25 * k
			_chime_left -= 1
		if _siren_left > 0:
			var sf: float = 620.0 + 340.0 * (0.5 + 0.5 * sin(float(_siren_left) / RATE * TAU * 0.8))
			_ph_s += sf / RATE
			if _ph_s > 1.0:
				_ph_s -= 1.0
			s += (1.0 if _ph_s < 0.5 else -1.0) * 0.07
			_siren_left -= 1
		_pb.push_frame(Vector2(s, s))
	if _n > 1000000000:
		_n = 0
