// The fake light of a carried lantern (G8 Runde 2, CarriedLanterns): a soft warm spot on the ground, added onto
// what lies there. One MultiMesh for all lanterns – the instance colour carries colour × strength × flicker (set
// by the CPU in step with the flame), so the shader has no TIME. Unshaded, no depth write, no shadow.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Fall-off: 1 in the middle, soft to 0 at the rim (power of the smooth bump).
uniform float falloff = 2.2;
// The spot is a little stronger towards the lantern (in front of the carrier): the centre shifts by this share.
uniform float core = 0.25;

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = clamp(length(d), 0.0, 1.0);
	float bump = pow(1.0 - r * r, falloff);
	float hot = 1.0 - smoothstep(0.0, 0.55, r);
	vec3 c = COLOR.rgb * (bump + hot * core);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// The browser renderer adds this value to the sRGB frame as it is (no linear blend): encode it, so the spot has
	// the same size and strength as in Forward+ (measured, docs/reviews/phase8_round2/lichtgang_messung.md).
	c = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
#endif
	ALBEDO = c;
}
