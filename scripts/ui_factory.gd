extends RefCounted
const FONT := preload("res://Battle/Art/secret_pixel.fnt")
const INK := Color("0b171e")
const TEXT := Color("e2e6d5")
const MUTED := Color("8ea7a8")
const GOLD := Color("d6b56b")

static func style(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	return s

static func panel(parent: Node, name: String, rect: Rect2) -> Panel:
	var node := Panel.new()
	node.name = name
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel",style(INK,Color("47606a")))
	parent.add_child(node)
	return node

static func label(parent: Node, name: String, rect: Rect2, text: String, size := 20, color := TEXT, wrap := false) -> Label:
	var node := Label.new()
	node.name = name
	node.position = rect.position
	node.size = rect.size
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

static func button(parent: Node, name: String, rect: Rect2, text: String, size := 18) -> Button:
	var node := Button.new()
	node.name = name
	node.position = rect.position
	node.size = rect.size
	node.text = text
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",TEXT)
	node.add_theme_color_override("font_disabled_color",Color("586b71"))
	node.add_theme_stylebox_override("normal",style(Color("172a31"),Color("617071")))
	var highlight := style(Color("293d39"),GOLD)
	for state in ["hover","focus","pressed"]:
		node.add_theme_stylebox_override(state,highlight)
	node.add_theme_stylebox_override("disabled",style(Color("111e25"),Color("30424b")))
	parent.add_child(node)
	return node

static func bar(parent: Node, name: String, rect: Rect2, color: Color) -> ProgressBar:
	var node := ProgressBar.new()
	node.name = name
	node.position = rect.position
	node.size = rect.size
	node.show_percentage = false
	node.add_theme_font_size_override("font_size",1)
	node.custom_minimum_size.y = rect.size.y
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("background",style(Color("070f17"),Color("47606a"),1))
	node.add_theme_stylebox_override("fill",style(color,color,0))
	node.size = rect.size
	parent.add_child(node)
	# Entering the tree resolves the theme's minimum height; apply the intended
	# thin bar height afterwards rather than keeping the default theme's size.
	node.size = rect.size
	return node
