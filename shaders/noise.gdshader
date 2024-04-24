shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}


vec3 hash33(vec3 p3) {
    p3 = fract(p3 * vec3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yxz + 19.19);
    return -1.0 + 2.0 * fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

// Raw simplex implementau9tion by candycat
// Source: https://www.shadertoy.com/view/4sc3z2
float SimplexNoiseRaw(vec3 pos) {
    const float K1 = 0.333333333;
    const float K2 = 0.166666667;

    vec3 i = floor(pos + (pos.x + pos.y + pos.z) * K1);
    vec3 d0 = pos - (i - (i.x + i.y + i.z) * K2);

    vec3 e = step(vec3(0.0), d0 - d0.yzx);
    vec3 i1 = e * (1.0 - e.zxy);
    vec3 i2 = 1.0 - e.zxy * (1.0 - e);

    vec3 d1 = d0 - (i1 - 1.0 * K2);
    vec3 d2 = d0 - (i2 - 2.0 * K2);
    vec3 d3 = d0 - (1.0 - 3.0 * K2);

    vec4 h = max(0.6 - vec4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), 0.0);
    vec4 n = h * h * h * h * vec4(dot(d0, hash33(i)), dot(d1, hash33(i + i1)), dot(d2, hash33(i + i2)), dot(d3, hash33(i + 1.0)));

    return dot(vec4(31.316), n);
}

float fbm(vec3 pos, int octaves, float scale, float persistence) {
    float final = 0.0;
    float amplitude = 1.0;
    float maxAmplitude = 0.0;

    for (int i = 0; i < octaves; ++i) {
        final += SimplexNoiseRaw(pos * scale) * amplitude;
        scale *= 2.0;
        maxAmplitude += amplitude;
        amplitude *= persistence;
    }

    return final / maxAmplitude;
}
uniform sampler2D tex : hint_default_black;
uniform sampler2D voronoi: hint_default_black;
uniform sampler3D rdtex: hint_default_black;
uniform float size : hint_range(0.0, 1.0);
void fragment() {
    vec3 color =  texture(tex, UV).rgb;
    vec4 vor =  texture(voronoi, UV);
    vec3 noise = (vec3(fbm(vec3(UV.x, UV.y+TIME*.01, .2), 4, 1.0/size, 0.5)*.5)+.5);
    // vec3 col = mix(noise, color, step(0.5, UV.y));
    vec3 black = vec3(0.0);
    // vec3 col = mix(noise, black, UV.y);
    step(0.5, UV.y);
    vec3 col = mix(noise, color, step(0.5, UV.x));
    COLOR.rgb = col;
    COLOR.rgb = vec3(vor.r);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
