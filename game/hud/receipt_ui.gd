class_name HudReceipt
extends RefCounted
## The end-of-day receipt (show_summary), the critic's review, and the paper helpers they
## share: cards popping in, ribbons, ornaments, rows and buttons.

var hud: Hud


func _init(hud_: Hud) -> void:
	hud = hud_


## Room kept clear above and below a clipboard on screen.
const CLIP_MARGIN := 24.0
## The paper's scroll on the board now open (null when none), for the pad to nudge.
var paper_scroll: ScrollContainer


func hide_card() -> void:
	paper_scroll = null
	for c in hud.center.get_children():
		hud.center.remove_child(c)
		c.queue_free()


func _pop_in(panel: Control) -> void:
	panel.pivot_offset = Vector2(240, 200)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)


## Puts the board's paper in a scroll inside `stack` and returns the box to fill with it.
## The buttons added to `stack` afterwards stay pinned under it. Call `fit_paper` once the
## box is filled; it is repeated when the window is resized.
func paper_box(clip: Control, stack: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_theme_scrollbar(scroll.get_v_scroll_bar())
	stack.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", stack.get_theme_constant("separation"))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	paper_scroll = scroll
	scroll.set_meta("clip", clip)
	var refit := func() -> void:
		if is_instance_valid(scroll) and scroll.is_inside_tree():
			fit_paper(scroll)
	hud.center.resized.connect(refit)
	scroll.tree_exited.connect(func() -> void:
		if is_instance_valid(hud) and is_instance_valid(hud.center) and hud.center.resized.is_connected(refit):
			hud.center.resized.disconnect(refit))
	return box


## A ScrollContainer reports no height of its own, so give it the paper's, or the room the
## screen has left once the clip's padding, buttons and gaps are taken out, whichever is less.
func fit_paper(scroll: ScrollContainer) -> void:
	var clip: Control = scroll.get_meta("clip")
	var stack := scroll.get_parent() as VBoxContainer
	var screen := hud.center.size.y
	if screen <= 0.0:
		screen = hud.get_viewport().get_visible_rect().size.y
	var room := screen - 2.0 * CLIP_MARGIN - clip.get_theme_constant("margin_top") - clip.get_theme_constant("margin_bottom")
	var shown := 1
	for c in stack.get_children():
		if c != scroll and c is Control and c.visible:
			room -= c.get_combined_minimum_size().y
			shown += 1
	room -= (shown - 1) * stack.get_theme_constant("separation")
	var paper_h: float = (scroll.get_child(0) as Control).get_combined_minimum_size().y
	scroll.custom_minimum_size.y = maxf(minf(paper_h, room), 0.0)


## A thin ink grabber on a clear track, so the wood shows through.
func _theme_scrollbar(bar: ScrollBar) -> void:
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(Hud.INK, 0.8)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	var hot := grab.duplicate() as StyleBoxFlat
	hot.bg_color = Hud.INK
	for n: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(n, grab if n == "grabber" else hot)
	for n: String in ["scroll", "scroll_focus"]:
		bar.add_theme_stylebox_override(n, StyleBoxEmpty.new())


## Nudge the open board's paper (the pad's stick or D-pad). False when nothing scrolls.
func scroll_paper(dy: float) -> bool:
	if not is_instance_valid(paper_scroll) or not paper_scroll.is_inside_tree():
		return false
	paper_scroll.scroll_vertical += roundi(dy)
	return true


func _ribbon(box: VBoxContainer, text: String, col: Color) -> void:
	var ribbon := HudWidgets.Sheet.new("ribbon", 30, 6)
	ribbon.tint = col
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ribbon)
	var l := hud._label(ribbon, 26, text)
	l.add_theme_color_override("font_color", Hud.CREAM)


## Fit now, and again once the labels have their widths.
func _fit_when_laid_out(scroll: ScrollContainer) -> void:
	fit_paper(scroll)
	var again := func() -> void:
		if is_instance_valid(scroll) and scroll.is_inside_tree():
			fit_paper(scroll)
	again.call_deferred()


