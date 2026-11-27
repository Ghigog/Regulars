extends "res://test/helpers/game_case.gd"
## Box tags belong to a cell's own storage: a piece lifted from under a wall cupboard
## takes none of that cupboard's tags with it.

var A := Vector2i(-99, -99)
var B := Vector2i(-99, -99)


func before_each():
	super.before_each()
	game.phase = Game.Phase.BUILD
	var free: Array[Vector2i] = []
	for c: Vector2i in game.kitchen.wall_cells:
		if not game.stations.has(c) and not game.highs.has(c) and game.kitchen.can_hang(c, "cabinet"):
			free.append(c)
	for c in free:
		if free.has(c + Vector2i(1, 0)):
			A = c
			B = c + Vector2i(1, 0)
			break
	assert_ne(A, Vector2i(-99, -99), "two neighbouring wall cells")
	game.world.add_high("cabinet", A)
	game.world.add_high("cabinet", B)
	game.kitchen.hang(A, "cabinet")
	game.kitchen.hang(B, "cabinet")
	game.kitchen.store(A, "box_roll")
	game.world.add_station("bin", A)
	game.world._show_boxes(A)
	game.world._show_boxes(B)


func _bin_at(c: Vector2i) -> Station:
	return game.stations[c]


func _tags(c: Vector2i) -> Array:
	var out: Array = []
	if game.stations.has(c):
		out.append_array(game.stations[c].boxes)
	if game.highs.has(c):
		out.append_array(game.highs[c].boxes)
	return out


func _lift_bin() -> void:
	assert_true(game.placing.pick_up(Grid.center(A), game.player, false, "base"))


func test_the_bin_moved_to_the_next_cupboard_takes_no_bread_basket_tag():
	_lift_bin()
	assert_true(game.placing.place(Vector3i(B.x, B.y, 0)))
	assert_eq(_tags(A), ["box_roll"], "only the first cupboard shows it")
	assert_eq(_tags(B), [])
	assert_eq(_bin_at(B).boxes, [])
	assert_true(game.kitchen.stock(A).has("box_roll"))
	assert_false(game.kitchen.stock(B).has("box_roll"))


func test_put_back_shows_exactly_one_tag():
	_lift_bin()
	assert_true(game.placing.place(Vector3i(A.x, A.y, 0)))
	assert_eq(_tags(A), ["box_roll"])


func test_undo_of_the_move_leaves_the_tag_only_over_the_first_cell():
	_lift_bin()
	assert_true(game.placing.place(Vector3i(B.x, B.y, 0)))
	assert_true(game.undo.undo())
	assert_true(game.stations.has(A))
	assert_eq(_tags(A), ["box_roll"])
	assert_eq(_tags(B), [])


func test_the_bin_under_a_cupboard_with_its_own_box_names_that_box():
	game.kitchen.store(B, "box_bun")
	_lift_bin()
	assert_true(game.placing.place(Vector3i(B.x, B.y, 0)))
	assert_eq(_bin_at(B).boxes, game.kitchen.stock(B))
	assert_false(_bin_at(B).boxes.has("box_roll"))
	assert_eq(_tags(A), ["box_roll"])
