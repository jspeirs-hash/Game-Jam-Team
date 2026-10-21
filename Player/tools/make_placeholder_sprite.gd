extends SceneTree
## Draws the player sprite sheet (Player/art/player_sheet.png).
## Run from the project folder:
##   godot --headless --path . --script res://Player/tools/make_placeholder_sprite.gd
##
## Sheet layout (keep the same layout when swapping in hand-drawn art):
##   frames are 32 x 52 px, 4 columns: 0 = stand, 1 = step, 2 = stand, 3 = other step
##   rows: 0 = facing down, 1 = facing up, 2 = facing right (left is flipped)
##   the feet stand 2 px above the bottom edge (room for the outline)

const W := 32
const H := 52
const COLS := 4
const ROWS := 3

# 4-tone ramps: [highlight, base, shadow, deep shadow]; light from the top left
const SKIN := [Color("ffe2c4"), Color("f0b48c"), Color("c07c7c"), Color("7a3f5c")]
const HAIR := [Color("fff7cc"), Color("f2d064"), Color("c4903a"), Color("7c5022")]
const PANTS := [Color("5d70a8"), Color("3d4b7e"), Color("2a335a"), Color("1a1f3a")]
const BOOTS := [Color("7a5638"), Color("553a28"), Color("3a271c"), Color("241812")]
const BAND := [Color("ff7058"), Color("d83a28"), Color("962014"), Color("5a120c")]
const GLOVE := [Color("70707c"), Color("4a4a54"), Color("30303a"), Color("1e1e24")]
const BELT := Color("2c2420")
const BUCKLE := Color("e8c25a")
const EYE_WHITE := Color("f6f6f6")
const IRIS := Color("7fd8e8")
const INK := Color("100c14") # outline and inner lines

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
	# body dips 1 px on step frames
	oy = frame_top + 6 + (1 if step != 0 else 0)
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


## Shaded block: highlight on top/left, shadow on right/bottom, deep corner.
func blk(x: int, y: int, w: int, h: int, pal: Array) -> void:
	r(x, y, w, h, pal[1])
	r(x, y, w - 1, 1, pal[0])
	r(x, y, 1, h - 1, pal[0])
	r(x + w - 1, y + 1, 1, h - 1, pal[2])
	r(x + 1, y + h - 1, w - 1, 1, pal[2])
	px(x + w - 1, y + h - 1, pal[3])


func ink(x: int, y: int, w: int = 1, h: int = 1) -> void:
	r(x, y, w, h, INK)


## Tapered hair spike growing up from (cx, base). lean > 0 tilts it right.
func spike(cx: int, base: int, h: int, lean: float) -> void:
	for i in h:
		var w := maxi(1, roundi(5.0 * (1.0 - float(i) / h)))
		var x0 := cx - (w - 1) / 2 + roundi(lean * i / float(h))
		var y := base - 1 - i
		r(x0, y, w, 1, HAIR[1])
		px(x0, y, HAIR[0])
		if w > 1:
			px(x0 + w - 1, y, HAIR[2])
		if w > 3:
			px(x0 + w - 2, y, HAIR[2])
		if w > 2 and i % 3 == 1:
			px(x0 + 1, y, HAIR[3])


# --- shared parts ------------------------------------------------------------

## Legs from the front/back. step 1 = left leg forward, right leg lifted.
func legs_front(step: int) -> void:
	var lift_l := 3 if step == -1 else 0
	var lift_r := 3 if step == 1 else 0
	blk(10, 35, 6, 6 - lift_l, PANTS)
	blk(16, 35, 6, 6 - lift_r, PANTS)
	r(11, 37, 1, 3 - lift_l, PANTS[2]) # crease
	r(20, 37, 1, 3 - lift_r, PANTS[2])
	ink(15, 37, 2, 4 - mini(lift_l, lift_r)) # gap between the legs
	blk(9, 41 - lift_l, 7, 3, BOOTS)
	blk(16, 41 - lift_r, 7, 3, BOOTS)
	ink(9, 40 - lift_l, 7, 1)
	ink(16, 40 - lift_r, 7, 1)


## Muscular arm seen from front/back. flip mirrors it for the right side.
func arm_front(x: int, y: int, flip: bool) -> void:
	var outer := x if not flip else x + 4
	blk(x, y, 5, 4, SKIN) # deltoid
	blk(x, y + 4, 5, 5, SKIN) # bicep
	r(outer, y + 4, 1, 5, SKIN[2])
	r(x + 1, y + 4, 3, 1, SKIN[3])
	var fx := x + (1 if flip else 0)
	blk(fx, y + 9, 4, 4, SKIN) # forearm
	r(fx + (0 if flip else 3), y + 9, 1, 4, SKIN[2])
	ink(fx, y + 13, 4, 1) # glove cuff
	blk(fx - (0 if flip else 1), y + 14, 5, 3, GLOVE) # fist
	px(fx + 1, y + 14, SKIN[1])
	px(fx + (3 if flip else 2), y + 14, SKIN[1])


