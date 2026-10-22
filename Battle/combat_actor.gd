extends Node2D

@export var facing_left := false
@export var fighter_name := "ADAM"
@export var body_height := 110.0
@onready var sprite: AnimatedSprite2D = $Sprite
var home := Vector2.ZERO
var defeated := false
var _version := 0
var _travel: Tween
var _reaction: Tween
signal item_animation_started(item: String)
var current_item := ""

func _ready() -> void:
	home = position
	sprite.flip_h = facing_left
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float flash = 0.0; uniform vec4 flash_color : source_color = vec4(1.0); void fragment(){ COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	sprite.material = material
	idle()

func _draw() -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * i / 24.0
		points.append(Vector2(cos(angle)*35, sin(angle)*6))
	draw_colored_polygon(points, Color(0.005,0.01,0.02,0.42))

func idle() -> void:
	if defeated:
		return
	_version += 1
	current_item = ""
	var item_visual := get_node_or_null("ItemVisual")
	if item_visual:
		item_visual.queue_free()
	sprite.position = Vector2.ZERO
	sprite.play("idle")

func animate(action: String) -> void:
	if defeated and action != "defeat":
		return
	_version += 1
	sprite.stop()
	sprite.play(action)

func use_item(item: String) -> void:
	if item=="apple":
		animate("item")
	elif item=="bandage":
		animate("defend")
		sprite.stop()
		sprite.frame = 1
	else:
		idle()
	current_item = item
	item_animation_started.emit(item)
	var version := _version
	var visual := Node2D.new()
	visual.set_script(preload("res://Battle/item_visual.gd"))
	visual.name = "ItemVisual"
	visual.item = item
	visual.duration = 1.02/maxf(sprite.speed_scale,0.1)
	add_child(visual)
	visual.finished.connect(func():
		if version==_version and not defeated:
			idle()
	)

func show_intent(action: String, tint: Color, seconds: float) -> void:
	var visual := Node2D.new()
	visual.set_script(preload("res://Battle/intent_visual.gd"))
	visual.kind = action
	visual.tint = tint
	visual.duration = seconds
	visual.position = Vector2(0,-body_height)
	add_child(visual)

func move_to_global(destination: Vector2, duration := 0.28) -> void:
	if _travel and _travel.is_valid():
		_travel.kill()
	if not defeated:
		sprite.play("walk")
	_travel = create_tween()
	_travel.tween_property(self, "global_position", destination, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _travel.finished

func go_home() -> void:
	if _travel and _travel.is_valid():
		_travel.kill()
	sprite.play("walk")
	_travel = create_tween()
	_travel.tween_property(self, "position", home, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _travel.finished
	idle()

func hold_guard() -> void:
	animate("defend")
	var version := _version
	await get_tree().create_timer(0.26).timeout
	if version == _version and not defeated:
		sprite.position = Vector2.ZERO
		sprite.stop()
		sprite.frame = 1

func react_hit(blocked := false) -> void:
	if defeated:
		return
	if _reaction and _reaction.is_valid():
		_reaction.kill()
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("flash_color", Color("9debf0") if blocked else Color.WHITE)
	material.set_shader_parameter("flash", 0.88)
	_reaction = create_tween().set_parallel(true)
	_reaction.tween_method(func(value: float): material.set_shader_parameter("flash", value), 0.88, 0.0, 0.24)
	_reaction.tween_property(sprite, "position:x", -7.0 if facing_left else 7.0, 0.05).set_trans(Tween.TRANS_BOUNCE)
	if blocked:
		hold_guard()
		return
	animate("hurt")
	var version := _version
	await get_tree().create_timer(0.4).timeout
	if version == _version and not defeated:
		idle()

func fall() -> void:
	if defeated:
		return
	defeated = true
	_version += 1
	if _reaction and _reaction.is_valid():
		_reaction.kill()
	sprite.position = Vector2.ZERO
	(sprite.material as ShaderMaterial).set_shader_parameter("flash",0.0)
	sprite.stop()
	sprite.play("defeat")

func reset_actor() -> void:
	if _travel and _travel.is_valid():
		_travel.kill()
	if _reaction and _reaction.is_valid():
		_reaction.kill()
	defeated = false
	position = home
	modulate = Color.WHITE
	(sprite.material as ShaderMaterial).set_shader_parameter("flash", 0.0)
	idle()
