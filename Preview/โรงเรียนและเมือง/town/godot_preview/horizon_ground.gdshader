shader_type spatial;
uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec3 eye = INV_VIEW_MATRIX[3].xyz;
    vec3 direction = normalize(world_position - eye);
    float longitude = atan(direction.x, direction.z) / (2.0 * PI) + 0.5;
    float u = 1.0 - abs(longitude * 2.0 - 1.0);
    float v = clamp(0.80 - asin(clamp(direction.y,-1.0,1.0)) * 0.90,0.0,1.0);
    float fade = smoothstep(115.0, 240.0, length(world_position.xz - vec2(0.0,-15.0)));
    ALBEDO = texture(grass, UV).rgb * (1.0-fade);
    vec3 painted = texture(panorama,vec2(u,v)).rgb;
    painted = mix(painted, vec3(0.33,0.46,0.26), smoothstep(0.94,1.0,v));
    EMISSION = painted * fade;
    ROUGHNESS = 0.9;
}
