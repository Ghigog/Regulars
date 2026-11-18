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
	"plate": [0.002, 10.0, 0.06],
	"burning": [0.01, 5.0, 0.06],
	"bin": [0.004, 15.0, 0.02],
	"sink": [0.003, 10.0, 0.04],
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
const NIGHT_ZERO_BLOCK := "Buy an ingredient, a tool, and write a menu."
const NIGHT_HINTS: Array[String] = ["Open a counter with E: make it a stove or a fridge, and stock it with boxes.", "Write a menu.", "Flip the door card to open."]
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
var storing_cell := NO_CELL      # the storage card is open on this cell (E on a counter, shelf or fridge)
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
var fav_path := "user://regulars_favourites.cfg"   # starred tree nodes: kept across runs
## Upgrade-tree nodes the player starred: the shop's Favourites tab sells each already
## upgraded, at the whole price of the way there.
var favourites: Array[String] = []
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
	load_favourites()
	var seed_value := int(Time.get_unix_time_from_system())
	grid = Grid.new(W + 2 - LOT.position.x, LOT.size.y, LOT.position)   # columns W and W + 1 are the pavement outside
	town = Town.new(seed_value, Scenery.theme_id)
	critic = Critic.new(seed_value, town.people.size())
	staff = Staff.new(seed_value)
	ledger = Ledger.new()
	catalog = Catalog.new(seed_value)
	_build_scenery()
	town.make_tastes(Scenery.theme_id)
	order_rng.seed = seed_value
	var saved := _resume_data
	_resume_data = {}
	if saved.is_empty():
		_build_layout()
		_start_plan()
		_hang_fixtures()
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
	_load_sounds()
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
		hud.refresh_input())
	if OS.get_environment("REGULARS_INPUT") != "":   # dev switch for screenshots: touch or pad
		controls.set_mode(OS.get_environment("REGULARS_INPUT"))
	_restore_seats()
	_shot_path = OS.get_environment("REGULARS_SHOT")
	_build_door_card()
	menu_board = MenuBoard.new()
	add_child(menu_board)
	menu_board.position = Vector3(W + 0.455, 0.39, 5.3)   # the slate of the A-frame Scenery._outside stands by the door
	menu_board.refresh([])
	var demo := OS.get_environment("REGULARS_DEMO")
	if demo != "" and not demo in ["title", "night0", "picker"]:
		test_kitchen()   # the demos show a working kitchen
	if not saved.is_empty():
		first_night = false
		_theme_picked = true
		_title_seen = true
		SaveGame.restore_after(self, saved)
		_open_night()
	elif demo == "title" or (first_night and demo == "" and not _title_seen):
		open_title()
	elif demo == "picker" or (first_night and demo == "" and not _theme_picked and not theme_forced()):
		open_title()   # starting over: the theme card again, the title skipped
		hud.title.show_themes()
	elif first_night and (demo == "" or demo == "night0"):   # night0: the empty kitchen and the first hint
		_open_first_night()
	else:
		start_day()
	_apply_demo(OS.get_environment("REGULARS_DEMO"))


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


## The slip demo: the first guest inside goes down on a level 4 cell, the friend beside them.
func _demo_slip() -> void:
	var party: Array = guests.filter(func(o: Guest) -> bool: return o.state == "to_seat")
	if party.is_empty():
		return
	var c := Vector2i(7, 4)   # open floor between the tables, in plain view
	for d in [Vector2i.ZERO, Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		if not grid.is_blocked(c + d) and plan.floors.has(c + d):
			c += d
			break
	for i in 4:
		floor_dirt.mess.add_dirt(c)
	var g: Guest = party[0]
	g.position = Grid.center(c) + Vector3(-0.3, 0, 0.3)
	g.cell = c
	g._body.rotation.y = -PI / 4   # so they fall across the screen, the puddle in front of them
	if party.size() > 1:   # the friend a step behind, who saw it
		var o: Guest = party[1]
		o.position = Grid.center(c) + Vector3(-0.6, 0, -1.0)   # behind, on the side they help from
		o.cell = Grid.to_cell(o.position)
	floor_dirt.slip(g, c)


## The cleaning demos (PRD 9.4). "mop": in service, a mop bucket and a sponge on its hook,
## the chef mid-clean along a trail of dirt with a mop gone dirty (shoot at 3). "robot":
## the robot sweeper drifting from its dock to a puddle (shoot at about 4).
## "mop_night": at night a table moved off the dirt under it, the chef mopping it (shoot at 3).
func _demo_mop(demo: String) -> void:
	arrivals.assign([{"time": 99999.0, "idx": 0}])   # keeps the day open, nobody comes
	floor_dirt.drops = false
	floor_dirt.sync_room()
	var m := floor_dirt.mess
	var at := Vector2i(1, 6)
	for c: Vector2i in [Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(1, 5), Vector2i(3, 5)]:
		if not stations.has(c) and grid.can_place_block(c, [], LOT, DOOR, _reach(), _touch()):
			at = c   # out of everyone's way
			break
	var bucket := add_station("mop_bucket", at)
	clean_kit.on_built(bucket, "mop_bucket")
	for c: Vector2i in kitchen.wall_cells:
		if not stations.has(c) and kitchen.can_hang(c, "hook"):
			clean_kit.on_built(add_high("hook", c), "sponge")
			break
	match demo:
		"mop":
			for d: Array in [[Vector2i(5, 3), 1], [Vector2i(5, 4), 3], [Vector2i(6, 4), 2], [Vector2i(7, 4), 4]]:
				for i in d[1]:
					m.add_dirt(d[0])
			player.position = Grid.center(Vector2i(5, 3)) + Vector3(0.1, 0, -0.1)
			player.look(Vector2i(0, 1))
			clean_kit.keep(bucket, "", 0)   # the mop is out, in the chef's hands
			CleanKit.hold(player, "mop", CleanTools.dirty_after("mop"))
			clean_kit.put_down("sponge", 1, Vector2i(6, 3))   # left lying about, in the way
		"robot":
			add_station("robot_dock", Vector2i(5, 6))
			for i in 3:
				m.add_dirt(Vector2i(7, 4))
			player.position = Grid.center(Vector2i(2, 4))
		"mop_night":
			ledger.record_sale(DEMO_BILL, 5)
			for i in 3:
				m.add_dirt(Vector2i(6, 5))   # under the table by the door: out of reach in service
			m.add_dirt(Vector2i(6, 4))
			arrivals.clear()
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				open_build()
				pick_up(Grid.center(Vector2i(6, 5)))
				var spots: Array = plan.floors.keys().filter(func(c: Vector2i) -> bool: return c.x >= 5 and c != Vector2i(6, 5))
				spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					return (a - Vector2i(6, 5)).length_squared() > (b - Vector2i(6, 5)).length_squared())   # well away
				for c: Vector2i in spots:
					if place(Vector3i(c.x, c.y, 0)):
						break   # moved aside: the dirt under it can be reached
				player.position = Grid.center(Vector2i(6, 4)) + Vector3(0, 0, -0.2)
				player.look(Vector2i(0, 1))
				clean_kit.keep(bucket, "", 0)
				CleanKit.hold(player, "mop", 1)
				hud.show_build())


## PRD 9.6: the mop bucket's tree in a row along the front, each with its own mop (plain,
## sponge-head, flat, wringer, the scrubber parked by its pail, a little dirty where it
## shows), the robot's dock; the small tools on hooks; a hood beside an extractor over the
## stoves; the chef pushing a scrubber through a trail of dirt (shoot at 3).
func _demo_mop_line() -> void:
	arrivals.assign([{"time": 99999.0, "idx": 0}])   # keeps the day open, nobody comes
	floor_dirt.drops = false
	floor_dirt.sync_room()
	var line: Array = [["mop_bucket", 2], ["sponge_mop", 3], ["flat_mop", 2], ["wringer_bucket", 0], ["scrubber", 0]]
	var x := 4
	for b: Array in line:
		var c := Vector2i(x, 6)
		x += 1
		if stations.has(c) or not plan.floors.has(c):
			continue
		var st := add_station(b[0], c)
		clean_kit.on_built(st, b[0])
		clean_kit.keep(st, st.kit_tool, b[1])
	if not stations.has(Vector2i(x, 6)) and plan.floors.has(Vector2i(x, 6)):
		add_station("robot_dock", Vector2i(x, 6))
	var hooks := 0
	for c: Vector2i in kitchen.wall_cells:
		if hooks >= 4 or stations.has(c) or highs.has(c) or not kitchen.can_hang(c, "hook"):
			continue
		clean_kit.keep(add_high("hook", c), ["sponge", "scourer", "grease_scraper", "spill_kit"][hooks], 0)
		hooks += 1
	var hood := Vector2i(0, 4)
	if highs.has(hood) and kitchen.hood_at(hood) == "hood":   # the second hood, up its tree
		kitchen.remove(hood, "high")
		(highs[hood] as Station).queue_free()
		highs.erase(hood)
		add_high("extractor", hood)
	for d: Array in [[Vector2i(7, 4), 2], [Vector2i(7, 3), 3], [Vector2i(7, 2), 4]]:
		for i in d[1]:
			floor_dirt.mess.add_dirt(d[0])
	player.position = Grid.center(Vector2i(7, 5))
	player.look(Vector2i(1, 0))
	CleanKit.hold(player, "scrubber", 0)
	floor_dirt.redraw()


## Dev aid for screenshots: REGULARS_DEMO=cook or =summary jumps to that moment.
func _apply_demo(demo: String) -> void:
	if demo == "cook":   # a patty on the grill, the chef with a plate for it
		find_station("stove").set_item("raw:" + fixed_main().grill)
		find_station("stove").cook = -8.2
		player.position = Grid.center(Vector2i(1, 3))
		player.look(Vector2i(-1, 0))
		player.take_dish(Dish.make(Dish.PLATE))
		for a in arrivals:
			a.time = 1.0
	elif demo in ["helpers", "helpers_break", "helpers_slip"]:   # PRD 10.6/10.8: staff at work; see Crew.demo
		crew.demo(demo)
	elif demo.begins_with("pay_"):   # PRD 11: paying the bill; see _demo_pay
		_demo_pay(demo)
	elif demo == "staff_only":   # PRD 10.7: a busy day run by helpers alone; see Crew.staff_only
		ledger.day = 8
		flyers_out = true
		crew.staff_only()
	elif demo == "dirt":  # every level of floor dirt, footprints, guests slowed tracking it in; shoot at about 7
		floor_dirt.sync_room()
		var m := floor_dirt.mess
		for lvl in range(1, 5):   # a few drops, a puddle, a big puddle, the whole cell, along the front
			for i in lvl:
				m.add_dirt(Vector2i(4 + lvl, 6))
		for i in 4:
			m.add_dirt(ENTRANCE_CELL)   # the whole cell inside the door: guests track it in, slowed
		for i in 2:
			m.add_dirt(Vector2i(2, 3))   # grease by the stove
		floor_dirt.prints[Vector2i(2, 3)] = Vector2i(0, 1)
		arrivals.resize(mini(arrivals.size(), 2))
		for a in arrivals:
			a.time = 0.5
	elif demo in ["mop", "robot", "mop_night"]:  # PRD 9.4: see _demo_mop
		_demo_mop(demo)
	elif demo == "mop_line":  # PRD 9.6: see _demo_mop_line
		_demo_mop_line()
	elif demo in ["treat", "treat_day", "tree_box", "tree_bucket", "tree_sponge"]:  # PRD 9.5: see _demo_treat
		ledger.record_sale(DEMO_BILL, 5)
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_treat.bind(demo))
	elif demo == "slip":  # a guest down on a level 4 cell, dizzy, a friend who saw it helping them up; shoot at about 7.5
		arrivals.clear()
		arrivals.append({"time": 0.2, "group": [0, 1]})
		get_tree().create_timer(5.5).timeout.connect(_demo_slip)
	elif demo == "messy":  # a sink piled with washing-up and an overflowing bin; shoot at about 10
		var sink := find_station("sink")
		sink.dirty = 4
		sink.refresh()
		find_station("plates").count = 0
		find_station("plates").refresh()
		var bin := find_station("bin")
		bin.count = Station.BIN_HOLDS
		bin.refresh()
		player.position = Grid.center(Vector2i(2, 4))
		player.set_held("rubbish_bag")
		for a in arrivals:
			a.time = 0.5
	elif demo == "lineup":  # every townsperson and every face, close up
		arrivals.clear()
		phase = Phase.SUMMARY
		cam.size = 6.5
		cam.position += Vector3(3.4, 0, -1.5)
		var names: Array = Peg.LOOKS.keys()
		for i in names.size():
			var p := Peg.guest(names[i])
			p.position = Vector3(10.6 + (i / 7) * 1.1 - (i % 7) * 0.25, 0, 7.4 - (i % 7) * 1.0 - (i / 7) * 0.5)
			p.rotation.y = PI / 4
			p.pose = ["idle", "carry", "tap", "wave"][i % 4]
			add_child(p)
		for i in Peg.FACES.size():
			var p := Peg.guest(names[i + 3])
			p.set_face(Peg.FACES[i])
			p.position = Vector3(13.2 - i * 0.3, 0, 7.2 - i * 0.95)
			p.rotation.y = PI / 4
			add_child(p)
		for i in 4:
			var c := Peg.chef(i)
			c.position = Vector3(15.0 - i * 0.6, 0, 3.4 - i)
			c.rotation.y = PI / 4 + i * PI / 2
			add_child(c)
	elif demo == "fx":  # fires every effect in turn; shoot at about 6.5 and 8.4
		for a in arrivals:
			a.time = 0.2
		while arrivals.size() < 8:
			arrivals.append({"time": 0.2, "idx": arrivals.size()})
		get_tree().create_timer(6.0).timeout.connect(_demo_fx)
	elif demo == "order":  # a table waiting to order, then the chef taking it; shoot at about 9 and 10.5
		for a in arrivals:
			a.time = 0.2
		get_tree().create_timer(8.0).timeout.connect(_demo_order.bind(false))
		get_tree().create_timer(9.5).timeout.connect(_demo_order.bind(true))
	elif demo == "ticket" or demo == "tray":  # two tickets on the rail and a bun on a patty waiting for a plate; or a whole order carried on a tray. Shoot at 10
		for a in arrivals:
			a.time = 0.2
		get_tree().create_timer(8.0).timeout.connect(_demo_ticket.bind(demo == "tray"))
	elif demo.begins_with("prep_"):  # a minigame mid-play at the chef's tool (frozen there); shoot at 2
		_demo_prep(demo.trim_prefix("prep_"))
	elif demo == "kind":  # an impatient guest and the half-price prompt; shoot at about 9 and 10.5
		for a in arrivals:
			a.time = 0.2
		get_tree().create_timer(8.0).timeout.connect(_demo_kind.bind(false))
		get_tree().create_timer(9.5).timeout.connect(_demo_kind.bind(true))
	elif demo == "comp":  # a fed-up guest who expects deals, then the free meal; shoot at about 9 and 10.5
		for a in arrivals:
			a.time = 0.2
		get_tree().create_timer(8.0).timeout.connect(_demo_comp.bind(false))
		get_tree().create_timer(9.5).timeout.connect(_demo_comp.bind(true))
	elif demo == "mood":  # a content and a fed-up guest, both served at 8 with the content one's card open;
		# shoot at 9 (card), 12.4 (the fed-up guest pays less) and 15.7 (the content one pays more)
		for a in arrivals:
			a.time = 0.2
		get_tree().create_timer(8.0).timeout.connect(_demo_mood)
	elif demo == "inspect":  # a seated guest with a few thoughts and their card open; shoot at 10
		for a in arrivals:
			a.time = 0.2
		get_tree().create_timer(9.0).timeout.connect(func() -> void:
			for g in guests:
				if g.seated_waiting():
					g.mood.patience = 0.4
					g.mood.disgust = 0.25
					g.mood.think("Nobody has cleared that table")
					inspect(g)
					return)
	elif demo == "tolerance":  # a seated guest who hates to wait and doesn't mind a mess, card open; shoot at 10
		for a in arrivals:
			a.time = 0.2
		get_tree().create_timer(9.0).timeout.connect(func() -> void:
			for g in guests:
				if g.seated_waiting():
					g.mood.tolerance = {"food": 3, "service": 1, "clean": 5}
					g.mood.patience = 1.0
					g.mood.wait(0.5 * Guest.QUEUE_PATIENCE, Guest.QUEUE_PATIENCE)   # a long wait, felt hard
					g.mood.see_gross(0.05, 0.5, "Nobody has cleared that table")   # shrugged off
					inspect(g)
					return)
	elif demo == "walkon":  # a pair who find nothing they like turn away at the door; shoot at about 7
		for i in [0, 1]:
			(town.people[i].dislikes as Array).append("patty")
		arrivals.clear()
		arrivals.append({"time": 0.2, "group": [0, 1]})
		arrivals.append({"time": 2.5, "idx": 2})
		(town.people[2].dislikes as Array).erase("patty")
		(town.people[2].dislikes as Array).erase("bun")
	elif demo == "orders_card":  # a seated guest's card with their orders so far, one item renamed; shoot at 10
		for a in arrivals:
			a.time = 0.2
		get_tree().create_timer(9.0).timeout.connect(func() -> void:
			for g in guests:
				if g.seated_waiting():
					var burger: int = menu.items[0].id
					var fries := menu.add("side", ["potato"], "Fries")
					for k in 3:
						town.record_order(g.idx, burger)
					town.record_order(g.idx, int(fries.id))
					town.record_order(g.idx, int(fries.id))
					menu.rename(burger, "Stupid Burger")   # the counts follow the rename
					menu.remove(int(fries.id))             # and a deleted item keeps its last name
					g.mood.think(Menu.LIKED_THOUGHT)
					inspect(g)
					return)
	elif demo == "pause":  # the pause menu over the room
		hud.toggle_pause()
		get_tree().paused = false   # so the screenshot timer still runs
	elif demo == "options" or demo == "options_gfx":  # the options screen, on either tab
		hud._options_tab = "graphics" if demo == "options_gfx" else "audio"
		hud.toggle_options()
		hud.options_action("down")   # the highlight on the first slider (keys and pad)
		get_tree().paused = false   # so the screenshot timer still runs
	elif demo in ["menu", "menu_name", "restock"]:  # the menu screen; naming an item; the restock note open
		ledger.record_sale(DEMO_BILL, 5)
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_menu.bind(demo))
	elif demo == "closed":
		best_path = "user://regulars_best_demo.json"
		for i in Ledger.MAX_STRIKES:
			ledger.record_walkout()
	elif demo in ["critic", "critic_bad", "critic_known", "critic_town"]:
		_demo_critic(demo)
	elif demo == "summary" or demo == "town":
		ledger.record_sale(DEMO_BILL, 5)
		ledger.record_sale(DEMO_BILL, 3)
		ledger.record_unpaid_bill()   # PRD 11: the LEFT UNPAID line and its open-purse stamp
		ledger.record_found_nothing(3)
		arrivals.clear()
		if demo == "town":  # a spread of opinions, then the town book over the receipt
			for i in town.people.size():
				town.record_visit(i, [0.9, 0.9, 0.3, -0.5, 0.6][i % 5])
				if i == 0 or i == 5:
					town.record_visit(i, 0.9)
					town.record_visit(i, 0.9)
				if i == 3:
					town.record_walkout(i, 1)
				if i % 2 == 0:
					town.record_visit(i, [0.9, -0.5, 0.9][i % 3])
			get_tree().create_timer(1.5).timeout.connect(hud.show_town)
	elif demo.begins_with("coop"):  # PRD 4: coop (service), coop_build (two ghosts at night), coop_ready (the receipt, one ready)
		var two := chefs[join("pad:1")]
		hud.coop_hint_time = 9999.0
		if demo == "coop":   # two chefs, two bubbles, two hint lines; shoot at about 8
			find_station("stove").set_item("raw:" + fixed_main().grill)
			find_station("stove").cook = -8.2
			player.position = Grid.center(Vector2i(1, 2))
			player.look(Vector2i(-1, 0))   # at the patty fridge, hands free
			two.position = Grid.center(Vector2i(3, 3))
			two.look(Vector2i(1, 0))
			two.set_held(Tray.kind("raw", fixed_main().bread))
			for a in arrivals:
				a.time = 1.0
		elif demo == "coop_build":   # shoot at about 3
			ledger.money = 300
			ledger.xp = 250
			arrivals.clear()
			get_tree().create_timer(1.0).timeout.connect(_demo_coop_build.bind(two))
		elif demo == "coop_door":   # night: chef 1 has used the door card, chef 2 has not; shoot at about 3
			ledger.money = 300
			arrivals.clear()
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				open_build()
				player.position = DOORWAY + Vector3(-0.6, 0, -0.3)
				player.look(Vector2i(1, 0))
				two.position = DOORWAY + Vector3(-1.2, 0, 0.6)
				two.look(Vector2i(1, 0))
				use_door(player))
		else:   # coop_ready: the receipt, player one ready; shoot at about 4
			ledger.record_sale(DEMO_BILL, 5)
			ledger.record_sale(DEMO_BILL, 3)
			arrivals.clear()
			get_tree().create_timer(1.5).timeout.connect(confirm_receipt.bind(0))
	elif demo in ["tree", "tree_stove", "tree_counter", "tree_fern", "upgraded", "tree_cut", "jobs"]:   # PRD 8.3 upgrade trees; shoot at 3
		ledger.record_sale(DEMO_BILL, 5)
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_tree.bind(demo))
	elif demo == "desk_wages":   # PRD 10.4: the receipt with a STAFF line, one wage unpaid; shoot at 3
		ledger.record_sale(DEMO_BILL, 5)
		arrivals.clear()
		_demo_hires()
		ledger.money = 40
		pay_staff()
	elif demo.begins_with("desk_"):   # PRD 10.3/10.4: desk_line, desk_post, desk_cvs, desk_haggle, desk_staff, desk_raise, desk_restock, desk_fire; shoot at 3
		ledger.record_sale(DEMO_BILL, 5)
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_desk.bind(demo))
	elif demo in ["pantry", "storage", "storage_card", "storage_card_up", "storage_fridge", "boxes_open"]:   # PRD 8.4: boxes in counters and a fridge; a counter's storage card; shoot at 3
		ledger.record_sale(DEMO_BILL, 5)
		ledger.money = 300
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_storage.bind(demo))
	elif demo in ["wall", "wall_build"]:   # PRD 8.5: hoods, cabinets, a closet, a tall fridge; a cabinet's ghost on the wall; shoot at 3
		ledger.record_sale(DEMO_BILL, 5)
		ledger.money = 300
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_wall.bind(demo))
	elif demo == "counters":   # PRD 8: a double counter, a board on a double counter, a stove on the pass; shoot at 3
		ledger.record_sale(DEMO_BILL, 5)
		ledger.money = 300
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_counters)
	elif demo.begins_with("build") or demo == "door":  # build (the shop), build_find (a search), build_no (refused spot), build_move, door
		ledger.record_sale(DEMO_BILL, 5)
		ledger.money = 300
		ledger.xp = 250
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_build.bind(demo))
	elif demo == "night_clean":  # a messy day carried into the night, the chef with a plate; shoot at 4 and 6
		ledger.record_sale(DEMO_BILL, 5)
		arrivals.clear()
		for c: Vector2i in [Vector2i(6, 5), Vector2i(8, 3)]:
			stations[c].dirty = 2
			stations[c].refresh()
		var sink := find_station("sink")
		sink.dirty = Station.SINK_PILED
		sink.refresh()
		var bin := find_station("bin")
		bin.count = Station.BIN_HOLDS
		bin.refresh()
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			open_build()
			player.position = Grid.center(Vector2i(6, 4))
			player.look(Vector2i(0, 1))   # at the table by the door: "Clear table"
			hud.show_build())
		get_tree().create_timer(5.0).timeout.connect(func() -> void:
			build_interact()              # a plate in hand, carried to the sink
			player.position = Grid.center(Vector2i(3, 3))
			player.look(Vector2i(0, -1)))
	elif demo == "newday":  # the receipt, then building, then the next day turning over
		ledger.record_sale(DEMO_BILL, 5)
		arrivals.clear()
		get_tree().create_timer(3.0).timeout.connect(open_build)
		get_tree().create_timer(5.0).timeout.connect(func() -> void:
			player.position = Grid.center(Vector2i(W - 1, DOOR.y))
			use_door())
	elif demo == "close":  # the door card flipped to CLOSED late in the day; shoot at about 3
		for a in arrivals:
			a.time = 400.0
		spawn_guest(0)
		clock = day_length() * 0.6
		player.position = Grid.center(Vector2i(W - 1, DOOR.y))
		player.look(Vector2i(1, 0))
		get_tree().create_timer(2.0).timeout.connect(use_door)
	elif demo == "crowd":  # a rush: every table taken and a dozen in line at the door; shoot at about 12
		arrivals.clear()
		var n := mini(town.people.size(), 20)
		var at := 0.3
		var i := 0
		while i < n:
			var size: int = [2, 1, 3, 1, 2, 4][arrivals.size() % 6]
			arrivals.append({"time": at, "group": range(i, mini(i + size, n))})
			i += size
			at += 0.9
	elif demo == "walkout":  # one walkout stamped on the card
		for a in arrivals:
			a.time = 30.0
		get_tree().create_timer(2.0).timeout.connect(ledger.record_walkout)
	elif demo == "flyers":
		ledger.record_sale(DEMO_BILL, 5)
		arrivals.clear()
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			open_build()
			open_shop()
			hud._set_category("Extras")
			buy(FLYERS))


## critic: the receipt of day 5 with a good review that contradicts the town;
## critic_bad: a walkout's review; critic_known: the named critic seated, card open
## (shoot at 10); critic_town: the town book with the critic marked.
func _demo_critic(demo: String) -> void:
	ledger.day = 5
	ledger.record_sale(DEMO_BILL, 5)
	ledger.record_sale(DEMO_BILL, 3)
	for i in town.people.size():   # the town thinks the place is dirty and slow
		if i % 3 == 0:
			town.record_disgust(i, 2)
		town.record_visit(i, 0.5, {"speed": -0.1, "clean": 0.0, "quality": 0.25, "variety": 0.0})
	if demo in ["critic", "critic_bad"]:
		arrivals.clear()
		var walked := demo == "critic_bad"
		_critic_rated = {"walked": walked, "ratings": {"speed": 5, "clean": 5, "quality": 4, "variety": 3}
			if not walked else {"speed": 1, "clean": 2, "quality": 1, "variety": 2}}
		if walked:
			ledger.record_walkout()
		return
	critic.publish({"speed": 4, "clean": 5, "quality": 4, "variety": 3}, false, town, 5)
	ledger.end_day()
	if demo == "critic_town":
		arrivals.clear()
		get_tree().create_timer(1.5).timeout.connect(hud.show_town)
		return
	arrivals.assign([{"time": 0.2, "group": [critic.critic_idx]}])
	get_tree().create_timer(9.0).timeout.connect(func() -> void:
		for g in guests:
			if is_critic(g):
				g.mood.think(Critic.thought("gross"))
				inspect(g)
				return)


## Two chefs at night, each with a piece: chef 1's fits, chef 2's (over a table) does not.
func _demo_coop_build(two: Player) -> void:
	open_build()
	player.position = Grid.center(Vector2i(5, 3))
	player.look(Vector2i(1, 0))
	pick_catalog(fern(), 1, player)
	player.demo_hover = Vector3(6.5, 0, 3.5)
	two.position = Grid.center(Vector2i(7, 2))
	two.look(Vector2i(-1, 0))
	pick_catalog("counter", 1, two)
	two.demo_hover = Vector3(6.5, 0, 1.5)


## Tools on counters (PRD 8.2), placed through the build flow at night.
func _demo_counters() -> void:
	open_build()
	for step: Array in [["counter", 2, 5], ["counter", 2, 5], ["board", 2, 5],
			["counter", 3, 4], ["counter", 3, 4]]:
		pick_catalog(step[0])
		place(Vector3i(step[1], step[2], 0))
		cancel_hand()
	open_storage(Vector2i(4, 3))   # a length of the pass made a stove on its card
	storage_upgrades()
	buy_upgrade("stove")
	find_station("board").set_item(Tray.kind("prep", "lemon" if Scenery.seaside() else "tomato"))   # a tool's surface still holds a thing
	player.position = Grid.center(Vector2i(2, 4))
	player.look(Vector2i(1, 0))


## Storage (PRD 8.4): "storage" a double counter with two boxes and a board on it, two
## under-counter fridges with the chilled kinds, ready-made in a
## pass counter, and a box held over a counter (its tags show what each cell holds);
## "storage_card" (or "pantry") a plain counter's storage card on Ingredients, the chilled
## kinds dimmed "Needs a fridge"; "storage_card_up" the same card on Upgrades;
## "storage_fridge" the counter upgraded to a fridge while lifted, back on Ingredients.
func _demo_storage(demo: String) -> void:
	open_build()
	if demo in ["pantry", "storage_card", "storage_card_up", "storage_fridge"]:
		var plain := NO_CELL
		var side := Vector2i(0, 1) if demo == "storage_fridge" else Vector2i(1, 0)   # the fridge's door in view
		for c: Vector2i in stations:
			if stations[c].type == "counter" and stations[c].base == "counter" and not stations[c].has_node("till") \
					and not stations.has(c + side) and plain == NO_CELL:
				plain = c
		player.position = Grid.center(plain + side)
		player.look(-side)
		lift()   # E: the counter rises with its card open
		if demo == "storage_card_up":
			storage_upgrades()
		elif demo == "storage_fridge":   # upgraded to a fridge while lifted, back on its card
			storage_upgrades()
			buy_upgrade("fridge")
			storage_ingredients()
			rotate_hand()   # turned on its card, the door toward the camera
		else:
			get_tree().create_timer(0.3).timeout.connect(hud.shop_move.bind(1))
		return
	var sea := Scenery.seaside()
	for step: Array in [["counter", 2, 5], ["counter", 2, 5]]:
		pick_catalog(step[0])
		place(Vector3i(step[1], step[2], 0))
		cancel_hand()
	stock_box("roll" if sea else "bun", Vector2i(2, 5))
	stock_box("courgette" if sea else "lettuce", Vector2i(2, 5))
	add_station("board", Vector2i(2, 5))
	stock_box("calamari" if sea else "cheese", Vector2i(1, 6))   # a second under-counter fridge
	stock_box("pepper" if sea else "tomato", Vector2i(4, 5), true)
	if demo == "boxes_open":   # the crates on the counter, and a fridge door caught open at 3
		get_tree().create_timer(1.8).timeout.connect(func() -> void: station_at(Vector2i(1, 6)).used())
		get_tree().create_timer(1.8).timeout.connect(func() -> void: station_at(Vector2i(0, 5)).used())
	else:
		pick_catalog("box_lemon" if sea else "box_onion")
	player.position = Grid.center(Vector2i(3, 3))
	player.look(Vector2i(1, 0))
	_demo_hover = Vector3(4.5, 0, 3.5)


