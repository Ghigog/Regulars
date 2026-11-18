class_name BuildClean
extends RefCounted
## Cleaning pieces (PRD 9.4, 9.5): mops, the scrubber, sponges and the small hand tools,
## floor treatment boxes and their sheens, mop buckets, the robot sweeper and its dock.


# ---------------------------------------------------------------- cleaning (PRD 9.4)

const MOP_CLEAN := "#f3ead6"    # cotton strands
const MOP_DIRTY := "#6b4e32"    # grey-brown once dirty: by shape too, the strands droop
const SPONGE := "#ffd452"
const SCOURER := "#4f9a5e"
const FLAT_PAD := "#5b8fc7"   # the flat mop's microfibre pad
const BUCKET := "#ffd452"
const ROBOT := "#f6efe0"
const ROBOT_RIM := "#f07a63"


## A mop standing upright from its foot: a wooden pole and a head that goes from its
## clean colour to brown as it gets dirty (`clean` 1 to 0). Each mop on the bucket's tree
## (PRD 9.5) has its own head, told apart by shape at 20 px: the plain mop's cotton
## strands (a dirty head droops); the sponge-head mop's yellow block in a steel clamp;
## the flat mop's wide blue pad; the wringer mop's strands under a coral collar (it
## never gets dirty); the floor scrubber, a coral motor on a round deck with a T-handle.
static func mop(parent: Node3D, clean := 1.0, tool := "mop") -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	if tool == "scrubber":
		_scrubber(n)
		return n
	Build.cyl(n, Vector3(0, 0.12, 0), 0.035, 1.15, Build.WOOD, 0.0, Build.R_WOOD)
	Build.ball(n, Vector3(0, 1.28, 0), 0.04, Build.CORAL)   # the grip
	match tool:
		"sponge_mop":
			var body := Color(MOP_DIRTY).lerp(Color(SPONGE), clean).to_html(false)
			Build.box(n, Vector3(0, 0.12, 0), Vector3(0.3, 0.05, 0.08), Build.STEEL, 0.0, Build.R_GLOSS)   # the clamp
			Build._add(n, Build.bevel_mesh(Vector3(0.32, 0.1, 0.12), 0.03), Vector3(0, 0.02, 0), Color(body), 0.0)
			Build.box(n, Vector3(0, 0.01, 0.061), Vector3(0.3, 0.025, 0.01), SCOURER)
			return n
		"flat_mop":
			var pad := Color(MOP_DIRTY).lerp(Color(FLAT_PAD), clean).to_html(false)
			Build.box(n, Vector3(0, 0.08, 0), Vector3(0.08, 0.05, 0.08), Build.STEEL_DARK)   # the swivel
			Build.box(n, Vector3(0, 0.05, 0), Vector3(0.46, 0.025, 0.16), Build.STEEL, 0.0, Build.R_GLOSS)
			Build._add(n, Build.bevel_mesh(Vector3(0.5, 0.05, 0.2), 0.02), Vector3(0, 0.0, 0), Color(pad), 0.0)
			return n
	var col := Color(MOP_DIRTY).lerp(Color(MOP_CLEAN), clean).to_html(false)
	var droop := 1.0 - clean
	Build.box(n, Vector3(0, 0.13, 0), Vector3(0.1, 0.05, 0.1), Build.STEEL_DARK)
	if tool == "wringer_mop":
		Build.cyl(n, Vector3(0, 0.15, 0), 0.075, 0.07, Build.CORAL)
	for i in 7:
		var a := TAU * i / 7.0
		var strand := Build.box(n, Vector3(cos(a) * 0.07, 0.02, sin(a) * 0.07), Vector3(0.045, 0.2, 0.045), col)
		strand.rotation = Vector3(sin(a) * (0.5 - 0.3 * droop), 0, -cos(a) * (0.5 - 0.3 * droop))
	if droop > 0.5:   # drips under a dirty mop
		Build.ball(n, Vector3(0.02, -0.08, 0.03), 0.03, MOP_DIRTY)
	return n


