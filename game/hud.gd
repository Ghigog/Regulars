class_name Hud
extends CanvasLayer
## The paper-and-wood interface (style guide, sheet 14): a wooden day plaque with
## a sun dial, a price-tag for money, a walkout punch-card, keycap prompts, the
## end-of-day receipt on a clipboard and the game-over menu card.

const INK := Color("#3a2c22")
const CREAM := Color("#fff6e6")
const PAPER := Color("#f4ead8")
const CORAL := Color("#ee7560")
const WOOD := Color("#b9824e")
const SHADOW := Color("#5a423a", 0.38)   # plum-brown, never black
const KRAFT := Color("#e6cfa6")
const NEWSPRINT := Color("#ede5d0")   # the critic's clipping
const RATING_ICONS := {"speed": "hourglass", "clean": "sparkle", "quality": "cloche", "variety": "menu_card"}


## The hand-lettered face of the interface sheets (Patrick Hand, open licence).
static func lettering() -> Font:
	return load("res://assets/fonts/PatrickHand-Regular.ttf")

var game
var root: Control
var calendar: HudWidgets.Calendar
var clock: HudWidgets.Clock
var dangle: HudWidgets.Dangle
var board: HudWidgets.Board
var fly: Control   # props in flight draw over everything else
var _shown_phase := -1
var _turning := false
var _tag_state := "hang"   # hang, fly, receipt or fall
var _tag_tween: Tween
var _summary_clip: Control
var toast_sheet: HudWidgets.Sheet
var toast: Label
var money: Label
var money_tag: HudWidgets.Sheet
var stamps: Array[HudWidgets.Punch] = []
var rep_meter: HudWidgets.RepMeter
var order_column: HudWidgets.OrderColumn
var ticket_rail: VBoxContainer   # the column's list of tickets
const ORDERS_TOP := 320.0     # below the calendar, clock, hanging money tag and toast
const ORDERS_BOTTOM := 290.0  # clear of the touch stick (home 150 up, radius 92 + 40)
var banner: HudWidgets.Sheet
var banner_label: Label
var center: CenterContainer
var prompt: Control
var prompt_label: Label
var last_action := ""      # the word on the prompt, for the touch Use button
var _prompt_key: Control
var _prompt_key_label: Label
var _prompts: Array[Dictionary] = []   # one bubble per chef: {sheet, key, key_label, label, tag}; 0 is `prompt`
var _shop_keys: Label
var _shown_money := -1
var _shown_strikes := 0
var _town_open := false
var build_bar: Control
var guest_card: Control
var _guest: Guest
var _guest_state: Label
var _guest_bill: Label   # what a served guest is paying (mood scales it)
var _guest_meters := {}
var _guest_thoughts: Label
var _guest_hints: Label
var _search := ""
var _category := ""
var _search_box: LineEdit
var _tabs: Array[Button] = []
var _cards: Control
var _ready_row: HBoxContainer           # the receipt's ready markers, in co-op
var _door_ready: Control                # the ready markers over the door card
var _door_ready_row: HBoxContainer
var _shop_tag: Control                  # "Chef 1 is shopping", over the shop in co-op
var _strip: VBoxContainer  # build phase: a lifted piece's upgrades and boxes, at the bottom
var menu: MenuScreen           # the menu screen, while it is open
var bill: BillScreen           # the bill screen at the till (PRD 11.3), while it is open
var desk: DeskScreen           # the desk screen (PRD 10.3), while it is open
var menu_notes: MenuScreen.BuildNotes   # night zero's hint and the restock note, at the bottom
var _shop: Control             # the shop's sliding tray; null while the shop is shut
var _tree: TreeScreen          # the upgrade tree of the piece in hand (PRD 8.3); null while shut
var _info: Label
var _info_blurb: Label
var _shop_items: Array[Dictionary] = []
var _shop_index := 0
var _items: Array[Control] = []      # one per piece in the row, laid out by _lay_out
var _views: Array[HudWidgets.ModelView] = []
var _row_pos := 0.0                  # which piece is in the middle; fractional while sliding
var _row_tween: Tween
var _toast_tween: Tween
var day_ui := HudDay.new(self)   # the clock, the calendar's day tags, the board, prompts, tickets and banners
var options_ui := HudOptions.new(self)   # the options screen, the title and the pause menu
var receipt_ui := HudReceipt.new(self)   # the end-of-day receipt and the critic's review
var hints_ui := HudHints.new(self)   # ready marks, the build notes and the lifted piece's strip
var board_key_ui := HudBoardKey.new(self)   # the glowing menu key over the board by the door
var prep_key_ui := HudPrepKey.new(self)   # the Use key beside a prep minigame's gauge, moving as it wants pressing
var shop_ui := HudShop.new(self)   # the build shop: tabs, cards, info and buying
var buttons_ui := HudButtons.new(self)   # the discs for every action the keys have, tapped on touch
var screens_ui := HudScreens.new(self)   # the upgrade tree, the town book and the closed sign


