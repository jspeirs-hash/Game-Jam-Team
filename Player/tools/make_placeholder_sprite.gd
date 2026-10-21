extends SceneTree
## Draws the player sprite sheet (Player/art/player_sheet.png).
## Run from the project folder:
##   godot --headless --path . --script res://Player/tools/make_placeholder_sprite.gd
##
## Sheet layout (keep the same layout when swapping in hand-drawn art):
##   frames are 24 x 36 px, 4 columns: 0 = stand, 1 = step, 2 = stand, 3 = other step
##   rows: 0 = facing down, 1 = facing up, 2 = facing right (left is flipped)
##   the feet stand 2 px above the bottom edge (room for the outline)

const W := 24
const H := 36
const COLS := 4
const ROWS := 3

# [highlight, base, shadow]; light comes from the top left
const SKIN := [Color("f7cf9f"), Color("e0a272"), Color("b0714a")]
const HAIR := [Color("fff3a6"), Color("f2c83c"), Color("c08e1c")]
const TANK := [Color("4d78a8"), Color("335582"), Color("213a5c")]
const PANTS := [Color("8c7b58"), Color("6a5b40"), Color("4a3f2c")]
const BOOTS := [Color("54402f"), Color("3a2a1f"), Color("241811")]
const BAND := [Color("ef5a44"), Color("cc3a28"), Color("8c2216")]
const GLOVE := [Color("4a4a52"), Color("34343a"), Color("222226")]
const BELT := Color("2a2622")
const BUCKLE := Color("e2bc52")
const EYE := Color("14141c")
const EYE_WHITE := Color("f4f4f4")
const OUTLINE := Color("0c0a0e")

var img: Image
var ox := 0
var oy := 0
var frame_top := 0


