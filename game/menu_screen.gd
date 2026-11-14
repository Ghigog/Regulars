class_name MenuScreen
extends Control
## The menu screen, opened at night (PRD 1, section 4): a coral-trimmed tent card
## with the menu in three columns (mains, sides, drinks), each item's price as coin
## marks and dollars, and greyed with the reason when it cannot be made tonight.
## Below, tomorrow's stock: a switch per ingredient station and the night's cost.
## Choosing an item (or Add) opens its page: a live picture of the stack, its
## ingredients to reorder or take out, the kitchen's ingredients to add, its name,
## its price level, off tonight and delete.
##
## Keys and pad move a highlight between the buttons (`action`); the mouse and touch
## press them. Naming: keys type into the name field; touch gets the system
## keyboard on the same field; a pad gets a letter grid.

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ '-&"
const GRID_COLS := 10
const DIRS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const LEVEL_WORDS := {"cheap": "Cheap", "fair": "Fair", "dear": "Dear"}

var game
var hud
var _card: Control
var _content: VBoxContainer
var _frame: Control
var _view: Hud.ModelView
var _line: LineEdit
var _edit := {}          # the item open on its page (a menu item, or a draft with id -1); {} on the list
var _named := false      # the item has a name of the player's, so it no longer follows its ingredients
var _naming := ""        # "", "type" (keys and touch: the name field) or "grid" (pad: the letter grid)
var _name_text := ""     # the letter grid's name so far
var _targets: Array[Control] = []
var _sel := 0
var _sel_key := ""


func setup(game_, hud_) -> void:
	game = game_
	hud = hud_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # the room underneath is not clicked through the card
	var dim := ColorRect.new()
	dim.color = Color(Hud.SHADOW, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(mid)
	_card = Hud.Sheet.new("menu", 40, 30)
	_card.custom_minimum_size = Vector2(1120, 600)
	mid.add_child(_card)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_card.add_child(_content)
	_frame = Control.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	render()
	hud._pop_in(_card)
	_card.pivot_offset = _card.custom_minimum_size / 2.0


func _process(delta: float) -> void:
	_frame.queue_redraw()
	if _view != null and is_instance_valid(_view):
		_view.spin.rotate_y(delta * 0.45)


# ---------------------------------------------------------------- drawing

## Rebuilds the card for what is open: the list, or an item's page.
func render() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_targets.clear()
	_view = null
	_line = null
	if _edit.is_empty():
		_list()
	else:
		_page()
	_keys_line()
	_sel = 0
	for i in _targets.size():
		if _targets[i].get_meta("key") == _sel_key:
			_sel = i
	if not _targets.is_empty():
		_sel_key = _targets[_sel].get_meta("key")


func _list() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_content.add_child(top)
	_ribbon(top, "TONIGHT'S MENU")
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(Hud.Icon.new("coins", 34, false))
	var cost: int = game.night_cost()
	var stock := _label(top, 24, "Tomorrow's stock: $%d   (you have $%d)" % [cost, game.ledger.money])
	stock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if cost > game.ledger.money:
		stock.add_theme_color_override("font_color", Hud.CORAL.darkened(0.2))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(cols)
	var stations: Array = game.kitchen_stock()
	var tools: Array = game.kitchen_tools()
	for course in Menu.COURSES:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(330, 300)
		col.add_theme_constant_override("separation", 8)
		cols.add_child(col)
		_label(col, 30, Menu.COURSE_NAMES[course])
		var items: Array[Dictionary] = game.menu.in_course(course)
		for it in items:
			var why := Menu.off_reason(it, stations, tools)
			var b := _paper_button(col, "item:%d" % it.id, _open.bind(it))
			var box := VBoxContainer.new()
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_theme_constant_override("separation", -2)
			_fill(b, box)
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 8)
			box.add_child(row)
			var name := _label(row, 24, it.name)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name.clip_text = true
			row.add_child(_coins(it.price_level, 18))
			_label(row, 24, "$%d" % Menu.price_of(it))
			if why != "":
				row.modulate.a = 0.45
				var note := _label(box, 18, why)
				note.add_theme_color_override("font_color", Hud.CORAL.darkened(0.25))
		if items.is_empty():
			var none := _label(col, 20, "Nothing yet")
			none.modulate.a = 0.5
		var add: Button = hud._button(col, "Add a %s" % course, _new.bind(course))
		_target(add, "add:" + course)
	_rule()
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	_content.add_child(srow)
	_label(srow, 22, "Stock for tomorrow:")
	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 8)
	srow.add_child(chips)
	var types: Array[String] = []
	for st: Station in game.stations.values():
		if Catalog.ingredient_of(st.type) != "" and not types.has(st.type):
			types.append(st.type)
	types.sort()
	for type in types:
		var on: bool = game.stations_of(type)[0].stocked
		var ing := Catalog.ingredient_of(type)
		var ready: bool = Catalog.ITEMS[type].get("ready", false)
		var label := "%s%s  $%d" % [Pantry.name_of(ing), " (ready)" if ready else "", Pantry.fee_of(ing, ready)] if on \
			else "%s: not stocked" % Pantry.name_of(ing)
		var chip := _paper_button(chips, "stock:" + type, _switch.bind(type), label, 20)
		if not on:
			chip.modulate.a = 0.55
	if types.is_empty():
		var none := _label(chips, 20, "No ingredient stations yet: buy them in the shop.")
		none.modulate.a = 0.6
	var done: Button = hud._button(srow, "Done", game.close_menu)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.custom_minimum_size = Vector2(150, 0)
	_target(done, "done")


