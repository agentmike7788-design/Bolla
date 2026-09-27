// "Gemaltes Diorama" base shader.
// Colour comes from Blender vertex paint (COLOR), modulated by a world-space
// brush noise so surfaces read as hand-painted. Lighting uses a soft wrapped
// terminator (painterly, not toon) plus a faint rim so silhouettes stay
// readable at night. Optional wind sway for foliage.
shader_type spatial;
render_mode cull_back;

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
uniform float wind_strength = 0.0;
uniform float wind_speed = 1.1;
// Foliage: break up silhouettes into leafy edges and add leafy normal noise.
uniform float edge_breakup = 0.0;
uniform float edge_scale = 2.2;
uniform float leaf_normal_strength = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (wind_strength > 0.0) {
		float h = max(VERTEX.y - 2.0, 0.0);
		float t = TIME * wind_speed + world_pos.x * 0.35 + world_pos.z * 0.25;
		VERTEX.x += sin(t) * wind_strength * h * 0.1;
		VERTEX.z += cos(t * 0.8) * wind_strength * h * 0.06;
	}
}

float triplanar(sampler2D tex, vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy * s).r * w.x + texture(tex, p.xz * s).r * w.y + texture(tex, p.xy * s).r * w.z;
}

void fragment() {
	vec3 col = COLOR.rgb * tint.rgb;
	float b = triplanar(brush_noise, world_pos, world_normal, brush_scale);
	col *= mix(1.0 - brush_strength, 1.0 + brush_strength, b);
	float pn = texture(patch_noise, world_pos.xz * patch_scale).r;
	col = mix(col, col * patch_color.rgb, smoothstep(0.45, 0.75, pn) * patch_strength);
	if (edge_breakup > 0.0) {
		float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float leaf = triplanar(brush_noise, world_pos, world_normal, edge_scale);
		if (fres * fres * edge_breakup > leaf) {
			discard;
		}
	}
	if (leaf_normal_strength > 0.0) {
		vec3 p = world_pos * edge_scale;
		vec3 jitter_n = vec3(
			triplanar(brush_noise, p + vec3(3.1, 0.0, 0.0), world_normal, 1.0),
			triplanar(brush_noise, p + vec3(0.0, 5.7, 0.0), world_normal, 1.0),
			triplanar(brush_noise, p + vec3(0.0, 0.0, 9.3), world_normal, 1.0)) - 0.5;
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(jitter_n, 0.0)).xyz * leaf_normal_strength);
	}
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.15;
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
