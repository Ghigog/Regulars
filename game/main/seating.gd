class_name GameSeating
extends RefCounted
## Guests: parties spawned and their orders planned, the board read, the queue, seating,
## what they notice around them, floor dirt each frame and the gross sources.

const SEAT_THOUGHT_CHANCE := 0.5   # how often a Fast or Comfortable seat prompts a thought

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- guests

## The biggest group that comes: the most seats on any one table, up to Town.MAX_PARTY.
## A group the room can never seat turns away at the door.
func max_party() -> int:
	var most := 0
	for t: Dictionary in game.tables.list:
		most = maxi(most, int(t.seats))
	return mini(most, Town.MAX_PARTY)


## A lone guest: a group of one.
func spawn_guest(idx: int) -> Guest:
	return spawn_group([idx])[0]


## Guests who arrive together, queue together and share a table with nobody else.
func spawn_group(ids: Array, as_critic := false) -> Array[Guest]:
	var party: Array[Guest] = []
	for idx: int in ids:
		var g := Guest.new()
		game.add_child(g)
		g.setup(game, idx, game.spawn_cell())
		# Up the street past the end of the line, so newcomers walk towards the door
		# like everyone else; friends come in single file, not stacked on one spot.
		var back := minf(Grid.center(game.spawn_cell()).z, queue_spot(game.queue.size()).z) - 1.5
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
	var no_table := not TableJoins.fits_ever(party.size(), game.tables.list)   # before the menu is read
	var too_long := not no_table and not as_critic and not _joins_line(party)
	var plan := {"walk": true} if no_table or too_long else _plan_orders(party)
	for g in party:
		g.no_table = no_table
		g.line_too_long = too_long
	if plan.walk:   # nobody has a main: they read the menu at the door and walk on
		for k in party.size():
			var g := party[k]
			game.queue.erase(g)
			g.state = "browse"
			g.timer = Guest.BROWSE_TIME
			g.hold = 0.4 * k
			g.walk_to(outer_lane(Grid.to_cell(queue_spot(0)).y + k), queue_spot(0) + Vector3(1.0, 0, k * 0.9))
	_reflow_queue()
	return party


## Whether the party joins the line: one roll per party, from the groups already waiting and how
## much the party likes the place. Their own earlier opinion is never touched by turning away.
func _joins_line(party: Array[Guest]) -> bool:
	var ahead := {}
	for g: Guest in game.queue:
		if not party.has(g):
			ahead[g.party] = true
	if ahead.is_empty():
		return true   # an empty line: everyone joins, no roll
	var like := game.critic.visit_boost(game.ledger.day)
	for g in party:
		like += float(game.town.people[g.idx].affinity) / party.size()
	return game.order_rng.randf() < QueueChoice.join_chance(ahead.size(), like)


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
		if plan.get("went_along", []).has(k):
			g.mood.think(Menu.GO_ALONG_THOUGHT)
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


const _COUNT_WORDS := ["", "one", "two", "three", "four"]


## A guest who found no main stops at the menu, says so and walks on. Not a walkout
## and not a strike, but they think a little less of the place, friends hear it, and
## the receipt counts them.
func read_board(g: Guest) -> void:
	if g.line_too_long:   # nobody served them badly: no opinion, no record, just a note
		game.audio.popup("Line's too long", g.position + Vector3(0, 2.3, 0), Color(Build.CABINET))
		return
	if g.no_table:   # no walkout, no grudge, no opinion: the room just has nothing for them
		var line := "No table for the %s of us" % _COUNT_WORDS[mini(g.party.size(), _COUNT_WORDS.size() - 1)] if g.party.size() > 1 \
			else "No table for me"
		g.mood.think(line)
		game.audio.popup(line, g.position + Vector3(0, 2.3, 0), Color(Build.CABINET))
		if g == g.party[0]:
			game.ledger.record_no_table()
		return
	g.mood.think(Menu.NOTHING_THOUGHT)
	game.audio.popup("Nothing I liked", g.position + Vector3(0, 2.3, 0), Color(Build.CABINET))
	game.ledger.record_found_nothing()
	game.town.record_found_nothing(g.idx)


