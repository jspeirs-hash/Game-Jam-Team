extends Node2D
## Uses masked pieces of Adam's existing sprite; no replacement character art.
signal step
const SHEET := preload("res://Battle/Art/adam_sprites.png")
const ORIGIN := Vector2(110.875,217)
const STRIDE := 56.0
const STANCE := 0.6
var phase := 0.0
var blend := 0.0
var moving := false
var _left: Dictionary
var _right: Dictionary
var _body: Node2D
var _arms: Array[Node2D] = []
var _step_index := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_left = _leg(Vector2(104,145),Vector2(93,178),Vector2(89,210),[
		Vector2(99,138),Vector2(116,141),Vector2(113,160),Vector2(101,180),Vector2(88,185),Vector2(85,175),Vector2(94,157)
	],[Vector2(89,172),Vector2(103,176),Vector2(97,193),Vector2(96,207),Vector2(79,209),Vector2(78,198),Vector2(84,184)],Rect2(77,202,36,15))
	_right = _leg(Vector2(126,145),Vector2(128,178),Vector2(132,210),[
		Vector2(117,138),Vector2(136,140),Vector2(137,161),Vector2(136,183),Vector2(121,183),Vector2(117,163)
	],[Vector2(121,173),Vector2(137,173),Vector2(135,193),Vector2(141,207),Vector2(126,210),Vector2(120,200)],Rect2(120,201,29,16))
	_body = Node2D.new()
	_body.z_index = 2
	add_child(_body)
	var torso := _piece(_body,Vector2.ZERO,[Vector2(94,87),Vector2(128,87),Vector2(134,113),Vector2(139,141),Vector2(131,153),Vector2(94,153),Vector2(98,128),Vector2(94,108)])
	torso.position = -ORIGIN
	var head := _rect_piece(_body,Rect2(74,20,79,77),Vector2(110,87))
	head.position = Vector2(110,87)-ORIGIN
	for entry in [[Vector2(97,95),[Vector2(91,89),Vector2(104,92),Vector2(100,110),Vector2(92,128),Vector2(93,141),Vector2(84,154),Vector2(70,150),Vector2(72,132),Vector2(84,111)]],[Vector2(130,96),[Vector2(125,90),Vector2(138,91),Vector2(142,109),Vector2(142,126),Vector2(151,139),Vector2(141,151),Vector2(125,143),Vector2(125,129),Vector2(129,114)]]]:
		var arm := Node2D.new()
		arm.position = entry[0]-ORIGIN
		_body.add_child(arm)
		_piece(arm,entry[0],entry[1])
		_arms.append(arm)

func _piece(parent: Node, pivot: Vector2, points: Array) -> Polygon2D:
	var node := Polygon2D.new()
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for point: Vector2 in points:
		vertices.append(point-pivot)
		uv.append(point)
	node.polygon = vertices
	node.uv = uv
	node.texture = SHEET
	parent.add_child(node)
	return node

func _rect_piece(parent: Node, rect: Rect2, pivot: Vector2) -> Polygon2D:
	return _piece(parent,pivot,[rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])

func _bone(pivot: Vector2, end: Vector2, points: Array) -> Node2D:
	var node := Node2D.new()
	add_child(node)
	var visual := _piece(node,pivot,points)
	var angle := (end-pivot).angle()
	# Canonical bone axis is X, so stretching doesn't thicken the limb.
	var vertices := visual.polygon
	for i in range(vertices.size()): vertices[i] = vertices[i].rotated(-angle)
	visual.polygon = vertices
	node.set_meta("source_angle",angle)
	node.set_meta("source_length",pivot.distance_to(end))
	return node

func _leg(hip: Vector2, knee: Vector2, ankle: Vector2, thigh: Array, calf: Array, foot_rect: Rect2) -> Dictionary:
	var upper := _bone(hip,knee,thigh)
	var lower := _bone(knee,ankle,calf)
	var foot := _rect_piece(self,foot_rect,ankle)
	return {"hip":hip-ORIGIN,"knee":knee-ORIGIN,"ankle":ankle-ORIGIN,"upper":upper,"lower":lower,"foot":foot}

func advance(distance_local: float) -> void:
	moving = true
	phase += distance_local/(STRIDE/STANCE)
	var contact := floori(phase*2.0)
	if contact!=_step_index:
		_step_index = contact
		step.emit()

func stop() -> void:
	moving = false

func _process(delta: float) -> void:
	blend = move_toward(blend,1.0 if moving else 0.0,delta/0.11)
	visible = blend>0.001
	var bob := -1.5*(1.0-cos(phase*TAU*2))*blend
	_body.position.y = bob
	_arms[0].rotation = sin(phase*TAU)*0.24*blend
	_arms[1].rotation = -sin(phase*TAU)*0.24*blend
	_pose_leg(_left,fposmod(phase,1.0),bob)
	_pose_leg(_right,fposmod(phase+0.5,1.0),bob)

func _pose_leg(leg: Dictionary, cycle: float, bob: float) -> void:
	var stride_x: float
	var lift := 0.0
	if cycle<STANCE:
		stride_x = lerpf(STRIDE*0.5,-STRIDE*0.5,cycle/STANCE)
	else:
		var swing := (cycle-STANCE)/(1.0-STANCE)
		stride_x = lerpf(-STRIDE*0.5,STRIDE*0.5,smoothstep(0,1,swing))
		lift = sin(swing*PI)*7.0
	var hip: Vector2 = leg.hip+Vector2(0,bob)
	var foot_target := Vector2(hip.x+stride_x,-7.0-lift)
	var delta := foot_target-hip
	var distance := clampf(delta.length(),1.0,71.8)
	var axis := delta.normalized()
	var along := (36.0*36.0-36.0*36.0+distance*distance)/(2.0*distance)
	var knee_target := hip+axis*along+Vector2(axis.y,-axis.x)*sqrt(maxf(0,36.0*36.0-along*along))
	var knee: Vector2 = (leg.knee as Vector2).lerp(knee_target,blend)
	var ankle: Vector2 = (leg.ankle as Vector2).lerp(foot_target,blend)
	hip = (leg.hip as Vector2).lerp(hip,blend)
	_set_bone(leg.upper,hip,knee)
	_set_bone(leg.lower,knee,ankle)
	leg.foot.position = ankle
	leg.foot.rotation = -sin(maxf(0,cycle-STANCE)/(1.0-STANCE)*PI)*0.12*blend

func _set_bone(bone: Node2D, origin: Vector2, end: Vector2) -> void:
	bone.position = origin
	bone.rotation = (end-origin).angle()
	bone.scale.x = origin.distance_to(end)/float(bone.get_meta("source_length"))


