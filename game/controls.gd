class_name Controls
extends CanvasLayer
## Input, per player. Every device is a source: "keys" (keyboard and mouse),
## "pad:<id>" (each controller) and "touch" (the screen). A source is seated
## to one player (`seats`; anything unseated is player 0's), and each player has
## a `PlayerInput` that remembers the device they used last, their stick and
## what they hold down. A press becomes an action ("use", "back", "turn",
## "sell", "shop", "town", "options", "confirm", "search", "mute" and the
## browse directions "up", "down", "left", "right") and goes to the game as
## `game.act(player, action)`, so all three devices share one set of rules.
## Movement is read with move(player).
##
## One chef today, so every source is seated to player 0 and whichever device
## was used last is that player's `mode`: a player can pick up a pad or reach
## for the screen at any moment. Co-op seats a pad to a new player index.
##
## Keys: WASD or arrows walk (and browse), E/Space use, Enter confirm, Esc back,
## R turn, X sell, Tab shop, T town, O options, F search, M mute, N the menu screen
## (R on an ingredient station at night switches its stock).
## Controller: left stick or d-pad walk (the d-pad also browses), A use (confirm
## on the receipt and the end screen), B back, X sell, Y shop (town on the
## receipt), LB/RB turn, Start options, Back the menu screen.
## Touch: a joystick bottom left, a column of round buttons on the right; taps on
## the room still pick guests and place pieces, as a mouse click would.

signal mode_changed(mode: String, p: int)   # a player's device kind, which their hints follow

const DEAD := 0.22             # stick dead zone
const STICK_R := 92.0          # touch joystick: base radius on screen
const KNOB_R := 40.0
const BTN_R := 44.0
const USE_R := 66.0
## What each action is called on screen, per mode.
const GLYPHS := {
	"keys": {"move": "WASD", "use": "E", "back": "Esc", "turn": "R", "sell": "X", "shop": "Tab",
		"confirm": "Enter", "town": "T", "options": "O", "search": "F", "browse": "Arrows", "menu": "N"},
	"pad": {"move": "Stick", "use": "A", "back": "B", "turn": "RB", "sell": "X", "shop": "Y",
		"confirm": "A", "town": "Y", "options": "Start", "search": "", "browse": "D-pad", "menu": "Back"},
	"touch": {"move": "Joystick", "use": "Use", "back": "Back", "turn": "Turn", "sell": "Sell", "shop": "Shop",
		"confirm": "Tap", "town": "Tap", "options": "Menu", "search": "", "browse": "Swipe", "menu": "Dishes"},
}
## The keyboard's actions. WASD and the arrows also walk (read in move()).
const KEY_ACTIONS := {
	KEY_E: "use", KEY_SPACE: "use", KEY_ENTER: "confirm", KEY_KP_ENTER: "confirm",
	KEY_ESCAPE: "back", KEY_R: "turn", KEY_X: "sell", KEY_TAB: "shop", KEY_T: "town",
	KEY_O: "options", KEY_F: "search", KEY_SLASH: "search", KEY_M: "mute", KEY_N: "menu",
	KEY_UP: "up", KEY_W: "up", KEY_DOWN: "down", KEY_S: "down",
	KEY_LEFT: "left", KEY_A: "left", KEY_RIGHT: "right", KEY_D: "right",
}
const PAD_ACTIONS := {
	JOY_BUTTON_A: "use", JOY_BUTTON_B: "back", JOY_BUTTON_X: "sell", JOY_BUTTON_Y: "shop",
	JOY_BUTTON_LEFT_SHOULDER: "turn", JOY_BUTTON_RIGHT_SHOULDER: "turn", JOY_BUTTON_START: "options",
	JOY_BUTTON_BACK: "menu",
	JOY_BUTTON_DPAD_UP: "up", JOY_BUTTON_DPAD_DOWN: "down",
	JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right",
}

var game
var players: Array[PlayerInput] = [PlayerInput.new(0)]
var seats := {}                 # source -> player index; unseated sources are player 0's
## Player 0's device kind, which the interface's hints follow.
var mode: String:
	get: return players[0].mode
## Player 0's touch erase switch (kept for the build phase's mouse code).
var erase: bool:
	get: return players[0].erase
var _fingers := {}              # touch index -> what it holds: "stick" or [button id, action]
var _stick_at := Vector2.ZERO   # where the joystick's base sits
var _mouse_held := false        # the emulated mouse press landed on a control
var _view: Control


func setup(game_) -> void:
	game = game_
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS   # the options screen pauses the game
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_touch)
	add_child(_view)


# ---------------------------------------------------------------- players

