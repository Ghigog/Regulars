class_name DeskPages
extends RefCounted
## Drawing the desk screen (render): the header, job posts and the post page, the CV list
## and a CV's sheet, star rows, the letter grid, the key line and the frame.

var screen: DeskScreen


func _init(screen_: DeskScreen) -> void:
	screen = screen_


# ---------------------------------------------------------------- drawing

func render() -> void:
	for c in screen._content.get_children():
		screen._content.remove_child(c)
		c.queue_free()
	screen._targets.clear()
	screen._line = null
	screen._scroll = null
	screen._cv_card = null
	screen._drag_from = Vector2.INF
	_header()
	if not screen._draft.is_empty():
		_post_page()
	elif screen.tab == "posts":
		_posts()
	elif screen.tab == "staff":
		if screen._person >= 0 and screen.game.staff.employee(screen._person).is_empty():
			screen._person = -1   # they quit or were fired
		if screen._person >= 0:
			screen.staff_ui._manage()
		else:
			screen.staff_ui._staff_list()
	else:
		_cvs()
	if not (screen.tab == "staff" and screen._person < 0 and screen._draft.is_empty()):
		_keys_line()
	screen._sel = 0
	for i in screen._targets.size():
		if screen._targets[i].get_meta("key") == screen._sel_key:
			screen._sel = i
	if not screen._targets.is_empty():
		screen._sel_key = screen._targets[screen._sel].get_meta("key")


func _header() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	screen._content.add_child(top)
	screen._ribbon(top, "THE DESK" if screen._draft.is_empty() else "NEW JOB POST")
	if screen._draft.is_empty():
		for t: Array in [["cvs", "CVs (%d)" % screen.game.staff.cvs.size()], ["posts", "Job posts"],
				["staff", "Staff (%d)" % screen.game.staff.employees.size()]]:
			var b := screen._paper_button(top, "tab:" + t[0], screen.posting._set_tab.bind(t[0]), t[1], 22)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if screen.tab == t[0]:
				screen._mark(b)
		if not screen.game.staff.employees.is_empty():
			var wages: Label = screen._label(top, 36, "$%d" % screen.game.staff.wages_due())
			wages.name = "Wages"
			wages.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var used := screen._label(top, 22, "Desks used: %d of %d" % [screen.game.staff.seats_used(), screen.game.desk.desk_count()])
	used.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if screen._draft.is_empty():
		var done: Button = screen.hud.receipt_ui._button(top, "Done", screen.game.desk.close_desk)
		done.size_flags_horizontal = Control.SIZE_SHRINK_END
		done.custom_minimum_size = Vector2(140, 0)
		screen._target(done, "done")
	screen._rule()


## The posts up, the staff hired, and Write a post.
func _posts() -> void:
	var staff: Staff = screen.game.staff
	var room: Dictionary = screen.game.desk.room_duties()
	var ids := staff.posts.keys()
	ids.sort()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen._content.add_child(list)
	screen._label(list, 26, "Job posts up")
	for id: int in ids:
		var p: Dictionary = staff.posts[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var sheet := HudWidgets.Sheet.new("card", 16, 8)
		sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sheet)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		sheet.add_child(box)
		var head := HBoxContainer.new()
		box.add_child(head)
		var name := screen._label(head, 24, p.name)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var waiting := 0
		for c in staff.cvs:
			waiting += 1 if c.post == id else 0
		screen._label(head, 18, "%s     %s     %s" % [screen._count_word(p.breaks, "break"), screen._count_word(p.days_off, "day off", "days off"),
			screen._count_word(waiting, "CV")])
		_duty_line(box, p.duties, room)
		var down := screen._paper_button(row, "down:%d" % id, screen.posting._take_down.bind(id), "Take down", 18)
		down.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ids.is_empty():
		var none := screen._label(list, 20, "No posts up. Write one: townspeople who suit it apply overnight.")
		none.modulate.a = 0.6
	if not staff.employees.is_empty():
		var hired := screen._label(list, 20, "%s on the staff: see the Staff tab." % screen._count_word(staff.employees.size(), "hire"))
		hired.modulate.a = 0.7
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	screen._content.add_child(foot)
	var write := screen._paper_button(foot, "write", screen.posting._write, "Write a job post", 24)
	if not staff.can_post(screen.game.desk.desk_count()):
		write.disabled = true
		write.modulate.a = 0.5
		var why := screen._label(foot, 20, "Every desk is taken: one desk for each post and each hire.")
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
			if screen.game.staff.duty_kind(d) == k and not missing.has(d):
				words.append(Staff.duty_word(d))
		if not words.is_empty():
			var l := screen._label(row, 17, "%s: %s" % [Staff.KIND_WORDS[k], ", ".join(words)])
			l.modulate.a = 0.85
	for d in missing:
		var gone := screen._label(row, 17, "%s (not in the room)" % Staff.duty_word(d))
		gone.modulate.a = 0.4


