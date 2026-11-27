class_name GameCooking
extends RefCounted
## Cooking and carrying: what E does at a station (use_station), boxes and surfaces,
## cups and plates in hand, washing, clearing, the press tools.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- cooking & carrying

## What using this station would do right now, e.g. "Cook". Empty when nothing.
func prompt_for(st: Station, ch: Player = null) -> String:
	ch = game._me(ch)
	var s := game.prep_games.prep_of(game.chefs.find(ch))
	if not s.is_empty():
		return {"chop": "Chop on the notch", "slice": "Slice %d times" % Prep.SLICE_COUNT,
			"pour": "Let go to stop", "grate": "Hold to grate, keep it green",
			"saw": "Press at the end", "juice": "Let go on the green",
			"blend": "Pulse %d times, don't spill" % Prep.BLEND_PULSES, "steam": "Lift the lid on the green"}.get(s.tool, "")
	if _wash_hold.has(ch) and _wash_hold[ch].st == st:
		return "Washing %d%%" % clampi(int(float(_wash_hold[ch].t) / WASH_HOLD * 100.0), 0, 100)
	return use_station(st, true, ch)


## Which tool's way of working a station is used as right now (PRD 8.3): a heat tool
## works as the tool of what is cooking on it, or of the raw thing in hand when it can
## cook that at all (a stove that fries works as a fryer). Others as themselves.
func _use_as(st: Station, held_ing: Dictionary) -> String:
	if Station.is_table(st.type):
		return "table"   # a fast or comfortable table is used as a table
	if not st.is_heat_tool():
		return st.type
	if st.heat != "":
		return st.mode()
	if not held_ing.is_empty() and held_ing.state == "raw" and st.item == "":
		var job := Pantry.tool_of(held_ing.id)
		if Station.HEAT_MODE.has(job) and st.q(job) > 0.0:
			return str(Station.HEAT_MODE[job])
	return st.type


## The player uses the station they are facing. Returns the name of the action taken.
## With dry_run, nothing changes and only the name is returned. A refusal (a plate
## that is not finished, food nothing on the menu combines) is returned as its
## reason, and on a real use it is said and nothing changes.
func use_station(st: Station, dry_run := false, ch: Player = null) -> String:
	ch = game._me(ch)
	var kit := game.clean_kit.station_use(st, dry_run, ch)   # cleaning tools first (PRD 9.4)
	if kit != "" or CleanKit.holding(ch):
		return kit   # a tool fills the hands: nothing else is done with it
	if game.phase == Game.Phase.BUILD and _fills_hands(_use_station(st, true, ch)):
		# The night is for building: no plate, cup or food into the hands.
		if not dry_run:
			game.hud.day_ui.say(NIGHT_HANDS + ".")
			game.audio.sfx("fail")
		return NIGHT_HANDS
	return _use_station(st, dry_run, ch)


const NIGHT_HANDS := "Plates and food wait for the morning"
const NIGHT_TAKES := ["Take off the heat", "Take out", "Pick up", "Lift basket", "Plate it", "Pour into cup"]


## Whether an action's name puts a plate, cup, tray or food in the chef's hands.
static func _fills_hands(act: String) -> bool:
	if act in NIGHT_TAKES or act.begins_with("Pour ") or act.begins_with("Swap for "):
		return true
	return act.begins_with("Take ") and not act.begins_with("Take order") and not act.contains(" orders")


