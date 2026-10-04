// mat_emissive_warm (G7 round 1): candle flames, lantern glass, glowing panes – unshaded warm glow
// that flickers softly. TIME is used in fragment() only and without discard, so the material does
// not count as animated (static shadow maps around it stay cached, see painted_common.gdshaderinc).
// The phase comes from the object's and the fragment's world position: two flames never pulse in step.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.42, 1.0);
uniform float glow_energy = 1.0;
// ± share of the brightness (0.18 = ±18 %), the speed of the main flicker and of the fast jitter.
uniform float flicker_amount = 0.18;
uniform float flicker_speed = 1.7;
uniform float jitter_speed = 8.5;
// Colour wobble towards a deeper orange at the dim moments.
uniform vec4 dim_color : source_color = vec4(1.0, 0.56, 0.24, 1.0);
uniform float wobble = 0.35;

varying vec3 world_pos;

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), u) * 2.0 - 1.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 o = NODE_POSITION_WORLD;
	float phase = dot(o, vec3(12.9898, 4.1414, 78.233)) + dot(floor(world_pos * 6.0), vec3(3.7, 11.3, 5.1));
	float t = TIME;
	float n = vnoise(t * flicker_speed + phase) * 0.7 + vnoise(t * jitter_speed + phase * 1.7) * 0.3;
	float k = 1.0 + n * flicker_amount;
	vec3 c = mix(glow_color.rgb, dim_color.rgb, clamp(-n, 0.0, 1.0) * wobble);
	ALBEDO = c * k * glow_energy;
}
