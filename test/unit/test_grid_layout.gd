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
	g.blocked[Vector2i(3, 0)] = true   # and both corners
	g.blocked[Vector2i(3, 2)] = true
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


func test_chef_walks_the_open_pavement_but_not_the_kerb_tile():
	var g := Grid.new(8, 5)   # columns 5 and 6 are the open pavement, 7 the kerb tile
	g.pavement_from = 7
	assert_false(g.chef_blocked(Vector2i(4, 4)), "the room is open")
	assert_false(g.chef_blocked(Vector2i(5, 3)), "the near pavement row, down the street")
	assert_false(g.chef_blocked(Vector2i(6, 1)), "the outer row, up the street")
	assert_true(g.chef_blocked(Vector2i(7, 2)), "not the kerb tile")
	assert_false(g.is_blocked(Vector2i(7, 2)), "guests are held only by `outside`")


func test_pavement_is_never_buildable():
	var g := Grid.new(8, 5)
	var room := Rect2i(0, 0, 5, 5)
	assert_eq(g.block_refusal(Vector2i(6, 2), _cells([]), room, Vector2i(5, 2), _cells([]), _cells([])), "off_lot")


func test_reach_stops_at_a_wall_and_passes_a_doorway_or_door():
	var g := Grid.new(6, 5)
	g.walls[Grid.edge_between(Vector2i(2, 2), Vector2i(3, 2))] = true   # a wall column at x = 3
	g.walls[Grid.edge_between(Vector2i(2, 1), Vector2i(3, 1))] = true
	g.walls[Grid.edge_between(Vector2i(2, 3), Vector2i(3, 3))] = true
	assert_false(g.reach_open(Vector2i(2, 2), Vector2i(3, 2)), "straight through a wall")
	assert_false(g.reach_open(Vector2i(2, 2), Vector2i(3, 3)), "diagonally through a wall")
	assert_false(g.reach_open(Vector2i(2, 2), Vector2i(4, 2)), "two away through a wall")
	assert_true(g.reach_open(Vector2i(2, 2), Vector2i(2, 4)), "along the wall")
	g.walls.erase(Grid.edge_between(Vector2i(2, 2), Vector2i(3, 2)))   # a doorway
	assert_true(g.reach_open(Vector2i(2, 2), Vector2i(3, 2)), "through a doorway")
	g.doors[Grid.edge_between(Vector2i(2, 1), Vector2i(3, 1))] = true   # a door edge is no wall
	g.walls.erase(Grid.edge_between(Vector2i(2, 1), Vector2i(3, 1)))
	assert_true(g.reach_open(Vector2i(2, 1), Vector2i(3, 1)), "through a door edge")
	assert_false(g.has_los(Vector2i(2, 1), Vector2i(3, 1)), "sight still stops at the door")


## A station shut on all four sides is still touched from a flooded diagonal cell.
func _diagonal_station(blocked_sides: Array) -> Grid:
	var g := _grid()
	g.blocked[Vector2i(2, 1)] = true
	for c in blocked_sides:
		g.blocked[c] = true
	return g


## Shuts the other diagonals and walls off the corner at (1, 0): nothing reaches (2, 1).
func _close_corner(g: Grid) -> void:
	for c in [Vector2i(3, 0), Vector2i(1, 2), Vector2i(3, 2)]:
		g.blocked[c] = true
	g.walls[Grid.edge_between(Vector2i(1, 0), Vector2i(2, 0))] = true
	g.walls[Grid.edge_between(Vector2i(1, 0), Vector2i(1, 1))] = true


func test_station_open_only_from_a_diagonal_is_not_cut_off():
	var g := _diagonal_station([Vector2i(1, 1), Vector2i(3, 1), Vector2i(2, 0), Vector2i(2, 2)])
	assert_true(g.cut_off(DOOR, _cells([]), _cells([Vector2i(2, 1)])).is_empty())


func test_station_is_cut_off_when_walls_close_both_corner_paths():
	var g := _diagonal_station([Vector2i(1, 1), Vector2i(3, 1), Vector2i(2, 0), Vector2i(2, 2)])
	_close_corner(g)
	assert_true(g.cut_off(DOOR, _cells([]), _cells([Vector2i(2, 1)])).has(Vector2i(2, 1)))


func test_last_orthogonal_side_is_not_shut_in_while_the_diagonal_stays_open():
	var g := _diagonal_station([Vector2i(3, 1), Vector2i(2, 0), Vector2i(2, 2), Vector2i(1, 2)])
	var touch := _cells([Vector2i(2, 1)])
	var side := Vector2i(1, 1)
	assert_eq(g.block_refusal(side, _cells([]), AREA, DOOR, _cells([]), touch), "", "(1, 0) is open")
	g.walls[Grid.edge_between(Vector2i(1, 0), Vector2i(2, 0))] = true
	g.walls[Grid.edge_between(Vector2i(1, 0), Vector2i(1, 1))] = true
	assert_eq(g.block_refusal(side, _cells([]), AREA, DOOR, _cells([]), touch), "shut_in")
