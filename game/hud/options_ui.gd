class_name HudOptions
extends RefCounted
## The options screen (saved to OPTIONS_FILE), the title screen and the pause menu.

var hud: Hud


func _init(hud_: Hud) -> void:
	hud = hud_


# ---------------------------------------------------------------- options

const OPTIONS_FILE := "user://regulars_options.cfg"
static var options_path := OPTIONS_FILE   # tests point this at a temporary file
## walk_learned / stick_learned: the walk keycaps over the chef are retired for good (PRD: teach in place).
var options := {"sfx": 0.8, "music": 0.8, "tilt_shift": true, "walk_learned": false, "stick_learned": false}
var _options_card: Control
var _options_body: VBoxContainer
var _options_tab := "audio"
var _options_tabs := {}
var _options_tab_row: HBoxContainer
var _options_done: Button
var _options_keys: Label         # what the keys do, for keys and pad
var _options_frame: Control       # the highlight round the chosen row (keys and pad)
var _options_rows: Array = []     # what up and down move between, top to bottom
var _options_sel := 0


func load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(options_path) != OK:
		return
	for key: String in options:
		options[key] = cfg.get_value("options", key, options[key])


func save_options() -> void:
	var cfg := ConfigFile.new()
	for key: String in options:
		cfg.set_value("options", key, options[key])
	cfg.save(options_path)


func apply_options() -> void:
	if not is_instance_valid(hud):
		return   # called deferred from Hud.setup; a test may free the hud first
	hud.game.audio.set_volumes(float(options.sfx), float(options.music))
	hud.game.audio.set_tilt_shift(bool(options.tilt_shift))


# ---------------------------------------------------------------- title screen

var title: Title
var _behind_title: Array[Control] = []


func title_open() -> bool:
	return title != null


## Covers the room with the title, hiding the rest of the interface until Play.
## The options screen opens over it (it is added to root after).
func show_title() -> void:
	_behind_title.clear()
	for c in hud.root.get_children():
		if c is Control and c.visible:
			c.visible = false
			_behind_title.append(c)
	title = Title.new()
	title.setup(hud)
	hud.root.add_child(title)


func hide_title() -> void:
	if title == null:
		return
	title.queue_free()
	title = null
	for c in _behind_title:
		c.visible = true
	_behind_title.clear()


func options_open() -> bool:
	return _options_card != null


var pause: PauseMenu


func pause_open() -> bool:
	return pause != null


## Opens or closes the pause menu (Resume, Options, Quit to title). The game stands still
## while it is open. Not on the title screen, which has its own.
func toggle_pause() -> void:
	if pause != null:
		pause.queue_free()
		pause = null
		hud.get_tree().paused = false
		return
	if title != null or hud.game.phase == hud.game.Phase.TITLE:
		return
	hud.get_tree().paused = true
	pause = PauseMenu.new()
	pause.setup(hud)
	hud.root.add_child(pause)


## One action while the options screen is open (see Controls): up and down pick
## a row, left and right turn a slider or switch tabs, use or confirm presses,
## back or options closes. Held browse keys repeat; nothing else does. Returns
## whether the action was used.
func options_action(action: String, echo := false) -> bool:
	match action:
		"up": _options_pick(_options_sel - 1)
		"down": _options_pick(_options_sel + 1)
		"left": _options_turn(-1)
		"right": _options_turn(1)
		_:
			if echo:
				return false
			match action:
				"use", "confirm": _options_press()
				"back", "options": toggle_options()
				_: return false
	return true


