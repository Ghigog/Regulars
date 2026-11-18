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
var _cv_card: Control      # the top CV, dragged to swipe
var _drag_from := Vector2.INF
var _targets: Array[Control] = []
var _sel := 0
var _sel_key := ""
var _person := -1          # the hire being managed on the staff tab; -1 for the list
var _raise_offer := -1     # the raise being haggled; -1 when not haggling
var _firing := false       # the fire buttons are out (with or without severance)
var _scroll: ScrollContainer


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
	_card = Hud.Sheet.new("wood", 30, 26)
	_card.custom_minimum_size = Vector2(1120, 620)
	mid.add_child(_card)
	var paper := Hud.Sheet.new("paper", 30, 22)
	_card.add_child(paper)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	paper.add_child(_content)
	_frame = Control.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	if game.staff.cvs.is_empty():
		tab = "staff" if not game.staff.employees.is_empty() else "posts"
	_sel_key = {"cvs": "hire", "posts": "write", "staff": "tab:staff"}[tab]
	render()
	hud._pop_in(_card)
	_card.pivot_offset = _card.custom_minimum_size / 2.0


func _process(_delta: float) -> void:
	_frame.queue_redraw()


# ---------------------------------------------------------------- drawing

func render() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_targets.clear()
	_line = null
	_scroll = null
	_cv_card = null
	_drag_from = Vector2.INF
	_header()
	if not _draft.is_empty():
		_post_page()
	elif tab == "posts":
		_posts()
	elif tab == "staff":
		if _person >= 0 and game.staff.employee(_person).is_empty():
			_person = -1   # they quit or were fired
		if _person >= 0:
			_manage()
		else:
			_staff_list()
	else:
		_cvs()
	_keys_line()
	_sel = 0
	for i in _targets.size():
		if _targets[i].get_meta("key") == _sel_key:
			_sel = i
	if not _targets.is_empty():
		_sel_key = _targets[_sel].get_meta("key")


