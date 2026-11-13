class_name Title
extends Control
## The placeholder title screen: the peg-doll logo over the room, and Play,
## Settings and Quit on a paper card. Keys and the controller move a framed
## pointer between the buttons (shape as well as colour); touch taps them.
## Quit is left off where quitting is not a thing (phones and the web).

var hud: Hud
var buttons: Array[Button] = []
var sel := 0
var _keys: Label
var _frame: Control


static func can_quit() -> bool:
	return not (OS.has_feature("mobile") or OS.has_feature("web"))


func setup(hud_: Hud) -> void:
	hud = hud_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()   # the room shows through, softened
	dim.color = Color(Hud.SHADOW, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var mid := CenterContainer.new()
	mid.set_anchors_preset(Control.PRESET_FULL_RECT)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mid)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	mid.add_child(col)
	var logo := Logo.new()
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(logo)
	var card := Hud.Sheet.new("paper", 30, 22)
	card.custom_minimum_size = Vector2(360, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	buttons.append(hud._button(box, "Play", press_id.bind("play")))
	buttons.append(hud._button(box, "Settings", press_id.bind("settings")))
	if can_quit():
		buttons.append(hud._button(box, "Quit", press_id.bind("quit")))
	for b in buttons:
		b.add_theme_font_size_override("font_size", 24)
		b.mouse_entered.connect(func() -> void: pick(buttons.find(b)))
	_keys = hud._label(box, 15)
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys.modulate.a = 0.7
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(func() -> void:
		if hud._mode() != "touch" and sel < buttons.size():
			var r := buttons[sel].get_global_rect().grow_individual(14, 6, 10, 6)
			r.position -= _frame.get_global_rect().position
			Hud.pick_frame(_frame, r))
	add_child(_frame)
	refresh()


## Sizes the buttons and rewords the key line for the device in use.
func refresh() -> void:
	var touch := hud._mode() == "touch"
	for b in buttons:
		b.custom_minimum_size.y = 72.0 if touch else 52.0
	_keys.visible = not touch
	_keys.text = "%s choose     %s press     %s settings" % [hud._g("browse"), hud._g("use"), hud._g("options")]
	_frame.queue_redraw()


func _process(_delta: float) -> void:
	_frame.queue_redraw()   # follows the buttons as the layout settles


func pick(i: int) -> void:
	i = clampi(i, 0, buttons.size() - 1)
	if i != sel:
		hud.game.sfx("tick")
	sel = i
	_frame.queue_redraw()


## One key press: up and down choose, E, Space or Enter press. The controller
## sends these too (d-pad, A). Returns whether the key was used.
func key(k: int, echo := false) -> bool:
	if k in [KEY_UP, KEY_W]:
		pick(sel - 1)
	elif k in [KEY_DOWN, KEY_S]:
		pick(sel + 1)
	elif echo:
		return false
	elif k in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		buttons[sel].pressed.emit()
	else:
		return false
	return true


func press_id(id: String) -> void:
	match id:
		"play":
			hud.game.play()
		"settings":
			hud.toggle_options()
		"quit":
			hud.game.quit_game()


## The peg-doll logo (sheet 15, bottom left): chunky gold and orange letters
## with an ink outline, peg heads perched on them, on a teal shield with a
## chequered dome and a wooden rim, and a burger at the foot. The "Town Diner"
## banner is left off: the subtitle is not decided.
class Logo extends Control:
	const TEAL := Color("#3f7f86")
	const TEAL_LIGHT := Color("#6aa7a8")
	const GOLD := Color("#f6c445")
	const ORANGE := Color("#f08b3c")
	const SKIN := Color("#f1c8a0")
	const W := 640.0
	const H := 350.0

	func _init() -> void:
		custom_minimum_size = Vector2(W, H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var burger := Hud.Icon.new("burger", 76, false)
		burger.position = Vector2(W / 2 - 38, H - 92)
		add_child(burger)

	func _draw() -> void:
		var ink := Hud.INK
		# The dome: a chequered teal half-circle behind the slab.
		var c := Vector2(W / 2, 170)
		var r := 150.0
		draw_circle(c + Vector2(0, 8), r + 6, Hud.SHADOW)
		draw_circle(c, r + 4, ink)
		draw_circle(c, r, TEAL)
		var sq := 22.0
		for gy in range(-7, 1):
			for gx in range(-7, 7):
				if (gx + gy) % 2 == 0:
					continue
				var p := c + Vector2(gx * sq, gy * sq)
				var inside := true
				for corner in [Vector2.ZERO, Vector2(sq, 0), Vector2(0, sq), Vector2(sq, sq)]:
					inside = inside and (p + corner).distance_to(c) < r - 16
				if inside:
					draw_rect(Rect2(p, Vector2(sq, sq)), TEAL_LIGHT)
		draw_arc(c, r - 12, 0, TAU, 64, Color(Hud.CREAM, 0.55), 3.0, true)
		# The slab: wood rim under a teal face, both ink-edged.
		var slab := Rect2(18, 136, W - 36, 150)
		Hud.box(self, Rect2(slab.position + Vector2(0, 16), slab.size), Hud.SHADOW, 34)
		Hud.box(self, Rect2(slab.position + Vector2(0, 10), slab.size), Hud.WOOD, 34, 4, ink)
		Hud.box(self, slab, TEAL, 34, 4, ink)
		# The letters, each bobbing a little, gold and orange in turn.
		var font: Font = Hud.lettering()
		var word := "REGULARS"
		var fs := 150
		var widths: Array[float] = []
		var total := 0.0
		for ch in word:
			var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			widths.append(w)
			total += w - 4.0
		var k := minf(1.0, (W - 90.0) / total)
		var x := (W - total * k) / 2.0
		var tops: Array[Vector2] = []
		for i in word.length():
			var bob := sin(i * 1.9) * 7.0
			var tilt := sin(i * 2.3) * 0.07
			var at := Vector2(x + widths[i] * k / 2.0, 262 + bob)
			tops.append(at + Vector2(0, -fs * 0.72 * k))
			draw_set_transform(at, tilt, Vector2(k, k))
			var o := Vector2(-widths[i] / 2.0, 0)
			draw_string_outline(font, o + Vector2(0, 9), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 22, Hud.SHADOW)
			draw_string_outline(font, o, word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 20, ink)
			draw_string(font, o + Vector2(0, 4), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, (GOLD if i % 2 == 0 else ORANGE).darkened(0.18))
			draw_string(font, o, word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD if i % 2 == 0 else ORANGE)
			draw_set_transform(Vector2.ZERO)
			x += (widths[i] - 4.0) * k
		# The regulars on top: the chef, two guests with buns, one in a red cap.
		_head(tops[0] + Vector2(-6, -4), "chef")
		_head(tops[2] + Vector2(-4, -2), "bun")
		_head(tops[3] + Vector2(0, -4), "bun_dark")
		_head(tops[7] + Vector2(-2, -4), "cap")

	func _head(p: Vector2, look: String) -> void:
		var ink := Hud.INK
		var r := 21.0
		if look.begins_with("bun"):
			var hair := Color("#6b3f26") if look == "bun" else Color("#3e2a20")
			draw_circle(p + Vector2(0, -r - 6), 11, ink)
			draw_circle(p + Vector2(0, -r - 6), 8.5, hair)
			draw_circle(p, r + 3, ink)
			draw_circle(p, r, hair)
			draw_circle(p + Vector2(0, 5), r - 3, SKIN)
		else:
			draw_circle(p, r + 3, ink)
			draw_circle(p, r, SKIN)
		for s in [-1, 1]:
			draw_circle(p + Vector2(s * 7, 3), 3.0, ink)
			draw_circle(p + Vector2(s * 12, 10), 4.0, Color(Hud.CORAL, 0.45))
		draw_arc(p + Vector2(0, 8), 6, 0.3, PI - 0.3, 10, ink, 2.0, true)
		if look == "chef":
			for b in [Vector2(-12, -r - 16), Vector2(12, -r - 16), Vector2(0, -r - 24)]:
				draw_circle(p + b, 15, ink)
			for b in [Vector2(-12, -r - 16), Vector2(12, -r - 16), Vector2(0, -r - 24)]:
				draw_circle(p + b, 12, Hud.CREAM)
			Hud.box(self, Rect2(p + Vector2(-18, -r - 8), Vector2(36, 15)), Hud.CREAM, 3, 3, ink)
		elif look == "cap":
			var dome := PackedVector2Array()
			for i in 17:
				dome.append(p + Vector2(0, -4) + Vector2.from_angle(PI + PI * i / 16.0) * (r + 3))
			draw_colored_polygon(dome, ink)
			dome = PackedVector2Array()
			for i in 17:
				dome.append(p + Vector2(0, -4) + Vector2.from_angle(PI + PI * i / 16.0) * r)
			draw_colored_polygon(dome, Color("#d9503f"))
			Hud.box(self, Rect2(p + Vector2(-r - 4, -9), Vector2(2 * r + 20, 9)), Color("#b8402f"), 4, 3, ink)
