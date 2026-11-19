class_name DeskStaff
extends RefCounted
## The staff list (PRD 10.4, 10.8): a row per hire, managing one (duties, breaks, days off),
## answering a raise, haggling over it, and firing.

var screen: DeskScreen


func _init(screen_: DeskScreen) -> void:
	screen = screen_


# ---------------------------------------------------------------- the staff list (PRD 10.4)

## Every hire, one card each: face; name, post and wage; duties and breaks; the week;
## how they feel; their skills; and Manage.
func _staff_list() -> void:
	var staff: Staff = screen.game.staff
	if staff.employees.is_empty():
		var area := CenterContainer.new()
		area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		screen._content.add_child(area)
		var none := screen._label(area, 22, "Nobody works here yet. Put up a job post, then hire from the CVs.")
		none.modulate.a = 0.6
		return
	screen._scroll = ScrollContainer.new()
	screen._scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen._scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen._content.add_child(screen._scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	screen._scroll.add_child(list)
	var people := staff.employees.keys()
	people.sort()
	for person: int in people:
		var sheet := HudWidgets.Sheet.new("card", 14, 8)
		sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(sheet)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		sheet.add_child(row)
		_person_row(row, person, 84)
		var m := screen._paper_button(row, "manage:%d" % person, open_person.bind(person), "Manage", 20)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if screen.note != "":
		var n := screen._label(screen._content, 18, screen.note)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_color_override("font_color", Hud.CORAL.darkened(0.3))


## One hire across a row: face, who and what, the week, their mood and their skills.
func _person_row(row: HBoxContainer, person: int, face_px: int) -> void:
	var staff: Staff = screen.game.staff
	var e: Dictionary = staff.employee(person)
	var who: Dictionary = screen.game.town.people[person]
	var face := HudWidgets.ModelView.new(face_px, false)
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
	screen._label(head, 24, who.name)
	var post := screen._label(head, 18, "%s,  $%d a day" % [e.post_name, int(e.wage)])
	post.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	post.modulate.a = 0.8
	screen.pages._duty_line(info, e.duties, screen.game.desk.room_duties())
	var rest := screen._label(info, 16, "%s a day,  %s a week" % [screen._count_word(int(e.breaks), "break"),
		screen._count_word(int(e.days_off), "day off", "days off")])
	rest.modulate.a = 0.7
	var wk := VBoxContainer.new()
	wk.add_theme_constant_override("separation", 2)
	wk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(wk)
	var day: int = screen.game.ledger.day
	var first := Staff.week_first(day)
	var wl := screen._label(wk, 15, "Week: days %d to %d" % [first, first + Staff.WEEK - 1])
	wl.modulate.a = 0.7
	wk.add_child(DeskScreen.Week.new(staff.week_boxes(person, day), day))
	if int(e.days_off) > 0 and not staff.picked_week(person, day):
		var later := screen._label(wk, 14, "Days off from next week")
		later.modulate.a = 0.6
	var md := VBoxContainer.new()
	md.add_theme_constant_override("separation", 2)
	md.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	md.custom_minimum_size = Vector2(170, 0)
	row.add_child(md)
	md.add_child(DeskScreen.Mood.new(float(e.satisfaction)))
	var word := screen._label(md, 18, Staff.mood_word(float(e.satisfaction)))
	if int(e.bottom_nights) > 0:
		word.text += "  (%d of %d nights)" % [int(e.bottom_nights), Staff.QUIT_NIGHTS]
		word.add_theme_color_override("font_color", Hud.CORAL.darkened(0.3))
	var why := staff.reasons(person)   # review, item 11: what makes them feel so
	if not why.is_empty():
		var wl2 := screen._label(md, 13, "\n".join(why))
		wl2.modulate.a = 0.75
	var sk := VBoxContainer.new()
	sk.add_theme_constant_override("separation", 0)
	sk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sk)
	for k in Staff.KINDS:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		sk.add_child(r)
		var l := screen._label(r, 16, Staff.KIND_WORDS[k])
		l.custom_minimum_size = Vector2(80, 0)
		var st := HudWidgets.Rating.new(Staff.stars(float(e.skills[k])), true)
		st.custom_minimum_size = Vector2(5 * 20, 20)
		r.add_child(st)


