class_name BuildStations
extends RefCounted
## Stations: what a sink or bin holds, chairs and counters, registering a built station,
## ingredient stations, the pass, hinges, base and node marks, and the wall layer's pieces.


## The washing-up in a sink: dirty plates leaning in the basin and, once it has
## piled up, a heap of suds that rises over the rim (readable from across the room).
static func sink_load(n: Node3D, plates: int, piled: bool) -> void:
	for i in mini(plates, 4):
		var p := BuildFood.item("dirty_plate")
		p.position = Vector3(-0.15 + i * 0.1, 0.95 + 0.01 * i, 0.06)
		p.rotation = Vector3(0.0, 0.0, -1.15)
		p.scale = Vector3.ONE * 0.8
		n.add_child(p)
	if not piled:
		return
	# A foam dome over the whole basin, lumpy, with a few bubbles floating off.
	for b: Array in [[-0.2, 0.0, 0.15], [0.0, 0.05, 0.19], [0.2, -0.02, 0.16], [-0.1, 0.15, 0.14], [0.13, 0.16, 0.13],
			[0.03, -0.14, 0.15], [-0.05, 0.0, 0.17]]:
		Build.ball(n, Vector3(b[0], 1.0 + b[2] * 0.4, 0.04 + b[1]), b[2], Build.SUDS, 0.0, Build.R_GLOSS).scale = Vector3(1, 0.85, 1)
	for b: Array in [[-0.14, 1.32, 0.07], [0.1, 1.4, 0.06], [0.0, 1.52, 0.045]]:
		Build.ball(n, Vector3(b[0], b[1], 0.04), b[2], "#9fd3de", 0.0, Build.R_GLOSS)


## The clean dishes drying in a rack: up to four plates (and cups) standing on end, one
## to a slot, so how full it is can be counted at a glance.
static func rack_load(n: Node3D, dishes: int, cups: int) -> void:
	for i in mini(dishes, 4):
		var cup := i >= dishes - cups
		var p := BuildFood.item("cup" if cup else "plate")
		p.position = Vector3(-0.21 + i * 0.14, 0.99 if not cup else 0.96, 0.0)
		p.rotation = Vector3(0.0, 0.0, -1.45 if not cup else 0.0)
		p.scale = Vector3.ONE * (1.0 if not cup else 0.9)
		n.add_child(p)


## What is in a bin: a mound of scraps that rises with each one thrown away, then,
## full, a bulging bag over the rim, rubbish spilt on the floor in front.
static func bin_load(n: Node3D, fill: int, holds: int) -> void:
	if fill <= 0:
		return
	if fill < holds:
		var h := 0.6 + 0.03 * fill
		Build.ball(n, Vector3(0, h - 0.1, 0), 0.2, Build.BAG).scale = Vector3(1, 0.6, 1)
		for i in fill:
			var a := TAU * i / 3.0 + 0.5
			Build.box(n, Vector3(cos(a) * 0.1, h, sin(a) * 0.1), Vector3(0.1, 0.05, 0.08), [Build.PAPER, "#c98a4a", "#e9c46a"][i % 3]).rotation.y = a
		return
	Build.ball(n, Vector3(0, 0.74, 0), 0.34, Build.BAG).scale = Vector3(1, 0.72, 1)
	Build.ball(n, Vector3(0.02, 0.97, 0.02), 0.07, Build.BAG)
	# Scraps on top and down the front (+z faces the room in the default layout, but
	# a bin is round enough for that not to matter much), and two on the floor.
	for s: Array in [[0.18, 0.9, 0.16, Build.PAPER, 0.4], [-0.2, 0.86, 0.12, "#e9c46a", 1.1], [-0.05, 0.88, -0.22, "#c98a4a", 2.0],
			[0.32, 0.62, 0.3, Build.PAPER, 0.8], [-0.3, 0.6, 0.32, "#e9c46a", -0.5]]:
		Build.box(n, Vector3(s[0], s[1], s[2]), Vector3(0.13, 0.05, 0.09), s[3]).rotation = Vector3(0.4, s[4], 0.3)
	for s: Array in [[0.48, 0.42, Build.PAPER], [-0.1, 0.55, "#c98a4a"], [0.3, 0.6, "#e9c46a"]]:
		Build.box(n, Vector3(s[0], 0.03, s[1]), Vector3(0.14, 0.05, 0.1), s[2]).rotation.y = s[0] * 4.0


