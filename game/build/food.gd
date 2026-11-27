class_name BuildFood
extends RefCounted
## Food and dishes (style guide, sheets 9 and 9b): patties, fillets, breads and every
## ingredient raw, prepped or burnt; plates, cups, stacks, trays and anything carried.


## How much bigger than modelled every loose item in play is drawn (T-87): food, plates,
## cups, stacks and trays on a station, in a chef's hands, on a table or in flight.
## Stations, furniture and pegs keep their own size.
const SIZE := 1.2


## The five patty looks from sheet 9: raw, nearly, perfect, dry, burnt.
static func patty(n: Node3D, look: String, y := 0.0) -> void:
	match look:
		"raw":
			Build._puck(n, y, 0.135, 0.075, "#f2a7ad")
		"nearly":
			Build._puck(n, y, 0.135, 0.07, "#c9986a")
			Build.lathe(n, Vector3(0, y + 0.012, 0), [[0.125, 0.0], [0.14, 0.012], [0.14, 0.036], [0.125, 0.048]], "#e3a63a", 0.0, Build.R_GLOSS)
		"perfect":
			Build._puck(n, y, 0.135, 0.07, "#7a3b22")
			for dx: float in [-0.045, 0.045]:
				Build.box(n, Vector3(dx, y + 0.062, 0), Vector3(0.03, 0.014, 0.19), "#4a2414").rotation.y = 0.6
		"dry":
			Build._puck(n, y, 0.14, 0.04, "#b79f88")
		"burnt":
			Build._puck(n, y, 0.125, 0.055, "#2a2523")
			for i in 6:  # a jagged hockey puck
				var a := TAU * i / 6.0
				var lump := Build.box(n, Vector3(cos(a) * 0.09, y + 0.005, sin(a) * 0.09), Vector3(0.09, 0.06 + 0.02 * (i % 2), 0.08), "#1f1b1a")
				lump.rotation = Vector3(0.3 * (i % 3 - 1), a, 0.25)


static func look_for(kind: String, quality: float) -> String:
	var p := Tray.parse(kind)
	if not p.is_empty():
		if p.state == "raw":
			return "raw"
		if p.state == "burnt":
			return "burnt"
	return "perfect" if quality > 0.95 else "dry"


const BURNT := "#2a2523"
const FISH_CRUST := "#e0a253"   # the golden top of a grilled fillet; its side is the fish's prepped colour


## A bread roll: an oval dome with a scored top (rounder and darker than the bun).
static func _roll(n: Node3D, y: float, col: String) -> void:
	Build.ball(n, Vector3(0, y + 0.07, 0), 0.12, col, 0.0, Build.R_GLOSS).scale = Vector3(1.3, 0.62, 0.92)
	for dx: float in [-0.05, 0.0, 0.05]:
		Build.box(n, Vector3(dx, y + 0.13, 0), Vector3(0.022, 0.012, 0.12), BuildStations._shade(col, 0.22)).rotation.y = 0.5


## A battered ring of calamari, lying flat.
static func _ring(n: Node3D, pos: Vector3, col: String) -> MeshInstance3D:
	return Build.lathe(n, pos, [[0.03, 0.0], [0.06, 0.0], [0.068, 0.015], [0.06, 0.03], [0.03, 0.03], [0.024, 0.015], [0.03, 0.0]], col, 0.0, Build.R_GLOSS)


## A thin round slice: a coloured rim (peel or skin) round a paler face.
static func _wheel(n: Node3D, pos: Vector3, rim: String, face: String, r := 0.062) -> void:
	Build._puck(n, pos.y, r, 0.018, rim).position += Vector3(pos.x, 0, pos.z)
	Build._puck(n, pos.y + 0.004, r * 0.8, 0.018, face).position += Vector3(pos.x, 0, pos.z)


## The fish fillet's five grill looks, after the salmon on sheet 9b: a chunky salmon
## block with pale fat lines when raw, a golden crust with grill marks when done.
static func fillet(n: Node3D, look: String, y := 0.0) -> void:
	var body: String = {"raw": Pantry.ITEMS.fish.colour, "nearly": "#f49a76", "perfect": Pantry.ITEMS.fish.prepped,
		"dry": "#dcbca4", "burnt": BURNT}.get(look, Pantry.ITEMS.fish.colour)
	var f := Node3D.new()
	f.position = Vector3(0, y, 0)
	f.rotation.y = 0.35
	n.add_child(f)
	Build._add(f, Build.bevel_mesh(Vector3(0.3, 0.08, 0.19), 0.03), Vector3(0, 0.04, 0), Color(body), 0.0, Build.R_GLOSS)
	match look:
		"raw":
			for k in 3:
				Build.box(f, Vector3(-0.08 + k * 0.08, 0.075, 0), Vector3(0.016, 0.008, 0.17), "#fde3d6").rotation.y = 0.45
		"nearly":
			Build._add(f, Build.bevel_mesh(Vector3(0.31, 0.03, 0.2), 0.012), Vector3(0, 0.018, 0), Color("#e3a63a"), 0.0, Build.R_GLOSS)
		"perfect":
			Build._add(f, Build.bevel_mesh(Vector3(0.28, 0.03, 0.17), 0.012), Vector3(0, 0.08, 0), Color(FISH_CRUST), 0.0, Build.R_GLOSS)
			for dx: float in [-0.06, 0.06]:
				Build.box(f, Vector3(dx, 0.092, 0), Vector3(0.022, 0.01, 0.15), "#8a5a2e").rotation.y = 0.5
		"burnt":
			for k in 3:
				Build.box(f, Vector3(-0.09 + k * 0.09, 0.06, 0.03 * (k % 2)), Vector3(0.08, 0.04, 0.07), "#1f1b1a").rotation = Vector3(0.2 * (k - 1), k, 0.2)


