class_name GamePaying
extends RefCounted
## Paying (PRD 11): table numbers, parties ready to pay, the till and its line, bills
## written and handed over, leaving unpaid, walkouts and guests leaving.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- paying (PRD 11)

const TILL_AFTER := 42.0   # tunable: seconds ready to pay before one of them goes to the till
const HAND_TIME := 1.0     # tunable: seconds of held E to hand a bill over
const CALL_EVERY := 0.5    # how often a ready table looks for someone to wave at
const TILL_GAP := 0.75     # metres between guests queued at the till
var pay_since := {}        # table Station -> clock when it became ready to pay
var _call_t := 0.0


## Every Table tile, in a fixed order: down the room, then across. Numbered from 1.
func dining_tables() -> Array[Station]:
	var out: Array[Station] = []
	for st: Station in game.stations.values():
		if Station.is_table(st.type):
			out.append(st)
	out.sort_custom(func(a: Station, b: Station) -> bool:
		return a.cell.x < b.cell.x if a.cell.x != b.cell.x else a.cell.y < b.cell.y)
	return out


func table_number(st: Station) -> int:
	return dining_tables().find(st) + 1


func table_by_number(n: int) -> Station:
	var all := dining_tables()
	return all[n - 1] if n >= 1 and n <= all.size() else null


## Everyone sat at this table who has not left.
func party_at(table: Station) -> Array[Guest]:
	var out: Array[Guest] = []
	for g: Guest in game.guests:
		if g.table == table and g.state != "leaving" and g.state != "queue" and g.state != "to_seat":
			out.append(g)
	return out


## The guests at this table who ordered something, and so are on the bill.
func payers(table: Station) -> Array[Guest]:
	return party_at(table).filter(func(g: Guest) -> bool: return not g.ordered_items().is_empty())


## Every guest at the table who ordered has eaten and chatted: one bill for the table.
func ready_to_pay(table: Station) -> bool:
	if table == null:
		return false
	var p := payers(table)
	return not p.is_empty() and p.all(func(g: Guest) -> bool: return g.paying())


## The patience the party is leaving on: the lowest among the payers. Every payer's bar
## shows this, so no bar reads full while someone at the table is about to give up.
func pay_patience(table: Station) -> float:
	var low := 1.0
	for g in payers(table):
		low = minf(low, g.mood.patience)
	return low


## Seconds this guest's table has been ready to pay, or -1 when it is not.
func pay_wait(g: Guest) -> float:
	if not g.paying() or not pay_since.has(g.table):
		return -1.0
	return game.clock - float(pay_since[g.table])


## The right bill for a table, from what its party ordered.
func right_bill(table: Station) -> Bill:
	var orders := []
	for g in payers(table):
		orders.append(g.ordered_items())
	return Bill.for_party(table_number(table), orders)


## The counter the till stands on (it moves with it). Null if it is gone.
## What a till could stand on at a cell: a counter, or a tool on one, with no till on it
## already and clean; null when there is none.
func _till_host(cell: Vector2i) -> Station:
	var st: Station = game.stations.get(cell)
	if st == null or not (st.type == "counter" or Kitchen.is_top(st.type)) or st.has_node("till") or game.room_edit.needs_cleaning(st):
		return null
	return st


func till_station() -> Station:
	for st: Station in game.stations.values():
		if st.has_node("till"):
			return st
	return null


func till_cell() -> Vector2i:
	var st := till_station()
	return st.cell if st != null else Game.NO_CELL


## The room-side cell in front of the till, where the line to pay starts.
func till_front() -> Vector2i:
	var t := till_cell()
	if t == Game.NO_CELL:
		return Game.NO_CELL
	var best := Game.NO_CELL
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]:
		var c := t + d
		if game.grid.in_bounds(c) and not game.grid.is_blocked(c) and game.grid.edge_open(t, c) and (best == Game.NO_CELL or c.x > best.x):
			best = c
	return best


