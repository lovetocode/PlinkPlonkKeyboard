extends Control

const FX_NAMES := ["Reverb", "Delay", "Distortion", "Low-pass", "High-pass", "Chorus"]

var colors := {"white": Color(0.9, 0.9, 0.95), "black": Color.BLACK, "pressed": Color(1.0, 0.6, 0.2), "border": Color.DIM_GRAY}:
	set(v):
		colors = v
		restyle()
var tracks := []
var bus_counter := 0
var list: VBoxContainer
var fd: FileDialog
var fd2: FileDialog

func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_right = -8
	root.offset_top = 6
	root.offset_bottom = -6
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	add_btn(bar, "Play All", 110, play_all)
	add_btn(bar, "Stop All", 110, stop_all)
	add_btn(bar, "Load WAV", 120, func(): fd.popup_centered_ratio(0.8))
	add_btn(bar, "Export WAV", 140, func(): fd2.popup_centered_ratio(0.8))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	
	fd2 = FileDialog.new()
	fd2.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd2.access = FileDialog.ACCESS_FILESYSTEM
	fd2.use_native_dialog = true
	fd2.filters = PackedStringArray(["*.wav ; WAV audio"])
	fd2.file_selected.connect(export_wav)
	add_child(fd2)

	fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.filters = PackedStringArray(["*.wav ; WAV audio"])
	fd.file_selected.connect(on_file)
	add_child(fd)
	restyle()

func add_btn(parent: Control, text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 50)
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b

func text_color() -> Color:
	return colors.black if colors.white.get_luminance() > 0.5 else Color.WHITE

func make_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = colors.white
	sb.border_color = colors.border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb

func restyle() -> void:
	if not is_inside_tree():
		return
	var sb := make_style()
	for t in tracks:
		t.panel.add_theme_stylebox_override("panel", sb)
		for l in t.labels:
			l.add_theme_color_override("font_color", text_color())
	queue_redraw()

func make_effects() -> Array:
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.8
	rv.wet = 0.4
	var dl := AudioEffectDelay.new()
	dl.feedback_active = true
	var di := AudioEffectDistortion.new()
	di.drive = 0.4
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 1200.0
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 800.0
	var ch := AudioEffectChorus.new()
	return [rv, dl, di, lp, hp, ch]   # same order as FX_NAMES

func make_label(text: String, w: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(w, 0)
	l.clip_text = true
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func make_slider(lo: float, hi: float, val: float, w: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = val
	s.custom_minimum_size = Vector2(w, 50)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

# Public: the main script calls this to send a take over.
func add_track(track_name: String, stream: AudioStream) -> Dictionary:
	bus_counter += 1
	var bus_name := "Track " + str(bus_counter)
	AudioServer.add_bus()
	var bi := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bi, bus_name)
	AudioServer.set_bus_send(bi, "Master")
	AudioServer.add_bus_effect(bi, AudioEffectPanner.new())   # effect 0 = pan
	for fx in make_effects():                                  # effects 1..6, all off
		AudioServer.add_bus_effect(bi, fx)
		AudioServer.set_bus_effect_enabled(bi, AudioServer.get_bus_effect_count(bi) - 1, false)

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus_name
	add_child(player)

	var panel := PanelContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	list.add_child(panel)

	var name_label := make_label(track_name, 110)
	h.add_child(name_label)
	add_btn(h, "Play", 80, player.play)

	var mute := Button.new()
	mute.text = "Mute"
	mute.toggle_mode = true
	mute.focus_mode = Control.FOCUS_NONE
	mute.custom_minimum_size = Vector2(80, 50)
	mute.toggled.connect(set_mute.bind(bus_name))
	h.add_child(mute)

	var vol_label := make_label("Vol")
	h.add_child(vol_label)
	var vol := make_slider(0.0, 1.5, 1.0, 160)
	vol.value_changed.connect(set_volume.bind(bus_name))
	h.add_child(vol)

	var pan_label := make_label("Pan")
	h.add_child(pan_label)
	var pan := make_slider(-1.0, 1.0, 0.0, 110)
	pan.value_changed.connect(set_pan.bind(bus_name))
	h.add_child(pan)

	var fx_btn := MenuButton.new()
	fx_btn.text = "FX"
	fx_btn.flat = false
	fx_btn.custom_minimum_size = Vector2(80, 50)
	var popup := fx_btn.get_popup()
	popup.hide_on_checkable_item_selection = false
	for i in FX_NAMES.size():
		popup.add_check_item(FX_NAMES[i], i)
	h.add_child(fx_btn)

	var rm := add_btn(h, "X", 50, Callable())

	var t := {"name": track_name, "stream": stream, "bus": bus_name, "player": player,
		"panel": panel, "labels": [name_label, vol_label, pan_label],
		"vol": vol, "pan": pan, "mute": mute, "popup": popup}
	popup.id_pressed.connect(toggle_fx.bind(t))
	rm.pressed.connect(remove_track.bind(t))
	tracks.append(t)
	restyle()
	return t

func set_volume(v: float, bus_name: String) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), linear_to_db(maxf(v, 0.0001)))

