class_name GameMenuStock
extends RefCounted
## The kitchen's stock and tonight's menu: what can be made, storage of each kind, the
## night's cost, floor treatments boxed and in force, the open block and night hints, and
## opening the menu screen.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- menu, tickets and dishes

## Every kind stocked tonight, each once: {ingredient, ready, stocked}. A box in a storage
## slot stocks its kind (PRD 8.4); a drink dispenser holds its own drinks, no slot needed.
func kitchen_stock() -> Array:
	var out := []
	var seen := {}
	for b: String in game.kitchen.stocked():
		if Kitchen.is_cleaning(b):
			continue   # a treatment's box stocks no food (PRD 9.5)
		var s := Pantry.station_ingredient(b)
		var key := Pantry.box_id(s.id, s.ready, s.marinated)
		if not seen.has(key):
			seen[key] = true
			out.append({"ingredient": s.id, "ready": s.ready, "marinated": s.marinated, "stocked": true})
	for st: Station in game.stations.values():
		for d: String in dispenser_drinks(st):
			if not seen.has(Pantry.box_id(d)):
				seen[Pantry.box_id(d)] = true
				out.append({"ingredient": d, "ready": false, "stocked": true})
	# Kinds made from a stocked kind (lemonade from lemons, PRD 8.6): no box, no fee.
	for s: Dictionary in out.duplicate():
		if s.ready:
			continue
		for d: String in Pantry.made_from(s.ingredient):
			if not seen.has(Pantry.box_id(d)):
				seen[Pantry.box_id(d)] = true
				out.append({"ingredient": d, "ready": false, "stocked": true, "derived": true})
	return out


## The drinks a dispenser on a counter pours (the fountain's soda, the barrel's wine).
func dispenser_drinks(st: Station) -> Array[String]:
	var out: Array[String] = []
	var drinks: Array = Kitchen.NODES[st.node].get("drinks", []) if Kitchen.has_node(st.node) else []
	if drinks.is_empty() and Catalog.ingredient_of(st.type) != "" and not Catalog.is_box(st.type):
		drinks = [Catalog.ingredient_of(st.type)]
	for d: String in drinks:
		if Pantry.has(d):
			out.append(d)
	return out


## The dispenser each poured drink comes from, for the menu screen's greyed lines.
const POURED_FROM := {"soda": "soda fountain", "cola": "two-tap fountain", "coffee": "coffee machine",
	"wine": "wine barrel", "red_wine": "wine rack", "ale": "beer tap"}


## Which drink a dispenser with several taps pours next: the first a ticket on the
## rail still wants, else the tap it is turned to.
func pour_pick(st: Station, taps: Array[String], cup: Dish = null) -> String:
	var fits := func(d: String) -> bool:
		return cup == null or cup.refusal(Tray.kind("prep", d), game.menu.items) == ""
	if cup != null and not cup.is_empty():
		for d in taps:
			if fits.call(d):
				return d   # a cup started on one drink is finished with the one it lacks
	for t: Dictionary in game.tickets:
		for it: Dictionary in t.get("items", []):
			for d: String in it.get("ingredients", []):
				if taps.has(d) and fits.call(d):
					return d
	return taps[st.tap % taps.size()]


## Why a menu item is off tonight, worded for the menu screen: a kind with no box says
## what it needs ("Patty: needs a fridge"), else the menu's own reason. "" if it is on.
func item_off_reason(it: Dictionary) -> String:
	var why := Menu.off_reason(it, kitchen_stock(), kitchen_tools())
	if why == "" or it.get("off", false):
		return why
	var have := {}
	for s: Dictionary in kitchen_stock():
		have[s.ingredient] = true
	for ing: String in it.ingredients:
		if not have.has(ing):
			if Pantry.is_poured(ing):
				return "%s: needs a %s" % [Pantry.name_of(ing), POURED_FROM.get(ing, "soda fountain")]
			if Pantry.is_derived(ing):
				return "%s: needs %s" % [Pantry.name_of(ing), Pantry.name_of(Pantry.source_of(ing)).to_lower()]
			if Kitchen.is_frozen(ing):
				return "%s: needs a freezer" % Pantry.name_of(ing)
			if Kitchen.is_chilled(ing) and not game.kitchen.has_fridge():
				return "%s: needs a fridge" % Pantry.name_of(ing)
			return "%s: needs a box" % Pantry.name_of(ing)
	return why


## Puts a box of an ingredient in the room for tests and demos: into the counter at
## `cell` (one is set there, upgraded to a fridge for a chilled kind, if the cell is
## free), else nowhere. Returns the station holding it, or null.
func stock_box(kind: String, cell: Vector2i, ready := false, facing := 0, marinated := false) -> Station:
	var box := Pantry.box_id(kind, ready, marinated)
	if not game.stations.has(cell):
		game.world.add_station("counter", cell, 1, facing, "freezer" if Kitchen.is_frozen(box) else ("fridge" if Kitchen.is_chilled(box) else ""))
	if not game.placing._store_box(cell, box):
		return null
	return game.stations[cell]


