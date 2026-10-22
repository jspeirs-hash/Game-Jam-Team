extends Control
const UI := preload("res://scripts/ui_factory.gd")
@onready var world: Node2D = $World
@onready var screen: Control = $Interface/Screen
var modal: Control
var window: Panel
var message: Label
var hp: ProgressBar
var sp: ProgressBar
var profile_text: Label
var summary: Label
var modal_kind := ""
var controls := {}
var walker: CharacterBody2D
var message_hold := 0.0
const INTERACTIONS := {"gate":Vector2(805,392),"house":Vector2(325,637),"tree":Vector2(800,807),"shop":Vector2(1290,645)}

func _ready() -> void:
	GameAudio.music("hideout")
	GameAudio.ambience("hideout_air")
	resized.connect(_fit)
	_fit()
	var title := UI.panel(screen,"Title",Rect2(30,22,530,102))
	UI.label(title,"Name",Rect2(24,12,490,38),"THE LAST HIDEOUT",28,UI.GOLD)
	UI.label(title,"Subtitle",Rect2(24,58,490,26),"HUMANITY TAKES ROOT HERE",14,UI.MUTED)
	var profile := UI.panel(screen,"Profile",Rect2(1090,22,480,124))
	profile_text = UI.label(profile,"Stats",Rect2(18,8,446,28),"",14,UI.GOLD)
	hp = UI.bar(profile,"HP",Rect2(18,47,446,12),Color("c69c61"))
	sp = UI.bar(profile,"SP",Rect2(18,76,446,10),Color("4c93cf"))
	summary = UI.label(profile,"Values",Rect2(18,93,446,22),"",13,UI.MUTED)
	var footer := UI.panel(screen,"Footer",Rect2(30,836,1540,44))
	message = UI.label(footer,"Message",Rect2(20,4,1500,36),"",17,UI.TEXT,true)
	for entry in [["gate",Rect2(610,130,390,255),"THE GATE",Vector2(685,345)], ["house",Rect2(125,250,400,360),"REST HOUSE",Vector2(200,605)], ["tree",Rect2(590,485,420,320),"THE GREAT TREE",Vector2(685,790)], ["shop",Rect2(1100,310,390,300),"SUPPLY SHOP",Vector2(1181,610)]]:
		var id: String = entry[0]
		var b := UI.button(screen,id,entry[1],"")
		b.add_theme_stylebox_override("normal",UI.style(Color.TRANSPARENT,Color.TRANSPARENT,0))
		var glow := UI.style(Color(0.8,0.7,0.3,0.04),Color(0.85,0.73,0.43,0.38),2)
		b.add_theme_stylebox_override("hover",glow)
		b.add_theme_stylebox_override("pressed",glow)
		b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		b.pressed.connect(open_facility.bind(id))
		controls[id] = b
		var sign := UI.panel(screen,id+"Sign",Rect2(entry[3],Vector2(230,38)))
		sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text := UI.label(sign,"Text",Rect2(4,0,222,38),entry[2],16,UI.GOLD)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal = Control.new()
	modal.name = "FacilityOverlay"
	modal.size = Vector2(1600,900)
	modal.z_index = 30
	screen.add_child(modal)
	var shade := ColorRect.new()
	shade.size = Vector2(1600,900)
	shade.color = Color(0.005,0.012,0.02,0.88)
	modal.add_child(shade)
	modal.hide()
	for entry in [["inventory","INVENTORY / I",Rect2(30,140,170,42)],["goals","OBJECTIVES / J",Rect2(214,140,185,42)],["help","HOW TO PLAY / H",Rect2(413,140,190,42)]]:
		var b := UI.button(screen,entry[0],entry[2],entry[1],13)
		b.pressed.connect(open_facility.bind(entry[0]))
	_build_walking_space()
	RunState.changed.connect(_refresh)
	_refresh()
	message.text = "WELCOME HOME. REST, STOCK SUPPLIES, OR VISIT THE GATE."
	if RunState.open_gate_on_return:
		RunState.open_gate_on_return = false
		open_facility("gate")

func _build_walking_space() -> void:
	for rect in [Rect2(125,250,400,350),Rect2(1100,310,390,300),Rect2(650,500,300,280),Rect2(610,130,390,240)]:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		world.add_child(body)
	walker = CharacterBody2D.new()
	walker.set_script(preload("res://scripts/hideout_walker.gd"))
	walker.name = "AdamWalker"
	walker.hideout = self
	walker.position = Vector2(1030,755)
	world.add_child(walker)

func movement_blocked() -> bool:
	return modal.visible or GameAudio.settings_open() or SceneFlow.busy