func _header() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_content.add_child(top)
	_ribbon(top, "THE DESK" if _draft.is_empty() else "NEW JOB POST")
	if _draft.is_empty():
		for t: Array in [["cvs", "CVs (%d)" % game.staff.cvs.size()], ["posts", "Job posts"],
				["staff", "Staff (%d)" % game.staff.employees.size()]]:
			var b := _paper_button(top, "tab:" + t[0], _set_tab.bind(t[0]), t[1], 22)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if tab == t[0]:
				_mark(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var used := _label(top, 22, "Desks used: %d of %d" % [game.staff.seats_used(), game.desk_count()])
	used.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _draft.is_empty():
		var done: Button = hud._button(top, "Done", game.close_desk)
		done.size_flags_horizontal = Control.SIZE_SHRINK_END
		done.custom_minimum_size = Vector2(140, 0)
		_target(done, "done")
	_rule()


## The posts up, the staff hired, and Write a post.
func _posts() -> void:
	var staff: Staff = game.staff
	var room: Dictionary = game.room_duties()
	var ids := staff.posts.keys()
	ids.sort()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(list)
	_label(list, 26, "Job posts up")
	for id: int in ids:
		var p: Dictionary = staff.posts[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var sheet := Hud.Sheet.new("card", 16, 8)
		sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sheet)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		sheet.add_child(box)
		var head := HBoxContainer.new()
		box.add_child(head)
		var name := _label(head, 24, p.name)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var waiting := 0
		for c in staff.cvs:
			waiting += 1 if c.post == id else 0
		_label(head, 18, "%s     %s     %s" % [_count_word(p.breaks, "break"), _count_word(p.days_off, "day off", "days off"),
			_count_word(waiting, "CV")])
		_duty_line(box, p.duties, room)
		var down := _paper_button(row, "down:%d" % id, _take_down.bind(id), "Take down", 18)
		down.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ids.is_empty():
		var none := _label(list, 20, "No posts up. Write one: townspeople who suit it apply overnight.")
		none.modulate.a = 0.6
	if not staff.employees.is_empty():
		var hired := _label(list, 20, "%s on the staff: see the Staff tab." % _count_word(staff.employees.size(), "hire"))
		hired.modulate.a = 0.7
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	_content.add_child(foot)
	var write := _paper_button(foot, "write", _write, "Write a job post", 24)
	if not staff.can_post(game.desk_count()):
		write.disabled = true
		write.modulate.a = 0.5
		var why := _label(foot, 20, "Every desk is taken: one desk for each post and each hire.")
		why.add_theme_color_override("font_color", Hud.CORAL.darkened(0.25))
		why.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## A post's duties in one line, by kind; a tool no longer in the room is struck through.
func _duty_line(parent: Node, duties: Array, room: Dictionary) -> void:
	var missing := Staff.missing_duties(duties, room)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	parent.add_child(row)
	for k in Staff.KINDS:
		var words: Array[String] = []
		for d in duties:
			if game.staff.duty_kind(d) == k and not missing.has(d):
				words.append(Staff.duty_word(d))
		if not words.is_empty():
			var l := _label(row, 17, "%s: %s" % [Staff.KIND_WORDS[k], ", ".join(words)])
			l.modulate.a = 0.85
	for d in missing:
		var gone := _label(row, 17, "%s (not in the room)" % Staff.duty_word(d))
		gone.modulate.a = 0.4


## Writing a post: its name, the duties by kind, breaks and days off.
func _post_page() -> void:
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	_content.add_child(name_row)
	_label(name_row, 24, "Name:")
	if _naming == "type":
		_line = LineEdit.new()
		_line.text = _draft.name
		_line.max_length = Staff.MAX_POST_NAME
		_line.custom_minimum_size = Vector2(380, 0)
		_line.add_theme_font_size_override("font_size", 24)
		_line.text_submitted.connect(func(_t: String) -> void: _finish_name())
		name_row.add_child(_line)
		_focus_line.call_deferred()
	else:
		var shown: String = _name_text if _naming == "grid" else str(_draft.name)
		_paper_button(name_row, "name", _start_name, (shown if shown != "" else DEFAULT_NAME) + ("_" if _naming == "grid" else ""), 24) \
			.custom_minimum_size = Vector2(380, 0)
	if _naming == "grid":
		_letter_grid()
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(cols)
	var room: Dictionary = game.room_duties()
	for k in Staff.KINDS:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(330, 0)
		col.add_theme_constant_override("separation", 6)
		cols.add_child(col)
		_label(col, 26, Staff.KIND_WORDS[k])
		for d: String in room[k]:
			var on: bool = (_draft.duties as Array).has(d)
			var b := _paper_button(col, "duty:" + d, _toggle_duty.bind(d), "", 20)
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 10)
			row.add_child(Tick.new(on))
			var l := _label(row, 20, Staff.duty_word(d))
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_fill(b, row)
			if on:
				_mark(b)
	_rule()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	_content.add_child(foot)
	_choice_row(foot, "Breaks a day:", "breaks", Staff.MAX_BREAKS)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	foot.add_child(gap)
	_choice_row(foot, "Days off a week:", "days_off", Staff.MAX_DAYS_OFF)
	var gap2 := Control.new()
	gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap2)
	_paper_button(foot, "cancel", _cancel_post, "Cancel", 22)
	var up: Button = hud._button(foot, "Put it up", _put_up)
	up.size_flags_horizontal = Control.SIZE_SHRINK_END
	up.custom_minimum_size = Vector2(170, 0)
	_target(up, "put_up")
	if (_draft.duties as Array).is_empty():
		up.disabled = true
		up.modulate.a = 0.5


func _choice_row(parent: HBoxContainer, words: String, field: String, most: int) -> void:
	var l := _label(parent, 20, words)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for n in most + 1:
		var b := _paper_button(parent, "%s:%d" % [field, n], _set_field.bind(field, n), str(n), 22)
		b.custom_minimum_size = Vector2(48, 0)
		if int(_draft[field]) == n:
			_mark(b)


