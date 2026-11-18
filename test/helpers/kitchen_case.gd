extends GutTest
## Shared setup and helpers for the test_kitchen* test files.


## Unit tests for PRD 8's kitchen: cells and layers, storage slots, chilled kinds, trees,
## and (8.3) the upgrade trees: buying steps, quality in the minigames, the tree screen.

const C := Vector2i(1, 1)

const W := Vector2i(0, 0)



func _kitchen() -> Kitchen:
	var k := Kitchen.new()
	k.set_wall(W)
	return k



# ---------- In the game ----------

var game



## The test kitchen at night, in the build phase; `night` false keeps it open for
## service, where cooking and the minigames run.
func _game(night := true) -> void:
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	game.menu_stock.test_kitchen()
	if night:
		game.arrivals.clear()   # the day ends at once, into the night
	for i in 2:
		game.step(0.1)
	if night:
		game.session.open_build()
	game.ledger.money = 500
	for person in game.town.people:   # no new random rules in these tests
		person.tolerance = {"food": 3, "service": 3, "clean": 3}
	game.floor_dirt.drops = false



func _at(x: int, z: int) -> Vector3:
	return Grid.center(Vector2i(x, z))



## A board standing on a new counter at (2, 5).
func _board_on_counter() -> Vector2i:
	game.placing.pick_catalog("counter")
	game.placing.place(Vector3i(2, 5, 0))
	game.placing.cancel_hand()
	game.placing.pick_catalog("board")
	game.placing.place(Vector3i(2, 5, 0))
	game.placing.cancel_hand()
	return Vector2i(2, 5)



func _night_zero(theme: String) -> void:
	game = load("res://game/main.tscn").instantiate()
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.session.play()
	game.session.choose_theme(theme)



func _tool_on(id: String, cell: Vector2i) -> Station:
	game.world.add_station("counter", cell)
	return game.world.add_station(id, cell)



## Keeps the grater's speed in its band (holding below the middle, letting go above)
## until the minigame ends.
func _grate() -> void:
	var who: PlayerInput = game.controls.players[0]
	var band := Prep.grate_band(float(game.prep_games.prep_of(0).q))
	while not game.prep_games.prep_of(0).is_empty():
		who.hold("test", "a", "use", float(game.prep_games.prep_of(0).v) < (band.x + band.y) / 2.0)
		game.step(0.02)
	who.hold("test", "a", "use", false)
