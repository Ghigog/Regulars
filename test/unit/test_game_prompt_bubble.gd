extends "res://test/helpers/game_case.gd"
## The prompt bubble: rimmed in its chef's trim colour, about half its former size (T-103).

const BEFORE_SIZE := Vector2(130, 62)   # "[E] COOK", keys mode, measured on main before T-103


func _sheet(p: int) -> Control:
	return game.hud._prompts[p].sheet


func test_rim_is_each_chefs_trim_colour() -> void:
	for p in 2:
		game.hud.day_ui.show_prompt(Vector2(400 + p * 300, 400), "Cook", p)
		assert_eq(_sheet(p).edge, Color(Peg.PLAYER_TRIM[p]))


func test_muted_bubble_keeps_its_player_rim() -> void:
	game.hud.day_ui.show_prompt(Vector2(600, 400), "Put down", 1, false)
	assert_true(_sheet(1).unavailable)
	assert_eq(_sheet(1).edge, Color(Peg.PLAYER_TRIM[1]))


func test_bubble_is_about_half_size() -> void:
	game.hud.day_ui.show_prompt(Vector2(600, 400), "Cook", 0)
	var s := _sheet(0).size
	assert_lte(s.x, BEFORE_SIZE.x * 0.55, str(s))
	assert_lte(s.y, BEFORE_SIZE.y * 0.55, str(s))
