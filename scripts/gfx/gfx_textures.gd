extends RefCounted
## 코드로 만드는 텍스처 모음 (외부 이미지 파일을 쓰지 않으므로 저작권 문제가 없습니다).
## 느린 per-pixel 반복을 피하려고 Image.fill_rect / blend_rect / resize 같은 엔진 내장 함수를 주로 씁니다.
## 모든 함수는 결과를 캐시하므로 두 번째 호출부터는 즉시 돌려줍니다.

static var _cache: Dictionary = {}

const FACADE_PALETTES: Array = [
	Color(0.86, 0.84, 0.76),
	Color(0.74, 0.80, 0.85),
	Color(0.89, 0.79, 0.73),
	Color(0.80, 0.86, 0.78),
	Color(0.68, 0.44, 0.36),
	Color(0.66, 0.67, 0.68),
]


# ---------------------------------------------------------------- 공통 도우미

static func _h(x: int, y: int, s: int) -> float:
	var n: int = (x * 374761393 + y * 668265263 + s * 1274126177) & 0x7FFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


static func _shade(c: Color, t: float) -> Color:
	if t >= 0.0:
		return c.lightened(t)
	return c.darkened(-t)


static func _finish(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## 흑백 잡음(투명도로 세기 조절). 다른 이미지 위에 blend_rect 로 얹어서 쓴다.
static func _grain(size: int, seed_v: int, strength: float) -> Image:
	var img = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var v: float = _h(x, y, seed_v)
			var c: Color = Color(1, 1, 1, 1) if v > 0.5 else Color(0, 0, 0, 1)
			c.a = absf(v - 0.5) * 2.0 * strength
			img.set_pixel(x, y, c)
	return img


static func _tile_blend(dst: Image, src: Image) -> void:
	var sw: int = src.get_width()
	var sh: int = src.get_height()
	var rect = Rect2i(0, 0, sw, sh)
	var y: int = 0
	while y < dst.get_height():
		var x: int = 0
		while x < dst.get_width():
			dst.blend_rect(src, rect, Vector2i(x, y))
			x += sw
		y += sh


## 이음매 없이 이어 붙는 부드러운 잡음. 결과 크기 = grid * up
static func _wrapped_noise(grid: int, up: int, seed_v: int) -> Image:
	var g: int = grid + 4
	var small = Image.create_empty(g, g, false, Image.FORMAT_RGBA8)
	for y in range(g):
		for x in range(g):
			var v: float = _h(posmod(x - 2, grid), posmod(y - 2, grid), seed_v)
			small.set_pixel(x, y, Color(v, v, v, 1.0))
	small.resize(g * up, g * up, Image.INTERPOLATE_BILINEAR)
	return small.get_region(Rect2i(2 * up, 2 * up, grid * up, grid * up))


# ---------------------------------------------------------------- 건물 외벽 (4x4 칸 아틀라스)
## mode 0 = 색, 1 = 거칠기(유리는 반들반들), 2 = 야간 불빛
## 한 칸 = 가로 4m x 세로 한 층. 창문은 칸 정중앙에 있고, 칸 무늬(커튼/불빛)는 variant 와 무관해서
## 세 가지 텍스처가 서로 정확히 겹칩니다.

static func facade(variant: int) -> ImageTexture:
	var key: String = "facade_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var wall: Color = FACADE_PALETTES[variant % FACADE_PALETTES.size()]
	var tex: ImageTexture = _finish(_facade_image(wall, variant == 4, 0))
	_cache[key] = tex
	return tex


static func facade_rough() -> ImageTexture:
	if _cache.has("facade_rough"):
		return _cache["facade_rough"]
	var tex: ImageTexture = _finish(_facade_image(Color(0.9, 0.9, 0.9), false, 1))
	_cache["facade_rough"] = tex
	return tex


static func facade_emission() -> ImageTexture:
	if _cache.has("facade_emit"):
		return _cache["facade_emit"]
	var tex: ImageTexture = _finish(_facade_image(Color(0, 0, 0), false, 2))
	_cache["facade_emit"] = tex
	return tex


static func _facade_image(wall: Color, brick: bool, mode: int) -> Image:
	var n: int = 256
	var cell: int = 64
	var img = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var base: Color = wall
	if mode == 1:
		base = Color(0.92, 0.92, 0.92, 1.0)
	elif mode == 2:
		base = Color(0.0, 0.0, 0.0, 1.0)
	img.fill(base)

	var seam: Color = _shade(wall, -0.12)
	var seam_v: Color = _shade(wall, -0.07)
	var frame_c: Color = _shade(wall, 0.55)
	var sill_c: Color = _shade(wall, 0.22)
	var under_c: Color = _shade(wall, -0.16)
	var lintel_c: Color = _shade(wall, -0.10)
	var streak_c: Color = _shade(wall, -0.08)

	for cy in range(4):
		for cx in range(4):
			var ox: int = cx * cell
			var oy: int = cy * cell
			var r: float = _h(cx, cy, 7)
			var r2: float = _h(cx, cy, 31)
			var r3: float = _h(cx, cy, 53)

			if mode == 0:
				img.fill_rect(Rect2i(ox, oy, cell, cell), _shade(wall, (r2 - 0.5) * 0.07))
				if brick:
					var j: int = 0
					while j < cell / 4:
						img.fill_rect(Rect2i(ox, oy + j * 4 + 3, cell, 1), seam)
						var b: int = 0
						while b < cell / 8:
							img.fill_rect(Rect2i(ox + b * 8 + (j % 2) * 4, oy + j * 4, 1, 3), seam)
							b += 1
						j += 1
				else:
					img.fill_rect(Rect2i(ox, oy + cell - 2, cell, 2), seam)
					img.fill_rect(Rect2i(ox, oy, 1, cell), seam_v)

			var wx: int = ox + 12
			var wy: int = oy + 14
			var ww: int = 40
			var wh: int = 36
			var gx: int = wx + 2
			var gy: int = wy + 2
			var gw: int = ww - 4
			var gh: int = wh - 4
			var curtain: bool = r < 0.22
			var lit: bool = r2 < 0.30

			if mode == 0:
				img.fill_rect(Rect2i(wx - 2, wy - 3, ww + 4, 3), lintel_c)
				img.fill_rect(Rect2i(wx - 1, wy - 1, ww + 2, wh + 2), frame_c)
				# 유리: 위쪽은 하늘이 비쳐 밝고 아래쪽은 어두움
				img.fill_rect(Rect2i(gx, gy, gw, gh), Color(0.10, 0.15, 0.22))
				img.fill_rect(Rect2i(gx, gy + gh / 3, gw, gh / 3), Color(0.16, 0.24, 0.33))
				img.fill_rect(Rect2i(gx, gy, gw, gh / 3), Color(0.32, 0.44, 0.58))
				if curtain:
					var cc: Color = Color(0.70 + 0.2 * r3, 0.55 + 0.2 * r2, 0.45 + 0.1 * r, 1.0)
					var cw: int = gw / 2 - 1
					if r3 < 0.5:
						img.fill_rect(Rect2i(gx, gy, cw, gh), cc)
					else:
						img.fill_rect(Rect2i(gx + gw - cw, gy, cw, gh), cc)
				img.fill_rect(Rect2i(wx + ww / 2 - 1, gy, 2, gh), frame_c)
				img.fill_rect(Rect2i(gx, wy + wh / 3, gw, 2), frame_c)
				img.fill_rect(Rect2i(wx - 3, wy + wh + 1, ww + 6, 3), sill_c)
				img.fill_rect(Rect2i(wx - 2, wy + wh + 4, ww + 4, 2), under_c)
				# 빗물 얼룩
				img.fill_rect(Rect2i(wx + 3, wy + wh + 6, 3, 2 + int(r3 * 6.0)), streak_c)
				img.fill_rect(Rect2i(wx + ww - 7, wy + wh + 6, 2, 2 + int(r * 6.0)), streak_c)
			elif mode == 1:
				img.fill_rect(Rect2i(wx - 1, wy - 1, ww + 2, wh + 2), Color(0.55, 0.55, 0.55))
				var gl: float = 0.10
				if curtain:
					gl = 0.5
				img.fill_rect(Rect2i(gx, gy, gw, gh), Color(gl, gl, gl, 1.0))
				img.fill_rect(Rect2i(wx + ww / 2 - 1, gy, 2, gh), Color(0.55, 0.55, 0.55))
				img.fill_rect(Rect2i(gx, wy + wh / 3, gw, 2), Color(0.55, 0.55, 0.55))
			else:
				if lit and not curtain:
					var warm: Color = Color(1.0, 0.80 + 0.12 * r3, 0.50 + 0.25 * r)
					img.fill_rect(Rect2i(gx, gy, gw, gh), warm)
					img.fill_rect(Rect2i(wx + ww / 2 - 1, gy, 2, gh), Color(0, 0, 0))
					img.fill_rect(Rect2i(gx, wy + wh / 3, gw, 2), Color(0, 0, 0))
				elif lit and curtain:
					var warm2: Color = Color(0.9, 0.6, 0.35)
					img.fill_rect(Rect2i(gx, gy, gw, gh), warm2)

	if mode == 0:
		_tile_blend(img, _grain(64, 5, 0.10))
	return img


# ---------------------------------------------------------------- 도로, 인도, 광장, 잔디, 지붕

static func asphalt() -> ImageTexture:
	if _cache.has("asphalt"):
		return _cache["asphalt"]
	var img = Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.19, 0.19, 0.20))
	_tile_blend(img, _grain(128, 11, 0.38))
	# 보수한 자국, 금
	for i in range(7):
		var x: int = int(_h(i, 1, 77) * 220.0)
		var y: int = int(_h(i, 2, 77) * 220.0)
		var len_px: int = 20 + int(_h(i, 3, 77) * 60.0)
		if i % 2 == 0:
			img.fill_rect(Rect2i(x, y, len_px, 1), Color(0.10, 0.10, 0.11))
		else:
			img.fill_rect(Rect2i(x, y, 1, len_px), Color(0.10, 0.10, 0.11))
	img.fill_rect(Rect2i(150, 40, 70, 46), Color(0.16, 0.16, 0.17))
	_tile_blend(img, _grain(64, 12, 0.12))
	var tex: ImageTexture = _finish(img)
	_cache["asphalt"] = tex
	return tex


