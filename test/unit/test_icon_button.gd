extends GutTest
## The paper-and-wood icon button and the icons made for it.

const NEW_ICONS := ["shop", "dishes", "cog", "back", "sell", "erase", "turn", "aim", "use", "basket"]


func _click(b: IconButton, pos := Vector2(20, 20)) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = pos
		b._gui_input(e)


func _button(key := "Tab") -> IconButton:
	var b := IconButton.new("shop", key)
	add_child_autofree(b)
	return b


func test_every_new_icon_builds_layers():
	for id: String in NEW_ICONS:
		var layers := Icons.icon(id)
		assert_gt(layers.size(), 0, id + " has layers")
		for l: Array in layers:
			assert_gte(l[0].size(), 3, id + " layer is a polygon")


func test_every_new_icon_layer_triangulates():
	for id: String in NEW_ICONS:
		for l: Array in Icons.icon(id):
			assert_gt(Geometry2D.triangulate_polygon(l[0]).size(), 0, id + " layer fills")


func test_new_icons_are_distinct():
	var seen := {}
	for id: String in NEW_ICONS:
		var sig := str(Icons.icon(id))
		assert_false(seen.has(sig), id + " differs from the others")
		seen[sig] = true


func test_keycap_shows_key_and_hides_on_touch():
	var b := _button("Tab")
	assert_true(b.key_shown())
	assert_gte(b.disc_width(), 64.0)
	b.set_touch(true)
	assert_false(b.key_shown(), "no tab on touch")
	assert_gte(b.disc_width(), 88.0)
	assert_gte(b.size.x, 88.0)
	b.set_touch(false)
	assert_true(b.key_shown())
	b.set_key("")
	assert_false(b.key_shown(), "empty key hides the tab")


func test_left_click_emits_pressed_once():
	var b := _button()
	watch_signals(b)
	_click(b)
	assert_signal_emit_count(b, "pressed", 1)


func test_blocked_button_still_emits_on_release():
	var b := _button()
	b.set_blocked(true)
	watch_signals(b)
	_click(b)
	assert_signal_emit_count(b, "pressed", 1)


func test_press_plays_thump():
	var b := _button()
	var heard := []
	b.sfx = func(id: String) -> void: heard.append(id)
	_click(b)
	assert_eq(heard, ["thump"])
