class_name GameServing
extends RefCounted
## Orders and serving: taking a table's orders, tickets and trays, handing dishes to the
## right guests, the dirty table left behind, half price and comps, finishing a meal.

var game: Game


func _init(game_: Game) -> void:
	game = game_


## What this guest orders: {main, side, drink}. Chosen at the door with their group
## (`planned`); a guest who came in some other way chooses now.
func order_for(g: Guest) -> Dictionary:
	if not g.planned.is_empty() or g.orders_nothing:
		return g.planned
	return Menu.order(game.menu_stock.tonight_menu(), g.info.likes, g.info.dislikes, game.town.rng)


## The chef takes the whole table's order in one go. Each guest who ordered
## something gets a ticket on the rail.
func take_orders(table: Station) -> void:
	for g in game.seating._guests_to_order(table):
		var o := order_for(g).duplicate()
		var items: Array[Dictionary] = []
		for c in Menu.COURSES:
			if not (o.get(c, {}) as Dictionary).is_empty():
				items.append(o[c])
				game.town.record_order(g.idx, int(o[c].id))
				game.ledger.record_order(int(o[c].id))
		o["ticket"] = -1
		if not items.is_empty():
			o.ticket = game._next_ticket
			game._next_ticket += 1
			var order := Tray.new()
			order.assign(o.ticket, items)
			game.tickets.append({"id": o.ticket, "guest": g, "items": items, "order": order})
		g.take_order(o)
		g.mood.patience = minf(1.0, g.mood.patience + Game.ORDER_RELIEF)
	game.hud.day_ui.refresh_tickets()
	game.audio.sfx("order_take")


func find_ticket(id: int) -> Dictionary:
	for t in game.tickets:
		if int(t.id) == id:
			return t
	return {}


## Everyone with hands in the room: the chefs, then the helpers at work (PRD 10.6).
func hands() -> Array[Player]:
	var out: Array[Player] = game.chefs.duplicate()
	if game.crew != null:
		out.append_array(game.crew.helpers)
	return out


## Every order on the rail: what each guest has been served so far.
func all_trays() -> Array[Tray]:
	var out: Array[Tray] = []
	for tk: Dictionary in game.tickets:
		if tk.has("order"):
			out.append(tk.order)
	return out


## A ticket's order record: its lines and what has been served on each.
func tray_for_ticket(id: int) -> Tray:
	var tk := find_ticket(id)
	return tk.get("order") if not tk.is_empty() else null


## The colour of a ticket's slip: its guest's shirt, or "" with no ticket.
func ticket_tag(id: int) -> String:
	var tk := find_ticket(id)
	return "" if tk.is_empty() else str(tk.guest.info.shirt)


## The waiting guests at this table who want one of these dishes, each once.
func _dish_guests(table: Station, dishes: Array) -> Array[Guest]:
	var out: Array[Guest] = []
	var taken := {}
	for d: Dish in dishes:
		var g := _guest_for_dish(table, d, taken)
		if g != null:
			taken[g] = int(taken.get(g, 0)) + 1
			if not out.has(g):
				out.append(g)
	return out


## The waiting guest at this table with a line still open for this dish's item: the
## least patient first. `taken` counts dishes already promised to each guest this press.
func _guest_for_dish(table: Station, d: Dish, taken := {}) -> Guest:
	if d == null or d.vessel == "" or d.dirty:
		return null
	var it := d.item_of(game.menu.items)
	if it.is_empty():
		return null
	var best: Guest = null
	for s in game.tables.seats_of(table):   # either half of a combined table
		if not game.seat_taken.has(s):
			continue
		var g: Guest = game.seat_taken[s]
		if g.state != "waiting":
			continue
		var t := tray_for_ticket(int(g.order.get("ticket", -1)))
		if t == null:
			continue
		# Lines for this item not yet served, less those already promised this press.
		var free := 0
		for l in t.lines:
			if int(l.item.id) == int(it.id) and not t._served(l):
				free += 1
		if free <= int(taken.get(g, 0)):
			continue
		if best == null or g.mood.patience < best.mood.patience:
			best = g
	return best


## Sets down every dish in hand that a waiting guest at this table ordered. A guest
## whose whole order is there starts eating. Returns how many were served.
func serve_dishes(ch: Player, table: Station) -> int:
	var n := 0
	for d: Dish in ch.dishes.duplicate():
		var g := _guest_for_dish(table, d)
		if g == null:
			continue
		var t := tray_for_ticket(int(g.order.ticket))
		if t.serve_dish(d, game.menu.items) < 0:
			continue
		ch.drop_dish(d)
		n += 1
		if t.is_complete():
			serve(g, t)
		else:
			g.show_served(t)
			game.audio.sfx("plate_food")
			game.hud.day_ui.say("%s is still waiting for the %s." % [g.info.name, _list(t.waiting_for())])
	game.hud.day_ui.refresh_tickets()
	return n