## A dining chair standing `away` from the cell centre, its back on the far side.
## Sheet 10: a coral seat and back on dark wooden legs. The back legs run on up as
## two posts holding a low back panel, so the legs read below the seat and the
## back stays low enough to show faces (0.9 m).
static func _chair(n: Node3D, away: Vector2i, col: String) -> void:
	var c := Node3D.new()
	c.position = Vector3(away.x, 0, away.y)
	c.rotation.y = atan2(-float(away.y), float(away.x))
	n.add_child(c)
	var legs := Build.WOOD_DARK
	var rough := Build.R_MATTE if col == Build.CORAL else Build.R_WOOD
	for lz: float in [-0.22, 0.22]:
		var front := Build._add(c, Build.bevel_mesh(Vector3(0.07, 0.38, 0.07), 0.02), Vector3(-0.22, 0.19, lz), Color(legs), 0.0, Build.R_WOOD)
		front.rotation.x = -signf(lz) * 0.07   # splayed a little at the foot
		front.rotation.z = -0.07
		Build._add(c, Build.bevel_mesh(Vector3(0.075, 0.92, 0.075), 0.025), Vector3(0.22, 0.46, lz), Color(legs), 0.0, Build.R_WOOD)
		Build._add(c, Build.bevel_mesh(Vector3(0.44, 0.04, 0.04), 0.015), Vector3(0, 0.13, lz), Color(legs), 0.0, Build.R_WOOD)
	Build._add(c, Build.bevel_mesh(Vector3(0.54, 0.05, 0.54), 0.02), Vector3(0, 0.355, 0), Color(legs), 0.0, Build.R_WOOD)
	Build._add(c, Build.bevel_mesh(Vector3(0.52, 0.07, 0.52), 0.03), Vector3(-0.01, 0.41, 0), Color(col), 0.0, rough)
	Build._add(c, Build.bevel_mesh(Vector3(0.07, 0.3, 0.4), 0.03), Vector3(0.23, 0.72, 0), Color(col), 0.0, rough)
	Build._add(c, Build.bevel_mesh(Vector3(0.09, 0.05, 0.52), 0.02), Vector3(0.22, 0.9, 0), Color(legs), 0.0, Build.R_WOOD)


static func _shade(col: String, amount := 0.13) -> String:
	return Color(col).darkened(amount).to_html(false)


static func _tint(col: String, amount := 0.08) -> String:
	return Color(col).lightened(amount).to_html(false)


## A 0.9 m counter: darker toe-kick, body with two doors and brass handles on the
## front (+z), bevelled worktop. Everything that takes a carried item sits flush.
## A node marked "bare" (a shop preview of a counter-top piece) gets no plain counter
## stand; an appliance's own steel body stays.
static func _counter(n: Node3D, body: String, top: String, doors := true, kick := "") -> void:
	if n.has_meta("bare") and body != Build.STEEL:
		return
	Build.box(n, Vector3.ZERO, Vector3(0.9, 0.15, 0.9), _shade(body) if kick == "" else kick)
	Build.box(n, Vector3(0, 0.12, 0), Vector3(0.94, 0.7, 0.94), body)
	Build.box(n, Vector3(0, 0.77, 0), Vector3(1.0, 0.13, 1.0), top, 0.0, Build.R_WOOD)  # a thick slab of worktop
	if doors:
		for sx: float in [-1.0, 1.0]:
			Build.box(n, Vector3(sx * 0.225, 0.2, 0.462), Vector3(0.4, 0.54, 0.03), _tint(body, 0.07))
			Build.box(n, Vector3(sx * 0.08, 0.5, 0.48), Vector3(0.035, 0.12, 0.03), "#d9a441", 0.0, Build.R_WOOD)


## Turns a till `facing` quarter turns from its resting look, keeping it centred
## on the worktop: its offset from the middle turns with it. Kept as meta "facing".
static func face_till(till: Node3D, facing: int) -> void:
	facing = posmod(facing, 4)
	till.set_meta("facing", facing)
	till.rotation.y = PI / 2 + facing * PI / 2
	till.position = Vector3(0, 0.9, -0.08).rotated(Vector3.UP, facing * PI / 2)