## The floor scrubber, standing from its deck: a round grey deck on a dark brush ring, a
## coral motor housing on top, a steel pole up to a T-handle with coral grips.
static func _scrubber(n: Node3D) -> void:
	Build.lathe(n, Vector3(0, 0.0, 0), [[0.0, 0.0], [0.24, 0.0], [0.24, 0.03], [0.0, 0.03]], Build.STEEL_DARK)   # the brush
	Build.lathe(n, Vector3(0, 0.03, 0), [[0.0, 0.0], [0.27, 0.0], [0.27, 0.06], [0.22, 0.09], [0.0, 0.09]], "#9aa3a6", 0.0, Build.R_GLOSS)
	Build._add(n, Build.bevel_mesh(Vector3(0.24, 0.16, 0.2), 0.04), Vector3(0, 0.12, -0.02), Color(Build.CORAL), 0.0)
	Build.ball(n, Vector3(0.0, 0.2, 0.09), 0.025, Build.GOOD, 0.8)   # the power light
	Build.cyl(n, Vector3(0, 0.26, -0.04), 0.03, 0.95, Build.STEEL, 0.0, Build.R_GLOSS)
	Build.box(n, Vector3(0, 1.22, -0.04), Vector3(0.36, 0.04, 0.04), Build.STEEL, 0.0, Build.R_GLOSS)
	for x: float in [-0.17, 0.17]:
		Build.box(n, Vector3(x, 1.22, -0.04), Vector3(0.08, 0.06, 0.06), Build.CORAL)


## A sponge: a yellow block with a green scourer on top, browner as it gets dirty.
static func sponge(parent: Node3D, clean := 1.0) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var body := Color(MOP_DIRTY).lerp(Color(SPONGE), clean).to_html(false)
	Build._add(n, Build.bevel_mesh(Vector3(0.24, 0.1, 0.15), 0.03), Vector3(0, 0.05, 0), Color(body), 0.0)
	Build._add(n, Build.bevel_mesh(Vector3(0.24, 0.04, 0.15), 0.015), Vector3(0, 0.12, 0), Color(SCOURER), 0.0)
	return n


## A small cleaning tool (PRD 9.5), each its own silhouette at 20 px: the sponge; the
## scourer, a sponge under a steel-wool pad; the grease scraper, a wide steel blade on
## a wooden handle; the spill kit, a coral pouch with a white band and cross.
static func hand_tool(parent: Node3D, tool: String, clean := 1.0) -> Node3D:
	match tool:
		"scourer":
			var n := Node3D.new()
			parent.add_child(n)
			var body := Color(MOP_DIRTY).lerp(Color(SPONGE), clean).to_html(false)
			Build._add(n, Build.bevel_mesh(Vector3(0.24, 0.08, 0.15), 0.03), Vector3(0, 0.04, 0), Color(body), 0.0)
			Build._add(n, Build.bevel_mesh(Vector3(0.26, 0.07, 0.17), 0.03), Vector3(0, 0.115, 0), Color("#b9c2c4"), 0.0, Build.R_WOOD)
			return n
		"grease_scraper":
			var n := Node3D.new()
			parent.add_child(n)
			Build.box(n, Vector3(0, 0.02, 0), Vector3(0.3, 0.03, 0.14), Build.STEEL, 0.0, Build.R_GLOSS)
			Build.cyl(n, Vector3(0, 0.03, 0.07), 0.025, 0.06, Build.STEEL_DARK)
			Build.box(n, Vector3(0, 0.05, 0.2), Vector3(0.06, 0.05, 0.22), Build.WOOD)
			return n
		"spill_kit":
			var n := Node3D.new()
			parent.add_child(n)
			Build._add(n, Build.bevel_mesh(Vector3(0.26, 0.2, 0.14), 0.04), Vector3(0, 0.1, 0), Color(Build.CORAL), 0.0)
			Build.box(n, Vector3(0, 0.13, 0.072), Vector3(0.27, 0.05, 0.005), "#fbf6ea")
			Build.box(n, Vector3(0, 0.13, 0.076), Vector3(0.025, 0.09, 0.005), Build.DANGER)
			Build.box(n, Vector3(0, 0.13, 0.076), Vector3(0.09, 0.025, 0.005), Build.DANGER)
			return n
	return sponge(parent, clean)


## The colour of each floor treatment's liquid, as its sheen on the floor (PRD 9.5).
const TREAT_COL := {
	"cleaner": "#5fb8c4", "strong_cleaner": "#2f8fa8", "primer": "#c9c1ae", "sealing_primer": "#9a917c",
	"finish": "#f0b04a", "high_gloss": "#f7cf5a",
}


