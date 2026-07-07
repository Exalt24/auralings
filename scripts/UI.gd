extends RefCounted

# Shared UI kit so every screen is consistent (the golden rule of game UI/UX): one
# button style, one panel style, one type hierarchy, one rarity color language.
# Everything is built in code (StyleBoxFlat) so there are no theme assets to ship.

const INK := Color("241c38")
const INK_SOFT := Color("2f2650")
const CARD := Color("362a5c")
const TEXT := Color("f2ecff")
const TEXT_DIM := Color("b3a5d9")
const GOLD := Color("ffe9c7")
const MINT := Color("9ff0d0")

const RARITY_COLOR := {
	"common": Color("8b96b8"),
	"rare": Color("52b6ff"),
	"epic": Color("c17bff"),
	"legendary": Color("ffcf4d"),
}

static func rarity_color(r: String) -> Color:
	return RARITY_COLOR.get(r, RARITY_COLOR["common"])

static func panel(bg: Color, radius: int = 22, border_col: Color = Color(0,0,0,0), border_w: int = 0, shadow: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(14)
	if border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border_col
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_offset = Vector2(0, 4)
	return sb

# Apply a full interactive button style (normal/hover/pressed/disabled) in one call.
static func style_button(btn: Button, bg: Color, fg: Color, font_size: int = 30, radius: int = 18) -> void:
	var hover := bg.lightened(0.10)
	var press := bg.darkened(0.14)
	btn.add_theme_stylebox_override("normal", panel(bg, radius, Color(1,1,1,0.06), 2, 6))
	btn.add_theme_stylebox_override("hover", panel(hover, radius, Color(1,1,1,0.14), 2, 8))
	btn.add_theme_stylebox_override("pressed", panel(press, radius, Color(1,1,1,0.10), 2, 2))
	btn.add_theme_stylebox_override("disabled", panel(bg.darkened(0.25), radius, Color(1,1,1,0.03), 1, 0))
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM.darkened(0.2))
	btn.add_theme_font_size_override("font_size", font_size)

static func label(txt: String, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	return l

# A small rounded rarity pill ("RARE", "LEGENDARY"). Tight padding + vertical-center
# so it sits on the name's baseline instead of floating.
static func rarity_pill(rarity: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var col := rarity_color(rarity)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.20)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(2)
	sb.border_color = col
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(rarity.to_upper(), 15, col, HORIZONTAL_ALIGNMENT_CENTER)
	pc.add_child(l)
	return pc