## A proper cash register (sheet 1, sheet 8): a cream body on a coral cash drawer
## with a brass pull, a sloped deck of chunky keys with a big coral total key, a
## dark display pod with a warm amber window and a coral price flag popped up on
## top, a receipt curling out of the back and a brass crank on the camera side.
## `facing` is its quarter turns (see `face_till`).
## Reads at 20 px as cream block, dark band, coral drawer.
static func register(n: Node3D, facing := 0) -> void:
	var cream := Color("#efe6d4")
	var till := Node3D.new()
	till.name = "till"
	n.add_child(till)
	face_till(till, facing)
	# Cash drawer: a cream plinth with a coral front, a brass pull and a coin slot.
	Build._add(till, Build.bevel_mesh(Vector3(0.62, 0.15, 0.56), 0.04), Vector3(0, 0.075, 0), cream, 0.0)
	Build._add(till, Build.bevel_mesh(Vector3(0.54, 0.11, 0.03), 0.015), Vector3(0, 0.075, 0.28), Color(Build.CORAL), 0.0)
	Build.ball(till, Vector3(0, 0.075, 0.305), 0.03, "#d9a441", 0.0, Build.R_WOOD)
	# Body: a tall back block, and a key deck sloping down toward the front.
	Build._add(till, Build.bevel_mesh(Vector3(0.6, 0.26, 0.22), 0.045), Vector3(0, 0.27, -0.16), cream, 0.0)
	var deck := Node3D.new()
	deck.position = Vector3(0, 0.2, 0.08)
	deck.rotation.x = 0.38
	till.add_child(deck)
	Build._add(deck, Build.bevel_mesh(Vector3(0.6, 0.12, 0.38), 0.04), Vector3.ZERO, cream, 0.0)
	Build._add(deck, Build.bevel_mesh(Vector3(0.5, 0.012, 0.3), 0.005), Vector3(0, 0.062, 0), Color("#d8ccb6"), 0.0)
	for row in 3:
		for col in 4:
			if row == 2 and col == 3:
				continue  # the total key takes this corner
			Build.cyl(deck, Vector3(-0.17 + col * 0.105, 0.06, -0.1 + row * 0.095), 0.034, 0.03, "#fbf6ea" if (row + col) % 3 else "#3d4a4f")
	Build._add(deck, Build.bevel_mesh(Vector3(0.1, 0.035, 0.17), 0.015), Vector3(0.155, 0.08, 0.05), Color(Build.CORAL), 0.0)
	# Display pod with a lit amber window, and a coral price flag popped up on top.
	Build._add(till, Build.bevel_mesh(Vector3(0.44, 0.15, 0.16), 0.04), Vector3(0, 0.46, -0.15), Color("#2f3a3e"), 0.0)
	Build._add(till, Build.bevel_mesh(Vector3(0.32, 0.075, 0.02), 0.01), Vector3(0, 0.465, -0.065), Color("#ffcf73"), 1.1)
	Build.box(till, Vector3(0, 0.53, -0.17), Vector3(0.025, 0.1, 0.025), "#9aa3a6", 0.0, Build.R_WOOD)
	Build._add(till, Build.bevel_mesh(Vector3(0.2, 0.1, 0.03), 0.02), Vector3(0, 0.67, -0.17), Color(Build.CORAL), 0.0)
	Build._add(till, Build.bevel_mesh(Vector3(0.11, 0.025, 0.012), 0.008), Vector3(0, 0.67, -0.152), Color(Build.PAPER), 0.0)
	# A curl of receipt out of the back.
	var paper := Build._add(till, Build.bevel_mesh(Vector3(0.16, 0.2, 0.01), 0.004), Vector3(0.14, 0.44, -0.29), Color(Build.PAPER), 0.0)
	paper.rotation.x = -0.45
	# A brass crank on the left side, which faces the camera on the pass.
	var crank := Node3D.new()
	crank.position = Vector3(-0.31, 0.28, -0.12)
	till.add_child(crank)
	Build.cyl(crank, Vector3.ZERO, 0.045, 0.04, "#d9a441", 0.0, Build.R_WOOD).rotation.z = PI / 2
	Build.box(crank, Vector3(-0.05, -0.12, 0), Vector3(0.03, 0.16, 0.03), "#d9a441", 0.0, Build.R_WOOD)
	Build.ball(crank, Vector3(-0.07, -0.13, 0), 0.04, Build.WOOD_DARK)


## Which body an ingredient station has: a cold cabinet for meat, fish and cheese,
## a sack for potatoes and onions, a fountain or barrel for poured drinks, else a crate
## (a juiced or blended drink's box is a crate of its fruit, not a dispenser).
static func _store_kind(id: String) -> String:
	if Pantry.is_poured(id):
		return "drink"
	if id in ["fish", "calamari", "mussels"]:
		return "ice"
	if id in ["patty", "cheese", "ice_cream"]:
		return "cold"
	if id in ["onion", "potato", "new_potato"]:
		return "sack"
	if id in ["roll", "sourdough", "crusty_loaf", "breadcrumbs"]:
		return "basket"
	return "crate"