## The player a device belongs to.
func owner_of(source: String) -> int:
	return int(seats.get(source, 0))


func input_of(p: int) -> PlayerInput:
	return players[p]


## Gives a device to a player, adding players up to that index.
func seat(source: String, p: int) -> void:
	while players.size() <= p:
		players.append(PlayerInput.new(players.size()))
	for q: PlayerInput in players:
		q.let_go(source)
	seats[source] = p


func glyph(action: String, p := 0) -> String:
	return GLYPHS[players[p].mode].get(action, "")


func set_mode(m: String, p := 0) -> void:
	var who := players[p]
	if m == who.mode:
		return
	who.mode = m
	who.erase = false
	if who.source.get_slice(":", 0) != m:
		who.source = "touch" if m == "touch" else ("keys" if m == "keys" else _any_pad(p))
	if owner_of("touch") == p:
		who.let_go("touch")
		_fingers.clear()
	_view.queue_redraw()
	mode_changed.emit(m, p)


func _any_pad(p: int) -> String:
	for s: String in seats:
		if s.begins_with("pad:") and seats[s] == p:
			return s
	return "pad:0"


## A device was used: it becomes its player's current device.
func _use(source: String) -> PlayerInput:
	var who := players[owner_of(source)]
	set_mode(source.get_slice(":", 0), who.index)
	who.source = source
	return who


## Where player p wants to walk, screen space, length <= 1: the keyboard (if it
## is theirs) plus the stick of the device they use.
func move(p := 0) -> Vector2:
	var v := players[p].stick()
	if owner_of("keys") == p:
		v += keys_vector()
	return v.limit_length(1.0)


## Player 0's stick (pad or touch joystick), as before the split.
func stick(p := 0) -> Vector2:
	return players[p].stick()


static func keys_vector() -> Vector2:
	return Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		- float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)))


## Whether player p is holding an action down on any of their devices.
func holding(p: int, action: String) -> bool:
	if players[p].holding(action):
		return true
	if owner_of("keys") == p:
		for key: Key in KEY_ACTIONS:
			if KEY_ACTIONS[key] == action and Input.is_physical_key_pressed(key):
				return true
	return false


## A control on a device was pressed or let go: the one way actions enter the
## game. `control` tells apart two buttons held for one action.
func press(source: String, action: String, pressed := true, control = null, echo := false) -> void:
	var who := _use(source)
	if action == "":
		return
	if control != null and not echo:
		action = who.hold(source, control, action, pressed)
	if pressed and action != "":
		game.act(who.index, action, echo)


## A device's stick moved (screen space, x right, y up).
func steer(source: String, v: Vector2) -> void:
	var who := players[owner_of(source)]
	if v.length() > 0.5:
		_use(source)
	who.set_stick(source, Vector2.ZERO if v.length() < DEAD else v.limit_length(1.0))


## True while the touch that would act as the mouse is on a control, so the room
## must not take it for a tap on the floor.
func owns_pointer() -> bool:
	return _mouse_held


static func action_for_key(key: int) -> String:
	return KEY_ACTIONS.get(key, "")


# ---------------------------------------------------------------- reading devices

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_use("touch")
		_touch_event(event)
	elif event is InputEventJoypadButton:
		_pad_button(event)
	elif event is InputEventJoypadMotion:
		_pad_axis(event)
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		_emulated_mouse(event)
	elif event is InputEventKey:
		_use("keys")
		# Tab is taken here, before the interface can use it to move focus.
		if event.physical_keycode == KEY_TAB and event.pressed and not event.echo \
				and game.phase == game.Phase.BUILD:
			press("keys", "shop")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 3.0):
		_use("keys")


## The keyboard's other keys arrive here, after the interface (the shop's
## search box) has had the chance to keep them.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or event.physical_keycode == KEY_TAB:
		return
	var action := action_for_key(event.physical_keycode)
	if action != "":
		press("keys", action, true, null, event.echo)


func _pad_button(e: InputEventJoypadButton) -> void:
	var action: String = PAD_ACTIONS.get(e.button_index, "")
	# A confirms the receipt and the end screen; Y opens the town book on the receipt.
	if action == "use" and game.phase in [game.Phase.SUMMARY, game.Phase.CLOSED]:
		action = "confirm"
	elif action == "shop" and game.phase == game.Phase.SUMMARY:
		action = "town"
	press("pad:%d" % e.device, action, e.pressed, e.button_index)