func _page() -> void:
	var it := _edit
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_content.add_child(top)
	_ribbon(top, {"main": "A MAIN", "side": "A SIDE", "drink": "A DRINK"}[it.course])
	var title := _label(top, 30, it.name if it.name != "" else "(no name yet)")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(body)
	# The picture: the item as it goes out on its tray, turning slowly.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	var inset := Hud.Sheet.new("inset", 6, 6)
	left.add_child(inset)
	_view = Hud.ModelView.new(264, true)
	inset.add_child(_view)
	_show_stack()
	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", 10)
	left.add_child(price)
	if it.ingredients.is_empty():
		_label(price, 22, "Add an ingredient")
	else:
		_label(price, 30, "$%d" % Menu.price_of(it))
		price.add_child(_coins(it.price_level, 24))
	var why := Menu.off_reason(it, game.kitchen_stock(), game.kitchen_tools()) if not it.ingredients.is_empty() else ""
	if why != "":
		var off := _label(left, 20, "Off tonight: " + why)
		off.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		off.add_theme_color_override("font_color", Hud.CORAL.darkened(0.25))
	# What is in it, top first, as it stacks in the picture.
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(340, 0)
	mid.add_theme_constant_override("separation", 6)
	body.add_child(mid)
	_label(mid, 24, "In it, top first (%d of %d)" % [it.ingredients.size(), Menu.MAX_INGREDIENTS])
	var n: int = it.ingredients.size()
	for k in range(n - 1, -1, -1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		mid.add_child(row)
		var l := _label(row, 22, Pantry.name_of(it.ingredients[k]))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if k < n - 1:
			_small(row, "Up", "up:%d" % k, _shift.bind(k, 1))
		else:
			_spacer(row)
		if k > 0:
			_small(row, "Down", "down:%d" % k, _shift.bind(k, -1))
		else:
			_spacer(row)
		_small(row, "Out", "out:%d" % k, _take_out.bind(k))
	if n == 0:
		var hint := _label(mid, 20, "Pick from the kitchen, on the right.")
		hint.modulate.a = 0.6
	# What can go in: the kitchen's ingredients for this course.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	_label(right, 24, "From the kitchen")
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	right.add_child(flow)
	var any := false
	for ing in kitchen_ingredients():
		if Pantry.is_drink(ing) != (it.course == "drink"):
			continue
		any = true
		var b := _paper_button(flow, "add:" + ing, _put_in.bind(ing), "+ " + Pantry.name_of(ing), 20)
		if n >= Menu.MAX_INGREDIENTS:
			b.disabled = true
			b.modulate.a = 0.45
			_targets.erase(b)
	if not any:
		var none := _label(right, 20, "No %s in the kitchen yet: buy one in the shop." % ("drinks" if it.course == "drink" else "food"))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.modulate.a = 0.6
	# Name, price level, off tonight, delete, done.
	_rule()
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 12)
	_content.add_child(nrow)
	_label(nrow, 22, "Name:")
	if _naming == "type":
		_line = LineEdit.new()
		_line.text = it.name
		_line.max_length = Menu.MAX_NAME
		_line.custom_minimum_size = Vector2(360, 0)
		_line.add_theme_font_size_override("font_size", 24)
		_line.placeholder_text = Menu.default_name(it.ingredients) if n > 0 else "A name"
		_line.text_submitted.connect(func(_t: String) -> void: _finish_name())
		_line.editing_toggled.connect(func(on: bool) -> void:
			if not on:
				_finish_name.call_deferred())
		nrow.add_child(_line)
		_focus_line.call_deferred()
	elif _naming == "grid":
		var shown := _label(nrow, 26, _name_text + "_")
		shown.custom_minimum_size = Vector2(360, 0)
	else:
		var nb := _paper_button(nrow, "name", _start_name, (it.name if it.name != "" else "(none)") + "   (rename)", 22)
		nb.custom_minimum_size = Vector2(360, 0)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	nrow.add_child(gap)
	_label(nrow, 22, "Price:")
	for lvl in Menu.LEVELS:
		var b := _paper_button(nrow, "lvl:" + lvl, _set_level.bind(lvl), "", 20)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		_fill(b, row)
		row.add_child(_coins(lvl, 18, false))
		_label(row, 20, LEVEL_WORDS[lvl])
		if lvl == it.price_level:
			_mark(b)
	if _naming == "grid":
		_letter_grid()
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 12)
	_content.add_child(brow)
	var off_b := _paper_button(brow, "off", _toggle_off, "Back on tonight" if it.off else "Off tonight", 20)
	if it.off:
		_mark(off_b)
	if int(it.id) >= 0:
		var del: Button = hud._button(brow, "Delete", _delete)
		del.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		del.custom_minimum_size = Vector2(150, 0)
		_target(del, "delete")
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(space)
	var done: Button = hud._button(brow, "Done", _close_page)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.custom_minimum_size = Vector2(150, 0)
	_target(done, "done")


