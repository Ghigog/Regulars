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
const KRAFT := Color("#e6cfa6")


## The hand-lettered face of the interface sheets (Patrick Hand, open licence).
static func lettering() -> Font:
	return load("res://assets/fonts/PatrickHand-Regular.ttf")

var game
var root: Control
var calendar: Calendar
var clock: Clock
var dangle: Dangle
var board: Board
var fly: Control   # props in flight draw over everything else
var _shown_phase := -1
var _turning := false
var _tag_state := "hang"   # hang, fly, receipt or fall
var _tag_tween: Tween
var _summary_clip: Control
var toast_sheet: Sheet
var toast: Label
var money: Label
var money_tag: Sheet
var stamps: Array[Punch] = []
var hint: Label
var ticket_rail: HBoxContainer
const RAIL_MAX := 5   # tickets shown on the rail; more are counted on a last tab
var banner: Sheet
var banner_label: Label
var center: CenterContainer
var prompt: Control
var prompt_label: Label
var last_action := ""      # the word on the prompt, for the touch Use button
var _prompt_key: Control
var _prompt_key_label: Label
var _shop_keys: Label
var _shown_money := -1
var _shown_strikes := 0
var _town_open := false
var build_bar: Control
var guest_card: Control
var _guest: Guest
var _guest_state: Label
var _guest_bill: Label   # what a served guest is paying (mood scales it)
var _guest_meters := {}
var _guest_thoughts: Label
var _search := ""
var _category := ""
var _search_box: LineEdit
var _tabs: Array[Button] = []
var _cards: Control
var _tip: Label
var _dirty_note: Control   # build phase: "Still dirty: ..." with a stink cloud, over the slip
var _dirty_label: Label
var menu: MenuScreen           # the menu screen, while it is open
var menu_notes: MenuScreen.BuildNotes   # night zero's hint and the restock note, over the slip
var _shop: Control             # the shop's sliding tray; null while the shop is shut
var _info: Label
var _info_blurb: Label
var _shop_items: Array[Dictionary] = []
var _shop_index := 0
var _items: Array[Control] = []      # one per piece in the row, laid out by _lay_out
var _views: Array[ModelView] = []
var _row_pos := 0.0                  # which piece is in the middle; fractional while sliding
var _row_tween: Tween
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


## One slot on the walkout card: a dashed circle that a rubber stamp marks in
## red. The ink is wet at first, creeps a little, then dries darker and matte.
class Punch extends Icon:
	var wet := 0.0
	var _age := 0.0
	var _smear := Vector2.ZERO
	var _seed := 0

	func _init(px: float) -> void:
		super("", px, false)

	func stamp() -> void:
		id = "walkout"
		wet = 1.0
		_age = 0.0
		_smear = Vector2.ZERO
		_seed = randi()
		pivot_offset = size / 2.0
		rotation = randf_range(-0.3, 0.3)
		queue_redraw()

	func _process(delta: float) -> void:
		if wet <= 0.0:
			return
		_age += delta
		wet = maxf(0.0, wet - delta / 2.4)
		_smear = Vector2(sin(_age * 5.0) * 1.3, (1.0 - cos(_age * 3.6)) * 0.9) * minf(1.0, _age * 3.0)
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		for i in 14:
			var a0 := TAU * i / 14.0
			draw_arc(c, r, a0, a0 + TAU / 14.0 * 0.55, 4, Color(Hud.INK, 0.45), 2.0, true)
		if id == "":
			return
		var col := Color("#b5352e", 0.86).lerp(Color("#ec4a3e"), wet)
		var o := c + _smear
		draw_arc(o, r * 0.96, 0, TAU, 40, Color(col, col.a * 0.25 * wet), 7.0, true)   # ink still spreading
		draw_arc(o, r * 0.96, 0, TAU, 40, col, 4.0, true)
		draw_arc(o, r * 0.78, 0, TAU, 40, Color(col, col.a * 0.55), 1.5, true)
		for sx: float in [-1.0, 1.0]:  # brows, eyes and a frown, stamped in one colour
			draw_line(o + Vector2(sx * r * 0.5, -r * 0.34), o + Vector2(sx * r * 0.12, -r * 0.14), col, 3.5, true)
			draw_circle(o + Vector2(sx * r * 0.28, -r * 0.02), r * 0.085, col)
		draw_arc(o + Vector2(0, r * 0.52), r * 0.3, PI * 1.15, PI * 1.85, 10, col, 3.5, true)
		var rng := RandomNumberGenerator.new()   # rubber texture: gaps in the ink, specks round the edge
		rng.seed = _seed
		for i in 30:
			var p := o + Vector2.from_angle(rng.randf() * TAU) * r * sqrt(rng.randf()) * 1.02
			draw_circle(p, rng.randf_range(0.6, 1.8), Hud.CREAM)
		for i in 8:
			var p := o + Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(1.04, 1.14)
			draw_circle(p, rng.randf_range(0.5, 1.3), col)
		if wet > 0.0:   # a wet sheen
			draw_arc(o, r * 0.9, PI * 1.1, PI * 1.45, 10, Color(1, 1, 1, 0.5 * wet), 2.0, true)


