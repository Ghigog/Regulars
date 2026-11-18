class_name Ledger
extends RefCounted
## Money, XP, reputation and the day-by-day books.

const XP_PER_LEVEL := 100
## Reputation (review, item 9): one meter over the whole run, 0 to REP_MAX. Walkouts and
## guests who leave unhappy or unpaid pull it down; happy guests, perfect plates and a good
## review push it up. Nothing resets it at night. The run ends when it hits 0. A bad day
## (four or five walkouts) costs a good run about a third of the meter, so it hurts, but
## only a run of bad days (or a disastrous first day) closes the place. (all tunable)
const REP_MAX := 100.0
const REP_START := 50.0
const REP_WALKOUT := 8.0
const REP_UNPAID := 3.0
const REP_NOTHING := 0.5      # someone found nothing on the menu they would eat
const REP_HAPPY := 1.0        # a guest paid and left happy (satisfaction above HAPPY_AT)
const REP_UNHAPPY := 1.5      # a guest paid but left unhappy (below UNHAPPY_AT)
const HAPPY_AT := 0.3
const UNHAPPY_AT := 0.0
const REP_PERFECT := 0.5      # a perfect plate three or more into a streak
const REP_STAR := 4.0         # a review, per star above or below three
const REP_LOW := 25.0         # below this the meter shows its warning colour

var money := 150   # tunable: buys one simple main with change for a second ingredient
var xp := 0
var day := 1
var reputation := REP_START
var today := _blank()
var history: Array[Dictionary] = []


static func _blank() -> Dictionary:
	return {"sales": 0, "tips": 0, "served": 0, "walkouts": 0, "spent": 0, "stock": 0, "staff": 0, "unpaid": 0, "found_nothing": 0, "unpaid_bills": 0, "perfect": 0, "best_streak": 0, "rep_change": 0.0, "ordered": {}}


func level() -> int:
	return 1 + floori(float(xp) / XP_PER_LEVEL)


func record_sale(bill: int, tip: int) -> void:
	money += bill + tip
	today.sales += bill
	today.tips += tip
	today.served += 1
	xp += 10 + tip


## Pays for tonight's stock as the door opens. False, and nothing paid, if it is
## more than the money there is.
func pay_stock(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	today.stock += amount
	return true


## Staff wages, paid with the stock as the night ends (PRD 10.4): `amount` paid, and how
## many could not be paid (no debt: they take it out of their satisfaction instead).
func pay_staff(amount: int, unpaid := 0) -> void:
	amount = mini(amount, money)
	money -= amount
	today.staff += amount
	today.unpaid += unpaid


## A perfect tray served, `streak` in a row (review, item 6).
func record_perfect(streak: int) -> void:
	today.perfect += 1
	today.best_streak = maxi(int(today.best_streak), streak)
	if streak >= 3:
		move_reputation(REP_PERFECT)


## A menu item was ordered (for the receipt's nudge on what nobody ordered).
func record_order(item_id: int) -> void:
	var o: Dictionary = today.ordered
	o[item_id] = int(o.get(item_id, 0)) + 1


## Moves the reputation meter by `amount`, kept between 0 and REP_MAX.
func move_reputation(amount: float) -> void:
	var before := reputation
	reputation = clampf(reputation + amount, 0.0, REP_MAX)
	today.rep_change = float(today.rep_change) + reputation - before


## A guest paid and left with this satisfaction: happy ones raise the meter, unhappy lower it.
func record_visit(satisfaction: float) -> void:
	if satisfaction > HAPPY_AT:
		move_reputation(REP_HAPPY)
	elif satisfaction < UNHAPPY_AT:
		move_reputation(-REP_UNHAPPY)


## The critic's stars move the meter: up for four or five, down for one or two.
func record_review(stars: int) -> void:
	move_reputation((stars - 3) * REP_STAR)


## Someone read the menu and found no main they would eat. Not a strike.
func record_found_nothing(count := 1) -> void:
	today.found_nothing += count
	move_reputation(-REP_NOTHING * count)


## A party left without paying (PRD 11): no money, and not a strike.
func record_unpaid_bill() -> void:
	today.unpaid_bills += 1
	move_reputation(-REP_UNPAID)


func record_walkout() -> void:
	today.walkouts += 1
	move_reputation(-REP_WALKOUT)


## Today's walkouts (for the receipt; they no longer end the run on their own).
func strikes() -> int:
	return today.walkouts


func is_closed_down() -> bool:
	return reputation <= 0.0


## Everything earned across the whole run, including today.
func lifetime_earnings() -> int:
	var total: int = today.sales + today.tips
	for rec in history:
		total += int(rec.sales) + int(rec.tips)
	return total


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	today.spent += amount
	return true


## Money back for something sold. It comes off today's spending.
func refund(amount: int) -> void:
	money += amount
	today.spent -= amount


## Closes the books for the day and returns that day's record.
func end_day() -> Dictionary:
	var record := today.duplicate()
	record["day"] = day
	record["level"] = level()
	record["level_was"] = int(history[-1].get("level", 1)) if not history.is_empty() else 1
	record["reputation"] = reputation
	history.append(record)
	today = _blank()
	day += 1
	return record
