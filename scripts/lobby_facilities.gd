extends CanvasLayer

const FACILITIES = {
	"Forge": ["THE FORGE", "UPGRADE EQUIPMENT / FORTIFY THE RESISTANCE", Color("dca15d")],
	"Infirmary": ["INFIRMARY", "RECOVERY AND FIELD SUPPORT", Color("c47870")],
	"ClassHall": ["CLASS HALL", "FIND YOUR ROLE IN THE RESISTANCE", Color("91aac6")],
	"Greenhouse": ["GREENHOUSE", "GROW A FUTURE INSIDE THE WALLS", Color("9db87e")],
	"Market": ["MARKET", "FRUIT / MEALS / DRINKS / RECOVERY", Color("d7b16c")],
	"AuctionHouse": ["AUCTION HOUSE", "BUY / SELL / MANAGE YOUR LISTINGS", Color("b49bd1")],
	"Deploy": ["DEPLOYMENT", "BEYOND THE WALLS / SECTOR 07", Color("e0aa64")]
}
const ROLES = [
	["VANGUARD", "FRONTLINE DEFENDER", "PROTECT YOUR TEAM AND HOLD THE FRONTLINE.", "SHIELD / HEAVY ARMOR\nBRACE / GUARD", [90, 35, 55]],
	["RANGER", "MOBILE MARKSMAN", "SCOUT AHEAD AND STRIKE AT MACHINE WEAK POINTS.", "RIFLE / LIGHT ARMOR\nSCOUT / PRECISION SHOT", [40, 90, 35]],
	["ENGINEER", "FIELD TECHNICIAN", "TURN SALVAGE INTO TOOLS THAT CONTROL THE BATTLEFIELD.", "TOOL KIT / FIELD GEAR\nDEPLOY / REPAIR", [60, 55, 85]],
	["MEDIC", "SQUAD SUPPORT", "KEEP THE RESISTANCE ALIVE AND BRING YOUR TEAM HOME.", "MED KIT / FIELD GEAR\nRECOVER / STABILIZE", [35, 65, 95]]
]
const ZONES = [
	["OUTER WALL", "LOW", "SCOUT THE APPROACHES AND SECURE A SAFE ROUTE HOME."],
	["SCRAPYARD", "MODERATE", "SEARCH THE RUINS FOR MATERIALS AND RECOVER USEFUL SALVAGE."],
	["RELAY TOWER", "HIGH", "RECON THE MACHINE RELAY AND IDENTIFY ITS DEFENSES."]
]
const MEDICINE = {
	"bandage": ["BANDAGES", 12, "CLEAN BANDAGES FOR BASIC FIELD CARE.", 0, "BNDG"],
	"herbs": ["HERBAL REMEDY", 18, "HERBS CULTIVATED INSIDE THE CITADEL.", 1, "HERB"],
	"antiseptic": ["ANTISEPTIC", 16, "CLEANING SUPPLIES FOR FIELD TREATMENT.", 2, "ANTI"],
	"medkit": ["FIELD MED KIT", 35, "A PACKED KIT OF ESSENTIAL MEDICAL SUPPLIES.", 3, "KIT"]
}
@onready var overlay: Control = $Overlay
@onready var window: Panel = $Overlay/Window
var active_facility := ""
var previous_focus: Control
var role_index := 0
var zone_index := 0
var auction_index := 0
var outpost = preload("res://scripts/outpost_state.gd").new()
var food_ui: RefCounted
var medical_credits: int:
	get:
		return outpost.credits
	set(value):
		outpost.credits = value
var medical_inventory: Array[String] = []
var pending_medical: Dictionary = {}
var medical_stock := {"bandage": 5, "herbs": 5, "antiseptic": 5, "medkit": 5}

func _ready() -> void:
	var buttons := get_parent().get_node("BuildingButtons")
	for facility in FACILITIES:
		for suffix in ["Building", "Sign"]:
			buttons.get_node(facility + suffix).pressed.connect(open_facility.bind(facility))
	_connect("Close", close_facility)
	$Overlay/Shade.gui_input.connect(_shade_input)
	for i in range(12):
		medical_inventory.append("")
		_connect("Infirmary/Inventory/Slot" + str(i), _medical_slot_clicked.bind(i))
		window.get_node("Infirmary/Inventory/Slot" + str(i)).gui_input.connect(_medical_slot_input.bind(i))
	for item in MEDICINE:
		_connect("Infirmary/Cabinet/Supply" + str(MEDICINE[item][3]), _medical_info.bind(item))
	_connect("Infirmary/Workbench/Buy", _medical_buy)
	_connect("Infirmary/Workbench/Cancel", _medical_clear)
	for i in range(4):
		_connect("ClassHall/Roster/Role" + str(i), _select_role.bind(i))
	_connect("ClassHall/Dossier/Loadout", _view_loadout)
	for i in range(3):
		_connect("AuctionHouse/Tab" + str(i), _auction_tab.bind(i))
		_connect("Deploy/Map/Zone" + str(i), _select_zone.bind(i))
	window.get_node("AuctionHouse/Browse/Exchange/Search").text_changed.connect(_search_changed)
	food_ui = preload("res://scripts/food_and_garden.gd").new(self, outpost)
	# SpinBox text fields use the same pixel font and frame as the rest of the UI.
	var reference := window.get_node("Close") as Button
	for spin in window.find_children("*", "SpinBox", true, false):
		var field: LineEdit = spin.get_line_edit()
		field.add_theme_font_override("font", reference.get_theme_font("font"))
		field.add_theme_font_size_override("font_size", 16)
		field.add_theme_color_override("font_color", Color("e6dfc6"))
		field.add_theme_stylebox_override("normal", reference.get_theme_stylebox("normal"))
		field.add_theme_stylebox_override("focus", reference.get_theme_stylebox("focus"))

