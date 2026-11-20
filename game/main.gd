class_name Game
extends Node3D
## Regulars vertical slice: an endless run of days. Cook meat, serve guests, get paid.

enum Phase { SERVICE, SUMMARY, CLOSED, BUILD, TITLE }

## The fixed menu until the menu screen is built: one main per theme, a bread and
## something grilled, and the starting kitchen has a station for each.
const FIXED_MAIN := {
	"diner": {"name": "Burger", "bread": "bun", "grill": "patty"},
	"seaside": {"name": "Fish roll", "bread": "roll", "grill": "fish"},
}
## What the prep demos use for each tool, per theme.
const DEMO_PREP := {
	"diner": {"fry": "potato", "boil": "corn", "chop": "tomato", "slice": "cheese", "pour": "soda"},
	"seaside": {"fry": "calamari", "boil": "new_potato", "chop": "courgette", "slice": "lemon", "pour": "wine"},
}
## PRD 8.6: what the new jobs' demos make, per theme (the kind made; its source is held).
const DEMO_PREP_NEW := {
	"diner": {"grate": "shredded_cheese", "saw": "sourdough", "juice": "orange_juice", "blend": "milkshake", "steam": "steamed_corn"},
	"seaside": {"grate": "breadcrumbs", "saw": "crusty_loaf", "juice": "lemonade", "blend": "fruit_smoothie", "steam": "mussels"},
}
const W := 10            # restaurant interior is 10 x 7 cells
const H := 7             # columns 10 and 11 are the pavement outside, to the right
const DOOR := Vector2i(W, 4)         # the pavement cell just outside the doorway, on the right-hand wall
const SPAWN := Vector2i(W + 1, LOT.position.y)   # the far end of the pavement; guests walk down from beyond it
const QUEUE_GAP := 0.8   # metres between guests standing in line on the pavement
const EXIT := Vector2i(W + 1, H - 1)
const SIGHT_RANGE := 7
const DEMO_BILL := 12   # a bill for the receipt demos
## Disgust sources: [starting rate per second, seconds to double, top rate]. See
## GuestMood.gross_rate. A plate and burning food age from when they appeared; the bin
## and carried rubbish age from when each guest first had them in view.
const GROSS := {
	"plate": [0.002, 20.0, 0.06],
	"burning": [0.01, 5.0, 0.06],
	"bin": [0.004, 25.0, 0.02],
	"sink": [0.003, 20.0, 0.04],
	"overflow": [0.008, 8.0, 0.06],
	"rubbish": [0.05, 1.5, 0.4],
}
const BIN_RANGE := 5          # the bin only bothers guests seated this close
const AREA := Rect2i(0, 0, W, H)   # the first room
## The lot: where floor may be laid. It grows back and to the left only: the
## street runs down the right, and the near edge of the floor stays where it is.
const LOT := Rect2i(-5, -2, W + 5, H + 2)
const ENTRANCE_CELL := Vector2i(W - 1, DOOR.y)   # the floor just inside the front door; never lifted
const DOORWAY := Vector3(W, 0, DOOR.y + 0.5)   # the middle of the doorway, on the floor
const DOOR_REACH := 1.25
const CLOSE_EARLY_FROM := 0.5   # the door card can be flipped to CLOSED from this far into the day
const FLYERS := {"id": "flyers", "tier": 1}   # sold in the shop's Extras, never placed
const CLEANER := {"id": "night_cleaner", "tier": 1}   # the night's clean-up, paid for in Extras (review, item 8)
const DISCOUNT_BELOW := 0.5   # half price can be offered once a guest is this impatient
## Taking orders (DESIGN.md section 9). A seated guest waits to order, then for food.
const ORDER_PATIENCE_SCALE := 0.8   # waiting to order drains patience 1.25x as fast as waiting for food
const ORDER_RELIEF := 0.1           # patience back when the chef comes over and takes the order
const ORDER_HANDS_FREE := true      # the chef needs empty hands to take an order
const BOOTH_DELIGHT := 0.08   # a booth's benches are cosier than chairs
const SOUNDS := {  # name -> volume in dB
	"pickup": -5.0, "putdown": -5.0, "ding": -1.7, "serve": -3.0, "coin": -4.0, "fail": -3.0, "burn": 0.5,
	"day": -4.0, "wash": -6.0, "step": -16.0, "bell": -15.2, "perfect": -4.0, "sizzle": -10.0,
	"roll": -8.0, "lift": -10.0, "rattle": -9.0, "page": -7.0, "thump": -6.0, "rip": -6.0,
	"flutter": -10.0, "rustle": -9.0, "rope": -8.0, "stamp": -4.0,
	"slide": -8.0, "tick": -9.0, "tab": -8.0, "flip": -5.0,
	"zoom": -6.0, "wobble": -6.0, "chop": -7.0, "slice": -9.0, "glug": -8.0,
	# Recorded (docs/AUDIO_GUIDE.md), peak-normalised; levels match what each replaces.
	"grill_drop": 5.7, "patty_flip": 0.2, "plate_food": 2.3, "creaky_door": -13.1, "sit": -4.7,
	"order_ready": 1.2, "order_take": -2.1, "sizzle_raw": -0.3, "sizzle_cooking": -8.2, "sizzle_done": -1.8, "smoke_warn": -3.5,
}
## Loops: the stove's three sizzles and its smoke cross-fade by doneness; "sizzle" is
## the fryer's and the pot's.
const LOOPING: Array[String] = ["sizzle", "sizzle_raw", "sizzle_cooking", "sizzle_done", "smoke_warn"]
const LOOP_FADE := 60.0   # dB a second a loop fades in or out
const LOOP_OFF := -50.0
const MUSIC_DB := -14.0
const MUSIC_FADE := 1.2   # seconds to cross-fade between tracks
## Track per moment. "Intro" is in assets/music too, waiting for a title screen.
const MUSIC := {"day": "Daytime", "night": "Nighttime", "closed": "Closed", "title": "Intro"}
# The camera sits wide to show the whole diorama between days, and moves in on
# the room and the queue while guests are being served.
const CAM_OFFSET := Vector3(14, 15, 14)
const WIDE_SIZE := 12.2
# The sun rises on the right of the screen and sets on the left, whatever the
# room's shape.
const SUN_LEAN := 24.0   # degrees the sun's arc leans toward the camera
# Tilt-shift: only a band across the middle of the picture is sharp, which makes
# the scene read as a small model photographed up close.
const TILT_SHIFT := true
const SUN_ENERGY := Vector2(0.95, 0.9)
const WIDE_FOCUS := Vector3(W / 2.0 + 0.9, 0, H / 2.0 + 0.1)  # framed on the room, with paper showing all round
const CLOSE_SIZE := 10.4
const CLOSE_FOCUS := Vector3(W / 2.0 + 0.3, 0, H / 2.0 - 0.2)