## Writing a post: its name, the duties by kind, breaks and days off.
func _post_page() -> void:
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	screen._content.add_child(name_row)
	screen._label(name_row, 24, "Name:")
	if screen._naming == "type":
		screen._line = LineEdit.new()
		screen._line.text = screen._draft.name
		screen._line.max_length = Staff.MAX_POST_NAME
		screen._line.custom_minimum_size = Vector2(380, 0)
		screen._line.add_theme_font_size_override("font_size", 24)
		screen._line.text_submitted.connect(func(_t: String) -> void: screen.posting._finish_name())
		name_row.add_child(screen._line)
		screen.posting._focus_line.call_deferred()
	else:
		var shown: String = screen._name_text if screen._naming == "grid" else str(screen._draft.name)
		screen._paper_button(name_row, "name", screen.posting._start_name, (shown if shown != "" else DeskScreen.DEFAULT_NAME) + ("_" if screen._naming == "grid" else ""), 24) \
			.custom_minimum_size = Vector2(380, 0)
	if screen._naming == "grid":
		_letter_grid()
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen._content.add_child(cols)
	var room: Dictionary = screen.game.desk.room_duties()
	for k in Staff.KINDS:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(330, 0)
		col.add_theme_constant_override("separation", 6)
		cols.add_child(col)
		screen._label(col, 26, Staff.KIND_WORDS[k])
		for d: String in room[k]:
			var on: bool = (screen._draft.duties as Array).has(d)
			var b := screen._paper_button(col, "duty:" + d, screen.posting._toggle_duty.bind(d), "", 20)
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 10)
			row.add_child(DeskScreen.Tick.new(on))
			var l := screen._label(row, 20, Staff.duty_word(d))
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			screen._fill(b, row)
			if on:
				screen._mark(b)
	screen._rule()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	screen._content.add_child(foot)
	_choice_row(foot, "Breaks a day:", "breaks", Staff.MAX_BREAKS)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	foot.add_child(gap)
	_choice_row(foot, "Days off a week:", "days_off", Staff.MAX_DAYS_OFF)
	var gap2 := Control.new()
	gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap2)
	screen._paper_button(foot, "cancel", screen.posting._cancel_post, "Cancel", 22)
	var up: Button = screen.hud.receipt_ui._button(foot, "Put it up", screen.posting._put_up)
	up.size_flags_horizontal = Control.SIZE_SHRINK_END
	up.custom_minimum_size = Vector2(170, 0)
	screen._target(up, "put_up")
	if (screen._draft.duties as Array).is_empty():
		up.disabled = true
		up.modulate.a = 0.5


func _choice_row(parent: HBoxContainer, words: String, field: String, most: int) -> void:
	var l := screen._label(parent, 20, words)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for n in most + 1:
		var b := screen._paper_button(parent, "%s:%d" % [field, n], screen.posting._set_field.bind(field, n), str(n), 22)
		b.custom_minimum_size = Vector2(48, 0)
		if int(screen._draft[field]) == n:
			screen._mark(b)


