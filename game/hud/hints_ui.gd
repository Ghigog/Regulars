class_name HudHints
extends RefCounted
## Hints: the hint lines per chef, co-op ready marks, key notes, the build tip and aim note,
## the build bar (show_build) and the lifted piece's strip of choices.

var hud: Hud


func _init(hud_: Hud) -> void:
	hud = hud_


# ---------------------------------------------------------------- co-op (PRD 4)

## Player p's corner hint line: their numbered tag and the words. Player one's sits
## bottom left, player two's bottom right (three and four would go a row above).
func _make_hint(p: int) -> Dictionary:
	var right := p % 2 == 1
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.anchor_left = 1.0 if right else 0.0
	box.anchor_right = box.anchor_left
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	box.offset_top = -44 - 34 * (p / 2)
	box.offset_bottom = -14 - 34 * (p / 2)
	if right:
		box.offset_left = -24
		box.offset_right = -24
	else:
		box.offset_left = 24
		box.offset_right = 24
	box.modulate.a = 0.85
	hud.root.add_child(box)
	var tag := HudWidgets.ChefTag.new(p, 24)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.visible = false
	box.add_child(tag)
	var label := hud._label(box, 15)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var d := {"box": box, "tag": tag, "label": label}
	hud._hints.append(d)
	return d


## One line per player, worded for their own device. With one chef it is the
## first-day reminder, as before; in co-op both lines also show for a while after
## someone joins. On a narrow screen a line drops to its buttons alone rather
## than wrap or run into the other.
func _update_hints(first_day: bool) -> void:
	var n: int = hud.game.chefs.size()
	while hud._hints.size() < n:
		_make_hint(hud._hints.size())
	hud.coop_hint_time = maxf(hud.coop_hint_time - hud.get_process_delta_time(), 0.0)
	var room := hud.root.size.x / 2.0 - 48.0 if n > 1 else hud.root.size.x - 48.0
	for p in hud._hints.size():
		var d: Dictionary = hud._hints[p]
		var show: bool = p < n and (first_day or (n > 1 and hud.coop_hint_time > 0.0 and hud.game.phase == hud.game.Phase.SERVICE)) \
			and _hint_text(p) != "" and hud.game.phase != hud.game.Phase.BUILD
		d.box.visible = show
		if not show:
			continue
		(d.tag as HudWidgets.ChefTag).visible = n > 1
		(d.tag as HudWidgets.ChefTag).set_player(p)
		var font := (d.label as Label).get_theme_font("font")
		var text := _hint_text(p)
		var tag_w := 32.0 if n > 1 else 0.0
		if font and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + tag_w > room:
			text = _hint_short(p)
		d.label.text = text
		d.box.reset_size()
		if p % 2 == 1:   # right-aligned: grow leftward from the right edge
			d.box.position.x = hud.root.size.x - 24.0 - d.box.size.x


## The hint line cut to buttons alone, for narrow screens.
func _hint_short(p: int) -> String:
	match hud._mode(p):
		"pad":
			return "Stick  A  B  Start"
		"touch":
			return ""
	return "WASD  E  O"


## The receipt's and the door card's ready markers, from the game's ready list.
func refresh_ready() -> void:
	var states: Array[String] = hud.game.coop.ready_states()
	var coop: bool = hud.game.chefs.size() > 1
	if hud._ready_row and is_instance_valid(hud._ready_row):
		_fill_ready(hud._ready_row, states, 30)
		hud._ready_row.visible = coop
	for c in hud._door_ready_row.get_children():
		c.queue_free()
	var any: bool = coop and hud.game.ready_chefs.size() > 0 and hud.game.phase in [hud.game.Phase.BUILD, hud.game.Phase.SERVICE]
	hud._door_ready.visible = any
	if any:
		_fill_ready(hud._door_ready_row, states, 24)
		hud._door_ready.reset_size()


func _fill_ready(row: HBoxContainer, states: Array[String], px: float) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	for p in states.size():
		row.add_child(HudWidgets.ChefTag.new(p, px, states[p]))


## Keeps the door card's ready markers over the card (a point on screen).
func place_door_ready(at: Vector2) -> void:
	if hud._door_ready.visible:
		hud._door_ready.position = (at - Vector2(hud._door_ready.size.x / 2.0, 0.0)).round()


## "   (Enter)" after a button's words; nothing on touch, where it is tapped.
func _key_note(action: String) -> String:
	return "" if hud._mode() == "touch" or hud._g(action) == "" else "   (%s)" % hud._g(action)


