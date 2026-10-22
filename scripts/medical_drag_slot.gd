extends Button

@export var inventory_slot := -1
@export var item_id := ""

func _interface() -> CanvasLayer:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is CanvasLayer:
			return ancestor
		ancestor = ancestor.get_parent()
	return null

func _get_drag_data(_at_position: Vector2) -> Variant:
	var interface := _interface()
	var data: Variant = interface.medical_drag_data(inventory_slot, item_id)
	if data == null:
		return null
	var preview := TextureRect.new()
	preview.texture = interface.medical_texture(data["item_id"])
	preview.custom_minimum_size = Vector2(56, 56)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(0.75, 1.0, 0.75, 0.85)
	set_drag_preview(preview)
	return data

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return inventory_slot >= 0 and _interface().can_stage_medical(inventory_slot, data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_interface().stage_medical(inventory_slot, data)
