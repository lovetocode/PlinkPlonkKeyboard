extends Control

const KEYBOARD := preload("res://scripts/keyboard.gd")
const DRUMS := preload("res://scripts/drums.gd")
const MIXER := preload("res://scripts/mixer.gd")
const THEREMIN := preload("res://scripts/theremin.gd")
const TOP_BAR := 70.0
const SING := preload("res://scripts/sing.gd")

const AREAS := ["Piano", "Drums", "Piano + Drums", "mixer", "Theremin", "sing", "record"]
const SOUNDS := ["Square", "Piano", "Organ", "E-Piano", "Harpsichord", "Xylophone", "Glass Harmonica", "Guitar", "Bass", "Sample"]

const AUTO_BEATS := [1.0, 0.5, 2.0]
var swap_btn: Button
var auto_btn: OptionButton
var auto_beats_btn: OptionButton

const RECORDER := preload("res://scripts/recorder.gd")
var recorder

var vbox: VBoxContainer
var top_row: HBoxContainer
var drums
var mixer
var theremin
var fd: FileDialog
var save_fd: FileDialog
var rec: AudioEffectRecord
var rec_btn: Button
var play_btn: Button
var play_player: AudioStreamPlayer
var last_take: AudioStreamWAV
var area_btn: OptionButton
var sound_btn: OptionButton
var kit_btn: OptionButton
var view_menu: MenuButton
var file_menu: MenuButton
var proj_save_fd: FileDialog
var proj_open_fd: FileDialog
var take_count := 0
var bpm := 100
var click_player: AudioStreamPlayer
var click_timer: Timer
var click_btn: Button
var backing_player: AudioStreamPlayer
var loading_backing := false
var theremin_btn: OptionButton
var sing
var vocal_count := 0
var bpm_box: SpinBox
var hands_swapped := false

const THEMES := [
	{"name": "Classic", "white": Color.WHITE, "black": Color.BLACK, "pressed": Color(0.4, 0.7, 1.0), "border": Color.DIM_GRAY},
	{"name": "Green Terminal", "white": Color(0.04, 0.2, 0.05), "black": Color(0.0, 0.04, 0.0), "pressed": Color(0.2, 1.0, 0.3), "border": Color(0.1, 0.7, 0.2)},
	{"name": "Amber Terminal", "white": Color(0.25, 0.12, 0.0), "black": Color(0.04, 0.02, 0.0), "pressed": Color(1.0, 0.69, 0.0), "border": Color(0.8, 0.45, 0.0)},
	{"name": "Orange CRT", "white": Color(0.3, 0.1, 0.0), "black": Color(0.05, 0.02, 0.0), "pressed": Color(1.0, 0.4, 0.05), "border": Color(0.9, 0.3, 0.0)},
	{"name": "Chiptune", "white": Color(0.7, 1.0, 0.7), "black": Color(0.1, 0.25, 0.1), "pressed": Color(1.0, 0.9, 0.2), "border": Color(0.05, 0.15, 0.05)},
	{"name": "Groovy 1960s", "white": Color(1.0, 0.93, 0.6), "black": Color(0.45, 0.2, 0.05), "pressed": Color(1.0, 0.35, 0.0), "border": Color(0.55, 0.6, 0.1)},
	{"name": "Psychedelic", "white": Color(1.0, 0.6, 0.85), "black": Color(0.3, 0.0, 0.5), "pressed": Color(0.2, 0.9, 0.4), "border": Color(1.0, 0.8, 0.0)},
	{"name": "Mod Pop", "white": Color(0.95, 0.95, 0.9), "black": Color(0.05, 0.1, 0.5), "pressed": Color(0.95, 0.15, 0.2), "border": Color(1.0, 0.8, 0.1)},
	{"name": "Sunset", "white": Color(1.0, 0.9, 0.75), "black": Color(0.35, 0.1, 0.2), "pressed": Color(1.0, 0.5, 0.2), "border": Color(0.3, 0.1, 0.1)},
	{"name": "Night", "white": Color(0.25, 0.28, 0.4), "black": Color(0.05, 0.05, 0.12), "pressed": Color(0.8, 0.4, 1.0), "border": Color.BLACK},
	{"name": "Neon", "white": Color(0.1, 0.9, 1.0), "black": Color(0.15, 0.0, 0.3), "pressed": Color(1.0, 0.2, 0.8), "border": Color(0.6, 0.0, 1.0)},
]