func _use_station(st: Station, dry_run := false, ch: Player = null) -> String:
	ch = game._me(ch)
	BuildFood.menu = game.menu.items
	var held := ch.held
	var q := ch.held_quality
	var held_ing := Tray.parse(held)
	var act := ""
	var why := ""
	# Paying (PRD 11): the till writes bills; a slip in hand is handed over with a held E.
	if held == "" and st == game.paying.till_station() and st.item == "" and not game.paying.bill_tables().is_empty():
		if not dry_run:
			game.paying.open_bill(ch)
		return "Write the bill"
	if held == "bill":
		if game.paying.bill_place(st):
			return "Hold to give the bill"
		# A wrong slip is not final: the till writes a new one over it.
		if st == game.paying.till_station() and st.item == "" and not game.paying.bill_tables().is_empty():
			if not dry_run:
				game.paying.open_bill(ch)
			return "Write a new bill"
		if st.type == "bin":
			if not dry_run:
				ch.set_held("")
				st.count += 1
				st.refresh()
			return _finish_use(st, ["Throw away", ""], dry_run, ch)
		if not st.seats.is_empty() or st == game.paying.till_station():
			return _finish_use(st, ["", "Nobody here is waiting to pay"], dry_run, ch)
		return ""
	var ing := Catalog.ingredient_of(st.type)   # a drink dispenser's own drink
	var taps := game.menu_stock.dispenser_drinks(st)
	var drinks_here := ing != "" and not taps.is_empty() and Pantry.is_drink(ing)
	if surface_first(st, held) and not (drinks_here and held in ["", "dishes"] and st.item == ""):
		return _finish_use(st, _use_surface(st, dry_run, ch), dry_run, ch)
	if taps.size() > 1:
		# Two taps (PRD 8.6): pour what the cup and a ticket want, else the tap it is
		# turned to (Turn, or Use with empty hands, turns it).
		ing = game.menu_stock.pour_pick(st, taps, _cup_in_hand(ch, ""))
		if held == "":
			act = "Turn to %s" % Pantry.name_of(taps[(st.tap + 1) % taps.size()]).to_lower()
			if not dry_run:
				game.serving.turn_tap(st)
			return act
	if drinks_here:
		# A drink station fills the cup in hand (PRD: drinks go out in cups).
		var cup := _cup_in_hand(ch, ing)
		if cup != null:
			var pour: bool = Pantry.tool_of(ing) == "pour" and not Catalog.ITEMS.get(st.type, {}).get("ready", false)
			act = ("Pour %s" if pour else "Fill with %s") % Pantry.name_of(ing).to_lower()
			if not dry_run:
				if pour:
					game.prep_games.start_prep(game.chefs.find(ch), st, "pour", ing, "", cup)
					return act
				cup.add(Tray.kind("prep", ing), Prep.PLAIN)
				ch.show_held()
		elif held == "":
			why = "Bring a cup for the %s" % Pantry.name_of(ing).to_lower()
		elif held == "dishes":
			var cups := ch.dishes.filter(func(d: Dish) -> bool: return d.vessel == Dish.CUP)
			why = "Bring a cup" if cups.is_empty() else (cups[0] as Dish).refusal(Tray.kind("prep", ing), game.menu.items)
		return _finish_use(st, [act, why], dry_run, ch)
	if ing != "":
		var ready: bool = Catalog.ITEMS[st.type].get("ready", false) if Catalog.ITEMS.has(st.type) else false
		if held == "" and Pantry.tool_of(ing) == "pour":
			act = "Pour %s" % Pantry.name_of(ing).to_lower()
			if not dry_run:
				game.prep_games.start_prep(game.chefs.find(ch), st, "pour", ing)
				return act
		elif held == "":
			act = "Take %s" % Pantry.name_of(ing).to_lower()
			if not dry_run:
				if ready or not Pantry.needs_prep(ing):
					ch.set_held(Tray.kind("prep", ing), Prep.PLAIN)
				else:
					ch.set_held(Tray.kind("raw", ing))
		elif held == Tray.kind("raw", ing) or (held == Tray.kind("prep", ing) and (ready or not Pantry.needs_prep(ing))):
			act = "Put back"
			if not dry_run:
				ch.set_held("")
	match _use_as(st, held_ing):
		"stove":
			if st.item == "" and not held_ing.is_empty() and held_ing.state == "raw" and Pantry.tool_of(held_ing.id) == "grill":
				act = "Grill"
				if not dry_run:
					st.set_item(held)
					st.set_meta("used_by", game.chefs.find(ch))
					ch.set_held("")
			elif held == "" and st.item != "":
				act = "Take off the heat"
				if not dry_run:
					var p := Tray.parse(st.item)
					var res := Prep.grill(st.cook, st.q("grill"))
					ch.set_held(Tray.kind(res.state, p.id), res.quality)
					st.set_item("")
					game.prep_games._prep_done(game.chefs.find(ch), st, "grill", res.result)
			elif not held_ing.is_empty() and st.item == "":
				why = "%s doesn't go on the grill" % Pantry.name_of(held_ing.id)
			elif not held_ing.is_empty() and game.chefs.size() > 1 and int(st.get_meta("used_by", -1)) not in [-1, game.chefs.find(ch)]:
				why = "Chef %d has it" % (int(st.get_meta("used_by", 0)) + 1)   # co-op: the losing press says who won
		"fryer":
			if st.item == "" and not held_ing.is_empty() and held_ing.state == "raw" and Pantry.tool_of(held_ing.id) == "fry":
				act = "Fry"
				if not dry_run:
					st.set_item(held)
					st.set_meta("used_by", game.chefs.find(ch))
					ch.set_held("")
			elif held == "" and st.on_rack():
				if st.draining():
					why = "Still draining"
				else:
					act = "Pick up"
					if not dry_run:
						ch.set_held(st.item, st.quality)
						st.set_item("")
			elif held == "" and st.item != "":
				act = "Lift basket"
				if not dry_run:
					var p := Tray.parse(st.item)
					var res := Prep.fry(st.cook, st.q("fry"))
					if res.state == "prep":
						st.lift_to_rack(Tray.kind("prep", p.id), res.quality, res.result)
					else:
						ch.set_held(Tray.kind(res.state, p.id), res.quality)
						st.set_item("")
					game.prep_games._prep_done(game.chefs.find(ch), st, "fry", res.result)
			elif not held_ing.is_empty() and st.item == "":
				why = "%s doesn't go in the fryer" % Pantry.name_of(held_ing.id)
		"pot":
			if st.item == "" and not held_ing.is_empty() and held_ing.state == "raw" and Pantry.tool_of(held_ing.id) == "boil":
				act = "Boil"
				if not dry_run:
					st.set_item(held)
					ch.set_held("")
			elif held == "" and st.item.begins_with("raw"):
				why = "Still boiling"
			elif held == "" and st.item != "":
				act = "Take out"
				if not dry_run:
					ch.set_held(st.item, Prep.PLAIN)
					game.floor_dirt.prep_grease("boil", "plain", ch.cell(), st)
					st.set_item("")
			elif not held_ing.is_empty() and st.item == "":
				why = "%s doesn't go in the pot" % Pantry.name_of(held_ing.id)
		"board", "slicer", "grater", "bread_knife", "juicer", "blender", "steamer":
			# The press tools: one minigame each. A stand-in counts (a board slices, a
			# slicer chops, PRD 8.3), and a kind made from what is held (a lemon juices
			# into lemonade, ice cream blends into a milkshake, PRD 8.6).
			var tool := st.main_job()
			var pj := press_job(st, held_ing)
			if pj[0] != "":
				tool = pj[0]
			if st.prep_by >= 0:
				why = _in_use_by(st)
			elif pj[0] != "":
				act = str(PRESS_VERBS[tool])
				if not dry_run:
					game.prep_games.start_prep(game.chefs.find(ch), st, tool, pj[1], held)
					return act
			elif not held_ing.is_empty() and held_ing.state == "prep" and st.q(Pantry.tool_of(held_ing.id)) > 0.0:
				why = "%s is already %s" % [Pantry.name_of(held_ing.id), PRESS_DONE[Pantry.tool_of(held_ing.id)]]
			elif not held_ing.is_empty():
				why = "%s doesn't go on the %s" % [Pantry.name_of(held_ing.id), Pantry.TOOL_NAMES.get(tool, "tool")]
		"counter", "pass":
			# Empty hands: the top first, then storage. Full hands: a box's kind goes
			# back or swaps for the next first, then the thing goes down on the top.
			var r := _use_surface(st, dry_run, ch) if held == "" else _use_storage(st, dry_run, ch)
			if r[0] == "":
				var r2 := _use_storage(st, dry_run, ch) if held == "" else _use_surface(st, dry_run, ch)
				if r2[0] != "" or r2[1] != "":
					r = r2
			act = r[0]
			why = r[1]
		"dish_rack", "cups":
			# One plate or cup a press; two in the hands, four on a tray. An empty one in
			# hand goes back. The rack keeps plates, the cup stack cups.
			var v := Dish.PLATE if st.type == "dish_rack" else Dish.CUP
			var noun := "plate" if v == Dish.PLATE else "cup"
			var spare := _empty_in_hand(ch, v)
			if spare != null:
				if st.type == "dish_rack" and st.count >= Station.RACK_CAPACITY:
					why = "The rack is full"
				else:
					act = "Put back"
					if not dry_run:
						st.count += 1
						ch.drop_dish(spare)
			elif st.type == "dish_rack" and _empty_in_hand(ch, Dish.CUP) != null:
				why = "Cups go on the cup stack"
			elif st.count > 0 and _loose_in_hand(ch, v) != null:
				# A loose stack in hand is plated in place: no extra hand slot.
				act = "Plate it" if v == Dish.PLATE else "Pour into cup"
				if not dry_run:
					var loose := _loose_in_hand(ch, v)
					var d := Dish.make(v)
					st.count -= 1
					d.take_all(loose)
					var i := ch.dishes.find(loose)
					ch.dishes[i] = d
					ch.show_held()
			elif st.count > 0 and held in ["", "tray", "dishes"] and ch.has_room():
				act = "Take %s" % noun
				if not dry_run:
					st.count -= 1
					ch.take_dish(Dish.make(v))
			elif st.count > 0 and not held_ing.is_empty() and held_ing.state != "burnt":
				# Food in hand goes straight onto a plate (or into a cup) off the stack.
				var d := Dish.make(v)
				why = d.refusal(held, game.menu.items)
				if why == "":
					act = "Plate it" if v == Dish.PLATE else "Pour into cup"
					if not dry_run:
						st.count -= 1
						d.add(held, q)
						ch.set_held("")
						ch.take_dish(d)
			elif st.count <= 0 and held in ["", "tray", "dishes"]:
				why = "No clean %ss. Wash some up" % noun
			elif held == "dishes":
				why = "Your hands are full"
			if not dry_run:
				st.refresh()
		"tray_stack":
			# A tray takes four plates or cups instead of two.
			if not ch.on_tray and st.count > 0 and held in ["", "dishes", "dirty_dishes"]:
				act = "Take tray"
				if not dry_run:
					st.count -= 1
					ch.set_held(held if held != "" else "tray", 1.0, ch.dishes, true)
			elif ch.on_tray and ch.dishes.size() <= Player.HANDS:
				act = "Put tray back"
				if not dry_run:
					st.count += 1
					ch.set_held(ch.held, 1.0, ch.dishes, false)
			elif ch.on_tray:
				why = "Too much to hold without the tray"
			if not dry_run:
				st.refresh()
		"sink":
			# Plates and cups soak until they are washed: one press washes the whole sink, each
			# back onto its own stack (review, item 11: three stacks, less upkeep).
			if held == "dirty_dishes" and st.sink_room() <= 0:
				why = "The sink is full. Wash some up"
			elif held == "dirty_dishes":
				act = "Put in sink"
				if not dry_run:
					var rest := st.put_in_sink(ch.dishes)
					ch.set_held("dirty_dishes", 1.0, rest, ch.on_tray)
					st.refresh()
			elif held == "" and st.dirty > 0:
				act = "Wash"   # a hold (`_tick_wash`): one dish a hold, into the hands
				if not dry_run:
					_wash_hold[ch] = {"st": st, "t": 0.0, "punch": 0.0}
		"bin":
			# Every scrap fills it; full, it overflows until the bag goes out the front.
			var scraps := ch.dishes.filter(func(d: Dish) -> bool: return not d.is_empty()) if held == "dishes" else []
			if not scraps.is_empty():
				act = "Scrape off"
				if not dry_run:
					var keep: Array = []
					for d: Dish in ch.dishes:
						d.scrape()
						if d.vessel != "":
							keep.append(d)   # a loose stack goes in whole
					ch.set_held("dishes", 1.0, keep, ch.on_tray)
			elif not held_ing.is_empty():
				act = "Throw away"
				if not dry_run:
					ch.set_held("")
			elif held == "" and st.count > 0:
				act = "Empty bin"
				if not dry_run:
					st.count = 0
					st.refresh()
					ch.set_held("rubbish_bag")
			if not dry_run and act in ["Scrape off", "Throw away"]:
				st.count += 1
				st.refresh()
		"table":
			var g := game.seating._waiting_guest_at(st)
			var to_order := game.seating._guests_to_order(st)
			var fed: Array[Guest] = []
			if held == "dishes":
				fed = game.serving._dish_guests(st, ch.dishes)
			if not fed.is_empty():
				act = "Serve %s" % fed[0].info.name if fed.size() == 1 else "Serve %d" % fed.size()
				if not dry_run:
					game.serving.serve_dishes(ch, st)
			elif not to_order.is_empty() and (held == "" or not Game.ORDER_HANDS_FREE):
				act = "Take order" if to_order.size() == 1 else "Take %d orders" % to_order.size()
				if not dry_run:
					game.serving.take_orders(st)
			elif held == "dishes" and not to_order.is_empty():
				why = "Take order first"
				if not dry_run:
					game.hud.day_ui.say("%s hasn't ordered yet. Free your hands and take the order." % to_order[0].info.name)
					game.audio.sfx("fail")
					return why
			elif held == "dishes" and g != null:
				why = game.serving._not_served_why(ch.dishes)
			elif held in ["", "tray", "dirty_dishes"] and st.dirty > 0 and ch.has_room(true):
				act = "Clear plates"
				if not dry_run:
					clear_one(st, ch)
					while st.dirty > 0 and ch.has_room(true):
						clear_one(st, ch)
			elif held == "" and g != null and not g.mood.discounted and g.mood.patience < Game.DISCOUNT_BELOW:
				act = "Hold for half price for %s" % g.info.name   # a hold, so a stray E gives nothing away
				if not dry_run:
					game.serving._deal_hold[ch] = {"g": g, "kind": "half", "t": 0.0}
			elif held == "" and g != null and not g.mood.comped and g.mood.very_unhappy():
				act = "Hold for a free meal for %s" % g.info.name   # after half price, or for disgust
				if not dry_run:
					game.serving._deal_hold[ch] = {"g": g, "kind": "comp", "t": 0.0}
	if act == "" and not st.type in ["counter", "pass"]:
		var r := _use_storage(st, dry_run, ch)   # what the tool cannot do, storage below may
		if r[0] != "":
			return _finish_use(st, r, dry_run, ch)
	if act == "" and held != "" and held != "dishes" and Kitchen.is_top(st.type) and not st.type in ["stove", "fryer", "pot"]:
		var r := _use_surface(st, true, ch)   # a thing the tool cannot use goes down on its surface
		if r[0] != "":
			return _finish_use(st, _use_surface(st, dry_run, ch), dry_run, ch)
	return _finish_use(st, [act, why], dry_run, ch)


