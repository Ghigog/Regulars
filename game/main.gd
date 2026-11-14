extends Node3D
## Regulars vertical slice: an endless run of days. Cook meat, serve guests, get paid.

enum Phase { SERVICE, SUMMARY, CLOSED, BUILD, TITLE }

const W := 10            # restaurant interior is 10 x 7 cells
const H := 7             # columns 10 and 11 are the pavement outside, to the right
const DOOR := Vector2i(W, 4)         # the pavement cell just outside the doorway, on the right-hand wall
const SPAWN := Vector2i(W + 1, LOT.position.y)   # the far end of the pavement; guests walk down from beyond it
const QUEUE_GAP := 0.8   # metres between guests standing in line on the pavement
const EXIT := Vector2i(W + 1, H - 1)
const BILL := 12
const SIGHT_RANGE := 7
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
	"pickup": -5.0, "putdown": -5.0, "ding": -3.0, "serve": -3.0, "coin": -4.0, "fail": -3.0, "burn": -4.0,
	"day": -4.0, "wash": -6.0, "step": -16.0, "bell": -9.0, "perfect": -4.0, "sizzle": -10.0,
	"roll": -8.0, "lift": -10.0, "rattle": -9.0, "page": -7.0, "thump": -6.0, "rip": -6.0,
	"flutter": -10.0, "rustle": -9.0, "rope": -8.0, "stamp": -4.0,
	"slide": -8.0, "tick": -9.0, "tab": -8.0, "flip": -5.0,
}
const LOOPING: Array[String] = ["sizzle"]
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
var ledger: Ledger
var phase: int = Phase.SERVICE
var stations := {}               # Vector2i -> Station
var guests: Array[Guest] = []
var queue: Array[Guest] = []
var seat_taken := {}             # Vector2i -> Guest
var arrivals: Array[Dictionary] = []
var clock := 0.0
var last_day := {}
var catalog: Catalog
## The piece being placed: {id, tier, price, facing} for a new one from the catalog;
## a piece picked up from the room also has {moving, node, from, from_facing}.
var hand := {}
var wall_nodes := {}                   # Vector3i edge -> Node3D, player-built partitions only
var rugs := {}                         # Vector2i anchor cell -> Node3D (meta "facing"); see rug_cells
var plan: Floorplan                    # floors, walls, doors and archways
var _room: Node3D                      # the room as drawn from the plan; rebuilt when it changes
var _room_lights: Array[OmniLight3D] = []
var _openings := {}                    # Vector3i edge -> Scenery opening info
var _opening_ok := {}                  # Vector3i edge -> whether it was last drawn usable
var _frame := [WIDE_FOCUS, WIDE_SIZE, CLOSE_FOCUS, CLOSE_SIZE]   # the camera, fitted to the floor
var _aim_mouse := false                # build phase: the mouse, not the chef, says where things go
var _mouse_point := Vector3.INF
var _drag := {}                        # a mouse drag with a build tool: {"from": Vector3, "remove": bool}
var _tool_ghost: Node3D
var _tool_key := ""
var _last_paint := Vector3i(-999, -999, -1)   # the spot E last built on while held
const PIECE_NAMES := {"fridge": "Fridge", "sink": "Sink", "bin": "Bin", "plates": "Plate stack", "pass": "Pass counter"}
var _ghost: Node3D
var _ghost_key := ""
var _no_mark: Node3D
var _demo_hover := Vector3.INF
var inspected: Guest                 # the guest whose card is open, if any
var flyers_out := false          # bought tonight, spent on tomorrow's crowd
var first_night := true          # open on the night before day 1, in the build phase (tests and demos skip it)
static var _title_seen := false  # the title shows once a launch; starting over skips it
var allow_quit := true           # tests turn this off to check Quit without leaving
var quit_asked := false
var shopping := false            # the shop is open over the build phase; the chef stands still
var door_open := true            # which side of the door card faces the street
var _door_hang: Node3D
var _range_marks: Node3D          # floor marks for the reach of the piece being carried
var _range_key := ""
var _door_turn: Node3D
var best_path := "user://regulars_best.json"
var player: Player               # chef 1; `chefs` holds every chef, by player index
var chefs: Array[Player] = []
var hud: Hud
var controls: Controls           # input per player: devices, touch buttons, presses sent to act()
var cam: Camera3D
var _cursor: Node3D
var _gross: Array[Dictionary] = []
var _sfx := {}
var music_id := ""               # which MUSIC track is playing
var _music: AudioStreamPlayer
var _sun: DirectionalLight3D
var _lens: ColorRect
var _sconces: Array[OmniLight3D] = []
var _env: Environment
var _shot_path := ""
var _shot_time := 0.0


func _ready() -> void:
	var seed_value := int(Time.get_unix_time_from_system())
	grid = Grid.new(W + 2 - LOT.position.x, LOT.size.y, LOT.position)   # columns W and W + 1 are the pavement outside
	town = Town.new(seed_value)
	ledger = Ledger.new()
	catalog = Catalog.new(seed_value)
	_build_scenery()
	_build_layout()
	_start_plan()
	_load_sounds()
	player = Player.new()
	add_child(player)
	player.setup(self, Vector2i(2, 3))
	chefs = [player]
	controls = Controls.new()
	add_child(controls)
	controls.setup(self)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	controls.mode_changed.connect(func(_m: String) -> void:   # player 0's device: the hints follow it
		_aim_mouse = false
		_drag = {}
		hud.refresh_input())
	if OS.get_environment("REGULARS_INPUT") != "":   # dev switch for screenshots: touch or pad
		controls.set_mode(OS.get_environment("REGULARS_INPUT"))
	# A warm frame around the top of the station the chef is facing.
	_cursor = Node3D.new()
	add_child(_cursor)
	for i in 4:
		var bar := Build.box(_cursor, Vector3(0, 0, 0.5).rotated(Vector3.UP, i * PI / 2), Vector3(1.06, 0.05, 0.07), Build.WARN, 0.8)
		bar.rotation.y = i * PI / 2
	# Build phase: a coral cross on the floor where the piece in hand cannot go.
	_no_mark = Node3D.new()
	_no_mark.visible = false
	add_child(_no_mark)
	for turn: float in [PI / 4, -PI / 4]:
		var arm := Build.box(_no_mark, Vector3(0, 0.02, 0), Vector3(1.2, 0.05, 0.2), Build.DANGER, 0.6)
		arm.rotation.y = turn
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(Build.DANGER)
		m.emission_enabled = true
		m.emission = Color(Build.DANGER)
		m.emission_energy_multiplier = 0.6
		m.no_depth_test = true          # shows through whatever is already standing there
		m.render_priority = 5
		arm.material_override = m
	_shot_path = OS.get_environment("REGULARS_SHOT")
	_build_door_card()
	_range_marks = Node3D.new()
	add_child(_range_marks)
	var demo := OS.get_environment("REGULARS_DEMO")
	if demo == "title" or (first_night and demo == "" and not _title_seen):
		open_title()
	elif first_night and demo == "":
		_open_first_night()
	else:
		start_day()
	_apply_demo(OS.get_environment("REGULARS_DEMO"))


