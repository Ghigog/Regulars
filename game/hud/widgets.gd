class_name HudWidgets
extends RefCounted
## The interface's drawn widgets, as inner classes (Hud's own until the split): icons and
## punched icons, marks, faces, chef tags, pips, ratings, meters, the calendar, the clock,
## the dangling sign, the reputation meter, boards, rubber stamps, model views and sheets.


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
## A ticket's ingredient marks: a ring per ingredient, filled with a tick once its item
## has been served to the guest. Read live from the game, so they tick off as plates land.
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
		var t: Tray = game.serving.tray_for_ticket(ticket)
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


## A player's tag (PRD 4): a disc in their trim colour with their number on it,
## so two players' marks differ by shape (the digit) as well as colour. With
## `ready`, a ticked note hangs off it; `waiting` shows a hollow ring instead.
class ChefTag extends Control:
	var p := 0
	var px := 28.0
	var state := ""   # "", "ready" or "waiting"

	func _init(p_: int, px_ := 28.0, state_ := "") -> void:
		p = p_
		px = px_
		state = state_
		custom_minimum_size = Vector2(px * (1.7 if state != "" else 1.0), px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_player(p_: int, state_ := "") -> void:
		if p_ == p and state_ == state:
			return
		p = p_
		state = state_
		custom_minimum_size = Vector2(px * (1.7 if state != "" else 1.0), px)
		queue_redraw()

	func _draw() -> void:
		var r := px / 2.0 - 1.0
		var c := Vector2(px / 2.0, px / 2.0)
		draw_circle(c + Vector2(0, 1.5), r, Hud.SHADOW)
		draw_circle(c, r, Hud.INK)
		draw_circle(c, r - 2.5, Color(Peg.PLAYER_TRIM[p % 4]))
		var f := Hud.lettering()
		var n := str(p + 1)
		var fs := int(px * 0.62)
		draw_string(f, c + Vector2(-f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2.0, fs * 0.36), n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Hud.CREAM)
		var b := Vector2(px * 1.32, px / 2.0)
		var br := px * 0.3
		if state == "ready":   # a cream disc with an inked tick
			draw_circle(b + Vector2(0, 1.5), br, Hud.SHADOW)
			draw_circle(b, br, Hud.INK)
			draw_circle(b, br - 2.0, Hud.CREAM)
			draw_polyline(PackedVector2Array([b + Vector2(-br * 0.5, 0), b + Vector2(-br * 0.12, br * 0.42), b + Vector2(br * 0.55, -br * 0.45)]), Hud.INK, 3.0, true)
		elif state == "waiting":   # an empty ring: not yet
			draw_arc(b, br - 1.0, 0, TAU, 24, Color(Hud.INK, 0.55), 2.5, true)


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


## A rating out of five read by shape: earned slots are solid ink-rimmed discs, the
## rest thin open rings. Stars: solid gold stars, the rest hollow outlines.
class Rating extends Control:
	var value := 0
	var stars := false

	func _init(value_: int, stars_ := false) -> void:
		value = value_
		stars = stars_
		custom_minimum_size = Vector2(5 * (34 if stars else 18), 34 if stars else 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var step := size.x / 5.0
		var y := size.y / 2.0
		for i in 5:
			var c := Vector2(step * (i + 0.5), y)
			var on := i < value
			if stars:
				var r := step * 0.46
				var pts := Icons.star(0, 0, 1.0, 5, 0.5)
				var shape := PackedVector2Array()
				for p in pts:
					shape.append(c + Vector2(p.x, -p.y) * r)
				if on:
					var shadow := PackedVector2Array()
					for p in shape:
						shadow.append(p + Vector2(0, 2))
					draw_colored_polygon(shadow, Hud.INK)
					draw_colored_polygon(shape, Color(Icons.GOLD))
				draw_polyline(shape + PackedVector2Array([shape[0]]), Hud.INK, 2.5 if on else 1.6, true)
			elif on:
				draw_circle(c, 7.0, Hud.INK)
				draw_circle(c, 4.6, Hud.CORAL)
			else:
				draw_arc(c, 4.5, 0, TAU, 16, Color(Hud.INK, 0.6), 1.5, true)


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
static func box(ci: CanvasItem, r: Rect2, col: Color, radius: int, border := 0, border_col := Hud.INK) -> void:
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
			HudWidgets.box(self, pr, Hud.INK, 6)
			HudWidgets.box(self, pr.grow(-2), Hud.CREAM, 5)
			var head := Rect2(pr.position + Vector2(2, 2), Vector2(pr.size.x - 4, 24))
			HudWidgets.box(self, head, Hud.CORAL, 5)
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
			HudWidgets.box(self, Rect2(Vector2(-g, 6.0 - g + lift * 0.15), Vector2(SIDE + g * 2.0, SIDE + g * 2.0)),
				Color(Hud.SHADOW, Hud.SHADOW.a * 0.4 * fade), int(10 + g))
		var o := Vector2(0, -lift)
		HudWidgets.box(self, Rect2(o, Vector2(SIDE, SIDE)), Hud.INK, 10)
		HudWidgets.box(self, Rect2(o + Vector2(3, 3), Vector2(SIDE - 6, SIDE - 6)), Hud.WOOD.darkened(0.12), 8)
		HudWidgets.box(self, Rect2(o + Vector2(3, 3), Vector2(SIDE - 6, SIDE - 10)), Hud.WOOD, 8)
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
## The reputation meter on the board (review, item 9): a bar that fills from 0 to
## Ledger.REP_MAX, green when healthy, gold in the middle and coral near the bottom, with
## the number on it. A change wobbles it, so a walkout is felt.
class RepMeter extends Control:
	var value := Ledger.REP_START
	var _shake := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(190, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		if v < value - 0.5:
			_shake = 0.5
		value = v
		queue_redraw()

	func _process(delta: float) -> void:
		if _shake > 0.0:
			_shake = maxf(0.0, _shake - delta)
			queue_redraw()

	func _draw() -> void:
		var off := Vector2(sin(_shake * 60.0) * 4.0 * _shake, 0)
		var r := Rect2(Vector2(4, 8) + off, Vector2(size.x - 8, 26))
		draw_rect(r.grow(3), Color(Hud.INK), true)
		draw_rect(r, Color("#6b5647"), true)
		var k := clampf(value / Ledger.REP_MAX, 0.0, 1.0)
		var col := Color(Build.GOOD) if value >= 60.0 else (Color("#f2b632") if value >= Ledger.REP_LOW else Color(Hud.CORAL))
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), col, true)
		for t: float in [0.25, 0.5, 0.75]:   # notches, so it reads without the number
			draw_line(r.position + Vector2(r.size.x * t, 0), r.position + Vector2(r.size.x * t, 6), Color(Hud.INK, 0.6), 2.0)
		var font := get_theme_default_font()
		var txt := "%d" % roundi(value)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string_outline(font, Vector2(r.get_center().x - w / 2.0, r.end.y - 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(Hud.INK))
		draw_string(font, Vector2(r.get_center().x - w / 2.0, r.end.y - 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Hud.PAPER))


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
		HudWidgets.box(self, Rect2(-27, -8, 54, 12), Hud.INK, 3)
		HudWidgets.box(self, Rect2(-25, -6, 50, 8), red, 2)
		HudWidgets.box(self, Rect2(-31, -28, 62, 22), Hud.INK, 5)
		HudWidgets.box(self, Rect2(-28, -25, 56, 16), Hud.WOOD, 4)
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
			game.world._wall_visual(n, 0.9 + 0.1 * int(bp.tier))
		elif Treatments.is_laying_tool(bp.id):   # a floor treatment (PRD 9.5): planks with its sheen
			Scenery.tool_preview(n, "floor_planks")
			for c: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				n.add_child(FloorDirt.sheen_look(c, Treatments.key_of(bp.id)))
		elif Catalog.is_build_tool(bp.id):
			Scenery.tool_preview(n, bp.id)
		elif bp.id == "night_cleaner":   # a mop in its bucket: the cleaner's kit
			BuildStations.station(n, "mop_bucket", 1, "", false, "mop_bucket")
			BuildClean.bucket_mop(n, 1.0, "mop")
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
			BuildStations.station(n, bp.id, int(bp.tier), "counter" if bp.get("counter", false) else str(bp.get("base", "")), false, str(bp.get("node", "")))
			var tool := CleanTools.comes_with(str(bp.get("node", bp.id)))
			if CleanTools.is_mop(tool):   # a bucket up its tree shows the mop it keeps (PRD 9.5)
				BuildClean.bucket_mop(n, 1.0, tool)
			if CleanTools.home_kind(bp.id) != "" or bp.id in ["mop_bucket", "robot_dock", "sponge"]:
				n.scale = Vector3.ONE * 1.5   # small floor and wall pieces, shown at a piece's size
			if Catalog.is_box(bp.id):   # a box is small: shown up close, at a piece's size
				n.scale = Vector3.ONE * 1.9
				n.position.y = 0.05
		if not live:
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	## A townsperson's peg, head and shoulders (the critic's byline). Call once in the tree.
	func show_peg(person: String) -> void:
		var peg := Peg.guest(person)
		peg.set_face("content")
		peg.rotation.y = PI / 4   # facing the camera
		var rig := Peg.rigged(peg)
		rig.position.y = -0.2
		spin.add_child(rig)
		# Leaned back to face level (review, item 11), so the eyes show under a hat brim
		# and over a beard: a portrait is the face, not the top of the head.
		tilt.basis = Basis(LEAN, -0.8)
		for c in vp.get_children():
			if c is Camera3D:
				c.size = 1.5
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS   # the peg settles its hands first

	## 0 is flat on the floor; 1 is lifted and tipped toward the camera, as on show.
	func lift(t: float) -> void:
		tilt.basis = Basis(LEAN, 0.2 * t) * Basis(Vector3(0.7071, 0, 0.7071), 0.1 * t)
		tilt.position.y = lerpf(-0.3, 0.1, t)


class Sheet extends MarginContainer:
	var kind := "paper"
	var tint := Hud.CORAL
	var unavailable := false   # the "tab" prompt in its muted, can't-do-that-now look

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
				_box(r.grow(-5), Color("#c9b9a3") if unavailable else Color("#f0d9ae"), 7)
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
			"news":  # a newspaper cutting: grey-cream newsprint, scissor-cut a little crooked
				var w := size.x
				var h := size.y
				var shape := PackedVector2Array([Vector2(3, 0), Vector2(w * 0.55, 4), Vector2(w - 2, 1),
					Vector2(w, h * 0.5), Vector2(w - 4, h), Vector2(w * 0.4, h - 3), Vector2(0, h - 1), Vector2(2, h * 0.45)])
				var shadow := PackedVector2Array()
				for p in shape:
					shadow.append(p + Vector2(2, 6))
				draw_colored_polygon(shadow, Hud.SHADOW)
				draw_colored_polygon(shape, Hud.NEWSPRINT)
				draw_polyline(shape + PackedVector2Array([shape[0]]), Color(Hud.INK, 0.35), 1.5, true)
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


## A small white chevron on the order column: press it to move one note.
class Chevron extends Control:
	signal pressed
	var up := false

	func _init(up_: bool) -> void:
		up = up_
		custom_minimum_size = Vector2(44, 28)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()
		elif e is InputEventScreenTouch and e.pressed:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var c := size / 2.0
		var d := -1.0 if up else 1.0
		var pts := PackedVector2Array([c + Vector2(-13, -5 * d), c + Vector2(0, 5 * d), c + Vector2(13, -5 * d)])
		draw_polyline(pts, Hud.INK, 9.0, true)
		draw_polyline(pts, Color("#fffaf0"), 4.5, true)


## A ScrollContainer that also scrolls by dragging, which Godot only does itself on touchscreens.
class DragScroll extends ScrollContainer:
	func _gui_input(e: InputEvent) -> void:
		if DisplayServer.is_touchscreen_available():
			return   # the container's own touch drag
		if e is InputEventScreenDrag:
			scroll_vertical -= int(e.relative.y)
			accept_event()
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			scroll_vertical -= int(e.relative.y)
			accept_event()


## The open order tickets, oldest at the top, in a scrolling column down the left edge.
## Chevrons at the top and bottom show when notes are hidden that way.
class OrderColumn extends Control:
	const WIDTH := 210.0
	var scroll: DragScroll
	var list: VBoxContainer
	var up: Chevron
	var down: Chevron
	var _tween: Tween

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroll = DragScroll.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(scroll)
		list = VBoxContainer.new()
		list.add_theme_constant_override("separation", 8)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroll.add_child(list)
		up = Chevron.new(true)
		up.set_anchors_preset(Control.PRESET_CENTER_TOP)
		up.pressed.connect(_step.bind(-1))
		add_child(up)
		down = Chevron.new(false)
		down.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		down.pressed.connect(_step.bind(1))
		add_child(down)

	func _process(_delta: float) -> void:
		var hidden_above := scroll.scroll_vertical > 1
		var hidden_below := scroll.scroll_vertical < max_scroll() - 1
		if up.visible != hidden_above:
			up.visible = hidden_above
		if down.visible != hidden_below:
			down.visible = hidden_below

	func max_scroll() -> int:
		return maxi(0, int(list.get_combined_minimum_size().y - scroll.size.y))

	## Glides to the next note's top in that direction (1 down, -1 up).
	func _step(dir: int) -> void:
		var here := scroll.scroll_vertical
		var want := here
		if dir > 0:
			for c: Control in list.get_children():
				if c.position.y > here + 1.0:
					want = int(c.position.y)
					break
		else:
			for c: Control in list.get_children():
				if c.position.y < here - 1.0:
					want = int(c.position.y)
		want = clampi(want, 0, max_scroll())
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(scroll, "scroll_vertical", want, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
