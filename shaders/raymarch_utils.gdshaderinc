vec2 ray_sphere_distance(vec3 ro, vec3 rd, vec3 sphere_origin, float sphere_rad){
    vec3 oc = ro - sphere_origin;
    float b = 2.0 * dot(rd, oc);
    float c = dot(oc, oc) - sphere_rad*sphere_rad;
    float disc = b * b - 4.0 * c;
    if (disc < 0.0)
        return vec2(-1.0);
        // return -1.0;

    float q = (-b - sign(b) * sqrt(disc)) / 2.0;
    float t0 = q;
    float t1 = c / q;
    float minT = min(t0, t1);
    float maxT = max(t0, t1);
    t0 = minT;
    t1 = maxT;
    return vec2(t0, t1);
}

// float ray_sphere_distance(vec3 ro, vec3 rd, vec3 sphere_origin, float sphere_rad){
//     vec3 oc = ro - sphere_origin;
//     float b = 2.0 * dot(rd, oc);
//     float c = dot(oc, oc) - sphere_rad*sphere_rad;
//     float disc = b * b - 4.0 * c;
//     if (disc < 0.0)
//         return -1.0;
//
//     float q = (-b - sign(b) * sqrt(disc)) / 2.0;
//     float t0 = q;
//     float t1 = c / q;
//     float minT = min(t0, t1);
//     float maxT = max(t0, t1);
//     t0 = minT;
//     t1 = maxT;
//     float val = mix(t1, t0, step(0.0, t0)); // (t0 < 0.0) ? t1 : t0;
//     return val;
// }

float inverse_lerp(float min1, float max1, float value) {
    return (value - min1) / (max1 - min1);
}

float hash11( float n )
{
    return fract(sin(n)*43758.5453);
}

float smoothmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float henyey_greenstein(float g, float mu) {
    float gg = g * g;
    float phase = (1.0 / (4.0 * PI)) * ((1.0 - gg) / pow(1.0 + gg - 2.0 * g * mu, 1.5));
    return phase;
}

float beers_law(float density, float absorption) {
    return exp(-density * absorption);
}

float sugar_powder(float density, float absorption) {
    return (1.0 - exp(-density * absorption * 2.0));
}

float BeerPowder(float density, float absorption) {
    return exp(-density * absorption) * (1.0 - exp(-density * absorption * 2.0));
}