func band_front() -> void:
	r(9, 8, 14, 2, BAND[1])
	r(9, 8, 13, 1, BAND[0])
	r(21, 9, 2, 1, BAND[2])


# --- directions --------------------------------------------------------------

func _draw_down(step: int) -> void:
	legs_front(step)
	# belt
	r(10, 33, 12, 2, BELT)
	r(15, 33, 2, 2, BUCKLE)
	# torso
	blk(10, 20, 12, 13, SKIN)
	r(10, 20, 12, 1, SKIN[1])
	# traps and collarbones
	r(11, 20, 10, 1, SKIN[2])
	r(12, 21, 3, 1, SKIN[0])
	r(17, 21, 3, 1, SKIN[0])
	# pecs
	r(11, 22, 4, 3, SKIN[0])
	r(17, 22, 4, 3, SKIN[1])
	r(11, 25, 4, 1, SKIN[3])
	r(17, 25, 4, 1, SKIN[3])
	r(15, 22, 2, 4, SKIN[2]) # sternum
	ink(15, 25, 2, 1)
	# abs: 3 rows of 2
	for ay in [28, 30]:
		r(12, ay, 3, 1, SKIN[2])
		r(17, ay, 3, 1, SKIN[3])
	r(12, 27, 2, 1, SKIN[0])
	r(12, 29, 2, 1, SKIN[0])
	r(15, 26, 2, 7, SKIN[3])
	# obliques
	r(10, 26, 2, 6, SKIN[2])
	r(20, 26, 2, 6, SKIN[3])
	# arms swing opposite to legs
	arm_front(5, 20 + (1 if step == -1 else 0) - (1 if step == 1 else 0), false)
	arm_front(22, 20 + (1 if step == 1 else 0) - (1 if step == -1 else 0), true)
	ink(10, 24, 1, 8) # inner line between arm and body
	ink(21, 24, 1, 8)
	# neck
	blk(13, 17, 6, 4, SKIN)
	r(13, 19, 6, 1, SKIN[2])
	r(17, 17, 2, 3, SKIN[3])
	# head
	blk(10, 6, 12, 12, SKIN)
	r(10, 16, 2, 2, SKIN[2])
	r(20, 10, 2, 8, SKIN[2]) # jaw shadow
	r(13, 17, 6, 1, SKIN[3])
	ink(10, 12, 1, 2) # ears
	ink(21, 12, 1, 2)
	# eyes
	r(12, 11, 3, 1, HAIR[3]) # brows
	r(17, 11, 3, 1, HAIR[3])
	r(12, 12, 3, 2, EYE_WHITE)
	r(17, 12, 3, 2, EYE_WHITE)
	r(13, 12, 2, 2, IRIS)
	r(17, 12, 2, 2, IRIS)
	px(14, 12, INK)
	px(17, 12, INK)
	ink(12, 14, 3, 1)
	ink(17, 14, 3, 1)
	# nose and mouth
	px(16, 14, SKIN[2])
	px(16, 15, SKIN[3])
	r(15, 16, 3, 1, SKIN[2])
	_hair_front()
	band_front()


func _hair_front() -> void:
	blk(9, 3, 14, 5, HAIR)
	r(9, 7, 2, 5, HAIR[1]) # sideburns
	r(21, 7, 2, 5, HAIR[2])
	ink(9, 12, 2, 1)
	ink(21, 12, 2, 1)
	# fringe falling over the forehead, swept to one side
	r(11, 10, 4, 1, HAIR[1])
	px(12, 10, HAIR[0])
	r(17, 10, 5, 1, HAIR[2])
	r(19, 11, 3, 1, HAIR[2])
	r(11, 10, 3, 3, HAIR[1])
	px(11, 10, HAIR[0])
	r(13, 11, 1, 2, HAIR[2])
	ink(11, 13, 2, 1)
	spike(9, 7, 5, -5.0)
	spike(12, 5, 9, -3.0)
	spike(16, 5, 7, 0.0)
	spike(19, 5, 10, 2.0)
	spike(23, 7, 6, 5.0)
	# dark strokes inside the mane
	r(13, 5, 1, 2, HAIR[3])
	r(18, 4, 1, 3, HAIR[3])