var grid: Grid
var town: Town
var staff: Staff                       # PRD 10: job posts, the CV pile and the hires
var applicants := {}                   # PRD 10.3: person -> peg standing in line outside tonight
var critic: Critic                     # PRD 2: who eats as the critic, and the last review
var critic_guest: Guest                # the critic, while they are here on a critic day
var _critic_seen := {}                 # what the critic saw as their meal arrived: {patience, quality}
var _critic_rated := {}                # their ratings once they leave, printed at the end of the day
var ledger: Ledger
var phase: int = Phase.SERVICE
var stations := {}               # Vector2i -> Station
var kitchen := Kitchen.new()     # the counters and the tools on them, kept in step with `stations` (PRD 8)
var highs := {}   # Vector2i -> Station: the pieces hung in a wall cell's high layer (PRD 8.5)
var wall_facing := {}   # Vector2i -> facing: a wall cell, and which way a piece hung there looks
var _glass := {}   # the wall edges with a window in them: no high piece hangs there
var guests: Array[Guest] = []
var queue: Array[Guest] = []
var seat_taken := {}             # Vector2i -> Guest
var arrivals: Array[Dictionary] = []
var perfect_streak := 0   # perfect trays served in a row today (review, item 6)
var clock := 0.0
var last_day := {}
var catalog: Catalog
var menu := Menu.new()
var tickets: Array[Dictionary] = []   # open orders, oldest first: {id, guest, items}
var _next_ticket := 1
var order_rng := RandomNumberGenerator.new()   # what guests order; apart from the town's own dice
## The piece being placed: {id, tier, price, facing} for a new one from the catalog;
## a piece picked up from the room also has {moving, node, from, from_facing}.
## Chef 1's build hand, for tests and demos; each chef holds their own (Player.hand).
var hand: Dictionary:
	get: return player.hand
	set(v): player.hand = v
