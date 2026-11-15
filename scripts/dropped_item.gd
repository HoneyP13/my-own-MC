# scripts/dropped_item.gd
class_name DroppedItem
extends RigidBody3D

const PICKUP_RANGE := 0.7
const MAGNET_RANGE := 2.0
const DESPAWN_TIME := 300.0

var item_id: StringName
var count := 1
var _age := 0.0
var _retry := 0.0
var _model: MeshInstance3D

func _init() -> void:
	lock_rotation = true
	linear_damp = 1.0
	collision_layer = 4    # own layer, so attack rays and mobs ignore it
	collision_mask = 1     # lands on terrain
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 0.15
	add_child(shape)
	_model = MeshInstance3D.new()
	add_child(_model)

## Call after add_child().
func setup(id: StringName, n: int) -> void:
	item_id = id
	count = n
	var world := get_parent()
	var def := Registry.get_item(id)
	var lib_id := GridMap.INVALID_CELL_ITEM
	var block: BlockDef = null
	if def is BlockItemDef and def.id == def.block_id:   # not seeds, which place another block
		block = Registry.get_block(def.block_id)
	if block != null and not block.id in world.NEEDS_SUPPORT:
		lib_id = world.grid_map.mesh_library.find_item_by_name(block.mesh_name)
	if lib_id != GridMap.INVALID_CELL_ITEM:
		_model.mesh = world.grid_map.mesh_library.get_item_mesh(lib_id)
		_model.scale = Vector3.ONE * 0.25
		_model.set_instance_shader_parameter("as_item", 1.0)
	else:
		_model.mesh = ItemMesh.for_icon(def.icon)
		_model.scale = Vector3.ONE * 0.4

func _physics_process(delta: float) -> void:
	if global_position.y < -20.0: queue_free(); return
	var world := get_parent()
	_age += delta
	_retry -= delta
	_model.rotation.y += delta
	_model.position.y = 0.15 + sin(_age * 2.0) * 0.05
	if _age > DESPAWN_TIME:
		queue_free()
		return
	if _age < 0.5 or world.player.is_dead or _retry > 0.0: return   # delay, so a fresh drop isn't instantly vacuumed
	var to_player: Vector3 = world.player.global_position + Vector3.UP * 0.9 - global_position
	if to_player.length() < PICKUP_RANGE:
		count = world.hud.add_item(item_id, count)
		if count <= 0: queue_free()
		else: _retry = 0.3    # inventory full: try again shortly
	elif to_player.length() < MAGNET_RANGE:
		linear_velocity = to_player.normalized() * 6.0