## A floor treatment's box (PRD 9.5): a kraft crate of two jugs in the treatment's
## colour, a white diamond label on the front for chemicals. Sits where a box of stock does.
static func treatment_box(n: Node3D, key: String) -> void:
	var col: String = TREAT_COL.get(key, TREAT_COL.cleaner)
	Build._add(n, Build.bevel_mesh(Vector3(0.7, 0.26, 0.5), 0.03), Vector3(0, 0.6, 0), Color("#c9a26b"), 0.0, Build.R_WOOD)
	for x: float in [-0.17, 0.17]:
		Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.13, 0.0], [0.13, 0.26], [0.07, 0.34], [0.05, 0.4], [0.0, 0.4]], 12),
			Vector3(x, 0.73, 0), Color(col), 0.0, Build.R_GLOSS)
		Build.cyl(n, Vector3(x, 1.13, 0), 0.055, 0.05, "#fbf6ea")
	var label := Build.box(n, Vector3(0, 0.62, 0.255), Vector3(0.16, 0.16, 0.01), "#fbf6ea")
	label.rotation.z = PI / 4
	Build.box(n, Vector3(0, 0.62, 0.262), Vector3(0.06, 0.06, 0.005), col).rotation.z = PI / 4


## Where a tool hangs off a hook drawn at height y0 against the wall.
static func hook_spot(y0: float) -> Vector3:
	return Vector3(0, y0 - 0.12, -0.5 + 0.2)


## The mop bucket: a yellow pail on castors with a grey wringer box on one side.
static func mop_bucket(n: Node3D, node := "") -> void:
	for x: float in [-0.2, 0.2]:
		for z: float in [-0.16, 0.16]:
			Build.ball(n, Vector3(x, 0.04, z), 0.04, Build.STEEL_DARK)
	Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.26, 0.0], [0.33, 0.42], [0.31, 0.44], [0.27, 0.06], [0.0, 0.06]], 4), Vector3(0, 0.06, 0), Color(BUCKET), 0.0).rotation.y = PI / 4
	var liquid := str(Kitchen.NODES.get(node, {}).get("liquid", ""))   # a cleaner in the pail tints its water
	var water: String = TREAT_COL.get(liquid, "#8fb7bd") if liquid != "" else "#8fb7bd"
	Build._add(n, Build.lathe_mesh([[0.0, 0.0], [0.27, 0.0], [0.27, 0.02], [0.0, 0.02]], 4), Vector3(0, 0.38, 0), Color(water), 0.0, Build.R_GLOSS).rotation.y = PI / 4   # water
	Build._add(n, Build.bevel_mesh(Vector3(0.2, 0.18, 0.34), 0.03), Vector3(0.24, 0.5, 0), Color("#9aa3a6"), 0.0, Build.R_WOOD)
	Build.box(n, Vector3(0.36, 0.62, 0), Vector3(0.05, 0.3, 0.05), Build.STEEL_DARK).rotation.z = -0.5   # the wringer's handle
	if node == "wringer_bucket":   # PRD 9.5: a big coral press on top, its long lever up
		Build._add(n, Build.bevel_mesh(Vector3(0.26, 0.12, 0.38), 0.03), Vector3(0.24, 0.66, 0), Color(Build.CORAL), 0.0)
		Build.box(n, Vector3(0.3, 0.98, 0), Vector3(0.06, 0.5, 0.06), Build.STEEL, 0.0, Build.R_GLOSS).rotation.z = -0.25
		Build.ball(n, Vector3(0.36, 1.22, 0), 0.05, Build.CORAL)


## Where the mop stands in its bucket: head up, handle down in the pail, leaning on the
## rim (PRD 9.6), so which mop it is and how dirty it is both show at 20 px.
static func bucket_mop(n: Node3D, clean: float, tool := "mop") -> Node3D:
	var m := mop(n, clean, tool)
	m.position = Vector3(0.22, 1.42, 0)
	m.rotation.z = PI - 0.2
	if tool == "scrubber":   # too big for the pail: parked beside it
		m.position = Vector3(-0.2, 0.0, 0.3)
		m.rotation.z = 0.0
	return m


