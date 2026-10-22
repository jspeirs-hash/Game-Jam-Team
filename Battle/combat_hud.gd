extends Control
signal action_requested(action: String)
signal choice_requested(kind: String, choice: String)
signal continue_requested
signal return_requested
const UI := preload("res://scripts/ui_factory.gd")
var design: Control
var actions := {}
var choice_buttons := {}
var enemy_name: Label
var enemy_hp: ProgressBar
var enemy_text: Label
var player_hp: ProgressBar
var player_sp: ProgressBar
var player_text: Label
var sp_text: Label
var sector: Label
var log_text: Label
var hint: Label
var menu: Control
var menu_window: Panel
var menu_title: Label
var menu_list: Control
var menu_cancel: Button
var result: Control
var result_title: Label
var result_message: Label
var next_button: Button
var return_button: Button
var turn_label: Label
var reactor: ProgressBar
var reactor_text: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	design = Control.new()
	design.name = "Design"
	design.size = Vector2(1600,900)
	design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(design)
	resized.connect(_fit)
	_fit()
	var enemy := UI.panel(design,"EnemyStatus",Rect2(56,40,470,140))
	enemy_name = UI.label(enemy,"Name",Rect2(22,10,426,38),"ENEMY",22)
	enemy_hp = UI.bar(enemy,"Health",Rect2(22,56,426,16),Color("39c3c7"))
	enemy_text = UI.label(enemy,"HP",Rect2(22,85,426,30),"",18,Color("63dce0"))
	enemy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reactor = UI.bar(enemy,"Reactor",Rect2(22,120,426,8),Color("ec765b"))
	reactor_text = UI.label(enemy,"ReactorText",Rect2(22,134,426,26),"",14,Color("ff9b80"))
	var turn_panel := UI.panel(design,"TurnIndicator",Rect2(610,76,380,56))
	turn_label = UI.label(turn_panel,"Text",Rect2(8,4,364,48),"YOUR TURN",19,UI.GOLD)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var player := UI.panel(design,"PlayerStatus",Rect2(1074,420,470,190))
	UI.label(player,"Name",Rect2(22,10,426,36),"ADAM / LV 5",22)
	player_hp = UI.bar(player,"Health",Rect2(22,55,426,16),Color("c5a05c"))
	player_text = UI.label(player,"HP",Rect2(22,78,426,30),"",18,UI.GOLD)
	player_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_sp = UI.bar(player,"Spirit",Rect2(22,124,426,12),Color("4b8fd4"))
	sp_text = UI.label(player,"SP",Rect2(22,144,426,28),"",16,Color("8ebcea"))
	sp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var commands := UI.panel(design,"Commands",Rect2(28,650,1544,222))
	sector = UI.label(commands,"Sector",Rect2(30,16,810,30),"",14,UI.MUTED)
	log_text = UI.label(commands,"Log",Rect2(30,55,800,98),"CHOOSE AN ACTION.",22,UI.TEXT,true)
	hint = UI.label(commands,"Hint",Rect2(30,164,800,38),"ATTACK +4 SP / DEFEND +12 SP",14,UI.MUTED)
	for index in range(5):
		var id: String = ["attack","skill","defend","item","escape"][index]
		var b := UI.button(commands,id,Rect2(900+(index%3)*204,18+(index/3)*96,194,86),id.to_upper(),20)
		if id=="escape":
			b.text = "ESCAPE\n25% CHANCE"
			b.tooltip_text = "25% chance to escape. A failed attempt uses your turn."
		b.pressed.connect(_request_action.bind(id))
		actions[id] = b
	menu = _overlay("ChoiceOverlay")
	menu_window = UI.panel(menu,"Window",Rect2(350,205,900,470))
	menu_title = UI.label(menu_window,"Title",Rect2(24,18,852,42),"CHOOSE",26)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_list = Control.new()
	menu_list.position = Vector2(26,90)
	menu_list.size = Vector2(848,250)
	menu_window.add_child(menu_list)
	menu_cancel = UI.button(menu_window,"Cancel",Rect2(295,380,310,60),"CANCEL")
	menu_cancel.pressed.connect(close_choices)
	result = _overlay("ResultOverlay")
	var window := UI.panel(result,"Window",Rect2(350,220,900,440))
	result_title = UI.label(window,"Title",Rect2(28,22,844,50),"VICTORY",30,UI.GOLD)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_message = UI.label(window,"Message",Rect2(40,100,820,170),"",21,UI.TEXT,true)
	result_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_button = UI.button(window,"Next",Rect2(35,320,405,76),"REST +30% HP / CONTINUE",16)
	return_button = UI.button(window,"Return",Rect2(460,320,405,76),"RETURN TO HIDEOUT",17)
	next_button.pressed.connect(func(): continue_requested.emit())
	return_button.pressed.connect(func(): return_requested.emit())