## The pad's letter grid for the name: letters, space and a few marks, then
## rub out and done.
func _letter_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for i in LETTERS.length():
		var ch := LETTERS[i]
		var b := _paper_button(grid, "L:%d" % i, _type_letter.bind(ch), "Space" if ch == " " else ch, 20)
		b.custom_minimum_size = Vector2(52, 40)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 10)
	_content.add_child(keys)
	var rub := _paper_button(keys, "L:del", _rub_out, "Rub out", 20)
	rub.custom_minimum_size = Vector2(110, 40)
	var done: Button = hud._button(keys, "Keep this name", _finish_name)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.custom_minimum_size = Vector2(200, 40)
	_target(done, "L:done")


func _keys_line() -> void:
	var text := ""
	match hud._mode():
		"keys":
			text = "Arrows choose     E select     Esc back     N close" if _naming != "type" else "Type a name     Enter keep it     Esc keep it"
		"pad":
			text = "D-pad choose     A select     B keep the name" if _naming == "grid" else "D-pad choose     A select     B back     Back close"
	if text != "":
		var l := _label(_content, 16, text)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.7


func _show_stack() -> void:
	if _view == null:
		return
	for c in _view.spin.get_children():
		c.queue_free()
	var t := Tray.new()
	t.assign(-1, [_edit])
	for l in t.lines:
		for k in l.have.size():
			l.have[k] = 1.0
	var n := Build.tray(t)
	n.scale = Vector3.ONE * 2.7
	# Centre the item, not the tray: see where Build.tray puts each course.
	var spot: Vector3 = {"main": Vector3(-0.1, 0, 0), "side": Vector3(0.18, 0, 0.11), "drink": Vector3(0.2, 0, -0.11)}[_edit.course]
	n.position = -spot * n.scale.x + Vector3(0, 0.2, 0)
	_view.spin.add_child(n)


func _draw_frame() -> void:
	if hud._mode() == "touch" or _targets.is_empty() or _naming == "type":
		return
	_sel = clampi(_sel, 0, _targets.size() - 1)
	var t := _targets[_sel]
	if not is_instance_valid(t) or not t.is_visible_in_tree():
		return
	var r := t.get_global_rect().grow_individual(12, 5, 8, 5)
	r.position -= _frame.get_global_rect().position
	Hud.pick_frame(_frame, r)


# ---------------------------------------------------------------- input

