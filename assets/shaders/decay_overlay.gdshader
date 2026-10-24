// Painted decay overlay (docs/PHASE4_DESIGN.md §2.5, §8) – material_overlay of every corpse
// mesh, set by CorpseDecayVisual. Multiplies the painted colour towards a pale grey-green in
// soft, blotchy brush patches: pallor, then stains, then a strongly desaturated body. Nothing
// open, no wounds, no gore. The painted base shader stays untouched; painted_common is only
// read for its brush noise helper (Forward+: its light() is unused, this pass is unshaded; the Compatibility pass
// below is lit by it).
// Static – no TIME (PERF-01). `amount` is an instance uniform, so every corpse shares one
// material (mat_decay_overlay) and the overlay is removed entirely at amount 0.
// Phase 9 W3 QA-Fix A9-8: in the Compatibility renderer (web export) a blend_mul pass came out black as soon as the
// environment runs its post-process path (glow / adjustments – the graveyard's WorldEnvironment): the corpse on the
// bier was a black silhouette. There the overlay is a lit blend_mix pass with the painted light() instead – the stain
// colour over the painted body with the stain's share as alpha (base × (1 − m) + stain × m, the same result as the
// multiply). Forward+ keeps the multiply pass unchanged.
shader_type spatial;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
render_mode blend_mix, depth_draw_never, cull_back, fog_disabled;
#else
render_mode blend_mul, unshaded, depth_draw_never, cull_back, fog_disabled, shadows_disabled;
#endif

#include "res://assets/shaders/painted_common.gdshaderinc"

instance uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 stain_color : source_color = vec4(0.557, 0.604, 0.494, 1.0);
// World-space size of the stain patches (per metre) and of the brush grain inside them.
uniform float stain_scale = 2.6;
uniform float grain_scale = 3.2;
// Share of the tint that is even pallor (the rest comes in blotches).
uniform float pallor = 0.6;
// How much the stain darkens at full amount (0 = keeps the luminance of the painted colour).
uniform float darken = 0.18;
// How much of the stain hue is kept (the rest is plain grey: "stark entsättigt", §2.5).
uniform float hue_strength = 0.55;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float a = clamp(amount, 0.0, 1.0);
	// Blotches grow with the amount: small islands first, larger merged patches later.
	float patches = triplanar(patch_noise, world_pos, world_normal, stain_scale);
	float grain = triplanar(brush_noise, world_pos, world_normal, grain_scale);
	float edge = mix(0.72, 0.38, a);
	float blot = smoothstep(edge - 0.12, edge + 0.08, patches * 0.8 + grain * 0.2 + 0.05);
	float m = clamp(a * mix(pallor, 1.0, blot), 0.0, 1.0);
	// The overlay sees the same vertex paint as the painted pass, so the multiply factor
	// target / base turns the painted colour into a desaturated, grey-green stained one
	// (brush noise and light scale all channels alike and cancel out).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// A9-8: the painted colour of the body (painted_colour lifts the vertex paint like the base pass), the stain over it.
	vec3 painted = max(painted_colour(COLOR.rgb, world_pos, world_normal), vec3(0.004));
	float plum = dot(painted, vec3(0.299, 0.587, 0.114));
	vec3 ps = stain_color.rgb;
	vec3 phue = mix(vec3(1.0), ps / max(dot(ps, vec3(0.299, 0.587, 0.114)), 0.001), hue_strength);
	ALBEDO = clamp(vec3(plum) * phue * (1.0 - darken), vec3(0.0), vec3(1.0));
	ALPHA = m;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.15;
#else
	vec3 base = max(COLOR.rgb, vec3(0.004));
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 s = stain_color.rgb;
	vec3 hue = mix(vec3(1.0), s / max(dot(s, vec3(0.299, 0.587, 0.114)), 0.001), hue_strength);
	vec3 target = mix(base, vec3(lum) * hue * (1.0 - darken), m);
	ALBEDO = clamp(target / base, vec3(0.0), vec3(1.6));
#endif
}
