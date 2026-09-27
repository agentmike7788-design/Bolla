// Grass tufts (MultiMesh). Wind sway grows with blade height; lighting uses the
// ground normal so blades blend into the painted ground instead of flickering.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D patch_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float patch_scale = 0.05;
uniform vec4 patch_color : source_color = vec4(1.05, 1.0, 0.8, 1.0);
uniform float patch_strength = 0.0;
uniform float wind_strength = 0.06;
uniform float wind_speed = 1.6;
uniform float wrap = 0.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = VERTEX.y * VERTEX.y * 6.0;
	float t = TIME * wind_speed + world_pos.x * 0.7 + world_pos.z * 0.5;
	VERTEX.x += (sin(t) * 0.7 + sin(t * 2.3) * 0.3) * wind_strength * h;
	VERTEX.z += cos(t * 0.9) * wind_strength * 0.5 * h;
}

void fragment() {
	vec3 col = COLOR.rgb * tint.rgb;
	float pn = texture(patch_noise, world_pos.xz * patch_scale).r;
	col = mix(col, col * patch_color.rgb, smoothstep(0.45, 0.75, pn) * patch_strength);
	ALBEDO = col;
	// Light every blade (front and back face) like the ground beneath it.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float w = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += w * ATTENUATION * LIGHT_COLOR / PI;
}
