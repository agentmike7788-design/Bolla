// Shared part of the "Gemaltes Diorama" shaders (painted.gdshader, painted_foliage.gdshader).
// Colour comes from Blender vertex paint (COLOR), modulated by a world-space brush noise so
// surfaces read as hand-painted. Lighting uses a soft wrapped terminator (painterly, not toon)
// plus a faint rim so silhouettes stay readable at night.
// No TIME here: a material whose vertex() uses TIME counts as animated, and every static
// light's shadow map in its range is then redrawn each frame (PERF-01) – only the foliage
// variant sways in the wind.

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D brush_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float brush_scale = 0.45;
uniform float brush_strength = 0.14;
uniform sampler2D patch_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float patch_scale = 0.05;
uniform vec4 patch_color : source_color = vec4(1.05, 1.0, 0.8, 1.0);
uniform float patch_strength = 0.0;
uniform float wrap = 0.35;
uniform float terminator_softness = 0.45;
uniform float rim_strength = 0.18;
uniform float roughness_value = 0.92;

varying vec3 world_pos;
varying vec3 world_normal;

float triplanar(sampler2D tex, vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy * s).r * w.x + texture(tex, p.xz * s).r * w.y + texture(tex, p.xy * s).r * w.z;
}

// Vertex paint × tint, brush strokes and large colour patches at world position p.
vec3 painted_colour(vec3 vertex_colour, vec3 p, vec3 n) {
	vec3 col = vertex_colour * tint.rgb;
	float b = triplanar(brush_noise, p, n, brush_scale);
	col *= mix(1.0 - brush_strength, 1.0 + brush_strength, b);
	float pn = texture(patch_noise, p.xz * patch_scale).r;
	return mix(col, col * patch_color.rgb, smoothstep(0.45, 0.75, pn) * patch_strength);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float soft = smoothstep(0.0, terminator_softness, w);
	float diffuse = mix(w, soft, 0.6);
	DIFFUSE_LIGHT += diffuse * ATTENUATION * LIGHT_COLOR / PI;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	DIFFUSE_LIGHT += rim * ATTENUATION * LIGHT_COLOR / PI * clamp(ndl + 0.6, 0.0, 1.0);
}