## The wall layer (PRD 8.5) at night. "wall": the start's hoods over the stoves and
## cabinets by the back door (one holding a box), a low and a high shelf as one closet,
## and the grill fridge turned into a tall fridge. "wall_build": a wall cabinet in hand,
## its ghost hung over the plate stack with the high band lit behind it.
func _demo_wall(demo: String) -> void:
	open_build()
	var sea := Scenery.seaside()
	var corner := Vector2i(0, 2)
	var fridge: Station = stations[corner]
	fridge.set_base("tall_fridge")
	kitchen.set_cell(corner, "tall_fridge")
	stock_box("cheese" if not sea else "calamari", corner)
	_show_boxes(corner)
	add_station("shelf", Vector2i(1, 2))
	add_high("shelf", Vector2i(1, 2))
	stock_box("onion" if not sea else "lemon", Vector2i(1, 2))
	stock_box("lettuce" if not sea else "courgette", Vector2i(1, 2))
	_store_box(Vector2i(0, 5), Pantry.box_id("tomato" if not sea else "pepper"))   # into the cabinet over the bin
	player.position = Grid.center(Vector2i(2, 4))
	player.look(Vector2i(-1, 0))
	if demo == "wall_build":
		pick_catalog("cabinet")
		_demo_hover = Vector3(2.5, 0, 2.5)
	hud.show_build()


## The upgrade trees (PRD 8.3): a piece picked up at night and the shop opened.
## "tree" a board in hand; "tree_stove" a stove, the choice scrolled down to the fryer;
## "tree_counter" a counter (its fridge line); "tree_fern" a fern's short tree;
## "upgraded" a row of upgraded pieces standing in the kitchen.
func _demo_tree(demo: String) -> void:
	open_build()
	ledger.money = 300
	ledger.xp = 500
	var c := Vector2i(2, 5)
	if demo == "jobs":   # PRD 8.6: the new tools in a row, and the new food on the counters before them
		_demo_jobs()
		player.position = Grid.center(Vector2i(4, 6))   # off the row, so no prompt hides a tool
		player.look(Vector2i(0, 1))
		_frame = [Vector3(5.0, 0, 3.2), 6.8, Vector3(5.0, 0, 3.2), 6.8]   # close up, held
		return
	if demo == "upgraded":
		var row := [["counter", "long_counter", Vector2i(1, 5)], ["butcher_block", "counter", Vector2i(2, 5)],
			["auto_slicer", "counter", Vector2i(3, 5)], ["char_grill", "fridge", Vector2i(2, 4)],
			["two_hob_range", "counter", Vector2i(3, 4)], ["twin_fryer", "counter", Vector2i(4, 5)]]
		for spot: Array in row:
			add_station("counter", spot[2], 1, 0, spot[1])
			if spot[0] != "counter":
				add_station(spot[0], spot[2])
		player.position = Grid.center(Vector2i(2, 6))
		player.look(Vector2i(0, -1))
		return
	var piece: String = {"tree": "board", "tree_cut": "board", "tree_stove": "stove", "tree_counter": "", "tree_fern": fern()}[demo]
	if demo == "tree_fern":
		add_station(piece, c)
	else:
		add_station("counter", c)
		if piece != "":
			add_station(piece, c)
	player.position = Grid.center(c + Vector2i(0, 1))
	player.look(Vector2i(0, -1))
	pick_up(Grid.center(c))
	open_shop()
	if demo == "tree_stove":
		for i in 3:
			get_tree().create_timer(0.4 + 0.3 * i).timeout.connect(hud.tree_move.bind("down"))
	if demo == "tree_cut":   # PRD 8.6: the whole cutting tree, scrolled down to the bread knife's line
		for i in 2:
			get_tree().create_timer(0.4 + 0.2 * i).timeout.connect(hud.tree_move.bind("down"))


## The floor treatment and cleaning tree demos (PRD 9.5). "treat": at night, a strip of
## each treatment's sheen, a little dirt on some, the boxes on a counter by the wall with
## their chemical tags, the small tools on their hooks, the chef laying primer (shoot at 3).
## "treat_day": the same laid for service, the sheens in force (shoot at 3). "tree_box",
## "tree_bucket", "tree_sponge": the tree of a cleaner's box, a mop bucket, a sponge's hook.
func _demo_treat(demo: String) -> void:
	open_build()
	ledger.money = 600
	ledger.xp = 500
	floor_dirt.drops = false
	var shelf := Vector2i(2, 5)
	add_station("counter", shelf, 1, 0, "double_counter")
	var keys: Array = Treatments.ITEMS.keys()
	for k: String in ["cleaner", "finish"]:
		_store_box(shelf, Treatments.box_id(k))
	var hooks := 0
	for c: Vector2i in kitchen.wall_cells:
		if hooks >= 4 or stations.has(c) or highs.has(c) or not kitchen.can_hang(c, "hook"):
			continue
		clean_kit.keep(add_high("hook", c), ["sponge", "scourer", "grease_scraper", "spill_kit"][hooks], 0)
		hooks += 1
	if demo.begins_with("tree_"):
		var at := Vector2i(5, 4)
		player.position = Grid.center(at + Vector2i(0, 1))
		player.look(Vector2i(0, -1))
		match demo:
			"tree_box":
				kitchen.unstore(shelf, "box_finish")
				pick_up(Grid.center(shelf))   # the cleaner's box
				_store_box(shelf, "box_finish")
			"tree_bucket":
				clean_kit.on_built(add_station("mop_bucket", at), "mop_bucket")
				pick_up(Grid.center(at))
			"tree_sponge":
				var w: Vector2i = highs.keys().filter(func(c: Vector2i) -> bool: return (highs[c] as Station).kit_tool == "sponge")[0]
				pick_up(Grid.center(w))
		open_shop()
		return
	var row: Array = plan.floors.keys().filter(func(c: Vector2i) -> bool:
		return c.x >= 7 and c.y >= 4 and not grid.is_blocked(c) and not grid.reserved.has(c))
	row.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for i in mini(keys.size(), row.size()):
		treat_laid[row[i]] = keys[i]
		if i % 2 == 1:   # a puddle on every other one: dirt shows more on a shine
			floor_dirt.mess.add_dirt(row[i])
			floor_dirt.mess.add_dirt(row[i])
	treat_off["sealing_primer"] = true   # dimmed: switched off
	player.position = Grid.center(Vector2i(3, 3))
	player.look(Vector2i(1, 0))
	pick_catalog("treat_cleaner")
	player.drag = {"from": Grid.center(Vector2i(3, 2)), "remove": false}
	player.demo_hover = Grid.center(Vector2i(4, 2))
	if demo == "treat_day":
		for k: String in keys:
			if not kitchen.stocked().has(Treatments.box_id(k)):
				var c := Vector2i(1, 5) if k.contains("primer") else Vector2i(3, 5)
				if not stations.has(c):
					add_station("counter", c, 1, 0, "double_counter")
				_store_box(c, Treatments.box_id(k))
		treat_off.clear()
		cancel_hand()
		player.demo_hover = Vector3.INF
		start_day()
		arrivals.assign([{"time": 99999.0, "idx": 0}])   # keeps the day open, nobody comes
	floor_dirt.redraw()


## PRD 8.6: the new jobs' tools along the back (cutting, heat and pour lines), and
## counters in front holding each new kind, raw and made, so their models can be checked.
func _demo_jobs() -> void:
	var diner := Scenery.theme_id != "seaside"
	var tools := ["grater", "rotary_grater", "bread_knife", "juicer", "blender", "steamer",
		"coffee_machine" if diner else "beer_tap", "two_tap_fountain" if diner else "wine_rack"]
	var spots := [Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(5, 3), Vector2i(6, 3),
		Vector2i(7, 3), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 2)].filter(func(c: Vector2i) -> bool: return not stations.has(c))
	for i in tools.size():
		add_station("counter", spots[i])
		add_station(tools[i], spots[i])
	var shown: Array[String] = []   # each new kind made, then each source raw
	for k: String in Pantry.for_theme(Scenery.theme_id):
		if Pantry.tool_of(k) in DEMO_PREP_NEW.diner or k in ["cola", "coffee", "red_wine", "ale", "ice_cream"]:
			shown.append(Tray.kind("prep", k))
	for k: String in Pantry.for_theme(Scenery.theme_id):
		if Pantry.tool_of(k) in DEMO_PREP_NEW.diner and Pantry.needs_prep(Pantry.source_of(k)):
			var raw := Tray.kind("raw", Pantry.source_of(k))
			if not shown.has(raw):
				shown.append(raw)
	var free := []
	for z in range(3, 7):
		for x in range(1, 4):
			if not stations.has(Vector2i(x, z)):
				free.append(Vector2i(x, z))
	for i in mini(shown.size(), free.size()):
		add_station("counter", free[i])
		stations[free[i]].set_item(shown[i])
	player.position = Grid.center(Vector2i(6, 5))
	player.look(Vector2i(0, -1))


## PRD 10.3. Two desks along the front wall and a grill cook's post up; the town warmed
## up so applicants come. desk_line: the room, the line outside, the pile on the desk and
## the chef at the desk. desk_post: writing a post. desk_cvs: the pile, the top CV half
## dragged right. desk_haggle: a low offer refused.
func _demo_desk(demo: String) -> void:
	for c: Vector2i in [Vector2i(8, 6), Vector2i(9, 6)]:
		add_station("desk", c)
	if demo in ["desk_staff", "desk_raise", "desk_restock", "desk_fire"]:   # PRD 10.4: three hires, the week of days 6 to 10
		for c: Vector2i in [Vector2i(7, 6), Vector2i(6, 6)]:
			add_station("desk", c)
		_demo_hires()
		ledger.day = 6   # a new week: everyone picks their days off as the build phase opens
		open_build()
		if demo == "desk_restock":
			hud.menu_notes.open = true
			player.position = Grid.center(Vector2i(1, 5))
			player.look(Vector2i(0, 1))
			hud.show_build()
			return
		open_desk()
		hud.desk.show_tab("staff")
		if demo == "desk_raise":
			var person: int = staff.employees.keys()[0]
			hud.desk.open_person(person)
			var e: Dictionary = staff.employee(person)
			e.pending = {"duty": "wash_up", "raise": 3, "haggle": staff._new_haggle(int(e.wage) + 3)}
			hud.desk.render()
		elif demo == "desk_fire":   # PRD 10.8: the fed-up washer opened, both fire buttons out
			hud.desk.open_person(staff.employees.keys()[2])
			hud.desk._set_firing(true)
		return
	staff.add_post("Grill cook", ["grill", "fetch", "assemble"], 1, 1, desk_count())
	for p in town.people:
		p.affinity = 0.5
	open_build()
	if demo == "desk_line":
		player.position = Grid.center(Vector2i(7, 6))
		player.look(Vector2i(1, 0))
		return
	open_desk()
	if demo == "desk_post":
		hud.desk.draft_post("Dish washer", ["wash_up", "empty_bin", "clear_tables"], 2, 1)
		hud.desk.select("duty:take_orders")
	elif demo == "desk_cvs":
		hud.desk.show_tab("cvs")
		get_tree().create_timer(0.6).timeout.connect(hud.desk.drag_to.bind(120.0))
	elif demo == "desk_haggle":
		hud.desk.show_tab("cvs")
		hud.desk.start_haggle()
		staff.rng.seed = 3
		hud.desk.make_offer(maxi(1, int(staff.cvs[0].ask) / 2))


## Three hires for the staff demos: a happy grill cook, a so-so server and a fed-up
## washer two nights from quitting.
func _demo_hires() -> void:
	for h: Array in [[2, "Grill cook", ["grill", "fetch", "assemble"], 1, 1, 0.85, 0],
			[5, "Server", ["take_orders", "take_payment", "carry_trays", "clear_tables"], 2, 2, 0.5, 0],
			[9, "Washer", ["wash_up", "empty_bin"], 0, 1, 0.12, 2]]:
		var pid := staff.add_post(h[1], h[2], h[3], h[4], 99)
		var cv := staff._make_cv(h[0], Staff.skills_from(town.people[h[0]].tolerance), town.rating(h[0]), 1.0, pid)
		staff.cvs.append(cv)
		staff.hire(cv.id, -1, 1)
		staff.employee(h[0]).satisfaction = h[5]
		staff.employee(h[0]).bottom_nights = h[6]


func _demo_build(demo: String) -> void:
	open_build()
	if demo == "build_new":   # every PRD 7 piece placed for this theme (run once per theme)
		var show := "jukebox" if not Scenery.seaside() else "aquarium"
		var small := "gumball" if not Scenery.seaside() else "lantern"
		for spot: Array in [["dish_rack", 3, 3, 0], ["sink", 3, 6, 0], ["bin", 1, 6, 0],
				["floor_lamp", 5, 0, 0], [show, 7, 0, 0], [small, 8, 0, 0], ["flower_stand", 9, 2, 0],
				["coat_stand", 5, 6, 0], ["stool", 5, 3, 0]]:
			add_station(spot[0], Vector2i(spot[1], spot[2]), 1, spot[3])
		return
	for step: Array in [["counter", 2, 4, 0], ["screen", 8, 5, 0], ["screen", 9, 5, 0], ["table", 8, 6, 0], [fern(), 9, 2, 0]]:
		pick_catalog(step[0])
		place(Vector3i(step[1], step[2], step[3]))
	cancel_hand()
	if demo == "door":  # at the doorway, about to flip the card
		player.position = Grid.center(Vector2i(W - 1, DOOR.y))
		player.look(Vector2i(1, 0))
	elif demo == "build_tools":   # the shop's Build tab: floors, walls and ways through
		open_shop()
		hud._set_category("Build")
	elif demo == "build" or demo == "build_find":  # the shop, three items along
		open_shop()
		if demo == "build_find":
			hud.set_search("o")
		for i in 3:
			get_tree().create_timer(0.3 + 0.25 * i).timeout.connect(hud.shop_move.bind(1))
	elif demo == "build_move":  # a table picked up and turned, ready to sell or put down
		pick_up(Vector3(8.5, 0, 3.5))
		rotate_hand()
		_demo_hover = Vector3(7.5, 0, 2.5)
	elif demo == "build_room" or demo == "build_drag":
		# A back room behind the dining room through a door, the kitchen grown to the
		# left behind a new wall, and a door the bin stands in front of (greyed out).
		ledger.money = 2000
		pick_catalog("floor_planks")
		finish_drag(Vector3(4.5, 0, -1.5), Vector3(9.5, 0, -0.5), false)
		pick_catalog("wall")
		finish_drag(Vector3(4, 0, 0), Vector3(10, 0, 0), false)
		pick_catalog("door")
		place(Vector3i(7, 0, 0))
		pick_catalog("floor_tile")
		finish_drag(Vector3(-2.5, 0, 2.5), Vector3(-0.5, 0, 6.5), false)
		pick_catalog("wall")
		finish_drag(Vector3(0, 0, 2), Vector3(0, 0, 7), false)
		pick_catalog("arch")
		place(Vector3i(0, 5, 1))
		pick_catalog("door")
		place(Vector3i(1, 2, 0))
		cancel_hand()
		if demo == "build_drag":   # more floor being dragged out, part of it off the lot
			pick_catalog("floor_planks")
			player.drag = {"from": Vector3(-0.5, 0, -1.5), "remove": false}
			_demo_hover = Vector3(3.5, 0, 1.5)
	elif demo == "build_dining" or demo == "build_dining_shop":  # a booth and a table for four, in the room or the shop
		for spot: Array in [[Vector3(6.5, 0, 1.5), "table4", Vector3i(6, 1, 0)], [Vector3(6.5, 0, 5.5), "booth", Vector3i(6, 5, 0)]]:
			pick_up(spot[0])
			sell_hand()
			pick_catalog(spot[1], 1)
			place(spot[2])
			cancel_hand()   # a bought piece stays in hand for the next one
		if demo == "build_dining_shop":
			open_shop()
			hud._set_category("Dining")
			get_tree().create_timer(0.3).timeout.connect(hud.shop_move.bind(1))
	elif demo == "build_finish":   # parquet and marble, striped and rose paper, paint, and the rug moved
		ledger.money = 2000
		ledger.xp = 500
		for step: Array in [["floor_parquet", Vector3(4.5, 0, 0.5), Vector3(9.5, 0, 2.5)],
				["floor_marble", Vector3(4.5, 0, 4.5), Vector3(7.5, 0, 6.5)],
				["paper_stripe", Vector3(4, 0, 0), Vector3(7, 0, 0)],
				["paper_rose", Vector3(7, 0, 0), Vector3(10, 0, 0)],
				["paint", Vector3(0, 0, 2), Vector3(4, 0, 2)],
				["paint", Vector3(10, 0, 0), Vector3(10, 0, 4)]]:
			pick_catalog(step[0])
			finish_drag(step[1], step[2], false)
		cancel_hand()
		pick_up(Vector3(8.5, 0, 4.5))
		place(Vector3i(6, 1, 0))
	elif demo == "build_range":  # a fern carried past the tables: its reach and the seats it touches
		pick_catalog(fern(), 1)
		_demo_hover = Vector3(6.5, 0, 3.5)
	elif demo == "build_range_floor":  # marble being dragged out under the tables: who sits on it
		ledger.xp = 500
		pick_catalog("floor_marble")
		player.drag = {"from": Vector3(6.5, 0, 2.5), "remove": false}
		_demo_hover = Vector3(9.5, 0, 4.5)
	elif demo == "build_range_rug":   # a new rug under the back table; one seat in view is full already
		ledger.xp = 500
		ledger.money = 500
		pick_catalog("floor_marble")
		finish_drag(Vector3(9.5, 0, 3.5), Vector3(9.5, 0, 3.5), false)   # marble and the old rug: (9, 3) is full
		pick_catalog("rug")
		_demo_hover = Vector3(6.5, 0, 1.5)
	elif demo == "build_range_paint":  # paint dragged along the back wall: the seats against it
		ledger.xp = 500
		pick_catalog("paint")
		player.drag = {"from": Vector3(4, 0, 0), "remove": false}
		_demo_hover = Vector3(10, 0, 0)
	elif demo == "build_till":  # the till lifted off the pass and held over the next counter down
		player.position = Grid.center(Vector2i(5, 2))
		player.look(Vector2i(-1, 0))
		lift()
		_demo_hover = Vector3(4.5, 0, 4.5)
	else:   # a stove from the shop, held over a good spot or (build_no) a refused one
		pick_catalog("stove", 2)
		_demo_hover = Vector3(6.5, 0, 5.5) if demo == "build_no" else Vector3(3.5, 0, 5.5)


## A fuller kitchen and menu: mains, sides (one with no onion to make it, greyed)
## and a drink, then the screen, an item being named, or the restock note.
func _demo_menu(demo: String) -> void:
	open_build()
	stock_box("cheese", Vector2i(1, 6), true)
	stock_box("potato", Vector2i(2, 6))
	add_station("fryer", Vector2i(3, 6))
	add_station("fountain", Vector2i(1, 2))
	var cheese := menu.add("main", ["bun", "patty", "cheese"], "Cheeseburger", "dear")
	menu.add("main", ["bun", "patty", "cheese", "patty", "cheese"], "Double Stack", "dear")
	menu.add("side", ["potato"], "Fries", "cheap")
	menu.add("side", ["potato", "cheese"], "Cheesy Fries")
	menu.add("side", ["onion"], "Onion Rings")
	menu.add("drink", ["soda"], "Soda", "cheap")
	menu_changed()
	if demo == "restock":
		hud.menu_notes.open = true
		player.position = Grid.center(Vector2i(1, 5))
		player.look(Vector2i(0, 1))
		hud.show_build()
		return
	open_menu()
	if demo == "menu_name":
		hud.menu.open_item(cheese)
		hud.menu.start_naming()


## PRD 11's demos. pay_call: a table ready to pay calling the chef in sight, a second
## behind a partition not calling (shoot at about 8). pay_till: two guests queued at the
## till (about 8). pay_bill: the bill screen open, two tables waiting, three items ticked
## (3). pay_hand: the chef handing a slip over, the bar half full (3). pay_wrong: a refused
## bill and its line on the guest card (4). pay_server: the server walking a slip to a
## table (about 10).
func _demo_pay(demo: String) -> void:
	arrivals.assign([{"time": 99999.0, "idx": 13}])
	var t1: Station = stations[Vector2i(6, 5)]
	var t2: Station = stations[Vector2i(8, 3)]
	var t3: Station = stations[Vector2i(6, 1)]
	match demo:
		"pay_call":
			# A partition shuts the far table off from the chef in the near corner.
			for x in range(5, 8):
				add_wall(Vector2i(x, 3), 0)
			for y in range(0, 3):
				add_wall(Vector2i(8, y), 1)
			_demo_paying_party([0, 1], t1)
			_demo_paying_party([2], t3)
			player.position = Grid.center(Vector2i(9, 5))
			player.look(Vector2i(-1, 0))
		"pay_till":
			var a := _demo_paying_party([0, 1], t1)
			var b := _demo_paying_party([2, 3], t2)
			player.position = Grid.center(Vector2i(1, 4))
			player.look(Vector2i(1, 0))
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				send_to_till(a[0].table)
				send_to_till(b[0].table))
		"pay_bill":
			# A fuller menu than the test kitchen's one main: bread as a side, and a drink.
			var bread: String = fixed_main().bread
			menu.add("side", [bread], Pantry.name_of(bread), "cheap")
			if Scenery.theme_id == "diner":
				add_station("fountain", Vector2i(1, 2))
				menu.add("drink", ["soda"], "Soda", "cheap")
			menu_changed()
			_demo_paying_party([0, 1], t1)
			_demo_paying_party([2], t2)
			var till := till_station()
			player.position = Grid.center(till.cell + Vector2i(-1, 0))
			player.look(Vector2i(1, 0))
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				open_bill(player)
				var items := tonight_menu()
				if items.is_empty():
					return
				hud.bill.bill.add(int(items[0].id), 2)
				hud.bill.bill.add(int(items[-1].id))
				hud.bill._sel_key = "item:%d" % int(items[0].id)
				hud.bill.render())
		"pay_hand":
			var party := _demo_paying_party([0, 1], t1)
			player.position = Grid.center(t1.cell + Vector2i(1, 0))
			player.look(Vector2i(-1, 0))
			player.set_held("bill")
			player.bill = right_bill(party[0].table)
			player.demo_giving = 0.5
		"pay_wrong":
			var party := _demo_paying_party([0, 1], t1)
			player.position = Grid.center(t1.cell + Vector2i(1, 0))
			player.look(Vector2i(-1, 0))
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				var wrong := right_bill(party[0].table)
				var items := tonight_menu()
				wrong.add(int(items[-1].id))   # one too many
				player.set_held("bill")
				player.bill = wrong
				give_bill(player, party[0].table)
				hud.show_guest(party[0]))
		"pay_server":
			_demo_paying_party([0, 1], stations[Vector2i(8, 3)])
			player.position = Grid.center(Vector2i(1, 4))
			player.look(Vector2i(1, 0))
			crew.demo_hire(5, "Server", ["take_orders", "take_payment", "carry_trays", "clear_tables"], Vector2i(5, 5))


## Demos (PRD 11): a party sat straight down at `table`, served and done eating.
func _demo_paying_party(ids: Array, table: Station) -> Array[Guest]:
	for idx: int in ids:   # tastes are random: make sure each orders from the demo menu
		town.people[idx].dislikes = []
	var party := spawn_group(ids)
	for i in party.size():
		var g := party[i]
		queue.erase(g)
		g.line_place = -1
		g.table = table
		g.seat = table.seats[i]
		seat_taken[g.seat] = g
		g.position = Grid.center(g.seat)
		g.cell = g.seat
		g.goal = g.position
		g.path.clear()
		g._sit()
	_reflow_queue()
	take_orders(table)
	for g in party:
		if g.state == "waiting":
			serve(g, full_tray_for(g))
			finish_meal(g)
			g.timer = 0.3 * party.find(g)
	return party


func _demo_order(take: bool) -> void:
	for g in guests:
		if g.state == "ordering":
			if take:
				use_station(g.table)
				return
			player.position = Grid.center(g.table.cell + Vector2i(0, 1))
			player.look(Vector2i(0, -1))
			hud.show_guest(g)
			return


func _demo_ticket(full: bool) -> void:
	for g in guests:
		if g.state == "ordering":
			take_orders(g.table)
	if tickets.is_empty():
		return
	var pass_st: Station = stations[Vector2i(4, 3)]
	if full:
		# Every dish of the first ticket, made and plated, carried on a tray.
		var ds: Array = []
		for it: Dictionary in tickets[0].items:
			var d := Dish.make(Tray.vessel_of(it))
			for ing: String in it.ingredients:
				d.add(Tray.kind("prep", ing), 1.0)
			ds.append(d)
		player.set_held("dishes", 1.0, ds, true)
		player.position = Grid.center(Vector2i(2, 5))
		player.look(Vector2i(0, 1))
	else:
		# A cooked patty with a bun on it, waiting for the plate in hand.
		var d := Dish.new()
		d.add("prep:" + fixed_main().grill, 1.0)
		d.add("prep:" + fixed_main().bread, Prep.PLAIN)
		pass_st.set_dish(d)
		find_station("stove").set_item("raw:" + fixed_main().grill)
		find_station("stove").cook = 3.0
		player.position = Grid.center(Vector2i(3, 3))
		player.look(Vector2i(1, 0))
		player.take_dish(Dish.make(Dish.PLATE))   # "Plate it"
	hud.refresh_tickets()


## The chef at (1, 4) facing a tool at (2, 4) (and a second at (2, 5) where the
## tool has two looks), the minigame stopped part-way so a shot can catch it.
func _demo_prep(which: String) -> void:
	player.position = Grid.center(Vector2i(1, 4))
	player.look(Vector2i(1, 0))
	var at := Vector2i(2, 4)
	var use: Dictionary = DEMO_PREP.get(Scenery.theme_id, DEMO_PREP.diner)
	match which:
		"grill":
			var st := find_station("stove")
			st.set_item("raw:" + fixed_main().grill)
			st.cook = 5.0
			player.position = Grid.center(Vector2i(1, 3))
			player.look(Vector2i(-1, 0))
		"fry":
			add_station("fryer", at, 1, 1).set_item("raw:" + use.fry)
			stations[at].cook = 1.0
			var rack := add_station("fryer", at + Vector2i(0, 1), 1, 1)
			rack.lift_to_rack("prep:" + use.fry, Prep.GOOD, "good")
			rack.rest = Prep.FRY_REST * 0.6
		"boil":
			add_station("pot", at, 1, 1).set_item("raw:" + use.boil)
			stations[at].cook = 1.0
			add_station("pot", at + Vector2i(0, 1), 1, 1).set_item("prep:" + use.boil)
		"chop", "slice", "pour":
			var ing: String = use[which]
			var type: String = {"chop": "board", "slice": "slicer", "pour": "wine_barrel" if ing == "wine" else "fountain"}[which]
			start_prep(0, add_station(type, at, 1, 1), which, ing)
			var s: Dictionary = preps[0]
			s.frozen = true
			match which:
				"chop":
					s.t = Prep.CHOP_SWEEP_TIME * 1.3
					s.hits = [true]
				"slice":
					s.t = Prep.SLICE_TIME * 0.45
					s.presses = 4
				"pour":
					s.fill = 0.72
			_show_prep(0)
		"grate", "saw", "juice", "blend", "steam":   # PRD 8.6
			var ing: String = DEMO_PREP_NEW.get(Scenery.theme_id, DEMO_PREP_NEW.diner)[which]
			var src := Pantry.source_of(ing)
			var held := Tray.kind("prep" if src != ing and not Pantry.needs_prep(src) else "raw", src)
			add_station("counter", at, 1, 1)
			var st := add_station(str(Pantry.TOOL_STATION[which]), at, 1, 1)
			start_prep(0, st, which, ing, held)
			var s: Dictionary = preps[0]
			s.frozen = true
			match which:
				"grate":
					s.t = 1.4
					s.v = 0.6
					s.fill = 0.55
				"saw":
					s.t = s.sweep * 1.6
					s.hits = [true]
				"juice":
					s.t = 1.5
					s.fill = 0.55
					s.hits = [true]
				"blend":
					s.t = 1.2
					s.presses = 4
					s.w = 0.55
				"steam":
					s.t = Prep.steam_time(s.q) * 0.62
			_show_prep(0)
		"good", "bad":
			player.set_held("prep:" + use.chop, Prep.GOOD if which == "good" else Prep.BAD)
			add_station("board", at, 1, 1)
			player.look(Vector2i(0, 1))
			PrepWidget.pop(stations[at], Vector3(0, 2.0, 0), which)
			player.boost("burst" if which == "good" else "penalty")
			player.boost_left = 999.0


func _demo_kind(offer: bool) -> void:
	for g in guests:
		if g.seated_waiting():
			take_orders(g.table)
			if offer:
				use_station(g.table)
				return
			g.mood.patience = 0.3
			player.position = Grid.center(g.table.cell + Vector2i(0, 1))
			player.look(Vector2i(0, -1))
			return


func _demo_comp(offer: bool) -> void:
	for g in guests:
		if g.seated_waiting():
			take_orders(g.table)
			if offer:
				use_station(g.table)
				return
			town.people[g.idx].deals = Town.EXPECT_AT
			g.mood.offer_discount()
			g.mood.patience = 0.15
			g.mood.disgust = 0.5
			g.mood.think("Nobody has cleared that table")
			player.position = Grid.center(g.table.cell + Vector2i(0, 1))
			player.look(Vector2i(0, -1))
			hud.show_guest(g)
			return


func _demo_mood() -> void:
	var seated: Array[Guest] = []
	for g in guests:
		if g.seated_waiting():
			seated.append(g)
	if seated.size() < 2:
		return
	var feel := [[1.0, 1.0], [0.0, 0.1]]   # joy and patience: content, then fed up
	for i in 2:
		var g := seated[i]
		take_orders(g.table)
		g.mood.joy = feel[i][0]
		g.mood.patience = feel[i][1]
		g.mood.disgust = 0.0
		serve(g, full_tray_for(g, 1.0 if i == 0 else 0.7))
	inspect(seated[0])


func _demo_fx() -> void:
	var seated: Array[Guest] = []
	for g in guests:
		if g.seated_waiting():
			seated.append(g)
		elif g.state == "queue":
			g.mood.patience = 0.5                 # Zzz bubble
	if seated.size() > 0:
		serve(seated[0], full_tray_for(seated[0]))   # stars, heart, chewing, a half-eaten tray
		seated[0].timer = 2.0                     # then the coin and a dirty plate
	if seated.size() > 1:
		seated[1].mood.patience = 0.0             # walkout: anger mark and a stamp
	if seated.size() > 2:
		seated[2]._gross_time = 6.0               # green cloud
	storage_of(fixed_main().grill).used()
	burst(find_station("sink").position + Vector3(0, 1.15, 0), "bubbles", 0.4)


# ---------------------------------------------------------------- world

