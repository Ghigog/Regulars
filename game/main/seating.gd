class_name GameSeating
extends RefCounted
## Guests: parties spawned and their orders planned, the board read, the queue, seating,
## what they notice around them, floor dirt each frame and the gross sources.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- guests

## The most guests one table can seat, which is also the biggest group that comes.
func max_party() -> int:
	var most := 1
	for st: Station in game.stations.values():
		most = maxi(most, st.seats.size())
	return most


## A lone guest: a group of one.
func spawn_guest(idx: int) -> Guest:
	return spawn_group([idx])[0]


## Guests who arrive together, queue together and share a table with nobody else.
func spawn_group(ids: Array, as_critic := false) -> Array[Guest]:
	var party: Array[Guest] = []
	for idx: int in ids:
		var g := Guest.new()
		game.add_child(g)
		g.setup(game, idx, Game.SPAWN)
		# Up the street past the end of the line, so newcomers walk towards the door
		# like everyone else; friends come in single file, not stacked on one spot.
		var back := minf(Grid.center(Game.SPAWN).z, queue_spot(game.queue.size()).z) - 1.5
		for o: Guest in game.guests:
			if o.position.x > Game.W and o.state != "leaving":   # out on the pavement, coming in
				back = minf(back, o.position.z - Game.QUEUE_GAP)
		g.position.z = back
		g.party = party
		party.append(g)
		game.guests.append(g)
		game.queue.append(g)
	if as_critic:
		game.critic_guest = party[0]
	var plan := _plan_orders(party)
	if plan.walk:   # nobody has a main: they read the menu at the door and walk on
		for k in party.size():
			var g := party[k]
			game.queue.erase(g)
			g.state = "browse"
			g.timer = Guest.BROWSE_TIME
			g.hold = 0.4 * k
			g.walk_to(Vector2i(Game.W + 1, Grid.to_cell(queue_spot(0)).y + k), queue_spot(0) + Vector3(1.0, 0, k * 0.9))
	_reflow_queue()
	return party


## The group reads the menu at the door and each decides what they will order.
## Returns the group's plan (see Menu.group_order).
func _plan_orders(party: Array[Guest]) -> Dictionary:
	var tastes := []
	for g in party:
		tastes.append(game.town.tastes_of(g.idx))
	var available := game.menu_stock.tonight_menu()
	var plan := Menu.group_order(available, tastes, game.order_rng)
	if party.size() == 1 and party[0] == game.critic_guest:   # never turned away by the menu
		plan = {"walk": false, "found_nothing": [],
			"orders": [Critic.order(available, tastes[0].likes, tastes[0].dislikes, game.order_rng)]}
		party[0].mood.think(Critic.thought("menu"))
	for k in party.size():
		var g := party[k]
		g.planned = plan.orders[k]
		if plan.walk:
			continue   # they think it at the board (read_board)
		if plan.found_nothing.has(k):   # stays with the group, with a drink or nothing
			g.orders_nothing = Menu.COURSES.all(func(c: String) -> bool: return (g.planned.get(c, {}) as Dictionary).is_empty())
			g.mood.think(Menu.NOTHING_THOUGHT)
			game.town.record_found_nothing(g.idx)
			game.ledger.record_found_nothing()
		else:
			g.mood.read_prices(Menu.dear_count(g.planned))   # Dear for their means costs happiness
			g.hint_tag = Menu.tag_hint(available, g.info.liked_tags)
			if g.hint_tag != "":
				g.mood.think(Menu.hint_thought(g.hint_tag))
	return plan


## A guest who found no main stops at the menu, says so and walks on. Not a walkout
## and not a strike, but they think a little less of the place, friends hear it, and
## the receipt counts them.
func read_board(g: Guest) -> void:
	g.mood.think(Menu.NOTHING_THOUGHT)
	game.audio.popup("Nothing I liked", g.position + Vector3(0, 2.3, 0), Color(Build.CABINET))
	game.ledger.record_found_nothing()
	var talk := game.town.gossip_line(g.idx, game.town.record_found_nothing(g.idx), "there was nothing on the menu for them")
	if g == g.party[0] and talk != "":
		game.hud.day_ui.say(talk)