func _draw_up(step: int) -> void:
	legs_front(-step)
	r(10, 33, 12, 2, BELT)
	# back
	blk(10, 20, 12, 13, SKIN)
	r(11, 21, 4, 4, SKIN[0]) # shoulder blades
	r(17, 21, 4, 4, SKIN[1])
	r(11, 25, 4, 1, SKIN[2])
	r(17, 25, 4, 1, SKIN[3])
	r(15, 20, 2, 13, SKIN[3]) # spine
	r(10, 26, 2, 6, SKIN[2]) # lats
	r(20, 26, 2, 6, SKIN[3])
	arm_front(5, 20 + (1 if step == 1 else 0) - (1 if step == -1 else 0), false)
	arm_front(22, 20 + (1 if step == -1 else 0) - (1 if step == 1 else 0), true)
	ink(10, 24, 1, 8)
	ink(21, 24, 1, 8)
	blk(13, 17, 6, 4, SKIN)
	r(15, 17, 2, 4, SKIN[2])
	# back of the head is all hair
	blk(9, 3, 14, 15, HAIR)
	r(11, 8, 1, 8, HAIR[2])
	r(15, 6, 1, 10, HAIR[3])
	r(19, 7, 1, 9, HAIR[2])
	r(10, 16, 12, 1, HAIR[2])
	ink(10, 17, 12, 1)
	spike(9, 7, 5, -5.0)
	spike(12, 5, 9, -3.0)
	spike(16, 5, 7, 0.0)
	spike(19, 5, 10, 2.0)
	spike(23, 7, 6, 5.0)
	band_front()
	# knot and tails
	blk(14, 8, 4, 3, BAND)
	r(14, 11, 2, 5, BAND[1])
	r(16, 11, 2, 4, BAND[2])
	ink(14, 16, 2, 1)


func _draw_side(step: int) -> void:
	# far arm, behind the body, swings opposite to the near arm
	var far := -3 * step
	r(14 + far, 21, 4, 9, SKIN[3])
	r(14 + far, 30, 4, 3, SKIN[2])
	blk(14 + far, 33, 4, 3, GLOVE)
	# legs
	if step == 0:
		blk(12, 35, 7, 6, PANTS)
		r(17, 36, 1, 4, PANTS[2])
		ink(12, 40, 9, 1)
		blk(12, 41, 9, 3, BOOTS)
	else:
		var back := 9 if step == 1 else 10
		var front := 16 if step == 1 else 15
		r(back, 35, 5, 6, PANTS[2])
		r(back + 4, 35, 1, 6, PANTS[3])
		ink(back - 1, 40, 7, 1)
		blk(back - 1, 41, 7, 3, BOOTS)
		r(back - 1, 41, 7, 3, BOOTS[2])
		blk(front, 35, 5, 6, PANTS)
		ink(front, 40, 8, 1)
		blk(front, 41, 8, 3, BOOTS)
		ink(front - 1, 36, 1, 4) # line between the legs
	r(11, 33, 10, 2, BELT)
	# torso, chest pushes forward to the right
	blk(11, 20, 9, 13, SKIN)
	blk(19, 21, 3, 5, SKIN) # pec
	r(19, 26, 3, 1, SKIN[3])
	r(17, 27, 2, 5, SKIN[2]) # abs edge
	r(11, 21, 2, 11, SKIN[2]) # back shading
	# near arm
	var near := 3 * step
	var ax := 13 + near
	var fx := ax + (1 if near > 0 else 0)
	blk(ax, 20, 6, 5, SKIN) # shoulder
	blk(ax, 25, 5, 5, SKIN)
	r(ax + 1, 25, 3, 1, SKIN[3])
	blk(fx, 30, 4, 3, SKIN)
	ink(fx, 33, 4, 1)
	blk(fx, 34, 5, 3, GLOVE)
	ink(ax - 1, 24, 1, 8) # line behind the arm
	# neck and head facing right
	blk(14, 17, 6, 4, SKIN)
	r(14, 17, 2, 4, SKIN[2])
	blk(12, 6, 11, 12, SKIN)
	r(12, 6, 3, 12, SKIN[2])
	blk(22, 12, 2, 3, SKIN) # nose
	r(22, 14, 2, 1, SKIN[2])
	r(19, 16, 3, 1, SKIN[3]) # mouth
	r(16, 17, 6, 1, SKIN[3]) # jaw
	ink(15, 11, 2, 3) # ear
	px(15, 12, SKIN[2])
	# eye
	r(19, 11, 3, 1, HAIR[3])
	r(19, 12, 3, 2, EYE_WHITE)
	r(20, 12, 2, 2, IRIS)
	px(21, 12, INK)
	ink(19, 14, 3, 1)
	# hair swept back
	blk(11, 3, 11, 6, HAIR)
	blk(9, 6, 6, 9, HAIR)
	r(9, 10, 3, 6, HAIR[2])
	r(12, 9, 2, 3, HAIR[1])
	r(17, 9, 5, 1, HAIR[2]) # fringe
	r(20, 10, 2, 1, HAIR[2])
	spike(19, 5, 6, 2.5)
	spike(15, 5, 8, -1.0)
	spike(11, 6, 7, -4.0)
	spike(9, 10, 6, -6.0)
	spike(9, 14, 5, -6.0)
	r(14, 5, 1, 3, HAIR[3])
	r(11, 8, 1, 4, HAIR[3])
	# headband with a tail flying back
	r(12, 8, 11, 2, BAND[1])
	r(13, 8, 9, 1, BAND[0])
	r(6, 9, 6, 2, BAND[2])
	r(3, 11, 4, 1, BAND[2])
	px(2, 12, BAND[3])


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
					img.set_pixel(x, y, INK)
					break