## One hire: their row, their duties as ticks, breaks and days off, and firing. A raise
## they named waits at the top until answered.
func _manage() -> void:
	var staff: Staff = screen.game.staff
	var e: Dictionary = staff.employee(screen._person)
	var who: String = screen.game.town.people[screen._person].name
	var top := HudWidgets.Sheet.new("card", 14, 8)
	screen._content.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	top.add_child(row)
	_person_row(row, screen._person, 96)
	if not (e.pending as Dictionary).is_empty():
		_raise_panel(e, who)
	else:
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 24)
		cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
		screen._content.add_child(cols)
		var room: Dictionary = screen.game.desk.room_duties()
		for k in Staff.KINDS:
			var col := VBoxContainer.new()
			col.custom_minimum_size = Vector2(330, 0)
			col.add_theme_constant_override("separation", 4)
			cols.add_child(col)
			screen._label(col, 22, Staff.KIND_WORDS[k])
			var list: Array = (room[k] as Array).duplicate()
			for d in e.duties:
				if staff.duty_kind(d) == k and not list.has(d):
					list.append(d)   # their tool left the room: shown so it can come off
			for d: String in list:
				var on: bool = (e.duties as Array).has(d)
				var b := screen._paper_button(col, "duty:" + d, _toggle_staff_duty.bind(d), "", 18)
				var r := HBoxContainer.new()
				r.mouse_filter = Control.MOUSE_FILTER_IGNORE
				r.add_theme_constant_override("separation", 8)
				r.add_child(DeskScreen.Tick.new(on))
				var l := screen._label(r, 18, Staff.duty_word(d) + ("" if (room[k] as Array).has(d) else " (not in the room)"))
				l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				screen._fill(b, r)
				if on:
					screen._mark(b)
	if screen.note != "":
		var n := screen._label(screen._content, 18, screen.note)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_color_override("font_color", Hud.CORAL.darkened(0.3))
	screen._rule()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	screen._content.add_child(foot)
	if screen._firing:
		var sev := screen._paper_button(foot, "fire_pay", _fire.bind(true), "Fire, paying $%d severance" % int(e.wage), 20)
		if not screen.game.desk.can_pay_severance(screen._person):
			sev.disabled = true
			sev.modulate.a = 0.5
		screen._paper_button(foot, "fire_harsh", _fire.bind(false), "Fire with nothing (friends hear)", 20)
		var g := Control.new()
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(g)
		screen._paper_button(foot, "keep", _set_firing.bind(false), "Keep them", 20)
		return
	var br := screen._paper_button(foot, "break", _more_break, "Add a break (%d of %d)" % [int(e.breaks), Staff.MAX_BREAKS], 20)
	if int(e.breaks) >= Staff.MAX_BREAKS:
		br.disabled = true
		br.modulate.a = 0.5
	var off := screen._paper_button(foot, "day_off", _more_day_off, "Add a day off (%d of %d)" % [int(e.days_off), Staff.MAX_DAYS_OFF], 20)
	if int(e.days_off) >= Staff.MAX_DAYS_OFF:
		off.disabled = true
		off.modulate.a = 0.5
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	screen._paper_button(foot, "fire", _set_firing.bind(true), "Fire...", 20)
	screen._paper_button(foot, "staff_back", close_person, "Back to the list", 20)


## The raise they named for a new duty: approve it, haggle it down, withdraw the duty, or
## deny it (and they quit).
func _raise_panel(e: Dictionary, who: String) -> void:
	var p: Dictionary = e.pending
	var area := CenterContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen._content.add_child(area)
	var sheet := HudWidgets.Sheet.new("note", 24, 16)
	sheet.rotation = -0.01
	area.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	sheet.add_child(box)
	var ask := HBoxContainer.new()
	ask.add_theme_constant_override("separation", 10)
	box.add_child(ask)
	ask.add_child(HudWidgets.Icon.new("coin", 30, false))
	screen._label(ask, 26, "%s wants $%d more a day to take on %s." % [who, int(p.raise), Staff.duty_word(p.duty).to_lower()])
	var now := screen._label(box, 18, "Now $%d a day; with the raise $%d." % [int(e.wage), int(e.wage) + int(p.raise)])
	now.modulate.a = 0.75
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	if screen._raise_offer >= 0:
		screen._paper_button(buttons, "rless", _nudge_raise.bind(-1), "-", 24).custom_minimum_size = Vector2(56, 0)
		var fig := screen._label(buttons, 26, "+$%d a day" % screen._raise_offer)
		fig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		screen._paper_button(buttons, "rmore", _nudge_raise.bind(1), "+", 24).custom_minimum_size = Vector2(56, 0)
		var offer: Button = screen.hud.receipt_ui._button(buttons, "Offer +$%d" % screen._raise_offer, func() -> void: answer_raise("haggle", screen._raise_offer))
		offer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		offer.custom_minimum_size = Vector2(180, 0)
		screen._target(offer, "raise_offer")
		screen._paper_button(buttons, "raise_back", _stop_raise_haggle, "Back", 22)
		return
	screen._paper_button(buttons, "withdraw", answer_raise.bind("withdraw"), "Withdraw the duty", 20)
	screen._paper_button(buttons, "raise_haggle", _start_raise_haggle, "Haggle", 20)
	screen._paper_button(buttons, "deny", answer_raise.bind("deny"), "Deny (they quit)", 20)
	var ok: Button = screen.hud.receipt_ui._button(buttons, "Approve +$%d" % int(p.raise), answer_raise.bind("approve"))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.custom_minimum_size = Vector2(190, 0)
	screen._target(ok, "approve")