var wall_nodes := {}                   # Vector3i edge -> Node3D, player-built partitions only
var rugs := {}                         # Vector2i anchor cell -> Node3D (meta "facing"); see rug_cells
var plan: Floorplan                    # floors, walls, doors and archways
var _room: Node3D                      # the room as drawn from the plan; rebuilt when it changes
var _room_lights: Array[OmniLight3D] = []
var _openings := {}                    # Vector3i edge -> Scenery opening info
var _opening_ok := {}                  # Vector3i edge -> whether it was last drawn usable
var _frame := [WIDE_FOCUS, WIDE_SIZE, CLOSE_FOCUS, CLOSE_SIZE]   # the camera, fitted to the floor
const NIGHT_ZERO_BLOCK := "Write a menu first: a main the kitchen can make (N, or the board by the door)."
## Night zero starts with a stove, a fridge and the starting main's boxes (review, item 7),
## so the first hint is the menu; the first is only seen if the starter kitchen is sold.
const NIGHT_HINTS: Array[String] = ["The first main needs a stove and a fridge (both are a counter upgraded: E on a counter), each with its box.",
	"Write a menu: N, or the board by the door.", "Flip the door card to open."]
var menu_board: MenuBoard               # the chalkboard by the door: tonight's names
const PIECE_NAMES := {"sink": "Sink", "bin": "Bin", "plates": "Plate stack", "cups": "Cup stack", "pass": "Pass counter"}
## What a kitchen cannot open without. Every piece can be sold, these too; while there is
## none of one, the shop sells it at any level and the door card stays shut.
const ESSENTIALS: Array[String] = ["sink", "bin", "plates", "till"]
const LIFT := 0.3   # how high a piece rises while its storage card is open on it
var _demo_hover: Vector3:            # chef 1's held spot, for tests and demos
	get: return player.demo_hover
	set(v): player.demo_hover = v
var inspected: Guest                 # the guest whose card is open, if any
var flyers_out := false          # bought tonight, spent on tomorrow's crowd
var first_night := true          # open on the night before day 1, in the build phase (tests and demos skip it)
static var _title_seen := false  # the title shows once a launch; starting over skips it
static var _resume_data := {}  # a saved game being loaded: read by _ready of the reloaded scene
static var _theme_picked := false  # this run's theme is chosen; starting over asks again
var save_path := SaveGame.PATH   # the saved game, written at the start of each night
var theme_path := "user://regulars_theme.cfg"   # the last theme picked, preselected next time
var allow_quit := true           # tests turn this off to check Quit without leaving
var quit_asked := false
var shopper: Player              # the chef whose player opened the shop; they stand still while it is open
var upgrading := false           # the shop is showing the upgrade tree of what the shopper holds (PRD 8.3)
## Floor treatments (PRD 9.5): Vector2i -> Treatments key, laid at night and re-laid each
## night for its price while switched on and its box is stored; key -> true for those
## switched off (still laid, not paid for or in force).
var treat_laid := {}
var treat_off := {}
const NO_CELL := Vector2i(-99, -99)
var storing_cell := NO_CELL      # a piece's card is open on this cell (E on any piece at night, review item 4)
var card_layer := "base"         # which piece on the cell the card is for: "base", "top" (a tool on a counter) or "high"
var _card_hold := {}             # Player -> seconds E has been held since it opened the card (hold E: move)
const HOLD_MOVE := 0.5           # tunable: seconds of held E that move the piece instead
var shopping: bool:              # the shop is open over the build phase
	get: return shopper != null
var door_open := true            # which side of the door card faces the street
var _door_hang: Node3D
var _range_marks: Node3D:         # chef 1's reach marks, for tests
	get: return player.range_marks
var _range_key: String:
	get: return player.range_key
var _tool_ghost: Node3D:          # chef 1's build-tool ghost, for tests
	get: return player.tool_ghost
var _drag: Dictionary:            # chef 1's mouse drag, for tests and demos
	get: return player.drag
	set(v): player.drag = v
