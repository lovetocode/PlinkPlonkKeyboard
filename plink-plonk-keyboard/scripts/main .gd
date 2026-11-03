extends Control

const KEYBOARD := preload("res://scripts/keyboard.gd")
const DRUMS := preload("res://scripts/drums.gd")
const TOP_BAR := 70.0

const AREAS := ["Piano", "Drums", "Piano + Drums"]
const SOUNDS := ["Square", "Piano", "Organ", "E-Piano", "Harpsichord", "Sample"]

var vbox: VBoxContainer
var top_row: HBoxContainer
var drums
var fd: FileDialog
var save_fd: FileDialog
var rec: AudioEffectRecord
var rec_btn: Button
var play_player: AudioStreamPlayer
var last_take: AudioStreamWAV
var area_btn: OptionButton
var sound_btn: OptionButton

const THEMES := [
	{"name": "Classic", "white": Color.WHITE, "black": Color.BLACK, "pressed": Color(0.4, 0.7, 1.0), "border": Color.DIM_GRAY},
	{"name": "Chiptune", "white": Color(0.7, 1.0, 0.7), "black": Color(0.1, 0.25, 0.1), "pressed": Color(1.0, 0.9, 0.2), "border": Color(0.05, 0.15, 0.05)},
	{"name": "Sunset", "white": Color(1.0, 0.9, 0.75), "black": Color(0.35, 0.1, 0.2), "pressed": Color(1.0, 0.5, 0.2), "border": Color(0.3, 0.1, 0.1)},
	{"name": "Night", "white": Color(0.25, 0.28, 0.4), "black": Color(0.05, 0.05, 0.12), "pressed": Color(0.8, 0.4, 1.0), "border": Color.BLACK},
]

var theme_indexes := [0, 1]
var theme_buttons := []
var kbs := []

func _ready() -> void:
	vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_top = TOP_BAR
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	for n in [72, 48]:
		var kb: Control = KEYBOARD.new()
		kb.start_note = n
		kb.side_on_right = (n == 72)
		kb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(kb)
		kbs.append(kb)

	drums = DRUMS.new()
	drums.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(drums)

	build_top_bar()
	setup_audio()
	set_area(0)
	set_sound(0)

func build_top_bar() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(0, 8)
	scroll.size = Vector2(get_viewport_rect().size.x, 56)
	scroll.z_index = 10
	add_child(scroll)
	top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	scroll.add_child(top_row)

	# Far left: which area/editor is showing (like Blender's editor type menu)
	area_btn = add_dropdown(AREAS, 190, set_area)
	# Which instrument sound the keyboards use
	sound_btn = add_dropdown(SOUNDS, 190, set_sound)
	sound_btn.set_item_disabled(SOUNDS.find("Sample"), true)  # enabled after Load WAV

	for i in kbs.size():
		var b := add_top_button("", 180, next_theme.bind(i))
		theme_buttons.append(b)
		apply_theme(i)
	add_top_button("Swap hands", 130, swap_hands)
	add_top_button("Load WAV", 140, pick)
	rec_btn = add_top_button("Rec", 100, toggle_record)
	add_top_button("Play", 100, play_take)
	add_top_button("Save", 100, save_take)

func add_top_button(text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 50)
	b.pressed.connect(cb)
	top_row.add_child(b)
	return b

func add_dropdown(items: Array, w: float, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(w, 50)
	for it in items:
		o.add_item(it)
	o.item_selected.connect(cb)
	top_row.add_child(o)
	return o

func set_area(i: int) -> void:
	for kb in kbs:
		kb.visible = (i == 0 or i == 2)
	drums.visible = (i == 1 or i == 2)
	if area_btn:
		area_btn.select(i)

func set_sound(i: int) -> void:
	for kb in kbs:
		kb.set_instrument(SOUNDS[i])
	if sound_btn:
		sound_btn.select(i)

func setup_audio() -> void:
	fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.filters = PackedStringArray(["*.wav ; WAV audio"])
	fd.file_selected.connect(on_file)
	add_child(fd)

	save_fd = FileDialog.new()
	save_fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_fd.access = FileDialog.ACCESS_FILESYSTEM
	save_fd.use_native_dialog = true
	save_fd.filters = PackedStringArray(["*.wav ; WAV audio"])
	save_fd.file_selected.connect(on_save_path)
	add_child(save_fd)

	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	play_player = AudioStreamPlayer.new()
	add_child(play_player)

func swap_hands() -> void:
	vbox.move_child(vbox.get_child(1), 0)

func next_theme(i: int) -> void:
	theme_indexes[i] = (theme_indexes[i] + 1) % THEMES.size()
	apply_theme(i)

func apply_theme(i: int) -> void:
	var t = THEMES[theme_indexes[i]]
	theme_buttons[i].text = ("Right: " if i == 0 else "Left: ") + t.name
	kbs[i].colors = t
	kbs[i].queue_redraw()

func pick() -> void:
	fd.popup_centered_ratio(0.8)

func on_file(path: String) -> void:
	var wav := AudioStreamWAV.load_from_file(path)
	if wav == null:
		push_error("Couldn't load " + path)
		return
	for k in kbs:
		k.sample = wav
	var idx := SOUNDS.find("Sample")
	sound_btn.set_item_disabled(idx, false)
	set_sound(idx)

func toggle_record() -> void:
	if rec.is_recording_active():
		rec.set_recording_active(false)
		last_take = rec.get_recording()
		rec_btn.text = "Rec"
	else:
		rec.set_recording_active(true)
		rec_btn.text = "Stop"

func play_take() -> void:
	if last_take:
		play_player.stream = last_take
		play_player.play()

func save_take() -> void:
	if last_take == null:
		return
	save_fd.current_file = "take.wav"
	save_fd.popup_centered_ratio(0.8)

func on_save_path(path: String) -> void:
	var err := last_take.save_to_wav(path)
	if err != OK:
		push_error("Couldn't save to " + path)
