# scripts/data/block_item_def.gd
class_name BlockItemDef
extends ItemDef

@export var block_id: StringName    # which BlockDef this places

func use_on_block(world: Node, hit: VoxelRaycast.Hit) -> bool:
	return world.place_block(block_id, hit)
