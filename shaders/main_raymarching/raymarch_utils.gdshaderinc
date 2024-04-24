float inverse_lerp(float min1, float max1, float value) {
    return (value - min1) / (max1 - min1);
}

float sphereSDF(in vec3 p, in float rad) {
    return length(p) - rad;
}

float boxSDF(in vec3 p, in vec3 side_length) {
    float smoothness = 2.0;
    vec3 d = abs(p) - side_length + smoothness;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0)) - smoothness;
}

float sceneSimpleSDF(vec3 p) {
    // p += vec3(16.0, 0.0, 0.0);
    float sphereDist = sphereSDF(p, 10.); // SDF for a box of size 1
    // float boxDist = boxSDF(p, vec3(10.0, 10.0, 10.0)*0.5); // SDF for a box of size 1
    // float spehereDist = -sphereSDF(p, 10.5); // SDF for a box of size 1
    // return sphereDist;
    return max(abs(sphereDist)-0.5, p.x);
    // return max(abs(boxDist)-0.5, p.x);
}

// float sceneSimpleSDF(vec3 p) {
//     // float boxDist = sphereSDF(p, 3.5); // SDF for a box of size 1
//     float boxDist = boxSDF(p, vec3(10.0, 10.0, 10.0)*1.0); // SDF for a box of size 1
//     return boxDist;
// }

vec3 calculateNormal(vec3 p) { // Calculate the gradient (normal) at point p
    float delta = 0.001;
    vec3 x = vec3(delta, 0.0, 0.0);
    vec3 y = vec3(0.0, delta, 0.0);
    vec3 z = vec3(0.0, 0.0, delta);
    return normalize(vec3(
        sceneSimpleSDF(p + x) - sceneSimpleSDF(p - x),
        sceneSimpleSDF(p + y) - sceneSimpleSDF(p - y),
        sceneSimpleSDF(p + z) - sceneSimpleSDF(p - z)
    ));
}

vec3 calculateLighting(vec3 p, vec3 rd, vec3 lightPos, vec3 lightColor, vec3 ambientColor) {
    vec3 N = calculateNormal(p);
    vec3 L = normalize(lightPos);
    vec3 V = normalize(-rd);
    vec3 R = reflect(-L, N);

    float ambientStrength = 0.1;
    vec3 ambient = ambientStrength * ambientColor;

    float diffuseStrength = max(dot(N, L), 0.0);
    vec3 diffuse = diffuseStrength * lightColor;

    // float specularStrength = 0.5;
    float shininess = 32.0;
    float specularStrength = pow(max(dot(V, R), 0.0), shininess);
    vec3 specular = specularStrength * lightColor;

    return ambient + diffuse + specular;
}

float HenyeyGreenstein(float g, float mu) {
    float gg = g * g;
    float phase = (1.0 / (4.0 * PI)) * ((1.0 - gg) / pow(1.0 + gg - 2.0 * g * mu, 1.5));
    return phase;
}

// float DoubleLobeHG(float bwScattering, float fwScattering, float mu, float k) {
//     return mix(HenyeyGreenstein(-bwScattering, sundot), HenyeyGreenstein(fwScattering, sundot), k);
// }

float SugarPowder(float density, float absorption, vec3 rd) {
    float lookAtSun = dot(normalize(rd), normalize(sun_position));
    lookAtSun = lookAtSun * .5 + 0.5;
    return (1.0 - exp(-density * absorption * 2.0));
    return (1.0 - exp(-density * absorption * 2.0))*lookAtSun;
}

// I = I0 * e^(-a*l)
// where:
// - I is the intensity of light after it has passed through the medium,
// - I0 is the initial intensity of light,
// - a is the absorption coefficient, which represents the ability of the medium to absorb light,

float BeersLaw(float density, float absorption) {
    return exp(-density * absorption);
}

float BeerPowder(float density, float absorption) {
    return exp(-density * absorption) * (1.0 - exp(-density * absorption * 2.0));
}

#ifdef DEBUG
group_uniforms debug;
uniform int MAX_MARCHING_STEPS_DEBUG:hint_range(1, 1000, 1) = 100;
const float DEBUG_EPSILON = 0.001;
uniform float DEBUG_STEP_SIZE:hint_range(.0, 1.0, .01) = .3;

//vec4 debug_march(in vec3 ro, in vec3 rd, in float end) {
//    float depth = 0.0;
//    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
//        float dist = sceneSimpleSDF(ro + depth * rd);
//        if (dist < EPSILON) {
//            return vec4(1.0, 0.0, 0.0, 1.0);
//        }
//        depth += STEP_SIZE;
//    }
//
//    return vec4(.0);
//}

vec4 debug_march(in vec3 ro, in vec3 rd, in float end, inout float depth) {
    // float depth = 0.0;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sceneSimpleSDF(ro + depth * rd);
        if (dist < EPSILON) {
            vec3 light = calculateLighting(ro + depth * rd, rd, sun_position, vec3(1.0, 1.0, 1.0), vec3(0.1, 0.1, 0.1));
            return vec4(light, 1.0);
            // return vec4(1.0, 0.0, 0.0, 1.0);
        }
        depth += STEP_SIZE;
        if (depth >= end) {
            break;
        }
    }
    depth = 0.0; // No hit/Infinite
    return vec4(0.0);
}
#endif

