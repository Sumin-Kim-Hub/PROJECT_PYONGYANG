extends RefCounted
## 게임 전체 설정값 모음.
## 숫자만 바꿔서 성능과 느낌을 조절할 수 있습니다.
## 다른 스크립트에서는 preload로 불러 사용합니다.

## 목표 프레임. 발열/배터리가 걱정되면 30으로 낮추세요.
const TARGET_FPS: int = 60

## 그림자. 프레임이 낮으면 false로 바꾸세요.
const SHADOWS: bool = true
const SHADOW_DISTANCE: float = 70.0

## 카메라가 보는 최대 거리(m)
const CAMERA_FAR: float = 320.0

## 지도 반 크기(m). 이 밖으로는 나갈 수 없습니다.
const MAP_HALF_SIZE: float = 240.0

## 도시 생성용 난수 시드 (같은 값이면 항상 같은 도시가 만들어집니다)
const RNG_SEED: int = 2026

## 시작 위치 (광장 남쪽)
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 1.0, 34.0)

## 화면 좌상단에 FPS와 좌표 표시
const SHOW_DEBUG: bool = true
