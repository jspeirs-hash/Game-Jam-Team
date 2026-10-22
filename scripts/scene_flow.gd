extends CanvasLayer
var busy := false
var shade: ColorRect
func _ready() -> void:
	layer = 90
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01,0.02,0.03,0)
	add_child(shade)
	shade.hide()
func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	shade.show()
	get_viewport().gui_release_focus()
	var fade := create_tween()
	fade.tween_property(shade,"color:a",1.0,0.22)
	await fade.finished
	var result := get_tree().change_scene_to_file(path)
	if result!=OK:
		push_error("Scene could not be opened: "+path)
	await get_tree().process_frame
	fade = create_tween()
	fade.tween_property(shade,"color:a",0.0,0.32)
	await fade.finished
	shade.hide()
	busy = false