## Where the guest `i`th in line stands: a single file up the pavement along the
## wall, one QUEUE_GAP apart, starting a step up from the doorway so guests on
## their way out pass the head of the line. A long line runs on up the street,
## past the edge of the lot.
func queue_spot(i: int) -> Vector3:
	return Grid.center(Game.DOOR) - Vector3(0, 0, Game.QUEUE_GAP * (i + 1))


## Everyone in line steps up to their own place. Newcomers walk down the outer
## half of the pavement and step in beside their place, so they never walk
## through the people already waiting.
func _reflow_queue() -> void:
	for i in game.queue.size():
		var g := game.queue[i]
		var at := queue_spot(i)
		var row := clampi(Grid.to_cell(at).y, Game.LOT.position.y, Game.LOT.end.y - 1)
		g.walk_to(Vector2i(Game.W if g.cell.x == Game.W else Game.W + 1, row), at)
		g.line_place = i


## The nearest other guest standing close, straight ahead of `g` going `dir`.
func guest_in_way(g: Guest, dir: Vector3) -> Guest:
	var best: Guest = null
	var near := Guest.PERSONAL
	for o: Guest in game.guests:
		if o == g:
			continue
		var d := o.position - g.position
		d.y = 0.0
		var dist := d.length()
		if dist < near and dist > 0.001 and d.dot(dir) > dist * 0.5:
			best = o
			near = dist
	return best


## A table nobody is sitting at with room for `count`; the smallest that fits.
func _free_table_for(count: int) -> Station:
	var best: Station = null
	for st: Station in game.stations.values():
		if st.seats.size() < count or (best != null and st.seats.size() >= best.seats.size()):
			continue
		var empty := true
		for s in st.seats:
			empty = empty and not game.seat_taken.has(s)
		if empty:
			best = st
	return best


## Seats the group at the head of the queue once a whole table is free for them.
## Groups never share a table, and nobody jumps the queue.
func _seat_waiting_guests() -> void:
	while not game.queue.is_empty():
		var party: Array[Guest] = []
		for m: Guest in game.queue[0].party:
			if game.queue.has(m):
				party.append(m)
		var table := _free_table_for(party.size())
		if table == null:
			return
		for i in party.size():
			var g := party[i]
			game.queue.erase(g)
			g.line_place = -1
			g.table = table
			g.seat = table.seats[i]
			game.seat_taken[g.seat] = g
			g.state = "to_seat"
			g.walk_to(g.seat)
		_reflow_queue()


func on_seated(g: Guest) -> void:
	if g.table.tier > 1:
		g.mood.delight(0.05 * (g.table.tier - 1), "What a lovely table")
	if g.table.type == "booth":
		g.mood.delight(Game.BOOTH_DELIGHT, "A booth! How cosy")
	for other in g.table.seats:
		if other != g.seat and game.seat_taken.has(other):
			var mate: Guest = game.seat_taken[other]
			if game.town.are_friends(g.idx, mate.idx):
				g.mood.delight(0.15, "Oh good, %s is here!" % mate.info.name)
				mate.mood.delight(0.15, "Oh good, %s is here!" % g.info.name)
	game.decor.cheer_with_decor(g)
	if game.paying.party_at(g.table).all(func(o: Guest) -> bool: return o.state != "to_seat"):
		# The whole party is down: a knock on the table, they are ready to order.
		game.get_tree().create_timer(0.6).timeout.connect(game.audio.sfx.bind("order_ready", 0.04))


