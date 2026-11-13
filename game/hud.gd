class_name Hud
extends CanvasLayer
## The paper-and-wood interface (style guide, sheet 14): a wooden day plaque with
## a sun dial, a price-tag for money, a walkout punch-card, keycap prompts, the
## end-of-day receipt on a clipboard and the game-over menu card.

const INK := Color("#3a2c22")
const CREAM := Color("#fff6e6")
const PAPER := Color("#f4ead8")
const CORAL := Color("#ee7560")
const WOOD := Color("#b9824e")
const SHADOW := Color("#5a423a", 0.38)   # plum-brown, never black

var game
var root: Control
var day_label: Label
var sun: SunDial
var toast_sheet: Sheet
var toast: Label
var money: Label
var money_tag: Sheet
var stamps: Array[Icon] = []
var hint: Label
var banner: Sheet
var banner_label: Label
var center: CenterContainer
var prompt: HBoxContainer
var prompt_label: Label
var _shown_money := -1
var _shown_strikes := 0
var _town_open := false
var build_bar: Control
var guest_card: Control
var _guest: Guest
var _guest_state: Label
var _guest_meters := {}
var _guest_thoughts: Label
var _search := ""
var _category := ""
var _search_box: LineEdit
var _tabs: Array[Button] = []
var _cards: HBoxContainer
var _tip: Label
var _level_label: Label
var _toast_tween: Tween


## A wooden-enamel token or a bare icon, drawn from the shared Icons artwork.
class Icon extends Control:
	var id := ""
	var token := true

	func _init(id_: String, px: float, token_ := true) -> void:
		id = id_
		token = token_
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_id(id_: String) -> void:
		id = id_
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		if token:
			draw_circle(c + Vector2(0, r * 0.1), r, Hud.SHADOW)
			draw_circle(c, r, Hud.INK)
			draw_circle(c, r * 0.86, Color("#e9d3ac"))
			draw_circle(c - Vector2(0, r * 0.05), r * 0.8, Hud.PAPER)
			r *= 0.6
		if id == "":
			return
		for l: Array in Icons.icon(id):
			var pts := PackedVector2Array()
			for p: Vector2 in l[0]:
				pts.append(c + Vector2(p.x, -p.y) * r)
			draw_colored_polygon(pts, Color(l[1]))


## Five pips for where a townsperson stands, with an arrow when it moved today.
## Read by count and arrow shape, not by colour.
class Pips extends Control:
	var filled := 0
	var trend := 0

	func _init(filled_: int, trend_: int) -> void:
		filled = filled_
		trend = trend_
		custom_minimum_size = Vector2(92, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y / 2.0
		for i in 5:
			var c := Vector2(7 + i * 14, y)
			draw_circle(c, 6.0, Hud.INK)
			draw_circle(c, 4.2, Hud.CORAL if i < filled else Hud.PAPER)
		if trend != 0:
			var x := 82.0
			var d := -float(trend)   # up is negative y
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y + d * 7), Vector2(x - 6, y - d * 3), Vector2(x + 6, y - d * 3)]), Hud.INK)


## A meter read by its length: an ink-rimmed trough with a filled bar.
class Meter extends Control:
	var value := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(110, 14)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Hud.INK)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Hud.PAPER)
		draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4) * clampf(value, 0.0, 1.0), size.y - 4)), Hud.CORAL)


## The day timer: the sun crosses the sky over a cream dial.
class SunDial extends Control:
	var progress := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(72, 72)

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x / 2.0
		draw_circle(c, r, Hud.INK)
		draw_circle(c, r - 4, Hud.CREAM)
		var a0 := deg_to_rad(200.0)
		var a1 := deg_to_rad(340.0)
		var arc_c := c + Vector2(0, r * 0.28)
		draw_arc(arc_c, r * 0.62, a0, a1, 24, Color(Hud.INK, 0.2), 5.0, true)
		var a := lerpf(a0, a1, progress)
		draw_arc(arc_c, r * 0.62, a0, a, 24, Color("#f2b632"), 5.0, true)
		draw_line(c + Vector2(-r * 0.7, r * 0.38), c + Vector2(r * 0.7, r * 0.38), Hud.INK, 3.0, true)
		var at := arc_c + Vector2(cos(a), sin(a)) * r * 0.62
		for l: Array in Icons.icon("sun"):
			var pts := PackedVector2Array()
			for p: Vector2 in l[0]:
				pts.append(at + Vector2(p.x, -p.y) * r * 0.3)
			draw_colored_polygon(pts, Color(l[1]))