## The pile: the top CV, the ones under it peeking out, and what to do with it.
func _cvs() -> void:
	var staff: Staff = game.staff
	var area := CenterContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(area)
	if staff.cvs.is_empty():
		var none := _label(area, 22, "No CVs in the pile. Put up a job post: townspeople apply overnight.")
		none.modulate.a = 0.6
		return
	var holder := Control.new()
	holder.custom_minimum_size = CV_SIZE + Vector2(40, 30)
	area.add_child(holder)
	for k in range(mini(staff.cvs.size(), 3) - 1, 0, -1):   # the ones underneath, a little askew
		var under := Hud.Sheet.new("card", 20, 14)
		under.custom_minimum_size = CV_SIZE
		under.size = CV_SIZE
		under.position = Vector2(20 + k * 9, 10 + k * 7)
		under.pivot_offset = CV_SIZE / 2.0
		under.rotation = 0.025 * k * (1 if k % 2 else -1)
		under.modulate = Color(0.93, 0.9, 0.86)
		holder.add_child(under)
	var cv: Dictionary = staff.cvs[0]
	_cv_card = _cv_sheet(cv)
	_cv_card.position = Vector2(20, 10)
	holder.add_child(_cv_card)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	_content.add_child(buttons)
	if _offer >= 0:
		_paper_button(buttons, "less", _nudge_offer.bind(-1), "-", 24).custom_minimum_size = Vector2(56, 0)
		var fig := _label(buttons, 28, "$%d a day" % _offer)
		fig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_paper_button(buttons, "more", _nudge_offer.bind(1), "+", 24).custom_minimum_size = Vector2(56, 0)
		var offer: Button = hud._button(buttons, "Offer $%d" % _offer, _make_offer)
		offer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		offer.custom_minimum_size = Vector2(180, 0)
		_target(offer, "offer")
		_paper_button(buttons, "unhaggle", _stop_haggle, "Back", 22)
	else:
		_paper_button(buttons, "dismiss", dismiss_top, "<  Dismiss", 24).custom_minimum_size = Vector2(200, 0)
		_paper_button(buttons, "haggle", _start_haggle, "Haggle", 24).custom_minimum_size = Vector2(160, 0)
		var hire: Button = hud._button(buttons, "Hire at $%d  >" % cv.ask, hire_top)
		hire.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hire.custom_minimum_size = Vector2(220, 0)
		_target(hire, "hire")
	var foot := _label(_content, 18, note if note != "" else "Drag the CV right to hire, left to send them home.  %s in the pile." % _count_word(staff.cvs.size(), "CV"))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if note != "":
		foot.add_theme_color_override("font_color", Hud.CORAL.darkened(0.3))


## One CV: the face on the left; the name, post, skills, rating and ask on the right.
func _cv_sheet(cv: Dictionary) -> Control:
	var sheet := Hud.Sheet.new("card", 22, 16)
	sheet.custom_minimum_size = CV_SIZE
	sheet.size = CV_SIZE
	sheet.pivot_offset = Vector2(CV_SIZE.x / 2.0, CV_SIZE.y)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.gui_input.connect(_cv_input)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	sheet.add_child(row)
	var person: Dictionary = game.town.people[cv.person]
	var face := Hud.ModelView.new(200, false)
	row.add_child(face)
	face.show_peg(person.name)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	_label(info, 34, person.name)
	var post: Dictionary = game.staff.posts.get(cv.post, {})
	var for_l := _label(info, 18, "For: %s" % post.get("name", "?"))
	for_l.modulate.a = 0.75
	for k in Staff.KINDS:
		_star_row(info, Staff.KIND_WORDS[k], Staff.stars(float(cv.skills[k])), false)
	_star_row(info, "Pace", int(cv.rating), true)   # how fast they walk and work (review, item 11: not an average)
	var ask := HBoxContainer.new()
	ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ask.add_theme_constant_override("separation", 8)
	info.add_child(ask)
	ask.add_child(Hud.Icon.new("coin", 28, false))
	_label(ask, 26, "Asks $%d a day" % int(cv.ask))
	return sheet


func _star_row(parent: Node, words: String, n: int, big: bool) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := _label(row, 20, words)
	l.custom_minimum_size = Vector2(110, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := Hud.Rating.new(n, true)
	if not big:
		r.custom_minimum_size = Vector2(5 * 26, 26)
	row.add_child(r)


func _letter_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for i in LETTERS.length():
		var c := LETTERS[i]
		var b := _paper_button(grid, "L:%d" % i, _type_letter.bind(c), "Space" if c == " " else c, 20)
		b.custom_minimum_size = Vector2(52, 40)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 10)
	_content.add_child(keys)
	_paper_button(keys, "L:del", _rub_out, "Rub out", 20).custom_minimum_size = Vector2(110, 40)
	var done: Button = hud._button(keys, "Keep this name", _finish_name)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.custom_minimum_size = Vector2(200, 40)
	_target(done, "L:done")