func _build_scenery() -> void:
	if theme_forced():  # a developer's switch: skips the theme card (see choose_theme)
		Scenery.theme_id = OS.get_environment("REGULARS_THEME")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(Scenery.t().backdrop)
	# Shadows are never black: the ambient fill carries the warm plum of #5a423a.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ece0dc")
	env.ambient_light_energy = 0.62  # a high, tinted fill: shadows are soft and never dark
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.tonemap_white = 1.7
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.4
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.15
	env.glow_bloom = 0.03
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	_env = env
	get_viewport().msaa_3d = Viewport.MSAA_4X
	# Grain-free soft shadows and contact shading: the default filters dither.
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, false, 0.5, 3, 50, 300)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = SUN_ENERGY.x
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.6
	sun.shadow_blur = 2.2  # an even, soft edge; a wide sun disc dithers instead
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 48.0  # just past the far corner of the paper
	sun.directional_shadow_fade_start = 1.0
	# Small biases keep each shadow attached to the foot of what casts it. The
	# defaults (0.1 and 2.0) slide shadows sideways and open a gap under walls.
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.4
	_sun = sun
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = WIDE_SIZE
	# Tight clip planes: with the default 0.05 to 4000 an orthographic camera gets
	# no directional shadows at all.
	cam.near = 1.0
	cam.far = 80.0
	# Tilt-shift is a screen-space blur drawn over the world and under the interface.
	var lens_layer := CanvasLayer.new()
	lens_layer.layer = -1
	add_child(lens_layer)
	_lens = ColorRect.new()
	_lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lens_mat := ShaderMaterial.new()
	lens_mat.shader = load("res://game/shaders/tilt_shift.gdshader")
	_lens.material = lens_mat
	lens_layer.add_child(_lens)
	add_child(cam)
	cam.look_at_from_position(WIDE_FOCUS + CAM_OFFSET, WIDE_FOCUS)

	_sconces = Scenery.build_ground(self, W, H)
	set_tilt_shift(TILT_SHIFT)


