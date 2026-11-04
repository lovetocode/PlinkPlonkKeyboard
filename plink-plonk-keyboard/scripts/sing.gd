extends Control

signal sing_started
signal sing_stopped
signal take_ready(take)

const EFFECTS := ["No effect", "Helium", "Deep"]
const EFFECT_PITCH := [1.0, 1.8, 0.7]
const COUNT_IN := 4

var colors := {}:
	set(v):
		colors = v
		_apply_colors()

var bpm := 100
var beats_per_line := 4
var lines: PackedStringArray = []
var running := false
var take_begun := false
var start_ms := 0
var last_line := -2

var editor: TextEdit
var stage: VBoxContainer
var sing_btn: Button
var labels: Array = []
var cue: ProgressBar
var mic_player: AudioStreamPlayer
var mic_rec: AudioEffectRecord
var shift: AudioEffectPitchShift
var mic_bus := -1

func _ready() -> void:
	_setup_mic()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)

	sing_btn = Button.new()
	sing_btn.text = "Sing"
	sing_btn.custom_minimum_size = Vector2(120, 50)
	sing_btn.pressed.connect(toggle)
	bar.add_child(sing_btn)

	var fx := OptionButton.new()
	fx.custom_minimum_size = Vector2(140, 50)
	for e in EFFECTS:
		fx.add_item(e)
	fx.item_selected.connect(_on_effect)
	bar.add_child(fx)

	var lbl := Label.new()
	lbl.text = "Beats per line:"
	bar.add_child(lbl)
	var sb := SpinBox.new()
	sb.min_value = 1
	sb.max_value = 16
	sb.value = beats_per_line
	sb.custom_minimum_size = Vector2(100, 50)
	sb.value_changed.connect(func(v): beats_per_line = int(v))
	bar.add_child(sb)

	editor = TextEdit.new()
	editor.placeholder_text = "Paste or type lyrics here, one line per phrase..."
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(editor)

	stage = VBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.visible = false
	root.add_child(stage)
	for k in 4:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 52 if k == 1 else 28)
		stage.add_child(l)
		labels.append(l)
	cue = ProgressBar.new()
	cue.max_value = 1.0
	cue.step = 0.001
	cue.show_percentage = false
	cue.custom_minimum_size = Vector2(0, 16)
	stage.add_child(cue)
	_apply_colors()

func _setup_mic() -> void:
	# Mic goes to a silent bus so you don't get feedback, but still records.
	AudioServer.add_bus()
	mic_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(mic_bus, "Mic")
	AudioServer.add_bus()
	var silent := AudioServer.bus_count - 1
	AudioServer.set_bus_name(silent, "MicSilent")
	AudioServer.set_bus_volume_db(silent, -80.0)
	AudioServer.set_bus_send(silent, "Master")
	AudioServer.set_bus_send(mic_bus, "MicSilent")

	shift = AudioEffectPitchShift.new()
	mic_rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(mic_bus, shift)   # effect index 0
	AudioServer.add_bus_effect(mic_bus, mic_rec) # effect index 1
	AudioServer.set_bus_effect_enabled(mic_bus, 0, false)

	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Mic"
	add_child(mic_player)

func _on_effect(i: int) -> void:
	shift.pitch_scale = EFFECT_PITCH[i]
	AudioServer.set_bus_effect_enabled(mic_bus, 0, i != 0)

func toggle() -> void:
	if running:
		stop()
	else:
		start()

func start() -> void:
	OS.request_permission("RECORD_AUDIO")
	lines = editor.text.split("\n", false)
	last_line = -2
	take_begun = false
	running = true
	editor.visible = false
	stage.visible = true
	sing_btn.text = "Stop"
	mic_player.play()
	start_ms = Time.get_ticks_msec()

func stop() -> void:
	if not running:
		return
	running = false
	var take = null
	if mic_rec.is_recording_active():
		mic_rec.set_recording_active(false)
		take = mic_rec.get_recording()
	mic_player.stop()
	editor.visible = true
	stage.visible = false
	sing_btn.text = "Sing"
	sing_stopped.emit()
	if take:
		take_ready.emit(take)

func _process(_d: float) -> void:
	if not running:
		return
	var beat := (Time.get_ticks_msec() - start_ms) / 1000.0 * bpm / 60.0
	var rel := beat - COUNT_IN
	if rel < 0.0:
		# Count-in: big 4..3..2..1 with the first line previewed
		labels[0].text = ""
		labels[1].text = str(int(ceil(-rel)))
		labels[2].text = lines[0] if lines.size() > 0 else ""
		labels[3].text = ""
		cue.value = 1.0 + rel / COUNT_IN
		return
	if not take_begun:
		take_begun = true
		mic_rec.set_recording_active(true)
		sing_started.emit()
	var idx := int(rel / beats_per_line)
	if idx != last_line:
		show_line(idx)
	cue.value = fmod(rel, beats_per_line) / beats_per_line

func show_line(idx: int) -> void:
	last_line = idx
	for k in 4:
		var i := idx - 1 + k
		labels[k].text = lines[i] if i >= 0 and i < lines.size() else ""

func _apply_colors() -> void:
	if labels.is_empty():
		return
	var hi: Color = colors.get("pressed", Color.YELLOW)
	var dim: Color = colors.get("white", Color.WHITE).lightened(0.5)
	dim.a = 0.7
	for k in 4:
		labels[k].add_theme_color_override("font_color", hi if k == 1 else dim)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), colors.get("black", Color(0.1, 0.1, 0.1)))