## Dev aid for screenshots: REGULARS_DEMO=cook or =summary jumps to that moment.
func _apply_demo(demo: String) -> void:
	if demo == "cook":
		find_station("stove").set_item("raw_patty")
		find_station("stove").cook = -8.2
		stations[Vector2i(0, 3)].set_item("raw_patty")
		player.position = Grid.center(Vector2i(1, 3))
		player.look(Vector2i(0, -1))
		player.set_held("plate")
		for a in arrivals:
			a.time = 1.0
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
	elif demo == "options" or demo == "options_gfx":  # the options screen, on either tab
		hud._options_tab = "graphics" if demo == "options_gfx" else "audio"
		hud.toggle_options()
		hud.options_action("down")   # the highlight on the first slider (keys and pad)
		get_tree().paused = false   # so the screenshot timer still runs
	elif demo == "closed":
		best_path = "user://regulars_best_demo.json"
		for i in Ledger.MAX_STRIKES:
			ledger.record_walkout()
	elif demo == "summary" or demo == "town":
		ledger.record_sale(BILL, 5)
		ledger.record_sale(BILL, 3)
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
	elif demo.begins_with("build") or demo == "door":  # build (the shop), build_find (a search), build_no (refused spot), build_move, door
		ledger.record_sale(BILL, 5)
		ledger.money = 300
		ledger.xp = 250
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_build.bind(demo))
	elif demo == "newday":  # the receipt, then building, then the next day turning over
		ledger.record_sale(BILL, 5)
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
		ledger.record_sale(BILL, 5)
		arrivals.clear()
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			open_build()
			open_shop()
			hud._set_category("Extras")
			buy(FLYERS))


func _demo_build(demo: String) -> void:
	open_build()
	for step: Array in [["counter", 2, 4, 0], ["screen", 8, 5, 0], ["screen", 9, 5, 0], ["table", 8, 6, 0], ["plant", 9, 2, 0]]:
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
			_drag = {"from": Vector3(-0.5, 0, -1.5), "remove": false}
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
		pick_catalog("plant", 1)
		_demo_hover = Vector3(6.5, 0, 3.5)
	else:   # a stove from the shop, held over a good spot or (build_no) a refused one
		pick_catalog("stove", 2)
		_demo_hover = Vector3(6.5, 0, 5.5) if demo == "build_no" else Vector3(3.5, 0, 5.5)


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
		serve(g, 1.0 if i == 0 else 0.7)
	inspect(seated[0])


func _demo_fx() -> void:
	var seated: Array[Guest] = []
	for g in guests:
		if g.seated_waiting():
			seated.append(g)
		elif g.state == "queue":
			g.mood.patience = 0.5                 # Zzz bubble
	if seated.size() > 0:
		serve(seated[0], 1.0)                     # stars, heart, chewing, bitten burger
		seated[0].timer = 2.0                     # then the coin and a dirty plate
	if seated.size() > 1:
		seated[1].mood.patience = 0.0             # walkout: anger mark and a stamp
	if seated.size() > 2:
		seated[2]._gross_time = 6.0               # green cloud
	find_station("fridge").used()                 # door swings open
	burst(find_station("sink").position + Vector3(0, 1.15, 0), "bubbles", 0.4)


# ---------------------------------------------------------------- world

func _build_scenery() -> void:
	if OS.get_environment("REGULARS_THEME") != "":  # dev switch until themes are selectable in game
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


func _build_layout() -> void:
	for spot: Array in [
		# The cooking line runs down the left wall under the hood, as in sheet 1.
		# The cell in front of the back doorway stays clear, so the fridge can be reached.
		["fridge", 0, 2], ["plates", 2, 2], ["sink", 3, 2],
		["stove", 0, 3, 1], ["stove", 0, 4, 1], ["bin", 0, 5, 1], ["counter", 0, 6, 1],
		["pass", 4, 2], ["pass", 4, 3], ["pass", 4, 4], ["pass", 4, 5],
		["table", 6, 1], ["table", 8, 3], ["table", 6, 5], ["plant", 9, 0],
	]:
		add_station(spot[0], Vector2i(spot[1], spot[2]), 1, spot[3] if spot.size() > 3 else 0)
	Build.register(stations[Vector2i(4, 2)])  # the till lives on the pass and moves with it
	add_rug(Vector2i(8, 3))   # under the middle table, as in sheet 1


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


func add_station(type: String, cell: Vector2i, tier := 1, facing := 0) -> Station:
	var st := Station.new()
	add_child(st)
	st.setup(type, cell, tier, facing)
	if Station.is_table(type):
		st.lamp = _add_lamp(st.position)
	_register(st)
	return st


func _register(st: Station) -> void:
	stations[st.cell] = st
	grid.blocked[st.cell] = true
	for s in st.seats:
		grid.reserved[s] = true


func _unregister(st: Station) -> void:
	stations.erase(st.cell)
	grid.blocked.erase(st.cell)
	for s in st.seats:
		grid.reserved.erase(s)


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
			stream.loop_end = stream.data.size() / 2
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
	var arc := deg_to_rad(lerpf(24.0, 156.0, p))
	var east := Vector3(1, 0, -1).normalized()
	var over := Vector3(0, 1, 0).rotated(east, deg_to_rad(SUN_LEAN))
	var from := east * cos(arc) + over * sin(arc)
	_sun.basis = Basis.looking_at(-from)
	_env.background_color = Color(Scenery.t().backdrop).lerp(Color("#d9c9cc"), t)
	_env.ambient_light_color = Color("#ece0dc").lerp(Color("#d9bfd0"), t)  # mauve evening shade
	_sun.light_energy = lerpf(SUN_ENERGY.x, SUN_ENERGY.y, t)
	for l in _sconces:  # practical lights come up as the sun goes down
		l.light_energy = float(l.get_meta("full", 0.45)) * lerpf(0.35, 1.0, t)


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

## Days get longer, busier and less forgiving.
func day_length() -> float:
	return 50.0 + 5.0 * ledger.day


func table_patience() -> float:
	return maxf(24.0, 46.0 - 1.5 * ledger.day)


func day_progress() -> float:
	return clampf(clock / day_length(), 0.0, 1.0) if phase == Phase.SERVICE else 1.0