## The pile as a list to scroll: every CV, the chosen one lit. Drag any CV right to hire,
## left to send them home; the buttons act on the chosen one.
func _cvs() -> void:
	var staff: Staff = screen.game.staff
	if staff.cvs.is_empty():
		var area := CenterContainer.new()
		area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		screen._content.add_child(area)
		var none := screen._label(area, 22, "No CVs in the pile. Put up a job post: townspeople apply overnight.")
		none.modulate.a = 0.6
		return
	screen._pick = clampi(screen._pick, 0, staff.cvs.size() - 1)
	screen._scroll = ScrollContainer.new()
	screen._scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen._scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen._scroll.custom_minimum_size = Vector2(0, 400)
	screen._content.add_child(screen._scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	screen._scroll.add_child(list)
	var picked: Control = null
	for i in staff.cvs.size():
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(0, DeskScreen.CV_SIZE.y + 10)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		list.add_child(slot)
		var sheet := _cv_sheet(staff.cvs[i], i)
		sheet.position = Vector2((1000 - DeskScreen.CV_SIZE.x) / 2.0, 5)
		if i != screen._pick:
			sheet.modulate = Color(0.9, 0.87, 0.83)
		else:
			picked = sheet
			screen._cv_card = sheet
		slot.add_child(sheet)
	if picked != null:
		screen._scroll.ensure_control_visible.call_deferred(picked)
	var cv: Dictionary = _cv()
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	screen._content.add_child(buttons)
	if screen._offer >= 0:
		screen._paper_button(buttons, "less", screen.posting._nudge_offer.bind(-1), "-", 24).custom_minimum_size = Vector2(56, 0)
		var fig := screen._label(buttons, 28, "$%d a day" % screen._offer)
		fig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		screen._paper_button(buttons, "more", screen.posting._nudge_offer.bind(1), "+", 24).custom_minimum_size = Vector2(56, 0)
		var offer: Button = screen.hud.receipt_ui._button(buttons, "Offer $%d" % screen._offer, screen.posting._make_offer)
		offer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		offer.custom_minimum_size = Vector2(180, 0)
		screen._target(offer, "offer")
		screen._paper_button(buttons, "unhaggle", screen.posting._stop_haggle, "Back", 22)
	else:
		screen._paper_button(buttons, "prev", _pick_by.bind(-1), "^", 24).custom_minimum_size = Vector2(56, 0)
		screen._paper_button(buttons, "dismiss", screen.posting.dismiss_top, "<  Dismiss", 24).custom_minimum_size = Vector2(200, 0)
		screen._paper_button(buttons, "haggle", screen.posting._start_haggle, "Haggle", 24).custom_minimum_size = Vector2(160, 0)
		var hire: Button = screen.hud.receipt_ui._button(buttons, "Hire at $%d  >" % cv.ask, screen.posting.hire_top)
		hire.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hire.custom_minimum_size = Vector2(220, 0)
		screen._target(hire, "hire")
		screen._paper_button(buttons, "next", _pick_by.bind(1), "v", 24).custom_minimum_size = Vector2(56, 0)
	var foot := screen._label(screen._content, 18, screen.note if screen.note != "" else "Scroll the pile. Drag a CV right to hire, left to send them home.  %s in the pile." % screen._count_word(staff.cvs.size(), "CV"))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if screen.note != "":
		foot.add_theme_color_override("font_color", Hud.CORAL.darkened(0.3))


## The chosen CV (the first in the pile unless another was picked).
func _cv() -> Dictionary:
	var cvs: Array = screen.game.staff.cvs
	return cvs[clampi(screen._pick, 0, cvs.size() - 1)]


func _pick_by(by: int) -> void:
	var n: int = screen.game.staff.cvs.size()
	if n == 0:
		return
	screen._pick = clampi(screen._pick + by, 0, n - 1)
	screen._offer = -1
	screen.game.audio.sfx("tick")
	render()


## One CV: the face on the left; the name, post, skills, rating and ask on the right.
func _cv_sheet(cv: Dictionary, index := 0) -> Control:
	var sheet := HudWidgets.Sheet.new("card", 22, 16)
	sheet.custom_minimum_size = DeskScreen.CV_SIZE
	sheet.size = DeskScreen.CV_SIZE
	sheet.pivot_offset = Vector2(DeskScreen.CV_SIZE.x / 2.0, DeskScreen.CV_SIZE.y)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.gui_input.connect(screen._cv_input.bind(sheet, index))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	sheet.add_child(row)
	var person: Dictionary = screen.game.town.people[cv.person]
	var face := HudWidgets.ModelView.new(200, false)
	row.add_child(face)
	face.show_peg(person.name)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	screen._label(info, 34, person.name)
	var post: Dictionary = screen.game.staff.posts.get(cv.post, {})
	var for_l := screen._label(info, 18, "For: %s" % post.get("name", "?"))
	for_l.modulate.a = 0.75
	for k in Staff.KINDS:
		_star_row(info, Staff.KIND_WORDS[k], Staff.stars(float(cv.skills[k])), false)
	_star_row(info, "Pace", int(cv.rating), true)   # how fast they walk and work (review, item 11: not an average)
	var ask := HBoxContainer.new()
	ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ask.add_theme_constant_override("separation", 8)
	info.add_child(ask)
	ask.add_child(HudWidgets.Icon.new("coin", 28, false))
	screen._label(ask, 26, "Asks $%d a day" % int(cv.ask))
	return sheet


func _star_row(parent: Node, words: String, n: int, big: bool) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := screen._label(row, 20, words)
	l.custom_minimum_size = Vector2(110, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := HudWidgets.Rating.new(n, true)
	if not big:
		r.custom_minimum_size = Vector2(5 * 26, 26)
	row.add_child(r)


func _letter_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = DeskScreen.GRID_COLS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	screen._content.add_child(grid)
	for i in DeskScreen.LETTERS.length():
		var c := DeskScreen.LETTERS[i]
		var b := screen._paper_button(grid, "L:%d" % i, screen.posting._type_letter.bind(c), "Space" if c == " " else c, 20)
		b.custom_minimum_size = Vector2(52, 40)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 10)
	screen._content.add_child(keys)
	screen._paper_button(keys, "L:del", screen.posting._rub_out, "Rub out", 20).custom_minimum_size = Vector2(110, 40)
	var done: Button = screen.hud.receipt_ui._button(keys, "Keep this name", screen.posting._finish_name)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.custom_minimum_size = Vector2(200, 40)
	screen._target(done, "L:done")


func _keys_line() -> void:
	var text := ""
	match screen.hud._mode():
		"keys":
			text = "Arrows choose     E select     Esc back" if screen._naming != "type" else "Type a name     Enter keep it     Esc keep it"
		"pad":
			text = "D-pad choose     A select     B keep the name" if screen._naming == "grid" else "D-pad choose     A select     B back"
	if text != "":
		var l := screen._label(screen._content, 16, text)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.7


func _draw_frame() -> void:
	if screen.hud._mode() == "touch" or screen._targets.is_empty() or screen._naming == "type":
		return
	screen._sel = clampi(screen._sel, 0, screen._targets.size() - 1)
	var t := screen._targets[screen._sel]
	if not is_instance_valid(t) or not t.is_visible_in_tree():
		return
	var r := t.get_global_rect().grow_individual(12, 5, 8, 5)
	r.position -= screen._frame.get_global_rect().position
	HudOptions.pick_frame(screen._frame, r)
