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
var _chefs: VBoxContainer   # the Chefs section; null while the confirm card shows
var _rows := {}             # seat -> signature of its row as last built
var _tags := {}             # seat -> its ChefTag, for the leave ring


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
	_chefs = null
	_tags.clear()


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
	_chefs = VBoxContainer.new()
	_chefs.add_theme_constant_override("separation", 8)
	_box.add_child(_chefs)
	_rows.clear()
	refresh_chefs()
	_add_button("Resume", "resume")
	_add_button("Options", "options")
	_add_button(quit_label(), "quit")
	_add_keys()
	sel = 0
	refresh()


func saving() -> bool:
	return hud.game.phase == Game.Phase.BUILD


func quit_label() -> String:
	if hud.game.practice:
		return "End practice"
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


func _ready() -> void:
	hud.root.move_child(hud.toast_sheet, -1)   # "Chef 2 joined." sits above the dim


func _process(_delta: float) -> void:
	for p: int in _tags:
		(_tags[p] as HudWidgets.ChefTag).set_progress(hud.game.controls.leave_progress(p))
	_frame.queue_redraw()


const DEVICE_WORDS := {"pad": "Controller", "keys": "Keyboard", "touch": "Touch"}


## Rebuilds only the Chefs rows: one per seat up to MAX_CHEFS, filled or empty. A row
## that is new or changed pops in. The pointer and the confirm card are left alone.
func refresh_chefs() -> void:
	if _chefs == null:
		return
	var game: Game = hud.game
	for c in _chefs.get_children():
		_chefs.remove_child(c)
		c.queue_free()
	_tags.clear()
	var old := _rows.duplicate()
	_rows.clear()
	var changed := false
	for p in Game.MAX_CHEFS:
		var filled: bool = p < game.chefs.size()
		var device := ""
		var line1 := ""
		var line2 := ""
		var sig := "empty"
		if filled:
			device = str(game.controls.players[p].mode)
			line1 = DEVICE_WORDS.get(device, "Controller")
			if device == "pad" and game.chefs.size() > 1:
				line2 = "Hold %s to leave" % hud._g("options", p)
			sig = "%s|%s" % [device, line2]
		else:
			var offer: String = game.controls.join_offer
			if offer != "" and not game.controls.seats.has(offer):
				line1 = "Controller ready: press Start to join as Chef %d" % (p + 1)
				sig = "offer"
			else:
				line1 = "Press Start on a controller to join"
			if p > game.chefs.size():
				continue   # only the next seat shows; the rest wait for it
		_rows[p] = sig
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_chefs.add_child(row)
		if filled:
			var tag := HudWidgets.ChefTag.new(p, 32)
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tag)
			_tags[p] = tag
		else:
			var ring := HudWidgets.SeatRing.new(32)
			ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ring)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var l := hud._label(col, 18, line1)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 280
		if line2 != "":
			var h := hud._label(col, 15, line2)
			h.modulate.a = 0.7
		if old.get(p, "") != sig:
			changed = true
			if old.has(p) or not old.is_empty():
				hud.receipt_ui._pop_in(row)
				row.pivot_offset = Vector2(150, 18)   # the card's pivot is far off a row
	if changed and not old.is_empty():
		game.audio.sfx("tick")
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
			if hud.game.practice:
				hud.game.session.quit_to_title()   # nothing was kept, so nothing to confirm
			else:
				show_confirm()
		"no":
			show_main()
		"yes":
			hud.game.session.save_and_quit()
