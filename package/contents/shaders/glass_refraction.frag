#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 canvasSize;
    float radius;
    float refraction;
    float specular;
    vec2 lightPoint;
};
layout(binding = 1) uniform sampler2D source;
float roundedDistance(vec2 p) {
    float r = clamp(radius, 0.0, min(canvasSize.x, canvasSize.y) * 0.5);
    vec2 q = abs(p - canvasSize * 0.5) - canvasSize * 0.5 + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void main() {
    vec2 p = qt_TexCoord0 * canvasSize;
    float d = roundedDistance(p);
    float mask = clamp(0.5 - d, 0.0, 1.0);
    vec2 normal2 = vec2(roundedDistance(p + vec2(0.5, 0.0)) - d,
                        roundedDistance(p + vec2(0.0, 0.5)) - d) * 2.0;
    float rim = exp(-abs(d) / 9.0);
    vec3 normal = normalize(vec3(normal2 * rim * 2.0, 1.0));
    // Schlick Fresnel with glass's ~4% reflectance at normal incidence.
    float fresnel = 0.04 + 0.96 * pow(1.0 - normal.z, 5.0);
    vec2 offset = normal2 * rim * refraction * 12.0 / canvasSize;
    vec2 uv = clamp(qt_TexCoord0 - offset, vec2(0.001), vec2(0.999));
    vec2 dispersion = offset * 0.14;
    vec4 green = texture(source, uv);
    vec3 rgb = vec3(texture(source, clamp(uv - dispersion, vec2(0.001), vec2(0.999))).r,
                    green.g, texture(source, clamp(uv + dispersion, vec2(0.001), vec2(0.999))).b);
    vec3 light = normalize(vec3((lightPoint - p) / max(canvasSize.x, canvasSize.y), 0.5));
    float shine = pow(max(0.0, dot(normal, normalize(light + vec3(0.0, 0.0, 1.0)))), 28.0);
    rgb = min(vec3(green.a), rgb + (fresnel * rim + shine * rim * 0.25) * specular * green.a);
    fragColor = vec4(rgb, green.a) * (mask * qt_Opacity);
}
