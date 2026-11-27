extends "res://test/helpers/game_case.gd"
## Five stars from the critic win the run; anything less opens the night.

const SAVE := "user://regulars_five_stars_test.json"


func before_each():
	super.before_each()
	game.save_path = SAVE
	SaveGame.write(SaveGame.capture(game), SAVE)
	DirAccess.remove_absolute(game.best_path)


func after_each():
	DirAccess.remove_absolute(SAVE)
	DirAccess.remove_absolute(game.best_path)


func _end_with(rating: int) -> void:
	game.arrivals.clear()
	game._critic_rated = {"walked": false, "ratings": {"speed": rating, "clean": rating, "quality": rating, "variety": rating}}
	game.day._end_day()


func test_five_stars_win_the_run_after_the_receipt() -> void:
	_end_with(5)
	assert_eq(int(game.last_day.review.stars), 5)
	assert_eq(game.phase, game.Phase.SUMMARY, "the receipt shows first")
	game.session.open_build()
	assert_eq(game.phase, game.Phase.CLOSED)
	assert_false(FileAccess.file_exists(SAVE), "the save is gone")
	assert_true(game.day.load_best().has("won"))


func test_four_stars_open_the_night() -> void:
	_end_with(4)
	assert_true(int(game.last_day.review.stars) < 5)
	game.session.open_build()
	assert_eq(game.phase, game.Phase.BUILD)


func test_the_receipt_carries_the_town_rating() -> void:
	_end_with(4)
	assert_eq(game.last_day.points, game.town.sentiment_points())
	assert_eq(game.last_day.tier, Town.tier_for(game.last_day.points))


func test_old_best_file_without_won_still_loads() -> void:
	var f := FileAccess.open(game.best_path, FileAccess.WRITE)
	f.store_string('{"days": 3, "earned": 40}')
	f.close()
	assert_eq(int(game.day.load_best().days), 3)