## The glow of the mushroom lamp on each table. (No hanging lamps: from this
## camera a shade would sit in front of the guests behind it.)
func _add_lamp(over: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = over + Vector3(0, 1.0, 0)
	light.light_color = Color("#ffd9a0")
	light.light_energy = 0.8
	light.set_meta("full", 0.8)
	light.omni_range = 2.8
	add_child(light)
	_sconces.append(light)
	return light


## The theme's potted plant: the diner's fern or the seaside's palm.
static func fern() -> String:
	return "palm" if Scenery.seaside() else "plant"


static func fixed_main() -> Dictionary:
	return FIXED_MAIN.get(Scenery.theme_id, FIXED_MAIN.diner)


func _build_layout() -> void:
	for spot: Array in [
		# The cooking line runs down the left wall under the hood, as in sheet 1.
		# The cell in front of the back doorway stays clear, so the patties can be reached.
		# The kitchen starts empty but for the sink, the bin, the plate stack and the
		# counters: the player buys the first stations and writes the menu on night zero.
		["plates", 2, 2], ["sink", 3, 2], ["bin", 0, 5, 1],
		["table", 6, 1], ["table", 8, 3], ["table", 6, 5], [fern(), 9, 0],
	]:
		add_station(spot[0], Vector2i(spot[1], spot[2]), 1, spot[3] if spot.size() > 3 else 0)
	# The pass: four real counters drawn as the frame's long teal run, each sellable,
	# each able to take a tool (PRD 8).
	for z in range(2, 6):
		add_station("counter", Vector2i(4, z), 1, 0, "counter", true)
	Build.register(stations[Vector2i(4, 2)])  # the till: its own piece, standing on the pass
	add_rug(Vector2i(8, 3))   # under the middle table, as in sheet 1


## The first room's wall pieces (PRD 8.5), real and sellable like the rest: the hood
## over where the cooking line goes, the wall cabinets by the back door, and the jar
## shelf over the sink.
func _hang_fixtures() -> void:
	for spot: Array in [["hood", 0, 3], ["hood", 0, 4], ["cabinet", 0, 5], ["cabinet", 0, 6], ["shelf", 3, 2]]:
		var cell := Vector2i(spot[1], spot[2])
		if kitchen.can_hang(cell, spot[0]):
			add_high(spot[0], cell)


## The first room is an L (sheet 1): a tiled kitchen on the left, set forward of
## the planked dining room, with the front door in the right-hand wall.
func _start_plan() -> void:
	plan = Floorplan.new(LOT)
	plan.fill(Rect2i(0, Scenery.KITCHEN_Z, Scenery.KITCHEN_W, H - Scenery.KITCHEN_Z), "tile")
	plan.fill(Rect2i(Scenery.KITCHEN_W, 0, W - Scenery.KITCHEN_W, H), "planks")
	plan.openings[Vector3i(DOOR.x, DOOR.y, 1)] = "entrance"
	_sync_grid()
	_rebuild_room()


## Copies the plan's walls, doors and bare ground into the grid, with the partitions.
func _sync_grid() -> void:
	grid.walls.clear()
	for e in plan.solid_walls():
		grid.walls[e] = true
	for e: Vector3i in wall_nodes:
		grid.walls[e] = true
	grid.doors.clear()
	for e in plan.doors():
		grid.doors[e] = true
	grid.outside.clear()
	for x in range(LOT.position.x, LOT.end.x):
		for y in range(LOT.position.y, LOT.end.y):
			if not plan.has_floor(Vector2i(x, y)):
				grid.outside[Vector2i(x, y)] = true


## Redraws the room from the plan and fits the camera round it.
func _rebuild_room() -> void:
	if _room:
		remove_child(_room)
		_room.queue_free()
	for l in _room_lights:
		_sconces.erase(l)
	recheck_decor()   # building is only between days today, so nobody is seated yet
	_room = Node3D.new()
	add_child(_room)
	var r: Dictionary = Scenery.build_room(_room, plan, DOOR)
	_sync_walls(r.get("glass", {}))
	_room_lights.assign(r.lights)
	_sconces.append_array(_room_lights)
	_openings = r.openings
	_opening_ok.clear()
	_refresh_openings()
	# The camera keeps the whole floor in view as it grows back and to the left.
	var b := plan.bounds()
	var shift := Vector3((b.position.x + b.end.x - W) / 2.0, 0, (b.position.y + b.end.y - H) / 2.0)
	var grow := maxf(1.0, float(b.size.x + b.size.y + 2) / float(W + H + 2))
	_frame = [WIDE_FOCUS + shift, WIDE_SIZE * grow, CLOSE_FOCUS + shift, CLOSE_SIZE * grow]


## Greys out each door and archway nobody can get through: one with bare
## ground or furniture on a side, or none of it reachable from the front door.
func _refresh_openings() -> void:
	var seen := grid.flood(DOOR)
	for e: Vector3i in _openings:
		var ok := opening_usable(e, seen)
		if _opening_ok.get(e, null) != ok:
			_opening_ok[e] = ok
			Scenery.dress_opening(_openings[e], ok)


func opening_usable(e: Vector3i, seen := {}) -> bool:
	if seen.is_empty():
		seen = grid.flood(DOOR)
	var s := Floorplan.sides(e)
	return plan.opening_has_floor(e) and not grid.blocked.has(s[0]) and not grid.blocked.has(s[1]) \
		and (seen.has(s[0]) or seen.has(s[1]))


## A tool (a top) added where a bare counter stands goes onto that counter.
func add_station(type: String, cell: Vector2i, tier := 1, facing := 0, base := "", pass_look := false, node := "") -> Station:
	var st := Station.new()
	add_child(st)
	st.setup(type, cell, tier, facing, base, pass_look, node)
	if Station.is_table(type) or type == "floor_lamp":
		st.lamp = _add_lamp(st.position)
	if Kitchen.is_top(type) and _bare_counter(cell) != null:
		_onto_counter(st, cell, facing)
	else:
		_register(st)
	return st


## The counter at a cell with nothing on top, or null.
func _bare_counter(cell: Vector2i) -> Station:
	var st: Station = stations.get(cell)
	return st if st != null and st.type == "counter" else null


## Stands a tool (not registered yet) on the bare counter at a cell: the counter's
## node gives way to the tool's, which takes over its base, look and the till.
func _onto_counter(top: Station, cell: Vector2i, facing: int) -> void:
	var under := _bare_counter(cell)
	var held := kitchen.take_stock(cell)   # the boxes below stay put (PRD 8.4)
	if under != null:
		_unregister(under)
		var till := under.get_node_or_null("till")
		if till:
			till.reparent(top, false)
		top.set_base(under.base, under.pass_look)
		top.stacked = under.stacked
		under.queue_free()
	top.place_at(cell, facing)
	_register(top)
	kitchen.give_stock(cell, held)
	_show_boxes(cell)


## Lifts the tool off a counter: the bare counter is left standing in its place.
func _off_counter(top: Station) -> void:
	var held := kitchen.take_stock(top.cell)
	_unregister(top)
	var under := Station.new()
	add_child(under)
	under.setup("counter", top.cell, 1, top.facing, top.base, top.pass_look)
	under.stacked = top.stacked
	var till := top.get_node_or_null("till")
	if till:
		till.reparent(under, false)
	_register(under)
	kitchen.give_stock(under.cell, held)
	_show_boxes(under.cell)
	top.set_boxes([])


## Whether the piece in hand can go onto the station at a cell: a tool onto a bare
## counter, or a counter onto a bare counter (a double counter). Neither while
## something sits on the counter below or on the counter carried.
func _stacks_on(cell: Vector2i, h: Dictionary) -> bool:
	var under := _bare_counter(cell)
	if under == null or under.item != "" or not (Kitchen.is_top(h.id) or Kitchen.is_counter(h.id)) \
			or Kitchen.grows_from_counter(hand_node(h)):
		return false
	if h.get("moving", false) and ((h.node as Station).item != "" \
			or (Kitchen.is_counter(h.id) and (h.node as Station).base != "counter")):
		return false   # an upgraded counter (a fridge, a long counter) does not stack
	return kitchen.can_place(cell, Kitchen.node_of(h.id))


func _register(st: Station) -> void:
	stations[st.cell] = st
	grid.blocked[st.cell] = true
	for s in st.seats:
		grid.reserved[s] = true
	if st.base != "":
		kitchen.set_cell(st.cell, st.base, st.node if Kitchen.is_top(st.type) else "")
	st.set_wall(false)
	_refresh_wall(st.cell)
	_update_racks()


## Redraws the tags naming what a cell stores: over the piece standing there, else over
## the piece hung on the wall; above the high layer when the cell has one.
func _show_boxes(cell: Vector2i) -> void:
	var up := kitchen.get_piece(cell, "high") != "" or Kitchen.is_tall(kitchen.get_piece(cell, "base"))
	var y := 2.62 if up else 1.6
	if stations.has(cell):
		(stations[cell] as Station).set_boxes(kitchen.stock(cell), y)
		if highs.has(cell):
			(highs[cell] as Station).set_boxes([])
	elif highs.has(cell):
		(highs[cell] as Station).set_boxes(kitchen.stock(cell), y)


# ---------------------------------------------------------------- the wall layer (PRD 8.5)

## The back walls behind a cell that a piece can hang on: full height, with floor on
## this side only and no door, archway or window in them. West first, then north.
func _back_walls(c: Vector2i, glass := {}) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for e: Vector3i in [Vector3i(c.x, c.y, 1), Vector3i(c.x, c.y, 0)]:
		if Scenery.wall_look(plan, e) == "tall" and not plan.openings.has(e) and not glass.has(e):
			out.append(e)
	return out


## Marks the kitchen's wall cells from the plan, and which way a piece hung in each
## faces: away from its wall (1 is +x, off the left wall; 0 is +z, off the back wall).
func _sync_walls(glass := {}) -> void:
	_glass = glass
	kitchen.wall_cells.clear()
	wall_facing.clear()
	for c: Vector2i in plan.floors:
		var e := _back_walls(c, glass)
		if not e.is_empty():
			kitchen.set_wall(c)
			wall_facing[c] = 1 if e[0].z == 1 else 0


## Whether taking away these wall edges (laying floor behind them, opening them up)
## would leave a hung piece with no wall to hang on.
func _strands_high(edges: Array[Vector3i]) -> bool:
	for c: Vector2i in highs:
		var left := _back_walls(c, _glass)
		for e in edges:
			left.erase(e)
		if left.is_empty():
			return true
	return false


## The kitchen node of a piece in hand: the counter's node for a counter (a fridge, a
## tall fridge), else the piece's own.
static func hand_node(h: Dictionary) -> String:
	if h.get("node") is Station:
		var st: Station = h.node
		return st.base if st.type == "counter" and st.base != "" else st.node
	if h.get("id", "") == "sponge":
		return "hook"   # sold hanging on its own hook (PRD 9.4)
	if h.get("up", "") != "":
		return h.up   # a favourite, built already upgraded
	if h.get("base", "") != "":
		return h.base   # a counter sold as a fridge
	return Kitchen.node_of(str(h.get("id", "")))


## The layer a kitchen piece would take in a cell: "base", "high" or "" (no room). Over
## anything standing there (a kitchen piece or not) only the high layer is left.
func layer_for(cell: Vector2i, node: String) -> String:
	if not Kitchen.has_node(node):
		return ""
	if stations.has(cell):
		return "high" if kitchen.can_hang(cell, node) else ""
	return kitchen.layer_for(cell, node)


## The layer the piece in hand would take where it is held: "high", "base", or "" for
## none (or a piece that is not a kitchen piece).
func hand_layer(ch: Player = null) -> String:
	ch = _me(ch)
	var hn := hand_node(ch.hand)
	var p := _hover_point(ch)
	if not Kitchen.has_node(hn) or p == Vector3.INF:
		return ""
	var sp := snap(p, ch)
	return layer_for(Vector2i(sp.x, sp.y), hn)


## Hangs a new piece from the catalog on a wall cell's high layer.
func add_high(id: String, cell: Vector2i) -> Station:
	var st := Station.new()
	add_child(st)
	st.setup(id, cell, 1, int(wall_facing.get(cell, 0)))
	_hang(st, cell)
	return st


## Hangs a piece (new or carried) in a cell's high layer, facing off the wall.
func _hang(st: Station, cell: Vector2i) -> void:
	st.visible = true
	st.place_at(cell, int(wall_facing.get(cell, 0)))
	kitchen.hang(cell, st.node)
	highs[cell] = st
	_refresh_wall(cell)
	_show_boxes(cell)


## Redraws a hung piece: a high shelf over a low one draws as one closet.
func _refresh_wall(cell: Vector2i) -> void:
	if highs.has(cell):
		(highs[cell] as Station).set_wall(true, kitchen.is_closet(cell))


## The piece a chef uses at a cell: what stands there, else what hangs on the wall above
## bare floor (a cabinet's stock is reached from below or beside it).
func station_at(cell: Vector2i) -> Station:
	return stations.get(cell, highs.get(cell))


func _unregister(st: Station) -> void:
	stations.erase(st.cell)
	kitchen.set_cell(st.cell, "")
	grid.blocked.erase(st.cell)
	for s in st.seats:
		grid.reserved.erase(s)
	_refresh_wall(st.cell)
	_show_boxes(st.cell)
	_update_racks()


## Marks each sink that has a dish rack standing beside it (one cell, diagonals too).
func _update_racks() -> void:
	for st: Station in stations.values():
		if st.type != "sink":
			continue
		var racked := false
		for o: Station in stations.values():
			racked = racked or (o.type == "dish_rack" and Decor.dist(o.cell, st.cell) == 1)
		if racked != st.racked:
			st.racked = racked
			st.refresh()


## A low partition (sheet 11): teal panelled base, tan cap, thin coral line.
func add_wall(cell: Vector2i, axis: int, height := 1.0) -> Node3D:
	grid.walls[Vector3i(cell.x, cell.y, axis)] = true
	var n := Node3D.new()
	_place_on_edge(n, Vector3i(cell.x, cell.y, axis))
	add_child(n)
	_wall_visual(n, height)
	return n


static func _place_on_edge(n: Node3D, edge: Vector3i) -> void:
	n.position = Vector3(edge.x + 0.5, 0, edge.y) if edge.z == 0 else Vector3(edge.x, 0, edge.y + 0.5)
	n.rotation.y = 0.0 if edge.z == 0 else PI / 2


static func _wall_visual(n: Node3D, height: float) -> void:
	Build.box(n, Vector3.ZERO, Vector3(1.0, height - 0.12, 0.24), Build.CABINET)
	Build.box(n, Vector3(0, height - 0.14, 0), Vector3(1.0, 0.04, 0.26), Build.CORAL)
	Build.box(n, Vector3(0, height - 0.1, 0), Vector3(1.04, 0.1, 0.3), Build.WORKTOP, 0.0, Build.R_WOOD)


func find_station(type: String) -> Station:
	for st: Station in stations.values():
		if st.type == type:
			return st
	return null


# ---------------------------------------------------------------- sound & feedback

func _load_sounds() -> void:
	for id: String in SOUNDS:
		var path := "res://assets/sfx/%s.wav" % id
		if not ResourceLoader.exists(path):
			continue
		var p := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load(path)
		if LOOPING.has(id):
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / (2 * (2 if stream.stereo else 1))   # 16-bit frames
		else:
			p.max_polyphony = 4
		p.volume_db = SOUNDS[id]
		p.bus = _bus("Sfx")
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.stream = stream
		add_child(p)
		_sfx[id] = p


## Cross-fades to a track from MUSIC. "closed" plays once; the others loop.
func play_music(id: String) -> void:
	if id == music_id:
		return
	music_id = id
	if _music:
		var old := _music
		var out := old.create_tween()
		out.tween_property(old, "volume_db", -50.0, MUSIC_FADE)
		out.tween_callback(old.queue_free)
		_music = null
	var path := "res://assets/music/%s.mp3" % MUSIC.get(id, "")
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStreamMP3 = load(path).duplicate()
	stream.loop = id != "closed"
	_music = AudioStreamPlayer.new()
	_music.bus = _bus("Music")
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.stream = stream
	_music.volume_db = -50.0
	add_child(_music)
	_music.play()
	_music.create_tween().tween_property(_music, "volume_db", MUSIC_DB, MUSIC_FADE)


## The name of an audio bus, made on first use and sent to the master bus.
func _bus(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var at := AudioServer.bus_count - 1
		AudioServer.set_bus_name(at, bus_name)
		AudioServer.set_bus_send(at, "Master")
	return bus_name


## Volumes from the options screen, 0 to 1 each.
func set_volumes(sfx_level: float, music_level: float) -> void:
	for pair: Array in [["Sfx", sfx_level], ["Music", music_level]]:
		var at := AudioServer.get_bus_index(_bus(pair[0]))
		AudioServer.set_bus_mute(at, pair[1] <= 0.001)
		AudioServer.set_bus_volume_db(at, linear_to_db(maxf(pair[1], 0.001)))


## Plays a sound with a little random pitch so repeats do not sound identical.
## Someone comes in: the shop bell and, under it, the door's creak.
func door_bell() -> void:
	sfx("bell")
	sfx("creaky_door")


func sfx(id: String, vary := 0.06, pitch := 1.0) -> void:
	if _sfx.has(id):
		_sfx[id].pitch_scale = pitch * randf_range(1.0 - vary, 1.0 + vary)
		_sfx[id].play()


## A four-frame cut-out effect in the world: stars, bubbles, wisps, anger...
func burst(at: Vector3, id: String, size := 0.45) -> void:
	Fx.play(self, id, at, size).drift = Vector3(0, 0.5, 0)


func shake(amount := 0.12) -> void:
	var tw := cam.create_tween()
	for i in 5:
		tw.tween_property(cam, "h_offset", randf_range(-amount, amount), 0.04)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)


## Tilt-shift on: a sharp band across the screen, soft above and below, and richer colour, like a close-up photo of
## a model. Off: everything sharp.
func set_tilt_shift(on: bool) -> void:
	_lens.visible = on
	_env.adjustment_saturation = 1.16 if on else 1.05
	_env.adjustment_contrast = 1.06 if on else 1.0


## Morning light drifts to a warm, low evening sun as the day goes on.
func _update_daylight() -> void:
	var t := smoothstep(0.35, 1.0, day_progress())
	_sun.light_color = Color("#fff3e2").lerp(Color("#ffb27c"), t)  # ends in an orange sunset
	var p := day_progress()
	# East is the right of the screen and west is the left, so shadows run across
	# the picture: leftward in the morning, rightward by evening. The arc leans a
	# little toward the camera so the faces we see are lit at midday.
	_night = move_toward(_night, 1.0 if phase == Phase.BUILD else 0.0, get_process_delta_time() * 0.7)
	var n := smoothstep(0.0, 1.0, _night)  # 0 by day, 1 in the calm of the night: moonlight and lamps
	var arc := deg_to_rad(lerpf(lerpf(24.0, 156.0, p), 128.0, n))
	var east := Vector3(1, 0, -1).normalized()
	var over := Vector3(0, 1, 0).rotated(east, deg_to_rad(SUN_LEAN))
	var from := east * cos(arc) + over * sin(arc)
	_sun.basis = Basis.looking_at(-from)
	_sun.light_color = _sun.light_color.lerp(Color("#a9bdff"), n)  # cool silver moonlight
	_env.background_color = Color(Scenery.t().backdrop).lerp(Color("#d9c9cc"), t).lerp(Color("#161b34"), n)
	_env.ambient_light_color = Color("#ece0dc").lerp(Color("#d9bfd0"), t).lerp(Color("#6f80b8"), n)  # deep blue shade
	_env.ambient_light_energy = lerpf(0.62, 0.5, n)
	_env.tonemap_exposure = lerpf(1.12, 1.0, n)
	_sun.light_energy = lerpf(lerpf(SUN_ENERGY.x, SUN_ENERGY.y, t), 0.42, n)
	for l in _sconces:  # practical lights come up as the sun goes down, and glow warm all night
		l.light_energy = float(l.get_meta("full", 0.45)) * lerpf(lerpf(0.35, 1.0, t), 1.7, n)


func popup(text: String, at: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.outline_size = 20
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_modulate = Color(Build.PAPER)
	l.position = at
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", at.y + 1.3, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- the day

## Days are the same length; they get busier and less forgiving (Town).
func day_length() -> float:
	return Town.DAY_LENGTH


func table_patience() -> float:
	return Town.table_patience(ledger.day)


func day_progress() -> float:
	return clampf(clock / day_length(), 0.0, 1.0) if phase == Phase.SERVICE else 1.0


func start_day() -> void:
	if phase == Phase.CLOSED:
		return
	ready_chefs.clear()
	for ch in chefs:
		if ch.hand.get("moving", false):
			cancel_hand(ch)   # a piece still being carried goes back where it was
		ch.hand = {}
	phase = Phase.SERVICE
	clock = 0.0
	shopper = null
	upgrading = false
	set_door(true)
	hud.close_menu()
	close_desk()
	_clear_applicants()
	hud.hide_card()
	hud.hide_build()
	ledger.pay_stock(night_cost())   # the door checked it can be paid (tests may skip the door)
	floor_dirt.mess.treat = treat_active()   # tonight's laying lasts the day (PRD 9.5)
	floor_dirt.mess.extractor = kitchen.has_extractor()
	clean_kit.start_day()
	floor_dirt.redraw()
	pay_staff()
	menu_board.refresh(tonight_menu())
	town.new_day()
	var coming := town.roll_guests(ledger.day, (Town.FLYER_BOOST if flyers_out else 0.0) + critic.visit_boost(ledger.day))
	coming = coming.filter(func(i: int) -> bool: return staff.may_visit(i, ledger.day))   # staff work; they eat out only on a day off
	var critic_day := critic.visits_on(ledger.day)
	if critic_day:   # they come alone, whatever the dice or a grudge say
		coming.erase(critic.critic_idx)
	var groups := town.make_groups(coming, max_party(), ledger.day)
	var flyered := flyers_out
	flyers_out = false
	arrivals.clear()
	critic_guest = null
	_critic_seen = {}
	_critic_rated = {}
	for i in groups.size():
		var t := 2.0 + (i + town.rng.randf() * 0.6) * (day_length() - 2.0) / groups.size()
		arrivals.append({"time": t, "group": groups[i]})
	if critic_day:
		_book_critic(critic.arrival_time(day_length()))
	crew.start_day()   # staff at work today walk in as the door opens (PRD 10.6)
	play_music("day")
	hud.show_banner("Day %d" % ledger.day)
	hud.say(("%d guests expected today." % coming.size()) + (" The flyers worked." if flyered else ""))
	sfx("day")


## Puts the critic in today's arrivals at `time`, in order. Nothing shows it.
func _book_critic(time: float) -> void:
	var k := 0
	while k < arrivals.size() and float(arrivals[k].time) <= time:
		k += 1
	arrivals.insert(k, {"time": time, "group": [critic.critic_idx], "critic": true})


## Whether `g` is the critic (on any day; the interface marks them only once known).
func is_critic(g: Guest) -> bool:
	return g != null and g.idx == critic.critic_idx


## The critic is leaving: rates the visit from what they saw. Printed at the end of the day.
func _critic_leaves(g: Guest, walked: bool) -> void:
	if g != critic_guest or not _critic_rated.is_empty():
		return
	walked = walked or g.mood.disgust_level() >= 3
	_critic_rated = {"walked": walked, "ratings": Critic.rate(float(_critic_seen.get("patience", 0.0)),
		float(_critic_seen.get("quality", -1.0)), g.mood.disgust, g.mood.disgust_level(), tonight_menu(), walked, critic.strictness())}
	g.mood.think(Critic.thought("leave"))
	critic_guest = null


## Opens the guest card for `g`, or closes it with null.
func inspect(g: Guest) -> void:
	inspected = g
	hud.show_guest(g)


## The guest drawn nearest a point on screen, or null if none is close.
func guest_at(screen: Vector2, within := 60.0) -> Guest:
	var best: Guest = null
	for g in guests:
		var d := cam.unproject_position(g.position + Vector3(0, 0.8, 0)).distance_to(screen)
		if d < within:
			within = d
			best = g
	return best


# ---------------------------------------------------------------- building

## Night 0: the game opens with the door card on CLOSED and the room to set up.
## Nothing has been played yet, so there is no receipt; day 1 starts at the door.
func _open_first_night() -> void:
	phase = Phase.BUILD
	door_open = false
	_door_turn.rotation.y = PI
	play_music("night")
	hud.show_build()
	hud.say("The night before day 1. Set up the kitchen, then flip the door card.")
	autosave()


## A saved game comes back on the night it was saved: the room to tend, the door closed.
func _open_night() -> void:
	phase = Phase.BUILD
	door_open = false
	_door_turn.rotation.y = PI
	play_music("night")
	roll_applicants()
	hud.show_build()
	hud.say("Welcome back. Day %d is tomorrow: set up the kitchen, then flip the door card." % ledger.day)


## Writes the saved game. Skipped when the game runs headless on the real save's path
## (the tests set their own).
func autosave() -> void:
	if DisplayServer.get_name() == "headless" and save_path == SaveGame.PATH:
		return
	SaveGame.write(SaveGame.capture(self), save_path)


## Continue on the title screen: the saved game, loaded into a fresh scene.
func continue_game() -> void:
	if phase != Phase.TITLE:
		return
	var data := SaveGame.read(save_path)
	if data.is_empty():
		return
	_resume_data = data
	Scenery.theme_id = SaveGame.theme_of(data)
	_kept_seats = controls.seats.duplicate()
	get_tree().paused = false
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().call_deferred("reload_current_scene")


## Quit to title from the pause menu: back to the first screen of a fresh launch.
func quit_to_title() -> void:
	_theme_picked = false
	_title_seen = false
	_kept_seats = controls.seats.duplicate()
	get_tree().paused = false
	get_tree().reload_current_scene()


## The title screen over the room, before the night before day 1.
func open_title() -> void:
	_title_seen = true
	phase = Phase.TITLE
	door_open = false
	_door_turn.rotation.y = PI
	play_music("title")
	hud.show_title()


## Play on the title screen: the theme card, unless REGULARS_THEME already chose.
func play() -> void:
	if phase != Phase.TITLE:
		return
	if theme_forced():
		_theme_picked = true
		hud.hide_title()
		_open_first_night()
		return
	hud.title.show_themes()


## REGULARS_THEME is set: a developer's switch that skips the theme card.
static func theme_forced() -> bool:
	return OS.get_environment("REGULARS_THEME") != ""


## The theme picked last time (to preselect on the card), or the current one.
func remembered_theme() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(theme_path) == OK:
		var id := str(cfg.get_value("run", "theme", ""))
		if Scenery.THEMES.has(id):
			return id
	return Scenery.theme_id


## A theme picked on the card: it holds for the run. The room is built for a theme,
## so a different one reloads the scene, which then opens straight on the night
## before day 1; the same one carries on in place.
func choose_theme(id: String) -> void:
	if phase != Phase.TITLE or not Scenery.THEMES.has(id):
		return
	var cfg := ConfigFile.new()
	cfg.set_value("run", "theme", id)
	cfg.save(theme_path)
	_theme_picked = true
	var rebuild := id != Scenery.theme_id
	Scenery.theme_id = id
	if rebuild and is_inside_tree() and get_tree().current_scene == self:
		_kept_seats = controls.seats.duplicate()
		get_tree().call_deferred("reload_current_scene")
		return
	hud.hide_title()
	_open_first_night()


## Quit on the title screen (not offered on phones or the web).
func quit_game() -> void:
	quit_asked = true
	if allow_quit:
		get_tree().quit()


## After the receipt: the room is yours to walk round and change, until you flip
## the door card to open for the day.
func open_build() -> void:
	if phase != Phase.SUMMARY:
		return
	phase = Phase.BUILD
	ready_chefs.clear()
	hud.hide_card()
	if Staff.week_day(ledger.day) == 0:   # a new week: everyone picks their days off (PRD 10.4)
		staff.start_week(ledger.day)
	roll_applicants()
	hud.show_build()
	autosave()   # the night's start: where Continue picks up


## What the shop lists for a search and a category tab: the catalog, the laying tool of
## each floor treatment with its box stored (PRD 9.5) under Build, and the flyers under Extras.
func shop_items(query := "", category := "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if storing():   # the storage card: what is stored here, then every box there is
		for box: String in kitchen.stock(storing_cell):
			found.append({"id": box, "tier": 1, "stored": true})
		for bp in Catalog.search(query, "Pantry", Scenery.theme_id, ledger.level()):
			if not kitchen.stock(storing_cell).has(bp.id):
				found.append(bp)
		found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:   # what fits first
			return _storage_rank(a) < _storage_rank(b))
		return found
	if category == "Favourites":
		return favourite_items(query)
	if category != "Extras":
		found = Catalog.search(query, category, Scenery.theme_id, ledger.level())
		for bp in Catalog.search(query, category, Scenery.theme_id):   # a missing essential, at any level
			if missing(bp.id) and not found.has(bp):
				found.append(bp)
	if category == "" or category == "Build":
		for k: String in Treatments.ITEMS:
			var id := Treatments.tool_id(k)
			if not treat_boxed().has(k):
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
			found.append(FLYERS)
	return found


func open_shop(ch: Player = null) -> void:
	ch = _me(ch)
	if phase != Phase.BUILD:
		return
	if shopping:   # one shop for everyone: the other player's Shop does nothing
		if shopper != ch:
			hud.say("Chef %d is shopping." % (chefs.find(shopper) + 1))
		return
	if Cleaning.carrying_mess(ch.held):
		sfx("fail")
		hud.say(Cleaning.HANDS_FULL)
		return
	if ch.hand.get("moving", false):   # a piece in hand: its upgrade tree instead (PRD 8.3)
		var key := hand_key(ch)
		if not Upgrades.has_tree(key):
			sfx("fail")
			hud.say("Nothing to upgrade the %s to. Put it down to shop." % piece_name(ch.hand).to_lower())
			return
		shopper = ch
		upgrading = true
		sfx("slide")
		hud.show_tree(key)
		return
	shopper = ch
	sfx("slide")
	hud.show_shop()


func close_shop() -> void:
	if not shopping:
		return
	var ch := shopper
	var carried: Dictionary = ch.hand.duplicate() if ch.hand.get("carry", false) else {}
	if not carried.is_empty():
		_settle(ch)
	if upgrading and shopper.hand.get("in_place", false):
		shopper.hand = {}   # upgraded where it stands: nothing was lifted
	storing_cell = NO_CELL
	shopper = null
	sfx("slide", 0.0, 0.8)
	if upgrading:
		upgrading = false
		hud.hide_tree()
	else:
		hud.hide_shop()
	if not carried.is_empty():   # Tab or Esc: the piece stays in hand to carry elsewhere
		pick_up(Grid.center(Vector2i(carried.from.x, carried.from.y)), ch, true, str(carried.layer))


# ---------------------------------------------------------------- favourites

func load_favourites() -> void:
	favourites.clear()
	var cfg := ConfigFile.new()
	if cfg.load(fav_path) == OK:
		for k in cfg.get_value("shop", "favourites", []):
			if Catalog.can_favourite(str(k)) and not favourites.has(str(k)):
				favourites.append(str(k))


func is_favourite(key: String) -> bool:
	return favourites.has(key)


## Stars or unstars a tree node. Returns whether it is a favourite now.
func toggle_favourite(key: String) -> bool:
	if not Catalog.can_favourite(key):
		sfx("fail")
		hud.say("Cleaning tools can't be favourites.")
		return false
	if favourites.has(key):
		favourites.erase(key)
	else:
		favourites.append(key)
	var cfg := ConfigFile.new()
	cfg.set_value("shop", "favourites", favourites.duplicate())
	cfg.save(fav_path)
	sfx("tick", 0.1)
	return favourites.has(key)


## The Favourites tab: each starred node this run's theme sells, at the level reached.
func favourite_items(query := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var words := query.strip_edges().to_lower().split(" ", false)
	for k: String in favourites:
		var bp := Catalog.fav_blueprint(k)
		if not Catalog.sold_in(bp.id, Scenery.theme_id) or Catalog.bp_level(bp) > ledger.level():
			continue
		var text := ("%s favourite %s" % [Catalog.label(bp), Catalog.bp_blurb(bp)]).to_lower()
		var hit := true
		for w in words:
			hit = hit and text.contains(w)
		if hit:
			out.append(bp)
	return out


## Picks a favourite to place, already upgraded. Nothing is paid until it is placed.
func pick_favourite(bp: Dictionary, ch: Player = null) -> bool:
	ch = _me(ch)
	if ledger.money < Catalog.bp_price(bp) or Catalog.bp_level(bp) > ledger.level() \
			or not pick_catalog(bp.id, int(bp.tier), ch, bp.get("base", "")):
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
	ch = _me(ch)
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
	ch = shopper if ch == null and shopper != null else _me(ch)
	var from := hand_key(ch)
	var link := Upgrades.is_link(to)   # a stove grown on a counter where it stands
	if link and not (ch.hand.get("in_place", false) and ch.hand.node is Station and (ch.hand.node as Station).item == ""):
		sfx("fail")
		hud.say("Put the counter down first, then upgrade it where it stands.")
		return false
	if phase != Phase.BUILD or from == "" or not Upgrades.can_buy(from, to, ledger.money, ledger.level()) \
			or not ledger.spend(Upgrades.step_price(to)):
		sfx("fail")
		return false
	if link:
		var under: Station = ch.hand.node
		var cell := under.cell
		var facing := under.facing
		close_shop()   # the counter settles; the card and its tree shut
		var top := add_station(to, cell, 1, facing)
		_bought_tonight(top, Upgrades.step_price(to))
		burst(Grid.center(cell) + Vector3(0, 1.0, 0), "stars", 0.4)
		hud.say("The counter is a %s now. Open it with E to upgrade it further." % Upgrades.name_of(to).to_lower())
		menu_changed()
		sfx("coin")
		return true
	if Upgrades.is_treatment(to):   # a box: it is the new treatment's now (PRD 9.5)
		ch.hand.id = to
		_swap_treatment(Treatments.key_of(from), Treatments.key_of(to))
		sfx("coin")
		hud.show_build()
		return true
	var st: Station = ch.hand.node
	_bought_tonight(st, Upgrades.step_price(to))   # an upgrade bought tonight comes back whole too
	if ch.hand.get("in_place", false):   # the storage card: upgraded where it stands
		if Kitchen.is_tall(to) and kitchen.get_piece(st.cell, "high") != "":
			ledger.refund(Upgrades.step_price(to))
			st.set_meta("fresh", spent_tonight(st) - Upgrades.step_price(to))
			sfx("fail")
			hud.say("A tall fridge needs the wall above clear. Take down what hangs there first.")
			return false
		if Kitchen.is_top(st.type):   # a stove up its tree where it stands: made anew in place
			_remake_in_place(st, to, ch)
		else:
			st.set_base(to)
			kitchen.set_cell(st.cell, to)
		_show_boxes(st.cell)
		menu_changed()
		sfx("coin")
		return true
	if st.type == "hook" and Kitchen.tool_of(to) != "":   # the hook's tool is swapped
		clean_kit.upgrade_tool(st, Kitchen.tool_of(to))
		sfx("coin")
		hud.show_build()
		return true
	if Upgrades.is_tiered(to):
		st.tier = Upgrades.tier_of(to)
		st.set_base(st.base)   # redraws it at the new tier
		ch.hand.tier = st.tier
	elif st.type == "counter":
		st.set_base(to)
	else:   # a tool: it may now work as another (a stove into a fryer), so it is made anew
		var up := Station.new()
		add_child(up)
		up.setup(to, st.cell, st.tier, st.facing, st.base, st.pass_look)
		up.stacked = st.stacked
		up.visible = false
		_bought_tonight(up, spent_tonight(st))   # what was paid tonight goes with it
		clean_kit.upgrade_home(st, up, Kitchen.tool_of(to))   # a bucket's mop goes with it (PRD 9.5)
		st.queue_free()
		ch.hand.node = up
		ch.hand.id = up.type
	sfx("coin")
	hud.show_build()
	return true


## A stove (its counter upgraded) bought up its tree where it stands, its card open: it
## may now work as another piece (a fryer), so a new one takes its place, its counter's
## boxes, the till and what was paid tonight with it, and the hand holds the new one.
func _remake_in_place(st: Station, to: String, ch: Player) -> void:
	var held := kitchen.take_stock(st.cell)
	_unregister(st)
	var up := Station.new()
	add_child(up)
	up.setup(to, st.cell, st.tier, st.facing, st.base, st.pass_look)
	up.stacked = st.stacked
	var till := st.get_node_or_null("till")
	if till:
		till.reparent(up, false)
	_register(up)
	kitchen.give_stock(up.cell, held)
	up.position.y = st.position.y   # still lifted while its card is open
	_bought_tonight(up, spent_tonight(st))
	st.queue_free()
	ch.hand.node = up
	ch.hand.id = up.type


## A treatment's box upgraded: the cells laid with the old one are the new one's now.
func _swap_treatment(was: String, now: String) -> void:
	for c: Vector2i in treat_laid:
		if treat_laid[c] == was:
			treat_laid[c] = now
	if treat_off.has(was):
		treat_off.erase(was)
		treat_off[now] = true


# ---------------------------------------------------------------- the storage card

## Whether the tray open is a storage card rather than the shop.
func storing() -> bool:
	return shopping and storing_cell != NO_CELL


## The storage cell in front of a chef with empty hands: a bare counter (or its fridge
## line) or a piece on the wall that keeps boxes. A tool on a counter is picked up, so
## it is not one. NO_CELL if none.
func _storage_in_front(ch: Player) -> Vector2i:
	if not ch.hand.is_empty():
		return NO_CELL
	var c := ch.target_cell()
	if kitchen.slots(c) == 0 or (stations.has(c) and needs_cleaning(stations[c])):
		return NO_CELL
	var st: Station = stations.get(c)
	if st != null and not st.type in ["counter", "shelf"] and not Kitchen.grows_from_counter(st.node):
		return NO_CELL
	return c


## Opens the storage card on a cell: its boxes first, then its upgrades.
func open_storage(cell: Vector2i, ch: Player = null) -> bool:
	ch = _me(ch)
	if phase != Phase.BUILD or shopping or cell == NO_CELL or hud.card_open():
		return false
	shopper = ch
	storing_cell = cell
	sfx("slide")
	hud.show_shop()
	return true


## The tree key of the storage piece standing at the open card's cell ("" when it has
## no tree, or only a piece on the wall keeps boxes there).
func storage_tree() -> String:
	var st: Station = stations.get(storing_cell)
	if st == null or not (st.type == "counter" or Kitchen.grows_from_counter(st.node)) \
			or (shopper != null and shopper.hand.get("layer", "") == "high"):
		return ""
	var key := Upgrades.key_of(st.type, st.tier, st.base if st.type == "counter" else st.node)
	return key if Upgrades.has_tree(key) else ""


## The card's Upgrades tab: the tree of the piece where it stands, nothing lifted.
func storage_upgrades() -> void:
	var key := storage_tree()
	if key == "" or not storing():
		sfx("fail")
		return
	var ch := shopper
	var st: Station = stations[storing_cell]
	if not ch.hand.get("carry", false):
		ch.hand = {"id": st.type, "tier": st.tier, "price": 0, "facing": st.facing, "moving": true,
			"node": st, "in_place": true, "from": Vector3i(st.cell.x, st.cell.y, 0), "from_facing": st.facing}
	hud.hide_shop()
	upgrading = true
	sfx("tab", 0.08)
	hud.show_tree(key)


## Back from the Upgrades tab to the card's Ingredients.
func storage_ingredients() -> void:
	if not upgrading:
		return
	if not shopper.hand.get("carry", false):
		shopper.hand = {}
	upgrading = false
	hud.hide_tree()
	sfx("tab", 0.08)
	hud.show_shop()


## E on a piece in the build phase: it is picked up. A piece that keeps boxes (a counter,
## shelf, cabinet or fridge, PRD 8.4) rises where it stands with its storage card open:
## choose a box and E puts the piece back down with it in (`storage_put_down`); Tab or Esc
## keeps it in hand, its boxes with it, to carry elsewhere.
## `at`: a point on the piece (a mouse click); by default the one in front of the chef.
func lift(ch: Player = null, at := Vector3.INF) -> bool:
	ch = _me(ch)
	var p := _piece_in_front(ch) if at == Vector3.INF else at
	if p == Vector3.INF:
		return false
	var c := Grid.to_cell(p)
	var layer := _lift_layer(c, ch)
	var st: Station = highs.get(c) if layer == "high" else stations.get(c)
	if wall_nodes.has(snap_edge(p)) or st == null or not _keeps_boxes(st, layer) or needs_cleaning(st) \
			or shopping or hud.card_open() or not ch.hand.is_empty():
		return pick_up(p, ch, true)
	ch.set_meta("low_next", NO_CELL)
	ch.hand = {"id": st.type, "tier": st.tier, "price": 0, "facing": st.facing, "moving": true, "node": st,
		"in_place": true, "carry": true, "layer": layer, "y": st.position.y,
		"from": Vector3i(c.x, c.y, 0), "from_facing": st.facing}
	st.position.y += LIFT
	sfx("pickup")
	if not open_storage(c, ch):
		_settle(ch)
		return false
	return true


## Whether the piece E would lift there keeps boxes itself (a double counter being split
## does not: its boxes stay with the counter left standing).
func _keeps_boxes(st: Station, layer: String) -> bool:
	if layer == "base" and Kitchen.unstacked(st.base) != "" and st.stacked:
		return false
	return layer in ["base", "high"] and Kitchen.slots_of(kitchen.get_piece(st.cell, layer)) > 0


## Which piece on a cell E picks up: a tool off its counter, else what hangs on the wall,
## else what stands on the floor. Once a wall piece is put back where it was, the next E
## there takes what stands under it, so a sink under a shelf can be reached.
func _lift_layer(c: Vector2i, ch: Player) -> String:
	var st: Station = stations.get(c)
	if st != null and st.has_node("till"):
		return "till"   # the till comes off before what it stands on
	if st != null and Kitchen.is_top(st.type) and not Kitchen.grows_from_counter(st.node):
		return "top"   # a stove is its counter upgraded: it lifts whole
	if highs.has(c) and (st == null or ch.get_meta("low_next", NO_CELL) != c):
		return "high"
	return "base" if st != null else ""


## The name of what E would pick up, for the prompt ("Pick up sink").
func lift_name(ch: Player = null) -> String:
	ch = _me(ch)
	var p := _piece_in_front(ch)
	if p == Vector3.INF:
		return ""
	if wall_nodes.has(snap_edge(p)):
		return piece_name({"id": "screen", "tier": 1}).to_lower()
	var c := Grid.to_cell(p)
	if _lift_layer(c, ch) == "till":
		return "till"
	var st: Station = highs.get(c) if _lift_layer(c, ch) == "high" else stations.get(c)
	if st == null:
		return "rug"
	return piece_name({"id": st.type, "tier": st.tier}).to_lower()


## E on a lifted piece's card: the chosen box goes in (if it is not in already and
## fits), the piece settles back where it stood, and the card shuts.
func storage_put_down() -> void:
	var bp: Dictionary = hud.shop_selected()
	if not bp.is_empty() and not bp.get("stored", false):
		if kitchen.store_refusal(storing_cell, bp.id) != "" or not _storage_buy(bp):
			hud.shop_buy()   # shakes it, with the reason on the card
			return
	_settle(shopper)
	sfx("putdown")
	close_shop()


## A piece lifted for its card comes down where it stood, nothing moved.
func _settle(ch: Player) -> void:
	var n: Variant = ch.hand.get("node")
	if n is Node3D and is_instance_valid(n):
		(n as Node3D).position.y = float(ch.hand.get("y", (n as Node3D).position.y))
	if ch.hand.get("layer", "") == "high":
		ch.set_meta("low_next", Vector2i(ch.hand.from.x, ch.hand.from.y))
	ch.hand = {}


## Ranks a box on the card: stored here, then ones that fit, then ones that do not.
func _storage_rank(bp: Dictionary) -> int:
	if bp.get("stored", false):
		return 0
	return 1 if kitchen.store_refusal(storing_cell, bp.id) == "" else 2


## Takes a box out of the open card's cell, or puts one in. The card stays open.
func _storage_buy(bp: Dictionary) -> bool:
	var ok := false
	if bp.get("stored", false):
		ok = kitchen.unstore(storing_cell, bp.id)
	else:
		ok = _store_box(storing_cell, bp.id)
	if not ok:
		sfx("fail")
		return false
	_show_boxes(storing_cell)
	var st := station_at(storing_cell)
	if st:
		st.used()   # a fridge or cabinet swings its door open
	menu_changed()
	sfx("putdown")
	hud._refresh_catalog()
	return true


## Buys what the shop is showing. Flyers are paid for at once; a piece goes into
## the hands of the chef whose player is shopping, and the shop shuts, so it can
## be carried to its place.
func buy(bp: Dictionary) -> bool:
	if storing():
		return _storage_buy(bp)
	if bp.id == FLYERS.id:
		if buy_flyers():
			return true
	elif pick_favourite(bp, shopper) if bp.has("fav") else pick_catalog(bp.id, int(bp.tier), shopper, bp.get("base", "")):
		sfx("pickup")
		close_shop()
		return true
	sfx("fail")
	return false


## Picks a piece from the catalog to place. Nothing is paid until it is placed.
## `base` is a tree node the shop sells outright (a counter already a fridge).
func pick_catalog(id: String, tier := 1, ch: Player = null, base := "") -> bool:
	ch = _me(ch)
	var bp := Catalog.node_blueprint(base) if base != "" else {"id": id, "tier": tier}
	if phase != Phase.BUILD or Cleaning.carrying_mess(ch.held) or not catalog.can_buy(id, ledger.money, buy_level(id), tier) \
			or ledger.money < Catalog.bp_price(bp) or not Catalog.sold_in(id, Scenery.theme_id):
		return false
	if id == "till" and till_station() != null:
		hud.say("One till is enough. Pick it up with E to move it.")
		return false
	if ch.hand.get("moving", false):
		cancel_hand(ch)
	ch.hand = {"id": id, "tier": tier, "price": Catalog.bp_price(bp), "facing": 0}
	if base != "":
		ch.hand.base = base
	hud.show_build()
	return true


## Puts down whatever is in hand: a new piece is dropped, a moved one goes back.
func cancel_hand(ch: Player = null) -> void:
	ch = _me(ch)
	ch.drag = {}
	if ch.hand.get("moving", false):
		_put_down(ch.hand, ch.hand.from, int(ch.hand.from_facing))
	ch.hand = {}
	if phase == Phase.BUILD:
		hud.show_build()


## The level the shop sells a piece at: any, while the kitchen has none of an essential.
func buy_level(id: String) -> int:
	return 999 if missing(id) else ledger.level()


## Whether the kitchen is without one of its essentials (a sink, a bin, a plate stack).
func missing(id: String) -> bool:
	if id == "till":
		return till_station() == null
	return id in ESSENTIALS and find_station(id) == null


static func piece_name(bp: Dictionary) -> String:
	return Catalog.label(bp) if Catalog.ITEMS.has(bp.id) else str(PIECE_NAMES.get(bp.id, bp.id))


## Picks up the piece standing at a point on the floor, to move, turn or sell it.
## `whole`: a piece that keeps boxes is lifted with them, rather than its boxes one by one.
## `layer` names the piece to lift on a cell ("high" or "base"); by default `_lift_layer`.
func pick_up(p: Vector3, ch: Player = null, whole := false, layer := "") -> bool:
	ch = _me(ch)
	if phase != Phase.BUILD or not ch.hand.is_empty() or Cleaning.carrying_mess(ch.held) or CleanKit.holding(ch):
		return false   # hands full: a bag, a plate, a mop (PRD 9.4)
	var c := Grid.to_cell(p)
	var edge := snap_edge(p)
	if layer == "":
		layer = _lift_layer(c, ch)
	ch.set_meta("low_next", NO_CELL)
	var carried: Array = []
	if layer == "till" and stations.has(c) and stations[c].has_node("till"):
		var till: Node3D = stations[c].get_node("till")
		till.reparent(self, false)   # off its counter: while carried, there is no till
		till.visible = false
		ch.hand = {"id": "till", "tier": 1, "price": 0, "facing": 0, "moving": true, "node": till,
			"from": Vector3i(c.x, c.y, 0), "from_facing": 0}
		sfx("pickup")
		hud.show_build()
		return true
	if stations.has(c) and needs_cleaning(stations[c]):
		sfx("fail")   # a messy piece is not moved or sold until it is clean
		hud.say(Cleaning.CLEAN_FIRST)
		return false
	if stations.has(c) or highs.has(c):
		var st: Station = stations.get(c)
		if st != null and Kitchen.is_top(st.type) and not Kitchen.grows_from_counter(st.node):
			_off_counter(st)   # the tool comes off first; its counter stays
		elif not whole and not kitchen.stock(c).is_empty():
			# Then the boxes, last in first; the counter only once it is empty (PRD 8.4).
			var box: String = kitchen.stock(c).back()
			kitchen.unstore(c, box)
			_show_boxes(c)
			ch.hand = {"id": box, "tier": 1, "price": 0, "facing": 0, "moving": true,
				"from": Vector3i(c.x, c.y, 0), "from_facing": 0}
			sfx("pickup")
			menu_changed()
			return true
		elif highs.has(c) and layer == "high":
			# Then what hangs on the wall (PRD 8.5), before what stands under it.
			st = highs[c]
			highs.erase(c)
			carried = kitchen.remove(c, "high").get("stock", [])
			_show_boxes(c)
		elif Kitchen.unstacked(st.base) != "" and st.stacked:
			# One counter comes off a double counter; the other stays with what is on it.
			st.set_base(Kitchen.unstacked(st.base))
			st.stacked = false
			kitchen.set_cell(c, st.base)
			var moved := mini(spent_tonight(stations[c]), Kitchen.price_of("counter"))   # tonight's counter comes off first
			if moved > 0:
				stations[c].set_meta("fresh", spent_tonight(stations[c]) - moved)
			st = Station.new()
			add_child(st)
			st.setup("counter", c, 1, stations[c].facing)
			_bought_tonight(st, moved)
		else:
			if whole and st.base != "":
				carried = (kitchen.take_stock(c).get("base", []) as Array).duplicate()
			_unregister(st)
		st.visible = false
		ch.hand = {"id": st.type, "tier": st.tier, "price": 0, "facing": st.facing, "moving": true,
			"node": st, "from": Vector3i(c.x, c.y, 0), "from_facing": st.facing, "layer": "high" if st.high else ""}
		if not carried.is_empty():
			ch.hand.stock = carried
			menu_changed()
	elif wall_nodes.has(edge):
		var n: Node3D = wall_nodes[edge]
		wall_nodes.erase(edge)
		grid.walls.erase(edge)
		n.visible = false
		ch.hand = {"id": "screen", "tier": int(n.get_meta("tier", 1)), "price": 0, "facing": 0, "moving": true,
			"node": n, "from": edge, "from_facing": 0}
	elif rug_at(c) != null:   # a rug is picked up last: whatever stands on it comes first
		var n := rug_at(c)
		var anchor: Vector2i = rugs.find_key(n)
		rugs.erase(anchor)
		n.visible = false
		var f := int(n.get_meta("facing", 0))
		ch.hand = {"id": "rug", "tier": 1, "price": 0, "facing": f, "moving": true,
			"node": n, "from": Vector3i(anchor.x, anchor.y, 0), "from_facing": f}
	else:
		return false
	sfx("pickup")
	hud.show_build()
	return true


## Stands the carried piece on a spot. No checks: callers have made them.
func _put_down(h: Dictionary, spot: Vector3i, facing: int) -> void:
	if Catalog.is_box(h.id):
		_store_box(Vector2i(spot.x, spot.y), h.id)
		return
	var n: Node3D = h.node
	n.visible = true
	var cell := Vector2i(spot.x, spot.y)
	if h.id == "till":
		n.reparent(_till_host(cell), false)
		return
	var hn := hand_node(h)
	if n is Station and Kitchen.can_go_high(hn):
		var layer := layer_for(cell, hn)
		if h.get("from", Vector3i(0, 0, -1)) == spot and h.get("layer", "") == "high" and kitchen.can_hang(cell, hn):
			layer = "high"   # put back where it hung
		if layer == "high":
			_hang(n, cell)
			if h.get("from", Vector3i(0, 0, -1)) == spot:
				for ch: Player in chefs:   # put back where it hung: E next takes what is under it
					if ch.hand.get("node") == n:
						ch.set_meta("low_next", cell)
			_restock(h, cell)
			return
	if h.id == "screen":
		grid.walls[spot] = true
		wall_nodes[spot] = n
		_place_on_edge(n, spot)
	elif h.id == "rug":
		_lay_rug(n, Vector2i(spot.x, spot.y), facing)
	elif _bare_counter(Vector2i(spot.x, spot.y)) != null and Kitchen.is_top(h.id):
		_onto_counter(n, Vector2i(spot.x, spot.y), facing)
	elif _bare_counter(Vector2i(spot.x, spot.y)) != null and Kitchen.is_counter(h.id):
		_stack_counter(Vector2i(spot.x, spot.y))
		n.queue_free()
	else:
		(n as Station).place_at(Vector2i(spot.x, spot.y), facing)
		_register(n)
	_restock(h, cell)


## The boxes a piece was carried with go into its new place; any that will not fit
## there are left out, and the player is told which.
func _restock(h: Dictionary, cell: Vector2i) -> void:
	var boxes: Array = h.get("stock", [])
	if boxes.is_empty():
		return
	var left: Array[String] = []
	for box: String in boxes:
		if not kitchen.store(cell, box):
			left.append(Catalog.label({"id": box, "tier": 1}))
	_show_boxes(cell)
	menu_changed()
	if not left.is_empty():
		hud.say("No room here for %s: left out." % ", ".join(left))


## Puts a box of stock in a cell's storage: that kind is stocked from tonight (PRD 8.4).
func _store_box(cell: Vector2i, box: String) -> bool:
	if not kitchen.store(cell, box):
		return false
	_show_boxes(cell)
	menu_changed()
	return true


## A counter placed on a bare counter: the two make a double counter.
func _stack_counter(cell: Vector2i) -> void:
	var under := _bare_counter(cell)
	kitchen.place(cell, "counter")
	under.set_base(kitchen.get_piece(cell, "base"))
	under.stacked = true


## Turns the piece in hand a quarter turn. Partitions turn by where you point.
func rotate_hand(ch: Player = null) -> void:
	ch = _me(ch)
	if Treatments.is_laying_tool(ch.hand.get("id", "")):   # a treatment's laying tool: turn switches it off or on
		var k := Treatments.key_of(ch.hand.id)
		switch_treatment(k, treat_off.has(k))
		sfx("pickup")
		hud.show_build()
		return
	if not ch.hand.is_empty() and not on_edge(ch.hand.id) and not Catalog.is_build_tool(ch.hand.id) \
			and not Kitchen.is_high_only(hand_node(ch.hand)):   # a hung piece faces off its wall
		ch.hand.facing = (int(ch.hand.facing) + 1) % 4
		if ch.hand.get("carry", false) and ch.hand.get("node") is Station:   # lifted in place: turn it now
			var st: Station = ch.hand.node
			st.place_at(st.cell, int(ch.hand.facing))
			st.position.y = float(ch.hand.get("y", 0.0)) + LIFT
		sfx("pickup")


## What selling the carried piece pays: half its catalog price, or 0 if not for sale.
func sell_value(ch: Player = null) -> int:
	ch = _me(ch)
	if not ch.hand.get("moving", false) or not Catalog.ITEMS.has(ch.hand.id):
		return 0
	var key := hand_key(ch)
	var whole := Upgrades.price(key) if key != "" else Catalog.price_of(ch.hand.id, int(ch.hand.tier))   # upgrades and all
	var hs: Variant = ch.hand.get("node")
	if hs is Station and Kitchen.grows_from_counter((hs as Station).node):
		whole += Kitchen.price_of((hs as Station).base)   # a stove sells with the counter it grew from
	var fresh := mini(spent_tonight(ch.hand.get("node")), whole)
	return (whole - fresh) / 2 + fresh   # half back, but what was bought tonight comes back whole


## Same-night returns: what was paid tonight for a piece (bought or upgraded since the
## last day ended) is paid back in full if it is sold before the door opens.
func _bought_tonight(n: Object, amount: int) -> void:
	if n == null or amount <= 0:
		return
	n.set_meta("fresh", spent_tonight(n) + amount)
	n.set_meta("fresh_night", ledger.day)


func spent_tonight(n: Variant) -> int:
	if not (n is Object) or n == null or int(n.get_meta("fresh_night", -1)) != ledger.day:
		return 0
	return int(n.get_meta("fresh", 0))


## Why the carried piece cannot be sold; empty when it can.
func sell_block(ch: Player = null) -> String:
	ch = _me(ch)
	if not ch.hand.get("moving", false):
		return "Nothing picked up"
	if not Catalog.ITEMS.has(ch.hand.id):
		return "The %s is not for sale" % piece_name(ch.hand).to_lower()
	if ch.hand.id == "desk" and not staff.can_sell_desk(desk_count() + 1):
		return "Every desk has a post or a hire"
	return ""


func sell_hand(ch: Player = null) -> bool:
	ch = _me(ch)
	if phase != Phase.BUILD or sell_block(ch) != "":
		return false
	ledger.refund(sell_value(ch))
	if Catalog.is_box(ch.hand.id):   # a box sold: its kind is no longer stocked
		ch.hand = {}
		sfx("coin")
		menu_changed()
		hud.show_build()
		return true
	var n: Node3D = ch.hand.node
	if n is Station and (n as Station).lamp:
		_sconces.erase((n as Station).lamp)
		(n as Station).lamp.queue_free()
	n.queue_free()
	var had_boxes := not (ch.hand.get("stock", []) as Array).is_empty()
	ch.hand = {}
	if had_boxes:
		menu_changed()
	sfx("coin")
	hud.show_build()
	return true


## The cell edge nearest a point on the floor: (x, y, axis).
static func snap_edge(p: Vector3) -> Vector3i:
	var c := Grid.to_cell(p)
	var fx := p.x - c.x
	var fz := p.z - c.y
	if minf(fz, 1.0 - fz) < minf(fx, 1.0 - fx):
		return Vector3i(c.x, c.y + (1 if fz > 0.5 else 0), 0)
	return Vector3i(c.x + (1 if fx > 0.5 else 0), c.y, 1)


## Where the piece in hand would go for a point on the floor: (x, y, axis).
## Furniture snaps to the cell (axis 0); a partition snaps to the nearest cell edge.
func snap(p: Vector3, ch: Player = null) -> Vector3i:
	ch = _me(ch)
	if on_edge(ch.hand.get("id", "")):
		return snap_edge(p)
	var c := Grid.to_cell(p)
	return Vector3i(c.x, c.y, 0)


## Pieces that sit on a cell edge rather than in a cell.
static func on_edge(id: String) -> bool:
	return id == "screen" or id == "wall" or id == "door" or id == "arch" or Catalog.is_finish(id)


## Groups the build tools: "floor" for every floor, "finish" for paint and paper,
## else the id itself.
static func tool_kind(id: String) -> String:
	if floor_kind(id) != "":
		return "floor"
	if Treatments.is_laying_tool(id):
		return "treat"   # a floor treatment (PRD 9.5)
	return "finish" if Catalog.is_finish(id) else id


## The six cells a rug covers: three across the anchor cell and three more one
## row on, toward `facing` (0 is +z, 1 is +x, 2 is -z, 3 is -x).
static func rug_cells(anchor: Vector2i, facing: int) -> Array[Vector2i]:
	var d: Vector2i = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)][posmod(facing, 4)]
	var across := Vector2i(absi(d.y), absi(d.x))
	var out: Array[Vector2i] = []
	for j in 2:
		for i in range(-1, 2):
			out.append(anchor + across * i + d * j)
	return out


## The rug lying on a cell, or null.
func rug_at(c: Vector2i) -> Node3D:
	for a: Vector2i in rugs:
		if rug_cells(a, int(rugs[a].get_meta("facing", 0))).has(c):
			return rugs[a]
	return null


func add_rug(anchor: Vector2i, facing := 0) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	Scenery.rug(n)
	_lay_rug(n, anchor, facing)
	return n


func _lay_rug(n: Node3D, anchor: Vector2i, facing: int) -> void:
	n.set_meta("facing", facing)
	n.position = Grid.center(anchor)
	n.rotation.y = facing * PI / 2
	rugs[anchor] = n


## A rug fits where all six cells have floor, no other rug and no wall between them.
func can_lay_rug(anchor: Vector2i, facing: int) -> bool:
	var cells := rug_cells(anchor, facing)
	for c in cells:
		if not plan.has_floor(c) or rug_at(c) != null:
			return false
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if cells.has(c + d):
				var e := Grid.edge_between(c, c + d)
				if plan.is_wall(e) or wall_nodes.has(e):
					return false
	return true


## The floor kind a floor tool lays, or "".
static func floor_kind(id: String) -> String:
	return id.trim_prefix("floor_") if id.begins_with("floor_") else ""


## Everyone who must still be able to get about after a change: the chef, every
## seat (must_reach) and a side of every station (must_touch).
func _reach() -> Array[Vector2i]:
	var reach: Array[Vector2i] = []
	for ch in chefs:   # every chef must still be able to get about
		reach.append(ch.cell())
	reach.assign(reach + grid.reserved.keys())
	return reach


func _touch() -> Array[Vector2i]:
	var touch: Array[Vector2i] = []
	touch.assign(stations.keys())
	return touch


## Would the piece in hand fit at this spot without cutting anyone off?
func can_place(spot: Vector3i, ch: Player = null) -> bool:
	ch = _me(ch)
	if ch.hand.is_empty():
		return false
	var cell := Vector2i(spot.x, spot.y)
	if Catalog.is_box(ch.hand.id):   # a box goes into a free storage slot that takes it
		return kitchen.can_store(cell, ch.hand.id)
	var reach := _reach()
	var touch := _touch()
	match tool_kind(ch.hand.id):
		"floor":   # floor laid behind a wall takes the wall away: not from under a hung piece
			return plan.can_lay(cell, floor_kind(ch.hand.id)) \
				and (plan.has_floor(cell) or not _strands_high(Floorplan.cell_edges(cell)))
		"finish":
			return plan.can_finish(spot, ch.hand.id)
		"treat":   # any floor, one treatment a cell: a new one replaces the old
			return plan.has_floor(cell) and treat_laid.get(cell, "") != Treatments.key_of(ch.hand.id)
		"rug":
			return can_lay_rug(cell, int(ch.hand.facing))
		"wall":
			return plan.can_build(spot) and grid.can_place_wall(spot, LOT, DOOR, reach, touch)
		"door", "arch":
			return plan.can_open(spot, ch.hand.id) and not _strands_high([spot])
	if ch.hand.id == "screen":
		return grid.can_place_wall(spot, LOT, DOOR, reach, touch) and not plan.is_wall(spot)
	if ch.hand.id == "till":   # on a counter, or a tool standing on one
		return _till_host(cell) != null
	var hn := hand_node(ch.hand)
	if Kitchen.can_go_high(hn):   # the wall layer (PRD 8.5): hung high, or a shelf low
		var layer := layer_for(cell, hn)
		if layer != "base":
			return layer == "high"
	elif Kitchen.is_tall(hn) and kitchen.get_piece(cell, "high") != "":
		return false   # a tall piece fills both wall layers
	if Kitchen.grows_from_counter(hand_node(ch.hand)):   # a stove is its counter upgraded: the floor only
		return not stations.has(cell) and kitchen.layer_for(cell, "counter") == "base" \
			and grid.can_place_block(cell, Station.seats_for("counter", cell, int(ch.hand.facing)), LOT, DOOR, reach, touch)
	if stations.has(cell) or Kitchen.is_top(ch.hand.id):
		return _stacks_on(cell, ch.hand)   # a tool needs a counter under it
	return grid.can_place_block(cell, Station.seats_for(ch.hand.id, cell, int(ch.hand.facing)), LOT, DOOR, reach, touch)


## Builds the piece in hand and pays for it, so cancelling before this is free.
## A new piece stays in hand for another while there is money for it; a moved
## piece is put down for nothing.
func place(spot: Vector3i, ch: Player = null) -> bool:
	ch = _me(ch)
	if phase != Phase.BUILD or not can_place(spot, ch):
		return false
	if Catalog.is_build_tool(ch.hand.id):
		if not _build_at(spot, ch):
			return false
		_plan_changed()
		sfx("putdown")
		_after_building(ch)
		return true
	var cell := Vector2i(spot.x, spot.y)
	if ch.hand.get("moving", false):
		_put_down(ch.hand, spot, int(ch.hand.facing))
		ch.hand = {}
		sfx("putdown")
		hud.show_build()
		return true
	if not ledger.spend(int(ch.hand.price)):
		return false
	if Catalog.is_box(ch.hand.id):
		_store_box(cell, ch.hand.id)
		ch.hand = {}   # one box a kind: hands are free again
		sfx("putdown")
		hud.show_build()
		return true
	var paid := int(ch.hand.price)
	if ch.hand.id == "screen":
		var n := add_wall(cell, spot.z, 0.9 + 0.1 * int(ch.hand.tier))
		n.set_meta("tier", int(ch.hand.tier))
		wall_nodes[spot] = n
		_bought_tonight(n, paid)
	elif ch.hand.id == "rug":
		add_rug(cell, int(ch.hand.facing))
		_bought_tonight(rug_at(cell), paid)
	elif ch.hand.id == "till":
		Build.register(_till_host(cell))
		_bought_tonight(stations[cell].get_node("till"), paid)
	elif Kitchen.is_counter(ch.hand.id) and ch.hand.get("base", "") == "" and _bare_counter(cell) != null:
		_bought_tonight(_bare_counter(cell), paid)
		_stack_counter(cell)
	elif layer_for(cell, hand_node(ch.hand)) == "high":
		var hung := add_high(hand_node(ch.hand) if ch.hand.id == "sponge" else str(ch.hand.get("up", ch.hand.id)), cell)
		_bought_tonight(hung, paid)
		clean_kit.on_built(hung, ch.hand.id)
	else:
		var st := add_station(str(ch.hand.get("up", ch.hand.id)), cell, int(ch.hand.tier), int(ch.hand.facing), ch.hand.get("base", ""))
		_bought_tonight(st, paid)
		clean_kit.on_built(st, ch.hand.id)
	burst(Grid.center(cell) + Vector3(0, 1.0, 0), "stars", 0.4)
	sfx("putdown")
	_after_building(ch)
	return true


## A new piece or tool stays in hand while there is money for another.
func _after_building(ch: Player = null) -> void:
	ch = _me(ch)
	if ch.hand.get("id", "") == "till" or not catalog.can_buy(ch.hand.id, ledger.money, buy_level(ch.hand.id), int(ch.hand.tier)) or ledger.money < int(ch.hand.price):
		ch.hand = {}
	hud.show_build()


# ---------------------------------------------------------------- building the room

## One tile, wall, door or archway from the tool in hand, if it fits and can be
## paid for. Keeps the grid in step; the room is redrawn by the caller.
func _build_at(spot: Vector3i, ch: Player = null) -> bool:
	ch = _me(ch)
	if not can_place(spot, ch) or not ledger.spend(int(ch.hand.price)):
		return false
	var cell := Vector2i(spot.x, spot.y)
	match tool_kind(ch.hand.id):
		"floor":
			var was := plan.kind(cell)
			if was != "":   # laying over another floor: the old one is taken up and paid back
				ledger.refund(Catalog.price_of("floor_" + was))
			for what: String in plan.lay(cell, floor_kind(ch.hand.id)).values():
				ledger.refund(Catalog.price_of(what))
		"wall":
			plan.build(spot)
		"finish":
			var was := plan.finish(spot, ch.hand.id)
			if was != "":   # papering over paint: the old finish is paid back
				ledger.refund(Catalog.price_of(was))
		"door", "arch":
			var had := plan.strip(spot)
			if had != "":
				ledger.refund(Catalog.price_of(had))
			plan.openings[spot] = ch.hand.id
		"treat":   # laid free: its price is paid at the door each night it is re-laid
			treat_laid[cell] = Treatments.key_of(ch.hand.id)
			floor_dirt.redraw()
			menu_changed()
			return true
	_sync_grid()
	return true


## Takes away the floor, built wall or opening at a spot, for the tool in hand,
## and pays back what it cost. Refused if it would cut anyone off.
func remove_at(spot: Vector3i, ch: Player = null) -> bool:
	ch = _me(ch)
	if phase != Phase.BUILD or ch.hand.is_empty() or not Catalog.is_build_tool(ch.hand.id):
		return false
	var cell := Vector2i(spot.x, spot.y)
	match tool_kind(ch.hand.id):
		"treat":   # lifted: bare from tomorrow
			if not treat_laid.has(cell):
				return false
			treat_laid.erase(cell)
			floor_dirt.redraw()
			menu_changed()
			return true
		"floor":
			if not plan.has_floor(cell) or cell == ENTRANCE_CELL or stations.has(cell) or highs.has(cell) \
					or grid.reserved.has(cell) or chefs.any(func(o: Player) -> bool: return o.cell() == cell) or rug_at(cell) != null:
				return false
			for e in Floorplan.cell_edges(cell):
				if wall_nodes.has(e):
					return false
			grid.outside[cell] = true
			var ok := grid.layout_ok(DOOR, _reach(), _touch())
			grid.outside.erase(cell)
			if not ok:
				return false
			ledger.refund(Catalog.price_of("floor_" + plan.kind(cell)))
			for e in Floorplan.cell_edges(cell):
				if plan.built.has(e):
					ledger.refund(Catalog.price_of("wall"))
			for what: String in plan.lift(cell).values():
				ledger.refund(Catalog.price_of(what))
		"wall":
			if not plan.built.has(spot):
				return false
			ledger.refund(Catalog.price_of("wall"))
			var paper := plan.strip(spot)
			if paper != "":
				ledger.refund(Catalog.price_of(paper))
			var had := plan.unbuild(spot)
			if had != "":
				ledger.refund(Catalog.price_of(had))
		"door", "arch":
			var what: String = plan.openings.get(spot, "")
			if what != "door" and what != "arch":
				return false
			grid.walls[spot] = true   # closing it up must not shut anyone in
			var ok := grid.layout_ok(DOOR, _reach(), _touch())
			grid.walls.erase(spot)
			if not ok:
				return false
			plan.openings.erase(spot)
			ledger.refund(Catalog.price_of(what))
		"finish":
			if not plan.finishes.has(spot):
				return false
			ledger.refund(Catalog.price_of(plan.strip(spot)))
	_sync_grid()
	return true


## After the plan changes: redraw the room and say so.
func _plan_changed() -> void:
	_rebuild_room()
	hud.show_build()


## The spots a mouse drag covers, from where it started to `to`: a rectangle of
## cells for floors, a straight line of edges for walls, one spot otherwise.
func drag_spots(from: Vector3, to: Vector3, ch: Player = null) -> Array[Vector3i]:
	ch = _me(ch)
	var out: Array[Vector3i] = []
	var id: String = ch.hand.get("id", "")
	if floor_kind(id) != "":
		var cells := Floorplan.rect_cells(Grid.to_cell(from), Grid.to_cell(to))
		if not ch.drag.get("remove", false):
			cells = plan.lay_order(cells, floor_kind(id))
		for c in cells:
			out.append(Vector3i(c.x, c.y, 0))
	elif Treatments.is_laying_tool(id):   # a treatment is laid over a rectangle of floor
		for c in Floorplan.rect_cells(Grid.to_cell(from), Grid.to_cell(to)):
			if plan.has_floor(c):
				out.append(Vector3i(c.x, c.y, 0))
	elif id == "wall" or Catalog.is_finish(id):
		var a := Vector2i(roundi(from.x), roundi(from.z))
		var b := Vector2i(roundi(to.x), roundi(to.z))
		if a == b:
			out.append(snap_edge(to))
		else:
			out.assign(Floorplan.line(a, b))
	elif id != "":
		out.append(snap(to, ch))
	return out


## Builds (or removes) along a whole drag, as far as the money goes.
func finish_drag(from: Vector3, to: Vector3, remove: bool, ch: Player = null) -> int:
	ch = _me(ch)
	ch.drag = {"from": from, "remove": remove}
	var done := 0
	for spot in drag_spots(from, to, ch):
		if remove:
			done += int(remove_at(spot, ch))
		elif _build_at(spot, ch):
			done += 1
		elif not ledger.money >= int(ch.hand.price):
			break
	ch.drag = {}
	if done > 0:
		_plan_changed()
		sfx("coin" if remove else "putdown")
		if not remove:
			_after_building(ch)
	else:
		sfx("fail")
	return done


## What a drag in progress would do, for the prompt: "Lay 6 tiles  $30".
func drag_summary(ch: Player = null) -> String:
	ch = _me(ch)
	if ch.drag.is_empty() or ch.hand.is_empty() or _hover_point(ch) == Vector3.INF:
		return ""
	var spots := drag_spots(ch.drag.from, _hover_point(ch), ch)
	if ch.drag.remove:
		return "Remove"
	var n := spots.size() if floor_kind(ch.hand.id) != "" else spots.filter(func(sp: Vector3i) -> bool: return can_place(sp, ch)).size()
	if Treatments.is_laying_tool(ch.hand.id):
		var each := Treatments.price_of(Treatments.key_of(ch.hand.id))
		return "Lay %d cell%s  $%d a night" % [n, "" if n == 1 else "s", n * each]
	var price := int(ch.hand.price)
	var noun: String = "tile" if floor_kind(ch.hand.id) != "" else ("wall" if ch.hand.id == "wall" or Catalog.is_finish(ch.hand.id) else ch.hand.id)
	var verb := "Lay" if floor_kind(ch.hand.id) != "" else ("Paint" if ch.hand.id == "paint" else ("Paper" if Catalog.is_finish(ch.hand.id) else "Build"))
	return "%s %d %s%s  $%d" % [verb, n, noun, "s" if n != 1 else "", n * price]


## A point on the floor in front of the chef: the middle of the next cell, or (for
## partitions) just inside the edge of the cell the chef stands in.
func _front_point(edge := false, ch: Player = null) -> Vector3:
	ch = _me(ch)
	return Grid.center(ch.cell()) + Vector3(ch.facing.x, 0, ch.facing.y) * (0.45 if edge else 1.0)


## Where the piece in hand is held: over the spot in front of the chef.
func _hover_point(ch: Player = null) -> Vector3:
	ch = _me(ch)
	if ch.demo_hover != Vector3.INF:
		return ch.demo_hover
	if ch.aim_mouse:
		return ch.mouse_point
	return _front_point(on_edge(ch.hand.get("id", "")), ch)


## Where a point on the screen lands on the floor.
func floor_point(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector3.INF
	return o + d * (-o.y / d.y)


## A point on the piece the chef could pick up: the partition on the edge ahead,
## or else whatever stands in the next cell. Vector3.INF when there is nothing.
func _piece_in_front(ch: Player = null) -> Vector3:
	ch = _me(ch)
	if wall_nodes.has(snap_edge(_front_point(true, ch))):
		return _front_point(true, ch)
	var c := Grid.to_cell(_front_point(false, ch))
	if stations.has(c) or highs.has(c) or rug_at(c) != null:   # a hood over bare floor too
		return _front_point(false, ch)
	return Vector3.INF


## What E would do in the build phase: "Put down", "Pick up", "Open up" or nothing.
func build_action(ch: Player = null) -> String:
	ch = _me(ch)
	if phase != Phase.BUILD or shopper == ch:
		return ""
	if not ch.hand.is_empty():
		if not ch.drag.is_empty():
			return drag_summary(ch)
		match tool_kind(ch.hand.id):
			"floor":
				return "Lay floor"
			"finish":
				return "Paint wall" if ch.hand.id == "paint" else "Paper wall"
			"wall":
				return "Build wall"
			"door":
				return "Add door"
			"arch":
				return "Add archway"
			"treat":
				return "Lay %s" % Treatments.name_of(Treatments.key_of(ch.hand.id)).to_lower()
		if Catalog.is_box(ch.hand.id):   # where it will not go, why: chemicals and food (PRD 9.5)
			var c := Grid.to_cell(_hover_point(ch))
			var why := kitchen.store_refusal(c, ch.hand.id) if kitchen.slots(c) > 0 else ""
			return why if why != "" else "Put in"
		return "Hang" if hand_layer(ch) == "high" else "Put down"
	var kit := _kit_action(ch)
	if kit != "":
		return kit
	var clean := night_clean_action(station_at(ch.target_cell()), ch)
	if clean != "":
		return clean
	if desk_in_front(ch) != null and not Cleaning.carrying_mess(ch.held):
		return "Use desk"
	if not Cleaning.carrying_mess(ch.held) and not CleanKit.holding(ch) and _piece_in_front(ch) != Vector3.INF:
		return "Pick up"
	return door_action(ch)


## What E does with cleaning tools at night (PRD 9.4): at a home or sink, else on the floor.
func _kit_action(ch: Player) -> String:
	if clean_kit.floor_first(ch):
		return clean_kit.floor_action(ch)
	var st: Station = station_at(ch.target_cell())
	var kit := clean_kit.station_use(st, true, ch) if st != null else ""
	return kit if kit != "" else clean_kit.floor_action(ch)


## The cleaning Use would do on this station at night, by its night name
## ("Clear table", "Wash up", "Take the bag out"); "" when there is none.
func night_clean_action(st: Station, ch: Player = null) -> String:
	ch = _me(ch)
	if st == null or phase != Phase.BUILD or shopper == ch or not ch.hand.is_empty():
		return ""
	return Cleaning.night_action(use_station(st, true, ch))


func needs_cleaning(st: Station) -> bool:
	return Cleaning.needs_cleaning("table" if Station.is_table(st.type) else st.type, st.dirty, st.count)


## The build-phase note on what is still dirty; "" when everything is clean.
func dirty_note() -> String:
	var tables := 0
	var sinks := 0
	var bins := 0
	for st: Station in stations.values():
		if needs_cleaning(st):
			tables += 1 if Station.is_table(st.type) else 0
			sinks += 1 if st.type == "sink" else 0
			bins += 1 if st.type == "bin" else 0
	return Cleaning.dirty_note(tables, sinks, bins)


func build_interact(ch: Player = null) -> void:
	ch = _me(ch)
	if ch.hand.is_empty() and _kit_action(ch) != "":   # a cleaning tool (PRD 9.4)
		var st: Station = station_at(ch.target_cell())
		if clean_kit.floor_first(ch) or st == null or clean_kit.station_use(st, false, ch) == "":
			clean_kit.floor_use(ch)
		return
	var action := build_action(ch)
	if not ch.hand.is_empty():
		action = "Put down"   # hung or stood, place() decides
	if action in Cleaning.NIGHT_ACTIONS.values():
		use_station(station_at(ch.target_cell()), false, ch)
		hud.show_build()   # the dirty note counts down
		return
	match action:
		"Put down":
			ch.last_paint = snap(_hover_point(ch), ch)
			if not place(ch.last_paint, ch):
				sfx("fail")
		"Pick up":
			lift(ch)
		"Use desk":
			open_desk(ch)
		"Open":
			open_storage(_storage_in_front(ch), ch)
		"Open up", "Take out rubbish":
			use_door(ch)
			hud.show_build()


## The piece in hand is held over the spot in front of the chef; a cross marks
## spots where it cannot go.
func _update_ghost(ch: Player = null) -> void:
	ch = _me(ch)
	_update_tool_ghost(ch)
	var key := "%s:%s:%s:%s" % [ch.hand.get("id", ""), ch.hand.get("tier", 0), hand_key(ch), ch.hand.get("up", "")] if phase == Phase.BUILD and not ch.hand.is_empty() and not Catalog.is_build_tool(ch.hand.id) and not ch.hand.get("in_place", false) else ""
	# A wall-layer piece (PRD 8.5) shows the layer it would take where it points.
	var hn := hand_node(ch.hand) if key != "" else ""
	var layer := ""
	var cell := Vector2i(-99, -99)
	var hover := _hover_point(ch)
	if (Kitchen.can_go_high(hn) or Kitchen.is_tall(hn)) and hover != Vector3.INF:
		var sp := snap(hover, ch)
		cell = Vector2i(sp.x, sp.y)
		layer = layer_for(cell, hn) if Kitchen.can_go_high(hn) else "tall"
		key += ":%s:%d:%s" % [layer, int(wall_facing.get(cell, -1)), kitchen.get_piece(cell, "base")]
	if key != ch.ghost_key:
		ch.ghost_key = key
		if ch.ghost:
			ch.ghost.queue_free()
			ch.ghost = null
		if key != "":
			ch.ghost = Node3D.new()
			add_child(ch.ghost)
			if ch.hand.id == "screen":
				_wall_visual(ch.ghost, 0.9 + 0.1 * int(ch.hand.tier))
			elif ch.hand.id == "rug":
				Scenery.rug(ch.ghost)
			elif ch.hand.id == "till":
				Build.register(ch.ghost)
			elif layer == "high":
				var closet := hn.ends_with("shelf") and kitchen.is_closet_with(cell, hn)
				Build.wall_piece(ch.ghost, hn, closet)
			elif ch.hand.get("node") is Station:
				var hs: Station = ch.hand.node
				Build.station(ch.ghost, hs.type, hs.tier, hs.base if hs.type == "counter" or hs.type == "shelf" or Kitchen.grows_from_counter(hs.node) else "", false, hs.node)
			else:
				Build.station(ch.ghost, ch.hand.id, int(ch.hand.tier), "counter" if ch.hand.get("counter", false) else ch.hand.get("base", ""), false, str(ch.hand.get("up", "")))
			if layer != "" and wall_facing.has(cell):
				_layer_band(ch.ghost, layer, 0 if layer == "high" else int(wall_facing[cell]) - int(ch.hand.facing), hn == "hook")
	var p := hover
	if ch.ghost == null or p == Vector3.INF:
		ch.no_mark.visible = false
		if ch.ghost:
			ch.ghost.visible = false
		return
	var spot := snap(p, ch)
	var ok := can_place(spot, ch)
	if on_edge(ch.hand.id):
		_place_on_edge(ch.ghost, spot)
	elif layer == "high":
		ch.ghost.position = Grid.center(Vector2i(spot.x, spot.y))
		ch.ghost.rotation.y = int(wall_facing.get(cell, 0)) * PI / 2
	else:
		ch.ghost.position = Grid.center(Vector2i(spot.x, spot.y))
		ch.ghost.rotation.y = int(ch.hand.facing) * PI / 2
	ch.ghost.position.y = 0.12 + 0.04 * sin(Time.get_ticks_msec() / 160.0)   # held just off the floor
	if Catalog.is_box(ch.hand.id):
		ch.ghost.position.y += 0.86   # a box is held over the counter it goes into
	ch.ghost.visible = ok
	ch.no_mark.visible = not ok
	ch.no_mark.position = Vector3(ch.ghost.position.x, 0, ch.ghost.position.z)


## A pale band on the wall behind a ghost marking the layer it takes (PRD 8.5): the
## high band for a hung piece, the low band for a shelf standing low, both for a tall
## piece. `turn` is the wall's facing in the ghost's own frame.
func _layer_band(ghost: Node3D, layer: String, turn: int, small := false) -> void:
	var band := Node3D.new()
	band.rotation.y = turn * PI / 2
	ghost.add_child(band)
	var y0 := Build.HIGH_Y0 if layer == "high" else 0.0
	var y1 := 0.92 if layer == "base" else Build.HIGH_Y1
	if small:   # a hook is a small thing low in the band: frame it, not the whole layer
		y0 = Build.HIGH_Y0 - 0.2
		y1 = Build.HIGH_Y0 + 0.5
	y0 -= 0.24   # a margin round the piece, so the band still shows as a frame behind it
	y1 += 0.24
	var plate := Build.box(band, Vector3(0, y0, -0.495), Vector3(1.0, y1 - y0, 0.01), Build.GOOD)
	plate.material_override = Build.overlay_mat(Color(Build.GOOD, 0.6), 2, true)   # behind the piece, on the wall
	for y: float in [y0, y1]:   # a darker rule top and bottom, so the band reads by shape too
		Build.box(band, Vector3(0, y - 0.015, -0.485), Vector3(1.0, 0.03, 0.02), Build.GOOD).material_override = Build.overlay_mat(Color(Build.GOOD, 0.85), 2, true)


## A build tool shows what it would do: pale squares for floor, bars along the
## edges for walls, the door or archway itself; green where it fits, coral
## where it does not, and coral everywhere a drag would remove.
func _update_tool_ghost(ch: Player = null) -> void:
	ch = _me(ch)
	var p := _hover_point(ch)
	var tool := phase == Phase.BUILD and not ch.hand.is_empty() and Catalog.is_build_tool(ch.hand.id) and shopper != ch and p != Vector3.INF
	var spots: Array[Vector3i] = []
	if tool:
		if ch.drag.is_empty():
			spots.append(snap(p, ch))
		else:   # not a one-line `a if c else b`: that drops the array's type and fails at run time
			spots = drag_spots(ch.drag.from, p, ch)
	var key := "%s|%s|%s|%d" % [ch.hand.get("id", ""), spots, ch.drag.get("remove", false), ledger.money] if tool else ""
	if key == ch.tool_key:
		return
	ch.tool_key = key
	if ch.tool_ghost:
		ch.tool_ghost.queue_free()
		ch.tool_ghost = null
	if not tool:
		return
	ch.tool_ghost = Node3D.new()
	add_child(ch.tool_ghost)
	var removing: bool = ch.drag.get("remove", false)
	var dragging := not ch.drag.is_empty()
	for spot in spots:
		var ok := not removing and (dragging and (floor_kind(ch.hand.id) != "" or Treatments.is_laying_tool(ch.hand.id)) or can_place(spot, ch))
		var col := Color(Build.DANGER if removing or not ok else Build.GOOD, 0.55)
		if floor_kind(ch.hand.id) != "" or Treatments.is_laying_tool(ch.hand.id):   # a treatment: its cells, flat (PRD 9.5)
			var tile := Build.box(ch.tool_ghost, Vector3(spot.x + 0.5, 0.02, spot.y + 0.5), Vector3(0.94, 0.03, 0.94), Build.GOOD)
			tile.material_override = Build.overlay_mat(col, 3)
		elif ch.hand.id == "wall" or Catalog.is_finish(ch.hand.id):
			var bar := Node3D.new()
			ch.tool_ghost.add_child(bar)
			_place_on_edge(bar, spot)
			var tall := Scenery.CUT_H if ch.hand.id == "wall" else 1.2
			var thick := Scenery.WALL_T + (0.0 if ch.hand.id == "wall" else 0.08)
			Build.box(bar, Vector3(0, 0, 0), Vector3(1.0, tall, thick), Build.GOOD).material_override = Build.overlay_mat(col, 3)
		else:
			var n := Node3D.new()
			ch.tool_ghost.add_child(n)
			_place_on_edge(n, spot)
			var inner := Node3D.new()
			n.add_child(inner)
			Scenery.dress_opening({"holder": inner, "kind": ch.hand.id, "tall": false}, true)
			if removing or not ok:
				Build.box(n, Vector3(0, 0, 0), Vector3(1.0, 0.9, Scenery.WALL_T + 0.1), Build.DANGER).material_override = Build.overlay_mat(col, 3)


## Flyers: bought from the shop's Extras at night for a bigger crowd tomorrow. One batch a night.
func buy_flyers() -> bool:
	if phase != Phase.BUILD or flyers_out or not ledger.spend(Town.FLYER_PRICE):
		return false
	flyers_out = true
	sfx("coin")
	hud.show_build()
	return true


# ---------------------------------------------------------------- the door card

## The OPEN / CLOSED card on a string in the doorway. It hangs from a nail under
## the lintel, facing the street, and spins on its string to show the other side.
func _build_door_card() -> void:
	_door_hang = Node3D.new()
	_door_hang.position = DOORWAY + Vector3(0.3, 2.03, 0)
	_door_hang.rotation.y = PI / 2   # local +z looks out at the street
	add_child(_door_hang)
	Build.ball(_door_hang, Vector3.ZERO, 0.035, Build.TRIM)
	_door_turn = Node3D.new()
	_door_hang.add_child(_door_turn)
	for side: float in [-1.0, 1.0]:
		var string := Build.box(_door_turn, Vector3.ZERO, Vector3(0.018, 0.33, 0.018), Build.TRIM)
		string.position = Vector3.ZERO
		string.rotation.z = PI - side * 0.74
		string.position = Vector3(side * 0.11, -0.12, 0)
	Build.box(_door_turn, Vector3(0, -0.56, 0), Vector3(0.62, 0.34, 0.03), Build.PAPER)
	for open: bool in [true, false]:
		var z := 0.014 if open else -0.014
		Build.box(_door_turn, Vector3(0, -0.53, z), Vector3(0.55, 0.28, 0.012), Build.LEAF if open else Build.CORAL_DARK)
		var l := Label3D.new()
		l.text = "OPEN" if open else "CLOSED"
		l.font = Hud.lettering()
		l.font_size = 64
		l.pixel_size = 0.0034 if open else 0.0028
		l.outline_size = 0
		l.modulate = Color(Build.PAPER)
		l.double_sided = false
		l.position = Vector3(0, -0.4, z * 1.6)
		l.rotation.y = 0.0 if open else PI
		_door_turn.add_child(l)


## Flips the card, with a spin on its string and a swing from the nail.
func set_door(open: bool) -> void:
	if door_open == open:
		return
	door_open = open
	sfx("flip")
	var tw := _door_turn.create_tween()
	tw.tween_property(_door_turn, "rotation:y", 0.0 if open else PI, 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_door_hang.rotation.z = 0.5
	_door_hang.create_tween().tween_property(_door_hang, "rotation:z", 0.0, 1.4) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func at_door(ch: Player = null) -> bool:
	ch = _me(ch)
	var d := ch.position - DOORWAY
	return Vector2(d.x, d.z).length() < DOOR_REACH


## What the chef can do with the door card from here: "Open up" at the end of the
## build phase, "Close early" from the middle of the day on, or nothing.
func door_action(ch: Player = null) -> String:
	ch = _me(ch)
	if not at_door(ch):
		return ""
	if ch.held == "rubbish_bag":
		return "Take out rubbish"
	if phase == Phase.BUILD and ch.hand.is_empty() and shopper != ch:
		return "Open up"
	if phase == Phase.SERVICE and door_open and not arrivals.is_empty() and day_progress() >= CLOSE_EARLY_FROM:
		return "Close early"
	return ""


func use_door(ch: Player = null) -> bool:
	ch = _me(ch)
	match door_action(ch):
		"Open up":
			var why := open_block()
			if why != "":
				sfx("fail")
				hud.say(why)
				hud.show_build()
				return false
			if _agree_at_door(ch):
				start_day()
		"Close early":
			if _agree_at_door(ch):
				close_early()
		"Take out rubbish":
			ch.set_held("")
			sfx("putdown")
		_:
			return false
	ch.punch()
	return true


## Nobody else comes in today. Guests already here, queue included, stay and are
## served as usual; the day ends when the last of them has gone.
func close_early() -> void:
	if phase != Phase.SERVICE or not door_open:
		return
	if arrivals.any(func(a: Dictionary) -> bool: return a.get("critic", false)):
		critic.postpone(ledger.day)   # they come tomorrow instead
	arrivals.clear()
	set_door(false)
	hud.say("Closed. Guests already here can stay.")


func _end_day() -> void:
	_cancel_all_preps()
	crew.clear()   # the staff go home
	floor_dirt.clear_slips()   # a chef still down gets up for the night
	clean_kit.end_day()   # robot sweepers go back to their docks
	floor_dirt.mess.treat = {}   # the day's treatments are worn off (PRD 9.5)
	floor_dirt.redraw()
	set_door(false)
	shopper = null
	upgrading = false
	ready_chefs.clear()
	phase = Phase.SUMMARY
	play_music("night")
	inspect(null)
	last_day = ledger.end_day()
	if not _critic_rated.is_empty():   # the paper prints the review with tonight's receipt
		last_day["review"] = critic.publish(_critic_rated.ratings, _critic_rated.walked, town, int(last_day.day))
		_critic_rated = {}
	hud.show_summary(last_day)
	sfx("coin")


func _close_down() -> void:
	_cancel_all_preps()
	crew.clear()
	play_music("closed")
	phase = Phase.CLOSED
	SaveGame.delete(save_path)   # the run is over: nothing to continue
	var days := ledger.day
	var earned := ledger.lifetime_earnings()
	var best := load_best()
	var is_record: bool = days > int(best.days) or (days == int(best.days) and earned > int(best.earned))
	if is_record:
		var f := FileAccess.open(best_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"days": days, "earned": earned}))
	hud.show_closed(days, earned, best, is_record)
	sfx("fail")


func load_best() -> Dictionary:
	var best := {"days": 0, "earned": 0}
	if FileAccess.file_exists(best_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(best_path))
		if data is Dictionary and data.has("days") and data.has("earned"):
			best = data
	return best


func restart() -> void:
	_theme_picked = false   # a new run: the theme card comes up again
	_kept_seats = controls.seats.duplicate()   # whoever is seated stays seated
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- guests

## The most guests one table can seat, which is also the biggest group that comes.
func max_party() -> int:
	var most := 1
	for st: Station in stations.values():
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
		add_child(g)
		g.setup(self, idx, SPAWN)
		# Up the street past the end of the line, so newcomers walk towards the door
		# like everyone else; friends come in single file, not stacked on one spot.
		var back := minf(Grid.center(SPAWN).z, queue_spot(queue.size()).z) - 1.5
		for o: Guest in guests:
			if o.position.x > W and o.state != "leaving":   # out on the pavement, coming in
				back = minf(back, o.position.z - QUEUE_GAP)
		g.position.z = back
		g.party = party
		party.append(g)
		guests.append(g)
		queue.append(g)
	if as_critic:
		critic_guest = party[0]
	var plan := _plan_orders(party)
	if plan.walk:   # nobody has a main: they read the menu at the door and walk on
		for k in party.size():
			var g := party[k]
			queue.erase(g)
			g.state = "browse"
			g.timer = Guest.BROWSE_TIME
			g.hold = 0.4 * k
			g.walk_to(Vector2i(W + 1, Grid.to_cell(queue_spot(0)).y + k), queue_spot(0) + Vector3(1.0, 0, k * 0.9))
	_reflow_queue()
	return party


## The group reads the menu at the door and each decides what they will order.
## Returns the group's plan (see Menu.group_order).
func _plan_orders(party: Array[Guest]) -> Dictionary:
	var tastes := []
	for g in party:
		tastes.append(town.tastes_of(g.idx))
	var available := tonight_menu()
	var plan := Menu.group_order(available, tastes, order_rng)
	if party.size() == 1 and party[0] == critic_guest:   # never turned away by the menu
		plan = {"walk": false, "found_nothing": [],
			"orders": [Critic.order(available, tastes[0].likes, tastes[0].dislikes, order_rng)]}
		party[0].mood.think(Critic.thought("menu"))
	for k in party.size():
		var g := party[k]
		g.planned = plan.orders[k]
		if plan.walk:
			continue   # they think it at the board (read_board)
		if plan.found_nothing.has(k):   # stays with the group, with a drink or nothing
			g.mood.think(Menu.NOTHING_THOUGHT)
			town.record_found_nothing(g.idx)
			ledger.record_found_nothing()
		else:
			g.hint_tag = Menu.tag_hint(available, g.info.liked_tags)
			if g.hint_tag != "":
				g.mood.think(Menu.hint_thought(g.hint_tag))
	return plan


## A guest who found no main stops at the menu, says so and walks on. Not a walkout
## and not a strike, but they think a little less of the place, friends hear it, and
## the receipt counts them.
func read_board(g: Guest) -> void:
	g.mood.think(Menu.NOTHING_THOUGHT)
	popup("Nothing I liked", g.position + Vector3(0, 2.3, 0), Color(Build.CABINET))
	ledger.record_found_nothing()
	var talk := town.gossip_line(g.idx, town.record_found_nothing(g.idx), "there was nothing on the menu for them")
	if g == g.party[0] and talk != "":
		hud.say(talk)


## Where the guest `i`th in line stands: a single file up the pavement along the
## wall, one QUEUE_GAP apart, starting a step up from the doorway so guests on
## their way out pass the head of the line. A long line runs on up the street,
## past the edge of the lot.
func queue_spot(i: int) -> Vector3:
	return Grid.center(DOOR) - Vector3(0, 0, QUEUE_GAP * (i + 1))


## Everyone in line steps up to their own place. Newcomers walk down the outer
## half of the pavement and step in beside their place, so they never walk
## through the people already waiting.
func _reflow_queue() -> void:
	for i in queue.size():
		var g := queue[i]
		var at := queue_spot(i)
		var row := clampi(Grid.to_cell(at).y, LOT.position.y, LOT.end.y - 1)
		g.walk_to(Vector2i(W if g.cell.x == W else W + 1, row), at)
		g.line_place = i


## The nearest other guest standing close, straight ahead of `g` going `dir`.
func guest_in_way(g: Guest, dir: Vector3) -> Guest:
	var best: Guest = null
	var near := Guest.PERSONAL
	for o: Guest in guests:
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
	for st: Station in stations.values():
		if st.seats.size() < count or (best != null and st.seats.size() >= best.seats.size()):
			continue
		var empty := true
		for s in st.seats:
			empty = empty and not seat_taken.has(s)
		if empty:
			best = st
	return best


## Seats the group at the head of the queue once a whole table is free for them.
## Groups never share a table, and nobody jumps the queue.
func _seat_waiting_guests() -> void:
	while not queue.is_empty():
		var party: Array[Guest] = []
		for m: Guest in queue[0].party:
			if queue.has(m):
				party.append(m)
		var table := _free_table_for(party.size())
		if table == null:
			return
		for i in party.size():
			var g := party[i]
			queue.erase(g)
			g.line_place = -1
			g.table = table
			g.seat = table.seats[i]
			seat_taken[g.seat] = g
			g.state = "to_seat"
			g.walk_to(g.seat)
		door_bell()
		_reflow_queue()


func on_seated(g: Guest) -> void:
	if g.table.tier > 1:
		g.mood.delight(0.05 * (g.table.tier - 1), "What a lovely table")
	if g.table.type == "booth":
		g.mood.delight(BOOTH_DELIGHT, "A booth! How cosy")
	for other in g.table.seats:
		if other != g.seat and seat_taken.has(other):
			var mate: Guest = seat_taken[other]
			if town.are_friends(g.idx, mate.idx):
				g.mood.delight(0.15, "Oh good, %s is here!" % mate.info.name)
				mate.mood.delight(0.15, "Oh good, %s is here!" % g.info.name)
	cheer_with_decor(g)
	if party_at(g.table).all(func(o: Guest) -> bool: return o.state != "to_seat"):
		# The whole party is down: a knock on the table, they are ready to order.
		get_tree().create_timer(0.6).timeout.connect(sfx.bind("order_ready", 0.04))


## Everything a seated guest can see changes how they feel.
func apply_surroundings(g: Guest, delta: float) -> void:
	var saw_gross := false
	for s in _gross:
		var c: Vector2i = s.cell
		if _near(g.cell, c, int(s.get("range", SIGHT_RANGE))) and grid.has_los(g.cell, c):
			var age: float = s.get("age", -1.0)
			if age < 0.0:   # no age of its own: count how long this guest has looked at it
				age = g.seen.get(s.key, 0.0)
				g.seen[s.key] = age + delta
			var curve: Array = GROSS[s.kind]
			var rate := GuestMood.gross_rate(curve[0], age, curve[1], curve[2])
			g.mood.see_gross(rate, delta, s.thought)
			if g == critic_guest and rate >= GuestMood.NOTICE:
				g.mood.think(Critic.thought("gross"))
			saw_gross = saw_gross or rate >= GuestMood.NOTICE
	saw_gross = floor_dirt.disgust(g, delta, SIGHT_RANGE) or saw_gross
	for st: Station in stations.values():
		if st.type == "stove" and not saw_gross and st.is_cooking() \
				and _near(g.cell, st.cell, SIGHT_RANGE) and grid.has_los(g.cell, st.cell):
			# An open kitchen is a show, as long as nothing nasty is in view.
			g.mood.delight(0.01 * delta, "I can watch the chef at work")
			saw_gross = true   # one stove's worth of show, however many are on


## Decor cheers a guest once, as they sit down: a flat bonus from what is near the
## seat (see Decor). If the room changes while they sit, they get the difference.
func cheer_with_decor(g: Guest) -> void:
	var b := decor_bonus(g.seat)
	var gain: float = b.joy - g.decor
	if absf(gain) > 0.0001:
		g.mood.delight(gain, Decor.thought(b.best) if gain > 0.0 else "")
	g.decor = b.joy


## Works the decor bonus out again for everyone seated, after the room changes.
func recheck_decor() -> void:
	for g: Guest in guests:
		if g.seated_waiting() or g.state == "eating":
			cheer_with_decor(g)


## The decor bonus for a seat: {"joy", "best"} from Decor.bonus.
func decor_bonus(cell: Vector2i) -> Dictionary:
	return Decor.bonus(decor_near(cell))


## Every nice thing a seat can see, as {"id", "dist", "tier"} for Decor.bonus:
## each kind of floor, each rug, each kind of wall finish and each fern, at the
## nearest cell of it the seat can see (Decor.nearest, the rule the reach marks use).
func decor_near(cell: Vector2i) -> Array:
	var out: Array = []
	var r := Decor.VIEW_RANGE
	var add := func(id: String, cells: Array, reach: int, tier: int) -> void:
		var d := Decor.nearest(grid, cell, cells, reach)
		if d >= 0:
			out.append({"id": id, "dist": d, "tier": tier})
	var floors := {}
	for c: Vector2i in plan.floors:
		var id := "floor_" + plan.kind(c)
		if Catalog.joy_of(id) > 0.0:
			if not floors.has(id):
				floors[id] = []
			floors[id].append(c)
	for id: String in floors:
		add.call(id, floors[id], r, 1)
	var treated := {}   # a floor finish in force today is decor, like parquet (PRD 9.5)
	for c: Vector2i in floor_dirt.mess.treat:
		var id := Treatments.tool_id(floor_dirt.mess.treat[c])
		if Catalog.joy_of(id) > 0.0:
			if not treated.has(id):
				treated[id] = []
			treated[id].append(c)
	for id: String in treated:
		add.call(id, treated[id], r, 1)
	for a: Vector2i in rugs:
		add.call("rug", rug_cells(a, int(rugs[a].get_meta("facing", 0))), r, 1)
	var walls := {}
	for e: Vector3i in plan.finishes:
		var id: String = plan.finishes[e]
		if not walls.has(id):
			walls[id] = []
		walls[id].append(e)
	for id: String in walls:
		add.call(id, Decor.finish_cells(plan, walls[id]), r, 1)
	for st: Station in stations.values():
		if Catalog.is_decor_piece(st.type):
			add.call(st.type, [st.cell], Decor.reach(st.type, st.tier), st.tier)
	return out


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return Decor.dist(a, b)


## How far a piece's effect on guests reaches, in cells. 0 for a piece with none.
static func range_of(id: String, tier := 1) -> int:
	if Catalog.is_decor_piece(id):
		return Decor.reach(id, tier)
	return BIN_RANGE if id == "bin" else 0


## Every seat in the room, and the share of a piece's joy (a Decor band) that would
## reach it from `cell` with a reach of `reach` cells: Decor.BESIDE, Decor.IN_VIEW or 0.
## Partitions block it, as they block a guest's view.
func seats_reached(cell: Vector2i, reach: int) -> Dictionary:
	var out := {}
	for st: Station in stations.values():
		for s in st.seats:
			var d := Decor.nearest(grid, s, [cell], reach)
			out[s] = Decor.band(maxi(1, d), reach) if d >= 0 else 0.0
	return out


## What a piece held as `h` at the point `at` would reach, with `drag` the drag in
## progress ({"from", "remove"} or {}). Takes the hand and spot as arguments so a
## second chef's hand works the same. {} when the piece cheers or bothers nobody.
## "cells": where its effect comes from; "area": the pale square (no area for
## floors and finishes, which have no single centre); "close": the brighter one.
func piece_reach(h: Dictionary, at: Vector3, drag: Dictionary) -> Dictionary:
	if h.is_empty() or at == Vector3.INF or drag.get("remove", false):
		return {}
	var id: String = h.id
	var tier := int(h.get("tier", 1))
	var cell := Grid.to_cell(at)
	var none := Rect2i()
	if range_of(id, tier) > 0:
		var r := range_of(id, tier)
		return {"id": id, "tier": tier, "cells": [cell], "reach": r, "decor": Catalog.is_decor_piece(id),
			"area": Rect2i(cell - Vector2i(r, r), Vector2i(r, r) * 2 + Vector2i.ONE),
			"close": Rect2i(cell - Vector2i.ONE, Vector2i(3, 3))}
	if Catalog.joy_of(id, tier) <= 0.0:
		return {}
	var from: Vector3 = drag.get("from", at)
	var cells: Array[Vector2i] = []
	var area := none
	var close := none
	if floor_kind(id) != "":
		var k := floor_kind(id)
		var rect := Floorplan.rect_cells(Grid.to_cell(from), cell)
		cells = plan.lay_order(rect, k)
		for c in rect:   # already this floor: it stays, and still counts
			if plan.has_floor(c) and plan.kind(c) == k:
				cells.append(c)
	elif Catalog.is_finish(id):
		var edges: Array[Vector3i] = []
		for e in _edge_run(from, at):
			if plan.is_wall(e) and not plan.openings.has(e):
				edges.append(e)
		cells = Decor.finish_cells(plan, edges)
	elif id == "rug":
		cells = rug_cells(cell, int(h.get("facing", 0)))
		var box := Rect2i(cells[0], Vector2i.ONE)
		for c in cells:
			box = box.expand(c).expand(c + Vector2i.ONE)
		area = box.grow(Decor.VIEW_RANGE)
		close = box.grow(1)
	else:
		return {}
	return {"id": id, "tier": tier, "cells": cells, "reach": Decor.reach(id, tier), "decor": true,
		"area": area, "close": close}


## The wall edges a drag from `from` to `to` runs along (one edge without a drag).
func _edge_run(from: Vector3, to: Vector3) -> Array[Vector3i]:
	var a := Vector2i(roundi(from.x), roundi(from.z))
	var b := Vector2i(roundi(to.x), roundi(to.z))
	if a == b:
		return [snap_edge(to)]
	return Floorplan.line(a, b)


## The mark each seat gets from a piece_reach: {seat: {"share", "mark", "full"}}.
## "full" is a seat whose decor joy is already at Decor.CAP, so the piece adds nothing.
func reach_marks(pr: Dictionary) -> Dictionary:
	var out := {}
	if pr.is_empty():
		return out
	for st: Station in stations.values():
		for s in st.seats:
			var share: float
			if pr.decor:
				share = Decor.share_from(grid, s, pr.id, pr.cells, pr.tier)
			else:
				var d := Decor.nearest(grid, s, pr.cells, pr.reach)
				share = Decor.band(maxi(1, d), pr.reach) if d >= 0 else 0.0
			var full: bool = pr.decor and share > 0.0 and Decor.is_full(decor_near(s))
			out[s] = {"share": share, "mark": Decor.mark(share), "full": full}
	return out


## While a piece with a reach is carried (a fern, the bin, a fine floor, a finish or
## a rug), every seat gets a mark: a green square on it (all its joy), a big green
## disc beside it (half), a small pale one in view (a fifth), red out of reach, and a
## white tick on a seat already as cheered as decor can make it. The fern, bin and
## rug also wash the floor they are seen from.
func _update_range(ch: Player = null) -> void:
	ch = _me(ch)
	var pr := piece_reach(ch.hand if phase == Phase.BUILD else {}, _hover_point(ch), ch.drag)
	var key := "%s:%s:%s:%d:%d:%d" % [pr.get("id", ""), pr.get("cells", []), pr.get("area", Rect2i()),
		stations.size(), grid.walls.size(), plan.floors.size()] if not pr.is_empty() else ""
	if key == ch.range_key:
		return
	ch.range_key = key
	for c in ch.range_marks.get_children():
		c.queue_free()
	if key == "":
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.22)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var y := 0.03
	for r: Rect2i in [pr.area, pr.close]:
		var area := r.intersection(LOT)
		if not area.has_area():
			continue
		var wash := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(area.size)
		wash.mesh = plane
		wash.material_override = m
		wash.position = Vector3(area.position.x + area.size.x / 2.0, y, area.position.y + area.size.y / 2.0)
		ch.range_marks.add_child(wash)
		y += 0.005
	var marks := reach_marks(pr)
	for s: Vector2i in marks:
		ch.range_marks.add_child(_seat_mark(s, marks[s]))


