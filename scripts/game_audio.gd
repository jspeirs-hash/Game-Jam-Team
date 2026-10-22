extends Node
## Persistent music, ambience and pooled effects across scene changes.
signal cue_played(cue: String)
signal music_changed(track: String)
const UI := preload("res://scripts/ui_factory.gd")
const TRACKS := ["hideout","battle","snow","shadow","credits"]
var settings_path := "user://audio_settings.cfg"
var settings_save_enabled := true
var music_volume := 0.55
var sfx_volume := 0.8
var muted := false
var current_track := ""
var _music: Array[AudioStreamPlayer] = []
var _effects: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _active := 0
var _effect_index := 0
var _fade: Tween
var _cache := {}
var _hover_time := 0
var _save_timer: Timer
var _overlay: Control
var _sound_button: Button
var _music_slider: HSlider
var _sfx_slider: HSlider
var _mute_button: CheckButton

func _ready() -> void:
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0,limiter)
	for bus in ["Music","SFX"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	for i in range(2):
		_music.append(_player("Music", "Music%d" % i))
	for i in range(12):
		_effects.append(_player("SFX", "Effect%d" % i))
	_ambience = _player("SFX","Weather")
	_ambience.volume_db = -17.0
	_voice = _player("SFX","EncounterVoice")
	_load_settings()
	_apply_volumes()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.35
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)
	_build_controls()
	get_tree().node_added.connect(_watch_button)
	_hook_existing(get_tree().root)

func _player(bus: String, label: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.bus = bus
	add_child(player)
	return player

func _stream(path: String, looping := false) -> AudioStream:
	var key := path + (":loop" if looping else "")
	if not _cache.has(key):
		var stream := load(path) as AudioStreamWAV
		if stream == null:
			return null
		if looping:
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		_cache[key] = stream
	return _cache[key]

func music(track: String, seconds := 0.8) -> void:
	if track == current_track and _music[_active].playing:
		return
	if track not in TRACKS:
		return
	if is_instance_valid(_fade):
		_fade.kill()
	var outgoing := _music[_active]
	_active = 1-_active
	var incoming := _music[_active]
	incoming.stop()
	incoming.stream = _stream("res://Audio/Music/%s.wav" % track,true)
	incoming.volume_db = -60.0
	incoming.play()
	current_track = track
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming,"volume_db",0.0,seconds)
	_fade.tween_property(outgoing,"volume_db",-60.0,seconds)
	_fade.finished.connect(outgoing.stop)
	music_changed.emit(track)

func stop_music(seconds := 0.5) -> void:
	if is_instance_valid(_fade):
		_fade.kill()
	current_track = ""
	_fade = create_tween().set_parallel(true)
	for player in _music:
		_fade.tween_property(player,"volume_db",-60.0,seconds)
		_fade.finished.connect(player.stop)
	music_changed.emit("")

func ambience(cue := "") -> void:
	if cue.is_empty():
		_ambience.stop()
		return
	var stream := _stream("res://Audio/SFX/%s.wav" % cue,true)
	if _ambience.stream == stream and _ambience.playing:
		return
	_ambience.stream = stream
	_ambience.play()

func sfx(cue: String, pitch := 1.0) -> void:
	var player := _effects[_effect_index]
	for candidate in _effects:
		if not candidate.playing:
			player = candidate
			break
	_effect_index = (_effect_index+1)%_effects.size()
	player.stop()
	player.stream = _stream("res://Audio/SFX/%s.wav" % cue)
	player.pitch_scale = pitch
	player.volume_db = -16.0 if cue=="dialogue_tick" else -14.0 if cue=="footstep" else -10.0 if cue.ends_with("_signal") else -11.0 if cue=="ui_hover" else -5.0 if cue=="ui_click" else 0.0
	player.play()
	cue_played.emit(cue)

func voice(cue: String) -> void:
	_voice.stop()
	_voice.stream = _stream("res://Audio/SFX/%s.wav" % cue)
	_voice.play()
	cue_played.emit(cue)

func _watch_button(node: Node) -> void:
	if node is BaseButton and not node.has_meta("audio_hooked"):
		node.set_meta("audio_hooked",true)
		node.pressed.connect(func():
			if not node.disabled:
				sfx("ui_click")
		)
		node.mouse_entered.connect(_hover.bind(node))
		node.focus_entered.connect(_hover.bind(node))

func _hook_existing(node: Node) -> void:
	_watch_button(node)
	for child in node.get_children():
		_hook_existing(child)