## An ingredient station (sheet 8's kitchen units, one per ingredient): a counter
## whose top shows what it hands out, raw, so it reads at 20 px; a ready-made tub
## shows the ingredient prepped, in a steel tub with a green tag.
static func _ingredient_station(n: Node3D, id: String, ready: bool, as_box := false) -> void:
	var kind := "ready" if ready else _store_kind(id)
	if as_box:
		# A box of stock (PRD 8.4): the old station's top, lifted off its counter onto a
		# low body of its own, so it reads as something carried and put away.
		var inner := Node3D.new()
		inner.position.y = -0.48
		inner.scale = Vector3.ONE * 0.8
		n.add_child(inner)
		n = inner
		var body := {"cold": "#eef3f4", "ice": "#4fa3b8", "ready": Build.STEEL, "crate": Build.WOOD}
		if body.has(kind):
			Build.box(n, Vector3(0, 0.6, 0), Vector3(0.84, 0.3, 0.8), body[kind])
		if kind == "cold":   # a frost-blue band: kept cold, by shape as well as colour
			Build.box(n, Vector3(0, 0.75, 0.41), Vector3(0.6, 0.08, 0.02), "#8fc3cf")
	match kind:
		"cold":
			if not as_box:
				_counter(n, "#f3ecdc", "#fbf6ea")
			Build.box(n, Vector3(0, 0.9, 0), Vector3(0.82, 0.06, 0.82), "#cfe3e6", 0.0, Build.R_GLOSS)
			Build.box(n, Vector3(0, 0.62, 0.48), Vector3(0.5, 0.05, 0.03), Build.STEEL, 0.0, Build.R_WOOD)
			for k in 3:
				var at := Node3D.new()
				at.position = Vector3(-0.24 + k * 0.24, 0.96, -0.12 + (k % 2) * 0.2)
				at.scale = Vector3.ONE * 0.8
				n.add_child(at)
				BuildFood.ingredient(at, id, "raw", "raw")
		"ice":
			# A seaside icebox: a sea-blue cooler with its lid propped open at the back,
			# full of crushed ice with the catch laid on top.
			if not as_box:
				_counter(n, Build.WOOD, Build.WORKTOP, false)
			Build._add(n, Build.bevel_mesh(Vector3(0.86, 0.2, 0.78), 0.04), Vector3(0, 0.98, 0.0), Color("#4fa3b8"), 0.0)
			Build.box(n, Vector3(0, 1.06, 0), Vector3(0.74, 0.04, 0.66), "#eef8fa", 0.0, Build.R_GLOSS)
			for k in 6:
				Build.ball(n, Vector3(-0.3 + k * 0.12, 1.1, 0.26 - (k % 3) * 0.24), 0.04, "#ffffff", 0.0, Build.R_GLOSS)
			var lid := Build._add(n, Build.bevel_mesh(Vector3(0.86, 0.36, 0.05), 0.02), Vector3(0, 1.22, -0.42), Color("#4fa3b8"), 0.0)
			lid.rotation.x = -0.25
			Build.box(n, Vector3(0, 0.94, 0.4), Vector3(0.6, 0.06, 0.02), Build.PAPER)
			for x: float in [-0.45, 0.45]:
				Build.box(n, Vector3(x, 1.0, 0), Vector3(0.04, 0.05, 0.22), Build.STEEL_DARK, 0.0, Build.R_WOOD)
			for k in 3:
				var at := Node3D.new()
				at.position = Vector3(-0.22 + k * 0.22, 1.09, -0.12 + (k % 2) * 0.22)
				at.scale = Vector3.ONE * 0.85
				n.add_child(at)
				BuildFood.ingredient(at, id, "raw", "raw")
		"basket":
			# A low wicker basket of rolls, a checked cloth tucked over one side.
			if not as_box:
				_counter(n, Build.WOOD, Build.WORKTOP, false)
			Build.lathe(n, Vector3(0, 0.9, 0), [[0.0, 0.0], [0.28, 0.0], [0.36, 0.18], [0.32, 0.18], [0.25, 0.04], [0.0, 0.04]], "#c8964f", 0.0, Build.R_WOOD)
			for h: float in [0.06, 0.12]:
				Build.lathe(n, Vector3(0, 0.9 + h, 0), [[0.28 + h * 0.44, 0.0], [0.3 + h * 0.44, 0.0], [0.3 + h * 0.44, 0.012], [0.28 + h * 0.44, 0.012]], "#9a6c34", 0.0, Build.R_WOOD)
			Build.box(n, Vector3(-0.2, 1.0, 0.0), Vector3(0.22, 0.03, 0.5), Build.PAPER).rotation.z = 0.3
			for k in 3:
				Build.box(n, Vector3(-0.2, 1.017, -0.16 + k * 0.16), Vector3(0.222, 0.03, 0.06), Build.CORAL).rotation.z = 0.3
			for k in 3:
				var at := Node3D.new()
				at.position = Vector3(0.08 + (k % 2) * 0.12 - 0.04, 0.96 + (k / 2) * 0.06, -0.12 + k * 0.12)
				at.scale = Vector3.ONE * 0.9
				n.add_child(at)
				BuildFood.ingredient(at, id, "raw", "raw")
		"sack":
			if not as_box:
				_counter(n, Build.WOOD, Build.WORKTOP, false)
			Build.ball(n, Vector3(0, 1.12, -0.05), 0.33, "#c8a56e").scale = Vector3(1, 0.8, 0.85)
			Build.lathe(n, Vector3(0, 1.3, -0.05), [[0.0, 0.0], [0.24, 0.0], [0.27, 0.05], [0.0, 0.05]], "#b48c56")
			for k in 3:
				var at := Node3D.new()
				at.position = Vector3(-0.16 + k * 0.16, 1.3, -0.05 + (k % 2) * 0.08)
				at.scale = Vector3.ONE * 0.75
				n.add_child(at)
				BuildFood.ingredient(at, id, "raw", "raw")
		"drink":
			if not as_box:
				_counter(n, Build.CORAL, Build.WORKTOP)
			if id == "wine":
				var barrel := Build.cyl(n, Vector3(0, 1.18, 0), 0.3, 0.6, Build.WOOD, 0.0, Build.R_WOOD)
				barrel.rotation.x = PI / 2
				for z: float in [-0.2, 0.2]:
					Build.cyl(n, Vector3(0, 1.18, z), 0.31, 0.04, Build.STEEL_DARK, 0.0, Build.R_WOOD).rotation.x = PI / 2
				Build.cyl(n, Vector3(0, 1.08, 0.3), 0.03, 0.1, "#d9a441", 0.0, Build.R_WOOD).rotation.x = PI / 2
				var glass := Node3D.new()
				glass.position = Vector3(0.3, 0.9, 0.3)
				glass.scale = Vector3.ONE * 1.3
				n.add_child(glass)
				BuildFood.ingredient(glass, id, "prep")
			else:
				Build._add(n, Build.bevel_mesh(Vector3(0.5, 0.6, 0.36), 0.05), Vector3(0, 0.9, -0.2), Color(Build.CORAL), 0.0)
				Build.box(n, Vector3(0, 1.32, -0.2), Vector3(0.54, 0.16, 0.4), Build.PAPER)
				for x: float in [-0.12, 0.12]:
					Build.cyl(n, Vector3(x, 1.18, 0.0), 0.03, 0.08, Build.STEEL, 0.0, Build.R_WOOD)
				Build.box(n, Vector3(0, 0.92, 0.1), Vector3(0.5, 0.03, 0.22), Build.STEEL, 0.0, Build.R_WOOD)
		"ready":
			if not as_box:
				_counter(n, Build.STEEL, Build.WORKTOP)
			Build.box(n, Vector3(0, 0.9, 0), Vector3(0.7, 0.14, 0.6), "#c9d0d1", 0.0, Build.R_WOOD)
			var at := Node3D.new()
			at.position = Vector3(0, 0.99, 0)
			n.add_child(at)
			BuildFood.ingredient(at, id, "prep")
			Build.box(n, Vector3(0.3, 0.6, 0.48), Vector3(0.2, 0.2, 0.02), Build.GOOD)
		_:
			if not as_box:
				_counter(n, Build.WOOD, Build.WORKTOP, false)
			for x: float in [-0.3, 0.3]:   # slatted crate sides
				Build.box(n, Vector3(x, 0.9, 0), Vector3(0.06, 0.24, 0.8), Build.WOOD_DARK)
			for z: float in [-0.38, 0.38]:
				Build.box(n, Vector3(0, 0.9, z), Vector3(0.66, 0.24, 0.05), Build.WOOD_DARK)
			for k in 4:
				var at := Node3D.new()
				at.position = Vector3(-0.13 + (k % 2) * 0.26, 0.92, -0.16 + (k / 2) * 0.3)
				at.scale = Vector3.ONE * 0.85
				n.add_child(at)
				BuildFood.ingredient(at, id, "raw", "raw")


