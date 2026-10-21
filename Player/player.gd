class_name Player
extends CharacterBody2D
## Top-down 2.5D overworld player. The node's origin is at the feet, so put
## it under a Node2D with y_sort_enabled and things in front/behind sort right.
##
## Controls: WASD / arrow keys to move, Shift to run, E / Space to interact.

signal interacted(target: Node)

@export var walk_speed: float = 110.0
@export var run_speed: float = 180.0
@export var acceleration: float = 900.0
@export var friction: float = 1100.0
## Squash the vertical axis a bit so up/down feels like walking into depth.
@export_range(0.5, 1.0) var vertical_scale: float = 0.85

var facing: Vector2 = Vector2.DOWN
var can_move: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_ray: RayCast2D = $InteractRay

var _bob_time := 0.0
var _sprite_base_y := 0.0


func _ready() -> void:
	_ensure_input_actions()
	_sprite_base_y = sprite.position.y


## Adds the movement actions if they aren't in Project Settings > Input Map yet,
## so the player works without anyone setting up keys by hand.
static func _ensure_input_actions() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT],
		"interact": [KEY_E, KEY_SPACE],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input != Vector2.ZERO:
		facing = input.normalized()
		var speed := run_speed if Input.is_action_pressed("run") else walk_speed
		var target := Vector2(input.x, input.y * vertical_scale).normalized() * speed * input.length()
		velocity = velocity.move_toward(target, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_visuals(delta)
	interact_ray.target_position = facing * 20.0


func _unhandled_input(event: InputEvent) -> void:
	if can_move and event.is_action_pressed("interact"):
		_try_interact()


func _try_interact() -> void:
	interact_ray.force_raycast_update()
	var hit := interact_ray.get_collider()
	if hit == null:
		return
	var target: Node = hit
	if not target.has_method("interact") and target.get_parent() and target.get_parent().has_method("interact"):
		target = target.get_parent()
	if target.has_method("interact"):
		target.interact(self)
	interacted.emit(target)


func _update_visuals(delta: float) -> void:
	if absf(facing.x) > 0.1:
		sprite.flip_h = facing.x < 0.0
	var moving := velocity.length() > 5.0
	if moving:
		_bob_time += delta * velocity.length() * 0.08
		sprite.position.y = _sprite_base_y - absf(sin(_bob_time)) * 3.0
	else:
		_bob_time = 0.0
		sprite.position.y = lerpf(sprite.position.y, _sprite_base_y, 0.3)
	queue_redraw()


func _draw() -> void:
	# Soft shadow at the feet sells the 2.5D look.
	var lift := _sprite_base_y - sprite.position.y
	var w := 14.0 - lift * 0.8
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