func _hint_text(p := 0) -> String:
	match hud._mode(p):
		"pad":
			return "Stick move     LT aim     A use     B back     Start options"
		"touch":
			return ""   # the joystick sits there; the Use button names the action
	if hud.game.chefs.size() > 1:   # shorter in co-op: two lines share the bottom edge
		return "WASD move     Shift aim     E use     O pause"
	return "WASD move     Shift+WASD aim     E or Space use     Click a guest     O pause     M mute"


func _shop_keys_text() -> String:
	if hud.game.card.storing():   # a piece's card: only E and Back (review, item 4)
		match hud._mode():
			"pad":
				return "A choose      D-pad browse      B back"
			"touch":
				return "Tap a card, then tap it again"
		return "E choose      Arrows browse      Esc back"
	match hud._mode():
		"pad":
			return "A buy      D-pad browse      B close"
		"touch":
			return "Tap a piece, then tap it again to buy"
	return "E buy      Tab close"


## The build slip's words for what player p's chef has in hand, for their device.
func _build_tip(p := 0) -> String:
	var ch: Player = hud.game.chefs[p]
	var hand: Dictionary = ch.hand
	var m := hud._mode(p)
	var use := hud._g("use", p)
	if hand.is_empty() and Cleaning.carrying_mess(ch.held):
		if ch.held == "rubbish_bag":
			return "Carrying the rubbish bag.      Take it out the front door before building or shopping"
		return "Carrying a dirty plate.      Put it in the sink before building or shopping"
	if hand.is_empty():
		if m == "touch":
			return "Joystick walk      Tap a piece to pick it up      Shop      Dishes for the menu      Flip the door card to open for day %d" % hud.game.ledger.day
		return "%s walk      %s pick up a piece (its upgrades show)      %s shop      %s menu      Flip the door card to open for day %d" % [hud._g("move", p), use, hud._g("shop", p), hud._g("menu", p), hud.game.ledger.day]
	if Treatments.is_laying_tool(hand.id):   # a floor treatment (PRD 9.5): laid free, paid each night
		var k := Treatments.key_of(hand.id)
		var off: bool = hud.game.treat_off.has(k)
		var what := "%s, laying free, its box %s%s." % [Treatments.name_of(k), Treatments.fee_words(k), " (switched off)" if off else ""]
		var flip := "%s switch %s" % ["Turn" if m == "touch" else hud._g("turn", p), "on" if off else "off"]
		match m:
			"touch":
				return "%s      Drag across the floor to lay      Erase, then drag, to lift      %s      Done" % [what, flip]
			"pad":
				return "%s      Hold A and walk to lay      X lift      %s      B done" % [what, flip]
		return "%s      Hold E and walk, or drag, to lay      Right-drag lifts      %s      Esc done" % [what, flip]
	if Catalog.is_build_tool(hand.id):
		var floor: bool = hud.game.placing.floor_kind(hand.id) != ""
		var what := "%s, $%d each." % [Catalog.label(hand), int(hand.price)]
		match m:
			"touch":
				var drag := "Drag along the floor for a row" if hand.id == "wall" or Catalog.is_finish(hand.id) else ("Drag across the floor for a rectangle" if floor else "Tap a wall to add one")
				return "%s      %s      Erase, then drag, to take away      Done" % [what, drag]
			"pad":
				return "%s      %s      X remove      B done" % [what, "Hold A and walk to keep laying" if floor else "A build"]
		var how := "Hold E and walk to keep laying" if floor else "E build"
		var drag := "drag for a row" if hand.id == "wall" or Catalog.is_finish(hand.id) else ("drag for a rectangle" if floor else "click to add")
		return "%s      %s      Mouse: %s, right-drag removes      X remove      Esc done" % [what, how, drag]
	var turn := hud._g("turn", p)
	if Treatments.is_box(hand.id):   # PRD 9.5: chemicals, kept away from food
		var k := Treatments.key_of(hand.id)
		var what := "%s box.      Put it on a shelf or counter with no food, not a fridge" % Treatments.name_of(k)
		var away := ("%s tree" % ("Shop" if m == "touch" else hud._g("shop", p))) if hand.get("moving", false) else "%s drop" % ("Drop" if m == "touch" else hud._g("back", p))
		return "%s      %s put in      %s" % [what, "Tap the shelf" if m == "touch" else use, away]
	if Catalog.is_box(hand.id):   # PRD 8.4: a box goes into a storage slot
		var b := Pantry.station_ingredient(hand.id)
		var where := "a fridge (pick up a counter and upgrade it)" if Kitchen.is_chilled(hand.id) else "a counter or a fridge"
		var what := "%s, $%d a night.      Put it in %s" % [Catalog.label(hand), Pantry.fee_of(b.id, b.ready), where]
		var away := ("%s sell stops the fee" % ("Sell" if m == "touch" else hud._g("sell", p))) if hand.get("moving", false) else "%s drop" % ("Drop" if m == "touch" else hud._g("back", p))
		return "%s      %s put in      %s" % [what, "Tap the counter" if m == "touch" else use, away]
	if Kitchen.is_high_only(hud.game.world.hand_node(hand)):   # PRD 8.5: it hangs on a wall, facing out
		var lead := "%s, $%d when it is hung." % [Catalog.label(hand), int(hand.price)]
		var tail := "%s drop" % ("Drop" if m == "touch" else hud._g("back", p))
		if hand.get("moving", false):
			var why: String = hud.game.placing.sell_block(ch)
			lead = "Carrying the %s." % hud.game.placing.piece_name(hand).to_lower()
			tail = ("%s for $%d" % ["Sell" if m == "touch" else hud._g("sell", p) + " sell", hud.game.placing.sell_value(ch)]) if why == "" else why
		return "%s      %s hang it on a wall, over anything      %s" % [lead, "Tap a cell by a wall to" if m == "touch" else use, tail]
	if hand.get("moving", false):
		var why: String = hud.game.placing.sell_block(ch)
		var sell := ("%s for $%d" % ["Sell" if m == "touch" else hud._g("sell", p) + " sell", hud.game.placing.sell_value(ch)]) if why == "" else why
		if m == "touch":
			return "Carrying the %s.      Tap the floor to put it down      Turn      %s      Drop puts it back" % [hud.game.placing.piece_name(hand).to_lower(), sell]
		return "Carrying the %s.      %s put down      %s turn      %s      %s put back" % [
			hud.game.placing.piece_name(hand).to_lower(), use, turn, sell, hud._g("back", p)]
	if m == "touch":
		return "%s, $%d when it is put down.      Tap the floor to put it down      Turn      Drop" % [Catalog.label(hand), int(hand.price)]
	return "%s, $%d when it is put down.      %s put down      %s turn      %s drop" % [
		Catalog.label(hand), int(hand.price), use, turn, hud._g("back", p)]


