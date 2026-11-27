extends "res://test/helpers/game_case.gd"
## The Use key beside a prep minigame's gauge: what it should show (key_cue) and its cap.


func _start(tool: String, ing: String, type: String) -> Dictionary:
	var st: Station = game.world.add_station(type, Vector2i(2, 4), 1, 1)
	game.prep_games.start_prep(0, st, tool, ing)
	game.preps[0].frozen = true
	return game.preps[0]


func _hold(on: bool) -> void:
	game.controls.players[0].hold("test", "use", "use", on)


func test_chop_taps_only_in_the_notch():
	var s := _start("chop", "beef", "board")
	s.t = s.sweep * 0.1
	assert_eq(game.prep_games.key_cue(0), "wait")
	s.t = s.sweep * 0.5
	assert_eq(game.prep_games.key_cue(0), "tap")
	s.hits.append(true)   # pressed: nothing more this sweep
	assert_eq(game.prep_games.key_cue(0), "wait")


func test_saw_taps_at_the_stroke_end():
	var s := _start("saw", "beef", "board")
	s.t = s.sweep * 0.3
	assert_eq(game.prep_games.key_cue(0), "wait")
	s.t = s.sweep * 0.95
	assert_eq(game.prep_games.key_cue(0), "tap")


func test_slice_and_blend_mash():
	_start("slice", "beef", "slicer")
	assert_eq(game.prep_games.key_cue(0), "mash")
	game.prep_games.cancel_prep(0)
	_start("blend", "beef", "blender")
	assert_eq(game.prep_games.key_cue(0), "mash")


func test_pour_holds_then_releases():
	var s := _start("pour", "soda", "fountain")
	assert_eq(game.prep_games.key_cue(0), "wait")
	_hold(true)
	s.fill = 0.3
	assert_eq(game.prep_games.key_cue(0), "hold")
	s.fill = 0.9
	assert_eq(game.prep_games.key_cue(0), "release")
	_hold(false)


func test_grate_releases_in_the_band():
	var s := _start("grate", "cheese", "grater")
	s.v = 0.1
	assert_eq(game.prep_games.key_cue(0), "wait")
	s.v = 0.5
	assert_eq(game.prep_games.key_cue(0), "release")


func test_juice_and_steam():
	var s := _start("juice", "lemon", "juicer")
	_hold(true)
	s.fill = 0.2
	assert_eq(game.prep_games.key_cue(0), "hold")
	s.fill = 0.75
	assert_eq(game.prep_games.key_cue(0), "release")
	_hold(false)
	game.prep_games.cancel_prep(0)
	s = _start("steam", "beef", "steamer")
	s.t = 0.0
	assert_eq(game.prep_games.key_cue(0), "wait")
	s.t = Prep.steam_time(s.q) * 0.65
	assert_eq(game.prep_games.key_cue(0), "release")


func test_auto_pieces_show_no_key():
	var s := _start("chop", "beef", "board")
	s.auto = true
	s.t = s.sweep * 0.5
	assert_eq(game.prep_games.key_cue(0), "")
	game._process(0.0)
	assert_false(game.hud.prep_key_ui.caps.has(0))


func test_cap_follows_the_device_and_goes_with_the_minigame():
	var s := _start("chop", "beef", "board")
	game.hud.prep_key_ui.update()
	var d: Dictionary = game.hud.prep_key_ui.caps[0]
	assert_eq(d.label.text, game.controls.glyph("use", 0))
	game.controls.set_mode("touch")
	game.hud.prep_key_ui.update()
	assert_eq(d.label.text, game.controls.glyph("use", 0))
	assert_eq(d.label.text, "Use")
	game.controls.set_mode("pad")
	game.hud.prep_key_ui.update()
	assert_eq(d.label.text, game.controls.glyph("use", 0))
	game.prep_games.cancel_prep(0)
	game.hud.prep_key_ui.update()
	assert_false(d.shown)
	assert_eq(game.prep_games.key_cue(0), "")
