extends Node2D
var clock := 0.0
var motes: Array[Node] = []
var fires: Array[Node] = []
var smoke: Array[Node] = []
func _ready() -> void:
	motes = get_tree().get_nodes_in_group("hideout_mote")
	fires = get_tree().get_nodes_in_group("hideout_fire")
	smoke = get_tree().get_nodes_in_group("hideout_smoke")
	for node in motes+smoke:
		node.set_meta("home",node.position)
func _process(delta: float) -> void:
	clock += delta
	for i in range(motes.size()):
		var node: Node2D = motes[i]
		var home: Vector2 = node.get_meta("home")
		node.position = (home+Vector2(sin(clock*0.6+i)*12,-fmod(clock*8+i*7,75))).snapped(Vector2(2,2))
		node.modulate.a = 0.25+0.65*absf(sin(clock*0.7+i))
	for i in range(fires.size()):
		fires[i].modulate = Color(1,0.88+0.12*sin(clock*5+i),0.8+0.2*sin(clock*3+i),0.75+0.25*sin(clock*4+i))
	for i in range(smoke.size()):
		var node: Node2D = smoke[i]
		var home: Vector2 = node.get_meta("home")
		var age := fmod(clock*0.18+i*0.18,1.0)
		node.position = (home+Vector2(sin(clock*0.5+i)*16,-age*100)).snapped(Vector2(3,3))
		node.scale = Vector2.ONE*(0.6+age*0.9)
		node.modulate.a = (1.0-age)*0.45
