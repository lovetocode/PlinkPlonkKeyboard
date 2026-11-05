extends Control

const RATE := 22050.0
const VOICES := 8
const FIRST_NOTE := 60
const WHITE_COUNT := 14
const WHITE_STEPS := [0, 2, 4, 5, 7, 9, 11]
const BLACK_AFTER := {0: 1, 1: 3, 3: 6, 4: 8, 5: 10}

class Voice:
	var player: AudioStreamPlayer
	var pb: AudioStreamGeneratorPlayback
	var freq := 0.0
	var phase := 0.0
	var amp := 0.0
	var held := false
	var key := -1

var keys := []      # {rect, note, black}
var touches := {}   # touch index -> key index
var voices := []
const TOP_BAR := 70.0

const THEMES := [
	{"name": "Classic", "white": Color.WHITE, "black": Color.BLACK, "pressed": Color(0.4, 0.7, 1.0), "border": Color.DIM_GRAY},
	{"name": "Chiptune", "white": Color(0.7, 1.0, 0.7), "black": Color(0.1, 0.25, 0.1), "pressed": Color(1.0, 0.9, 0.2), "border": Color(0.05, 0.15, 0.05)},
	{"name": "Sunset", "white": Color(1.0, 0.9, 0.75), "black": Color(0.35, 0.1, 0.2), "pressed": Color(1.0, 0.5, 0.2), "border": Color(0.3, 0.1, 0.1)},
	{"name": "Night", "white": Color(0.25, 0.28, 0.4), "black": Color(0.05, 0.05, 0.12), "pressed": Color(0.8, 0.4, 1.0), "border": Color.BLACK},
]
var theme_index := 0
var theme_button: Button

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
	resized.connect(build_keys)
	build_keys()
	theme_button = Button.new()
	theme_button.position = Vector2(10, 10)
	theme_button.custom_minimum_size = Vector2(160, 50)
	theme_button.pressed.connect(next_theme)
	add_child(theme_button)
	theme_index = 0
	apply_theme_label()
	theme_button.z_index = 10
	
func next_theme() -> void:
	theme_index = (theme_index + 1) % THEMES.size()
	apply_theme_label()
	queue_redraw()

func apply_theme_label() -> void:
	theme_button.text = "Theme: " + THEMES[theme_index].name


func build_keys() -> void:
	keys.clear()
	var w: float = size.x / WHITE_COUNT
	var keyboard_height: float = size.y - TOP_BAR
	var black_height: float = keyboard_height * 0.6

	# White keys first, spanning the full keyboard height.
	for i in WHITE_COUNT:
		var note: int = FIRST_NOTE + (i / 7) * 12 + WHITE_STEPS[i % 7]
		keys.append({
			"rect": Rect2(i * w, TOP_BAR, w, keyboard_height),
			"note": note,
			"black": false
		})

	# Black keys positioned between the appropriate white keys.
	for i in WHITE_COUNT - 1:
		if BLACK_AFTER.has(i % 7):
			var note: int = FIRST_NOTE + (i / 7) * 12 + BLACK_AFTER[i % 7]
			keys.append({
				"rect": Rect2((i + 1) * w - w * 0.3, TOP_BAR, w * 0.6, black_height),
				"note": note,
				"black": true
			})

	queue_redraw()


func key_at(pos: Vector2) -> int:
	for i in range(keys.size() - 1, -1, -1):  # black keys first
		if keys[i].rect.has_point(pos):
			return i
	return -1

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var k := key_at(event.position)
			if k >= 0:
				press(event.index, k)
		else:
			release(event.index)
	elif event is InputEventScreenDrag:
		var k := key_at(event.position)
		if touches.get(event.index, -1) != k:
			release(event.index)
			if k >= 0:
				press(event.index, k)

func press(index: int, k: int) -> void:
	var chosen: Voice = voices[0]
	for v in voices:
		if not v.held and v.amp < 0.01:
			chosen = v
			break
	chosen.freq = 440.0 * pow(2.0, (keys[k].note - 69) / 12.0)
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
	var t = THEMES[theme_index]
	var down := touches.values()
	for pass_black in [false, true]:
		for i in keys.size():
			var k = keys[i]
			if k.black != pass_black:
				continue
			var col: Color = t.black if k.black else t.white
			if down.has(i):
				col = t.pressed
			draw_rect(k.rect, col)
			draw_rect(k.rect, t.border, false, 2.0)