func _keys_line() -> void:
	var text := ""
	match hud._mode():
		"keys":
			text = "Arrows choose     E select     Esc back" if _naming != "type" else "Type a name     Enter keep it     Esc keep it"
		"pad":
			text = "D-pad choose     A select     B keep the name" if _naming == "grid" else "D-pad choose     A select     B back"
	if text != "":
		var l := _label(_content, 16, text)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.7


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
		if _scroll != null and _scroll.is_ancestor_of(_targets[best]):
			_scroll.ensure_control_visible(_targets[best])
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
	elif _offer >= 0:
		_stop_haggle()
	elif _raise_offer >= 0:
		_stop_raise_haggle()
	elif _firing:
		_set_firing(false)
	elif _person >= 0:
		close_person()
	elif not _draft.is_empty():
		_cancel_post()
	else:
		game.close_desk()


func selected() -> String:
	return _sel_key


func select(key: String) -> bool:
	for i in _targets.size():
		if _targets[i].get_meta("key") == key:
			_sel = i
			_sel_key = key
			return true
	return false


## Dragging the top CV: it follows the pointer and leans; let go far enough right to
## hire, left to dismiss, else it springs back.
func _cv_input(event: InputEvent) -> void:
	if _cv_card == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.global_position
		elif _drag_from != Vector2.INF:
			var dx: float = event.global_position.x - _drag_from.x
			_drag_from = Vector2.INF
			if dx > SWIPE:
				hire_top()
			elif dx < -SWIPE:
				dismiss_top()
			else:
				drag_to(0.0)
	elif event is InputEventMouseMotion and _drag_from != Vector2.INF:
		drag_to(event.global_position.x - _drag_from.x)


## Shows the top CV dragged `dx` pixels across (for the swipe and the demos).
func drag_to(dx: float) -> void:
	if _cv_card == null:
		return
	_cv_card.position.x = 20 + dx
	_cv_card.rotation = clampf(dx / 1600.0, -0.25, 0.25)
	_cv_card.modulate = Color.WHITE.lerp(Color("#d8f5df") if dx > 0 else Color("#f6d6cf"), clampf(absf(dx) / SWIPE, 0.0, 1.0) * 0.8)


# ---------------------------------------------------------------- what the buttons do

func _set_tab(t: String) -> void:
	tab = t
	_sel_key = "hire" if t == "cvs" and not game.staff.cvs.is_empty() else "tab:" + t
	note = ""
	_offer = -1
	_person = -1
	_raise_offer = -1
	_firing = false
	game.sfx("page")
	render()


## Swipe right: hire the top CV at their ask.
func hire_top() -> void:
	var staff: Staff = game.staff
	if staff.cvs.is_empty():
		return
	var cv: Dictionary = staff.cvs[0]
	var who: String = game.town.people[cv.person].name
	if game.desk_hire(int(cv.id)):
		note = "%s is hired, at $%d a day." % [who, int(cv.ask)]
	_offer = -1
	render()


## Swipe left: send the top CV's applicant home.
func dismiss_top() -> void:
	var staff: Staff = game.staff
	if staff.cvs.is_empty():
		return
	game.desk_dismiss(int(staff.cvs[0].id))
	note = ""
	_offer = -1
	render()


func _start_haggle() -> void:
	var staff: Staff = game.staff
	if staff.cvs.is_empty():
		return
	var ask := int(staff.cvs[0].ask)
	var last := int(staff.cvs[0].haggle.last)
	_offer = clampi(last if last > 0 else int(round(ask * 0.85)), 1, maxi(1, ask - 1))
	_sel_key = "offer"
	game.sfx("page")
	render()


func _nudge_offer(by: int) -> void:
	var ask := int(game.staff.cvs[0].ask)
	_offer = clampi(_offer + by, 1, maxi(1, ask - 1))
	game.sfx("tick")
	render()


func _stop_haggle() -> void:
	_offer = -1
	_sel_key = "haggle"
	render()


