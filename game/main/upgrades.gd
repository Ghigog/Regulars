class_name GameUpgrades
extends RefCounted
## Upgrades (PRD 8.3): choosing a node on the tree, buying it and remaking the piece where it
## stands; the lifted piece's strip of choices.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- tree nodes in the shop

## Picks a tree node the shop sells outright, already upgraded (review, item 4). Nothing
## is paid until it is placed; the price is the whole way there.
func pick_tree(bp: Dictionary, ch: Player = null) -> bool:
	ch = game._me(ch)
	if game.ledger.money < Catalog.bp_price(bp) or Catalog.bp_level(bp) > game.ledger.level() \
			or not game.placing.pick_catalog(bp.id, int(bp.tier), ch, bp.get("base", "")):
		return false
	ch.hand.price = Catalog.bp_price(bp)
	if bp.get("up", "") != "":
		ch.hand.up = bp.up
		if bp.get("counter", false):
			ch.hand.counter = true
	return true


## The upgrade-tree key of the piece a chef has picked up: its kitchen node, its tier
## in a tiered piece's short tree, or "" (nothing picked up, or a piece with no tree).
func hand_key(ch: Player = null) -> String:
	ch = game._me(ch)
	if ch.hand.get("moving", false) and Treatments.is_box(ch.hand.get("id", "")):
		return ch.hand.id   # a treatment's box, picked up from storage (PRD 9.5)
	if not ch.hand.get("moving", false) or not (ch.hand.get("node") is Station):
		return ""
	var st: Station = ch.hand.node
	if st.type == "hook" and Kitchen.has_node(st.kit_tool):
		return st.kit_tool   # a hook's tree is its tool's: sponge, scourer and on (PRD 9.5)
	return Upgrades.key_of(st.type, st.tier, st.base if st.type == "counter" else st.node)