## A wooden serving tray, 0.66 x 0.46, with a raised rim. Its top is at 0.04.
static func _tray_board(n: Node3D) -> void:
	Build._add(n, Build.bevel_mesh(Vector3(0.66, 0.03, 0.46), 0.012), Vector3(0, 0.0, 0), Color("#c98f58"), 0.0, Build.R_WOOD)
	for side: Array in [[Vector3(0, 0.03, 0.22), Vector3(0.66, 0.04, 0.03)], [Vector3(0, 0.03, -0.22), Vector3(0.66, 0.04, 0.03)],
			[Vector3(0.32, 0.03, 0), Vector3(0.03, 0.04, 0.46)], [Vector3(-0.32, 0.03, 0), Vector3(0.03, 0.04, 0.46)]]:
		Build._add(n, Build.bevel_mesh(side[1], 0.01), side[0], Color(Build.WOOD), 0.0, Build.R_WOOD)


## One ingredient as it is carried or sits on a counter: raw, prepped or burnt.
## `look` is the grill look for meat and fish.
static func ingredient(n: Node3D, id: String, state: String, look := "", y := 0.0) -> void:
	var info: Dictionary = Pantry.ITEMS[id]
	var col: String = info.colour if state == "raw" else (BURNT if state == "burnt" else info.prepped)
	match str(info.shape):
		"bun":
			Build._puck(n, y, 0.14, 0.05, col)
			Build.lathe(n, Vector3(0, y + 0.055, 0), [[0.0, 0.0], [0.135, 0.0], [0.145, 0.03], [0.125, 0.075], [0.07, 0.1], [0.0, 0.106]], col, 0.0, Build.R_GLOSS)
		"patty":
			patty(n, look if look != "" else ("raw" if state == "raw" else ("burnt" if state == "burnt" else "perfect")), y)
		"roll":
			_roll(n, y, col)
		"fillet":
			fillet(n, look if look != "" else ("raw" if state == "raw" else ("burnt" if state == "burnt" else "perfect")), y)
		"squid":
			if state == "raw":
				# A pale squid lying on its side: a tapering tube with two fins at the tip
				# and a short fan of tentacles at the head end.
				var body := Build.lathe(n, Vector3(-0.1, y + 0.06, 0), [[0.0, 0.0], [0.055, 0.0], [0.062, 0.1], [0.045, 0.18], [0.0, 0.22]], col, 0.0, Build.R_GLOSS)
				body.rotation.z = -PI / 2
				for sz: float in [-1.0, 1.0]:
					Build.ball(n, Vector3(0.08, y + 0.06, sz * 0.045), 0.045, col, 0.0, Build.R_GLOSS).scale = Vector3(1.0, 0.25, 0.9)
				for k in 4:
					var t := Build.box(n, Vector3(-0.15, y + 0.03, -0.045 + k * 0.03), Vector3(0.12, 0.018, 0.018), "#e9b6ae", 0.0, Build.R_GLOSS)
					t.rotation.y = -0.45 + k * 0.3
				for sp: Vector3 in [Vector3(-0.02, 0.115, 0.02), Vector3(0.04, 0.11, -0.02)]:
					Build.ball(n, Vector3(sp.x, y + sp.y, sp.z), 0.014, "#c98a9a")
			else:
				for k in 3:  # battered rings in a little heap, the third leaning on the others
					var a := TAU * k / 3.0
					_ring(n, Vector3(cos(a) * 0.06, y + (0.02 if k == 2 else 0.0), sin(a) * 0.06), col).rotation.z = 0.35 if k == 2 else 0.0
		"lemon":
			if state == "raw":
				Build.ball(n, Vector3(0, y + 0.08, 0), 0.08, col, 0.0, Build.R_GLOSS).scale = Vector3(1.35, 1.0, 1.0)
				for sx: float in [-1.0, 1.0]:
					Build.ball(n, Vector3(sx * 0.105, y + 0.08, 0), 0.025, col, 0.0, Build.R_GLOSS).scale = Vector3(1.2, 0.8, 0.8)
				Build.box(n, Vector3(0.0, y + 0.155, 0.0), Vector3(0.07, 0.012, 0.035), Build.LEAF).rotation.y = 0.5
			else:
				for k in 3:
					_wheel(n, Vector3(-0.07 + k * 0.07, y + k * 0.006, 0.02 * (k % 2)), col, "#fbf3c4")
		"courgette":
			if state == "raw":
				var c := Build.cyl(n, Vector3(0.15, y + 0.05, 0), 0.05, 0.3, col, 0.0, Build.R_GLOSS)
				c.rotation.z = PI / 2
				for dz: float in [-0.02, 0.02]:
					Build.box(n, Vector3(0, y + 0.092, dz), Vector3(0.26, 0.008, 0.008), "#6fa85a")
				Build.cyl(n, Vector3(0.19, y + 0.05, 0), 0.018, 0.05, "#a8b86a").rotation.z = PI / 2
			else:
				for k in 4:
					_wheel(n, Vector3(-0.09 + k * 0.06, y + (k % 2) * 0.008, 0.02 * (k % 2)), "#3f7f34", col, 0.05)
		"pepper":
			if state == "raw":
				for k in 4:  # four lobes and a green stalk
					var a := TAU * k / 4.0 + PI / 4
					Build.ball(n, Vector3(cos(a) * 0.04, y + 0.085, sin(a) * 0.04), 0.07, col, 0.0, Build.R_GLOSS).scale = Vector3(1, 1.2, 1)
				Build.cyl(n, Vector3(0, y + 0.16, 0), 0.03, 0.03, "#4f8f3a")
				Build.cyl(n, Vector3(0, y + 0.18, 0), 0.012, 0.05, "#4f8f3a")
			else:
				for k in 6:  # strips
					Build.box(n, Vector3(-0.06 + (k % 3) * 0.06, y + (k / 3) * 0.022, -0.03 + (k / 3) * 0.05), Vector3(0.17, 0.022, 0.032), col, 0.0, Build.R_GLOSS).rotation.y = 0.9 + (k % 3) * 0.35
		"beans":
			if state == "raw":
				for k in 7:  # a bundle tied with string
					Build.box(n, Vector3(0, y + (k / 4) * 0.026, -0.05 + (k % 4) * 0.032 + (k / 4) * 0.016), Vector3(0.26, 0.024, 0.024), col, 0.0, Build.R_GLOSS).rotation.y = 0.04 * (k % 3 - 1)
				Build.box(n, Vector3(0, y - 0.004, 0), Vector3(0.03, 0.06, 0.15), "#d9a441")
			else:
				for k in 8:
					Build.box(n, Vector3(-0.04 + (k % 3) * 0.04, y + (k / 3) * 0.02, -0.03 + (k % 4) * 0.02), Vector3(0.22, 0.022, 0.022), col, 0.0, Build.R_GLOSS).rotation.y = -0.6 + k * 0.45
		"leaf":
			if state == "raw":
				Build.ball(n, Vector3(0, y + 0.12, 0), 0.13, col).scale = Vector3(1, 0.9, 1)
				Build.ball(n, Vector3(0.05, y + 0.18, 0.04), 0.08, BuildStations._tint(col, 0.15))
			else:
				for k in 5:
					var a := TAU * k / 5.0
					Build.ball(n, Vector3(cos(a) * 0.06, y + 0.02, sin(a) * 0.06), 0.07, col, 0.0, Build.R_GLOSS).scale = Vector3(1, 0.3, 1)
		"round":
			if state == "raw":
				Build.ball(n, Vector3(0, y + 0.1, 0), 0.1, col, 0.0, Build.R_GLOSS)
				Build.box(n, Vector3(0, y + 0.2, 0), Vector3(0.05, 0.02, 0.02), Build.LEAF)
			else:
				for k in 3:
					Build._puck(n, y + k * 0.004, 0.06, 0.018, col).position.x = -0.07 + k * 0.07
		"ring":
			if state == "raw":
				Build.ball(n, Vector3(0, y + 0.1, 0), 0.1, col).scale = Vector3(1, 1.05, 1)
			else:
				for k in 3:
					var r := Build.lathe(n, Vector3(-0.06 + k * 0.06, y + 0.01 + k * 0.006, 0), [[0.035, 0.0], [0.06, 0.0], [0.06, 0.02], [0.035, 0.02], [0.035, 0.0]], col, 0.0, Build.R_GLOSS)
					r.rotation.z = 0.1 * k
		"slab":
			if state == "raw":
				Build.box(n, Vector3(0, y, 0), Vector3(0.24, 0.14, 0.16), col, 0.0, Build.R_GLOSS)
			else:
				Build.box(n, Vector3(0, y, 0), Vector3(0.22, 0.02, 0.22), col, 0.0, Build.R_GLOSS).rotation.y = PI / 4
		"spud":
			if state == "raw":   # a lumpy, matte brown spud: three merged balls and a few dark eyes
				for b: Array in [[Vector3(-0.045, 0.075, 0.0), 0.085, Vector3(1.1, 0.85, 1.0)], [Vector3(0.05, 0.07, 0.015), 0.08, Vector3(1.0, 0.85, 0.95)], [Vector3(0.0, 0.085, -0.04), 0.065, Vector3.ONE]]:
					Build.ball(n, Vector3(b[0].x, y + b[0].y, b[0].z), b[1], col, 0.0, Build.R_MATTE).scale = b[2]
				for e: Vector3 in [Vector3(-0.07, 0.115, 0.055), Vector3(0.06, 0.105, 0.06), Vector3(0.0, 0.15, 0.0)]:
					Build.ball(n, Vector3(e.x, y + e.y, e.z), 0.014, "#5e3d20")
			else:   # a heap of pale cut sticks lying on the board, no carton
				for k in 8:
					Build.box(n, Vector3(-0.07 + (k % 4) * 0.045, y + 0.015 + (k / 4) * 0.03, -0.03 + (k % 3) * 0.03), Vector3(0.16, 0.028, 0.028), col, 0.0, Build.R_GLOSS).rotation.y = 0.3 + k * 0.55
		"sticks":
			if state == "raw":   # pale sticks, as in the basket
				for k in 6:
					Build.box(n, Vector3(-0.06 + (k % 3) * 0.06, y + 0.015 + (k / 3) * 0.03, -0.03 + (k % 2) * 0.04), Vector3(0.17, 0.026, 0.026), col, 0.0, Build.R_GLOSS).rotation.y = 0.3 + k * 0.5
			else:
				Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.05, 0.0], [0.09, 0.14], [0.0, 0.14]], 12), Vector3(0, y, 0), Color(Build.CORAL), 0.0)
				for k in 6:
					Build.box(n, Vector3(-0.05 + (k % 3) * 0.05, y + 0.15, -0.02 + (k / 3) * 0.04), Vector3(0.025, 0.12, 0.025), col, 0.0, Build.R_GLOSS).rotation.z = 0.2 * (k % 3 - 1)
		"cob":
			Build.cyl(n, Vector3(0, y + 0.05, 0), 0.05, 0.24, col, 0.0, Build.R_GLOSS).rotation.z = PI / 2
			if state == "prep" and id == "steamed_corn":   # a melting pat of butter
				Build.box(n, Vector3(0.02, y + 0.105, 0), Vector3(0.07, 0.025, 0.05), "#fff3b0", 0.0, Build.R_GLOSS).rotation.y = 0.4
			if state == "raw":
				for sx: float in [-1.0, 1.0]:
					Build.ball(n, Vector3(0.0, y + 0.06, sx * 0.04), 0.06, Build.LEAF).scale = Vector3(2.0, 0.6, 0.6)
		"pebbles":
			for k in 4:
				Build.ball(n, Vector3(-0.06 + (k % 2) * 0.1, y + 0.045, -0.04 + (k / 2) * 0.08), 0.05, col, 0.0, Build.R_MATTE if state == "raw" else Build.R_GLOSS).scale = Vector3(1.15, 0.9, 1)
			if state != "raw":
				for f: Vector3 in [Vector3(-0.05, 0.095, -0.03), Vector3(0.05, 0.095, 0.05), Vector3(0.0, 0.09, 0.0), Vector3(0.04, 0.094, -0.04)]:
					Build.box(n, Vector3(f.x, y + f.y, f.z), Vector3(0.022, 0.008, 0.016), Build.LEAF).rotation.y = f.x * 30.0
		# PRD 8.6. Each reads by shape at 20 px: a holed block and a fluffy heap, a slashed
		# loaf and a slice, a scoop in a tub, crumbs, shells, and four drinks' vessels.
		"shreds":
			if state == "raw":   # a block of cheese with holes
				Build.box(n, Vector3(0, y, 0), Vector3(0.22, 0.13, 0.15), col, 0.0, Build.R_GLOSS)
				for h: Vector3 in [Vector3(-0.05, 0.08, 0.076), Vector3(0.05, 0.05, 0.076), Vector3(0.112, 0.08, 0.02)]:
					Build.ball(n, Vector3(h.x, y + h.y, h.z), 0.022, "#d9a62a")
			else:
				Build.lathe(n, Vector3(0, y, 0), [[0.0, 0.0], [0.12, 0.0], [0.08, 0.05], [0.0, 0.07]], BuildStations._shade(col, 0.08))
				for k in 12:   # a fluffy heap of strands
					var a := TAU * k / 7.0
					var r := 0.02 + 0.06 * float(k % 3) / 2.0
					var strand := Build.box(n, Vector3(cos(a) * r, y + 0.015 + (2 - k % 3) * 0.02, sin(a) * r), Vector3(0.11, 0.016, 0.016), col, 0.0, Build.R_GLOSS)
					strand.rotation = Vector3(0.3 * (k % 2), a * 1.7, 0.25 * (k % 3 - 1))
		"loaf":
			if state == "raw":   # a whole loaf, slashed on top
				Build.ball(n, Vector3(0, y + 0.08, 0), 0.12, col, 0.0, Build.R_GLOSS).scale = Vector3(1.5, 0.75, 1.0)
				for k in 3:
					Build.box(n, Vector3(-0.08 + k * 0.08, y + 0.165, 0), Vector3(0.025, 0.012, 0.14), BuildStations._tint(col, 0.3)).rotation.y = 0.5
			else:   # two thick slices leaning together, crust round the crumb
				for k in 2:
					var sl := Node3D.new()
					sl.position = Vector3(-0.04 + k * 0.08, y + 0.1, 0)
					sl.rotation.z = 0.25 if k == 0 else -0.25
					n.add_child(sl)
					Build.box(sl, Vector3.ZERO, Vector3(0.04, 0.2, 0.22), str(info.colour), 0.0, Build.R_GLOSS)
					Build.box(sl, Vector3(0, 0.005, 0), Vector3(0.046, 0.17, 0.18), col)
		"scoop":
			Build.lathe(n, Vector3(0, y, 0), [[0.0, 0.0], [0.07, 0.0], [0.09, 0.09], [0.0, 0.09]], Build.PAPER)
			Build.box(n, Vector3(0, y + 0.045, 0), Vector3(0.185, 0.03, 0.03), "#f4b3c4").rotation.y = 0.5
			Build.ball(n, Vector3(0, y + 0.13, 0), 0.075, col, 0.0, Build.R_GLOSS)
			Build.ball(n, Vector3(0.0, y + 0.21, 0.0), 0.022, "#c8283a", 0.0, Build.R_GLOSS)
		"crumbs":
			if state == "raw":   # a stale heel of bread
				var heel := Build.ball(n, Vector3(0, y + 0.03, 0), 0.11, col)
				heel.scale = Vector3(1.0, 0.6, 1.0)
				Build.box(n, Vector3(0, y + 0.0, 0), Vector3(0.2, 0.04, 0.2), "#e8c48a")
			else:   # a little heap of golden crumbs
				Build.lathe(n, Vector3(0, y, 0), [[0.0, 0.0], [0.13, 0.0], [0.07, 0.06], [0.0, 0.08]], col)
				for k in 6:
					var a := TAU * k / 6.0
					Build.box(n, Vector3(cos(a) * 0.12, y + 0.01, sin(a) * 0.12), Vector3(0.025, 0.02, 0.025), BuildStations._shade(col, 0.15)).rotation.y = a
		"mussels":
			for k in 4:   # closed blue-black shells, or opened on orange meat
				var a := TAU * k / 4.0 + 0.4
				var sh := Node3D.new()
				sh.position = Vector3(cos(a) * 0.065, y + 0.03 + (0.02 if k == 3 else 0.0), sin(a) * 0.065)
				sh.rotation.y = a
				n.add_child(sh)
				if state == "raw":
					Build.ball(sh, Vector3.ZERO, 0.055, col, 0.0, Build.R_GLOSS).scale = Vector3(1.4, 0.55, 0.8)
				else:
					for side: float in [-1.0, 1.0]:
						var half := Build.ball(sh, Vector3(0, 0.0, side * 0.03), 0.05, "#2f3a52", 0.0, Build.R_GLOSS)
						half.scale = Vector3(1.4, 0.3, 0.7)
						half.rotation.x = side * 0.6
					Build.ball(sh, Vector3(0, 0.015, 0), 0.032, col, 0.0, Build.R_GLOSS).scale = Vector3(1.3, 0.7, 0.9)
		"juice":
			if state == "raw":   # oranges (lemonade starts as a lemon, drawn as one)
				Build.ball(n, Vector3(0, y + 0.08, 0), 0.08, col, 0.0, Build.R_GLOSS)
				Build.box(n, Vector3(0.0, y + 0.16, 0.0), Vector3(0.06, 0.012, 0.03), Build.LEAF).rotation.y = 0.5
			else:   # juice in a tumbler (a pale base and rim), a wheel of fruit on the rim
				Build.cyl(n, Vector3(0, y, 0), 0.064, 0.025, "#dff0f2", 0.0, Build.R_GLOSS)
				Build.cyl(n, Vector3(0, y + 0.02, 0), 0.06, 0.16, col, 0.0, Build.R_GLOSS)
				Build.lathe(n, Vector3(0, y + 0.17, 0), [[0.055, 0.0], [0.068, 0.0], [0.068, 0.03], [0.055, 0.03]], "#dff0f2", 0.0, Build.R_GLOSS)
				var wheel := Build.cyl(n, Vector3(0.05, y + 0.2, 0), 0.04, 0.012, "#f28a1e" if id == "orange_juice" else "#f5d936")
				wheel.rotation.x = PI / 2
				Build.cyl(n, Vector3(0.05, y + 0.2, 0.0), 0.03, 0.014, "#fbe3b0").rotation.x = PI / 2
		"shake":
			if state == "raw":   # berries
				for k in 4:
					var a := TAU * k / 4.0
					Build.ball(n, Vector3(cos(a) * 0.05, y + 0.05 + (0.04 if k == 0 else 0.0), sin(a) * 0.05), 0.05, col, 0.0, Build.R_GLOSS)
				Build.box(n, Vector3(0.0, y + 0.13, 0.0), Vector3(0.05, 0.012, 0.025), Build.LEAF)
			else:   # a fluted glass, cream on top, a cherry and a straw
				Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.05, 0.0], [0.03, 0.04], [0.045, 0.08], [0.075, 0.2], [0.0, 0.2]], 16), Vector3(0, y, 0), Color(col), 0.0, Build.R_GLOSS)
				Build.ball(n, Vector3(0, y + 0.21, 0), 0.065, Build.PAPER, 0.0, Build.R_GLOSS).scale = Vector3(1, 0.7, 1)
				Build.ball(n, Vector3(0, y + 0.27, 0), 0.022, "#c8283a", 0.0, Build.R_GLOSS)
				Build.box(n, Vector3(0.035, y + 0.28, 0), Vector3(0.014, 0.16, 0.014), Build.CORAL).rotation.z = 0.3
		"mug":
			Build.cyl(n, Vector3(0, y, 0), 0.07, 0.15, Build.PAPER, 0.0, Build.R_GLOSS)
			Build.cyl(n, Vector3(0, y + 0.146, 0), 0.06, 0.008, col)
			var handle := _ring(n, Vector3(0.078, y + 0.075, 0), Build.PAPER)
			handle.rotation.x = PI / 2
			handle.scale = Vector3.ONE * 0.75
			for k in 2:   # steam
				Build.ball(n, Vector3(-0.02 + k * 0.04, y + 0.2 + k * 0.04, 0), 0.022, "#ffffff").scale = Vector3(1, 1.4, 1)
		"pint":
			Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.05, 0.0], [0.065, 0.2], [0.0, 0.2]], 16), Vector3(0, y, 0), Color(col), 0.0, Build.R_GLOSS)
			Build.cyl(n, Vector3(0, y + 0.2, 0), 0.066, 0.045, Build.PAPER, 0.0, Build.R_GLOSS)
			Build.ball(n, Vector3(0.0, y + 0.245, 0.0), 0.05, Build.PAPER).scale = Vector3(1.2, 0.5, 1.2)
		"cup":
			Build.cyl(n, Vector3(0, y, 0), 0.07, 0.2, Build.CORAL)
			Build.cyl(n, Vector3(0, y + 0.19, 0), 0.06, 0.012, col)
			Build.box(n, Vector3(0.02, y + 0.26, 0), Vector3(0.014, 0.16, 0.014), Build.PAPER).rotation.z = 0.25
		"glass":
			Build.cyl(n, Vector3(0, y, 0), 0.05, 0.01, "#dfeef0", 0.0, Build.R_GLOSS)
			Build.cyl(n, Vector3(0, y, 0), 0.012, 0.12, "#dfeef0", 0.0, Build.R_GLOSS)
			Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.035, 0.0], [0.065, 0.06], [0.07, 0.13], [0.0, 0.13]], 16), Vector3(0, y + 0.12, 0), Color(col), 0.0, Build.R_GLOSS)