## A piece of paper or wood that holds other controls.
class Sheet extends MarginContainer:
	var kind := "paper"
	var tint := Hud.CORAL

	func _init(kind_: String, mx := 14, my := 10) -> void:
		kind = kind_
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side: String in ["left", "right"]:
			add_theme_constant_override("margin_" + side, mx)
		for side: String in ["top", "bottom"]:
			add_theme_constant_override("margin_" + side, my)
		resized.connect(queue_redraw)

	func pad(left: int, top: int, right: int, bottom: int) -> Sheet:
		add_theme_constant_override("margin_left", left)
		add_theme_constant_override("margin_top", top)
		add_theme_constant_override("margin_right", right)
		add_theme_constant_override("margin_bottom", bottom)
		return self

	func _box(r: Rect2, col: Color, radius: int, border := 0, border_col := Hud.INK) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(radius)
		sb.set_border_width_all(border)
		sb.border_color = border_col
		sb.anti_aliasing = true
		draw_style_box(sb, r)

	func _wood(r: Rect2, radius := 12) -> void:
		_box(Rect2(r.position + Vector2(0, 6), r.size), Hud.SHADOW, radius)
		_box(r, Hud.INK, radius)
		var inner := r.grow(-4)
		_box(inner, Hud.WOOD.darkened(0.14), radius - 3)                 # the 3 cm bevel: dark foot,
		_box(Rect2(inner.position, inner.size - Vector2(0, 5)), Hud.WOOD.lightened(0.16), radius - 3)  # light lip,
		_box(Rect2(inner.position + Vector2(0, 4), inner.size - Vector2(0, 9)), Hud.WOOD, radius - 4)  # flat face

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		match kind:
			"wood":
				_wood(r)
			"clip":
				_wood(r, 16)
				var cw := 150.0
				_box(Rect2(size.x / 2 - cw / 2, -12, cw, 46), Color("#8f989a"), 8, 3, Hud.INK)
				_box(Rect2(size.x / 2 - 22, -24, 44, 26), Color("#8f989a"), 12, 3, Hud.INK)
			"paper":
				_box(Rect2(r.position + Vector2(0, 4), r.size), Hud.SHADOW, 6)
				_box(r, Hud.CREAM, 6)
			"label":
				_box(Rect2(r.position + Vector2(0, 3), r.size), Hud.SHADOW, 5)
				_box(r, Hud.CREAM, 5, 2, Hud.INK)
			"inset":
				_box(r, Hud.PAPER, 5, 2, Color(Hud.INK, 0.5))
			"key":
				_box(Rect2(r.position + Vector2(0, 5), r.size), Hud.SHADOW, 9)
				_box(r, Color("#cbbfa8"), 9, 2, Hud.INK)
				_box(Rect2(r.position + Vector2(4, 3), r.size - Vector2(8, 11)), Hud.CREAM, 7)
			"tag":  # a price tag: pointed end with a punched hole
				var nose := 22.0
				var shape := PackedVector2Array([Vector2(nose, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(nose, size.y), Vector2(0, size.y / 2)])
				var shadow := PackedVector2Array()
				for p in shape:
					shadow.append(p + Vector2(0, 4))
				draw_colored_polygon(shadow, Hud.SHADOW)
				draw_colored_polygon(shape, Hud.CREAM)
				draw_polyline(shape + PackedVector2Array([shape[0]]), Hud.INK, 2.0, true)
				draw_circle(Vector2(nose, size.y / 2), 5, Hud.INK)
				draw_line(Vector2(nose, size.y / 2), Vector2(nose + 10, -18), Hud.INK, 2.0, true)
			"receipt":  # torn at the bottom
				var shape := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0)])
				var teeth := int(size.x / 16.0)
				for i in teeth + 1:
					var x := size.x - i * size.x / teeth
					shape.append(Vector2(x, size.y - (10.0 if i % 2 else 0.0)))
				var shadow := PackedVector2Array()
				for p in shape:
					shadow.append(p + Vector2(0, 5))
				draw_colored_polygon(shadow, Hud.SHADOW)
				draw_colored_polygon(shape, Hud.CREAM)
			"note":  # the pinned gossip note
				_box(Rect2(r.position + Vector2(0, 4), r.size), Hud.SHADOW, 2)
				_box(r, Color("#ffe58a"), 2)
				draw_circle(Vector2(size.x / 2, 6), 8, Hud.INK)
				draw_circle(Vector2(size.x / 2, 5), 6, Hud.CORAL)
			"ribbon":
				var n := 14.0
				draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x - n, size.y / 2), Vector2(size.x, size.y), Vector2(0, size.y), Vector2(n, size.y / 2)]), tint)
			"menu":  # a folded, coral-trimmed menu card with a curled corner
				_box(Rect2(r.position + Vector2(0, 7), r.size), Hud.SHADOW, 10)
				_box(r, Hud.CORAL, 10, 3, Hud.INK)
				_box(r.grow(-10), Hud.CREAM, 5)
				_box(r.grow(-16), Hud.CREAM, 3, 2, Color(Hud.CORAL, 0.6))
				draw_line(Vector2(size.x / 2, 12), Vector2(size.x / 2, size.y - 12), Color(Hud.INK, 0.07), 3.0)
				var k := 34.0
				draw_colored_polygon(PackedVector2Array([Vector2(size.x - 10 - k, size.y - 10), Vector2(size.x - 10, size.y - 10 - k), Vector2(size.x - 10 - k, size.y - 10 - k)]), Hud.PAPER.darkened(0.12))


