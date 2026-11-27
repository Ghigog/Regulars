class_name BillScreen
extends Control
## The bill screen (PRD 11.3): a paper slip on the till. At the top, the tables waiting to
## pay, by number and party size (the ones at the till marked), as a line to read: the
## slip is for whichever table it is handed to. Below, tonight's menu in its three courses
## with a count beside each item. Use (E, A, a click) adds one; Backspace, X or a right click takes one off.
## "Print" puts the slip in the chef's hand. It never shows what a table ordered: the
## player remembers, or reads the guest card.

const DIRS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

const CARD_W := 400.0

var game
var hud
var chef: Player            # who is writing
var bill := Bill.new()      # the slip so far; it carries no table
var _card: Control
var _content: VBoxContainer
var _frame: Control
var _scroll: ScrollContainer
var _targets: Array[Control] = []
var _sel := 0
var _sel_key := ""


func setup(game_, hud_, chef_: Player) -> void:
	game = game_
	hud = hud_
	chef = chef_
	if chef.held == "bill":
		bill = Bill.new(-1, chef.bill.items.duplicate())   # fix the wrong lines, not start over
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # the room around the slip stays playable
	_card = HudWidgets.Sheet.new("paper", 16, 12)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.offset_right = -22.0   # the cork board's and guest card's margin
	_card.offset_left = -22.0 - CARD_W
	_card.offset_top = Hud.BOARD_Y
	_card.custom_minimum_size = Vector2(CARD_W, 0)
	add_child(_card)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_card.add_child(_content)
	_frame = Control.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	render()
	hud.receipt_ui._pop_in(_card)
	_card.pivot_offset = Vector2(CARD_W, 0)   # grow out of the top-right corner


func _process(_delta: float) -> void:
	_frame.queue_redraw()