## How tall a stacked layer of this ingredient is on a plate. `coat`: the stack is
## breaded (fish and breadcrumbs, PRD 8.6): a fillet wears a crumb crust and the crumbs
## themselves draw nothing.
static func _layer(n: Node3D, id: String, y: float, first: bool, last: bool, coat := false) -> float:
	var info: Dictionary = Pantry.ITEMS[id]
	var col: String = info.prepped
	match str(info.shape):
		"shreds":
			for k in 9:
				var a := TAU * k / 9.0
				Build.box(n, Vector3(cos(a) * 0.06, y + 0.01 + (k % 2) * 0.008, sin(a) * 0.06), Vector3(0.12, 0.014, 0.014), col, 0.0, Build.R_GLOSS).rotation.y = a * 1.3
			return 0.025
		"loaf":
			Build.box(n, Vector3(0, y, 0), Vector3(0.26, 0.045, 0.22), str(info.colour), 0.0, Build.R_GLOSS)
			Build.box(n, Vector3(0, y + 0.004, 0), Vector3(0.22, 0.046, 0.18), col)
			return 0.045
		"crumbs":
			if coat:
				return 0.0
			Build.lathe(n, Vector3(0, y, 0), [[0.0, 0.0], [0.12, 0.0], [0.06, 0.04], [0.0, 0.05]], col)
			return 0.04
		"scoop":
			for k in 2:
				Build.ball(n, Vector3(-0.05 + k * 0.1, y + 0.06, 0), 0.07, str(info.colour), 0.0, Build.R_GLOSS)
			return 0.1
		"mussels":
			for k in 5:
				var a := TAU * k / 5.0
				var sh := Node3D.new()
				sh.position = Vector3(cos(a) * 0.08, y + 0.03, sin(a) * 0.08)
				sh.rotation.y = a
				n.add_child(sh)
				for side: float in [-1.0, 1.0]:
					var half := Build.ball(sh, Vector3(0, 0, side * 0.03), 0.05, "#2f3a52", 0.0, Build.R_GLOSS)
					half.scale = Vector3(1.4, 0.3, 0.7)
					half.rotation.x = side * 0.6
				Build.ball(sh, Vector3(0, 0.015, 0), 0.032, col, 0.0, Build.R_GLOSS).scale = Vector3(1.3, 0.7, 0.9)
			return 0.07
		"bun":
			if first and not last:
				Build._puck(n, y, 0.13, 0.045, col)
				return 0.045
			Build.lathe(n, Vector3(0, y, 0), [[0.0, 0.0], [0.125, 0.0], [0.135, 0.028], [0.115, 0.07], [0.065, 0.095], [0.0, 0.1]], col, 0.0, Build.R_GLOSS)
			return 0.1
		"patty":
			patty(n, "perfect", y)
			return 0.07
		"roll":
			if first and not last:
				Build._puck(n, y, 0.12, 0.04, col).scale = Vector3(1.2, 1, 0.9)
				return 0.04
			var top := Build.lathe(n, Vector3(0, y, 0), [[0.0, 0.0], [0.115, 0.0], [0.125, 0.025], [0.105, 0.06], [0.06, 0.08], [0.0, 0.085]], col, 0.0, Build.R_GLOSS)
			top.scale = Vector3(1.2, 1, 0.9)
			Build.box(n, Vector3(0, y + 0.074, 0), Vector3(0.16, 0.014, 0.022), BuildStations._shade(col, 0.22))
			return 0.085
		"fillet":
			var f := Node3D.new()
			f.position = Vector3(0, y, 0)
			f.rotation.y = 0.35
			n.add_child(f)
			f.rotation.y = 0.6
			Build._add(f, Build.bevel_mesh(Vector3(0.34, 0.05, 0.15), 0.02), Vector3(0, 0.025, 0), Color(col), 0.0, Build.R_GLOSS)
			if coat:   # a breaded fillet: a thick golden crumb crust, knobbly on top
				Build._add(f, Build.bevel_mesh(Vector3(0.36, 0.07, 0.17), 0.03), Vector3(0, 0.03, 0), Color("#e2a94e"), 0.0, Build.R_MATTE)
				for k in 6:
					Build.box(f, Vector3(-0.13 + k * 0.05, 0.07, 0.03 * (k % 2 * 2 - 1)), Vector3(0.03, 0.02, 0.03), "#c98a3a").rotation.y = k
				return 0.08
			Build._add(f, Build.bevel_mesh(Vector3(0.32, 0.022, 0.13), 0.01), Vector3(0, 0.056, 0), Color(FISH_CRUST), 0.0, Build.R_GLOSS)
			return 0.07
		"squid":
			for k in 4:
				var a := TAU * k / 4.0 + 0.3
				_ring(n, Vector3(cos(a) * 0.06, y + 0.004 * k, sin(a) * 0.06), col)
			return 0.035
		"lemon":
			for k in 2:
				_wheel(n, Vector3(-0.035 + k * 0.07, y + k * 0.006, 0.0), "#f5d936", col)
			return 0.024
		"courgette":
			for k in 5:
				var a := TAU * k / 5.0
				_wheel(n, Vector3(cos(a) * 0.065, y + 0.004 * (k % 2), sin(a) * 0.065), "#3f7f34", col, 0.05)
			return 0.024
		"pepper":
			for k in 5:
				Build.box(n, Vector3(-0.06 + k * 0.03, y + (k % 2) * 0.012, 0.0), Vector3(0.18, 0.02, 0.03), col, 0.0, Build.R_GLOSS).rotation.y = 0.4 + k * 0.6
			return 0.03
		"beans":
			for k in 8:
				Build.box(n, Vector3(-0.04 + (k % 3) * 0.04, y + (k / 3) * 0.018, -0.03 + (k % 4) * 0.02), Vector3(0.2, 0.022, 0.022), col, 0.0, Build.R_GLOSS).rotation.y = -0.6 + k * 0.45
			return 0.05
		"leaf":
			Build.lathe(n, Vector3(0, y, 0), [[0.0, 0.0], [0.15, 0.0], [0.16, 0.01], [0.15, 0.022], [0.0, 0.022]], col, 0.0, Build.R_GLOSS)
			return 0.022
		"round":
			Build._puck(n, y, 0.12, 0.022, col)
			return 0.022
		"ring":
			Build.lathe(n, Vector3(0, y, 0), [[0.06, 0.0], [0.12, 0.0], [0.12, 0.02], [0.06, 0.02], [0.06, 0.0]], col, 0.0, Build.R_GLOSS)
			return 0.02
		"slab":
			Build.box(n, Vector3(0, y, 0), Vector3(0.22, 0.02, 0.22), col, 0.0, Build.R_GLOSS).rotation.y = PI / 4
			return 0.02
		"cob":
			Build.cyl(n, Vector3(0, y + 0.045, 0), 0.045, 0.22, col, 0.0, Build.R_GLOSS).rotation.z = PI / 2
			return 0.09
		"sticks":
			for k in 7:
				Build.box(n, Vector3(-0.08 + (k % 4) * 0.05, y + 0.015 + (k / 4) * 0.025, -0.03 + (k % 3) * 0.03), Vector3(0.12, 0.025, 0.025), col, 0.0, Build.R_GLOSS).rotation.y = k * 0.7
			return 0.05
		"spud":
			for k in 7:
				Build.box(n, Vector3(-0.08 + (k % 4) * 0.05, y + 0.015 + (k / 4) * 0.025, -0.03 + (k % 3) * 0.03), Vector3(0.12, 0.025, 0.025), col, 0.0, Build.R_GLOSS).rotation.y = k * 0.7
			return 0.05
		"pebbles":
			for k in 4:
				Build.ball(n, Vector3(-0.05 + (k % 2) * 0.1, y + 0.04, -0.04 + (k / 2) * 0.08), 0.045, col)
			return 0.06
	Build._puck(n, y, 0.1, 0.03, col)
	return 0.03