func nearest_facility() -> String:
	var nearest := ""
	var distance := 112.0
	for id in INTERACTIONS:
		var candidate: float = walker.position.distance_to(INTERACTIONS[id])
		if candidate<distance:
			distance = candidate
			nearest = id
	return nearest

func _process(delta: float) -> void:
	if not is_instance_valid(walker) or not is_instance_valid(message):
		return
	if message_hold>0:
		message_hold -= delta
	elif not modal.visible:
		var nearby := nearest_facility()
		message.text = "E / " + {"gate":"ENTER THE GATE","house":"REST IN THE HOUSE","tree":"VISIT THE GREAT TREE","shop":"BUY SUPPLIES"}[nearby] if not nearby.is_empty() else "WASD / ARROWS MOVE    E INTERACT    I INVENTORY    J OBJECTIVES    H HELP"

func _fit() -> void:
	var zoom := minf(size.x/1600.0,size.y/900.0)
	var offset := (size-Vector2(1600,900)*zoom)*0.5
	world.scale = Vector2.ONE*zoom
	world.position = offset
	screen.scale = Vector2.ONE*zoom
	screen.position = offset

func _refresh() -> void:
	profile_text.text = "%d CREDITS / DMG %.1fX / DUR %.1fX" % [RunState.credits,RunState.damage_multiplier(),RunState.durability_multiplier()]
	hp.max_value = RunState.max_hp
	hp.value = RunState.hp
	sp.max_value = RunState.max_sp
	sp.value = RunState.sp
	summary.text = "HP %d/%d / SP %d/%d" % [RunState.hp,RunState.max_hp,RunState.sp,RunState.max_sp]
	if modal.visible:
		_draw_facility()

func open_facility(kind: String) -> void:
	modal_kind = kind
	modal.show()
	_draw_facility()

func close_facility() -> void:
	modal.hide()
	get_viewport().gui_release_focus()

func _draw_facility() -> void:
	if is_instance_valid(window):
		modal.remove_child(window)
		window.queue_free()
	window = UI.panel(modal,"Window",Rect2(250,155,1100,590))
	var title: String = {"gate":"BEYOND THE WALL","house":"A PLACE TO RECOVER","tree":"THE GREAT TREE","shop":"CARE AND SUPPLIES","inventory":"ADAM'S INVENTORY","goals":"THE RESISTANCE BOARD","help":"HOW TO PLAY"}[modal_kind]
	UI.label(window,"Title",Rect2(32,18,950,44),title,28,UI.GOLD)
	var close := UI.button(window,"Close",Rect2(1010,18,60,44),"X")
	close.pressed.connect(close_facility)
	match modal_kind:
		"gate": _gate()
		"house": _house()
		"tree": _tree()
		"shop": _shop()
		"inventory": _inventory()
		"goals": _goals()
		"help": _help()

func _gate() -> void:
	UI.label(window,"Description",Rect2(32,76,1036,48),"CHOOSE A NEW RUN. ENEMY HP AND DAMAGE BOTH SCALE.",17,UI.MUTED)
	var modes := ["normal","hard","nightmare"]
	for i in range(3):
		var id: String = modes[i]
		var factor: float = RunState.MODES[id]
		var b := UI.button(window,id,Rect2(32+i*350,145,330,205),"%s\n\n%.1fX HP\n%.1fX DAMAGE\n\nSTART RUN" % [id.to_upper(),factor,factor],18)
		b.disabled = RunState.hp<=0
		b.pressed.connect(_start.bind(id))
	if RunState.can_continue_run():
		var b := UI.button(window,"Continue",Rect2(220,445,660,68),"CONTINUE %s" % RunState.difficulty.to_upper(),17)
		b.disabled = RunState.hp<=0
		b.pressed.connect(_continue)
	if RunState.hp<=0:
		UI.label(window,"RestFirst",Rect2(32,520,1036,35),"REST IN THE HOUSE BEFORE LEAVING.",17,UI.GOLD)

func _house() -> void:
	UI.label(window,"Body",Rect2(70,110,960,150),"THE HEARTH IS WARM.\n\nRESTING HERE FULLY RESTORES HP AND SP.\nYOUR ROBOT PROGRESS AND SUPPLIES STAY WITH YOU.",21,UI.TEXT,true)
	UI.label(window,"Current",Rect2(70,300,960,65),"HP %d / %d    SP %d / %d" % [RunState.hp,RunState.max_hp,RunState.sp,RunState.max_sp],24,UI.GOLD)
	var b := UI.button(window,"Rest",Rect2(285,430,530,78),"REST / FULL HP + SP / FREE",19)
	b.disabled = RunState.hp>=RunState.max_hp and RunState.sp>=RunState.max_sp
	b.pressed.connect(_rest)