## Buys a node of the tree for the piece in the shopper's hand: only a child of what it
## is now, paid for at once (the step's price). The piece turns into it, still in hand.
func buy_upgrade(to: String, ch: Player = null) -> bool:
	ch = game.shopper if ch == null and game.shopper != null else game._me(ch)
	var from := hand_key(ch)
	var link := Upgrades.is_link(to)   # a stove grown on a counter
	if link and not (ch.hand.node is Station and (ch.hand.node as Station).item == ""):
		game.audio.sfx("fail")
		game.hud.say("Clear the counter first, then grow it into a %s." % Upgrades.name_of(to).to_lower())
		return false
	if game.phase != Game.Phase.BUILD or from == "" or not Upgrades.can_buy(from, to, game.ledger.money, game.ledger.level()) \
			or not game.ledger.spend(Upgrades.step_price(to)):
		game.audio.sfx("fail")
		return false
	if link and not ch.hand.get("in_place", false):   # a lifted counter grows in hand
		var was: Station = ch.hand.node
		var grown := Station.new()
		game.add_child(grown)
		grown.setup(to, was.cell, 1, was.facing, was.base, was.pass_look)
		grown.visible = false
		game.placing._bought_tonight(grown, game.placing.spent_tonight(was) + Upgrades.step_price(to))
		was.queue_free()
		ch.hand.node = grown
		ch.hand.id = grown.type
		ch.hand.tier = 1
		game.menu_stock.menu_changed()
		game.audio.sfx("coin")
		game.hud.show_build()
		return true
	if link:
		var under: Station = ch.hand.node
		var cell := under.cell
		var facing := under.facing
		game.session.close_shop()   # the counter settles; the card and its tree shut
		var top := game.world.add_station(to, cell, 1, facing)
		game.placing._bought_tonight(top, Upgrades.step_price(to))
		game.audio.burst(Grid.center(cell) + Vector3(0, 1.0, 0), "stars", 0.4)
		game.hud.say("The counter is a %s now. Open it with E to upgrade it further." % Upgrades.name_of(to).to_lower())
		game.menu_stock.menu_changed()
		game.audio.sfx("coin")
		return true
	if Upgrades.is_treatment(to):   # a box: it is the new treatment's now (PRD 9.5)
		if ch.hand.get("in_place", false):   # still in its slot, upgraded from the card
			var cell := Vector2i(ch.hand.from.x, ch.hand.from.y)
			game.kitchen.unstore(cell, from)
			game.kitchen.store(cell, to)
			game.world._show_boxes(cell)
		ch.hand.id = to
		_swap_treatment(Treatments.key_of(from), Treatments.key_of(to))
		game.audio.sfx("coin")
		game.hud.show_build()
		return true
	var st: Station = ch.hand.node
	if st.type == "hook" and Kitchen.fit_of(to) == "floor":   # the sponge grows into a mop bucket
		if ch.hand.get("in_place", false):
			game.ledger.refund(Upgrades.step_price(to))
			game.audio.sfx("fail")
			game.hud.say("Lift the hook first: the bucket stands on the floor.")
			return false
		var bucket := Station.new()
		game.add_child(bucket)
		bucket.setup(to, st.cell, 1, 0)
		bucket.visible = false
		game.placing._bought_tonight(bucket, game.placing.spent_tonight(st) + Upgrades.step_price(to))
		game.clean_kit.upgrade_home(st, bucket, Kitchen.tool_of(to))
		st.queue_free()
		ch.hand.node = bucket
		ch.hand.id = bucket.type
		ch.hand.tier = 1
		ch.hand.layer = ""
		ch.hand.facing = 0
		game.audio.sfx("coin")
		game.hud.say("The sponge is a mop bucket now: put it down on the floor.")
		game.hud.show_build()
		return true
	game.placing._bought_tonight(st, Upgrades.step_price(to))   # an upgrade bought tonight comes back whole too
	if ch.hand.get("in_place", false):   # the storage card: upgraded where it stands
		if Kitchen.is_tall(to) and game.kitchen.get_piece(st.cell, "high") != "":
			game.ledger.refund(Upgrades.step_price(to))
			st.set_meta("fresh", game.placing.spent_tonight(st) - Upgrades.step_price(to))
			game.audio.sfx("fail")
			game.hud.say("A tall fridge needs the wall above clear. Take down what hangs there first.")
			return false
		if Upgrades.is_tiered(to):   # a table or fern a tier up where it stands
			st.tier = Upgrades.tier_of(to)
			st.set_base(st.base)
		elif st.type == "hook" and Kitchen.tool_of(to) != "":   # the hook's tool is swapped
			game.clean_kit.upgrade_tool(st, Kitchen.tool_of(to))
		elif st.high:   # what hangs on the wall a step up: made anew and hung back
			var up := Station.new()
			game.add_child(up)
			up.setup(to, st.cell, st.tier, st.facing, st.base, st.pass_look)
			game.highs.erase(st.cell)
			game.kitchen.cells[st.cell].high = ""
			game.world._hang(up, st.cell)
			game.placing._bought_tonight(up, game.placing.spent_tonight(st))
			st.queue_free()
			ch.hand.node = up
			ch.hand.id = up.type
		elif st.type == "counter" or (Kitchen.slots_of(to) > 0 and not Kitchen.is_top(st.type)):
			st.set_base(to)   # a counter or fridge a step up: the same piece, redrawn
			game.kitchen.set_cell(st.cell, to)
		else:   # a stove or any other tool up its tree where it stands: made anew in place
			_remake_in_place(st, to, ch)
		game.world._show_boxes(st.cell)
		game.menu_stock.menu_changed()
		game.audio.sfx("coin")
		return true
	if st.type == "hook" and Kitchen.tool_of(to) != "":   # the hook's tool is swapped
		game.clean_kit.upgrade_tool(st, Kitchen.tool_of(to))
		game.audio.sfx("coin")
		game.hud.show_build()
		return true
	if Upgrades.is_tiered(to):
		st.tier = Upgrades.tier_of(to)
		st.set_base(st.base)   # redraws it at the new tier
		ch.hand.tier = st.tier
	elif st.type == "counter":
		st.set_base(to)
	else:   # a tool: it may now work as another (a stove into a fryer), so it is made anew
		var up := Station.new()
		game.add_child(up)
		up.setup(to, st.cell, st.tier, st.facing, st.base, st.pass_look)
		up.stacked = st.stacked
		up.visible = false
		game.placing._bought_tonight(up, game.placing.spent_tonight(st))   # what was paid tonight goes with it
		game.clean_kit.upgrade_home(st, up, Kitchen.tool_of(to))   # a bucket's mop goes with it (PRD 9.5)
		st.queue_free()
		ch.hand.node = up
		ch.hand.id = up.type
	game.audio.sfx("coin")
	game.hud.show_build()
	return true


