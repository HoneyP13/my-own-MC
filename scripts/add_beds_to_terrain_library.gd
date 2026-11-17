@tool
extends EditorScript
## Adds the two bed halves to your terrain MeshLibrary as "bed_foot" and "bed_head".
##
## HOW: open this file in Godot's script editor and choose  File > Run  (Ctrl+Shift+X).
## It's safe to run again: it replaces the two items instead of adding duplicates.
## Commit to git first if you like; a copy of the library is also saved next to it as .bak.

# Edit these three paths if your files live somewhere else:
const LIBRARY := "res://assets/meshes/terrain_mesh_library.tres"
const BED_FOOT_SCENE := "res://scenes/bed_foot.tscn"
const BED_HEAD_SCENE := "res://scenes/bed_head.tscn"


func _run() -> void:
	var lib := load(LIBRARY) as MeshLibrary
	if lib == null:
		push_error("Can't load the terrain MeshLibrary at %s" % LIBRARY)
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(LIBRARY), ProjectSettings.globalize_path(LIBRARY) + ".bak")
	for pair in [[BED_FOOT_SCENE, "bed_foot"], [BED_HEAD_SCENE, "bed_head"]]:
		var id := MeshLibraryBaker.bake_scene_item(lib, pair[0], pair[1])
		if id < 0:
			push_error("Stopped: couldn't add %s, nothing was saved." % pair[1])
			return
		print("Added '%s' as item %d" % [pair[1], id])
	var err := ResourceSaver.save(lib, LIBRARY)
	print("Saved %s (%s)" % [LIBRARY, "ok" if err == OK else "error %d" % err])
