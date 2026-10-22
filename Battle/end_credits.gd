extends Control

## Optional Inspector override for the scrolling credits.
@export_multiline var credits_text := ""
const DEFAULT_CREDITS := "CREATED BY\nJAYMIE\nTARO\nHARRISON\n\nAI ASSISTANCE\nCHATGPT\nCLAUDE\n\nBUILT WITH\nGODOT ENGINE\n\nMUSIC AND SOUND\nORIGINAL SYNTH SCORE\n\nADDITIONAL SOUND EFFECTS\nRE:ZERO\nRETURN BY DEATH\n\nVISUAL INSPIRATIONS\nADAM FROM RECORD OF RAGNAROK\nCYBERPUNK: EDGERUNNERS\nATOM FROM REAL STEEL\n\nFOR EVERYONE WHO KEPT FIGHTING"
var _scroll_time := 0.0
@onready var content: VBoxContainer = $Center/Content
@onready var replay: Button = $Center/Content/Buttons/Replay
@onready var lobby: Button = $Center/Content/Buttons/Lobby

func _ready() -> void:
	GameAudio.music("credits",1.6)
	GameAudio.ambience()
	$Center/Content/CreditsScroll/CreditsText.text = DEFAULT_CREDITS if credits_text.strip_edges().is_empty() else credits_text
	$Center/Content/CreditsScroll.visible = true
	$Center/Content/CreditsScroll.custom_minimum_size.y = 210
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment(){
 vec2 grid=floor(UV*vec2(200.0,112.0));
 float star=step(0.997,fract(sin(dot(grid,vec2(13.7,79.3)))*43758.5));
 float pulse=0.55+0.45*sin(TIME*0.5+grid.x);
 vec3 sky=mix(vec3(0.015,0.03,0.05),vec3(0.002,0.005,0.009),UV.y);
 COLOR=vec4(sky+star*pulse*vec3(0.38,0.42,0.38),1.0);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	$Black.material = material
	$Center.anchor_left = 0.34
	var memorial := Node2D.new()
	memorial.name = "AdamMemorial"
	memorial.set_script(preload("res://Battle/credits_memorial.gd"))
	add_child(memorial)
	move_child(memorial,$Black.get_index()+1)
	memorial.modulate.a = 0.0
	create_tween().tween_property(memorial,"modulate:a",1.0,1.6)
	replay.text = "NEW RUN"
	replay.tooltip_text = "CHOOSE A DIFFICULTY. UPGRADES AND REMAINING SUPPLIES ARE KEPT."
	lobby.text = "HIDEOUT"
	replay.pressed.connect(_play_again)
	lobby.pressed.connect(func(): SceneFlow.change_scene("res://Scene/lobby.tscn"))
	content.modulate.a = 0.0
	replay.disabled = true
	lobby.disabled = true
	var entrance := create_tween()
	entrance.tween_property(content,"modulate:a",1.0,1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await entrance.finished
	replay.disabled = false
	lobby.disabled = false
	lobby.grab_focus()

func _process(delta: float) -> void:
	_scroll_time += delta
	if _scroll_time>3.5:
		var scroll: ScrollContainer = $Center/Content/CreditsScroll
		var end := maxi(0,int(scroll.get_v_scroll_bar().max_value-scroll.size.y))
		scroll.scroll_vertical = mini(end,int((_scroll_time-3.5)*18.0))

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneFlow.change_scene("res://Scene/lobby.tscn")

func _play_again() -> void:
	RunState.rest_home()
	RunState.run_active = false
	RunState.stage = 0
	RunState.nightmare_cleared = false
	RunState.open_gate_on_return = true
	RunState.save_profile()
	SceneFlow.change_scene("res://Scene/lobby.tscn")
