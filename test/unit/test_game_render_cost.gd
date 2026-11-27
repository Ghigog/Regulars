extends "res://test/helpers/game_case.gd"
## Render cost: a 3D preview renders each frame only while its model moves.


func _views(node: Node, out: Array) -> Array:
	for c in node.get_children():
		if c is HudWidgets.ModelView:
			out.append(c)
		_views(c, out)
	return out


func _always(views: Array) -> int:
	var n := 0
	for v in views:
		if v.vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			n += 1
	return n


func _counts() -> Array:
	return [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), _sub_viewports(game.get_tree().root)]


func _sub_viewports(node: Node) -> int:
	var n := 1 if node is SubViewport else 0
	for c in node.get_children():
		n += _sub_viewports(c)
	return n


func test_shop_renders_only_the_middle_piece():
	_to_build()
	game.session.open_shop()
	await wait_frames(3)
	game.hud._process(0.016)
	var views := _views(game.hud, [])
	assert_gt(views.size(), 1)
	assert_lte(_always(views), 1, "only the selected piece renders every frame")
	var steady := 0
	for v in views:
		if v.vp.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE:
			steady += 1
	assert_eq(steady, 0, "no shop piece is left rendering whenever visible")


func test_peg_stops_rendering_once_settled():
	var v := HudWidgets.ModelView.new(84, false)
	add_child_autofree(v)
	v.show_peg(game.town.people[0].name)
	assert_eq(v.vp.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	v._process(1.0)
	assert_ne(v.vp.render_target_update_mode, SubViewport.UPDATE_ALWAYS)


func test_menu_card_closed_renders_nothing_and_opening_is_clean():
	_to_build()
	assert_true(game.menu_stock.open_menu())   # one warm-up cycle settles lazy setup
	await wait_frames(2)
	game.hud.close_menu()
	await wait_frames(4)
	var base := _counts()
	for i in 10:
		assert_true(game.menu_stock.open_menu())
		await wait_frames(2)
		game.hud.close_menu()
		await wait_frames(4)
	assert_eq(_always(_views(game.hud, [])), 0)
	var now := _counts()
	assert_lte(now[0], base[0], "no nodes left behind")
	assert_eq(now[1], base[1], "no SubViewports left behind")


func test_shop_open_close_returns_to_baseline():
	_to_build()
	game.session.open_shop()
	await wait_frames(2)
	game.session.close_shop()
	_step_tweens(0.4)
	await wait_frames(1)   # the queue_free lands
	var base := _counts()
	for i in 10:
		game.session.open_shop()
		await wait_frames(2)
		game.session.close_shop()
		_step_tweens(0.4)
		await wait_frames(1)   # the queue_free lands
	var now := _counts()
	assert_lte(now[0], base[0], "no nodes left behind")
	assert_eq(now[1], base[1], "no SubViewports left behind")


func test_3d_scale_caps_pixels_on_large_windows():
	assert_eq(Game.scale_3d_for(Vector2i(1440, 900)), 1.0)
	assert_eq(Game.scale_3d_for(Vector2i(2880, 1800)), 1.0, "a Retina default window is full scale")
	var s := Game.scale_3d_for(Vector2i(5120, 2880))
	assert_lt(s, 1.0)
	assert_lte(5120.0 * 2880.0 * s * s, float(Game.BASE_3D_PIXELS) * 1.001)


func test_3d_mode_is_fsr_below_full_scale_and_bilinear_at_full():
	var win := get_window()
	var old := win.size
	win.size = Vector2i(5120, 2880)
	game._fit_3d()
	assert_eq(game.get_viewport().scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR)
	win.size = Vector2i(1280, 720)
	game._fit_3d()
	assert_eq(game.get_viewport().scaling_3d_scale, 1.0)
	assert_eq(game.get_viewport().scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR)
	win.size = old