func setup(game_) -> void:
	game = game_
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)

	# Top left: the wooden day plaque with its sun dial, and the money tag below.
	var left := VBoxContainer.new()
	left.position = Vector2(22, 18)
	left.add_theme_constant_override("separation", 14)
	root.add_child(left)
	var plaque := Sheet.new("wood", 14, 12)
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(plaque)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	plaque.add_child(prow)
	sun = SunDial.new()
	prow.add_child(sun)
	var day_paper := Sheet.new("inset", 16, 4)
	day_paper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(day_paper)
	day_label = _label(day_paper, 34)
	money_tag = Sheet.new("tag").pad(38, 6, 16, 6)
	money_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(money_tag)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	money_tag.add_child(mrow)
	mrow.add_child(Icon.new("coin", 34, false))
	money = _label(mrow, 34)
	toast_sheet = Sheet.new("paper", 14, 6)
	toast_sheet.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast_sheet.modulate.a = 0.0
	left.add_child(toast_sheet)
	toast = _label(toast_sheet, 18)

	# Top right: the walkout punch-card. Each walkout stamps a red angry face.
	var card := Sheet.new("label", 16, 10)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -246
	card.offset_right = -22
	card.offset_top = 18
	root.add_child(card)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 4)
	card.add_child(cbox)
	_label(cbox, 15, "WALKOUTS").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 12)
	cbox.add_child(slots)
	for i in Ledger.MAX_STRIKES:
		var slot := Sheet.new("inset", 4, 4)
		slots.add_child(slot)
		var stamp := Icon.new("", 46, false)
		slot.add_child(stamp)
		stamps.append(stamp)

	hint = _label(root, 15)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 24
	hint.offset_top = -40
	hint.modulate.a = 0.75
	hint.text = "WASD move     E or Space use     Click a guest     M mute"

	# The keycap prompt that floats over the station the chef faces.
	prompt = HBoxContainer.new()
	prompt.add_theme_constant_override("separation", 6)
	prompt.visible = false
	root.add_child(prompt)
	var key := Sheet.new("key", 13, 4).pad(13, 3, 13, 9)
	prompt.add_child(key)
	_label(key, 22, "E")
	var tag := Sheet.new("label", 12, 4)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt.add_child(tag)
	prompt_label = _label(tag, 20)

	var banner_box := CenterContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_box)
	banner = Sheet.new("wood", 26, 20)
	banner.modulate.a = 0.0
	banner_box.add_child(banner)
	var banner_paper := Sheet.new("inset", 40, 6)
	banner.add_child(banner_paper)
	banner_label = _label(banner_paper, 84)

	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)


