## Writes the member names a class inherits (methods, properties, signals, constants), one
## per line, for tools/gdsplit.py:
##   CHAIN=Node3D,Node,Object OUT=/tmp/inherited.txt godot --headless -s tools/godot_members.gd
extends SceneTree
func _init():
	var names := {}
	for c in OS.get_environment("CHAIN").split(","):
		for m in ClassDB.class_get_method_list(c, true): names[m.name] = 1
		for p in ClassDB.class_get_property_list(c, true): names[p.name] = 1
		for s in ClassDB.class_get_signal_list(c, true): names[s.name] = 1
		for k in ClassDB.class_get_integer_constant_list(c, true): names[k] = 1
	var f := FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
	for n in names: f.store_line(n)
	quit()