var _door_turn: Node3D
var best_path := "user://regulars_best.json"
var player: Player               # chef 1; `chefs` holds every chef, by player index
const MAX_CHEFS := 2             # trims exist for four; two are shipped and tested (PRD 4)
var ready_chefs: Array[Player] = []   # co-op: who has confirmed the receipt, or used the door card
static var _kept_seats := {}     # devices seated past player one, kept over a restart
var chefs: Array[Player] = []
## Press- or hold-based prep minigames being played (chop, slice, pour), by player
## index: {tool, st, ing, t, hits, presses, fill, last}. Each chef has their own, so
## co-op needs no rework. The chef stands still while one runs.
var preps := {}
var hud: Hud
var controls: Controls           # input per player: devices, touch buttons, presses sent to act()
var cam: Camera3D
var _gross: Array[Dictionary] = []
var floor_dirt: FloorDirt              # dirt on the floor (PRD 9)
var clean_kit: CleanKit                # mops, sponges and robot sweepers (PRD 9.4)
var crew: Crew                         # the hired helpers at work in the room (PRD 10.6)
var demos := GameDemos.new(self)   # the REGULARS_DEMO dispatcher and the kitchen, storage, cleaning and staff scenes
var demo_scenes := GameDemoScenes.new(self)   # building, menu, paying, orders, prep and mood demo scenes
var world := GameWorld.new(self)   # the room: scenery, layout, stations, walls, the wall layer
var audio := GameAudio.new(self)   # sound, music, shake, daylight and popups
var tidy := GameTidy.new(self)   # nightfall: plates back to the rack, food into the bin
var day := GameDay.new(self)   # the day: start, critic booking, door card, end of day
var session := GameSession.new(self)   # night zero, saving, title, themes and the shop
var upgrades := GameUpgrades.new(self)   # upgrade tree buys and the lifted piece's strip
var card := GameCard.new(self)   # the storage card on a piece at night
var placing := GamePlacing.new(self)   # buying, picking up, putting down and selling pieces
var room_edit := GameRoomEdit.new(self)   # floors, walls and doors, drags, ghosts, build actions
var seating := GameSeating.new(self)   # arrivals, the queue, seating, surroundings, gross-out and floor ticks
var decor := GameDecor.new(self)   # decor bonuses and reach marks
var menu_stock := GameMenuStock.new(self)   # tonight's stock, treatments' cost and the menu screen
var desk := GameDesk.new(self)   # the staff desk: posts, CVs, hiring, wages and firing
var serving := GameServing.new(self)   # orders, tickets, trays, serving and deals
var paying := GamePaying.new(self)   # bills, the till line and guests leaving
var cooking := GameCooking.new(self)   # using stations: cooking, carrying, storage, washing
var prep_games := GamePrepGames.new(self)   # the prep minigames and stove loops
var coop := GameCoop.new(self)   # co-op: joining, leaving, readiness and act()
var _sfx := {}
var music_id := ""               # which MUSIC track is playing
var _music: AudioStreamPlayer
var _sun: DirectionalLight3D
var _lens: ColorRect
var _sconces: Array[OmniLight3D] = []
var _night := 0.0   # 0 in service, eases to 1 in the build phase at night
var _env: Environment
var _shot_path := ""
var _shot_time := 0.0


func _ready() -> void:
	var seed_value := int(Time.get_unix_time_from_system())
	grid = Grid.new(W + 2 - LOT.position.x, LOT.size.y, LOT.position)   # columns W and W + 1 are the pavement outside
	town = Town.new(seed_value, Scenery.theme_id)
	critic = Critic.new(seed_value, town.people.size())
	staff = Staff.new(seed_value)
	ledger = Ledger.new()
	catalog = Catalog.new(seed_value)
	world._build_scenery()
	town.make_tastes(Scenery.theme_id)
	order_rng.seed = seed_value
	var saved := _resume_data
	_resume_data = {}
	if saved.is_empty():
		world._build_layout()
		world._start_plan()
		world._hang_fixtures()
	else:
		plan = Floorplan.new(LOT)
		SaveGame.restore_world(self, saved)
	floor_dirt = FloorDirt.new()
	add_child(floor_dirt)
	floor_dirt.setup(self)
	clean_kit = CleanKit.new()
	add_child(clean_kit)
	clean_kit.setup(self)
	crew = Crew.new()
	add_child(crew)
	crew.setup(self)
	audio._load_sounds()
	add_chef()
	controls = Controls.new()
	add_child(controls)
	controls.setup(self)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	controls.mode_changed.connect(func(_m: String, p: int) -> void:   # a player's device: their hints follow it
		if p < chefs.size():
			chefs[p].aim_mouse = false
			chefs[p].drag = {}
		hud.hints_ui.refresh_input())
	if OS.get_environment("REGULARS_INPUT") != "":   # dev switch for screenshots: touch or pad
		controls.set_mode(OS.get_environment("REGULARS_INPUT"))
	_restore_seats()
	_shot_path = OS.get_environment("REGULARS_SHOT")
	day._build_door_card()
	menu_board = MenuBoard.new()
	add_child(menu_board)
	menu_board.position = Vector3(W + 0.455, 0.39, 5.3)   # the slate of the A-frame Scenery._outside stands by the door
	menu_board.refresh([])
	var demo := OS.get_environment("REGULARS_DEMO")
	if demo != "" and not demo in ["title", "night0", "picker"]:
		menu_stock.test_kitchen()   # the demos show a working kitchen
	if not saved.is_empty():
		first_night = false
		_theme_picked = true
		_title_seen = true
		SaveGame.restore_after(self, saved)
		session._open_night()
	elif demo == "title" or (first_night and demo == "" and not _title_seen):
		session.open_title()
	elif demo == "picker" or (first_night and demo == "" and not _theme_picked and not GameSession.theme_forced()):
		session.open_title()   # starting over: the theme card again, the title skipped
		hud.options_ui.title.show_themes()
	elif first_night and (demo == "" or demo == "night0"):   # night0: the empty kitchen and the first hint
		session._open_first_night()
	else:
		day.start_day()
	demos._apply_demo(OS.get_environment("REGULARS_DEMO"))


