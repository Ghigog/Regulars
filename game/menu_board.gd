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
var glow: MeshInstance3D       # warm halo behind the slate, like the door card's
var _glow_on := false
var _glow_bright := true
var _glow_tween: Tween
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
	_build_glow(face)


## Same build as GameDay._build_door_glow: radial fade, unshaded, additive, no shadow.
func _build_glow(face: Node3D) -> void:
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color(Build.WARN, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.95, 1.0)
	quad.material = mat
	glow = MeshInstance3D.new()
	glow.mesh = quad
	glow.position = Vector3(0, 0.02, -0.04)   # behind the slate: it rims the board
	glow.visible = false
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.add_child(glow)


## Starts, retunes or stops the halo (called every frame by HudBoardKey).
## `want`: build phase; `bright`: no main yet, so it breathes brighter.
func update_glow(want: bool, bright: bool) -> void:
	if want == _glow_on and (not want or bright == _glow_bright):
		return
	_glow_on = want
	_glow_bright = bright
	if _glow_tween:
		_glow_tween.kill()
	var mat := glow.mesh.material as StandardMaterial3D
	_glow_tween = glow.create_tween()
	if want:
		var hi := 0.55 if bright else 0.3
		var lo := 0.22 if bright else 0.1
		glow.visible = true
		_glow_tween.tween_property(mat, "albedo_color:a", hi, 0.5)
		_glow_tween.set_loops()
		_glow_tween.tween_property(mat, "albedo_color:a", lo, 1.0).set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_property(mat, "albedo_color:a", hi, 1.0).set_trans(Tween.TRANS_SINE)
	else:
		_glow_tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
		_glow_tween.tween_callback(func() -> void: glow.visible = false)


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