## A rule with a small round token in the middle, as on the game-over card.
func _ornament(box: VBoxContainer, icon: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for i in 2:
		var line := ColorRect.new()
		line.color = Color(Hud.INK, 0.4)
		line.custom_minimum_size = Vector2(110, 2)
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
		if i == 0:
			row.add_child(HudWidgets.Icon.new(icon, 30))


func _centred(box: VBoxContainer, text: String, font := 28) -> Label:
	var l := hud._label(box, font, text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _row(box: VBoxContainer, icon: String, title: String, value: String, font := 22) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	if icon != "":
		row.add_child(HudWidgets.Icon.new(icon, font + 10))
	var l := hud._label(row, font, title)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return hud._label(row, font, value)


func _rule(box: VBoxContainer) -> void:
	var l := hud._label(box, 14, "- ".repeat(60))
	l.clip_text = true
	l.modulate.a = 0.45


func _button(box: Container, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE   # so Enter always means "carry on"
	b.pressed.connect(action)
	box.add_child(b)
	return b


## End of day: a torn diner receipt on a wooden clipboard, with the town gossip
## pinned beside it.
func show_summary(rec: Dictionary, animate := true) -> void:
	hide_card()
	hud._town_open = false
	var clip := HudWidgets.Sheet.new("clip").pad(26, 46, 26, 26)
	hud.center.add_child(clip)
	hud._summary_clip = clip
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	clip.add_child(stack)
	var paper := paper_box(clip, stack)
	var receipt := HudWidgets.Sheet.new("receipt").pad(30, 22, 30, 34)
	receipt.custom_minimum_size = Vector2(430, 0)
	if rec.has("review"):   # the critic's review, cut from tonight's paper, beside the receipt
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		paper.add_child(row)
		row.add_child(receipt)
		var cutting := clipping(rec.review)
		cutting.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(cutting)
	else:
		paper.add_child(receipt)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	receipt.add_child(box)
	_ribbon(box, "END OF DAY %d" % rec.day, Hud.CORAL)
	_row(box, "", "MEALS SERVED:", str(rec.served))
	_row(box, "", "SALES:", "$%d" % rec.sales)
	_row(box, "", "TIPS:", "$%d" % rec.tips)
	_row(box, "", "WALKOUTS:", str(rec.walkouts))
	if rec.has("reputation"):   # review, item 9: the meter, and how today moved it
		var ch := float(rec.get("rep_change", 0.0))
		_row(box, "", "REPUTATION:", "%d  (%s%d)" % [roundi(float(rec.reputation)), "+" if ch >= 0.0 else "-", absi(roundi(ch))])
	if int(rec.get("perfect", 0)) > 0:   # review, item 6: good prep shows on the books
		_row(box, "", "PERFECT PLATES:", "%d   (best run %d)" % [int(rec.perfect), int(rec.get("best_streak", 0))])
	var unpaid_bills := int(rec.get("unpaid_bills", 0))
	if unpaid_bills > 0:   # PRD 11: parties who left without paying, an open-purse stamp each
		var ub := _row(box, "", "LEFT UNPAID:", str(unpaid_bills))
		for k in mini(unpaid_bills, 5):
			var purse := HudWidgets.Icon.new("purse", 34, false)
			purse.rotation = [-0.12, 0.08, -0.04, 0.14, -0.1][k]
			ub.get_parent().add_child(purse)
			ub.get_parent().move_child(purse, ub.get_index())
	_row(box, "", "STOCK:", "-$%d" % int(rec.get("stock", 0)))
	if int(rec.get("staff", 0)) > 0 or int(rec.get("unpaid", 0)) > 0:   # wages, paid with the stock (PRD 10.4)
		_row(box, "", "STAFF:", "-$%d" % int(rec.get("staff", 0)))
		var unpaid := int(rec.get("unpaid", 0))
		if unpaid > 0:
			var ul := hud._label(box, 15, "%s not paid: no debt, but they mind." % ("1 wage" if unpaid == 1 else "%d wages" % unpaid))
			ul.add_theme_color_override("font_color", Hud.CORAL.darkened(0.25))
	for line: String in rec.get("unordered", []):   # review, item 11: a side or drink nobody ordered
		var ul := hud._label(box, 15, line)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.custom_minimum_size = Vector2(360, 0)
		ul.modulate.a = 0.75
	var nothing := int(rec.get("found_nothing", 0))
	if nothing > 0:
		var nl := hud._label(box, 15, "%d %s nothing they liked." % [nothing, "person found" if nothing == 1 else "people found"])
		nl.modulate.a = 0.75
	_rule(box)
	var earned: int = rec.sales + rec.tips
	var total := _row(box, "", "TOTAL EARNED:", "$%d" % earned, 32)
	total.get_parent().add_child(HudWidgets.Icon.new("coins", 34, false))
	if animate:
		total.create_tween().tween_method(func(v: float) -> void: total.text = "$%d" % roundi(v), 0.0, float(earned), 0.9) \
		.set_delay(0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_row(box, "", "IN THE BANK:", "$%d" % hud.game.ledger.money)
	_new_in_shop(box, rec)
	var note := HudWidgets.Sheet.new("note").pad(18, 14, 18, 12)
	note.rotation = -0.035
	paper.add_child(note)
	var gossip := hud._label(note, 19, "TOWN GOSSIP: " + hud.game.town.headline())
	gossip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gossip.custom_minimum_size = Vector2(380, 0)
	_button(stack, "Town book" + hud.hints_ui._key_note("town"), hud.screens_ui.show_town)
	_button(stack, ("Set up for day %d" % hud.game.ledger.day) + hud.hints_ui._key_note("confirm"),
		func() -> void: hud.game.coop.confirm_receipt(hud.game.controls.owner_of("keys") if hud.game.controls else 0))
	# Co-op: everyone confirms. A tag per player, ticked once they have.
	hud._ready_row = HBoxContainer.new()
	hud._ready_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hud._ready_row.add_theme_constant_override("separation", 14)
	stack.add_child(hud._ready_row)
	hud.hints_ui.refresh_ready()
	_fit_when_laid_out(paper_scroll)
	if animate:
		_pop_in(clip)


## A day that ended on a new level: "LEVEL 3: NEW IN THE SHOP" and the pieces it opened,
## as little pictures with their names, so new pieces never turn up unannounced.
func _new_in_shop(box: VBoxContainer, rec: Dictionary) -> void:
	var lvl := int(rec.get("level", 1))
	if lvl <= int(rec.get("level_was", 1)):
		return
	var fresh: Array[Dictionary] = []
	for l in range(int(rec.get("level_was", 1)) + 1, lvl + 1):
		fresh.append_array(Catalog.unlocked_at(l, Scenery.theme_id))
	_rule(box)
	_row(box, "", "LEVEL %d:" % lvl, "NEW IN THE SHOP" if not fresh.is_empty() else "")
	var names := ", ".join(fresh.map(func(bp: Dictionary) -> String: return Catalog.label(bp)))
	if names != "":
		var nl := hud._label(box, 16, names)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(380, 0)


## The critic's review as a newspaper cutting: masthead, a headline by stars, the
## stars, the four ratings (each with its icon and a row of pips), the line that
## confirms or contradicts the town, and the byline with the critic's peg.
func clipping(review: Dictionary) -> Control:
	var cut := HudWidgets.Sheet.new("news").pad(24, 18, 24, 20)
	cut.custom_minimum_size = Vector2(350, 0)
	cut.rotation = 0.025
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	cut.add_child(box)
	var mast := _centred(box, "THE TOWN CRIER  ·  DAY %d" % int(review.day), 14)
	mast.modulate.a = 0.65
	for k in 2:   # the masthead's double rule
		var line := ColorRect.new()
		line.color = Color(Hud.INK, 0.7 if k == 0 else 0.4)
		line.custom_minimum_size = Vector2(0, 3 if k == 0 else 1)
		box.add_child(line)
	var head := _centred(box, review.headline, 27)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(300, 0)
	var stars := HudWidgets.Rating.new(int(review.stars), true)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(stars)
	for t: String in Critic.TOPICS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		row.add_child(HudWidgets.Icon.new(Hud.RATING_ICONS[t], 30))
		var l := hud._label(row, 18, Critic.TOPIC_WORDS[t])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pips := HudWidgets.Rating.new(int(review.ratings[t]))
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pips)
		if t == "variety":   # the one rating that is a rule, not a taste: say it
			var rule := hud._label(box, 12, Critic.VARIETY_RULE + ".")
			rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rule.custom_minimum_size = Vector2(300, 0)
			rule.modulate.a = 0.65
	_rule(box)
	var said := hud._label(box, 17, "\"%s\"" % review.line)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.custom_minimum_size = Vector2(300, 0)
	var by := HBoxContainer.new()
	by.add_theme_constant_override("separation", 8)
	box.add_child(by)
	var face := HudWidgets.ModelView.new(84, false)
	by.add_child(face)
	face.show_peg(review.name)
	var words := VBoxContainer.new()
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	by.add_child(words)
	var sign := HBoxContainer.new()
	sign.add_theme_constant_override("separation", 6)
	words.add_child(sign)
	sign.add_child(HudWidgets.Icon.new("quill", 22, false))
	hud._label(sign, 19, "%s, our critic" % review.name)
	if review.get("first", false):   # the reveal
		var aside := hud._label(words, 13, "Yes, that %s. You served them on day %d." % [review.name, int(review.day)])
		aside.modulate.a = 0.7
	return cut


## The last review on its own, from the town book.
func show_review() -> void:
	hide_card()
	var clip := HudWidgets.Sheet.new("clip").pad(26, 46, 26, 26)
	hud.center.add_child(clip)
	hud._summary_clip = clip
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	clip.add_child(stack)
	paper_box(clip, stack).add_child(clipping(hud.game.critic.last_review))
	_button(stack, "Back", hud.screens_ui.show_town)
	_fit_when_laid_out(paper_scroll)
	_pop_in(clip)


const SHOP_TABS: Array[String] = ["Furniture", "Tools", "Ingredients", "Build", "Extras"]


## A piece's card (E on any piece at night, review item 4): its boxes (or just the piece,
## when it keeps none), then its upgrade tree when it has one.
const STORAGE_TABS: Array[String] = ["Ingredients", "Upgrades"]