func _tree() -> void:
	UI.label(window,"Body",Rect2(60,95,980,120),"A LIVING MEMORY OF HUMANITY.\nGROW ITS ROOTS FOR +0.2X DAMAGE AND DURABILITY PER LEVEL.\nDURABILITY REDUCES THE DAMAGE YOU TAKE.",19,UI.TEXT,true)
	UI.label(window,"Level",Rect2(60,235,980,80),"ROOT LEVEL %d / 5\nDAMAGE %.1fX / DURABILITY %.1fX" % [RunState.damage_level,RunState.damage_multiplier(),RunState.durability_multiplier()],23,UI.GOLD)
	UI.label(window,"Attack",Rect2(60,335,980,65),"BASIC PUNCH / %d DAMAGE\nINCOMING DAMAGE / %.1f%%" % [ceili(22*RunState.damage_multiplier()),100.0/RunState.durability_multiplier()],18)
	var maxed: bool = RunState.damage_level>=5
	var b := UI.button(window,"Upgrade",Rect2(260,430,580,78),"ROOTS FULLY GROWN" if maxed else "GROW ROOTS / %d CREDITS" % RunState.upgrade_cost(),19)
	b.disabled = maxed or RunState.credits<RunState.upgrade_cost()
	b.pressed.connect(_upgrade)

func _shop() -> void:
	UI.label(window,"Body",Rect2(32,80,1036,44),"SUPPLIES ARE SHARED WITH EVERY BATTLE. %d CREDITS AVAILABLE." % RunState.credits,17,UI.MUTED)
	var items := ["apple","bandage","ether"]
	for i in range(items.size()):
		var id: String = items[i]
		var entry: Dictionary = RunState.SHOP[id]
		var x := 32+i*350
		var card := UI.panel(window,id+"Card",Rect2(x,150,330,350))
		UI.label(card,"Name",Rect2(20,18,290,42),entry["name"],21,UI.GOLD)
		UI.label(card,"Effect",Rect2(20,82,290,132),"RESTORES %d %s\n%sMAX %d USES PER FIGHT\nOWNED %d\nPRICE %d CREDITS" % [entry["sp"] if id=="ether" else entry["heal"],"SP" if id=="ether" else "HP","ACT AGAIN IN COMBAT\n" if id=="apple" else "",entry.limit,RunState.inventory[id],entry["price"]],17,UI.TEXT,true)
		var b := UI.button(card,"Buy",Rect2(20,260,290,65),"BUY ONE",19)
		b.disabled = RunState.credits<int(entry["price"]) or int(RunState.inventory[id])>=99
		b.pressed.connect(_buy.bind(id))

func _inventory() -> void:
	UI.label(window,"Stats",Rect2(32,76,1036,44),"ROOT %d / DAMAGE %.1fX / DURABILITY %.1fX / HP %d/%d / SP %d/%d" % [RunState.damage_level,RunState.damage_multiplier(),RunState.durability_multiplier(),RunState.hp,RunState.max_hp,RunState.sp,RunState.max_sp],16,UI.MUTED)
	var ids := ["apple","bandage","ether"]
	for i in range(3):
		var id: String = ids[i]
		var entry: Dictionary = RunState.SHOP[id]
		var card := UI.panel(window,id+"Card",Rect2(32+i*350,150,330,350))
		UI.label(card,"Name",Rect2(20,18,290,42),entry.name,21,UI.GOLD)
		UI.label(card,"Details",Rect2(20,80,290,150),"OWNED %d\n\n%s" % [RunState.inventory[id],RunState.ITEM_DESCRIPTIONS[id]],16,UI.TEXT,true)
		var b := UI.button(card,"Use",Rect2(20,260,290,65),"USE",19)
		var full: bool = RunState.sp>=RunState.max_sp if int(entry.sp)>0 else RunState.hp>=RunState.max_hp
		b.disabled = int(RunState.inventory[id])<=0 or full or RunState.hp<=0
		b.tooltip_text = "REST IN THE HOUSE FIRST." if RunState.hp<=0 else "NONE OWNED." if int(RunState.inventory[id])<=0 else "ALREADY FULL." if full else "RESTORE %d %s." % [entry.sp if int(entry.sp)>0 else entry.heal,"SP" if int(entry.sp)>0 else "HP"]
		b.pressed.connect(_use_supply.bind(id))

