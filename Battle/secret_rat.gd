extends Control
## Rat finale uses the very same HUD and action model as every robot fight.
signal phase_changed(phase: int)
signal dialogue_started(index: int, line: String)
signal dialogue_finished(index: int)
enum Phase { PLAYER_RAT, PLAYER_ACTION, RAT_WAIT, COLLAPSING, SINKING, PORTAL, EMERGING, PLAYER_CAT, CAT_ATTACK, DEATH, DEFEAT, FADING, CAT_DIALOGUE }
const RULES = preload("res://Battle/battle_rules.gd")
const EFFECT = preload("res://Battle/battle_effect.gd")
const CAT_LINES := [
	"ADAM, YOU FAILED TO SAVE THE WORLD.",
	"YOU LET DOWN EVERYONE WHO BELIEVED IN YOU.",
	"I WILL DESTROY THE WORLD. DIE, ADAM!"
]
const RAT_LINES := [
	"PLEASE... DON'T KILL ME.",
	"I DON'T WANT TO DIE. PLEASE, ADAM.",
	"I'M BEGGING YOU... LET ME LIVE.",
	"PLEASE... LET ME GO HOME."
]
@export_range(12.0,60.0,1.0) var dialogue_characters_per_second := 28.0
@export_range(0.5,3.0,0.1) var dialogue_read_pause := 1.2
var rules = RULES.new()
var phase := Phase.PLAYER_RAT
var cat_swings := 0
var cat_hits := 0
var dialogue_index := 0
var _dialogue_tween: Tween
var _dialogue_line := ""
var _dialogue_prefix_length := 4
var _dialogue_pitch := 0.86
var rat_beg_turns := 0
var _sequence: Tween
var _cat_material: ShaderMaterial
var _idle_clock := 0.0
var _death_body: Node2D
var _death_head: Sprite2D
var _claws: Line2D
@onready var world: Control = $World
@onready var enemy_anchor: Marker2D = $World/EnemyAnchor
@onready var adam: Node2D = $World/Adam
@onready var rat: AnimatedSprite2D = $World/Rat
@onready var cat: AnimatedSprite2D = $World/Cat
@onready var portal: Node2D = $World/Portal
@onready var hud: Control = $BattleUI/HUD
@onready var fade: ColorRect = $Transition/Black

