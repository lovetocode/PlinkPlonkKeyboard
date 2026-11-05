extends Control

signal sound_ready(wav, target)

const TARGETS := ["Keyboard", "Drum pad 1", "Drum pad 2", "Drum pad 3", "Drum pad 4",
	"Drum pad 5", "Drum pad 6", "Drum pad 7", "Drum pad 8", "Theremin", "Mixer track"]

var colors := {}:
	set(v):
		colors = v
		queue_redraw()

var mic_player: AudioStreamPlayer
var rec_effect: AudioEffectRecord
var preview: AudioStreamPlayer
var clip: AudioStreamWAV
var is_rec := false
var started_ms := 0
var info: Label
var rec_btn: Button
var play_btn: Button
var use_btn: Button
var target_btn: OptionButton
var save_fd: FileDialog
var load_fd: FileDialog

func _ready() -> void:
	AudioServer.add_bus()
	var mic_bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(mic_bus, "SoundRec")
	AudioServer.add_bus()
	var silent := AudioServer.bus_count - 1
	AudioServer.set_bus_name(silent, "SoundRecSilent")
	AudioServer.set_bus_volume_db(silent, -80.0)
	AudioServer.set_bus_send(silent, "Master")
	AudioServer.set_bus_send(mic_bus, "SoundRecSilent")
	rec_effect = AudioEffectRecord.new()
	AudioServer.add_bus_effect(mic_bus, rec_effect)

	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "SoundRec"
	add_child(mic_player)

	preview = AudioStreamPlayer.new()
	preview.bus = "Monitor"
	add_child(preview)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	info = Label.new()
	info.text = "Tap Record, make a sound, tap Stop."
	info.add_theme_font_size_override("font_size", 28)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	rec_btn = make_btn(row, "Record", 150, toggle_record)
	play_btn = make_btn(row, "Play", 120, play_clip)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	root.add_child(row2)
	target_btn = OptionButton.new()
	target_btn.custom_minimum_size = Vector2(200, 50)
	for t in TARGETS:
		target_btn.add_item(t)
	row2.add_child(target_btn)
	use_btn = make_btn(row2, "Use sound", 160, use_clip)
	make_btn(row2, "Save WAV", 140, save_clip)
	save_fd = FileDialog.new()
	save_fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_fd.access = FileDialog.ACCESS_FILESYSTEM
	save_fd.use_native_dialog = true
	save_fd.filters = PackedStringArray(["*.wav ; WAV audio"])
	save_fd.file_selected.connect(on_save_path)
	add_child(save_fd)
	
	make_btn(row2, "Load WAV", 140, func(): load_fd.popup_centered_ratio(0.8))
	load_fd = FileDialog.new()
	load_fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_fd.access = FileDialog.ACCESS_FILESYSTEM
	load_fd.use_native_dialog = true
	load_fd.filters = PackedStringArray(["*.wav ; WAV audio"])
	load_fd.file_selected.connect(on_load_path)
	add_child(load_fd)

func make_btn(parent: Control, text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 50)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func toggle_record() -> void:
	if is_rec:
		is_rec = false
		rec_effect.set_recording_active(false)
		mic_player.stop()
		clip = clean(rec_effect.get_recording())
		rec_btn.text = "Record"
		if clip:
			info.text = "Got it: %.2f sec. Play it, or pick a target and tap Use sound." % clip.get_length()
		else:
			info.text = "Nothing heard. (First time? Allow the mic, then try again.)"
	else:
		OS.request_permission("RECORD_AUDIO")
		mic_player.play()
		rec_effect.set_recording_active(true)
		started_ms = Time.get_ticks_msec()
		is_rec = true
		rec_btn.text = "Stop"

func _process(_d: float) -> void:
	if is_rec:
		info.text = "Recording... %.1f sec" % ((Time.get_ticks_msec() - started_ms) / 1000.0)

func play_clip() -> void:
	if clip == null:
		return
	if preview.playing:
		preview.stop()
	else:
		preview.stream = clip
		preview.play()

func use_clip() -> void:
	if clip:
		sound_ready.emit(clip, TARGETS[target_btn.selected])
		info.text = "Sent to " + TARGETS[target_btn.selected] + "."

# Trims silence from both ends and normalizes the volume.
func clean(w: AudioStreamWAV) -> AudioStreamWAV:
	if w == null or w.format != AudioStreamWAV.FORMAT_16_BITS:
		return w
	var d := w.data
	var ch := 2 if w.stereo else 1
	var frames := d.size() / (2 * ch)
	var peak := 0
	for i in frames * ch:
		peak = maxi(peak, absi(d.decode_s16(i * 2)))
	if peak < 200:
		return null
	var thresh := maxi(300, int(peak * 0.05))
	var first := -1
	var last := 0
	for f in frames:
		var loud := false
		for c in ch:
			if absi(d.decode_s16((f * ch + c) * 2)) > thresh:
				loud = true
		if loud:
			if first < 0:
				first = f
			last = f
	var pad := int(w.mix_rate * 0.01)
	first = maxi(first - pad, 0)
	last = mini(last + pad, frames - 1)
	var out := d.slice(first * ch * 2, (last + 1) * ch * 2)
	var gain := 30000.0 / peak
	for i in out.size() / 2:
		out.encode_s16(i * 2, clampi(int(out.decode_s16(i * 2) * gain), -32768, 32767))
	var r := AudioStreamWAV.new()
	r.format = AudioStreamWAV.FORMAT_16_BITS
	r.mix_rate = w.mix_rate
	r.stereo = w.stereo
	r.data = out
	return r

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), colors.get("black", Color(0.1, 0.1, 0.1)))
	
func save_clip() -> void:
	if clip == null:
		return
	save_fd.current_file = "sound.wav"
	save_fd.popup_centered_ratio(0.8)

func on_save_path(path: String) -> void:
	if clip.save_to_wav(path) != OK:
		push_error("Couldn't save to " + path)
		
func on_load_path(path: String) -> void:
	var w := AudioStreamWAV.load_from_file(path)
	if w == null:
		info.text = "Couldn't load that file."
		return
	clip = w
	info.text = "Loaded %s (%.2f sec). Pick a target and tap Use sound." % [path.get_file(), clip.get_length()]