## A new chef for the next player index, with their marks in the room: the frame
## on the station they would use, the cross where their piece cannot go and the
## reach marks of what they carry. Returns the chef.
func add_chef(at := Vector2i(2, 3)) -> Player:
	var ch := Player.new()
	add_child(ch)
	ch.setup(self, at, chefs.size())
	chefs.append(ch)
	player = chefs[0]
	ch.no_mark = Node3D.new()
	ch.no_mark.visible = false
	add_child(ch.no_mark)
	for turn: float in [PI / 4, -PI / 4]:
		var arm := Build.box(ch.no_mark, Vector3(0, 0.02, 0), Vector3(1.2, 0.05, 0.2), Build.DANGER, 0.6)
		arm.rotation.y = turn
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(Build.DANGER)
		m.emission_enabled = true
		m.emission = Color(Build.DANGER)
		m.emission_energy_multiplier = 0.6
		m.no_depth_test = true          # shows through whatever is already standing there
		m.render_priority = 5
		arm.material_override = m
	ch.range_marks = Node3D.new()
	add_child(ch.range_marks)
	_recolour_cursors()
	return ch


## A warm frame around the top of the station each chef is facing: the usual
## amber with one chef; each chef's trim colour, with a corner tab per player
## number (one tab for chef 1, two for chef 2), when there are more.
func _recolour_cursors() -> void:
	for ch in chefs:
		var key := "%d:%d" % [ch.trim, chefs.size()]
		if ch.cursor and ch.cursor_key == key:
			continue
		var was_visible := ch.cursor != null and ch.cursor.visible
		var at := ch.cursor.position if ch.cursor else Vector3.ZERO
		if ch.cursor:
			ch.cursor.queue_free()
		ch.cursor_key = key
		ch.cursor = Node3D.new()
		ch.cursor.visible = was_visible
		ch.cursor.position = at
		add_child(ch.cursor)
		var col: String = Build.WARN if chefs.size() == 1 else Peg.PLAYER_TRIM[ch.trim % 4]
		for i in 4:
			var bar := Build.box(ch.cursor, Vector3(0, 0, 0.5).rotated(Vector3.UP, i * PI / 2), Vector3(1.06, 0.05, 0.07), col, 0.8)
			bar.rotation.y = i * PI / 2
		if chefs.size() > 1:   # the number, by shape: n little tabs on the near corner
			for k in ch.trim + 1:
				Build.box(ch.cursor, Vector3(0.5 - 0.17 * k, 0.04, 0.5) , Vector3(0.1, 0.09, 0.14), col, 0.8)


## After a restart, the players who were seated are seated again, each with a chef.
## The number of chefs is not saved between runs: only within one launch.
func _restore_seats() -> void:
	var kept := _kept_seats
	_kept_seats = {}
	for p in range(0, MAX_CHEFS):
		for source: String in kept:
			if kept[source] != p:
				continue
			controls.seat(source, p)
			controls.used_any = true
			if p > 0 and chefs.size() == p:
				controls.set_mode(source.get_slice(":", 0), p)
				controls.input_of(p).source = source
				add_chef(Vector2i(3, 3))
	_recolour_cursors()


## The chef a call is for: chef 1 when none is named (tests and demos).
func _me(ch: Player) -> Player:
	return ch if ch != null else player