## A press from keys or a pad (see Controls). Mouse and touch press the buttons.
func action(a: String, echo := false) -> void:
	if echo and not DIRS.has(a):
		return
	if _naming == "type":
		if a == "back":
			_finish_name()
		return   # the name field has the keys
	if DIRS.has(a):
		move(DIRS[a])
	elif a == "use" or a == "confirm":
		press()
	elif a == "back":
		back()
	elif a == "menu" and _naming == "":
		game.close_menu()


## Moves the highlight to the nearest button that way.
func move(dir: Vector2) -> void:
	if _targets.is_empty():
		return
	var here := _targets[_sel].get_global_rect().get_center()
	var best := -1
	var best_score := INF
	for i in _targets.size():
		var d := _targets[i].get_global_rect().get_center() - here
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		var score := along + absf(d.dot(Vector2(dir.y, -dir.x))) * 3.0
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_sel = best
		_sel_key = _targets[best].get_meta("key")
		game.sfx("tick")


func press() -> void:
	if _targets.is_empty():
		return
	var b := _targets[_sel] as Button
	if b != null and not b.disabled:
		b.pressed.emit()


func back() -> void:
	if _naming != "":
		_finish_name()
	elif not _edit.is_empty():
		_close_page()
	else:
		game.close_menu()


## The highlighted button's key ("item:3", "add:main", "lvl:dear"), for tests.
func selected() -> String:
	return _sel_key


func select(key: String) -> bool:
	for i in _targets.size():
		if _targets[i].get_meta("key") == key:
			_sel = i
			_sel_key = key
			return true
	return false


# ---------------------------------------------------------------- what the buttons do

## The ingredients the kitchen has a station for, stocked or not, in pantry order.
func kitchen_ingredients() -> Array[String]:
	var have := {}
	for s: Dictionary in game.kitchen_stock():
		have[s.ingredient] = true
	var out: Array[String] = []
	for id: String in Pantry.ITEMS:
		if have.has(id):
			out.append(id)
	return out


func _open(it: Dictionary) -> void:
	_edit = it
	_named = it.name != Menu.default_name(it.ingredients)
	_naming = ""
	_sel_key = "done"
	game.sfx("page")
	render()


## A new item: a draft until its first ingredient goes in.
func _new(course: String) -> void:
	_edit = {"id": -1, "name": "", "course": course, "ingredients": [], "price_level": "fair", "off": false}
	_named = false
	_naming = ""
	_sel_key = ""
	game.sfx("page")
	render()
	for ing in kitchen_ingredients():
		if select("add:" + ing):
			break


func _close_page() -> void:
	var was := "item:%d" % _edit.id if int(_edit.get("id", -1)) >= 0 else "add:" + str(_edit.get("course", "main"))
	_edit = {}
	_naming = ""
	_sel_key = was
	game.sfx("page")
	render()


## Changes the open item's ingredients; a draft becomes a menu item with its first.
func _set_ingredients(ings: Array) -> void:
	var it := _edit
	if int(it.id) < 0:
		if ings.is_empty():
			return
		var made: Dictionary = game.menu.add(it.course, ings, it.name if _named else "", it.price_level)
		if made.is_empty():
			return
		made.off = it.off
		_edit = made
	elif ings.is_empty():
		game.menu.remove(int(it.id))   # the last ingredient out: back to a draft
		_edit = {"id": -1, "name": it.name if _named else "", "course": it.course, "ingredients": [],
			"price_level": it.price_level, "off": it.off}
	elif game.menu.set_ingredients(int(it.id), ings):
		if not _named:
			it.name = Menu.default_name(ings)
	_changed()


func _put_in(ing: String) -> void:
	var ings: Array = _edit.ingredients.duplicate()
	ings.append(ing)
	if Menu.refusal(_edit.course, ings) != "":
		game.sfx("fail")
		return
	game.sfx("pickup")
	_set_ingredients(ings)


func _take_out(k: int) -> void:
	var ings: Array = _edit.ingredients.duplicate()
	ings.remove_at(k)
	game.sfx("putdown")
	_set_ingredients(ings)
	if not select("out:%d" % mini(k, ings.size() - 1)):
		select("done")


