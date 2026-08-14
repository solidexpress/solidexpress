class_name UIIcons
## Runtime-generated icon set: one 24x24 stroke-style SVG glyph per action,
## rasterized once per (name, size) and cached. This is the app's visual
## language — anything clickable carries an icon + tooltip; plain text is
## informational only. run_icon_tests.gd enforces the rule.

const STROKE := "#dde2ea"
const ACCENT := "#6ab0f3"

## name -> inner SVG (24x24 viewBox). Default stroke/fill applied by _wrap;
## elements may override (e.g. fill='...' for solid dots).
const GLYPHS := {
	# --- primitives ---
	"box": "<path d='M5 8.5 12 5l7 3.5v7L12 19l-7-3.5z'/><path d='M5 8.5 12 12l7-3.5M12 12v7'/>",
	"cylinder": "<ellipse cx='12' cy='6.5' rx='6' ry='2.5'/><path d='M6 6.5v11M18 6.5v11'/><path d='M6 17.5a6 2.5 0 0 0 12 0'/>",
	"sphere": "<circle cx='12' cy='12' r='7'/><ellipse cx='12' cy='12' rx='7' ry='2.6'/>",
	"cone": "<path d='M12 5 6 17.5M12 5l6 12.5'/><ellipse cx='12' cy='17.5' rx='6' ry='2.2'/>",
	"torus": "<ellipse cx='12' cy='12' rx='8' ry='4.5'/><ellipse cx='12' cy='12' rx='3.2' ry='1.6'/>",
	# --- sketch tools ---
	"sketch": "<path d='M5 19l1-4L16.5 4.5l3 3L9 18z'/><path d='M14.5 6.5l3 3'/>",
	"select": "<path d='M7 4l11 8-4.5 1L16 18l-2.5 1-2.5-5-3.5 3.5z'/>",
	"line": "<path d='M5 19 19 5'/>",
	"rect": "<rect x='5' y='7' width='14' height='10'/>",
	"circle": "<circle cx='12' cy='12' r='7'/><circle cx='12' cy='12' r='1.2' fill='%STROKE%'/>",
	"arc": "<path d='M5 18a11 11 0 0 1 14 0'/><circle cx='5' cy='18' r='1.5' fill='%STROKE%'/><circle cx='19' cy='18' r='1.5' fill='%STROKE%'/>",
	"polygon": "<path d='M12 4.5 18.5 9l-2.5 8h-8L5.5 9z'/>",
	"trim": "<path d='M5 5l14 14'/><path d='M19 5 5 19' stroke-dasharray='2.4 2.4'/><circle cx='12' cy='12' r='2'/>",
	"extend": "<path d='M4 12h9'/><path d='M13 12h6' stroke-dasharray='2.4 2.4'/><path d='M16.5 9.5 19 12l-2.5 2.5'/>",
	"spline": "<path d='M4 16c3-10 5 2 8-4s5 8 8-2'/>",
	"point": "<circle cx='12' cy='12' r='2.5' fill='%STROKE%'/><circle cx='12' cy='12' r='6'/>",
	"convert": "<path d='M7 7h10v10'/><path d='M7 17 17 7'/><path d='M5 12h4M15 12h4'/>",
	"pattern": "<rect x='4' y='4' width='6' height='6'/><rect x='14' y='4' width='6' height='6'/><rect x='4' y='14' width='6' height='6'/>",
	# --- constraints ---
	"horizontal": "<path d='M5 12h14'/><circle cx='5' cy='12' r='1.6' fill='%STROKE%'/><circle cx='19' cy='12' r='1.6' fill='%STROKE%'/>",
	"vertical": "<path d='M12 5v14'/><circle cx='12' cy='5' r='1.6' fill='%STROKE%'/><circle cx='12' cy='19' r='1.6' fill='%STROKE%'/>",
	"parallel": "<path d='M8 5 5 19M19 5l-3 14'/>",
	"perpendicular": "<path d='M5 19h14M12 19V5'/>",
	"equal": "<path d='M6 9.5h12M6 14.5h12'/>",
	"coincident": "<circle cx='12' cy='12' r='6.5'/><circle cx='12' cy='12' r='2' fill='%STROKE%'/>",
	"dimension": "<path d='M5 8v12M19 8v12M5 14h14'/><path d='M8 12l-3 2 3 2M16 12l3 2-3 2'/>",
	# --- feature ops ---
	"extrude": "<rect x='6' y='14' width='12' height='5'/><path d='M12 12V4.5'/><path d='M8.5 8 12 4.5 15.5 8'/>",
	"revolve": "<path d='M12 4v16' stroke-dasharray='2.4 2.4'/><path d='M12 12a6 4.5 0 1 0 6-4.4'/><path d='M18.5 4.5 18 7.7l-3-1.2z' fill='%STROKE%'/>",
	"fillet": "<path d='M5 19V12A7 7 0 0 1 12 5h7'/><path d='M5 5h3M5 5v3' stroke-dasharray='2 2'/>",
	"chamfer": "<path d='M5 19v-8l6-6h8'/><path d='M5 5h3M5 5v3' stroke-dasharray='2 2'/>",
	"linear_pattern": "<rect x='4' y='9' width='4.4' height='6'/><rect x='10' y='9' width='4.4' height='6' stroke-dasharray='2 2'/><rect x='16' y='9' width='4.4' height='6' stroke-dasharray='2 2'/>",
	"circular_pattern": "<circle cx='12' cy='12' r='1.4' fill='%STROKE%'/><circle cx='12' cy='5.5' r='2.4'/><circle cx='17.6' cy='15.2' r='2.4' stroke-dasharray='2 2'/><circle cx='6.4' cy='15.2' r='2.4' stroke-dasharray='2 2'/>",
	"mirror": "<path d='M12 4v16' stroke-dasharray='2.4 2.4'/><path d='M9 8 5 12l4 4zM15 8l4 4-4 4'/>",
	"instance": "<rect x='4.5' y='4.5' width='9' height='9'/><rect x='10.5' y='10.5' width='9' height='9' stroke-dasharray='2 2'/>",
	"offset": "<rect x='8.5' y='8.5' width='11' height='11'/><rect x='4.5' y='4.5' width='11' height='11' stroke-dasharray='2 2'/>",
	"fuse": "<circle cx='9.5' cy='12' r='5.5'/><circle cx='14.5' cy='12' r='5.5'/>",
	"cut": "<circle cx='9.5' cy='12' r='5.5'/><circle cx='14.5' cy='12' r='5.5' stroke-dasharray='2 2'/>",
	"common": "<circle cx='9.5' cy='12' r='5.5' stroke-dasharray='2 2'/><circle cx='14.5' cy='12' r='5.5' stroke-dasharray='2 2'/><path d='M12 7.1a5.5 5.5 0 0 1 0 9.8 5.5 5.5 0 0 1 0-9.8z' fill='%STROKE%' fill-opacity='0.55'/>",
	"measure": "<rect x='3.5' y='9' width='17' height='6' transform='rotate(-25 12 12)'/><path d='M8 13.2l1-2.2M11.5 11.6l1-2.2M15 10l1-2.2' transform='rotate(0 0 0)'/>",
	"mass": "<path d='M7 9h10l2.5 10h-15z'/><circle cx='12' cy='6.5' r='2.2'/>",
	"shell": "<path d='M4.5 8.5v11h15v-11'/><path d='M7.5 8.5v8h9v-8' stroke-dasharray='2 2'/>",
	"draft": "<path d='M6 19V5h6'/><path d='M6 19h12L15 5h-3' stroke-dasharray='2 2'/>",
	"hole": "<rect x='4' y='10' width='16' height='9'/><path d='M10 10v5h4v-5' stroke-dasharray='2 2'/><path d='M12 3.5V8M10.2 6.2 12 8l1.8-1.8'/>",
	"area": "<rect x='5' y='5' width='14' height='14'/><path d='M5 19 19 5M5 12l7 7M12 5l7 7' stroke-opacity='0.55'/>",
	"mate": "<rect x='4' y='5' width='16' height='5'/><rect x='4' y='14' width='16' height='5' stroke-dasharray='2 2'/><path d='M12 10v4'/>",
	"solve": "<path d='M6 13l4 4L18 7'/><circle cx='12' cy='12' r='9' stroke-opacity='0.45'/>",
	"lock": "<rect x='7' y='11' width='10' height='8' rx='1'/><path d='M9 11V8a3 3 0 0 1 6 0v3'/>",
	"unlock": "<rect x='7' y='11' width='10' height='8' rx='1'/><path d='M9 11V8a3 3 0 0 1 5.2-2'/>",
	# --- small row actions ---
	"add": "<path d='M12 5v14M5 12h14'/>",
	"delete": "<path d='M6 8h12l-1 12H7zM4.5 8h15M9.5 8V5.5h5V8'/><path d='M10 11.5v5M14 11.5v5'/>",
	"rename": "<path d='M6 18l.8-3.2L15.6 6l2.4 2.4-8.8 8.8z'/><path d='M4 21h16' stroke-opacity='0.55'/>",
	"up": "<path d='M12 19V6'/><path d='M6.5 11.5 12 6l5.5 5.5'/>",
	"down": "<path d='M12 5v13'/><path d='M6.5 12.5 12 18l5.5-5.5'/>",
	"save": "<path d='M5 5h11l3 3v11H5z'/><path d='M8 5v5h7V5'/><rect x='8' y='13' width='8' height='6'/>",
	"cancel": "<path d='M6 6l12 12M18 6 6 18'/>",
	"ok": "<path d='M5 13l4.5 4.5L19 7'/>",
	"mic": "<path d='M12 4a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0V7a3 3 0 0 1 3-3z'/><path d='M7.5 11.5a4.5 4.5 0 0 0 9 0M12 16v3.5M9.5 19.5h5'/>",
}

