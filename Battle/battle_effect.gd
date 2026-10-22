extends Node2D

var kind := "hit"
var tint := Color("ffd594")
var caption := ""
var age := 0.0
var lifetime := 0.65
var direction := 1.0
var beam_end := Vector2.ZERO
var font: Font = preload("res://Scene/citadel_pixel.fnt")

func _ready() -> void:
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := age / lifetime
	var color := Color(tint, 1.0-progress)
	if kind == "beam" or kind == "ultimate_beam":
		var front := clampf(progress*1.5,0.0,1.0)
		var back := clampf(front-0.26,0.0,1.0)
		draw_line(beam_end*back,beam_end*front,Color(tint,0.45),46 if kind=="ultimate_beam" else 18)
		draw_line(beam_end*back,beam_end*front,Color("ffe2a2"),15 if kind=="ultimate_beam" else 7)
	elif kind == "ultimate" or kind == "ultimate_charge":
		var radius := 130*progress if kind=="ultimate" else 110*(1.0-progress)+22
		for ring in range(2):
			var points := PackedVector2Array()
			for i in range(25):
				var angle := TAU*i/24.0
				points.append((Vector2(cos(angle),sin(angle))*(radius+ring*16)).snapped(Vector2(3,3)))
			draw_polyline(points,Color(tint,(1-progress)*(0.7 if ring else 1.0)),4)
		for i in range(12):
			var angle := TAU*i/12.0+progress
			var point := Vector2(cos(angle),sin(angle))*radius
			draw_rect(Rect2(point.snapped(Vector2(3,3))-Vector2(4,4),Vector2(8,8)),color)
	elif kind == "stun":
		for i in range(3):
			var angle := TAU*i/3+age*7
			var point := Vector2(cos(angle)*40,sin(angle)*12)-Vector2(0,65)
			draw_rect(Rect2(point.snapped(Vector2(2,2))-Vector2(4,4),Vector2(8,8)),color)
	elif kind == "hit" or kind == "skill":
		var radius := (42.0 if kind == "hit" else 68.0) * (0.6+progress)
		var points := PackedVector2Array()
		for i in range(16):
			var angle := TAU * i / 16.0
			var distance := radius * (1.0 if i%2 == 0 else 0.32)
			points.append(Vector2(cos(angle),sin(angle))*distance)
		draw_colored_polygon(points,color)
		for i in range(8):
			var angle := TAU * i/8.0
			var point := Vector2(cos(angle),sin(angle)) * (24+progress*95)
			draw_rect(Rect2(point-Vector2(3,3),Vector2(6,6)),color)
	elif kind == "heal":
		for ring in range(3):
			var points := PackedVector2Array()
			for i in range(33):
				var angle := TAU*i/32.0
				points.append(Vector2(cos(angle)*64,sin(angle)*18)+Vector2(0,75-ring*53-progress*30))
			draw_polyline(points,color,3.0)
		for i in range(7):
			var x := sin(i*2.7)*65
			var y := 80-i*29-progress*65
			draw_rect(Rect2(x-3,y-10,6,20),color)
			draw_rect(Rect2(x-10,y-3,20,6),color)
	elif kind == "guard":
		var x := direction*68
		var points := PackedVector2Array([Vector2(x-42,-70),Vector2(x+42,-70),Vector2(x+42,20),Vector2(x,67),Vector2(x-42,20),Vector2(x-42,-70)])
		draw_colored_polygon(points,Color(tint,0.14*(1-progress)))
		draw_polyline(points,color,4.0)
		draw_line(Vector2(x,-48),Vector2(x,38),color,3)
	elif kind == "charge":
		for i in range(8):
			var angle := TAU*i/8.0+progress
			var point := Vector2(cos(angle),sin(angle))*(85-progress*55)
			draw_rect(Rect2(point-Vector2(4,4),Vector2(8,8)),color)
	if not caption.is_empty():
		var size := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24)
		var origin := Vector2(-size.x/2,-105-progress*45)
		draw_string(font,origin+Vector2(2,2),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(0,0,0,1-progress))
		draw_string(font,origin,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24,color)
