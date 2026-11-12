extends RefCounted
## V2.2 데이터: 정보 조각, 거래 가격, 새 NPC, 방송 문구, 랜덤 이벤트.
## 이 세계의 인물·장소·문서는 모두 가상입니다. 실제 인물이나 단체와 관계없습니다. (Godot 실행 미검증)

## 월드 한계(m). 원래 240 이었던 경계를 이 값으로 넓힙니다.
const MAP_LIMIT: float = 380.0

## 정보 조각: 대화로 얻으면 플래그 intel_<키> 가 켜지고 메시지가 표시됩니다.
const INTEL: Dictionary = {
	"pass": "북쪽 통제구역은 통행증 없이는 검문소를 지날 수 없다고 한다.",
	"market": "서쪽 장마당의 상인 한옥분이 구하기 힘든 물건을 구해 준다고 한다.",
	"manhole": "장마당 뒤 창고 구석 바닥에 오래된 맨홀 덮개가 있다고 한다.",
	"code": "지하 금고의 암호는 세 자리. 폐건물·강변·장마당에 숫자 단서가 흩어져 있다고 한다.",
	"oh": "검문소 앞 보급관 오문철이 배급 물자를 빼돌린다는 소문이 있다.",
	"base": "군사시설 안쪽 문은 특별 통행증이 있어야 한다. 연락장교 류가 열쇠라고 한다.",
	"boat": "강가 낚시꾼 마씨는 믿을 만한 사람에게만 속삭이듯 이야기해 준다고 한다.",
}
## 순서대로 알려 주는 NPC 별 정보
const INFO_BY_NPC: Dictionary = {
	"lee_sunhui": ["pass", "market", "oh"],
	"han_okbun": ["manhole", "code", "market"],
	"cho_boy": ["manhole", "boat"],
	"old_man_jo": ["code", "manhole"],
	"fisher_ma": ["boat", "base", "code"],
	"ration_clerk": ["oh", "pass"],
	"bong_sun": ["pass", "oh"],
	"supply_oh": ["base", "pass"],
	"officer_ryu": ["base", "oh"],
	"mole": ["code", "base"],
}
## 부탁을 들어주면 건네는 것 {"item": 아이템, "won": 돈}
const FAVOR_BY_NPC: Dictionary = {
	"lee_sunhui": {"item": "food_ration"},
	"han_okbun": {"item": "radio_part"},
	"bong_sun": {"won": 25},
	"cho_boy": {"item": "scrap"},
	"fisher_ma": {"item": "gift_tea"},
	"ration_clerk": {"item": "food_ration"},
	"old_man_jo": {"item": "old_stamp"},
}
## 거래: 살 수 있는 물건 {아이템: 가격(원)}
const BUY_PRICES: Dictionary = {"food_ration": 30, "medicine": 60, "gift_sweets": 15, "gift_tea": 18, "radio_part": 55}
## 팔 때 받는 값
const SELL_PRICES: Dictionary = {
	"food_ration": 18, "medicine": 40, "radio_part": 30, "scrap": 6, "old_watch": 140,
	"gift_sweets": 8, "gift_tea": 10, "rare_medal": 220,
}
## 거래를 해 주는 NPC (장사하는 사람)
const VENDORS: Array = ["han_okbun", "mole", "market_b", "market_c", "shop_owner", "station_clerk"]

## 통행증 정보
const PASS_NAMES: Dictionary = {
	"pass_general": "일반 통행증", "pass_special": "특별 통행증",
	"pass_temp": "임시 통행증", "pass_forged": "위조 통행증",
}
## 임시 통행증 유효 시간(게임 분)
const TEMP_PASS_MINUTES: float = 1440.0

## 방송 문구 (도시 안내 방송 / 라디오). 모두 이 게임 속 가상의 방송입니다.
const PA_LINES: Array = [
	"[도시 안내 방송] 시민 여러분, 통제구역 접근 시에는 통행증을 미리 준비해 주십시오.",
	"[도시 안내 방송] 오늘의 배급은 오후 세 시부터 배급소에서 시작됩니다.",
	"[도시 안내 방송] 야간 통행 시간이 가까워 옵니다. 귀가를 서둘러 주십시오.",
	"[라디오] 이 방송은 가상의 도시 방송입니다. 오늘의 날씨와 생산 소식을 전해 드립니다.",
	"[라디오] 다 같이 힘을 모아 도시를 가꿉시다. 오늘도 수고하셨습니다.",
	"[도시 안내 방송] 분실물을 주운 시민은 가까운 경비 초소에 맡겨 주십시오.",
	"[도시 안내 방송] 검문소에서는 통행증의 유효 기간을 반드시 확인합니다.",
]

## 랜덤 이벤트 이름
const EVENTS: Array = ["wallet", "inspect", "whisper", "ration", "patrol_alert", "radio_tip"]


static func item_label(id: String) -> String:
	if PASS_NAMES.has(id):
		return str(PASS_NAMES[id])
	return id