static func sidewalk() -> ImageTexture:
	if _cache.has("sidewalk"):
		return _cache["sidewalk"]
	var img = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.58, 0.58, 0.56))
	for ty in range(4):
		for tx in range(4):
			var t: float = (_h(tx, ty, 21) - 0.5) * 0.10
			img.fill_rect(Rect2i(tx * 32, ty * 32, 32, 32), _shade(Color(0.60, 0.60, 0.58), t))
			img.fill_rect(Rect2i(tx * 32, ty * 32, 32, 2), Color(0.38, 0.38, 0.37))
			img.fill_rect(Rect2i(tx * 32, ty * 32, 2, 32), Color(0.38, 0.38, 0.37))
	_tile_blend(img, _grain(64, 13, 0.22))
	var tex: ImageTexture = _finish(img)
	_cache["sidewalk"] = tex
	return tex


static func plaza_stone() -> ImageTexture:
	if _cache.has("plaza"):
		return _cache["plaza"]
	var img = Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.72, 0.71, 0.69))
	for ty in range(2):
		for tx in range(2):
			var t: float = (_h(tx, ty, 41) - 0.5) * 0.10
			img.fill_rect(Rect2i(tx * 128, ty * 128, 128, 128), _shade(Color(0.72, 0.71, 0.68), t))
			img.fill_rect(Rect2i(tx * 128, ty * 128, 128, 2), Color(0.48, 0.47, 0.45))
			img.fill_rect(Rect2i(tx * 128, ty * 128, 2, 128), Color(0.48, 0.47, 0.45))
	_tile_blend(img, _grain(128, 14, 0.18))
	var tex: ImageTexture = _finish(img)
	_cache["plaza"] = tex
	return tex