## The station whose storage holds a kind (or box id), for tests and demos; null if none.
func storage_of(kind: String) -> Station:
	for cell: Vector2i in game.kitchen.cells_with(kind if Catalog.is_box(kind) else Pantry.box_id(kind)) \
			+ game.kitchen.cells_with(Pantry.box_id(kind, true)) + game.kitchen.cells_with(Pantry.box_id(kind, false, true)):
		return game.stations.get(cell)
	return null


## The prep tools in the room ("grill", "fry", ...).
func kitchen_tools() -> Array:
	var out := []
	for st: Station in game.stations.values():
		var jobs := Kitchen.jobs_of(st.node) if Kitchen.has_node(st.node) else {}
		if jobs.is_empty() and Catalog.tool_of(st.type) != "":
			jobs = {Catalog.tool_of(st.type): 1.0}
		for t: String in jobs:   # stand-ins count: a board can slice (PRD 8.3)
			if jobs[t] > 0.0 and not out.has(t):
				out.append(t)
	return out


## The menu items that can be offered tonight.
func tonight_menu() -> Array[Dictionary]:
	return game.menu.tonight(kitchen_stock(), kitchen_tools())


## The kitchen the tests and most demos start from: the theme's fixed line (the
## grilled ingredient's station, two stoves, the bread's) and a menu of its one main
## (a Burger in the diner, a Fish roll by the sea).
func test_kitchen() -> void:
	var fm := GameWorld.fixed_main()
	# Built from pieces (PRD 8.4): the grilled kind's box in an under-counter fridge,
	# two stoves on counters, the bread's box in a plain counter.
	if not game.stations.has(Vector2i(0, 2)):
		stock_box(fm.grill, Vector2i(0, 2))
	for at: Vector2i in [Vector2i(0, 3), Vector2i(0, 4)]:
		if not game.stations.has(at):
			game.world.add_station("stove", at, 1, 1)
	if not game.stations.has(Vector2i(0, 6)):
		stock_box(fm.bread, Vector2i(0, 6), false, 1)
	write_test_menu()
	game.menu_board.refresh(tonight_menu())


## Takes every hung piece off the walls, unpaid, stock and all (tests of other
## systems start with bare walls, as they did before PRD 8.5).
func clear_walls() -> void:
	for c: Vector2i in game.highs.keys():
		var st: Station = game.highs[c]
		game.highs.erase(c)
		game.kitchen.remove(c, "high")
		st.queue_free()
		game.world._show_boxes(c)


## A one-item menu for tests: the theme's fixed main (a Burger: bun, patty).
func write_test_menu() -> void:
	game.menu.items.clear()
	game.menu.add("main", [GameWorld.fixed_main().bread, GameWorld.fixed_main().grill], GameWorld.fixed_main().name)


## What tomorrow's stock costs: every stocked ingredient station's fee, and re-laying
## the floor treatments switched on (PRD 9.5).
func night_cost() -> int:
	return Menu.night_cost(kitchen_stock()) + Treatments.night_cost(_laid_on_floor(), game.treat_off, treat_boxed())


## The treatments with a box stored somewhere: key -> true.
func treat_boxed() -> Dictionary:
	var out := {}
	for b: String in game.kitchen.stocked():
		if Treatments.is_box(b):
			out[Treatments.key_of(b)] = true
	return out


## The laid cells still floor (floor taken up takes its treatment with it).
func _laid_on_floor() -> Dictionary:
	var out := {}
	for c: Vector2i in game.treat_laid:
		if game.plan.has_floor(c):
			out[c] = game.treat_laid[c]
	return out


## The cells treated for tomorrow's service: laid, switched on, box stored.
func treat_active() -> Dictionary:
	return Treatments.active(_laid_on_floor(), game.treat_off, treat_boxed())


## Switches a laid treatment off (not re-laid, nothing paid) or back on.
func switch_treatment(key: String, on: bool) -> void:
	if on:
		game.treat_off.erase(key)
	else:
		game.treat_off[key] = true
	menu_changed()


## The restock note's ingredient lines, one per stocked kind: {name, fee}, dearest
## first. (Other lines, such as staff wages, are the note's own.)
func stock_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in kitchen_stock():
		if s.get("derived", false):
			continue   # made from another kind's stock, which is listed
		var node := " (prepared)" if s.ready else (" (marinated)" if s.get("marinated", false) else "")
		out.append({"name": Pantry.name_of(s.ingredient) + node,
			"fee": Pantry.box_fee(Pantry.box_id(s.ingredient, s.ready, s.get("marinated", false)))})
	var lines := Treatments.night_lines(_laid_on_floor(), game.treat_off, treat_boxed())
	for k: String in lines:   # floor treatments, re-laid each night (PRD 9.5)
		var l: Dictionary = lines[k]
		var why := "" if l.on else (", off" if game.treat_off.has(k) else ", no box")
		out.append({"name": "%s box, %d tile%s%s" % [Treatments.name_of(k), l.cells, "" if l.cells == 1 else "s", why],
			"fee": l.fee})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.fee) > int(b.fee))
	return out


