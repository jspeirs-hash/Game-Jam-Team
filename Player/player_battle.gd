class_name PlayerBattle
extends RefCounted
## Hooks the player into the battle screen (Battle/battle.tscn).
##
##   var battle = preload("res://Battle/battle.tscn").instantiate()
##   battle.auto_start = false
##   add_child(battle)
##   PlayerBattle.style_battle(battle)
##   battle.start_battle(PlayerBattle.make_unit(), enemy_unit)

## Same order as the overworld player: local-only art first, then the shared sheet.
const SHEETS := ["res://Player/art/player_sheet_local.png", "res://Player/art/player_sheet.png"]
const FRAME_SIZE := Vector2i(32, 52)
const SIDE_ROW := 2 ## side view, standing (guard pose when the sheet has one)
const BATTLE_SCALE := 4 ## art pixels -> texture pixels, so the sprite stays sharp
const UNIT_SCRIPT := "res://Battle/battle_unit.gd"


## The player as the battle screen expects it (a BattleUnit), with our sprite.
static func make_unit(unit_name := "Player", level := 5, max_hp := 40, attack := 12,
		defense := 9, speed := 10, move_name := "Strike", move_power := 45) -> Resource:
	var script: Script = load(UNIT_SCRIPT)
	var unit: Resource = script.new()
	unit.unit_name = unit_name
	unit.level = level
	unit.max_hp = max_hp
	unit.attack = attack
	unit.defense = defense
	unit.speed = speed
	unit.move_name = move_name
	unit.move_power = move_power
	unit.texture = battle_texture()
	return unit


## Side-view frame facing right (towards the enemy), cropped and enlarged
## with hard pixel edges.
static func battle_texture() -> Texture2D:
	var sheet: Image = null
	for path in SHEETS:
		if ResourceLoader.exists(path):
			sheet = (load(path) as Texture2D).get_image()
			break
	if sheet == null:
		return null
	sheet.decompress()
	var frame := sheet.get_region(Rect2i(Vector2i(0, SIDE_ROW * FRAME_SIZE.y), FRAME_SIZE))
	frame = frame.get_region(frame.get_used_rect())
	frame.resize(frame.get_width() * BATTLE_SCALE, frame.get_height() * BATTLE_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(frame)


## Keeps the battle sprites pixel-sharp instead of blurred when scaled.
static func style_battle(battle: Node) -> void:
	for sprite_name in ["%PlayerSprite", "%EnemySprite"]:
		var sprite := battle.get_node_or_null(sprite_name) as CanvasItem
		if sprite:
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
