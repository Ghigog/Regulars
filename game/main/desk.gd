class_name GameDesk
extends RefCounted
## The staff desk (PRD 10.3, 10.4, 10.8) as the room sees it: desks, job posts, hiring,
## haggling, applicants in line, wages, duties, breaks and days off, firing.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- the desk (PRD 10.3)

## Desks in the room: one for each post and each hire.
func desk_count() -> int:
	return game.menu_stock.stations_of("desk").size()


## The desk the chef faces, or null.
func desk_in_front(ch: Player = null) -> Station:
	ch = game._me(ch)
	var st: Station = game.stations.get(ch.target_cell())
	return st if st != null and st.type == "desk" else null


## The duties a post can hold tonight, by kind, read from the room (`Staff.room_duties`).
func room_duties() -> Dictionary:
	var pieces := []
	for st: Station in game.stations.values() + game.highs.values():   # a hook's sponge hangs high (PRD 9.4)
		pieces.append(st.type)
		if st.kit_tool != "":
			pieces.append(st.kit_tool)
	return Staff.room_duties(game.menu_stock.kitchen_tools(), pieces)


## The desk screen, at night only, from either chef. Everything about staff is done here.
func open_desk(ch: Player = null) -> bool:
	ch = game._me(ch)
	if game.phase != Game.Phase.BUILD or desk_count() == 0 or game.hud.card_open() or Cleaning.carrying_mess(ch.held):
		return false
	if game.shopping:
		game.session.close_shop()
	if not ch.hand.is_empty():
		game.placing.cancel_hand(ch)
	game.hud.open_desk()
	game.audio.sfx("slide")
	return true


func close_desk() -> void:
	if game.hud.desk_open():
		game.hud.close_desk()
		game.audio.sfx("slide", 0.0, 0.8)
		_refresh_desks()


## Puts up a post. Refused (-1) when every desk is taken.
func desk_post(post_name: String, duties: Array, breaks: int, days_off: int) -> int:
	var id := game.staff.add_post(post_name, duties, breaks, days_off, desk_count())
	game.audio.sfx("page" if id >= 0 else "fail")
	return id


func desk_take_down(id: int) -> void:
	for c in game.staff.cvs:
		if c.post == id:
			_send_home(int(c.person))
	game.staff.remove_post(id)
	game.audio.sfx("page")
	_refresh_desks()


## Hires a CV at its ask (or `wage`). The post is filled: its other applicants go home.
func desk_hire(cv_id: int, wage := -1) -> bool:
	var c := game.staff.cv(cv_id)
	if c.is_empty():
		return false
	var others := game.staff.cvs.filter(func(o: Dictionary) -> bool: return o.post == c.post)
	if game.staff.hire(cv_id, wage, game.ledger.day) < 0:
		return false
	for o in others:
		_send_home(int(o.person), int(o.person) == int(c.person))
	game.audio.sfx("coin")
	_refresh_desks()
	return true


func desk_dismiss(cv_id: int) -> void:
	var c := game.staff.cv(cv_id)
	if c.is_empty():
		return
	game.staff.dismiss(cv_id)
	_send_home(int(c.person))
	game.audio.sfx("slide", 0.0, 0.8)
	_refresh_desks()


## Haggling at hire (section 5): "accept", "refuse", "take_last" or "walk".
func desk_haggle(cv_id: int, offer: int) -> String:
	var c := game.staff.cv(cv_id)
	if c.is_empty():
		return ""
	var others := game.staff.cvs.filter(func(o: Dictionary) -> bool: return o.post == c.post)
	var r := game.staff.haggle_hire(cv_id, offer, game.ledger.day)
	match r:
		"accept", "take_last":
			for o in others:
				_send_home(int(o.person), int(o.person) == int(c.person))
			game.audio.sfx("coin")
		"refuse":
			game.audio.sfx("fail")
		"walk":
			_send_home(int(c.person))
			game.audio.sfx("fail")
	_refresh_desks()
	return r


## The start of the build phase: tonight's applicants send their CVs to the pile and
## stand in a line outside the door. Earlier CVs stay in the pile; their people do not
## queue again.
func roll_applicants() -> Array[Dictionary]:
	var fresh := game.staff.roll_applicants(Staff.candidates(game.town, game.ledger.day))
	_clear_applicants()
	for i in fresh.size():
		var person := int(fresh[i].person)
		var peg := Peg.guest(game.town.people[person].name)
		var rig := Peg.rigged(peg)
		game.add_child(rig)
		rig.position = game.seating.queue_spot(i)
		rig.rotation.y = PI / 2   # facing the door
		game.applicants[person] = rig
	if not fresh.is_empty():
		game.hud.say("%s outside: %s in the pile at the desk." % [
			"An applicant is" if fresh.size() == 1 else "%d applicants are" % fresh.size(),
			"a CV" if fresh.size() == 1 else "their CVs"])
	_refresh_desks()
	return fresh