## One seat's reach mark, as reach_marks describes it. Each level differs in shape:
## a white-rimmed square for on, a big disc for beside, a small disc for in view, a
## red disc for not reached; the "full" tick is a white check, inked, on top.
func _seat_mark(s: Vector2i, info: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = Grid.center(s) + Vector3(0, 0.05, 0)
	var kind: String = info.mark
	var mark := Node3D.new()
	root.add_child(mark)
	var col := Color(Build.DANGER) if kind == Decor.MARK_NONE else Color(Build.GOOD)
	var fill := Build.overlay_mat(Color(col, 0.5 if kind == Decor.MARK_VIEW else 0.85), 2)
	if kind == Decor.MARK_ON:
		_flat_box(mark, Vector3.ZERO, Vector2(0.78, 0.78), 0.0, Build.overlay_mat(Color(Build.PAPER), 2))
		_flat_box(mark, Vector3(0, 0.005, 0), Vector2(0.6, 0.6), 0.0, Build.overlay_mat(Color(col), 3))
	else:
		var disc := MeshInstance3D.new()
		var puck := CylinderMesh.new()
		puck.top_radius = 0.4
		puck.bottom_radius = 0.4
		puck.height = 0.02
		disc.mesh = puck
		disc.material_override = fill
		mark.add_child(disc)
	var size := Vector3(0.6, 1, 0.6) if kind == Decor.MARK_VIEW else Vector3.ONE
	mark.scale = Vector3(0.3, 1, 0.3)
	mark.create_tween().tween_property(mark, "scale", size, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if info.full:
		# A check mark lying flat, the same size on every mark: ink under, white over.
		var tick := Node3D.new()
		tick.position = Vector3(0, 0.02, 0)
		tick.rotation.y = deg_to_rad(45.0)   # upright to the camera
		tick.scale = Vector3(1.4, 1, 1.4)
		var strokes := [[Vector3(-0.1, 0, 0.05), 0.2, deg_to_rad(-45.0)], [Vector3(0.08, 0, -0.03), 0.4, deg_to_rad(45.0)]]
		for layer: Array in [[Build.TRIM, 0.13, 4], [Build.PAPER, 0.07, 5]]:
			for st: Array in strokes:
				_flat_box(tick, st[0] + Vector3(0, 0.002 * layer[2], 0), Vector2(st[1] + layer[1] - 0.07, layer[1]),
					st[2], Build.overlay_mat(Color(layer[0]), layer[2]))
		root.add_child(tick)
	return root


## A thin flat box lying on the floor, `size` across x and z, turned `turn` about y.
static func _flat_box(parent: Node3D, at: Vector3, size: Vector2, turn: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(size.x, 0.01, size.y)
	m.mesh = b
	m.material_override = mat
	m.position = at
	m.rotation.y = turn
	parent.add_child(m)


static func _near(a: Vector2i, b: Vector2i, r: int) -> bool:
	return absi(a.x - b.x) <= r and absi(a.y - b.y) <= r


## Dirt on the floor follows the room, moves with everyone's feet and is drawn (PRD 9).
func _tick_floor(delta: float) -> void:
	floor_dirt.sync_room()
	var walkers := []
	for ch in hands():   # chefs and helpers
		walkers.append([ch, ch.cell()])
	for g in guests:
		walkers.append([g, Grid.to_cell(g.position)])
	floor_dirt.step_feet(walkers, phase == Phase.SERVICE)   # slips only while open (9.3)
	floor_dirt.tick_slips(delta)
	clean_kit.tick(delta)   # mop waits, the robot sweepers (PRD 9.4)
	floor_dirt.redraw()


## How fast anyone moves standing at `p`: slowed by the floor dirt under them.
func floor_speed(p: Vector3) -> float:
	return floor_dirt.speed_at(p) if floor_dirt != null else 1.0


func _collect_gross() -> void:
	_gross.clear()
	for st: Station in stations.values():
		if Station.is_table(st.type) and st.dirty > 0:
			_gross.append({"cell": st.cell, "kind": "plate", "age": st.dirty_age, "thought": "Nobody has cleared that table"})
		elif st.type == "bin" and st.overflowing():
			_gross.append({"cell": st.cell, "kind": "overflow", "age": st.dirty_age, "thought": "The bin is overflowing"})
		elif st.type == "bin":
			_gross.append({"cell": st.cell, "kind": "bin", "key": "bin:%s" % st.cell, "range": BIN_RANGE, "thought": "I can see the bin from my seat"})
		elif st.type == "sink" and st.messy():
			_gross.append({"cell": st.cell, "kind": "sink", "age": st.dirty_age, "thought": "Look at that washing-up"})
		elif (st.type == "stove" or st.type == "fryer") and st.item.begins_with("burnt:"):
			_gross.append({"cell": st.cell, "kind": "burning", "age": st.cook - Station.BURN_TIME, "thought": "Something is burning in there"})
	for ch in hands():
		if ch.carrying_something_gross():
			_gross.append({"cell": ch.cell(), "kind": "rubbish", "key": "rubbish", "thought": "I just watched the chef carry rubbish past me"})


## The most impatient guest sat at this table, waiting to order or for food.
func _waiting_guest_at(table: Station) -> Guest:
	var best: Guest = null
	for s in table.seats:
		if seat_taken.has(s):
			var g: Guest = seat_taken[s]
			if g.seated_waiting() and (best == null or g.mood.patience < best.mood.patience):
				best = g
	return best


## Everyone at this table who is sat down and has not ordered yet.
func _guests_to_order(table: Station) -> Array[Guest]:
	var out: Array[Guest] = []
	for s in table.seats:
		if seat_taken.has(s) and seat_taken[s].state == "ordering":
			out.append(seat_taken[s])
	return out


# ---------------------------------------------------------------- menu, tickets and dishes

## Every kind stocked tonight, each once: {ingredient, ready, stocked}. A box in a storage
## slot stocks its kind (PRD 8.4); a drink dispenser holds its own drinks, no slot needed.
func kitchen_stock() -> Array:
	var out := []
	var seen := {}
	for b: String in kitchen.stocked():
		if Kitchen.is_cleaning(b):
			continue   # a treatment's box stocks no food (PRD 9.5)
		var s := Pantry.station_ingredient(b)
		var key := Pantry.box_id(s.id, s.ready)
		if not seen.has(key):
			seen[key] = true
			out.append({"ingredient": s.id, "ready": s.ready, "stocked": true})
	for st: Station in stations.values():
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
		return cup == null or cup.refusal(Tray.kind("prep", d), menu.items) == ""
	if cup != null and not cup.is_empty():
		for d in taps:
			if fits.call(d):
				return d   # a cup started on one drink is finished with the one it lacks
	for t: Dictionary in tickets:
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
			if Kitchen.is_chilled(ing) and not kitchen.has_fridge():
				return "%s: needs a fridge" % Pantry.name_of(ing)
			return "%s: needs a box" % Pantry.name_of(ing)
	return why


## Puts a box of an ingredient in the room for tests and demos: into the counter at
## `cell` (one is set there, upgraded to a fridge for a chilled kind, if the cell is
## free), else nowhere. Returns the station holding it, or null.
func stock_box(kind: String, cell: Vector2i, ready := false, facing := 0) -> Station:
	var box := Pantry.box_id(kind, ready)
	if not stations.has(cell):
		add_station("counter", cell, 1, facing, "freezer" if Kitchen.is_frozen(box) else ("fridge" if Kitchen.is_chilled(box) else ""))
	if not _store_box(cell, box):
		return null
	return stations[cell]


## The station whose storage holds a kind (or box id), for tests and demos; null if none.
func storage_of(kind: String) -> Station:
	for cell: Vector2i in kitchen.cells_with(kind if Catalog.is_box(kind) else Pantry.box_id(kind)) \
			+ kitchen.cells_with(Pantry.box_id(kind, true)):
		return stations.get(cell)
	return null


## The prep tools in the room ("grill", "fry", ...).
func kitchen_tools() -> Array:
	var out := []
	for st: Station in stations.values():
		var jobs := Kitchen.jobs_of(st.node) if Kitchen.has_node(st.node) else {}
		if jobs.is_empty() and Catalog.tool_of(st.type) != "":
			jobs = {Catalog.tool_of(st.type): 1.0}
		for t: String in jobs:   # stand-ins count: a board can slice (PRD 8.3)
			if jobs[t] > 0.0 and not out.has(t):
				out.append(t)
	return out


## The menu items that can be offered tonight.
func tonight_menu() -> Array[Dictionary]:
	return menu.tonight(kitchen_stock(), kitchen_tools())


## The kitchen the tests and most demos start from: the theme's fixed line (the
## grilled ingredient's station, two stoves, the bread's) and a menu of its one main
## (a Burger in the diner, a Fish roll by the sea).
func test_kitchen() -> void:
	var fm := fixed_main()
	# Built from pieces (PRD 8.4): the grilled kind's box in an under-counter fridge,
	# two stoves on counters, the bread's box in a plain counter.
	if not stations.has(Vector2i(0, 2)):
		stock_box(fm.grill, Vector2i(0, 2))
	for at: Vector2i in [Vector2i(0, 3), Vector2i(0, 4)]:
		if not stations.has(at):
			add_station("stove", at, 1, 1)
	if not stations.has(Vector2i(0, 6)):
		stock_box(fm.bread, Vector2i(0, 6), false, 1)
	write_test_menu()
	menu_board.refresh(tonight_menu())


## Takes every hung piece off the walls, unpaid, stock and all (tests of other
## systems start with bare walls, as they did before PRD 8.5).
func clear_walls() -> void:
	for c: Vector2i in highs.keys():
		var st: Station = highs[c]
		highs.erase(c)
		kitchen.remove(c, "high")
		st.queue_free()
		_show_boxes(c)


## A one-item menu for tests: the theme's fixed main (a Burger: bun, patty).
func write_test_menu() -> void:
	menu.items.clear()
	menu.add("main", [fixed_main().bread, fixed_main().grill], fixed_main().name)


## What tomorrow's stock costs: every stocked ingredient station's fee, and re-laying
## the floor treatments switched on (PRD 9.5).
func night_cost() -> int:
	return Menu.night_cost(kitchen_stock()) + Treatments.night_cost(_laid_on_floor(), treat_off, treat_boxed())


## The treatments with a box stored somewhere: key -> true.
func treat_boxed() -> Dictionary:
	var out := {}
	for b: String in kitchen.stocked():
		if Treatments.is_box(b):
			out[Treatments.key_of(b)] = true
	return out


## The laid cells still floor (floor taken up takes its treatment with it).
func _laid_on_floor() -> Dictionary:
	var out := {}
	for c: Vector2i in treat_laid:
		if plan.has_floor(c):
			out[c] = treat_laid[c]
	return out


## The cells treated for tomorrow's service: laid, switched on, box stored.
func treat_active() -> Dictionary:
	return Treatments.active(_laid_on_floor(), treat_off, treat_boxed())


## Switches a laid treatment off (not re-laid, nothing paid) or back on.
func switch_treatment(key: String, on: bool) -> void:
	if on:
		treat_off.erase(key)
	else:
		treat_off[key] = true
	menu_changed()


## The restock note's ingredient lines, one per stocked kind: {name, fee}, dearest
## first. (Other lines, such as staff wages, are the note's own.)
func stock_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in kitchen_stock():
		if s.get("derived", false):
			continue   # made from another kind's stock, which is listed
		out.append({"name": Pantry.name_of(s.ingredient) + (" (ready)" if s.ready else ""),
			"fee": Pantry.fee_of(s.ingredient, s.ready)})
	var lines := Treatments.night_lines(_laid_on_floor(), treat_off, treat_boxed())
	for k: String in lines:   # floor treatments, re-laid each night (PRD 9.5)
		var l: Dictionary = lines[k]
		var why := "" if l.on else (", off" if treat_off.has(k) else ", no box")
		out.append({"name": "%s, %d cell%s%s" % [Treatments.name_of(k), l.cells, "" if l.cells == 1 else "s", why],
			"fee": l.fee})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.fee) > int(b.fee))
	return out


## The stations of one catalog type.
func stations_of(type: String) -> Array[Station]:
	var out: Array[Station] = []
	for st: Station in stations.values():
		if st.type == type:
			out.append(st)
	return out


## Something about tonight's menu changed: the board by the door and the notes follow.
func menu_changed() -> void:
	menu_board.refresh(tonight_menu())
	if phase == Phase.BUILD and not shopping:
		hud.show_build()


## Why the door card will not flip to open, or "" if it will.
func open_block() -> String:
	for id in ESSENTIALS:
		if missing(id):
			return "The kitchen needs a %s. Buy one in the shop (%s)." % [piece_name({"id": id, "tier": 1}).to_lower(), controls.glyph("shop")]
	if find_station("cups") == null and tonight_menu().any(func(it: Dictionary) -> bool: return it.course == "drink"):
		return "Drinks go out in cups: the kitchen needs a cup stack. Buy one in the shop (%s)." % controls.glyph("shop")
	if not Menu.has_main(tonight_menu()):
		if ledger.history.is_empty():
			return NIGHT_ZERO_BLOCK
		return "No main on the menu can be made. Check the menu (%s)." % controls.glyph("menu")
	if night_cost() > ledger.money:
		return "Tomorrow's stock costs $%d. You have $%d." % [night_cost(), ledger.money]
	return ""


## Night zero's three hints, one at a time as the player goes; "" once they are done
## or on any later night.
func night_hint() -> String:
	if not ledger.history.is_empty() or phase != Phase.BUILD:
		return ""
	if kitchen_stock().is_empty() or kitchen_tools().is_empty():
		return NIGHT_HINTS[0]
	if not Menu.has_main(tonight_menu()):
		return NIGHT_HINTS[1]
	return NIGHT_HINTS[2]


## The menu screen, at night only: it cannot change during service.
func open_menu(ch: Player = null) -> bool:
	ch = _me(ch)
	if phase != Phase.BUILD:
		if phase == Phase.SERVICE:
			hud.say("The menu can't change during service.")
			sfx("fail")
		return false
	if Cleaning.carrying_mess(ch.held) or hud.card_open():
		return false
	if shopping:
		close_shop()
	if not ch.hand.is_empty():
		cancel_hand(ch)
	hud.open_menu()
	sfx("slide")
	return true


func close_menu() -> void:
	if hud.menu_open():
		hud.close_menu()
		sfx("slide", 0.0, 0.8)
		menu_changed()


# ---------------------------------------------------------------- the desk (PRD 10.3)

## Desks in the room: one for each post and each hire.
func desk_count() -> int:
	return stations_of("desk").size()


## The desk the chef faces, or null.
func desk_in_front(ch: Player = null) -> Station:
	ch = _me(ch)
	var st: Station = stations.get(ch.target_cell())
	return st if st != null and st.type == "desk" else null


## The duties a post can hold tonight, by kind, read from the room (`Staff.room_duties`).
func room_duties() -> Dictionary:
	var pieces := []
	for st: Station in stations.values() + highs.values():   # a hook's sponge hangs high (PRD 9.4)
		pieces.append(st.type)
		if st.kit_tool != "":
			pieces.append(st.kit_tool)
	return Staff.room_duties(kitchen_tools(), pieces)


## The desk screen, at night only, from either chef. Everything about staff is done here.
func open_desk(ch: Player = null) -> bool:
	ch = _me(ch)
	if phase != Phase.BUILD or desk_count() == 0 or hud.card_open() or Cleaning.carrying_mess(ch.held):
		return false
	if shopping:
		close_shop()
	if not ch.hand.is_empty():
		cancel_hand(ch)
	hud.open_desk()
	sfx("slide")
	return true


func close_desk() -> void:
	if hud.desk_open():
		hud.close_desk()
		sfx("slide", 0.0, 0.8)
		_refresh_desks()


## Puts up a post. Refused (-1) when every desk is taken.
func desk_post(post_name: String, duties: Array, breaks: int, days_off: int) -> int:
	var id := staff.add_post(post_name, duties, breaks, days_off, desk_count())
	sfx("page" if id >= 0 else "fail")
	return id


func desk_take_down(id: int) -> void:
	for c in staff.cvs:
		if c.post == id:
			_send_home(int(c.person))
	staff.remove_post(id)
	sfx("page")
	_refresh_desks()


## Hires a CV at its ask (or `wage`). The post is filled: its other applicants go home.
func desk_hire(cv_id: int, wage := -1) -> bool:
	var c := staff.cv(cv_id)
	if c.is_empty():
		return false
	var others := staff.cvs.filter(func(o: Dictionary) -> bool: return o.post == c.post)
	if staff.hire(cv_id, wage, ledger.day) < 0:
		return false
	for o in others:
		_send_home(int(o.person), int(o.person) == int(c.person))
	sfx("coin")
	_refresh_desks()
	return true


func desk_dismiss(cv_id: int) -> void:
	var c := staff.cv(cv_id)
	if c.is_empty():
		return
	staff.dismiss(cv_id)
	_send_home(int(c.person))
	sfx("slide", 0.0, 0.8)
	_refresh_desks()


## Haggling at hire (section 5): "accept", "refuse", "take_last" or "walk".
func desk_haggle(cv_id: int, offer: int) -> String:
	var c := staff.cv(cv_id)
	if c.is_empty():
		return ""
	var others := staff.cvs.filter(func(o: Dictionary) -> bool: return o.post == c.post)
	var r := staff.haggle_hire(cv_id, offer, ledger.day)
	match r:
		"accept", "take_last":
			for o in others:
				_send_home(int(o.person), int(o.person) == int(c.person))
			sfx("coin")
		"refuse":
			sfx("fail")
		"walk":
			_send_home(int(c.person))
			sfx("fail")
	_refresh_desks()
	return r


## The start of the build phase: tonight's applicants send their CVs to the pile and
## stand in a line outside the door. Earlier CVs stay in the pile; their people do not
## queue again.
func roll_applicants() -> Array[Dictionary]:
	var fresh := staff.roll_applicants(Staff.candidates(town, ledger.day))
	_clear_applicants()
	for i in fresh.size():
		var person := int(fresh[i].person)
		var peg := Peg.guest(town.people[person].name)
		var rig := Peg.rigged(peg)
		add_child(rig)
		rig.position = queue_spot(i)
		rig.rotation.y = PI / 2   # facing the door
		applicants[person] = rig
	if not fresh.is_empty():
		hud.say("%s outside: %s in the pile at the desk." % [
			"An applicant is" if fresh.size() == 1 else "%d applicants are" % fresh.size(),
			"a CV" if fresh.size() == 1 else "their CVs"])
	_refresh_desks()
	return fresh


## Someone in tonight's line leaves it: hired (they come back to work, 10.6) or sent home.
func _send_home(person: int, hired := false) -> void:
	if not applicants.has(person):
		return
	var rig: Node3D = applicants[person]
	applicants.erase(person)
	burst(rig.position + Vector3(0, 1.2, 0), "stars" if hired else "puff", 0.4)
	rig.queue_free()


func _clear_applicants() -> void:
	for rig: Node3D in applicants.values():
		rig.queue_free()
	applicants.clear()


# ---------------------------------------------------------------- the staff list (PRD 10.4)

## Tonight's wages, for the restock note.
func staff_wages() -> int:
	return staff.wages_due()


## The night ends as the door opens: wages are paid with the stock, a STAFF line on the
## receipt. A wage that cannot be paid is not owed later; that employee takes the hit
## instead. Satisfaction moves, and anyone at the bottom too long quits.
func pay_staff() -> Dictionary:
	if staff.employees.is_empty():
		return {}
	var night := staff.end_night(ledger.money)
	ledger.pay_staff(int(night.paid), (night.unpaid as Array).size())
	var words: Array[String] = []
	for p: int in night.unpaid:
		if not (night.quit as Array).has(p):
			words.append("%s wasn't paid" % town.people[p].name)
	for p: int in night.quit:
		words.append("%s quit" % town.people[p].name)
	if not words.is_empty():
		hud.say(". ".join(words) + ".")
	return night


## Offers a hire a new duty. {ok: true} when taken, else {ok: false, raise} and the
## raise waits on the desk for an answer (`desk_answer_raise`).
func desk_add_duty(person: int, duty: String) -> Dictionary:
	var r := staff.propose_duty(person, duty)
	sfx("page" if r.ok else "fail")
	return r


## "withdraw", "approve", "deny" (they quit) or "haggle" with a smaller raise `offer`.
## Returns "added", "withdrawn", "refuse" or "quit".
func desk_answer_raise(person: int, choice: String, offer := 0) -> String:
	var r := staff.answer_raise(person, choice, offer)
	match r:
		"added":
			sfx("coin")
		"refuse", "quit":
			sfx("fail")
		"withdrawn":
			sfx("page")
	_refresh_desks()
	return r


func desk_remove_duty(person: int, duty: String) -> void:
	staff.remove_duty(person, duty)
	sfx("tick")


func desk_add_break(person: int) -> bool:
	var ok := staff.add_break(person)
	sfx("tick" if ok else "fail")
	return ok


func desk_add_day_off(person: int) -> bool:
	var ok := staff.add_day_off(person)
	sfx("tick" if ok else "fail")
	return ok


## Whether a day's wage can be paid as severance now.
func can_pay_severance(person: int) -> bool:
	var e := staff.employee(person)
	return not e.is_empty() and int(e.wage) <= ledger.money


## Fires a hire, with severance (a day's wage, paid now) or without (their opinion drops
## more and their friends hear it). False if the severance cannot be paid.
func desk_fire(person: int, severance: bool) -> bool:
	if staff.employee(person).is_empty() or (severance and not can_pay_severance(person)):
		sfx("fail")
		return false
	var r := staff.fire(person, severance)
	if int(r.cost) > 0:
		ledger.spend(int(r.cost))
	town.record_fired(person, float(r.drop), float(r.friend_drop))
	sfx("putdown")
	_refresh_desks()
	return true


## The CV pile on each desk: a sheet of paper per CV, up to a handful.
func _refresh_desks() -> void:
	for st in stations_of("desk"):
		var old := st.get_node_or_null("pile")
		if old:
			old.free()
		var n := staff.cvs.size()
		if n == 0:
			continue
		var pile := Node3D.new()
		pile.name = "pile"
		st.add_child(pile)
		for k in mini(n, 6):
			Build.box(pile, Vector3(0.12, 0.775 + k * 0.012, 0.08), Vector3(0.3, 0.008, 0.38), Build.PAPER) \
				.rotation.y = [0.0, 0.12, -0.08, 0.2, -0.15, 0.05][k]


## What this guest orders: {main, side, drink}. Chosen at the door with their group
## (`planned`); a guest who came in some other way chooses now.
func order_for(g: Guest) -> Dictionary:
	if not g.planned.is_empty():
		return g.planned
	return Menu.order(tonight_menu(), g.info.likes, g.info.dislikes, town.rng)


## The chef takes the whole table's order in one go. Each guest who ordered
## something gets a ticket on the rail.
func take_orders(table: Station) -> void:
	for g in _guests_to_order(table):
		var o := order_for(g).duplicate()
		var items: Array[Dictionary] = []
		for c in Menu.COURSES:
			if not (o.get(c, {}) as Dictionary).is_empty():
				items.append(o[c])
				town.record_order(g.idx, int(o[c].id))
		o["ticket"] = -1
		if not items.is_empty():
			o.ticket = _next_ticket
			_next_ticket += 1
			var order := Tray.new()
			order.assign(o.ticket, items)
			tickets.append({"id": o.ticket, "guest": g, "items": items, "order": order})
		g.take_order(o)
		g.mood.patience = minf(1.0, g.mood.patience + ORDER_RELIEF)
	hud.refresh_tickets()
	sfx("order_take")


func find_ticket(id: int) -> Dictionary:
	for t in tickets:
		if int(t.id) == id:
			return t
	return {}


## Everyone with hands in the room: the chefs, then the helpers at work (PRD 10.6).
func hands() -> Array[Player]:
	var out: Array[Player] = chefs.duplicate()
	if crew != null:
		out.append_array(crew.helpers)
	return out


## Every order on the rail: what each guest has been served so far.
func all_trays() -> Array[Tray]:
	var out: Array[Tray] = []
	for tk: Dictionary in tickets:
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
	var it := d.item_of(menu.items)
	if it.is_empty():
		return null
	var best: Guest = null
	for s in table.seats:
		if not seat_taken.has(s):
			continue
		var g: Guest = seat_taken[s]
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
		if t.serve_dish(d, menu.items) < 0:
			continue
		ch.drop_dish(d)
		n += 1
		if t.is_complete():
			serve(g, t)
		else:
			g.show_served(t)
			sfx("plate_food")
	hud.refresh_tickets()
	return n


## Why none of the dishes in hand can be served here.
func _not_served_why(dishes: Array) -> String:
	for d: Dish in dishes:
		if d.vessel == "" and not d.is_empty():
			return "Put it on a plate first"
	for d: Dish in dishes:
		if d.is_empty():
			continue
		if d.item_of(menu.items).is_empty():
			var it := d.heading_for(menu.items)
			if not it.is_empty():
				var need := d.needs_for(it)
				if not need.is_empty():
					return "Needs %s" % Pantry.name_of(need[0]).to_lower()
	return "Nobody here ordered that"


## Turns a dispenser with several taps to its next tap.
func turn_tap(st: Station) -> bool:
	if st == null or dispenser_drinks(st).size() < 2:
		return false
	st.tap = (st.tap + 1) % dispenser_drinks(st).size()
	hud.say("Turned to %s." % Pantry.name_of(dispenser_drinks(st)[st.tap]).to_lower())
	sfx("page")
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
	tickets.erase(tk)
	var t: Tray = tk.get("order")
	if t != null and t.served_count() > 0 and g.state in ["waiting", "ordering"] and g.table != null:
		_leave_dirty(g.table, t)
		g.clear_meal()
	hud.refresh_tickets()


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
	if g == critic_guest:
		_critic_seen = {"patience": g.mood.patience, "quality": t.quality()}
		if Critic.speed_rating(g.mood.patience) <= 3:
			g.mood.think(Critic.thought("wait"))
		g.mood.think(Critic.thought("good" if Critic.quality_rating(t.quality()) >= 4 else "bad"))
	if g.mood.patience > 0.65:
		g.mood.delight(0.15, "That was quick!")
	var q := savour_for(g, t)
	var perfect := t.quality() > 0.95
	g.mood.think("Perfectly done" if perfect else ("Just right" if t.quality() >= Prep.PLAIN - 0.01 else "A bit off, this"))
	g.bill_base = t.price()
	tickets.erase(find_ticket(t.ticket))
	t.ticket = -1
	hud.refresh_tickets()
	g.liked_meal = Menu.liked_count(t.ingredients(), g.info.likes) > 0
	if g.liked_meal:
		g.mood.think(Menu.LIKED_THOUGHT)
	var settled := g.start_eating(q, t)
	if settled != "":
		g.mood.think(settled)
	sfx("serve")
	if perfect:
		sfx("perfect")
		burst(g.position + Vector3(0, 1.3, 0), "stars")


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
func offer_discount(g: Guest) -> void:
	if not g.mood.offer_discount():
		return
	town.record_kindness(g.idx, "half")
	hud.say("Half price for %s. Word gets around." % g.info.name)
	burst(g.position + Vector3(0, 1.5, 0), "stars", 0.3)
	g._heart_time = 1.5
	sfx("coin")


## The bigger kindness: the meal is free, for a guest who is very unhappy. Their
## friends hear about it.
func offer_comp(g: Guest) -> void:
	if not g.mood.offer_comp():
		return
	town.record_kindness(g.idx, "comp")
	hud.say("%s eats free tonight. Their friends will hear of it." % g.info.name)
	burst(g.position + Vector3(0, 1.5, 0), "stars")
	g._heart_time = 2.5
	sfx("perfect")


## The last bite (PRD 11): the plate is left on the table and they sit back to chat.
## Paying comes later, when the bill is handed over (`pay_bill`).
func finish_meal(g: Guest) -> void:
	if g._meal_tray != null:
		_leave_dirty(g.table, g._meal_tray)
	else:
		g.table.dirty += 1
		g.table.refresh()
	floor_dirt.meal_mess(g)
	if g._meal:
		g._meal.queue_free()
		g._meal = null
	g.state = "chatting"
	g.timer = Guest.CHAT_TIME


## One guest pays their share of the table's bill: what `finish_meal` paid before PRD 11.
func _pay_guest(g: Guest) -> void:
	var bill := g.mood.pay_for(g.bill_base)
	if g.mood.paid_full():   # someone used to deals is let down by full price
		var letdown := town.paid_full_price(g.idx)
		if letdown > 0.0:
			g.mood.delight(-letdown, "Full price this time? Hm")
	var tip := g.mood.tip_for(bill, town.tip_bonus(g.idx))
	var was_sore: bool = g.info.sore
	var was_regular := town.is_regular(g.idx)
	ledger.record_sale(bill, tip)
	var delta := town.record_visit(g.idx, g.mood.satisfaction(),
		g.mood.satisfaction_terms(g._meal_tray.quality() if g._meal_tray else -1.0))
	var talk := town.gossip_line(g.idx, delta, Town.praise_about(g.liked_meal, g.hint_tag) if delta > 0.0 else "")
	if was_sore and not g.info.sore:
		talk = "%s has forgiven you." % g.info.name
	elif town.is_regular(g.idx) and not was_regular:
		talk = "%s is now a regular!" % g.info.name
		burst(g.position + Vector3(0, 1.5, 0), "stars")
	var news := town.record_disgust(g.idx, g.mood.disgust_level())
	if news != "":
		talk = news
	if talk != "":
		hud.say(talk)
	_critic_leaves(g, false)
	popup("+$%d" % (bill + tip), g.position + Vector3(0, 1.9, 0), Color(Build.TRIM))
	Fx.coin(self, g.position + Vector3(0, 1.5, 0))
	if g.mood.satisfaction() > 0.5:
		g._heart_time = 2.5


# ---------------------------------------------------------------- paying (PRD 11)

const TILL_AFTER := 12.0   # tunable: seconds ready to pay before one of them goes to the till
const HAND_TIME := 1.0     # tunable: seconds of held E to hand a bill over
const CALL_EVERY := 0.5    # how often a ready table looks for someone to wave at
const TILL_GAP := 0.75     # metres between guests queued at the till
var pay_since := {}        # table Station -> clock when it became ready to pay
var _call_t := 0.0


## Every table with seats, in a fixed order: down the room, then across. Numbered from 1.
func dining_tables() -> Array[Station]:
	var out: Array[Station] = []
	for st: Station in stations.values():
		if not st.seats.is_empty():
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
	for g: Guest in guests:
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


## Seconds this guest's table has been ready to pay, or -1 when it is not.
func pay_wait(g: Guest) -> float:
	if not g.paying() or not pay_since.has(g.table):
		return -1.0
	return clock - float(pay_since[g.table])


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
	var st: Station = stations.get(cell)
	if st == null or not (st.type == "counter" or Kitchen.is_top(st.type)) or st.has_node("till") or needs_cleaning(st):
		return null
	return st


func till_station() -> Station:
	for st: Station in stations.values():
		if st.has_node("till"):
			return st
	return null


func till_cell() -> Vector2i:
	var st := till_station()
	return st.cell if st != null else NO_CELL


## The room-side cell in front of the till, where the line to pay starts.
func till_front() -> Vector2i:
	var t := till_cell()
	if t == NO_CELL:
		return NO_CELL
	var best := NO_CELL
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]:
		var c := t + d
		if grid.in_bounds(c) and not grid.is_blocked(c) and grid.edge_open(t, c) and (best == NO_CELL or c.x > best.x):
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
	for g: Guest in guests:
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
		g.walk_to(c if grid.in_bounds(c) else till_front(), at)
		if g.state == "at_till" and g.position.distance_to(at) > 0.05:
			g.state = "to_till"


