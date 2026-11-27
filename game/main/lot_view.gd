class_name GameLotView
extends RefCounted
## The lot in the build phase: a subtle white line round the owned ground, and each block the
## player can buy drawn as a faint outline with a + and its price. A chef at (or facing) one
## who holds the shop button buys it. Drawn only at night and only while a chef is outside the
## restaurant (standing on a cell with no floor); it fades in and out over FADE_TIME.

const HOLD_TIME := 0.8            # seconds the shop button is held to buy (tunable)
const LINE_W := 0.05
const EDGE_ALPHA := 0.3         # owned-lot edge
const BLOCK_ALPHA := 0.12       # buyable-block outline
const LINE_Y := 0.03
const FADE_TIME := 0.2          # seconds to fade the overlay in or out

var game: Game
var _root: Node3D
var _key := ""
var _shown := false               # whether the overlay was showing at the last redraw
var _hold := {}                   # Player -> seconds held; -1 once refused, until let go


func _init(game_: Game) -> void:
	game = game_


## The buyable block a chef is standing in or facing, or Vector2i.MAX.
func block_for(ch: Player) -> Vector2i:
	if game.phase != Game.Phase.BUILD or game.shopper == ch or not _outside(ch):
		return Vector2i.MAX
	var open := game.lot.buyable()
	for c: Vector2i in [Grid.to_cell(ch.position), ch.target_cell()]:
		var b := Lot.block_of(c)
		if open.has(b):
			return b
	return Vector2i.MAX


## Redraws the overlay when what it shows has changed, and counts a chef's hold.
func update(ch: Player, held: bool, delta: float) -> void:
	_redraw()
	tick(ch, held, delta)


## One frame of a chef holding (or not) the shop button at a block.
func tick(ch: Player, held: bool, delta: float) -> void:
	var b := block_for(ch)
	if not held or b == Vector2i.MAX:
		_hold.erase(ch)
		return
	var t: float = _hold.get(ch, 0.0)
	if t < 0.0:
		return
	t += delta
	_hold[ch] = t
	if t >= HOLD_TIME:
		_hold[ch] = -1.0
		buy(b)


## Pays for a block and adds it, or says why not.
func buy(b: Vector2i) -> bool:
	var price := game.lot.next_price()
	if not game.lot.buyable().has(b):
		return false
	if game.ledger.money < price:
		game.hud.day_ui.say("A new lot costs $%d. You have $%d." % [price, game.ledger.money])
		game.audio.sfx("fail")
		return false
	game.ledger.spend(price)
	game.lot.buy(b)
	game.undo.record_lot(b, price)
	game.audio.sfx("coin")
	game.world._sync_grid()
	game.room_edit._plan_changed()
	return true


## A chef is outside when the cell they stand on has no floor (pavement, doorway, bare lot).
func _outside(ch: Player) -> bool:
	return not game.plan.has_floor(Grid.to_cell(ch.position))


func _any_outside() -> bool:
	for ch: Player in game.chefs:
		if _outside(ch):
			return true
	return false


func _redraw() -> void:
	var show := game.phase == Game.Phase.BUILD and _any_outside()
	var glyph: String = game.controls.glyph("shop") if game.controls else "Tab"
	var price := game.lot.next_price()
	var key := "%s|%d|%d|%d|%s|%s" % [show, game.lot.blocks.hash(), game.lot.bought, price, game.ledger.money >= price, glyph]
	if key == _key:
		return
	_key = key
	var was_shown := _shown
	_shown = show
	if _root:
		if was_shown and not show and game.phase == Game.Phase.BUILD:
			_fade(_root, false)   # a chef went back inside: fade out, then free
		else:
			_root.queue_free()
		_root = null
	if not show:
		return
	_root = Node3D.new()
	_root.name = "LotView"
	game.add_child(_root)
	var white := Color(Build.PAPER)
	for b: Vector2i in game.lot.blocks:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not game.lot.blocks.has(b + d):
				_edge(Lot.block_rect(b), d, Color(white, EDGE_ALPHA))
	var afford := game.ledger.money >= game.lot.next_price()
	for b: Vector2i in game.lot.buyable():
		var r := Lot.block_rect(b)
		var inner := r.grow(-1)
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			_side(inner, d, Color(white, BLOCK_ALPHA))
		var mid := Grid.center(r.position + r.size / 2)
		_label("+", mid + Vector3(0, 0.1, 0), 120, 0.012, white)
		var tint := Color(Build.TRIM) if afford else Color(Build.TRIM, 0.6)
		_label("$%d" % game.lot.next_price(), mid + Vector3(0, 0.75, 1.1), 56, 0.01, tint)
		_label("hold %s" % glyph, mid + Vector3(0, 0.25, 1.1), 30, 0.008, tint)
	if not was_shown:
		_fade(_root, true)


