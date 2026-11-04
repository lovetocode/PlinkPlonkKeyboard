extends Control

const RATE := 22050.0
const SEMITONES := 48.0
const LOW_HZ := 110.0
const VOL_W := 0.2          # left strip = volume hand
const VOICES := {
	"Classic": {"h": [1.0, 0.25, 0.08], "rate": 5.5, "amt": 0.03},
	"Pure": {"h": [1.0], "rate": 5.5, "amt": 0.03},
	"Buzzy": {"h": [1.0, 0.5, 0.33, 0.25, 0.2, 0.17, 0.14], "rate": 5.5, "amt": 0.03},
	"Hollow": {"h": [1.0, 0.0, 0.33, 0.0, 0.2, 0.0, 0.14], "rate": 5.0, "amt": 0.02},
	"Voice": {"h": [1.0, 0.6, 0.5, 0.15, 0.3, 0.1], "rate": 4.5, "amt": 0.02},
	"Spooky": {"h": [1.0, 0.3], "rate": 4.0, "amt": 0.08},
}

var colors := {"white": Color(0.9, 0.9, 0.95), "black": Color.BLACK, "pressed": Color(1.0, 0.6, 0.2), "border": Color.DIM_GRAY}
var player: AudioStreamPlayer
var pb: AudioStreamGeneratorPlayback
var phase := 0.0
var lfo := 0.0
var freq := 440.0
var amp := 0.0
var target_freq := 440.0
var vol_level := 0.6
var vib_depth := 0.0
var pitch_index := -1
var vol_index := -1
var pitch_pos := Vector2.ZERO
var vol_pos := Vector2.ZERO
var harm: Array = []
var harm_norm := 1.0
var vib_rate := 5.5
var vib_amt := 0.03

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Rec"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.1
	player.stream = gen
	add_child(player)
	player.play()
	pb = player.get_stream_playback()
	set_voice("Classic")
	
func set_voice(name: String) -> void:
	var d: Dictionary = VOICES[name]
	harm = d.h
	vib_rate = d.rate
	vib_amt = d.amt
	harm_norm = 0.0
	for h in harm:
		harm_norm += h

func _process(_delta: float) -> void:
	if pb == null:
		return
	var target_amp := vol_level if pitch_index != -1 else 0.0
	var n := pb.get_frames_available()
	for i in n:
		amp += (target_amp - amp) * 0.001
		freq += (target_freq - freq) * 0.0015
		lfo = fmod(lfo + vib_rate / RATE, 1.0)
		var wobble := 1.0 + sin(TAU * lfo) * vib_depth * vib_amt
		phase = fmod(phase + freq * wobble / RATE, 1.0)
		var s := 0.0
		for h in harm.size():
			s += harm[h] * sin(TAU * phase * (h + 1))
		s *= amp * 0.5 / harm_norm
		pb.push_frame(Vector2(s, s))

func update_pitch(pos: Vector2) -> void:
	pitch_pos = pos
	var zone_x := size.x * VOL_W
	var x := clampf((pos.x - zone_x) / (size.x - zone_x), 0.0, 1.0)
	var y := clampf(pos.y / size.y, 0.0, 1.0)
	target_freq = LOW_HZ * pow(2.0, SEMITONES * x / 12.0)
	vib_depth = 1.0 - y
	queue_redraw()

func update_volume(pos: Vector2) -> void:
	vol_pos = pos
	vol_level = 1.0 - clampf(pos.y / size.y, 0.0, 1.0)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var inv := get_global_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var pos: Vector2 = inv * event.position
		if event.pressed:
			if not Rect2(Vector2.ZERO, size).has_point(pos):
				return
			if pos.x < size.x * VOL_W:
				if vol_index == -1:
					vol_index = event.index
					update_volume(pos)
			elif pitch_index == -1:
				pitch_index = event.index
				update_pitch(pos)
		else:
			if event.index == pitch_index:
				pitch_index = -1
				vib_depth = 0.0
			elif event.index == vol_index:
				vol_index = -1
			queue_redraw()
	elif event is InputEventScreenDrag:
		var pos: Vector2 = inv * event.position
		if event.index == pitch_index:
			update_pitch(pos)
		elif event.index == vol_index:
			update_volume(pos)

func _draw() -> void:
	var zone_x := size.x * VOL_W
	draw_rect(Rect2(Vector2.ZERO, size), colors.white)
	# volume strip with a level bar
	draw_rect(Rect2(0, 0, zone_x, size.y), colors.border.lerp(colors.white, 0.6))
	var bar_h := size.y * vol_level
	draw_rect(Rect2(0, size.y - bar_h, zone_x, bar_h), colors.pressed.lerp(colors.white, 0.4))
	draw_line(Vector2(zone_x, 0), Vector2(zone_x, size.y), colors.border, 4.0)
	# a line for every semitone, thicker at each octave
	var pitch_w := size.x - zone_x
	for s in int(SEMITONES) + 1:
		var x := zone_x + pitch_w * s / SEMITONES
		draw_line(Vector2(x, 0), Vector2(x, size.y), colors.border, 3.0 if s % 12 == 0 else 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12, 36), "VOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, colors.black)
	draw_string(font, Vector2(zone_x + 16, 36), "PITCH: left/right = note, up/down = vibrato", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, colors.black)
	if pitch_index != -1:
		draw_circle(pitch_pos, 36.0, colors.pressed)
		draw_arc(pitch_pos, 36.0, 0.0, TAU, 32, colors.border, 3.0)
	if vol_index != -1:
		draw_circle(vol_pos, 36.0, colors.pressed)
		draw_arc(vol_pos, 36.0, 0.0, TAU, 32, colors.border, 3.0)