## Tonight's menu, for drawing a loose stack in the order of the item it is heading for.
## The game keeps it current.
static var menu: Array = []


static func menu_items() -> Array:
	return menu


## An empty plate as served on: white, a low rim. Its top is at 0.015.
static func _serving_plate(n: Node3D, pos := Vector3.ZERO) -> void:
	Build.lathe(n, pos, [[0.0, 0.0], [0.11, 0.0], [0.18, 0.025], [0.185, 0.035], [0.165, 0.035], [0.11, 0.015], [0.0, 0.015]], "#f6efe0", 0.0, Build.R_GLOSS)


## An empty cup: a pale tumbler, wider at the top.
static func _empty_cup(n: Node3D, pos := Vector3.ZERO) -> void:
	Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.05, 0.0], [0.065, 0.17], [0.058, 0.17], [0.045, 0.012], [0.0, 0.012]], 16), pos, Color("#dfeef0"), 0.0, Build.R_GLOSS)
	Build.cyl(n, pos + Vector3(0, 0.165, 0), 0.066, 0.01, Build.CORAL)


## Food stacked in the order `ids` lists it, skipping any whose `have` is below 0. One
## bread in a stack of several wraps it: a heel below, the dome on top. `bitten`: half eaten.
static func _food(spot: Node3D, ids: Array, have: Array, y: float, bitten := false) -> void:
	var placed := 0
	for k in ids.size():
		if float(have[k]) >= 0.0:
			placed += 1
	var wrap: bool = ids.size() > 1 and Pantry.is_bread(ids[0]) and ids.count(ids[0]) == 1 and float(have[0]) >= 0.0
	var shown := 0
	var coat := _breaded(ids, have)
	for k in ids.size():
		if float(have[k]) < 0.0:
			continue
		shown += 1
		if bitten and shown > maxi(1, placed / 2):
			break
		y += _layer(spot, ids[k], y, k == 0, k == ids.size() - 1 and not wrap, coat)
	if wrap and not bitten:
		_layer(spot, ids[0], y, false, true)


