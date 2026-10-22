extends Node2D

## Black-hole floor effect. Pixel-stepped ellipses and wisps remain behind actors.
var opening := 0.0
var power := 0.0
var clock := 0.0

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func ellipse(rx: float, ry: float, center := Vector2.ZERO) -> PackedVector2Array:
	var points := PackedVector2Array()
	rx = maxf(2.0,rx)
	ry = maxf(2.0,ry)
	for i in range(65):
		var angle := TAU * i / 64.0
		var point := (center + Vector2(cos(angle) * rx, sin(angle) * ry)).snapped(Vector2(2,2))
		if points.is_empty() or points[points.size()-1] != point:
			points.append(point)
	if points.size() > 1 and points[0] == points[points.size()-1]:
		points.remove_at(points.size()-1)
	return points

func _draw() -> void:
	if opening <= 0.001:
		# Only a very small grounded shadow before the transformation.
		draw_colored_polygon(ellipse(25,5),Color(0.005,0.01,0.02,0.55))
		return
	var radius := lerpf(42.0,180.0,power) * opening
	var depth := lerpf(10.0,35.0,power) * opening
	draw_colored_polygon(ellipse(radius+18,depth+7),Color(0.07,0.045,0.15,0.55*opening))
	draw_colored_polygon(ellipse(radius+7,depth+3),Color(0.17,0.13,0.29,opening))
	draw_colored_polygon(ellipse(radius,depth),Color(0.001,0.001,0.004,opening))
	# Layered rising puffs give the emergence a moving smoke column.
	for i in range(14):
		var phase := fmod(clock*0.22+float(i)/14.0,1.0)
		var spread := sin(float(i)*4.7+clock*0.5)*(40.0+power*90.0)
		var center := Vector2(spread,-phase*(90.0+power*170.0))
		var puff := (18.0+sin(float(i))*8.0+phase*23.0)*power
		if puff > 4.0:
			draw_colored_polygon(ellipse(puff,puff*0.7,center),Color(0.065,0.075,0.12,(1.0-phase)*opening*0.72))
	for i in range(30):
		var phase := clock * 0.8 + i * 2.399
		var point := Vector2(cos(phase)*radius,sin(phase)*depth)
		var size := 2.0 + float(i%3)*2.0
		draw_rect(Rect2(point.snapped(Vector2(2,2)),Vector2(size*2,size)),Color(0.3,0.26,0.43,opening*0.7))
	for i in range(18):
		var phase := fmod(clock*0.35 + float(i)/18.0,1.0)
		var point := Vector2(sin(i*7.1+clock)*radius*(1.0-phase),-phase*(65.0+power*70.0))
		draw_rect(Rect2(point.snapped(Vector2(3,3)),Vector2(5,8)),Color(0.10,0.08,0.18,(1.0-phase)*opening*0.8))
