// Ghost of the buried (docs/PHASE3_DESIGN.md §8, mat_ghost): a pale grey-green shroud whose
// silhouette glows cold (#6FE3D2 fresnel rim), painted with the shared brush noise of
// painted_common.gdshaderinc, fading out towards a ragged, waving hem. Pivot = hem centre
// (local y 0), height ≈ `height`.
// fade (0..1): fade in/out 21:30 / 04:30 · unrest (0..1): flicker, colder desaturation,
// stronger hem wave. Both are per-instance so all ghosts share one material.
// No TIME (PERF-01: an animated material makes shadow maps in its range redraw): the ghost
// script advances the per-instance `anim_time` instead. Ghosts never cast shadows either.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://assets/shaders/painted_common.gdshaderinc"

instance uniform float fade : hint_range(0.0, 1.0) = 1.0;
instance uniform float unrest : hint_range(0.0, 1.0) = 0.0;
instance uniform float phase = 0.0;
// Seconds, advanced by ghost.gd (replaces TIME).
instance uniform float anim_time = 0.0;

uniform vec4 base_color : source_color = vec4(0.718, 0.761, 0.690, 1.0);  // #B7C2B0
uniform vec4 rim_color : source_color = vec4(0.435, 0.890, 0.824, 1.0);   // #6FE3D2
uniform float base_alpha : hint_range(0.0, 1.0) = 0.27;
uniform float rim_power = 2.0;
uniform float rim_alpha = 0.6;
uniform float rim_emission = 2.4;
uniform float body_emission = 0.3;
// Dark face opening of the hood (object +Z, band of the height).
uniform float face_low = 0.72;
uniform float face_high = 0.92;
uniform float face_dark = 0.9;
uniform float height = 1.6;
// Hem: fully faded below hem_low, opaque above hem_high (fractions of height).
uniform float hem_low = 0.0;
uniform float hem_high = 0.32;
uniform float hem_ragged = 0.22;
uniform float wave_amount = 0.05;
uniform float wave_speed = 1.3;
uniform float drift_speed = 0.06;
// restless: colder, desaturated tone.
uniform vec4 unrest_color : source_color = vec4(0.56, 0.70, 0.72, 1.0);

varying float local_h;
varying vec3 obj_normal;

void vertex() {
	local_h = clamp(VERTEX.y / max(height, 0.01), 0.0, 1.5);
	obj_normal = NORMAL;
	float hem = 1.0 - smoothstep(0.0, 0.55, local_h);
	float amp = wave_amount * (1.0 + unrest * 1.6) * hem;
	float t = anim_time * wave_speed * (1.0 + unrest * 0.8) + phase;
	float ang = atan(VERTEX.z, VERTEX.x);
	VERTEX.x += sin(t + ang * 3.0 + local_h * 7.0) * amp;
	VERTEX.z += cos(t * 0.8 + ang * 2.0 - local_h * 5.0) * amp;
	VERTEX.y += sin(t * 1.3 + ang * 4.0) * amp * 0.5;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Brush strokes drift slowly upwards through the shroud.
	vec3 p = world_pos + vec3(0.0, -anim_time * drift_speed, 0.0);
	float brush = triplanar(brush_noise, p, world_normal, brush_scale * 1.6);
	float patches = texture(patch_noise, p.xy * 0.9 + vec2(phase, anim_time * 0.02)).r;

	vec3 col = base_color.rgb * tint.rgb;
	col = mix(col, unrest_color.rgb, unrest * 0.65);
	col *= mix(1.0 - brush_strength * 1.5, 1.0 + brush_strength * 1.5, brush);

	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - clamp(facing, 0.0, 1.0), rim_power);

	// Ragged hem: painted noise eats the lower edge.
	float edge = hem_high + (patches - 0.5) * hem_ragged;
	float hem = smoothstep(hem_low, max(edge, hem_low + 0.02), local_h + (brush - 0.5) * 0.08);

	float flicker = 1.0;
	if (unrest > 0.0) {
		float f = 0.5 + 0.5 * sin(anim_time * 9.0 + phase * 3.1) * sin(anim_time * 3.7 + phase);
		flicker = mix(1.0, mix(0.5, 1.0, f), unrest);
	}

	// Hood: a shadowed face opening towards +Z.
	float front = smoothstep(0.35, 0.85, normalize(obj_normal).z);
	float band = smoothstep(face_low, face_low + 0.04, local_h) * (1.0 - smoothstep(face_high - 0.04, face_high, local_h));
	float face = front * band * face_dark * (0.75 + 0.5 * patches);
	col *= 1.0 - face;
	rim *= 1.0 - face;

	ALBEDO = col;
	EMISSION = col * body_emission + rim_color.rgb * rim * rim_emission;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float a = clamp(base_alpha * mix(0.8, 1.15, brush) + rim * rim_alpha + face * 0.35, 0.0, 1.0);
	ALPHA = clamp(a * hem * flicker * fade, 0.0, 1.0);
}