## A plate, a cup, or a loose stack of food on a worktop, as it is now.
static func dish(d: Dish, items: Array = []) -> Node3D:
	var n := Node3D.new()
	if d == null:
		return n
	if items.is_empty():
		items = menu
	if d.dirty:
		return item("dirty_cup" if d.vessel == Dish.CUP else "dirty_plate")
	var lay := d.layout(items)
	if d.vessel == Dish.CUP:
		if d.is_empty():
			_empty_cup(n)
		else:
			ingredient(n, str(lay[0][0]) if not (lay[0] as Array).is_empty() else d.ings[0], "prep")
		return n
	var y := 0.0
	if d.vessel == Dish.PLATE:
		_serving_plate(n)
		y = 0.015
	if d.ings.size() == 1 and d.vessel == "":
		ingredient(n, d.ings[0], "prep")
		return n
	_food(n, lay[0], lay[1], y)
	return n


## Several dishes carried: side by side in the hands, or on a tray (`on_tray`) two by two.
static func carried(dishes: Array, on_tray: bool) -> Node3D:
	var n := Node3D.new()
	if on_tray:
		_tray_board(n)
	var spots := [Vector3(-0.15, 0.0, 0.0), Vector3(0.15, 0.0, 0.0), Vector3(-0.15, 0.0, -0.18), Vector3(0.15, 0.0, -0.18)] \
		if on_tray else [Vector3(-0.2, 0.0, 0.0), Vector3(0.2, 0.0, 0.0)]
	for i in dishes.size():
		var d := dish(dishes[i])
		d.position = spots[mini(i, spots.size() - 1)] + Vector3(0, 0.035 if on_tray else 0.0, 0.1 if on_tray else 0.0)
		d.scale = Vector3.ONE * (0.72 if on_tray else 0.85)
		n.add_child(d)
	return n