## Five pips for where a townsperson stands, with an arrow when it moved today.
## Read by count and arrow shape, not by colour.
## A ticket's ingredient marks: a ring per ingredient, filled with a tick once it is
## on the ticket's tray. Read live from the game, so they tick off as the chef works.
class Marks extends Control:
	var game
	var ticket := -1
	var line := 0
	var count := 0

	func _init(game_, ticket_: int, line_: int, count_: int) -> void:
		game = game_
		ticket = ticket_
		line = line_
		count = count_
		custom_minimum_size = Vector2(count * 15, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t: Tray = game.tray_for_ticket(ticket)
		for k in count:
			var c := Vector2(7 + k * 15, 8)
			var have := t != null and line < t.lines.size() and float(t.lines[line].have[k]) >= 0.0
			draw_circle(c, 6.5, Hud.INK)
			draw_circle(c, 4.5, Color("#6fcf97") if have else Hud.PAPER)
			if have:   # a tick, so a done mark differs by shape as well as colour
				draw_polyline(PackedVector2Array([c + Vector2(-3, 0), c + Vector2(-1, 2.5), c + Vector2(3.5, -3)]), Hud.INK, 2.0)


## The face on a ticket: a token in the guest's shirt colour with their initial.
class Face extends Control:
	var col := Color.WHITE
	var letter := ""

	func _init(col_: Color, letter_: String) -> void:
		col = col_
		letter = letter_
		custom_minimum_size = Vector2(28, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(Vector2(14, 15), 13, Hud.SHADOW)
		draw_circle(Vector2(14, 14), 13, Hud.INK)
		draw_circle(Vector2(14, 14), 10.5, col)
		var f := Hud.lettering()
		draw_string(f, Vector2(14 - f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x / 2, 20), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Hud.CREAM)


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


## Draws a rounded box on any canvas item.
static func box(ci: CanvasItem, r: Rect2, col: Color, radius: int, border := 0, border_col := INK) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


## The day: a square desk calendar on a wooden back with two binder rings.
## `flip` turns the top page over its top edge to show `next_day` beneath it;
## `lift` raises it off the desk while its shadow stays where it was.
class Calendar extends Control:
	const SIDE := 100.0
	var day := 0:
		set(v):
			day = v
			queue_redraw()
	var next_day := 0
	var flip := 0.0:
		set(v):
			flip = v
			queue_redraw()
	var lift := 0.0:
		set(v):
			lift = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(SIDE, SIDE)
		size = custom_minimum_size
		pivot_offset = Vector2(SIDE / 2.0, SIDE)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Where the money tag's string is tied, on screen.
	func knot() -> Vector2:
		return get_global_transform() * Vector2(SIDE / 2.0, SIDE - 6.0 - lift)

	func _page(o: Vector2, n: int, sy: float) -> void:
		var pr := Rect2(8, 0, SIDE - 16, SIDE - 22)
		draw_set_transform(o + Vector2(0, 13), 0.0, Vector2(1, sy))
		if sy < 0.0:   # the back of the page as it goes over the top
			draw_rect(pr, Hud.INK)
			draw_rect(pr.grow(-2), Hud.PAPER.darkened(0.08))
		else:
			Hud.box(self, pr, Hud.INK, 6)
			Hud.box(self, pr.grow(-2), Hud.CREAM, 5)
			var head := Rect2(pr.position + Vector2(2, 2), Vector2(pr.size.x - 4, 24))
			Hud.box(self, head, Hud.CORAL, 5)
			draw_rect(Rect2(head.position + Vector2(0, 14), Vector2(head.size.x, 10)), Hud.CORAL)
			var f := Hud.lettering()
			draw_string(f, Vector2(pr.position.x, 21), "DAY", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 19, Hud.CREAM)
			draw_string(f, Vector2(pr.position.x, pr.size.y - 9), str(n), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 50, Hud.INK)
		draw_set_transform(Vector2.ZERO)

	func _draw() -> void:
		# A soft shadow that stays on the desk: fainter and wider the higher it goes.
		var fade := 1.0 / (1.0 + lift / 10.0)
		for i in 3:
			var g := 2.0 + i * 3.0 + lift * 0.12
			Hud.box(self, Rect2(Vector2(-g, 6.0 - g + lift * 0.15), Vector2(SIDE + g * 2.0, SIDE + g * 2.0)),
				Color(Hud.SHADOW, Hud.SHADOW.a * 0.4 * fade), int(10 + g))
		var o := Vector2(0, -lift)
		Hud.box(self, Rect2(o, Vector2(SIDE, SIDE)), Hud.INK, 10)
		Hud.box(self, Rect2(o + Vector2(3, 3), Vector2(SIDE - 6, SIDE - 6)), Hud.WOOD.darkened(0.12), 8)
		Hud.box(self, Rect2(o + Vector2(3, 3), Vector2(SIDE - 6, SIDE - 10)), Hud.WOOD, 8)
		for i in 2:   # the edges of the pages still to come
			draw_line(o + Vector2(10, SIDE - 7 + i * 2), o + Vector2(SIDE - 10, SIDE - 7 + i * 2), Hud.PAPER.darkened(0.15 + i * 0.1), 1.5)
		_page(o, next_day if flip > 0.0 else day, 1.0)
		if flip > 0.0:
			var sy := cos(flip * PI)
			if absf(sy) > 0.03:
				_page(o, day, sy)
		for x: float in [SIDE * 0.3, SIDE * 0.7]:   # binder rings
			draw_arc(o + Vector2(x, 10), 7, PI * 0.95, PI * 2.05, 14, Hud.INK, 5.0, true)
			draw_arc(o + Vector2(x, 10), 7, PI * 0.95, PI * 2.05, 14, Color("#c9c2b6"), 2.5, true)


## The day timer: a wooden clock. Service runs from eight in the morning to
## eight at night; a little window at the top shows the sun crossing the sky,
## or the moon after closing. It rolls like a wheel when it moves.
class Clock extends Control:
	const R := 40.0
	const NIGHT := Color("#2f3e63")
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()
	var night := false:
		set(v):
			night = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(R * 2.0, R * 2.0)
		size = custom_minimum_size
		pivot_offset = Vector2(R, R)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(R, R)
		var down := Vector2(0, 1).rotated(-rotation)   # light and shadow stay put while it rolls
		draw_circle(c + down * 5.0, R, Hud.SHADOW)
		draw_circle(c, R, Hud.INK)
		draw_circle(c, R - 3, Hud.WOOD.darkened(0.12))
		draw_circle(c - down * 2.0, R - 4, Hud.WOOD)
		var face := R - 9.0
		draw_circle(c, face + 2, Hud.INK)
		draw_circle(c, face, Hud.CREAM)
		var w := c + Vector2(0, -face * 0.45)
		var wr := face * 0.3
		draw_circle(w, wr + 1.5, Hud.INK)
		if night:
			draw_circle(w, wr, NIGHT)
			draw_circle(w + Vector2(-wr * 0.15, 0), wr * 0.55, Color("#ffe9a8"))
			draw_circle(w + Vector2(wr * 0.08, -wr * 0.12), wr * 0.5, NIGHT)
			draw_circle(w + Vector2(wr * 0.55, wr * 0.35), 1.2, Color("#ffe9a8"))
		else:
			draw_circle(w, wr, Color("#bfe3f0").lerp(Color("#f6b26b"), progress))
			var s := w + Vector2(lerpf(wr * 0.5, -wr * 0.5, progress), wr * 0.35 - sin(progress * PI) * wr * 0.55)
			draw_circle(s, wr * 0.4, Color("#ffd452").lerp(Color("#e8621c"), progress))
		for i in 12:
			var d := Vector2.UP.rotated(TAU * i / 12.0)
			var big := i % 3 == 0
			draw_line(c + d * (face - (7.0 if big else 4.0)), c + d * (face - 1.5), Hud.INK, 3.0 if big else 1.6, true)
		var hours := 8.0 + 12.0 * progress
		draw_line(c, c + Vector2.UP.rotated(TAU * fmod(hours, 12.0) / 12.0) * face * 0.5, Hud.INK, 5.0, true)
		draw_line(c, c + Vector2.UP.rotated(TAU * fmod(hours, 1.0)) * face * 0.75, Hud.INK, 3.0, true)
		draw_circle(c, 4.5, Hud.CORAL)
		draw_circle(c, 1.8, Hud.INK)


## The money tag's string: a pendulum tied under the calendar. The tag swings
## when the calendar moves and when it is jolted.
class Dangle extends Control:
	const LENGTH := 24.0
	var tag: Control
	var angle := 0.0
	var spin := 0.0
	var drop := 1.0      # 0 tucked behind the calendar, 1 hanging at full length
	var tied := true
	var _last := Vector2.ZERO
	var _vel := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _hang_y() -> float:
		return lerpf(6.0 - tag.size.y, LENGTH - 13.0, drop)

	func step(at: Vector2, delta: float) -> void:
		if delta <= 0.0:
			return
		var vel := (at - _last) / delta
		var acc := (vel - _vel) / delta if _last != Vector2.ZERO else Vector2.ZERO
		_last = at
		_vel = vel
		if tied:
			spin += (-30.0 * sin(angle) + clampf(acc.x, -4000.0, 4000.0) * 0.002) * delta
			spin *= exp(-1.6 * delta)
			angle += spin * delta
		else:
			angle = 0.0
		position = at
		rotation = angle
		if tag and tag.get_parent() == self:
			tag.position = Vector2(-tag.size.x / 2.0, _hang_y())
		queue_redraw()

	func _draw() -> void:
		if not tied:   # the torn end left on the calendar
			draw_polyline(PackedVector2Array([Vector2.ZERO, Vector2(1, 6), Vector2(-2, 9)]), Hud.INK, 2.0, true)
		elif tag and tag.get_parent() == self and _hang_y() + 13.0 > 0.0:
			draw_line(Vector2.ZERO, Vector2(0, _hang_y() + 13.0), Hud.INK, 2.0, true)


## The cork board that holds the walkout card. It hangs on two ropes from the
## top of the screen and sways when it lands or is stamped.
class Board extends Sheet:
	var angle := 0.0
	var spin := 0.0

	func _init() -> void:
		super("cork", 14, 14)

	func _process(delta: float) -> void:
		spin += -26.0 * sin(angle) * delta
		spin *= exp(-2.2 * delta)
		angle += spin * delta
		pivot_offset = Vector2(size.x / 2.0, -80.0)
		rotation = angle
		queue_redraw()   # the ropes reach to the top of the screen wherever it is


## A rubber stamp seen from the front. `hover` is how high it is above the spot
## it will stamp; its shadow stays on that spot.
class RubberStamp extends Control:
	var target := Vector2.ZERO
	var hover := 400.0:
		set(v):
			hover = v
			position = target - Vector2(0, v)
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sh := Color(Hud.SHADOW, Hud.SHADOW.a * clampf(1.0 - hover / 140.0, 0.0, 1.0))
		draw_set_transform(Vector2(0, hover + 4.0), 0.0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, 30.0 + hover * 0.05, sh)
		draw_set_transform(Vector2.ZERO)
		var red := Color("#c9372e")
		Hud.box(self, Rect2(-27, -8, 54, 12), Hud.INK, 3)
		Hud.box(self, Rect2(-25, -6, 50, 8), red, 2)
		Hud.box(self, Rect2(-31, -28, 62, 22), Hud.INK, 5)
		Hud.box(self, Rect2(-28, -25, 56, 16), Hud.WOOD, 4)
		draw_rect(Rect2(-7, -54, 14, 28), Hud.INK)
		draw_rect(Rect2(-4.5, -54, 9, 28), Hud.WOOD.darkened(0.1))
		draw_circle(Vector2(0, -60), 13, Hud.INK)
		draw_circle(Vector2(0, -60), 10.5, Hud.CORAL)
		draw_circle(Vector2(-3.5, -64), 3.5, Hud.CORAL.lightened(0.4))


## A piece of paper or wood that holds other controls.
## A catalog piece as a little picture: its 3D model in a world of its own, seen
## from the game's camera angle. A `live` one redraws every frame so the model can
## spin; the rest are drawn once.
class ModelView extends TextureRect:
	const LEAN := Vector3(0.7071, 0, -0.7071)   # tipping about this shows the camera more of the top
	var vp: SubViewport
	var tilt: Node3D
	var spin: Node3D
	var live := false

	func _init(px: int, live_: bool) -> void:
		live = live_
		custom_minimum_size = Vector2(px, px)
		size = Vector2(px, px)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		vp = SubViewport.new()
		vp.size = Vector2i(px, px) * 2
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE
		add_child(vp)
		texture = vp.get_texture()
		var env := Environment.new()
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#ece0dc")
		env.ambient_light_energy = 0.62
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.12
		env.tonemap_white = 1.7
		var cam := Camera3D.new()
		cam.environment = env
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 2.6
		cam.near = 1.0
		cam.far = 60.0
		var focus := Vector3(0, 0.75, 0)
		cam.position = focus + Vector3(14, 15, 14)
		cam.basis = Basis.looking_at(-Vector3(14, 15, 14))
		vp.add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.light_color = Color("#fff3e2")
		sun.light_energy = 0.95
		sun.basis = Basis.looking_at(-Vector3(0.55, 1.0, 0.2))
		vp.add_child(sun)
		tilt = Node3D.new()
		vp.add_child(tilt)
		spin = Node3D.new()
		tilt.add_child(spin)

	## Call once this view is in the scene tree.
	func show_piece(game, bp: Dictionary) -> void:
		for c in spin.get_children():
			spin.remove_child(c)
			c.queue_free()
		var n := Node3D.new()
		spin.add_child(n)
		if bp.id == "screen":
			game._wall_visual(n, 0.9 + 0.1 * int(bp.tier))
		elif Catalog.is_build_tool(bp.id):
			Scenery.tool_preview(n, bp.id)
		elif bp.id == "rug":
			Scenery.rug(n)
			n.scale = Vector3.ONE * 0.55
			n.position = Vector3(0, 0.2, -0.28)
		elif bp.id == "flyers":   # a loose stack of printed sheets
			n.scale = Vector3.ONE * 1.7
			for i in 4:
				Build.box(n, Vector3(0, 0.12 + i * 0.035, 0), Vector3(0.62, 0.03, 0.84), Build.PAPER) \
					.rotation.y = [0.1, -0.16, 0.06, -0.04][i]
			Build.box(n, Vector3(0, 0.25, -0.14), Vector3(0.44, 0.014, 0.34), Build.CORAL).rotation.y = -0.04
			Build.box(n, Vector3(0, 0.25, 0.2), Vector3(0.44, 0.014, 0.1), Build.TILE_TEAL).rotation.y = -0.04
		else:
			Build.station(n, bp.id, int(bp.tier))
		if not live:
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	## 0 is flat on the floor; 1 is lifted and tipped toward the camera, as on show.
	func lift(t: float) -> void:
		tilt.basis = Basis(LEAN, 0.2 * t) * Basis(Vector3(0.7071, 0, 0.7071), 0.1 * t)
		tilt.position.y = lerpf(-0.3, 0.1, t)


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
			"clip":  # a pale, grained board with a sprung clip and its ring
				var board := Hud.WOOD.lightened(0.18)
				_box(Rect2(r.position + Vector2(0, 7), r.size), Hud.SHADOW, 24)
				_box(r, Hud.INK, 24)
				_box(r.grow(-4), board.darkened(0.16), 21)
				_box(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 13)), board, 21)
				for i in 9:  # grain
					var y := 26.0 + i * (size.y - 50.0) / 8.0 + sin(i * 2.3) * 6.0
					draw_polyline(PackedVector2Array([Vector2(16, y), Vector2(size.x * 0.35, y + sin(i * 1.7) * 5.0), Vector2(size.x * 0.7, y - 3.0), Vector2(size.x - 16, y + cos(i * 1.3) * 4.0)]), Color(Hud.INK, 0.09), 2.0, true)
				var cw := 170.0
				var steel := Color("#b3aba0")
				draw_arc(Vector2(size.x / 2, -22), 13, 0, TAU, 24, Hud.INK, 9.0, true)
				draw_arc(Vector2(size.x / 2, -22), 13, 0, TAU, 24, steel, 4.0, true)
				_box(Rect2(size.x / 2 - cw / 2, -14, cw, 50), steel, 12, 3, Hud.INK)
				_box(Rect2(size.x / 2 - cw / 2 + 8, -8, cw - 16, 10), steel.lightened(0.25), 5)
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
			"tag":  # a price tag hanging on a string: clipped corners, pinked bottom
				var k := 14.0
				if size.x < k * 2.0 + 4.0 or size.y < k + 12.0:
					return   # not laid out yet: the shape would be degenerate
				var shape := PackedVector2Array([Vector2(k, 0), Vector2(size.x - k, 0), Vector2(size.x, k), Vector2(size.x, size.y - 8)])
				var teeth := maxi(4, int(size.x / 11.0))
				for i in range(1, teeth * 2):
					shape.append(Vector2(size.x - i * size.x / (teeth * 2.0), size.y - (0.0 if i % 2 else 8.0)))
				shape.append_array(PackedVector2Array([Vector2(0, size.y - 8), Vector2(0, k)]))
				var shadow := PackedVector2Array()
				for p in shape:
					shadow.append(p + Vector2(0, 4))
				draw_colored_polygon(shadow, Hud.SHADOW)
				draw_colored_polygon(shape, Hud.CREAM)
				draw_polyline(shape + PackedVector2Array([shape[0]]), Hud.INK, 2.0, true)
				draw_circle(Vector2(size.x / 2, 13), 5, Hud.INK)
				draw_circle(Vector2(size.x / 2, 13), 2.5, Hud.CREAM)
			"cork":  # a framed cork board hung on two ropes from the top of the screen
				for x: float in [26.0, size.x - 26.0]:
					var top := Vector2(x, -global_position.y - 120.0)
					var end := Vector2(x, 10)
					draw_line(top, end, Hud.INK, 7.0)
					draw_line(top, end, Color("#c8a46a"), 4.0)
					var y := end.y
					while y > top.y:   # the twist
						draw_line(Vector2(x - 2, y), Vector2(x + 2, y - 4), Color("#8a6a3e"), 1.5, true)
						y -= 6.0
				_wood(r)
				var inner := r.grow(-9)
				inner.size.y -= 4
				_box(inner, Color("#c48f58"), 4, 2, Color(Hud.INK, 0.55))
				var rng := RandomNumberGenerator.new()
				rng.seed = 7
				for i in int(inner.get_area() / 40.0):
					var p := inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
					var dark := rng.randf() < 0.6
					draw_circle(p, rng.randf_range(0.7, 1.8), Color("#9c6a3a") if dark else Color("#ddb07a"))
				for x: float in [26.0, size.x - 26.0]:   # eyelets
					draw_circle(Vector2(x, 10), 5.5, Hud.INK)
					draw_circle(Vector2(x, 10), 3.0, Color("#c9c2b6"))
			"card":  # a cream card pinned to the cork
				_box(Rect2(r.position + Vector2(2, 4), r.size), Hud.SHADOW, 3)
				_box(r, Hud.CREAM, 3, 2, Color(Hud.INK, 0.7))
				for x: float in [14.0, size.x - 14.0]:
					draw_circle(Vector2(x + 1, 13), 6, Hud.SHADOW)
					draw_circle(Vector2(x, 11), 6, Hud.INK)
					draw_circle(Vector2(x, 11), 4.5, Hud.CORAL)
					draw_circle(Vector2(x - 1.5, 9.5), 1.6, Hud.CORAL.lightened(0.5))
			"tab":  # the prompt: a keycap and a word on one wood-edged tab
				_box(Rect2(r.position + Vector2(0, 5), r.size), Hud.SHADOW, 11)
				_box(r, Hud.WOOD.lightened(0.1), 11, 2, Hud.INK)
				_box(r.grow(-5), Color("#f0d9ae"), 7)
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
			"note":  # the gossip note, taped on
				_box(Rect2(r.position + Vector2(0, 4), r.size), Hud.SHADOW, 2)
				_box(r, Color("#ffe58a"), 2)
				for x: float in [-8.0, size.x - 44.0]:
					draw_set_transform(Vector2(x + 26, 4), -0.5 if x < 0 else 0.5)
					draw_rect(Rect2(-26, -9, 52, 18), Color(1, 1, 1, 0.55))
				draw_set_transform(Vector2.ZERO)
			"ribbon":
				var n := 14.0
				draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x - n, size.y / 2), Vector2(size.x, size.y), Vector2(0, size.y), Vector2(n, size.y / 2)]), tint)
			"menu":  # a coral-trimmed tent card on a wooden stand, corner curled
				var stand := Rect2(r.position + Vector2(22, 26), r.size + Vector2(6, 0))
				_box(Rect2(stand.position + Vector2(0, 7), stand.size), Hud.SHADOW, 12)
				_box(stand, Hud.WOOD.darkened(0.1), 12, 3, Hud.INK)
				_box(r, Hud.CORAL, 10, 3, Hud.INK)
				_box(r.grow(-10), Hud.CREAM, 5)
				_box(r.grow(-16), Hud.CREAM, 3, 2, Color(Hud.CORAL, 0.6))
				var k := 34.0
				draw_colored_polygon(PackedVector2Array([Vector2(size.x - 10 - k, size.y - 10), Vector2(size.x - 10, size.y - 10 - k), Vector2(size.x - 10 - k, size.y - 10 - k)]), Hud.PAPER.darkened(0.12))
				draw_polyline(PackedVector2Array([Vector2(size.x - 10 - k, size.y - 10), Vector2(size.x - 10, size.y - 10 - k)]), Color(Hud.INK, 0.4), 2.0, true)

