class_name PlayerInput
extends RefCounted
## One player's input, whatever device it comes from: which device they used
## last (so the hints can name its buttons), the stick they steer with, and the
## actions they are holding down. `Controls` fills one of these per player from
## the devices seated to that player; the game asks it for movement and held
## actions and receives presses as `game.act(index, action)`.
##
## A source is one device: "keys" (the keyboard and the mouse), "pad:<id>" (one
## controller, by Godot device id) or "touch" (the screen).

var index := 0
var mode := "keys"              # the kind of device used last: "keys", "pad" or "touch"
var source := "keys"            # the device used last
var erase := false              # touch: drags with a build tool take things away
var browse_dir := Vector2i.ZERO # a stick flick held in the shop or the options
var browse_wait := 0.0
var _sticks := {}               # source -> Vector2, screen space (x right, y up), dead zone applied
var _down := {}                 # source -> {control: action}: buttons, keys or fingers held


func _init(index_ := 0) -> void:
	index = index_


## The analogue stick of the device in use (a pad's left stick or the touch
## joystick) plus a pad's d-pad, length <= 1. Not the keyboard: Controls adds it.
func stick() -> Vector2:
	if source == "keys":
		return Vector2.ZERO
	var v: Vector2 = _sticks.get(source, Vector2.ZERO)
	var held: Dictionary = _down.get(source, {})
	for action: String in held.values():
		match action:
			"left": v.x -= 1.0
			"right": v.x += 1.0
			"up": v.y += 1.0
			"down": v.y -= 1.0
	return v.limit_length(1.0)


func set_stick(from: String, v: Vector2) -> void:
	_sticks[from] = v


## Marks a control (a button index, a finger, a key) on a device as held for
## an action, or lets it go. Returns the action the control was holding, so a
## release lets go of what the press took even if the phase has moved on.
func hold(from: String, control, action: String, pressed: bool) -> String:
	var held: Dictionary = _down.get_or_add(from, {})
	if pressed:
		held[control] = action
		return action
	var was: String = held.get(control, "")
	held.erase(control)
	return was


func holding(action: String) -> bool:
	for held: Dictionary in _down.values():
		if action in held.values():
			return true
	return false


## Forgets what one device was doing: its stick and its held controls.
func let_go(from: String) -> void:
	_sticks.erase(from)
	_down.erase(from)