func _process(delta: float) -> void:
	if food_ui != null:
		food_ui.advance(delta)

func _connect(path: String, callback: Callable) -> void:
	window.get_node(path).pressed.connect(callback)

func _text(path: String, value: String) -> void:
	window.get_node(path).text = value

func _choose(parent: String, prefix: String, count: int, index: int) -> void:
	for i in range(count):
		var button := window.get_node(parent + "/" + prefix + str(i)) as Button
		button.toggle_mode = true
		button.set_pressed_no_signal(i == index)

func open_facility(facility: String) -> void:
	if not FACILITIES.has(facility):
		return
	if not overlay.visible:
		previous_focus = get_viewport().gui_get_focus_owner()
	active_facility = facility
	for key in FACILITIES:
		window.get_node(key).visible = key == facility
	_text("Title", FACILITIES[facility][0])
	_text("Subtitle", FACILITIES[facility][1])
	$Overlay/Window/Accent.color = FACILITIES[facility][2]
	match facility:
		"Forge": _text("Detail", "SELECT EQUIPMENT FROM YOUR INVENTORY TO BEGIN")
		"Infirmary": _medical_refresh()
		"ClassHall": _select_role(role_index)
		"Greenhouse": food_ui.open_garden()
		"Market": food_ui.open_market()
		"AuctionHouse": _auction_tab(0)
		"Deploy": _select_zone(zone_index)
	window.get_node("Detail").add_theme_font_size_override("font_size", 14 if facility == "Market" else 16)
	overlay.show()
	window.get_node("Close").grab_focus()

func close_facility() -> void:
	overlay.hide()
	active_facility = ""
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if overlay.visible and event.is_action_pressed("ui_cancel"):
		close_facility()
		get_viewport().set_input_as_handled()

func _shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_facility()
		get_viewport().set_input_as_handled()

func medical_texture(item: String) -> Texture2D:
	return window.get_node("Infirmary/Cabinet/Supply" + str(MEDICINE[item][3]) + "/Icon").texture

func medical_drag_data(slot: int, item: String) -> Variant:
	if slot >= 0:
		if not pending_medical.has(slot):
			return null
		return {"kind": "medical_supply", "item_id": pending_medical[slot], "from_slot": slot}
	if not MEDICINE.has(item) or int(medical_stock[item]) <= _pending_count(item):
		return null
	return {"kind": "medical_supply", "item_id": item, "from_slot": -1}

func _pending_count(item: String) -> int:
	var count := 0
	for staged in pending_medical.values():
		if staged == item:
			count += 1
	return count

func can_stage_medical(slot: int, data: Variant) -> bool:
	if slot < 0 or slot >= medical_inventory.size() or not data is Dictionary:
		return false
	if data.get("kind") != "medical_supply" or not MEDICINE.has(data.get("item_id")):
		return false
	if not medical_inventory[slot].is_empty() or pending_medical.has(slot):
		return false
	var origin := int(data.get("from_slot", -1))
	if origin >= 0:
		return pending_medical.get(origin) == data["item_id"]
	return int(medical_stock[data["item_id"]]) > _pending_count(data["item_id"])

func stage_medical(slot: int, data: Variant) -> void:
	if not can_stage_medical(slot, data):
		return
	var origin := int(data.get("from_slot", -1))
	if origin >= 0:
		pending_medical.erase(origin)
	pending_medical[slot] = data["item_id"]
	_medical_refresh()
	_medical_info(data["item_id"])

func medical_cost() -> int:
	var cost := 0
	for item in pending_medical.values():
		cost += int(MEDICINE[item][1])
	return cost

