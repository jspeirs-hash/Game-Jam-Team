extends Node2D
## Native pixel hologram; its only text is WARNING.
var age := 0.0
const FONT := preload("res://Scene/citadel_pixel.fnt")
func _ready() -> void:
	z_index = 30
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	age += delta
	queue_redraw()
func _draw() -> void:
	var flicker := 0.75+0.25*absf(sin(age*6.0))
	var red := Color(1,0.28,0.23,flicker)
	draw_rect(Rect2(-108,-35,216,70),Color(0.16,0.03,0.025,0.8))
	draw_rect(Rect2(-108,-35,216,70),red,false,2)
	for row in range(9):
		draw_line(Vector2(-104,-30+row*8),Vector2(104,-30+row*8),Color(1,0.22,0.18,0.08),1)
	var scan_y := -32+fposmod(age*38,64)
	draw_line(Vector2(-105,scan_y),Vector2(105,scan_y),Color(1,0.5,0.35,0.32),2)
	var text_width := FONT.get_string_size("WARNING",HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
	draw_string(FONT,Vector2(-text_width/2,8),"WARNING",HORIZONTAL_ALIGNMENT_LEFT,-1,24,red)
	draw_line(Vector2(-66,36),Vector2(-32,64),Color(1,0.32,0.2,0.22),2)
	draw_line(Vector2(66,36),Vector2(32,64),Color(1,0.32,0.2,0.22),2)
