class_name MenuBoard
extends Node3D
## Tonight's item names chalked on the street side of the A-frame board that
## Scenery._outside stands on the pavement by the door, mains first. It is what
## guests "read" on the way in; a prop, not a screen. At night a click or tap on
## it opens the menu screen. Stand this node at the middle of that board's slate.

const CHALK := Color("#f6f0e2")
const LINES := 5           # names shown before "and N more"
const WIDTH := 12          # letters that fit across the slate; longer names are cut
const LEAN := 0.22         # the board's lean back from the street (Scenery._outside)

var _text: Label3D
var _head: Label3D
var names: Array[String] = []


func _init() -> void:
	# Face the street (+x) and lean back with the board, just proud of the slate.
	var face := Node3D.new()
	face.basis = Basis(Vector3(0, 0, 1), LEAN) * Basis(Vector3.UP, PI / 2)
	face.position = Vector3(cos(LEAN), sin(LEAN), 0) * 0.02
	add_child(face)
	_head = Label3D.new()
	_head.text = "MENU"
	_chalk(_head, 30)
	_head.position = Vector3(0, 0.2, 0)
	face.add_child(_head)
	_text = Label3D.new()
	_chalk(_text, 21)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.position = Vector3(0, 0.15, 0)
	face.add_child(_text)


func _chalk(l: Label3D, px: int) -> void:
	l.font = Hud.lettering()
	l.font_size = px
	l.pixel_size = 0.0024
	l.outline_size = 0
	l.modulate = CHALK
	l.double_sided = false
	l.line_spacing = -6
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Writes tonight's names: mains, then sides, then drinks.
func refresh(items: Array) -> void:
	names.clear()
	for course in Menu.COURSES:
		for it: Dictionary in items:
			if it.course == course:
				names.append(str(it.name))
	var shown: Array[String] = []
	for n in names.slice(0, LINES if names.size() <= LINES else LINES - 1):
		shown.append(n if n.length() <= WIDTH else n.substr(0, WIDTH - 1).strip_edges() + ".")
	var text := "\n".join(shown)
	if names.size() > shown.size():
		text += "\n+%d more" % (names.size() - shown.size())
	_text.text = text if not names.is_empty() else "closed"


## Whether a point on screen is over the board.
func under(cam: Camera3D, screen: Vector2, within := 40.0) -> bool:
	if cam == null or not is_inside_tree():
		return false
	return cam.unproject_position(global_position).distance_to(screen) < within
