extends RefCounted
## Common action, SP, damage and item rules for robot and rat encounters.
const ESCAPE_CHANCE := 0.25
const RAT_MAX_HP := 20
const RAT_DAMAGE_PER_TURN := 5
const ULTIMATE_FRACTION := 0.40
const SMASHER_REACTOR_MAX := 60
const PATTERNS := [["attack","attack","skill","attack","defend"],["attack","defend","attack","skill"],["attack","skill","defend","skill","attack","defend"]]
const SKILLS = {
	"first_fist":{"name":"FIRST FIST","damage":42,"hits":1,"cooldown":3,"sp":14},
	"origin_rush":{"name":"ORIGIN RUSH","damage":19,"hits":2,"cooldown":3,"sp":20},
	"last_light":{"name":"LAST LIGHT","damage":0,"hits":1,"cooldown":0,"sp":60,"ultimate":true}
}
const ITEMS = {
	"apple":{"name":"GOD APPLE","heal":30,"sp":0,"limit":2,"extra_turn":true},
	"bandage":{"name":"BANDAGE","heal":60,"sp":0,"limit":3},
	"ether":{"name":"SP POTION","heal":0,"sp":30,"limit":3}
}
const ENCOUNTERS = [
	{"name":"SCOUT BOT","scene":"res://Battle/scout_bot.tscn","level":2,"hp":80,"attack":10,"skill":16,"guard_period":5,"skill_period":3,"scale":1.0,"body_height":110.0,"ranged":false,"color":"94eab4","attack_text":"SCOUT BOT SWINGS A MECHANICAL FIST.","skill_text":"SCOUT BOT USES BATTERY BURST.","guard_text":"SCOUT BOT RAISES ITS GUARD."},
	{"name":"ATOM","scene":"res://Battle/atom.tscn","level":5,"hp":150,"attack":18,"skill":28,"guard_period":4,"skill_period":3,"scale":1.32,"body_height":110.0,"ranged":false,"color":"88e8f1","attack_text":"ATOM FIRES A HEAVY PUNCH.","skill_text":"ATOM USES CORE BREAKER.","guard_text":"ATOM LOCKS ITS ARMS INTO A STEEL GUARD."},
	{"name":"ADAM SMASHER","scene":"res://Battle/adam_smasher.tscn","level":10,"hp":240,"attack":22,"skill":32,"guard_period":4,"skill_period":3,"scale":1.45,"body_height":160.0,"ranged":true,"color":"ff9b68","attack_text":"ADAM SMASHER FIRES HIS ARM CANNON.","skill_text":"ADAM SMASHER USES SIEGE CANNON.","guard_text":"ADAM SMASHER BRACES HIS HEAVY ARMOR."}
]
var encounter_index := 0
var phase := "player"
var adam_max_hp := 120
var adam_hp := 120
var adam_max_sp := 60
var adam_sp := 60
var atom_max_hp := 80
var atom_hp := 80
var adam_guard := false
var atom_guard := false
var turn := 1
var cooldowns := {"first_fist":0,"origin_rush":0,"last_light":0}
var inventory := {"apple":3,"bandage":2,"ether":2}
var pending_item := ""
var item_uses := {"apple":0,"bandage":0,"ether":0}
var _consumed_item := ""
var difficulty := "normal"
var enemy_multiplier := 1.0
var damage_multiplier := 1.0
var durability_multiplier := 1.0
var is_final := false
var boss_phase := "rat"
var escape_rng := RandomNumberGenerator.new()
var _escape_pending := false
var rat_damage_this_turn := 0
var adam_ultimate_pending := false
var adam_stunned := false
var smasher_reactor := 0
var smasher_charging := false
var _enemy_ultimate_turn := false

func configure(profile: Dictionary, final := false) -> void:
	escape_rng.randomize()
	difficulty = str(profile.get("difficulty","normal"))
	enemy_multiplier = float({"normal":1.0,"hard":1.4,"nightmare":2.0}.get(difficulty,1.0))
	damage_multiplier = 1.0+0.2*clampi(int(profile.get("damage_level",0)),0,5)
	durability_multiplier = damage_multiplier
	adam_max_hp = int(profile.get("max_hp",120))
	adam_max_sp = int(profile.get("max_sp",60))
	adam_hp = clampi(int(profile.get("hp",120)),0,adam_max_hp)
	adam_sp = clampi(int(profile.get("sp",60)),0,adam_max_sp)
	for item in ITEMS:
		inventory[item] = int(profile.get("inventory",{}).get(item,0))
	is_final = final
	boss_phase = "rat"
	start_encounter(clampi(int(profile.get("stage",0)),0,2))

