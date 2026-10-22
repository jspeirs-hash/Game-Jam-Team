class_name BattleUnit
extends Resource
## Stats and runtime state for one combatant.
## Create a .tres of this resource for each monster / character.

@export var unit_name := "Monster"
@export var level := 5
@export var max_hp := 30
@export var attack := 10
@export var defense := 8
@export var speed := 8
@export var move_name := "Tackle"
@export var move_power := 40
## Sprite shown in battle. If empty, a coloured square is used instead.
@export var texture: Texture2D
@export var placeholder_color := Color.WHITE
## -1 means "full HP". Stored so HP carries over between battles.
@export_storage var hp := -1

## Reset at the start of every turn by the battle script.
var is_defending := false


## Call before a battle. Fills HP only if the unit has never been initialised.
func prepare() -> void:
	if hp < 0:
		hp = max_hp
	is_defending = false


func is_fainted() -> bool:
	return hp <= 0


func take_damage(amount: int) -> int:
	var before := hp
	hp = maxi(hp - amount, 0)
	return before - hp


func heal(amount: int) -> int:
	var before := hp
	hp = mini(hp + amount, max_hp)
	return hp - before


## Pokemon-style damage formula. Returns {damage, crit, blocked}.
func calculate_damage(target: BattleUnit) -> Dictionary:
	var crit := randf() < 1.0 / 16.0
	var base := ((2.0 * level / 5.0 + 2.0) * move_power * attack / maxf(target.defense, 1.0)) / 50.0 + 2.0
	var multiplier := randf_range(0.85, 1.0)
	if crit:
		multiplier *= 1.5
	var dmg := int(base * multiplier)
	var blocked := target.is_defending
	if blocked:
		dmg = int(dmg * 0.5)
	return {"damage": maxi(dmg, 1), "crit": crit, "blocked": blocked}