## Offers the figure. They accept, refuse (try again), take it after two refusals, or walk.
func _make_offer() -> void:
	make_offer(_offer)


func make_offer(figure: int) -> String:
	var staff: Staff = game.staff
	if staff.cvs.is_empty():
		return ""
	var cv: Dictionary = staff.cvs[0]
	var who: String = game.town.people[cv.person].name
	var r: String = game.desk_haggle(int(cv.id), figure)
	match r:
		"accept":
			note = "%s takes $%d a day. Hired." % [who, figure]
			_offer = -1
		"take_last":
			note = "%s grumbles, but takes $%d a day. Hired." % [who, figure]
			_offer = -1
		"refuse":
			note = "%s wants more than $%d." % [who, figure]
			_offer = figure
		"walk":
			note = "%s won't work for that, and goes home." % who
			_offer = -1
	render()
	return r


func _take_down(id: int) -> void:
	game.desk_take_down(id)
	render()


func _write() -> void:
	if not game.staff.can_post(game.desk_count()):
		return
	_draft = {"name": "", "duties": [], "breaks": 1, "days_off": 1}
	_sel_key = "name"
	game.sfx("page")
	render()


func _toggle_duty(d: String) -> void:
	var duties: Array = _draft.duties
	if duties.has(d):
		duties.erase(d)
	else:
		duties.append(d)
	_sel_key = "duty:" + d
	game.sfx("tick")
	render()


func _set_field(field: String, n: int) -> void:
	_draft[field] = n
	_sel_key = "%s:%d" % [field, n]
	game.sfx("tick")
	render()


func _cancel_post() -> void:
	_draft = {}
	_naming = ""
	_sel_key = "write"
	render()


func _put_up() -> void:
	if (_draft.duties as Array).is_empty():
		return
	var title: String = _draft.name if str(_draft.name) != "" else DEFAULT_NAME
	if game.desk_post(title, _draft.duties, int(_draft.breaks), int(_draft.days_off)) >= 0:
		_draft = {}
		tab = "posts"
		_sel_key = "write"
	render()


func _start_name() -> void:
	_naming = "grid" if hud._mode() == "pad" else "type"
	_name_text = _draft.name
	_sel_key = "L:0"
	game.sfx("page")
	render()


func _focus_line() -> void:
	if _line != null and is_instance_valid(_line):
		_line.grab_focus()
		_line.edit()
		_line.caret_column = _line.text.length()


func _type_letter(c: String) -> void:
	if _name_text.length() < Staff.MAX_POST_NAME:
		_name_text += c if _name_text.length() == 0 or _name_text.ends_with(" ") else c.to_lower()
		game.sfx("tick")
		render()


func _rub_out() -> void:
	_name_text = _name_text.substr(0, maxi(0, _name_text.length() - 1))
	game.sfx("tick")
	render()


func _finish_name() -> void:
	if _naming == "":
		return
	var text := _name_text if _naming == "grid" else (_line.text if _line != null and is_instance_valid(_line) else str(_draft.name))
	_naming = ""
	_draft.name = text.strip_edges().substr(0, Staff.MAX_POST_NAME)
	_sel_key = "name"
	render()


# ---------------------------------------------------------------- the staff list (PRD 10.4)

## Every hire, one card each: face; name, post and wage; duties and breaks; the week;
## how they feel; their skills; and Manage.
func _staff_list() -> void:
	var staff: Staff = game.staff
	if staff.employees.is_empty():
		var area := CenterContainer.new()
		area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content.add_child(area)
		var none := _label(area, 22, "Nobody works here yet. Put up a job post, then hire from the CVs.")
		none.modulate.a = 0.6
		return
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	_scroll.add_child(list)
	var people := staff.employees.keys()
	people.sort()
	for person: int in people:
		var sheet := Hud.Sheet.new("card", 14, 8)
		sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(sheet)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		sheet.add_child(row)
		_person_row(row, person, 84)
		var m := _paper_button(row, "manage:%d" % person, open_person.bind(person), "Manage", 20)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wages := _label(_content, 18, "Wages tonight: $%d, paid with the stock as the door opens. Days off are paid." % staff.wages_due())
	wages.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wages.modulate.a = 0.75
	if note != "":
		var n := _label(_content, 18, note)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_color_override("font_color", Hud.CORAL.darkened(0.3))


