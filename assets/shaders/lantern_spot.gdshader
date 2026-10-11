// The fake light of a carried lantern (G8 Runde 2, CarriedLanterns): a soft warm spot on the ground, added onto
// what lies there. One MultiMesh for all lanterns – the instance colour carries colour × strength × flicker (set
// by the CPU in step with the flame), so the shader has no TIME. Unshaded, no depth write, no shadow.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Fall-off: 1 in the middle, soft to 0 at the rim (power of the smooth bump).
uniform float falloff = 2.2;
// The spot is a little stronger towards the lantern (in front of the carrier): the centre shifts by this share.
uniform float core = 0.25;

// Browser: how the shape is encoded (the fall-off a little wider, as the sRGB curve widens it in Forward+).
uniform float compat_shape = 0.75;

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = clamp(length(d), 0.0, 1.0);
	float shape = pow(1.0 - r * r, falloff) + (1.0 - smoothstep(0.0, 0.55, r)) * core;
	vec3 c = COLOR.rgb * shape;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// The browser renderer adds this value to the sRGB frame as it is (no linear blend): encode the strength (not the
	// hue – a warm spot stays warm instead of turning grey), so size and strength match Forward+ (measured,
	// docs/reviews/phase8_round2/lichtgang_messung.md).
	float m = max(COLOR.r, max(COLOR.g, COLOR.b));
	vec3 hue = COLOR.rgb / max(m, 0.0001);
	c = hue * pow(max(m, 0.0), 1.0 / 2.2) * pow(max(shape, 0.0), compat_shape);
#endif
	ALBEDO = c;
}