const BOARD_Y := 18.0


func setup(game_) -> void:
	game = game_
	process_mode = Node.PROCESS_MODE_ALWAYS  # the options screen works while the game is paused
	options_ui.load_options()
	options_ui.apply_options.call_deferred()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	buttons_ui.build()

	# Top left: the desk calendar, the clock that rolls out from behind it, and
	# the money tag hanging from it on a string.
	dangle = HudWidgets.Dangle.new()
	root.add_child(dangle)
	clock = HudWidgets.Clock.new()
	clock.position.y = 18.0 + HudWidgets.Calendar.SIDE / 2.0 - HudWidgets.Clock.R
	root.add_child(clock)
	calendar = HudWidgets.Calendar.new()
	calendar.position = Vector2(22, 18)
	root.add_child(calendar)
	day_ui._roll_clock(0.0)
	money_tag = HudWidgets.Sheet.new("tag").pad(12, 24, 12, 12)
	dangle.tag = money_tag
	dangle.add_child(money_tag)
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", -2)
	money_tag.add_child(mcol)
	money = _label(mcol, 30)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var coin := HudWidgets.Icon.new("coin", 26, false)
	coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mcol.add_child(coin)
	toast_sheet = HudWidgets.Sheet.new("paper", 14, 6)
	toast_sheet.position = Vector2(22, 268)
	toast_sheet.modulate.a = 0.0
	root.add_child(toast_sheet)
	toast = _label(toast_sheet, 18)

	# Top right: the cork board with the reputation card, hung on ropes (review, item 9).
	board = HudWidgets.Board.new()
	board.anchor_left = 1.0
	board.anchor_right = 1.0
	board.offset_left = -246
	board.offset_right = -22
	board.offset_top = BOARD_Y
	root.add_child(board)
	var card := HudWidgets.Sheet.new("card").pad(14, 8, 14, 10)
	board.add_child(card)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 2)
	card.add_child(cbox)
	_label(cbox, 24, "REPUTATION").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rep_meter = HudWidgets.RepMeter.new()
	cbox.add_child(rep_meter)

	# Left: the open tickets, oldest at the top, below the money tag and above the touch stick.
	order_column = HudWidgets.OrderColumn.new()
	order_column.offset_left = 22
	order_column.offset_right = 22 + HudWidgets.OrderColumn.WIDTH
	order_column.offset_top = ORDERS_TOP
	order_column.anchor_bottom = 1.0
	order_column.offset_bottom = -ORDERS_BOTTOM
	root.add_child(order_column)
	ticket_rail = order_column.list

	# Over the door card in co-op: who is ready to flip it.
	_door_ready = HudWidgets.Sheet.new("note").pad(10, 6, 10, 6)
	_door_ready.visible = false
	root.add_child(_door_ready)
	_door_ready_row = HBoxContainer.new()
	_door_ready_row.add_theme_constant_override("separation", 4)
	_door_ready.add_child(_door_ready_row)

	# The keycap prompt that floats over the station the chef faces.
	var first := day_ui._make_prompt()
	prompt = first.sheet
	_prompt_key = first.key
	_prompt_key_label = first.key_label
	prompt_label = first.label

	var banner_box := CenterContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_box)
	banner = HudWidgets.Sheet.new("wood", 26, 20)
	banner.modulate.a = 0.0
	banner_box.add_child(banner)
	var banner_paper := HudWidgets.Sheet.new("inset", 40, 6)
	banner.add_child(banner_paper)
	banner_label = _label(banner_paper, 84)

	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	fly = Control.new()
	fly.set_anchors_preset(Control.PRESET_FULL_RECT)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fly)


