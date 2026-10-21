extends SceneTree
## Turns the Blender renders (Player/tools/blender/build_player.py) into a
## player sheet: snaps colours to the palette, adds a black outline and black
## lines where hair, skin and shorts meet.
##
##   godot --headless --path . --script res://Player/tools/make_sheet_from_renders.gd -- <render_dir> <out.png>
##
## Sheet rows (32 x 52 frames, 16 columns; walks use all 16, guard drops 8):
##   0 down: guard          1 up: walk (hands down)     2 side: guard
##   3 side: walk           4 side: guard up, halfway, down
##   5 down: walk           6 down: guard up, halfway, down

const W := 32
const H := 52
const COLS := 16
const GUARD_FRAMES := 8

# palette colour -> group; ink lines go between different groups
const PALETTE := {
	"d9b98a": "skin", "a8865a": "skin", "6b4f33": "skin",
	"5a5048": "hair", "2e2925": "hair", "171412": "hair",
	"7dffa6": "eye", "f4f0e0": "teeth", "c9c2ad": "teeth",
}
const INK := Color("010101")

var colors: Array[Color] = []
var groups: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	for h in PALETTE:
		colors.append(Color(h))
		groups.append(PALETTE[h])

	var walk := []
	for i in COLS:
		walk.append("walk%d" % i)
	var guard := []
	for i in GUARD_FRAMES:
		guard.append("guard_t%d" % i)
	var rows := [
		["down", ["guard"]],
		["up", walk],
		["side", ["guard"]],
		["side", walk],
		["side", guard],
		["down", walk],
		["down", guard],
	]
	var sheet := Image.create(W * COLS, H * rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for r in rows.size():
		var names: Array = rows[r][1]
		for c in names.size():
			var f := _frame("%s/%s_%s.png" % [dir, rows[r][0], names[c]])
			# bob by a whole pixel at full stride (the renders themselves never bob)
			var dip := 1 if names == walk and absf(sin(TAU * c / COLS)) > 0.7 else 0
			sheet.blit_rect(f, Rect2i(0, 0, W, H - dip), Vector2i(c * W, r * H + dip))
	var err := sheet.save_png(args[1])
	print("saved ", args[1], ": ", error_string(err))
	quit()


func _frame(path: String) -> Image:
	var src := Image.load_from_file(path)
	src.convert(Image.FORMAT_RGBA8)
	var g := []  # group index per pixel, -1 empty
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in H:
		for x in W:
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				g.append("")
				continue
			var best := 0
			for i in colors.size():
				if _dist(colors[i], c) < _dist(colors[best], c):
					best = i
			out.set_pixel(x, y, colors[best])
			g.append(groups[best])
	# outline around the silhouette
	var result := out.duplicate()
	for y in H:
		for x in W:
			var here: String = g[y * W + x]
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H:
					continue
				var there: String = g[n.y * W + n.x]
				if here == "" and there != "":
					result.set_pixel(x, y, INK)
				# inner line: paint the lower/right side of a group change
				elif here != "" and there != "" and here != there and (d.x > 0 or d.y > 0) \
						and not here in ["eye", "teeth"] and not there in ["eye", "teeth"]:
					result.set_pixel(n.x, n.y, INK)
	return result


func _dist(a: Color, b: Color) -> float:
	return (a.r - b.r) ** 2 + (a.g - b.g) ** 2 + (a.b - b.b) ** 2