func _goals() -> void:
	UI.label(window,"Intro",Rect2(32,71,1036,28),"BUILD A FUTURE FOR THE HIDEOUT. EACH REWARD CAN BE CLAIMED ONCE.",15,UI.MUTED)
	for i in range(RunState.GOALS.size()):
		var goal: Dictionary = RunState.GOALS[i]
		var row := UI.panel(window,goal.id,Rect2(32,110+i*83,1036,74))
		UI.label(row,"Name",Rect2(16,6,570,26),goal.name,17,UI.GOLD)
		UI.label(row,"Description",Rect2(16,36,590,25),goal.description,14)
		var progress: int = mini(RunState.goal_progress(goal),int(goal.target))
		UI.label(row,"Progress",Rect2(613,15,100,40),"%d / %d" % [progress,goal.target],16,UI.MUTED)
		var claimed: bool = goal.id in RunState.claimed_goals
		var b := UI.button(row,"Claim",Rect2(755,12,265,50),"CLAIMED" if claimed else "CLAIM %d CREDITS" % goal.reward,14)
		b.disabled = claimed or progress<int(goal.target)
		b.pressed.connect(_claim.bind(goal.id))

func _help() -> void:
	UI.label(window,"Guide",Rect2(45,90,1010,430),"HIDEOUT\nWASD / ARROWS TO WALK. E TO USE A NEARBY BUILDING.\nYOU CAN ALSO CLICK BUILDINGS. I OPENS YOUR INVENTORY.\nJ OPENS OBJECTIVES. THE HOUSE FULLY RESTORES HP AND SP.\n\nCOMBAT\nCHOOSE ONE ACTION PER TURN. WATCH THE ENEMY'S NEXT MOVE.\nATTACK RESTORES 4 SP. DEFEND REDUCES DAMAGE AND GIVES 12 SP.\nSKILLS COST SP. GOD APPLE HEALS 30 HP AND LETS ADAM ACT AGAIN.\nPER FIGHT: GOD APPLE 2 / BANDAGE 3 / SP POTION 3.\nESCAPE HAS A 25% CHANCE; FAILURE USES YOUR TURN.\n\nPREPARATION\nROOTS INCREASE DAMAGE AND DURABILITY. BRING SUPPLIES.\nVICTORY OFFERS THE HIDEOUT OR 30% HP REST AND CONTINUE.\nF10 OPENS SOUND SETTINGS.",17,UI.TEXT,true)

func _claim(id: String) -> void:
	if RunState.claim_goal(id):
		GameAudio.sfx("purchase")
		message_hold = 3
		message.text = "OBJECTIVE COMPLETE / REWARD CLAIMED."

func _use_supply(id: String) -> void:
	var amount: int = RunState.use_supply(id)
	if amount>0:
		close_facility()
		GameAudio.sfx("sp_heal" if id=="ether" else "heal")
		walker.actor.use_item(id)
		message_hold = 3
		message.text = "USED %s / RESTORED %d %s." % [RunState.SHOP[id].name,amount,"SP" if id=="ether" else "HP"]

func _start(mode: String) -> void:
	if SceneFlow.busy:
		return
	if RunState.begin_run(mode):
		GameAudio.sfx("gate")
		SceneFlow.change_scene(RunState.next_scene())
func _continue() -> void:
	if RunState.hp>0 and RunState.can_continue_run():
		GameAudio.sfx("gate")
		SceneFlow.change_scene(RunState.next_scene())
func _rest() -> void:
	RunState.rest_home()
	GameAudio.sfx("heal")
	message.text = "REST COMPLETE / HP AND SP FULLY RESTORED."
	message_hold = 3
func _upgrade() -> void:
	if RunState.upgrade_damage():
		GameAudio.sfx("upgrade")
		message.text = "THE TREE ANSWERS / DAMAGE %.1fX / DURABILITY %.1fX." % [RunState.damage_multiplier(),RunState.durability_multiplier()]
		message_hold = 3
func _buy(id: String) -> void:
	if RunState.buy(id):
		GameAudio.sfx("purchase")
		message.text = "BOUGHT " + RunState.SHOP[id]["name"] + ". SUPPLIES ARE READY FOR BATTLE."
		message_hold = 3
func _unhandled_key_input(event: InputEvent) -> void:
	if modal.visible and event.is_action_pressed("ui_cancel"):
		close_facility()
		get_viewport().set_input_as_handled()
	elif not modal.visible and event is InputEventKey and event.pressed and not event.echo and not GameAudio.settings_open():
		match event.keycode:
			KEY_I: open_facility("inventory")
			KEY_J: open_facility("goals")
			KEY_H: open_facility("help")
			KEY_E:
				var nearest := nearest_facility()
				if not nearest.is_empty():
					open_facility(nearest)