func encounter() -> Dictionary:
	if is_final:
		return {"name":"???" if boss_phase=="shadow" else "RAT","level":"???" if boss_phase=="shadow" else "1","hp":999 if boss_phase=="shadow" else RAT_MAX_HP,"color":"c5b2e6","body_height":135.0,"ranged":false}
	return ENCOUNTERS[encounter_index]

func player_damage(power: int) -> int:
	return ceili(power*damage_multiplier)

func enemy_power(skill := false) -> int:
	return ceili(int(encounter().get("skill" if skill else "attack",0))*enemy_multiplier)

func is_rat_encounter() -> bool:
	return is_final and boss_phase == "rat"

func rat_damage_remaining() -> int:
	return maxi(0,RAT_DAMAGE_PER_TURN-rat_damage_this_turn)

func start_encounter(index: int, carry_progress := false) -> bool:
	if index < 0 or index >= ENCOUNTERS.size():
		return false
	encounter_index = index
	atom_max_hp = RAT_MAX_HP if is_rat_encounter() else ceili(int(encounter()["hp"])*enemy_multiplier)
	atom_hp = atom_max_hp
	phase = "player"
	turn = 1
	adam_guard = false
	atom_guard = false
	pending_item = ""
	item_uses = {"apple":0,"bandage":0,"ether":0}
	_consumed_item = ""
	_escape_pending = false
	rat_damage_this_turn = 0
	cooldowns = {"first_fist":0,"origin_rush":0,"last_light":0}
	adam_ultimate_pending = false
	adam_stunned = false
	smasher_reactor = 0
	smasher_charging = false
	_enemy_ultimate_turn = false
	if carry_progress:
		adam_hp = mini(adam_max_hp,adam_hp+ceili(adam_max_hp*0.30))
	return true

func awaken_shadow() -> void:
	boss_phase = "shadow"
	atom_max_hp = ceili(999*enemy_multiplier)
	atom_hp = atom_max_hp
	phase = "player"
	adam_guard = false
	atom_guard = false

func has_next_encounter() -> bool:
	return not is_final and encounter_index < 2

func can_act() -> bool:
	return phase == "player" and adam_hp > 0 and atom_hp > 0

func begin_action(action: String, choice := "") -> bool:
	if not can_act():
		return false
	if action=="escape" and is_final:
		return false
	if action == "skill":
		if not SKILLS.has(choice): return false
		if int(cooldowns[choice]) > 0 or adam_sp < skill_sp_cost(choice):
			return false
		if choice=="last_light" and adam_sp!=adam_max_sp:
			return false
		adam_ultimate_pending = choice=="last_light"
		adam_sp -= adam_max_sp if adam_ultimate_pending else int(SKILLS[choice]["sp"])
		cooldowns[choice] = int(SKILLS[choice]["cooldown"])
	elif action == "item":
		if not item_unavailable_reason(choice).is_empty():
			return false
	elif action not in ["attack","defend","escape"]:
		return false
	phase = "charging" if adam_ultimate_pending else "resolving"
	_escape_pending = action == "escape"
	pending_item = choice if action == "item" else ""
	_consumed_item = ""
	adam_guard = action == "defend"
	if action == "attack":
		adam_sp = mini(adam_max_sp,adam_sp+4)
	elif action == "defend":
		adam_sp = mini(adam_max_sp,adam_sp+12)
	return true

func roll_escape() -> bool:
	if is_final or phase != "resolving" or not _escape_pending:
		return false
	_escape_pending = false
	if escape_rng.randf() < ESCAPE_CHANCE:
		phase = "escaped"
		return true
	return false

func hit(target: String, power: int, pierce_guard := false) -> Dictionary:
	if power < 0 or target not in ["adam","atom"]:
		return {"damage":0,"blocked":false}
	var guard := (adam_guard if target == "adam" else atom_guard) and not pierce_guard
	var factor := 1.0/durability_multiplier if target == "adam" else 1.0
	if guard:
		factor *= 0.35 if target == "adam" else 0.5
	var damage := maxi(1,ceili(power*factor)) if power > 0 else 0
	if target == "adam":
		damage = mini(damage,adam_hp)
		adam_hp -= damage
		adam_guard = false
	else:
		if is_rat_encounter():
			damage = mini(damage,rat_damage_remaining())
			rat_damage_this_turn += damage
		damage = mini(damage,atom_hp)
		atom_hp -= damage
		atom_guard = false
	return {"damage":damage,"blocked":guard}

func item_uses_left(item: String) -> int:
	return maxi(0,int(ITEMS[item].limit)-int(item_uses.get(item,0))) if ITEMS.has(item) else 0

