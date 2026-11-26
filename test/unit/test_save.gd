extends GutTest
## The saved game (written at the start of the night) and the pause menu.

const SAVE_TEST_PATH := "user://regulars_save_test.dat"
var game


func before_each():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEST_PATH))
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.save_path = SAVE_TEST_PATH


func after_each():
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEST_PATH))


func test_no_save_is_empty():
	assert_true(SaveGame.read(SAVE_TEST_PATH).is_empty())


func test_capture_round_trips_through_the_file():
	game.ledger.money = 321
	game.ledger.day = 4
	game.session.autosave()
	var d := SaveGame.read(SAVE_TEST_PATH)
	assert_false(d.is_empty())
	assert_eq(int(d.ledger.money), 321)
	assert_eq(int(d.ledger.day), 4)
	assert_true(SaveGame.blurb(d).begins_with("Day 4"))
	assert_gt(d.pieces.size(), 0)


func test_restore_rebuilds_the_room():
	game.ledger.money = 77
	game.world.add_station("table", Vector2i(7, 4), 1, 0)
	var data := SaveGame.capture(game)
	var other = load("res://game/main.tscn").instantiate()
	other._resume_data = data
	add_child_autofree(other)
	other.set_process(false)
	assert_eq(other.ledger.money, 77)
	assert_true(other.stations.has(Vector2i(7, 4)))
	assert_eq(other.stations.size(), game.stations.size())
	assert_eq(other.highs.size(), game.highs.size())
	assert_eq(other.phase, other.Phase.BUILD)
	assert_ne(other.paying.till_cell(), other.NO_CELL)


func test_closing_down_deletes_the_save():
	game.session.autosave()
	assert_true(SaveGame.exists(SAVE_TEST_PATH))
	game.day._close_down()
	assert_false(SaveGame.exists(SAVE_TEST_PATH))


func test_pause_menu_opens_and_resumes():
	game.hud.options_ui.toggle_pause()
	assert_true(game.hud.options_ui.pause_open())
	assert_true(get_tree().paused)
	game.coop.act(0, "down")
	assert_eq(game.hud.options_ui.pause.sel, 1)
	game.coop.act(0, "back")
	assert_false(game.hud.options_ui.pause_open())
	assert_false(get_tree().paused)


func test_pause_options_returns_to_pause():
	game.hud.options_ui.toggle_pause()
	game.hud.options_ui.pause.press_id("options")
	assert_true(game.hud.options_ui.options_open())
	game.hud.options_ui.toggle_options()
	assert_true(game.hud.options_ui.pause_open())
	assert_true(get_tree().paused)
	game.hud.options_ui.toggle_pause()


func test_quit_asks_first():
	game.hud.options_ui.toggle_pause()
	game.hud.options_ui.pause.press_id("quit")
	assert_true(game.hud.options_ui.pause.confirming)
	game.hud.options_ui.pause.press_id("no")
	assert_false(game.hud.options_ui.pause.confirming)
	game.hud.options_ui.toggle_pause()


func test_turned_till_round_trips_and_old_saves_face_as_before():
	var till: Node3D = game.stations[Vector2i(4, 2)].get_node("till")
	BuildStations.face_till(till, 3)
	var data := SaveGame.capture(game)
	var other = load("res://game/main.tscn").instantiate()
	other._resume_data = data
	add_child_autofree(other)
	other.set_process(false)
	var back: Node3D = other.stations[Vector2i(4, 2)].get_node("till")
	assert_eq(int(back.get_meta("facing")), 3)
	assert_almost_eq(back.rotation.y, PI / 2 + 3 * PI / 2, 0.001)
	for p: Dictionary in data.pieces:
		p.erase("till_facing")
	var old = load("res://game/main.tscn").instantiate()
	old._resume_data = data
	add_child_autofree(old)
	old.set_process(false)
	assert_almost_eq(old.stations[Vector2i(4, 2)].get_node("till").rotation.y, PI / 2, 0.001)


func test_old_cheese_block_box_becomes_the_cheese_box():
	var data := SaveGame.capture(game)
	var cells: Array = game.kitchen.cells.keys()
	var a: Vector2i = cells[0]
	var b: Vector2i = cells[1]
	data.stock[a] = {"base": ["box_shredded_cheese"], "high": []}
	data.stock[b] = {"base": ["box_cheese", "box_shredded_cheese"], "high": []}
	var other = load("res://game/main.tscn").instantiate()
	other._resume_data = data
	add_child_autofree(other)
	other.set_process(false)
	assert_eq(other.kitchen.take_stock(a).base, ["box_cheese"])
	assert_eq(other.kitchen.take_stock(b).base, ["box_cheese"], "one box of a kind per cell")


