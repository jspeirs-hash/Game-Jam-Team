extends SceneTree
## Builds a player sheet by putting our character's head and hair onto the
## frames of an RPG walk base.
##
##   godot --headless --path . --script res://Player/tools/make_sheet_from_base_frames.gd -- <base_dir> <hand_dir> <out.png>
##
## base_dir: base_<row>_<col>.png, rows 0 front, 1 back, 2 left, 3 right;
##           cols 0 step, 1 stand, 2 other step (base palette, see BASE_TO_OURS)
## hand_dir: front.txt, back.txt, side.txt pixel grids (side faces right);
##           the first HEAD_ROWS rows are the head, hair below is laid over the body
## Sheet: 32 x 52 frames, rows 0 down, 1 up, 2 side (right); columns are
## stand, step, stand, other step.

const W := 32
const H := 52
const FOOT_PADDING := 2
const HEAD_ROWS := 18

const PALETTE := {
	"O": "3b2414", "o": "5c3a22", "S": "9c6e45", "s": "c99a68", "L": "e3bb88",
	"K": "2a160c", "D": "5a2f17", "H": "8a4a24", "h": "b0683a",
	"W": "f4f4ec", "G": "39c95a", "T": "f2ead6", "R": "c0302a",
}
const HAIR := ["K", "D", "H", "h"]
# base colours -> our skin; eye colours on the body become skin too
const BASE_TO_OURS := {
	"5a341f": "O", "74462f": "o", "d58761": "S", "f8d3a7": "s", "fdeec7": "L",
	"afd2e6": "s", "155561": "s", "1b7188": "s", "dfecf4": "s", "1d7db9": "s",
}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var base_dir: String = a[0]
	var hand_dir: String = a[1]
	var front := _lines(hand_dir + "/front.txt")
	var back := _lines(hand_dir + "/back.txt")
	var side := _lines(hand_dir + "/side.txt")
	var sheet := Image.create(W * 4, H * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	# sheet row -> [base row, grid]
	var rows := [[0, front], [1, back], [3, side]]
	for r in rows.size():
		var order := [1, 0, 1, 2] # stand, step, stand, other step
		for c in order.size():
			var base := Image.load_from_file("%s/base_%d_%d.png" % [base_dir, rows[r][0], order[c]])
			base.convert(Image.FORMAT_RGBA8)
			var frame := _compose(base, rows[r][1])
			var at := Vector2i(c * W + (W - frame.get_width()) / 2, r * H + H - FOOT_PADDING - frame.get_height())
			sheet.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), at)
	var err := sheet.save_png(a[2])
	print("saved ", a[2], ": ", error_string(err))
	quit()


func _lines(path: String) -> PackedStringArray:
	return FileAccess.get_file_as_string(path).strip_edges().split("\n")


## Row where the base's head ends: the narrowest row below the widest head row.
func _neck_row(img: Image) -> int:
	var widths := []
	for y in mini(img.get_height(), 20):
		var n := 0
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				n += 1
		widths.append(n)
	var widest := 0
	for y in range(0, 14):
		if widths[y] >= widths[widest]:
			widest = y
	var neck := widest
	for y in range(widest, widths.size()):
		if widths[y] < widths[neck]:
			neck = y
	return neck


func _head_center(img: Image, rows: int) -> float:
	var lo := 999
	var hi := -1
	for y in rows:
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return (lo + hi) / 2.0


func _compose(base: Image, grid: PackedStringArray) -> Image:
	var neck := _neck_row(base)
	var center := _head_center(base, neck)
	var gw := grid[0].length()
	var body_h := base.get_height() - neck
	var out_w := maxi(gw, base.get_width()) + 8
	var out_h := HEAD_ROWS + body_h
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var head_x := out_w / 2 - gw / 2
	var body_x := head_x + gw / 2 - roundi(center)
	# body, recoloured to our skin
	for y in body_h:
		for x in base.get_width():
			var c := base.get_pixel(x, neck + y)
			if c.a == 0.0:
				continue
			var key: String = BASE_TO_OURS.get(c.to_html(false), "s")
			out.set_pixel(body_x + x, HEAD_ROWS + y, Color(PALETTE[key]))
	# head, then the hair that hangs below it
	for y in grid.size():
		var line: String = grid[y]
		for x in line.length():
			var ch := line[x]
			if not PALETTE.has(ch):
				continue
			if y >= HEAD_ROWS and not ch in HAIR:
				continue
			if y < out_h:
				out.set_pixel(head_x + x, y, Color(PALETTE[ch]))
	return out