func _pad_axis(e: InputEventJoypadMotion) -> void:
	var source := "pad:%d" % e.device
	var who := players[owner_of(source)]
	var v: Vector2 = who._sticks.get(source, Vector2.ZERO)
	if e.axis == JOY_AXIS_LEFT_X:
		v.x = e.axis_value
	elif e.axis == JOY_AXIS_LEFT_Y:
		v.y = -e.axis_value
	else:
		return
	if absf(e.axis_value) > 0.5:
		_use(source)
	who.set_stick(source, Vector2.ZERO if v.length() < DEAD else v)


func _process(delta: float) -> void:
	if game == null:
		return
	for who: PlayerInput in players:
		_browse(who, delta)
	if _touch_who().mode == "touch":
		_view.queue_redraw()


## In the shop, on the options screen and on the title the stick browses: a flick steps once,
## holding it repeats.
func _browse(who: PlayerInput, delta: float) -> void:
	var hand := _hand_of(who.index)
	if who.erase and (hand.is_empty() or not Catalog.is_build_tool(hand.id)):
		who.erase = false
	var dir := Vector2i.ZERO
	var s := who._sticks.get(who.source, Vector2.ZERO) as Vector2
	if ((game.shopping and game.shopper == _chef_of(who.index)) or _options() or game.hud.title_open()) and s.length() > 0.6:
		dir = Vector2i(signi(roundi(s.x)), 0) if absf(s.x) > absf(s.y) else Vector2i(0, -signi(roundi(s.y)))
	if dir != who.browse_dir:
		who.browse_dir = dir
		who.browse_wait = 0.0
	if dir != Vector2i.ZERO:
		who.browse_wait -= delta
		if who.browse_wait <= 0.0:
			who.browse_wait = 0.28
			game.act(who.index, "right" if dir.x > 0 else "left" if dir.x < 0 else "down" if dir.y > 0 else "up")


# ---------------------------------------------------------------- touch

## The round buttons down the right-hand side, bottom first, for what can be
## done right now: [id, label, centre, radius].
func buttons() -> Array:
	var r := _view.get_rect()
	var out: Array = []
	if game.hud.title_open():   # the title's own buttons are tapped
		return out
	var x := r.size.x - 92.0
	var y := r.size.y - 112.0
	var hand := _hand_of(owner_of("touch"))
	var build: bool = game.phase == game.Phase.BUILD
	if _options() or game.hud.menu_open():   # the card's own buttons are big enough to tap
		pass
	elif game.phase == game.Phase.SERVICE or (build and not _touch_shops()):
		var word: String = game.hud.last_action if game.hud.last_action != "" else "Use"
		out.append(["use", word, Vector2(x, y), USE_R])
		y -= USE_R + BTN_R + 16.0
	if build and not _touch_shops() and not game.hud.menu_open():
		if not hand.is_empty():
			out.append(["back", "Done" if Catalog.is_build_tool(hand.id) else "Drop", Vector2(x, y), BTN_R])
			y -= BTN_R * 2 + 14.0
			if Catalog.is_build_tool(hand.id):
				out.append(["sell", "Erase" if not _touch_who().erase else "Erasing", Vector2(x, y), BTN_R])
				y -= BTN_R * 2 + 14.0
			else:
				out.append(["turn", "Turn", Vector2(x, y), BTN_R])
				y -= BTN_R * 2 + 14.0
				if hand.get("moving", false):
					out.append(["sell", "Sell", Vector2(x, y), BTN_R])
					y -= BTN_R * 2 + 14.0
		out.append(["shop", "Shop", Vector2(x, y), BTN_R])
		y -= BTN_R * 2 + 14.0
		if hand.is_empty():
			out.append(["menu", "Dishes", Vector2(x, y), BTN_R])
			y -= BTN_R * 2 + 14.0
			var crate: Station = game.stock_station_in_front(_chef_of(owner_of("touch")))
			if crate != null:
				out.append(["turn", "Unstock" if crate.stocked else "Stock", Vector2(x, y), BTN_R])
	elif build and _touch_shops():
		out.append(["back", "Close", Vector2(x, 70.0), BTN_R])
	out.append(["options", "Menu", Vector2(r.size.x - 60.0, 196.0), 30.0])
	return out


## Player p's chef, or null while they have none.
func _chef_of(p: int) -> Player:
	return game.chefs[p] if p < game.chefs.size() else null


## The screen's player has the shop open.
func _touch_shops() -> bool:
	return game.shopping and game.shopper == _chef_of(owner_of("touch"))


## What player p's chef holds in the build phase ({} with no chef).
func _hand_of(p: int) -> Dictionary:
	var ch := _chef_of(p)
	return ch.hand if ch != null else {}


## The player the screen belongs to: its joystick and buttons are theirs.
func _touch_who() -> PlayerInput:
	return players[owner_of("touch")]