## Opens or closes the options screen. The game is paused while it is open.
func toggle_options() -> void:
	if _options_card != null:
		_options_card.queue_free()
		_options_card = null
		_options_rows.clear()
		save_options()
		hud.get_tree().paused = pause != null   # back to the pause menu it was opened from
		return
	hud.get_tree().paused = true
	_options_sel = 0
	_options_card = Control.new()
	_options_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.root.add_child(_options_card)
	var dim := ColorRect.new()
	dim.color = Color(Hud.SHADOW, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_card.add_child(dim)
	var mid := CenterContainer.new()
	mid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_card.add_child(mid)
	var card := HudWidgets.Sheet.new("paper", 30, 24)
	card.custom_minimum_size = Vector2(480, 0)
	mid.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	hud.receipt_ui._ribbon(box, "OPTIONS", Hud.CORAL)
	_options_tab_row = HBoxContainer.new()
	_options_tab_row.add_theme_constant_override("separation", 10)
	box.add_child(_options_tab_row)
	_options_tabs = {
		"audio": hud.receipt_ui._button(_options_tab_row, "Audio", _show_options_tab.bind("audio")),
		"graphics": hud.receipt_ui._button(_options_tab_row, "Graphics", _show_options_tab.bind("graphics")),
	}
	_options_body = VBoxContainer.new()
	_options_body.add_theme_constant_override("separation", 12)
	_options_body.custom_minimum_size = Vector2(0, 96)
	box.add_child(_options_body)
	_options_done = hud.receipt_ui._button(box, "Done", toggle_options)
	_options_keys = hud._label(box, 15)
	_options_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_options_keys.modulate.a = 0.7
	_options_frame = Control.new()
	_options_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_frame.draw.connect(_draw_options_frame)
	_options_card.add_child(_options_frame)
	_show_options_tab(_options_tab)
	hud.receipt_ui._pop_in(card)


## Fills the body for a tab and lists the rows the arrows move between: the
## tabs, each slider or switch, Done. Also sizes everything for the device in
## use, so refresh_input calls it when the player switches.
func _show_options_tab(tab: String) -> void:
	_options_tab = tab
	for id: String in _options_tabs:
		_options_tabs[id].modulate.a = 1.0 if id == tab else 0.55
	for c in _options_body.get_children():
		_options_body.remove_child(c)
		c.queue_free()
	_options_rows = [_options_tab_row]
	if tab == "audio":
		_options_rows.append(_volume_row("Sound effects", "sfx"))
		_options_rows.append(_volume_row("Music", "music"))
	else:
		_options_rows.append(hud.receipt_ui._button(_options_body,
			"Tilt-shift (miniature look):  %s" % ("On" if options.tilt_shift else "Off"), _toggle_tilt_shift))
		var note := hud._label(_options_body, 15, "Blurs the near and far edges so the town looks like a model.")
		note.modulate.a = 0.7
	_options_rows.append(_options_done)
	_options_done.text = "Done" + hud.hints_ui._key_note("back")
	var touch := hud._mode() == "touch"
	_options_keys.visible = not touch
	_options_keys.text = "%s choose and change     %s press     %s close" % [hud._g("browse"), hud._g("use"), hud._g("back")]
	for row: Control in _options_rows:
		if row is Button:
			row.custom_minimum_size.y = 64.0 if touch else 0.0
		row.mouse_filter = Control.MOUSE_FILTER_PASS if row is Container else row.mouse_filter
		if not row.has_meta("picks"):   # the mouse moves the frame too
			row.set_meta("picks", true)
			row.mouse_entered.connect(func() -> void: _options_pick(_options_rows.find(row)))
	for b: Button in _options_tabs.values():
		b.custom_minimum_size.y = 64.0 if touch else 0.0
	_options_pick(_options_sel)


func _toggle_tilt_shift() -> void:
	options.tilt_shift = not options.tilt_shift
	apply_options()
	_show_options_tab("graphics")


func _options_pick(i: int) -> void:
	i = clampi(i, 0, maxi(_options_rows.size() - 1, 0))
	if i != _options_sel and _options_card != null:
		hud.game.audio.sfx("tick")
	_options_sel = i
	if _options_frame:
		_options_frame.queue_redraw()


func _options_row() -> Control:
	return _options_rows[_options_sel] if _options_sel < _options_rows.size() else null


## Left or right: the next tab along, or a slider a notch (a tenth) each way.
func _options_turn(dir: int) -> void:
	var row := _options_row()
	if row == _options_tab_row:
		var ids: Array = _options_tabs.keys()
		var at := ids.find(_options_tab)
		_show_options_tab(ids[posmod(at + dir, ids.size())])
		hud.game.audio.sfx("tab")
	elif row is HBoxContainer:
		var slider: HSlider = row.get_meta("slider")
		slider.value = clampf(snappedf(slider.value + dir * 0.1, 0.05), 0.0, 1.0)


func _options_press() -> void:
	var row := _options_row()
	if row == _options_tab_row:
		_options_turn(1)
	elif row is Button:
		row.pressed.emit()


## Keys and controller only: a heavy ink frame round the chosen row with a
## coral pointer tab on its left, like a marker clipped to the card. Drawn on
## top of the card so it follows the pop-in.
func _draw_options_frame() -> void:
	var row := _options_row()
	if row == null or hud._mode() == "touch":
		return
	var r := row.get_global_rect().grow_individual(14, 6, 10, 6)
	r.position -= _options_frame.get_global_rect().position
	pick_frame(_options_frame, r)


## The keys-and-pad highlight: an ink frame with a coral pointer tab on its left.
static func pick_frame(ci: CanvasItem, r: Rect2) -> void:
	var ink := StyleBoxFlat.new()
	ink.draw_center = false
	ink.border_color = Hud.INK
	ink.set_border_width_all(3)
	ink.set_corner_radius_all(14)
	ci.draw_style_box(ink, r)
	var y := r.get_center().y
	var x := r.position.x
	var tip := PackedVector2Array([Vector2(x - 2, y), Vector2(x - 20, y - 12), Vector2(x - 20, y + 12)])
	ci.draw_colored_polygon(PackedVector2Array([tip[0] + Vector2(0, 3), tip[1] + Vector2(0, 3), tip[2] + Vector2(0, 3)]), Hud.SHADOW)
	ci.draw_colored_polygon(tip, Hud.CORAL)
	ci.draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2], tip[0]]), Hud.INK, 2.5, true)


## A round cream grabber with an ink ring, big enough for a thumb on touch.
static func _grabber(diameter: int) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var c := diameter / 2.0
	for y in diameter:
		for x in diameter:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(c, c))
			var col := Color(Hud.INK)
			if d < c - 3.5:
				col = Color(Hud.CREAM)
			elif d < c - 3.0:
				col = Color(Hud.CREAM).lerp(Hud.INK, (d - (c - 3.5)) * 2.0)
			col.a = clampf(c - d, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _volume_row(title: String, key: String) -> HBoxContainer:
	var touch := hud._mode() == "touch"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_options_body.add_child(row)
	hud._label(row, 20, title).custom_minimum_size = Vector2(170, 0)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(options[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 56.0 if touch else 30.0
	var knob := _grabber(46 if touch else 26)
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(icon, knob)
	slider.focus_mode = Control.FOCUS_NONE   # the arrows are read by options_action instead
	row.add_child(slider)
	row.set_meta("slider", slider)
	var value := hud._label(row, 20, "%d%%" % roundi(slider.value * 100))
	value.custom_minimum_size = Vector2(56, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		options[key] = v
		value.text = "%d%%" % roundi(v * 100)
		apply_options()
		if key == "sfx":
			hud.game.audio.sfx("coin"))
	return row
