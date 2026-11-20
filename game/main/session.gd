class_name GameSession
extends RefCounted
## Opening the night (night zero and the starter kitchen), autosave and Continue, the title
## and quitting, the theme pick, and opening and filling the build shop.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- building

## Night 0: the game opens with the door card on CLOSED and the room to set up.
## Nothing has been played yet, so there is no receipt; day 1 starts at the door.
func _open_first_night() -> void:
	_starter_kitchen()
	game.phase = Game.Phase.BUILD
	game.door_open = false
	game._door_turn.rotation.y = PI
	game.audio.play_music("night")
	game.hud.hints_ui.show_build()
	game.hud.day_ui.say("The night before day 1. Set up the kitchen, then flip the door card.")
	autosave()


## Night zero's starting goodies (review, item 7): the starting main's stove and fridge,
## built already, its two boxes stocked, a cup stack beside the plates and a sponge on a hook. Only in a new
## kitchen that has none of them yet.
func _starter_kitchen() -> void:
	if not game.ledger.history.is_empty() or game.world.find_station("stove") != null:
		return
	var fm := GameWorld.fixed_main()
	if not game.stations.has(Vector2i(0, 2)):
		game.menu_stock.stock_box(fm.grill, Vector2i(0, 2), false, 1)   # the corner fridge, the chilled kind in it
	if not game.stations.has(Vector2i(0, 3)):
		game.world.add_station("stove", Vector2i(0, 3), 1, 1)   # under the hood: a counter grown into a stove
	if not game.stations.has(Vector2i(0, 4)):
		game.menu_stock.stock_box(fm.bread, Vector2i(0, 4), false, 1)
	if game.world.find_station("cups") == null and not game.stations.has(Vector2i(1, 2)):
		game.world.add_station("cups", Vector2i(1, 2))
	# A sponge on its hook by the sink (owner's review of night zero): something to wipe
	# the first spills with, before a mop is bought.
	if game.highs.values().all(func(h: Station) -> bool: return h.node != "hook"):
		for c: Vector2i in [Vector2i(2, 2), Vector2i(1, 2), Vector2i(4, 1)]:
			if not game.highs.has(c) and game.kitchen.can_hang(c, "hook"):
				game.clean_kit.on_built(game.world.add_high("hook", c), "sponge")
				break
	game.menu_stock.menu_changed()


## A saved game comes back on the night it was saved: the room to tend, the door closed.
func _open_night() -> void:
	game.phase = Game.Phase.BUILD
	game.door_open = false
	game._door_turn.rotation.y = PI
	game.audio.play_music("night")
	game.desk.roll_applicants()
	game.hud.hints_ui.show_build()
	game.hud.day_ui.say("Welcome back. Day %d is tomorrow: set up the kitchen, then flip the door card." % game.ledger.day)


## Writes the saved game. Skipped when the game runs headless on the real save's path
## (the tests set their own).
func autosave() -> void:
	if DisplayServer.get_name() == "headless" and game.save_path == SaveGame.PATH:
		return
	SaveGame.write(SaveGame.capture(game), game.save_path)


## Continue on the title screen: the saved game, loaded into a fresh scene.
func continue_game() -> void:
	if game.phase != Game.Phase.TITLE:
		return
	var data := SaveGame.read(game.save_path)
	if data.is_empty():
		return
	Game._resume_data = data
	Scenery.theme_id = SaveGame.theme_of(data)
	Game._kept_seats = game.controls.seats.duplicate()
	game.get_tree().paused = false
	if game.is_inside_tree() and game.get_tree().current_scene == game:
		game.get_tree().call_deferred("reload_current_scene")


## Save and quit from the pause menu: in the build phase the night's work so far is
## saved first; in any other phase the night-start save stands and the day is lost.
func save_and_quit() -> void:
	save_night()
	quit_to_title()


## The build-phase save on quit: the shop closed and every chef's hand put down (a lifted
## piece goes back to its cell; a new, unpaid one is dropped), then the room is written.
func save_night() -> void:
	if game.phase != Game.Phase.BUILD:
		return
	close_shop()
	for ch in game.chefs:
		game.placing.cancel_hand(ch)
	autosave()


## Quit to title: back to the first screen of a fresh launch.
func quit_to_title() -> void:
	Game._theme_picked = false
	Game._title_seen = false
	Game._kept_seats = game.controls.seats.duplicate()
	game.get_tree().paused = false
	game.get_tree().reload_current_scene()


## The title screen over the room, before the night before day 1.
func open_title() -> void:
	Game._title_seen = true
	game.phase = Game.Phase.TITLE
	game.door_open = false
	game._door_turn.rotation.y = PI
	game.audio.play_music("title")
	game.hud.options_ui.show_title()


## Play on the title screen: the theme card, unless REGULARS_THEME already chose.
func play() -> void:
	if game.phase != Game.Phase.TITLE:
		return
	if theme_forced():
		Game._theme_picked = true
		game.hud.options_ui.hide_title()
		_open_first_night()
		return
	game.hud.options_ui.title.show_themes()


## REGULARS_THEME is set: a developer's switch that skips the theme card.
static func theme_forced() -> bool:
	return OS.get_environment("REGULARS_THEME") != ""


## The theme picked last time (to preselect on the card), or the current one.
func remembered_theme() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(game.theme_path) == OK:
		var id := str(cfg.get_value("run", "theme", ""))
		if Scenery.THEMES.has(id):
			return id
	return Scenery.theme_id


