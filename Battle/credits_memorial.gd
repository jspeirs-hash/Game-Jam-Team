extends Node2D
## The last pose from the encounter stays still while the credits roll.
const ATLAS := preload("res://Battle/Art/adam_sprites.png")
var _body: Sprite2D
var _head: Sprite2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Snow behind the figure is softer and slower than the foreground flakes.
	_snow("DistantSnow",240,30.0,Vector2(26,42),Vector2(0.5,1),Color(0.64,0.77,0.9,0.4))
	_body = Sprite2D.new()
	_body.name = "KneelingBody"
	_body.texture = _region(Rect2(253,1458,145,84))
	_body.centered = false
	_body.position = Vector2(350,770)+Vector2(-79.625,-84)*2.2
	_body.scale = Vector2.ONE*2.2
	_body.modulate = Color(0.76,0.83,0.94)
	add_child(_body)
	_head = Sprite2D.new()
	_head.name = "FallenHead"
	_head.texture = _region(Rect2(74,20,78,69))
	_head.position = Vector2(90,770-78*2.2/2)
	_head.scale = Vector2.ONE*2.2
	_head.rotation = -PI/2
	_head.modulate = _body.modulate
	add_child(_head)
	_snow("ForegroundSnow",130,16.0,Vector2(62,88),Vector2(1,2),Color(0.85,0.92,1,0.72))
	resized_to_viewport()
	get_viewport().size_changed.connect(resized_to_viewport)

func _region(rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = rect
	texture.filter_clip = true
	return texture

func resized_to_viewport() -> void:
	var view := get_parent().size as Vector2
	scale = Vector2(view.x/1600.0,view.y/900.0)

func _snow(id: String, count: int, life: float, speed: Vector2, sizes: Vector2, tint: Color) -> void:
	var snow := CPUParticles2D.new()
	snow.name = id
	snow.position = Vector2(800,-30)
	snow.amount = count
	snow.lifetime = life
	snow.preprocess = life
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(1000,20)
	snow.direction = Vector2(-0.2,1)
	snow.spread = 14
	snow.gravity = Vector2.ZERO
	snow.initial_velocity_min = speed.x
	snow.initial_velocity_max = speed.y
	snow.scale_amount_min = sizes.x
	snow.scale_amount_max = sizes.y
	snow.color = tint
	snow.seed = 1407 if id=="DistantSnow" else 2231
	snow.use_fixed_seed = true
	var white := Gradient.new()
	white.colors = PackedColorArray([Color.WHITE,Color.WHITE])
	var pixel := GradientTexture2D.new()
	pixel.gradient = white
	pixel.width = 2
	pixel.height = 2
	snow.texture = pixel
	add_child(snow)

func _draw() -> void:
	# Broken paving and a thin layer of snow carry the encounter into the ending.
	_ground_shadow(Vector2(322,774),Vector2(260,25),Color(0.002,0.006,0.01,0.85))
	for i in range(6):
		var y := 770+i*22
		draw_line(Vector2(25,y),Vector2(570-i*26,y),Color(0.21,0.28,0.33,0.44),2)
		for j in range(4):
			var x := 55+j*125+(i%2)*52
			draw_line(Vector2(x,y),Vector2(x+8,y+22),Color(0.21,0.28,0.33,0.4),2)
	for i in range(34):
		var x := 32+fposmod(i*71.7,516)
		var y := 767+fposmod(i*37.3,116)
		draw_rect(Rect2(x,y,8+(i%4)*3,2),Color(0.58,0.68,0.76,0.34))

func _ground_shadow(center: Vector2, radius: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(48):
		var angle := TAU*i/48
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
	draw_colored_polygon(points,tint)
