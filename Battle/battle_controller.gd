extends Control
signal animation_event(fighter: String, action: String)
signal impact_event(target: String, damage: int, blocked: bool)
signal battle_finished(outcome: String)
const RULES = preload("res://Battle/battle_rules.gd")
const EFFECT = preload("res://Battle/battle_effect.gd")
@export_range(0.25,10.0) var playback_speed := 1.0
@onready var adam: Node2D = $Combatants/PlayerAnchor/Adam
@onready var atom: Node2D = $Combatants/EnemyAnchor.get_child(0)
@onready var hud: Control = $BattleUI/HUD
var rules = RULES.new()
var _rewarded := false
var _ultimate_warning: Node2D

func _ready() -> void:
	GameAudio.music("battle")
	GameAudio.ambience()
	rules.configure(RunState.snapshot())
	_swap_enemy()
	hud.action_requested.connect(_action)
	hud.choice_requested.connect(_choice)
	hud.continue_requested.connect(next_encounter)
	hud.return_requested.connect(return_to_lobby)
	_sync_hud()
	_log("ADAM FACES " + rules.encounter()["name"] + ". CHOOSE AN ACTION.")
	_threat()

func _action(action: String) -> void:
	match action:
		"attack": player_attack()
		"skill","item": hud.open_choices(action,rules)
		"defend": player_defend()
		"escape": player_escape()

func _choice(kind: String, choice: String) -> void:
	if kind == "skill":
		player_skill(choice)
	else:
		player_item(choice)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds/playback_speed).timeout

func _animate(actor: Node2D, action: String) -> void:
	actor.sprite.speed_scale = playback_speed
	actor.animate(action)
	animation_event.emit(actor.fighter_name,action)

func _sync_hud() -> void:
	hud.render(rules)

func _log(text: String) -> void:
	hud.log_text.text = text

func _threat() -> void:
	var next := rules.enemy_action()
	if next in ["charge","ultimate"]:
		hud.hint.text = "NEXT / "+rules.enemy_intent_text()+(" / DEFEND TO AVOID STUN" if next=="ultimate" else "")
		return
	hud.hint.text = "NEXT / " + rules.enemy_intent_text() + (" / GUARDS" if next=="defend" else " / %d DAMAGE" % ceili(rules.enemy_power(next=="skill")/rules.durability_multiplier))

func _effect(actor: Node2D, kind: String, color: Color, caption := "") -> Node2D:
	var effect := Node2D.new()
	effect.set_script(EFFECT)
	effect.kind = kind
	effect.tint = color
	effect.caption = caption
	effect.lifetime = 1.0 if kind=="heal" else 0.65
	effect.direction = -1.0 if actor.facing_left else 1.0
	$Effects.add_child(effect)
	effect.global_position = actor.global_position+Vector2(0,-actor.body_height)
	return effect

func player_attack() -> void:
	if not rules.begin_action("attack"):
		return
	hud.menu.hide()
	_sync_hud()
	_log("ADAM THROWS A PUNCH.")
	await _strike(adam,atom,rules.player_damage(22),"attack",1)
	await _after_player()

func player_skill(skill: String) -> void:
	if not rules.begin_action("skill",skill):
		return
	hud.menu.hide()
	_sync_hud()
	if skill=="last_light":
		await _last_light()
		return
	var entry: Dictionary = RULES.SKILLS[skill]
	_log("ADAM USES " + entry["name"] + ".")
	GameAudio.sfx("skill")
	_effect(adam,"charge",Color("ffdb91"))
	await _wait(0.22)
	await _strike(adam,atom,rules.player_damage(entry["damage"]),"skill",entry["hits"])
	await _after_player()

func _last_light() -> void:
	_log("LAST LIGHT / ADAM IS VULNERABLE WHILE CHARGING.")
	hud.hint.text = "THE ENEMY GETS ONE FREE ATTACK BEFORE LAST LIGHT."
	GameAudio.sfx("skill",0.7)
	adam.hold_guard()
	var charge := _effect(adam,"ultimate_charge",Color("ffe4a1"))
	charge.lifetime = 1.3/playback_speed
	await _wait(0.65)
	# A single free basic attack represents the charging turn. It neither stuns
	# the enemy nor consumes or cancels a queued Smasher ultimate.
	await _strike(atom,adam,rules.enemy_power(false),"attack",1)
	if rules.adam_hp<=0:
		rules.finish_adam_ultimate()
		RunState.sync_battle(rules)
		_sync_hud()
		_finish_defeat()
		return
	_log("ADAM UNLEASHES LAST LIGHT!")
	GameAudio.sfx("skill")
	await _strike(adam,atom,rules.adam_ultimate_power(),"ultimate",1)
	rules.finish_adam_ultimate()
	RunState.sync_battle(rules)
	_sync_hud()
	if rules.phase=="victory":
		_finish_victory()
	else:
		adam.idle()
		_log("LAST LIGHT / YOUR TURN. CHOOSE ANOTHER ACTION.")
		_threat()

