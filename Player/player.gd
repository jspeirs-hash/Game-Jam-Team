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

@export_group("Look")
## Sprite sheet: 4 columns (stand, step, stand, step) x 3 rows (down, up, right).
## Left is the right row flipped. Swap in real art with the same layout.
@export var sprite_sheet: Texture2D = preload("res://Player/art/player_sheet.png")
@export var frame_size: Vector2i = Vector2i(24, 36)
## Empty pixels under the feet in each frame.
@export var foot_padding: int = 2
@export var walk_fps: float = 8.0

var facing: Vector2 = Vector2.DOWN
var can_move: bool = true

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interact_ray: RayCast2D = $InteractRay

const ROWS := { "down": 0, "up": 1, "side": 2 }


func _ready() -> void:
	_ensure_input_actions()
	sprite.sprite_frames = _build_frames()
	sprite.position.y = -frame_size.y / 2.0 + foot_padding
	sprite.play("idle_down")


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


## Cuts the sheet into idle_<dir> and walk_<dir> animations.
func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for dir in ROWS:
		var row: int = ROWS[dir]
		var idle := StringName("idle_" + dir)
		var walk := StringName("walk_" + dir)
		frames.add_animation(idle)
		frames.add_frame(idle, _cut(0, row))
		frames.add_animation(walk)
		frames.set_animation_speed(walk, walk_fps)
		for col in 4:
			frames.add_frame(walk, _cut(col, row))
	return frames


func _cut(col: int, row: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = sprite_sheet
	t.region = Rect2(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
	return t


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var running := Input.is_action_pressed("run")
	if input != Vector2.ZERO:
		facing = input.normalized()
		var speed := run_speed if running else walk_speed
		var target := Vector2(input.x, input.y * vertical_scale).normalized() * speed * input.length()
		velocity = velocity.move_toward(target, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_animation(input != Vector2.ZERO, running)
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


func _facing_name() -> String:
	if absf(facing.x) > absf(facing.y) * 0.9:
		return "side"
	return "down" if facing.y > 0.0 else "up"


func _update_animation(moving: bool, running: bool) -> void:
	var dir := _facing_name()
	if dir == "side":
		sprite.flip_h = facing.x < 0.0
	var anim := StringName(("walk_" if moving else "idle_") + dir)
	if sprite.animation != anim:
		var frame := sprite.frame
		sprite.play(anim)
		if moving:
			sprite.frame = frame # keep the step going when turning
	sprite.speed_scale = run_speed / walk_speed if moving and running else 1.0


func _draw() -> void:
	# Soft shadow at the feet sells the 2.5D look.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, -1), 9.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
