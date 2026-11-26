class_name DeskScreen
extends Control
## The desk (PRD 10.3, sections 2 to 5), opened at a desk at night by either chef: a
## wooden desk top with paper on it. Two tabs:
## - Job posts: the posts up, each with its duties, breaks and days off and a Take down
##   button, the staff hired so far, and Write a post. Writing one is a page like naming a
##   menu item: a name, the duties as a checklist under Cooking, Serving and Cleaning (only
##   tools in the room, plus the fixed tasks), breaks 0 to 3 and days off 0 to 2.
## - CVs: the pile, read as a stack. The top CV shows the face, name, post, three skills,
##   the overall rating and the asking wage. Drag it right (or Hire) to hire at the ask,
##   left (or Dismiss) to send them home; Haggle names a lower figure.
## - Staff (PRD 10.4): each hire with face, post, wage, duties, breaks, the week as five
##   boxes (days off crossed), satisfaction (a meter with a face, and a word) and the three
##   skills. Manage opens one hire: tick a duty to offer it (they may name a raise: approve,
##   haggle, withdraw or deny, and they quit), untick to take it off, add a break or a day
##   off, or fire them with or without a day's wage as severance.
## All rules are `Staff`'s (game.staff); this only draws and wires them.
##
## Keys and pad move a highlight between the buttons (`action`), as on the menu screen;
## the mouse and touch press them and drag the CV. Naming: keys type into the name
## field, touch gets the system keyboard, a pad gets a letter grid.

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ '-&"
const GRID_COLS := 10
const DIRS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const SWIPE := 150.0        # how far a CV is dragged before letting go hires or dismisses
const CV_SIZE := Vector2(620, 300)
const DEFAULT_NAME := "Helper"

var game
var hud
var tab := "cvs"           # "cvs", "posts" or "staff"
var note := ""             # what just happened, under the CV ("Mabel wants more.")
var _card: Control
var _content: VBoxContainer
var _frame: Control
var _line: LineEdit
var _draft := {}           # the post being written: {name, duties, breaks, days_off}; {} when not
var _naming := ""          # "", "type" or "grid"
var _name_text := ""
var _offer := -1           # the figure being haggled on the top CV; -1 when not haggling
var _cv_card: Control      # the CV being dragged (or the chosen one)
var _pick := 0             # which CV in the pile the buttons act on
var _drag_from := Vector2.INF
var _targets: Array[Control] = []
var _sel := 0
var _sel_key := ""
var _person := -1          # the hire being managed on the staff tab; -1 for the list
var _raise_offer := -1     # the raise being haggled; -1 when not haggling
var _firing := false       # the fire buttons are out (with or without severance)
var _scroll: ScrollContainer
var pages := DeskPages.new(self)   # 
var posting := DeskPosting.new(self)   # 
var staff_ui := DeskStaff.new(self)   # 


func setup(game_, hud_) -> void:
	game = game_
	hud = hud_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Hud.SHADOW, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(mid)
	_card = HudWidgets.Sheet.new("wood", 30, 26)
	_card.custom_minimum_size = Vector2(1120, 620)
	mid.add_child(_card)
	var paper := HudWidgets.Sheet.new("paper", 30, 22)
	_card.add_child(paper)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	paper.add_child(_content)
	_frame = Control.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(pages._draw_frame)
	add_child(_frame)
	if game.staff.cvs.is_empty():
		tab = "staff" if not game.staff.employees.is_empty() else "posts"
	_sel_key = {"cvs": "hire", "posts": "write", "staff": "tab:staff"}[tab]
	pages.render()
	hud.receipt_ui._pop_in(_card)
	_card.pivot_offset = _card.custom_minimum_size / 2.0


func _process(_delta: float) -> void:
	_frame.queue_redraw()


# ---------------------------------------------------------------- input

func action(a: String, echo := false) -> void:
	if echo and not DIRS.has(a):
		return
	if _naming == "type":
		if a == "back":
			posting._finish_name()
		return   # the name field has the keys
	if DIRS.has(a):
		move(DIRS[a])
	elif a == "use" or a == "confirm":
		press()
	elif a == "back":
		back()


func move(dir: Vector2) -> void:
	if _targets.is_empty():
		return
	if tab == "cvs" and _offer < 0 and _draft.is_empty() and (dir == Vector2.UP or dir == Vector2.DOWN) and _move_in_pile(dir == Vector2.DOWN):
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
		if _scroll != null and _scroll.is_ancestor_of(_targets[best]):
			_scroll.ensure_control_visible(_targets[best])
		game.audio.sfx("tick")