## A guest's order as served, on the table: the main on its plate, the side on a small
## plate, the drink beside them. Only the lines served so far. `bitten`: half eaten.
static func meal(t: Tray, bitten := false) -> Node3D:
	var n := Node3D.new()
	if t == null:
		return n
	for l in t.lines:
		var placed := false
		for q: float in l.have:
			placed = placed or q >= 0.0
		if not placed:
			continue
		var spot := Node3D.new()
		n.add_child(spot)
		var course: String = l.item.course
		var y := 0.015
		if course == "main":
			spot.position = Vector3(-0.1, 0, 0)
			_serving_plate(spot)
		elif course == "side":
			spot.position = Vector3(0.18, 0, 0.11)
			spot.scale = Vector3.ONE * 0.7
			_serving_plate(spot)
		else:
			spot.position = Vector3(0.2, 0.0, -0.11)
			ingredient(spot, l.item.ingredients[0], "prep")
			continue
		_food(spot, l.item.ingredients, l.have, y, bitten and course == "main")
	return n


## A whole order on a tray board, for the menu screen's turning picture.
static func tray(t: Tray, tag := "", bitten := false) -> Node3D:
	var n := Node3D.new()
	_tray_board(n)
	var m := meal(t, bitten)
	m.position.y = 0.03
	n.add_child(m)
	return n


