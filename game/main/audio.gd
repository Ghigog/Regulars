class_name GameAudio
extends RefCounted
## Sound and feedback: sound effects and music, buses and volumes, bursts, camera shake,
## tilt-shift, daylight and floating popups.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- sound & feedback

func _load_sounds() -> void:
	for id: String in Game.SOUNDS:
		var path := "res://assets/sfx/%s.wav" % id
		if not ResourceLoader.exists(path):
			continue
		var p := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load(path)
		if Game.LOOPING.has(id):
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / (2 * (2 if stream.stereo else 1))   # 16-bit frames
		else:
			p.max_polyphony = 4
		p.volume_db = Game.SOUNDS[id]
		p.bus = _bus("Sfx")
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.stream = stream
		game.add_child(p)
		game._sfx[id] = p


## Cross-fades to a track from MUSIC. "closed" plays once; the others loop.
func play_music(id: String) -> void:
	if id == game.music_id:
		return
	game.music_id = id
	if game._music:
		var old := game._music
		var out := old.create_tween()
		out.tween_property(old, "volume_db", -50.0, Game.MUSIC_FADE)
		out.tween_callback(old.queue_free)
		game._music = null
	var path := "res://assets/music/%s.mp3" % Game.MUSIC.get(id, "")
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStreamMP3 = load(path).duplicate()
	stream.loop = id != "closed"
	game._music = AudioStreamPlayer.new()
	game._music.bus = _bus("Music")
	game._music.process_mode = Node.PROCESS_MODE_ALWAYS
	game._music.stream = stream
	game._music.volume_db = -50.0
	game.add_child(game._music)
	game._music.play()
	game._music.create_tween().tween_property(game._music, "volume_db", Game.MUSIC_DB, Game.MUSIC_FADE)


## The name of an audio bus, made on first use and sent to the master bus.
func _bus(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var at := AudioServer.bus_count - 1
		AudioServer.set_bus_name(at, bus_name)
		AudioServer.set_bus_send(at, "Master")
	return bus_name


## Volumes from the options screen, 0 to 1 each.
func set_volumes(sfx_level: float, music_level: float) -> void:
	for pair: Array in [["Sfx", sfx_level], ["Music", music_level]]:
		var at := AudioServer.get_bus_index(_bus(pair[0]))
		AudioServer.set_bus_mute(at, pair[1] <= 0.001)
		AudioServer.set_bus_volume_db(at, linear_to_db(maxf(pair[1], 0.001)))


## Plays a sound with a little random pitch so repeats do not sound identical.
## Someone comes in: the shop bell and, under it, the door's creak.
func door_bell() -> void:
	sfx("bell")
	sfx("creaky_door")


func sfx(id: String, vary := 0.06, pitch := 1.0) -> void:
	if game._sfx.has(id):
		game._sfx[id].pitch_scale = pitch * randf_range(1.0 - vary, 1.0 + vary)
		game._sfx[id].play()


## A four-frame cut-out effect in the world: stars, bubbles, wisps, anger...
func burst(at: Vector3, id: String, size := 0.45) -> void:
	Fx.play(game, id, at, size).drift = Vector3(0, 0.5, 0)


func shake(amount := 0.12) -> void:
	var tw := game.cam.create_tween()
	for i in 5:
		tw.tween_property(game.cam, "h_offset", randf_range(-amount, amount), 0.04)
	tw.tween_property(game.cam, "h_offset", 0.0, 0.05)


## Tilt-shift on: a sharp band across the screen, soft above and below, and richer colour, like a close-up photo of
## a model. Off: everything sharp.
func set_tilt_shift(on: bool) -> void:
	game._lens.visible = on
	game._env.adjustment_saturation = 1.16 if on else 1.05
	game._env.adjustment_contrast = 1.06 if on else 1.0


## Morning light drifts to a warm, low evening sun as the day goes on.
func _update_daylight() -> void:
	var t := smoothstep(0.35, 1.0, game.day.day_progress())
	game._sun.light_color = Color("#fff3e2").lerp(Color("#ffb27c"), t)  # ends in an orange sunset
	var p := game.day.day_progress()
	# East is the right of the screen and west is the left, so shadows run across
	# the picture: leftward in the morning, rightward by evening. The arc leans a
	# little toward the camera so the faces we see are lit at midday.
	game._night = move_toward(game._night, 1.0 if game.phase == Game.Phase.BUILD else 0.0, game.get_process_delta_time() * 0.7)
	var n := smoothstep(0.0, 1.0, game._night)  # 0 by day, 1 in the calm of the night: moonlight and lamps
	var arc := deg_to_rad(lerpf(lerpf(24.0, 156.0, p), 128.0, n))
	var east := Vector3(1, 0, -1).normalized()
	var over := Vector3(0, 1, 0).rotated(east, deg_to_rad(Game.SUN_LEAN))
	var from := east * cos(arc) + over * sin(arc)
	game._sun.basis = Basis.looking_at(-from)
	game._sun.light_color = game._sun.light_color.lerp(Color("#a9bdff"), n)  # cool silver moonlight
	game._env.background_color = Color(Scenery.t().backdrop).lerp(Color("#d9c9cc"), t).lerp(Color("#161b34"), n)
	game._env.ambient_light_color = Color("#ece0dc").lerp(Color("#d9bfd0"), t).lerp(Color("#6f80b8"), n)  # deep blue shade
	game._env.ambient_light_energy = lerpf(0.62, 0.5, n)
	game._env.tonemap_exposure = lerpf(1.12, 1.0, n)
	game._sun.light_energy = lerpf(lerpf(Game.SUN_ENERGY.x, Game.SUN_ENERGY.y, t), 0.42, n)
	for l in game._sconces:  # practical lights come up as the sun goes down, and glow warm all night
		l.light_energy = float(l.get_meta("full", 0.45)) * lerpf(lerpf(0.35, 1.0, t), 1.7, n)


func popup(text: String, at: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.outline_size = 20
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_modulate = Color(Build.PAPER)
	l.position = at
	game.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", at.y + 1.3, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)
