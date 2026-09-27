// "Gemaltes Diorama" base shader (mat_painted, mat_ground): hand-painted colour and the
// painterly light of painted_common.gdshaderinc. Static – no TIME, no discard – so shadow maps
// of static lights stay cached. Foliage (wind, leafy edges) uses painted_foliage.gdshader.
shader_type spatial;
render_mode cull_back;

#include "res://assets/shaders/painted_common.gdshaderinc"

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ALBEDO = painted_colour(COLOR.rgb, world_pos, world_normal);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.15;
}
