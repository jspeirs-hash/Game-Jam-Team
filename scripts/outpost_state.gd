class_name OutpostState
extends RefCounted
## Scene-local gameplay state. A future player can listen to food_consumed.

signal changed
signal food_consumed(item_id: String, effects: Dictionary)

const CROPS = [
	{"id": "apple", "name": "APPLE", "seed": "APPLE SEEDS", "seconds": 45.0, "yield": 2, "description": "GROW FRESH APPLES. HARVEST 2 FRUIT AND RECOVER 1 SEED."},
	{"id": "berries", "name": "BERRIES", "seed": "BERRY SEEDS", "seconds": 30.0, "yield": 3, "description": "GROW BERRIES. HARVEST 3 FRUIT AND RECOVER 1 SEED."},
	{"id": "carrot", "name": "CARROT", "seed": "CARROT SEEDS", "seconds": 20.0, "yield": 2, "description": "GROW CARROTS. HARVEST 2 ROOTS AND RECOVER 1 SEED."}
]
const CATEGORIES = ["FRUIT", "MEALS", "DRINKS"]
const SHOP = [["apple", "berries", "pear"], ["carrot", "stew", "rations"], ["tea", "juice", "broth"]]
const FOOD = {
	"apple": {"name": "APPLE", "price": 8, "icon": 0, "heal": 20.0, "stamina": 0.0, "buff": "", "strength": 0.0, "duration": 0.0, "effect": "+20 HEALTH", "description": "CRISP FRUIT GROWN INSIDE THE CITADEL."},
	"berries": {"name": "BERRIES", "price": 10, "icon": 1, "heal": 10.0, "stamina": 15.0, "buff": "", "strength": 0.0, "duration": 0.0, "effect": "+10 HEALTH\n+15 STAMINA", "description": "A HANDFUL OF ENERGIZING BERRIES."},
	"pear": {"name": "PEAR", "price": 12, "icon": 2, "heal": 10.0, "stamina": 0.0, "buff": "speed", "strength": 0.10, "duration": 30.0, "effect": "+10 HEALTH\n+10% SPEED / 30S", "description": "LIGHT FOOD FOR QUICK FEET."},
	"carrot": {"name": "CARROT", "price": 6, "icon": 3, "heal": 15.0, "stamina": 0.0, "buff": "defense", "strength": 0.10, "duration": 30.0, "effect": "+15 HEALTH\n+10% DEFENSE / 30S", "description": "FRESH ROOTS FOR A HEARTY FIELD SNACK."},
	"stew": {"name": "VEGETABLE STEW", "price": 24, "icon": 4, "heal": 30.0, "stamina": 0.0, "buff": "regen", "strength": 1.0, "duration": 20.0, "effect": "+30 HEALTH\n+1 HP / SECOND / 20S", "description": "A WARM MEAL THAT SUPPORTS RECOVERY."},
	"rations": {"name": "TRAIL RATIONS", "price": 16, "icon": 5, "heal": 0.0, "stamina": 30.0, "buff": "stamina_regen", "strength": 1.0, "duration": 30.0, "effect": "+30 STAMINA\n+1 ST / SECOND / 30S", "description": "DRIED FOOD FOR LONG EXPEDITIONS."},
	"tea": {"name": "HERBAL TEA", "price": 14, "icon": 6, "heal": 10.0, "stamina": 0.0, "buff": "regen", "strength": 0.5, "duration": 30.0, "effect": "+10 HEALTH\n+0.5 HP / SECOND / 30S", "description": "GARDEN HERBS BREWED FOR GENTLE RECOVERY."},
	"juice": {"name": "BERRY JUICE", "price": 18, "icon": 7, "heal": 0.0, "stamina": 25.0, "buff": "speed", "strength": 0.15, "duration": 20.0, "effect": "+25 STAMINA\n+15% SPEED / 20S", "description": "FRESH JUICE FOR A QUICK BURST OF ENERGY."},
	"broth": {"name": "WARM BROTH", "price": 20, "icon": 8, "heal": 20.0, "stamina": 10.0, "buff": "defense", "strength": 0.15, "duration": 30.0, "effect": "+20 HP / +10 ST\n+15% DEFENSE / 30S", "description": "COMFORTING FOOD BEFORE A TOUGH MISSION."}
}

var credits := 120
var health := 70.0
var max_health := 100.0
var stamina := 60.0
var max_stamina := 100.0
var seeds: Array[int] = [3, 3, 3]
var beds: Array[Dictionary] = []
var food_bag: Dictionary = {}
var shop_stock: Dictionary = {}
var buffs: Dictionary = {}

