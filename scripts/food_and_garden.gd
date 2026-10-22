extends RefCounted

const STATE = preload("res://scripts/outpost_state.gd")
var ui: CanvasLayer
var state: RefCounted
var seed_index := 0
var plot_index := 0
var category_index := 0
var selected_food := "apple"
var bag_mode := false
var bag_page := 0
var feedback := ""
var refresh_clock := 0.0
var refreshing := false

func _init(interface: CanvasLayer, session: RefCounted) -> void:
	ui = interface
	state = session
	for i in range(3):
		connect_button("Greenhouse/Seeds/Seed" + str(i), select_seed.bind(i))
		connect_button("Market/Catalog/Category" + str(i), select_category.bind(i))
		connect_button("Market/Catalog/Item" + str(i), select_item.bind(i))
	for i in range(6):
		connect_button("Greenhouse/Beds/Plot" + str(i), select_plot.bind(i))
	connect_button("Greenhouse/Record/Plant", plant_or_harvest)
	connect_button("Market/Catalog/BagTab", open_bag)
	connect_button("Market/Catalog/Previous", change_page.bind(-1))
	connect_button("Market/Catalog/Next", change_page.bind(1))
	connect_button("Market/Purchase/Buy", buy_food)
	connect_button("Market/Purchase/Use", use_food)
	node("Market/Purchase/Quantity").value_changed.connect(quantity_changed)
	state.changed.connect(refresh_active)

func node(path: String) -> Node:
	return ui.window.get_node(path)

func text(path: String, value: String) -> void:
	node(path).text = value

func connect_button(path: String, callback: Callable) -> void:
	node(path).pressed.connect(callback)

func advance(delta: float) -> void:
	state.advance_time(delta)
	refresh_clock += delta
	if refresh_clock >= 0.2:
		refresh_clock = 0.0
		refresh_active()

func refresh_active() -> void:
	if refreshing:
		return
	refreshing = true
	match ui.active_facility:
		"Greenhouse": refresh_garden()
		"Market": refresh_market()
		"Infirmary": ui._medical_refresh()
	refreshing = false

func open_garden() -> void:
	feedback = "CHOOSE A SEED AND AN EMPTY BED / HARVEST READY CROPS INTO YOUR FOOD BAG"
	refresh_garden()

func select_seed(index: int) -> void:
	seed_index = index
	feedback = "SELECTED " + STATE.CROPS[index]["seed"]
	refresh_garden()

func select_plot(index: int) -> void:
	plot_index = index
	feedback = "BED %02d SELECTED" % (index + 1)
	refresh_garden()

func food_texture(item: String) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://Scene/food_items.svg")
	texture.region = Rect2(int(STATE.FOOD[item]["icon"]) * 64, 0, 64, 64)
	return texture

func sprout_texture(stage: int) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://Scene/food_items.svg")
	texture.region = Rect2((9 + stage) * 64, 0, 64, 64)
	return texture