## Up and down on the CV tab walk the pile in order: tabs, each CV, then the buttons.
## True when handled.
func _move_in_pile(down: bool) -> bool:
	var n: int = game.staff.cvs.size()
	if n == 0 or _no_key():
		return false
	var key := _sel_key
	if key.begins_with("cv:"):
		var i := int(key.substr(3))
		if down:
			if i + 1 < n:
				_land_on_cv(i + 1)
			else:
				_go("hire")
		elif i > 0:
			_land_on_cv(i - 1)
		else:
			_go("tab:cvs")
		return true
	if down and key.begins_with("tab:"):
		_land_on_cv(_pick)
		return true
	if not down and key in ["dismiss", "haggle", "hire"]:
		_land_on_cv(_pick)
		return true
	return false


func _no_key() -> bool:
	return _sel_key == ""


func _go(key: String) -> void:
	if select(key):
		game.audio.sfx("tick")


## The highlight lands on CV `i`: it becomes the chosen one, and the card scrolls into view.
func _land_on_cv(i: int) -> void:
	if i != _pick:
		_offer = -1
	_pick = i
	_sel_key = "cv:%d" % i
	pages.render()
	if _scroll != null and select(_sel_key):
		_scroll.ensure_control_visible(_targets[_sel])
	game.audio.sfx("tick")


func press() -> void:
	if _targets.is_empty():
		return
	var t := _targets[_sel]
	if t.get_meta("key").begins_with("cv:"):   # A on a CV chooses it and goes to its Hire button
		_pick = int(str(t.get_meta("key")).substr(3))
		_offer = -1
		_sel_key = "hire"
		pages.render()
		return
	var b := _targets[_sel] as Button
	if b != null and not b.disabled:
		b.pressed.emit()


func back() -> void:
	if _naming != "":
		posting._finish_name()
	elif _offer >= 0:
		posting._stop_haggle()
	elif _raise_offer >= 0:
		staff_ui._stop_raise_haggle()
	elif _firing:
		staff_ui._set_firing(false)
	elif _person >= 0:
		staff_ui.close_person()
	elif not _draft.is_empty():
		posting._cancel_post()
	else:
		game.desk.close_desk()


func selected() -> String:
	return _sel_key


func select(key: String) -> bool:
	for i in _targets.size():
		if _targets[i].get_meta("key") == key:
			_sel = i
			_sel_key = key
			return true
	return false


## Dragging a CV: it follows the pointer and leans; let go far enough right to hire,
## left to dismiss, else it springs back (a plain click chooses it).
func _cv_input(event: InputEvent, sheet: Control, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.global_position
			_cv_card = sheet
		elif _drag_from != Vector2.INF:
			var dx: float = event.global_position.x - _drag_from.x
			_drag_from = Vector2.INF
			var changed := index != _pick
			_pick = index
			if dx > SWIPE:
				posting.hire_top()
			elif dx < -SWIPE:
				posting.dismiss_top()
			elif changed:
				_offer = -1
				pages.render()
			else:
				drag_to(0.0)
	elif event is InputEventMouseMotion and _drag_from != Vector2.INF and _cv_card == sheet:
		drag_to(event.global_position.x - _drag_from.x)


## Shows the top CV dragged `dx` pixels across (for the swipe and the demos).
func drag_to(dx: float) -> void:
	if _cv_card == null:
		return
	_cv_card.position.x = (1000 - CV_SIZE.x) / 2.0 + dx
	_cv_card.rotation = clampf(dx / 1600.0, -0.25, 0.25)
	_cv_card.modulate = Color.WHITE.lerp(Color("#d8f5df") if dx > 0 else Color("#f6d6cf"), clampf(absf(dx) / SWIPE, 0.0, 1.0) * 0.8)


# ---------------------------------------------------------------- for tests and demos

## Starts a post with these fields, as if typed and ticked.
func draft_post(post_name: String, duties: Array, breaks := 1, days_off := 1) -> void:
	_draft = {"name": post_name, "duties": duties.duplicate(), "breaks": breaks, "days_off": days_off}
	pages.render()


func drafting() -> Dictionary:
	return _draft


func put_up() -> void:
	posting._put_up()


func start_haggle() -> void:
	posting._start_haggle()


func show_tab(t: String) -> void:
	posting._set_tab(t)


# ---------------------------------------------------------------- pieces

func _count_word(n: int, one: String, many := "") -> String:
	return "%d %s" % [n, one if n == 1 else (many if many != "" else one + "s")]


func _label(parent: Node, px: int, text := "") -> Label:
	var l: Label = hud._label(parent, px, text)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ribbon(parent: Container, text: String) -> void:
	var ribbon := HudWidgets.Sheet.new("ribbon", 30, 6)
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


func _fill(b: Button, inner: Control) -> void:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 5)
	m.add_child(inner)
	b.add_child(m)
	b.custom_minimum_size = Vector2(inner.get_combined_minimum_size().x + 24, inner.get_combined_minimum_size().y + 10)