static func _flat(col: Color, radius: int, margin := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func _stamp_button(col: Color) -> StyleBoxFlat:
	var sb := _flat(col, 10, 12)
	sb.border_color = col.darkened(0.25)
	sb.border_width_bottom = 5
	sb.shadow_color = SHADOW
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _theme() -> Theme:
	var t := Theme.new()
	# A chunky rounded face where the system has one. (A bundled hand-lettered
	# font is still to be chosen.)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Nunito", "Varela Round", "Verdana"])
	font.font_weight = 700
	t.default_font = font
	t.set_color("font_color", "Label", INK)   # dark brown ink for all text
	t.set_stylebox("normal", "Button", _stamp_button(CORAL))
	t.set_stylebox("hover", "Button", _stamp_button(CORAL.lightened(0.1)))
	t.set_stylebox("pressed", "Button", _stamp_button(CORAL.darkened(0.12)))
	t.set_stylebox("disabled", "Button", _stamp_button(Color("#c9b9a3")))
	t.set_color("font_disabled_color", "Button", CREAM)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var field := _flat(CREAM, 8, 8)
	field.border_color = INK
	field.set_border_width_all(2)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.45))
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_hover_pressed_color", "Button", CREAM)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", CREAM)
	t.set_font_size("font_size", "Button", 20)
	return t


func _label(parent: Node, font_size: int, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


const STATE_WORDS := {"queue": "Queueing outside", "to_seat": "Finding a seat", "waiting": "Waiting for food",
	"eating": "Eating", "leaving": "Leaving"}


## The guest card (click a guest): who they are, how they feel and what they have
## thought so far. Pass null to close it.
func show_guest(g: Guest) -> void:
	if guest_card:
		guest_card.queue_free()
		guest_card = null
	_guest = g
	if g == null:
		return
	var card := Sheet.new("label", 16, 12)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -246
	card.offset_right = -22
	card.offset_top = 132
	root.add_child(card)
	guest_card = card
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)
	_label(box, 24, g.info.name)
	var town: Town = game.town
	var who := "Back after a grudge" if g.info.sore else town.status_word(g.idx, game.ledger.day)
	var standing := _label(box, 13, "%s  ·  visit %d" % [who, int(g.info.visits) + 1])
	standing.modulate.a = 0.7
	_guest_state = _label(box, 15)
	_guest_meters.clear()
	for id: String in ["patience", "joy", "savour", "disgust"]:
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := _label(row, 14, id.capitalize())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m := Meter.new()
		row.add_child(m)
		_guest_meters[id] = m
	_rule(box)
	_guest_thoughts = _label(box, 13)
	_guest_thoughts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guest_thoughts.custom_minimum_size = Vector2(190, 0)
	_update_guest()


func _update_guest() -> void:
	if guest_card == null or not is_instance_valid(_guest):
		return
	var m: GuestMood = _guest.mood
	_guest_state.text = STATE_WORDS.get(_guest.state, "")
	for id: String in _guest_meters:
		_guest_meters[id].value = float(m.get(id))
		_guest_meters[id].queue_redraw()
	var lines: Array[String] = []
	for t in m.thoughts.slice(-6):
		lines.append("\"%s\"" % t)
	lines.reverse()   # newest first
	_guest_thoughts.text = "No thoughts yet." if lines.is_empty() else "\n".join(lines)


