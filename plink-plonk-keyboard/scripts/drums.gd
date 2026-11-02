extends Control

const RATE := 22050
const NAMES := ["Kick", "Snare", "Hat", "Open Hat", "Tom", "Clap", "Click", "Crash"]

var colors := {"white": Color(0.9, 0.9, 0.95), "black": Color.BLACK, "pressed": Color(1.0, 0.6, 0.2), "border": Color.DIM_GRAY}
var players := []
var pad_rects := []
var touches := {}

func _ready() -> void:
	for n in NAMES:
		var p := AudioStreamPlayer.new()
		p.stream = make_sound(n)
		add_child(p)
		players.append(p)
	resized.connect(build_pads)
	build_pads()

func make_sound(kind: String) -> AudioStreamWAV:
	var dur := 0.3
	match kind:
		"Hat": dur = 0.08
		"Click": dur = 0.05
		"Clap": dur = 0.2
		"Crash": dur = 1.0
		"Open Hat": dur = 0.35
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		match kind:
			"Kick":
				phase += (40.0 + 110.0 * exp(-t * 25.0)) / RATE
				s = sin(TAU * phase) * exp(-t * 9.0)
			"Snare":
				phase += 190.0 / RATE
				s = (randf() * 2.0 - 1.0) * exp(-t * 18.0) * 0.7 + sin(TAU * phase) * exp(-t * 30.0) * 0.5
			"Tom":
				phase += (90.0 + 80.0 * exp(-t * 12.0)) / RATE
				s = sin(TAU * phase) * exp(-t * 8.0)
			"Hat", "Open Hat", "Crash":
				var noise := randf() * 2.0 - 1.0
				s = (noise - prev) * 0.5
				prev = noise
				var decay := 60.0 if kind == "Hat" else (12.0 if kind == "Open Hat" else 4.0)
				s *= exp(-t * decay)
			"Clap":
				var burst := exp(-fmod(t, 0.03) * 150.0)
				s = (randf() * 2.0 - 1.0) * burst * exp(-t * 14.0)
			"Click":
				s = (1.0 if fmod(t * 900.0, 1.0) < 0.5 else -1.0) * exp(-t * 80.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func build_pads() -> void:
	pad_rects.clear()
	var cols := 4
	var rows := 2
	var gap := 8.0
	var w := (size.x - gap * (cols + 1)) / cols
	var h := (size.y - gap * (rows + 1)) / rows
	for i in NAMES.size():
		var c := i % cols
		var r := i / cols
		pad_rects.append(Rect2(gap + c * (w + gap), gap + r * (h + gap), w, h))
	queue_redraw()

func pad_at(pos: Vector2) -> int:
	for i in pad_rects.size():
		if pad_rects[i].has_point(pos):
			return i
	return -1

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var k := pad_at(get_global_transform().affine_inverse() * event.position)
			if k >= 0:
				players[k].play()
				touches[event.index] = k
				queue_redraw()
		else:
			touches.erase(event.index)
			queue_redraw()

func _draw() -> void:
	var down := touches.values()
	var font := ThemeDB.fallback_font
	for i in pad_rects.size():
		var col: Color = colors.pressed if down.has(i) else colors.white
		draw_rect(pad_rects[i], col)
		draw_rect(pad_rects[i], colors.border, false, 3.0)
		draw_string(font, pad_rects[i].position + Vector2(16, 40), NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, colors.black)
