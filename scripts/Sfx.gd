extends Node

# Procedural sound. Every SFX is synthesized in code into an AudioStreamWAV (no audio
# assets to ship, works on web export). Juicy audio measurably raises presence, and a
# silent game feels dead, so every meaningful action gets a blip. Respect a mute flag
# for accessibility. (ACM "Juicy Audio"; sfxengine sound-design)

const RATE := 22050
const Settings = preload("res://scripts/Settings.gd")
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bank := {}
var muted := false

func _ready() -> void:
	# a small pool so overlapping hits don't cut each other off
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_bank["tap"]     = _tone([880.0], 0.06, "square", 0.18, 0.0)
	_bank["summon"]  = _sweep(300.0, 1100.0, 0.34, "sine", 0.22)
	_bank["hit"]     = _noise(0.10, 0.28, 900.0)
	_bank["crit"]    = _sweep(700.0, 1600.0, 0.20, "square", 0.26)
	_bank["ability"] = _sweep(500.0, 1300.0, 0.30, "sine", 0.24)
	_bank["hurt"]    = _sweep(500.0, 180.0, 0.22, "saw", 0.22)
	_bank["victory"] = _arp([523.25, 659.25, 783.99, 1046.5], 0.10, "square", 0.22)
	_bank["defeat"]  = _arp([440.0, 349.23, 261.63], 0.16, "sine", 0.22)
	_bank["rare"]    = _arp([784.0, 988.0, 1319.0, 1568.0], 0.09, "sine", 0.26)

func play(name: String, pitch := 1.0) -> void:
	if muted or Settings.muted or not _bank.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _bank[name]
	p.pitch_scale = pitch
	p.play()

# --- synthesis ---
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

func _osc(phase: float, kind: String) -> float:
	match kind:
		"square": return 1.0 if sin(phase) >= 0.0 else -1.0
		"saw": return fmod(phase / TAU, 1.0) * 2.0 - 1.0
		_: return sin(phase)

func _tone(freqs: Array, dur: float, kind: String, amp: float, _pad: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env: float = clampf(1.0 - t / dur, 0.0, 1.0)
		var v := 0.0
		for f in freqs:
			v += _osc(TAU * float(f) * t, kind)
		s[i] = v / freqs.size() * amp * env
	return _wav(s)

func _sweep(f0: float, f1: float, dur: float, kind: String, amp: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array(); s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / dur / RATE
		var f: float = lerp(f0, f1, t)
		phase += TAU * f / RATE
		var env: float = sin(PI * clampf(t, 0.0, 1.0))
		s[i] = _osc(phase, kind) * amp * env
	return _wav(s)

func _noise(dur: float, amp: float, lp: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array(); s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var prev := 0.0
	var a: float = clampf(lp / RATE, 0.02, 1.0)
	for i in n:
		var t := float(i) / RATE
		var env: float = clampf(1.0 - t / dur, 0.0, 1.0)
		var white := rng.randf_range(-1.0, 1.0)
		prev = lerp(prev, white, a)
		s[i] = prev * amp * env
	return _wav(s)

func _arp(notes: Array, step: float, kind: String, amp: float) -> AudioStreamWAV:
	var n := int(step * notes.size() * RATE)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var idx: int = int(t / step)
		if idx >= notes.size():
			idx = notes.size() - 1
		var lt := t - idx * step
		var env: float = clampf(1.0 - lt / step, 0.0, 1.0)
		s[i] = _osc(TAU * float(notes[idx]) * t, kind) * amp * env
	return _wav(s)
