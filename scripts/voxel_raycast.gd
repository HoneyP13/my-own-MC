class_name VoxelRaycast
extends RefCounted
## Walks a ray through a GridMap one cell at a time and reports the first filled cell it enters
## (the "voxel DDA" / Amanatides-Woo algorithm).
##
## Unlike a physics RayCast3D it doesn't need collision shapes, so it can target flowers, short
## grass, glass, water... anything that has a cell item. It also knows which face the ray came in
## through, so there's no need to nudge the hit point to work out which side of the block it's on.
##
## Usage:
##     var hit := VoxelRaycast.cast_ray(grid_map, origin, direction, reach)
##     if hit:
##         print(hit.cell, " ", hit.normal, " ", hit.place_cell)


## What a successful cast found.
class Hit:
	## The cell that was hit, in GridMap cell coordinates.
	var cell: Vector3i
	## The face of that cell the ray came in through, as a unit step pointing AWAY from the block:
	## (0, 1, 0) is the top face, (-1, 0, 0) is the face on the -X side, and so on.
	## It's (0, 0, 0) in the rare case where the ray starts inside the block.
	var normal: Vector3i
	## The MeshLibrary item id of the block that was hit.
	var item: int
	## Where the ray touched the block, in world space.
	var point: Vector3
	## World-space distance from the ray's origin to `point`.
	var distance: float

	## The cell in front of the face that was hit: where a placed block would go.
	var place_cell: Vector3i:
		get:
			return cell + normal


## Casts a ray from `origin` along `direction` (both in world space) and returns a Hit for the
## first filled cell of `grid` within `max_distance` world units, or null if there isn't one.
static func cast_ray(grid: GridMap, origin: Vector3, direction: Vector3, max_distance: float) -> Hit:
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx():
		return null
	if not is_finite(max_distance) or max_distance < 0.0:
		return null
	direction = direction.normalized()

	# Work in "cell space": 1 unit = 1 cell, and cell (i, j, k) covers [i, i+1) x [j, j+1) x [k, k+1).
	# That's exactly how GridMap.local_to_map() turns positions into cells, and converting like this
	# takes care of cell_size and the GridMap's own transform.
	var o := grid.to_local(origin) / grid.cell_size
	var d := (grid.global_transform.basis.inverse() * direction) / grid.cell_size

	var cell := Vector3i(o.floor())
	var step := Vector3i.ZERO
	# How far along the ray (in world units) until it crosses the next cell boundary, per axis...
	var t_max := Vector3(INF, INF, INF)
	# ...and how far it travels between one boundary and the next, per axis.
	var t_delta := Vector3(INF, INF, INF)
	for axis in 3:
		if d[axis] > 0.0:
			step[axis] = 1
			t_delta[axis] = 1.0 / d[axis]
			t_max[axis] = (cell[axis] + 1 - o[axis]) / d[axis]
		elif d[axis] < 0.0:
			step[axis] = -1
			t_delta[axis] = -1.0 / d[axis]
			t_max[axis] = (cell[axis] - o[axis]) / d[axis]

	var normal := Vector3i.ZERO # the face we last came in through
	var t := 0.0                # distance travelled so far
	# A ray can only cross so many cell boundaries in max_distance, so this also acts as a safety net.
	var max_steps := int(ceil((absf(d.x) + absf(d.y) + absf(d.z)) * max_distance)) + 3
	for _i in max_steps:
		var item := grid.get_cell_item(cell)
		if item != GridMap.INVALID_CELL_ITEM:
			var hit := Hit.new()
			hit.cell = cell
			hit.normal = normal
			hit.item = item
			hit.point = origin + direction * t
			hit.distance = t
			return hit

		# Step into whichever neighbouring cell the ray reaches first.
		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			t = t_max.x
			t_max.x += t_delta.x
			cell.x += step.x
			normal = Vector3i(-step.x, 0, 0)
		elif t_max.y <= t_max.z:
			t = t_max.y
			t_max.y += t_delta.y
			cell.y += step.y
			normal = Vector3i(0, -step.y, 0)
		else:
			t = t_max.z
			t_max.z += t_delta.z
			cell.z += step.z
			normal = Vector3i(0, 0, -step.z)

		if t > max_distance:
			return null
	return null