func update_status() -> void:
	_update_guest()
	var l: Ledger = game.ledger
	# After closing the books the ledger is already on tomorrow; keep showing the day just played.
	day_label.text = "DAY %d" % (l.day - 1 if game.phase == game.Phase.SUMMARY else l.day)
	sun.progress = game.day_progress()
	sun.queue_redraw()
	if l.money != _shown_money:
		if _shown_money >= 0 and l.money > _shown_money:
			money_tag.pivot_offset = money_tag.size * Vector2(0.0, 0.5)
			money_tag.scale = Vector2(1.25, 1.25)
			money_tag.create_tween().tween_property(money_tag, "scale", Vector2.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_shown_money = l.money
		money.text = "$%d" % l.money
	var strikes := l.strikes()
	if strikes != _shown_strikes:
		for i in stamps.size():
			stamps[i].set_id("walkout" if i < strikes else "")
			if i < strikes and i >= _shown_strikes:  # the stamp slams into the next slot
				stamps[i].pivot_offset = stamps[i].size / 2.0
				stamps[i].scale = Vector2(2.4, 2.4)
				stamps[i].rotation = randf_range(-0.3, 0.3)
				stamps[i].create_tween().tween_property(stamps[i], "scale", Vector2.ONE, 0.22) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_shown_strikes = strikes


## Shows "[E] COOK" over a point on screen, or hides it when `text` is empty.
func show_prompt(at: Vector2, text: String) -> void:
	prompt.visible = text != ""
	if text != "":
		prompt_label.text = text.to_upper()
		prompt.reset_size()
		prompt.position = (at - Vector2(prompt.size.x / 2.0, prompt.size.y)).round()
		prompt.position.y = maxf(prompt.position.y, 6.0)  # never off the top of the screen


func say(s: String) -> void:
	toast.text = s
	toast_sheet.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = toast_sheet.create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(toast_sheet, "modulate:a", 0.0, 0.8)


func show_banner(s: String) -> void:
	banner_label.text = s.to_upper()
	banner.modulate.a = 0.0
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(0.9)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)


func hide_card() -> void:
	for c in center.get_children():
		center.remove_child(c)
		c.queue_free()


func _pop_in(panel: Control) -> void:
	panel.pivot_offset = Vector2(240, 200)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)


func _ribbon(box: VBoxContainer, text: String, col: Color) -> void:
	var ribbon := Sheet.new("ribbon", 30, 6)
	ribbon.tint = col
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ribbon)
	var l := _label(ribbon, 26, text)
	l.add_theme_color_override("font_color", CREAM)


func _row(box: VBoxContainer, icon: String, title: String, value: String, font := 22) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	if icon != "":
		row.add_child(Icon.new(icon, font + 10))
	var l := _label(row, font, title)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _label(row, font, value)


func _rule(box: VBoxContainer) -> void:
	var l := _label(box, 14, "- ".repeat(34))
	l.clip_text = true
	l.modulate.a = 0.45