static func _flat(col: Color, radius: int, margin := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func _stamp_button(col: Color) -> StyleBoxFlat:
	var sb := _flat(col, 10, 12)
	sb.border_color = col.darkened(0.25)
	sb.border_width_bottom = 5
	sb.shadow_color = SHADOW
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _theme() -> Theme:
	var t := Theme.new()
	# A chunky rounded face where the system has one. (A bundled hand-lettered
	# font is still to be chosen.)
	t.default_font = lettering()
	t.set_color("font_color", "Label", INK)   # dark brown ink for all text
	t.set_stylebox("normal", "Button", _stamp_button(CORAL))
	t.set_stylebox("hover", "Button", _stamp_button(CORAL.lightened(0.1)))
	t.set_stylebox("pressed", "Button", _stamp_button(CORAL.darkened(0.12)))
	t.set_stylebox("disabled", "Button", _stamp_button(Color("#c9b9a3")))
	t.set_color("font_disabled_color", "Button", CREAM)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var field := _flat(CREAM, 8, 8)
	field.border_color = INK
	field.set_border_width_all(2)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.45))
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_hover_pressed_color", "Button", CREAM)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", CREAM)
	t.set_font_size("font_size", "Button", 20)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.22)
	track.set_corner_radius_all(5)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = track.duplicate()
	filled.bg_color = CORAL
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	return t