func _medical_refresh() -> void:
	for i in range(medical_inventory.size()):
		var slot := window.get_node("Infirmary/Inventory/Slot" + str(i)) as Button
		var item: String = pending_medical.get(i, medical_inventory[i])
		var pending := pending_medical.has(i)
		slot.get_node("Icon").visible = not item.is_empty()
		slot.get_node("Pending").visible = pending
		slot.get_node("Name").text = "+" if item.is_empty() else MEDICINE[item][4]
		if not item.is_empty():
			slot.get_node("Icon").texture = medical_texture(item)
		slot.add_theme_stylebox_override("normal", slot.get_theme_stylebox("pressed") if pending else window.get_node("ClassHall/Roster/Role0").get_theme_stylebox("normal"))
	_text("Infirmary/Workbench/Credits", "CREDITS / %d" % medical_credits)
	_text("Infirmary/Workbench/CostPanel/Cost", "%d CREDITS" % medical_cost())
	window.get_node("Infirmary/Workbench/Buy").disabled = pending_medical.is_empty() or medical_cost() > medical_credits
	window.get_node("Infirmary/Workbench/Cancel").disabled = pending_medical.is_empty()
	for item in MEDICINE:
		var source := "Infirmary/Cabinet/Supply" + str(MEDICINE[item][3])
		_text(source + "/Price", "%d CR / STOCK %d" % [MEDICINE[item][1], medical_stock[item] - _pending_count(item)])
		window.get_node(source).disabled = int(medical_stock[item]) <= _pending_count(item)
	_text("Detail", "DRAG SUPPLIES LEFT / GREEN MEANS PENDING / RIGHT CLICK TO REMOVE" if medical_cost() <= medical_credits else "NOT ENOUGH CREDITS / REMOVE ITEMS BEFORE BUYING")

func _medical_info(item: String) -> void:
	if MEDICINE.has(item):
		_text("Infirmary/Workbench/Info/Name", MEDICINE[item][0])
		_text("Infirmary/Workbench/Info/Description", MEDICINE[item][2])

func _medical_slot_clicked(slot: int) -> void:
	var item: String = pending_medical.get(slot, medical_inventory[slot])
	_medical_info(item)

func _medical_slot_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and pending_medical.has(slot):
		pending_medical.erase(slot)
		_medical_refresh()
		window.get_node("Infirmary/Inventory/Slot" + str(slot)).accept_event()

func _medical_clear() -> void:
	pending_medical.clear()
	_medical_refresh()

func _medical_buy() -> void:
	var cost := medical_cost()
	if pending_medical.is_empty() or cost > medical_credits:
		return
	# Validate the whole purchase before changing any balance or inventory slot.
	for item in MEDICINE:
		if _pending_count(item) > int(medical_stock[item]):
			return
	for slot in pending_medical:
		if not medical_inventory[slot].is_empty():
			return
	var count := pending_medical.size()
	for slot in pending_medical:
		var item: String = pending_medical[slot]
		medical_inventory[slot] = item
		medical_stock[item] -= 1
	medical_credits -= cost
	pending_medical.clear()
	_medical_refresh()
	_text("Detail", "PURCHASE COMPLETE / %d ITEMS / %d CREDITS" % [count, cost])

func _select_role(index: int) -> void:
	role_index = index
	_choose("ClassHall/Roster", "Role", 4, index)
	var role: Array = ROLES[index]
	_text("ClassHall/Hero/RoleName", role[0])
	_text("ClassHall/Hero/RoleTag", role[1])
	_text("ClassHall/Hero/Equipment", role[3])
	_text("ClassHall/Dossier/Description", role[2])
	window.get_node("ClassHall/Hero/Mannequin").modulate = [Color("b7cfdf"), Color("9cbf90"), Color("dbb97a"), Color("deb1ad")][index]
	for i in range(3):
		window.get_node("ClassHall/Dossier/Stat" + str(i)).value = role[4][i]
	_text("Detail", role[0] + " / ARCHETYPE STRENGTHS / " + role[1])

func _view_loadout() -> void:
	_text("Detail", ROLES[role_index][0] + " / " + ROLES[role_index][3].replace("\n", " / "))

func _auction_tab(index: int) -> void:
	auction_index = index
	_choose("AuctionHouse", "Tab", 3, index)
	for i in range(3):
		window.get_node("AuctionHouse/" + ["Browse", "Sell", "Mine"][i]).visible = i == index
	_text("Detail", ["THE EXCHANGE / SEARCH FOR ITEMS OFFERED BY THE RESISTANCE", "CREATE A LISTING / CHOOSE AN INVENTORY ITEM AND SET YOUR ASKING PRICE", "MY LISTINGS / TRACK YOUR OFFERS AND SALES"][index])

func _search_changed(query: String) -> void:
	var search := window.get_node("AuctionHouse/Browse/Exchange/Search") as LineEdit
	var cursor := search.caret_column
	if search.text != query.to_upper():
		search.text = query.to_upper()
		search.caret_column = cursor
	_text("AuctionHouse/Browse/Exchange/Empty", "NO LISTINGS AVAILABLE" if query.is_empty() else "NO MATCHING LISTINGS")

func _select_zone(index: int) -> void:
	zone_index = index
	_choose("Deploy/Map", "Zone", 3, index)
	_text("Deploy/Briefing/ZoneName", ZONES[index][0])
	_text("Deploy/Briefing/Threat", "THREAT / " + ZONES[index][1])
	_text("Deploy/Briefing/Objective", ZONES[index][2])
	window.get_node("Deploy/Briefing/Threat").add_theme_color_override("font_color", [Color("a5cb95"), Color("d6b273"), Color("d48074")][index])
	_text("Detail", "SECTOR 07 / " + ZONES[index][0] + " / REVIEW YOUR LOADOUT BEFORE DEPLOYING")