## A stove (its counter upgraded) bought up its tree where it stands, its card open: it
## may now work as another piece (a fryer), so a new one takes its place, its counter's
## boxes, the till and what was paid tonight with it, and the hand holds the new one.
func _remake_in_place(st: Station, to: String, ch: Player) -> void:
	var held := game.kitchen.take_stock(st.cell)
	game.world._unregister(st)
	var up := Station.new()
	game.add_child(up)
	up.setup(to, st.cell, st.tier, st.facing, st.base, st.pass_look)
	up.stacked = st.stacked
	var till := st.get_node_or_null("till")
	if till:
		till.reparent(up, false)
	game.world._register(up)
	game.kitchen.give_stock(up.cell, held)
	game.placing._bought_tonight(up, game.placing.spent_tonight(st))
	game.clean_kit.upgrade_home(st, up, Kitchen.tool_of(to))   # a bucket's mop goes with it (PRD 9.5)
	st.queue_free()
	ch.hand.node = up
	ch.hand.id = up.type


## A treatment's box upgraded: the cells laid with the old one are the new one's now.
func _swap_treatment(was: String, now: String) -> void:
	for c: Vector2i in game.treat_laid:
		if game.treat_laid[c] == was:
			game.treat_laid[c] = now
	if game.treat_off.has(was):
		game.treat_off.erase(was)
		game.treat_off[now] = true


# ---------------------------------------------------------------- the lifted piece's strip

## A lifted piece's strip along the bottom (owner's review of night zero): the upgrades it
## can take at this level, then the boxes it carries. Z and X (LB and RB) choose, Space
## (Y) buys the upgrade or takes the box out, which stops its nightly fee. Each is
## {"kind": "up", "key": tree key} or {"kind": "box", "id": box id}.
func strip_choices(ch: Player = null) -> Array[Dictionary]:
	ch = game._me(ch)
	var out: Array[Dictionary] = []
	if game.phase != Game.Phase.BUILD or not ch.hand.get("moving", false) or game.shopper == ch:
		return out
	var key := hand_key(ch)
	if key != "" and Upgrades.has_tree(key):
		for to: String in Upgrades.children(key):
			if Upgrades.level(to) <= game.ledger.level():
				out.append({"kind": "up", "key": to})
	for box: String in ch.hand.get("stock", []):
		out.append({"kind": "box", "id": box})
	return out


## Whether player p's chef has a strip to choose on.
func strip_open(p: int) -> bool:
	return game.phase == Game.Phase.BUILD and p >= 0 and p < game.chefs.size() and not strip_choices(game.chefs[p]).is_empty()


## The choice the strip is on, or {} when there is none.
func strip_chosen(ch: Player = null) -> Dictionary:
	ch = game._me(ch)
	var list := strip_choices(ch)
	if list.is_empty():
		return {}
	ch.strip_pick = clampi(ch.strip_pick, 0, list.size() - 1)
	return list[ch.strip_pick]


func strip_move(d: int, ch: Player = null) -> bool:
	ch = game._me(ch)
	var n := strip_choices(ch).size()
	if n == 0:
		return false
	ch.strip_pick = posmod(ch.strip_pick + d, n)
	game.audio.sfx("tab", 0.08)
	game.hud.show_build()
	return true


## Buys the chosen upgrade for the piece in hand, or takes the chosen box out of it.
func strip_buy(ch: Player = null) -> bool:
	ch = game._me(ch)
	var c := strip_chosen(ch)
	if c.is_empty():
		game.audio.sfx("fail")
		return false
	if c.kind == "box":
		(ch.hand.stock as Array).erase(c.id)
		game.menu_stock.menu_changed()
		game.audio.sfx("putdown")
		game.hud.say("%s taken out: it is not stocked any more." % Catalog.label({"id": c.id, "tier": 1}))
		game.hud.show_build()
		return true
	var price := Upgrades.step_price(c.key)
	if game.ledger.money < price:
		game.audio.sfx("fail")
		game.hud.say("The %s costs $%d." % [Upgrades.name_of(c.key).to_lower(), price])
		return false
	if not buy_upgrade(c.key, ch):
		return false
	ch.strip_pick = 0
	game.hud.show_build()
	return true