## The frame's long teal counter (the starting counters). Each piece runs a little past
## its cell, so a row of them is one unbroken body under one unbroken worktop.
## `front`: a door panel and a brass pull on the +z face, so a turned piece shows which
## way it faces (the body alone is the same on every side). Inside a run the marks sit
## in the next piece's body, so only an end of the run, or a turned piece, shows them.
static func _pass(n: Node3D, front := false) -> void:
	Build.box(n, Vector3.ZERO, Vector3(0.9, 0.15, 1.04), Build.CORAL)
	if front:
		Build.box(n, Vector3(0, 0.2, 0.545), Vector3(0.7, 0.5, 0.03), _tint(Build.CABINET, 0.07))
		Build.box(n, Vector3(0, 0.5, 0.565), Vector3(0.3, 0.035, 0.03), "#d9a441", 0.0, Build.R_WOOD)
	Build._add(n, Build.bevel_mesh(Vector3(0.94, 0.7, 1.08), 0.03), Vector3(0, 0.47, 0), Color(Build.CABINET), 0.0)
	Build._add(n, Build.bevel_mesh(Vector3(1.0, 0.13, 1.1), 0.03), Vector3(0, 0.835, 0), Color(Build.WORKTOP), 0.0, Build.R_WOOD)


## A double counter (a counter placed on a counter, PRD 8): more storage, so it wears
## stacked drawers, a column of three down each side with brass pulls, readable from
## any turn; a bare one also swaps its front doors for two rows of drawers. The tool
## on top, if any, draws over it as usual.
static func _double(n: Node3D, front: bool, dz := 0.0) -> void:
	var face := _tint(Build.CABINET, 0.07)
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var y := 0.18 + k * 0.19
			Build.box(n, Vector3(sx * 0.478, y, 0), Vector3(0.03, 0.16, 0.8), face)
			Build.box(n, Vector3(sx * 0.5, y + 0.065, 0), Vector3(0.03, 0.035, 0.18), "#d9a441", 0.0, Build.R_WOOD)
	if not front:
		return
	for k in 2:
		var y := 0.2 + k * 0.28
		for sx: float in [-1.0, 1.0]:
			Build.box(n, Vector3(sx * 0.225, y, 0.462 + dz), Vector3(0.4, 0.25, 0.03), face)
			Build.box(n, Vector3(sx * 0.225, y + 0.17, 0.48 + dz), Vector3(0.14, 0.035, 0.03), "#d9a441", 0.0, Build.R_WOOD)


