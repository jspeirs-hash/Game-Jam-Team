extends Node2D
var age := 0.0
var duration := 0.6
var kind := "attack"
var tint := Color("7de4f1")
func _ready() -> void:
	z_index = 15
func _process(delta: float) -> void:
	age += delta
	if age>=duration:
		queue_free()
	else:
		queue_redraw()
func _draw() -> void:
	var phase := age/maxf(duration,0.01)
	var color := Color(tint,0.35+0.65*absf(sin(phase*PI*2)))
	var radius := 76.0-26.0*phase
	if kind=="defend":
		draw_polyline(PackedVector2Array([Vector2(-45,-60),Vector2(45,-60),Vector2(45,12),Vector2(0,55),Vector2(-45,12),Vector2(-45,-60)]),color,4)
	else:
		for i in range(8):
			var angle := i*TAU/8.0
			var point := Vector2(cos(angle),sin(angle))*radius
			draw_rect(Rect2(point.snapped(Vector2(2,2))-Vector2(3,3),Vector2(6,6)),color)
		if kind=="skill":
			draw_line(Vector2(-25,0),Vector2(25,0),color,3)
			draw_line(Vector2(0,-25),Vector2(0,25),color,3)