## A stack of clean cups or trays on its counter.
static func stack_load(n: Node3D, type: String, count: int) -> void:
	for i in count:
		var t: Node3D
		match type:
			"cups":   # two rows of upturned cups
				t = Node3D.new()
				_empty_cup(t)
				t.rotation.x = PI
				t.position = Vector3(-0.2 + (i % 3) * 0.2, 0.916 + 0.18 + (i / 3) * 0.0, -0.12 + (i / 3) * 0.24)
			_:
				t = item("tray")
				t.position = Vector3(0, 0.916 + i * 0.04, 0)
		n.add_child(t)


## Whether a stack is breaded: a fillet and a coating (breadcrumbs) both on it.
static func _breaded(ings: Array, have: Array) -> bool:
	var fillet := false
	var crumbs := false
	for k in ings.size():
		if float(have[k]) < 0.0:
			continue
		fillet = fillet or str(Pantry.ITEMS[ings[k]].shape) == "fillet"
		crumbs = crumbs or Pantry.ITEMS[ings[k]].get("coat", false)
	return fillet and crumbs


## Anything that can be carried or put down. `look` overrides the grill look
## (a stove knows more about what is on it than the item kind says).
static func item(kind: String, quality := 1.0, look := "") -> Node3D:
	var n := Node3D.new()
	if look == "":
		look = look_for(kind, quality)
	var p := Tray.parse(kind)
	if not p.is_empty():
		ingredient(n, p.id, p.state, look)
		return n
	match kind:
		"tray":
			_tray_board(n)
		"plate":
			_serving_plate(n)
		"cup":
			_empty_cup(n)
		"dirty_plate":
			# A smeared plate with crumbs and a gravy ring.
			_serving_plate(n)
			Build.lathe(n, Vector3(0.01, 0.02, 0.0), [[0.05, 0.0], [0.07, 0.008], [0.09, 0.0]], "#7a4a2b", 0.0, Build.R_GLOSS)
			Build.ball(n, Vector3(-0.03, 0.02, 0.02), 0.022, "#7a4a2b", 0.0, Build.R_GLOSS)
			for c: Vector3 in [Vector3(0.08, 0.025, 0.06), Vector3(-0.08, 0.025, -0.06), Vector3(0.05, 0.025, -0.08)]:
				Build.box(n, c, Vector3(0.035, 0.02, 0.03), "#e0a850").rotation.y = c.x * 20.0
		"dirty_cup":
			_empty_cup(n)
			Build.cyl(n, Vector3(0, 0.012, 0), 0.046, 0.025, "#8a5a3a")   # a last drop in the bottom
			Build.box(n, Vector3(0.02, 0.2, 0), Vector3(0.014, 0.14, 0.014), Build.PAPER).rotation.z = 0.35
		"tool:mop", "tool:sponge_mop", "tool:flat_mop", "tool:wringer_mop", "tool:scrubber", "tool:cleaner_mop", "tool:strong_mop":
			# Held out at the side, head on the floor, the pole leaning out (PRD 9.4). Held
			# items are tipped 25 degrees to the camera (Player.move); a pole stands back
			# up so it reads at full length, leaning out a little. The scrubber is pushed.
			var m := BuildClean.mop(n, quality, kind.trim_prefix("tool:"))
			m.basis = Basis(Vector3(1, 0, -1).normalized(), deg_to_rad(-25.0)) * Basis(Vector3(0, 0, 1), -0.2)
			m.position = Vector3(0.45, -0.55, 0.1)
			if kind == "tool:scrubber":
				m.position = Vector3(0.5, -0.55, 0.35)
		"tool:sponge", "tool:scourer", "tool:grease_scraper", "tool:spill_kit":
			BuildClean.hand_tool(n, kind.trim_prefix("tool:"), quality).scale = Vector3.ONE * BuildClean.HAND_TOOL_SIZE / SIZE   # drawn at SIZE by its holder
		"bill":  # a printed bill (PRD 11): a paper slip held up, inked lines, a coral total
			var slip := Node3D.new()
			slip.rotation.x = -1.0   # tipped up to the camera, so it reads as paper
			n.add_child(slip)
			Build._add(slip, Build.bevel_mesh(Vector3(0.26, 0.012, 0.36), 0.004), Vector3(0, 0.12, 0), Color(Build.PAPER), 0.0)
			for k in 4:
				Build.box(slip, Vector3(-0.02 + (k % 2) * 0.02, 0.128, -0.12 + k * 0.06), Vector3(0.16 - (k % 2) * 0.05, 0.004, 0.018), "#3a2c22")
			Build.box(slip, Vector3(0.05, 0.128, 0.13), Vector3(0.1, 0.005, 0.04), Build.CORAL)
		"rubbish_bag":  # a fat knotted sack, for carrying out the front
			Build.ball(n, Vector3(0, 0.17, 0), 0.19, Build.BAG).scale = Vector3(1, 0.95, 0.9)
			Build.ball(n, Vector3(0, 0.38, 0), 0.06, Build.BAG)
			for a: float in [-0.6, 0.6]:
				Build.ball(n, Vector3(sin(a) * 0.07, 0.45, 0), 0.04, Build.BAG).scale = Vector3(0.7, 1.4, 0.7)
	if kind.begins_with("tool:") and quality <= 0.001:   # worn out: a red wear pip, it works slower
		Build.ball(n, Vector3(0, 0.72, 0.12), 0.075, "#e0463a", 0.0, 0.5)
		Build.ball(n, Vector3(0, 0.72, 0.12), 0.045, "#ffffff", 0.0, 0.5).position.z = 0.17
	return n
