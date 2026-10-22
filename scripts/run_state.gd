extends Node
## Shared hideout / combat profile. Never resets HP or supplies on a scene change.
signal changed
const MODES := {"normal":1.0,"hard":1.4,"nightmare":2.0}
const MODE_NAMES := {"normal":"NORMAL","hard":"HARD","nightmare":"NIGHTMARE"}
const SHOP := {
	"apple":{"name":"GOD APPLE","price":8,"heal":30,"sp":0,"limit":2,"extra_turn":true},
	"bandage":{"name":"BANDAGE","price":22,"heal":60,"sp":0,"limit":3},
	"ether":{"name":"SP POTION","price":15,"heal":0,"sp":30,"limit":3}
}
var save_path := "user://hideout_profile.json"
var save_enabled := true
var hp := 120
var max_hp := 120
var sp := 60
var max_sp := 60
var credits := 120
var damage_level := 0
var difficulty := "normal"
var stage := 0
var run_active := false
var nightmare_cleared := false
var inventory := {"apple":3,"bandage":2,"ether":2}
const ITEM_DESCRIPTIONS := {"apple":"RESTORES 30 HP. IN COMBAT, ADAM CAN ACT AGAIN. LIMIT 2 PER FIGHT.","bandage":"RESTORES 60 HP. USES YOUR TURN. LIMIT 3 PER FIGHT.","ether":"RESTORES 30 SP. USES YOUR TURN. LIMIT 3 PER FIGHT."}
const GOALS := [
	{"id":"first_win","name":"FIRST STAND","description":"DEFEAT ONE ROBOT.","stat":"wins","target":1,"reward":25},
	{"id":"supplies","name":"READY FOR THE ROAD","description":"BUY THREE SUPPLIES.","stat":"purchases","target":3,"reward":20},
	{"id":"roots","name":"PUT DOWN ROOTS","description":"REACH ROOT LEVEL TWO.","stat":"roots","target":2,"reward":40},
	{"id":"normal_clear","name":"HOLD THE LINE","description":"CLEAR A NORMAL ROBOT RUN.","stat":"normal_clears","target":1,"reward":80},
	{"id":"hard_clear","name":"AGAINST THE ODDS","description":"CLEAR A HARD ROBOT RUN.","stat":"hard_clears","target":1,"reward":120}
]
var stats := {"wins":0,"purchases":0,"normal_clears":0,"hard_clears":0,"nightmare_clears":0,"rests":0}
var claimed_goals: Array[String] = []
var last_result := ""
var open_gate_on_return := false

func _ready() -> void:
	load_profile()

func damage_multiplier() -> float:
	return 1.0+0.2*damage_level

func durability_multiplier() -> float:
	return 1.0+0.2*damage_level

func enemy_multiplier() -> float:
	return float(MODES.get(difficulty,1.0))

func upgrade_cost() -> int:
	return 60*(damage_level+1)

func snapshot() -> Dictionary:
	return {"hp":hp,"sp":sp,"max_hp":max_hp,"max_sp":max_sp,"credits":credits,"damage_level":damage_level,"difficulty":difficulty,"stage":stage,"run_active":run_active,"nightmare_cleared":nightmare_cleared,"inventory":inventory.duplicate(true),"stats":stats.duplicate(true),"claimed_goals":claimed_goals.duplicate()}

func save_profile() -> void:
	if save_enabled:
		var file := FileAccess.open(save_path,FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(snapshot()))
	changed.emit()