func _fit() -> void:
	var zoom := minf(size.x/1600.0,size.y/900.0)
	design.scale = Vector2.ONE*zoom
	design.position = (size-Vector2(1600,900)*zoom)*0.5

func _overlay(id: String) -> Control:
	var layer := Control.new()
	layer.name = id
	layer.size = Vector2(1600,900)
	layer.z_index = 30
	design.add_child(layer)
	var shade := ColorRect.new()
	shade.size = Vector2(1600,900)
	shade.color = Color(0.005,0.01,0.02,0.88)
	layer.add_child(shade)
	layer.hide()
	return layer

func _request_action(id: String) -> void:
	action_requested.emit(id)

func render(rules: RefCounted) -> void:
	var info: Dictionary = rules.encounter()
	enemy_name.text = "%s / LV %s" % [info["name"],str(info["level"])]
	enemy_hp.max_value = rules.atom_max_hp
	enemy_hp.value = rules.atom_hp
	enemy_text.text = "HP %d / %d" % [rules.atom_hp,rules.atom_max_hp]
	player_hp.max_value = rules.adam_max_hp
	player_hp.value = rules.adam_hp
	player_sp.max_value = rules.adam_max_sp
	player_sp.value = rules.adam_sp
	player_text.text = "HP %d / %d" % [rules.adam_hp,rules.adam_max_hp]
	sp_text.text = "SP %d / %d" % [rules.adam_sp,rules.adam_max_sp]
	if rules.adam_sp==rules.adam_max_sp: sp_text.text += " / LAST LIGHT READY"
	var is_smasher: bool = not rules.is_final and rules.encounter_index==2
	reactor.visible = is_smasher
	reactor_text.visible = is_smasher
	(enemy_name.get_parent() as Panel).size.y = 178 if is_smasher else 140
	if is_smasher:
		reactor.max_value = rules.SMASHER_REACTOR_MAX
		reactor.value = rules.smasher_reactor
		reactor_text.text = "EXTINCTION PROTOCOL / CHARGING" if rules.smasher_charging else "REACTOR %d / %d" % [rules.smasher_reactor,rules.SMASHER_REACTOR_MAX]
	sector.text = "%s / %s / DAMAGE %.1fX / DURABILITY %.1fX" % [rules.difficulty.to_upper(),"ENCOUNTER" if rules.is_final else "ROBOT %d / 3" % (rules.encounter_index+1),rules.damage_multiplier,rules.durability_multiplier]
	var state: String = {"player":"YOUR TURN","enemy":"ENEMY TURN","resolving":"ADAM'S ACTION","charging":"LAST LIGHT / CHARGING","stunned":"ADAM / STUNNED","dialogue":"LISTENING","escaped":"ESCAPED","victory":"VICTORY","defeat":"DEFEAT"}.get(rules.phase,"PLEASE WAIT")
	turn_label.text = "%s / %d" % [state,rules.turn]
	turn_label.add_theme_color_override("font_color",UI.GOLD if rules.can_act() else Color("7bd4e0"))
	for id in actions:
		actions[id].disabled = not rules.can_act() or (id=="escape" and rules.is_final)
		actions[id].tooltip_text = "WAIT FOR THE CURRENT ACTION OR DIALOGUE TO FINISH." if not rules.can_act() else {"attack":"DEAL DAMAGE AND RESTORE 4 SP.","skill":"SKILLS COST SP. OPEN TO SEE COOLDOWNS AND REQUIREMENTS.","defend":"REDUCE THE NEXT HIT BY 65% AND RESTORE 12 SP.","item":"GOD APPLE HEALS 30 HP AND LETS ADAM ACT AGAIN. PER FIGHT: APPLE 2 / BANDAGE 3 / SP POTION 3.","escape":"25% CHANCE TO ESCAPE. FAILURE USES YOUR TURN."}[id]
		if id=="escape":
			actions[id].text = "ESCAPE\nUNAVAILABLE" if rules.is_final else "ESCAPE\n25% CHANCE"
			if rules.is_final: actions[id].tooltip_text = "ESCAPE IS NOT AVAILABLE IN THIS ENCOUNTER."