func _mark(b: Button) -> void:
	for s in ["normal", "hover", "pressed"]:
		var st := b.get_theme_stylebox(s).duplicate() as StyleBoxFlat
		st.border_color = Hud.CORAL
		st.set_border_width_all(4)
		st.bg_color = Color("#fff0dc")
		b.add_theme_stylebox_override(s, st)


## A tick box read by shape: an empty ink square, or the square with a bold coral tick.
class Tick extends Control:
	var on := false

	func _init(on_: bool) -> void:
		on = on_
		custom_minimum_size = Vector2(24, 24)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_rect(r, Hud.CREAM)
		draw_rect(r, Hud.INK, false, 2.5)
		if on:
			var pts := PackedVector2Array([Vector2(5, 12), Vector2(10, 18), Vector2(20, 4)])
			draw_polyline(pts, Hud.INK, 6.0, true)
			draw_polyline(pts, Hud.CORAL, 3.5, true)


## The week as five boxes, day numbers inside: a day off crossed out in bold, the coming
## day ringed. Read by shape: the cross, and the thick ring.
class Week extends Control:
	const BOX := 28.0
	var boxes: Array[Dictionary]
	var today := 0

	func _init(boxes_: Array[Dictionary], today_: int) -> void:
		boxes = boxes_
		today = today_
		custom_minimum_size = Vector2(5 * (BOX + 4), BOX + 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := get_theme_default_font()
		for k in boxes.size():
			var b: Dictionary = boxes[k]
			var r := Rect2(Vector2(2 + k * (BOX + 4), 2), Vector2(BOX, BOX))
			draw_rect(r, Hud.CREAM if not b.off else Color("#efe1cc"))
			draw_rect(r, Hud.INK, false, 3.5 if int(b.day) == today else 1.6)
			var t := str(b.day)
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, r.position + Vector2((BOX - w) / 2.0, BOX / 2.0 + 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				Color(Hud.INK, 0.45 if b.off else 0.9))
			if b.off:
				var a := r.grow(-4)
				for line in [[a.position, a.end], [Vector2(a.end.x, a.position.y), Vector2(a.position.x, a.end.y)]]:
					draw_line(line[0], line[1], Hud.INK, 5.0, true)
					draw_line(line[0], line[1], Hud.CORAL, 3.0, true)


## Satisfaction: a face whose mouth bends from a frown to a smile, then a bar read by its
## length with a notch at the bottom fifth. Colour follows, from coral to green.
class Mood extends Control:
	var value := 0.5

	func _init(value_: float) -> void:
		value = clampf(value_, 0.0, 1.0)
		custom_minimum_size = Vector2(160, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var tint := Hud.CORAL.lerp(Color("#6fae6a"), value)
		var c := Vector2(13, 14)
		draw_circle(c, 12.0, Hud.INK)
		draw_circle(c, 10.0, tint.lightened(0.35))
		draw_circle(c + Vector2(-4, -3), 1.8, Hud.INK)
		draw_circle(c + Vector2(4, -3), 1.8, Hud.INK)
		var bend := (value - 0.5) * 8.0   # down at the ends for a smile, up for a frown
		var mouth := PackedVector2Array()
		for i in 7:
			var x := -5.0 + i * (10.0 / 6.0)
			mouth.append(c + Vector2(x, 4.0 + bend * (1.0 - pow(x / 5.0, 2)) * 0.5))
		draw_polyline(mouth, Hud.INK, 2.2, true)
		var bar := Rect2(Vector2(32, 7), Vector2(size.x - 34, 14))
		draw_rect(bar, Hud.CREAM)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * value, bar.size.y)), tint)
		draw_rect(bar, Hud.INK, false, 2.0)
		var notch := bar.position.x + bar.size.x * Staff.BOTTOM
		draw_line(Vector2(notch, bar.position.y - 3), Vector2(notch, bar.end.y + 3), Hud.INK, 2.0)