# 0 = right keyboard, 1 = left keyboard, 2 = drums + sequencer + theremin
var theme_index := 0
var kbs := []

func _ready() -> void:
	setup_audio()
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

	mixer = MIXER.new()
	mixer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(mixer)

	theremin = THEREMIN.new()
	theremin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(theremin)

	sing = SING.new()
	sing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sing.bpm = bpm
	sing.sing_started.connect(on_sing_started)
	sing.sing_stopped.connect(on_sing_stopped)
	sing.take_ready.connect(on_vocal_take)
	vbox.add_child(sing)
	
	recorder = RECORDER.new()
	recorder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recorder.sound_ready.connect(on_sound_ready)
	vbox.add_child(recorder)

	build_top_bar()
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

	# 1. File menu (far left)
	file_menu = add_menu("File", 100, ["Load WAV", "Save take", "Send take to mixer", "Save project", "Load project", "Backing: use last take", "Backing: load WAV", "Backing: play/stop"], on_file_item)
	# 2. Area
	area_btn = add_dropdown(AREAS, 140, set_area)
	# 3. Instrument sound
	sound_btn = add_dropdown(SOUNDS, 120, set_sound)
	sound_btn.set_item_disabled(SOUNDS.find("Sample"), true)
	# 4. Drum kit
	kit_btn = add_dropdown(DRUMS.KIT_NAMES, 110, set_kit)
	swap_btn = add_top_button("Swap pads", 130, func(): pass)
	swap_btn.toggle_mode = true
	swap_btn.pressed.connect(func(): drums.set_swap_mode(swap_btn.button_pressed))
	var auto_items := ["Auto: Off"]
	for n in 8:
		auto_items.append("Auto: Pad " + str(n + 1))
	auto_btn = add_dropdown(auto_items, 140, update_auto)
	auto_beats_btn = add_dropdown(["1 beat", "1/2 beat", "2 beats"], 110, update_auto)
	theremin_btn = add_dropdown(THEREMIN.VOICES.keys(), 130, set_theremin_voice)
	# 5. View menu: themes + swap hands
	var view_items := []
	for t in THEMES:
		view_items.append(t.name)
	view_items.append("Swap hands")
	view_menu = add_menu("View", 110, view_items, on_view_item)
	apply_theme()
	# 6. Transport
	rec_btn = add_top_button("Rec", 100, toggle_record)
	play_btn = add_top_button("Play", 100, play_take)
	click_btn = add_top_button("Click: Off", 120, toggle_click)
	var sb := SpinBox.new()
	bpm_box = sb
	sb.min_value = 40
	sb.max_value = 240
	sb.value = bpm
	sb.custom_minimum_size = Vector2(110, 50)
	sb.value_changed.connect(set_bpm)
	top_row.add_child(sb)
	
func set_theremin_voice(i: int) -> void:
	theremin.set_voice(THEREMIN.VOICES.keys()[i])

func add_top_button(text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 50)
	b.pressed.connect(cb)
	top_row.add_child(b)
	return b
	
func send_take() -> void:
	if last_take == null:
		return
	take_count += 1
	mixer.add_track("Take " + str(take_count), last_take)
	set_area(3)