func open_choices(kind: String, rules: RefCounted) -> void:
	if not rules.can_act():
		return
	for child in menu_list.get_children():
		menu_list.remove_child(child)
		child.queue_free()
	choice_buttons.clear()
	menu_title.text = "ADAM / " + ("SKILLS" if kind=="skill" else "ITEMS")
	var ids: Array = rules.SKILLS.keys() if kind=="skill" else rules.ITEMS.keys()
	var width := (848.0-(ids.size()-1)*14.0)/ids.size()
	for i in range(ids.size()):
		var id: String = ids[i]
		var text := ""
		var disabled := false
		if kind=="skill":
			var entry: Dictionary = rules.SKILLS[id]
			var cooldown: int = rules.cooldowns[id]
			if id=="last_light":
				text = "LAST LIGHT\n\n%s\nALL %d SP\nTAKE 1 HIT FIRST\nTHEN ACT AGAIN\n\n%s" % ["MAX 5 DAMAGE / TURN" if rules.is_rat_encounter() else "40% MAX HP",rules.adam_max_sp,"READY" if rules.adam_sp==rules.adam_max_sp else "NEED FULL SP"]
				disabled = rules.adam_sp!=rules.adam_max_sp
			else:
				var damage_text: String = "MAX %d DAMAGE / TURN" % rules.RAT_DAMAGE_PER_TURN if rules.is_rat_encounter() else "%d DAMAGE" % (rules.player_damage(entry["damage"])*int(entry["hits"]))
				text = "%s\n\n%s / %d SP\n\n%s" % [entry["name"],damage_text,entry["sp"],"CD %d TURNS" % cooldown if cooldown>0 else "NEED SP" if rules.adam_sp < int(entry["sp"]) else "READY"]
				disabled = cooldown>0 or rules.adam_sp < int(entry["sp"])
		else:
			var entry: Dictionary = rules.ITEMS[id]
			var is_sp := int(entry["sp"])>0
			var reason: String = rules.item_unavailable_reason(id)
			text = "%s\n\n+%d %s%s\nOWNED %d\nUSES LEFT %d / %d\n\n%s" % [entry["name"],entry["sp"] if is_sp else entry["heal"],"SP" if is_sp else "HP"," / ACT AGAIN" if entry.get("extra_turn",false) else "",rules.inventory[id],rules.item_uses_left(id),entry.limit,"USE ITEM" if reason.is_empty() else reason]
			disabled = not reason.is_empty()
		var b := UI.button(menu_list,id,Rect2(i*(width+14),0,width,250),text,17)
		b.disabled = disabled
		if kind=="skill":
			if id=="last_light":
				b.tooltip_text = "NEEDS FULL SP (%d/%d)." % [rules.adam_sp,rules.adam_max_sp] if disabled else "USES ALL SP. TAKE ONE FREE ENEMY ATTACK WHILE CHARGING; IF ADAM SURVIVES, DEAL 40% MAX HP THROUGH ARMOR AND ACT AGAIN. DOES NOT STUN THE ENEMY."
			else:
				b.tooltip_text = "COOLDOWN: %d MORE TURNS." % rules.cooldowns[id] if rules.cooldowns[id]>0 else "NEEDS %d MORE SP." % (int(rules.SKILLS[id].sp)-rules.adam_sp) if rules.adam_sp<int(rules.SKILLS[id].sp) else "READY. USES ONE TURN."
		else:
			b.tooltip_text = rules.item_unavailable_reason(id)+"." if disabled else RunState.ITEM_DESCRIPTIONS[id]
		b.pressed.connect(_choice.bind(kind,id))
		choice_buttons[id] = b
	menu.show()
	menu_cancel.grab_focus()

func _choice(kind: String, id: String) -> void:
	choice_requested.emit(kind,id)

func close_choices() -> void:
	menu.hide()
	if not actions["attack"].disabled:
		actions["attack"].grab_focus()

func show_result(title: String, message: String, can_continue: bool, next_text := "REST +30% HP / CONTINUE") -> void:
	result_title.text = title
	result_message.text = message
	next_button.visible = can_continue
	next_button.text = next_text
	return_button.position.x = 460 if can_continue else 250
	result.show()
	if can_continue:
		next_button.grab_focus()
	else:
		return_button.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if menu.visible and event.is_action_pressed("ui_cancel"):
		close_choices()
		get_viewport().set_input_as_handled()
