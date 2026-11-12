class_name Fx
extends Node3D
## Camera-facing toy billboards: flat cut-out cards played as four-frame
## sequences, with crisp edges and no soft alpha (style guide, sheet 13).

var frames: Array[Node3D] = []
var fps := 7.0
var loop := false
var drift := Vector3.ZERO
var _t := 0.0


## A card made of icon layers, `size` metres from centre to edge.
static func card(layers: Array, size: float) -> Node3D:
	var n := Node3D.new()
	n.basis = Build.CAM_BASIS
	n.scale = Vector3(size, size, 1.0)
	for i in layers.size():
		Build.flat(n, layers[i][0], layers[i][1], i * 0.004)
	return n


static func play(parent: Node3D, id: String, at: Vector3, size := 0.4, looping := false) -> Fx:
	var fx := Fx.new()
	fx.loop = looping
	fx.position = at
	for layers: Array in Icons.fx(id):
		var c := card(layers, size)
		c.visible = false
		fx.add_child(c)
		fx.frames.append(c)
	fx.frames[0].visible = true
	parent.add_child(fx)
	return fx


func _process(delta: float) -> void:
	_t += delta
	var i := int(_t * fps)
	if i >= frames.size():
		if not loop:
			queue_free()
			return
		i %= frames.size()
	for k in frames.size():
		frames[k].visible = k == i
	position += drift * delta


## The gold coin that pops out of a paid bill, hops, spins and banks upward.
static func coin(parent: Node3D, at: Vector3) -> void:
	var c := card(Icons.icon("coin"), 0.2)
	c.position = at
	parent.add_child(c)
	var up := Build.CAM_BASIS.y
	var tw := c.create_tween()
	tw.tween_property(c, "position", at + up * 0.6, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", at + up * 0.25, 0.14).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "position", at + up * 4.0 - Build.CAM_BASIS.x * 5.0, 0.45).set_ease(Tween.EASE_IN).set_delay(0.12)
	tw.tween_callback(c.queue_free)
	var spin := c.create_tween().set_loops(4)
	spin.tween_property(c, "scale:x", 0.04, 0.09)
	spin.tween_property(c, "scale:x", 0.2, 0.09)


## A thought bubble: two lead-in dots into a thick-rimmed cream cloud that holds
## one bold icon. Call `show_icon` on the returned node's script-free API below.
static func bubble() -> Node3D:
	var b := card(Icons.bubble(), 0.3)
	var holder := Node3D.new()
	holder.name = "icon"
	holder.position.z = 0.08
	b.add_child(holder)
	b.visible = false
	b.set_meta("icon", "")
	return b


static func set_bubble(b: Node3D, id: String) -> void:
	if b.get_meta("icon") == id:
		return
	b.set_meta("icon", id)
	var holder: Node3D = b.get_node("icon")
	for c in holder.get_children():
		c.queue_free()
	b.visible = id != ""
	if id == "":
		return
	var layers := Icons.icon(id)
	for i in layers.size():
		Build.flat(holder, Icons._moved([layers[i]], Vector2.ZERO, 0.62)[0][0], layers[i][1], i * 0.004)
	# It forms from the dots: a quick pop.
	b.scale = Vector3.ONE * 0.05
	b.create_tween().tween_property(b, "scale", Vector3(0.3, 0.3, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