func add_dropdown(items: Array, w: float, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(w, 50)
	for it in items:
		o.add_item(it)
	o.item_selected.connect(cb)
	top_row.add_child(o)
	return o

func add_menu(text: String, w: float, items: Array, cb: Callable) -> MenuButton:
	var m := MenuButton.new()
	m.text = text
	m.flat = false
	m.custom_minimum_size = Vector2(w, 50)
	var p := m.get_popup()
	for i in items.size():
		p.add_item(items[i], i)
	p.id_pressed.connect(cb)
	top_row.add_child(m)
	return m

func on_view_item(id: int) -> void:
	if id < THEMES.size():
		theme_index = id
		apply_theme()
	else:
		swap_hands()

func apply_theme() -> void:
	theme_index = clampi(theme_index, 0, THEMES.size() - 1)
	var t = THEMES[theme_index]
	var p := view_menu.get_popup()
	for i in THEMES.size():
		p.set_item_text(i, ("● " if i == theme_index else "    ") + THEMES[i].name)
	for c in kbs + [drums, mixer, theremin, sing, recorder]:
		c.colors = t
		c.queue_redraw()

func on_file_item(id: int) -> void:
	if id == 0:
		pick()
	elif id == 1:
		save_take()
	elif id == 2:
		send_take()
	elif id == 3:
		proj_save_fd.current_file = "project.ppp"
		proj_save_fd.popup_centered_ratio(0.8)
	elif id == 4:
		proj_open_fd.popup_centered_ratio(0.8)
	elif id == 5:
		take_as_backing()
	elif id == 6:
		load_backing()
	elif id == 7:
		toggle_backing()

func save_project(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Couldn't save to " + path)
		return
	var pads := {}
	var custom: Dictionary = drums.get_custom()
	for i in custom:
		pads[i] = pack_wav(custom[i])
	f.store_var({
		"version": 4,
		"theme": theme_index,
		"tracks": mixer.get_state(),
		"keyboard": pack_wav(kbs[0].sample),
		"kit": kit_btn.selected,
		"pads": pads,
		"layout": drums.get_layout(),
		"theremin": pack_wav(theremin.sample_wav),
		"theremin_on": theremin.use_sample,
		"sound": sound_btn.selected,
		"theremin_voice": theremin_btn.selected,
		"bpm": bpm,
		"lyrics": sing.editor.text,
		"area": area_btn.selected,
		"hands_swapped": hands_swapped,
		"auto_pad": auto_btn.selected,
		"auto_beats": auto_beats_btn.selected,
		"backing": pack_wav(backing_player.stream as AudioStreamWAV),
		"octaves": [kbs[0].start_note, kbs[1].start_note],
		"sing": sing.get_settings(),
	})
	f.close()

func load_project(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Couldn't open " + path)
		return
	var d = f.get_var()
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		push_error("Not a project file")
		return
	if d.has("theme"):
		theme_index = d["theme"]
	elif d.has("themes"):
		theme_index = d["themes"][2]
	apply_theme()
	mixer.set_state(d.get("tracks", []))

	var kw := unpack_wav(d.get("keyboard", {}))
	var sample_idx := SOUNDS.find("Sample")
	for k in kbs:
		k.sample = kw
	sound_btn.set_item_disabled(sample_idx, kw == null)
	var snd: int = d.get("sound", sound_btn.selected)
	if snd == sample_idx and kw == null:
		snd = 0
	set_sound(snd)

	set_kit(d.get("kit", 0))
	drums.set_layout(d.get("layout", []))
	var pads: Dictionary = d.get("pads", {})
	for i in pads:
		var pw := unpack_wav(pads[i])
		if pw:
			drums.set_pad_sound(int(i), pw)
			
	var tv: int = clampi(d.get("theremin_voice", theremin_btn.selected), 0, theremin_btn.item_count - 1)
	theremin_btn.select(tv)
	set_theremin_voice(tv)

	bpm_box.value = d.get("bpm", bpm)
	sing.editor.text = d.get("lyrics", sing.editor.text)
	var octs: Array = d.get("octaves", [])
	for i in mini(octs.size(), kbs.size()):
		kbs[i].start_note = clampi(int(octs[i]), 24, 84)
		kbs[i].update_label()
	sing.set_settings(d.get("sing", {}))

	var tw := unpack_wav(d.get("theremin", {}))
	if tw:
		theremin.set_sample(tw)
		if not d.get("theremin_on", true):
			theremin.use_sample = false
			theremin.sample_player.stop()

	var want_swap: bool = d.get("hands_swapped", false)
	if want_swap != hands_swapped:
		swap_hands()

	if d.has("backing"):
		backing_player.stop()
		backing_player.stream = unpack_wav(d["backing"])

	var area: int = clampi(d.get("area", 3), 0, AREAS.size() - 1)
	set_area(area)
	if area == 1 or area == 2:
		auto_btn.select(clampi(d.get("auto_pad", 0), 0, auto_btn.item_count - 1))
		auto_beats_btn.select(clampi(d.get("auto_beats", 0), 0, auto_beats_btn.item_count - 1))
		update_auto()

func set_area(i: int) -> void:
	for kb in kbs:
		kb.visible = (i == 0 or i == 2)
	drums.visible = (i == 1 or i == 2)
	mixer.visible = (i == 3)
	theremin.visible = (i == 4)
	if sound_btn:
		sound_btn.visible = (i == 0 or i == 2)
	if kit_btn:
		kit_btn.visible = (i == 1 or i == 2)
	if theremin_btn:
		theremin_btn.visible = (i == 4)
	recorder.visible = (i == 6)
	if area_btn:
		area_btn.select(i)
	sing.visible = (i == 5)
	var on_drums := (i == 1 or i == 2)
	if swap_btn:
		swap_btn.visible = on_drums
		auto_btn.visible = on_drums
		auto_beats_btn.visible = on_drums
		if not on_drums:
			auto_btn.select(0)
			update_auto()

func set_sound(i: int) -> void:
	for kb in kbs:
		kb.set_instrument(SOUNDS[i])
	if sound_btn:
		sound_btn.select(i)

func set_kit(i: int) -> void:
	drums.set_kit(DRUMS.KIT_NAMES[i])
	if kit_btn:
		kit_btn.select(i)

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
	AudioServer.add_bus()
	var rec_bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(rec_bus, "Rec")
	AudioServer.set_bus_send(rec_bus, "Master")
	AudioServer.add_bus_effect(rec_bus, rec)
	AudioServer.add_bus()
	var mon_bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(mon_bus, "Monitor")
	AudioServer.set_bus_send(mon_bus, "Master")

	play_player = AudioStreamPlayer.new()
	play_player.bus = "Monitor"
	play_player.finished.connect(func(): play_btn.text = "Play")
	add_child(play_player)

	click_player = AudioStreamPlayer.new()
	click_player.stream = make_click()
	click_player.bus = "Monitor"
	add_child(click_player)

	click_timer = Timer.new()
	click_timer.timeout.connect(func(): click_player.play())
	add_child(click_timer)

	backing_player = AudioStreamPlayer.new()
	backing_player.bus = "Monitor"
	add_child(backing_player)
	
	proj_save_fd = FileDialog.new()
	proj_save_fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	proj_save_fd.access = FileDialog.ACCESS_FILESYSTEM
	proj_save_fd.use_native_dialog = true
	proj_save_fd.filters = PackedStringArray(["*.ppp ; Plink Plonk project"])
	proj_save_fd.file_selected.connect(save_project)
	add_child(proj_save_fd)
	
	proj_open_fd = FileDialog.new()
	proj_open_fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	proj_open_fd.access = FileDialog.ACCESS_FILESYSTEM
	proj_open_fd.use_native_dialog = true
	proj_open_fd.filters = PackedStringArray(["*.ppp ; Plink Plonk project"])
	proj_open_fd.file_selected.connect(load_project)
	add_child(proj_open_fd)

func swap_hands() -> void:
	vbox.move_child(vbox.get_child(1), 0)
	hands_swapped = not hands_swapped

func pick() -> void:
	fd.popup_centered_ratio(0.8)

func on_file(path: String) -> void:
	var wav := AudioStreamWAV.load_from_file(path)
	if wav == null:
		push_error("Couldn't load " + path)
		return
	if loading_backing:
		loading_backing = false
		backing_player.stream = wav
		return
	for k in kbs:
		k.sample = wav
	var idx := SOUNDS.find("Sample")
	sound_btn.set_item_disabled(idx, false)
	set_sound(idx)

func toggle_record() -> void:
	if rec.is_recording_active():
		rec.set_recording_active(false)
		backing_player.stop()
		mixer.stop_all()
		last_take = rec.get_recording()
		rec_btn.text = "Rec"
	else:
		rec.set_recording_active(true)
		if backing_player.stream:
			backing_player.play()
		mixer.play_all()
		rec_btn.text = "Stop Rec"

func play_take() -> void:
	if play_player.playing:
		play_player.stop()
		play_btn.text = "Play"
		return
	if last_take:
		play_player.stream = last_take
		play_player.play()
		play_btn.text = "Stop"

func save_take() -> void:
	if last_take == null:
		return
	save_fd.current_file = "take.wav"
	save_fd.popup_centered_ratio(0.8)

func on_save_path(path: String) -> void:
	var err := last_take.save_to_wav(path)
	if err != OK:
		push_error("Couldn't save to " + path)
		
func make_click() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.03)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / n
		data.encode_s16(i * 2, int(sin(TAU * 1000.0 * i / rate) * env * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

func toggle_click() -> void:
	if click_timer.is_stopped():
		click_timer.start(60.0 / bpm)
		click_player.play()
		click_btn.text = "Click: On"
	else:
		click_timer.stop()
		click_btn.text = "Click: Off"

func set_bpm(v: float) -> void:
	bpm = int(v)
	click_timer.wait_time = 60.0 / bpm
	if sing:
		sing.bpm = bpm
	if auto_btn:
		update_auto()
	

func take_as_backing() -> void:
	if last_take:
		backing_player.stream = last_take

func load_backing() -> void:
	loading_backing = true
	pick()

func toggle_backing() -> void:
	if backing_player.playing:
		backing_player.stop()
	elif backing_player.stream:
		backing_player.play()

func on_sing_started() -> void:
	if backing_player.stream:
		backing_player.play()
	mixer.play_all()

func on_sing_stopped() -> void:
	backing_player.stop()
	mixer.stop_all()

func on_vocal_take(take: AudioStreamWAV) -> void:
	vocal_count += 1
	mixer.add_track("Vocal " + str(vocal_count), take)
	
func update_auto(_i: int = 0) -> void:
	drums.set_auto(auto_btn.selected - 1, bpm, AUTO_BEATS[auto_beats_btn.selected])
	
func on_sound_ready(wav: AudioStreamWAV, target: String) -> void:
	if target == "Keyboard":
		for k in kbs:
			k.sample = wav
		var idx := SOUNDS.find("Sample")
		sound_btn.set_item_disabled(idx, false)
		set_sound(idx)
	elif target.begins_with("Drum pad"):
		drums.set_pad_sound(int(target.get_slice(" ", 2)) - 1, wav)
	elif target == "Theremin":
		theremin.set_sample(wav)
	else:
		take_count += 1
		mixer.add_track("Sound " + str(take_count), wav)
		
func pack_wav(w: AudioStreamWAV) -> Dictionary:
	if w == null:
		return {}
	return {"format": w.format, "mix_rate": w.mix_rate, "stereo": w.stereo, "data": w.data}

func unpack_wav(d: Dictionary) -> AudioStreamWAV:
	if d.is_empty():
		return null
	var w := AudioStreamWAV.new()
	w.format = d.format
	w.mix_rate = d.mix_rate
	w.stereo = d.stereo
	w.data = d.data
	return w
