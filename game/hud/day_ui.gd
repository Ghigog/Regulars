class_name HudDay
extends RefCounted
## The day plaque in motion: the clock rolling, the calendar's tags torn and flown, the board
## up and down, stamps, the prompt line, the ticket rail, toasts and banners.

var hud: Hud


func _init(hud_: Hud) -> void:
	hud = hud_


# ---------------------------------------------------------------- moving props

## Puts the clock somewhere between hidden behind the calendar (0) and out on its
## right (1), turned as a wheel would turn rolling that far.
func _roll_clock(out: float) -> void:
	var hidden := hud.calendar.position.x + HudWidgets.Calendar.SIDE / 2.0 - HudWidgets.Clock.R
	var shown := hud.calendar.position.x + HudWidgets.Calendar.SIDE - 12.0
	hud.clock.position.x = lerpf(hidden, shown, out)
	hud.clock.rotation = (hud.clock.position.x - shown) / HudWidgets.Clock.R


func _intro() -> void:
	var tw := hud.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(hud.game.audio.sfx.bind("roll"))
	tw.tween_method(_roll_clock, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A new day: the clock rolls in behind the calendar, the calendar lifts and
## jiggles, a page turns over the top, it thumps down, and the clock rolls out.
func _turn_day(to: int) -> void:
	hud._turning = true
	var tw := hud.create_tween()
	tw.tween_callback(hud.game.audio.sfx.bind("roll"))
	tw.tween_method(_roll_clock, 1.0, 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(hud.game.audio.sfx.bind("lift"))
	tw.tween_property(hud.calendar, "lift", 15.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(hud.game.audio.sfx.bind("rattle"))
	for i in 5:
		tw.tween_property(hud.calendar, "rotation", 0.07 * (1.0 if i % 2 == 0 else -1.0) * (1.0 - i * 0.16), 0.065)
	tw.tween_property(hud.calendar, "rotation", 0.0, 0.06)
	tw.tween_callback(func() -> void:
		hud.calendar.next_day = to
		hud.game.audio.sfx("page"))
	tw.tween_property(hud.calendar, "flip", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		hud.calendar.day = to
		hud.calendar.flip = 0.0)
	tw.tween_property(hud.calendar, "lift", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		hud.game.audio.sfx("thump")
		hud.calendar.scale = Vector2(1.06, 0.93)
		hud.dangle.spin += randf_range(1.5, 2.5) * (1.0 if randf() < 0.5 else -1.0))
	tw.tween_property(hud.calendar, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		hud.clock.night = false
		hud.game.audio.sfx("roll"))
	tw.tween_method(_roll_clock, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: hud._turning = false)


## Where the torn-off tag sits on the end-of-day clipboard: over its right edge.
func _tag_goal() -> Vector2:
	if not is_instance_valid(hud._summary_clip):
		return hud.money_tag.position
	return hud._summary_clip.get_global_transform() * Vector2(hud._summary_clip.size.x - 6.0, 150.0)


## End of day: the tag is torn off its string and flutters onto the receipt.
func _rip_tag() -> void:
	if hud._tag_state != "hang":
		return
	hud._tag_state = "fly"
	hud.game.audio.sfx("rip")
	hud.money_tag.reparent(hud.fly)
	hud.dangle.tied = false
	hud.money_tag.pivot_offset = hud.money_tag.size * Vector2(0.5, 0.0)
	var p0 := hud.money_tag.position
	var r0 := hud.money_tag.rotation
	hud._tag_tween = hud.money_tag.create_tween()
	hud._tag_tween.tween_property(hud.money_tag, "position:y", p0.y - 18.0, 0.12).set_ease(Tween.EASE_OUT)
	hud._tag_tween.tween_callback(hud.game.audio.sfx.bind("flutter"))
	hud._tag_tween.tween_method(_flutter.bind(p0 - Vector2(0, 18), r0), 0.0, 1.0, 1.5)
	hud._tag_tween.tween_callback(func() -> void:
		hud._tag_state = "receipt"
		hud.money_tag.scale = Vector2.ONE
		hud.game.audio.sfx("rustle"))


func _flutter(t: float, p0: Vector2, r0: float) -> void:
	var e := ease(t, -1.8)
	var calm := 1.0 - t
	hud.money_tag.position = p0.lerp(_tag_goal(), e) + Vector2(sin(t * TAU * 2.0) * 60.0 * calm, -sin(t * PI) * 80.0)
	hud.money_tag.rotation = lerpf(r0, 0.12, e) + sin(t * TAU * 2.5) * 0.5 * calm
	hud.money_tag.scale = Vector2(lerpf(0.55 + 0.45 * absf(cos(t * TAU * 1.5)), 1.0, e), 1.0)


## Building: the old tag drops away with the receipt, and a new one falls from
## behind the calendar and dangles. (Money is needed while building.)
func _new_tag() -> void:
	if hud._tag_tween:
		hud._tag_tween.kill()
	if hud._tag_state == "hang":
		return
	hud._tag_state = "fall"
	hud.money_tag.visible = true
	hud._tag_tween = hud.money_tag.create_tween()
	hud._tag_tween.set_parallel()
	hud._tag_tween.tween_property(hud.money_tag, "position:y", hud.money_tag.position.y + 900.0, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hud._tag_tween.tween_property(hud.money_tag, "rotation", hud.money_tag.rotation + 1.4, 0.7)
	hud._tag_tween.chain().tween_callback(func() -> void:
		hud.money_tag.reparent(hud.dangle, false)
		hud.money_tag.rotation = 0.0
		hud.money_tag.scale = Vector2.ONE
		hud._tag_state = "hang"
		hud.dangle.tied = true
		hud.dangle.angle = 0.0
		hud.dangle.spin = 0.0
		hud.dangle.drop = 0.0
		hud.game.audio.sfx("rustle"))
	hud._tag_tween.tween_property(hud.dangle, "drop", 1.12, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hud._tag_tween.tween_callback(func() -> void:
		hud.dangle.spin = randf_range(2.5, 3.5) * (1.0 if randf() < 0.5 else -1.0)
		hud.game.audio.sfx("rustle"))
	hud._tag_tween.tween_property(hud.dangle, "drop", 1.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _board_down() -> void:
	for i in hud.stamps.size():   # yesterday's walkouts are wiped before it comes back
		if i >= hud._shown_strikes:
			hud.stamps[i].id = ""
			hud.stamps[i].wet = 0.0
			hud.stamps[i].rotation = 0.0
			hud.stamps[i].queue_redraw()
	hud.board.position.y = -hud.board.size.y - 80.0
	var tw := hud.board.create_tween()
	tw.tween_callback(hud.game.audio.sfx.bind("rope"))
	tw.tween_property(hud.board, "position:y", Hud.BOARD_Y, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: hud.board.spin += 1.4)


func _board_up(at_once := false) -> void:
	var gone := -hud.board.size.y - 80.0
	if at_once:
		hud.board.position.y = gone
		return
	var tw := hud.board.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		hud.board.spin -= 0.8
		hud.game.audio.sfx("rope"))
	tw.tween_property(hud.board, "position:y", gone, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## A walkout: a rubber stamp comes down from above and thumps the next slot.
func _stamp(slot: HudWidgets.Punch, delay: float) -> void:
	var st := HudWidgets.RubberStamp.new()
	st.target = slot.get_global_transform() * (slot.size / 2.0)
	st.hover = 420.0
	hud.fly.add_child(st)
	var tw := st.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(st, "hover", 48.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.1)
	tw.tween_property(st, "hover", 0.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		hud.game.audio.sfx("stamp")
		slot.stamp()
		hud.board.spin += randf_range(-1.0, 1.0)
		st.scale = Vector2(1.08, 0.9))
	tw.tween_interval(0.16)
	tw.tween_callback(func() -> void: st.scale = Vector2.ONE)
	tw.tween_property(st, "hover", 70.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(st, "hover", 520.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(st.queue_free)


## One chef's prompt bubble: their number tag (shown in co-op), a keycap and a word.
func _make_prompt() -> Dictionary:
	var sheet := HudWidgets.Sheet.new("tab").pad(10, 8, 16, 12)
	sheet.visible = false
	hud.root.add_child(sheet)
	if hud._prompts.size() > 0:
		hud.root.move_child(sheet, hud._prompts[0].sheet.get_index() + hud._prompts.size())
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	sheet.add_child(prow)
	var tag := HudWidgets.ChefTag.new(hud._prompts.size(), 30)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.visible = false
	prow.add_child(tag)
	var key := HudWidgets.Sheet.new("key", 13, 4).pad(13, 1, 13, 7)
	prow.add_child(key)
	var key_label := hud._label(key, 24, "E")
	var d := {"sheet": sheet, "key": key, "key_label": key_label, "label": hud._label(prow, 26), "tag": tag, "row": prow, "extras": []}
	hud._prompts.append(d)
	return d


## Shows "[E] COOK" over a point on screen for player p's chef, or hides it when
## `text` is empty. In co-op each bubble carries its player's numbered tag and
## their own device's button; a second bubble that would cover the first sits above it.
## `extras` are small keycap tags beside the main one while a piece is held:
## [[action, word], ...], each cap from that chef's device (words only on touch).
func show_prompt(at: Vector2, text: String, p := 0, ready := true, extras := []) -> void:
	while hud._prompts.size() <= p:
		_make_prompt()
	var d: Dictionary = hud._prompts[p]
	var sheet: Control = d.sheet
	if hud.game.controls == null or hud.game.controls.owner_of("touch") == p:
		hud.last_action = text
	sheet.visible = text != "" and hud.options_ui.title == null
	if text == "":
		return
	var coop: bool = hud.game.chefs.size() > 1
	(d.tag as HudWidgets.ChefTag).visible = coop
	(d.tag as HudWidgets.ChefTag).set_player(p)
	var m: String = hud.game.controls.input_of(p).mode if hud.game.controls and p < hud.game.controls.players.size() else "keys"
	d.key.visible = m != "touch"
	d.key_label.text = hud.game.controls.glyph("use", p) if hud.game.controls and p < hud.game.controls.players.size() else "E"
	d.label.text = text.to_upper()
	_show_extras(d, p, m, extras)
	sheet.unavailable = not ready   # muted tan, cream text, as a disabled stamp button
	if ready:
		d.label.remove_theme_color_override("font_color")
	else:
		d.label.add_theme_color_override("font_color", Hud.CREAM)
	sheet.queue_redraw()
	sheet.reset_size()
	sheet.position = (at - Vector2(sheet.size.x / 2.0, sheet.size.y)).round()
	for q in p:   # never on top of an earlier player's bubble
		var o: Control = hud._prompts[q].sheet
		if o.visible and Rect2(o.position, o.size).grow(-2).intersects(Rect2(sheet.position, sheet.size)):
			sheet.position.y = o.position.y - sheet.size.y + 4.0
	var cluster := walk_rect(p)   # the walk keys stay readable: the bubble stacks above them
	if cluster.size != Vector2.ZERO and cluster.grow(-2).intersects(Rect2(sheet.position, sheet.size)):
		sheet.position.y = cluster.position.y - sheet.size.y - 2.0
	sheet.position.y = maxf(sheet.position.y, 6.0)  # never off the top of the screen
	sheet.position.x = clampf(sheet.position.x, 4.0, maxf(4.0, hud.root.size.x - sheet.size.x - 4.0))  # nor the sides (a phone)


## Fills the small tags after the main word: shrunk to about 70%, the main cap too.
func _show_extras(d: Dictionary, p: int, mode: String, extras: Array) -> void:
	var small := not extras.is_empty()
	var fs := 18 if small else 26
	d.label.add_theme_font_size_override("font_size", fs)
	d.key_label.add_theme_font_size_override("font_size", 17 if small else 24)
	while d.extras.size() < extras.size():
		var cap := HudWidgets.Sheet.new("key", 9, 3).pad(9, 1, 9, 5)
		d.row.add_child(cap)
		var kl := hud._label(cap, 17, "")
		d.extras.append({"cap": cap, "key_label": kl, "label": hud._label(d.row, 18)})
		d.row.move_child(d.extras[-1].label, cap.get_index() + 1)
	for i in d.extras.size():
		var e: Dictionary = d.extras[i]
		var on: bool = i < extras.size()
		e.cap.visible = on and mode != "touch"
		e.label.visible = on
		if on:
			e.key_label.text = hud.game.controls.glyph(extras[i][0], p) if hud.game.controls and p < hud.game.controls.players.size() else ""
			e.label.text = String(extras[i][1]).to_upper()


# ---------------------------------------------------------------- walk keycaps

const WALK_KEYS := {"W": [KEY_W, KEY_UP], "A": [KEY_A, KEY_LEFT], "S": [KEY_S, KEY_DOWN], "D": [KEY_D, KEY_RIGHT]}
const WALK_LAYOUT := {"W": Vector2(1, 0), "A": Vector2(0, 1), "S": Vector2(1, 1), "D": Vector2(2, 1)}
const CAP := Vector2(30, 30)
const CAP_GAP := 3.0
var _walk: Array[Dictionary] = []   # per chef: {root, caps, pressed, retired}


func _make_walk() -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(CAP.x * 3 + CAP_GAP * 2, CAP.y * 2 + CAP_GAP)
	root.pivot_offset = Vector2(root.size.x / 2.0, root.size.y)
	root.visible = false
	hud.root.add_child(root)
	var d := {"root": root, "caps": {}, "pressed": {}, "retired": false, "tween": null}
	for k: String in WALK_LAYOUT:
		var cap := HudWidgets.Sheet.new("key", 6, 2).pad(6, 0, 6, 4)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.position = WALK_LAYOUT[k] * (CAP + Vector2(CAP_GAP, CAP_GAP))
		root.add_child(cap)
		var l := hud._label(cap, 20, k)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.caps[k] = cap
	return d


## The cluster over one chef's head: WASD for a keyboard, one stick cap for a pad,
## nothing on touch. Each new key ticks and dims; the last pops it away, and the
## lesson is remembered in the options so it never returns. `head` is the chef's
## head on screen. The E prompt bubble stacks above it (see show_prompt).
func update_walk_keys(p: int, head: Vector2) -> void:
	while _walk.size() <= p:
		_walk.append(_make_walk())
	var d: Dictionary = _walk[p]
	var game: Game = hud.game
	var mode: String = game.controls.input_of(p).mode if game.controls and p < game.controls.players.size() else "keys"
	var flag := "stick_learned" if mode == "pad" else "walk_learned"
	var shown: bool = mode != "touch" and not hud.options_ui.options[flag] and not d.retired \
		and hud.options_ui.title == null and not hud.options_ui.options_open() and not game.shopping
	var root: Control = d.root
	if d.retired:
		root.position = (head - Vector2(root.size.x / 2.0, root.size.y)).round()
		return
	root.visible = shown
	if not shown:
		return
	if mode == "pad":
		_walk_pad(d, p, flag)
	else:
		_walk_keys(d, p, flag)
	root.position = (head - Vector2(root.size.x / 2.0, root.size.y)).round()


func _walk_keys(d: Dictionary, p: int, flag: String) -> void:
	for k: String in WALK_KEYS:
		(d.caps[k] as Control).visible = true
	if hud.game.controls.owner_of("keys") == p:
		for k: String in WALK_KEYS:
			if not d.pressed.has(k) and WALK_KEYS[k].any(func(c: int) -> bool: return Input.is_physical_key_pressed(c)):
				d.pressed[k] = true
				(d.caps[k] as Control).modulate = Color(1, 1, 1, 0.4)
				hud.game.audio.sfx("tick")
	if d.pressed.size() == WALK_KEYS.size():
		_retire_walk(d, flag)


func _walk_pad(d: Dictionary, p: int, flag: String) -> void:
	for k: String in WALK_KEYS:
		(d.caps[k] as Control).visible = k == "W"
	var cap: Control = d.caps["W"]
	cap.position = Vector2(d.root.size.x / 2.0 - CAP.x / 2.0, CAP.y + CAP_GAP)
	((cap.get_child(0)) as Label).text = hud.game.controls.glyph("move", p)
	if hud.game.controls.stick(p).length() > 0.3:
		hud.game.audio.sfx("tick")
		_retire_walk(d, flag)


## Pops the cluster up a little, fades it, and remembers it was learned.
func _retire_walk(d: Dictionary, flag: String) -> void:
	d.retired = true
	hud.options_ui.options[flag] = true
	hud.options_ui.save_options()
	var root: Control = d.root
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "modulate:a", 0.0, 0.35).set_delay(0.1)
	tw.chain().tween_callback(root.hide)


## Where player p's walk cluster is, on screen, or an empty rect when hidden.
func walk_rect(p: int) -> Rect2:
	if p >= _walk.size() or not _walk[p].root.visible:
		return Rect2()
	return Rect2(_walk[p].root.position, _walk[p].root.size)


## Hides the bubbles of players with no chef (one left).
func trim_prompts(count: int) -> void:
	for p in range(count, hud._prompts.size()):
		hud._prompts[p].sheet.visible = false


## Rebuilds the ticket rail from the game's open tickets.
func refresh_tickets() -> void:
	if hud.ticket_rail == null:
		return
	for c in hud.ticket_rail.get_children():
		c.queue_free()
	var shown := 0
	for tk: Dictionary in hud.game.tickets:
		if shown >= Hud.RAIL_MAX:
			break
		shown += 1
		var card := HudWidgets.Sheet.new("paper", 10, 6)
		hud.ticket_rail.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		card.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		col.add_child(head)
		var g: Guest = tk.guest
		head.add_child(HudWidgets.Face.new(Color(g.info.shirt), str(g.info.name).left(1)))
		hud._label(head, 18, g.info.name)
		var line := 0
		for course in Menu.COURSES:
			for it: Dictionary in tk.items:
				if it.course != course:
					continue
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 4)
				col.add_child(row)
				row.add_child(HudWidgets.Icon.new(Icons.dish_id(it), 22, false))
				var box := VBoxContainer.new()
				box.add_theme_constant_override("separation", 0)
				row.add_child(box)
				hud._label(box, 14, it.name)
				box.add_child(HudWidgets.Marks.new(hud.game, int(tk.id), line, it.ingredients.size()))
				line += 1
	if hud.game.tickets.size() > shown:
		var more := HudWidgets.Sheet.new("paper", 8, 6)
		hud.ticket_rail.add_child(more)
		hud._label(more, 18, "+%d" % (hud.game.tickets.size() - shown))


func say(s: String) -> void:
	hud.toast.text = s
	hud.toast_sheet.modulate.a = 1.0
	if hud._toast_tween:
		hud._toast_tween.kill()
	hud._toast_tween = hud.toast_sheet.create_tween()
	hud._toast_tween.tween_interval(3.0)
	hud._toast_tween.tween_property(hud.toast_sheet, "modulate:a", 0.0, 0.8)


func show_banner(s: String) -> void:
	hud.banner_label.text = s.to_upper()
	hud.banner.modulate.a = 0.0
	var tw := hud.banner.create_tween()
	tw.tween_property(hud.banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(0.9)
	tw.tween_property(hud.banner, "modulate:a", 0.0, 0.5)