func step(delta: float) -> void:
	for st: Station in stations.values():
		st.dirty_age = Cleaning.aged(st.dirty_age, delta, st.messy(), phase == Phase.SERVICE)
	seating._tick_floor(delta)
	day.update_door_glow()
	if phase != Phase.SERVICE:
		return
	clock += delta
	while not arrivals.is_empty() and float(arrivals[0].time) <= clock:
		var a: Dictionary = arrivals.pop_front()
		seating.spawn_group(a.get("group", [a.get("idx", 0)]), a.get("critic", false))
	prep_games._tick_stoves(delta)
	prep_games._tick_preps(delta)
	for c in chefs:
		c.tick(delta)
	crew.tick(delta)
	seating._collect_gross()
	seating._seat_waiting_guests()
	for g in guests.duplicate():
		g.tick(delta)
	paying._tick_paying(delta)
	if ledger.is_closed_down():
		day._close_down()
	elif arrivals.is_empty() and guests.is_empty():
		day._end_day()


# ---------------------------------------------------------------- input & frame

func _process(delta: float) -> void:
	BuildFood.menu = menu.items   # loose stacks draw in the order of the item they are heading for
	for p in chefs.size():
		var ch := chefs[p]
		var input := Vector2.ZERO
		if hud.options_ui.options_open():
			pass   # paused anyway; the arrows belong to the options screen
		elif phase == Phase.SERVICE or (phase == Phase.BUILD and shopper != ch and not hud.card_open() \
				and not (hud.typing() and controls.owner_of("keys") == p)):
			input = controls.move(p)
		if preps.has(p) or (hud.bill_open() and hud.bill.chef == ch):
			input = Vector2.ZERO   # the chef stands at the tool while a minigame runs, or writes a bill
		ch.move(input, delta, controls.aiming(p) and (phase == Phase.SERVICE or phase == Phase.BUILD))
		ch.carry(not ch.hand.is_empty())
		if phase == Phase.BUILD:
			if input != Vector2.ZERO:
				ch.aim_mouse = false   # walking hands aim back to the chef
			if ch.aim_mouse:
				ch.mouse_point = room_edit.aim_point(get_viewport().get_mouse_position(), ch)
			_paint_held(p)
			card._tick_card_hold(ch, controls.holding(p, "use"), delta)
		if phase in [Phase.SERVICE, Phase.BUILD] and shopper != ch and not preps.has(p):
			clean_kit.hold_use(ch, controls.holding(p, "use"), delta)   # held E keeps mopping, or scrubbing by hand
		if phase == Phase.SERVICE and not (hud.bill_open() and hud.bill.chef == ch):
			paying._tick_giving(ch, controls.holding(p, "use"), delta)   # held E hands a bill over (PRD 11)
			serving._tick_deal(ch, controls.holding(p, "use"), delta)     # held E gives a deal (review, item 11)
	if phase == Phase.BUILD:
		world._refresh_openings()
	step(delta)
	_update_camera(delta)
	for ch in chefs:
		_update_cursor(ch)
		room_edit._update_ghost(ch)
		decor._update_range(ch)
	audio._update_daylight()
	hud.update_status()
	hud.hints_ui.place_door_ready(cam.unproject_position(DOORWAY + Vector3(0.3, 1.3, 0)))   # just under the card
	if _shot_path != "":
		_shot_time += delta
		if _shot_time > float(OS.get_environment("REGULARS_SHOT_AT")):
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


func _update_camera(delta: float) -> void:
	var close := phase == Phase.SERVICE
	var k := 1.0 - exp(-2.5 * delta)
	cam.size = lerpf(cam.size, _frame[3] if close else _frame[1], k)
	cam.position = cam.position.lerp((_frame[2] if close else _frame[0]) + CAM_OFFSET, k)