## One of a ready table's guests stands and walks to the till.
func send_to_till(table: Station) -> Guest:
	if till_front() == NO_CELL:
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
	var out: Array[Player] = chefs.duplicate()
	if crew != null:
		for h in crew.helpers:
			if crew.has_duty(h, "take_payment"):
				out.append(h)
	return out


func _sees(table: Station, who: Player) -> bool:
	return grid.has_los(table.cell, who.cell())


## The table numbers waiting to pay, for the bill screen: {number, size, till, printed}.
func bill_tables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st in dining_tables():
		if ready_to_pay(st):
			var at_till := party_at(st).any(func(g: Guest) -> bool: return g.state == "at_till" or g.state == "to_till")
			out.append({"number": table_number(st), "size": party_at(st).size(), "till": at_till,
				"printed": slip_out(table_number(st))})
	return out


## A slip for this table is already printed and in someone's hand.
func slip_out(number: int) -> bool:
	for h in hands():
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
			pay_since[st] = clock
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
					sfx("bell", 0.04, 1.3)
			elif not seen and caller != null:
				caller.calling = false
		var at_till := party_at(st).any(func(g: Guest) -> bool: return g.state == "to_till" or g.state == "at_till")
		if not at_till and clock - float(pay_since[st]) >= TILL_AFTER and not slip_out(table_number(st)):
			send_to_till(st)
	# Slips for tables that have gone are thrown away.
	for h in hands():
		if h.held == "bill" and h.bill != null and not ready_to_pay(table_by_number(h.bill.table)) \
				and payers(table_by_number(h.bill.table)).is_empty():
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
		_pay_guest(g)
	sfx("coin")
	_party_leaves(table)