## Says a refusal, or plays what an action looks and sounds like. Returns the action,
## else the refusal.
func _finish_use(st: Station, r: Array, dry_run: bool, ch: Player) -> String:
	var act: String = r[0]
	var why: String = r[1]
	if act == "" and why != "":
		if not dry_run:
			game.hud.day_ui.say(why + ".")
			game.audio.sfx("fail")
		return why
	if act != "" and not dry_run:
		ch.punch()
		st.used()
		if act == "Wash":
			pass   # the hold makes the sound when the dish is clean
		elif act == "Grill":
			game.audio.sfx("grill_drop")
		elif act == "Take off the heat":
			game.audio.sfx("patty_flip")   # the spatula under the patty
		elif act.begins_with("Add ") or act == "Plate it" or act == "Pour into cup":
			game.audio.sfx("plate_food")   # onto a plate
		elif not (act.begins_with("Serve") or act.begins_with("Half") or act.begins_with("Free") or act.begins_with("Take order") or act.ends_with(" orders")):
			game.audio.sfx("pickup" if ch.held != "" else "putdown")
	return act


## The storage under a cell (PRD 8.4). Empty hands take its first kind; holding a kind
## as it came out of a box here, each use swaps it for the next kind, or with one kind
## puts it back. Returns [action, refusal].
func _use_storage(st: Station, dry_run: bool, ch: Player) -> Array:
	var stock: Dictionary = game.kitchen.take_stock(st.cell)   # a hung piece keeps its own boxes: Reach takes those
	var layer: Array = stock.get("high", []) if game.highs.get(st.cell) == st else stock.get("base", [])
	var boxes := layer.filter(func(b: String) -> bool: return not Kitchen.is_cleaning(b))
	if boxes.is_empty():
		return ["", ""]
	var held := ch.held
	if game.world.is_tall_at(st.cell):   # a tall piece has two levels: plain use is the lower, Reach the upper
		var upper: bool = game.card.reaching(ch)
		if upper and boxes.size() < 2:
			return ["", ""]
		if upper or held == "" or boxes.size() < 3 or _from_box(boxes[0]) == held or _from_box(boxes[1]) == held:
			return _use_level(boxes, 1 if upper else 0, dry_run, ch)
	if held == "":
		var b: String = boxes[0]
		if not dry_run:
			_hold_from_box(ch, b)
		return ["Take %s" % Pantry.name_of(Pantry.kind_of(b)).to_lower(), ""]
	for i in boxes.size():
		if held != _from_box(boxes[i]) or (held.begins_with("prep") and not is_equal_approx(ch.held_quality, Prep.PLAIN)):
			continue
		if boxes.size() == 1:
			if not dry_run:
				ch.set_held("")
			return ["Put back", ""]
		var next: String = boxes[(i + 1) % boxes.size()]
		if not dry_run:
			_hold_from_box(ch, next)
		return ["Swap for %s" % Pantry.name_of(Pantry.kind_of(next)).to_lower(), ""]
	return ["", ""]