## One hire across a row: face, who and what, the week, their mood and their skills.
func _person_row(row: HBoxContainer, person: int, face_px: int) -> void:
	var staff: Staff = game.staff
	var e: Dictionary = staff.employee(person)
	var who: Dictionary = game.town.people[person]
	var face := Hud.ModelView.new(face_px, false)
	row.add_child(face)
	face.show_peg(who.name)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	info.add_child(head)
	_label(head, 24, who.name)
	var post := _label(head, 18, "%s,  $%d a day" % [e.post_name, int(e.wage)])
	post.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	post.modulate.a = 0.8
	_duty_line(info, e.duties, game.room_duties())
	var rest := _label(info, 16, "%s a day,  %s a week" % [_count_word(int(e.breaks), "break"),
		_count_word(int(e.days_off), "day off", "days off")])
	rest.modulate.a = 0.7
	var wk := VBoxContainer.new()
	wk.add_theme_constant_override("separation", 2)
	wk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(wk)
	var day: int = game.ledger.day
	var first := Staff.week_first(day)
	var wl := _label(wk, 15, "Week: days %d to %d" % [first, first + Staff.WEEK - 1])
	wl.modulate.a = 0.7
	wk.add_child(Week.new(staff.week_boxes(person, day), day))
	if int(e.days_off) > 0 and not staff.picked_week(person, day):
		var later := _label(wk, 14, "Days off from next week")
		later.modulate.a = 0.6
	var md := VBoxContainer.new()
	md.add_theme_constant_override("separation", 2)
	md.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	md.custom_minimum_size = Vector2(170, 0)
	row.add_child(md)
	md.add_child(Mood.new(float(e.satisfaction)))
	var word := _label(md, 18, Staff.mood_word(float(e.satisfaction)))
	if int(e.bottom_nights) > 0:
		word.text += "  (%d of %d nights)" % [int(e.bottom_nights), Staff.QUIT_NIGHTS]
		word.add_theme_color_override("font_color", Hud.CORAL.darkened(0.3))
	var why := staff.reasons(person)   # review, item 11: what makes them feel so
	if not why.is_empty():
		var wl2 := _label(md, 13, "\n".join(why))
		wl2.modulate.a = 0.75
	var sk := VBoxContainer.new()
	sk.add_theme_constant_override("separation", 0)
	sk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sk)
	for k in Staff.KINDS:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		sk.add_child(r)
		var l := _label(r, 16, Staff.KIND_WORDS[k])
		l.custom_minimum_size = Vector2(80, 0)
		var st := Hud.Rating.new(Staff.stars(float(e.skills[k])), true)
		st.custom_minimum_size = Vector2(5 * 20, 20)
		r.add_child(st)


