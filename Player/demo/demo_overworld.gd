extends Node2D
## TEST ONLY. Scatters a few blocks so you can walk around them and check
## Y-sorting (walk above and below a block to see it draw in front/behind).

func _ready() -> void:
	y_sort_enabled = true
	for i in 12:
		var block := StaticBody2D.new()
		block.position = Vector2(randf_range(-200, 200), randf_range(-120, 120))
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(32, 10)
		shape.shape = rect
		block.add_child(shape)
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([Vector2(-16, 5), Vector2(16, 5), Vector2(16, -40), Vector2(-16, -40)])
		visual.color = Color.from_hsv(randf(), 0.35, 0.7)
		block.add_child(visual)
		add_child(block)
