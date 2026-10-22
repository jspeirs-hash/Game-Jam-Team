class_name Battle
extends Control
## Turn-based battle: Attack / Defend / Item / Escape.
## Attach to the root of battle.tscn.
##
## Usage from your overworld:
##   var battle: Battle = preload("res://battle/battle.tscn").instantiate()
##   battle.auto_start = false
##   add_child(battle)
##   battle.battle_finished.connect(_on_battle_finished)
##   battle.start_battle(player_unit, enemy_unit, {"potion": 3})

## result is "win", "lose" or "escaped". player_unit keeps its remaining HP,
## items is the bag after the battle.
signal battle_finished(result: String, player_unit: BattleUnit, items: Dictionary)

const WIN := "win"
const LOSE := "lose"
const ESCAPED := "escaped"

enum Action { ATTACK, DEFEND, ITEM, ESCAPE }

## Add new items here. They show up in the Item menu when the bag has them.
const ITEMS := {
	"potion": {"name": "Potion", "heal": 20},
	"super_potion": {"name": "Super Potion", "heal": 50},
}

@export var player_data: BattleUnit
@export var enemy_data: BattleUnit
@export var starting_items: Dictionary = {"potion": 3, "super_potion": 1}
## Set to false for trainer / boss battles.
@export var can_escape := true
## If true, the battle starts by itself when the scene loads (handy for testing with F6).
@export var auto_start := true
@export var text_speed := 0.02
@export var message_pause := 0.7

var player: BattleUnit
var enemy: BattleUnit
var inventory: Dictionary = {}

var _escape_attempts := 0
var _battle_over := false

@onready var enemy_sprite: TextureRect = %EnemySprite
@onready var player_sprite: TextureRect = %PlayerSprite
@onready var enemy_name: Label = %EnemyName
@onready var enemy_hp_bar: ProgressBar = %EnemyHPBar
@onready var enemy_hp_label: Label = %EnemyHPLabel
@onready var player_name: Label = %PlayerName
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_label: Label = %PlayerHPLabel
@onready var message_label: Label = %MessageLabel
@onready var action_menu: GridContainer = %ActionMenu
@onready var attack_button: Button = %AttackButton
@onready var defend_button: Button = %DefendButton
@onready var item_button: Button = %ItemButton
@onready var escape_button: Button = %EscapeButton
@onready var item_menu: VBoxContainer = %ItemMenu


func _ready() -> void:
	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	item_button.pressed.connect(_on_item_pressed)
	escape_button.pressed.connect(_on_escape_pressed)
	_hide_menus()

	if auto_start:
		var p: BattleUnit = player_data
		var e: BattleUnit = enemy_data
		if p == null:
			p = _demo_unit("Player", 5, 40, 12, 9, 10, "Slash", 45, Color(0.3, 0.5, 0.9))
		if e == null:
			e = _demo_unit("AI machine", 4, 32, 9, 7, 6, "Splat", 40, Color(0.9, 0.35, 0.35))
		start_battle(p, e, starting_items)


func _unhandled_input(event: InputEvent) -> void:
	# Esc / B closes the item list.
	if item_menu.visible and event.is_action_pressed("ui_cancel"):
		_show_action_menu()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- public API

## Starts a battle. Units are duplicated, so your original resources are not
## modified; use the player_unit from battle_finished to keep the new HP.
func start_battle(p: BattleUnit, e: BattleUnit, items: Dictionary = {}) -> void:
	player = p.duplicate()
	enemy = e.duplicate()
	player.prepare()
	enemy.prepare()
	inventory = items.duplicate()
	_escape_attempts = 0
	_battle_over = false

	player_sprite.texture = _texture_for(player)
	enemy_sprite.texture = _texture_for(enemy)
	player_sprite.modulate = Color.WHITE
	enemy_sprite.modulate = Color.WHITE
	enemy_name.text = "%s  Lv%d" % [enemy.unit_name, enemy.level]
	player_name.text = "%s  Lv%d" % [player.unit_name, player.level]
	_update_hp(player, false)
	_update_hp(enemy, false)

	await _say("A wild %s appeared!" % enemy.unit_name)
	_begin_player_turn()


# ---------------------------------------------------------------- turn flow

func _begin_player_turn() -> void:
	player.is_defending = false
	enemy.is_defending = false
	await _say("What will %s do?" % player.unit_name, false)
	_show_action_menu()


func _run_turn(action: Action, item_id: String = "") -> void:
	_hide_menus()
	var enemy_action := _choose_enemy_action()
	var order: Array = [[true, action, item_id], [false, enemy_action, ""]]
	if not _player_goes_first(action, enemy_action):
		order.reverse()

	for step in order:
		await _perform(step[0], step[1], step[2])
		if _battle_over:
			return
	_begin_player_turn()


func _perform(is_player: bool, action: Action, item_id: String) -> void:
	var actor := player if is_player else enemy
	var target := enemy if is_player else player

	match action:
		Action.ATTACK:
			await _do_attack(actor, target)
		Action.DEFEND:
			await _do_defend(actor)
		Action.ITEM:
			await _do_item(item_id)
		Action.ESCAPE:
			await _do_escape()

	if _battle_over:
		return
	if enemy.is_fainted():
		await _end_battle(WIN)
	elif player.is_fainted():
		await _end_battle(LOSE)


## Defend, Item and Escape act before Attack (like Pokemon's priority moves).
## Same priority: faster unit goes first, ties are random.
func _player_goes_first(player_action: Action, enemy_action: Action) -> bool:
	var pp := _priority(player_action)
	var ep := _priority(enemy_action)
	if pp != ep:
		return pp > ep
	if player.speed != enemy.speed:
		return player.speed > enemy.speed
	return randf() < 0.5