func item_unavailable_reason(item: String) -> String:
	if not ITEMS.has(item): return "UNKNOWN ITEM"
	if item_uses_left(item)<=0: return "FIGHT LIMIT REACHED"
	if int(inventory.get(item,0))<=0: return "NONE OWNED"
	if int(ITEMS[item].sp)>0 and adam_sp>=adam_max_sp: return "SP ALREADY FULL"
	if int(ITEMS[item].heal)>0 and adam_hp>=adam_max_hp and not ITEMS[item].get("extra_turn",false): return "HP ALREADY FULL"
	return ""

func consume_item(item: String) -> int:
	if phase != "resolving" or item != pending_item or not item_unavailable_reason(item).is_empty():
		return 0
	var restores_sp := int(ITEMS[item]["sp"]) > 0
	var amount := mini(adam_max_sp-adam_sp,int(ITEMS[item]["sp"])) if restores_sp else mini(adam_max_hp-adam_hp,int(ITEMS[item]["heal"]))
	if amount <= 0 and not ITEMS[item].get("extra_turn",false):
		return 0
	pending_item = ""
	_consumed_item = item
	inventory[item] -= 1
	item_uses[item] = int(item_uses.get(item,0))+1
	if restores_sp:
		adam_sp += amount
	else:
		adam_hp += amount
	return amount

func finish_item_action(item: String) -> bool:
	if phase!="resolving" or _consumed_item!=item: return false
	_consumed_item = ""
	if not ITEMS[item].get("extra_turn",false): return false
	phase = "player"
	return true

func enemy_action() -> String:
	if is_final:
		return "wait" if boss_phase=="rat" else "attack"
	if encounter_index==2:
		if smasher_charging: return "ultimate"
		if smasher_reactor>=SMASHER_REACTOR_MAX: return "charge"
	var pattern: Array = PATTERNS[encounter_index]
	return pattern[(turn-1)%pattern.size()]

func enemy_intent_text() -> String:
	var action := enemy_action()
	if action=="charge": return "REACTOR CHARGING"
	if action=="ultimate": return "EXTINCTION PROTOCOL"
	if action=="defend":
		return ["STEEL GUARD","IRON STANCE","COOLING ARMOR"][encounter_index]
	if action=="skill":
		return ["BATTERY BURST","CORE BREAKER","SIEGE CANNON"][encounter_index]
	return ["SCOUT JAB","HEAVY PUNCH","ARM CANNON"][encounter_index]

func end_player_action() -> void:
	adam_ultimate_pending = false
	phase = "victory" if atom_hp <= 0 else "enemy"

func adam_ultimate_power() -> int:
	return ceili(atom_max_hp*ULTIMATE_FRACTION)

func skill_sp_cost(skill: String) -> int:
	return adam_max_sp if skill=="last_light" else int(SKILLS[skill].sp)

func smasher_ultimate_power() -> int:
	# Percentage damage is fixed; difficulty already changes normal attacks.
	return ceili(adam_max_hp*ULTIMATE_FRACTION)

func finish_adam_ultimate() -> void:
	if not adam_ultimate_pending: return
	adam_ultimate_pending = false
	phase = "defeat" if adam_hp<=0 else "victory" if atom_hp<=0 else "player"

func charge_smasher_ultimate() -> bool:
	if is_final or encounter_index!=2 or smasher_charging or smasher_reactor<SMASHER_REACTOR_MAX:
		return false
	smasher_reactor = 0
	smasher_charging = true
	_enemy_ultimate_turn = true
	return true

func resolve_smasher_ultimate() -> Dictionary:
	if not smasher_charging or is_final or encounter_index!=2:
		return {"damage":0,"blocked":false,"stunned":false}
	smasher_charging = false
	_enemy_ultimate_turn = true
	var outcome := hit("adam",smasher_ultimate_power())
	adam_stunned = not outcome.blocked and adam_hp>0
	outcome["stunned"] = adam_stunned
	return outcome

func consume_adam_stun() -> bool:
	if not adam_stunned: return false
	adam_stunned = false
	return true

func finish_enemy_action() -> void:
	if not is_final and encounter_index==2 and not _enemy_ultimate_turn:
		smasher_reactor = mini(SMASHER_REACTOR_MAX,smasher_reactor+20)
	_enemy_ultimate_turn = false
	if adam_hp <= 0:
		phase = "defeat"
		return
	turn += 1
	rat_damage_this_turn = 0
	for skill in cooldowns:
		cooldowns[skill] = maxi(0,int(cooldowns[skill])-1)
	phase = "player"
