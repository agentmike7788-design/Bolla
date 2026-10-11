// mat_lantern_glass (G8 Runde 2, Lichtgang): the panes of a carried hand lantern – translucent warm glow,
// added onto what lies behind (the dark frame posts, the candle flame inside), so the lantern reads as
// glass with a light in it instead of a solid glowing block. Unshaded, no depth write.
// Flicker like flame_glow.gdshader (TIME in fragment() only); CarriedLanterns gives every carried lantern its
// own copy with flicker_amount 0 and drives glow_energy from the CPU, in step with the flame, the pool light
// and the light spot on the ground.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.7, 0.36, 1.0);
uniform float glow_energy = 0.75;
uniform float flicker_amount = 0.14;
uniform float flicker_speed = 1.7;
uniform float jitter_speed = 8.5;
// The panes glow most in their middle (where the flame is) and fade a little towards the frame.
uniform float edge_fade = 0.45;

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), u) * 2.0 - 1.0;
}

void fragment() {
	vec3 o = NODE_POSITION_WORLD;
	float phase = dot(o, vec3(12.9898, 4.1414, 78.233));
	float n = vnoise(TIME * flicker_speed + phase) * 0.7 + vnoise(TIME * jitter_speed + phase * 1.7) * 0.3;
	float k = 1.0 + n * flicker_amount;
	// facing the camera = looking through the middle of a pane; grazing = the pane's edge and the frame
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float mid = mix(1.0 - edge_fade, 1.0, facing);
	vec3 c = glow_color.rgb * glow_energy * k * mid;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// added to the sRGB frame as it is in the browser renderer: encode the strength, keep the hue (lantern_spot.gdshader)
	float m = max(c.r, max(c.g, c.b));
	c = c / max(m, 0.0001) * pow(max(m, 0.0), 1.0 / 2.2);
#endif
	ALBEDO = c;
}
