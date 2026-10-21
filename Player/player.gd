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
## Leave empty to use player_sheet_local.png if it exists, else player_sheet.png.
@export var sprite_sheet: Texture2D
@export var frame_size: Vector2i = Vector2i(32, 52)
## Empty pixels under the feet in each frame.
@export var foot_padding: int = 2
@export var walk_fps: float = 8.0

var facing: Vector2 = Vector2.DOWN
var can_move: bool = true

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interact_ray: RayCast2D = $InteractRay
@onready var camera: Camera2D = $Camera2D

var _sprite_offset := Vector2.ZERO
var _camera_offset := Vector2.ZERO

const ROWS := { "down": 0, "up": 1, "side": 2 }
## Local-only art (git-ignored) wins over the shared sheet.
const SHEETS := ["res://Player/art/player_sheet_local.png", "res://Player/art/player_sheet.png"]
## Sheets with 5 rows also have a hands-down side walk (row 3) and guard frames
## (row 4: up, halfway, down); 7 rows add the same for facing down (rows 5, 6).
## He lowers his guard to walk and raises it when he stops.
const GUARD_ROWS := 5
const FRONT_GUARD_ROWS := 7
const GUARD_FPS := 12.0

var _has_guard := false
var _rows := 3
var _was_moving := false


func _ready() -> void:
	_ensure_input_actions()
	if sprite_sheet == null:
		for path in SHEETS:
			if ResourceLoader.exists(path):
				sprite_sheet = load(path)
				break
	_rows = sprite_sheet.get_height() / frame_size.y
	_has_guard = _rows >= GUARD_ROWS
	sprite.sprite_frames = _build_frames()
	sprite.position.y = -frame_size.y / 2.0 + foot_padding
	_sprite_offset = sprite.position
	_camera_offset = camera.position
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
		var walk_row := row
		var guard_row := 4
		if _has_guard and dir != "up":
			walk_row = 3
			if dir == "down" and _rows >= FRONT_GUARD_ROWS:
				walk_row = 5
				guard_row = 6
		var cols := _frames_in_row(walk_row)
		frames.set_animation_speed(walk, walk_fps * cols / 4.0)
		for col in cols:
			frames.add_frame(walk, _cut(col, walk_row))
		if _has_guard and dir != "up":
			for kind in ["lower", "raise"]:
				var anim := StringName("guard_%s_%s" % [kind, dir])
				frames.add_animation(anim)
				frames.set_animation_loop(anim, false)
				var order := range(_frames_in_row(guard_row))
				if kind == "raise":
					order.reverse()
				# same duration whatever the frame count (3 frames = 0.25 s)
				frames.set_animation_speed(anim, GUARD_FPS * order.size() / 3.0)
				for col in order:
					frames.add_frame(anim, _cut(col, guard_row))
	return frames


## Number of frames drawn in a row (frames after the last drawn one are empty).
func _frames_in_row(row: int) -> int:
	var img := sprite_sheet.get_image()
	var count := 0
	for col in img.get_width() / frame_size.x:
		var rect := Rect2i(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
		if not img.get_region(rect).is_invisible():
			count = col + 1
	return count


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
	_snap_to_pixels()
	queue_redraw()
	_update_animation(input != Vector2.ZERO, running)
	interact_ray.target_position = facing * 20.0


## Draws the sprite and camera on whole pixels so pixel art stays crisp
## (the body itself still moves smoothly).
func _snap_to_pixels() -> void:
	var snap := global_position.round() - global_position
	sprite.position = _sprite_offset + snap
	camera.position = _camera_offset + snap


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
	if _has_guard and moving != _was_moving and dir != "up":
		sprite.speed_scale = 1.0
		sprite.play(StringName("guard_%s_%s" % ["lower" if moving else "raise", dir]))
	_was_moving = moving
	var transition := StringName("guard_%s_%s" % ["lower" if moving else "raise", dir])
	if sprite.animation == transition and sprite.is_playing():
		return # let the guard finish moving first
	if sprite.animation != anim:
		var frame := sprite.frame
		sprite.play(anim)
		if moving:
			sprite.frame = frame # keep the step going when turning
	sprite.speed_scale = run_speed / walk_speed if moving and running else 1.0


func _draw() -> void:
	# Soft shadow at the feet sells the 2.5D look.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, -1) + sprite.position - _sprite_offset, 12.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