func _priority(action: Action) -> int:
	return 0 if action == Action.ATTACK else 1


func _choose_enemy_action() -> Action:
	return Action.DEFEND if randf() < 0.2 else Action.ATTACK


# ---------------------------------------------------------------- actions

func _do_attack(actor: BattleUnit, target: BattleUnit) -> void:
	await _say("%s used %s!" % [actor.unit_name, actor.move_name])
	var result := actor.calculate_damage(target)
	await _shake(_sprite_of(target))
	target.take_damage(result["damage"])
	await _update_hp(target)
	if result["crit"]:
		await _say("A critical hit!")
	if result["blocked"]:
		await _say("%s's guard softened the blow!" % target.unit_name)


func _do_defend(actor: BattleUnit) -> void:
	actor.is_defending = true
	await _say("%s is defending!" % actor.unit_name)


func _do_item(item_id: String) -> void:
	var item: Dictionary = ITEMS[item_id]
	inventory[item_id] -= 1
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	await _say("You used a %s!" % item["name"])
	var healed := player.heal(item["heal"])
	await _update_hp(player)
	await _say("%s recovered %d HP!" % [player.unit_name, healed])


func _do_escape() -> void:
	await _say("You try to run away...")
	if _escape_succeeds():
		await _say("Got away safely!")
		await _end_battle(ESCAPED)
	else:
		await _say("Couldn't get away!")


func _escape_succeeds() -> bool:
	_escape_attempts += 1
	if player.speed >= enemy.speed:
		return true
	# Gen III style: faster player = better odds, every retry helps.
	var odds := int(player.speed * 128.0 / enemy.speed) + 30 * _escape_attempts
	return randi_range(0, 255) < odds


func _end_battle(result: String) -> void:
	_battle_over = true
	_hide_menus()
	match result:
		WIN:
			await _say("%s fainted!" % enemy.unit_name)
			await _fade_out(enemy_sprite)
			await _say("You won the battle!")
		LOSE:
			await _say("%s fainted!" % player.unit_name)
			await _fade_out(player_sprite)
			await _say("You lost the battle...")
	battle_finished.emit(result, player, inventory)


# ---------------------------------------------------------------- button handlers

func _on_attack_pressed() -> void:
	_run_turn(Action.ATTACK)


func _on_defend_pressed() -> void:
	_run_turn(Action.DEFEND)


func _on_item_pressed() -> void:
	for child in item_menu.get_children():
		item_menu.remove_child(child)
		child.queue_free()

	for id in inventory:
		var button := Button.new()
		button.text = "%s x%d" % [ITEMS[id]["name"], inventory[id]]
		button.custom_minimum_size = Vector2(220, 36)
		button.pressed.connect(_run_turn.bind(Action.ITEM, id))
		item_menu.add_child(button)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(220, 36)
	back.pressed.connect(_show_action_menu)
	item_menu.add_child(back)

	action_menu.hide()
	item_menu.show()
	item_menu.get_child(0).grab_focus()


func _on_escape_pressed() -> void:
	if not can_escape:
		_hide_menus()
		await _say("You can't escape from this battle!")
		_begin_player_turn()
		return
	_run_turn(Action.ESCAPE)


# ---------------------------------------------------------------- UI helpers

func _show_action_menu() -> void:
	item_menu.hide()
	action_menu.show()
	item_button.disabled = inventory.is_empty()
	attack_button.grab_focus()


func _hide_menus() -> void:
	action_menu.hide()
	item_menu.hide()


## Types the message out, then pauses (unless wait is false).
func _say(text: String, wait := true) -> void:
	message_label.text = text
	message_label.visible_ratio = 0.0
	var tween := create_tween()
	tween.tween_property(message_label, "visible_ratio", 1.0, maxf(text.length() * text_speed, 0.01))
	await tween.finished
	if wait:
		await get_tree().create_timer(message_pause).timeout


func _update_hp(unit: BattleUnit, animate := true) -> void:
	var is_player := unit == player
	var bar := player_hp_bar if is_player else enemy_hp_bar
	var label := player_hp_label if is_player else enemy_hp_label
	bar.max_value = unit.max_hp

	if animate:
		var tween := create_tween()
		tween.tween_property(bar, "value", unit.hp, 0.5)
		await tween.finished
	else:
		bar.value = unit.hp

	label.text = "HP %d/%d" % [unit.hp, unit.max_hp]
	var ratio := float(unit.hp) / float(unit.max_hp)
	if ratio > 0.5:
		bar.modulate = Color(0.4, 1.0, 0.4)
	elif ratio > 0.2:
		bar.modulate = Color(1.0, 0.85, 0.3)
	else:
		bar.modulate = Color(1.0, 0.35, 0.35)


func _sprite_of(unit: BattleUnit) -> TextureRect:
	return player_sprite if unit == player else enemy_sprite


func _shake(sprite: Control) -> void:
	var origin := sprite.position
	var tween := create_tween()
	for i in 3:
		tween.tween_property(sprite, "position:x", origin.x + 12.0, 0.04)
		tween.tween_property(sprite, "position:x", origin.x - 12.0, 0.04)
	tween.tween_property(sprite, "position:x", origin.x, 0.04)
	await tween.finished


func _fade_out(sprite: Control) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tween.finished


func _texture_for(unit: BattleUnit) -> Texture2D:
	if unit.texture:
		return unit.texture
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(unit.placeholder_color)
	return ImageTexture.create_from_image(image)


func _demo_unit(n: String, lvl: int, hp: int, atk: int, def: int, spd: int,
		move: String, power: int, color: Color) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_name = n
	u.level = lvl
	u.max_hp = hp
	u.attack = atk
	u.defense = def
	u.speed = spd
	u.move_name = move
	u.move_power = power
	u.placeholder_color = color
	return u