func _init() -> void:
	for i in range(6):
		beds.append({"crop": -1, "elapsed": 0.0})
	for item in FOOD:
		food_bag[item] = 0
		shop_stock[item] = 10

func plant(bed: int, seed: int) -> String:
	if bed < 0 or bed >= beds.size() or seed < 0 or seed >= CROPS.size():
		return "INVALID BED OR SEED"
	if int(beds[bed]["crop"]) != -1:
		return "THIS BED IS ALREADY PLANTED"
	if seeds[seed] <= 0:
		return "NO SEEDS AVAILABLE"
	seeds[seed] -= 1
	beds[bed] = {"crop": seed, "elapsed": 0.0}
	changed.emit()
	return "PLANTED " + CROPS[seed]["name"]

func is_ready(bed: int) -> bool:
	if bed < 0 or bed >= beds.size():
		return false
	var crop := int(beds[bed]["crop"])
	return crop >= 0 and float(beds[bed]["elapsed"]) >= float(CROPS[crop]["seconds"])

func harvest(bed: int) -> String:
	if not is_ready(bed):
		return "CROP IS NOT READY"
	var crop := int(beds[bed]["crop"])
	var info: Dictionary = CROPS[crop]
	food_bag[info["id"]] += int(info["yield"])
	seeds[crop] += 1
	beds[bed] = {"crop": -1, "elapsed": 0.0}
	changed.emit()
	return "HARVESTED %d %s / +1 SEED" % [info["yield"], info["name"]]

func purchase(item: String, quantity: int) -> String:
	if not FOOD.has(item) or quantity < 1 or quantity > 99:
		return "INVALID PURCHASE"
	var cost := int(FOOD[item]["price"]) * quantity
	if int(shop_stock[item]) < quantity:
		return "NOT ENOUGH STOCK"
	if credits < cost:
		return "NOT ENOUGH CREDITS"
	credits -= cost
	shop_stock[item] -= quantity
	food_bag[item] += quantity
	changed.emit()
	return "BOUGHT %d %s / %d CREDITS" % [quantity, FOOD[item]["name"], cost]

func consume(item: String) -> String:
	if not FOOD.has(item) or int(food_bag.get(item, 0)) < 1:
		return "YOU DO NOT OWN THIS FOOD"
	var food: Dictionary = FOOD[item]
	if str(food["buff"]).is_empty() and float(food["stamina"]) == 0.0 and health >= max_health:
		return "HEALTH IS ALREADY FULL"
	if str(food["buff"]).is_empty() and float(food["heal"]) == 0.0 and stamina >= max_stamina:
		return "STAMINA IS ALREADY FULL"
	food_bag[item] -= 1
	health = minf(max_health, health + float(food["heal"]))
	stamina = minf(max_stamina, stamina + float(food["stamina"]))
	var buff := str(food["buff"])
	if not buff.is_empty():
		# One effect per kind: keep the stronger magnitude and longer duration.
		var old: Dictionary = buffs.get(buff, {"strength": 0.0, "remaining": 0.0})
		buffs[buff] = {"strength": maxf(float(old["strength"]), float(food["strength"])), "remaining": maxf(float(old["remaining"]), float(food["duration"]))}
	food_consumed.emit(item, food.duplicate(true))
	changed.emit()
	return "USED " + food["name"]

func advance_time(delta: float) -> void:
	if delta <= 0.0:
		return
	for bed in beds:
		var crop := int(bed["crop"])
		if crop >= 0:
			bed["elapsed"] = minf(float(CROPS[crop]["seconds"]), float(bed["elapsed"]) + delta)
	for buff in buffs.keys():
		var effect: Dictionary = buffs[buff]
		var active_delta := minf(delta, float(effect["remaining"]))
		if buff == "regen":
			health = minf(max_health, health + float(effect["strength"]) * active_delta)
		elif buff == "stamina_regen":
			stamina = minf(max_stamina, stamina + float(effect["strength"]) * active_delta)
		effect["remaining"] = maxf(0.0, float(effect["remaining"]) - delta)
		if float(effect["remaining"]) <= 0.0:
			buffs.erase(buff)

func speed_multiplier() -> float:
	return 1.0 + float(buffs.get("speed", {}).get("strength", 0.0))

func defense_multiplier() -> float:
	return 1.0 + float(buffs.get("defense", {}).get("strength", 0.0))
