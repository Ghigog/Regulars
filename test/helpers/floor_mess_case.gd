extends GutTest
## Shared setup and helpers for the test_floor_mess* test files.


## Unit tests for sim/floor_mess.gd (PRD 9.1).


func _room(w: int = 5, h: int = 5, seed_value: int = 1) -> FloorMess:
	var cells := []
	for y in h:
		for x in w:
			cells.append(Vector2i(x, y))
	return FloorMess.new(cells, seed_value)



# ---------- In the room (PRD 9.2) ----------

func _game():
	var game = load("res://game/main.tscn").instantiate()
	game.first_night = false   # straight into day 1
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])   # keeps the day open
	game.menu_stock.test_kitchen()
	game.floor_dirt.mess.rng.seed = 7
	game.step(0.01)   # the dirt takes the room's floors and furniture
	return game



func _dirty(game, cell: Vector2i, lvl: int) -> void:
	for i in lvl:
		game.floor_dirt.mess.add_dirt(cell)



func _guest_at(game, idx: int, c: Vector2i) -> Guest:
	var g: Guest = game.seating.spawn_guest(idx)
	g.position = Grid.center(c)
	g.cell = c
	g.path.clear()
	g.goal = g.position
	return g



# ---------------------------------------------------------------- 9.4 in the room

## The chef stands at `c` looking along `dir`; returns the cell in front.
func _stand(game, c: Vector2i, dir := Vector2i(0, 1)) -> Vector2i:
	assert_false(game.grid.is_blocked(c), "the test needs open floor at %s" % c)
	game.player.position = Grid.center(c)
	game.player.look(dir)
	return c + dir



func _bucket(game, c: Vector2i) -> Station:
	var st: Station = game.world.add_station("mop_bucket", c)
	game.clean_kit.on_built(st, "mop_bucket")
	game.step(0.01)
	return st



func _wall_cell(game) -> Vector2i:
	for c: Vector2i in game.kitchen.wall_cells:
		if not game.stations.has(c) and game.kitchen.can_hang(c, "shelf"):
			return c
	return Vector2i(-99, -99)



# ---------- 9.5: in the room ----------

func _night(game) -> void:
	game.arrivals.clear()
	game.step(0.1)
	game.session.open_build()
	game.ledger.money = 1000



## A bare counter at a free cell for a box; its cell.
func _shelf_for(game, c := Vector2i(7, 2)) -> Vector2i:
	game.world.add_station("counter", c)
	return c
