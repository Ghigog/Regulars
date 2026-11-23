extends "res://test/helpers/game_case.gd"
## Pressing E or clicking on a refused spot says why and dims the prompt (EPIC-3-T3).


func _hold_over(id: String, at: Vector3) -> void:
	game.ledger.money = 500
	game.placing.pick_catalog(id)
	game._demo_hover = at
	game.room_edit._update_ghost()


func test_e_on_a_refused_spot_keeps_the_hand_and_says_why():
	_to_build()
	_hold_over("board", Vector3(3.5, 0, 5.5))   # a tool over bare floor
	game.room_edit.build_interact()
	assert_false(game.hand.is_empty(), "still held")
	assert_eq(game.hud.toast.text, GamePlacing.NEEDS_COUNTER)
	assert_true(game.player.no_mark.get_meta("wobble", null) != null, "the cross wobbles")


func test_click_on_a_refused_spot_says_why():
	_to_build()
	_hold_over("board", Vector3(3.5, 0, 5.5))
	var spot: Vector3i = game.placing.snap(Vector3(3.5, 0, 5.5))
	var why: String = game.placing.place_refusal(spot)
	assert_ne(why, "")
	game.room_edit.refuse(spot, game.player)
	assert_eq(game.hud.toast.text, why)


func test_prompt_is_dimmed_over_a_refused_spot_and_ready_over_a_fitting_one():
	_to_build()
	_hold_over("stove", Vector3(3.5, 0, 5.5))
	var good: bool = game.placing.place_refusal(game.placing.snap(Vector3(3.5, 0, 5.5))) == ""
	game._update_cursor()
	var sheet = game.hud._prompts[0].sheet
	assert_true(good)
	assert_false(sheet.unavailable, "ready over a fitting spot")
	_hold_over("stove", Vector3(4.5, 0, 6.5))
	game._update_cursor()
	assert_eq(game.placing.place_refusal(game.placing.snap(Vector3(4.5, 0, 6.5))), "That would shut someone in")
	assert_true(sheet.unavailable, "dimmed over a refused spot")
	game.hud.day_ui.show_prompt(Vector2(100, 100), "Put down", 0, false)
	assert_true(sheet.unavailable)
	game.hud.day_ui.show_prompt(Vector2(100, 100), "Put down", 0)
	assert_false(sheet.unavailable)


## The mesh positions a station body is built from, to compare a held counter with a standing one.
func _body_shape(root: Node) -> Array:
	var out: Array = []
	for m in root.find_children("*", "MeshInstance3D", true, false):
		out.append(m.position)
	out.sort()
	return out


func _hold_station(cell: Vector2i) -> Station:
	var st: Station = game.stations[cell]
	assert_true(game.placing.pick_up(Grid.center(cell)))
	game._demo_hover = Vector3(3.5, 0, 5.5)
	game.room_edit._update_ghost()
	return st


func test_a_held_pass_counter_is_drawn_with_the_pass_look():
	_to_build()
	var hs := _hold_station(Vector2i(4, 3))
	assert_true(hs.pass_look, "the starting counter is a pass piece")
	var want := Node3D.new()
	BuildStations.station(want, hs.type, hs.tier, hs.base if hs.type == "counter" else "", true, hs.node)
	var plain := Node3D.new()
	BuildStations.station(plain, hs.type, hs.tier, hs.base if hs.type == "counter" else "", false, hs.node)
	assert_ne(_body_shape(want), _body_shape(plain), "the two looks differ")
	assert_eq(_body_shape(game.player.ghost), _body_shape(want))
	want.free()
	plain.free()


func test_a_held_plain_counter_keeps_its_doors():
	_to_build()
	game.ledger.money = 500
	game.placing.pick_catalog("counter")
	game._demo_hover = Vector3(3.5, 0, 5.5)
	game.room_edit._update_ghost()
	var plain := Node3D.new()
	BuildStations.station(plain, "counter", 1, "counter", false, "")
	assert_eq(_body_shape(game.player.ghost), _body_shape(plain))
	plain.free()