static var _cache := {}


static func get_icon(icon_name: String, size := 18) -> Texture2D:
	var key := "%s@%d" % [icon_name, size]
	if _cache.has(key):
		return _cache[key]
	if not GLYPHS.has(icon_name):
		push_warning("UIIcons: unknown icon '%s'" % icon_name)
		return null
	var body: String = GLYPHS[icon_name]
	body = body.replace("%STROKE%", STROKE)
	var svg := ("<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' "
		+ "viewBox='0 0 24 24'><g fill='none' stroke='%s' stroke-width='1.7' " % STROKE
		+ "stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % body)
	var img := Image.new()
	# Rasterize at 2x for crisp downscaled rendering.
	if img.load_svg_from_string(svg, size * 2.0 / 24.0) != OK:
		push_warning("UIIcons: bad svg for '%s'" % icon_name)
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Standard action button: icon + tooltip; `label` may be "" for icon-only
## (compact rows) — the tooltip then carries the meaning on mouseover.
static func button(icon_name: String, label: String, tooltip: String) -> Button:
	var b := Button.new()
	b.icon = get_icon(icon_name)
	b.text = label
	b.tooltip_text = tooltip
	if label == "":
		b.expand_icon = false
		b.custom_minimum_size = Vector2(30, 28)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


static func apply(b: Button, icon_name: String, tooltip: String) -> Button:
	b.icon = get_icon(icon_name)
	if tooltip != "":
		b.tooltip_text = tooltip
	return b