## One level of a tall piece (0 lower, 1 upper): empty hands take its kind; holding it puts
## it back, holding the other level's kind swaps. Returns [action, refusal].
func _use_level(boxes: Array, level: int, dry_run: bool, ch: Player) -> Array:
	var mine: String = boxes[level]
	var my_name := Pantry.name_of(Pantry.kind_of(mine)).to_lower()
	if ch.held == "":
		if not dry_run:
			_hold_from_box(ch, mine)
		return ["Take %s" % my_name, ""]
	if not _is_plain_from(ch, boxes.slice(0, 2)):
		return ["", ""]
	if ch.held == _from_box(mine):
		if not dry_run:
			ch.set_held("")
		return ["Put back", ""]
	if not dry_run:
		_hold_from_box(ch, mine)
	return ["Swap for %s" % my_name, ""]


func _is_plain_from(ch: Player, boxes: Array) -> bool:
	for b in boxes:
		if ch.held == _from_box(b) and not (ch.held.begins_with("prep") and not is_equal_approx(ch.held_quality, Prep.PLAIN)):
			return true
	return false


func _hold_from_box(ch: Player, box: String) -> void:
	var k := _from_box(box)
	ch.set_held(k, Prep.PLAIN if k.begins_with("prep") else 1.0)


## What comes out of a box: raw, or prepped and plain when it is ready-made or needs no prep.
static func _from_box(box: String) -> String:
	var s := Pantry.station_ingredient(box)
	if s.ready or not Pantry.needs_prep(s.id):
		return Tray.kind("prep", s.id)
	return Tray.kind("raw", s.id)


