extends RefCounted
## Viewport PNG capture: RGBA when Transparent, composite-on-white helpers.
## File → Export Image and automation screenshot share this path.

const SHOP_BG := Color(0.16, 0.17, 0.20, 1.0)
const CHARCOAL_MAX := 8.0 / 255.0


static func shop_background() -> Color:
	return SHOP_BG


static func ensure_rgba(img: Image) -> Image:
	if img == null:
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func composite_on_white(img: Image) -> Image:
	if img == null:
		return null
	var src := ensure_rgba(img)
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	out.fill(Color.WHITE)
	for y in h:
		for x in w:
			var p := src.get_pixel(x, y)
			out.set_pixel(x, y, Color.WHITE.lerp(Color(p.r, p.g, p.b, 1.0), p.a))
	return out


static func png_color_type(path: String) -> int:
	if path == "" or not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var buf := f.get_buffer(26)
	if buf.size() < 26 or buf[0] != 0x89 or buf[1] != 0x50:
		return -1
	# PNG is big-endian; colour type is IHDR byte 9 (file offset 25).
	return int(buf[25])


static func has_real_alpha_channel(path: String) -> bool:
	# PNG colour type 6 = truecolor + alpha.
	return png_color_type(path) == 6


static func is_charcoal(c: Color, tol: float = CHARCOAL_MAX) -> bool:
	return absf(c.r - SHOP_BG.r) <= tol \
			and absf(c.g - SHOP_BG.g) <= tol \
			and absf(c.b - SHOP_BG.b) <= tol


static func has_transparent_pixel(img: Image) -> bool:
	if img == null:
		return false
	var src := ensure_rgba(img)
	var w := src.get_width()
	var h := src.get_height()
	var samples: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(w - 1, 0),
		Vector2i(0, h - 1), Vector2i(w - 1, h - 1),
		Vector2i(w / 2, 0), Vector2i(w / 2, h - 1),
		Vector2i(0, h / 2), Vector2i(w - 1, h / 2),
	]
	for s in samples:
		if src.get_pixel(s.x, s.y).a < 0.5:
			return true
	return false


static func composites_without_charcoal(img: Image) -> bool:
	var plate := composite_on_white(img)
	if plate == null:
		return false
	var w := plate.get_width()
	var h := plate.get_height()
	if w < 2 or h < 2:
		return false
	var samples: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(w - 1, 0),
		Vector2i(0, h - 1), Vector2i(w - 1, h - 1),
		Vector2i(w / 2, 0), Vector2i(w / 2, h - 1),
		Vector2i(0, h / 2), Vector2i(w - 1, h / 2),
	]
	for s in samples:
		if is_charcoal(plate.get_pixel(s.x, s.y)):
			return false
	return true


## Opaque grey “part” on a fully transparent plate — dummy-renderer stand-in.
static func make_alpha_fixture(width := 160, height := 90) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x0 := width / 4
	var y0 := height / 4
	var x1 := (width * 3) / 4
	var y1 := (height * 3) / 4
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, Color(0.66, 0.67, 0.70, 1.0))
	return img