static func grass() -> ImageTexture:
	if _cache.has("grass"):
		return _cache["grass"]
	var img: Image = _wrapped_noise(8, 32, 3)
	var out = Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(0, 256, 2):
			var v: float = img.get_pixel(x, y).r
			var c = Color(0.22 + 0.12 * v, 0.34 + 0.14 * v, 0.16 + 0.07 * v, 1.0)
			out.set_pixel(x, y, c)
			out.set_pixel(x + 1, y, c)
	_tile_blend(out, _grain(64, 15, 0.45))
	var tex: ImageTexture = _finish(out)
	_cache["grass"] = tex
	return tex


static func roof() -> ImageTexture:
	if _cache.has("roof"):
		return _cache["roof"]
	var img = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.30, 0.30, 0.31))
	_tile_blend(img, _grain(64, 16, 0.5))
	var tex: ImageTexture = _finish(img)
	_cache["roof"] = tex
	return tex


static func foliage() -> ImageTexture:
	if _cache.has("foliage"):
		return _cache["foliage"]
	var noise: Image = _wrapped_noise(8, 16, 9)
	var out = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var v: float = noise.get_pixel(x, y).r
			var f: float = _h(x, y, 17)
			var k: float = v * 0.7 + f * 0.3
			out.set_pixel(x, y, Color(0.12 + 0.18 * k, 0.28 + 0.24 * k, 0.10 + 0.08 * k, 1.0))
	var tex: ImageTexture = _finish(out)
	_cache["foliage"] = tex
	return tex


static func water() -> ImageTexture:
	if _cache.has("water"):
		return _cache["water"]
	var noise: Image = _wrapped_noise(8, 16, 19)
	var out = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var v: float = noise.get_pixel(x, y).r
			out.set_pixel(x, y, Color(0.08 + 0.10 * v, 0.22 + 0.16 * v, 0.28 + 0.14 * v, 1.0))
	var tex: ImageTexture = _finish(out)
	_cache["water"] = tex
	return tex


## 구름: 이음매 없이 반복되는 흰 구름(투명도 포함)
static func cloud() -> ImageTexture:
	if _cache.has("cloud"):
		return _cache["cloud"]
	var a: Image = _wrapped_noise(8, 16, 23)
	var b: Image = _wrapped_noise(16, 8, 29)
	var out = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var v: float = a.get_pixel(x, y).r * 0.62 + b.get_pixel(x, y).r * 0.38
			var al: float = smoothstep(0.50, 0.78, v) * 0.85
			var shade: float = 1.0 - 0.18 * smoothstep(0.55, 0.95, v)
			out.set_pixel(x, y, Color(shade, shade, shade * 1.02, al))
	var tex: ImageTexture = _finish(out)
	_cache["cloud"] = tex
	return tex