## A counter's worktop, and the free surface of any tool on one: it holds one thing,
## a tray to build on or a single item. Returns [action, refusal].
func _use_surface(st: Station, dry_run: bool, ch: Player) -> Array:
	var held := ch.held
	var q := ch.held_quality
	var held_ing := Tray.parse(held)
	var here: Dish = st.dish if st.item == "dish" else null
	var here_ing := Tray.parse(st.item)
	var items := game.menu.items
	var act := ""
	var why := ""
	if not held_ing.is_empty():
		if st.item == "":
			if held_ing.state != "burnt":
				act = "Put down"
				if not dry_run:
					st.set_item(held, q)
					ch.set_held("")
		elif here != null:
			# Onto a plate, a cup, or a stack already started.
			why = here.refusal(held, items)
			if why == "":
				act = "Add %s" % Pantry.name_of(held_ing.id).to_lower()
				if not dry_run:
					here.add(held, q)
					ch.set_held("")
					st.show_dish()
		elif not here_ing.is_empty():
			# Two things made combine into a stack on the worktop (a bun on a patty).
			var d := Dish.new()
			why = d.refusal(st.item, items)
			if why == "":
				d.add(st.item, st.current_quality())
				why = d.refusal(held, items)
			if why == "":
				act = "Add %s" % Pantry.name_of(held_ing.id).to_lower()
				if not dry_run:
					d.add(held, q)
					ch.set_held("")
					st.set_dish(d)
	elif held == "dishes":
		var loose: Dish = here if here != null and here.vessel == "" else null
		if loose == null and not here_ing.is_empty():
			loose = Dish.new()
			loose.add(st.item, st.current_quality())
		if st.item == "":
			if is_countertop_item(st):
				why = "Plates go on a clear counter"
			else:
				act = "Put down"
			if act != "" and not dry_run:
				var d: Dish = ch.dishes.back()
				ch.drop_dish(d)
				st.set_dish(d)
		elif loose != null:
			# Food on the worktop goes onto a plate (or into a cup) in hand.
			var target: Dish = null
			for i in range(ch.dishes.size() - 1, -1, -1):
				var d: Dish = ch.dishes[i]
				if d.vessel == "" and here_ing.is_empty():
					continue   # two loose stacks do not merge in the air
				var r := d.refusal(st.item, items) if not here_ing.is_empty() else d.merge_refusal(loose, items)
				if r == "":
					target = d
					break
				if why == "":
					why = r
			if target == null and why == "":
				why = "Get a plate for that" if not Pantry.is_drink(loose.ings[0]) else "Get a cup for that"
			if target != null:
				why = ""
				var was_empty := target.is_empty() and target.vessel != ""
				act = ("Plate it" if target.vessel == Dish.PLATE else "Pour into cup") if was_empty else (
					"Add %s" % Pantry.name_of(loose.ings[0]).to_lower() if loose.ings.size() == 1 else "Add it")
				if not dry_run:
					target.take_all(loose)
					if was_empty and not is_countertop_item(st):
						# The empty plate (or cup) slides under the food and stays on the worktop.
						ch.drop_dish(target)
						st.set_dish(target)
					else:
						st.set_item("")
						ch.show_held()
		elif here != null:
			# A loose stack in hand goes onto the plate on the worktop; else it is picked up.
			var stack: Dish = null
			for d: Dish in ch.dishes:
				if d.vessel == "" and here.merge_refusal(d, items) == "":
					stack = d
					break
			if stack != null:
				act = "Plate it"
				if not dry_run:
					here.take_all(stack)
					ch.drop_dish(stack)
					st.show_dish()
			elif ch.has_room():
				act = "Pick up"
				if not dry_run:
					st.set_item("")
					ch.take_dish(here)
			else:
				why = "Your hands are full"
	elif held == "dirty_dishes":
		if st.item == "":
			act = "Put down"
			if not dry_run:
				var d: Dish = ch.dishes.back()
				ch.drop_dish(d)
				st.set_dish(d)
		elif here != null and here.dirty and ch.has_room(true):
			act = "Pick up"
			if not dry_run:
				st.set_item("")
				ch.take_dish(here)
	elif held in ["", "tray"] and here != null:
		act = "Pick up"
		if not dry_run:
			st.set_item("")
			ch.take_dish(here)
	elif held == "" and st.item != "":
		act = "Pick up"
		if not dry_run:
			ch.set_held(st.item, st.current_quality())
			st.set_item("")
	return [act, why]