func player_defend() -> void:
	if not rules.begin_action("defend"):
		return
	hud.menu.hide()
	_sync_hud()
	_log("ADAM GUARDS AND RECOVERS 12 SP.")
	adam.hold_guard()
	GameAudio.sfx("guard")
	_effect(adam,"guard",Color("ffe0a2"),"GUARD")
	await _wait(0.6)
	await _after_player()

func player_item(item: String) -> void:
	if not rules.begin_action("item",item):
		return
	hud.menu.hide()
	_sync_hud()
	_log("ADAM USES " + RULES.ITEMS[item]["name"] + ".")
	adam.sprite.speed_scale = playback_speed
	adam.use_item(item)
	animation_event.emit(adam.fighter_name,"item_"+item)
	GameAudio.sfx("crunch" if item=="apple" else "bandage" if item=="bandage" else "sp_heal")
	await _wait(0.42)
	var amount: int = rules.consume_item(item)
	_sync_hud()
	var spirit: bool = int(RULES.ITEMS[item]["sp"])>0
	if not spirit:
		GameAudio.sfx("heal")
	_effect(adam,"heal",Color("9fc9ff") if spirit else Color("9ff2ad"),"+%d %s" % [amount,"SP" if spirit else "HP"])
	await _wait(0.6)
	adam.idle()
	if rules.finish_item_action(item):
		RunState.sync_battle(rules)
		_sync_hud()
		_log("GOD APPLE / +%d HP. ADAM CAN ACT AGAIN!" % amount)
		_threat()
		return
	await _after_player()

func _strike(attacker: Node2D, target: Node2D, power: int, animation: String, hits: int) -> void:
	if attacker == atom and bool(rules.encounter()["ranged"]):
		await _fire_cannon(power,animation)
		return
	var offset := Vector2(175,-4) if attacker.facing_left else Vector2(-175,12)
	await attacker.move_to_global(target.global_position+offset,0.3/playback_speed)
	for hit in range(hits):
		if rules.adam_hp<=0 or rules.atom_hp<=0:
			break
		_animate(attacker,"skill" if animation=="ultimate" else animation)
		GameAudio.sfx("swing",0.8 if attacker==atom else 1.0)
		await _wait(0.26)
		_resolve_hit(attacker,target,power,animation)
		await _wait(0.28)
	await attacker.go_home()

func _resolve_hit(attacker: Node2D, target: Node2D, power: int, animation: String) -> Dictionary:
	var outcome: Dictionary = rules.hit("atom" if target==atom else "adam",power,animation=="ultimate" and attacker==adam)
	_present_hit(attacker,target,outcome,animation)
	return outcome

func _present_hit(attacker: Node2D, target: Node2D, outcome: Dictionary, animation: String) -> void:
	GameAudio.sfx("guard" if outcome["blocked"] else "hit_metal" if target==atom else "hit_body")
	_sync_hud()
	impact_event.emit(target.fighter_name,outcome["damage"],outcome["blocked"])
	var color := Color(rules.encounter()["color"]) if attacker==atom else Color("ffda8a")
	_effect(target,"guard" if outcome["blocked"] else "ultimate" if animation=="ultimate" else "skill" if animation=="skill" else "hit",color,("BLOCK " if outcome["blocked"] else "-")+str(outcome["damage"]))
	target.react_hit(outcome["blocked"])
	if (target==atom and rules.atom_hp<=0) or (target==adam and rules.adam_hp<=0):
		target.fall()
		if target==atom:
			GameAudio.sfx("robot_down")

func _fire_cannon(power: int, animation: String) -> Dictionary:
	_animate(atom,"skill" if animation=="ultimate" else animation)
	await _wait(0.26)
	GameAudio.sfx("cannon")
	var beam := Node2D.new()
	beam.set_script(EFFECT)
	beam.kind = "ultimate_beam" if animation=="ultimate" else "beam"
	beam.tint = Color(rules.encounter()["color"])
	beam.lifetime = (0.5 if animation=="ultimate" else 0.2)/playback_speed
	$Effects.add_child(beam)
	beam.global_position = atom.global_position+Vector2(-120,-185)
	beam.beam_end = adam.global_position+Vector2(0,-130)-beam.global_position
	await _wait(0.18)
	var outcome: Dictionary
	if animation=="ultimate":
		outcome = rules.resolve_smasher_ultimate()
		_present_hit(atom,adam,outcome,animation)
	else:
		outcome = _resolve_hit(atom,adam,power,animation)
	await _wait(0.32)
	atom.idle()
	return outcome

func _after_player() -> void:
	rules.end_player_action()
	_sync_hud()
	RunState.sync_battle(rules)
	if rules.phase=="victory":
		await _wait(0.45)
		_finish_victory()
		return
	await _wait(0.32)
	await _enemy_turn()

