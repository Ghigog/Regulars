class_name DeskPosting
extends RefCounted
## The desk's actions on posts and CVs: tabs, hiring and dismissing, haggling over an offer,
## writing a post (duties, fields, its name typed letter by letter) and putting it up.

var screen: DeskScreen


func _init(screen_: DeskScreen) -> void:
	screen = screen_


# ---------------------------------------------------------------- what the buttons do

func _set_tab(t: String) -> void:
	screen.tab = t
	screen._sel_key = "hire" if t == "cvs" and not screen.game.staff.cvs.is_empty() else "tab:" + t
	screen.note = ""
	screen._offer = -1
	screen._person = -1
	screen._raise_offer = -1
	screen._firing = false
	screen.game.audio.sfx("page")
	screen.pages.render()


## Swipe right: hire the top CV at their ask.
func hire_top() -> void:
	var staff: Staff = screen.game.staff
	if staff.cvs.is_empty():
		return
	var cv: Dictionary = screen.pages._cv()
	var who: String = screen.game.town.people[cv.person].name
	if screen.game.desk.desk_hire(int(cv.id)):
		screen.note = "%s is hired, at $%d a day." % [who, int(cv.ask)]
	screen._offer = -1
	screen.pages.render()


## Swipe left: send the top CV's applicant home.
func dismiss_top() -> void:
	var staff: Staff = screen.game.staff
	if staff.cvs.is_empty():
		return
	screen.game.desk.desk_dismiss(int(screen.pages._cv().id))
	screen.note = ""
	screen._offer = -1
	screen.pages.render()


func _start_haggle() -> void:
	var staff: Staff = screen.game.staff
	if staff.cvs.is_empty():
		return
	var ask := int(screen.pages._cv().ask)
	var last := int(screen.pages._cv().haggle.last)
	screen._offer = clampi(last if last > 0 else int(round(ask * 0.85)), 1, maxi(1, ask - 1))
	screen._sel_key = "offer"
	screen.game.audio.sfx("page")
	screen.pages.render()


func _nudge_offer(by: int) -> void:
	var ask := int(screen.pages._cv().ask)
	screen._offer = clampi(screen._offer + by, 1, maxi(1, ask - 1))
	screen.game.audio.sfx("tick")
	screen.pages.render()


func _stop_haggle() -> void:
	screen._offer = -1
	screen._sel_key = "haggle"
	screen.pages.render()


## Offers the figure. They accept, refuse (try again), take it after two refusals, or walk.
func _make_offer() -> void:
	make_offer(screen._offer)


func make_offer(figure: int) -> String:
	var staff: Staff = screen.game.staff
	if staff.cvs.is_empty():
		return ""
	var cv: Dictionary = screen.pages._cv()
	var who: String = screen.game.town.people[cv.person].name
	var r: String = screen.game.desk.desk_haggle(int(cv.id), figure)
	match r:
		"accept":
			screen.note = "%s takes $%d a day. Hired." % [who, figure]
			screen._offer = -1
		"take_last":
			screen.note = "%s grumbles, but takes $%d a day. Hired." % [who, figure]
			screen._offer = -1
		"refuse":
			screen.note = "%s wants more than $%d." % [who, figure]
			screen._offer = figure
		"walk":
			screen.note = "%s won't work for that, and goes home." % who
			screen._offer = -1
	screen.pages.render()
	return r


func _take_down(id: int) -> void:
	screen.game.desk.desk_take_down(id)
	screen.pages.render()


func _write() -> void:
	if not screen.game.staff.can_post(screen.game.desk.desk_count()):
		return
	screen._draft = {"name": "", "duties": [], "breaks": 1, "days_off": 1}
	screen._sel_key = "name"
	screen.game.audio.sfx("page")
	screen.pages.render()


func _toggle_duty(d: String) -> void:
	var duties: Array = screen._draft.duties
	if duties.has(d):
		duties.erase(d)
	else:
		duties.append(d)
	screen._sel_key = "duty:" + d
	screen.game.audio.sfx("tick")
	screen.pages.render()


func _set_field(field: String, n: int) -> void:
	screen._draft[field] = n
	screen._sel_key = "%s:%d" % [field, n]
	screen.game.audio.sfx("tick")
	screen.pages.render()


func _cancel_post() -> void:
	screen._draft = {}
	screen._naming = ""
	screen._sel_key = "write"
	screen.pages.render()


func _put_up() -> void:
	if (screen._draft.duties as Array).is_empty():
		return
	var title: String = screen._draft.name if str(screen._draft.name) != "" else DeskScreen.DEFAULT_NAME
	if screen.game.desk.desk_post(title, screen._draft.duties, int(screen._draft.breaks), int(screen._draft.days_off)) >= 0:
		screen._draft = {}
		screen.tab = "posts"
		screen._sel_key = "write"
	screen.pages.render()


func _start_name() -> void:
	screen._naming = "grid" if screen.hud._mode() == "pad" else "type"
	screen._name_text = screen._draft.name
	screen._sel_key = "L:0"
	screen.game.audio.sfx("page")
	screen.pages.render()


func _focus_line() -> void:
	if screen._line != null and is_instance_valid(screen._line):
		screen._line.grab_focus()
		screen._line.edit()
		screen._line.caret_column = screen._line.text.length()


func _type_letter(c: String) -> void:
	if screen._name_text.length() < Staff.MAX_POST_NAME:
		screen._name_text += c if screen._name_text.length() == 0 or screen._name_text.ends_with(" ") else c.to_lower()
		screen.game.audio.sfx("tick")
		screen.pages.render()


func _rub_out() -> void:
	screen._name_text = screen._name_text.substr(0, maxi(0, screen._name_text.length() - 1))
	screen.game.audio.sfx("tick")
	screen.pages.render()


func _finish_name() -> void:
	if screen._naming == "":
		return
	var text := screen._name_text if screen._naming == "grid" else (screen._line.text if screen._line != null and is_instance_valid(screen._line) else str(screen._draft.name))
	screen._naming = ""
	screen._draft.name = text.strip_edges().substr(0, Staff.MAX_POST_NAME)
	screen._sel_key = "name"
	screen.pages.render()