## Where the guest `i`th in line stands: a single file up the pavement along the
## wall, one QUEUE_GAP apart, starting a step up from the doorway so guests on
## their way out pass the head of the line. A long line runs on up the street,
## past the edge of the lot.
func queue_spot(i: int) -> Vector3:
	return Grid.center(Game.DOOR) - Vector3(0, 0, Game.QUEUE_GAP * (i + 1))


## The outer lane's cell at `row`, or the nearest open cell of the open pavement rows when a
## table or decor piece stands there.
func outer_lane(row: int) -> Vector2i:
	var best := Vector2i(Game.W + 1, row)
	var best_d := 1 << 30
	var pave := game.pavement()
	for c in pave.size.x * pave.size.y:
		var cell := pave.position + Vector2i(c % pave.size.x, c / pave.size.x)
		if game.grid.is_blocked(cell):
			continue
		var d := absi(cell.y - row) * 2 + (0 if cell.x == Game.W + 1 else 1)
		if d < best_d:
			best_d = d
			best = cell
	return best


## Everyone in line steps up to their own place. Newcomers walk down the outer
## half of the pavement and step in beside their place, so they never walk
## through the people already waiting.
func _reflow_queue() -> void:
	for i in game.queue.size():
		var g := game.queue[i]
		var at := queue_spot(i)
		var row := clampi(Grid.to_cell(at).y, game.pavement().position.y, game.pavement().end.y - 1)
		g.walk_to(Vector2i(Game.W, row) if g.cell.x == Game.W else outer_lane(row), at)
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


## The lead of a table nobody is sitting at with room for `count`: the smallest that
## fits, a joined pair only when no single piece will do. The whole table is theirs.
func _free_table_for(count: int) -> Station:
	var taken: Array = []
	for st: Station in game.paying.dining_tables():
		if st.seats.any(func(s: Vector2i) -> bool: return game.seat_taken.has(s)):
			taken.append(game.paying.table_number(st))
	var i := TableJoins.pick(count, game.tables.list, taken)
	return null if i < 0 else game.paying.table_by_number(int(game.tables.list[i].pieces.min()))


## Seats the group at the head of the queue once a whole table is free for them.
## Groups never share a table, and nobody jumps the queue.
func _seat_waiting_guests() -> void:
	while not game.queue.is_empty():
		var party: Array[Guest] = []
		for m: Guest in game.queue[0].party:
			if game.queue.has(m):
				party.append(m)
		if not TableJoins.fits_ever(party.size(), game.tables.list):
			if party.any(func(m: Guest) -> bool: return not m.path.is_empty()):
				return   # still walking up to the line: they turn away once they are at the door
			for k in party.size():   # no table could ever seat them: they turn away at the door
				party[k].hold = 0.5 * k   # one after another, as in a walkout
				game.paying.leave_with_friends(party[k])
			continue
		var table := _free_table_for(party.size())
		if table == null:
			return
		var chairs := game.tables.seats_of(table)
		for i in party.size():
			var g := party[i]
			game.queue.erase(g)
			g.line_place = -1
			g.table = table
			g.seat = chairs[i]
			game.seat_taken[g.seat] = g
			g.state = "to_seat"
			g.walk_to(g.seat)
		_reflow_queue()


func on_seated(g: Guest) -> void:
	_apply_seat_effects(g)
	for other in game.tables.seats_of(g.table):
		if other != g.seat and game.seat_taken.has(other):
			var mate: Guest = game.seat_taken[other]
			if game.town.are_friends(g.idx, mate.idx):
				g.mood.delight(0.15, "Oh good, %s is here!" % mate.info.name)
				mate.mood.delight(0.15, "Oh good, %s is here!" % g.info.name)
	game.decor.cheer_with_decor(g)


