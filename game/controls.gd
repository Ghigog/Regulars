class_name Controls
extends CanvasLayer
## Input, per player. Every device is a source: "keys" (keyboard and mouse),
## "pad:<id>" (each controller) and "touch" (the screen). A source is seated
## to one player (`seats`; anything unseated is player 0's), and each player has
## a `PlayerInput` that remembers the device they used last, their stick and
## what they hold down. A press becomes an action ("use", "back", "turn",
## "sell", "shop", "town", "options", "confirm", "search" and the
## browse directions "up", "down", "left", "right") and goes to the game as
## `game.coop.act(player, action)`, so all three devices share one set of rules.
## Movement is read with move(player).
##
## Every device nobody has been seated to is player one's, and whichever of
## them was used last is their `mode`: player one can pick up a pad or reach for
## the screen at any moment. Co-op (PRD 4): Start on another pad (Enter on the
## keyboard while player one is on a pad) seats it to the next player
## (`game.coop.join`); holding Start a second, or unplugging, leaves (`game.coop.leave`).
##
## Keys: WASD or arrows walk (and browse), E/Space use, Enter confirm, Esc back,
## R turn, C sell, Tab shop, Z and X choose a lifted piece's upgrade and Space buys it
## (Space is "use" everywhere else: `game.coop.act` turns "buy" back into "use"), T town, O options, F search, N the menu screen
## (R on an ingredient station at night switches its stock). Shift held: the chef stands
## still and WASD only turns them, to aim (diagonals too at night).
## Controller: left stick or d-pad walk (the d-pad also browses), A use (confirm
## on the receipt and the end screen), B back, X sell, Y shop (town on the
## receipt; buys the chosen upgrade while a piece is lifted), LB/RB choose a lifted
## piece's upgrade (turn otherwise), the right stick's click turns, either trigger held aims, Start options, Back the menu screen.
## Touch: a joystick bottom left, round buttons on the right, drawn by HudButtons (Aim, beside
## Use, is held while the joystick turns the chef); taps on
## the room still pick guests and place pieces, as a mouse click would.

signal mode_changed(mode: String, p: int)   # a player's device kind, which their hints follow