func start_day() -> void:
	if phase == Phase.CLOSED:
		return
	if hand.get("moving", false):
		cancel_hand()   # a piece still being carried goes back where it was
	phase = Phase.SERVICE
	clock = 0.0
	hand = {}
	shopping = false
	set_door(true)
	hud.hide_card()
	hud.hide_build()
	town.new_day()
	var coming := town.roll_guests(ledger.day, Town.FLYER_BOOST if flyers_out else 0.0)
	var groups := town.make_groups(coming, max_party())
	var flyered := flyers_out
	flyers_out = false
	arrivals.clear()
	for i in groups.size():
		var t := 2.0 + (i + town.rng.randf() * 0.6) * (day_length() - 2.0) / groups.size()
		arrivals.append({"time": t, "group": groups[i]})
	play_music("day")
	hud.show_banner("Day %d" % ledger.day)
	hud.say(("%d guests expected today." % coming.size()) + (" The flyers worked." if flyered else ""))
	sfx("day")


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
	hud.say("The night before day 1. Set the room up, then flip the door card.")


## The title screen over the room, before the night before day 1.
func open_title() -> void:
	_title_seen = true
	phase = Phase.TITLE
	door_open = false
	_door_turn.rotation.y = PI
	play_music("title")
	hud.show_title()


## Play on the title screen.
func play() -> void:
	if phase != Phase.TITLE:
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
	hud.hide_card()
	hud.show_build()