func set_mute(on: bool, bus_name: String) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bus_name), on)

func set_pan(v: float, bus_name: String) -> void:
	var pn: AudioEffectPanner = AudioServer.get_bus_effect(AudioServer.get_bus_index(bus_name), 0)
	pn.pan = v

func set_fx(t: Dictionary, i: int, on: bool) -> void:
	var popup: PopupMenu = t.popup
	popup.set_item_checked(popup.get_item_index(i), on)
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(t.bus), 1 + i, on)

func toggle_fx(id: int, t: Dictionary) -> void:
	var popup: PopupMenu = t.popup
	set_fx(t, id, not popup.is_item_checked(popup.get_item_index(id)))

func remove_track(t: Dictionary) -> void:
	t.player.stop()
	t.player.queue_free()
	t.panel.queue_free()
	AudioServer.remove_bus(AudioServer.get_bus_index(t.bus))
	tracks.erase(t)
	queue_redraw()

func play_all() -> void:
	for t in tracks:
		t.player.play()

func stop_all() -> void:
	for t in tracks:
		t.player.stop()

func on_file(path: String) -> void:
	var wav := AudioStreamWAV.load_from_file(path)
	if wav == null:
		push_error("Couldn't load " + path)
		return
	add_track(path.get_file().get_basename(), wav)

# ---- project save / load ----
func get_state() -> Array:
	var out := []
	for t in tracks:
		var s: AudioStreamWAV = t.stream
		var popup: PopupMenu = t.popup
		var fx := []
		for i in FX_NAMES.size():
			fx.append(popup.is_item_checked(popup.get_item_index(i)))
		out.append({"name": t.name, "format": s.format, "mix_rate": s.mix_rate, "stereo": s.stereo,
			"data": s.data, "vol": t.vol.value, "pan": t.pan.value, "mute": t.mute.button_pressed, "fx": fx})
	return out
	
func set_state(state: Array) -> void:
	while tracks.size() > 0:
		remove_track(tracks[0])
	for e: Dictionary in state:
		var w := AudioStreamWAV.new()
		w.format = e.format
		w.mix_rate = e.mix_rate
		w.stereo = e.stereo
		w.data = e.data
		var t := add_track(e.name, w)
		t.vol.value = e.vol
		t.pan.value = e.pan
		t.mute.button_pressed = e.mute
		for i in FX_NAMES.size():
			set_fx(t, i, e.fx[i])

var export_rec: AudioEffectRecord
var export_path := ""
var exporting := false

func export_wav(path: String) -> void:
	if tracks.is_empty() or exporting:
		return
	exporting = true
	export_path = path
	export_rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, export_rec)   # bus 0 = Master
	export_rec.set_recording_active(true)
	var longest := 0.0
	for t in tracks:
		longest = maxf(longest, t.stream.get_length())
	play_all()
	get_tree().create_timer(longest + 1.0).timeout.connect(finish_export)

func finish_export() -> void:
	export_rec.set_recording_active(false)
	var rec: AudioStreamWAV = export_rec.get_recording()
	stop_all()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	exporting = false
	if rec:
		rec.save_to_wav(export_path)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), colors.border)
	if tracks.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(16, 130), "No tracks yet: Load WAV, or File > Send take to mixer", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, text_color())
