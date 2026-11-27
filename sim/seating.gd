class_name Seating
extends RefCounted
## What chairs and tables do to a guest's stay (EPIC-87). Pure numbers, no scenes.
## A piece's branch is "fast" (quick service: eat and order faster, tip less, mind anger and
## disgust more), "comfortable" (the reverse, and a little joy) or "" (Chair 1 / Table 1).
## A chair's and its table's effects multiply, then each factor is held to a floor and ceiling.

const FAST_EAT := 0.9        # tunable: eating-time factor per step
const FAST_ORDER := 0.9      # tunable: ordering-time factor per step
const FAST_TIP := 0.95       # tunable: tip factor per step
const FAST_TOLERANCE := 1.1  # tunable: anger and disgust factor per step
const COMFY_EAT := 1.1
const COMFY_ORDER := 1.1
const COMFY_TIP := 1.05
const COMFY_TOLERANCE := 0.9
const COMFY_JOY := 0.05      # tunable: joy per step (EPIC-85's comfort joy)

## Floor and ceiling of a combined factor.
const EAT_RANGE := Vector2(0.6, 1.5)
const ORDER_RANGE := Vector2(0.5, 1.6)
const TIP_RANGE := Vector2(0.8, 1.3)
const TOLERANCE_RANGE := Vector2(0.7, 1.4)

## Menu reading: seconds = clamp(BASE + PER_ITEM * items, 0, READ_CAP), times the order scale.
const READ_BASE := 1.0
const READ_PER_ITEM := 0.5
const READ_CAP := 6.0
const ORDER_SCALE_RANGE := Vector2(0.5, 1.6)


static func neutral() -> Dictionary:
	return {"eat": 1.0, "order": 1.0, "tip": 1.0, "tolerance": 1.0, "joy": 0.0}


## One piece's effect, `steps` along its branch.
static func piece_effect(path: String, steps: int) -> Dictionary:
	var out := neutral()
	var n := maxi(0, steps)
	match path:
		"fast":
			out.eat = pow(FAST_EAT, n)
			out.order = pow(FAST_ORDER, n)
			out.tip = pow(FAST_TIP, n)
			out.tolerance = pow(FAST_TOLERANCE, n)
		"comfortable":
			out.eat = pow(COMFY_EAT, n)
			out.order = pow(COMFY_ORDER, n)
			out.tip = pow(COMFY_TIP, n)
			out.tolerance = pow(COMFY_TOLERANCE, n)
			out.joy = COMFY_JOY * n
	return out


## A chair and its table together: factors multiply and are capped; only the chair gives joy.
static func combine(chair: Dictionary, table: Dictionary) -> Dictionary:
	var out := neutral()
	for key in ["eat", "order", "tip", "tolerance"]:
		out[key] = float(chair.get(key, 1.0)) * float(table.get(key, 1.0))
	out.eat = clampf(out.eat, EAT_RANGE.x, EAT_RANGE.y)
	out.order = clampf(out.order, ORDER_RANGE.x, ORDER_RANGE.y)
	out.tip = clampf(out.tip, TIP_RANGE.x, TIP_RANGE.y)
	out.tolerance = clampf(out.tolerance, TOLERANCE_RANGE.x, TOLERANCE_RANGE.y)
	out.joy = float(chair.get("joy", 0.0))   # comfort joy is the chair's alone
	return out


## The product of ordering modifiers from any upgrade tree, held to a range.
static func order_scale(mods: Array[float]) -> float:
	var s := 1.0
	for m in mods:
		s *= m
	return clampf(s, ORDER_SCALE_RANGE.x, ORDER_SCALE_RANGE.y)


## Seconds a guest reads the menu before calling the chef.
static func reading_time(menu_items: int, scale: float) -> float:
	return clampf(READ_BASE + READ_PER_ITEM * menu_items, 0.0, READ_CAP) * scale