## A guest has put the menu down and the notepad is up: the table knocks, once per calling table.
func on_decided(g: Guest) -> void:
	if g.orders_nothing:
		return
	for o in game.paying.party_at(g.table):
		if o != g and o.state == "ordering" and not o.orders_nothing:
			return
	game.audio.sfx("order_ready", 0.04)


## The chair's and its table's effects on this guest (Seating), kept on the guest and the mood.
## Comfortable joy is the chair's own, so a booth is cosy through it and nothing is doubled.
func _apply_seat_effects(g: Guest) -> void:
	var chair: Station = game.stations.get(g.seat)
	var half := game.tables.half_of_seat(g.table, g.seat)
	g.seat_fx = Seating.combine(_piece_effect(chair), _piece_effect(half))
	g.mood.seat_tolerance = g.seat_fx.tolerance
	g.mood.seat_tip = g.seat_fx.tip
	if g.seat_fx.joy > 0.0:
		g.mood.delight(g.seat_fx.joy, "A booth! How cosy" if chair.type == "booth_seat" else "What a lovely table")
	if randf() < SEAT_THOUGHT_CHANCE:
		if g.seat_fx.eat < 1.0:
			g.mood.think("Grab and go")
		elif g.seat_fx.eat > 1.0:
			g.mood.think("Nice to sit a while")


func _piece_effect(st: Station) -> Dictionary:
	if st == null:
		return Seating.neutral()
	var key := "%s%s%d" % [st.type, Upgrades.TIER_SEP, st.tier]
	return Seating.piece_effect(Upgrades.seat_path(key), Upgrades.seat_steps(key))


## Everything a seated guest can see changes how they feel.
func apply_surroundings(g: Guest, delta: float) -> void:
	var saw_gross := false
	var in_view := {}
	for s in game._gross:
		var c: Vector2i = s.cell
		if GameDecor._near(g.cell, c, int(s.get("range", Game.SIGHT_RANGE))) and game.grid.has_los(g.cell, c):
			if s.has("key"):
				in_view[s.key] = true
			var age: float = s.get("age", -1.0)
			if age < 0.0:   # no age of its own: count how long this guest has looked at it
				age = g.seen.get(s.key, 0.0)
				g.seen[s.key] = age + delta
			var curve: Array = Game.GROSS[s.kind]
			var rate := GuestMood.gross_rate(curve[0], age, curve[1], curve[2])
			g.mood.see_gross(rate, delta, s.thought)
			if rate >= GuestMood.NOTICE:
				g.note_disgust(c, s.kind)
			if g == game.critic_guest and rate >= GuestMood.NOTICE:
				g.mood.think(Critic.thought("gross"))
			saw_gross = saw_gross or rate >= GuestMood.NOTICE
	for k in g.seen.keys():   # out of view: starts again from the base rate next time
		if not in_view.has(k):
			g.seen.erase(k)
	saw_gross = game.floor_dirt.disgust(g, delta, Game.SIGHT_RANGE) or saw_gross
	if not saw_gross:
		g.mood.fade(delta)   # before the stove show below, which also sets saw_gross
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
		if ch.carrying_dirty_dishes():
			game._gross.append({"cell": ch.cell(), "kind": "plate", "key": "carried_plate", "thought": "Somebody is clearing up"})
		elif ch.carrying_something_gross():
			game._gross.append({"cell": ch.cell(), "kind": "rubbish", "key": "rubbish", "thought": "I just watched the chef carry rubbish past me"})


## The most impatient guest sat at this table, waiting to order or for food.
func _waiting_guest_at(table: Station) -> Guest:
	var best: Guest = null
	for s in game.tables.seats_of(table):
		if game.seat_taken.has(s):
			var g: Guest = game.seat_taken[s]
			if g.seated_waiting() and (best == null or g.mood.patience < best.mood.patience):
				best = g
	return best


## Everyone at this table who is sat down and has not ordered yet.
func _guests_to_order(table: Station) -> Array[Guest]:
	var out: Array[Guest] = []
	for s in game.tables.seats_of(table):
		if game.seat_taken.has(s) and game.seat_taken[s].state == "ordering":
			out.append(game.seat_taken[s])
	return out