## A party waited to pay until they gave up (PRD 11): no money, no tip, an opinion drop
## friends hear about. Not a walkout and not a strike.
func leave_unpaid(table: Station) -> void:
	var p := payers(table)
	if p.is_empty():
		return
	ledger.record_unpaid_bill()
	var talk := ""
	for g in p:
		g.mood.skipped_bill = true
		g.mood.think("Nobody came with the bill")
		_critic_leaves(g, false)
		talk = town.left_unpaid(g.idx)
	hud.say(talk if p.size() == 1 else "Table %d left without paying. Nobody came." % table_number(table))
	sfx("fail")
	_party_leaves(table)


## Where the chef holding a bill would hand it over: the table they face, if its party is
## waiting to pay, or the till they face, if someone is queued there. Null for neither.
func bill_target(ch: Player) -> Station:
	if ch.held != "bill":
		return null
	var st := station_at(ch.target_cell())
	return st if bill_place(st) else null


## A bill can be handed over here: a table whose party waits to pay, or the till with
## someone queued at it.
func bill_place(st: Station) -> bool:
	if st == null:
		return false
	if not st.seats.is_empty() and ready_to_pay(st):
		return true
	return st == till_station() and till_line().any(func(g: Guest) -> bool: return g.state == "at_till")


## The table a bill handed over at `at` is checked against: that table, or at the till
## the table of the guest there it is written for (else the guest at the front).
func _bill_table_at(at: Station, bill: Bill) -> Station:
	if at != till_station():
		return at
	var front: Station = null
	for g in till_line():
		if g.state != "at_till":
			continue
		if table_number(g.table) == bill.table:
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
	var line := Bill.refusal(diff, menu)
	for g in party_at(table):
		g.mood.refuse_bill(line)
	var who := payers(table)
	if not who.is_empty():
		hud.say("%s: \"%s.\"" % [who[0].info.name, line])
		Fx.play(who[0], "anger", Vector3(0, 1.75, 0), 0.3)
	sfx("fail")
	return false


## Opens the bill screen for a chef at the till.
func open_bill(ch: Player) -> void:
	hud.open_bill(ch)
	sfx("page")


func close_bill() -> void:
	hud.close_bill()


## "Print": the slip goes into the chef's hand, and the screen closes.
func print_bill(ch: Player, bill: Bill) -> void:
	if bill.table < 0 or bill.is_empty() or slip_out(bill.table) or ch.held != "":
		sfx("fail")
		return
	var slip := Bill.new(bill.table, bill.items)
	ch.set_held("bill")
	ch.bill = slip
	close_bill()
	sfx("page")


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
	ledger.record_walkout()
	var names: Array[String] = []
	var talk := ""
	for m in going:
		m.mood.think("I'm never coming back")
		m.stormed = true
		talk = town.gossip_line(m.idx, town.record_walkout(m.idx, ledger.day))
		_critic_leaves(m, true)
		names.append(m.info.name)
		var mark := Fx.play(m, "anger", Vector3(0, 1.75, 0), 0.3, true)
		mark.fps = 6.0
		_leave(m)
	hud.say(("%s walked out! " % " and ".join(names)) + (talk if going.size() == 1 else ""))
	sfx("fail")
	shake()


## A guest who found nothing they liked goes once their friends have gone.
func leave_with_friends(g: Guest) -> void:
	_leave(g)


func _leave(g: Guest) -> void:
	tear_ticket(g)
	seat_taken.erase(g.seat)
	g.stand_up()
	g.walk_to(EXIT)
	if queue.has(g):
		queue.erase(g)
		_reflow_queue()
		g.line_place = -1
		# Out of the line onto the outer half of the pavement first, not down
		# through the people still waiting.
		var out := Vector2i(W + 1, g.cell.y)
		g.path.assign(grid.find_path(g.cell, out) + grid.find_path(out, EXIT))


func remove_guest(g: Guest) -> void:
	if inspected == g:
		inspect(null)
	guests.erase(g)
	g.queue_free()


# ---------------------------------------------------------------- cooking & carrying

## What using this station would do right now, e.g. "Cook". Empty when nothing.
func prompt_for(st: Station, ch: Player = null) -> String:
	ch = _me(ch)
	var s := prep_of(chefs.find(ch))
	if not s.is_empty():
		return {"chop": "Chop on the notch", "slice": "Slice %d times" % Prep.SLICE_COUNT,
			"pour": "Let go to stop", "grate": "Hold to grate, keep it green",
			"saw": "Press at the end of each stroke", "juice": "Squeeze, let go on the green",
			"blend": "Pulse %d times, don't spill" % Prep.BLEND_PULSES, "steam": "Lift the lid on the green"}.get(s.tool, "")
	return use_station(st, true, ch)


## Which tool's way of working a station is used as right now (PRD 8.3): a heat tool
## works as the tool of what is cooking on it, or of the raw thing in hand when it can
## cook that at all (a stove that fries works as a fryer). Others as themselves.
func _use_as(st: Station, held_ing: Dictionary) -> String:
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
	ch = _me(ch)
	var kit := clean_kit.station_use(st, dry_run, ch)   # cleaning tools first (PRD 9.4)
	if kit != "" or CleanKit.holding(ch):
		return kit   # a tool fills the hands: nothing else is done with it
	return _use_station(st, dry_run, ch)


func _use_station(st: Station, dry_run := false, ch: Player = null) -> String:
	ch = _me(ch)
	Build.menu = menu.items
	var held := ch.held
	var q := ch.held_quality
	var held_ing := Tray.parse(held)
	var act := ""
	var why := ""
	# Paying (PRD 11): the till writes bills; a slip in hand is handed over with a held E.
	if held == "" and st == till_station() and st.item == "" and not bill_tables().is_empty():
		if not dry_run:
			open_bill(ch)
		return "Write the bill"
	if held == "bill":
		if bill_place(st):
			return "Hold to give the bill"
		if st.type == "bin":
			if not dry_run:
				ch.set_held("")
				st.count += 1
				st.refresh()
			return _finish_use(st, ["Throw away", ""], dry_run, ch)
		if not st.seats.is_empty() or st == till_station():
			return _finish_use(st, ["", "Nobody here is waiting to pay"], dry_run, ch)
		return ""
	var ing := Catalog.ingredient_of(st.type)   # a drink dispenser's own drink
	var taps := dispenser_drinks(st)
	var drinks_here := ing != "" and not taps.is_empty() and Pantry.is_drink(ing)
	if surface_first(st, held) and not (drinks_here and held in ["", "dishes"] and st.item == ""):
		return _finish_use(st, _use_surface(st, dry_run, ch), dry_run, ch)
	if taps.size() > 1:
		# Two taps (PRD 8.6): pour what the cup and a ticket want, else the tap it is
		# turned to (Turn, or Use with empty hands, turns it).
		ing = pour_pick(st, taps, _cup_in_hand(ch, ""))
		if held == "":
			act = "Turn to %s" % Pantry.name_of(taps[(st.tap + 1) % taps.size()]).to_lower()
			if not dry_run:
				turn_tap(st)
			return act
	if drinks_here:
		# A drink station fills the cup in hand (PRD: drinks go out in cups).
		var cup := _cup_in_hand(ch, ing)
		if cup != null:
			var pour: bool = Pantry.tool_of(ing) == "pour" and not Catalog.ITEMS.get(st.type, {}).get("ready", false)
			act = ("Pour %s" if pour else "Fill with %s") % Pantry.name_of(ing).to_lower()
			if not dry_run:
				if pour:
					start_prep(chefs.find(ch), st, "pour", ing, "", cup)
					return act
				cup.add(Tray.kind("prep", ing), Prep.PLAIN)
				ch.show_held()
		elif held == "":
			why = "Bring a cup for the %s" % Pantry.name_of(ing).to_lower()
		elif held == "dishes":
			var cups := ch.dishes.filter(func(d: Dish) -> bool: return d.vessel == Dish.CUP)
			why = "Bring a cup" if cups.is_empty() else (cups[0] as Dish).refusal(Tray.kind("prep", ing), menu.items)
		return _finish_use(st, [act, why], dry_run, ch)
	if ing != "":
		var ready: bool = Catalog.ITEMS[st.type].get("ready", false) if Catalog.ITEMS.has(st.type) else false
		if held == "" and Pantry.tool_of(ing) == "pour":
			act = "Pour %s" % Pantry.name_of(ing).to_lower()
			if not dry_run:
				start_prep(chefs.find(ch), st, "pour", ing)
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
					ch.set_held("")
			elif held == "" and st.item != "":
				act = "Take off the heat"
				if not dry_run:
					var p := Tray.parse(st.item)
					var res := Prep.grill(st.cook, st.q("grill"))
					ch.set_held(Tray.kind(res.state, p.id), res.quality)
					st.set_item("")
					_prep_done(chefs.find(ch), st, "grill", res.result)
			elif not held_ing.is_empty() and st.item == "":
				why = "%s doesn't go on the grill" % Pantry.name_of(held_ing.id)
		"fryer":
			if st.item == "" and not held_ing.is_empty() and held_ing.state == "raw" and Pantry.tool_of(held_ing.id) == "fry":
				act = "Fry"
				if not dry_run:
					st.set_item(held)
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
					_prep_done(chefs.find(ch), st, "fry", res.result)
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
					floor_dirt.prep_grease("boil", "plain", ch.cell(), st)
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
				why = "In use"
			elif pj[0] != "":
				act = str(PRESS_VERBS[tool])
				if not dry_run:
					start_prep(chefs.find(ch), st, tool, pj[1], held)
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
		"plates", "cups":
			# One plate or cup a press; two in the hands, four on a tray. An empty one in
			# hand goes back.
			var v := Dish.PLATE if st.type == "plates" else Dish.CUP
			var noun := "plate" if v == Dish.PLATE else "cup"
			var spare := _empty_in_hand(ch, v)
			if spare != null:
				act = "Put back"
				if not dry_run:
					st.count += 1
					ch.drop_dish(spare)
			elif st.count > 0 and held in ["", "tray", "dishes"] and ch.has_room():
				act = "Take %s" % noun
				if not dry_run:
					st.count -= 1
					ch.take_dish(Dish.make(v))
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
			# Plates and cups soak until they are washed, one at a time, back onto their stacks.
			if held == "dirty_dishes":
				act = "Put in sink"
				if not dry_run:
					st.dirty += ch.dishes.size()
					st.dirty_cups += ch.dishes.filter(func(d: Dish) -> bool: return d.vessel == Dish.CUP).size()
					ch.set_held("dirty_dishes", 1.0, [], ch.on_tray)
					st.refresh()
			elif held == "" and st.dirty > 0:
				act = "Wash"
				if not dry_run:
					wash_one(st)
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
		"table", "booth", "table4":
			var g := _waiting_guest_at(st)
			var to_order := _guests_to_order(st)
			var fed: Array[Guest] = []
			if held == "dishes":
				fed = _dish_guests(st, ch.dishes)
			if not fed.is_empty():
				act = "Serve %s" % fed[0].info.name if fed.size() == 1 else "Serve %d" % fed.size()
				if not dry_run:
					serve_dishes(ch, st)
			elif not to_order.is_empty() and (held == "" or not ORDER_HANDS_FREE):
				act = "Take order" if to_order.size() == 1 else "Take %d orders" % to_order.size()
				if not dry_run:
					take_orders(st)
			elif held == "dishes" and not to_order.is_empty():
				why = "Take order first"
				if not dry_run:
					hud.say("%s hasn't ordered yet. Free your hands and take the order." % to_order[0].info.name)
					sfx("fail")
					return why
			elif held == "dishes" and g != null:
				why = _not_served_why(ch.dishes)
			elif held in ["", "tray", "dirty_dishes"] and st.dirty > 0 and ch.has_room(true):
				act = "Clear plates"
				if not dry_run:
					clear_one(st, ch)
					while st.dirty > 0 and ch.has_room(true):
						clear_one(st, ch)
			elif held == "" and g != null and not g.mood.discounted and g.mood.patience < DISCOUNT_BELOW:
				act = "Half price for %s" % g.info.name
				if not dry_run:
					offer_discount(g)
			elif held == "" and g != null and not g.mood.comped and g.mood.very_unhappy():
				act = "Free meal for %s" % g.info.name   # after half price, or for disgust
				if not dry_run:
					offer_comp(g)
	if act == "" and not st.type in ["counter", "pass"]:
		var r := _use_storage(st, dry_run, ch)   # what the tool cannot do, storage below may
		if r[0] != "":
			return _finish_use(st, r, dry_run, ch)
	if act == "" and held != "" and Kitchen.is_top(st.type) and not st.type in ["stove", "fryer", "pot"]:
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
			hud.say(why + ".")
			sfx("fail")
		return why
	if act != "" and not dry_run:
		ch.punch()
		st.used()
		if act == "Wash":
			sfx("wash")
			burst(st.position + Vector3(0, 1.15, 0), "bubbles", 0.4)
		elif act == "Grill":
			sfx("grill_drop")
		elif act == "Take off the heat":
			sfx("patty_flip")   # the spatula under the patty
		elif act.begins_with("Add "):
			sfx("plate_food")   # onto a plate
		elif not (act.begins_with("Serve") or act.begins_with("Half") or act.begins_with("Free") or act.begins_with("Take order") or act.ends_with(" orders")):
			sfx("pickup" if ch.held != "" else "putdown")
	return act


