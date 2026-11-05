extends Control

@export var side_on_right := false

const RATE := 22050.0
const VOICES := 8
const WHITE_STEPS := [0, 2, 4, 5, 7, 9, 11]
const BLACK_AFTER := {0: 1, 1: 3, 3: 6, 4: 8, 5: 10}
const SIDE := 110.0

# harmonics = relative strength of each overtone (empty = square wave)
# sustain   = level a held note settles to (1 = never decays)
# decay     = how fast it falls toward sustain (per second)
# release   = how fast it fades after key up
# attack (optional) = how fast it rises on key down (per sample, default 0.002)
const INSTRUMENTS := {
	"Square": {"harmonics": [], "sustain": 0.15, "decay": 3.0, "release": 0.0002},
	"Piano": {"harmonics": [1.0, 0.5, 0.3, 0.15, 0.08], "sustain": 0.1, "decay": 2.5, "release": 0.0003},
	"Organ": {"harmonics": [1.0, 0.8, 0.6, 0.4, 0.2], "sustain": 1.0, "decay": 0.0, "release": 0.0008},
	"E-Piano": {"harmonics": [1.0, 0.1, 0.3, 0.0, 0.05], "sustain": 0.2, "decay": 1.5, "release": 0.0004},
	"Harpsichord": {"harmonics": [1.0, 0.9, 0.7, 0.6, 0.5, 0.4, 0.3], "sustain": 0.05, "decay": 6.0, "release": 0.0008},
	"Xylophone": {"harmonics": [1.0, 0.0, 0.5, 0.0, 0.0, 0.25], "sustain": 0.0, "decay": 9.0, "release": 0.0003},
	"Glass Harmonica": {"harmonics": [1.0, 0.12, 0.04], "sustain": 1.0, "decay": 0.0, "release": 0.00001, "attack": 0.00004},
	"Sample": {"harmonics": [], "sustain": 1.0, "decay": 0.0, "release": 0.0002},
	"Guitar": {"harmonics": [1.0, 0.7, 0.5, 0.35, 0.2, 0.1], "sustain": 0.0, "decay": 2.0, "release": 0.0006},
	"Bass": {"harmonics": [1.0, 0.4, 0.15], "sustain": 0.15, "decay": 1.5, "release": 0.0004, "octave": -1},
	"Saw": {"harmonics": [1.0, 0.2, 0.08, 0.03], "sustain": 1.0, "decay": 0.0, "release": 0.0003, "attack": 0.0004, "vib": 0.006, "vib_rate": 5.0, "scoop": -1.5, "scoop_rate": 12.0},
	"Chip Saw": {"harmonics": [], "sustain": 1.0, "decay": 0.0, "release": 0.0004, "attack": 0.0004, "vib": 0.012, "vib_rate": 5.5, "scoop": -1.0, "scoop_rate": 14.0},
	"Pulse 12": {"wave": "pulse", "duty": 0.125, "harmonics": [], "sustain": 1.0, "decay": 0.0, "release": 0.0004, "attack": 0.0004},
	"Pulse 25": {"wave": "pulse", "duty": 0.25, "harmonics": [], "sustain": 1.0, "decay": 0.0, "release": 0.0004, "attack": 0.0004},
	"Triangle": {"wave": "tri", "harmonics": [], "sustain": 1.0, "decay": 0.0, "release": 0.0004, "attack": 0.0004},
	"8-Bit Noise": {"wave": "noise", "harmonics": [], "sustain": 0.3, "decay": 6.0, "release": 0.0004, "attack": 0.0004},
	"8-Bit Metal": {"wave": "noise", "short": true, "harmonics": [], "sustain": 0.3, "decay": 6.0, "release": 0.0004, "attack": 0.0004},
	"VRC6 Saw": {"wave": "saw", "harmonics": [], "sustain": 1.0, "decay": 0.0, "release": 0.0004, "attack": 0.0004},
}

var instrument := "Square"
var cur_harm: Array = []
var cur_norm := 1.0
var cur_sustain := 1.0
var cur_decay := 0.0
var cur_release := 0.0002
var cur_attack := 0.002
var cur_octave := 0
var cur_vib := 0.0
var cur_vib_rate := 5.0
var cur_scoop := 0.0
var cur_scoop_rate := 12.0
var cur_wave := "harm"
var cur_duty := 0.5
var cur_short := false

var sample: AudioStreamWAV = null
var root_note := 60                 # pitch the WAV was recorded at (C4)
var sample_players := []
var sample_next := 0

@export var start_note := 60
@export var white_count := 14

var colors := {"white": Color.WHITE, "black": Color.BLACK, "pressed": Color(0.4, 0.7, 1.0), "border": Color.DIM_GRAY}:
	set(value):
		colors = value
		style_side()
		queue_redraw()

class Voice:
	var player: AudioStreamPlayer
	var pb: AudioStreamGeneratorPlayback
	var freq := 0.0
	var phase := 0.0
	var amp := 0.0
	var age := 0.0
	var held := false
	var key := -1
	var pedal := false
	var lfo := 0.0
	var scoop := 0.0
	var lfsr := 1
	var noise_out := 1.0
	

var keys := []
var touches := {}
var voices := []
var side: VBoxContainer
var octave_label: Label
var sustain_on := false

func _ready() -> void:
	for i in VOICES:
		var v := Voice.new()
		v.player = AudioStreamPlayer.new()
		v.player.bus = "Rec"
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
	var sus := Button.new()
	sus.text = "Sus"
	sus.toggle_mode = true
	sus.focus_mode = Control.FOCUS_NONE
	sus.toggled.connect(set_pedal)
	side.add_child(sus)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Rec"
		add_child(p)
		sample_players.append(p)

	set_instrument("Square")
	resized.connect(build_keys)
	build_keys()
	style_side()

