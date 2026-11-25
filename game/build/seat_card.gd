class_name BuildSeatCard
extends RefCounted
## The seat-count card (EPIC 28): a small cream paper tent card standing at the centre of a
## table, its dark brown numeral the number of chairs the table seats. Paper, not HUD: it
## has a thickness, leans back a little and throws a soft plum-brown shadow on the tabletop.

const INK := "#3a2c22"          # dark brown numeral (the trim brown)
const SHADOW := Color(0.29, 0.16, 0.22, 0.38)   # plum-brown, soft
const W := 0.54                  # wide enough to read at 20 px from the fixed camera
const H := 0.46
const LEAN := -0.2               # radians back from upright


## A card on its own node, base centred on the origin; `n` is its numeral. The returned
## node is what folds (scale.y) and carries the numeral as meta "label".
static func make(parent: Node3D, n: int) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var shadow := MeshInstance3D.new()   # a soft blot on the tabletop under the card
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3
	disc.bottom_radius = 0.3
	disc.height = 0.004
	shadow.mesh = disc
	shadow.scale = Vector3(1.0, 1.0, 0.7)
	shadow.position = Vector3(0, 0.004, 0.06)
	shadow.material_override = Build.mat(SHADOW, 0.0, Build.R_MATTE, false)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	var fold := Node3D.new()   # the leaning paper: folds flat about its foot
	root.add_child(fold)
	fold.rotation.x = LEAN
	Build.box(fold, Vector3.ZERO, Vector3(W, H, 0.035), Build.PAPER)
	Build.box(fold, Vector3(0, 0.0, 0.0), Vector3(W + 0.03, 0.04, 0.05), "#e8d7b4")   # the folded foot
	var l := Label3D.new()
	l.text = str(n)
	l.font_size = 96
	l.pixel_size = 0.0068
	l.modulate = Color(INK)
	l.outline_size = 0
	l.shaded = false
	l.no_depth_test = false
	l.position = Vector3(0, H * 0.52, 0.02)
	fold.add_child(l)
	root.set_meta("label", l)
	root.set_meta("fold", fold)
	return root
