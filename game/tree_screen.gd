class_name TreeScreen
extends Control
## The upgrade tree (PRD 8.3): what the shop shows when it is opened with a piece in
## hand. A wooden tray like the shop's, but on blue blueprint paper with white lines.
## The held piece sits on the left; its line forks to the right, one row per branch:
## an efficient step goes straight on along the row, a specialist forks down to a new
## row. A branch that runs off the paper ends in an arrow, and the view scrolls to it.
## Each node shows the piece, its jobs as tool icons with a quality pip, and the step's
## price. Only a node next to the held piece can be bought; it becomes the held piece.
## The rules live in Upgrades (sim/); this only draws and picks.

const BLUE := Color("#2c5c8c")
const BLUE_DEEP := Color("#22486f")
const LINE := Color(1, 1, 1, 0.92)
const GRID := Color(1, 1, 1, 0.07)
const GOLD := Color("#ffd166")
const NO := Color("#ffb3a3")
const CARD := Vector2(176, 206)   # one node
const COL := 252.0                # from one column to the next
const ROW := 226.0                # from one row to the next
const PAD := Vector2(26, 18)      # the paper's margin round the tree
const VIEW := Vector2(1180, 452)  # the most paper you can see; the tree scrolls behind it
const DROP := 320.0               # how far below its place the tray waits

var game
var hud
var root_key := ""          # the held piece: the tree is drawn from it
var selected := ""
var lay := {}               # key -> Vector2i(column, row)
var cards := {}             # key -> Card
var _views: Array = []
var _clip: Control
var _content: Control
var _over: Control
var _scroll := Vector2.ZERO
var view := VIEW            # the paper shown: no taller than the tree needs
var _scroll_tween: Tween
var _title: Label
var _info: Label
var _blurb: Label
var _state: Label