## A door's hinge: a node named "door" at the hinge line, which Station.used() swings
## open and shut. Its parts are drawn relative to the hinge.
static func hinge(n: Node3D, at: Vector3) -> Node3D:
	var h := Node3D.new()
	h.name = "door"
	h.position = at
	n.add_child(h)
	return h


## Furniture visuals centred on a cell, front facing +z. Tier adds a gold trim.
## Shapes and heights are shared by every theme (sheets 8 and 10). `node` is the
## piece's place in its upgrade tree (PRD 8.3): a step adds its own marks.
static func station(n: Node3D, type: String, tier: int, base := "", pass_look := false, node := "") -> void:
	if type == "till":   # its own piece, drawn at worktop height as it stands on a counter
		register(n)
		return
	BuildStationBody._station_body(n, type, tier, base, pass_look, node)
	_base_marks(n, base, PASS_FRONT if pass_look and not Kitchen.is_tall(base) else 0.0)
	if node != "" and node != base:
		_node_marks(n, node)


## How far a length of the pass stands proud of a plain counter's front: its marks
## (drawers, a fridge door) come forward by this, or the pass's body hides them.
const PASS_FRONT := 0.09


## What an upgraded counter adds under whatever stands on it: a third row of drawers
## (long counter), a white fridge front with a frost-blue badge (under-counter fridge),
## or a whole tall fridge (its top is then not a worktop). `dz` brings the front
## marks forward onto a length of the pass.
static func _base_marks(n: Node3D, base: String, dz := 0.0) -> void:
	match base:
		"long_counter":
			_double(n, false)
			for sx: float in [-1.0, 1.0]:
				Build.box(n, Vector3(sx * 0.225, 0.06, 0.47 + dz), Vector3(0.4, 0.08, 0.03), _tint(Build.CABINET, 0.07))
				Build.box(n, Vector3(sx * 0.225, 0.07, 0.49 + dz), Vector3(0.14, 0.03, 0.03), "#d9a441", 0.0, Build.R_WOOD)
		"fridge":
			# A cold dark inside, seen when the door (hinged on the left) swings open.
			Build.box(n, Vector3(0, 0.15, 0.455 + dz), Vector3(0.84, 0.58, 0.02), "#2b4a52")
			var door := hinge(n, Vector3(-0.45, 0.0, 0.47 + dz))
			Build.box(door, Vector3(0.45, 0.13, 0), Vector3(0.9, 0.62, 0.04), "#eef3f4", 0.0, Build.R_GLOSS)
			Build.box(door, Vector3(0.45, 0.66, 0.03), Vector3(0.6, 0.045, 0.04), "#c9d0d1", 0.0, Build.R_WOOD)
			Build.cyl(door, Vector3(0.75, 0.32, 0.02), 0.07, 0.02, "#8fc3cf").rotation.x = PI / 2
		"tall_fridge", "glass_fridge":
			Build.box(n, Vector3(0, 0.0, 0), Vector3(0.96, 2.1, 0.94), "#eef3f4", 0.0, Build.R_GLOSS)
			if base == "glass_fridge":   # seen through: no door to swing (PRD 8 fixes)
				Build.box(n, Vector3(0, 1.32, 0.48), Vector3(0.86, 0.04, 0.02), "#c9d0d1")
				Build.box(n, Vector3(0.36, 0.9, 0.5), Vector3(0.05, 0.6, 0.04), "#c9d0d1", 0.0, Build.R_WOOD)
				Build.box(n, Vector3(-0.04, 0.2, 0.485), Vector3(0.66, 1.0, 0.02), "#8fc3cf", 0.0, Build.R_GLOSS)
				Build.cyl(n, Vector3(-0.3, 1.7, 0.49), 0.08, 0.02, "#8fc3cf").rotation.x = PI / 2
			else:   # the lower door swings open on a dark cold inside; the freezer door stays
				Build.box(n, Vector3(0, 0.12, 0.475), Vector3(0.84, 1.14, 0.02), "#2b4a52")
				Build.box(n, Vector3(0, 1.32, 0.48), Vector3(0.86, 0.04, 0.02), "#c9d0d1")
				Build.cyl(n, Vector3(-0.3, 1.7, 0.49), 0.08, 0.02, "#8fc3cf").rotation.x = PI / 2
				var door := hinge(n, Vector3(-0.46, 0.0, 0.49))
				Build.box(door, Vector3(0.46, 0.06, 0), Vector3(0.9, 1.24, 0.03), "#eef3f4", 0.0, Build.R_GLOSS)
				Build.box(door, Vector3(0.82, 0.9, 0.025), Vector3(0.05, 0.36, 0.04), "#c9d0d1", 0.0, Build.R_WOOD)