## A theme picked on the card: it holds for the run. The room is built for a theme,
## so a different one reloads the scene, which then opens straight on the night
## before day 1; the same one carries on in place.
func choose_theme(id: String) -> void:
	if game.phase != Game.Phase.TITLE or not Scenery.THEMES.has(id):
		return
	var cfg := ConfigFile.new()
	cfg.set_value("run", "theme", id)
	cfg.save(game.theme_path)
	Game._theme_picked = true
	var rebuild := id != Scenery.theme_id
	Scenery.theme_id = id
	if rebuild and game.is_inside_tree() and game.get_tree().current_scene == game:
		Game._kept_seats = game.controls.seats.duplicate()
		game.get_tree().call_deferred("reload_current_scene")
		return
	game.hud.options_ui.hide_title()
	_open_first_night()


## Quit on the title screen (not offered on phones or the web).
func quit_game() -> void:
	game.quit_asked = true
	if game.allow_quit:
		game.get_tree().quit()


## After the receipt: the room is yours to walk round and change, until you flip
## the door card to open for the day.
func open_build() -> void:
	if game.phase != Game.Phase.SUMMARY:
		return
	game.phase = Game.Phase.BUILD
	game.ready_chefs.clear()
	game.hud.receipt_ui.hide_card()
	if Staff.week_day(game.ledger.day) == 0:   # a new week: everyone picks their days off (PRD 10.4)
		game.staff.start_week(game.ledger.day)
	game.desk.roll_applicants()
	game.hud.hints_ui.show_build()
	game.tidy.play()
	autosave()   # the night's start: where Continue picks up


## What the shop lists for a search and a category tab: the catalog, the laying tool of
## each floor treatment with its box stored (PRD 9.5) under Build, and the flyers under Extras.
func shop_items(query := "", category := "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if game.card.storing():   # a piece's card: its actions, then what is stored here, then every box there is
		var acts := game.card.card_actions()
		if not game.card.card_keeps_boxes():
			return acts
		for box: String in game.kitchen.stock(game.storing_cell):
			found.append({"id": box, "tier": 1, "stored": true})
		for bp in Catalog.search(query, "Pantry", Scenery.theme_id, game.ledger.level()):
			if not game.kitchen.stock(game.storing_cell).has(bp.id):
				found.append(bp)
		found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:   # what fits first
			return game.card._storage_rank(a) < game.card._storage_rank(b))
		return acts + found
	if category != "Extras":
		# What can be bought tonight only (owner's review of night zero): a piece above the
		# level is left out, but a missing essential is sold at any level.
		for bp in Catalog.search(query, category, Scenery.theme_id, game.ledger.level(), true):
			if not bp.get("locked", false):
				found.append(bp)
			elif not bp.has("tree") and game.placing.missing(bp.id):
				found.append({"id": bp.id, "tier": bp.tier})
	if category == "" or category == "Build":
		for k: String in Treatments.ITEMS:
			var id := Treatments.tool_id(k)
			if not game.menu_stock.treat_boxed().has(k):
				continue
			var hit := true
			var text := ("%s build floor treatment %s" % [Treatments.name_of(k), Treatments.ITEMS[k].blurb]).to_lower()
			for w in query.strip_edges().to_lower().split(" ", false):
				hit = hit and text.contains(w)
			if hit:
				found.append({"id": id, "tier": 1})
	if category == "" or category == "Extras":
		var hit := true
		for w in query.strip_edges().to_lower().split(" ", false):
			hit = hit and "flyers extras more guests tomorrow".contains(w)
		if hit:
			found.append(Game.FLYERS)
		var hit_c := true
		for w in query.strip_edges().to_lower().split(" ", false):
			hit_c = hit_c and "cleaner extras clean up tidy mop wash".contains(w)
		if hit_c:
			found.append(Game.CLEANER)
	return found


func open_shop(ch: Player = null) -> void:
	ch = game._me(ch)
	if game.phase != Game.Phase.BUILD:
		return
	if game.shopping:   # one shop for everyone: the other player's Shop does nothing
		if game.shopper != ch:
			game.hud.day_ui.say("Chef %d is shopping." % (game.chefs.find(game.shopper) + 1))
		return
	if Cleaning.carrying_mess(ch.held):
		game.audio.sfx("fail")
		game.hud.day_ui.say(Cleaning.HANDS_FULL)
		return
	if ch.hand.get("moving", false):   # a piece in hand: its upgrades are on the strip
		game.audio.sfx("fail")
		game.hud.day_ui.say("Put the %s down to shop. Its upgrades are along the bottom." % GamePlacing.piece_name(ch.hand).to_lower())
		return
	game.shopper = ch
	game.audio.sfx("slide")
	game.hud.shop_ui.show_shop()


func close_shop() -> void:
	if not game.shopping:
		return
	var ch := game.shopper
	var carried: Dictionary = ch.hand.duplicate() if ch.hand.get("carry", false) else {}
	if not carried.is_empty():
		game.card._settle(ch)
	if game.upgrading and game.shopper.hand.get("in_place", false):
		game.shopper.hand = {}   # upgraded where it stands: nothing was lifted
	game.storing_cell = Game.NO_CELL
	game.shopper = null
	game.audio.sfx("slide", 0.0, 0.8)
	if game.upgrading:
		game.upgrading = false
		game.hud.screens_ui.hide_tree()
	else:
		game.hud.shop_ui.hide_shop()
	if not carried.is_empty():   # Tab or Esc: the piece stays in hand to carry elsewhere
		game.placing.pick_up(Grid.center(Vector2i(carried.from.x, carried.from.y)), ch, true, str(carried.layer))