## One hire: their row, their duties as ticks, breaks and days off, and firing. A raise
## they named waits at the top until answered.
func _manage() -> void:
	var staff: Staff = game.staff
	var e: Dictionary = staff.employee(_person)
	var who: String = game.town.people[_person].name
	var top := Hud.Sheet.new("card", 14, 8)
	_content.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	top.add_child(row)
	_person_row(row, _person, 96)
	if not (e.pending as Dictionary).is_empty():
		_raise_panel(e, who)
	else:
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 24)
		cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content.add_child(cols)
		var room: Dictionary = game.room_duties()
		for k in Staff.KINDS:
			var col := VBoxContainer.new()
			col.custom_minimum_size = Vector2(330, 0)
			col.add_theme_constant_override("separation", 4)
			cols.add_child(col)
			_label(col, 22, Staff.KIND_WORDS[k])
			var list: Array = (room[k] as Array).duplicate()
			for d in e.duties:
				if staff.duty_kind(d) == k and not list.has(d):
					list.append(d)   # their tool left the room: shown so it can come off
			for d: String in list:
				var on: bool = (e.duties as Array).has(d)
				var b := _paper_button(col, "duty:" + d, _toggle_staff_duty.bind(d), "", 18)
				var r := HBoxContainer.new()
				r.mouse_filter = Control.MOUSE_FILTER_IGNORE
				r.add_theme_constant_override("separation", 8)
				r.add_child(Tick.new(on))
				var l := _label(r, 18, Staff.duty_word(d) + ("" if (room[k] as Array).has(d) else " (not in the room)"))
				l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				_fill(b, r)
				if on:
					_mark(b)
	if note != "":
		var n := _label(_content, 18, note)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_color_override("font_color", Hud.CORAL.darkened(0.3))
	_rule()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	_content.add_child(foot)
	if _firing:
		var sev := _paper_button(foot, "fire_pay", _fire.bind(true), "Fire, paying $%d severance" % int(e.wage), 20)
		if not game.can_pay_severance(_person):
			sev.disabled = true
			sev.modulate.a = 0.5
		_paper_button(foot, "fire_harsh", _fire.bind(false), "Fire with nothing (friends hear)", 20)
		var g := Control.new()
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(g)
		_paper_button(foot, "keep", _set_firing.bind(false), "Keep them", 20)
		return
	var br := _paper_button(foot, "break", _more_break, "Add a break (%d of %d)" % [int(e.breaks), Staff.MAX_BREAKS], 20)
	if int(e.breaks) >= Staff.MAX_BREAKS:
		br.disabled = true
		br.modulate.a = 0.5
	var off := _paper_button(foot, "day_off", _more_day_off, "Add a day off (%d of %d)" % [int(e.days_off), Staff.MAX_DAYS_OFF], 20)
	if int(e.days_off) >= Staff.MAX_DAYS_OFF:
		off.disabled = true
		off.modulate.a = 0.5
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	_paper_button(foot, "fire", _set_firing.bind(true), "Fire...", 20)
	_paper_button(foot, "staff_back", close_person, "Back to the list", 20)


## The raise they named for a new duty: approve it, haggle it down, withdraw the duty, or
## deny it (and they quit).
func _raise_panel(e: Dictionary, who: String) -> void:
	var p: Dictionary = e.pending
	var area := CenterContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(area)
	var sheet := Hud.Sheet.new("note", 24, 16)
	sheet.rotation = -0.01
	area.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	sheet.add_child(box)
	var ask := HBoxContainer.new()
	ask.add_theme_constant_override("separation", 10)
	box.add_child(ask)
	ask.add_child(Hud.Icon.new("coin", 30, false))
	_label(ask, 26, "%s wants $%d more a day to take on %s." % [who, int(p.raise), Staff.duty_word(p.duty).to_lower()])
	var now := _label(box, 18, "Now $%d a day; with the raise $%d." % [int(e.wage), int(e.wage) + int(p.raise)])
	now.modulate.a = 0.75
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	if _raise_offer >= 0:
		_paper_button(buttons, "rless", _nudge_raise.bind(-1), "-", 24).custom_minimum_size = Vector2(56, 0)
		var fig := _label(buttons, 26, "+$%d a day" % _raise_offer)
		fig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_paper_button(buttons, "rmore", _nudge_raise.bind(1), "+", 24).custom_minimum_size = Vector2(56, 0)
		var offer: Button = hud._button(buttons, "Offer +$%d" % _raise_offer, func() -> void: answer_raise("haggle", _raise_offer))
		offer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		offer.custom_minimum_size = Vector2(180, 0)
		_target(offer, "raise_offer")
		_paper_button(buttons, "raise_back", _stop_raise_haggle, "Back", 22)
		return
	_paper_button(buttons, "withdraw", answer_raise.bind("withdraw"), "Withdraw the duty", 20)
	_paper_button(buttons, "raise_haggle", _start_raise_haggle, "Haggle", 20)
	_paper_button(buttons, "deny", answer_raise.bind("deny"), "Deny (they quit)", 20)
	var ok: Button = hud._button(buttons, "Approve +$%d" % int(p.raise), answer_raise.bind("approve"))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.custom_minimum_size = Vector2(190, 0)
	_target(ok, "approve")


func open_person(person: int) -> void:
	if game.staff.employee(person).is_empty():
		return
	tab = "staff"
	_person = person
	_raise_offer = -1
	_firing = false
	note = ""
	_sel_key = "staff_back"
	game.sfx("page")
	render()


func close_person() -> void:
	var was := _person
	_person = -1
	_raise_offer = -1
	_firing = false
	note = ""
	_sel_key = "manage:%d" % was
	render()


