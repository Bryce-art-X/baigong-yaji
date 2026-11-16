/// Faux 3D Perspective + Golden Foil Sheen Shader for 2D Cards in Godot 4.
/// Perspective math from codevogel/faux-3d-perspective-shader-godot (MIT License).
/// Extended with specular golden foil sweep for Baigong Yaji.

shader_type canvas_item;

uniform float fov : hint_range(1, 179) = 90.0;
uniform float rot_y_deg : hint_range(-45, 45) = 0.0;
uniform float rot_x_deg : hint_range(-45, 45) = 0.0;
uniform float inset : hint_range(0, 1) = 0.04;
uniform float foil_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 mouse_norm = vec2(0.5, 0.5);

varying vec2 offset;
varying vec3 world_pos_3d;

void vertex() {
	float rot_y_rad = radians(rot_y_deg);
	float rot_x_rad = radians(rot_x_deg);

	float sin_y = sin(rot_y_rad), cos_y = cos(rot_y_rad);
	float sin_x = sin(rot_x_rad), cos_x = cos(rot_x_rad);

	mat3 rotation_matrix;
	rotation_matrix[0] = vec3(cos_y, 0.0, -sin_y);
	rotation_matrix[1] = vec3(sin_y * sin_x, cos_x, cos_y * sin_x);
	rotation_matrix[2] = vec3(sin_y * cos_x, -sin_x, cos_y * cos_x);

	float perspective_scale = tan(radians(fov) * 0.5);
	world_pos_3d = rotation_matrix * vec3(UV - 0.5, 0.5 / perspective_scale);

	float depth_scale = (0.5 / perspective_scale) + 0.5;
	world_pos_3d.xy *= depth_scale * rotation_matrix[2].z;
	offset = depth_scale * rotation_matrix[2].xy;

	VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE * perspective_scale * (1.0 - inset) * 0.06;
}

void fragment() {
	if (world_pos_3d.z <= 0.0) discard;

	vec2 projected_uv = (world_pos_3d.xy / world_pos_3d.z) - offset + 0.5;
	if (projected_uv.x < 0.0 || projected_uv.x > 1.0 || projected_uv.y < 0.0 || projected_uv.y > 1.0) {
		discard;
	}

	vec4 tex = texture(TEXTURE, projected_uv);

	// Diagonal golden foil sheen driven by tilt & time
	float diag = (projected_uv.x * 0.75 + projected_uv.y * 0.65);
	float sweep = sin(diag * 7.0 - TIME * 1.6 + (mouse_norm.x - 0.5) * 3.5);
	float glint = smoothstep(0.65, 1.0, sweep) * foil_strength;
	vec3 gold_tint = vec3(0.95, 0.78, 0.36);

	COLOR = vec4(tex.rgb + gold_tint * glint * 0.32, tex.a);
}
