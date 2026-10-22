extends CharacterBody2D
var hideout: Control
var actor: Node2D
var walk_rig: Node2D
var _walking := false
var _facing_left := false
func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	z_index = 10
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	add_child(shape)
	actor = preload("res://Battle/adam.tscn").instantiate()
	actor.scale = Vector2.ONE*0.45
	add_child(actor)
	walk_rig = Node2D.new()
	walk_rig.set_script(preload("res://scripts/adam_walk_rig.gd"))
	walk_rig.name = "WalkRig"
	actor.add_child(walk_rig)
	walk_rig.hide()
	walk_rig.step.connect(func(): GameAudio.sfx("footstep",randf_range(0.95,1.05)))
func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	var using_item: bool = not actor.current_item.is_empty()
	var blocked: bool = hideout.movement_blocked() or using_item
	if not blocked:
		direction.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		direction.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	var target := direction.normalized()*100.0*global_scale.x
	velocity = velocity.move_toward(target,1100.0*global_scale.x*delta)
	if blocked: velocity = Vector2.ZERO
	var before := position
	move_and_slide()
	position = position.clamp(Vector2(70,360),Vector2(1530,813))
	var moving := position.distance_to(before)>0.05
	if moving:
		if absf(position.x-before.x)>0.05:
			_facing_left = position.x<before.x
		actor.sprite.flip_h = _facing_left
		walk_rig.scale.x = -1 if _facing_left else 1
		walk_rig.advance(position.distance_to(before)/actor.scale.x)
	elif _walking:
		if not using_item: actor.idle()
		walk_rig.stop()
	actor.sprite.visible = not moving and walk_rig.blend<=0.001
	if using_item:
		walk_rig.stop()
		walk_rig.blend = 0
		walk_rig.hide()
		actor.sprite.show()
	_walking = moving