func _init(game_, hud_, key: String, keys_text: String) -> void:
	game = game_
	hud = hud_
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var wood := Hud.Sheet.new("wood", 10, 10)
	wood.mouse_filter = Control.MOUSE_FILTER_STOP
	wood.size_flags_vertical = Control.SIZE_SHRINK_END
	wood.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(wood)
	var paper := Blueprint.new()
	paper.add_theme_constant_override("margin_left", 16)
	paper.add_theme_constant_override("margin_right", 16)
	paper.add_theme_constant_override("margin_top", 10)
	paper.add_theme_constant_override("margin_bottom", 10)
	wood.add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	paper.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	box.add_child(head)
	_title = _text(head, 22, "", LINE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var legend := Legend.new()
	head.add_child(legend)

	_clip = Control.new()
	_clip.custom_minimum_size = VIEW
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	_clip.gui_input.connect(_clip_input)
	box.add_child(_clip)
	_content = Lines.new(self)
	_clip.add_child(_content)
	_over = Arrows.new(self)
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip.add_child(_over)

	var about := HBoxContainer.new()
	about.add_theme_constant_override("separation", 14)
	box.add_child(about)
	_info = _text(about, 21, "", LINE)
	_blurb = _text(about, 17, "", Color(LINE, 0.75))
	_blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blurb.clip_text = true
	_state = _text(about, 19, "", GOLD)
	var keys := _text(about, 15, keys_text, Color(LINE, 0.7))
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	set_root(key)


func _ready() -> void:
	position.y = DROP   # the tray slides up from under the screen, as the shop's does
	create_tween().tween_property(self, "position:y", 0.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _text(parent: Node, px: int, s: String, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", BLUE_DEEP)
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l


## Draws the tree of the piece now held, its first next step chosen.
func set_root(key: String) -> void:
	root_key = key
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	cards.clear()
	_views.clear()
	lay = Upgrades.layout(key)
	var ext := Upgrades.extent(lay)
	_content.size = Vector2(PAD.x * 2 + (ext.x - 1) * COL + CARD.x, PAD.y * 2 + (ext.y - 1) * ROW + CARD.y)
	view = Vector2(VIEW.x, minf(VIEW.y, _content.size.y))
	_clip.custom_minimum_size = view
	_title.text = "UPGRADE THE %s" % Upgrades.name_of(key).to_upper()
	for k: String in lay:
		var card := Card.new(self, k)
		card.position = card_pos(k)
		_content.add_child(card)
		cards[k] = card
	var kids := Upgrades.children(key)
	_scroll = Vector2.ZERO
	_content.position = Vector2.ZERO
	select(kids[0] if not kids.is_empty() else key)
	_content.queue_redraw()


## Where a node's card sits on the tree.
func card_pos(k: String) -> Vector2:
	var at: Vector2i = lay[k]
	return PAD + Vector2(at.x * COL, at.y * ROW)


## What a node is to the held piece: "held", "next" (can be bought now), or "later".
func state_of(k: String) -> String:
	if k == root_key:
		return "held"
	return "next" if Upgrades.parent(k) == root_key else "later"


func select(k: String) -> void:
	if not lay.has(k):
		return
	selected = k
	for c: String in cards:
		cards[c].queue_redraw()
	_info.text = Upgrades.name_of(k)
	_blurb.text = Upgrades.blurb(k)
	_state.text = _why(k)
	_show(k)


## The line under the tree: what buying the chosen node would take.
func _why(k: String) -> String:
	match state_of(k):
		"held":
			return "In hand"
		"later":
			return "Buy the %s first" % Upgrades.name_of(Upgrades.parent(k))
	if game.ledger.level() < Upgrades.level(k):
		return "Needs level %d" % Upgrades.level(k)
	if game.ledger.money < Upgrades.step_price(k):
		return "$%d: not enough money" % Upgrades.step_price(k)
	return "$%d to upgrade" % Upgrades.step_price(k)


## Scrolls the paper so a node's card is in full view.
func _show(k: String) -> void:
	var r := Rect2(card_pos(k) - PAD, CARD + PAD * 2)
	var want := _scroll
	want.x = clampf(want.x, r.end.x - view.x, r.position.x)
	want.y = clampf(want.y, r.end.y - view.y, r.position.y)
	want = want.clamp(Vector2.ZERO, (_content.size - view).max(Vector2.ZERO))
	if want.is_equal_approx(_scroll):
		_over.queue_redraw()
		return
	_scroll = want
	if _scroll_tween:
		_scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(_content, "position", -want, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scroll_tween.parallel().tween_method(func(_t: float) -> void: _over.queue_redraw(), 0.0, 1.0, 0.3)


## Moves the choice to the nearest node that way: right along a row or into a fork,
## left back toward the held piece, up and down between rows.
func move(action: String) -> void:
	var dir: Vector2i = {"left": Vector2i(-1, 0), "right": Vector2i(1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1)}[action]
	var from: Vector2i = lay[selected]
	var best := ""
	var best_d := INF
	for k: String in lay:
		var d: Vector2i = lay[k] - from
		var along := d.x * dir.x + d.y * dir.y
		if along <= 0:
			continue
		var across := absi(d.x * dir.y) + absi(d.y * dir.x)
		var score := along + across * 2.5
		if score < best_d:
			best_d = score
			best = k
	if best != "":
		game.sfx("tick", 0.1)
		select(best)


## Buys the chosen node: the held piece becomes it, and the tree is drawn from there.
## A refusal shakes the card.
func buy() -> bool:
	if state_of(selected) == "next" and game.buy_upgrade(selected):
		set_root(selected)
		var card: Control = cards[root_key]
		card.pivot_offset = CARD / 2.0
		card.scale = Vector2.ONE * 1.12
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return true
	game.sfx("fail")
	var c: Control = cards[selected]
	var x := c.position.x
	var no := c.create_tween()
	for dx: float in [-10.0, 8.0, -5.0, 0.0]:
		no.tween_property(c, "position:x", x + dx, 0.05)
	return false


## A tap or click on a card: the first chooses it, the second buys it.
func card_pressed(k: String) -> void:
	if k == selected:
		buy()
	else:
		game.sfx("tick", 0.1)
		select(k)


func _clip_input(event: InputEvent) -> void:
	var by := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN: by = Vector2(0, 60)
			MOUSE_BUTTON_WHEEL_UP: by = Vector2(0, -60)
			MOUSE_BUTTON_WHEEL_RIGHT: by = Vector2(60, 0)
			MOUSE_BUTTON_WHEEL_LEFT: by = Vector2(-60, 0)
		if event.shift_pressed:
			by = Vector2(by.y, by.x)
	elif event is InputEventPanGesture:
		by = event.delta * 20.0
	elif event is InputEventScreenDrag:
		by = -event.relative
	if by == Vector2.ZERO:
		return
	_scroll = (_scroll + by).clamp(Vector2.ZERO, (_content.size - view).max(Vector2.ZERO))
	if _scroll_tween:
		_scroll_tween.kill()
	_content.position = -_scroll
	_over.queue_redraw()
	_clip.accept_event()


## The paper's visible rect in tree coordinates.
func view_rect() -> Rect2:
	return Rect2(-_content.position, view)


# ---------------------------------------------------------------- pieces of the screen

## Blue blueprint paper: a faint grid, a white rule inset from the edge.
class Blueprint extends MarginContainer:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = BLUE
		sb.set_corner_radius_all(6)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(r.position + Vector2(0, 4), r.size).grow(0))
		sb.bg_color = BLUE
		draw_style_box(sb, r)
		var step := 24.0
		var x := step
		while x < size.x:
			draw_line(Vector2(x, 2), Vector2(x, size.y - 2), GRID, 1.0)
			x += step
		var y := step
		while y < size.y:
			draw_line(Vector2(2, y), Vector2(size.x - 2, y), GRID, 1.0)
			y += step
		draw_rect(r.grow(-5), Color(LINE, 0.5), false, 1.5)


## A key to the two kinds of line, top right.
class Legend extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(430, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := get_theme_default_font()
		var y := 14.0
		draw_line(Vector2(0, y), Vector2(40, y), LINE, 3.0)
		draw_string(font, Vector2(48, y + 6), "efficient: a bit better", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(LINE, 0.85))
		var x := 228.0
		draw_polyline(PackedVector2Array([Vector2(x, y - 8), Vector2(x + 14, y - 8), Vector2(x + 14, y + 6), Vector2(x + 40, y + 6)]), LINE, 3.0)
		Arrows.diamond(self, Vector2(x + 14, y + 6), 5.0)
		draw_string(font, Vector2(x + 48, y + 6), "specialist: a new row", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(LINE, 0.85))


## The tree's lines, drawn under its cards: straight on for an efficient step, a fork
## down to a new row for a specialist.
class Lines extends Control:
	var screen

	func _init(screen_) -> void:
		screen = screen_
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for k: String in screen.lay:
			var up: String = Upgrades.parent(k)
			if up == "" or not screen.lay.has(up):
				continue
			var p := Rect2(screen.card_pos(up), CARD)
			var c := Rect2(screen.card_pos(k), CARD)
			var y0 := p.position.y + CARD.y * 0.42
			var y1 := c.position.y + CARD.y * 0.42
			var col := LINE if screen.state_of(k) != "later" else Color(LINE, 0.55)
			if Upgrades.step(k) == Kitchen.EFFICIENT and is_equal_approx(y0, y1):
				draw_line(Vector2(p.end.x, y0), Vector2(c.position.x, y1), col, 3.0, true)
				_chevron(Vector2((p.end.x + c.position.x) / 2.0, y1), col)
			else:
				var fx := p.end.x + 24.0
				draw_polyline(PackedVector2Array([Vector2(p.end.x, y0), Vector2(fx, y0), Vector2(fx, y1), Vector2(c.position.x, y1)]), col, 3.0, true)
				Arrows.diamond(self, Vector2(fx, y1), 6.0, col)

	func _chevron(at: Vector2, col: Color) -> void:
		draw_polyline(PackedVector2Array([at + Vector2(-6, -8), at + Vector2(2, 0), at + Vector2(-6, 8)]), col, 3.0, true)


## Arrows at the paper's edge where a branch runs on out of view.
class Arrows extends Control:
	var screen

	func _init(screen_) -> void:
		screen = screen_
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func diamond(c: CanvasItem, at: Vector2, r: float, col := LINE) -> void:
		c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), col)

	func _draw() -> void:
		var view: Rect2 = screen.view_rect()
		var done := {}
		for k: String in screen.lay:
			var c := Rect2(screen.card_pos(k), CARD)
			if view.encloses(c.grow(-30)):
				continue
			var up: String = Upgrades.parent(k)
			if screen.lay.has(up) and not view.intersects(Rect2(screen.card_pos(up), CARD)):
				continue   # its parent is off the paper too: the parent's arrow says it
			var at := Vector2.ZERO
			var dir := Vector2.ZERO
			if c.position.x >= view.end.x - 30:
				dir = Vector2.RIGHT
				at = Vector2(screen.view.x - 18, clampf(c.position.y + CARD.y * 0.42 - view.position.y, 24, screen.view.y - 24))
			elif c.position.y >= view.end.y - 30:
				dir = Vector2.DOWN
				at = Vector2(clampf(c.position.x - 24 - view.position.x, 24, screen.view.x - 24), screen.view.y - 18)
			elif c.end.x <= view.position.x + 30:
				dir = Vector2.LEFT
				at = Vector2(18, clampf(c.position.y + CARD.y * 0.42 - view.position.y, 24, screen.view.y - 24))
			elif c.end.y <= view.position.y + 30:
				dir = Vector2.UP
				at = Vector2(clampf(c.position.x - 24 - view.position.x, 24, screen.view.x - 24), 18)
			else:
				continue
			# Right and down: an arrow where each branch runs off. Back up or left, one is enough.
			var tag := "%d,%d,%d" % [int(at.x / 30), int(at.y / 30), int(dir.angle() * 10)] \
					if dir == Vector2.RIGHT or dir == Vector2.DOWN else str(dir)
			if done.has(tag):
				continue
			done[tag] = true
			var side := dir.orthogonal()
			draw_circle(at, 17.0, Color(BLUE_DEEP, 0.9))
			draw_colored_polygon(PackedVector2Array([at + dir * 11, at - dir * 7 + side * 10, at - dir * 2, at - dir * 7 - side * 10]), LINE)


## One node: its picture, its name, its jobs with quality pips, and the step's price.
class Card extends Control:
	var screen
	var key := ""

	func _init(screen_, key_: String) -> void:
		screen = screen_
		key = key_
		size = CARD
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "%s\n%s" % [Upgrades.name_of(key), Upgrades.blurb(key)]
		gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				screen.card_pressed(key))
		var later: bool = screen.state_of(key) == "later"
		var view := Hud.ModelView.new(112, false)
		view.position = Vector2((CARD.x - 112) / 2.0, 2)
		view.modulate = Color(1, 1, 1, 0.6 if later else 1.0)
		add_child(view)
		view.tree_entered.connect(func() -> void:
			view.show_piece(screen.game, _blueprint())
			view.lift(0.6)
			_frame(view), CONNECT_ONE_SHOT)
		var name_l: Label = screen._text(self, 15, Upgrades.name_of(key), LINE)
		name_l.position = Vector2(4, 112)
		name_l.size = Vector2(CARD.x - 8, 20)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.clip_text = true
		var jobs := HBoxContainer.new()
		jobs.alignment = BoxContainer.ALIGNMENT_CENTER
		jobs.add_theme_constant_override("separation", 3)
		jobs.position = Vector2(0, 134)
		jobs.size = Vector2(CARD.x, 34)
		add_child(jobs)
		_fill_jobs(jobs)
		var price: Label = screen._text(self, 20, _price(), GOLD if not later else Color(LINE, 0.6))
		price.position = Vector2(0, 172)
		price.size = Vector2(CARD.x, 28)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if screen.state_of(key) == "next" and not Upgrades.can_buy(screen.root_key, key, screen.game.ledger.money, screen.game.ledger.level()):
			price.add_theme_color_override("font_color", NO)

	## A tool on a counter is framed closer than the shop's default, so its top (the part
	## a step changes: a crank, a second pan, grill bars) reads at card size.
	func _frame(view) -> void:
		if Upgrades.is_tiered(key) or not Kitchen.has_node(key) or Kitchen.fit_of(key) != "top":
			return
		for c in view.vp.get_children():
			if c is Camera3D:
				c.size = 1.45
				c.position = Vector3(0, 1.0, 0) + Vector3(14, 15, 14)

	## What ModelView draws for this node.
	func _blueprint() -> Dictionary:
		var id := Upgrades.catalog_id(key)
		if Upgrades.is_tiered(key):
			return {"id": id, "tier": Upgrades.tier_of(key)}
		var fit := Kitchen.fit_of(key)
		return {"id": id, "tier": 1, "node": key, "base": key if fit == "counter" or fit == "tall" else ""}

	func _price() -> String:
		match screen.state_of(key):
			"held":
				return "In hand"
		if screen.game.ledger.level() < Upgrades.level(key):
			return "Level %d" % Upgrades.level(key)
		return "+$%d" % Upgrades.step_price(key)

	## The jobs as tool icons, each with its quality pip; storage as a crate with its
	## count; a tiered piece as a heart with a pip a tier.
	func _fill_jobs(row: HBoxContainer) -> void:
		if Upgrades.is_tiered(key):
			row.add_child(Hud.Icon.new("heart", 34))
			for i in Upgrades.tier_of(key):
				row.add_child(Pip.new(Kitchen.BASE + Kitchen.EFFICIENT_STEP if i > 0 else Kitchen.BASE))
			return
		var jobs := Upgrades.jobs(key)
		var order: Array = jobs.keys()
		order.sort_custom(func(a: String, b: String) -> bool: return jobs[a] > jobs[b])
		for job: String in order:
			var ic := Hud.Icon.new("job_" + job, 34)
			ic.tooltip_text = "%s %.2f" % [job, jobs[job]]
			row.add_child(ic)
			row.add_child(Pip.new(float(jobs[job]), Kitchen.is_auto(key)))
		if Kitchen.slots_of(key) > 0:
			row.add_child(Hud.Icon.new("job_chill" if Kitchen.chills(key) else "job_store", 34))
			var n: Label = screen._text(row, 16, "x%d" % Kitchen.slots_of(key), LINE)
			n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pans := int(Kitchen.NODES[key].get("pans", 1))
		if pans > 1:
			var n: Label = screen._text(row, 16, "x%d" % pans, LINE)
			n.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var st: String = screen.state_of(key)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.anti_aliasing = true
		sb.bg_color = Color(1, 1, 1, 0.16) if st == "held" else Color(BLUE_DEEP, 0.55)
		sb.set_border_width_all(3 if st != "later" else 2)
		sb.border_color = LINE if st != "later" else Color(LINE, 0.45)
		if key == screen.selected:
			sb.border_color = GOLD
			sb.set_border_width_all(5)
		draw_style_box(sb, r)
		if st == "later":   # a dashed inner rule: not yet within reach
			var inner := r.grow(-7)
			for e: Array in [[inner.position, Vector2(inner.end.x, inner.position.y)], [Vector2(inner.end.x, inner.position.y), inner.end],
					[inner.end, Vector2(inner.position.x, inner.end.y)], [Vector2(inner.position.x, inner.end.y), inner.position]]:
				draw_dashed_line(e[0], e[1], Color(LINE, 0.25), 1.5, 6.0)


## A quality pip, said by shape: a hollow ring for a stand-in (under 1), a dot for a
## tool at its own job, a dot with a plus for a better one, a star for a specialist
## (1.6 and up), and a star in a ring for a piece that plays itself.
class Pip extends Control:
	var q := 1.0
	var auto := false

	func _init(q_: float, auto_ := false) -> void:
		q = q_
		auto = auto_
		custom_minimum_size = Vector2(16, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(8, 17)
		if q >= Kitchen.SPECIALIST - 0.01:
			draw_colored_polygon(_star(c, 7.5), GOLD)
			if auto:
				draw_arc(c, 8.5, 0, TAU, 20, LINE, 1.5, true)
		elif q < Kitchen.BASE - 0.01:
			draw_arc(c, 4.5, 0, TAU, 16, LINE, 2.0, true)
		else:
			draw_circle(c, 5.0, LINE)
			if q > Kitchen.BASE + 0.01:
				draw_line(c + Vector2(-3, -9), c + Vector2(3, -9), GOLD, 2.0)
				draw_line(c + Vector2(0, -12), c + Vector2(0, -6), GOLD, 2.0)

	func _star(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 10:
			var a := PI * i / 5.0
			pts.append(c + Vector2(sin(a), -cos(a)) * (r if i % 2 == 0 else r * 0.45))
		return pts