## Moves ingredient k up (+1, toward the top) or down (-1) the stack.
func _shift(k: int, by: int) -> void:
	var ings: Array = _edit.ingredients.duplicate()
	var j := k + by
	if j < 0 or j >= ings.size():
		return
	var tmp = ings[k]
	ings[k] = ings[j]
	ings[j] = tmp
	game.sfx("tick")
	_set_ingredients(ings)
	if not select("%s:%d" % ["up" if by > 0 else "down", j]):
		select("out:%d" % j)


func _set_level(lvl: String) -> void:
	_edit.price_level = lvl
	game.sfx("coin")
	_changed()


func _toggle_off() -> void:
	_edit.off = not _edit.off
	game.sfx("flip")
	_changed()


func _delete() -> void:
	if int(_edit.id) >= 0:
		game.menu.remove(int(_edit.id))
	var course: String = _edit.course
	_edit = {}
	_sel_key = "add:" + course
	game.sfx("rip")
	_changed()


func _switch(type: String) -> void:
	var st: Array = game.stations_of(type)
	if not st.is_empty():
		game.set_stocked(type, not (st[0] as Station).stocked)
	render()


func _start_name() -> void:
	_naming = "grid" if hud._mode() == "pad" else "type"
	_name_text = _edit.name
	_sel_key = "L:0"
	game.sfx("page")
	render()


func _focus_line() -> void:
	if _line != null and is_instance_valid(_line):
		_line.grab_focus()
		_line.edit()
		_line.caret_column = _line.text.length()


func _type_letter(ch: String) -> void:
	if _name_text.length() < Menu.MAX_NAME:
		_name_text += ch if _name_text.length() == 0 or _name_text.ends_with(" ") else ch.to_lower()
		game.sfx("tick")
		render()


func _rub_out() -> void:
	_name_text = _name_text.substr(0, maxi(0, _name_text.length() - 1))
	game.sfx("tick")
	render()


## Keeps the name typed (an empty one goes back to the made-up name).
func _finish_name() -> void:
	if _naming == "":
		return
	var text := _name_text if _naming == "grid" else (_line.text if _line != null and is_instance_valid(_line) else str(_edit.name))
	_naming = ""
	set_name_text(text)
	_sel_key = "name"
	render()


## Names the open item: the player's own name, or "" for the made-up one.
func set_name_text(text: String) -> void:
	var clean := text.strip_edges().substr(0, Menu.MAX_NAME)
	_named = clean != ""
	if int(_edit.id) >= 0:
		game.menu.rename(int(_edit.id), clean)
	else:
		_edit.name = clean
	game.menu_changed()


func _changed() -> void:
	game.menu_changed()
	render()


## Opens an item's page, or a new one for a course, for tests and demos.
func open_item(it: Dictionary) -> void:
	_open(it)


func new_item(course: String) -> void:
	_new(course)


func put_in(ing: String) -> void:
	_put_in(ing)


func start_naming(mode := "") -> void:
	_start_name()
	if mode != "":
		_naming = mode
		render()


func editing() -> Dictionary:
	return _edit


func naming() -> String:
	return _naming


# ---------------------------------------------------------------- pieces

func _label(parent: Node, px: int, text := "") -> Label:
	return hud._label(parent, px, text)


func _ribbon(parent: Container, text: String) -> void:
	var ribbon := Hud.Sheet.new("ribbon", 30, 6)
	ribbon.tint = Hud.CORAL
	ribbon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(ribbon)
	var l := _label(ribbon, 26, text)
	l.add_theme_color_override("font_color", Hud.CREAM)


func _rule() -> void:
	var line := ColorRect.new()
	line.color = Color(Hud.INK, 0.25)
	line.custom_minimum_size = Vector2(0, 2)
	_content.add_child(line)


func _target(b: Control, key: String) -> void:
	b.set_meta("key", key)
	_targets.append(b)


## A cream paper button with ink lettering, for items, chips and choices.
func _paper_button(parent: Node, key: String, on_press: Callable, text := "", px := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", px)
	for s in ["normal", "hover", "pressed", "disabled"]:
		var st := Hud._flat(Hud.CREAM if s != "hover" else Hud.CREAM.darkened(0.04), 8, 8)
		st.border_color = Color(Hud.INK, 0.55)
		st.set_border_width_all(2)
		st.content_margin_left = 12
		st.content_margin_right = 12
		b.add_theme_stylebox_override(s, st)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Hud.INK)
	b.pressed.connect(on_press)
	parent.add_child(b)
	_target(b, key)
	return b


