class_name PinFixture
extends RefCounted
## Rung-8 in-context pin: R10 head + Ø10×35 shank + R10 tail, overall 55.
## Front XY, origin at the tail pole, revolve about sketch +Y.


static func add_profile(sk) -> void:
	sk.add_line(0.0, 0.0, 0.0, 55.0)
	sk.add_arc(0.0, 10.0, 10.0, -PI * 0.5, 0.0)
	sk.add_line(10.0, 10.0, 5.0, 10.0)
	sk.add_line(5.0, 10.0, 5.0, 45.0)
	sk.add_line(5.0, 45.0, 10.0, 45.0)
	sk.add_arc(0.0, 45.0, 10.0, 0.0, PI * 0.5)
