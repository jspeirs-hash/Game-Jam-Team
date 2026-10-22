extends Node2D
signal finished
var item := "bandage"
var duration := 1.02
var age := 0.0
func _ready() -> void:
	z_index = 25
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	age += delta
	if age>=duration:
		finished.emit()
		queue_free()
	else:
		queue_redraw()
func _draw() -> void:
	var progress := clampf(age/duration,0,1)
	if item=="bandage":
		var hand := Vector2(17,-119)
		var end := hand+Vector2(-40+sin(progress*TAU*2)*14,8+cos(progress*TAU*2)*5)
		draw_line(hand,end,Color("c5c4ae"),6)
		draw_rect(Rect2(hand-Vector2(14,9),Vector2(29,18)),Color("65685a"))
		draw_rect(Rect2(hand-Vector2(12,7),Vector2(25,14)),Color("ede8ce"))
		for stripe in range(4):
			draw_line(hand+Vector2(-10+stripe*7,-6),hand+Vector2(-13+stripe*7,6),Color("aaa993"),2)
		draw_rect(Rect2(end-Vector2(6,5),Vector2(12,10)),Color("f3eee0"))
	elif item=="ether":
		var lift := sin(minf(progress*1.7,1)*PI*0.5)
		var point := Vector2(40,-103).lerp(Vector2(18,-165),lift).snapped(Vector2(2,2))
		draw_line(Vector2(31,-112),point+Vector2(2,10),Color("f1c7b9"),7)
		draw_rect(Rect2(point+Vector2(-5,0),Vector2(13,23)),Color("172a43"))
		draw_rect(Rect2(point+Vector2(-3,3),Vector2(9,17)),Color("96d5df"))
		draw_rect(Rect2(point+Vector2(-2,10),Vector2(7,9)),Color("4b8fd4"))
		draw_rect(Rect2(point+Vector2(-1,-4),Vector2(5,6)),Color("b79862"))
		if progress>0.45:
			for i in range(3):
				draw_rect(Rect2(point+Vector2(16+i*7,-8-sin(progress*9+i)*8),Vector2(3,3)),Color("a4d9ff"))