## The storage under a cell (PRD 8.4). Empty hands take its first kind; holding a kind
## as it came out of a box here, each use swaps it for the next kind, or with one kind
## puts it back. Returns [action, refusal].
func _use_storage(st: Station, dry_run: bool, ch: Player) -> Array:
	var boxes := kitchen.stock(st.cell).filter(func(b: String) -> bool: return not Kitchen.is_cleaning(b))
	if boxes.is_empty():
		return ["", ""]
	var held := ch.held
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
	var items := menu.items
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
			act = "Put down"
			if not dry_run:
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
				act = "Plate it" if target.vessel == Dish.PLATE and target.is_empty() else (
					"Add %s" % Pantry.name_of(loose.ings[0]).to_lower() if loose.ings.size() == 1 else "Add it")
				if not dry_run:
					target.take_all(loose)
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


## A cup in hand that this drink can go in ("" for any cup), or null.
func _cup_in_hand(ch: Player, drink: String) -> Dish:
	if ch.held != "dishes":
		return null
	for d: Dish in ch.dishes:
		if d.vessel == Dish.CUP and (drink == "" or d.refusal(Tray.kind("prep", drink), menu.items) == ""):
			return d
	return null


## Washes one dish in a sink back onto its stack: plates first.
func wash_one(st: Station) -> void:
	var cup := st.dirty_cups >= st.dirty
	st.dirty -= 1
	if cup:
		st.dirty_cups -= 1
	st.refresh()
	var stack := find_station("cups" if cup else "plates")
	if stack != null:
		stack.count += 1
		stack.refresh()


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
	return (held == "" and st.item != "") or held in ["dishes", "tray"] or st.item == "dish"


# ---------------------------------------------------------------- prep minigames

## `src`: the kind the chef held, when it differs from what is made (a lemon for
## lemonade, PRD 8.6); it sits on the tool meanwhile and comes back on Back.
func start_prep(p: int, st: Station, tool: String, ing: String, src := "", cup: Dish = null) -> void:
	var chef: Player = chefs[p]
	var hands := {"cup": cup, "dishes": chef.dishes.duplicate(), "on_tray": chef.on_tray}
	var q := st.q(tool) if st.q(tool) > 0.0 else 1.0
	preps[p] = {"tool": tool, "st": st, "ing": ing, "t": 0.0, "hits": [], "presses": 0, "fill": 0.0, "last": 0.0,
		"q": q, "sweep": Prep.chop_sweep(q), "auto": Kitchen.is_auto(st.node),
		"src": src if src != "" else Tray.kind("raw", ing), "v": 0.0, "w": 0.0, "was_held": true}
	if cup != null:
		preps[p].merge(hands)   # the dishes in hand wait while the cup is filled
	if tool == "saw":
		preps[p].sweep = Prep.saw_stroke(q)
	st.prep_by = p
	chef.set_held("")
	if tool != "pour":
		st.set_item(preps[p].src)
	st.show_widget(tool, q, ing if tool in ["pour", "grate", "blend", "juice"] else "")
	chef.punch()
	st.used()
	_show_prep(p)


func prep_of(p := 0) -> Dictionary:
	return preps.get(p, {})


## Use was pressed during a minigame.
func prep_press(p: int) -> void:
	var s: Dictionary = preps[p]
	if s.get("auto", false):
		return   # it plays itself
	match s.tool:
		"chop":
			if s.hits.size() == int(s.t / s.sweep) and s.hits.size() < Prep.CHOP_SWEEPS:
				var hit := Prep.chop_hit(_chop_pos(s), s.q)
				s.hits.append(hit)
				sfx("chop", 0.1, 1.0 if hit else 0.8)
				chefs[p].punch()
		"slice":
			s.presses += 1
			s.last = s.t
			sfx("slice", 0.15)
			chefs[p].punch()
		"saw":
			if s.hits.size() == int(s.t / s.sweep) and s.hits.size() < Prep.SAW_STROKES:
				var hit := Prep.saw_hit(_chop_pos(s), s.q)
				s.hits.append(hit)
				sfx("chop", 0.1, 0.7 if hit else 0.55)
				chefs[p].punch()
		"blend":
			s.presses += 1
			s.w += Prep.blend_kick(s.q)
			sfx("slice", 0.15, 0.6)
			chefs[p].punch()
		"steam":
			s.lift = true
	_show_prep(p)


## Back leaves a press-based minigame and gives the ingredient back raw.
func cancel_prep(p: int) -> void:
	var s: Dictionary = preps[p]
	preps.erase(p)
	var st: Station = s.st
	st.prep_by = -1
	st.hide_widget()
	if s.tool != "pour":
		st.set_item("")
		chefs[p].set_held(s.src, Prep.PLAIN if str(s.src).begins_with("prep") else 1.0)
	elif s.get("cup") != null:
		chefs[p].set_held("dishes", 1.0, s.dishes, s.on_tray)
	sfx("putdown")


func _chop_pos(s: Dictionary) -> float:
	return fmod(s.t, s.sweep) / s.sweep


func _tick_preps(delta: float) -> void:
	for p: int in preps.keys():
		var s: Dictionary = preps[p]
		if s.get("frozen", false):
			continue   # a demo shot
		s.t += delta
		var result := ""
		if s.get("auto", false):   # an auto piece plays itself: always good, no burst
			s.presses = mini(int(s.t / Prep.AUTO_TIME * Prep.SLICE_COUNT), Prep.SLICE_COUNT)
			s.hits = []
			for k in mini(int(s.t / Prep.AUTO_TIME * Prep.CHOP_SWEEPS), Prep.CHOP_SWEEPS):
				s.hits.append(true)
			if s.t >= Prep.AUTO_TIME:
				_finish_prep(p, "good")
			else:
				_show_prep(p)
			continue
		match s.tool:
			"chop":
				while s.hits.size() < mini(int(s.t / s.sweep), Prep.CHOP_SWEEPS):
					s.hits.append(false)   # a sweep went by without a press
				if s.hits.size() >= Prep.CHOP_SWEEPS:
					result = Prep.chop(s.hits.count(true))
			"slice":
				if s.t >= Prep.slice_time(s.q) or (s.presses >= Prep.SLICE_COUNT and s.t - s.last > 0.5):
					result = Prep.slice(s.presses, s.q)
			"pour":
				if controls.holding(p, "use"):
					s.fill += Prep.pour_rate(s.q) * delta
					if s.fill > 1.04:
						result = "bad"   # overflowed
				else:
					result = Prep.pour(s.fill, s.q)
			"grate":
				var holding := controls.holding(p, "use")
				s.v = Prep.grate_speed(s.v, holding, delta, s.q)
				var band := Prep.grate_band(s.q)
				if s.v >= band.x and s.v <= band.y:
					s.fill += delta / Prep.GRATE_FILL
					if fmod(s.t, 0.25) < delta:
						sfx("slice", 0.1, 1.3)
				result = Prep.grate(s.t, s.fill >= 1.0, s.v > 1.0, s.q)
			"saw":
				while s.hits.size() < mini(int(s.t / s.sweep), Prep.SAW_STROKES):
					s.hits.append(false)   # a stroke went by without a press
				if s.hits.size() >= Prep.SAW_STROKES:
					result = Prep.saw(s.hits.count(true))
			"juice":
				var holding := controls.holding(p, "use")
				if holding:
					s.fill += Prep.juice_rate(s.q) * delta
					if s.fill > 1.0:   # pressed too hard: the pips squirt
						s.hits.append(false)
						s.fill = 0.0
						sfx("wobble", 0.1)
				elif s.fill >= Prep.JUICE_MIN:
					var hit := Prep.juice_hit(s.fill, s.q)
					s.hits.append(hit)
					sfx("pickup", 0.1, 1.2 if hit else 0.8)
					chefs[p].punch()
					s.fill = 0.0
				else:
					s.fill = 0.0
				if s.hits.size() >= Prep.JUICE_HALVES:
					result = Prep.juice(s.hits.count(true))
			"blend":
				s.w = Prep.blend_settle(s.w, delta)
				result = Prep.blend(s.t, s.presses, s.w > 1.0, s.q)
			"steam":
				var frac: float = s.t / Prep.steam_time(s.q)
				if s.get("lift", false) or frac >= Prep.STEAM_OVER:
					result = Prep.steam(frac, s.q)
		if result != "":
			_finish_prep(p, result)
		else:
			_show_prep(p)


func _show_prep(p: int) -> void:
	var s: Dictionary = preps[p]
	var w: PrepWidget = s.st.widget
	match s.tool:
		"chop":
			w.show_state({"pos": _chop_pos(s), "hits": s.hits})
		"slice":
			w.show_state({"presses": s.presses, "left": 1.0 - s.t / (Prep.AUTO_TIME if s.get("auto", false) else Prep.slice_time(s.q))})
		"pour":
			w.show_state({"fill": s.fill})
		"grate":
			w.show_state({"v": s.v, "fill": s.fill})
		"saw":
			w.show_state({"pos": _chop_pos(s), "stroke": int(s.t / s.sweep), "hits": s.hits})
		"juice":
			w.show_state({"p": s.fill, "hits": s.hits})
		"blend":
			w.show_state({"w": s.w, "pulses": s.presses})
		"steam":
			w.show_state({"frac": s.t / Prep.steam_time(s.q)})


func _finish_prep(p: int, result: String) -> void:
	var s: Dictionary = preps[p]
	preps.erase(p)
	var st: Station = s.st
	st.prep_by = -1
	st.hide_widget()
	if s.tool != "pour":
		st.set_item("")
	if s.get("cup") != null:
		(s.cup as Dish).add(Tray.kind("prep", s.ing), Prep.quality_of(result))
		chefs[p].set_held("dishes", 1.0, s.dishes, s.on_tray)
	else:
		chefs[p].set_held(Tray.kind("prep", s.ing), Prep.quality_of(result))
	sfx("pickup")
	_prep_done(p, st, s.tool, result)


## A minigame ended: a mark over the tool, and the chef's burst or penalty.
func _prep_done(p: int, st: Station, tool: String, result: String) -> void:
	if result == "" or p < 0:
		return
	floor_dirt.prep_grease(tool, result, chefs[p].cell(), st)
	PrepWidget.pop(st, Vector3(0, 2.0, 0), result)
	match Prep.reward(tool, result, Kitchen.is_auto(st.node) and tool in ["chop", "slice"]):
		"burst":
			chefs[p].boost("burst")
			sfx("zoom")
		"penalty":
			chefs[p].boost("penalty")
			sfx("wobble")


func _cancel_all_preps() -> void:
	for p: int in preps.keys():
		cancel_prep(p)


func _tick_stoves(delta: float) -> void:
	var loops := {}
	for st: Station in stations.values():
		var stage := st.tick_cooking(delta)
		if stage == "prep":
			sfx("ding")
			burst(st.position + Vector3(0, 1.2, 0), "stars", 0.4)
		elif stage == "burnt":
			sfx("burn")
			shake(0.08)
		elif stage == "rested":
			sfx("tick")
		if st.sizzle_stage() != "":
			loops[st.sizzle_stage()] = true
	_fade_loops(loops, delta)


## Fades each looping sound toward on (wanted) or off, so a patty's sizzle changes
## smoothly as it cooks; one that has faded out stops.
func _fade_loops(want: Dictionary, delta: float) -> void:
	for id: String in LOOPING:
		if not _sfx.has(id):
			continue
		var p: AudioStreamPlayer = _sfx[id]
		var on := want.has(id)
		if on and not p.playing:
			p.volume_db = LOOP_OFF
			p.play()
		if p.playing:
			p.volume_db = move_toward(p.volume_db, float(SOUNDS[id]) if on else LOOP_OFF, LOOP_FADE * delta)
			if not on and p.volume_db <= LOOP_OFF:
				p.stop()


func step(delta: float) -> void:
	for st: Station in stations.values():
		st.dirty_age = Cleaning.aged(st.dirty_age, delta, st.messy(), phase == Phase.SERVICE)
	_tick_floor(delta)
	if phase != Phase.SERVICE:
		return
	clock += delta
	while not arrivals.is_empty() and float(arrivals[0].time) <= clock:
		var a: Dictionary = arrivals.pop_front()
		spawn_group(a.get("group", [a.get("idx", 0)]), a.get("critic", false))
	_tick_stoves(delta)
	_tick_preps(delta)
	for c in chefs:
		c.tick(delta)
	crew.tick(delta)
	_collect_gross()
	_seat_waiting_guests()
	for g in guests.duplicate():
		g.tick(delta)
	_tick_paying(delta)
	if ledger.is_closed_down():
		_close_down()
	elif arrivals.is_empty() and guests.is_empty():
		_end_day()


# ---------------------------------------------------------------- input & frame

func _process(delta: float) -> void:
	Build.menu = menu.items   # loose stacks draw in the order of the item they are heading for
	for p in chefs.size():
		var ch := chefs[p]
		var input := Vector2.ZERO
		if hud.options_open():
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
				ch.mouse_point = floor_point(get_viewport().get_mouse_position())
			_paint_held(p)
		if phase in [Phase.SERVICE, Phase.BUILD] and shopper != ch and not preps.has(p):
			clean_kit.hold_use(ch, controls.holding(p, "use"))   # held E keeps mopping
		if phase == Phase.SERVICE and not (hud.bill_open() and hud.bill.chef == ch):
			_tick_giving(ch, controls.holding(p, "use"), delta)   # held E hands a bill over (PRD 11)
	if phase == Phase.BUILD:
		_refresh_openings()
	step(delta)
	_update_camera(delta)
	for ch in chefs:
		_update_cursor(ch)
		_update_ghost(ch)
		_update_range(ch)
	_update_daylight()
	hud.update_status()
	hud.place_door_ready(cam.unproject_position(DOORWAY + Vector3(0.3, 1.3, 0)))   # just under the card
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
	if (hud.bill_open() and hud.bill.chef == ch) or ch.give_t > 0.0 or ch.demo_giving >= 0.0:
		# Writing a bill, or handing one over (PRD 11): the slip or the fill bar, no prompt.
		ch.cursor.visible = false
		hud.show_prompt(Vector2.ZERO, "", chefs.find(ch))
		return
	var fallen: Node3D = floor_dirt.help_target(ch) if phase == Phase.SERVICE else null
	if fallen != null:   # someone down beside the chef: helping them up comes first (PRD 9.3)
		ch.cursor.visible = false
		hud.show_prompt(cam.unproject_position(fallen.position + Vector3(0, 1.9, 0)), "Help up", chefs.find(ch))
		return
	var st: Station = null if clean_kit.floor_first(ch) else station_at(ch.target_cell())
	var action := ""
	if st != null:
		action = prompt_for(st, ch) if phase == Phase.SERVICE else night_clean_action(st, ch)
		if action == "" and phase == Phase.BUILD and shopper != ch and ch.hand.is_empty():
			action = clean_kit.station_use(st, true, ch)   # a tool's home at night (PRD 9.4)
	if action == "" and (phase == Phase.SERVICE or (phase == Phase.BUILD and shopper != ch and ch.hand.is_empty())):
		var fl := clean_kit.floor_action(ch)
		if fl != "":   # mopping, or a tool to put down or pick up
			ch.cursor.visible = false
			var fc: Vector2i = clean_kit.floor_cell(ch)
			hud.show_prompt(cam.unproject_position(Grid.center(fc) + Vector3(0, 1.3, 0)), fl, chefs.find(ch))
			return
	var messy := _messy_at_mouse(ch)
	if messy != null and messy != st:   # the mouse cannot clean: that is the chef's job
		ch.cursor.visible = false
		hud.show_prompt(cam.unproject_position(messy.position + Vector3(0, 1.6, 0)), Cleaning.WALK_OVER, chefs.find(ch))
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
		action = build_action(ch) if phase == Phase.BUILD else door_action(ch)
		if action in ["Open up", "Close early"] and ready_chefs.has(ch):
			action = "Not ready"   # co-op: using the card again takes their ready back
		var p := DOORWAY + Vector3(0, 2.9, 0)
		if not ch.hand.is_empty() and _hover_point(ch) != Vector3.INF:
			p = _hover_point(ch) + Vector3(0, 2.9 if hand_layer(ch) == "high" else 2.0, 0)
		elif action == "Pick up":
			p = _piece_in_front(ch) + Vector3(0, 2.0, 0)
			action = "Pick up %s" % lift_name(ch)
		elif action == "Use desk":
			p = desk_in_front(ch).position + Vector3(0, 1.9, 0)
		at = cam.unproject_position(p)
	hud.show_prompt(at, action, chefs.find(ch))


## The messy piece under the mouse at night, when the mouse is aiming with empty hands.
func _messy_at_mouse(ch: Player = null) -> Station:
	ch = _me(ch)
	if phase != Phase.BUILD or shopper == ch or not ch.aim_mouse or not ch.hand.is_empty() or ch.mouse_point == Vector3.INF:
		return null
	var st: Station = stations.get(Grid.to_cell(ch.mouse_point))
	return st if st != null and needs_cleaning(st) else null


## One action while the shop is open. Returns whether it was used.
func shop_action(action: String) -> bool:
	if upgrading:
		match action:
			"left", "right", "up", "down": hud.tree_move(action)
			"back" when storing(): storage_ingredients()
			"shop" when storing(): storage_ingredients()
			"back", "shop": close_shop()
			"use", "confirm": hud.tree_buy()
			"sell": hud.tree_favourite()   # X: star the chosen node for the Favourites tab
			"turn" when shopper.hand.get("node") is Station:   # turn it round to see its back
				rotate_hand(shopper)
			_: return false
		return true
	if storing() and shopper.hand.get("carry", false):
		match action:   # a lifted piece's card: E puts it down, Enter or X puts in or takes out
			"use":
				storage_put_down()
				return true
			"sell":
				hud.shop_buy()
				return true
			"turn":   # the lifted piece turns where it hangs; E sets it down that way round
				rotate_hand(shopper)
				return true
	match action:
		"left": hud.shop_move(-1)
		"right": hud.shop_move(1)
		"up": hud.shop_category(-1)
		"down": hud.shop_category(1)
		"shop" when storing() and storage_tree() != "": storage_upgrades()
		"back", "shop": close_shop()
		"use", "confirm": hud.shop_buy()
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
			or floor_kind(ch.hand.id) == "" or ch.aim_mouse:
		ch.last_paint = Vector3i(-999, -999, -1)
		return
	var spot := snap(_hover_point(ch), ch)
	if spot != ch.last_paint:
		ch.last_paint = spot
		if can_place(spot, ch):
			place(spot, ch)


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
	var p := floor_point(mb.position)
	ch.aim_mouse = true
	ch.mouse_point = p
	if p == Vector3.INF:
		return
	var tool := not ch.hand.is_empty() and Catalog.is_build_tool(ch.hand.id)
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	if mb.pressed and ch.hand.is_empty() and not right and menu_board.under(cam, mb.position):
		open_menu(ch)   # a click on the board by the door
		return
	if mb.pressed:
		if tool:
			ch.drag = {"from": p, "remove": right or erase}
		elif right:
			cancel_hand(ch)
		elif not ch.hand.is_empty():
			if not place(snap(p, ch), ch):
				sfx("fail")
		else:
			lift(ch, p)   # as E does: a piece that keeps boxes rises with its card open
	elif not ch.drag.is_empty() and (right == bool(ch.drag.remove) or erase):
		finish_drag(ch.drag.from, p, ch.drag.remove, ch)


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
			inspect(guest_at(event.position))
		return
	# Keys, controller buttons and touch buttons arrive as act() from Controls.


# ---------------------------------------------------------------- co-op (PRD 4)

## A device that is not seated pressed Start (Enter on the keyboard): it becomes
## the next player and their chef walks in at the door. Returns the new player
## index, or -1 when every chef's place is taken.
func join(source: String) -> int:
	if chefs.size() >= MAX_CHEFS or source == "touch":
		return -1
	var p := chefs.size()
	controls.seat(controls.input_of(0).source, 0)   # player one keeps the device they are using
	controls.seat(source, p)
	controls.set_mode(source.get_slice(":", 0), p)
	controls.input_of(p).source = source
	var ch := add_chef(ENTRANCE_CELL)
	ch.look(Vector2i(-1, 0))
	burst(ch.position + Vector3(0, 1.0, 0), "stars", 0.5)
	door_bell()
	ch.punch()
	hud.say("Chef %d joined." % (p + 1))
	hud.coop_hint_time = 25.0
	hud.refresh_input()
	if phase == Phase.BUILD:
		hud.show_build()
	_refresh_ready()
	return p


## Player p leaves (held Start, or their controller was unplugged). Their chef
## puts down what they carry and walks out of the door; the players after them
## move up one, so if player one leaves the other becomes player one. The last
## chef never leaves.
func leave(p: int) -> bool:
	if p < 0 or p >= chefs.size() or chefs.size() <= 1:
		return false
	var ch := chefs[p]
	if preps.has(p):
		cancel_prep(p)   # the ingredient comes back to their hands, and then goes down
	if shopper == ch:
		close_shop()
	if ch.hand.get("moving", false):
		cancel_hand(ch)   # a moved piece goes back where it was
	ch.hand = {}          # a new piece is only paid for when placed: nothing to refund
	ch.drag = {}
	if ch.held != "":
		set_down(ch)
	ready_chefs.erase(ch)
	chefs.remove_at(p)
	var moved := {}
	for q: int in preps:   # the minigames of later players move up one with them
		var nq := q - 1 if q > p else q
		moved[nq] = preps[q]
		(preps[q].st as Station).prep_by = nq
	preps = moved
	controls.unseat(p)
	player = chefs[0]
	for k in chefs.size():
		if chefs[k].trim != k:
			chefs[k].set_trim(k)
	for n: Node3D in [ch.cursor, ch.no_mark, ch.range_marks, ch.ghost, ch.tool_ghost]:
		if n:
			n.queue_free()
	_recolour_cursors()
	hud.trim_prompts(chefs.size())
	_walk_out(ch)
	hud.say("Chef %d left." % (p + 1))
	hud.refresh_input()
	if phase == Phase.BUILD:
		hud.show_build()
	_refresh_ready()
	if phase == Phase.SUMMARY and ready_chefs.size() >= chefs.size() and not ready_chefs.is_empty():
		open_build()
	return true


## What a leaving chef carries goes on the nearest free counter, or is lost.
func set_down(ch: Player) -> void:
	var best: Station = null
	var best_d := INF
	for st: Station in stations.values():
		if st.type in ["counter", "pass"] and st.item == "":
			var d := st.position.distance_to(ch.position)
			if d < best_d:
				best_d = d
				best = st
	if best != null:
		if ch.held == "dishes" and not ch.dishes.is_empty():
			best.set_dish(ch.dishes[0])   # the rest go with the tray
		elif Tray.parse(ch.held).size() > 0:
			best.set_item(ch.held, ch.held_quality)
		sfx("putdown")
	ch.set_held("")
	hud.refresh_tickets()


## A chef who left walks out of the door and down the street, then is gone.
func _walk_out(ch: Player) -> void:
	ch.set_process(false)
	var tw := ch.create_tween()
	var path: Array[Vector3] = [Grid.center(ENTRANCE_CELL), DOORWAY, Grid.center(DOOR), Grid.center(EXIT)]
	var from := ch.position
	for at: Vector3 in path:
		var t := from.distance_to(at) / Player.SPEED
		from = at
		tw.tween_callback(func() -> void:
			var d := at - ch.position
			if d.length() > 0.01:
				ch.aim = Vector3(d.x, 0, d.z).normalized())
		tw.tween_property(ch, "position", at, t)
	tw.tween_callback(ch.queue_free)


## The receipt needs every player's Confirm. With one chef, one is enough.
func confirm_receipt(p: int) -> void:
	if phase != Phase.SUMMARY or p >= chefs.size():
		return
	if not ready_chefs.has(chefs[p]):
		ready_chefs.append(chefs[p])
		sfx("tick")
	if ready_chefs.size() >= chefs.size():
		open_build()
	else:
		_refresh_ready()


## Back on the receipt takes a player's ready back, until everyone has confirmed.
func unconfirm_receipt(p: int) -> void:
	if phase != Phase.SUMMARY or p >= chefs.size() or not ready_chefs.has(chefs[p]):
		return
	ready_chefs.erase(chefs[p])
	sfx("tick", 0.0, 0.8)
	_refresh_ready()


## The door card (opening up, or closing early) needs every chef. The first to use
## it turns it half way and shows their ready marker; using it again takes that
## back; the last one turns it. With one chef it turns at once, as before.
func _agree_at_door(ch: Player) -> bool:
	if chefs.size() <= 1:
		return true
	if ready_chefs.has(ch):
		ready_chefs.erase(ch)
		sfx("flip", 0.0, 0.8)
	else:
		ready_chefs.append(ch)
	if ready_chefs.size() >= chefs.size():
		ready_chefs.clear()   # the card turns all the way (set_door), not part way
		hud.refresh_ready()
		return true
	sfx("flip")
	hud.say("Chef %d is ready. Everyone uses the door card to %s." % [chefs.find(ch) + 1, "open" if phase == Phase.BUILD else "close"]
		if ready_chefs.has(ch) else "Chef %d is not ready." % (chefs.find(ch) + 1))
	_refresh_ready()
	return false


## Each player's state for the ready markers: "ready" or "waiting", by index.
func ready_states() -> Array[String]:
	var out: Array[String] = []
	for ch in chefs:
		out.append("ready" if ready_chefs.has(ch) else "waiting")
	return out


## The door card turns part way for each chef who is ready; the receipt and the
## card show the ready markers.
func _refresh_ready() -> void:
	if _door_turn != null and phase in [Phase.BUILD, Phase.SERVICE]:
		var shut := PI if phase == Phase.BUILD else 0.0   # the side showing now
		var share := float(ready_chefs.size()) / maxf(chefs.size(), 1)
		_door_turn.create_tween().tween_property(_door_turn, "rotation:y", lerpf(shut, PI - shut, share * 0.5), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hud.refresh_ready()


## Player p pressed an action, on whatever device is theirs (see Controls).
## The options screen and the shop are shared; the rest is done by that
## player's chef.
func act(p: int, action: String, echo := false) -> void:
	if action == "aim":
		return   # held, not pressed: read each frame (`Controls.aiming`)
	if hud.options_open():
		hud.options_action(action, echo)
		return
	if hud.pause_open():
		hud.pause.action(action, echo)
		return
	if hud.title_open():
		if action == "options":
			hud.toggle_options()
		else:
			hud.title.action(action, echo)
		return
	if hud.desk_open():
		hud.desk.action(action, echo)
		return
	if hud.menu_open():
		hud.menu.action(action, echo)
		return
	if hud.bill_open() and p < chefs.size() and hud.bill.chef == chefs[p]:
		hud.bill.action(action, echo)
		return
	if echo:
		return
	if action == "options":
		hud.toggle_pause()
		return
	if action == "mute":
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		return
	if p >= chefs.size():
		return   # a seated player with no chef yet
	var ch := chefs[p]
	match phase:
		Phase.SERVICE:
			if preps.has(p):
				if action == "use":
					prep_press(p)
				elif action == "back":
					cancel_prep(p)
			elif action == "back" and ch.held == "bill":
				ch.set_held("")   # the slip is thrown away (PRD 11)
				sfx("putdown")
			elif action == "back" and ch.held == "" and inspected == null:
				hud.toggle_pause()
			elif action == "turn":
				turn_tap(stations.get(ch.target_cell()))
			elif action == "menu":
				open_menu(ch)   # refused: it says why
			elif floor_dirt.is_down(ch) or floor_dirt.helping(ch) != null:
				pass   # on the floor, or helping someone up (PRD 9.3)
			elif action == "use" and floor_dirt.help_up(ch):
				ch.punch()
			elif action == "use":
				var st: Station = station_at(ch.target_cell())
				if clean_kit.floor_first(ch):
					clean_kit.floor_use(ch)   # dirt straight ahead, a tool in hand (PRD 9.4)
				elif st != null and prompt_for(st, ch) != "":
					use_station(st, false, ch)
				elif clean_kit.floor_use(ch):
					pass   # a mop or sponge on the floor (PRD 9.4)
				elif not use_door(ch) and st != null:
					use_station(st, false, ch)
		Phase.SUMMARY:
			if action == "confirm":
				confirm_receipt(p)
			elif action == "back":
				unconfirm_receipt(p)
			elif action == "town":
				hud.toggle_town()
		Phase.CLOSED:
			if action == "confirm":
				restart()
		Phase.BUILD:
			if shopper == ch:
				shop_action(action)
			else:
				_build_act(action, ch)


func _build_act(action: String, ch: Player = null) -> void:
	ch = _me(ch)
	match action:
		"use":
			build_interact(ch)
		"back":
			if ch.hand.is_empty():
				hud.toggle_pause()
			else:
				cancel_hand(ch)
		"turn":
			rotate_hand(ch)
		"shop":
			open_shop(ch)
		"menu":
			open_menu(ch)
		"sell":
			if not ch.hand.is_empty() and Catalog.is_build_tool(ch.hand.id):
				if _hover_point(ch) != Vector3.INF and remove_at(snap(_hover_point(ch), ch), ch):
					_plan_changed()
					sfx("coin")
				else:
					sfx("fail")
			elif not sell_hand(ch):
				sfx("fail")