## Names joined for a sentence: "soda", "soda and fries", "soda, fries and a bun".
func _list(names: Array[String]) -> String:
	var low: Array[String] = []
	for n in names:
		low.append(n.to_lower())
	if low.size() < 2:
		return "".join(low)
	return ", ".join(low.slice(0, -1)) + " and " + low[-1]


## Why none of the dishes in hand can be served here.
func _not_served_why(dishes: Array) -> String:
	for d: Dish in dishes:
		if d.vessel == "" and not d.is_empty():
			return "Put it on a plate first"
	for d: Dish in dishes:
		if d.is_empty():
			continue
		if d.item_of(game.menu.items).is_empty():
			var it := d.heading_for(game.menu.items)
			if not it.is_empty():
				var need := d.needs_for(it)
				if not need.is_empty():
					return "Needs %s" % Pantry.name_of(need[0]).to_lower()
	return "Nobody here ordered that"


## Turns a dispenser with several taps to its next tap.
func turn_tap(st: Station) -> bool:
	if st == null or game.menu_stock.dispenser_drinks(st).size() < 2:
		return false
	st.tap = (st.tap + 1) % game.menu_stock.dispenser_drinks(st).size()
	game.hud.day_ui.say("Turned to %s." % Pantry.name_of(game.menu_stock.dispenser_drinks(st)[st.tap]).to_lower())
	game.audio.sfx("page")
	return true


## Tears a guest's ticket off the rail. What was already served to them is left on the
## table as dirty dishes.
func tear_ticket(g: Guest) -> void:
	var id := int(g.order.get("ticket", -1))
	if id < 0:
		return
	var tk := find_ticket(id)
	if tk.is_empty():
		return
	game.tickets.erase(tk)
	var t: Tray = tk.get("order")
	if t != null and t.served_count() > 0 and g.state in ["waiting", "ordering"] and g.table != null:
		_leave_dirty(game.tables.half_of_seat(g.table, g.seat), t)   # on the half they sat at
		g.clear_meal()
	game.hud.day_ui.refresh_tickets()


## Leaves a guest's served plates and cups on the table, dirty.
func _leave_dirty(table: Station, t: Tray) -> void:
	for l in t.lines:
		var served := false
		for q: float in l.have:
			served = served or q >= 0.0
		if served:
			table.dirty += 1
			if l.item.course == "drink":
				table.dirty_cups += 1
	table.refresh()


## How the meal tastes to this guest: its quality, raised for what they like.
func savour_for(g: Guest, t: Tray) -> float:
	return Menu.savour(t.qualities(), t.ingredients(), g.info.likes)


func serve(g: Guest, t: Tray) -> void:
	if g == game.critic_guest:
		game._critic_seen = {"patience": g.mood.patience, "quality": t.quality()}
		if Critic.speed_rating(g.mood.patience) <= 3:
			g.mood.think(Critic.thought("wait"))
		g.mood.think(Critic.thought("good" if Critic.quality_rating(t.quality()) >= 4 else "bad"))
	if g.mood.patience > 0.65:
		g.mood.delight(0.15, "That was quick!")
	var q := savour_for(g, t)
	var perfect := Prep.is_perfect(t.quality())
	game.perfect_streak = game.perfect_streak + 1 if perfect else 0
	g.perfect_streak = game.perfect_streak
	if perfect:
		game.ledger.record_perfect(game.perfect_streak)
		game.town.record_praise(g.idx, Prep.streak_rep(game.perfect_streak))
		if game.perfect_streak >= 2:
			game.audio.popup("Perfect! x%d" % game.perfect_streak, g.position + Vector3(0, 2.5, 0), Color(Build.GOOD))
	g.mood.think("Perfectly done" if perfect else ("Just right" if t.quality() >= Prep.PLAIN - 0.01 else "A bit off, this"))
	g.bill_base = t.price()
	game.tickets.erase(find_ticket(t.ticket))
	t.ticket = -1
	game.hud.day_ui.refresh_tickets()
	g.liked_meal = Menu.liked_count(t.ingredients(), g.info.likes) > 0
	if g.liked_meal:
		g.mood.think(Menu.LIKED_THOUGHT)
	var settled := g.start_eating(q, t)
	if settled != "":
		g.mood.think(settled)
	game.audio.sfx("serve")
	if perfect:
		game.audio.sfx("perfect")
		game.audio.burst(g.position + Vector3(0, 1.3, 0), "stars")


## A guest's whole order served, every ingredient at quality `q`. For demos
## and tests: their table's order is taken first if it has not been.
func full_tray_for(g: Guest, q := 1.0) -> Tray:
	if g.order.is_empty() and g.state == "ordering":
		take_orders(g.table)
	var tk := find_ticket(int(g.order.get("ticket", -1)))
	if tk.is_empty():
		return Tray.new()
	var t: Tray = tk.order
	for l in t.lines:
		for k in l.have.size():
			l.have[k] = q
	return t


