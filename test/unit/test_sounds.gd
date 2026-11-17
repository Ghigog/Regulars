extends GutTest
## The recorded sounds (docs/AUDIO_GUIDE.md): each loads, the stove's loops follow a
## patty's doneness, and order ready is the first three taps only.

var game


func before_each():
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"


func test_every_recorded_sound_loads():
	for id: String in ["grill_drop", "patty_flip", "plate_food", "creaky_door", "sit", "order_ready", "order_take",
			"sizzle_raw", "sizzle_cooking", "sizzle_done", "smoke_warn", "bell", "ding", "burn", "flip"]:
		assert_true(game._sfx.has(id), id)


func test_order_ready_is_short():
	var s: AudioStreamWAV = load("res://assets/sfx/order_ready.wav")
	assert_lt(s.get_length(), 0.85, "three taps, not five")


func test_a_patty_sounds_its_doneness():
	var stove := Station.new()
	game.add_child(stove)
	stove.setup("stove", Vector2i(1, 1), 1)
	assert_eq(stove.sizzle_stage(), "", "nothing on it")
	stove.set_item(Tray.kind("raw", "patty"))
	var tt: Array = stove._times()
	stove.cook = 0.0
	assert_eq(stove.sizzle_stage(), "sizzle_raw")
	stove.cook = (tt[0] + tt[1]) / 2.0
	assert_eq(stove.sizzle_stage(), "sizzle_cooking")
	stove.cook = (tt[1] + tt[2]) / 2.0
	assert_eq(stove.sizzle_stage(), "sizzle_done")
	stove.cook = (tt[2] + tt[3]) / 2.0
	assert_eq(stove.sizzle_stage(), "smoke_warn", "drying out toward burnt")


func test_loops_fade_in_and_out():
	game._fade_loops({"sizzle_raw": true}, 0.1)
	assert_true(game._sfx.sizzle_raw.playing)
	for i in 30:
		game._fade_loops({}, 0.1)
	assert_false(game._sfx.sizzle_raw.playing, "faded out and stopped")