## Fades every strip and label under `root` in (then leaves them) or out (then frees `root`).
## The tween lives on the node, not on this RefCounted part.
func _fade(root: Node3D, appear: bool) -> void:
	var base := {}   # node -> [color alpha, outline alpha]
	for n in root.get_children():
		if n is MeshInstance3D:
			base[n] = [(n.material_override as StandardMaterial3D).albedo_color.a, 1.0]
		elif n is Label3D:
			base[n] = [n.modulate.a, n.outline_modulate.a]
	var apply := func(f: float) -> void:
		for n: Node in base:
			if not is_instance_valid(n):
				continue
			var a: Array = base[n]
			if n is MeshInstance3D:
				var mat := (n as MeshInstance3D).material_override as StandardMaterial3D
				mat.albedo_color.a = a[0] * f
			else:
				(n as Label3D).modulate.a = a[0] * f
				(n as Label3D).outline_modulate.a = a[1] * f
	var from := 0.0 if appear else 1.0
	apply.call(from)
	var tw := root.create_tween()
	tw.tween_method(apply, from, 1.0 - from, FADE_TIME)
	if not appear:
		tw.tween_callback(root.queue_free)


## The owned-lot edge one cell at a time, leaving out cells with floor behind them: a room
## wall stands on that edge and the line would show over it.
func _edge(r: Rect2i, d: Vector2i, col: Color) -> void:
	for i in (r.size.y if d.x != 0 else r.size.x):
		var cell := Vector2i(r.position.x + (r.size.x - 1 if d.x > 0 else 0), r.position.y + i) if d.x != 0 \
			else Vector2i(r.position.x + i, r.position.y + (r.size.y - 1 if d.y > 0 else 0))
		if not game.plan.has_floor(cell):
			_side(Rect2i(cell, Vector2i.ONE), d, col)


## One edge of a rect (the side `d` faces) as a flat strip on the ground.
func _side(r: Rect2i, d: Vector2i, col: Color) -> void:
	var a := Vector3(r.position.x, 0, r.position.y)
	var s := Vector3(r.size.x, 0, r.size.y)
	var pos := a + s / 2.0
	var size := Vector3(s.x, 0.01, s.z)
	if d.x != 0:
		pos.x = a.x + (s.x if d.x > 0 else 0.0)
		size.x = LINE_W
	else:
		pos.z = a.z + (s.z if d.y > 0 else 0.0)
		size.z = LINE_W
	size += Vector3(LINE_W if d.x == 0 else 0.0, 0, LINE_W if d.x != 0 else 0.0)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos + Vector3(0, LINE_Y, 0)
	_root.add_child(m)


func _label(text: String, at: Vector3, font_size: int, pixel: float, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.no_depth_test = true
	l.font = Hud.lettering()
	l.font_size = font_size
	l.outline_size = 10
	l.pixel_size = pixel
	l.modulate = col
	l.outline_modulate = Color(Build.PAPER) if col != Color(Build.PAPER) else Color(Build.TRIM)
	l.position = at
	_root.add_child(l)
