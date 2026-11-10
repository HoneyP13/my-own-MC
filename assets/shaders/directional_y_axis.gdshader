shader_type spatial;
render_mode cull_back, vertex_lighting;

// Was meant for chests, I think I messed it up a little bit, but at least the code isn't mad at me :)

uniform sampler2D texture_top: source_color, repeat_enable, filter_nearest;  // the y axis
uniform sampler2D texture_side: source_color, repeat_enable, filter_nearest; // every other side face
uniform sampler2D texture_front: source_color, repeat_enable, filter_nearest; // facing the player


// Where the block's corner sits relative to the mesh origin. 0.5 = cube centred on its origin
// (a BoxMesh, or a cube made in Blender/Blockbench with the origin in the middle).
// Use 0.0 if your mesh has its origin at a corner.
uniform vec3 corner_offset = vec3(0.0);

varying vec3 block_pos;    // position inside the block, 0..1, in the block's own (unrotated) space
varying vec3 block_normal; // face towards player

void vertex() {
	block_pos = VERTEX + corner_offset;
	block_normal = NORMAL;
}

void fragment() {
	vec3 a = block_normal;
	vec3 albedo;
	if (a.x > a.z && a.x > 0.0) {
		albedo = texture(texture_side, 1.0 - block_pos.zy).rgb;
	} else if (a.z > a.x && a.z > 0.0) {
		albedo = texture(texture_front, 1.0 - block_pos.xy).rgb;
	} else if (a.x < a.z && a.x < 0.0) {
		albedo = texture(texture_side, 1.0 - block_pos.zy).rgb;
	} else if (a.z < a.x && a.z < 0.0) {
		albedo = texture(texture_side, 1.0 - block_pos.xy).rgb;
	} else {
		albedo = texture(texture_top, 1.0 - block_pos.xz).rgb;
	}
	ALBEDO = albedo;
}