## Where the `i`th guest in line at the till stands: a single file out into the room.
func till_spot(i: int) -> Vector3:
	var f := till_front()
	var d := f - till_cell()
	var dir := Vector3(d.x, 0, d.y)
	if dir == Vector3.ZERO:
		dir = Vector3(1, 0, 0)
	return Grid.center(f) - dir * 0.15 + dir * TILL_GAP * i


## Guests queued at the till (or on their way), front first.
func till_line() -> Array[Guest]:
	var out: Array[Guest] = []
	for g: Guest in game.guests:
		if g.state == "to_till" or g.state == "at_till":
			out.append(g)
	out.sort_custom(func(a: Guest, b: Guest) -> bool: return a.line_place < b.line_place)
	return out


## Everyone at the till steps up to their place; the line follows the till if it moved.
func reflow_till() -> void:
	var line := till_line()
	for i in line.size():
		var g := line[i]
		g.line_place = i
		var at := till_spot(i)
		var c := Grid.to_cell(at)
		g.walk_to(c if game.grid.in_bounds(c) else till_front(), at)
		if g.state == "at_till" and g.position.distance_to(at) > 0.05:
			g.state = "to_till"


## One of a ready table's guests stands and walks to the till.
func send_to_till(table: Station) -> Guest:
	if till_front() == Game.NO_CELL:
		return null
	var p := payers(table)
	var who: Guest = null
	for g in p:
		if g.calling:
			who = g
	if who == null:
		for g in party_at(table):
			if g.state == "to_pay":
				who = g
				break
	if who == null or who.state != "to_pay":
		return null
	who.stand_up()
	who.state = "to_till"
	who.calling = false
	who.line_place = till_line().size()
	who.mood.think("I'll go and pay at the till")
	reflow_till()
	return who


## Someone who could bring the bill and can see the table: a chef, or a helper with
## the take_payment duty (PRD 11.4).
func _bill_watchers() -> Array[Player]:
	var out: Array[Player] = game.chefs.duplicate()
	if game.crew != null:
		for h in game.crew.helpers:
			if game.crew.has_duty(h, "take_payment"):
				out.append(h)
	return out


func _sees(table: Station, who: Player) -> bool:
	return game.grid.has_los(table.cell, who.cell())


## The table numbers waiting to pay, for the bill screen: {number, size, till, printed}.
func bill_tables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st in dining_tables():
		if ready_to_pay(st):
			var at_till := party_at(st).any(func(g: Guest) -> bool: return g.state == "at_till" or g.state == "to_till")
			out.append({"number": table_number(st), "size": party_at(st).size(), "till": at_till,
				"printed": slip_out(table_number(st))})
	return out


## A slip for this table is already printed and in someone's hand. A chef's slip has no
## table yet, so only helper slips count.
func slip_out(number: int) -> bool:
	for h in game.serving.hands():
		if h.held == "bill" and h.bill != null and h.bill.table == number:
			return true
	return false


## Runs every step in service: tables become ready, call while watched, and after
## TILL_AFTER with no bill on the way one guest goes to the till.
func _tick_paying(delta: float) -> void:
	_call_t -= delta
	var look := _call_t <= 0.0
	if look:
		_call_t = CALL_EVERY
	for st in dining_tables():
		if not ready_to_pay(st):
			pay_since.erase(st)
			for g in party_at(st):
				g.calling = false
			continue
		if not pay_since.has(st):
			pay_since[st] = game.clock
		var p := payers(st)
		if look:
			var seen := _bill_watchers().any(func(w: Player) -> bool: return _sees(st, w))
			var caller: Guest = null
			for g in p:
				if g.calling:
					caller = g
			if seen and caller == null:
				for g in p:
					if g.state == "to_pay":
						caller = g
						break
				if caller != null:
					caller.calling = true
					game.audio.sfx("bell", 0.04, 1.3)
			elif not seen and caller != null:
				caller.calling = false
		var at_till := party_at(st).any(func(g: Guest) -> bool: return g.state == "to_till" or g.state == "at_till")
		if not at_till and game.clock - float(pay_since[st]) >= TILL_AFTER and not slip_out(table_number(st)):
			send_to_till(st)
	# Slips for tables that have gone are thrown away; a slip with no table, once nobody
	# is waiting to pay.
	var anyone := not bill_tables().is_empty()
	for h in game.serving.hands():
		if h.held != "bill" or h.bill == null:
			continue
		if h.bill.table < 0:
			if not anyone:
				h.set_held("")
		elif not ready_to_pay(table_by_number(h.bill.table)) and payers(table_by_number(h.bill.table)).is_empty():
			h.set_held("")


