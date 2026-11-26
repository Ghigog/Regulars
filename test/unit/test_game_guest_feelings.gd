extends "res://test/helpers/game_case.gd"
## What a guest's disgust is recorded against, and how they react to it.


func _seated() -> Guest:
	game.stations.erase(Vector2i(0, 5))
	var g: Guest = game.seating.spawn_guest(2)
	_run(12.0)
	return g


func test_a_dirty_plate_is_recorded_as_the_cause_and_faced():
	var g := _seated()
	var other: Station = game.stations[Vector2i(6, 5)] if g.table.cell != Vector2i(6, 5) else game.stations[Vector2i(6, 1)]
	other.dirty = 1
	other.dirty_age = 60.0
	other.refresh()
	g.mood.disgust = 0.2   # just short of Disgusted
	_run(1.0)
	assert_eq(g.disgust_from.get("kind"), "plate")
	assert_eq(g.disgust_from.get("cell"), other.cell)
	g.mood.disgust = 0.9
	g._refresh(0.1)
	assert_gt(g._glance_time, 0.0, "they glance at it")


func test_smell_shows_the_stink_bubble():
	var g := _seated()
	g.note_disgust(g.cell, "smell")
	g.mood.disgust = 0.9
	g._refresh(0.1)
	assert_eq(g._gross_bubble.get_meta("icon"), "stink")
	assert_gt(g.mood.disgust_level(), 0)


func test_impatience_alone_records_no_disgust():
	var g := _seated()
	g.mood.patience = 0.1
	_run(0.5)
	assert_true(g.disgust_from.is_empty())
	assert_eq(g.mood.feelings().disgust, 0)
	assert_gt(g.mood.feelings().anger, 0.0)