const DEAD := 0.22             # stick dead zone
const STICK_R := 92.0          # touch joystick: base radius on screen
const KNOB_R := 40.0
const BTN_R := 44.0
const USE_R := 66.0
## What each action is called on screen, per mode.
const GLYPHS := {
	"keys": {"move": "WASD", "aim": "Shift", "reach": "Alt", "use": "E", "back": "Esc", "turn": "R", "sell": "C", "shop": "Tab",
		"prev": "Z", "next": "X", "buy": "Space",
		"confirm": "Enter", "town": "T", "options": "O", "search": "F", "browse": "Arrows", "menu": "N"},
	"pad": {"move": "Stick", "aim": "LT", "reach": "RT", "use": "A", "back": "B", "turn": "RS", "sell": "X", "shop": "Y",
		"prev": "LB", "next": "RB", "buy": "Y",
		"confirm": "A", "town": "Y", "options": "Start", "search": "", "browse": "D-pad", "menu": "Back"},
	"touch": {"move": "Joystick", "aim": "Aim", "reach": "Reach", "use": "Use", "back": "Back", "turn": "Turn", "sell": "Sell", "shop": "Shop",
		"prev": "", "next": "", "buy": "Tap it again",
		"confirm": "Tap", "town": "Tap", "options": "Menu", "search": "", "browse": "Swipe", "menu": "Dishes"},
}
## The keyboard's actions. WASD and the arrows also walk (read in move()).
const KEY_ACTIONS := {
	KEY_E: "use", KEY_SPACE: "buy", KEY_ENTER: "confirm", KEY_KP_ENTER: "confirm",
	KEY_ESCAPE: "back", KEY_R: "turn", KEY_C: "sell", KEY_Z: "prev", KEY_X: "next", KEY_TAB: "shop", KEY_T: "town",
	KEY_O: "options", KEY_F: "search", KEY_SLASH: "search", KEY_N: "menu",
	KEY_UP: "up", KEY_W: "up", KEY_DOWN: "down", KEY_S: "down",
	KEY_LEFT: "left", KEY_A: "left", KEY_RIGHT: "right", KEY_D: "right",
}
const PAD_ACTIONS := {
	JOY_BUTTON_A: "use", JOY_BUTTON_B: "back", JOY_BUTTON_X: "sell", JOY_BUTTON_Y: "shop",
	JOY_BUTTON_LEFT_SHOULDER: "prev", JOY_BUTTON_RIGHT_SHOULDER: "next", JOY_BUTTON_RIGHT_STICK: "turn", JOY_BUTTON_START: "options",
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
var used_any := false           # a device has been used: it is player one's, and others can join
const LEAVE_HOLD := 1.0          # seconds Start is held to leave
var _start_held := {}           # pad source -> seconds Start has been held (-1 once it left)
var _fingers := {}              # touch index -> what it holds: "stick" or [button id, action]
var _right_y := {}   # source -> right stick's vertical axis, kept apart from the walking stick
var _desk_dir := 0
var _desk_wait := 0.0
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
	Input.joy_connection_changed.connect(_on_joy_connection)


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


## Player p has left: their devices are let go, and later players move up one.
func unseat(p: int) -> void:
	if p >= players.size():
		return
	for s: String in seats.keys():
		if seats[s] == p:
			seats.erase(s)
			if _start_held.has(s):
				_start_held[s] = -1.0   # a Start still held lets go without opening the options
		elif seats[s] > p:
			seats[s] -= 1
	players.remove_at(p)
	if players.is_empty():
		players.append(PlayerInput.new(0))
	for k in players.size():
		players[k].index = k


## Would a press of Start (Enter on the keyboard) on this device add a player?
## Only a device that is not seated and is not the one player one is using, once
## some device has been used (the first device used is player one's). Never touch.
func joins(source: String) -> bool:
	return used_any and source != "touch" and not seats.has(source) and source != players[0].source \
		and game.chefs.size() < game.MAX_CHEFS


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
	used_any = true
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


## Whether player p holds their chef in place to aim: Shift on the keyboard, LT on a
## controller, the Aim button on touch.
func aiming(p := 0) -> bool:
	if owner_of("keys") == p and Input.is_physical_key_pressed(KEY_SHIFT):
		return true
	return players[p].holding("aim")


## Whether player p holds Reach, to use the high layer (wall shelf, cabinet, hook): Left Alt
## on the keyboard (Cmd too on a Mac; never the Windows key, it opens the Start menu), RT on
## a controller, the Reach button on touch.
func reaching(p := 0) -> bool:
	if owner_of("keys") == p and (Input.is_physical_key_pressed(KEY_ALT) \
			or (OS.get_name() == "macOS" and Input.is_physical_key_pressed(KEY_META))):
		return true
	return players[p].holding("reach")


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
			var a: String = KEY_ACTIONS[key]
			if (a == action or (a == "buy" and action == "use")) and Input.is_physical_key_pressed(key):
				return true   # Space is held as "use" too
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
		game.coop.act(who.index, action, echo)


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
		if event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and joins("keys"):
			game.coop.join("keys")
			get_viewport().set_input_as_handled()
			return
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
	var source := "pad:%d" % e.device
	if e.button_index == JOY_BUTTON_START:
		_start_button(source, e.pressed)
		return
	var action: String = PAD_ACTIONS.get(e.button_index, "")
	if e.pressed and game.phase == game.Phase.SUMMARY and e.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		if game.hud.receipt_ui.scroll_paper(-90.0 if e.button_index == JOY_BUTTON_DPAD_UP else 90.0):
			return
	# A confirms the receipt and the end screen; Y opens the town book on the receipt.
	if action == "use" and game.phase in [game.Phase.SUMMARY, game.Phase.CLOSED]:
		action = "confirm"
	elif action == "shop" and game.phase == game.Phase.SUMMARY:
		action = "town"
	press("pad:%d" % e.device, action, e.pressed, e.button_index)


## Start: on a device nobody has, a new player joins. On a seated one, a tap
## opens the options (on release) and holding it for a second leaves.
func _start_button(source: String, pressed: bool) -> void:
	if pressed:
		if joins(source):
			if game.coop.join(source) >= 0:
				_start_held[source] = -1.0   # its release does nothing
				return
		_use(source)
		_start_held[source] = 0.0
		return
	var held: float = _start_held.get(source, 0.0)
	_start_held.erase(source)
	if held >= 0.0:
		press(source, "options")


## A controller was unplugged: its player leaves (unless they are the only one).
func _on_joy_connection(device: int, connected: bool) -> void:
	var source := "pad:%d" % device
	if connected or not seats.has(source):
		return
	var p := owner_of(source)
	for q: PlayerInput in players:
		q.let_go(source)
	if game.chefs.size() > 1:
		game.coop.leave(p)


func _pad_axis(e: InputEventJoypadMotion) -> void:
	var source := "pad:%d" % e.device
	var who := players[owner_of(source)]
	var v: Vector2 = who._sticks.get(source, Vector2.ZERO)
	if e.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:   # held: LT stands and aims, RT reaches high
		who.hold(source, "trigger%d" % e.axis, "reach" if e.axis == JOY_AXIS_TRIGGER_RIGHT else "aim", e.axis_value > 0.5)
		if e.axis_value > 0.5:
			_use(source)
		return
	if e.axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y] and game.phase == game.Phase.SUMMARY and absf(e.axis_value) > 0.2:
		if game.hud.receipt_ui.scroll_paper(e.axis_value * 30.0):   # a long receipt: the stick reads it
			return
	if e.axis == JOY_AXIS_RIGHT_Y and game.hud.desk_open():   # the desk's lists: read in _desk_stick, never walks the chef
		_right_y[source] = e.axis_value
		return
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
	_desk_stick(delta)
	for who: PlayerInput in players:
		_browse(who, delta)
	for source: String in _start_held.keys():
		if not _start_held.has(source) or _start_held[source] < 0.0:
			continue
		_start_held[source] += delta
		if _start_held[source] >= LEAVE_HOLD and game.chefs.size() > 1:
			_start_held[source] = -1.0
			game.coop.leave(owner_of(source))
	if _touch_who().mode == "touch":
		_view.queue_redraw()


