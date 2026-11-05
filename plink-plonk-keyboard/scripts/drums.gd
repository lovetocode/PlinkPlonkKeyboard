extends Control

signal kit_changed

const RATE := 22050
const KIT_NAMES := ["Standard", "Bongos", "Electro"]
const KITS := {
	"Standard": ["Kick", "Snare", "Hat", "Open Hat", "Tom", "Clap", "Click", "Crash"],
	"Bongos": ["Bongo Hi", "Bongo Lo", "Conga Hi", "Conga Lo", "Slap", "Cowbell", "Shaker", "Woodblock"],
	"Electro": ["808 Kick", "Snare", "Clap", "Hat", "808 Tom", "Cowbell", "Click", "Crash"],
}
# tonal drums: [base Hz, pitch sweep Hz, sweep speed, volume decay]
const TONAL := {
	"Kick": [40.0, 110.0, 25.0, 9.0],
	"Tom": [90.0, 80.0, 12.0, 8.0],
	"808 Kick": [45.0, 150.0, 18.0, 4.0],
	"808 Tom": [110.0, 100.0, 10.0, 5.0],
	"Bongo Hi": [330.0, 120.0, 40.0, 14.0],
	"Bongo Lo": [240.0, 90.0, 40.0, 12.0],
	"Conga Hi": [260.0, 60.0, 30.0, 9.0],
	"Conga Lo": [180.0, 50.0, 30.0, 8.0],
}
const DURS := {
	"Hat": 0.08, "Click": 0.05, "Clap": 0.2, "Crash": 1.0, "Open Hat": 0.35,
	"808 Kick": 0.6, "808 Tom": 0.5, "Slap": 0.12, "Shaker": 0.15,
	"Woodblock": 0.1, "Bongo Hi": 0.2, "Bongo Lo": 0.25,
	"Conga Hi": 0.35, "Conga Lo": 0.35,
}

var colors := {"white": Color(0.9, 0.9, 0.95), "black": Color.BLACK, "pressed": Color(1.0, 0.6, 0.2), "border": Color.DIM_GRAY}
var players := []
var names := []
var cache := {}
var pad_rects := []
var touches := {}

var auto_pad := -1
var auto_timer: Timer

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Rec"
		add_child(p)
		players.append(p)
	set_kit("Standard")
	resized.connect(build_pads)
	build_pads()
	_setup_auto()

func _setup_auto() -> void:
	auto_timer = Timer.new()
	auto_timer.timeout.connect(_on_auto)
	add_child(auto_timer)

func _on_auto() -> void:
	if auto_pad >= 0:
		play_pad(auto_pad)

func set_auto(pad: int, bpm: float, beats: float) -> void:
	auto_pad = pad
	if pad < 0:
		auto_timer.stop()
	else:
		auto_timer.start(60.0 / bpm * beats)
		
func set_kit(kit: String) -> void:
	names = KITS[kit].duplicate()
	for i in names.size():
		players[i].stream = get_sound(names[i])
	queue_redraw()
	kit_changed.emit()

func get_sound(kind: String) -> AudioStreamWAV:
	if not cache.has(kind):
		cache[kind] = make_sound(kind)
	return cache[kind]

func play_pad(i: int) -> void:
	players[i].play()

func make_sound(kind: String) -> AudioStreamWAV:
	var dur: float = DURS.get(kind, 0.3)
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var phase2 := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		if TONAL.has(kind):
			var p: Array = TONAL[kind]
			phase += (p[0] + p[1] * exp(-t * p[2])) / RATE
			s = sin(TAU * phase) * exp(-t * p[3])
		else:
			match kind:
				"Snare":
					phase += 190.0 / RATE
					s = (randf() * 2.0 - 1.0) * exp(-t * 18.0) * 0.7 + sin(TAU * phase) * exp(-t * 30.0) * 0.5
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
				"Slap":
					phase += 500.0 / RATE
					s = (randf() * 2.0 - 1.0) * exp(-t * 45.0) * 0.6 + sin(TAU * phase) * exp(-t * 35.0) * 0.4
				"Shaker":
					var nz := randf() * 2.0 - 1.0
					s = (nz - prev) * 0.4 * exp(-t * 14.0) * clampf(t * 60.0, 0.0, 1.0)
					prev = nz
				"Cowbell":
					phase += 540.0 / RATE
					phase2 += 800.0 / RATE
					var a := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
					var b := 1.0 if fmod(phase2, 1.0) < 0.5 else -1.0
					s = (a + b) * 0.3 * exp(-t * 9.0)
				"Woodblock":
					phase += 1100.0 / RATE
					s = sin(TAU * phase) * exp(-t * 45.0)
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
	for i in 8:
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
				if swap_mode:
					if swap_from < 0:
						swap_from = k
					else:
						swap_pads(swap_from, k)
						swap_from = -1
					queue_redraw()
					return
				play_pad(k)
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
		if swap_mode and i == swap_from:
			col = Color(0.6, 0.9, 0.6)
		draw_rect(pad_rects[i], col)
		draw_rect(pad_rects[i], colors.border, false, 3.0)
		if i < names.size():
			draw_string(font, pad_rects[i].position + Vector2(16, 40), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, colors.black)
	
var swap_mode := false
var swap_from := -1

func set_swap_mode(on: bool) -> void:
	swap_mode = on
	swap_from = -1
	queue_redraw()

func swap_pads(a: int, b: int) -> void:
	var tn = names[a]
	names[a] = names[b]
	names[b] = tn
	var ts = players[a].stream
	players[a].stream = players[b].stream
	players[b].stream = ts