func _button(box: Container, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE   # so Enter always means "carry on"
	b.pressed.connect(action)
	box.add_child(b)
	return b


## End of day: a torn diner receipt on a wooden clipboard, with the town gossip
## pinned beside it.
func show_summary(rec: Dictionary, animate := true) -> void:
	hide_card()
	_town_open = false
	var clip := Sheet.new("clip").pad(26, 46, 26, 26)
	center.add_child(clip)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	clip.add_child(stack)
	var receipt := Sheet.new("receipt").pad(30, 22, 30, 34)
	receipt.custom_minimum_size = Vector2(430, 0)
	stack.add_child(receipt)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	receipt.add_child(box)
	_ribbon(box, "END OF DAY %d" % rec.day, CORAL)
	_row(box, "food", "Meals served", str(rec.served))
	_row(box, "coin", "Sales", "$%d" % rec.sales)
	_row(box, "tip", "Tips", "$%d" % rec.tips)
	_row(box, "walkout", "Walkouts", str(rec.walkouts))
	_rule(box)
	var earned: int = rec.sales + rec.tips
	var total := _row(box, "", "Earned today", "$%d" % earned, 30)
	if animate:
		total.create_tween().tween_method(func(v: float) -> void: total.text = "$%d" % roundi(v), 0.0, float(earned), 0.9) \
		.set_delay(0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_row(box, "", "In the bank", "$%d" % game.ledger.money)
	var note := Sheet.new("note").pad(16, 18, 16, 10)
	note.rotation = -0.02
	stack.add_child(note)
	var gossip := _label(note, 16, game.town.headline())
	gossip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gossip.custom_minimum_size = Vector2(380, 0)
	if game.flyers_out:
		_row(box, "star", "Flyers for tomorrow", "paid")
	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 12)
	stack.add_child(extras)
	var flyers := _button(extras, "Flyers  $%d   (F)" % Town.FLYER_PRICE, game.buy_flyers)
	flyers.disabled = game.flyers_out or game.ledger.money < Town.FLYER_PRICE
	flyers.tooltip_text = "More guests tomorrow."
	if game.flyers_out:
		flyers.text = "Flyers are out"
	_button(extras, "Town book   (T)", show_town)
	_button(stack, "Build, then day %d   (Enter)" % game.ledger.day, game.open_build)
	if animate:
		_pop_in(clip)


func hide_build() -> void:
	if build_bar:
		build_bar.queue_free()
		build_bar = null
	hint.visible = true


func set_search(text: String) -> void:
	_search = text
	if _search_box and _search_box.text != text:
		_search_box.text = text
	_refresh_catalog()


func _set_category(cat: String) -> void:
	_category = cat
	_refresh_catalog()


## The build phase: a wooden tray along the bottom holding the catalog. Search it,
## browse by category, pick a card, then click the floor. Built once per night;
## later calls only redraw the cards.
func show_build() -> void:
	if build_bar:
		_refresh_catalog()
		return
	hint.visible = false
	_search = ""
	_category = ""
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_bottom", 14)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	build_bar = holder
	var wood := Sheet.new("wood", 10, 10)
	wood.mouse_filter = Control.MOUSE_FILTER_STOP
	wood.size_flags_vertical = Control.SIZE_SHRINK_END
	wood.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(wood)
	var paper := Sheet.new("paper", 16, 10)
	paper.custom_minimum_size = Vector2(900, 0)
	wood.add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	paper.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	_label(top, 20, "CATALOG")
	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search..."
	_search_box.custom_minimum_size = Vector2(190, 0)
	_search_box.add_theme_font_size_override("font_size", 16)
	_search_box.text_changed.connect(set_search)
	_search_box.text_submitted.connect(func(_t: String) -> void: _search_box.release_focus())
	top.add_child(_search_box)
	_tabs.clear()
	for cat: String in [""] + Catalog.CATEGORIES:
		var tab := _button(top, "All" if cat == "" else cat, _set_category.bind(cat))
		tab.add_theme_font_size_override("font_size", 15)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.toggle_mode = true
		tab.set_meta("cat", cat)
		_tabs.append(tab)
	_level_label = _label(top, 15)
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_label.modulate.a = 0.75

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 86)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	scroll.add_child(_cards)

	var last := HBoxContainer.new()
	last.add_theme_constant_override("separation", 14)
	box.add_child(last)
	_tip = _label(last, 15)
	_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip.modulate.a = 0.8
	_button(last, "Open for day %d   (Enter)" % game.ledger.day, game.start_day).size_flags_horizontal = Control.SIZE_SHRINK_END
	_refresh_catalog()


