shader_type sky;
// A painted 2D panorama, mirrored across two hemispheres to avoid a hard seam.
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_disable;
void sky() {
    float longitude = atan(EYEDIR.x, EYEDIR.z) / (2.0 * PI) + 0.5;
    float u = 1.0 - abs(longitude * 2.0 - 1.0);
    float latitude = asin(clamp(EYEDIR.y, -1.0, 1.0));
    float v = clamp(0.80 - latitude * 0.90, 0.0, 1.0);
    vec3 painted = texture(panorama, vec2(u, v)).rgb;
    painted = mix(painted, vec3(0.33,0.46,0.26), smoothstep(0.94,1.0,v));
    // Fade the top into a uniform zenith, without stretching cloud pixels.
    vec3 zenith = texture(panorama, vec2(0.5, 0.02)).rgb;
    float top = smoothstep(0.69, 1.15, latitude);
    COLOR = mix(painted, zenith, top);
}