## What the shop lists for a search and a category tab: the catalog, and the flyers
## under Extras.
static func shop_items(query := "", category := "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if category != "Extras":
		found = Catalog.search(query, category)
	if category == "" or category == "Extras":
		var hit := true
		for w in query.strip_edges().to_lower().split(" ", false):
			hit = hit and "flyers extras more guests tomorrow".contains(w)
		if hit:
			found.append(FLYERS)
	return found


func open_shop() -> void:
	if phase != Phase.BUILD or shopping:
		return
	shopping = true
	sfx("slide")
	hud.show_shop()


func close_shop() -> void:
	if not shopping:
		return
	shopping = false
	sfx("slide", 0.0, 0.8)
	hud.hide_shop()


## Buys what the shop is showing. Flyers are paid for at once; a piece goes into
## the chef's hands and the shop shuts, so it can be carried to its place.
func buy(bp: Dictionary) -> bool:
	if bp.id == FLYERS.id:
		if buy_flyers():
			return true
	elif pick_catalog(bp.id, int(bp.tier)):
		sfx("pickup")
		close_shop()
		return true
	sfx("fail")
	return false


## Picks a piece from the catalog to place. Nothing is paid until it is placed.
func pick_catalog(id: String, tier := 1) -> bool:
	if phase != Phase.BUILD or not catalog.can_buy(id, ledger.money, ledger.level(), tier):
		return false
	if hand.get("moving", false):
		cancel_hand()
	hand = {"id": id, "tier": tier, "price": Catalog.price_of(id, tier), "facing": 0}
	hud.show_build()
	return true


## Puts down whatever is in hand: a new piece is dropped, a moved one goes back.
func cancel_hand() -> void:
	_drag = {}
	if hand.get("moving", false):
		_put_down(hand.from, int(hand.from_facing))
	hand = {}
	if phase == Phase.BUILD:
		hud.show_build()


static func piece_name(bp: Dictionary) -> String:
	return Catalog.label(bp) if Catalog.ITEMS.has(bp.id) else str(PIECE_NAMES.get(bp.id, bp.id))


## Picks up the piece standing at a point on the floor, to move, turn or sell it.
func pick_up(p: Vector3) -> bool:
	if phase != Phase.BUILD or not hand.is_empty():
		return false
	var c := Grid.to_cell(p)
	var edge := snap_edge(p)
	if stations.has(c):
		var st: Station = stations[c]
		_unregister(st)
		st.visible = false
		hand = {"id": st.type, "tier": st.tier, "price": 0, "facing": st.facing, "moving": true,
			"node": st, "from": Vector3i(c.x, c.y, 0), "from_facing": st.facing}
	elif wall_nodes.has(edge):
		var n: Node3D = wall_nodes[edge]
		wall_nodes.erase(edge)
		grid.walls.erase(edge)
		n.visible = false
		hand = {"id": "screen", "tier": int(n.get_meta("tier", 1)), "price": 0, "facing": 0, "moving": true,
			"node": n, "from": edge, "from_facing": 0}
	elif rug_at(c) != null:   # a rug is picked up last: whatever stands on it comes first
		var n := rug_at(c)
		var anchor: Vector2i = rugs.find_key(n)
		rugs.erase(anchor)
		n.visible = false
		var f := int(n.get_meta("facing", 0))
		hand = {"id": "rug", "tier": 1, "price": 0, "facing": f, "moving": true,
			"node": n, "from": Vector3i(anchor.x, anchor.y, 0), "from_facing": f}
	else:
		return false
	sfx("pickup")
	hud.show_build()
	return true


## Stands the carried piece on a spot. No checks: callers have made them.
func _put_down(spot: Vector3i, facing: int) -> void:
	var n: Node3D = hand.node
	n.visible = true
	if hand.id == "screen":
		grid.walls[spot] = true
		wall_nodes[spot] = n
		_place_on_edge(n, spot)
	elif hand.id == "rug":
		_lay_rug(n, Vector2i(spot.x, spot.y), facing)
	else:
		(n as Station).place_at(Vector2i(spot.x, spot.y), facing)
		_register(n)


## Turns the piece in hand a quarter turn. Partitions turn by where you point.
func rotate_hand() -> void:
	if not hand.is_empty() and not on_edge(hand.id) and not Catalog.is_build_tool(hand.id):
		hand.facing = (int(hand.facing) + 1) % 4
		sfx("pickup")


## What selling the carried piece pays: half its catalog price, or 0 if not for sale.
func sell_value() -> int:
	if not hand.get("moving", false) or not Catalog.ITEMS.has(hand.id):
		return 0
	return Catalog.price_of(hand.id, int(hand.tier)) / 2


## Why the carried piece cannot be sold; empty when it can.
func sell_block() -> String:
	if not hand.get("moving", false):
		return "Nothing picked up"
	if not Catalog.ITEMS.has(hand.id):
		return "The %s is not for sale" % piece_name(hand).to_lower()
	if (hand.id == "stove" or hand.id == "table") and find_station(hand.id) == null:
		return "Your last %s" % hand.id
	return ""


func sell_hand() -> bool:
	if phase != Phase.BUILD or sell_block() != "":
		return false
	ledger.refund(sell_value())
	var n: Node3D = hand.node
	if n is Station and (n as Station).lamp:
		_sconces.erase((n as Station).lamp)
		(n as Station).lamp.queue_free()
	n.queue_free()
	hand = {}
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
func snap(p: Vector3) -> Vector3i:
	if on_edge(hand.get("id", "")):
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
	var reach: Array[Vector2i] = [player.cell()]
	reach.assign(reach + grid.reserved.keys())
	return reach


func _touch() -> Array[Vector2i]:
	var touch: Array[Vector2i] = []
	touch.assign(stations.keys())
	return touch


## Would the piece in hand fit at this spot without cutting anyone off?
func can_place(spot: Vector3i) -> bool:
	if hand.is_empty():
		return false
	var reach := _reach()
	var touch := _touch()
	var cell := Vector2i(spot.x, spot.y)
	match tool_kind(hand.id):
		"floor":
			return plan.can_lay(cell, floor_kind(hand.id))
		"finish":
			return plan.can_finish(spot, hand.id)
		"rug":
			return can_lay_rug(cell, int(hand.facing))
		"wall":
			return plan.can_build(spot) and grid.can_place_wall(spot, LOT, DOOR, reach, touch)
		"door", "arch":
			return plan.can_open(spot, hand.id)
	if hand.id == "screen":
		return grid.can_place_wall(spot, LOT, DOOR, reach, touch) and not plan.is_wall(spot)
	return grid.can_place_block(cell, Station.seats_for(hand.id, cell, int(hand.facing)), LOT, DOOR, reach, touch)


## Builds the piece in hand and pays for it, so cancelling before this is free.
## A new piece stays in hand for another while there is money for it; a moved
## piece is put down for nothing.
func place(spot: Vector3i) -> bool:
	if phase != Phase.BUILD or not can_place(spot):
		return false
	if Catalog.is_build_tool(hand.id):
		if not _build_at(spot):
			return false
		_plan_changed()
		sfx("putdown")
		_after_building()
		return true
	var cell := Vector2i(spot.x, spot.y)
	if hand.get("moving", false):
		_put_down(spot, int(hand.facing))
		hand = {}
		sfx("putdown")
		hud.show_build()
		return true
	if not ledger.spend(int(hand.price)):
		return false
	if hand.id == "screen":
		var n := add_wall(cell, spot.z, 0.9 + 0.1 * int(hand.tier))
		n.set_meta("tier", int(hand.tier))
		wall_nodes[spot] = n
	elif hand.id == "rug":
		add_rug(cell, int(hand.facing))
	else:
		add_station(hand.id, cell, int(hand.tier), int(hand.facing))
	burst(Grid.center(cell) + Vector3(0, 1.0, 0), "stars", 0.4)
	sfx("putdown")
	_after_building()
	return true


## A new piece or tool stays in hand while there is money for another.
func _after_building() -> void:
	if not catalog.can_buy(hand.id, ledger.money, ledger.level(), int(hand.tier)):
		hand = {}
	hud.show_build()


# ---------------------------------------------------------------- building the room

## One tile, wall, door or archway from the tool in hand, if it fits and can be
## paid for. Keeps the grid in step; the room is redrawn by the caller.
func _build_at(spot: Vector3i) -> bool:
	if not can_place(spot) or not ledger.spend(int(hand.price)):
		return false
	var cell := Vector2i(spot.x, spot.y)
	match tool_kind(hand.id):
		"floor":
			var was := plan.kind(cell)
			if was != "":   # laying over another floor: the old one is taken up and paid back
				ledger.refund(Catalog.price_of("floor_" + was))
			for what: String in plan.lay(cell, floor_kind(hand.id)).values():
				ledger.refund(Catalog.price_of(what))
		"wall":
			plan.build(spot)
		"finish":
			var was := plan.finish(spot, hand.id)
			if was != "":   # papering over paint: the old finish is paid back
				ledger.refund(Catalog.price_of(was))
		"door", "arch":
			var had := plan.strip(spot)
			if had != "":
				ledger.refund(Catalog.price_of(had))
			plan.openings[spot] = hand.id
	_sync_grid()
	return true


## Takes away the floor, built wall or opening at a spot, for the tool in hand,
## and pays back what it cost. Refused if it would cut anyone off.
func remove_at(spot: Vector3i) -> bool:
	if phase != Phase.BUILD or hand.is_empty() or not Catalog.is_build_tool(hand.id):
		return false
	var cell := Vector2i(spot.x, spot.y)
	match tool_kind(hand.id):
		"floor":
			if not plan.has_floor(cell) or cell == ENTRANCE_CELL or stations.has(cell) \
					or grid.reserved.has(cell) or cell == player.cell() or rug_at(cell) != null:
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
func drag_spots(from: Vector3, to: Vector3) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var id: String = hand.get("id", "")
	if floor_kind(id) != "":
		var cells := Floorplan.rect_cells(Grid.to_cell(from), Grid.to_cell(to))
		if not _drag.get("remove", false):
			cells = plan.lay_order(cells, floor_kind(id))
		for c in cells:
			out.append(Vector3i(c.x, c.y, 0))
	elif id == "wall" or Catalog.is_finish(id):
		var a := Vector2i(roundi(from.x), roundi(from.z))
		var b := Vector2i(roundi(to.x), roundi(to.z))
		if a == b:
			out.append(snap_edge(to))
		else:
			out.assign(Floorplan.line(a, b))
	elif id != "":
		out.append(snap(to))
	return out


## Builds (or removes) along a whole drag, as far as the money goes.
func finish_drag(from: Vector3, to: Vector3, remove: bool) -> int:
	_drag = {"from": from, "remove": remove}
	var done := 0
	for spot in drag_spots(from, to):
		if remove:
			done += int(remove_at(spot))
		elif _build_at(spot):
			done += 1
		elif not ledger.money >= int(hand.price):
			break
	_drag = {}
	if done > 0:
		_plan_changed()
		sfx("coin" if remove else "putdown")
		if not remove:
			_after_building()
	else:
		sfx("fail")
	return done


## What a drag in progress would do, for the prompt: "Lay 6 tiles  $30".
func drag_summary() -> String:
	if _drag.is_empty() or hand.is_empty() or _hover_point() == Vector3.INF:
		return ""
	var spots := drag_spots(_drag.from, _hover_point())
	if _drag.remove:
		return "Remove"
	var n := spots.size() if floor_kind(hand.id) != "" else spots.filter(can_place).size()
	var price := int(hand.price)
	var noun: String = "tile" if floor_kind(hand.id) != "" else ("wall" if hand.id == "wall" or Catalog.is_finish(hand.id) else hand.id)
	var verb := "Lay" if floor_kind(hand.id) != "" else ("Paint" if hand.id == "paint" else ("Paper" if Catalog.is_finish(hand.id) else "Build"))
	return "%s %d %s%s  $%d" % [verb, n, noun, "s" if n != 1 else "", n * price]


## A point on the floor in front of the chef: the middle of the next cell, or (for
## partitions) just inside the edge of the cell the chef stands in.
func _front_point(edge := false) -> Vector3:
	return Grid.center(player.cell()) + Vector3(player.facing.x, 0, player.facing.y) * (0.45 if edge else 1.0)


## Where the piece in hand is held: over the spot in front of the chef.
func _hover_point() -> Vector3:
	if _demo_hover != Vector3.INF:
		return _demo_hover
	if _aim_mouse:
		return _mouse_point
	return _front_point(on_edge(hand.get("id", "")))


## Where a point on the screen lands on the floor.
func floor_point(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector3.INF
	return o + d * (-o.y / d.y)


## A point on the piece the chef could pick up: the partition on the edge ahead,
## or else whatever stands in the next cell. Vector3.INF when there is nothing.
func _piece_in_front() -> Vector3:
	if wall_nodes.has(snap_edge(_front_point(true))):
		return _front_point(true)
	if stations.has(Grid.to_cell(_front_point())) or rug_at(Grid.to_cell(_front_point())) != null:
		return _front_point()
	return Vector3.INF


## What E would do in the build phase: "Put down", "Pick up", "Open up" or nothing.
func build_action() -> String:
	if phase != Phase.BUILD or shopping:
		return ""
	if not hand.is_empty():
		if not _drag.is_empty():
			return drag_summary()
		match tool_kind(hand.id):
			"floor":
				return "Lay floor"
			"finish":
				return "Paint wall" if hand.id == "paint" else "Paper wall"
			"wall":
				return "Build wall"
			"door":
				return "Add door"
			"arch":
				return "Add archway"
		return "Put down"
	if _piece_in_front() != Vector3.INF:
		return "Pick up"
	return door_action()


func build_interact() -> void:
	var action := build_action()
	if not hand.is_empty():
		action = "Put down"
	match action:
		"Put down":
			_last_paint = snap(_hover_point())
			if not place(_last_paint):
				sfx("fail")
		"Pick up":
			pick_up(_piece_in_front())
		"Open up", "Take out rubbish":
			use_door()


## The piece in hand is held over the spot in front of the chef; a cross marks
## spots where it cannot go.
func _update_ghost() -> void:
	_update_tool_ghost()
	var key := "%s:%s" % [hand.get("id", ""), hand.get("tier", 0)] if phase == Phase.BUILD and not hand.is_empty() and not Catalog.is_build_tool(hand.id) else ""
	if key != _ghost_key:
		_ghost_key = key
		if _ghost:
			_ghost.queue_free()
			_ghost = null
		if key != "":
			_ghost = Node3D.new()
			add_child(_ghost)
			if hand.id == "screen":
				_wall_visual(_ghost, 0.9 + 0.1 * int(hand.tier))
			elif hand.id == "rug":
				Scenery.rug(_ghost)
			else:
				Build.station(_ghost, hand.id, int(hand.tier))
	var p := _hover_point()
	if _ghost == null or p == Vector3.INF:
		_no_mark.visible = false
		if _ghost:
			_ghost.visible = false
		return
	var spot := snap(p)
	var ok := can_place(spot)
	if on_edge(hand.id):
		_place_on_edge(_ghost, spot)
	else:
		_ghost.position = Grid.center(Vector2i(spot.x, spot.y))
		_ghost.rotation.y = int(hand.facing) * PI / 2
	_ghost.position.y = 0.12 + 0.04 * sin(Time.get_ticks_msec() / 160.0)   # held just off the floor
	_ghost.visible = ok
	_no_mark.visible = not ok
	_no_mark.position = Vector3(_ghost.position.x, 0, _ghost.position.z)


## A build tool shows what it would do: pale squares for floor, bars along the
## edges for walls, the door or archway itself; green where it fits, coral
## where it does not, and coral everywhere a drag would remove.
func _update_tool_ghost() -> void:
	var p := _hover_point()
	var tool := phase == Phase.BUILD and not hand.is_empty() and Catalog.is_build_tool(hand.id) and not shopping and p != Vector3.INF
	var spots: Array[Vector3i] = []
	if tool:
		if _drag.is_empty():
			spots.append(snap(p))
		else:   # not a one-line `a if c else b`: that drops the array's type and fails at run time
			spots = drag_spots(_drag.from, p)
	var key := "%s|%s|%s|%d" % [hand.get("id", ""), spots, _drag.get("remove", false), ledger.money] if tool else ""
	if key == _tool_key:
		return
	_tool_key = key
	if _tool_ghost:
		_tool_ghost.queue_free()
		_tool_ghost = null
	if not tool:
		return
	_tool_ghost = Node3D.new()
	add_child(_tool_ghost)
	var removing: bool = _drag.get("remove", false)
	var dragging := not _drag.is_empty()
	for spot in spots:
		var ok := not removing and (dragging and floor_kind(hand.id) != "" or can_place(spot))
		var col := Color(Build.DANGER if removing or not ok else Build.GOOD, 0.55)
		if floor_kind(hand.id) != "":
			var tile := Build.box(_tool_ghost, Vector3(spot.x + 0.5, 0.02, spot.y + 0.5), Vector3(0.94, 0.03, 0.94), Build.GOOD)
			tile.material_override = Build.overlay_mat(col, 3)
		elif hand.id == "wall" or Catalog.is_finish(hand.id):
			var bar := Node3D.new()
			_tool_ghost.add_child(bar)
			_place_on_edge(bar, spot)
			var tall := Scenery.CUT_H if hand.id == "wall" else 1.2
			var thick := Scenery.WALL_T + (0.0 if hand.id == "wall" else 0.08)
			Build.box(bar, Vector3(0, 0, 0), Vector3(1.0, tall, thick), Build.GOOD).material_override = Build.overlay_mat(col, 3)
		else:
			var n := Node3D.new()
			_tool_ghost.add_child(n)
			_place_on_edge(n, spot)
			var inner := Node3D.new()
			n.add_child(inner)
			Scenery.dress_opening({"holder": inner, "kind": hand.id, "tall": false}, true)
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


func at_door() -> bool:
	var d := player.position - DOORWAY
	return Vector2(d.x, d.z).length() < DOOR_REACH


## What the chef can do with the door card from here: "Open up" at the end of the
## build phase, "Close early" from the middle of the day on, or nothing.
func door_action() -> String:
	if not at_door():
		return ""
	if player.held == "rubbish_bag":
		return "Take out rubbish"
	if phase == Phase.BUILD and hand.is_empty() and not shopping:
		return "Open up"
	if phase == Phase.SERVICE and door_open and not arrivals.is_empty() and day_progress() >= CLOSE_EARLY_FROM:
		return "Close early"
	return ""


func use_door() -> bool:
	match door_action():
		"Open up":
			start_day()
		"Close early":
			close_early()
		"Take out rubbish":
			player.set_held("")
			sfx("putdown")
		_:
			return false
	player.punch()
	return true


## Nobody else comes in today. Guests already here, queue included, stay and are
## served as usual; the day ends when the last of them has gone.
func close_early() -> void:
	if phase != Phase.SERVICE or not door_open:
		return
	arrivals.clear()
	set_door(false)
	hud.say("Closed. Guests already here can stay.")


func _end_day() -> void:
	set_door(false)
	shopping = false
	phase = Phase.SUMMARY
	play_music("night")
	inspect(null)
	last_day = ledger.end_day()
	hud.show_summary(last_day)
	sfx("coin")


func _close_down() -> void:
	play_music("closed")
	phase = Phase.CLOSED
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
func spawn_group(ids: Array) -> Array[Guest]:
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
	_reflow_queue()
	return party


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
		sfx("bell")
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
			saw_gross = saw_gross or rate >= GuestMood.NOTICE
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
## floors and rugs by cell, wall finishes by the floor beside them, and ferns.
func decor_near(cell: Vector2i) -> Array:
	var out: Array = []
	var r := Decor.VIEW_RANGE
	var sees := func(c: Vector2i, reach: int) -> bool:
		return _near(cell, c, reach) and (c == cell or grid.has_los(cell, c))
	for c: Vector2i in plan.floors:
		var id := "floor_" + plan.kind(c)
		if Catalog.joy_of(id) > 0.0 and sees.call(c, r):
			out.append({"id": id, "dist": _dist(cell, c)})
	for a: Vector2i in rugs:
		for c in rug_cells(a, int(rugs[a].get_meta("facing", 0))):
			if sees.call(c, r):
				out.append({"id": "rug", "dist": _dist(cell, c)})
	for e: Vector3i in plan.finishes:
		for side in Floorplan.sides(e):
			if plan.has_floor(side) and sees.call(side, r):
				out.append({"id": plan.finishes[e], "dist": _dist(cell, side)})
	for st: Station in stations.values():
		if st.type == "plant" and sees.call(st.cell, Decor.reach("plant", st.tier)):
			out.append({"id": "plant", "tier": st.tier, "dist": _dist(cell, st.cell)})
	return out


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## How far a piece's effect on guests reaches, in cells. 0 for a piece with none.
static func range_of(id: String, tier := 1) -> int:
	if id == "plant":
		return Decor.reach(id, tier)
	return BIN_RANGE if id == "bin" else 0


## Every seat in the room, and the share of a piece's joy (a Decor band) that would
## reach it from `cell` with a reach of `reach` cells: Decor.BESIDE, Decor.IN_VIEW or 0.
## Partitions block it, as they block a guest's view.
func seats_reached(cell: Vector2i, reach: int) -> Dictionary:
	var out := {}
	for st: Station in stations.values():
		for s in st.seats:
			var seen := _near(s, cell, reach) and grid.has_los(s, cell)
			out[s] = Decor.band(maxi(1, _dist(s, cell)), reach) if seen else 0.0
	return out


## While a piece with a reach is carried: a pale square on the floor shows how far
## it is seen from the spot in front, a brighter one the cells beside it, and every
## seat gets a disc: big and green beside it (half its joy), small and pale green
## in view (a fifth), red out of reach.
func _update_range() -> void:
	var reach := 0
	if phase == Phase.BUILD and not hand.is_empty():
		reach = range_of(hand.id, int(hand.tier))
	if _hover_point() == Vector3.INF:
		reach = 0
	var cell := Grid.to_cell(_hover_point()) if reach > 0 else Vector2i.ZERO
	var key := "%d:%s:%d:%d" % [reach, cell, stations.size(), grid.walls.size()] if reach > 0 else ""
	if key == _range_key:
		return
	_range_key = key
	for c in _range_marks.get_children():
		c.queue_free()
	if key == "":
		return
	var area := Rect2i(cell - Vector2i(reach, reach), Vector2i(reach, reach) * 2 + Vector2i.ONE).intersection(LOT)
	if area.has_area():
		var wash := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(area.size)
		wash.mesh = plane
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 1, 1, 0.22)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wash.material_override = m
		wash.position = Vector3(area.position.x + area.size.x / 2.0, 0.03, area.position.y + area.size.y / 2.0)
		_range_marks.add_child(wash)
		var close := MeshInstance3D.new()
		var inner := PlaneMesh.new()
		inner.size = Vector2(3, 3)
		close.mesh = inner
		close.material_override = m
		close.position = Grid.center(cell) + Vector3(0, 0.035, 0)
		_range_marks.add_child(close)
	var seats := seats_reached(cell, reach)
	for s: Vector2i in seats:
		var disc := MeshInstance3D.new()
		var puck := CylinderMesh.new()
		puck.top_radius = 0.4
		puck.bottom_radius = 0.4
		puck.height = 0.02
		disc.mesh = puck
		var share: float = seats[s]
		var full := share >= Decor.BESIDE
		disc.material_override = Build.overlay_mat(Color(Color(Build.GOOD if share > 0.0 else Build.DANGER), 0.8 if full or share == 0.0 else 0.5), 2)
		disc.position = Grid.center(s) + Vector3(0, 0.05, 0)
		_range_marks.add_child(disc)
		disc.scale = Vector3(0.3, 1, 0.3)
		var size := Vector3.ONE if full or share == 0.0 else Vector3(0.6, 1, 0.6)
		disc.create_tween().tween_property(disc, "scale", size, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _near(a: Vector2i, b: Vector2i, r: int) -> bool:
	return absi(a.x - b.x) <= r and absi(a.y - b.y) <= r


func _collect_gross() -> void:
	_gross.clear()
	for st: Station in stations.values():
		if Station.is_table(st.type) and st.dirty > 0:
			_gross.append({"cell": st.cell, "kind": "plate", "age": st.dirty_age, "thought": "Nobody has cleared that table"})
		elif st.type == "bin" and st.overflowing():
			_gross.append({"cell": st.cell, "kind": "overflow", "age": st.dirty_age, "thought": "The bin is overflowing"})
		elif st.type == "bin":
			_gross.append({"cell": st.cell, "kind": "bin", "key": "bin", "range": BIN_RANGE, "thought": "I can see the bin from my seat"})
		elif st.type == "sink" and st.messy():
			_gross.append({"cell": st.cell, "kind": "sink", "age": st.dirty_age, "thought": "Look at that washing-up"})
		elif st.type == "stove" and st.item == "burnt_patty":
			_gross.append({"cell": st.cell, "kind": "burning", "age": st.cook - Station.BURN_TIME, "thought": "Something is burning in there"})
	if player.carrying_something_gross():
		_gross.append({"cell": player.cell(), "kind": "rubbish", "key": "rubbish", "thought": "I just watched the chef carry rubbish past me"})


## The most impatient guest sat at this table, waiting to order or for food.
func _waiting_guest_at(table: Station) -> Guest:
	var best: Guest = null
	for s in table.seats:
		if seat_taken.has(s):
			var g: Guest = seat_taken[s]
			if g.seated_waiting() and (best == null or g.mood.patience < best.mood.patience):
				best = g
	return best


## The guest at this table who ordered what the chef is holding, most impatient first.
func _guest_wanting(table: Station, held: String) -> Guest:
	var best: Guest = null
	for s in table.seats:
		if seat_taken.has(s):
			var g: Guest = seat_taken[s]
			if g.state == "waiting" and held != "" and g.order.get("dish", "") == held \
					and (best == null or g.mood.patience < best.mood.patience):
				best = g
	return best


## Everyone at this table who is sat down and has not ordered yet.
func _guests_to_order(table: Station) -> Array[Guest]:
	var out: Array[Guest] = []
	for s in table.seats:
		if seat_taken.has(s) and seat_taken[s].state == "ordering":
			out.append(seat_taken[s])
	return out


## What this guest orders. Today there is one dish; the menu system will choose
## here from the player's menu, by taste and price.
func order_for(_g: Guest) -> Dictionary:
	return {"dish": "burger"}


## The chef takes the whole table's order in one go.
func take_orders(table: Station) -> void:
	for g in _guests_to_order(table):
		g.take_order(order_for(g))
		g.mood.patience = minf(1.0, g.mood.patience + ORDER_RELIEF)
	sfx("page")


func serve(g: Guest, quality: float) -> void:
	if g.mood.patience > 0.65:
		g.mood.delight(0.15, "That was quick!")
	var perfect := quality > 0.95
	g.mood.think("Perfectly juicy" if perfect else "A bit dry, this")
	var settled := g.start_eating(quality)
	if settled != "":
		g.mood.think(settled)
	sfx("serve")
	if perfect:
		sfx("perfect")
		burst(g.position + Vector3(0, 1.3, 0), "stars")


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


func finish_meal(g: Guest) -> void:
	var bill := g.mood.pay_for(BILL)
	if g.mood.paid_full():   # someone used to deals is let down by full price
		var letdown := town.paid_full_price(g.idx)
		if letdown > 0.0:
			g.mood.delight(-letdown, "Full price this time? Hm")
	var tip := g.mood.tip_for(bill, town.tip_bonus(g.idx))
	var was_sore: bool = g.info.sore
	var was_regular := town.is_regular(g.idx)
	ledger.record_sale(bill, tip)
	var talk := town.gossip_line(g.idx, town.record_visit(g.idx, g.mood.satisfaction()))
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
	g.table.dirty += 1
	g.table.refresh()
	popup("+$%d" % (bill + tip), g.position + Vector3(0, 1.9, 0), Color(Build.TRIM))
	Fx.coin(self, g.position + Vector3(0, 1.5, 0))
	if g.mood.satisfaction() > 0.5:
		g._heart_time = 2.5
	sfx("coin")
	_leave(g)


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
		names.append(m.info.name)
		var mark := Fx.play(m, "anger", Vector3(0, 1.75, 0), 0.3, true)
		mark.fps = 6.0
		_leave(m)
	hud.say(("%s walked out! " % " and ".join(names)) + (talk if going.size() == 1 else ""))
	sfx("fail")
	shake()


func _leave(g: Guest) -> void:
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
func prompt_for(st: Station) -> String:
	return use_station(st, true)


## The player uses the station they are facing. Returns the name of the action taken.
## With dry_run, nothing changes and only the name is returned.
func use_station(st: Station, dry_run := false) -> String:
	var held := player.held
	var q := player.held_quality
	var act := ""
	match st.type:
		"fridge":
			if held == "":
				act = "Take meat"
				if not dry_run:
					player.set_held("raw_patty")
		"stove", "counter", "pass":
			if held == "plate" and st.item == "cooked_patty":
				act = "Plate it"
				if not dry_run:
					player.set_held("burger", st.current_quality())
					st.set_item("")
			elif held == "cooked_patty" and st.item == "plate":
				act = "Plate it"
				if not dry_run:
					st.set_item("burger", q)
					player.set_held("")
			elif held != "" and st.item == "" and (st.type != "stove" or held.ends_with("patty")):
				act = "Cook" if st.type == "stove" else "Put down"
				if not dry_run:
					st.set_item(held, q)
					player.set_held("")
			elif held == "" and st.item != "":
				act = "Take off the heat" if st.type == "stove" else "Pick up"
				if not dry_run:
					player.set_held(st.item, st.current_quality())
					st.set_item("")
		"plates":
			if held == "" and st.count > 0:
				act = "Take plate"
				if not dry_run:
					st.count -= 1
					player.set_held("plate")
			elif held == "plate":
				act = "Put back"
				if not dry_run:
					st.count += 1
					player.set_held("")
			elif held == "cooked_patty" and st.count > 0:
				act = "Plate it"
				if not dry_run:
					st.count -= 1
					player.set_held("burger", q)
			if not dry_run:
				st.refresh()
		"sink":
			# Plates soak until they are washed, one at a time, back onto the stack.
			if held == "dirty_plate":
				act = "Put in sink"
				if not dry_run:
					player.set_held("")
					st.dirty += 1
					st.refresh()
			elif held == "" and st.dirty > 0:
				act = "Wash"
				if not dry_run:
					st.dirty -= 1
					st.refresh()
					var stack := find_station("plates")
					stack.count += 1
					stack.refresh()
		"bin":
			# Every scrap fills it; full, it overflows until the bag goes out the front.
			if held == "burger":
				act = "Scrape off"
				if not dry_run:
					player.set_held("plate")
			elif held.ends_with("patty"):
				act = "Throw away"
				if not dry_run:
					player.set_held("")
			elif held == "" and st.count > 0:
				act = "Empty bin"
				if not dry_run:
					st.count = 0
					st.refresh()
					player.set_held("rubbish_bag")
			if not dry_run and act in ["Scrape off", "Throw away"]:
				st.count += 1
				st.refresh()
		"table", "booth", "table4":
			var g := _waiting_guest_at(st)
			var fed := _guest_wanting(st, held)
			var to_order := _guests_to_order(st)
			if fed != null:
				act = "Serve %s" % fed.info.name
				if not dry_run:
					player.set_held("")
					serve(fed, q)
			elif not to_order.is_empty() and (held == "" or not ORDER_HANDS_FREE):
				act = "Take order" if to_order.size() == 1 else "Take %d orders" % to_order.size()
				if not dry_run:
					take_orders(st)
			elif held == "burger" and not to_order.is_empty():
				act = "Take order first"   # a refusal: nothing changes
				if not dry_run:
					hud.say("%s hasn't ordered yet. Free your hands and take the order." % to_order[0].info.name)
					sfx("fail")
					return act
			elif held == "" and st.dirty > 0:
				act = "Clear plate"
				if not dry_run:
					st.dirty -= 1
					st.refresh()
					player.set_held("dirty_plate")
			elif held == "" and g != null and not g.mood.discounted and g.mood.patience < DISCOUNT_BELOW:
				act = "Half price for %s" % g.info.name
				if not dry_run:
					offer_discount(g)
			elif held == "" and g != null and not g.mood.comped and g.mood.very_unhappy():
				act = "Free meal for %s" % g.info.name   # after half price, or for disgust
				if not dry_run:
					offer_comp(g)
	if act != "" and not dry_run:
		player.punch()
		st.used()
		if act == "Wash":
			sfx("wash")
			burst(st.position + Vector3(0, 1.15, 0), "bubbles", 0.4)
		elif not (act.begins_with("Serve") or act.begins_with("Half") or act.begins_with("Free") or act.begins_with("Take order") or act.ends_with(" orders")):
			sfx("pickup" if player.held != "" else "putdown")
	return act


func _tick_stoves(delta: float) -> void:
	var sizzling := false
	for st: Station in stations.values():
		var stage := st.tick_cooking(delta)
		if stage == "cooked_patty":
			sfx("ding")
			burst(st.position + Vector3(0, 1.2, 0), "stars", 0.4)
		elif stage == "burnt_patty":
			sfx("burn")
			shake(0.08)
		sizzling = sizzling or st.is_cooking()
	if _sfx.has("sizzle") and _sfx.sizzle.playing != sizzling:
		_sfx.sizzle.playing = sizzling


func step(delta: float) -> void:
	if phase != Phase.SERVICE:
		return
	clock += delta
	while not arrivals.is_empty() and float(arrivals[0].time) <= clock:
		var a: Dictionary = arrivals.pop_front()
		spawn_group(a.get("group", [a.get("idx", 0)]))
	_tick_stoves(delta)
	for st: Station in stations.values():
		st.dirty_age = st.dirty_age + delta if st.messy() else 0.0
	_collect_gross()
	_seat_waiting_guests()
	for g in guests.duplicate():
		g.tick(delta)
	if ledger.is_closed_down():
		_close_down()
	elif arrivals.is_empty() and guests.is_empty():
		_end_day()


# ---------------------------------------------------------------- input & frame

func _process(delta: float) -> void:
	var input := Vector2.ZERO
	if hud.options_open():
		pass   # paused anyway; the arrows belong to the options screen
	elif phase == Phase.SERVICE or (phase == Phase.BUILD and not shopping and not hud.typing()):
		input = controls.move(0)
	player.move(input, delta)
	player.carry(not hand.is_empty())
	if phase == Phase.BUILD:
		if input != Vector2.ZERO:
			_aim_mouse = false   # walking hands aim back to the chef
		if _aim_mouse:
			_mouse_point = floor_point(get_viewport().get_mouse_position())
		_paint_held(0)
		_refresh_openings()
	step(delta)
	_update_camera(delta)
	_update_cursor()
	_update_ghost()
	_update_range()
	_update_daylight()
	hud.update_status()
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


func _update_cursor() -> void:
	var st: Station = stations.get(player.target_cell())
	var action := prompt_for(st) if st != null and phase == Phase.SERVICE else ""
	_cursor.visible = action != ""
	var at := Vector2.ZERO
	if st != null:
		var top := 1.72 if st.type == "fridge" else 0.9
		_cursor.position = st.position + Vector3(0, top, 0)
		at = cam.unproject_position(st.position + Vector3(0, 2.25 if st.type == "stove" else top + 0.7, 0))
	if action == "":   # nothing to cook or serve: the build phase and the door card
		action = build_action() if phase == Phase.BUILD else door_action()
		var p := DOORWAY + Vector3(0, 2.9, 0)
		if not hand.is_empty() and _hover_point() != Vector3.INF:
			p = _hover_point() + Vector3(0, 2.0, 0)
		elif action == "Pick up":
			p = _piece_in_front() + Vector3(0, 2.0, 0)
		at = cam.unproject_position(p)
	hud.show_prompt(at, action)


## One action while the shop is open. Returns whether it was used.
func shop_action(action: String) -> bool:
	match action:
		"left": hud.shop_move(-1)
		"right": hud.shop_move(1)
		"up": hud.shop_category(-1)
		"down": hud.shop_category(1)
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
	var held := controls.holding(p, "use")
	if not held or shopping or hud.typing() or hand.is_empty() or floor_kind(hand.id) == "" or _aim_mouse:
		_last_paint = Vector3i(-999, -999, -1)
		return
	var spot := snap(_hover_point())
	if spot != _last_paint:
		_last_paint = spot
		if can_place(spot):
			place(spot)


## The mouse in the build phase: it aims whatever is in hand. Left click puts a
## piece down or picks one up; with a build tool, a left drag lays a rectangle of
## floor or a line of wall and a right drag takes them away. Right click drops a piece.
func _build_mouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_aim_mouse = true
		return
	# A touch on the room arrives as the mouse: the erase switch is the screen's player's.
	var erase := controls.input_of(controls.owner_of("touch" if event.device == InputEvent.DEVICE_ID_EMULATION else "keys")).erase
	var mb := event as InputEventMouseButton
	if mb == null or (mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT):
		return
	var p := floor_point(mb.position)
	_aim_mouse = true
	_mouse_point = p
	if p == Vector3.INF:
		return
	var tool := not hand.is_empty() and Catalog.is_build_tool(hand.id)
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	if mb.pressed:
		if tool:
			_drag = {"from": p, "remove": right or erase}
		elif right:
			cancel_hand()
		elif not hand.is_empty():
			if not place(snap(p)):
				sfx("fail")
		else:
			pick_up(p)
	elif not _drag.is_empty() and (right == bool(_drag.remove) or erase):
		finish_drag(_drag.from, p, _drag.remove)


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.BUILD and (event is InputEventMouseButton or event is InputEventMouseMotion):
		if event is InputEventMouseButton and event.pressed:
			hud.stop_typing()   # a click on the room leaves the search box
		if not shopping:
			_build_mouse(event)
		return
	if phase == Phase.SERVICE and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			inspect(guest_at(event.position))
		return
	# Keys, controller buttons and touch buttons arrive as act() from Controls.


## Player p pressed an action, on whatever device is theirs (see Controls).
## The options screen and the shop are shared; the rest is done by that
## player's chef.
func act(p: int, action: String, echo := false) -> void:
	if hud.options_open():
		hud.options_action(action, echo)
		return
	if hud.title_open():
		if action == "options":
			hud.toggle_options()
		else:
			hud.title.action(action, echo)
		return
	if echo:
		return
	if action == "options":
		hud.toggle_options()
		return
	if action == "mute":
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		return
	if p >= chefs.size():
		return   # a seated player with no chef yet (co-op is not built)
	match phase:
		Phase.SERVICE:
			if action == "use":
				var st: Station = stations.get(player.target_cell())
				if st != null and prompt_for(st) != "":
					use_station(st)
				elif not use_door() and st != null:
					use_station(st)
		Phase.SUMMARY:
			if action == "confirm":
				open_build()
			elif action == "town":
				hud.toggle_town()
		Phase.CLOSED:
			if action == "confirm":
				restart()
		Phase.BUILD:
			if shopping:
				shop_action(action)
			else:
				_build_act(action)


func _build_act(action: String) -> void:
	match action:
		"use":
			build_interact()
		"back":
			cancel_hand()
		"turn":
			rotate_hand()
		"shop":
			open_shop()
		"sell":
			if not hand.is_empty() and Catalog.is_build_tool(hand.id):
				if _hover_point() != Vector3.INF and remove_at(snap(_hover_point())):
					_plan_changed()
					sfx("coin")
				else:
					sfx("fail")
			elif not sell_hand():
				sfx("fail")