func refresh_garden() -> void:
	ui._choose("Greenhouse/Seeds", "Seed", 3, seed_index)
	ui._choose("Greenhouse/Beds", "Plot", 6, plot_index)
	for i in range(3):
		node("Greenhouse/Seeds/Seed" + str(i)).text = "%s / %d" % [STATE.CROPS[i]["name"], state.seeds[i]]
	text("Greenhouse/Seeds/Stock", "SEEDS / %d" % state.seeds[seed_index])
	var ready_count := 0
	for i in range(6):
		var bed: Dictionary = state.beds[i]
		var crop := int(bed["crop"])
		var path := "Greenhouse/Beds/Plot" + str(i)
		node(path + "/Crop").visible = crop >= 0
		if crop < 0:
			text(path + "/Status", "EMPTY")
		elif state.is_ready(i):
			ready_count += 1
			text(path + "/Status", "READY")
			node(path + "/Crop").texture = food_texture(STATE.CROPS[crop]["id"])
		else:
			var progress := float(bed["elapsed"]) / float(STATE.CROPS[crop]["seconds"])
			text(path + "/Status", "GROWING %d%%" % int(progress * 100))
			node(path + "/Crop").texture = sprout_texture(mini(2, int(progress * 3)))
	text("Greenhouse/Beds/Subheading", "%d CROPS READY / GROWTH CONTINUES WHILE IN THE LOBBY" % ready_count)
	var selected: Dictionary = state.beds[plot_index]
	var planted := int(selected["crop"])
	var info: Dictionary = STATE.CROPS[seed_index if planted < 0 else planted]
	var ready: bool = state.is_ready(plot_index)
	var status := "EMPTY" if planted < 0 else ("READY" if ready else "GROWING")
	text("Greenhouse/Record/BedName", "BED %02d / %s" % [plot_index + 1, status])
	text("Greenhouse/Record/SeedName", info["name"])
	text("Greenhouse/Record/Description", info["description"])
	var progress := 0.0 if planted < 0 else float(selected["elapsed"]) / float(info["seconds"])
	text("Greenhouse/Record/Growth", "GROWTH / %d%%" % int(progress * 100))
	node("Greenhouse/Record/GrowthBar").value = progress * 100
	var remaining := ceili(float(info["seconds"]) - (0.0 if planted < 0 else float(selected["elapsed"])))
	text("Greenhouse/Record/Harvest", "READY TO HARVEST" if ready else "READY IN / %02d:%02d" % [remaining / 60, remaining % 60])
	var action := node("Greenhouse/Record/Plant") as Button
	action.text = "HARVEST" if ready else ("GROWING" if planted >= 0 else "PLANT")
	action.disabled = (planted >= 0 and not ready) or (planted < 0 and state.seeds[seed_index] <= 0)
	text("Detail", feedback)

func plant_or_harvest() -> void:
	if int(state.beds[plot_index]["crop"]) >= 0:
		feedback = state.harvest(plot_index)
	else:
		feedback = state.plant(plot_index, seed_index)
	refresh_garden()

func open_market() -> void:
	feedback = "BUY FOOD OR OPEN YOUR FOOD BAG / EAT TO RECOVER AND GAIN EFFECTS"
	refresh_market()

func select_category(index: int) -> void:
	category_index = index
	bag_mode = false
	selected_food = STATE.SHOP[index][0]
	feedback = "BROWSING " + STATE.CATEGORIES[index]
	refresh_market()

func bag_items() -> Array[String]:
	var items: Array[String] = []
	for item in STATE.FOOD:
		if int(state.food_bag[item]) > 0:
			items.append(item)
	return items

func open_bag() -> void:
	bag_mode = true
	bag_page = 0
	var items := bag_items()
	selected_food = "" if items.is_empty() else items[0]
	feedback = "FOOD BAG / SELECT OWNED FOOD TO EAT OR DRINK"
	refresh_market()

func change_page(direction: int) -> void:
	var pages := maxi(1, ceili(bag_items().size() / 3.0))
	bag_page = clampi(bag_page + direction, 0, pages - 1)
	var items := bag_items()
	selected_food = "" if items.is_empty() else items[bag_page * 3]
	refresh_market()

func select_item(index: int) -> void:
	var items: Array = bag_items() if bag_mode else STATE.SHOP[category_index]
	var offset := bag_page * 3 + index if bag_mode else index
	if offset >= items.size():
		return
	selected_food = items[offset]
	feedback = STATE.FOOD[selected_food]["description"]
	refresh_market()

func quantity_changed(_value: float) -> void:
	if not refreshing and ui.active_facility == "Market":
		refresh_active()

