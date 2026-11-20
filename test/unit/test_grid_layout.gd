extends "res://test/helpers/sim_case.gd"

## Grid placement judges a spot by what it cuts off, not by the whole room.

const AREA := Rect2i(0, 0, 5, 3)
const DOOR := Vector2i(0, 0)


func _grid() -> Grid:
	return Grid.new(5, 3)


func _cells(a: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in a:
		out.append(c)
	return out


func test_cut_off_lists_unreachable_and_untouchable():
	var g := _grid()
	g.walls[Grid.edge_between(Vector2i(3, 0), Vector2i(4, 0))] = true
	g.walls[Grid.edge_between(Vector2i(3, 1), Vector2i(4, 1))] = true
	g.walls[Grid.edge_between(Vector2i(3, 2), Vector2i(4, 2))] = true
	var out := g.cut_off(DOOR, _cells([Vector2i(4, 1)]), _cells([Vector2i(4, 2)]))
	assert_eq(out.size(), 2)
	assert_false(g.layout_ok(DOOR, _cells([Vector2i(4, 1)]), _cells([])))


func test_broken_room_still_accepts_harmless_block():
	var g := _grid()
	g.walls[Grid.edge_between(Vector2i(3, 0), Vector2i(4, 0))] = true
	g.walls[Grid.edge_between(Vector2i(3, 1), Vector2i(4, 1))] = true
	g.walls[Grid.edge_between(Vector2i(3, 2), Vector2i(4, 2))] = true
	var chef := _cells([Vector2i(4, 1)])
	assert_true(g.can_place_block(Vector2i(1, 2), _cells([]), AREA, DOOR, chef, _cells([])))


func test_block_that_cuts_off_a_seat_is_shut_in():
	var g := _grid()
	g.blocked[Vector2i(1, 0)] = true
	var seat := _cells([Vector2i(2, 0)])
	g.blocked[Vector2i(1, 2)] = true
	assert_eq(g.block_refusal(Vector2i(1, 1), _cells([]), AREA, DOOR, seat, _cells([])), "shut_in")


func test_wall_that_cuts_off_a_seat_is_shut_in():
	var g := _grid()
	for y in [1, 2]:
		g.walls[Grid.edge_between(Vector2i(0, y), Vector2i(1, y))] = true
	var seat := _cells([Vector2i(4, 0)])
	assert_eq(g.wall_refusal(Vector3i(1, 0, 1), AREA, DOOR, seat, _cells([])), "shut_in")


func test_closed_in_station_does_not_refuse_a_wall_elsewhere():
	var g := _grid()
	var st := Vector2i(4, 1)
	for d in Grid.DIRS:
		g.blocked[st + d] = true
	g.blocked[st] = true
	var touch := _cells([st])
	assert_true(g.can_place_wall(Vector3i(2, 1, 0), AREA, DOOR, _cells([]), touch))
	assert_true(g.cut_off(DOOR, _cells([]), touch).has(st))


func test_off_lot_and_taken_codes_change_nothing():
	var g := _grid()
	g.blocked[Vector2i(2, 2)] = true
	g.outside[Vector2i(3, 2)] = true
	var none := _cells([])
	assert_eq(g.block_refusal(Vector2i(9, 9), none, AREA, DOOR, none, none), "off_lot")
	assert_eq(g.block_refusal(Vector2i(3, 2), none, AREA, DOOR, none, none), "off_lot")
	assert_eq(g.block_refusal(Vector2i(2, 2), none, AREA, DOOR, none, none), "taken")
	g.walls[Vector3i(1, 1, 0)] = true
	assert_eq(g.wall_refusal(Vector3i(1, 1, 0), AREA, DOOR, none, none), "taken")
	assert_eq(g.blocked.size(), 1)
	assert_eq(g.walls.size(), 1)


func test_chef_steps_out_only_as_far_as_the_bin():
	var g := Grid.new(8, 5)   # columns 5 and 6 are the pavement; the doorway is (5, 2)
	g.pavement_from = 5
	g.chef_pavement = {Vector2i(5, 2): true, Vector2i(6, 2): true}
	assert_false(g.chef_blocked(Vector2i(4, 4)), "the room is open")
	assert_false(g.chef_blocked(Vector2i(5, 2)), "the doorway")
	assert_false(g.chef_blocked(Vector2i(6, 2)), "the pavement by the bin")
	assert_true(g.chef_blocked(Vector2i(5, 3)), "no further down the pavement")
	assert_true(g.chef_blocked(Vector2i(6, 1)), "nor up the queue line")
	assert_false(g.is_blocked(Vector2i(6, 1)), "guests still use the whole pavement")


func test_pavement_is_never_buildable():
	var g := Grid.new(8, 5)
	g.pavement_from = 5
	g.chef_pavement = {Vector2i(5, 2): true, Vector2i(6, 2): true}
	var room := Rect2i(0, 0, 5, 5)
	assert_eq(g.block_refusal(Vector2i(6, 2), _cells([]), room, Vector2i(5, 2), _cells([]), _cells([])), "off_lot")
