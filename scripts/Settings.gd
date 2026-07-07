extends RefCounted

# Global accessibility toggles, read from anywhere via the static vars. Reduce-motion
# damps screen shake + particle bursts for players prone to motion sickness; mute kills
# all SFX. (Game Accessibility Guidelines: reduced motion + audio options.)

static var muted := false
static var reduced_motion := false

static func motion_scale() -> float:
	return 0.0 if reduced_motion else 1.0