func load_profile() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return
	hp = clampi(int(data.get("hp",120)),0,max_hp)
	sp = clampi(int(data.get("sp",60)),0,max_sp)
	credits = maxi(0,int(data.get("credits",120)))
	damage_level = clampi(int(data.get("damage_level",0)),0,5)
	difficulty = str(data.get("difficulty","normal"))
	if not MODES.has(difficulty):
		difficulty = "normal"
	stage = clampi(int(data.get("stage",0)),0,3)
	run_active = bool(data.get("run_active",false))
	nightmare_cleared = bool(data.get("nightmare_cleared",false)) and difficulty == "nightmare" and stage == 3
	if stage == 3 and difficulty != "nightmare":
		run_active = false
	elif stage == 3 and not nightmare_cleared:
		# Old direct-entry saves must earn progression through the run.
		stage = 0
	var bag = data.get("inventory",{})
	if bag is Dictionary:
		for item in SHOP:
			inventory[item] = clampi(int(bag.get(item,0)),0,99)
	var saved_stats = data.get("stats",{})
	if saved_stats is Dictionary:
		for id in stats:
			stats[id] = maxi(0,int(saved_stats.get(id,0)))
	claimed_goals.clear()
	var saved_goals = data.get("claimed_goals",[])
	if saved_goals is Array:
		for id in saved_goals:
			if str(id) not in claimed_goals:
				claimed_goals.append(str(id))

func rest_home() -> void:
	hp = max_hp
	sp = max_sp
	stats.rests += 1
	save_profile()

func buy(item: String) -> bool:
	if not SHOP.has(item) or credits < int(SHOP[item]["price"]) or int(inventory[item]) >= 99:
		return false
	credits -= int(SHOP[item]["price"])
	inventory[item] += 1
	stats.purchases += 1
	save_profile()
	return true

func use_supply(item: String) -> int:
	if hp<=0 or not SHOP.has(item) or int(inventory[item])<=0:
		return 0
	var entry: Dictionary = SHOP[item]
	var amount := mini(max_sp-sp,int(entry.sp)) if int(entry.sp)>0 else mini(max_hp-hp,int(entry.heal))
	if amount<=0:
		return 0
	inventory[item] -= 1
	if int(entry.sp)>0:
		sp += amount
	else:
		hp += amount
	save_profile()
	return amount

func goal_progress(goal: Dictionary) -> int:
	return damage_level if goal.stat=="roots" else int(stats.get(goal.stat,0))

func claim_goal(id: String) -> bool:
	if id in claimed_goals:
		return false
	for goal in GOALS:
		if goal.id==id and goal_progress(goal)>=int(goal.target):
			claimed_goals.append(id)
			credits += int(goal.reward)
			save_profile()
			return true
	return false

func upgrade_damage() -> bool:
	if damage_level >= 5 or credits < upgrade_cost():
		return false
	credits -= upgrade_cost()
	damage_level += 1
	save_profile()
	return true

func begin_run(mode: String) -> bool:
	if hp <= 0 or not MODES.has(mode):
		return false
	difficulty = mode
	stage = 0
	run_active = true
	nightmare_cleared = false
	save_profile()
	return true

func can_enter_final() -> bool:
	return run_active and difficulty == "nightmare" and stage == 3 and nightmare_cleared

func can_continue_run() -> bool:
	return run_active and (stage < 3 or can_enter_final())

func next_scene() -> String:
	if can_enter_final():
		return "res://Battle/secret_rat.tscn"
	if run_active and stage < 3:
		return "res://Battle/attack.tscn"
	return "res://Scene/lobby.tscn"

func sync_battle(rules: RefCounted) -> void:
	hp = clampi(rules.adam_hp,0,max_hp)
	sp = clampi(rules.adam_sp,0,max_sp)
	inventory = rules.inventory.duplicate(true)
	save_profile()

func award_victory(index: int) -> int:
	if not run_active or index != stage or index < 0 or index >= 3:
		return 0
	var reward := ceili(float([35,55,85][index])*enemy_multiplier())
	credits += reward
	stats.wins += 1
	stage = index+1
	if stage==3:
		stats[difficulty+"_clears"] += 1
	nightmare_cleared = stage == 3 and difficulty == "nightmare"
	run_active = stage < 3 or nightmare_cleared
	save_profile()
	return reward

func field_rest() -> int:
	var healing := mini(max_hp-hp,ceili(max_hp*0.30))
	hp += healing
	save_profile()
	return healing
