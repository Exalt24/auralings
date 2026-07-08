extends Control

# A tiny hand-drawn checkmark so the toast has an icon WITHOUT relying on a glyph font
# (avoids the tofu/missing-glyph issue that bit the emoji chars earlier).

@export var color: Color = Color("9ff0d0")

func _ready() -> void:
	custom_minimum_size = Vector2(24, 24)

func _draw() -> void:
	var w := 3.0
	draw_line(Vector2(3, 13), Vector2(9, 19), color, w, true)
	draw_line(Vector2(9, 19), Vector2(21, 5), color, w, true)