## A plate (or cup) in hand with nothing on it, last taken first; null for none.
func _empty_in_hand(ch: Player, vessel: String) -> Dish:
	if ch.held != "dishes":
		return null
	for i in range(ch.dishes.size() - 1, -1, -1):
		if ch.dishes[i].vessel == vessel and ch.dishes[i].is_empty():
			return ch.dishes[i]
	return null


## The loose stack in hand (no vessel) that this plate or cup would take, last taken
## first; null for none or when the vessel refuses it.
func _loose_in_hand(ch: Player, vessel: String) -> Dish:
	if ch.held != "dishes":
		return null
	for i in range(ch.dishes.size() - 1, -1, -1):
		var l: Dish = ch.dishes[i]
		if l.vessel == "" and not l.is_empty():
			return l if Dish.make(vessel).merge_refusal(l, game.menu.items) == "" else null
	return null


## A cup in hand that this drink can go in ("" for any cup), or null.
func _cup_in_hand(ch: Player, drink: String) -> Dish:
	if ch.held != "dishes":
		return null
	for d: Dish in ch.dishes:
		if d.vessel == Dish.CUP and (drink == "" or d.refusal(Tray.kind("prep", drink), game.menu.items) == ""):
			return d
	return null


## Washes one dish in a sink, plates first, into a clean empty dish.
func wash_one(st: Station) -> Dish:
	var cup := st.dirty_cups >= st.dirty
	st.dirty -= 1
	if cup:
		st.dirty_cups -= 1
	st.refresh()
	return Dish.make(Dish.CUP if cup else Dish.PLATE)


