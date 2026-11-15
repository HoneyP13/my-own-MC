class_name ItemMesh
extends RefCounted

static var _cache := {}

static func for_icon(tex: Texture2D, depth := 1.0 / 16.0) -> ArrayMesh:
	if _cache.has(tex): return _cache[tex]
	var img := tex.get_image()
	if img.is_compressed(): img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var s := 1.0 / w                  # one pixel, if the item is 1 unit wide
	var d := depth / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Front and back: one quad each; alpha scissor cuts out the empty pixels.
	_quad(st, [Vector3(-.5, .5, d), Vector3(.5, .5, d), Vector3(.5, -.5, d), Vector3(-.5, -.5, d)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], Vector3.BACK)
	_quad(st, [Vector3(.5, .5, -d), Vector3(-.5, .5, -d), Vector3(-.5, -.5, -d), Vector3(.5, -.5, -d)],
		[Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)], Vector3.FORWARD)
	for py in h:
		for px in w:
			if img.get_pixel(px, py).a < 0.5: continue
			var c := Vector2((px + 0.5) / w, (py + 0.5) / h)
			var uv := [c, c, c, c]
			var x0 := px * s - 0.5
			var x1 := x0 + s
			var y0 := 0.5 - py * s
			var y1 := y0 - s
			if py == 0 or img.get_pixel(px, py - 1).a < 0.5:
				_quad(st, [Vector3(x0, y0, -d), Vector3(x1, y0, -d), Vector3(x1, y0, d), Vector3(x0, y0, d)], uv, Vector3.UP)
			if py == h - 1 or img.get_pixel(px, py + 1).a < 0.5:
				_quad(st, [Vector3(x0, y1, d), Vector3(x1, y1, d), Vector3(x1, y1, -d), Vector3(x0, y1, -d)], uv, Vector3.DOWN)
			if px == 0 or img.get_pixel(px - 1, py).a < 0.5:
				_quad(st, [Vector3(x0, y0, -d), Vector3(x0, y0, d), Vector3(x0, y1, d), Vector3(x0, y1, -d)], uv, Vector3.LEFT)
			if px == w - 1 or img.get_pixel(px + 1, py).a < 0.5:
				_quad(st, [Vector3(x1, y0, d), Vector3(x1, y0, -d), Vector3(x1, y1, -d), Vector3(x1, y1, d)], uv, Vector3.RIGHT)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh.surface_set_material(0, mat)
	_cache[tex] = mesh
	return mesh

static func _quad(st: SurfaceTool, v: Array, uv: Array, n: Vector3) -> void:
	for i in [0, 1, 2, 0, 2, 3]:    # vertices are given top-left, top-right, bottom-right, bottom-left
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(v[i])
