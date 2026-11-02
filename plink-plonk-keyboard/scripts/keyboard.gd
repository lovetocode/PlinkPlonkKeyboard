extends Control

@export var side_on_right := false

const RATE := 22050.0
const VOICES := 8
const WHITE_STEPS := [0, 2, 4, 5, 7, 9, 11]
const BLACK_AFTER := {0: 1, 1: 3, 3: 6, 4: 8, 5: 10}
const SIDE := 110.0

var sample: AudioStreamWAV = null   # null = square wave
var root_note := 60                 # pitch the WAV was recorded at (C4)
var sample_players := []
var sample_next := 0

@export var start_note := 60
@export var white_count := 14

var colors := {"white": Color.WHITE, "black": Color.BLACK, "pressed": Color(0.4, 0.7, 1.0), "border": Color.DIM_GRAY}

class Voice:
	var player: AudioStreamPlayer
	var pb: AudioStreamGeneratorPlayback
	var freq := 0.0
	var phase := 0.0
	var amp := 0.0
	var held := false
	var key := -1

var keys := []
var touches := {}
var voices := []
var side: VBoxContainer
var octave_label: Label

func _ready() -> void:
	for i in VOICES:
		var v := Voice.new()
		v.player = AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = 0.1
		v.player.stream = gen
		add_child(v.player)
		v.player.play()
		v.pb = v.player.get_stream_playback()
		voices.append(v)

	side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	add_child(side)
	make_button("Oct +", 1)
	octave_label = Label.new()
	octave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(octave_label)
	make_button("Oct -", -1)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sample_players.append(p)

	resized.connect(build_keys)
	build_keys()

func make_button(text: String, dir: int) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.pressed.connect(change_octave.bind(dir))
	side.add_child(b)

func change_octave(dir: int) -> void:
	start_note = clampi(start_note + dir * 12, 24, 84)
	update_label()

func update_label() -> void:
	if octave_label:
		octave_label.text = "C" + str(start_note / 12 - 1)

func build_keys() -> void:
	keys.clear()
	side.position = Vector2(size.x - SIDE if side_on_right else 0.0, 0.0)
	side.size = Vector2(SIDE, size.y)
	var left := 0.0 if side_on_right else SIDE
	var w := (size.x - SIDE) / white_count
	for i in white_count:
		keys.append({"rect": Rect2(left + i * w, 0, w, size.y), "offset": (i / 7) * 12 + WHITE_STEPS[i % 7], "black": false})
	for i in white_count - 1:
		if BLACK_AFTER.has(i % 7):
			keys.append({"rect": Rect2(left + (i + 1) * w - w * 0.3, 0, w * 0.6, size.y * 0.6), "offset": (i / 7) * 12 + BLACK_AFTER[i % 7], "black": true})
	update_label()
	queue_redraw()

func key_at(pos: Vector2) -> int:
	for i in range(keys.size() - 1, -1, -1):
		if keys[i].rect.has_point(pos):
			return i
	return -1

func _input(event: InputEvent) -> void:
	var inv := get_global_transform().affine_inverse()
	if event is InputEventScreenTouch:
		if event.pressed:
			var k := key_at(inv * event.position)
			if k >= 0:
				press(event.index, k)
		else:
			release(event.index)
	elif event is InputEventScreenDrag:
		if not touches.has(event.index):
			return
		var k := key_at(inv * event.position)
		if touches[event.index] != k:
			release(event.index)
			if k >= 0:
				press(event.index, k)

func press(index: int, k: int) -> void:
	var note: int = start_note + keys[k].offset
	if sample:
		var p: AudioStreamPlayer = sample_players[sample_next]
		sample_next = (sample_next + 1) % sample_players.size()
		p.stream = sample
		p.pitch_scale = pow(2.0, (note - root_note) / 12.0)
		p.play()
		touches[index] = k
		queue_redraw()
		return
	# ...rest of your existing code (chosen voice etc.)
	var chosen: Voice = voices[0]
	for v in voices:
		if not v.held and v.amp < 0.01:
			chosen = v
			break
	chosen.freq = 440.0 * pow(2.0, (note - 69) / 12.0)
	chosen.held = true
	chosen.key = k
	touches[index] = k
	queue_redraw()

func release(index: int) -> void:
	if not touches.has(index):
		return
	var k: int = touches[index]
	for v in voices:
		if v.held and v.key == k:
			v.held = false
			break
	touches.erase(index)
	queue_redraw()

func _process(_delta: float) -> void:
	for v in voices:
		var target := 0.2 if v.held else 0.0
		var step := 0.001 if v.held else 0.0002
		for i in v.pb.get_frames_available():
			v.amp = move_toward(v.amp, target, step)
			var s: float = 1.0 if v.phase < 0.5 else -1.0
			s *= v.amp
			v.pb.push_frame(Vector2(s, s))
			v.phase += v.freq / RATE
			if v.phase >= 1.0:
				v.phase -= 1.0

func _draw() -> void:
	var down := touches.values()
	for pass_black in [false, true]:
		for i in keys.size():
			var k = keys[i]
			if k.black != pass_black:
				continue
			var col: Color = colors.black if k.black else colors.white
			if down.has(i):
				col = colors.pressed
			draw_rect(k.rect, col)
			draw_rect(k.rect, colors.border, false, 2.0)
