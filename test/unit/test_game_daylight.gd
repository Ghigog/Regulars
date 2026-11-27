extends "res://test/helpers/game_case.gd"
## Service light runs morning, noon, sunset, then dusk into the build phase's night.


func _at(progress: float) -> void:
	game.phase = Game.Phase.SERVICE
	game._night = 0.0
	game.clock = progress * game.day.day_length()
	game.audio._update_daylight()


func test_start_of_service_is_warm_daylight() -> void:
	_at(0.0)
	assert_eq(game.audio.night_amount(), 0.0)
	assert_gt(game._sun.light_color.r, 0.95)
	assert_gt(game._sun.light_color.r, game._sun.light_color.b)


func test_noon_sun_is_near_the_top() -> void:
	_at(0.3)
	assert_gt(game._sun.global_transform.basis.z.y, 0.85, "the light comes from high up")


func test_end_of_service_matches_build_night() -> void:
	_at(1.0)
	assert_eq(game.audio.night_amount(), 1.0)
	var col: Color = game._sun.light_color
	var energy: float = game._sun.light_energy
	game.phase = Game.Phase.BUILD
	game.audio._update_daylight()
	assert_eq(game.audio.night_amount(), 1.0)
	assert_true(col.is_equal_approx(game._sun.light_color))
	assert_almost_eq(energy, game._sun.light_energy, 0.001)
	assert_almost_eq(energy, 0.42, 0.001)


func test_sunset_is_orange_and_not_yet_night() -> void:
	_at(0.75)
	assert_eq(game.audio.night_amount(), 0.0)
	assert_gt(game._sun.light_color.r, game._sun.light_color.b + 0.2)


func test_clock_past_dusk_draws_as_night() -> void:
	var c := HudWidgets.Clock.new()
	c.progress = 0.5
	assert_false(c.is_night())
	c.progress = 0.95
	assert_true(c.is_night())
	c.free()
