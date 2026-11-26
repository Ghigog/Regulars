class_name PauseMenu
extends Control
## The pause menu: Resume, Options and Quit to title on a paper card over the room,
## which stands still behind it. Keys and the controller move a framed pointer (as on
## the title); touch taps. Quit asks first. In the build phase it reads "Save and quit"
## and keeps the night's work; in service the day in play is not kept (the game was saved
## when the restaurant opened, and when quitting from the build phase).

var hud: Hud
var buttons: Array[Button] = []
var sel := 0
var confirming := false   # the "leave this day?" card is showing
var _box: VBoxContainer
var _keys: Label
var _frame: Control


func setup(hud_: Hud) -> void:
	hud = hud_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(Hud.SHADOW, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var mid := CenterContainer.new()
	mid.set_anchors_preset(Control.PRESET_FULL_RECT)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mid)
	var card := HudWidgets.Sheet.new("paper", 30, 24)
	card.custom_minimum_size = Vector2(380, 0)
	mid.add_child(card)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	card.add_child(_box)
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(func() -> void:
		if hud._mode() != "touch" and sel < buttons.size():
			var r := buttons[sel].get_global_rect().grow_individual(14, 6, 10, 6)
			r.position -= _frame.get_global_rect().position
			HudOptions.pick_frame(_frame, r))
	add_child(_frame)
	show_main()
	hud.receipt_ui._pop_in(card)


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	buttons.clear()


func _add_button(text: String, id: String) -> void:
	var b := hud.receipt_ui._button(_box, text, press_id.bind(id))
	b.add_theme_font_size_override("font_size", 24)
	var i := buttons.size()
	b.mouse_entered.connect(func() -> void: pick(i))
	buttons.append(b)


func show_main() -> void:
	_clear()
	confirming = false
	hud.receipt_ui._ribbon(_box, "PAUSED", Hud.CORAL)
	_add_button("Resume", "resume")
	_add_button("Options", "options")
	_add_button(quit_label(), "quit")
	_add_keys()
	sel = 0
	refresh()


func saving() -> bool:
	return hud.game.phase == Game.Phase.BUILD


func quit_label() -> String:
	return "Save and quit" if saving() else "Quit to title"


## "Leave this day?": the day in play is lost, the night's save is not.
func show_confirm() -> void:
	_clear()
	confirming = true
	var msg := "Save and leave for the title?\nTonight's work is saved; Continue picks up here." if saving() \
			else "Leave for the title?\nThe game was saved when you opened; today's service is lost."
	var l := hud._label(_box, 22, msg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 320
	_add_button(quit_label(), "yes")
	_add_button("Stay", "no")
	_add_keys()
	sel = 1
	refresh()


func _add_keys() -> void:
	_keys = hud._label(_box, 15)
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys.modulate.a = 0.7


func refresh() -> void:
	var touch := hud._mode() == "touch"
	for b in buttons:
		b.custom_minimum_size.y = 72.0 if touch else 52.0
	_keys.visible = not touch
	_keys.text = "%s choose     %s press     %s resume" % [hud._g("browse"), hud._g("use"), hud._g("back")]
	_frame.queue_redraw()


func _process(_delta: float) -> void:
	_frame.queue_redraw()


func pick(i: int) -> void:
	i = clampi(i, 0, buttons.size() - 1)
	if i != sel:
		hud.game.audio.sfx("tick")
	sel = i
	_frame.queue_redraw()


## One action from any player's device: up and down pick, use or confirm presses,
## back or options resumes (or, on the confirm card, stays).
func action(a: String, echo := false) -> bool:
	match a:
		"up":
			pick(posmod(sel - 1, buttons.size()))
		"down":
			pick(posmod(sel + 1, buttons.size()))
		"use", "confirm":
			if echo:
				return false
			buttons[sel].pressed.emit()
		"back", "options":
			if echo:
				return false
			if confirming:
				show_main()
			else:
				hud.options_ui.toggle_pause()
		_:
			return false
	return true


func press_id(id: String) -> void:
	match id:
		"resume":
			hud.options_ui.toggle_pause()
		"options":
			hud.options_ui.toggle_options()
		"quit":
			show_confirm()
		"no":
			show_main()
		"yes":
			hud.game.session.save_and_quit()
