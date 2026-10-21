extends SceneTree
## Turns a zoomed-in pixel-art picture into a player sheet with the same
## layout as player_sheet.png, saved as Player/art/player_sheet_local.png.
## That file is git-ignored: it's for art we can't ship without permission.
## The player uses it automatically when it exists.
##
##   godot --headless --path . --script res://Player/tools/make_sheet_from_picture.gd -- <picture> [facing]
##
## facing: "left" (default) if the character in the picture faces left.
## The picture has one pose, so every direction uses it (flipped for left),
## and walk frames bob and lift one leg.

const W := 32
const H := 52
const FOOT_PADDING := 2
const LIFT := 2


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("pass the picture path after --")
		quit(1)
		return
	var pic := Image.load_from_file(args[0])
	pic.convert(Image.FORMAT_RGBA8)
	var faces_left := args.size() < 2 or args[1] != "right"

	var pitch := _find_pitch(pic)
	var px := _find_phase(pic, pitch, true)
	var py := _find_phase(pic, pitch, false)
	var bg := pic.get_pixel(2, 2)
	print("pixel size %d, offset %d,%d" % [pitch, px, py])

	# sample the centre of every big pixel
	var cols := (pic.get_width() - px) / pitch
	var rows := (pic.get_height() - py) / pitch
	var small := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	for cy in rows:
		for cx in cols:
			var c := pic.get_pixel(px + cx * pitch + pitch / 2, py + cy * pitch + pitch / 2)
			if _diff(c, bg) < 0.12:
				c = Color(0, 0, 0, 0)
			small.set_pixel(cx, cy, c)
	var used := small.get_used_rect()
	small = small.get_region(used)
	if faces_left:
		small.flip_x() # the sheet's side row faces right
	print("character is %dx%d px" % [small.get_width(), small.get_height()])
	if small.get_width() > W or small.get_height() > H - FOOT_PADDING:
		push_error("character is bigger than the %dx%d frame" % [W, H])
		quit(1)
		return

	var frame := Image.create(W, H, false, Image.FORMAT_RGBA8)
	frame.fill(Color(0, 0, 0, 0))
	var dest := Vector2i((W - small.get_width()) / 2, H - FOOT_PADDING - small.get_height())
	frame.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), dest)

	var split := dest.x + small.get_width() / 2
	var leg_cut := dest.y + int(small.get_height() * 0.8)
	var sheet := Image.create(W * 4, H * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for row in 3:
		for col in 4:
			var step: int = [0, 1, 0, -1][col]
			var f := frame.duplicate()
			if step != 0:
				_lift(f, split if step == 1 else 0, W if step == 1 else split, leg_cut)
			sheet.blit_rect(f, Rect2i(0, 0, W, H), Vector2i(col * W, row * H + (1 if step != 0 else 0)))
	var err := sheet.save_png("res://Player/art/player_sheet_local.png")
	print("saved player_sheet_local.png: ", error_string(err))
	quit()


func _diff(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## Most common distance between colour changes along the rows = one big pixel.
func _find_pitch(img: Image) -> int:
	var hist := {}
	for y in range(0, img.get_height(), 5):
		var last := 0
		for x in range(1, img.get_width()):
			if _diff(img.get_pixel(x, y), img.get_pixel(x - 1, y)) > 0.3:
				var run := x - last
				if run >= 2:
					hist[run] = hist.get(run, 0) + 1
				last = x
	var best := 1
	for k in hist:
		if hist[k] > hist.get(best, 0):
			best = k
	return best


## Offset of the pixel grid: where colour changes line up best.
func _find_phase(img: Image, pitch: int, horizontal: bool) -> int:
	var scores := []
	scores.resize(pitch)
	scores.fill(0)
	var n := img.get_width() if horizontal else img.get_height()
	var m := img.get_height() if horizontal else img.get_width()
	for j in range(0, m, 5):
		for i in range(1, n):
			var a := img.get_pixel(i, j) if horizontal else img.get_pixel(j, i)
			var b := img.get_pixel(i - 1, j) if horizontal else img.get_pixel(j, i - 1)
			if _diff(a, b) > 0.3:
				scores[i % pitch] += 1
	var best := 0
	for p in pitch:
		if scores[p] > scores[best]:
			best = p
	return best


## Shortens the leg between columns x0..x1 below `cut` so the foot lifts.
func _lift(img: Image, x0: int, x1: int, cut: int) -> void:
	var src := img.duplicate()
	for x in range(x0, x1):
		for y in range(cut, H):
			var from := y + LIFT
			img.set_pixel(x, y, src.get_pixel(x, from) if from < H else Color(0, 0, 0, 0))