## Ticking a duty offers it; unticking takes it off (free, and they are glad).
func _toggle_staff_duty(d: String) -> void:
	var e: Dictionary = game.staff.employee(_person)
	var who: String = game.town.people[_person].name
	_sel_key = "duty:" + d
	if (e.duties as Array).has(d):
		game.desk_remove_duty(_person, d)
		note = "%s is glad to be off %s." % [who, Staff.duty_word(d).to_lower()]
	else:
		var r: Dictionary = game.desk_add_duty(_person, d)
		if r.ok:
			note = "%s takes on %s." % [who, Staff.duty_word(d).to_lower()]
		else:
			note = ""
			_sel_key = "approve"
	render()


## The answer to a named raise (`Staff.answer_raise`), from the buttons or a test.
func answer_raise(choice: String, offer := 0) -> String:
	if _person < 0:
		return ""
	var person := _person
	var who: String = game.town.people[person].name
	var duty: String = Staff.duty_word(str(game.staff.employee(person).pending.get("duty", ""))).to_lower()
	var r: String = game.desk_answer_raise(person, choice, offer)
	match r:
		"added":
			note = "%s takes on %s, at $%d a day." % [who, duty, int(game.staff.employee(person).wage)]
			_raise_offer = -1
			_sel_key = "staff_back"
		"withdrawn":
			note = "Withdrawn. %s carries on as before." % who
			_sel_key = "staff_back"
		"refuse":
			note = "%s wants more than +$%d." % [who, offer]
		"quit":
			note = "%s quits." % who
			_person = -1
			_raise_offer = -1
			_sel_key = "tab:staff"
	render()
	return r


func _start_raise_haggle() -> void:
	var p: Dictionary = game.staff.employee(_person).pending
	_raise_offer = maxi(0, int(p.raise) - 1)
	_sel_key = "raise_offer"
	game.sfx("page")
	render()


func _nudge_raise(by: int) -> void:
	var p: Dictionary = game.staff.employee(_person).pending
	_raise_offer = clampi(_raise_offer + by, 0, maxi(0, int(p.raise) - 1))
	game.sfx("tick")
	render()


func _stop_raise_haggle() -> void:
	_raise_offer = -1
	_sel_key = "raise_haggle"
	render()


func _more_break() -> void:
	if game.desk_add_break(_person):
		note = "%s has a break more a day." % game.town.people[_person].name
	_sel_key = "break"
	render()


func _more_day_off() -> void:
	if game.desk_add_day_off(_person):
		note = "%s has a day off more a week, picked next week." % game.town.people[_person].name
	_sel_key = "day_off"
	render()


func _set_firing(on: bool) -> void:
	_firing = on
	_sel_key = "keep" if on else "fire"
	game.sfx("page")
	render()


func _fire(severance: bool) -> void:
	var who: String = game.town.people[_person].name
	if game.desk_fire(_person, severance):
		note = "%s is let go%s." % [who, " with a day's wage" if severance else ", and their friends will hear of it"]
		_person = -1
		_firing = false
		_sel_key = "tab:staff"
	render()


## For tests and demos: opens the raise haggle at `offer`.
func start_raise_haggle(offer := -1) -> void:
	_start_raise_haggle()
	if offer >= 0:
		_raise_offer = offer
		render()


func managing() -> int:
	return _person


# ---------------------------------------------------------------- for tests and demos

## Starts a post with these fields, as if typed and ticked.
func draft_post(post_name: String, duties: Array, breaks := 1, days_off := 1) -> void:
	_draft = {"name": post_name, "duties": duties.duplicate(), "breaks": breaks, "days_off": days_off}
	render()


func drafting() -> Dictionary:
	return _draft


func put_up() -> void:
	_put_up()


func start_haggle() -> void:
	_start_haggle()


func show_tab(t: String) -> void:
	_set_tab(t)


# ---------------------------------------------------------------- pieces

func _count_word(n: int, one: String, many := "") -> String:
	return "%d %s" % [n, one if n == 1 else (many if many != "" else one + "s")]


func _label(parent: Node, px: int, text := "") -> Label:
	var l: Label = hud._label(parent, px, text)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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