## Puts a layout inside a button, sizing the button to it.
func _fill(b: Button, inner: Control) -> void:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	m.add_child(inner)
	b.add_child(m)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, inner.get_combined_minimum_size().y + 12)
	inner.minimum_size_changed.connect(func() -> void:
		b.custom_minimum_size = Vector2(maxf(b.custom_minimum_size.x, inner.get_combined_minimum_size().x + 24), inner.get_combined_minimum_size().y + 12))
	b.custom_minimum_size = Vector2(inner.get_combined_minimum_size().x + 24, inner.get_combined_minimum_size().y + 12)


## The chosen one of a set: a coral rim.
func _mark(b: Button) -> void:
	for s in ["normal", "hover", "pressed"]:
		var st := b.get_theme_stylebox(s).duplicate() as StyleBoxFlat
		st.border_color = Hud.CORAL
		st.set_border_width_all(4)
		st.bg_color = Color("#fff0dc")
		b.add_theme_stylebox_override(s, st)


func _small(row: HBoxContainer, text: String, key: String, on_press: Callable) -> void:
	var b := _paper_button(row, key, on_press, text, 18)
	b.custom_minimum_size = Vector2(66, 0)


func _spacer(row: HBoxContainer) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(66, 0)
	row.add_child(c)


## One, two or three coin marks for a price level, the rest faint, so the level
## reads by count and not only by colour.
static func _coins(level: String, px: int, faint := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", -px / 5)
	var n := Menu.LEVELS.find(level) + 1
	for i in (3 if faint else n):
		var c := Hud.Icon.new("coin", px, false)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if i >= n:
			c.modulate.a = 0.22
		row.add_child(c)
	return row


# ---------------------------------------------------------------- the build-phase notes

## Taped above the build slip: night zero's hint, one at a time, and the restock
## note with tomorrow's total. A click or tap on the restock note lists its lines;
## it turns coral and says so when the stock cannot be paid.
class BuildNotes extends HBoxContainer:
	var game
	var hud
	var open := false
	var _hint: Hud.Sheet
	var _hint_label: Label
	var _restock: Hud.Sheet
	var _box: VBoxContainer

	func _init(game_, hud_) -> void:
		game = game_
		hud = hud_
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		alignment = BoxContainer.ALIGNMENT_CENTER
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_theme_constant_override("separation", 18)
		_hint = Hud.Sheet.new("note").pad(16, 10, 18, 8)
		_hint.rotation = 0.02
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_hint)
		_hint_label = hud._label(_hint, 22)
		_restock = Hud.Sheet.new("label").pad(14, 8, 14, 8)
		_restock.mouse_filter = Control.MOUSE_FILTER_STOP
		_restock.size_flags_vertical = Control.SIZE_SHRINK_END
		_restock.gui_input.connect(_clicked)
		add_child(_restock)
		_box = VBoxContainer.new()
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_theme_constant_override("separation", 0)
		_restock.add_child(_box)

	func _clicked(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			open = not open
			game.sfx("rustle")
			refresh()
			accept_event()

	func refresh() -> void:
		var hint: String = game.night_hint()
		_hint.visible = hint != ""
		_hint_label.text = hint
		for c in _box.get_children():
			c.free()   # nothing in the note is mid-signal: the click lands on the note itself
		var cost: int = game.night_cost()
		var short: bool = cost > game.ledger.money
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_theme_constant_override("separation", 8)
		_box.add_child(head)
		head.add_child(Hud.Icon.new("coins", 26, false))
		var t: Label = hud._label(head, 21, "Tomorrow's stock: $%d" % cost)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var more: Label = hud._label(head, 16, "less" if open else "more")
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.modulate.a = 0.55
		if open:
			var lines: Array[Dictionary] = game.stock_lines()
			for l in lines:
				var row := HBoxContainer.new()
				row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_box.add_child(row)
				var n: Label = hud._label(row, 18, str(l.name))
				n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hud._label(row, 18, "$%d" % int(l.fee))
			if lines.is_empty():
				hud._label(_box, 18, "Nothing stocked yet").modulate.a = 0.6
		if short:
			var warn: Label = hud._label(_box, 18, "You can't pay it: the door won't open.")
			warn.add_theme_color_override("font_color", Hud.CORAL.darkened(0.25))
		_restock.modulate = Color(1, 0.86, 0.82) if short else Color.WHITE
