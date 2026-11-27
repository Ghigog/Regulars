extends GutTest
## A version 1 save (whole seating sets) loads as version 2 pieces.

const PATH := "user://regulars_save_migration_test.dat"


func after_each():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _v1(pieces: Array) -> Dictionary:
	return {"version": 1, "ledger": {}, "plan": {}, "pieces": pieces}


func _set(type_: String, cell: Vector2i, facing: int, tier: int, dirty := 0) -> Dictionary:
	return {"type": type_, "cell": cell, "facing": facing, "tier": tier, "dirty": dirty, "dirty_cups": 0,
		"dirty_age": 0.0, "high": false, "till": false}


func _load(pieces: Array) -> Array:
	SaveGame.write(_v1(pieces), PATH)
	var d := SaveGame.read(PATH)
	assert_eq(int(d.version), 2)
	return d.pieces


func test_each_set_becomes_a_tile_and_its_seats():
	var pieces := _load([
		_set("table", Vector2i(2, 2), 0, 2),
		_set("booth", Vector2i(6, 2), 1, 3),
		_set("table4", Vector2i(10, 2), 0, 1),
		_set("stool", Vector2i(14, 2), 1, 2),
	])
	var tables := TableJoins.tables(pieces)
	assert_eq(tables.size(), 4)
	var seats: Array = []
	for t in tables:
		seats.append(t.seats)
	assert_eq(seats, [2, 2, 4, 1])
	assert_eq(TableJoins.unseated(pieces), [])
	var cells := {}
	for p in pieces:
		cells[p.cell] = p
	assert_eq(cells[Vector2i(1, 2)].type, "chair")
	assert_eq(cells[Vector2i(1, 2)].tier, 2)
	assert_eq(cells[Vector2i(6, 1)].type, "booth_seat")
	assert_eq(cells[Vector2i(6, 1)].tier, 3)
	assert_eq(cells[Vector2i(6, 3)].facing, 3)
	assert_eq(cells[Vector2i(14, 1)].type, "chair")   # a stool turned 1 sat at (0, -1)
	assert_eq(cells[Vector2i(14, 1)].facing, 1)


func test_dirty_plates_stay_on_the_tile():
	var pieces := _load([_set("table", Vector2i(2, 2), 0, 1, 3)])
	for p in pieces:
		if p.type == "table":
			assert_eq(int(p.dirty), 3)
		else:
			assert_eq(int(p.dirty), 0)


func test_version_2_loads_unchanged():
	var d := _v1([_set("chair", Vector2i(1, 1), 0, 1)])
	d.version = 2
	SaveGame.write(d, PATH)
	assert_eq(SaveGame.read(PATH).pieces, d.pieces)