## On the desk the right stick steps the highlight up and down: a flick once, held it repeats.
func _desk_stick(delta: float) -> void:
	var dir := 0
	var source := ""
	if game.hud.desk_open():
		for src: String in _right_y:
			if absf(_right_y[src]) > 0.6:
				dir = signi(roundi(_right_y[src]))
				source = src
	if dir != _desk_dir:
		_desk_dir = dir
		_desk_wait = 0.0
	if dir == 0:
		return
	_desk_wait -= delta
	if _desk_wait <= 0.0:
		_desk_wait = 0.28
		game.coop.act(owner_of(source), "down" if dir > 0 else "up")


## In the shop, on the options screen and on the title the stick browses: a flick steps once,
## holding it repeats.
func _browse(who: PlayerInput, delta: float) -> void:
	var hand := _hand_of(who.index)
	if who.erase and (hand.is_empty() or not Catalog.is_build_tool(hand.id)):
		who.erase = false
	var dir := Vector2i.ZERO
	var s := who._sticks.get(who.source, Vector2.ZERO) as Vector2
	if ((game.shopping and game.shopper == _chef_of(who.index)) or _options() or game.hud.options_ui.title_open()) and s.length() > 0.6:
		dir = Vector2i(signi(roundi(s.x)), 0) if absf(s.x) > absf(s.y) else Vector2i(0, -signi(roundi(s.y)))
	if dir != who.browse_dir:
		who.browse_dir = dir
		who.browse_wait = 0.0
	if dir != Vector2i.ZERO:
		who.browse_wait -= delta
		if who.browse_wait <= 0.0:
			who.browse_wait = 0.28
			game.coop.act(who.index, "right" if dir.x > 0 else "left" if dir.x < 0 else "down" if dir.y > 0 else "up")


# ---------------------------------------------------------------- touch

## The discs on screen now, for what can be done: [id, label, centre, radius]. HudButtons
## draws and lays them out; touches are tested against them here.
func buttons() -> Array:
	return game.hud.buttons_ui.specs().map(func(s: Dictionary) -> Array: return [s.id, s.label, s.centre, s.r])


## The ids of the buttons a finger is holding down.
func held_ids() -> Array:
	var out := []
	for f in _fingers.values():
		if f is Array:
			out.append(f[0])
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
	return game.hud != null and (game.hud.options_ui.options_open() or game.hud.options_ui.pause_open())


func _stick_shown() -> bool:
	return _touch_who().mode == "touch" and not _options() and (game.phase == game.Phase.SERVICE \
		or (game.phase == game.Phase.BUILD and not _touch_shops() and not game.hud.card_open()))


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
			elif what in HudButtons.HOLD:
				_fingers[e.index] = [what]
				press("touch", what, true, "finger%d" % e.index)
			else:
				game.hud.buttons_ui.activate(what)   # taps press once, as their key does
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