## Added to the slip while a chef holds a piece they can put down (not a build or
## treatment tool, which are laid where the chef faces anyway): how to stand still and aim.
func _aim_note(p: int) -> String:
	var ch: Player = hud.game.chefs[p]
	var hand: Dictionary = ch.hand
	if hand.is_empty() or Catalog.is_build_tool(hand.id) or Treatments.is_laying_tool(hand.id):
		return ""
	if hud._mode(p) == "touch":
		return "      Hold Aim to stand still and aim"
	return "      Hold %s to stand still and aim" % hud._g("aim", p)


## Redraws every hint for a new device: the corner hint, the prompt's keycap,
## the build slip and the shop's key line.
func refresh_input() -> void:
	hud.hint.text = _hint_text()
	hud._prompt_key.visible = hud._mode() != "touch"
	hud._prompt_key_label.text = hud._g("use")
	if hud._shop_keys:
		hud._shop_keys.text = _shop_keys_text()
	if hud.build_bar:
		show_build()
	if hud.options_ui._options_card:
		hud.options_ui._show_options_tab(hud.options_ui._options_tab)
	if hud.options_ui.title:
		hud.options_ui.title.refresh()


## The build phase: a paper slip along the bottom says what the keys do. The
## shop (show_shop) slides up over it. Later calls only redraw.
func show_build() -> void:
	if hud.build_bar == null:
		hud.hint.visible = false
		var holder := MarginContainer.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_theme_constant_override("margin_bottom", 16)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.root.add_child(holder)
		hud.root.move_child(holder, hud.center.get_index())
		hud.build_bar = holder
		var stack := VBoxContainer.new()
		stack.size_flags_vertical = Control.SIZE_SHRINK_END
		stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.alignment = BoxContainer.ALIGNMENT_END
		stack.add_theme_constant_override("separation", 6)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(stack)
		# Night cleaning: a note taped above the slip while anything is still dirty.
		var note := HudWidgets.Sheet.new("note").pad(14, 8, 18, 8)
		note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		note.rotation = -0.02
		stack.add_child(note)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.add_child(row)
		row.add_child(HudWidgets.Icon.new("stink", 30))
		hud._dirty_label = hud._label(row, 20)
		hud._dirty_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hud._dirty_note = note
		hud.menu_notes = MenuScreen.BuildNotes.new(hud.game, hud)
		stack.add_child(hud.menu_notes)
		stack.move_child(hud.menu_notes, 0)
		hud._strip = VBoxContainer.new()
		hud._strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hud._strip.add_theme_constant_override("separation", 6)
		hud._strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(hud._strip)
		var slip := HudWidgets.Sheet.new("paper", 22, 10)
		slip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(slip)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 4)
		slip.add_child(rows)
		hud._tip_rows.clear()
		hud.day_ui._add_tip_row(rows)
		hud._tip = hud._tip_rows[0].label
		holder.modulate.a = 0.0
		holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.3)
		hud.game.audio.sfx("rustle")
	hud.build_bar.visible = hud._shop == null
	# One row per chef, each worded for that player's device; tagged in co-op.
	var n: int = hud.game.chefs.size()
	while hud._tip_rows.size() < n:
		hud.day_ui._add_tip_row(hud._tip_rows[0].row.get_parent())
	for p in hud._tip_rows.size():
		var d: Dictionary = hud._tip_rows[p]
		d.row.visible = p < n
		if p < n:
			(d.tag as HudWidgets.ChefTag).visible = n > 1
			d.label.text = _build_tip(p) + _aim_note(p)
	hud._dirty_label.text = hud.game.room_edit.dirty_note()
	hud._dirty_note.visible = hud._dirty_label.text != ""
	_fill_strip()
	hud.menu_notes.refresh()
	hud.shop_ui._refresh_catalog()