## Washing at a sink: E starts a hold and one dish comes clean in the hands once E has been
## held WASH_HOLD; the prompt counts "Washing N%" like scrubbing, with no bar. Let go, or walk off, and the
## progress is lost.
const WASH_HOLD := 1.5   # tunable
const WASH_BEAT := 0.45  # seconds between scrubs of the arm
var _wash_hold := {}     # Player -> {st: Station, t: seconds held, punch: seconds to the next scrub}


func _tick_wash(ch: Player, held: bool, delta: float) -> void:
	if not _wash_hold.has(ch):
		return
	var w: Dictionary = _wash_hold[ch]
	var st: Station = w.st
	if not held or not is_instance_valid(st) or st.dirty <= 0 or ch.held != "" or game.world.station_at(ch.target_cell()) != st:
		_wash_hold.erase(ch)
		return
	w.t = float(w.t) + delta
	w.punch = float(w.punch) - delta
	if float(w.punch) <= 0.0:
		w.punch = WASH_BEAT
		ch.punch()   # the scrubbing arm
		game.audio.burst(st.global_position + Vector3(0, 1.0, 0), "bubbles", 0.15)
	if float(w.t) >= WASH_HOLD:
		_wash_hold.erase(ch)
		ch.take_dish(wash_one(st))
		game.audio.sfx("wash")
		game.audio.burst(st.global_position + Vector3(0, 1.15, 0), "bubbles", 0.4)