## Everyone at the table goes: the company with them, the one at the till out of the door.
func _party_leaves(table: Station) -> void:
	for g in party_at(table):
		g.calling = false
		g.line_place = -1
		_leave(g)
	pay_since.erase(table)
	reflow_till()


## The bill is right: each guest who ordered pays their share, then the party leaves.
func pay_bill(table: Station) -> void:
	for g in payers(table):
		game.serving._pay_guest(g)
	game.audio.sfx("coin")
	_party_leaves(table)


## A party waited to pay until they gave up (PRD 11): no money, no tip, an opinion drop
## friends hear about. Not a walkout and not a strike.
func leave_unpaid(table: Station, quitter: Guest = null) -> void:
	var p := payers(table)
	if p.is_empty():
		return
	game.ledger.record_unpaid_bill()
	var talk := ""
	for g in p:
		g.mood.skipped_bill = true
		g.mood.think("Nobody came with the bill")
		game.day._critic_leaves(g, false)
		talk = game.town.left_unpaid(g.idx)
	if p.size() == 1:
		game.hud.day_ui.say(talk)
	elif quitter != null:
		game.hud.day_ui.say("%s gave up: table %d left without paying. Nobody came." % [game.town.people[quitter.idx].name, table_number(table)])
	else:
		game.hud.day_ui.say("Table %d left without paying. Nobody came." % table_number(table))
	game.audio.sfx("fail")
	_party_leaves(table)


## Where the chef holding a bill would hand it over: the table they face, if its party is
## waiting to pay, or the till they face, if someone is queued there. Null for neither.
func bill_target(ch: Player) -> Station:
	if ch.held != "bill":
		return null
	var st := game.world.station_at(ch.target_cell())
	return st if bill_place(st) else null


## A bill can be handed over here: a table whose party waits to pay, or the till with
## someone queued at it.
func bill_place(st: Station) -> bool:
	if st == null:
		return false
	if not st.seats.is_empty() and ready_to_pay(game.tables.lead(st)):
		return true
	return st == till_station() and till_line().any(func(g: Guest) -> bool: return g.state == "at_till")


## The table a bill handed over at `at` is checked against: that table, or at the till
## the table of the first guest there whose order the slip matches exactly (else the guest
## at the front).
func _bill_table_at(at: Station, bill: Bill) -> Station:
	if at != till_station():
		return game.tables.lead(at)   # a bill handed at either half is for the one table
	var front: Station = null
	for g in till_line():
		if g.state != "at_till":
			continue
		if bill.table >= 0:
			if table_number(g.table) == bill.table:
				return g.table
		elif Bill.check(bill, right_bill(g.table)) is String:
			return g.table
		if front == null:
			front = g.table
	return front


## The hold filled: the bill is checked. Right, they pay and go; wrong, they refuse it and
## say what is wrong, the slip is thrown away and each loses a little joy.
func give_bill(ch: Player, at: Station) -> bool:
	var table := _bill_table_at(at, ch.bill)
	if table == null or ch.bill == null:
		return false
	var written := ch.bill
	ch.set_held("")
	ch.punch()
	var diff = Bill.check(written, right_bill(table))
	if diff is String:
		pay_bill(table)
		return true
	var line := Bill.refusal(diff, game.menu)
	for g in party_at(table):
		g.mood.refuse_bill(line)
	var who := payers(table)
	if not who.is_empty():
		game.hud.day_ui.say("%s: \"%s.\"" % [who[0].info.name, line])
		Fx.play(who[0], "anger", Vector3(0, 1.75, 0), 0.3)
	game.audio.sfx("fail")
	return false


