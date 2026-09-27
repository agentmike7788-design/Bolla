// Foliage variant of painted.gdshader (mat_foliage: tree crowns, bushes): wind sway – the only
// TIME use of the painted family –, leafy silhouette breakup and leafy normal noise.
// Occlusion cutout (UI-01): leaves between the camera and the player (global uniforms
// occlusion_target = the player's chest, set every frame by Player, and occlusion_radius) fade
// out in a leafy, dithered disc so the gravekeeper stays visible under a crown. The cut is a
// cone from the camera to the target (a constant disc on screen), only above the target's height
// and never in shadow passes – crowns keep casting their full shadow.
shader_type spatial;
render_mode cull_back;

#include "res://assets/shaders/painted_common.gdshaderinc"

uniform float wind_strength = 0.0;
uniform float wind_speed = 1.1;
// Break up silhouettes into leafy edges and add leafy normal noise.
uniform float edge_breakup = 0.0;
uniform float edge_scale = 2.2;
uniform float leaf_normal_strength = 0.0;
// Occlusion cutout: the outer part of the disc (fraction of the radius) fades out, and the cut
// fades in over this height (m) above the target.
uniform float occlusion_softness = 0.45;
uniform float occlusion_rise = 0.35;

global uniform vec3 occlusion_target;
global uniform float occlusion_radius;

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

// 4×4 ordered dither threshold (0..1) of a pixel.
float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

// How deep p lies in the cutout seen from eye: 0 = keep … 1 = centre of the cut.
// A target far below the world (the project default) switches the cut off.
float occlusion_cut(vec3 p, vec3 eye) {
	if (occlusion_radius <= 0.0 || occlusion_target.y < -500.0) {
		return 0.0;
	}
	vec3 axis = occlusion_target - eye;
	float len2 = dot(axis, axis);
	if (len2 < 0.0001) {
		return 0.0;
	}
	float t = dot(p - eye, axis) / len2;  // 0 at the camera, 1 at the target
	if (t <= 0.0 || t >= 1.0) {
		return 0.0;
	}
	float radius = occlusion_radius * t;
	float d = length(p - (eye + axis * t));
	float radial = 1.0 - smoothstep(radius * (1.0 - occlusion_softness), radius, d);
	return radial * smoothstep(occlusion_target.y, occlusion_target.y + occlusion_rise, p.y);
}

void fragment() {
	vec3 col = painted_colour(COLOR.rgb, world_pos, world_normal);
	float leaf = triplanar(brush_noise, world_pos, world_normal, edge_scale);
	if (edge_breakup > 0.0) {
		float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		if (fres * fres * edge_breakup > leaf) {
			discard;
		}
	}
	if (!IN_SHADOW_PASS) {
		float cut = occlusion_cut(world_pos, CAMERA_POSITION_WORLD);
		// Leafy (brush noise) and stippled (ordered dither) edge instead of a hard hole.
		if (cut > 0.0 && cut >= mix(bayer4(FRAGCOORD.xy), leaf, 0.6)) {
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
