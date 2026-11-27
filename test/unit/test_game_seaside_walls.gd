extends "res://test/helpers/game_case.gd"
## Fixed dressing never holds a wall; only a hung piece the player can lift may stop
## floor, and then the refusal names it (T-125).


func _start(theme: String) -> void:
	Scenery.theme_id = theme
	game.world._rebuild_room()
	game.menu_stock.clear_walls()
	game.world._hang_fixtures()   # the start's hood, cabinets and jar shelf
	_to_build()
	game.ledger.money = 1000
	game.placing.pick_catalog("floor_planks")


## Lot cells with no floor that touch the starting floor.
func _edge_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(game.lot.bounds().position.x, game.lot.bounds().end.x):
		for y in range(game.lot.bounds().position.y, game.lot.bounds().end.y):
			var c := Vector2i(x, y)
			if game.plan.can_lay(c, "planks") and not game.plan.has_floor(c):
				out.append(c)
	return out


func _refusals() -> Dictionary:
	var out := {}
	for c in _edge_cells():
		out[c] = game.placing.place_refusal(Vector3i(c.x, c.y, 0))
	return out


func test_seaside_refuses_no_cell_the_diner_accepts_and_only_for_a_liftable_piece():
	_start("diner")
	var diner := _refusals()
	Scenery.theme_id = "seaside"
	game.world._rebuild_room()
	var sea := _refusals()
	assert_gt(diner.size(), 0)
	for c: Vector2i in diner:
		if diner[c] == "":
			assert_eq(sea[c], "", "seaside takes %s as the diner does" % c)
		for why: String in [diner[c], sea[c]]:
			assert_true(why == "" or why.begins_with("Take the "), "%s refused only for a liftable piece, not '%s'" % [c, why])


func test_a_hung_piece_is_named_and_floor_goes_down_once_it_is_lifted():
	for theme in ["diner", "seaside"]:
		after_each()
		before_each()
		_start(theme)
		var named := {}
		var all := _refusals()
		for k: Vector2i in all:
			if all[k] != "":
				named[k] = all[k]
		assert_gt(named.size(), 0, "%s: a hung piece holds some wall" % theme)
		var c: Vector2i = named.keys()[0]
		var why: String = named[c]
		assert_true(why.begins_with("Take the ") and why.ends_with(" down first"), why)
		assert_false(game.room_edit._build_at(Vector3i(c.x, c.y, 0)), "refused while hung")
		# Lift every hung piece, as the player does (boxes come off with clear_walls).
		for h: Vector2i in game.highs.keys():
			game.hand = {}
			assert_true(game.placing.pick_up(Grid.center(h), game.player, false, "high"), "lift at %s" % h)
			game.player.hand = {}
		game.placing.pick_catalog("floor_planks")
		assert_eq(game.placing.place_refusal(Vector3i(c.x, c.y, 0)), "", theme)
		assert_true(game.room_edit._build_at(Vector3i(c.x, c.y, 0)), theme)
		assert_true(game.plan.has_floor(c))


func test_a_wall_with_a_hung_piece_is_still_stranded():
	_start("seaside")
	var cell: Vector2i = game.highs.keys()[0]
	var walls: Array[Vector3i] = game.world._back_walls(cell)
	assert_true(game.world._strands_high(walls))
	assert_true(game.world.strand_refusal(walls).begins_with("Take the "))
