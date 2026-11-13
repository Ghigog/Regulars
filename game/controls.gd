class_name Controls
extends CanvasLayer
## Keyboard and mouse, controller, or touch: whichever was used last is the
## current `mode`, so a player can pick up a pad or reach for the screen at any
## moment. Controller buttons and the on-screen touch buttons send the same key
## presses the keyboard does, so the game has one set of rules for all three;
## movement comes from stick() as well as the keys.
##
## Controller: left stick or d-pad walk, A use (Enter on the receipt), B back,
## X sell or remove, Y shop (town book on the receipt), LB/RB turn, Start options.
## Touch: a joystick bottom left, a column of round buttons on the right; taps on
## the room still pick guests and place pieces, as a mouse click would.

signal mode_changed(mode: String)

const SYNTHETIC := 77          # device id on the key presses sent from here
const DEAD := 0.22             # stick dead zone
const STICK_R := 92.0          # touch joystick: base radius on screen
const KNOB_R := 40.0
const BTN_R := 44.0
const USE_R := 66.0
## What each action is called on screen, per mode.
const GLYPHS := {
	"keys": {"move": "WASD", "use": "E", "back": "Esc", "turn": "R", "sell": "X", "shop": "Tab",
		"confirm": "Enter", "town": "T", "options": "O", "search": "F", "browse": "Arrows"},
	"pad": {"move": "Stick", "use": "A", "back": "B", "turn": "RB", "sell": "X", "shop": "Y",
		"confirm": "A", "town": "Y", "options": "Start", "search": "", "browse": "D-pad"},
	"touch": {"move": "Joystick", "use": "Use", "back": "Back", "turn": "Turn", "sell": "Sell", "shop": "Shop",
		"confirm": "Tap", "town": "Tap", "options": "Menu", "search": "", "browse": "Swipe"},
}

var game
var mode := "keys"
var erase := false              # touch: drags with a build tool take things away
var _pad := Vector2.ZERO        # left stick, screen space (x right, y up)
var _touch := Vector2.ZERO      # touch joystick, same space
var _fingers := {}              # touch index -> what it holds: "stick" or a button id
var _stick_at := Vector2.ZERO   # where the joystick's base sits
var _mouse_held := false        # the emulated mouse press landed on a control
var _shop_dir := Vector2i.ZERO  # stick flick held in the shop
var _shop_wait := 0.0
var _pad_keys := {}             # joypad button -> key it is holding down
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


func glyph(action: String) -> String:
	return GLYPHS[mode].get(action, "")


func set_mode(m: String) -> void:
	if m == mode:
		return
	mode = m
	erase = false
	_touch = Vector2.ZERO
	_fingers.clear()
	_view.queue_redraw()
	mode_changed.emit(m)


## Movement from the left stick or the touch joystick, screen space, length <= 1.
func stick() -> Vector2:
	var v := _pad if mode == "pad" else (_touch if mode == "touch" else Vector2.ZERO)
	return v.limit_length(1.0)


## True while the touch that would act as the mouse is on a control, so the room
## must not take it for a tap on the floor.
func owns_pointer() -> bool:
	return _mouse_held


# ---------------------------------------------------------------- reading input

func _input(event: InputEvent) -> void:
	if event.device == SYNTHETIC:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		set_mode("touch")
		_touch_event(event)
	elif event is InputEventJoypadButton:
		set_mode("pad")
		_pad_button(event)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.5:
			set_mode("pad")
		_pad_axis(event)
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		_emulated_mouse(event)
	elif event is InputEventKey:
		set_mode("keys")
	elif event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 3.0):
		set_mode("keys")


## Sends a key press (or release) through the game as if typed.
func send_key(key: Key, pressed := true) -> void:
	var e := InputEventKey.new()
	e.device = SYNTHETIC
	e.keycode = key
	e.physical_keycode = key
	e.pressed = pressed
	Input.parse_input_event(e)


func tap_key(key: Key) -> void:
	send_key(key, true)
	send_key(key, false)


## Which key a button means right now: A confirms the receipt and the end
## screen, Y opens the shop by night and the town book on the receipt.
func _key_for(action: String) -> Key:
	var summary: bool = game.phase == game.Phase.SUMMARY
	var closed: bool = game.phase == game.Phase.CLOSED
	match action:
		"use":
			return KEY_ENTER if summary or closed else KEY_E
		"back":
			return KEY_ESCAPE
		"turn":
			return KEY_R
		"sell":
			return KEY_X
		"shop":
			return KEY_T if summary else KEY_TAB
		"options":
			return KEY_O
	return KEY_NONE


func _pad_button(e: InputEventJoypadButton) -> void:
	var action := ""
	var arrow := KEY_NONE
	match e.button_index:
		JOY_BUTTON_A: action = "use"
		JOY_BUTTON_B: action = "back"
		JOY_BUTTON_X: action = "sell"
		JOY_BUTTON_Y: action = "shop"
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER: action = "turn"
		JOY_BUTTON_START: action = "options"
		JOY_BUTTON_DPAD_UP: arrow = KEY_UP
		JOY_BUTTON_DPAD_DOWN: arrow = KEY_DOWN
		JOY_BUTTON_DPAD_LEFT: arrow = KEY_LEFT
		JOY_BUTTON_DPAD_RIGHT: arrow = KEY_RIGHT
	if e.pressed:
		var key: Key = arrow if arrow != KEY_NONE else _key_for(action)
		if key != KEY_NONE:
			_pad_keys[e.button_index] = key
			send_key(key, true)
	elif _pad_keys.has(e.button_index):
		send_key(_pad_keys[e.button_index], false)   # the same key it pressed, even if the phase moved on
		_pad_keys.erase(e.button_index)


