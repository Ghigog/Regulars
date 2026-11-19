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
	game.prep_games._fade_loops({"sizzle_raw": true}, 0.1)
	assert_true(game._sfx.sizzle_raw.playing)
	for i in 30:
		game.prep_games._fade_loops({}, 0.1)
	assert_false(game._sfx.sizzle_raw.playing, "faded out and stopped")


func _door_sounds_playing() -> bool:
	return game._sfx.bell.playing or game._sfx.creaky_door.playing


func test_door_bell_rings_once_as_the_first_guest_comes_through_the_door():
	game.menu_stock.test_kitchen()   # a one-Burger menu, so nobody just browses
	for p in game.town.people:
		p.likes = []
		p.dislikes = []
	var party: Array[Guest] = game.seating.spawn_group([0, 1])
	game.seating._seat_waiting_guests()
	assert_eq(party[0].state, "to_seat")
	assert_false(_door_sounds_playing(), "given a table outside: no bell yet")
	var first_in := false
	for i in 4000:
		for g: Guest in party:
			g.tick(0.05)
		if not first_in and party[0].came_in:
			first_in = true
			assert_true(game._sfx.bell.playing, "bell as the first comes in")
			assert_true(game._sfx.creaky_door.playing, "creak too")
			game._sfx.bell.stop()
			game._sfx.creaky_door.stop()
		if party[0].came_in and party[1].came_in:
			break
	assert_true(party[1].came_in, "the second came in too")
	assert_false(_door_sounds_playing(), "the second did not ring it again")