func _update_cursor(ch: Player = null) -> void:
	ch = _me(ch)
	hud.day_ui.update_walk_keys(chefs.find(ch), cam.unproject_position(ch.position + Vector3(0, 2.3, 0)))
	if (hud.bill_open() and hud.bill.chef == ch) or ch.give_t > 0.0 or ch.demo_giving >= 0.0:
		# Writing a bill, or handing one over (PRD 11): the slip or the fill bar, no prompt.
		ch.cursor.visible = false
		hud.day_ui.show_prompt(Vector2.ZERO, "", chefs.find(ch))
		return
	var fallen: Node3D = floor_dirt.help_target(ch) if phase == Phase.SERVICE else null
	if fallen != null:   # someone down beside the chef: helping them up comes first (PRD 9.3)
		ch.cursor.visible = false
		hud.day_ui.show_prompt(cam.unproject_position(fallen.position + Vector3(0, 1.9, 0)), "Help up", chefs.find(ch))
		return
	var st: Station = null if clean_kit.floor_first(ch) else world.station_at(ch.target_cell())
	var action := ""
	if st != null:
		action = cooking.prompt_for(st, ch) if phase == Phase.SERVICE else room_edit.night_clean_action(st, ch)
		if action == "" and phase == Phase.BUILD and shopper != ch and ch.hand.is_empty():
			action = clean_kit.station_use(st, true, ch)   # a tool's home at night (PRD 9.4)
	if action == "" and (phase == Phase.SERVICE or (phase == Phase.BUILD and shopper != ch and ch.hand.is_empty())):
		var fl := clean_kit.floor_action(ch) if phase == Phase.SERVICE else room_edit._kit_action(ch)
		if fl != "":   # mopping, or a tool to put down or pick up
			ch.cursor.visible = false
			var fc: Vector2i = clean_kit.floor_cell(ch)
			hud.day_ui.show_prompt(cam.unproject_position(Grid.center(fc) + Vector3(0, 1.3, 0)), fl, chefs.find(ch))
			return
	var messy := _messy_at_mouse(ch)
	if messy != null and messy != st:   # the mouse cannot clean: that is the chef's job
		ch.cursor.visible = false
		hud.day_ui.show_prompt(cam.unproject_position(messy.position + Vector3(0, 1.6, 0)), Cleaning.WALK_OVER, chefs.find(ch))
		return
	ch.cursor.visible = action != ""
	var at := Vector2.ZERO
	if st != null:
		var top := 0.9
		ch.cursor.position = st.position + Vector3(0, top, 0)
		var over := 2.25 if st.type in ["stove", "fryer"] else top + 0.7
		if st.widget != null and st.widget.visible:
			over = 2.6   # above a minigame gauge
		at = cam.unproject_position(st.position + Vector3(0, over, 0))
	if action == "":   # nothing to cook or serve: the build phase and the door card
		action = room_edit.build_action(ch) if phase == Phase.BUILD else day.door_action(ch)
		if action in ["Open up", "Close early"] and ready_chefs.has(ch):
			action = "Not ready"   # co-op: using the card again takes their ready back
		var p := DOORWAY + Vector3(0, 2.9, 0)
		if not ch.hand.is_empty() and room_edit._hover_point(ch) != Vector3.INF:
			p = room_edit._hover_point(ch) + Vector3(0, 2.9 if world.hand_layer(ch) == "high" else 2.0, 0)
		elif action == "Pick up":
			var piece := room_edit._piece_in_front(ch)
			p = piece + Vector3(0, 2.0, 0)
			ch.cursor.visible = not wall_nodes.has(GamePlacing.snap_edge(piece))   # a partition: the bubble only
			if ch.cursor.visible:   # a cell piece: the brackets sit on it
				ch.cursor.position = Grid.center(Grid.to_cell(piece)) + Vector3(0, 0.9, 0)
			action = "%s %s" % [action, card.lift_name(ch)]
		elif action == "Use desk":
			p = desk.desk_in_front(ch).position + Vector3(0, 1.9, 0)
		at = cam.unproject_position(p)
	var ready := true   # a piece held over a spot that refuses it: the bubble is dimmed
	if phase == Phase.BUILD and not ch.hand.is_empty() and not Catalog.is_build_tool(ch.hand.id) and room_edit._hover_point(ch) != Vector3.INF:
		ready = placing.place_refusal(placing.snap(room_edit._hover_point(ch), ch), ch) == ""
	var extras := []
	if phase == Phase.BUILD and not ch.hand.is_empty():
		var held := room_edit.held_prompt(ch, action)
		action = held.text
		extras = held.extras
	hud.day_ui.show_prompt(at, action, chefs.find(ch), ready, extras)


## The messy piece under the mouse at night, when the mouse is aiming with empty hands.
func _messy_at_mouse(ch: Player = null) -> Station:
	ch = _me(ch)
	if phase != Phase.BUILD or shopper == ch or not ch.aim_mouse or not ch.hand.is_empty() or ch.mouse_point == Vector3.INF:
		return null
	var st: Station = stations.get(Grid.to_cell(ch.mouse_point))
	return st if st != null and room_edit.needs_cleaning(st) else null