func set_instrument(name: String) -> void:
	instrument = name
	var d: Dictionary = INSTRUMENTS[name]
	cur_harm = d.harmonics
	cur_sustain = d.sustain
	cur_decay = d.decay
	cur_release = d.release
	cur_attack = d.get("attack", 0.002)
	cur_norm = 0.0
	cur_octave = d.get("octave", 0)
	cur_wave = d.get("wave", "harm")
	cur_duty = d.get("duty", 0.5)
	cur_short = d.get("short", false)
	cur_vib = d.get("vib", 0.0)
	cur_vib_rate = d.get("vib_rate", 5.0)
	cur_scoop = d.get("scoop", 0.0)
	cur_scoop_rate = d.get("scoop_rate", 12.0)
	for h in cur_harm:
		cur_norm += h
	if cur_norm == 0.0:
		cur_norm = 1.0

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
	if not is_visible_in_tree():
		return
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
	if instrument == "Sample" and sample:
		var p: AudioStreamPlayer = sample_players[sample_next]
		sample_next = (sample_next + 1) % sample_players.size()
		p.stream = sample
		p.pitch_scale = pow(2.0, (note - root_note) / 12.0)
		p.play()
		touches[index] = k
		queue_redraw()
		return
	for v in voices:
		if v.pedal and v.key == k:
			v.pedal = false
			v.held = false
	var chosen: Voice = voices[0]
	for v in voices:
		if not v.held and v.amp < 0.01:
			chosen = v
			break
	chosen.freq = 440.0 * pow(2.0, (note - 69) / 12.0 + cur_octave)
	chosen.held = true
	chosen.pedal = false
	chosen.age = 0.0
	chosen.lfsr = 1
	chosen.lfo = 0.0
	chosen.scoop = cur_scoop
	chosen.key = k
	touches[index] = k
	queue_redraw()
	
func release(index: int) -> void:
	if not touches.has(index):
		return
	var k: int = touches[index]
	for v in voices:
		if v.held and not v.pedal and v.key == k:
			if sustain_on:
				v.pedal = true
			else:
				v.held = false
			break
	touches.erase(index)
	queue_redraw()

func _process(_delta: float) -> void:
	for v in voices:
		var frames: int = v.pb.get_frames_available()
		if frames == 0:
			continue
		if not v.held and v.amp < 0.0001:
			v.amp = 0.0
			for i in frames:
				v.pb.push_frame(Vector2.ZERO)
			continue
		var target := 0.0
		var step := cur_release
		if v.held:
			target = 0.2 * (cur_sustain + (1.0 - cur_sustain) * exp(-v.age * cur_decay))
			step = cur_attack
			v.age += frames / RATE
		v.scoop = move_toward(v.scoop, 0.0, cur_scoop_rate * frames / RATE)
		var mult: float = pow(2.0, v.scoop / 12.0)
		var vib: float = cur_vib * clampf(v.age * 2.0, 0.0, 1.0)
		var noisy := cur_wave == "noise"
		for i in frames:
			v.amp = move_toward(v.amp, target, step)
			var s: float
			match cur_wave:
				"pulse":
					s = 1.0 if v.phase < cur_duty else -1.0
				"tri":
					s = roundf((4.0 * absf(v.phase - 0.5) - 1.0) * 7.5) / 7.5
				"saw":
					s = roundf((v.phase * 2.0 - 1.0) * 3.5) / 3.5
				"noise":
					s = v.noise_out
				_:
					if cur_harm.is_empty():
						s = 1.0 if v.phase < 0.5 else -1.0
					else:
						s = 0.0
						for h in cur_harm.size():
							s += cur_harm[h] * sin(TAU * v.phase * (h + 1))
						s /= cur_norm
			s *= v.amp
			v.pb.push_frame(Vector2(s, s))
			var f: float = v.freq * mult * (1.0 + vib * sin(TAU * v.lfo))
			if noisy:
				f *= 8.0
			v.phase += f / RATE
			v.lfo += cur_vib_rate / RATE
			if v.phase >= 1.0:
				v.phase -= 1.0
				if noisy:
					var bit: int = (v.lfsr ^ (v.lfsr >> (6 if cur_short else 1))) & 1
					v.lfsr = (v.lfsr >> 1) | (bit << 14)
					v.noise_out = 1.0 if (v.lfsr & 1) == 0 else -1.0
			if v.lfo >= 1.0:
				v.lfo -= 1.0
			
func make_box(fill: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(2)
	b.set_corner_radius_all(6)
	return b

func style_side() -> void:
	if side == null:
		return
	var fill: Color = colors.white
	var txt: Color = colors.black if fill.get_luminance() > 0.5 else colors.pressed
	var normal := make_box(fill, colors.border)
	var hover := make_box(fill.lerp(colors.pressed, 0.35), colors.border)
	var down := make_box(colors.pressed, colors.border)
	var label_col: Color = colors.pressed if colors.black.get_luminance() < 0.5 else colors.white
	for c in side.get_children():
		if c is Button:
			c.add_theme_stylebox_override("normal", normal)
			c.add_theme_stylebox_override("hover", hover)
			c.add_theme_stylebox_override("pressed", down)
			c.add_theme_stylebox_override("hover_pressed", down)
			c.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			for n in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
				c.add_theme_color_override(n, txt)
			c.add_theme_color_override("font_pressed_color", colors.black)
		elif c is Label:
			c.add_theme_color_override("font_color", label_col)

func _draw() -> void:
	draw_rect(Rect2(side.position, side.size), colors.black)
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
			
func set_pedal(on: bool) -> void:
	sustain_on = on
	if not on:
		for v in voices:
			if v.pedal:
				v.pedal = false
				v.held = false