func _hover(button: BaseButton) -> void:
	var now := Time.get_ticks_msec()
	if not button.disabled and now-_hover_time>100:
		_hover_time = now
		sfx("ui_hover")

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SoundControls"
	layer.layer = 60
	add_child(layer)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(holder)
	_sound_button = UI.button(holder,"Sound",Rect2(-65,12,130,36),"SOUND / F10",12)
	_sound_button.anchor_left = 0.5
	_sound_button.anchor_right = 0.5
	_sound_button.pressed.connect(toggle_settings)
	_overlay = Control.new()
	_overlay.name = "AudioSettings"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0,0.015,0.025,0.85)
	_overlay.add_child(shade)
	var panel := UI.panel(_overlay,"Window",Rect2(-330,-220,660,440))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	UI.label(panel,"Title",Rect2(30,20,600,40),"SOUND SETTINGS",26,UI.GOLD)
	UI.label(panel,"MusicLabel",Rect2(30,85,600,30),"MUSIC",18)
	_music_slider = _slider(panel,"MusicVolume",Vector2(30,130),music_volume)
	UI.label(panel,"SFXLabel",Rect2(30,185,600,30),"SOUND EFFECTS",18)
	_sfx_slider = _slider(panel,"SFXVolume",Vector2(30,230),sfx_volume)
	_music_slider.value_changed.connect(func(value: float):
		music_volume = value/100.0
		_volume_changed()
	)
	_sfx_slider.value_changed.connect(func(value: float):
		sfx_volume = value/100.0
		_volume_changed()
	)
	_sfx_slider.drag_ended.connect(func(_changed: bool): sfx("ui_click"))
	_mute_button = CheckButton.new()
	_mute_button.name = "Mute"
	_mute_button.text = "MUTE ALL"
	_mute_button.position = Vector2(30,294)
	_mute_button.size = Vector2(280,42)
	_mute_button.add_theme_font_override("font",UI.FONT)
	_mute_button.add_theme_font_size_override("font_size",18)
	_mute_button.button_pressed = muted
	panel.add_child(_mute_button)
	_mute_button.toggled.connect(func(value: bool):
		muted = value
		_volume_changed()
	)
	var close := UI.button(panel,"Close",Rect2(360,350,270,60),"CLOSE",18)
	close.pressed.connect(toggle_settings)
	_overlay.hide()

func _slider(parent: Node, label: String, offset: Vector2, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.name = label
	slider.position = offset
	slider.size = Vector2(600,40)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value*100
	slider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slider.add_theme_stylebox_override("slider",UI.style(Color("111e25"),Color("47606a"),1))
	slider.add_theme_stylebox_override("grabber_area",UI.style(UI.GOLD,UI.GOLD,0))
	var image := Image.create(12,20,false,Image.FORMAT_RGBA8)
	image.fill(UI.GOLD)
	image.fill_rect(Rect2i(3,3,6,14),UI.TEXT)
	var thumb := ImageTexture.create_from_image(image)
	slider.add_theme_icon_override("grabber",thumb)
	slider.add_theme_icon_override("grabber_highlight",thumb)
	parent.add_child(slider)
	return slider

func toggle_settings() -> void:
	_overlay.visible = not _overlay.visible
	if _overlay.visible:
		_music_slider.grab_focus()
	else:
		get_viewport().gui_release_focus()

func settings_open() -> bool:
	return is_instance_valid(_overlay) and _overlay.visible

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F10 or (_overlay.visible and event.keycode==KEY_ESCAPE):
			toggle_settings()
			get_viewport().set_input_as_handled()

func _volume_changed() -> void:
	_apply_volumes()
	_save_timer.start()

func _apply_volumes() -> void:
	for entry in [["Music",music_volume],["SFX",sfx_volume]]:
		var index := AudioServer.get_bus_index(entry[0])
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(float(entry[1]),0.0001)))
		AudioServer.set_bus_mute(index,muted or float(entry[1])<=0)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path)==OK:
		music_volume = clampf(float(config.get_value("audio","music",0.55)),0,1)
		sfx_volume = clampf(float(config.get_value("audio","sfx",0.8)),0,1)
		muted = bool(config.get_value("audio","muted",false))

func save_settings() -> void:
	if not settings_save_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("audio","music",music_volume)
	config.set_value("audio","sfx",sfx_volume)
	config.set_value("audio","muted",muted)
	config.save(settings_path)

func _exit_tree() -> void:
	if is_instance_valid(_fade):
		_fade.kill()
	for player in _music + _effects:
		player.stop()
	if is_instance_valid(_ambience):
		_ambience.stop()
	if is_instance_valid(_voice):
		_voice.stop()
