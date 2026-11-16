shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.42;
uniform float candle_pulse : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 d = UV - vec2(0.5, 0.5);
	float dist = length(d * vec2(1.0, 1.15));
	float vig = smoothstep(0.28, 0.92, dist) * vignette_strength;
	float pulse = 1.0 + sin(TIME * 1.1) * candle_pulse + sin(TIME * 2.7) * (candle_pulse * 0.4);
	vec3 warm = mix(tex.rgb * pulse, tex.rgb * (1.0 - vig), vig);
	COLOR = vec4(warm, tex.a);
}
