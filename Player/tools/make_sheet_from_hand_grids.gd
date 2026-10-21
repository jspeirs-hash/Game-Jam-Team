extends SceneTree
## Builds a player sheet from hand-drawn pixel grids (one letter per pixel):
##   <dir>/front.txt, back.txt, side.txt (side faces right)
## and makes 8-frame walk cycles by lifting legs and swinging arms.
##
##   godot --headless --path . --script res://Player/tools/make_sheet_from_hand_grids.gd -- <dir> <out.png>
##
## Sheet: 32 x 52 frames, rows 0 down, 1 up, 2 side; column 0 is standing.

const W := 32
const H := 52
const FRAMES := 8
const FOOT_PADDING := 2

const PALETTE := {
	"O": "3b2414", "o": "5c3a22", "S": "9c6e45", "s": "c99a68", "L": "e3bb88",
	"K": "2a160c", "D": "5a2f17", "H": "8a4a24", "h": "b0683a",
	"W": "f4f4ec", "G": "39c95a", "T": "f2ead6", "R": "c0302a",
}

# lift of [left leg, right leg] per frame, in pixels
const LIFT := [[0, 0], [1, 0], [2, 0], [1, 0], [0, 0], [0, 1], [0, 2], [0, 1]]
# side view: how far the near leg reaches forward at the foot
const STRIDE := [0, 2, 3, 2, 0, 2, 3, 2]  # legs look alike from the side


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var sheet := Image.create(W * FRAMES, H * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var views := ["front", "back", "side"]
	for row in 3:
		var base: Image = _grid(dir + "/" + views[row] + ".txt")
		var frames: Array[Image] = []
		var stride_path: String = dir + "/" + views[row] + "_stride.txt"
		if views[row] == "side" and FileAccess.file_exists(stride_path):
			# hand-drawn stride: stand, near leg forward, stand, far leg forward
			var stride := _grid(stride_path)
			frames = [base, stride, base, _swap_legs(stride)]
		else:
			for f in FRAMES:
				if views[row] == "side":
					frames.append(_side_step(base, STRIDE[f]))
				else:
					frames.append(_front_step(base, LIFT[f][0], LIFT[f][1]))
		for f in frames.size():
			var frame := frames[f]
			var at := Vector2i(f * W + (W - frame.get_width()) / 2, row * H + H - FOOT_PADDING - frame.get_height())
			sheet.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), at)
	var err := sheet.save_png(args[1])
	print("saved ", args[1], ": ", error_string(err))
	quit()


func _grid(path: String) -> Image:
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	var w := 0
	for l in lines:
		w = maxi(w, l.length())
	var img := Image.create(w, lines.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in lines.size():
		for x in lines[y].length():
			var ch: String = lines[y][x]
			if PALETTE.has(ch):
				img.set_pixel(x, y, Color(PALETTE[ch]))
	return img


## Swaps light and dark on the legs so the other leg reads as in front.
func _swap_legs(img: Image) -> Image:
	var out: Image = img.duplicate()
	var dark := Color(PALETTE["S"])
	var mid := Color(PALETTE["s"])
	var light := Color(PALETTE["L"])
	for y in range(_legs_top(img) - 1, img.get_height()):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.is_equal_approx(dark):
				out.set_pixel(x, y, mid)
			elif c.is_equal_approx(mid) or c.is_equal_approx(light):
				out.set_pixel(x, y, dark)
	return out


## First row (from the bottom) where the legs split, i.e. the crotch.
func _legs_top(img: Image) -> int:
	var mid := img.get_width() / 2
	var y := img.get_height() - 1
	while y > 0 and img.get_pixel(mid, y).a == 0.0:
		y -= 1
	return y + 1


## Front/back: shorten each lifted leg's shin and swing the opposite arm down.
func _front_step(base: Image, lift_l: int, lift_r: int) -> Image:
	var img: Image = base.duplicate()
	var w := img.get_width()
	var h := img.get_height()
	var top := _legs_top(base)
	var knee := top + (h - top) / 2
	for side in 2:
		var lift: int = [lift_l, lift_r][side]
		if lift == 0:
			continue
		var x0: int = 0 if side == 0 else w / 2 + 1
		var x1: int = w / 2 if side == 0 else w
		for x in range(x0, x1):
			for y in range(knee, h):
				var from: int = y + lift
				img.set_pixel(x, y, base.get_pixel(x, from) if from < h else Color(0, 0, 0, 0))
	# arms swing opposite to the legs: drop the arm on the lifted leg's other side
	var arm_drop := [lift_r > 0, lift_l > 0]
	for side in 2:
		if not arm_drop[side]:
			continue
		var x0: int = 0 if side == 0 else w - 5
		var x1: int = 5 if side == 0 else w
		var src: Image = img.duplicate()
		for x in range(x0, x1):
			for y in range(top - 14, top + 2):
				img.set_pixel(x, y, src.get_pixel(x, y - 1))
	return img


## Side: lean the legs forward/back from the hip, like a stride.
func _side_step(base: Image, stride: int) -> Image:
	if stride == 0:
		return base.duplicate() as Image
	var w := base.get_width()
	var h := base.get_height()
	var hip := h - 10
	var img := Image.create(w + 6, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.blit_rect(base.get_region(Rect2i(0, 0, w, hip)), Rect2i(0, 0, w, hip), Vector2i(3, 0))
	var split := 13 # columns left of this are the far leg
	# far leg first so the near leg draws over it
	for pass_i in 2:
		var near := pass_i == 1
		var amount := stride if near else -stride
		for y in range(hip, h):
			var t := float(y - hip) / float(h - 1 - hip)
			var dx := roundi(amount * t)
			for x in w:
				if (x >= split) != near:
					continue
				var c := base.get_pixel(x, y)
				if c.a > 0.0:
					img.set_pixel(x + 3 + dx, y, c)
	return img