## Opens the bill screen for a chef at the till.
func open_bill(ch: Player) -> void:
	game.hud.open_bill(ch)
	game.audio.sfx("page")


func close_bill() -> void:
	game.hud.close_bill()


## "Print": the slip goes into the chef's hand (replacing one already held), and the screen closes.
func print_bill(ch: Player, bill: Bill) -> void:
	if bill.is_empty() or (bill.table >= 0 and slip_out(bill.table)) or ch.held not in ["", "bill"]:
		game.audio.sfx("fail")
		return
	var slip := Bill.new(bill.table, bill.items)
	ch.set_held("bill")
	ch.bill = slip
	close_bill()
	game.audio.sfx("page")


## A chef holding E with a bill fills the hand-over bar; walking off cancels it.
func _tick_giving(ch: Player, held: bool, delta: float) -> void:
	if ch.held != "bill":
		return
	var at := bill_target(ch)
	if ch.demo_giving >= 0.0 and at != null:
		ch.show_giving(at, ch.demo_giving)
		return
	if not held or at == null or (ch.give_at != null and ch.give_at != at):
		ch.stop_giving()
		return
	ch.give_at = at
	ch.give_t += delta
	ch.show_giving(at, ch.give_t / HAND_TIME)
	if ch.give_t >= HAND_TIME:
		give_bill(ch, at)


## One guest runs out of patience and the rest of their group who are still
## waiting go with them. That is one walkout on the card, however many leave.
func walk_out(g: Guest) -> void:
	var going: Array[Guest] = []
	for m: Guest in (g.party if not g.party.is_empty() else [g]):
		if is_instance_valid(m) and (m == g or m.state == "queue" or m.state == "to_seat" or m.seated_waiting()):
			going.append(m)
	# Out of the line one after another, the one nearest the door first.
	var in_line := going.filter(func(m: Guest) -> bool: return m.line_place >= 0)
	in_line.sort_custom(func(a: Guest, b: Guest) -> bool: return a.line_place < b.line_place)
	for k in in_line.size():
		in_line[k].hold = 0.5 * k
	game.ledger.record_walkout()
	var names: Array[String] = []
	var talk := ""
	for m in going:
		m.mood.think("I'm never coming back")
		m.stormed = true
		talk = game.town.gossip_line(m.idx, game.town.record_walkout(m.idx, game.ledger.day), "", true)
		game.day._critic_leaves(m, true)
		names.append(m.info.name)
		var mark := Fx.play(m, "anger", Vector3(0, 1.75, 0), 0.3, true)
		mark.fps = 6.0
		_leave(m)
	game.hud.day_ui.say(("%s walked out! " % " and ".join(names)) + (talk if going.size() == 1 else ""))
	game.audio.sfx("fail")
	game.audio.shake()


## A guest who found nothing they liked goes once their friends have gone.
func leave_with_friends(g: Guest) -> void:
	_leave(g)


func _leave(g: Guest) -> void:
	game.serving.tear_ticket(g)
	game.seat_taken.erase(g.seat)
	g.stand_up()
	g.walk_to(Game.EXIT)
	if game.queue.has(g):
		game.queue.erase(g)
		game.seating._reflow_queue()
		g.line_place = -1
		# Out of the line onto the outer half of the pavement first, not down
		# through the people still waiting.
		var out := game.seating.outer_lane(g.cell.y)
		g.path.assign(game.grid.find_path(g.cell, out) + game.grid.find_path(out, Game.EXIT))


func remove_guest(g: Guest) -> void:
	if game.inspected == g:
		game.day.inspect(null)
	game.guests.erase(g)
	g.queue_free()