## The lifted piece's strip (one row a chef who has one): a chip for each upgrade it can
## take now and each box it carries, the chosen one raised, its blurb and keys under it.
func _fill_strip() -> void:
	for c in hud._strip.get_children():
		hud._strip.remove_child(c)
		c.queue_free()
	var n: int = hud.game.chefs.size()
	for p in n:
		var ch: Player = hud.game.chefs[p]
		var list: Array[Dictionary] = hud.game.upgrades.strip_choices(ch)
		if list.is_empty():
			continue
		var chosen: Dictionary = hud.game.upgrades.strip_chosen(ch)
		var sheet := HudWidgets.Sheet.new("paper", 16, 8)
		sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hud._strip.add_child(sheet)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		sheet.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		box.add_child(head)
		if n > 1:
			head.add_child(HudWidgets.ChefTag.new(p))
		hud._label(head, 18, "Upgrades for the %s" % hud.game.placing.piece_name(ch.hand).to_lower()).modulate = Color(Hud.INK, 0.7)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		for i in list.size():
			row.add_child(_strip_chip(ch, i, list[i], list[i] == chosen))
		var m := hud._mode(p)
		var keys := ""
		var act := "take out" if chosen.kind == "box" else "buy"
		if m == "touch":
			keys = "Tap a card, tap it again to %s" % act
		else:
			keys = "%s %s choose      %s %s" % [hud._g("prev", p), hud._g("next", p), hud._g("buy", p), act]
		var what := ""
		if chosen.kind == "box":
			what = "Stocked every night for $%d. Take it out to stop that." % _box_fee(chosen.id)
		else:
			what = Upgrades.blurb(chosen.key)
		hud._label(box, 18, "%s      %s" % [what, keys])


func _box_fee(id: String) -> int:
	if Treatments.is_box(id):
		return int(Treatments.ITEMS[Treatments.key_of(id)].fee)
	var b := Pantry.station_ingredient(id)
	return Pantry.fee_of(b.id, b.ready)


func _strip_chip(ch: Player, i: int, c: Dictionary, on: bool) -> Control:
	var chip := HudWidgets.Sheet.new("label" if on else "inset", 12, 6)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	chip.add_child(col)
	if c.kind == "box":
		hud._label(col, 20, Catalog.label({"id": c.id, "tier": 1}))
		hud._label(col, 16, "In it: take out").modulate = Color(Hud.INK, 0.7)
	else:
		var price := Upgrades.step_price(c.key)
		hud._label(col, 20, Upgrades.name_of(c.key))
		var tag := hud._label(col, 16, "$%d" % price)
		tag.modulate = Color(Hud.CORAL) if price > hud.game.ledger.money else Color(Hud.INK, 0.7)
	if not on:
		chip.modulate = Color(1, 1, 1, 0.8)
	chip.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			if ch.strip_pick == i:
				hud.game.upgrades.strip_buy(ch)
			else:
				ch.strip_pick = i
				hud.game.audio.sfx("tab", 0.08)
				show_build()
			chip.accept_event())
	return chip


const SLOT := 88.0                  # the gap between the small pieces along the row
const GAP := 64.0                   # extra room either side of the piece in the middle
const BAND := Vector2(1080, 232)    # the row itself
const ITEM := Vector2(204, 232)     # one piece: its picture with the price underneath
const SMALL := 0.42                 # how big the pieces either side of the middle are


func _drop_row() -> void:
	if hud._row_tween:
		hud._row_tween.kill()
	hud._items.clear()
	hud._views.clear()
