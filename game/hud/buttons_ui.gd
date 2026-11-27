class_name HudButtons
extends RefCounted
## The button set: a paper-and-wood disc for every action the keys have. Shop, Dishes,
## C (sell or erase), Back and the options cog show only while they do something; on touch
## Use, Aim (held) and Turn join them. On keyboard and pad each wears its key
## (`controls.glyph`); on touch it wears none and a tap does the work. A press is the
## action's key: `game.coop.act(owner, action)`. `Controls.buttons()` reads `specs()`
## to hit-test fingers, so touch and clicks share one set of discs.

const HOLD := ["use", "aim", "reach"]   ## held by a finger, not pressed once
const ORDER := ["use", "aim", "reach", "turn", "sell", "shop", "menu", "undo", "back", "options"]
const ICONS := {"use": "use", "aim": "aim", "reach": "reach", "turn": "turn", "sell": "sell", "shop": "shop",
	"menu": "dishes", "undo": "undo", "back": "back", "options": "cog"}

var hud
var game: Game
var _nodes := {}   # id -> IconButton


func _init(hud_) -> void:
	hud = hud_


## Makes the discs, hidden, over the room. Called by Hud.setup once its root exists.
func build() -> void:
	game = hud.game
	for id: String in ORDER:
		var b := IconButton.new(ICONS[id])
		b.visible = false
		b.sfx = func(s: String) -> void: game.audio.sfx(s)
		b.pressed.connect(activate.bind(id))
		hud.root.add_child(b)
		_nodes[id] = b


## The player whose buttons these are: the screen's while it is their device, else the keyboard's.
func owner_id() -> int:
	var c: Controls = game.controls
	var t := c.owner_of("touch")
	return t if c.players[t].mode == "touch" else c.owner_of("keys")


## What shows now, bottom of the right column first: {id, label, icon, key, centre, r, badge, blocked, face}.
func specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c: Controls = game.controls
	if c == null or game.hud.options_ui.title_open():
		return out
	var p := owner_id()
	var touch: bool = c.players[p].mode == "touch"
	var size: Vector2 = hud.root.get_rect().size
	var ch: Player = game.chefs[p] if p < game.chefs.size() else null
	var hand: Dictionary = ch.hand if ch != null else {}
	var build: bool = game.phase == game.Phase.BUILD
	var options: bool = game.hud.options_ui.options_open() or game.hud.options_ui.pause_open()
	var card: bool = game.hud.card_open()
	var shop: bool = game.shopping and ch != null and game.shopper == ch
	var tool: bool = not hand.is_empty() and Catalog.is_build_tool(hand.id)
	var free: bool = build and not shop and not card and not options   # the room is the player's
	var d := IconButton.THUMB if touch else IconButton.REACH
	var r := d / 2.0
	var x := size.x - (92.0 if touch else 56.0)
	var y := size.y - (112.0 if touch else 70.0)
	var want: Array[Dictionary] = []
	if touch and not card and not options and (game.phase == game.Phase.SERVICE or free):
		var word: String = hud.last_action if hud.last_action != "" else "Use"
		want.append({"id": "use", "badge": word, "r": Controls.USE_R, "face": Hud.CORAL,
			"centre": Vector2(x, y)})
		want.append({"id": "aim", "r": r, "centre": Vector2(x - Controls.USE_R - r - 18.0, y + Controls.USE_R - r)})
		if ch != null and (game.card.reaching(ch) or game.card.reach_action(ch) != ""):   # only where something hangs to reach
			want.append({"id": "reach", "r": r, "centre": Vector2(x - Controls.USE_R - r - 18.0, y + Controls.USE_R - r - d - 14.0)})
		y -= Controls.USE_R + r + 16.0
	var step := d + (14.0 if touch else 30.0)
	if free:
		if tool:
			want.append({"id": "sell", "icon": "erase", "centre": Vector2(x, y), "held": c.players[p].erase and touch})
			y -= step
		elif not hand.is_empty():
			if touch:
				want.append({"id": "turn", "centre": Vector2(x, y)})
				y -= step
			if hand.get("moving", false):
				var why: String = game.placing.sell_block(ch)
				want.append({"id": "sell", "badge": "$%d" % game.placing.sell_value(ch), "blocked": why != "",
					"centre": Vector2(x, y)})
				y -= step
		want.append({"id": "shop", "centre": Vector2(x, y)})
		y -= step
		if hand.is_empty():
			want.append({"id": "menu", "centre": Vector2(x, y)})
			y -= step
			if game.undo.has_steps():
				want.append({"id": "undo", "centre": Vector2(x, y)})
	var top := 18.0 + r
	var back: bool = (free and not hand.is_empty()) or shop or ((card or options) and not touch)
	if back:
		want.append({"id": "back", "centre": Vector2(x, top)})
	want.append({"id": "options", "centre": Vector2(x, top + d + 26.0)})
	for w in want:
		var id: String = w.id
		w["label"] = c.glyph(id, p)
		w["key"] = c.glyph(id, p)
		w["touch"] = touch
		w["r"] = w.get("r", r)
		w["icon"] = w.get("icon", ICONS[id])
		w["badge"] = w.get("badge", "")
		w["blocked"] = w.get("blocked", false)
		w["held"] = w.get("held", false)
		w["face"] = w.get("face", Color(0, 0, 0, 0))
		out.append(w)
	return out


## Shows the discs `specs()` names, wearing the owner's live keys.
func update() -> void:
	if game == null or game.controls == null or _nodes.is_empty():
		return
	var on := {}
	var fingers: Array = game.controls.held_ids()
	for s in specs():
		var b: IconButton = _nodes[s.id]
		on[s.id] = true
		b.span = s.r * 2.0 if s.r > IconButton.THUMB / 2.0 else 0.0
		b.set_touch(s.touch)
		b.set_key(s.key)
		b.set_icon(s.icon)
		b.set_badge(s.badge)
		b.set_blocked(s.blocked)
		b.face = s.face
		b.set_held(s.held or s.id in fingers)
		b.position = s.centre - Vector2(b.disc_width() / 2.0, b.disc_width() / 2.0)
		b.visible = true
	for id: String in _nodes:
		if not on.has(id):
			_nodes[id].visible = false


## A press on a disc: the key's action, for the buttons' owner. A sale that cannot be made
## fails out loud and says why; a build tool's C toggles erasing on touch.
func activate(id: String) -> void:
	var p := owner_id()
	var ch: Player = game.chefs[p] if p < game.chefs.size() else null
	if id == "sell" and ch != null:
		if game.controls.players[p].mode == "touch" and not ch.hand.is_empty() and Catalog.is_build_tool(ch.hand.id):
			game.controls.players[p].erase = not game.controls.players[p].erase
			return
		var why: String = game.placing.sell_block(ch)
		if why != "":
			game.audio.sfx("fail")
			hud.day_ui.say(why)
			return
	game.coop.act(p, id)
