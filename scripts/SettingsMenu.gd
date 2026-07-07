extends Control

# A gear button (top-right) that expands/collapses a small settings panel holding the
# Sound + Reduce-Motion toggles. Progressive disclosure keeps the screen clean on
# mobile, and a gear is the universally-understood settings icon. The gear is DRAWN in
# code (a font glyph would tofu on the web build). Sits on top of everything so it is
# always clickable.

const UI = preload("res://scripts/UI.gd")
const Settings = preload("res://scripts/Settings.gd")

var sfx = null
var _expanded := false
var _gear: Button
var _panel: PanelContainer

# --- drawn gear icon (overlaid on the gear button) ---
class GearIcon extends Control:
	var col := Color("9ff0d0")
	var hole := Color("2f2650")
	func _draw() -> void:
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.30
		for i in 8:
			var a := TAU * float(i) / 8.0
			var dir := Vector2(cos(a), sin(a))
			var perp := Vector2(-dir.y, dir.x)
			var tip := c + dir * (r * 1.5)
			var pts := PackedVector2Array([
				c + dir * r * 0.85 + perp * (r * 0.26),
				tip + perp * (r * 0.16),
				tip - perp * (r * 0.16),
				c + dir * r * 0.85 - perp * (r * 0.26),
			])
			draw_colored_polygon(pts, col)
		draw_circle(c, r, col)
		draw_circle(c, r * 0.42, hole)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_gear = Button.new()
	_gear.custom_minimum_size = Vector2(52, 52)
	_gear.size = Vector2(52, 52)
	_gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_gear.offset_left = -66; _gear.offset_top = 16
	_gear.offset_right = -14; _gear.offset_bottom = 68
	var round_sb := UI.panel(UI.INK_SOFT, 26, Color(1, 1, 1, 0.10), 2, 6)
	_gear.add_theme_stylebox_override("normal", round_sb)
	_gear.add_theme_stylebox_override("hover", UI.panel(UI.INK_SOFT.lightened(0.1), 26, Color(1, 1, 1, 0.16), 2, 8))
	_gear.add_theme_stylebox_override("pressed", UI.panel(UI.INK_SOFT.darkened(0.12), 26, Color(1, 1, 1, 0.1), 2, 2))
	add_child(_gear)
	var icon := GearIcon.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gear.add_child(icon)
	_gear.pressed.connect(_toggle)

	# the expandable panel (hidden until the gear is tapped)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.panel(UI.CARD, 18, Color(1, 1, 1, 0.08), 2, 10))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -250; _panel.offset_top = 78
	_panel.offset_right = -14; _panel.offset_bottom = 208
	_panel.visible = false
	_panel.modulate.a = 0.0
	add_child(_panel)
	var pad := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 14)
	_panel.add_child(pad)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pad.add_child(vb)
	vb.add_child(_row("Sound", true, func(on): Settings.muted = not on))
	vb.add_child(_row("Reduce Motion", not Settings.reduced_motion, func(on): Settings.reduced_motion = not on))

func _row(label_text: String, start_on: bool, apply: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UI.label(label_text, 20, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var t := Button.new()
	t.toggle_mode = true
	t.button_pressed = start_on
	t.custom_minimum_size = Vector2(76, 40)
	t.text = "ON" if start_on else "OFF"
	UI.style_button(t, UI.INK_SOFT, UI.MINT if start_on else UI.TEXT_DIM, 18, 12)
	t.toggled.connect(func(on):
		apply.call(on)
		t.text = "ON" if on else "OFF"
		t.add_theme_color_override("font_color", UI.MINT if on else UI.TEXT_DIM)
		if sfx: sfx.play("tap"))
	row.add_child(t)
	return row

func _toggle() -> void:
	if sfx: sfx.play("tap")
	_expanded = not _expanded
	if _expanded:
		_panel.visible = true
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	else:
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 0.0, 0.12)
		tw.tween_callback(func(): _panel.visible = false)