## A clean plate or cup in hand with nothing on it, last taken first; null for none.
func _clean_empty_in_hand(ch: Player) -> Dish:
	if ch.held != "dishes":
		return null
	for i in range(ch.dishes.size() - 1, -1, -1):
		var d: Dish = ch.dishes[i]
		if d.vessel != "" and d.is_empty() and not d.dirty:
			return d
	return null


## Who is working a tool another press found busy (review, item 11): "Chef 2 has it" in
## co-op, "A helper has it" for staff.
func _in_use_by(st: Station) -> String:
	if st.prep_by == Crew.HELPER_PREP:
		return "A helper has it"
	if st.prep_by >= 0 and game.chefs.size() > 1:
		return "Chef %d has it" % (st.prep_by + 1)
	return "In use"


## Takes one dirty dish off a table into the hands: plates first.
func clear_one(st: Station, ch: Player) -> void:
	var cup := st.dirty_cups >= st.dirty
	st.dirty -= 1
	if cup:
		st.dirty_cups -= 1
	st.refresh()
	ch.take_dish(Dish.make(Dish.CUP if cup else Dish.PLATE, true))


## The press tools' actions and what a kind is once done (PRD 8.6).
const PRESS_VERBS := {"chop": "Chop", "slice": "Slice", "grate": "Grate", "saw": "Saw", "juice": "Juice",
	"blend": "Blend", "steam": "Steam"}
const PRESS_DONE := {"chop": "chopped", "slice": "sliced", "grate": "grated", "saw": "sawn", "juice": "juiced",
	"blend": "blended", "steam": "steamed"}


## What a press tool would make of what is held: [job, kind made], or ["", ""]. The
## held kind's own job first, where this piece does it; else a kind made from it whose
## job this piece does (lemon: lemonade at a juicer). Raw only, except a kind that
## needs no prep of its own (ice cream comes out of the freezer ready).
static func press_job(st: Station, held_ing: Dictionary) -> Array:
	if held_ing.is_empty():
		return ["", ""]
	var id: String = held_ing.id
	if held_ing.state == "raw":
		# The station's own main job wins when it makes a kind from this one (a grater grates cheese).
		for k: String in Pantry.made_from(id):
			if st.main_job() == Pantry.tool_of(k) and PRESS_VERBS.has(st.main_job()) and st.q(st.main_job()) > 0.0:
				return [st.main_job(), k]
		var own := Pantry.tool_of(id)
		if PRESS_VERBS.has(own) and st.q(own) > 0.0:
			return [own, id]
	elif held_ing.state != "prep" or Pantry.needs_prep(id):
		return ["", ""]
	for k: String in Pantry.made_from(id):
		var job := Pantry.tool_of(k)
		if PRESS_VERBS.has(job) and st.q(job) > 0.0:
			return [job, k]
	return ["", ""]


## Whether a tool's surface, rather than the tool, answers Use: empty hands take what
## sits on it first, and a plate goes down on it or is built on it. A heat tool's own
## item is its cooking, so only a dish rests there.
static func surface_first(st: Station, held: String) -> bool:
	if not Kitchen.is_top(st.type) or st.prep_by >= 0:
		return false
	if st.type in ["stove", "fryer", "pot"]:
		return st.item == "dish" or (held == "dishes" and st.item == "")
	return (held == "" and st.item != "") or held == "tray" or (held == "dishes" and (st.item != "" or not is_countertop_item(st))) or st.item == "dish"


## The till, or a tool standing on a counter: plates never go down on these, only on a
## clear counter or the pass.
static func is_countertop_item(st: Station) -> bool:
	return st.has_node("till") or Kitchen.is_top(st.type)
