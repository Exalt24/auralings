extends RefCounted

# Tiny one-shot particle burst used for summons and knockouts. Built in code (no
# texture = small square sparks) so there are no art assets to ship. Auto-frees.

const Settings = preload("res://scripts/Settings.gd")

static func burst(parent: Node2D, pos: Vector2, col: Color, amount: int = 26, speed: float = 280.0) -> void:
	if Settings.reduced_motion:
		amount = maxi(6, int(amount * 0.3))   # keep a subtle pop, drop the spray
		speed *= 0.5
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 30
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, 340)
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.damping_min = 40.0
	p.damping_max = 90.0
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 1.0))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = grad
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(float(p.lifetime) + 0.4).timeout.connect(p.queue_free)