func open_person(person: int) -> void:
	if screen.game.staff.employee(person).is_empty():
		return
	screen.tab = "staff"
	screen._person = person
	screen._raise_offer = -1
	screen._firing = false
	screen.note = ""
	screen._sel_key = "staff_back"
	screen.game.audio.sfx("page")
	screen.pages.render()


func close_person() -> void:
	var was := screen._person
	screen._person = -1
	screen._raise_offer = -1
	screen._firing = false
	screen.note = ""
	screen._sel_key = "manage:%d" % was
	screen.pages.render()


## Ticking a duty offers it; unticking takes it off (free, and they are glad).
func _toggle_staff_duty(d: String) -> void:
	var e: Dictionary = screen.game.staff.employee(screen._person)
	var who: String = screen.game.town.people[screen._person].name
	screen._sel_key = "duty:" + d
	if (e.duties as Array).has(d):
		screen.game.desk.desk_remove_duty(screen._person, d)
		screen.note = "%s is glad to be off %s." % [who, Staff.duty_word(d).to_lower()]
	else:
		var r: Dictionary = screen.game.desk.desk_add_duty(screen._person, d)
		if r.ok:
			screen.note = "%s takes on %s." % [who, Staff.duty_word(d).to_lower()]
		else:
			screen.note = ""
			screen._sel_key = "approve"
	screen.pages.render()


## The answer to a named raise (`Staff.answer_raise`), from the buttons or a test.
func answer_raise(choice: String, offer := 0) -> String:
	if screen._person < 0:
		return ""
	var person := screen._person
	var who: String = screen.game.town.people[person].name
	var duty: String = Staff.duty_word(str(screen.game.staff.employee(person).pending.get("duty", ""))).to_lower()
	var r: String = screen.game.desk.desk_answer_raise(person, choice, offer)
	match r:
		"added":
			screen.note = "%s takes on %s, at $%d a day." % [who, duty, int(screen.game.staff.employee(person).wage)]
			screen._raise_offer = -1
			screen._sel_key = "staff_back"
		"withdrawn":
			screen.note = "Withdrawn. %s carries on as before." % who
			screen._sel_key = "staff_back"
		"refuse":
			screen.note = "%s wants more than +$%d." % [who, offer]
		"quit":
			screen.note = "%s quits." % who
			screen._person = -1
			screen._raise_offer = -1
			screen._sel_key = "tab:staff"
	screen.pages.render()
	return r


func _start_raise_haggle() -> void:
	var p: Dictionary = screen.game.staff.employee(screen._person).pending
	screen._raise_offer = maxi(0, int(p.raise) - 1)
	screen._sel_key = "raise_offer"
	screen.game.audio.sfx("page")
	screen.pages.render()


func _nudge_raise(by: int) -> void:
	var p: Dictionary = screen.game.staff.employee(screen._person).pending
	screen._raise_offer = clampi(screen._raise_offer + by, 0, maxi(0, int(p.raise) - 1))
	screen.game.audio.sfx("tick")
	screen.pages.render()


func _stop_raise_haggle() -> void:
	screen._raise_offer = -1
	screen._sel_key = "raise_haggle"
	screen.pages.render()


func _more_break() -> void:
	if screen.game.desk.desk_add_break(screen._person):
		screen.note = "%s has a break more a day." % screen.game.town.people[screen._person].name
	screen._sel_key = "break"
	screen.pages.render()


func _more_day_off() -> void:
	if screen.game.desk.desk_add_day_off(screen._person):
		screen.note = "%s has a day off more a week, picked next week." % screen.game.town.people[screen._person].name
	screen._sel_key = "day_off"
	screen.pages.render()


func _set_firing(on: bool) -> void:
	screen._firing = on
	screen._sel_key = "keep" if on else "fire"
	screen.game.audio.sfx("page")
	screen.pages.render()


func _fire(severance: bool) -> void:
	var who: String = screen.game.town.people[screen._person].name
	if screen.game.desk.desk_fire(screen._person, severance):
		screen.note = "%s is let go%s." % [who, " with a day's wage" if severance else ", and their friends will hear of it"]
		screen._person = -1
		screen._firing = false
		screen._sel_key = "tab:staff"
	screen.pages.render()


## For tests and demos: opens the raise haggle at `offer`.
func start_raise_haggle(offer := -1) -> void:
	_start_raise_haggle()
	if offer >= 0:
		screen._raise_offer = offer
		screen.pages.render()


func managing() -> int:
	return screen._person