func _enemy_turn() -> void:
	var choice: String = rules.enemy_action()
	atom.show_intent(choice,Color(rules.encounter().color),0.45/playback_speed)
	GameAudio.sfx(["scout_signal","atom_signal","smasher_signal"][rules.encounter_index])
	_log(rules.encounter().name+" / "+rules.enemy_intent_text())
	await _wait(0.45)
	if choice=="charge":
		rules.atom_guard = false
		rules.charge_smasher_ultimate()
		_ultimate_warning = preload("res://Battle/ultimate_warning.gd").new()
		atom.add_child(_ultimate_warning)
		_ultimate_warning.position = Vector2(0,-atom.body_height-5)
		_log("ADAM SMASHER CHARGES EXTINCTION PROTOCOL.")
		GameAudio.sfx("skill",0.65)
		_effect(atom,"ultimate_charge",Color("ff866d"))
		await _wait(0.9)
	elif choice=="ultimate":
		_log("ADAM SMASHER / EXTINCTION PROTOCOL!")
		var outcome: Dictionary = await _fire_cannon(rules.smasher_ultimate_power(),"ultimate")
		if is_instance_valid(_ultimate_warning): _ultimate_warning.queue_free()
		if outcome.get("stunned",false):
			rules.phase = "stunned"
			_sync_hud()
			_log("ADAM IS STUNNED FOR ONE TURN!")
			hud.hint.text = "ADAM SMASHER GETS ONE FOLLOW-UP ATTACK."
			_effect(adam,"stun",Color("ffe4a1"),"STUNNED")
			await _wait(0.8)
			if rules.consume_adam_stun():
				await _strike(atom,adam,rules.enemy_power(false),"attack",1)
		elif outcome.blocked:
			_log("ADAM BLOCKS EXTINCTION PROTOCOL. STUN PREVENTED!")
			await _wait(0.6)
	elif choice=="defend":
		rules.atom_guard = true
		_log(rules.encounter()["guard_text"])
		atom.hold_guard()
		GameAudio.sfx("guard",0.8)
		_effect(atom,"guard",Color("7de4f1"),"STEEL GUARD")
		await _wait(0.7)
	else:
		rules.atom_guard = false
		_log(rules.encounter()["skill_text"] if choice=="skill" else rules.encounter()["attack_text"])
		await _strike(atom,adam,rules.enemy_power(choice=="skill"),choice,1)
	rules.finish_enemy_action()
	RunState.sync_battle(rules)
	_sync_hud()
	if rules.phase=="defeat":
		_finish_defeat()
		return
	if not rules.atom_guard:
		atom.idle()
	adam.idle()
	_log("TURN %d / ADAM'S MOVE." % rules.turn)
	_threat()

func _finish_defeat() -> void:
	if is_instance_valid(_ultimate_warning): _ultimate_warning.queue_free()
	GameAudio.stop_music()
	GameAudio.sfx("defeat")
	hud.show_result("DEFEAT","ADAM HAS FALLEN.\nRETURN TO THE HIDEOUT AND REST IN THE HOUSE.",false)
	battle_finished.emit("DEFEAT")

func _finish_victory() -> void:
	if _rewarded:
		return
	if is_instance_valid(_ultimate_warning): _ultimate_warning.queue_free()
	_rewarded = true
	GameAudio.stop_music()
	GameAudio.sfx("victory")
	var reward: int = RunState.award_victory(rules.encounter_index)
	var can_continue: bool = RunState.can_continue_run()
	var message := "%s DEFEATED / +%d CREDITS\n\n" % [rules.encounter()["name"],reward]
	message += "RETURN TO PREPARE, OR REST +30% MAX HP AND CONTINUE." if can_continue else "RUN COMPLETE. RETURN TO THE HIDEOUT."
	hud.show_result("VICTORY",message,can_continue)
	battle_finished.emit("VICTORY")

func next_encounter() -> void:
	if rules.phase != "victory" or not _rewarded or not RunState.can_continue_run():
		return
	hud.next_button.disabled = true
	RunState.field_rest()
	SceneFlow.change_scene(RunState.next_scene())

func player_escape() -> void:
	if not rules.begin_action("escape"):
		return
	hud.menu.hide()
	_sync_hud()
	if rules.roll_escape():
		GameAudio.sfx("escape_success")
		_log("ESCAPED! ADAM RETURNS TO THE HIDEOUT.")
		RunState.sync_battle(rules)
		await _wait(0.5)
		return_to_lobby()
	else:
		GameAudio.sfx("escape_fail")
		_log("ESCAPE FAILED! ADAM CANNOT GET AWAY.")
		hud.hint.text = "THE ENEMY'S TURN."
		await _wait(0.7)
		await _after_player()

func _swap_enemy() -> void:
	var entry: Dictionary = rules.encounter()
	if atom.fighter_name != entry["name"]:
		$Combatants/EnemyAnchor.remove_child(atom)
		atom.queue_free()
		atom = load(entry["scene"]).instantiate()
		$Combatants/EnemyAnchor.add_child(atom)
	atom.scale = Vector2.ONE*float(entry["scale"])
	atom.body_height = entry["body_height"]
	atom.reset_actor()

func return_to_lobby() -> void:
	RunState.sync_battle(rules)
	SceneFlow.change_scene("res://Scene/lobby.tscn")
