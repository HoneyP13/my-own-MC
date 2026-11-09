# scripts/registry.gd
extends Node

var items := {}            # StringName -> ItemDef
var blocks := {}           # StringName -> BlockDef
var blocks_by_mesh := {}   # mesh name -> BlockDef (to go from a hit cell back to its def)

func _ready() -> void:
	_load_dir("res://data/items", items)
	_load_dir("res://data/blocks", blocks)
	for b in blocks.values():
		blocks_by_mesh[b.mesh_name] = b

func _load_dir(path: String, into: Dictionary) -> void:
	for f in DirAccess.get_files_at(path):
		f = f.trim_suffix(".remap")          # exported builds rename resources
		if not f.ends_with(".tres"): continue
		var res = load(path + "/" + f)
		into[res.id] = res

func get_item(id: StringName) -> ItemDef:
	return items.get(id)
