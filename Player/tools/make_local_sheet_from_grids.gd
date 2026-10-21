extends SceneTree
## Builds Player/art/player_sheet_local.png from pixel grids in
## Player/art/local/ (git-ignored, like the sheet it makes):
##   side_guard.txt  side view, fists up      (idle)
##   side_mid.txt    side view, hands halfway (guard dropping / rising)
##   side_down.txt   side view, hands down    (walking)
##   back.txt        back view                (walking up)
##
##   godot --headless --path . --script res://Player/tools/make_local_sheet_from_grids.gd
##
## Sheet rows (32 x 52 frames, 4 columns):
##   0 down:  guard pose stand/step     1 up: back view stand/step
##   2 side:  guard pose stand/step     3 side, hands down: stand/step (walk)
##   4 guard: up, halfway, down

const W := 32
const H := 52
const LIFT := 2
const LEG_CUT := 43 # shin rows below this get shortened on step frames
const DIR := "res://Player/art/local/"

const PALETTE := {
	"K": "010101", "H": "f3f2b1", "Y": "c19458", "B": "6a3913",
	"S": "f7ddc6", "M": "c1789a", "P": "6b2151",
	"W": "ffffff", "C": "5bd7ef", "G": "9ea9ba", "g": "576271",
	"k": "0e2e21", "m": "155236", "n": "108351",
}


func _init() -> void:
	var guard := _grid("side_guard")
	var mid := _grid("side_mid")
	var down := _grid("side_down")
	var back := _grid("back")
	if guard == null or mid == null or down == null or back == null:
		quit(1)
		return
	var sheet := Image.create(W * 4, H * 5, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	_walk_row(sheet, 0, guard)
	_walk_row(sheet, 1, back)
	_walk_row(sheet, 2, guard)
	_walk_row(sheet, 3, down)
	for i in 3:
		sheet.blit_rect([guard, mid, down][i], Rect2i(0, 0, W, H), Vector2i(i * W, 4 * H))
	var err := sheet.save_png("res://Player/art/player_sheet_local.png")
	print("saved player_sheet_local.png: ", error_string(err))
	quit()


func _walk_row(sheet: Image, row: int, base: Image) -> void:
	for col in 4:
		var step: int = [0, 1, 0, -1][col]
		var f := base.duplicate()
		if step == 1:
			_lift(f, W / 2, W)
		elif step == -1:
			_lift(f, 0, W / 2)
		sheet.blit_rect(f, Rect2i(0, 0, W, H), Vector2i(col * W, row * H + (1 if step != 0 else 0)))


func _grid(name: String) -> Image:
	var path := DIR + name + ".txt"
	if not FileAccess.file_exists(path):
		push_error("missing " + path)
		return null
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in mini(lines.size(), H):
		var line: String = lines[y]
		for x in mini(line.length(), W):
			if PALETTE.has(line[x]):
				img.set_pixel(x, y, Color(PALETTE[line[x]]))
	return img


func _lift(img: Image, x0: int, x1: int) -> void:
	var src := img.duplicate()
	for x in range(x0, x1):
		for y in range(LEG_CUT, H):
			var from := y + LIFT
			img.set_pixel(x, y, src.get_pixel(x, from) if from < H else Color(0, 0, 0, 0))