func render() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_targets.clear()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_content.add_child(top)
	_ribbon(top, "THE BILL")
	top.add_child(HudWidgets.Icon.new("bill", 24, false))
	var waiting := []
	for t: Dictionary in game.paying.bill_tables():
		waiting.append("Table %d  ·  %d%s" % [t.number, t.size, "  ·  at the till" if t.till else ""])
	if waiting.is_empty():
		_label(_content, 16, "Nobody is waiting to pay").modulate.a = 0.6
	else:
		var w := _label(_content, 16, "Waiting:  " + "     ".join(waiting))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size.x = CARD_W - 32
	_rule()
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(_scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	_scroll.add_child(col)
	var tonight := {}
	for it: Dictionary in game.menu_stock.tonight_menu():
		tonight[int(it.id)] = true
	for course in Menu.COURSES:
		_label(col, 18, Menu.COURSE_NAMES[course])
		var shown := 0
		for it: Dictionary in game.menu.in_course(course):
			if not tonight.has(int(it.id)):
				continue
			shown += 1
			var n := bill.count(int(it.id))
			var b := _button(col, "item:%d" % it.id, _add.bind(int(it.id), 1),
				"%s    x%d" % [it.name, n] if n > 0 else it.name, 16, n > 0)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.gui_input.connect(_item_input.bind(int(it.id)))
		if shown == 0:
			_label(col, 15, "Nothing tonight").modulate.a = 0.5
	_rule()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	_content.add_child(foot)
	var total := _label(foot, 17, "%d on the slip   ·   $%d" % [bill.total_count(), Bill.price(bill, game.menu)])
	total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pr := _button(foot, "print", _print, "Print", 20, true)
	pr.disabled = bill.is_empty()
	_keys_line()
	_cap_height()
	_sel = 0
	for i in _targets.size():
		if _targets[i].get_meta("key") == _sel_key:
			_sel = i
	if _sel_key == "" or _targets[_sel].get_meta("key") != _sel_key:
		select_first_item()
	if not _targets.is_empty():
		_sel_key = _targets[_sel].get_meta("key")


## Caps the item list so the slip never runs past the bottom of the screen; the list scrolls.
func _cap_height() -> void:
	var other := _content.get_combined_minimum_size().y + 24.0
	var list_h: float = _scroll.get_child(0).get_combined_minimum_size().y
	var room := get_viewport_rect().size.y - Hud.BOARD_Y - 16.0 - other
	_scroll.custom_minimum_size.y = minf(list_h, maxf(room, 120.0))


func select_first_item() -> void:
	for i in _targets.size():
		if str(_targets[i].get_meta("key")).begins_with("item:"):
			_sel = i
			return


func _keys_line() -> void:
	var text := ""
	match hud._mode(game.chefs.find(chef)):
		"keys":
			text = "Arrows choose     E add one     Backspace or X take one off     Esc close"
		"pad":
			text = "D-pad choose     A add one     X take one off     B close"
		"touch":
			text = "Tap to add one     Sell takes one off     Back closes"
	var l := _label(_content, 13, text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = CARD_W - 32
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate.a = 0.7


func _draw_frame() -> void:
	if hud._mode(game.chefs.find(chef)) == "touch" or _targets.is_empty():
		return
	_sel = clampi(_sel, 0, _targets.size() - 1)
	var t := _targets[_sel]
	if not is_instance_valid(t) or not t.is_visible_in_tree():
		return
	var r := t.get_global_rect().grow_individual(12, 5, 8, 5)
	r.position -= _frame.get_global_rect().position
	HudOptions.pick_frame(_frame, r)


# ---------------------------------------------------------------- input

func action(a: String, echo := false) -> void:
	if echo and not DIRS.has(a):
		return
	if DIRS.has(a):
		move(DIRS[a])
	elif a == "use" or a == "confirm":
		press()
	elif a == "sell":
		take_one()
	elif a == "back":
		game.paying.close_bill()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_BACKSPACE:
		take_one()
		get_viewport().set_input_as_handled()


func _item_input(event: InputEvent, id: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_add(id, -1)


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
		game.audio.sfx("tick")


func press() -> void:
	if _targets.is_empty():
		return
	var b := _targets[_sel] as Button
	if b != null and not b.disabled:
		b.pressed.emit()


## Takes one of the highlighted item off.
func take_one() -> void:
	var key := str(_sel_key)
	if key.begins_with("item:"):
		_add(int(key.trim_prefix("item:")), -1)


func select(key: String) -> bool:
	for i in _targets.size():
		if _targets[i].get_meta("key") == key:
			_sel = i
			_sel_key = key
			return true
	return false


# ---------------------------------------------------------------- what the buttons do

func _add(id: int, n: int) -> void:
	var before := bill.count(id)
	bill.add(id, n)
	game.audio.sfx("tick" if bill.count(id) != before else "fail")
	_sel_key = "item:%d" % id
	render()


func _print() -> void:
	game.paying.print_bill(chef, bill)


# ---------------------------------------------------------------- pieces

func _label(parent: Node, px: int, text := "") -> Label:
	return hud._label(parent, px, text)


func _ribbon(parent: Container, text: String) -> void:
	var ribbon := HudWidgets.Sheet.new("ribbon", 18, 4)
	ribbon.tint = Hud.CORAL
	ribbon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(ribbon)
	var l := _label(ribbon, 20, text)
	l.add_theme_color_override("font_color", Hud.CREAM)


func _rule() -> void:
	var line := ColorRect.new()
	line.color = Color(Hud.INK, 0.25)
	line.custom_minimum_size = Vector2(0, 2)
	_content.add_child(line)


## A cream paper button; `on` gives it a coral border (an item ticked).
func _button(parent: Node, key: String, on_press: Callable, text: String, px: int, on := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", px)
	for s in ["normal", "hover", "pressed", "disabled"]:
		var st := Hud._flat(Hud.CREAM if s != "hover" else Hud.CREAM.darkened(0.04), 8, 8)
		st.border_color = Hud.CORAL if on else Color(Hud.INK, 0.55)
		st.set_border_width_all(4 if on else 2)
		st.content_margin_left = 12
		st.content_margin_right = 12
		b.add_theme_stylebox_override(s, st)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Hud.INK)
	b.pressed.connect(on_press)
	parent.add_child(b)
	b.set_meta("key", key)
	_targets.append(b)
	return b
