@tool
class_name MeshLibraryBaker
extends RefCounted
## Puts a multi-part Blockbench scene into a MeshLibrary as ONE item.
##
## Godot's own "Export as MeshLibrary" has two catches for models like your bed:
##   * it only takes the first mesh. Anything nested under it (the bed's four legs are children of the
##     mattress) is silently left out, and
##   * the item is named after the mesh NODE ("bed2", "bed"), not after the scene.
## This merges the whole scene into one mesh, names the item what you ask, shifts it so it sits on the
## floor of its cell, and gives it a box collision shape.
##
## Used by tools/add_beds_to_terrain_library.gd, but works for any scene (a lever, a door, a fence post...).


## Bake `scene_path` into `lib` as an item called `item_name` (replacing it if it already exists).
## `shift` moves the model inside its cell: Blockbench puts the floor at y = 0, but a GridMap cell's
## origin is its CENTRE, so models need to drop by half a cell. Returns the item id, or -1 on failure.
static func bake_scene_item(lib: MeshLibrary, scene_path: String, item_name: String, shift := Vector3(0, -0.5, 0)) -> int:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("MeshLibraryBaker: can't load '%s'" % scene_path)
		return -1
	var root := packed.instantiate() as Node3D
	var main: MeshInstance3D = null
	for child in root.get_children():
		if child is MeshInstance3D:
			main = child
			break
	if main == null:
		push_error("MeshLibraryBaker: '%s' has no MeshInstance3D directly under its root" % scene_path)
		root.free()
		return -1

	# Gather the main mesh plus everything nested under it, each with its transform relative to the main mesh.
	var parts: Array = []
	_collect(main, Transform3D.IDENTITY, parts)

	# Merge into one mesh. Parts that share a material share a surface; different materials stay separate.
	var groups: Array = []    # [{material, tool}]
	for part: Dictionary in parts:
		var mi: MeshInstance3D = part["node"]
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			var group: Dictionary = {}
			for g: Dictionary in groups:
				if g["material"] == mat:
					group = g
					break
			if group.is_empty():
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mat)
				group = {"material": mat, "tool": st}
				groups.append(group)
			(group["tool"] as SurfaceTool).append_from(mesh, s, part["xform"])
	var merged := ArrayMesh.new()
	for g: Dictionary in groups:
		(g["tool"] as SurfaceTool).commit(merged)

	# The item transform is the main mesh's own transform (that's what "Apply MeshInstance Transforms" does)
	# plus the drop to the floor of the cell.
	var item_xform := Transform3D(main.transform.basis, main.transform.origin + shift)
	var cell_aabb := item_xform * merged.get_aabb()
	var box := BoxShape3D.new()
	box.size = cell_aabb.size

	var id := lib.find_item_by_name(item_name)
	if id < 0:    # not in the library yet
		id = lib.get_last_unused_item_id()
		lib.create_item(id)
	lib.set_item_name(id, item_name)
	lib.set_item_mesh(id, merged)
	lib.set_item_mesh_transform(id, item_xform)
	lib.set_item_shapes(id, [box, Transform3D(Basis.IDENTITY, cell_aabb.get_center())])
	root.free()
	return id


static func _collect(node: Node3D, xform: Transform3D, out: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append({"node": node, "xform": xform})
	for child in node.get_children():
		if child is Node3D:
			_collect(child, xform * (child as Node3D).transform, out)