## The stations of one catalog type.
func stations_of(type: String) -> Array[Station]:
	var out: Array[Station] = []
	for st: Station in game.stations.values():
		if st.type == type:
			out.append(st)
	return out


## Something about tonight's menu changed: the board by the door and the notes follow.
func menu_changed() -> void:
	game.menu_board.refresh(tonight_menu())
	if game.phase == Game.Phase.BUILD and not game.shopping:
		game.hud.hints_ui.show_build()


## The door card's reason on night zero with no main. use_door keeps quiet about it:
## the glowing key over the board is the hint.
const NO_MAIN_YET := "No main on the menu yet."


## Why the door card will not flip to open, or "" if it will.
func open_block() -> String:
	for id in Game.ESSENTIALS:
		if game.placing.missing(id):
			return "The kitchen needs a %s. Buy one in the shop (%s)." % [GamePlacing.piece_name({"id": id, "tier": 1}).to_lower(), game.controls.glyph("shop")]
	if game.world.find_station("cups") == null and tonight_menu().any(func(it: Dictionary) -> bool: return it.course == "drink"):
		return "Drinks go out in cups: the kitchen needs a cup stack. Buy one in the shop (%s)." % game.controls.glyph("shop")
	if not Menu.has_main(tonight_menu()):
		if game.ledger.history.is_empty():
			return NO_MAIN_YET   # never shown: the key over the board says it
		return "No main on the menu can be made. Check the menu (%s)." % game.controls.glyph("menu")
	if night_cost() > game.ledger.money:
		return "Tomorrow's stock costs $%d. You have $%d. %s" % [night_cost(), game.ledger.money, money_remedy()]
	return ""


## The receipt's nudges (review, item 11): each side or drink on tonight's menu that
## nobody ordered, and why that may be: a side or drink is ordered only by someone who
## likes something in it, so it names what is in it that nobody who came likes.
func unordered_nudges() -> Array[String]:
	var out: Array[String] = []
	if int(game.ledger.today.served) == 0:
		return out
	var ordered: Dictionary = game.ledger.today.get("ordered", {})
	for it: Dictionary in tonight_menu():
		if it.course == "main" or int(ordered.get(int(it.id), 0)) > 0:
			continue
		var tag := ""
		for ing: String in it.ingredients:
			for t: String in Pantry.tags_of(ing):
				if t != "drink" and tag == "":
					tag = t
		var why := "Nobody who came likes %s." % Menu.tag_word(tag) if tag != "" \
			else "A %s is ordered only by someone who likes something in it." % it.course
		out.append("%s: no orders. %s" % [it.name, why])
	return out


## What to do when tomorrow's stock costs more than there is (review, item 11): the
## dearest line to take out, and selling something.
func money_remedy() -> String:
	var lines := stock_lines()
	var dear := ""
	if not lines.is_empty() and int(lines[0].fee) > 0:
		dear = "Take out the dearest box, %s ($%d a night), or a" % [str(lines[0].name).to_lower(), int(lines[0].fee)]
	else:
		dear = "Take a"
	return "%s dish off the menu (%s), or sell something: E on a piece, then Sell." % [dear, game.controls.glyph("menu")]


## Night zero's three hints, one at a time as the player goes; "" once they are done
## or on any later night.
func night_hint() -> String:
	if not game.ledger.history.is_empty() or game.phase != Game.Phase.BUILD:
		return ""
	if kitchen_stock().is_empty() or kitchen_tools().is_empty():
		return Game.NIGHT_HINTS[0]
	if not Menu.has_main(tonight_menu()):
		return Game.NIGHT_HINTS[1]
	return Game.NIGHT_HINTS[2]


## The menu screen, at night only: it cannot change during service.
func open_menu(ch: Player = null) -> bool:
	ch = game._me(ch)
	if game.phase != Game.Phase.BUILD:
		if game.phase == Game.Phase.SERVICE:
			game.hud.day_ui.say("The menu can't change during service.")
			game.audio.sfx("fail")
		return false
	if Cleaning.carrying_mess(ch.held) or game.hud.card_open():
		return false
	if game.shopping:
		game.session.close_shop()
	if not ch.hand.is_empty():
		game.placing.cancel_hand(ch)
	game.hud.open_menu()
	game.audio.sfx("slide")
	return true


func close_menu() -> void:
	if game.hud.menu_open():
		game.hud.close_menu()
		game.audio.sfx("slide", 0.0, 0.8)
		menu_changed()
