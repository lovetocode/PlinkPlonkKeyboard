extends Control

const RATE := 22050.0
const SEMITONES := 36.0
const LOW_HZ := 110.0

var colors := {"white": Color(0.9, 0.9, 0.95), "black": Color.BLACK, "pressed": Color(1.0, 0.6, 0.2), "border": Color.DIM_GRAY}
var player: AudioStreamPlayer
var pb: AudioStreamGeneratorPlayback
var phase := 0.0
var freq := 440.0
var amp := 0.0
var target_freq := 440.0
var target_amp := 0.0
var touch_index := -1
var touch_pos := Vector2.ZERO

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.1
	player.stream = gen
	add_child(player)
	player.play()
	pb = player.get_stream_playback()

func _process(_delta: float) -> void:
	if pb == null:
		return
	var n := pb.get_frames_available()
	for i in n:
		amp += (target_amp - amp) * 0.002
		freq += (target_freq - freq) * 0.003
		phase = fmod(phase + freq / RATE, 1.0)
		var s := sin(TAU * phase) * amp * 0.5
		pb.push_frame(Vector2(s, s))

func update_from(pos: Vector2) -> void:
	touch_pos = pos
	var x := clampf(pos.x / size.x, 0.0, 1.0)
	var y := clampf(pos.y / size.y, 0.0, 1.0)
	target_freq = LOW_HZ * pow(2.0, SEMITONES * x / 12.0)
	target_amp = 1.0 - y
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var inv := get_global_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var pos: Vector2 = inv * event.position
		if event.pressed:
			if Rect2(Vector2.ZERO, size).has_point(pos) and touch_index == -1:
				touch_index = event.index
				update_from(pos)
		elif event.index == touch_index:
			touch_index = -1
			target_amp = 0.0
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == touch_index:
		update_from(inv * event.position)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), colors.white)
	# a line for every semitone, thicker on each C-ish octave (every 12)
	for s in int(SEMITONES) + 1:
		var x := size.x * s / SEMITONES
		draw_line(Vector2(x, 0), Vector2(x, size.y), colors.border, 3.0 if s % 12 == 0 else 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(16, 36), "Theremin: left/right = pitch, up/down = volume", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, colors.black)
	if touch_index != -1:
		draw_circle(touch_pos, 36.0, colors.pressed)
		draw_arc(touch_pos, 36.0, 0.0, TAU, 32, colors.border, 3.0)