## The robot's dock: a low ramp plate with a back post and a green charge light.
static func robot_dock(n: Node3D) -> void:
	Build._add(n, Build.bevel_mesh(Vector3(0.86, 0.05, 0.86), 0.02), Vector3(0, 0.0, 0), Color(Build.STEEL_DARK), 0.0)
	Build._add(n, Build.bevel_mesh(Vector3(0.5, 0.36, 0.14), 0.04), Vector3(0, 0.03, -0.36), Color(ROBOT), 0.0)
	Build.ball(n, Vector3(0, 0.3, -0.28), 0.045, Build.GOOD, 0.8)


## The robot sweeper: a flat cream disc with a coral bumper, a dark sensor dome and two
## side brushes (the "brush" node spins while it works).
static func robot(n: Node3D) -> void:
	Build.lathe(n, Vector3(0, 0.03, 0), [[0.0, 0.0], [0.3, 0.0], [0.32, 0.03], [0.32, 0.09], [0.29, 0.12], [0.0, 0.12]], ROBOT)
	Build.lathe(n, Vector3(0, 0.03, 0), [[0.315, 0.0], [0.335, 0.0], [0.335, 0.08], [0.315, 0.08]], ROBOT_RIM)
	Build.lathe(n, Vector3(0, 0.15, -0.08), [[0.0, 0.0], [0.08, 0.0], [0.07, 0.04], [0.0, 0.06]], Build.STEEL_DARK, 0.0, Build.R_GLOSS)
	Build.ball(n, Vector3(0, 0.16, 0.18), 0.03, Build.GOOD, 0.8)
	var brush := Node3D.new()
	brush.name = "brush"
	brush.position = Vector3(0.22, 0.02, 0.22)
	n.add_child(brush)
	for i in 3:
		var a := TAU * i / 3.0
		Build.box(brush, Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), Vector3(0.14, 0.012, 0.02), Build.TRIM).rotation.y = -a


## The row of tags over a storage cell naming the kinds it holds (PRD 8.4): a cream
## card per box with the raw ingredient in front of it, readable at 20 px. A box kept
## cold has a square, frost-blue card (by shape as well as colour); a ready-made one
## shows the food prepped, with a green corner.
static func box_tags(n: Node3D, boxes: Array, y := 1.6) -> void:
	var gap := 0.5
	for i in boxes.size():
		var at := Build.CAM_BASIS.x * (i - (boxes.size() - 1) / 2.0) * gap + Vector3(0, y, 0)
		if Treatments.is_box(boxes[i]):   # chemicals (PRD 9.5): a diamond card, a jug on it
			var col: String = TREAT_COL.get(Treatments.key_of(boxes[i]), TREAT_COL.cleaner)
			var tag := Fx.card([[Icons.rect(0, 0, 1.7, 1.7, PI / 4), Icons.INK], [Icons.rect(0, 0, 1.46, 1.46, PI / 4), "#fbf6ea"],
				[Icons.rect(0, -0.12, 0.5, 0.62), Icons.INK], [Icons.rect(0, -0.12, 0.38, 0.5), col],
				[Icons.rect(0, 0.3, 0.2, 0.26), Icons.INK]], 0.23)
			tag.position = at
			n.add_child(tag)
			continue
		var s := Pantry.station_ingredient(boxes[i])
		if s.is_empty():
			continue
		var layers: Array = []
		if Kitchen.is_chilled(boxes[i]):
			layers.append([Icons.rect(0, 0, 2.0, 2.0), Icons.INK])
			layers.append([Icons.rect(0, 0, 1.76, 1.76), "#8fc3cf"])
			layers.append([Icons.rect(0, 0, 1.4, 1.4), "#fbf6ea"])
		else:
			layers.append([Icons.ell(0, 0, 1.0), Icons.INK])
			layers.append([Icons.ell(0, 0, 0.86), "#fbf6ea"])
		if s.ready:
			layers.append([Icons.ell(0.62, 0.62, 0.34), Icons.INK])
			layers.append([Icons.ell(0.62, 0.62, 0.24), Build.GOOD])
		var card := Fx.card(layers, 0.23)
		card.position = at
		n.add_child(card)
		var food := Node3D.new()
		food.position = at + Build.CAM_BASIS.z * 0.2 - Build.CAM_BASIS.y * 0.08
		food.scale = Vector3.ONE * 0.95
		n.add_child(food)
		BuildFood.ingredient(food, s.id, "prep" if s.ready else "raw", "" if s.ready else "raw")
