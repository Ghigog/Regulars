extends "res://test/helpers/game_case.gd"
## Building must not leak nodes or redo per-frame work (framerate fell for good once building began).


func _counts() -> Array:
	return [Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT)]


func _frames(n: int) -> void:
	for i in n:
		game._process(0.016)
	await get_tree().process_frame
	await get_tree().process_frame


func _cycle() -> void:
	var ch: Player = game.chefs[0]
	game.ledger.money = 1000
	game.placing.pick_catalog("wall")
	_mouse(Vector3(0.5, 0, 6.0), MOUSE_BUTTON_LEFT, true)
	_mouse(Vector3(3.5, 0, 6.0), MOUSE_BUTTON_LEFT, false)
	game.placing.pick_catalog("floor_tile")
	_mouse(Vector3(0.5, 0, 1.5), MOUSE_BUTTON_LEFT, true)
	_mouse(Vector3(3.5, 0, 0.5), MOUSE_BUTTON_LEFT, false)
	await _frames(2)
	game.placing.pick_catalog("floor_tile")   # a hand with a ghost
	await _frames(2)
	ch.hand = {}   # lift the hand so the ghost clears
	await _frames(2)
	_mouse(Vector3(0.5, 0, 1.5), MOUSE_BUTTON_RIGHT, true)
	_mouse(Vector3(3.5, 0, 0.5), MOUSE_BUTTON_RIGHT, false)
	ch.hand = {}
	game.undo.clear()
	await _frames(2)


func test_build_cycles_do_not_grow_the_scene():
	_to_build()
	game.cam.position = game._frame[0] + game.CAM_OFFSET
	game.cam.size = game._frame[1]
	var seen := []
	for i in 24:
		await _cycle()
		seen.append(_counts())
	var early: Array = seen[7]
	var late: Array = seen[23]
	for k in 3:
		assert_true(late[k] <= early[k] + 10, "monitor %d settles: %s then %s" % [k, early[k], late[k]])


func test_idle_build_frames_rebuild_nothing():
	_to_build()
	var ch: Player = game.chefs[0]
	game.placing.pick_catalog("floor_tile")
	await _frames(3)
	var ghost = ch.ghost
	var tool_ghost = ch.tool_ghost
	var marks := ch.range_marks.get_children()
	var root = game.lot_view._root
	var room = game._room
	var floods: int = game.world.flood_runs
	await _frames(30)
	assert_same(ch.ghost, ghost)
	assert_same(ch.tool_ghost, tool_ghost)
	assert_eq(ch.range_marks.get_children(), marks)
	assert_same(game.lot_view._root, root)
	assert_same(game._room, room)
	assert_eq(game.world.flood_runs, floods, "no door flood while nothing changes")