func _pad_axis(e: InputEventJoypadMotion) -> void:
	if e.axis == JOY_AXIS_LEFT_X:
		_pad.x = e.axis_value
	elif e.axis == JOY_AXIS_LEFT_Y:
		_pad.y = -e.axis_value
	else:
		return
	if _pad.length() < DEAD:
		_pad = Vector2.ZERO


func _process(delta: float) -> void:
	if game == null:
		return
	if erase and (game.hand.is_empty() or not Catalog.is_build_tool(game.hand.id)):
		erase = false
	# In the shop the stick browses: a flick steps once, holding it repeats.
	var dir := Vector2i.ZERO
	if game.shopping and stick().length() > 0.6:
		var s := stick()
		dir = Vector2i(signi(roundi(s.x)), 0) if absf(s.x) > absf(s.y) else Vector2i(0, -signi(roundi(s.y)))
	if dir != _shop_dir:
		_shop_dir = dir
		_shop_wait = 0.0
	if dir != Vector2i.ZERO:
		_shop_wait -= delta
		if _shop_wait <= 0.0:
			_shop_wait = 0.28
			tap_key(KEY_RIGHT if dir.x > 0 else KEY_LEFT if dir.x < 0 else KEY_DOWN if dir.y > 0 else KEY_UP)
	if mode == "touch":
		_view.queue_redraw()


# ---------------------------------------------------------------- touch

## The round buttons down the right-hand side, bottom first, for what can be
## done right now: [id, label, centre, radius].
func buttons() -> Array:
	var r := _view.get_rect()
	var out: Array = []
	var x := r.size.x - 92.0
	var y := r.size.y - 112.0
	var hand: Dictionary = game.hand
	var build: bool = game.phase == game.Phase.BUILD
	if game.phase == game.Phase.SERVICE or (build and not game.shopping):
		var word: String = game.hud.last_action if game.hud.last_action != "" else "Use"
		out.append(["use", word, Vector2(x, y), USE_R])
		y -= USE_R + BTN_R + 16.0
	if build and not game.shopping:
		if not hand.is_empty():
			out.append(["back", "Done" if Catalog.is_build_tool(hand.id) else "Drop", Vector2(x, y), BTN_R])
			y -= BTN_R * 2 + 14.0
			if Catalog.is_build_tool(hand.id):
				out.append(["sell", "Erase" if not erase else "Erasing", Vector2(x, y), BTN_R])
				y -= BTN_R * 2 + 14.0
			else:
				out.append(["turn", "Turn", Vector2(x, y), BTN_R])
				y -= BTN_R * 2 + 14.0
				if hand.get("moving", false):
					out.append(["sell", "Sell", Vector2(x, y), BTN_R])
					y -= BTN_R * 2 + 14.0
		out.append(["shop", "Shop", Vector2(x, y), BTN_R])
	elif build and game.shopping:
		out.append(["back", "Close", Vector2(x, 70.0), BTN_R])
	out.append(["options", "Menu", Vector2(r.size.x - 60.0, 196.0), 30.0])
	return out


func _stick_home() -> Vector2:
	return Vector2(150.0, _view.get_rect().size.y - 150.0)


func _stick_shown() -> bool:
	return mode == "touch" and (game.phase == game.Phase.SERVICE or (game.phase == game.Phase.BUILD and not game.shopping))


## What a touch at this point would press: "stick", a button id, or "".
func control_at(p: Vector2) -> String:
	if mode != "touch":
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
				_touch = _stick_vec(e.position)
			elif what == "sell" and not game.hand.is_empty() and Catalog.is_build_tool(game.hand.id):
				erase = not erase
			else:
				send_key(_key_for(what), true)
				_fingers[e.index] = [what, _key_for(what)]
			get_viewport().set_input_as_handled()
		elif _fingers.has(e.index):
			var held = _fingers[e.index]
			_fingers.erase(e.index)
			if held is String and held == "stick":
				_touch = Vector2.ZERO
			elif held is Array:
				send_key(held[1], false)
			get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and _fingers.get(e.index) is String and _fingers[e.index] == "stick":
		_touch = _stick_vec(e.position)
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
	if mode != "touch" or game == null:
		return
	var ink := Color(Hud.INK)
	var cream := Color("#fff6e6")
	if _stick_shown():
		var home := _stick_home()
		_view.draw_circle(home, STICK_R, Color(cream, 0.35))
		_view.draw_arc(home, STICK_R, 0, TAU, 48, Color(ink, 0.55), 4.0, true)
		var knob := home + Vector2(_touch.x, -_touch.y) * STICK_R
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
		var down: bool = held.has(b[0]) or (b[0] == "sell" and erase)
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
