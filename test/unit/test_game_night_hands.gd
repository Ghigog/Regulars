extends "res://test/helpers/game_case.gd"
## No taking plates, cups or food in the build phase (EPIC-20).

const LINE := "Plates and food wait for the morning"


func _face_station(st: Station) -> void:
	var c := game.stations.find_key(st) as Vector2i
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		_face(c + d, -d)
		if game.world.station_at(game.player.target_cell()) == st:
			return


func test_the_plate_stack_hands_out_nothing_at_night():
	_to_build()
	var plates: Station = game.world.find_station("plates")
	var count := plates.count
	assert_eq(game.cooking.use_station(plates, true), LINE, "a dry run is the refusal")
	assert_eq(game.cooking.use_station(plates), LINE)
	assert_eq(game.player.held, "")
	assert_eq(plates.count, count)


func test_a_counter_patty_stays_put_at_night():
	_to_build()
	var counter: Station = game.world.find_station("counter")
	counter.set_item(Tray.kind("prep", "patty"), 1.0)
	assert_eq(game.cooking.use_station(counter), LINE)
	assert_eq(game.player.held, "")
	assert_ne(counter.item, "")


func test_the_prompt_at_the_plate_stack_still_moves_furniture():
	_to_build()
	_face_station(game.world.find_station("plates"))
	assert_eq(game.room_edit.build_action(), "Pick up")


func test_clear_table_still_works_at_night():
	_to_build()
	_dirty_table(2)
	_face_table()
	assert_eq(game.room_edit.build_action(), "Clear table")
	game.room_edit.build_interact()
	assert_eq(game.player.held, "dirty_dishes")


func test_service_still_hands_a_plate():
	var plates: Station = game.world.find_station("plates")
	game.cooking.use_station(plates)
	assert_ne(game.player.held, "")