func refresh_market() -> void:
	var was_refreshing := refreshing
	refreshing = true
	ui._choose("Market/Catalog", "Category", 3, -1 if bag_mode else category_index)
	var bag := node("Market/Catalog/BagTab") as Button
	bag.toggle_mode = true
	bag.set_pressed_no_signal(bag_mode)
	var items: Array = bag_items() if bag_mode else STATE.SHOP[category_index]
	var pages := maxi(1, ceili(items.size() / 3.0)) if bag_mode else 1
	bag_page = clampi(bag_page, 0, pages - 1)
	if bag_mode and not items.has(selected_food):
		selected_food = "" if items.is_empty() else items[bag_page * 3]
	text("Market/Catalog/StockHeading", "YOUR FOOD BAG" if bag_mode else "FOOD STALL / " + STATE.CATEGORIES[category_index])
	for i in range(3):
		var row := node("Market/Catalog/Item" + str(i)) as Button
		var index := bag_page * 3 + i if bag_mode else i
		row.visible = index < items.size() or (items.is_empty() and i == 0)
		row.disabled = index >= items.size()
		row.toggle_mode = true
		row.set_pressed_no_signal(index < items.size() and items[index] == selected_food)
		if index >= items.size():
			row.get_node("Icon").hide()
			row.get_node("Name").text = "NO FOOD YET"
			row.get_node("Kind").text = "BUY FOOD OR HARVEST YOUR CROPS"
			row.get_node("Price").text = ""
			continue
		var item: String = items[index]
		var info: Dictionary = STATE.FOOD[item]
		row.get_node("Icon").show()
		row.get_node("Icon").texture = food_texture(item)
		row.get_node("Name").text = info["name"]
		row.get_node("Kind").text = "OWNED / %d" % state.food_bag[item] if bag_mode else "STOCK / %d" % state.shop_stock[item]
		row.get_node("Price").text = "FOOD BAG" if bag_mode else "%d CREDITS" % info["price"]
	text("Market/Catalog/Page", "PAGE %d / %d" % [bag_page + 1 if bag_mode else 1, pages])
	node("Market/Catalog/Previous").disabled = not bag_mode or bag_page == 0
	node("Market/Catalog/Next").disabled = not bag_mode or bag_page >= pages - 1
	var quantity := node("Market/Purchase/Quantity") as SpinBox
	quantity.editable = not bag_mode
	node("Market/Purchase/FoodArt").visible = not selected_food.is_empty()
	if selected_food.is_empty():
		text("Market/Purchase/Name", "FOOD BAG")
		text("Market/Purchase/Description", "HARVEST CROPS OR BUY FOOD TO FILL YOUR BAG.")
		text("Market/Purchase/Total", "TOTAL / --")
		text("Market/Purchase/Balance", "CREDITS / %d" % state.credits)
		node("Market/Purchase/Buy").disabled = true
		node("Market/Purchase/Use").disabled = true
	else:
		var info: Dictionary = STATE.FOOD[selected_food]
		quantity.max_value = maxi(1, mini(99, int(state.shop_stock[selected_food])))
		var cost := int(quantity.value) * int(info["price"])
		text("Market/Purchase/Name", info["name"])
		text("Market/Purchase/Description", info["effect"])
		node("Market/Purchase/FoodArt").texture = food_texture(selected_food)
		text("Market/Purchase/Balance", "CREDITS / %d  OWNED / %d" % [state.credits, state.food_bag[selected_food]])
		text("Market/Purchase/Total", "OWNED / %d" % state.food_bag[selected_food] if bag_mode else "TOTAL / %d CREDITS" % cost)
		node("Market/Purchase/Buy").text = "OPEN SHOP TO BUY" if bag_mode else "BUY FOOD"
		node("Market/Purchase/Buy").disabled = bag_mode or cost > state.credits or int(state.shop_stock[selected_food]) < int(quantity.value)
		node("Market/Purchase/Use").disabled = int(state.food_bag[selected_food]) <= 0
	refresh_status()
	refreshing = was_refreshing

func refresh_status() -> void:
	var status := "HP %d/%d / ST %d/%d" % [roundi(state.health), state.max_health, roundi(state.stamina), state.max_stamina]
	for buff in state.buffs:
		var name: String = {"speed": "SPD", "defense": "DEF", "regen": "REGEN", "stamina_regen": "ST REGEN"}[buff]
		status += " / %s %dS" % [name, ceili(state.buffs[buff]["remaining"])]
	text("Detail", feedback + "\n" + status)

func buy_food() -> void:
	if bag_mode or selected_food.is_empty():
		return
	feedback = state.purchase(selected_food, int(node("Market/Purchase/Quantity").value))
	refresh_market()

func use_food() -> void:
	if selected_food.is_empty():
		return
	feedback = state.consume(selected_food)
	refresh_market()