## The marks a tree step puts on its tool. An efficient step shows as brass studs on
## the front (one a step), so it reads by shape at 20 px; a specialist has its own part.
static func _node_marks(n: Node3D, node: String) -> void:
	var steps := 0
	var up := node
	while Kitchen.has_node(up) and not Kitchen.is_root(up) and Kitchen.step_of(up) == Kitchen.EFFICIENT:
		steps += 1
		up = Kitchen.parent_of(up)
	for i in steps:
		Build.ball(n, Vector3(-0.38 + i * 0.1, 0.83, 0.5), 0.035, "#d9a441", 0.0, Build.R_WOOD)
	match node:
		"sharp_knife", "butcher_block":
			if node == "butcher_block":   # an end-grain block, thick and dark
				Build._add(n, Build.bevel_mesh(Vector3(0.7, 0.12, 0.52), 0.02), Vector3(0, 0.9, 0), Color("#b07a45"), 0.0, Build.R_WOOD)
			Build.box(n, Vector3(-0.16, 0.97 if node == "butcher_block" else 0.94, -0.12), Vector3(0.3, 0.012, 0.06), "#f4f8f8", 0.0, Build.R_GLOSS).rotation.y = -0.4
		"auto_slicer":   # a motor housing with a lit coral switch
			Build._add(n, Build.bevel_mesh(Vector3(0.2, 0.18, 0.2), 0.03), Vector3(-0.2, 0.98, -0.14), Color(Build.STEEL_DARK), 0.0)
			Build.ball(n, Vector3(-0.2, 1.17, -0.14), 0.04, Build.CORAL, 1.2)
		"two_hob_range":   # a second pan on the front burner
			Build.lathe(n, Vector3(-0.22, 0.905, 0.22), [[0.0, 0.0], [0.13, 0.0], [0.16, 0.035], [0.15, 0.035], [0.12, 0.018], [0.0, 0.018]], "#34383b", 0.0, Build.R_WOOD)
		"char_grill":   # black grill bars across the cooking side
			for k in 5:
				Build.box(n, Vector3(-0.2 + k * 0.1, 0.93, 0.02), Vector3(0.03, 0.03, 0.7), "#1f2224", 0.0, Build.R_WOOD)
		"twin_fryer":   # a second basket handle
			Build.box(n, Vector3(0.05, 1.02, -0.36), Vector3(0.04, 0.24, 0.04), Build.STEEL_DARK)
		"rotary_grater":   # a drum and a big crank on the grater's side, a coral knob
			Build.cyl(n, Vector3(0.07, 1.12, -0.04), 0.09, 0.05, Build.STEEL_DARK).rotation.z = PI / 2
			Build.box(n, Vector3(0.11, 1.22, -0.04), Vector3(0.035, 0.24, 0.035), Build.STEEL_DARK)
			Build.box(n, Vector3(0.16, 1.33, -0.04), Vector3(0.1, 0.035, 0.035), Build.STEEL_DARK)
			Build.ball(n, Vector3(0.22, 1.33, -0.04), 0.05, Build.CORAL)
		"two_tap_fountain", "wine_rack":   # a second tap
			Build.box(n, Vector3(0.22, 1.25, 0.2), Vector3(0.06, 0.16, 0.06), "#c9d0d1", 0.0, Build.R_WOOD)
			Build.ball(n, Vector3(0.22, 1.36, 0.2), 0.05, Build.CORAL if node == "two_tap_fountain" else "#7a2e3a")


## The wall layer (PRD 8.5). Heights of the high band: a high piece hangs between
## HIGH_Y0 and HIGH_Y1, its back on the wall (local z -0.5), front toward +z.
const HIGH_Y0 := 1.38
const HIGH_Y1 := 2.32
const HOOD_COL := "#7fa3a8"