func _init() -> void:
	img = Image.create(W * COLS, H * ROWS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for col in COLS:
		var step: int = [0, 1, 0, -1][col]
		_frame(col, 0, step, _draw_down)
		_frame(col, 1, step, _draw_up)
		_frame(col, 2, step, _draw_side)
	_outline()
	DirAccess.make_dir_recursive_absolute("res://Player/art")
	var err := img.save_png("res://Player/art/player_sheet.png")
	print("saved player_sheet.png: ", error_string(err))
	quit()


func _frame(col: int, row: int, step: int, fn: Callable) -> void:
	ox = col * W
	frame_top = row * H
	oy = frame_top + 2
	fn.call(step)


# --- drawing helpers ---------------------------------------------------------

func px(x: int, y: int, c: Color) -> void:
	if x < 0 or x >= W or oy + y < frame_top or oy + y >= frame_top + H:
		return
	img.set_pixel(ox + x, oy + y, c)


func r(x: int, y: int, w: int, h: int, c: Color) -> void:
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			px(ix, iy, c)


## Shaded block: base fill, highlight on the top-left edge, shadow on the right/bottom.
func block(x: int, y: int, w: int, h: int, pal: Array, shade_bottom := true) -> void:
	r(x, y, w, h, pal[1])
	r(x, y, w - 1, 1, pal[0])
	r(x, y, 1, h - 1, pal[0])
	r(x + w - 1, y, 1, h, pal[2])
	if shade_bottom:
		r(x, y + h - 1, w, 1, pal[2])


# --- body parts ----------------------------------------------------------------

## Legs seen from front/back. step 1 = left leg forward, right leg lifted.
func legs_front(step: int) -> void:
	var lift_l := 2 if step == -1 else 0
	var lift_r := 2 if step == 1 else 0
	block(8, 25, 4, 5 - lift_l, PANTS, false)
	block(7, 29 - lift_l, 5, 3, BOOTS)
	block(12, 25, 4, 5 - lift_r, PANTS, false)
	block(12, 29 - lift_r, 5, 3, BOOTS)
	r(11, 25, 2, 2, PANTS[2]) # crotch shadow


func arm(x: int, y: int, flip: bool) -> void:
	# deltoid + bicep (4 wide), forearm (3 wide), fist in fingerless glove
	block(x, y, 4, 5, SKIN)
	var fx := x + (1 if flip else 0)
	block(fx, y + 5, 3, 3, SKIN)
	block(fx, y + 8, 3, 2, GLOVE)
	px(fx + (0 if flip else 2), y + 8, SKIN[1]) # knuckle showing


func torso_front() -> void:
	block(8, 15, 8, 9, TANK)
	# pecs and abs read through the shirt
	r(9, 18, 6, 1, TANK[2])
	r(11, 19, 2, 4, TANK[2])
	r(9, 15, 6, 1, SKIN[1]) # collarbones above the neckline
	r(10, 16, 4, 1, SKIN[2])
	r(8, 24, 8, 1, BELT)
	r(11, 24, 2, 1, BUCKLE)


## One tapered hair spike growing up from (cx, base). lean > 0 tilts it right.
func spike(cx: int, base: int, h: int, lean: float) -> void:
	for i in h:
		var w := 3 if i == 0 else (2 if i < h - 1 else 1)
		var x0 := cx - (w - 1) / 2 + roundi(lean * i / float(h))
		var y := base - 1 - i
		r(x0, y, w, 1, HAIR[1])
		px(x0, y, HAIR[0])
		if w > 1:
			px(x0 + w - 1, y, HAIR[2])


func hair_front() -> void:
	# spiky blond hair: a cap plus upward spikes
	block(7, 3, 10, 5, HAIR, false)
	spike(8, 4, 3, -2.0)
	spike(11, 4, 5, -1.0)
	spike(13, 4, 5, 1.0)
	spike(16, 4, 3, 2.0)
	r(6, 5, 1, 4, HAIR[1]) # side tufts
	r(17, 5, 1, 4, HAIR[2])
	r(8, 8, 2, 1, HAIR[1]) # fringe over the forehead
	r(13, 8, 3, 1, HAIR[2])


func headband_front() -> void:
	r(7, 7, 10, 1, BAND[1])
	px(7, 7, BAND[0])
	px(16, 7, BAND[2])


# --- directions --------------------------------------------------------------

func _draw_down(step: int) -> void:
	if step != 0:
		oy += 1 # body dips on step frames
	legs_front(step)
	torso_front()
	arm(4, 15 + (1 if step == -1 else 0), false)
	arm(16, 15 + (1 if step == 1 else 0), true)
	# neck and head
	r(10, 13, 4, 2, SKIN[2])
	block(8, 6, 8, 8, SKIN)
	hair_front()
	headband_front()
	# eyes, brows, mouth
	r(9, 9, 2, 1, HAIR[2])
	r(13, 9, 2, 1, HAIR[2])
	px(9, 10, EYE_WHITE)
	px(10, 10, EYE)
	px(13, 10, EYE)
	px(14, 10, EYE_WHITE)
	px(12, 11, SKIN[2]) # nose
	r(11, 12, 2, 1, SKIN[2])


func _draw_up(step: int) -> void:
	if step != 0:
		oy += 1
	legs_front(-step)
	block(8, 15, 8, 9, TANK)
	r(11, 16, 2, 7, TANK[2]) # spine shadow
	r(8, 24, 8, 1, BELT)
	arm(4, 15 + (1 if step == 1 else 0), false)
	arm(16, 15 + (1 if step == -1 else 0), true)
	r(10, 13, 4, 2, SKIN[2])
	# back of the head is all hair
	block(7, 3, 10, 11, HAIR)
	spike(8, 4, 3, -2.0)
	spike(11, 4, 5, -1.0)
	spike(13, 4, 5, 1.0)
	spike(16, 4, 3, 2.0)
	r(6, 5, 1, 5, HAIR[1])
	r(17, 5, 1, 5, HAIR[2])
	headband_front()
	# knot and tails at the back
	r(11, 7, 2, 2, BAND[2])
	r(11, 9, 1, 3, BAND[1])
	r(12, 9, 1, 2, BAND[2])


func _draw_side(step: int) -> void:
	if step != 0:
		oy += 1
	# far arm (behind the body), swings opposite
	var far := -2 * step
	block(10 + far, 16, 3, 5, SKIN)
	r(10 + far, 16, 3, 5, SKIN[2])
	block(10 + far, 21, 3, 3, GLOVE)
	# legs
	if step == 0:
		block(9, 25, 5, 4, PANTS, false)
		block(9, 29, 7, 3, BOOTS)
	else:
		var back := 6 if step == 1 else 7
		var front := 12 if step == 1 else 11
		block(back, 25, 4, 4, PANTS, false)
		r(back, 25, 4, 4, PANTS[2])
		block(back - 1, 29, 5, 3, BOOTS)
		block(front, 25, 4, 4, PANTS, false)
		block(front, 29, 6, 3, BOOTS)
	# torso, chest pushes forward
	block(8, 15, 7, 9, TANK)
	r(15, 16, 1, 3, TANK[1])
	px(15, 18, TANK[2])
	r(9, 24, 7, 1, BELT)
	# near arm, swings with the step
	var near := 2 * step
	block(10 + near, 15, 4, 5, SKIN)
	block(10 + near + (1 if near > 0 else 0), 20, 3, 3, SKIN)
	block(10 + near + (1 if near > 0 else 0), 23, 3, 2, GLOVE)
	# neck and head (facing right)
	r(11, 13, 3, 2, SKIN[2])
	block(9, 6, 8, 8, SKIN)
	px(17, 10, SKIN[1]) # nose
	px(17, 11, SKIN[2])
	r(14, 12, 2, 1, SKIN[2]) # mouth
	# hair swept back, spikes point up and to the left
	block(8, 3, 7, 6, HAIR, false)
	r(8, 8, 3, 3, HAIR[1])
	r(8, 9, 2, 2, HAIR[2])
	spike(14, 4, 4, 1.0)
	spike(11, 4, 5, -1.0)
	spike(9, 5, 4, -3.0)
	spike(8, 8, 3, -4.0)
	r(15, 4, 2, 2, HAIR[1])
	r(15, 6, 2, 1, HAIR[2]) # fringe
	r(9, 7, 8, 1, BAND[1])
	r(5, 8, 3, 1, BAND[2]) # headband tail flying back
	px(4, 9, BAND[2])
	r(14, 9, 2, 1, HAIR[2]) # brow
	px(15, 10, EYE)
	px(14, 10, EYE_WHITE)
	px(10, 10, SKIN[2]) # ear
	px(10, 11, SKIN[2])


func _outline() -> void:
	var src := img.duplicate()
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for x in img.get_width():
		for y in img.get_height():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in dirs:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x < 0 or n.y < 0 or n.x >= img.get_width() or n.y >= img.get_height():
					continue
				# don't bleed outlines across frame borders
				if n.x / W != x / W or n.y / H != y / H:
					continue
				if src.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break
