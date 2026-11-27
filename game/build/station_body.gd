class_name BuildStationBody
extends RefCounted
## The body of every station by type and tier (_station_body), kept in its own file for size.


static func _station_body(n: Node3D, type: String, tier: int, base := "", pass_look := false, node := "") -> void:
	if base == "double_counter":
		BuildStations._double(n, type == "counter", BuildStations.PASS_FRONT if pass_look else 0.0)
	if Treatments.is_box(type):
		BuildClean.treatment_box(n, Treatments.key_of(type))
		return
	var ing := Catalog.ingredient_of(type)
	if ing != "" and not type in ["coffee_machine", "beer_tap"]:
		BuildStations._ingredient_station(n, ing, Catalog.ITEMS[type].get("ready", false), Catalog.is_box(type))
		return
	match type:
		# PRD 8.6: the new jobs' tools, each with a silhouette of its own at 20 px.
		"grater":
			# A tall steel box grater with a handle, a heap of shreds at its foot.
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build._add(n, Build.bevel_mesh(Vector3(0.6, 0.04, 0.44), 0.02), Vector3(0, 0.9, 0), Color("#e2b178"), 0.0, Build.R_WOOD)
			var g := Build._add(n, Build.bevel_mesh(Vector3(0.24, 0.4, 0.2), 0.03), Vector3(-0.08, 0.92, -0.04), Color("#c9d0d1"), 0.0, Build.R_WOOD)
			g.scale = Vector3(1, 1, 1)
			for k in 4:
				for j in 2:
					Build.box(n, Vector3(-0.13 + j * 0.1, 1.0 + k * 0.07, 0.065), Vector3(0.05, 0.02, 0.015), Build.STEEL_DARK)
			Build.box(n, Vector3(-0.08, 1.36, -0.04), Vector3(0.2, 0.04, 0.05), Build.STEEL_DARK)
			for x: float in [-0.17, 0.01]:
				Build.box(n, Vector3(x, 1.3, -0.04), Vector3(0.03, 0.08, 0.03), Build.STEEL_DARK)
			Build.lathe(n, Vector3(0.2, 0.92, 0.12), [[0.0, 0.0], [0.11, 0.0], [0.05, 0.06], [0.0, 0.08]], "#f7d258")
		"bread_knife":
			# A long bread board with a loaf on it and a long serrated knife.
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build._add(n, Build.bevel_mesh(Vector3(0.76, 0.05, 0.42), 0.02), Vector3(0, 0.9, 0), Color("#a8703e"), 0.0, Build.R_WOOD)
			Build.ball(n, Vector3(-0.08, 1.0, -0.04), 0.13, "#c98a4a", 0.0, Build.R_GLOSS).scale = Vector3(1.5, 0.75, 1.0)
			for k in 3:
				Build.box(n, Vector3(-0.16 + k * 0.08, 1.09, -0.04), Vector3(0.025, 0.012, 0.15), "#ead2a4").rotation.y = 0.5
			Build.box(n, Vector3(0.14, 0.94, 0.15), Vector3(0.48, 0.01, 0.06), "#dfe6e7", 0.0, Build.R_WOOD).rotation.y = 0.15
			for k in 8:
				Build.box(n, Vector3(-0.06 + k * 0.05, 0.94, 0.12 + k * 0.0075), Vector3(0.02, 0.012, 0.02), "#b8c2c4").rotation.y = 0.8
			Build.box(n, Vector3(-0.2, 0.95, 0.2), Vector3(0.16, 0.035, 0.05), Build.WOOD_DARK).rotation.y = 0.15
		"juicer":
			# A citrus press: a coral base, a steel bowl and ribbed cone, the lever raised.
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build._add(n, Build.bevel_mesh(Vector3(0.44, 0.14, 0.44), 0.05), Vector3(0, 0.9, 0), Color(Build.CORAL), 0.0)
			Build.lathe(n, Vector3(0, 1.04, 0), [[0.0, 0.0], [0.12, 0.0], [0.2, 0.08], [0.18, 0.08], [0.11, 0.02], [0.0, 0.02]], "#c9d0d1", 0.0, Build.R_WOOD)
			Build.lathe(n, Vector3(0, 1.05, 0), [[0.0, 0.0], [0.08, 0.0], [0.0, 0.12]], "#eef3f4", 0.0, Build.R_GLOSS)
			Build.box(n, Vector3(0, 1.15, -0.2), Vector3(0.06, 0.32, 0.06), Build.STEEL_DARK)
			var lever := Build.box(n, Vector3(0, 1.36, -0.05), Vector3(0.08, 0.04, 0.4), Build.STEEL_DARK)
			lever.rotation.x = -0.5
			Build.ball(n, Vector3(0, 1.48, 0.12), 0.05, Build.CORAL)
			Build.ball(n, Vector3(0.24, 0.98, 0.22), 0.07, "#f28a1e", 0.0, Build.R_GLOSS)
		"blender":
			# A blender: a steel base with a dial and a tall glass jug, pink to the brim.
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build._add(n, Build.bevel_mesh(Vector3(0.3, 0.16, 0.3), 0.04), Vector3(0, 0.9, 0), Color(Build.STEEL_DARK), 0.0)
			Build.cyl(n, Vector3(0, 0.97, 0.155), 0.035, 0.02, Build.CORAL).rotation.x = PI / 2
			Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.1, 0.0], [0.15, 0.42], [0.0, 0.42]], 16), Vector3(0, 1.06, 0), Color("#dff0f2"), 0.0, Build.R_GLOSS)
			Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.092, 0.0], [0.125, 0.28], [0.0, 0.28]], 16), Vector3(0, 1.08, 0), Color("#f4b3c4"), 0.0, Build.R_GLOSS)
			Build.cyl(n, Vector3(0, 1.48, 0), 0.155, 0.04, "#2b2f31")
			Build.box(n, Vector3(0.17, 1.3, 0), Vector3(0.04, 0.2, 0.04), "#dff0f2", 0.0, Build.R_GLOSS)
		"steamer":
			# Two bamboo baskets stacked on a pot, a domed lid, steam on top.
			# Woven bands and upright slats so the baskets read as baskets, not a stack of
			# pancakes; a wide steel pot under them, and a tall puff of steam.
			BuildStations._counter(n, Build.STEEL, Build.STEEL_DARK, false)
			Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.3, 0.0], [0.32, 0.02], [0.32, 0.16], [0.0, 0.16]], 24), Vector3(0, 0.9, 0), Color("#c9d0d1"), 0.0, Build.R_WOOD)
			for x: float in [-0.36, 0.36]:
				Build.box(n, Vector3(x, 1.0, 0), Vector3(0.08, 0.04, 0.06), Build.STEEL_DARK)
			for k in 2:
				var y0 := 1.06 + k * 0.15
				Build.cyl(n, Vector3(0, y0, 0), 0.23, 0.14, "#d8cb9a", 0.0, Build.R_WOOD)
				for h: float in [0.015, 0.125]:
					Build.cyl(n, Vector3(0, y0 + h - 0.01, 0), 0.238, 0.022, "#7a6a3a", 0.0, Build.R_WOOD)
				for j in 12:
					var a := TAU * j / 12.0
					Build.box(n, Vector3(cos(a) * 0.232, y0 + 0.02, sin(a) * 0.232), Vector3(0.016, 0.1, 0.016), "#9c8a52").rotation.y = -a
			# A tall woven dome of a lid, a loop on top: a bamboo steamer by shape.
			Build.lathe(n, Vector3(0, 1.36, 0), [[0.0, 0.0], [0.24, 0.0], [0.22, 0.08], [0.14, 0.18], [0.04, 0.22], [0.0, 0.22]], "#d8cb9a", 0.0, Build.R_WOOD)
			for r: float in [0.2, 0.12]:
				Build.lathe(n, Vector3(0, 1.36 + (0.24 - r) * 0.9, 0), [[r, 0.0], [r + 0.012, 0.0], [r + 0.012, 0.014], [r, 0.014]], "#7a6a3a", 0.0, Build.R_WOOD)
			var loop := BuildFood._ring(n, Vector3(0, 1.6, 0), "#7a6a3a")
			loop.rotation.x = PI / 2
			loop.scale = Vector3.ONE * 0.7
		"coffee_machine":
			# A cream espresso machine: a group head, a mug beneath, a gauge and cups on top.
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build._add(n, Build.bevel_mesh(Vector3(0.64, 0.5, 0.44), 0.06), Vector3(0, 0.9, -0.12), Color("#f3ecdc"), 0.0)
			Build.box(n, Vector3(0, 1.1, 0.12), Vector3(0.5, 0.06, 0.08), "#2b2f31")
			Build.cyl(n, Vector3(0, 1.04, 0.14), 0.06, 0.06, "#c9d0d1", 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0.12, 1.05, 0.22), Vector3(0.18, 0.025, 0.04), "#2b2f31").rotation.y = 0.3
			Build.box(n, Vector3(0, 0.9, 0.16), Vector3(0.4, 0.02, 0.2), Build.STEEL_DARK)
			var mug := Node3D.new()
			mug.position = Vector3(0, 0.91, 0.16)
			mug.scale = Vector3.ONE * 0.8
			n.add_child(mug)
			BuildFood.ingredient(mug, "coffee", "prep")
			Build.cyl(n, Vector3(-0.18, 1.22, 0.11), 0.06, 0.015, Build.PAPER).rotation.x = PI / 2
			Build.cyl(n, Vector3(-0.18, 1.22, 0.115), 0.045, 0.015, "#2b2f31").rotation.x = PI / 2
			for k in 3:
				Build.cyl(n, Vector3(-0.15 + k * 0.15, 1.4, -0.14), 0.05, 0.06, Build.PAPER)
		"beer_tap":
			# A tap tower on a wooden bar: a brass pillar, two tall wooden handles, a drip
			# tray and a pint.
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build.box(n, Vector3(0, 0.9, 0.14), Vector3(0.5, 0.03, 0.2), Build.STEEL_DARK)
			Build.cyl(n, Vector3(0, 0.9, -0.12), 0.06, 0.38, "#d9a441", 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0, 1.27, -0.12), Vector3(0.44, 0.07, 0.07), "#d9a441", 0.0, Build.R_WOOD)
			for x: float in [-0.15, 0.15]:
				Build.box(n, Vector3(x, 1.22, -0.06), Vector3(0.025, 0.06, 0.07), "#d9a441", 0.0, Build.R_WOOD)
				Build._add(n, Build.bevel_mesh(Vector3(0.06, 0.24, 0.06), 0.02), Vector3(x, 1.31, -0.12), Color(Build.WOOD_DARK if x < 0 else "#d9962e"), 0.0, Build.R_WOOD)
			var pint := Node3D.new()
			pint.position = Vector3(0.15, 0.92, 0.14)
			n.add_child(pint)
			BuildFood.ingredient(pint, "ale", "prep")
		"fryer":
			# A steel fryer: a deep well of golden oil, a basket hung on the back, and a
			# drain rack on the right where fried food rests before it is picked up.
			BuildStations._counter(n, Build.STEEL, Build.STEEL_DARK, false)
			Build.box(n, Vector3(-0.15, 0.88, 0), Vector3(0.5, 0.06, 0.6), "#2b2f31", 0.0, Build.R_WOOD)
			Build.box(n, Vector3(-0.15, 0.9, 0), Vector3(0.42, 0.02, 0.52), "#e8b04e", 0.4, Build.R_GLOSS)
			Build.box(n, Vector3(0.28, 0.9, 0), Vector3(0.3, 0.02, 0.5), "#c9d0d1", 0.0, Build.R_WOOD)
			for z: float in [-0.16, 0.0, 0.16]:
				Build.box(n, Vector3(0.28, 0.92, z), Vector3(0.28, 0.015, 0.015), Build.STEEL_DARK)
			Build.box(n, Vector3(-0.15, 1.02, -0.36), Vector3(0.04, 0.24, 0.04), Build.STEEL_DARK)
			Build._add(n, Build.bevel_mesh(Vector3(0.72, 0.36, 0.05), 0.03), Vector3(0, 0.4, 0.46), Color(Build.STEEL_DARK), 0.0)
		"pot":
			# A big stock pot on a ring burner, its lid tipped back.
			BuildStations._counter(n, Build.STEEL, Build.STEEL_DARK, false)
			Build.lathe(n, Vector3(0, 0.9, 0), [[0.0, 0.0], [0.22, 0.0], [0.24, 0.02], [0.0, 0.02]], "#2b2f31", 0.0, Build.R_WOOD)
			Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.26, 0.0], [0.27, 0.02], [0.27, 0.34], [0.29, 0.36], [0.24, 0.36], [0.24, 0.04], [0.0, 0.04]], 24), Vector3(0, 0.92, 0), Color("#c9d0d1"), 0.0, Build.R_WOOD)
			Build.cyl(n, Vector3(0, 1.2, 0), 0.24, 0.02, "#8fc3cf", 0.0, Build.R_GLOSS)
			for x: float in [-0.3, 0.3]:
				Build.box(n, Vector3(x, 1.2, 0), Vector3(0.08, 0.04, 0.05), Build.STEEL_DARK)
		"board":
			# A thick chopping board on a worktop, with a big kitchen knife.
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build._add(n, Build.bevel_mesh(Vector3(0.66, 0.05, 0.48), 0.02), Vector3(0, 0.9, 0), Color("#e2b178"), 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0.12, 0.94, 0.16), Vector3(0.34, 0.01, 0.07), "#dfe6e7", 0.0, Build.R_WOOD).rotation.y = 0.3
			Build.box(n, Vector3(-0.12, 0.95, 0.22), Vector3(0.14, 0.03, 0.04), Build.WOOD_DARK).rotation.y = 0.3
		"slicer":
			# A deli slicer: a round steel blade on a coral base, with a sliding carriage.
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build._add(n, Build.bevel_mesh(Vector3(0.6, 0.12, 0.46), 0.04), Vector3(0, 0.9, 0), Color(Build.CORAL), 0.0)
			var blade := Build.cyl(n, Vector3(0.05, 1.18, -0.05), 0.2, 0.03, "#dfe6e7", 0.0, Build.R_WOOD)
			blade.rotation = Vector3(PI / 2, 0, 0.3)
			Build.ball(n, Vector3(0.05, 1.18, -0.02), 0.05, Build.STEEL_DARK)
			Build.box(n, Vector3(-0.15, 1.05, 0.08), Vector3(0.22, 0.04, 0.24), "#c9d0d1", 0.0, Build.R_WOOD)
		"stove":
			# Sheet 8: a steel-teal range with a raised back, four burners, a row of
			# knobs and an oven door with a window and a bar handle.
			BuildStations._counter(n, Build.STEEL, Build.STEEL_DARK, false)
			Build._add(n, Build.bevel_mesh(Vector3(0.96, 0.2, 0.1), 0.03), Vector3(0, 0.99, -0.44), Color(Build.STEEL), 0.0)
			for bx: float in [-0.22, 0.22]:
				for bz: float in [-0.17, 0.22]:
					if bx < 0.0 and bz < 0.0:
						continue  # the working burner, below
					Build.lathe(n, Vector3(bx, 0.9, bz), [[0.0, 0.0], [0.13, 0.0], [0.14, 0.012], [0.0, 0.012]], "#2b2f31", 0.0, Build.R_WOOD)
			var ring := Build.lathe(n, Vector3(Build.PAN.x, 0.9, Build.PAN.z), [[0.1, 0.0], [0.115, 0.012], [0.15, 0.012], [0.165, 0.0]], Build.STEEL_DARK)
			ring.name = "ring"
			# The frying pan lives on the back burner; the patty sits in it.
			Build.lathe(n, Vector3(Build.PAN.x, 0.905, Build.PAN.z), [[0.0, 0.0], [0.15, 0.0], [0.19, 0.04], [0.177, 0.04], [0.143, 0.02], [0.0, 0.02]], "#34383b", 0.0, Build.R_WOOD)
			Build.box(n, Vector3(Build.PAN.x + 0.3, 0.92, Build.PAN.z), Vector3(0.26, 0.035, 0.055), Build.WOOD_DARK)
			Build._add(n, Build.bevel_mesh(Vector3(0.72, 0.44, 0.05), 0.03), Vector3(0, 0.4, 0.46), Color(Build.STEEL_DARK), 0.0)
			Build._add(n, Build.bevel_mesh(Vector3(0.46, 0.2, 0.03), 0.02), Vector3(0, 0.4, 0.485), Color("#2b2f31"), 0.0, Build.R_GLOSS)
			Build._add(n, Build.bevel_mesh(Vector3(0.6, 0.045, 0.045), 0.02), Vector3(0, 0.66, 0.52), Color("#c9d0d1"), 0.0, Build.R_WOOD)
			for hx: float in [-0.26, 0.26]:
				Build.box(n, Vector3(hx, 0.64, 0.48), Vector3(0.04, 0.04, 0.05), "#c9d0d1", 0.0, Build.R_WOOD)
			for i in 4:
				Build.ball(n, Vector3(-0.3 + i * 0.2, 0.79, 0.475), 0.04, "#2b2f31")
		"counter":
			if pass_look and not Kitchen.is_tall(base):   # a tall fridge stands whole, the pass broken round it
				BuildStations._pass(n, base in ["", "counter"])   # a bare length shows its front
			else:
				BuildStations._counter(n, Build.CABINET, Build.WORKTOP, base != "double_counter")
		"pass":
			BuildStations._pass(n)
		"cups", "tray_stack":
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build._add(n, Build.bevel_mesh(Vector3(0.74, 0.02, 0.54), 0.008), Vector3(0, 0.9, 0), Color(Build.CORAL), 0.0)
		"sink":
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build.box(n, Vector3(0, 0.885, 0.04), Vector3(0.7, 0.03, 0.56), "#c9d0d1", 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0, 0.89, 0.04), Vector3(0.58, 0.03, 0.44), "#8fc3cf", 0.0, Build.R_GLOSS)
			Build.cyl(n, Vector3(0, 0.9, -0.36), 0.035, 0.26, "#c9d0d1", 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0, 1.12, -0.25), Vector3(0.06, 0.05, 0.26), "#c9d0d1", 0.0, Build.R_WOOD)
		"cabinet", "hood", "shelf", "wide_shelf":
			BuildStations.wall_piece(n, type, BuildStations.HIGH_Y0 - 0.3)
		"sponge":   # a hand tool, seen in the shop and in hand as itself (up its tree, the node's tool, 9.5)
			BuildClean.hand_tool(n, Kitchen.tool_of(node) if Kitchen.tool_of(node) != "" else "sponge", 1.0).position = Vector3(0, 0.3, 0)
		"mop_bucket":
			BuildClean.mop_bucket(n, node)
		"robot_dock":
			BuildClean.robot_dock(n)
		"bin":
			# Sheet 8: a dark brown tub, wider at the top, with a steel rim.
			Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.34, 0.0], [0.43, 0.62], [0.0, 0.62]], 4), Vector3.ZERO, Color("#5a4034"), 0.0).rotation.y = PI / 4
			Build._add(n, Build.lathe_mesh([[0.36, 0.6], [0.47, 0.6], [0.47, 0.7], [0.36, 0.7], [0.36, 0.6]], 4), Vector3.ZERO, Color("#9aa3a6"), 0.0, Build.R_WOOD).rotation.y = PI / 4
			Build.box(n, Vector3(0, 0.63, 0), Vector3(0.5, 0.02, 0.5), Build.TRIM)
		"plant":
			Build.lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.18, 0.0], [0.2, 0.02], [0.27, 0.36], [0.3, 0.38], [0.3, 0.44], [0.26, 0.46], [0.0, 0.46]], Build.CORAL)
			Build.lathe(n, Vector3(0, 0.2, 0), [[0.228, 0.0], [0.24, 0.006], [0.256, 0.08], [0.246, 0.086]], Build.PAPER)
			var size := 0.3 + 0.05 * tier
			Build.ball(n, Vector3(0, 0.5 + size, 0), size, Build.LEAF)
			for i in 5:
				var a := TAU * i / 5.0 + 0.4
				var frond := Build.ball(n, Vector3(cos(a) * size * 0.8, 0.56 + size * 0.7, sin(a) * size * 0.8), size * 0.62, Build.LEAF_2 if i % 2 else Build.LEAF)
				frond.scale = Vector3(1, 0.7, 1)
			Build.ball(n, Vector3(0.05, 0.62 + size * 1.75, 0.03), size * 0.55, Build.LEAF_2)
		"palm":
			# The seaside's fern (PRD 7): a sand-coloured pot, a ringed trunk leaning a
			# little, and long fronds that droop from the crown. Taller each tier.
			Build.lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.17, 0.0], [0.19, 0.02], [0.25, 0.34], [0.28, 0.36], [0.28, 0.42], [0.24, 0.44], [0.0, 0.44]], "#d8c3a0")
			Build.lathe(n, Vector3(0, 0.18, 0), [[0.215, 0.0], [0.226, 0.006], [0.24, 0.07], [0.23, 0.076]], Scenery.SEAFOAM)
			var tall := 0.75 + 0.15 * tier
			var segs := 4 + tier
			for i in segs:
				var f := float(i) / segs
				Build.cyl(n, Vector3(0.06 * f, 0.42 + tall * f, 0.0), 0.075 - 0.02 * f, tall / segs + 0.01, "#9a7350" if i % 2 else "#86603f", 0.0, Build.R_WOOD)
			var crown := Vector3(0.06, 0.45 + tall, 0)
			for i in 7:
				var a := TAU * i / 7.0 + 0.3
				var leaf := Node3D.new()
				leaf.position = crown
				leaf.rotation = Vector3(0, -a, 0)
				n.add_child(leaf)
				for k in 4:   # each frond a row of flattened balls, drooping toward its tip
					var b := Build.ball(leaf, Vector3(0.14 + k * 0.16, 0.05 - k * k * 0.045, 0), 0.13 - k * 0.02, Build.LEAF if (i + k) % 2 else Build.LEAF_2)
					b.scale = Vector3(1.6, 0.3, 0.75)
			Build.ball(n, crown + Vector3(0, 0.04, 0), 0.09, Build.LEAF_2)
		"flower_stand":
			# A three-legged wooden stand with a coral pot of flowers: the cheap starter.
			for i in 3:
				var a := TAU * i / 3.0
				Build.box(n, Vector3(cos(a) * 0.2, 0, sin(a) * 0.2), Vector3(0.06, 0.62, 0.06), Build.WOOD_DARK, 0.0, Build.R_WOOD)
			Build.lathe(n, Vector3(0, 0.28, 0), [[0.0, 0.0], [0.24, 0.0], [0.24, 0.035], [0.0, 0.035]], Build.WOOD, 0.0, Build.R_WOOD)
			Build.lathe(n, Vector3(0, 0.6, 0), [[0.0, 0.0], [0.28, 0.0], [0.28, 0.05], [0.0, 0.05]], Build.WOOD, 0.0, Build.R_WOOD)
			Build.lathe(n, Vector3(0, 0.65, 0), [[0.0, 0.0], [0.13, 0.0], [0.18, 0.24], [0.2, 0.26], [0.0, 0.26]], Build.CORAL)
			for b: Array in [[0.0, 0.0, 0.17, Build.LEAF], [-0.12, 0.05, 0.12, Build.LEAF_2], [0.12, -0.04, 0.12, Build.LEAF_2]]:
				Build.ball(n, Vector3(b[0], 0.98, b[1]), b[2], b[3])
			for f: Array in [[0.0, 0.1, Build.PAPER], [-0.14, 0.0, Build.WARN], [0.14, 0.04, Build.CORAL_DARK], [0.05, -0.13, Build.WARN], [-0.06, 0.14, Build.CORAL], [0.1, 0.15, Build.PAPER]]:
				Build.ball(n, Vector3(f[0], 1.1 + absf(f[1]) * 0.3, f[1]), 0.075, f[2], 0.0, Build.R_GLOSS)
				Build.ball(n, Vector3(f[0], 1.13 + absf(f[1]) * 0.3, f[1]), 0.03, "#f6c445")
		"desk":
			# PRD 10: a small wooden writing desk. A drawer pedestal on the left, two legs on
			# the right, a blotter, a pencil pot and a coral-tabbed "HIRING" card standing up
			# at the back so it reads as the staff desk, not another counter. The CV pile is
			# added on top by the game (`pile`).
			Build._add(n, Build.bevel_mesh(Vector3(0.92, 0.07, 0.62), 0.03), Vector3(0, 0.72, 0), Color(Build.WOOD), 0.0, Build.R_WOOD)
			Build._add(n, Build.bevel_mesh(Vector3(0.32, 0.7, 0.56), 0.03), Vector3(-0.27, 0.35, 0), Color(Build.WOOD_DARK), 0.0, Build.R_WOOD)
			for y: float in [0.2, 0.46]:
				Build.box(n, Vector3(-0.27, y, 0.285), Vector3(0.26, 0.2, 0.02), Build.WOOD, 0.0, Build.R_WOOD)
				Build.ball(n, Vector3(-0.27, y, 0.3), 0.025, Scenery.BRASS, 0.0, Build.R_WOOD)
			for z: float in [-0.25, 0.25]:
				Build.box(n, Vector3(0.39, 0.35, z), Vector3(0.07, 0.7, 0.07), Build.WOOD_DARK, 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0.39, 0.12, 0), Vector3(0.05, 0.05, 0.46), Build.WOOD_DARK, 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0.05, 0.765, 0.04), Vector3(0.5, 0.012, 0.36), Build.CABINET)
			Build.cyl(n, Vector3(0.36, 0.755, -0.18), 0.06, 0.14, Build.CORAL)
			for k in 3:
				Build.box(n, Vector3(0.34 + k * 0.025, 0.93, -0.18 + (k - 1) * 0.02), Vector3(0.018, 0.16, 0.018), [Build.WARN, Build.PAPER, Build.STEEL_DARK][k]).rotation.z = (k - 1) * 0.2
			var card := Build.box(n, Vector3(-0.12, 0.92, -0.25), Vector3(0.42, 0.26, 0.03), Build.PAPER)
			card.rotation.x = -0.18
			Build.box(card, Vector3(0, 0.08, 0.018), Vector3(0.42, 0.08, 0.01), Build.CORAL)
			for k in 2:
				Build.box(card, Vector3(-0.04 + k * 0.05, -0.03 - k * 0.06, 0.018), Vector3(0.28 - k * 0.1, 0.025, 0.01), Build.TRIM)
		"coat_stand":
			# A dark wooden coat stand on a cross foot, a coral coat and a hat hung on it.
			for turn: float in [0.0, PI / 2]:
				Build.box(n, Vector3.ZERO, Vector3(0.62, 0.06, 0.08), Build.WOOD_DARK, 0.0, Build.R_WOOD).rotation.y = turn
			Build.cyl(n, Vector3(0, 0.04, 0), 0.04, 1.62, Build.WOOD_DARK, 0.0, Build.R_WOOD)
			Build.ball(n, Vector3(0, 1.69, 0), 0.07, Build.WOOD, 0.0, Build.R_WOOD)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4
				var hook := Build.box(n, Vector3(cos(a) * 0.1, 1.48, sin(a) * 0.1), Vector3(0.2, 0.04, 0.04), Build.WOOD, 0.0, Build.R_WOOD)
				hook.rotation = Vector3(0, -a, 0.5)
			# The coat: a soft hanging body with a collar, on the front hooks.
			Build.lathe(n, Vector3(0, 0.62, 0.13), [[0.0, 0.0], [0.2, 0.0], [0.22, 0.04], [0.17, 0.66], [0.1, 0.8], [0.0, 0.82]], Build.CORAL).scale = Vector3(1, 1, 0.55)
			Build.box(n, Vector3(0, 1.32, 0.15), Vector3(0.24, 0.07, 0.12), Build.CORAL_DARK)
			for by: float in [0.95, 1.1]:
				Build.ball(n, Vector3(0, by, 0.25), 0.022, Build.PAPER)
			# The hat on the top.
			Build.cyl(n, Vector3(0.02, 1.72, 0), 0.17, 0.03, Build.CABINET)
			Build.cyl(n, Vector3(0.02, 1.74, 0), 0.1, 0.13, Build.CABINET)
			Build.cyl(n, Vector3(0.02, 1.76, 0), 0.105, 0.03, Build.CORAL)
		"floor_lamp":
			# A slim brass lamp with a warm drum shade: lit, it glows at night (the game
			# hangs a light over it, as over a table's candle).
			Build.lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.2, 0.0], [0.22, 0.02], [0.2, 0.06], [0.05, 0.08], [0.0, 0.08]], Build.STEEL_DARK, 0.0, Build.R_WOOD)
			Build.cyl(n, Vector3(0, 0.06, 0), 0.025, 1.3, Scenery.BRASS, 0.0, Build.R_WOOD)
			Build.ball(n, Vector3(0, 0.7, 0), 0.04, Scenery.BRASS, 0.0, Build.R_WOOD)
			Build.ball(n, Vector3(0, 1.36, 0), 0.06, "#fff1c4", 3.0)
			Build.lathe(n, Vector3(0, 1.22, 0), [[0.25, 0.0], [0.27, 0.01], [0.2, 0.36], [0.18, 0.37], [0.16, 0.35], [0.23, 0.01]], "#ffe3a8", 0.9)
			Build.lathe(n, Vector3(0, 1.21, 0), [[0.26, 0.0], [0.28, 0.0], [0.28, 0.03], [0.26, 0.03]], Build.CORAL)
		"gumball":
			# A coral gumball machine: a fluted foot, a box with the coin slot and a
			# chrome dial, a glass globe of coloured gumballs and a cap.
			Build.lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.2, 0.0], [0.22, 0.02], [0.2, 0.05], [0.07, 0.1], [0.06, 0.56], [0.12, 0.6], [0.0, 0.6]], Build.CORAL_DARK, 0.0, Build.R_WOOD)
			Build._add(n, Build.bevel_mesh(Vector3(0.34, 0.26, 0.34), 0.05), Vector3(0, 0.73, 0), Color(Build.DANGER), 0.0, Build.R_GLOSS)
			Build.cyl(n, Vector3(0, 0.74, 0.17), 0.06, 0.03, "#c9d0d1", 0.0, Build.R_WOOD).rotation.x = PI / 2
			Build.box(n, Vector3(0, 0.66, 0.17), Vector3(0.1, 0.05, 0.03), "#2b2f31")
			for i in 14:
				var a := i * 2.4
				var h := 0.06 + (i % 5) * 0.06
				var rr := 0.17 * sqrt(1.0 - pow((h - 0.13) / 0.22, 2)) if absf(h - 0.13) < 0.22 else 0.05
				Build.ball(n, Vector3(cos(a) * rr * 0.75, 0.9 + h, sin(a) * rr * 0.75), 0.05,
					[Build.WARN, Build.CORAL, Build.GOOD, Build.PAPER, "#6aa7dc"][i % 5], 0.0, Build.R_GLOSS)
			Build.ball(n, Vector3(0, 1.06, 0), 0.22, "#eaf6f866", 0.0, Build.R_GLOSS)
			Build.cyl(n, Vector3(0, 1.24, 0), 0.1, 0.06, Build.DANGER, 0.0, Build.R_GLOSS)
			Build.ball(n, Vector3(0, 1.31, 0), 0.045, "#c9d0d1", 0.0, Build.R_WOOD)
		"jukebox":
			# The diner's showpiece: a wide coral and teal cabinet under a glowing arch,
			# a record window, a speaker grille and bubble tubes up the sides. Each tier
			# lights another band across the arch.
			Build._add(n, Build.bevel_mesh(Vector3(0.86, 0.1, 0.56), 0.03), Vector3(0, 0.05, 0), Color(Build.WOOD_DARK), 0.0, Build.R_WOOD)
			Build._add(n, Build.bevel_mesh(Vector3(0.8, 0.9, 0.5), 0.05), Vector3(0, 0.55, 0), Color(Build.CABINET), 0.0)
			var arch := Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.4, 0.0], [0.4, 0.5], [0.0, 0.5]], 32), Vector3(0, 1.0, -0.25), Color(Build.CORAL), 0.0)
			arch.rotation.x = PI / 2
			arch.scale = Vector3(1, 1, 0.85)
			for k in tier + 1:   # glowing bands across the arch, one more a tier
				var band := Build._add(n, Build.lathe_mesh([[0.3 - k * 0.07, 0.0], [0.34 - k * 0.07, 0.0], [0.34 - k * 0.07, 0.52], [0.3 - k * 0.07, 0.52]], 32), Vector3(0, 1.0, -0.26), Color(["#ffd98a", "#fff1c4", "#ffb38a", "#ffd98a"][k]), 1.6)
				band.rotation.x = PI / 2
				band.scale = Vector3(1, 1, 0.85)
			Build.box(n, Vector3(0, 0.98, 0.0), Vector3(0.82, 0.04, 0.52), Build.WARN, 0.5)
			# The record window and the grille below it.
			Build._add(n, Build.bevel_mesh(Vector3(0.5, 0.26, 0.04), 0.02), Vector3(0, 0.8, 0.26), Color("#2b2f31"), 0.0, Build.R_GLOSS)
			Build.cyl(n, Vector3(0, 0.8, 0.27), 0.1, 0.02, "#1b1b1f", 0.0, Build.R_GLOSS).rotation.x = PI / 2
			Build.cyl(n, Vector3(0, 0.8, 0.29), 0.035, 0.01, Build.CORAL).rotation.x = PI / 2
			Build._add(n, Build.bevel_mesh(Vector3(0.52, 0.3, 0.03), 0.02), Vector3(0, 0.38, 0.255), Color(Build.WORKTOP), 0.0, Build.R_WOOD)
			for gx in 5:
				Build.box(n, Vector3(-0.2 + gx * 0.1, 0.24, 0.27), Vector3(0.035, 0.28, 0.02), Build.WOOD_DARK)
			for sx: float in [-0.36, 0.36]:
				Build.cyl(n, Vector3(sx, 0.12, 0.2), 0.04, 0.84, "#ffb38a", 1.2)
		"lantern":
			# A ship's lantern on a small barrel: a brass cage round a glowing glass, a
			# ring to hang it by, and a coil of rope on the lid.
			Build.lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.22, 0.0], [0.27, 0.27], [0.22, 0.54], [0.0, 0.54]], Build.WOOD, 0.0, Build.R_WOOD)
			for hy: float in [0.08, 0.44]:
				Build.lathe(n, Vector3(0, hy, 0), [[0.235 + (0.02 if hy < 0.2 else 0.0), 0.0], [0.255 + (0.02 if hy < 0.2 else 0.0), 0.0], [0.255 + (0.02 if hy < 0.2 else 0.0), 0.04], [0.235 + (0.02 if hy < 0.2 else 0.0), 0.04]], Build.STEEL_DARK, 0.0, Build.R_WOOD)
			Build.lathe(n, Vector3(0.0, 0.54, 0.0), [[0.12, 0.0], [0.2, 0.0], [0.2, 0.05], [0.12, 0.05]], "#d8c3a0")
			Build.cyl(n, Vector3(0, 0.56, 0), 0.13, 0.04, Scenery.BRASS, 0.0, Build.R_WOOD)
			Build.cyl(n, Vector3(0, 0.6, 0), 0.1, 0.28, "#ffd98a", 1.4, Build.R_GLOSS)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4
				Build.box(n, Vector3(cos(a) * 0.11, 0.6, sin(a) * 0.11), Vector3(0.025, 0.27, 0.025), Scenery.BRASS, 0.0, Build.R_WOOD)
			Build.lathe(n, Vector3(0, 0.88, 0), [[0.0, 0.0], [0.14, 0.0], [0.08, 0.1], [0.0, 0.1]], Scenery.BRASS, 0.0, Build.R_WOOD)
			var ring := Build.lathe(n, Vector3(0, 1.04, 0), [[0.05, -0.012], [0.07, -0.012], [0.07, 0.012], [0.05, 0.012]], Scenery.BRASS, 0.0, Build.R_WOOD)
			ring.rotation.x = PI / 2
		"aquarium":
			# The seaside's showpiece: a tank of blue water on a wooden cabinet,
			# with sand, weed and a lid lamp. A fish more each tier.
			BuildStations._counter(n, Build.WOOD, Build.WOOD_DARK, true)
			Build.box(n, Vector3(0, 0.9, 0), Vector3(0.84, 0.05, 0.62), "#e8d9b0")
			# Opaque blue water inside steel corner posts (glass would wash out from the
			# fixed camera); the fish swim at the two faces the camera sees, +z and +x.
			Build.box(n, Vector3(0, 0.92, 0), Vector3(0.76, 0.48, 0.54), "#5fb3cf", 0.0, Build.R_GLOSS)
			Build.box(n, Vector3(0, 1.36, 0), Vector3(0.76, 0.03, 0.54), "#9fd8e8", 0.0, Build.R_GLOSS)
			for cx: float in [-0.4, 0.4]:
				for cz: float in [-0.29, 0.29]:
					Build.box(n, Vector3(cx, 0.9, cz), Vector3(0.05, 0.54, 0.05), Build.STEEL_DARK, 0.0, Build.R_WOOD)
			for w: Array in [[-0.22, 0.3], [-0.12, 0.22], [0.2, 0.26]]:
				Build.box(n, Vector3(w[0], 0.94, 0.27), Vector3(0.05, w[1], 0.03), Build.LEAF)
			var fish_at: Array = [Vector3(-0.2, 1.1, 0.28), Vector3(0.1, 1.22, 0.28), Vector3(0.39, 1.08, 0.05),
				Vector3(0.39, 1.24, -0.15), Vector3(0.12, 1.02, 0.28)]
			for i in tier + 2:
				var col: String = [Build.CORAL, Build.WARN, "#ffb38a", Build.CORAL_DARK, Build.WARN][i]
				var holder := Node3D.new()
				holder.position = fish_at[i]
				holder.rotation.y = 0.0 if fish_at[i].z > 0.2 else PI / 2
				n.add_child(holder)
				Build.ball(holder, Vector3.ZERO, 0.06, col, 0.0, Build.R_GLOSS).scale = Vector3(1.5, 1.0, 0.5)
				Build.box(holder, Vector3(-0.1, -0.035, 0), Vector3(0.05, 0.07, 0.025), col).rotation.z = 0.4
				Build.ball(holder, Vector3(0.05, 0.015, 0.03), 0.012, Build.TRIM)
			Build._add(n, Build.bevel_mesh(Vector3(0.88, 0.06, 0.66), 0.02), Vector3(0, 1.45, 0), Color(Build.CABINET), 0.0, Build.R_WOOD)
			Build.box(n, Vector3(0, 1.42, 0.0), Vector3(0.5, 0.02, 0.3), "#fff1c4", 1.0)
		"stool":
			# A counter stool (PRD 7): a small round high table on a pedestal, and one
			# chrome stool with a coral cushion on its seat cell (+x, like a chair).
			Build.lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.2, 0.0], [0.22, 0.02], [0.22, 0.06], [0.2, 0.08], [0.06, 0.08], [0.06, 0.66], [0.0, 0.66]], Build.STEEL_DARK, 0.0, Build.R_WOOD)
			Build.lathe(n, Vector3(0, 0.66, 0), [[0.0, 0.0], [0.38, 0.0], [0.4, 0.02], [0.4, 0.07], [0.38, 0.08], [0.0, 0.08]], "#ecc88f", 0.0, Build.R_WOOD)
			var stool := Node3D.new()
			stool.position = Vector3(1, 0, 0)
			n.add_child(stool)
			Build.lathe(stool, Vector3.ZERO, [[0.0, 0.0], [0.18, 0.0], [0.2, 0.02], [0.18, 0.04], [0.04, 0.05], [0.0, 0.05]], "#c9d0d1", 0.0, Build.R_WOOD)
			Build.cyl(stool, Vector3(0, 0.04, 0), 0.035, 0.32, "#c9d0d1", 0.0, Build.R_WOOD)
			Build.lathe(stool, Vector3(0, 0.16, 0), [[0.15, 0.0], [0.17, 0.0], [0.17, 0.02], [0.15, 0.02]], "#c9d0d1", 0.0, Build.R_WOOD)
			Build.lathe(stool, Vector3(0, 0.33, 0), [[0.0, 0.0], [0.23, 0.0], [0.26, 0.03], [0.26, 0.08], [0.22, 0.11], [0.0, 0.11]], Build.CORAL)
			Build.cyl(n, Vector3(0, 0.74, 0), 0.05, 0.085, "#ffd98a", 1.3)
			Build.ball(n, Vector3(0, 0.84, 0), 0.022, "#fff1c4", 3.0).scale = Vector3(1, 1.5, 1)
		"dish_rack":
			# A worktop with a wooden rack; the dishes drying in it are `BuildStations.rack_load`.
			BuildStations._counter(n, Build.CABINET, Build.WORKTOP)
			Build.box(n, Vector3(0, 0.9, 0), Vector3(0.72, 0.03, 0.5), Build.WOOD_DARK, 0.0, Build.R_WOOD)
			for i in 9:
				Build.box(n, Vector3(-0.28 + i * 0.07, 0.93, 0.2), Vector3(0.03, 0.2, 0.03), Build.WOOD, 0.0, Build.R_WOOD)
				Build.box(n, Vector3(-0.28 + i * 0.07, 0.93, -0.2), Vector3(0.03, 0.3, 0.03), Build.WOOD, 0.0, Build.R_WOOD)
		"table":
			# Two-seat table (sheet 1): a slab top with a small bevel on a slim pedestal and
			# disc foot; coral chairs on dark wooden legs (`_chair`).
			Build.lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.25, 0.0], [0.27, 0.02], [0.27, 0.08], [0.25, 0.1], [0.075, 0.1], [0.075, 0.63], [0.0, 0.63]], Build.CABINET, 0.0, Build.R_WOOD)
			Build._add(n, Build.bevel_mesh(Vector3(1.12, 0.12, 1.12), 0.035), Vector3(0, 0.68, 0), Color("#ecc88f"), 0.0, Build.R_WOOD)
			for sx: int in [-1, 1]:
				BuildStations._chair(n, Vector2i(sx, 0), Build.CORAL)
			# A small candle in a glass, as in the sunset frame.
			Build.cyl(n, Vector3(0, 0.74, 0), 0.05, 0.085, "#ffd98a", 1.3)
			Build.ball(n, Vector3(0, 0.84, 0), 0.022, "#fff1c4", 3.0).scale = Vector3(1, 1.5, 1)
		"table4":
			# Four-seat table (sheet 10): a square plank top on four square legs, two coral
			# chairs and two wooden ones, one on each side.
			Build._add(n, Build.bevel_mesh(Vector3(1.0, 0.1, 1.0), 0.035), Vector3(0, 0.69, 0), Color("#c98f58"), 0.0, Build.R_WOOD)
			for lx: float in [-0.4, 0.4]:
				for lz: float in [-0.4, 0.4]:
					Build._add(n, Build.bevel_mesh(Vector3(0.09, 0.64, 0.09), 0.025), Vector3(lx, 0.32, lz), Color(Build.WOOD), 0.0, Build.R_WOOD)
			for i in 4:
				var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][i]
				BuildStations._chair(n, d, Build.CORAL if i < 2 else Build.WOOD)
			Build.cyl(n, Vector3(0, 0.74, 0), 0.05, 0.085, "#ffd98a", 1.3)
			Build.ball(n, Vector3(0, 0.84, 0), 0.022, "#fff1c4", 3.0).scale = Vector3(1, 1.5, 1)
		"booth":
			# Booth (sheet 10): teal benches with coral cushions facing across a narrow
			# wooden table on a dark pedestal. One guest per bench, so it fits one cell.
			Build.lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.24, 0.0], [0.26, 0.02], [0.26, 0.07], [0.24, 0.09], [0.07, 0.09], [0.07, 0.63], [0.0, 0.63]], Build.STEEL_DARK, 0.0, Build.R_WOOD)
			Build._add(n, Build.bevel_mesh(Vector3(0.72, 0.1, 1.0), 0.035), Vector3(0, 0.68, 0), Color("#c98f58"), 0.0, Build.R_WOOD)
			for sx: float in [-1.0, 1.0]:
				Build._add(n, Build.bevel_mesh(Vector3(0.66, 0.08, 0.98), 0.025), Vector3(sx * 1.02, 0.04, 0), Color(Build.WOOD_DARK), 0.0, Build.R_WOOD)
				Build._add(n, Build.bevel_mesh(Vector3(0.62, 0.3, 0.96)), Vector3(sx * 1.02, 0.23, 0), Color(Build.CABINET), 0.0)
				Build._add(n, Build.bevel_mesh(Vector3(0.5, 0.08, 0.88), 0.035), Vector3(sx * 0.98, 0.41, 0), Color(Build.CORAL), 0.0)
				Build._add(n, Build.bevel_mesh(Vector3(0.16, 0.86, 0.96)), Vector3(sx * 1.27, 0.51, 0), Color(Build.CABINET), 0.0)
				for cz: float in [-0.22, 0.22]:
					Build._add(n, Build.bevel_mesh(Vector3(0.07, 0.4, 0.42), 0.03), Vector3(sx * 1.16, 0.66, cz), Color(Build.CORAL), 0.0)
			Build.cyl(n, Vector3(0, 0.73, 0), 0.05, 0.085, "#ffd98a", 1.3)
			Build.ball(n, Vector3(0, 0.83, 0), 0.022, "#fff1c4", 3.0).scale = Vector3(1, 1.5, 1)
	if tier > 1:
		for i in tier - 1:
			Build.box(n, Vector3(0, 0.05 + i * 0.1, 0), Vector3(1.02, 0.04, 1.02), Build.WARN, 0.6)