## A piece hung in a cell's high layer: a wall cabinet, an open shelf (two planks when
## wide), or a hood. `drop` lowers it (shop previews).
static func wall_piece(n: Node3D, node: String, drop := 0.0) -> void:
	var y0 := HIGH_Y0 - drop
	var back := -0.5
	match node:
		"cabinet":
			# A teal wall cabinet: two doors with brass pulls under a thin cornice.
			Build._add(n, Build.bevel_mesh(Vector3(0.94, 0.86, 0.42), 0.04), Vector3(0, y0 + 0.48, back + 0.21), Color(Build.CABINET), 0.0)
			Build.box(n, Vector3(0, y0 + 0.9, back + 0.22), Vector3(0.98, 0.05, 0.46), Build.WOOD, 0.0, Build.R_WOOD)
			# The left door swings open on a dark inside when the cabinet is used.
			Build.box(n, Vector3(-0.225, y0 + 0.12, back + 0.415), Vector3(0.4, 0.72, 0.02), "#2b3a3a")
			Build.box(n, Vector3(0.225, y0 + 0.1, back + 0.43), Vector3(0.42, 0.76, 0.03), _tint(Build.CABINET, 0.07))
			Build.box(n, Vector3(0.07, y0 + 0.14, back + 0.455), Vector3(0.035, 0.16, 0.03), "#d9a441", 0.0, Build.R_WOOD)
			var door := hinge(n, Vector3(-0.435, y0, back + 0.43))
			Build.box(door, Vector3(0.21, 0.1, 0), Vector3(0.42, 0.76, 0.03), _tint(Build.CABINET, 0.07))
			Build.box(door, Vector3(0.365, 0.14, 0.025), Vector3(0.035, 0.16, 0.03), "#d9a441", 0.0, Build.R_WOOD)
		"shelf", "wide_shelf":
			var planks := 2 if node == "wide_shelf" else 1
			for i in planks:
				var y := y0 + 0.12 + i * 0.44
				Build.box(n, Vector3(0, y, back + 0.15), Vector3(0.94, 0.05, 0.3), Build.WOOD, 0.0, Build.R_WOOD)
				for sx: float in [-0.36, 0.36]:   # brass brackets under each plank
					Build.box(n, Vector3(sx, y - 0.16, back + 0.04), Vector3(0.04, 0.16, 0.08), "#d9a441", 0.0, Build.R_WOOD)
				# Jars on the plank: the jar shelf of sheet 1.
				var jars := [Build.PAPER, Build.CORAL, Build.TILE_TEAL, Build.WARN]
				for j in 3:
					var jx := -0.28 + j * 0.28
					var tall := 0.18 + 0.05 * ((i + j) % 2)
					Build.cyl(n, Vector3(jx, y + 0.05, back + 0.15), 0.08, tall, jars[(i + j) % jars.size()], 0.0, Build.R_GLOSS)
					Build.cyl(n, Vector3(jx, y + 0.05 + tall, back + 0.15), 0.065, 0.04, Build.WOOD_DARK)
		"hook":
			# A wooden plate on the wall with a brass hook bent up off it (PRD 9.4).
			Build.box(n, Vector3(0, y0 + 0.08, back + 0.03), Vector3(0.3, 0.36, 0.05), Build.WOOD, 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0, y0 + 0.02, back + 0.12), Vector3(0.05, 0.05, 0.16), "#d9a441", 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0, y0 + 0.07, back + 0.19), Vector3(0.05, 0.12, 0.04), "#d9a441", 0.0, Build.R_WOOD)
		"hood", "extractor":
			# A sloped steel-blue canopy over the stove (sheet 1), a square frustum squashed
			# to the wall's depth, with a duct up to the top of the wall. The extractor
			# (PRD 9.5) swaps the square duct for a round steel one with a fan box on it,
			# its blades showing, and a coral trim band along the canopy's lip.
			var hold := Node3D.new()
			hold.position = Vector3(0, y0, back + 0.37)
			hold.scale = Vector3(1, 1, 0.76)
			n.add_child(hold)
			var canopy := Build._add(hold, Build.lathe_mesh([[0.0, 0.0], [0.69, 0.0], [0.69, 0.1], [0.34, 0.46], [0.0, 0.46]], 4), Vector3.ZERO, Color(HOOD_COL), 0.0, Build.R_WOOD)
			canopy.rotation.y = PI / 4
			Build.box(n, Vector3(0, y0 - 0.005, back + 0.38), Vector3(0.8, 0.02, 0.56), "#4a5a5e")   # the filter
			if node == "hood":
				Build._add(n, Build.bevel_mesh(Vector3(0.46, 0.5, 0.36), 0.03), Vector3(0, y0 + 0.68, back + 0.19), Color(_shade(HOOD_COL, 0.08)), 0.0, Build.R_WOOD)
			else:
				Build.box(hold, Vector3(0, 0.07, 0), Vector3(0.99, 0.05, 0.99), Build.CORAL)   # the trim band
				Build._add(n, Build.bevel_mesh(Vector3(0.5, 0.34, 0.36), 0.05), Vector3(0, y0 + 0.4, back + 0.2), Color(Build.STEEL_DARK), 0.0, Build.R_WOOD)
				Build.cyl(n, Vector3(0, y0 + 0.74, back + 0.2), 0.14, 0.3, Build.STEEL, 0.0, Build.R_GLOSS)
				var fan := Node3D.new()   # the fan face, turned to the room
				fan.position = Vector3(0, y0 + 0.57, back + 0.39)
				fan.rotation.x = PI / 2
				n.add_child(fan)
				Build.cyl(fan, Vector3.ZERO, 0.14, 0.02, "#3a4548")
				for i in 3:
					Build.box(fan, Vector3(0, 0.025, 0), Vector3(0.24, 0.01, 0.06), Build.STEEL, 0.0, Build.R_GLOSS).rotation.y = TAU * i / 3.0
				Build.ball(fan, Vector3(0, 0.03, 0), 0.03, Build.CORAL)