## Kindness: half price to say sorry for the wait. The town remembers it.
## Deals at a table (review, item 11): E starts a hold and the deal is given once E has
## been held DEAL_HOLD, with the same fill bar as every hold. Let go, or walk off, and
## nothing is given away.
const DEAL_HOLD := 0.6   # tunable
var _deal_hold := {}     # Player -> {g: Guest, kind: "half" | "comp", t: seconds held}


func _tick_deal(ch: Player, held: bool, delta: float) -> void:
	if not _deal_hold.has(ch):
		return
	var d: Dictionary = _deal_hold[ch]
	var g: Guest = d.g
	if not held or not is_instance_valid(g) or g.table == null or game.world.station_at(ch.target_cell()) != g.table:
		_deal_hold.erase(ch)
		ch.stop_giving()
		return
	d.t = float(d.t) + delta
	ch.show_hold(g.table.global_position, float(d.t) / DEAL_HOLD, "coin")
	if float(d.t) >= DEAL_HOLD:
		_deal_hold.erase(ch)
		ch.stop_giving()
		if d.kind == "half":
			offer_discount(g)
		else:
			offer_comp(g)


func offer_discount(g: Guest) -> void:
	if not g.mood.offer_discount():
		return
	game.town.record_kindness(g.idx, "half")
	game.hud.day_ui.say("Half price for %s. Word gets around." % g.info.name)
	game.audio.burst(g.position + Vector3(0, 1.5, 0), "stars", 0.3)
	g._heart_time = 1.5
	game.audio.sfx("coin")


## The bigger kindness: the meal is free, for a guest who is very unhappy. Their
## friends hear about it.
func offer_comp(g: Guest) -> void:
	if not g.mood.offer_comp():
		return
	game.town.record_kindness(g.idx, "comp")
	game.hud.day_ui.say("%s eats free tonight. Their friends will hear of it." % g.info.name)
	game.audio.burst(g.position + Vector3(0, 1.5, 0), "stars")
	g._heart_time = 2.5
	game.audio.sfx("perfect")


## The last bite (PRD 11): the plate is left on the table and they sit back to chat.
## Paying comes later, when the bill is handed over (`pay_bill`).
func finish_meal(g: Guest) -> void:
	var half := game.tables.half_of_seat(g.table, g.seat)   # the plate stays where they sat
	if g._meal_tray != null:
		_leave_dirty(half, g._meal_tray)
	else:
		half.dirty += 1
		half.refresh()
	game.floor_dirt.meal_mess(g)
	if g._meal:
		g._meal.queue_free()
		g._meal = null
	g.state = "chatting"
	g.timer = Guest.CHAT_TIME


## One guest pays their share of the table's bill: what `finish_meal` paid before PRD 11.
## They pay what the slip says, less any deal (review, item 11: the amount paid never
## differs from the slip). How happy they are still moves the money: "ordered extras"
## (or, in a hurry, skimping) goes with the tip, never below nothing.
func _pay_guest(g: Guest) -> void:
	var bill := g.mood.bill_for(g.bill_base)
	var extras := g.mood.pay_for(g.bill_base) - bill
	if g.mood.paid_full():   # someone used to deals is let down by full price
		var letdown := game.town.paid_full_price(g.idx)
		if letdown > 0.0:
			g.mood.delight(-letdown, "Full price this time? Hm")
	var tip := maxi(0, g.mood.tip_for(bill, game.town.tip_bonus(g.idx) * Prep.streak_tip(g.perfect_streak)) + extras)
	var was_sore: bool = g.info.sore
	var was_regular := game.town.is_regular(g.idx)
	game.ledger.record_sale(bill, tip)
	game.ledger.record_visit(g.mood.satisfaction())   # the reputation meter (review, item 9)
	var delta := game.town.record_visit(g.idx, g.mood.satisfaction(),
		g.mood.satisfaction_terms(g._meal_tray.quality() if g._meal_tray else -1.0))
	var talk := game.town.gossip_line(g.idx, delta, Town.praise_about(g.liked_meal, g.hint_tag) if delta > 0.0 else "")
	if was_sore and not g.info.sore:
		talk = "%s has forgiven you." % g.info.name
	elif game.town.is_regular(g.idx) and not was_regular:
		talk = "%s is now a regular!" % g.info.name
		game.audio.burst(g.position + Vector3(0, 1.5, 0), "stars")
	var news := game.town.record_disgust(g.idx, g.mood.disgust_level())
	if news != "":
		talk = news
	if talk != "":
		game.hud.day_ui.say(talk)
	game.day._critic_leaves(g, false)
	game.audio.popup("+$%d" % (bill + tip), g.position + Vector3(0, 1.9, 0), Color(Build.TRIM))
	Fx.coin(game, g.position + Vector3(0, 1.5, 0))
	if g.mood.satisfaction() > 0.5:
		g._heart_time = 2.5