func _ready() -> void:
	if not RunState.can_enter_final():
		set_process(false)
		set_process_unhandled_key_input(false)
		get_tree().call_deferred("change_scene_to_file","res://Scene/lobby.tscn")
		return
	resized.connect(_fit)
	GameAudio.music("snow")
	GameAudio.ambience("wind")
	_fit()
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float reveal = 0.0;
uniform float idle_time = 0.0;
uniform float idle_enabled = 1.0;
uniform float blink = 0.0;
uniform float hit_flash = 0.0;
uniform float dialogue_glow = 0.0;
uniform float floor_line = 4.6875;
varying float local_y;
void vertex(){
 float t = floor(idle_time*16.0)/16.0;
 float breath = sin(t*2.0)*0.0035*idle_enabled;
 VERTEX.y *= 1.0+breath;
 VERTEX.x += sin(VERTEX.y*0.025+t*1.4)*3.0*idle_enabled*smoothstep(-470.0,0.0,VERTEX.y);
 local_y = VERTEX.y;
}
void fragment(){
 COLOR.a *= reveal*(1.0-step(floor_line,local_y));
 vec2 p=UV*vec2(1774.0,887.0);
 vec2 eye1=vec2(234.0,181.0); vec2 eye2=vec2(288.0,188.0);
 float mask1=1.0-smoothstep(22.0,34.0,distance(p,eye1));
 float mask2=1.0-smoothstep(22.0,34.0,distance(p,eye2));
 float lid1=step(17.0*(1.0-blink),abs(p.y-eye1.y));
 float lid2=step(17.0*(1.0-blink),abs(p.y-eye2.y));
 COLOR.rgb=mix(COLOR.rgb,vec3(0.002,0.004,0.009),max(mask1*lid1,mask2*lid2)*blink*idle_enabled);
 COLOR.rgb=mix(COLOR.rgb,vec3(0.91,0.88,1.0),hit_flash);
 COLOR.rgb += vec3(0.17,0.14,0.02)*max(mask1,mask2)*dialogue_glow;
}"""
	_cat_material = ShaderMaterial.new()
	_cat_material.shader = shader
	cat.material = _cat_material
	var rat_shader := Shader.new()
	rat_shader.code = "shader_type canvas_item; uniform float floor_line = 12.5; varying float local_y; void vertex(){ local_y = VERTEX.y; } void fragment(){ COLOR.a *= 1.0-step(floor_line,local_y); }"
	var rat_material := ShaderMaterial.new()
	rat_material.shader = rat_shader
	rat.material = rat_material
	hud.action_requested.connect(_action)
	hud.choice_requested.connect(_choice)
	hud.return_requested.connect(return_to_lobby)
	reset_encounter()

func _process(delta: float) -> void:
	if rat.visible:
		(rat.material as ShaderMaterial).set_shader_parameter("floor_line",(enemy_anchor.position.y+3.0-rat.position.y)/rat.scale.y)
	_idle_clock += delta
	_cat_material.set_shader_parameter("idle_time",_idle_clock)
	_cat_material.set_shader_parameter("floor_line",(enemy_anchor.position.y+3.0-cat.position.y)/cat.scale.y)
	var blink_phase := fmod(_idle_clock,4.3)
	var blink := sin(clampf((blink_phase-3.92)/0.24,0.0,1.0)*PI)
	_cat_material.set_shader_parameter("blink",blink)
	_cat_material.set_shader_parameter("dialogue_glow",0.4+0.3*sin(_idle_clock*7.0) if phase==Phase.CAT_DIALOGUE else 0.0)
	if phase==Phase.RAT_WAIT:
		rat.rotation = sin(_idle_clock*19.0)*0.018
		rat.position.x = enemy_anchor.position.x+sin(_idle_clock*21.0)*1.2

func _fit() -> void:
	var factor := minf(size.x/1600.0,size.y/900.0)
	world.scale = Vector2.ONE * factor
	world.position = (size - Vector2(1600,900)*factor)*0.5


func _action(action: String) -> void:
	if action in ["skill","item"]:
		hud.open_choices(action,rules)
	else:
		player_action(action)

func _choice(kind: String, choice: String) -> void:
	player_action(kind,choice)

func _unhandled_key_input(event: InputEvent) -> void:
	if phase == Phase.FADING:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not hud.menu.visible:
		get_viewport().set_input_as_handled()

func _set_phase(next: Phase) -> void:
	if phase==Phase.RAT_WAIT:
		rat.rotation = 0
		rat.position = enemy_anchor.position
	phase = next
	if phase in [Phase.PLAYER_RAT,Phase.PLAYER_CAT]:
		rules.phase = "player"
	elif phase in [Phase.DEATH,Phase.DEFEAT,Phase.FADING]:
		rules.phase = "defeat"
	elif phase in [Phase.RAT_WAIT,Phase.CAT_DIALOGUE]:
		rules.phase = "dialogue"
	elif phase==Phase.CAT_ATTACK:
		rules.phase = "enemy"
	else:
		rules.phase = "resolving"
	_sync_hud()
	phase_changed.emit(phase)

func _sync_hud() -> void:
	hud.render(rules)

func reset_encounter() -> void:
	rules.configure(RunState.snapshot(),true)
	cat_swings = 0
	cat_hits = 0
	dialogue_index = 0
	rat_beg_turns = 0
	if is_instance_valid(_dialogue_tween):
		_dialogue_tween.kill()
	hud.log_text.visible_characters = -1
	_idle_clock = 0.0
	adam.home = $World/PlayerAnchor.position
	adam.reset_actor()
	rat.position = enemy_anchor.position
	rat.modulate = Color.WHITE
	rat.show()
	rat.play("idle")
	cat.position = enemy_anchor.position
	cat.scale = Vector2(0.34,0.34)
	cat.offset = Vector2(0,-390)
	cat.hide()
	cat.play("idle")
	_cat_material.set_shader_parameter("reveal",0.0)
	_cat_material.set_shader_parameter("idle_enabled",1.0)
	_cat_material.set_shader_parameter("hit_flash",0.0)
	portal.position = enemy_anchor.position
	portal.opening = 0.0
	portal.power = 0.0
	fade.hide()
	fade.color.a = 0.0
	_set_phase(Phase.PLAYER_RAT)
	hud.log_text.text = "A SMALL RAT BLOCKS THE PATH."
	hud.hint.text = "RAT / MAX 5 DAMAGE PER TURN"

func player_action(action: String, choice := "") -> void:
	if not rules.begin_action(action,choice):
		return
	hud.log_text.visible_characters = -1
	hud.menu.hide()
	_set_phase(Phase.PLAYER_ACTION)
	if action=="escape":
		if rules.roll_escape():
			GameAudio.sfx("escape_success")
			hud.log_text.text = "ESCAPED! ADAM RETURNS TO THE HIDEOUT."
			RunState.sync_battle(rules)
			await get_tree().create_timer(0.5).timeout
			return_to_lobby()
		else:
			GameAudio.sfx("escape_fail")
			hud.log_text.text = "ESCAPE FAILED! ADAM CANNOT GET AWAY."
			await get_tree().create_timer(0.7).timeout
			await _after_player_action(action)
		return
	if action in ["attack","skill"]:
		var skill: Dictionary = RULES.SKILLS.get(choice,{})
		var ultimate := action=="skill" and choice=="last_light"
		var power: int = rules.adam_ultimate_power() if ultimate else rules.player_damage(int(skill.get("damage",22)))
		var hits: int = int(skill.get("hits",1))
		hud.log_text.text = "ADAM USES " + (str(skill["name"]) if action=="skill" else "A PUNCH") + "."
		if action=="skill":
			GameAudio.sfx("skill")
		if ultimate:
			hud.log_text.text = "LAST LIGHT / ADAM GATHERS HIS REMAINING STRENGTH."
			_effect(adam.position+Vector2(0,-130),"ultimate_charge",Color("ffe4a1"))
			# These enemies wait during the charge. Their established dialogue
			# and the apparition's single scripted attack still occur in order.
			await get_tree().create_timer(0.8).timeout
		await adam.move_to_global(world.get_global_transform()*(enemy_anchor.position+Vector2(-175,12)),0.3)
		for hit in range(hits):
			adam.animate("skill" if action=="skill" else "attack")
			GameAudio.sfx("swing")
			await get_tree().create_timer(0.26).timeout
			var hit_power := power
			if rules.is_rat_encounter():
				hit_power = mini(power,ceili(float(rules.rat_damage_remaining())/(hits-hit)))
			var outcome: Dictionary = rules.hit("atom",hit_power,ultimate)
			GameAudio.sfx("hit_body")
			var is_cat: bool = rules.boss_phase=="shadow"
			if is_cat:
				cat_hits += 1
				# The final apparition is intentionally unbeatable.
				rules.atom_hp = maxi(1,rules.atom_hp)
				_cat_material.set_shader_parameter("hit_flash",0.8)
				var flash := create_tween()
				flash.tween_method(func(value: float): _cat_material.set_shader_parameter("hit_flash",value),0.8,0.0,0.25)
			_effect(cat.position+Vector2(-32,-135) if is_cat else rat.position+Vector2(0,-25),"ultimate" if ultimate else "skill" if action=="skill" else "hit",Color("e3d7ff") if is_cat else Color("ffdc9e"),"-%d" % outcome["damage"])
			_sync_hud()
			if rules.atom_hp<=0:
				RunState.sync_battle(rules)
				await spawn_cat()
				return
			await get_tree().create_timer(0.28).timeout
		await adam.go_home()
	elif action=="defend":
		adam.hold_guard()
		GameAudio.sfx("guard")
		_effect(adam.position+Vector2(0,-130),"guard",Color("9debf0"),"GUARD")
		hud.log_text.text = "ADAM GUARDS AND RECOVERS 12 SP."
		await get_tree().create_timer(0.6).timeout
	else:
		adam.use_item(choice)
		GameAudio.sfx("crunch" if choice=="apple" else "bandage" if choice=="bandage" else "sp_heal")
		await get_tree().create_timer(0.42).timeout
		var amount: int = rules.consume_item(choice)
		var spirit: bool = int(RULES.ITEMS[choice]["sp"])>0
		if not spirit:
			GameAudio.sfx("heal")
		_effect(adam.position+Vector2(0,-130),"heal",Color("9fc9ff") if spirit else Color("9ff2ad"),"+%d %s" % [amount,"SP" if spirit else "HP"])
		hud.log_text.text = "ADAM USES " + str(RULES.ITEMS[choice]["name"]) + "."
		_sync_hud()
		await get_tree().create_timer(0.6).timeout
		adam.idle()
		if rules.finish_item_action(choice):
			RunState.sync_battle(rules)
			_set_phase(Phase.PLAYER_CAT if rules.boss_phase=="shadow" else Phase.PLAYER_RAT)
			hud.log_text.text = "GOD APPLE / +%d HP. ADAM CAN ACT AGAIN!" % amount
			hud.hint.text = "YOUR TURN"
			return
	await _after_player_action(action)

func _after_player_action(action: String) -> void:
	rules.end_player_action()
	RunState.sync_battle(rules)
	if rules.boss_phase=="shadow":
		if action in ["attack","skill"]:
			await _cat_dialogue_turn()
		else:
			_return_cat_player_turn()
			hud.log_text.text = "??? WATCHES IN SILENCE."
	else:
		await _rat_turn()

func _rat_turn() -> void:
	_set_phase(Phase.RAT_WAIT)
	var line: String = RAT_LINES[rat_beg_turns%RAT_LINES.size()]
	rat_beg_turns += 1
	await _type_line("RAT",line,1.5,0.7)
	rules.finish_enemy_action()
	adam.idle()
	_set_phase(Phase.PLAYER_RAT)
	hud.hint.text = "YOUR TURN / MAX 5 DAMAGE TO THE RAT"
	RunState.sync_battle(rules)


func _return_cat_player_turn() -> void:
	rules.finish_enemy_action()
	adam.idle()
	_set_phase(Phase.PLAYER_CAT)
	hud.hint.text = "YOUR TURN"

func _cat_dialogue_turn() -> void:
	# Advance once per offensive action, including a skill with multiple hits.
	if dialogue_index >= CAT_LINES.size() or cat_swings > 0:
		return
	_dialogue_line = CAT_LINES[dialogue_index]
	dialogue_index += 1
	_set_phase(Phase.CAT_DIALOGUE)
	dialogue_started.emit(dialogue_index,_dialogue_line)
	await _type_line("???",_dialogue_line,0.86,dialogue_read_pause)
	dialogue_finished.emit(dialogue_index)
	if dialogue_index == CAT_LINES.size():
		await cat_turn()
	else:
		_return_cat_player_turn()

func _type_line(speaker: String, line: String, pitch: float, read_pause: float) -> void:
	_dialogue_line = line
	_dialogue_prefix_length = speaker.length()+1
	_dialogue_pitch = pitch
	hud.log_text.text = speaker+"\n"+line
	hud.log_text.visible_characters = _dialogue_prefix_length
	hud.hint.text = "..."
	_dialogue_tween = create_tween()
	for i in range(_dialogue_line.length()):
		_dialogue_tween.tween_callback(_reveal_dialogue_character.bind(i+1))
		var pause := 1.0/dialogue_characters_per_second
		if _dialogue_line[i] in [",",";",":"]:
			pause += 0.12
		elif _dialogue_line[i] in [".","!","?"]:
			pause += 0.22
		_dialogue_tween.tween_interval(pause)
	await _dialogue_tween.finished
	hud.log_text.visible_characters = -1
	await get_tree().create_timer(read_pause).timeout

func _reveal_dialogue_character(count: int) -> void:
	hud.log_text.visible_characters = _dialogue_prefix_length+count
	var character := _dialogue_line[count-1]
	if count%2 == 1 and character not in [" ",",",".","!","?",":",";"]:
		GameAudio.sfx("dialogue_tick",_dialogue_pitch+float((count+dialogue_index)%3)*0.06)

func _effect(point: Vector2, kind: String, tint: Color, caption := "") -> void:
	var effect := EFFECT.new()
	effect.kind = kind
	effect.tint = tint
	effect.caption = caption
	world.add_child(effect)
	effect.add_to_group("secret_effects")
	effect.position = point

func spawn_cat() -> void:
	_set_phase(Phase.COLLAPSING)
	GameAudio.stop_music(0.5)
	GameAudio.voice("rat_death_voice")
	hud.log_text.text = "THE RAT FALLS SILENT."
	rat.stop()
	rat.play("collapse")
	await rat.animation_finished
	adam.go_home()
	await get_tree().create_timer(5.0).timeout
	_set_phase(Phase.SINKING)
	GameAudio.sfx("portal")
	hud.log_text.text = "A BLACK HOLE OPENS."
	_sequence = create_tween().set_parallel(true)
	_sequence.tween_property(portal,"opening",1.0,0.5)
	_sequence.tween_property(rat,"position:y",enemy_anchor.position.y+37.0,0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_sequence.tween_property(rat,"modulate:a",0.0,0.2).set_delay(0.65)
	await _sequence.finished
	rat.hide()
	_set_phase(Phase.PORTAL)
	hud.log_text.text = "SMOKE RISES FROM BELOW."
	_sequence = create_tween()
	_sequence.tween_property(portal,"power",1.0,0.8).set_trans(Tween.TRANS_SINE)
	await _sequence.finished
	await get_tree().create_timer(0.35).timeout
	rules.awaken_shadow()
	_set_phase(Phase.EMERGING)
	GameAudio.music("shadow",1.8)
	GameAudio.voice("cat_spawn_voice")
	hud.log_text.text = "THE SHADOW WAKES."
	cat.show()
	# Ears rise first through the floor mask; smoke hides the portal edge.
	cat.position.y = enemy_anchor.position.y+826.0*cat.scale.y
	cat.play("idle")
	_sequence = create_tween().set_parallel(true)
	_sequence.tween_method(func(value: float): _cat_material.set_shader_parameter("reveal",value),0.0,1.0,1.8).set_trans(Tween.TRANS_SINE)
	_sequence.tween_property(cat,"position:y",enemy_anchor.position.y,1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _sequence.finished
	await get_tree().create_timer(0.45).timeout
	hud.log_text.text = "YOUR TURN"
	hud.hint.text = "??? IS WATCHING."
	_set_phase(Phase.PLAYER_CAT)

func cat_turn() -> void:
	if cat_swings > 0:
		return
	cat_swings += 1
	_set_phase(Phase.CAT_ATTACK)
	hud.hint.text = "??? RAISES ITS PAW."
	adam.idle()
	await get_tree().create_timer(0.65).timeout
	# Paw frames play in place. The enemy root remains on its platform.
	cat.scale = Vector2(0.52,0.52)
	cat.offset = Vector2(0,-260)
	_cat_material.set_shader_parameter("idle_enabled",0.0)
	cat.stop()
	cat.play("attack")
	GameAudio.sfx("swing",0.65)
	_finish_single_swing()
	# Apply the hit when the one strike frame appears, including at low FPS.
	await cat.frame_changed
	await special_death()
	hud.log_text.text = "ADAM DROPS TO HIS KNEES."
	hud.hint.text = "..."
	_set_phase(Phase.DEFEAT)
	await _fade_to_credits()

func _finish_single_swing() -> void:
	await cat.animation_finished
	cat.scale = Vector2(0.34,0.34)
	cat.offset = Vector2(0,-390)
	cat.play("idle")
	_cat_material.set_shader_parameter("idle_enabled",1.0)

func special_death() -> void:
	GameAudio.sfx("shadow_hit")
	rules.adam_hp = 0
	RunState.sync_battle(rules)
	_set_phase(Phase.DEATH)
	hud.log_text.text = "A SINGLE SWEEP."
	# Native atlas regions preserve Adam's art with a clean, bloodless pixel edge.
	var atlas := load("res://Battle/Art/adam_sprites.png") as Texture2D
	var actor_scale := adam.scale
	var head_texture := AtlasTexture.new()
	head_texture.atlas = atlas
	head_texture.region = Rect2(74,20,78,69)
	head_texture.filter_clip = true
	var body_texture := AtlasTexture.new()
	body_texture.atlas = atlas
	body_texture.region = Rect2(74,89,78,128)
	body_texture.filter_clip = true
	var kneeling_texture := AtlasTexture.new()
	kneeling_texture.atlas = atlas
	kneeling_texture.region = Rect2(253,1458,145,84)
	kneeling_texture.filter_clip = true
	_death_body = Node2D.new()
	world.add_child(_death_body)
	_death_body.position = adam.position
	var body := Sprite2D.new()
	body.texture = body_texture
	body.centered = false
	body.position = Vector2(-36.875,-128)*actor_scale
	body.scale = actor_scale
	_death_body.add_child(body)
	_death_head = Sprite2D.new()
	_death_head.texture = head_texture
	_death_head.scale = actor_scale
	_death_head.position = adam.position + Vector2(2.125,-162.5)*actor_scale
	world.add_child(_death_head)
	adam.hide()
	_claws = Line2D.new()
	world.add_child(_claws)
	_claws.width = 5
	_claws.default_color = Color(0.7,0.82,1.0,0.9)
	var cut_point := adam.position+Vector2(0,-129)*actor_scale
	_claws.points = PackedVector2Array([cut_point+Vector2(125,-35),cut_point+Vector2(55,-5),cut_point+Vector2(-40,30)])
	_sequence = create_tween().set_parallel(true)
	_sequence.tween_property(_claws,"modulate:a",0.0,0.28)
	_sequence.tween_property(_death_head,"position",adam.position+Vector2(-120,-56),0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_sequence.tween_property(_death_head,"rotation",-PI/2,0.8)
	# Feet stay planted as Adam drops onto his knees. His body never tips over.
	_sequence.tween_property(_death_body,"scale:y",0.72,0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_sequence.tween_callback(func():
		body.texture = kneeling_texture
		body.position = Vector2(-79.625,-84)*actor_scale
		_death_body.scale = Vector2.ONE
	).set_delay(0.28)
	await _sequence.finished
	GameAudio.sfx("hit_body",0.65)
	await get_tree().create_timer(0.8).timeout

func _fade_to_credits() -> void:
	_set_phase(Phase.FADING)
	GameAudio.stop_music(1.5)
	hud.actions["escape"].disabled = true
	get_viewport().gui_release_focus()
	fade.show()
	_sequence = create_tween()
	_sequence.tween_property(fade,"color:a",1.0,1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _sequence.finished
	SceneFlow.change_scene("res://Battle/end_credits.tscn")

func return_to_lobby() -> void:
	if phase == Phase.FADING:
		return
	RunState.sync_battle(rules)
	SceneFlow.change_scene("res://Scene/lobby.tscn")