func _refresh_catalog() -> void:
	if build_bar == null:
		return
	var cat: Catalog = game.catalog
	var l: Ledger = game.ledger
	var into := float(l.xp % Ledger.XP_PER_LEVEL) / Ledger.XP_PER_LEVEL
	_level_label.text = "Level %d   (%d%% to the next)" % [l.level(), roundi(into * 100)]
	for tab in _tabs:
		tab.set_pressed_no_signal(tab.get_meta("cat") == _category)
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var found := Catalog.search(_search, _category)
	for bp in found:
		var id: String = bp.id
		var tier: int = bp.tier
		var held: bool = game.hand.get("id", "") == id and int(game.hand.get("tier", 0)) == tier
		var locked := l.level() < Catalog.level_of(id, tier)
		var line := "Level %d" % Catalog.level_of(id, tier) if locked else "$%d" % Catalog.price_of(id, tier)
		var card := _button(_cards, "%s\n%s" % [Catalog.label(bp), line], game.pick_catalog.bind(id, tier))
		card.add_theme_font_size_override("font_size", 15)
		card.custom_minimum_size = Vector2(150, 70)
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.tooltip_text = Catalog.blurb_of(id, tier)
		card.disabled = not cat.can_buy(id, l.money, l.level(), tier)
		card.toggle_mode = true
		card.set_pressed_no_signal(held)   # the piece in hand sits pressed in
	if found.is_empty():
		_label(_cards, 16, "Nothing in the catalog matches.").modulate.a = 0.7
	if game.hand.is_empty():
		_tip.text = "Pick something, then click the floor to place it."
	else:
		_tip.text = "%s: %s  Right-click or Esc puts it back." % [
			Catalog.label(game.hand), Catalog.blurb_of(game.hand.id, int(game.hand.tier))]


func toggle_town() -> void:
	if _town_open:
		show_summary(game.last_day)
	else:
		show_town()


## The town book: every townsperson, where they stand and whether today moved them.
func show_town() -> void:
	hide_card()
	_town_open = true
	var clip := Sheet.new("clip").pad(26, 46, 26, 26)
	center.add_child(clip)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	clip.add_child(stack)
	var page := Sheet.new("note").pad(26, 24, 26, 20)
	stack.add_child(page)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	page.add_child(box)
	_ribbon(box, "THE TOWN", INK)
	var town: Town = game.town
	var cols := GridContainer.new()
	cols.columns = 2
	cols.add_theme_constant_override("h_separation", 34)
	cols.add_theme_constant_override("v_separation", 7)
	box.add_child(cols)
	# Fill down the two columns, not across.
	var half := ceili(town.people.size() / 2.0)
	for n in town.people.size():
		var i := (n / 2) + (half if n % 2 == 1 else 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		cols.add_child(row)
		var name_label := _label(row, 18, town.people[i].name)
		name_label.custom_minimum_size = Vector2(86, 0)
		row.add_child(Pips.new(town.standing(i) + 1, town.trend(i)))
		var word := _label(row, 13, town.status_word(i, game.ledger.day))
		word.custom_minimum_size = Vector2(150, 0)
		word.modulate.a = 0.7
	_rule(box)
	var key := _label(box, 13, "Arrows show who changed their mind today. Friends talk to each other.")
	key.modulate.a = 0.7
	_button(stack, "Back   (T)", toggle_town)
	_pop_in(clip)


## Game over: a folded, coral-trimmed menu card.
func show_closed(days: int, earned: int, best: Dictionary, is_record: bool) -> void:
	hide_card()
	var menu := Sheet.new("menu").pad(40, 34, 40, 40)
	menu.custom_minimum_size = Vector2(480, 0)
	center.add_child(menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	menu.add_child(box)
	_ribbon(box, "CLOSED DOWN", INK)
	var why := _label(box, 17, "Three guests walked out in one day.")
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.modulate.a = 0.75
	_row(box, "sun", "Days survived", str(days), 26)
	_row(box, "coin", "Total earned", "$%d" % earned, 26)
	if is_record:
		_row(box, "star", "New best run!", "", 26)
	else:
		_row(box, "star", "Best run", "%d days, $%d" % [best.days, best.earned], 20)
	_button(box, "Try again   (Enter)", game.restart)
	_pop_in(menu)