const BOARD_Y := 18.0


func setup(game_) -> void:
	game = game_
	process_mode = Node.PROCESS_MODE_ALWAYS  # the options screen works while the game is paused
	load_options()
	apply_options.call_deferred()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)

	# Top left: the desk calendar, the clock that rolls out from behind it, and
	# the money tag hanging from it on a string.
	dangle = Dangle.new()
	root.add_child(dangle)
	clock = Clock.new()
	clock.position.y = 18.0 + Calendar.SIDE / 2.0 - Clock.R
	root.add_child(clock)
	calendar = Calendar.new()
	calendar.position = Vector2(22, 18)
	root.add_child(calendar)
	_roll_clock(0.0)
	money_tag = Sheet.new("tag").pad(12, 24, 12, 12)
	dangle.tag = money_tag
	dangle.add_child(money_tag)
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", -2)
	money_tag.add_child(mcol)
	money = _label(mcol, 30)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var coin := Icon.new("coin", 26, false)
	coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mcol.add_child(coin)
	toast_sheet = Sheet.new("paper", 14, 6)
	toast_sheet.position = Vector2(22, 268)
	toast_sheet.modulate.a = 0.0
	root.add_child(toast_sheet)
	toast = _label(toast_sheet, 18)

	# Top right: the cork board with the walkout card, hung on ropes.
	board = Board.new()
	board.anchor_left = 1.0
	board.anchor_right = 1.0
	board.offset_left = -246
	board.offset_right = -22
	board.offset_top = BOARD_Y
	root.add_child(board)
	var card := Sheet.new("card").pad(14, 8, 14, 10)
	board.add_child(card)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 2)
	card.add_child(cbox)
	_label(cbox, 24, "WALKOUTS").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 12)
	cbox.add_child(slots)
	for i in Ledger.MAX_STRIKES:
		var stamp := Punch.new(52)
		slots.add_child(stamp)
		stamps.append(stamp)

	# Top middle: the rail of open tickets, oldest on the left.
	ticket_rail = HBoxContainer.new()
	ticket_rail.anchor_left = 0.5
	ticket_rail.anchor_right = 0.5
	ticket_rail.offset_top = 14
	ticket_rail.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ticket_rail.alignment = BoxContainer.ALIGNMENT_CENTER
	ticket_rail.add_theme_constant_override("separation", 8)
	ticket_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ticket_rail)

	hint = _label(root, 15)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 24
	hint.offset_top = -40
	hint.modulate.a = 0.75
	hint.text = _hint_text()

	# The keycap prompt that floats over the station the chef faces.
	prompt = Sheet.new("tab").pad(10, 8, 16, 12)
	prompt.visible = false
	root.add_child(prompt)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	prompt.add_child(prow)
	var key := Sheet.new("key", 13, 4).pad(13, 1, 13, 7)
	prow.add_child(key)
	_prompt_key = key
	_prompt_key_label = _label(key, 24, "E")
	prompt_label = _label(prow, 26)

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
	fly = Control.new()
	fly.set_anchors_preset(Control.PRESET_FULL_RECT)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fly)


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
	t.default_font = lettering()
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
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.22)
	track.set_corner_radius_all(5)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = track.duplicate()
	filled.bg_color = CORAL
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	return t