func test_an_old_plate_stack_loads_as_a_dish_rack_and_old_rack_cups_go_to_the_cup_stack():
	game.world.add_station("cups", Vector2i(2, 5))
	game.world.add_station("dish_rack", Vector2i(2, 4))
	var data := SaveGame.capture(game)
	for p: Dictionary in data.pieces:
		if p.cell == Vector2i(2, 2):
			p.type = "plates"   # a plate stack, as an old save has it
			p.count = 12
		elif p.cell == Vector2i(2, 4):
			p.count = 4
			p.rack_cups = 2   # an old rack held cups among its dishes
	var other = load("res://game/main.tscn").instantiate()
	other._resume_data = data
	add_child_autofree(other)
	other.set_process(false)
	assert_eq(other.stations[Vector2i(2, 2)].type, "dish_rack", "the plate stack is a rack in the same cell")
	assert_eq(other.stations[Vector2i(2, 2)].count, Station.RACK_CAPACITY, "its plates, capped at what a rack holds")
	assert_eq(other.stations[Vector2i(2, 4)].count, 2, "the old rack keeps only its plates")
	assert_eq(other.stations[Vector2i(2, 5)].count, Station.CUPS + 2, "its cups went to the cup stack")


func _saved_cells() -> Array:
	var cells := []
	for p in SaveGame.read(SAVE_TEST_PATH).pieces:
		cells.append(p.cell)
	return cells


func test_build_quit_saves_changes_made_after_the_night_opened():
	game.phase = Game.Phase.BUILD
	game.session.autosave()
	game.ledger.money -= 55
	game.world.add_station("table", Vector2i(7, 4), 1, 0)
	game.session.save_night()
	var d := SaveGame.read(SAVE_TEST_PATH)
	assert_eq(int(d.ledger.money), game.ledger.money)
	assert_true(_saved_cells().has(Vector2i(7, 4)))


func test_build_quit_puts_a_lifted_piece_back():
	game.phase = Game.Phase.BUILD
	var c := Vector2i(7, 4)
	game.world.add_station("table", c, 1, 0)
	game.placing.pick_up(Grid.center(c), game.player)
	assert_true(game.player.hand.get("moving", false), "the table is lifted")
	game.session.save_night()
	assert_true(game.player.hand.is_empty())
	assert_true(_saved_cells().has(c))


func test_opening_the_door_saves_the_night_as_built():
	game.phase = Game.Phase.BUILD
	game.flyers_out = true
	var fryer := Vector2i(2, 5)
	game.world.add_station("fryer", fryer)
	var moved := Vector2i(7, 4)
	game.world.add_station("table", moved, 1, 0)
	game.placing.pick_up(Grid.center(fryer), game.player)
	var money: int = game.ledger.money
	game.day.start_day()
	assert_eq(game.phase, Game.Phase.SERVICE)
	var d := SaveGame.read(SAVE_TEST_PATH)
	assert_true(_saved_cells().has(moved), "the new table is saved")
	assert_true(_saved_cells().has(fryer), "the lifted fryer is back in its cell")
	assert_eq(int(d.ledger.money), money, "money is from before the stock was paid")
	assert_true(bool(d.flyers_out))
	var other = load("res://game/main.tscn").instantiate()
	other._resume_data = d
	add_child_autofree(other)
	other.set_process(false)
	assert_eq(other.phase, other.Phase.BUILD)
	assert_true(other.stations.has(moved))


func test_service_quit_leaves_the_save_alone():
	game.phase = Game.Phase.BUILD
	game.session.autosave()
	var before := FileAccess.get_file_as_string(SAVE_TEST_PATH)
	game.phase = Game.Phase.SERVICE
	game.ledger.money -= 10
	game.session.save_night()
	assert_eq(FileAccess.get_file_as_string(SAVE_TEST_PATH), before)


func test_pause_quit_label_differs_by_phase():
	game.phase = Game.Phase.BUILD
	game.hud.options_ui.toggle_pause()
	assert_eq(game.hud.options_ui.pause.buttons[2].text, "Save and quit")
	game.hud.options_ui.toggle_pause()
	game.phase = Game.Phase.SERVICE
	game.hud.options_ui.toggle_pause()
	assert_eq(game.hud.options_ui.pause.buttons[2].text, "Quit to title")
	game.hud.options_ui.toggle_pause()


func test_a_post_put_up_tonight_has_no_applicants_after_continue():
	for p in game.town.people:
		p.affinity = 0.5
	game.world.add_station("desk", Vector2i(8, 6))
	game.desk.desk_post("Grill cook", ["grill"], 0, 0)
	var data := SaveGame.capture(game)
	var other = load("res://game/main.tscn").instantiate()
	other._resume_data = data
	add_child_autofree(other)
	other.set_process(false)
	var opened := int(other.staff.posts.values()[0].opened)
	assert_eq(opened, game.ledger.day, "the posting day round-trips")
	for i in 20:
		other.session._open_night()
	assert_true(other.applicants.is_empty())
	assert_true(other.staff.cvs.is_empty())


func test_a_save_from_before_the_warning_key_still_gives_a_headline():
	var data := SaveGame.capture(game)
	for p: Dictionary in data.town.people:
		p.erase("warning")
	var old = load("res://game/main.tscn").instantiate()
	old._resume_data = data
	add_child_autofree(old)
	old.set_process(false)
	for p: Dictionary in old.town.people:
		assert_true(p.has("warning"))
	assert_true(old.town.headline() is String)
