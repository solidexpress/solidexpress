# Object-model: SketchRegions via SxSketch / SxDocument. Dummy renderer.
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("sketch regions")
	_closed_rect()
	finish()


func _closed_rect() -> void:
	var sk := SxSketch.new()
	sk.set_plane(Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 1, 0))
	sk.add_line(0, 0, 40, 0)
	sk.add_line(40, 0, 40, 20)
	sk.add_line(40, 20, 0, 20)
	sk.add_line(0, 20, 0, 0)
	check(sk.contour_count() == 1, "one closed contour")
	check(int(sk.region_at(20, 10)) == 0, "click inside the rectangle")
	check(int(sk.region_at(80, 10)) < 0, "click outside is no region")