func _stick_home() -> Vector2:
	return Vector2(150.0, _view.get_rect().size.y - 150.0)


func _options() -> bool:
	return game.hud != null and game.hud.options_open()


func _stick_shown() -> bool:
	return _touch_who().mode == "touch" and not _options() and (game.phase == game.Phase.SERVICE \
		or (game.phase == game.Phase.BUILD and not _touch_shops() and not game.hud.menu_open()))


## What a touch at this point would press: "stick", a button id, or "".
func control_at(p: Vector2) -> String:
	if _touch_who().mode != "touch":
		return ""
	if _stick_shown() and p.distance_to(_stick_home()) < STICK_R + 40.0:
		return "stick"
	for b: Array in buttons():
		if p.distance_to(b[2]) < float(b[3]) + 10.0:
			return b[0]
	return ""


func _touch_event(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			var what := control_at(e.position)
			if what == "":
				return
			_fingers[e.index] = what
			if what == "stick":
				_stick_at = _stick_home()
				steer("touch", _stick_vec(e.position))
			elif what == "sell" and not _hand_of(owner_of("touch")).is_empty() and Catalog.is_build_tool(_hand_of(owner_of("touch")).id):
				_touch_who().erase = not _touch_who().erase
			else:
				_fingers[e.index] = [what]
				press("touch", what, true, "finger%d" % e.index)
			get_viewport().set_input_as_handled()
		elif _fingers.has(e.index):
			var held = _fingers[e.index]
			_fingers.erase(e.index)
			if held is String and held == "stick":
				steer("touch", Vector2.ZERO)
			elif held is Array:
				press("touch", held[0], false, "finger%d" % e.index)
			get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and _fingers.get(e.index) is String and _fingers[e.index] == "stick":
		steer("touch", _stick_vec(e.position))
		get_viewport().set_input_as_handled()


func _stick_vec(p: Vector2) -> Vector2:
	var v := (p - _stick_at) / STICK_R
	v.y = -v.y
	v = v.limit_length(1.0)
	return Vector2.ZERO if v.length() < DEAD else v


## Touch also arrives as a mouse (finger one only). A press that lands on a
## control is swallowed, with everything up to its release, so the room and
## the interface never see it.
func _emulated_mouse(e: InputEventMouse) -> void:
	if e is InputEventMouseButton and e.pressed and control_at(e.position) != "":
		_mouse_held = true
	if _mouse_held:
		get_viewport().set_input_as_handled()
		if e is InputEventMouseButton and not e.pressed:
			_mouse_held = false


func _draw_touch() -> void:
	if game == null or _touch_who().mode != "touch":
		return
	var ink := Color(Hud.INK)
	var cream := Color("#fff6e6")
	if _stick_shown():
		var home := _stick_home()
		_view.draw_circle(home, STICK_R, Color(cream, 0.35))
		_view.draw_arc(home, STICK_R, 0, TAU, 48, Color(ink, 0.55), 4.0, true)
		var at: Vector2 = _touch_who()._sticks.get("touch", Vector2.ZERO)
		var knob := home + Vector2(at.x, -at.y) * STICK_R
		_view.draw_circle(knob + Vector2(0, 4), KNOB_R, Color(ink, 0.25))
		_view.draw_circle(knob, KNOB_R, Color(Hud.CORAL))
		_view.draw_arc(knob, KNOB_R, 0, TAU, 32, ink, 3.0, true)
	var font: Font = Hud.lettering()
	var held := {}
	for f in _fingers.values():
		if f is Array:
			held[f[0]] = true
	for b: Array in buttons():
		var c: Vector2 = b[2]
		var r: float = b[3]
		var down: bool = held.has(b[0]) or (b[0] == "sell" and _touch_who().erase)
		var face := Color(Hud.CORAL) if b[0] == "use" else cream
		if down:
			face = face.darkened(0.15)
		_view.draw_circle(c + Vector2(0, 5), r, Color(ink, 0.3))
		_view.draw_circle(c + (Vector2(0, 3) if down else Vector2.ZERO), r, face)
		_view.draw_arc(c + (Vector2(0, 3) if down else Vector2.ZERO), r, 0, TAU, 40, ink, 3.0, true)
		var size := 22 if r >= USE_R else (17 if r >= BTN_R else 13)
		var text: String = str(b[1]).to_upper()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		if w > r * 1.8:
			size = int(size * r * 1.8 / w)
			w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		_view.draw_string(font, c + Vector2(-w / 2, size * 0.35 + (3 if down else 0)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, cream if b[0] == "use" else ink)
