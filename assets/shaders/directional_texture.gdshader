shader_type spatial;
render_mode cull_back, vertex_lighting;

// Logs, pillars, anything with end caps on one pair of faces.
//
// The old version had a `direction` uniform. Uniforms live on the *material*, and every cell of the
// same MeshLibrary item shares that material, so changing it turned ALL of those blocks at once.
//
// This version works in the block's OWN space instead: texture_top is drawn on the block's local
// +Y / -Y faces and texture_side on the other four. Rotating a cell then turns the textures with
// it, so one MeshLibrary item covers every orientation:
//   - in the editor, rotate the GridMap cursor with A / S / D while painting
//   - in code, pass an orientation to GridMap.set_cell_item(cell, item, orientation)

uniform sampler2D texture_top: source_color, repeat_enable, filter_nearest;  // the end caps
uniform sampler2D texture_side: source_color, repeat_enable, filter_nearest; // the bark

// Where the block's corner sits relative to the mesh origin. 0.5 = cube centred on its origin
// (a BoxMesh, or a cube made in Blender/Blockbench with the origin in the middle).
// Use 0.0 if your mesh has its origin at a corner.
uniform vec3 corner_offset = vec3(0.5);

varying vec3 block_pos;    // position inside the block, 0..1, in the block's own (unrotated) space
varying vec3 block_normal; // face direction in the block's own space

void vertex() {
	block_pos = VERTEX + corner_offset;
	block_normal = NORMAL;
}

void fragment() {
	vec3 a = abs(block_normal);
	vec3 albedo;
	if (a.y > a.x && a.y > a.z) {
		albedo = texture(texture_top, 1.0 - block_pos.xz).rgb;
	} else if (a.x > a.z) {
		albedo = texture(texture_side, 1.0 - block_pos.zy).rgb;
	} else {
		albedo = texture(texture_side, 1.0 - block_pos.xy).rgb;
	}
	ALBEDO = albedo;
}