## One action while the shop is open. Returns whether it was used.
func shop_action(action: String) -> bool:
	if upgrading:
		match action:
			"left", "right", "up", "down": hud.screens_ui.tree_move(action)
			"back" when card.storing(): card.storage_ingredients()
			"shop" when card.storing(): card.storage_ingredients()
			"back", "shop": session.close_shop()
			"use", "confirm": hud.screens_ui.tree_buy()
			"turn" when shopper.hand.get("node") is Station:   # turn it round to see its back
				placing.rotate_hand(shopper)
			_: return false
		return true
	match action:
		"left": hud.shop_ui.shop_move(-1)
		"right": hud.shop_ui.shop_move(1)
		"up": hud.shop_ui.shop_category(-1)
		"down": hud.shop_ui.shop_category(1)
		"shop" when card.storing() and card.storage_tree() != "": card.storage_upgrades()
		"back", "shop": session.close_shop()
		"use", "confirm": hud.shop_ui.shop_buy()
		"search": hud.focus_search()
		_: return false
	return true


## A key typed into the shop's search box, which would otherwise keep the arrow
## keys and Esc for itself. Letters (WASD among them) stay in the box.
func shop_key(key: int) -> bool:
	if key == KEY_ESCAPE:
		hud.stop_typing()
		return true
	if key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		return shop_action(Controls.action_for_key(key))
	return false


## Holding E with a floor tool keeps laying as the chef walks: each new cell in
## front of them is floored as they reach it, so they can pave their way out.
## (Not walls: the chef faces the way they walk, so walls would go across it.)
func _paint_held(p: int) -> void:
	var ch := chefs[p]
	var held := controls.holding(p, "use")
	if not held or shopper == ch or (hud.typing() and controls.owner_of("keys") == p) or ch.hand.is_empty() \
			or GamePlacing.floor_kind(ch.hand.id) == "" or ch.aim_mouse:
		ch.last_paint = Vector3i(-999, -999, -1)
		return
	var spot := placing.snap(room_edit._hover_point(ch), ch)
	if spot != ch.last_paint:
		ch.last_paint = spot
		if placing.can_place(spot, ch):
			placing.place(spot, ch)


## The mouse in the build phase: it aims whatever is in hand. Left click puts a
## piece down or picks one up; with a build tool, a left drag lays a rectangle of
## floor or a line of wall and a right drag takes them away. Right click drops a piece.
## The mouse (and a touch on the room) is the keyboard-and-mouse player's, or the
## screen's: it aims that player's chef only. Null when that player has no chef.
func _mouse_chef(event: InputEvent) -> Player:
	var p := controls.owner_of("touch" if event.device == InputEvent.DEVICE_ID_EMULATION else "keys")
	return chefs[p] if p < chefs.size() else null


func _build_mouse(event: InputEvent, ch: Player) -> void:
	if event is InputEventMouseMotion:
		ch.aim_mouse = true
		return
	# A touch on the room arrives as the mouse: the erase switch is the screen's player's.
	var erase := controls.input_of(controls.owner_of("touch" if event.device == InputEvent.DEVICE_ID_EMULATION else "keys")).erase
	var mb := event as InputEventMouseButton
	if mb == null or (mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT):
		return
	var p := room_edit.aim_point(mb.position, ch)
	ch.aim_mouse = true
	ch.mouse_point = p
	if p == Vector3.INF:
		return
	var tool := not ch.hand.is_empty() and Catalog.is_build_tool(ch.hand.id)
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	if mb.pressed and ch.hand.is_empty() and not right and menu_board.under(cam, mb.position):
		menu_stock.open_menu(ch)   # a click on the board by the door
		return
	if mb.pressed:
		if tool:
			ch.drag = {"from": p, "remove": right or erase}
		elif right:
			placing.cancel_hand(ch)
		elif not ch.hand.is_empty():
			var spot := placing.snap(p, ch)
			if not placing.place(spot, ch):
				room_edit.refuse(spot, ch)
		else:
			ch.strip_pick = 0
			placing.pick_up(p, ch, true)   # as E does: the piece is lifted whole
	elif not ch.drag.is_empty() and (right == bool(ch.drag.remove) or erase):
		room_edit.finish_drag(ch.drag.from, p, ch.drag.remove, ch)


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.BUILD and (event is InputEventMouseButton or event is InputEventMouseMotion):
		if event is InputEventMouseButton and event.pressed:
			hud.stop_typing()   # a click on the room leaves the search box
		var ch := _mouse_chef(event)
		if ch != null and shopper != ch:
			_build_mouse(event, ch)
		return
	if phase == Phase.SERVICE and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			day.inspect(day.guest_at(event.position))
		return
	# Keys, controller buttons and touch buttons arrive as act() from Controls.