func _label(parent: Node, font_size: int, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


const STATE_WORDS := {"queue": "Queueing outside", "to_seat": "Finding a seat", "reading": "Reading the menu", "ordering": "Waiting to order", "waiting": "Waiting for food",
	"eating": "Eating", "company": "Found nothing they liked", "leaving": "Leaving", "chatting": "Chatting after the meal",
	"to_pay": "Waiting for the bill", "to_till": "Going to pay at the till", "at_till": "Waiting for the bill at the till"}


## The guest card (click a guest): who they are, how they feel and what they have
## thought so far. Pass null to close it.
func show_guest(g: Guest) -> void:
	if guest_card:
		guest_card.queue_free()
		guest_card = null
	_guest = g
	if g == null:
		return
	var card := HudWidgets.Sheet.new("label", 16, 12)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -246
	card.offset_right = -22
	card.offset_top = 160
	root.add_child(card)
	guest_card = card
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	box.add_child(name_row)
	_label(name_row, 24, g.info.name)
	if game.critic.known and game.day.is_critic(g):   # only once a review has named them
		var mark := HudWidgets.Icon.new("quill", 26, false)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(mark)
		_label(name_row, 13, "Critic").modulate.a = 0.7
	var town: Town = game.town
	var who := "Back after a grudge" if g.info.sore else town.status_word(g.idx, game.ledger.day)
	var standing := _label(box, 13, "%s  ·  visit %d" % [who, int(g.info.visits) + 1])
	standing.modulate.a = 0.7
	if town.expects_deal(g.idx):   # discounting has a cost: they now expect it
		_label(box, 13, "Expects a deal").add_theme_color_override("font_color", Color(Build.CORAL_DARK))
	var orders := town.order_summary(g.idx, game.menu)   # tastes are never listed; what they order is
	if orders != "":
		var ol := _label(box, 13, "Orders: " + orders)
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ol.custom_minimum_size = Vector2(190, 0)
		ol.add_theme_color_override("font_color", Color(Build.CABINET))
	_guest_hints = _label(box, 13)   # tolerances are never shown, only hinted once felt
	_guest_hints.add_theme_color_override("font_color", Color(Build.CORAL_DARK))
	_guest_state = _label(box, 15)
	_guest_bill = _label(box, 14)
	_guest_bill.add_theme_color_override("font_color", Color(Build.CABINET))
	_guest_meters.clear()
	for id: String in ["patience", "joy", "savour", "disgust"]:
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := _label(row, 14, id.capitalize())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m := HudWidgets.Meter.new()
		row.add_child(m)
		_guest_meters[id] = m
	receipt_ui._rule(box)
	_guest_thoughts = _label(box, 13)
	_guest_thoughts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guest_thoughts.custom_minimum_size = Vector2(190, 0)
	_update_guest()


func _update_guest() -> void:
	if guest_card == null or not is_instance_valid(_guest):
		return
	var m: GuestMood = _guest.mood
	_guest_state.text = STATE_WORDS.get(_guest.state, "")
	var paying: float = _guest.game.paying.pay_wait(_guest)   # PRD 11: how long they have waited to pay
	if paying >= 0.0:
		_guest_state.text = ("Waiting at the till, %ds" if _guest.state == "at_till" else "Waiting for the bill, %ds") % roundi(paying)
	var hints := m.tolerance_hints()
	_guest_hints.visible = not hints.is_empty()
	_guest_hints.text = "\n".join(hints)
	_guest_bill.visible = m.served_comfort >= 0.0
	if _guest_bill.visible:
		_guest_bill.text = _bill_words(m, _guest.bill_base)
	for id: String in _guest_meters:
		_guest_meters[id].value = float(m.get(id))
		_guest_meters[id].queue_redraw()
	var lines: Array[String] = []
	for t in m.thoughts.slice(-6):
		lines.append("\"%s\"" % t)
	lines.reverse()   # newest first
	_guest_thoughts.text = "No thoughts yet." if lines.is_empty() else "\n".join(lines)


## "Paying $14 · ordered extras": the served guest's bill, and why it moved.
static func _bill_words(m: GuestMood, base: int) -> String:
	var text := "Paying $%d" % m.bill_for(base)   # the slip's total, less any deal
	var extra := m.pay_for(base) - m.bill_for(base)
	if m.comped:
		text += "  ·  on the house"
	elif m.discounted:
		text += "  ·  half price"
	if extra > 0:
		text += "  ·  +$%d extras with the tip" % extra
	elif extra < 0:
		text += "  ·  in a hurry: less tip"
	return text


func update_status() -> void:
	_update_guest()
	var l: Ledger = game.ledger
	var P = game.Phase
	if options_ui.title != null:
		return   # nothing of the day shows until Play
	if game.phase != _shown_phase:
		var first := _shown_phase == -1
		_shown_phase = game.phase
		match game.phase:
			P.SERVICE:
				day_ui._board_down()
			P.SUMMARY:
				day_ui._board_up(first)
				day_ui._rip_tag()
			P.BUILD:
				if first:   # the night before day 1: no walkout card to show yet
					day_ui._board_up(true)
				day_ui._new_tag()
		if first:
			day_ui._intro()
	# The calendar keeps the day just played until the next one opens.
	var want: int = l.day - 1 if game.phase == P.SUMMARY or game.phase == P.BUILD else l.day
	if calendar.day == 0:
		calendar.day = want
	elif want != calendar.day and not _turning:
		day_ui._turn_day(want)
	if not _turning:
		clock.night = game.phase != P.SERVICE
	clock.progress = game.day.day_progress()
	if l.money != _shown_money:
		if _shown_money >= 0 and l.money > _shown_money:
			money_tag.pivot_offset = money_tag.size * Vector2(0.5, 0.0)
			money_tag.scale = Vector2(1.25, 1.25)
			money_tag.create_tween().tween_property(money_tag, "scale", Vector2.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			dangle.spin += randf_range(-2.5, 2.5)
		_shown_money = l.money
		money.text = "$%d" % l.money
		money_tag.reset_size()
	if rep_meter and absf(rep_meter.value - l.reputation) > 0.01:
		rep_meter.set_value(l.reputation)


func _process(delta: float) -> void:
	if options_ui._options_card and options_ui._options_frame:
		options_ui._options_frame.queue_redraw()   # follows the card as it pops in
	if not calendar:
		return
	buttons_ui.update()
	dangle.step(calendar.knot(), delta)
	for j in _views.size() if _shop else 0:   # the piece in the middle turns ever so slowly
		var turn: Node3D = _views[j].spin
		if j == _shop_index:
			turn.rotate_y(delta * 0.45)
			_views[j].animate(true)
		else:
			var off := absf(wrapf(turn.rotation.y, -PI, PI))
			if off > 0.004:   # still settling face-on: render until it is
				turn.rotation.y = lerp_angle(turn.rotation.y, 0.0, 1.0 - exp(-6.0 * delta))
				if off <= 0.01:
					turn.rotation.y = 0.0
				_views[j].animate(true)
			else:
				turn.rotation.y = 0.0
				_views[j].animate(false)
	if _tag_state == "receipt":
		money_tag.visible = is_instance_valid(_summary_clip)
		if money_tag.visible:
			money_tag.position = day_ui._tag_goal()
			money_tag.rotation = 0.12


## The tabs of the tray now open: the shop's, or a piece's card's.
func shop_tabs() -> Array[String]:
	if not game.card.storing():
		return HudReceipt.SHOP_TABS
	var tabs: Array[String] = ["Ingredients" if game.card.card_keeps_boxes() else "This piece"]
	if game.card.storage_tree() != "":
		tabs.append("Upgrades")
	return tabs
const TRAY_DROP := 260.0   # how far below its place the shop tray waits


func menu_open() -> bool:
	return menu != null


func desk_open() -> bool:
	return desk != null


## A full-screen card (the menu or the desk) is over the room: nobody walks or builds.
func card_open() -> bool:
	return menu != null or desk != null


func bill_open() -> bool:
	return bill != null


func open_bill(ch: Player) -> void:
	if bill != null:
		return
	bill = BillScreen.new()
	root.add_child(bill)
	bill.setup(game, self, ch)


func close_bill() -> void:
	if bill != null:
		bill.queue_free()
		bill = null


func open_desk() -> void:
	if desk != null:
		return
	desk = DeskScreen.new()
	root.add_child(desk)
	desk.setup(game, self)


func close_desk() -> void:
	if desk != null:
		desk.queue_free()
		desk = null


func open_menu() -> void:
	if menu != null:
		return
	menu = MenuScreen.new()
	root.add_child(menu)
	menu.setup(game, self)


func close_menu() -> void:
	if menu != null:
		menu.queue_free()
		menu = null


func hide_build() -> void:
	for n: Control in [build_bar, _shop, _tree]:
		if n:
			n.queue_free()
	hints_ui._drop_row()
	build_bar = null
	_shop = null
	_tree = null


func set_search(text: String) -> void:
	_search = text
	if _search_box and _search_box.text != text:
		_search_box.text = text
	shop_ui._refresh_catalog()


func _set_category(cat: String) -> void:
	if game.card.storing() and cat == "Upgrades":
		game.card.storage_upgrades()
		return
	if cat != _category and _shop:
		game.audio.sfx("tab", 0.08)
	_category = cat
	_search = ""   # a search looks through every category; picking one ends it
	if _search_box:
		_search_box.text = ""
	shop_ui._refresh_catalog()
	shop_ui._deal_cards()


func typing() -> bool:
	return _shop != null and _search_box.has_focus()


func focus_search() -> void:
	if _shop:
		_search_box.grab_focus()
		_search_box.edit()


func stop_typing() -> void:
	if typing():
		_search_box.release_focus()


## What a control is called for player p's device ("E", "A", "Use").
func _g(action: String, p := 0) -> String:
	if game.controls == null or p >= game.controls.players.size():
		return str(Controls.GLYPHS.keys[action])
	return game.controls.glyph(action, p)


func _mode(p := 0) -> String:
	if game.controls == null or p >= game.controls.players.size():
		return "keys"
	return game.controls.input_of(p).mode