## Everything a seated guest can see changes how they feel.
func apply_surroundings(g: Guest, delta: float) -> void:
	var saw_gross := false
	for s in game._gross:
		var c: Vector2i = s.cell
		if GameDecor._near(g.cell, c, int(s.get("range", Game.SIGHT_RANGE))) and game.grid.has_los(g.cell, c):
			var age: float = s.get("age", -1.0)
			if age < 0.0:   # no age of its own: count how long this guest has looked at it
				age = g.seen.get(s.key, 0.0)
				g.seen[s.key] = age + delta
			var curve: Array = Game.GROSS[s.kind]
			var rate := GuestMood.gross_rate(curve[0], age, curve[1], curve[2])
			g.mood.see_gross(rate, delta, s.thought)
			if g == game.critic_guest and rate >= GuestMood.NOTICE:
				g.mood.think(Critic.thought("gross"))
			saw_gross = saw_gross or rate >= GuestMood.NOTICE
	saw_gross = game.floor_dirt.disgust(g, delta, Game.SIGHT_RANGE) or saw_gross
	for st: Station in game.stations.values():
		if st.type == "stove" and not saw_gross and st.is_cooking() \
				and GameDecor._near(g.cell, st.cell, Game.SIGHT_RANGE) and game.grid.has_los(g.cell, st.cell):
			# An open kitchen is a show, as long as nothing nasty is in view.
			g.mood.delight(0.01 * delta, "I can watch the chef at work")
			saw_gross = true   # one stove's worth of show, however many are on


## Dirt on the floor follows the room, moves with everyone's feet and is drawn (PRD 9).
func _tick_floor(delta: float) -> void:
	game.floor_dirt.sync_room()
	var walkers := []
	for ch in game.serving.hands():   # chefs and helpers
		walkers.append([ch, ch.cell()])
	for g in game.guests:
		walkers.append([g, Grid.to_cell(g.position)])
	game.floor_dirt.step_feet(walkers, game.phase == Game.Phase.SERVICE)   # slips only while open (9.3)
	game.floor_dirt.tick_slips(delta)
	game.clean_kit.tick(delta)   # mop waits, the robot sweepers (PRD 9.4)
	game.floor_dirt.redraw()


## How fast anyone moves standing at `p`: slowed by the floor dirt under them.
func floor_speed(p: Vector3) -> float:
	return game.floor_dirt.speed_at(p) if game.floor_dirt != null else 1.0


func _collect_gross() -> void:
	game._gross.clear()
	for st: Station in game.stations.values():
		if Station.is_table(st.type) and st.dirty > 0:
			game._gross.append({"cell": st.cell, "kind": "plate", "age": st.dirty_age, "thought": "Nobody has cleared that table"})
		elif st.type == "bin" and st.overflowing():
			game._gross.append({"cell": st.cell, "kind": "overflow", "age": st.dirty_age, "thought": "The bin is overflowing"})
		elif st.type == "bin":
			game._gross.append({"cell": st.cell, "kind": "bin", "key": "bin:%s" % st.cell, "range": Game.BIN_RANGE, "thought": "I can see the bin from my seat"})
		elif st.type == "sink" and st.messy():
			game._gross.append({"cell": st.cell, "kind": "sink", "age": st.dirty_age, "thought": "Look at that washing-up"})
		elif (st.type == "stove" or st.type == "fryer") and st.item.begins_with("burnt:"):
			game._gross.append({"cell": st.cell, "kind": "burning", "age": st.cook - Station.BURN_TIME, "thought": "Something is burning in there"})
	for ch in game.serving.hands():
		if ch.carrying_something_gross():
			game._gross.append({"cell": ch.cell(), "kind": "rubbish", "key": "rubbish", "thought": "I just watched the chef carry rubbish past me"})


## The most impatient guest sat at this table, waiting to order or for food.
func _waiting_guest_at(table: Station) -> Guest:
	var best: Guest = null
	for s in table.seats:
		if game.seat_taken.has(s):
			var g: Guest = game.seat_taken[s]
			if g.seated_waiting() and (best == null or g.mood.patience < best.mood.patience):
				best = g
	return best


## Everyone at this table who is sat down and has not ordered yet.
func _guests_to_order(table: Station) -> Array[Guest]:
	var out: Array[Guest] = []
	for s in table.seats:
		if game.seat_taken.has(s) and game.seat_taken[s].state == "ordering":
			out.append(game.seat_taken[s])
	return out