## Someone in tonight's line leaves it: hired (they come back to work, 10.6) or sent home.
func _send_home(person: int, hired := false) -> void:
	if not game.applicants.has(person):
		return
	var rig: Node3D = game.applicants[person]
	game.applicants.erase(person)
	game.audio.burst(rig.position + Vector3(0, 1.2, 0), "stars" if hired else "puff", 0.4)
	rig.queue_free()


func _clear_applicants() -> void:
	for rig: Node3D in game.applicants.values():
		rig.queue_free()
	game.applicants.clear()


# ---------------------------------------------------------------- the staff list (PRD 10.4)

## Tonight's wages, for the restock note.
func staff_wages() -> int:
	return game.staff.wages_due()


## The night ends as the door opens: wages are paid with the stock, a STAFF line on the
## receipt. A wage that cannot be paid is not owed later; that employee takes the hit
## instead. Satisfaction moves, and anyone at the bottom too long quits.
func pay_staff() -> Dictionary:
	if game.staff.employees.is_empty():
		return {}
	var night := game.staff.end_night(game.ledger.money)
	game.ledger.pay_staff(int(night.paid), (night.unpaid as Array).size())
	var words: Array[String] = []
	for p: int in night.unpaid:
		if not (night.quit as Array).has(p):
			words.append("%s wasn't paid" % game.town.people[p].name)
	for p: int in night.quit:
		words.append("%s quit" % game.town.people[p].name)
	if not words.is_empty():
		game.hud.say(". ".join(words) + ".")
	return night


## Offers a hire a new duty. {ok: true} when taken, else {ok: false, raise} and the
## raise waits on the desk for an answer (`desk_answer_raise`).
func desk_add_duty(person: int, duty: String) -> Dictionary:
	var r := game.staff.propose_duty(person, duty)
	game.audio.sfx("page" if r.ok else "fail")
	return r


## "withdraw", "approve", "deny" (they quit) or "haggle" with a smaller raise `offer`.
## Returns "added", "withdrawn", "refuse" or "quit".
func desk_answer_raise(person: int, choice: String, offer := 0) -> String:
	var r := game.staff.answer_raise(person, choice, offer)
	match r:
		"added":
			game.audio.sfx("coin")
		"refuse", "quit":
			game.audio.sfx("fail")
		"withdrawn":
			game.audio.sfx("page")
	_refresh_desks()
	return r


func desk_remove_duty(person: int, duty: String) -> void:
	game.staff.remove_duty(person, duty)
	game.audio.sfx("tick")


func desk_add_break(person: int) -> bool:
	var ok := game.staff.add_break(person)
	game.audio.sfx("tick" if ok else "fail")
	return ok


func desk_add_day_off(person: int) -> bool:
	var ok := game.staff.add_day_off(person)
	game.audio.sfx("tick" if ok else "fail")
	return ok


## Whether a day's wage can be paid as severance now.
func can_pay_severance(person: int) -> bool:
	var e := game.staff.employee(person)
	return not e.is_empty() and int(e.wage) <= game.ledger.money


## Fires a hire, with severance (a day's wage, paid now) or without (their opinion drops
## more and their friends hear it). False if the severance cannot be paid.
func desk_fire(person: int, severance: bool) -> bool:
	if game.staff.employee(person).is_empty() or (severance and not can_pay_severance(person)):
		game.audio.sfx("fail")
		return false
	var r := game.staff.fire(person, severance)
	if int(r.cost) > 0:
		game.ledger.spend(int(r.cost))
	game.town.record_fired(person, float(r.drop), float(r.friend_drop))
	game.audio.sfx("putdown")
	_refresh_desks()
	return true


## The CV pile on each desk: a sheet of paper per CV, up to a handful.
func _refresh_desks() -> void:
	for st in game.menu_stock.stations_of("desk"):
		var old := st.get_node_or_null("pile")
		if old:
			old.free()
		var n := game.staff.cvs.size()
		if n == 0:
			continue
		var pile := Node3D.new()
		pile.name = "pile"
		st.add_child(pile)
		for k in mini(n, 6):
			Build.box(pile, Vector3(0.12, 0.775 + k * 0.012, 0.08), Vector3(0.3, 0.008, 0.38), Build.PAPER) \
				.rotation.y = [0.0, 0.12, -0.08, 0.2, -0.15, 0.05][k]