func _label(parent: Node, font_size: int, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


const STATE_WORDS := {"queue": "Queueing outside", "to_seat": "Finding a seat", "ordering": "Waiting to order", "waiting": "Waiting for food",
	"eating": "Eating", "company": "Found nothing they liked", "leaving": "Leaving"}


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
	card.offset_top = 160
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
	if town.expects_deal(g.idx):   # discounting has a cost: they now expect it
		_label(box, 13, "Expects a deal").add_theme_color_override("font_color", Color(Build.CORAL_DARK))
	var orders := town.order_summary(g.idx, game.menu)   # tastes are never listed; what they order is
	if orders != "":
		var ol := _label(box, 13, "Orders: " + orders)
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ol.custom_minimum_size = Vector2(190, 0)
		ol.add_theme_color_override("font_color", Color(Build.CABINET))
	_guest_state = _label(box, 15)
	_guest_bill = _label(box, 14)
	_guest_bill.add_theme_color_override("font_color", Color(Build.CABINET))
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
	_guest_bill.visible = m.served_comfort >= 0.0
	if _guest_bill.visible:
		_guest_bill.text = _bill_words(m, _guest.bill_base)
	for id: String in _guest_meters:
		_guest_meters[id].value = float(m.get(id))
		_guest_meters[id].queue_redraw()
	var lines: Array[String] = []
	for t in m.thoughts.slice(-6):
		lines.append("\"%s\"" % t)
	lines.reverse()   # newest first
	_guest_thoughts.text = "No thoughts yet." if lines.is_empty() else "\n".join(lines)


## "Paying $14 · ordered extras": the served guest's bill, and why it moved.
static func _bill_words(m: GuestMood, base: int) -> String:
	var text := "Paying $%d" % m.pay_for(base)
	var scaled := m.scaled_price(base)
	if m.comped:
		text += "  ·  on the house"
	elif m.discounted:
		text += "  ·  half price"
	if scaled > base:
		text += "  ·  ordered extras"
	elif scaled < base:
		text += "  ·  in a hurry"
	return text


func update_status() -> void:
	_update_guest()
	var l: Ledger = game.ledger
	var P = game.Phase
	if title != null:
		return   # nothing of the day shows until Play
	if game.phase != _shown_phase:
		var first := _shown_phase == -1
		_shown_phase = game.phase
		match game.phase:
			P.SERVICE:
				_board_down()
			P.SUMMARY:
				_board_up(first)
				_rip_tag()
			P.BUILD:
				if first:   # the night before day 1: no walkout card to show yet
					_board_up(true)
				_new_tag()
		if first:
			_intro()
	# The calendar keeps the day just played until the next one opens.
	var want: int = l.day - 1 if game.phase == P.SUMMARY or game.phase == P.BUILD else l.day
	if calendar.day == 0:
		calendar.day = want
	elif want != calendar.day and not _turning:
		_turn_day(want)
	if not _turning:
		clock.night = game.phase != P.SERVICE
	clock.progress = game.day_progress()
	hint.visible = l.day <= 1 and game.phase == P.SERVICE   # the controls reminder is for the first day
	if l.money != _shown_money:
		if _shown_money >= 0 and l.money > _shown_money:
			money_tag.pivot_offset = money_tag.size * Vector2(0.5, 0.0)
			money_tag.scale = Vector2(1.25, 1.25)
			money_tag.create_tween().tween_property(money_tag, "scale", Vector2.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			dangle.spin += randf_range(-2.5, 2.5)
		_shown_money = l.money
		money.text = "$%d" % l.money
		money_tag.reset_size()
	var strikes := l.strikes()
	if strikes > _shown_strikes:   # one stamp per new walkout, in turn
		for i in range(_shown_strikes, mini(strikes, stamps.size())):
			_stamp(stamps[i], (i - _shown_strikes) * 0.8)
	_shown_strikes = strikes   # a new day's reset is wiped when the board comes back down


func _process(delta: float) -> void:
	if _options_card and _options_frame:
		_options_frame.queue_redraw()   # follows the card as it pops in
	if not calendar:
		return
	dangle.step(calendar.knot(), delta)
	for j in _views.size() if _shop else 0:   # the piece in the middle turns ever so slowly
		var turn: Node3D = _views[j].spin
		if j == _shop_index:
			turn.rotate_y(delta * 0.45)
		else:
			turn.rotation.y = lerp_angle(turn.rotation.y, 0.0, 1.0 - exp(-6.0 * delta))
	if _tag_state == "receipt":
		money_tag.visible = is_instance_valid(_summary_clip)
		if money_tag.visible:
			money_tag.position = _tag_goal()
			money_tag.rotation = 0.12


# ---------------------------------------------------------------- moving props

## Puts the clock somewhere between hidden behind the calendar (0) and out on its
## right (1), turned as a wheel would turn rolling that far.
func _roll_clock(out: float) -> void:
	var hidden := calendar.position.x + Calendar.SIDE / 2.0 - Clock.R
	var shown := calendar.position.x + Calendar.SIDE - 12.0
	clock.position.x = lerpf(hidden, shown, out)
	clock.rotation = (clock.position.x - shown) / Clock.R


func _intro() -> void:
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(game.sfx.bind("roll"))
	tw.tween_method(_roll_clock, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A new day: the clock rolls in behind the calendar, the calendar lifts and
## jiggles, a page turns over the top, it thumps down, and the clock rolls out.
func _turn_day(to: int) -> void:
	_turning = true
	var tw := create_tween()
	tw.tween_callback(game.sfx.bind("roll"))
	tw.tween_method(_roll_clock, 1.0, 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(game.sfx.bind("lift"))
	tw.tween_property(calendar, "lift", 15.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(game.sfx.bind("rattle"))
	for i in 5:
		tw.tween_property(calendar, "rotation", 0.07 * (1.0 if i % 2 == 0 else -1.0) * (1.0 - i * 0.16), 0.065)
	tw.tween_property(calendar, "rotation", 0.0, 0.06)
	tw.tween_callback(func() -> void:
		calendar.next_day = to
		game.sfx("page"))
	tw.tween_property(calendar, "flip", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		calendar.day = to
		calendar.flip = 0.0)
	tw.tween_property(calendar, "lift", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		game.sfx("thump")
		calendar.scale = Vector2(1.06, 0.93)
		dangle.spin += randf_range(1.5, 2.5) * (1.0 if randf() < 0.5 else -1.0))
	tw.tween_property(calendar, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		clock.night = false
		game.sfx("roll"))
	tw.tween_method(_roll_clock, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: _turning = false)


## Where the torn-off tag sits on the end-of-day clipboard: over its right edge.
func _tag_goal() -> Vector2:
	if not is_instance_valid(_summary_clip):
		return money_tag.position
	return _summary_clip.get_global_transform() * Vector2(_summary_clip.size.x - 6.0, 150.0)


## End of day: the tag is torn off its string and flutters onto the receipt.
func _rip_tag() -> void:
	if _tag_state != "hang":
		return
	_tag_state = "fly"
	game.sfx("rip")
	money_tag.reparent(fly)
	dangle.tied = false
	money_tag.pivot_offset = money_tag.size * Vector2(0.5, 0.0)
	var p0 := money_tag.position
	var r0 := money_tag.rotation
	_tag_tween = money_tag.create_tween()
	_tag_tween.tween_property(money_tag, "position:y", p0.y - 18.0, 0.12).set_ease(Tween.EASE_OUT)
	_tag_tween.tween_callback(game.sfx.bind("flutter"))
	_tag_tween.tween_method(_flutter.bind(p0 - Vector2(0, 18), r0), 0.0, 1.0, 1.5)
	_tag_tween.tween_callback(func() -> void:
		_tag_state = "receipt"
		money_tag.scale = Vector2.ONE
		game.sfx("rustle"))


func _flutter(t: float, p0: Vector2, r0: float) -> void:
	var e := ease(t, -1.8)
	var calm := 1.0 - t
	money_tag.position = p0.lerp(_tag_goal(), e) + Vector2(sin(t * TAU * 2.0) * 60.0 * calm, -sin(t * PI) * 80.0)
	money_tag.rotation = lerpf(r0, 0.12, e) + sin(t * TAU * 2.5) * 0.5 * calm
	money_tag.scale = Vector2(lerpf(0.55 + 0.45 * absf(cos(t * TAU * 1.5)), 1.0, e), 1.0)


## Building: the old tag drops away with the receipt, and a new one falls from
## behind the calendar and dangles. (Money is needed while building.)
func _new_tag() -> void:
	if _tag_tween:
		_tag_tween.kill()
	if _tag_state == "hang":
		return
	_tag_state = "fall"
	money_tag.visible = true
	_tag_tween = money_tag.create_tween()
	_tag_tween.set_parallel()
	_tag_tween.tween_property(money_tag, "position:y", money_tag.position.y + 900.0, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tag_tween.tween_property(money_tag, "rotation", money_tag.rotation + 1.4, 0.7)
	_tag_tween.chain().tween_callback(func() -> void:
		money_tag.reparent(dangle, false)
		money_tag.rotation = 0.0
		money_tag.scale = Vector2.ONE
		_tag_state = "hang"
		dangle.tied = true
		dangle.angle = 0.0
		dangle.spin = 0.0
		dangle.drop = 0.0
		game.sfx("rustle"))
	_tag_tween.tween_property(dangle, "drop", 1.12, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tag_tween.tween_callback(func() -> void:
		dangle.spin = randf_range(2.5, 3.5) * (1.0 if randf() < 0.5 else -1.0)
		game.sfx("rustle"))
	_tag_tween.tween_property(dangle, "drop", 1.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _board_down() -> void:
	for i in stamps.size():   # yesterday's walkouts are wiped before it comes back
		if i >= _shown_strikes:
			stamps[i].id = ""
			stamps[i].wet = 0.0
			stamps[i].rotation = 0.0
			stamps[i].queue_redraw()
	board.position.y = -board.size.y - 80.0
	var tw := board.create_tween()
	tw.tween_callback(game.sfx.bind("rope"))
	tw.tween_property(board, "position:y", BOARD_Y, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: board.spin += 1.4)


func _board_up(at_once := false) -> void:
	var gone := -board.size.y - 80.0
	if at_once:
		board.position.y = gone
		return
	var tw := board.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		board.spin -= 0.8
		game.sfx("rope"))
	tw.tween_property(board, "position:y", gone, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## A walkout: a rubber stamp comes down from above and thumps the next slot.
func _stamp(slot: Punch, delay: float) -> void:
	var st := RubberStamp.new()
	st.target = slot.get_global_transform() * (slot.size / 2.0)
	st.hover = 420.0
	fly.add_child(st)
	var tw := st.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(st, "hover", 48.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.1)
	tw.tween_property(st, "hover", 0.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		game.sfx("stamp")
		slot.stamp()
		board.spin += randf_range(-1.0, 1.0)
		st.scale = Vector2(1.08, 0.9))
	tw.tween_interval(0.16)
	tw.tween_callback(func() -> void: st.scale = Vector2.ONE)
	tw.tween_property(st, "hover", 70.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(st, "hover", 520.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(st.queue_free)


## Shows "[E] COOK" over a point on screen, or hides it when `text` is empty.
func show_prompt(at: Vector2, text: String) -> void:
	last_action = text
	prompt.visible = text != "" and title == null
	if text != "":
		prompt_label.text = text.to_upper()
		prompt.reset_size()
		prompt.position = (at - Vector2(prompt.size.x / 2.0, prompt.size.y)).round()
		prompt.position.y = maxf(prompt.position.y, 6.0)  # never off the top of the screen


## Rebuilds the ticket rail from the game's open tickets.
func refresh_tickets() -> void:
	if ticket_rail == null:
		return
	for c in ticket_rail.get_children():
		c.queue_free()
	var shown := 0
	for tk: Dictionary in game.tickets:
		if shown >= RAIL_MAX:
			break
		shown += 1
		var card := Sheet.new("paper", 10, 6)
		ticket_rail.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		card.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		col.add_child(head)
		var g: Guest = tk.guest
		head.add_child(Face.new(Color(g.info.shirt), str(g.info.name).left(1)))
		_label(head, 18, g.info.name)
		var tray: Tray = game.tray_for_ticket(int(tk.id))
		if tray != null:   # a tray is being built for it: a little tray mark
			head.add_child(Icon.new("tray", 22, false))
		var line := 0
		for course in Menu.COURSES:
			for it: Dictionary in tk.items:
				if it.course != course:
					continue
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 4)
				col.add_child(row)
				row.add_child(Icon.new(Icons.dish_id(it), 22, false))
				var box := VBoxContainer.new()
				box.add_theme_constant_override("separation", 0)
				row.add_child(box)
				_label(box, 14, it.name)
				box.add_child(Marks.new(game, int(tk.id), line, it.ingredients.size()))
				line += 1
	if game.tickets.size() > shown:
		var more := Sheet.new("paper", 8, 6)
		ticket_rail.add_child(more)
		_label(more, 18, "+%d" % (game.tickets.size() - shown))


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


# ---------------------------------------------------------------- options

const OPTIONS_FILE := "user://regulars_options.cfg"
var options := {"sfx": 0.8, "music": 0.8, "tilt_shift": true}
var _options_card: Control
var _options_body: VBoxContainer
var _options_tab := "audio"
var _options_tabs := {}
var _options_tab_row: HBoxContainer
var _options_done: Button
var _options_keys: Label         # what the keys do, for keys and pad
var _options_frame: Control       # the highlight round the chosen row (keys and pad)
var _options_rows: Array = []     # what up and down move between, top to bottom
var _options_sel := 0


func load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(OPTIONS_FILE) != OK:
		return
	for key: String in options:
		options[key] = cfg.get_value("options", key, options[key])


func save_options() -> void:
	var cfg := ConfigFile.new()
	for key: String in options:
		cfg.set_value("options", key, options[key])
	cfg.save(OPTIONS_FILE)


func apply_options() -> void:
	game.set_volumes(float(options.sfx), float(options.music))
	game.set_tilt_shift(bool(options.tilt_shift))


# ---------------------------------------------------------------- title screen

var title: Title
var _behind_title: Array[Control] = []


func title_open() -> bool:
	return title != null


## Covers the room with the title, hiding the rest of the interface until Play.
## The options screen opens over it (it is added to root after).
func show_title() -> void:
	_behind_title.clear()
	for c in root.get_children():
		if c is Control and c.visible:
			c.visible = false
			_behind_title.append(c)
	title = Title.new()
	title.setup(self)
	root.add_child(title)


func hide_title() -> void:
	if title == null:
		return
	title.queue_free()
	title = null
	for c in _behind_title:
		c.visible = true
	_behind_title.clear()


func options_open() -> bool:
	return _options_card != null


## One action while the options screen is open (see Controls): up and down pick
## a row, left and right turn a slider or switch tabs, use or confirm presses,
## back or options closes. Held browse keys repeat; nothing else does. Returns
## whether the action was used.
func options_action(action: String, echo := false) -> bool:
	match action:
		"up": _options_pick(_options_sel - 1)
		"down": _options_pick(_options_sel + 1)
		"left": _options_turn(-1)
		"right": _options_turn(1)
		_:
			if echo:
				return false
			match action:
				"use", "confirm": _options_press()
				"back", "options": toggle_options()
				_: return false
	return true


## Opens or closes the options screen. The game is paused while it is open.
func toggle_options() -> void:
	if _options_card != null:
		_options_card.queue_free()
		_options_card = null
		_options_rows.clear()
		save_options()
		get_tree().paused = false
		return
	get_tree().paused = true
	_options_sel = 0
	_options_card = Control.new()
	_options_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_options_card)
	var dim := ColorRect.new()
	dim.color = Color(SHADOW, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_card.add_child(dim)
	var mid := CenterContainer.new()
	mid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_card.add_child(mid)
	var card := Sheet.new("paper", 30, 24)
	card.custom_minimum_size = Vector2(480, 0)
	mid.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	_ribbon(box, "OPTIONS", CORAL)
	_options_tab_row = HBoxContainer.new()
	_options_tab_row.add_theme_constant_override("separation", 10)
	box.add_child(_options_tab_row)
	_options_tabs = {
		"audio": _button(_options_tab_row, "Audio", _show_options_tab.bind("audio")),
		"graphics": _button(_options_tab_row, "Graphics", _show_options_tab.bind("graphics")),
	}
	_options_body = VBoxContainer.new()
	_options_body.add_theme_constant_override("separation", 12)
	_options_body.custom_minimum_size = Vector2(0, 96)
	box.add_child(_options_body)
	_options_done = _button(box, "Done", toggle_options)
	_options_keys = _label(box, 15)
	_options_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_options_keys.modulate.a = 0.7
	_options_frame = Control.new()
	_options_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_frame.draw.connect(_draw_options_frame)
	_options_card.add_child(_options_frame)
	_show_options_tab(_options_tab)
	_pop_in(card)


## Fills the body for a tab and lists the rows the arrows move between: the
## tabs, each slider or switch, Done. Also sizes everything for the device in
## use, so refresh_input calls it when the player switches.
func _show_options_tab(tab: String) -> void:
	_options_tab = tab
	for id: String in _options_tabs:
		_options_tabs[id].modulate.a = 1.0 if id == tab else 0.55
	for c in _options_body.get_children():
		_options_body.remove_child(c)
		c.queue_free()
	_options_rows = [_options_tab_row]
	if tab == "audio":
		_options_rows.append(_volume_row("Sound effects", "sfx"))
		_options_rows.append(_volume_row("Music", "music"))
	else:
		_options_rows.append(_button(_options_body,
			"Tilt-shift (miniature look):  %s" % ("On" if options.tilt_shift else "Off"), _toggle_tilt_shift))
		var note := _label(_options_body, 15, "Blurs the near and far edges so the town looks like a model.")
		note.modulate.a = 0.7
	_options_rows.append(_options_done)
	_options_done.text = "Done" + _key_note("back")
	var touch := _mode() == "touch"
	_options_keys.visible = not touch
	_options_keys.text = "%s choose and change     %s press     %s close" % [_g("browse"), _g("use"), _g("back")]
	for row: Control in _options_rows:
		if row is Button:
			row.custom_minimum_size.y = 64.0 if touch else 0.0
		row.mouse_filter = Control.MOUSE_FILTER_PASS if row is Container else row.mouse_filter
		if not row.has_meta("picks"):   # the mouse moves the frame too
			row.set_meta("picks", true)
			row.mouse_entered.connect(func() -> void: _options_pick(_options_rows.find(row)))
	for b: Button in _options_tabs.values():
		b.custom_minimum_size.y = 64.0 if touch else 0.0
	_options_pick(_options_sel)


func _toggle_tilt_shift() -> void:
	options.tilt_shift = not options.tilt_shift
	apply_options()
	_show_options_tab("graphics")


func _options_pick(i: int) -> void:
	i = clampi(i, 0, maxi(_options_rows.size() - 1, 0))
	if i != _options_sel and _options_card != null:
		game.sfx("tick")
	_options_sel = i
	if _options_frame:
		_options_frame.queue_redraw()


func _options_row() -> Control:
	return _options_rows[_options_sel] if _options_sel < _options_rows.size() else null


## Left or right: the next tab along, or a slider a notch (a tenth) each way.
func _options_turn(dir: int) -> void:
	var row := _options_row()
	if row == _options_tab_row:
		var ids: Array = _options_tabs.keys()
		var at := ids.find(_options_tab)
		_show_options_tab(ids[posmod(at + dir, ids.size())])
		game.sfx("tab")
	elif row is HBoxContainer:
		var slider: HSlider = row.get_meta("slider")
		slider.value = clampf(snappedf(slider.value + dir * 0.1, 0.05), 0.0, 1.0)


func _options_press() -> void:
	var row := _options_row()
	if row == _options_tab_row:
		_options_turn(1)
	elif row is Button:
		row.pressed.emit()


## Keys and controller only: a heavy ink frame round the chosen row with a
## coral pointer tab on its left, like a marker clipped to the card. Drawn on
## top of the card so it follows the pop-in.
func _draw_options_frame() -> void:
	var row := _options_row()
	if row == null or _mode() == "touch":
		return
	var r := row.get_global_rect().grow_individual(14, 6, 10, 6)
	r.position -= _options_frame.get_global_rect().position
	pick_frame(_options_frame, r)


## The keys-and-pad highlight: an ink frame with a coral pointer tab on its left.
static func pick_frame(ci: CanvasItem, r: Rect2) -> void:
	var ink := StyleBoxFlat.new()
	ink.draw_center = false
	ink.border_color = INK
	ink.set_border_width_all(3)
	ink.set_corner_radius_all(14)
	ci.draw_style_box(ink, r)
	var y := r.get_center().y
	var x := r.position.x
	var tip := PackedVector2Array([Vector2(x - 2, y), Vector2(x - 20, y - 12), Vector2(x - 20, y + 12)])
	ci.draw_colored_polygon(PackedVector2Array([tip[0] + Vector2(0, 3), tip[1] + Vector2(0, 3), tip[2] + Vector2(0, 3)]), SHADOW)
	ci.draw_colored_polygon(tip, CORAL)
	ci.draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2], tip[0]]), INK, 2.5, true)


## A round cream grabber with an ink ring, big enough for a thumb on touch.
static func _grabber(diameter: int) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var c := diameter / 2.0
	for y in diameter:
		for x in diameter:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(c, c))
			var col := Color(INK)
			if d < c - 3.5:
				col = Color(CREAM)
			elif d < c - 3.0:
				col = Color(CREAM).lerp(INK, (d - (c - 3.5)) * 2.0)
			col.a = clampf(c - d, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _volume_row(title: String, key: String) -> HBoxContainer:
	var touch := _mode() == "touch"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_options_body.add_child(row)
	_label(row, 20, title).custom_minimum_size = Vector2(170, 0)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(options[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 56.0 if touch else 30.0
	var knob := _grabber(46 if touch else 26)
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(icon, knob)
	slider.focus_mode = Control.FOCUS_NONE   # the arrows are read by options_action instead
	row.add_child(slider)
	row.set_meta("slider", slider)
	var value := _label(row, 20, "%d%%" % roundi(slider.value * 100))
	value.custom_minimum_size = Vector2(56, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		options[key] = v
		value.text = "%d%%" % roundi(v * 100)
		apply_options()
		if key == "sfx":
			game.sfx("coin"))
	return row


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


## A rule with a small round token in the middle, as on the game-over card.
func _ornament(box: VBoxContainer, icon: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for i in 2:
		var line := ColorRect.new()
		line.color = Color(INK, 0.4)
		line.custom_minimum_size = Vector2(110, 2)
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
		if i == 0:
			row.add_child(Icon.new(icon, 30))


func _centred(box: VBoxContainer, text: String, font := 28) -> Label:
	var l := _label(box, font, text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


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
	var l := _label(box, 14, "- ".repeat(60))
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
	_summary_clip = clip
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
	_row(box, "", "MEALS SERVED:", str(rec.served))
	_row(box, "", "SALES:", "$%d" % rec.sales)
	_row(box, "", "TIPS:", "$%d" % rec.tips)
	_row(box, "", "WALKOUTS:", str(rec.walkouts))
	_row(box, "", "STOCK:", "-$%d" % int(rec.get("stock", 0)))
	var nothing := int(rec.get("found_nothing", 0))
	if nothing > 0:
		var nl := _label(box, 15, "%d %s nothing they liked." % [nothing, "person found" if nothing == 1 else "people found"])
		nl.modulate.a = 0.75
	_rule(box)
	var earned: int = rec.sales + rec.tips
	var total := _row(box, "", "TOTAL EARNED:", "$%d" % earned, 32)
	total.get_parent().add_child(Icon.new("coins", 34, false))
	if animate:
		total.create_tween().tween_method(func(v: float) -> void: total.text = "$%d" % roundi(v), 0.0, float(earned), 0.9) \
		.set_delay(0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_row(box, "", "IN THE BANK:", "$%d" % game.ledger.money)
	var note := Sheet.new("note").pad(18, 14, 18, 12)
	note.rotation = -0.035
	stack.add_child(note)
	var gossip := _label(note, 19, "TOWN GOSSIP: " + game.town.headline())
	gossip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gossip.custom_minimum_size = Vector2(380, 0)
	_button(stack, "Town book" + _key_note("town"), show_town)
	_button(stack, ("Set up for day %d" % game.ledger.day) + _key_note("confirm"), game.open_build)
	if animate:
		_pop_in(clip)


const SHOP_TABS: Array[String] = ["Kitchen", "Dining", "Decor", "Build", "Extras"]
const TRAY_DROP := 260.0   # how far below its place the shop tray waits


func menu_open() -> bool:
	return menu != null


func open_menu() -> void:
	if menu != null:
		return
	menu = MenuScreen.new()
	root.add_child(menu)
	menu.setup(game, self)


func close_menu() -> void:
	if menu != null:
		menu.queue_free()
		menu = null


func hide_build() -> void:
	for n: Control in [build_bar, _shop]:
		if n:
			n.queue_free()
	_drop_row()
	build_bar = null
	_shop = null
	hint.visible = true


func set_search(text: String) -> void:
	_search = text
	if _search_box and _search_box.text != text:
		_search_box.text = text
	_refresh_catalog()


func _set_category(cat: String) -> void:
	if cat != _category and _shop:
		game.sfx("tab", 0.08)
	_category = cat
	_search = ""   # a search looks through every category; picking one ends it
	if _search_box:
		_search_box.text = ""
	_refresh_catalog()
	_deal_cards()


func typing() -> bool:
	return _shop != null and _search_box.has_focus()


func focus_search() -> void:
	if _shop:
		_search_box.grab_focus()
		_search_box.edit()


func stop_typing() -> void:
	if typing():
		_search_box.release_focus()


## What a control is called for the device in use ("E", "A", "Use").
func _g(action: String) -> String:
	return game.controls.glyph(action) if game.controls else str(Controls.GLYPHS.keys[action])


func _mode() -> String:
	return game.controls.mode if game.controls else "keys"


## "   (Enter)" after a button's words; nothing on touch, where it is tapped.
func _key_note(action: String) -> String:
	return "" if _mode() == "touch" or _g(action) == "" else "   (%s)" % _g(action)


func _hint_text() -> String:
	match _mode():
		"pad":
			return "Stick move     A use     B back     Start options"
		"touch":
			return ""   # the joystick sits there; the Use button names the action
	return "WASD move     E or Space use     Click a guest     O options     M mute"


func _shop_keys_text() -> String:
	match _mode():
		"pad":
			return "A buy      D-pad browse      B close"
		"touch":
			return "Tap a piece, then tap it again to buy"
	return "E buy      Tab close"


## The build slip's words for what is in hand, for the device in use.
func _build_tip(hand: Dictionary) -> String:
	var m := _mode()
	var use := _g("use")
	if hand.is_empty() and Cleaning.carrying_mess(game.player.held):
		if game.player.held == "rubbish_bag":
			return "Carrying the rubbish bag.      Take it out the front door before building or shopping"
		return "Carrying a dirty plate.      Put it in the sink before building or shopping"
	if hand.is_empty():
		if m == "touch":
			return "Joystick walk      Tap a piece to pick it up      Shop      Dishes for the menu      Flip the door card to open for day %d" % game.ledger.day
		var stock := "%s stock a crate or not      " % _g("turn")
		return "%s walk      %s pick up      %s%s shop      %s menu      Flip the door card to open for day %d" % [_g("move"), use, stock, _g("shop"), _g("menu"), game.ledger.day]
	if Catalog.is_build_tool(hand.id):
		var floor: bool = game.floor_kind(hand.id) != ""
		var what := "%s, $%d each." % [Catalog.label(hand), int(hand.price)]
		match m:
			"touch":
				var drag := "Drag along the floor for a row" if hand.id == "wall" or Catalog.is_finish(hand.id) else ("Drag across the floor for a rectangle" if floor else "Tap a wall to add one")
				return "%s      %s      Erase, then drag, to take away      Done" % [what, drag]
			"pad":
				return "%s      %s      X remove      B done" % [what, "Hold A and walk to keep laying" if floor else "A build"]
		var how := "Hold E and walk to keep laying" if floor else "E build"
		var drag := "drag for a row" if hand.id == "wall" or Catalog.is_finish(hand.id) else ("drag for a rectangle" if floor else "click to add")
		return "%s      %s      Mouse: %s, right-drag removes      X remove      Esc done" % [what, how, drag]
	var turn := _g("turn")
	if hand.get("moving", false):
		var why: String = game.sell_block()
		var sell := ("%s for $%d" % ["Sell" if m == "touch" else _g("sell") + " sell", game.sell_value()]) if why == "" else why
		if m == "touch":
			return "Carrying the %s.      Tap the floor to put it down      Turn      %s      Drop puts it back" % [game.piece_name(hand).to_lower(), sell]
		return "Carrying the %s.      %s put down      %s turn      %s      %s put back" % [
			game.piece_name(hand).to_lower(), use, turn, sell, _g("back")]
	if m == "touch":
		return "%s, $%d when it is put down.      Tap the floor to put it down      Turn      Drop" % [Catalog.label(hand), int(hand.price)]
	return "%s, $%d when it is put down.      %s put down      %s turn      %s drop" % [
		Catalog.label(hand), int(hand.price), use, turn, _g("back")]


## Redraws every hint for a new device: the corner hint, the prompt's keycap,
## the build slip and the shop's key line.
func refresh_input() -> void:
	hint.text = _hint_text()
	_prompt_key.visible = _mode() != "touch"
	_prompt_key_label.text = _g("use")
	if _shop_keys:
		_shop_keys.text = _shop_keys_text()
	if build_bar:
		show_build()
	if _options_card:
		_show_options_tab(_options_tab)
	if title:
		title.refresh()


## The build phase: a paper slip along the bottom says what the keys do. The
## shop (show_shop) slides up over it. Later calls only redraw.
func show_build() -> void:
	if build_bar == null:
		hint.visible = false
		var holder := MarginContainer.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_theme_constant_override("margin_bottom", 16)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(holder)
		root.move_child(holder, center.get_index())
		build_bar = holder
		var stack := VBoxContainer.new()
		stack.size_flags_vertical = Control.SIZE_SHRINK_END
		stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.alignment = BoxContainer.ALIGNMENT_END
		stack.add_theme_constant_override("separation", 6)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(stack)
		# Night cleaning: a note taped above the slip while anything is still dirty.
		var note := Sheet.new("note").pad(14, 8, 18, 8)
		note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		note.rotation = -0.02
		stack.add_child(note)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.add_child(row)
		row.add_child(Icon.new("stink", 30))
		_dirty_label = _label(row, 20)
		_dirty_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dirty_note = note
		menu_notes = MenuScreen.BuildNotes.new(game, self)
		stack.add_child(menu_notes)
		stack.move_child(menu_notes, 0)
		var slip := Sheet.new("paper", 22, 10)
		slip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(slip)
		_tip = _label(slip, 20)
		holder.modulate.a = 0.0
		holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.3)
		game.sfx("rustle")
	build_bar.visible = _shop == null
	var hand: Dictionary = game.hand
	_tip.text = _build_tip(hand)
	_dirty_label.text = game.dirty_note()
	_dirty_note.visible = _dirty_label.text != ""
	menu_notes.refresh()
	_refresh_catalog()


const SLOT := 88.0                  # the gap between the small pieces along the row
const GAP := 64.0                   # extra room either side of the piece in the middle
const BAND := Vector2(1080, 232)    # the row itself
const ITEM := Vector2(204, 232)     # one piece: its picture with the price underneath
const SMALL := 0.42                 # how big the pieces either side of the middle are


func _drop_row() -> void:
	if _row_tween:
		_row_tween.kill()
	_items.clear()
	_views.clear()


## The shop: a wooden tray along the bottom with one row of pieces that slides
## left and right. The piece in the middle is the selected one: a little bigger,
## lifted and tipped on a soft white disc, turning slowly, its price underneath.
## Category tabs sit under the row, with the search box at the bottom right.
func show_shop() -> void:
	if _shop:
		return
	_search = ""
	_category = SHOP_TABS[0]
	_shop_index = 0
	build_bar.visible = false
	_shop = Control.new()
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shop)
	root.move_child(_shop, center.get_index())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop.add_child(margin)
	var wood := Sheet.new("wood", 10, 10)
	wood.mouse_filter = Control.MOUSE_FILTER_STOP
	wood.size_flags_vertical = Control.SIZE_SHRINK_END
	wood.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(wood)
	var paper := Sheet.new("paper", 14, 8)
	wood.add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	paper.add_child(box)

	var band := Control.new()
	band.custom_minimum_size = BAND
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(band)
	var felt := Panel.new()   # a kraft mat, so the white disc shows against the paper
	felt.set_anchors_preset(Control.PRESET_FULL_RECT)
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.add_theme_stylebox_override("panel", _flat(KRAFT, 12))
	band.add_child(felt)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.78, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.97), Color(1, 1, 1, 0.0)])
	var disc := GradientTexture2D.new()
	disc.gradient = fade
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(1.0, 0.5)
	disc.width = 256
	disc.height = 256
	var glow := TextureRect.new()
	glow.texture = disc
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(216, 216)
	glow.position = Vector2(BAND.x / 2.0 - 108, -8)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(glow)
	_cards = Control.new()   # only a holder: _lay_out places the pieces by hand
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(_cards)
	for side: int in [-1, 1]:   # keycaps at the ends: there is more to the left and right
		var key := Sheet.new("key", 13, 4).pad(13, 1, 13, 7)
		key.position = Vector2(BAND.x / 2.0 + side * (BAND.x / 2.0 - 30) - 20, 70)
		band.add_child(key)
		_label(key, 24, "<" if side < 0 else ">")
	var about := HBoxContainer.new()
	about.alignment = BoxContainer.ALIGNMENT_CENTER
	about.add_theme_constant_override("separation", 14)
	box.add_child(about)
	_info = _label(about, 21)
	_info_blurb = _label(about, 18)
	_info_blurb.modulate.a = 0.7

	# Under the row: search on the left, the categories in the middle, the keys on the right.
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	box.add_child(strip)
	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search...  (F)"
	_search_box.custom_minimum_size = Vector2(210, 0)
	_search_box.add_theme_font_size_override("font_size", 16)
	_search_box.text_changed.connect(set_search)
	_search_box.text_submitted.connect(func(_t: String) -> void: _search_box.release_focus())
	_search_box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and game.shop_key(event.physical_keycode):
			_search_box.accept_event())
	strip.add_child(_search_box)
	var middle := HBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	strip.add_child(middle)
	_tabs.clear()
	for cat: String in SHOP_TABS:
		var tab := _button(middle, cat, _set_category.bind(cat))
		tab.add_theme_font_size_override("font_size", 16)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.toggle_mode = true
		tab.set_meta("cat", cat)
		_tabs.append(tab)
	var keys := _label(strip, 15, _shop_keys_text())
	_shop_keys = keys
	keys.custom_minimum_size = Vector2(210, 0)   # as wide as the search box, so the tabs sit dead centre
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.modulate.a = 0.75

	_refresh_catalog()
	_deal_cards()
	# The tray slides up from under the screen.
	_shop.position.y = TRAY_DROP
	_shop.create_tween().tween_property(_shop, "position:y", 0.0, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Slides the tray away.
func hide_shop() -> void:
	if _shop == null:
		return
	stop_typing()
	var tray := _shop
	_shop = null
	_drop_row()
	var tw := tray.create_tween()
	tw.tween_property(tray, "position:y", TRAY_DROP, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(tray.queue_free)
	if build_bar:
		build_bar.visible = true


## What the shop says about a piece: {name, price, blurb, can, locked}.
func _shop_info(bp: Dictionary) -> Dictionary:
	var l: Ledger = game.ledger
	if bp.id == "flyers":
		return {"name": "Flyers", "price": "Out" if game.flyers_out else "$%d" % Town.FLYER_PRICE,
			"blurb": "More guests tomorrow",
			"can": not game.flyers_out and l.money >= Town.FLYER_PRICE, "locked": false}
	var id: String = bp.id
	var tier: int = bp.tier
	var locked := l.level() < Catalog.level_of(id, tier)
	return {"name": Catalog.label(bp), "blurb": Catalog.blurb_of(id, tier), "locked": locked,
		"price": "Level %d" % Catalog.level_of(id, tier) if locked else "$%d" % Catalog.price_of(id, tier),
		"can": game.catalog.can_buy(id, l.money, l.level(), tier)}


## Rebuilds the row for the current search and category, keeping the selection on
## the same piece where it is still listed.
func _refresh_catalog() -> void:
	if _shop == null:
		return
	var searching := _search.strip_edges() != ""   # a search looks through every category
	for tab in _tabs:
		tab.set_pressed_no_signal(tab.get_meta("cat") == _category and not searching)
	var keep: Dictionary = _shop_items[_shop_index] if _shop_index < _shop_items.size() else {}
	var turned := _views[_shop_index].spin.rotation.y if _shop_index < _views.size() else -0.6
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_drop_row()
	_shop_items = game.shop_items(_search, "" if searching else _category)
	for i in _shop_items.size():
		var bp := _shop_items[i]
		var info := _shop_info(bp)
		var item := Control.new()
		item.size = ITEM
		item.pivot_offset = Vector2(ITEM.x / 2.0, 122)
		item.tooltip_text = "%s\n%s" % [info.name, info.blurb]
		item.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_card_pressed(i))
		_cards.add_child(item)
		_items.append(item)
		var view := ModelView.new(int(ITEM.x), true)
		view.modulate = Color(1, 1, 1, 0.45) if info.locked else Color.WHITE
		item.add_child(view)
		view.show_piece(game, bp)
		_views.append(view)
		var price := _label(item, 32, info.price)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.position = Vector2(0, 190)
		price.size = Vector2(ITEM.x, 40)
		if not info.can:
			price.add_theme_color_override("font_color", Color(INK, 0.6) if info.locked else Color("#b8473a"))
	if _shop_items.is_empty():
		var none := _label(_cards, 20, "Nothing in the shop matches.")
		none.modulate.a = 0.7
		none.position = Vector2(BAND.x / 2.0 - 120, 196)
	var at := _shop_items.find(keep)
	_select(clampi(_shop_index, 0, maxi(_shop_items.size() - 1, 0)) if at < 0 else at, 0)
	if at >= 0:
		_views[at].spin.rotation.y = turned   # the same piece carries on turning from where it was


## Places every piece for a row position: `pos` is the index in the middle, and
## fractional while the row slides. A piece grows, lifts and tips as it comes in.
func _lay_out(pos: float) -> void:
	_row_pos = pos
	for j in _items.size():
		var away := absf(j - pos)
		var near := 1.0 - clampf(away, 0.0, 1.0)
		var item := _items[j]
		var along := (j - pos) * SLOT + signf(j - pos) * GAP * minf(away, 1.0)
		item.position.x = BAND.x / 2.0 - ITEM.x / 2.0 + along
		item.scale = Vector2.ONE * lerpf(SMALL, 1.0, smoothstep(0.0, 1.0, near))
		item.modulate.a = clampf(5.3 - away, 0.0, 1.0)   # fading out toward the ends of the tray
		item.z_index = 1 if near > 0.5 else 0
		_views[j].lift(near)


## The pieces drop into the tray one after another, from the middle outward.
func _deal_cards() -> void:
	for i in _items.size():
		var wait := absi(i - _shop_index) * 0.03
		_items[i].position.y = 90.0
		_items[i].create_tween().tween_property(_items[i], "position:y", 0.0, 0.3).set_delay(wait) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _card_pressed(i: int) -> void:
	if i == _shop_index:
		shop_buy()
	else:
		game.sfx("tick", 0.1)
		_select(i, signi(i - _shop_index))


## Brings piece `i` to the middle of the row. `dir` is the way the selection
## moved; 0 puts it there at once.
func _select(i: int, dir: int) -> void:
	_shop_index = i
	if _row_tween:
		_row_tween.kill()
	if _shop_items.is_empty():
		_info.text = ""
		_info_blurb.text = ""
		return
	var info := _shop_info(_shop_items[i])
	_info.text = info.name
	_info_blurb.text = info.blurb
	if dir == 0:
		_lay_out(i)
	else:
		_row_tween = _shop.create_tween()
		_row_tween.tween_method(_lay_out, _row_pos, float(i), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Left and right along the tray, wrapping at the ends.
func shop_move(d: int) -> void:
	if _shop == null or _shop_items.is_empty():
		return
	game.sfx("tick", 0.1)
	_select(wrapi(_shop_index + d, 0, _shop_items.size()), d)


func shop_category(d: int) -> void:
	if _shop:
		_set_category(SHOP_TABS[wrapi(SHOP_TABS.find(_category) + d, 0, SHOP_TABS.size())])


## Buys the piece in the middle. A refusal shakes it; flyers get a little hop.
func shop_buy() -> void:
	if _shop == null or _shop_items.is_empty():
		game.sfx("fail")
		return
	var item := _items[_shop_index]
	if game.buy(_shop_items[_shop_index]):
		if _shop:   # still open: it was the flyers, and the row has been redrawn
			item = _items[_shop_index]
			var tw := item.create_tween()
			tw.tween_property(item, "position:y", -22.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		return
	var x := item.position.x
	var no := item.create_tween()
	for dx: float in [-12.0, 10.0, -6.0, 0.0]:
		no.tween_property(item, "position:x", x + dx, 0.05)


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
	_summary_clip = clip
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
	_ornament(box, "day")
	_centred(box, "DAYS SURVIVED: %d" % days)
	_ornament(box, "coin")
	_centred(box, "TOTAL EARNED: $%d" % earned)
	_ornament(box, "star")
	_centred(box, "NEW BEST RUN!" if is_record else "BEST RUN: %d %s" % [best.days, "DAY" if best.days == 1 else "DAYS"])
	_button(box, "Try again" + _key_note("confirm"), game.restart)
	_pop_in(menu)
