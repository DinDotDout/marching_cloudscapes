shader_type spatial;
render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;
// render_mode cull_disabled, unshaded;
// render_mode cull_disabled, unshaded, depth_draw_never;
const float K = 0.7;

group_uniforms sampling;
uniform int MAX_MISSED_STEP:hint_range(1, 20, 1) = 10;
uniform int MIN_MARCHING_STEPS:hint_range(1, 1000, 1) = 35;
uniform int MAX_MARCHING_STEPS:hint_range(1, 1000, 1) = 60;
uniform float STEP_SIZE:hint_range(.0, 100.0, 1.) = .3;
uniform float LARGE_STEP_SIZE:hint_range(.01, 200.0, 1.) = .3;
uniform float MAX_DEPTH:hint_range(.001, 10000.0, 100.) = 1000;

uniform float CRUISSING_STEP_SIZE:hint_range(.01, 200.0, .01) = .3;
uniform float LARGE_STEP_CRUISE:hint_range(.01, 1000.0, .01) = .3;

uniform float MAX_DEPTH_CRUISSING:hint_range(.001, 100000.0, 100.) = 1000;
uniform float dither_strength: hint_range(.0, 100.0, .01) = 20.0;

group_uniforms light_interaction;

uniform int MAX_STEPS_LIGHTS:hint_range(1, 20) = 6;
uniform float STEPS_SIZE_LIGHTS:hint_range(0.001, 5.8, .001) = .09;

uniform float SCATTERING_ANISO_FW:hint_range(.0, 1.0, .01)  = .5;
uniform float SCATTERING_ANISO_BW:hint_range(.0, 1.0, .01)  = .4;
uniform float ABSORPTION_COEFFICIENT_CLOUDS :hint_range(.0, 2.0, .001) = 0.11;
uniform float ABSORPTION_COEFFICIENT_LIGHT :hint_range(.0, 4.0, .001) = 0.67;
uniform float ABSORPTION_COEFFICIENT_SUGAR :hint_range(.0, 4.0, .001) = 0.64;
// const float AIR_ABSORPTION_COEFFICIENT = 0.03;

group_uniforms post_processing;
uniform float temp_aa: hint_range(.0, 1.0, .01) = 0.0;

group_uniforms clouds;
uniform float earth_radius: hint_range(0.0, 10000.0, 100) = 6000.0;
// uniform float clouds_min_height: hint_range(0.0, 400) = 5.0;
// uniform float clouds_max_height: hint_range(0.0, 400) = 15.0;
uniform float clouds_min_height: hint_range(500.0, 4000) = 1500.0;
uniform float clouds_max_height: hint_range(900.0, 4000) = 1500.0;
uniform float sun_energy:hint_range(.0, 10.0, .01) = 1.0;
uniform float AMBIENT_STRENGTH:hint_range(.0, .101, .00001) = .0;
uniform sampler2D stratus: source_color;
uniform sampler2D cumulus: source_color; // TODO: Apply for distance to center
uniform sampler2D cumulonimbus: source_color;

// Main shape
uniform float map_cut_size: hint_range(0.0, .001, .00001) = 0.0;
uniform float cut_size: hint_range(0.0, .001, .00001) = 0.0;
uniform float cut_size2: hint_range(0.0, .01, .00001) = 0.0;

uniform float clouds_type_test: hint_range(0.0, 1.0, .01) = 0.0;


// WARNING: Probably will remove and hardcode according to clouds type
uniform float base_density: hint_range(0.0, 2.0, .01) = 1.;
uniform float coverage: hint_range(0.0, 1.0, .01) = 0.5;

uniform float second_degrade: hint_range(0.0, 1.0, .01) = 0.5;
uniform float third_degrade: hint_range(0.0, 1.0, .01) = 0.5;
uniform float last_degrade: hint_range(0.0, 1.0, .01) = 0.5;
// uniform float n_tiles: hint_range(1.0, 10.0, .1) = 1.0;
uniform float blend_low: hint_range(.0, 1.0, .1) = 1.0;
uniform float blend_high: hint_range(.0, 1.0, .1) = 1.0;

group_uniforms sky_color;
uniform vec3 COLOUR_LIGHT_BLUE: source_color;
uniform vec3 COLOUR_BRIGHT_BLUE: source_color;


group_uniforms textures;
uniform sampler2D sky_color: source_color;
uniform sampler3D voronoi: source_color;
uniform sampler3D voronoi2: source_color;
uniform sampler2D blue_noise: source_color;
uniform sampler2D prev_frame: source_color;

uniform sampler2D map: source_color;

group_uniforms auto_update;
uniform vec3 sun_position;

#include "res://shaders/main_raymarching/raymarch_utils.gdshaderinc"

float get_stratus(in float height, in vec4 clouds_layers, in float map_coverage){
    float maxAmplitude = 0.0;
    float amplitude = 1.0;
    float persistence = 0.4;
    float result_layer = 0.0;

    for(int i = 0; i < 4; i++){
        float layer = clouds_layers[i];
        result_layer += layer * amplitude;
        maxAmplitude += amplitude;
        amplitude *= persistence;
    }

    result_layer /= maxAmplitude;
    float stratus_coverage = .4;
    result_layer *= stratus_coverage;
    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);
    float stratus_color = texture(stratus, vec2(height, TIME*.0)).r;
    // stratus_color = 1.0;
    // stratus_color = texture(cumulonimbus, vec2(height, TIME*.0)).r;
    const float stratus_density = .3;
    // return result_layer*stratus_density;
    return stratus_color*result_layer*stratus_density;
}

float get_cumulus(in float height, in vec4 clouds_layers, in float map_coverage){
    float maxAmplitude = 0.0;
    float amplitude = 1.0;
    float persistence = 0.0;
    float result_layer = 0.0;

    for(int i = 0; i < 4; i++){
        float layer = clouds_layers[i];
        result_layer += layer * amplitude;
        maxAmplitude += amplitude;
        amplitude *= persistence;
    }

    result_layer /= maxAmplitude;
    float cumulus_coverage = .8;
    result_layer *= cumulus_coverage;
    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);
    float cumulus_color = texture(cumulus, vec2(height, TIME*.0)).r;
    const float cumulus_density = .1;
    return cumulus_color*result_layer*cumulus_density;
    // return cumulus_color*base_density;
    return cumulus_color*result_layer*base_density;
    // return cumulus_color*result_layer*cumulus_density;
}

float get_cumulonimbus(in float height, in vec4 clouds_layers, in float map_coverage){
    float maxAmplitude = 0.0;
    float amplitude = 1.0;
    float persistence = .1;
    float result_layer = 0.0;
    // result_layer = clouds_layers.r*coverage;

    for(int i = 0; i < 4; i++){
        float layer = clouds_layers[i];
        result_layer += layer * amplitude;
        maxAmplitude += amplitude;
        amplitude *= persistence;
    }

    result_layer /= maxAmplitude;
    float cumulonimbus_coverage = .8;
    result_layer *= cumulonimbus_coverage;
    // result_layer -= coverage;
    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);
    float cumulonimbus_color = texture(cumulonimbus, vec2(height, TIME*.0)).r;

    const float cumulonimbus_density = .8;
    return cumulonimbus_color*result_layer*cumulonimbus_density;
}

float simpleSDF(vec3 p) {
    // NOTE: This should be always between the range given we start and stop at that position
    // p += vec3(.0, earth_radius, .0);
    // p += earth_radius;
    float normalized_y = inverse_lerp(clouds_min_height*1.0, clouds_max_height*1.0, p.y);
    // normalized_y = inverse_lerp(clouds_min_height, clouds_max_height, length(p));
    // normalized_y = inverse_lerp(clouds_min_height+earth_radius, clouds_max_height+earth_radius, length(p));
    // normalized_y = fract(normalized_y);

    // vec3 map_tex = (texture(map, fract(uv*map_cut_size))).rgb;
    vec3 map_tex = (texture(map, (p.xz*map_cut_size))).rgb;
    // map_tex = vec3(1.0);

    float map_coverage = map_tex.r;
    // map_coverage = 1.0;
    float clouds_type = 1.0-map_tex.g;
    // clouds_type = 1.0;
    float precipitation = map_tex.b;

    // Clouds type set which one will be, but chance of one or other increases with coverage or height?
    vec4 clouds_layers = texture(voronoi, p*vec3(cut_size)+vec3(.0, .0, TIME*0.008));
    // clouds_layers = vec4(1.0);
    // float cumulus_color = get_cumulus(normalized_y, clouds_layers, map_coverage);
    float stratus_color = get_stratus(normalized_y, clouds_layers, map_coverage);
    float cumulus_color = get_cumulus(normalized_y, clouds_layers, map_coverage);

    // float stratus_col = texture(stratus, vec2(normalized_y, TIME*.0)).r;
    // float cumulus_col = texture(cumulus, vec2(normalized_y, TIME*.0)).r;
    //
    // float weight = stratus_col + cumulus_col;
    //
    // float stratus_weight = stratus_col / weight;
    // float cumulus_weight = cumulus_col / weight;
    // float clouds = mix(stratus_color*stratus_weight, cumulus_color*cumulus_weight, clouds_type);

    // float blend = stratus_col*stratus_weight + cumulus_col*(1.0-stratus_weight);

    // float height = mix(stratus_col, cumulus_col, clouds_type_test);

    // float height = mix(stratus_col*stratus_weight, cumulus_col*cumulus_weight, clouds_type);
    float clouds = mix(stratus_color, cumulus_color, clouds_type);

    // return clouds_layers.r*base_density;

    // clouds = cumulus_color;
    // clouds = stratus_color;
    return clouds;

}

float sceneSDF(vec3 p) {
    float clouds = simpleSDF(p);
    vec4 clouds_degrade = 1.0-texture(voronoi2, p*vec3(cut_size2)-vec3(.0, .0, TIME*.0));
    clouds -= (1.0-clouds_degrade.r)*second_degrade;
    // clouds = mix(clouds_layers2,(1.0-clouds_layers2.r)*second_degrade;
    clouds -= (1.0-clouds_degrade.r)*third_degrade;
    clouds -= (1.0-clouds_degrade.r)*last_degrade;
    return clouds;
}


vec3 texture_bg(in vec3 ro, in vec3 rd) {
    // rd = clamp(rd, .0, 1.0);
    // rd = fract(rd);
    float normalized_rdy = inverse_lerp(-1.0, 1.0, rd.y);

    vec2 uv = vec2(atan(rd.z, rd.x) / (2.0 * PI) + 0.5, asin(rd.y) / PI + 0.5);
    return texture(sky_color, clamp(uv.yy,.0, 1.0)).rgb;
}



// TODO: Add flat clouds to sky
vec3 skybox(in vec3 ro, in vec3 rd){
    // vec3 p = ro+rd*skybox_dist;
    // float clouds_layer1= texture(voronoi3dBg, normalize(p)*noise_size+vec3(1.0, 1.0, TIME*0.01)).r;
    // float clouds_layer2= texture(voronoi3d2Bg, normalize(p)*noise_size+vec3(1.0, 1.0, -TIME*.01)).r;
    // clouds_layer2 = 1.0-smoothstep(coverage2-.5, coverage2+.5, 1.0-clouds_layer2);
    // clouds_layer1 = 1.0-smoothstep(coverage-.5, coverage+.5, 1.0-clouds_layer1);
    // float clouds = 1.0 - (2.0 - clouds_layer1 - clouds_layer2);
    // clouds = clamp(clouds, 0.0, 1.0);
    // // return vec3(clouds);
    //
    // vec3 skyCol = texture_bg(ro, rd);
    //
    // // Calculate the dot product of the sun direction and the ray direction
    // float sunDot = dot(normalize(sun_position), rd);
    //
    // // Use the dot product to create a lighting effect
    // vec3 cloudColor = vec3(0.9) * (0.5 + 0.5 * sunDot);
    //
    // // Dim the clouds at the horizon and hide the lower part of the sphere
    // float horizonFade = smoothstep(0.0, horizon_fade, rd.y);
    // clouds *= horizonFade;
    // vec3 finalColor = mix(skyCol.rgb, cloudColor, clouds);
    // vec3 finalColor2 = mix(vec3(0.0), cloudColor, clouds);
    //
    // return finalColor;
    return texture_bg(ro, rd);

}

float lightmarch(in vec3 p, in vec3 rd) {
    vec3 lightDir = normalize(sun_position);
    float totalDensity = 0.0;
    float totalTransmittance = 1.0;
    vec3 samplePosition = p;
    for (int i = 0; i < MAX_STEPS_LIGHTS; i++) {
        // vec3 deviation = vec3(random(p+vec3(float(i))), random(p + vec3(float(i)+1.0)), random(p + vec3(float(i)+2.0))) * 2.0 - 1.0;
        // float deviationFactor = float(i) / float(MAX_STEPS_LIGHTS);
        // deviation = mix(vec3(-1.0), vec3(1.0), deviation)*9999.0001;
        // deviation = mix(vec3(-1.0), vec3(1.0), deviation)*.0;
        // vec3 light = normalize(lightDir + (deviation));
        samplePosition = p + lightDir* STEPS_SIZE_LIGHTS;
        // samplePosition = p + light * STEPS_SIZE_LIGHTS;
        float lightSample = sceneSDF(p);
        totalDensity += lightSample * STEPS_SIZE_LIGHTS; // integration in step
        // totalTransmittance *= BeersLaw(lightSample*STEPS_SIZE_LIGHTS, ABSORPTION_COEFFICIENT_LIGHT);
        // totalTransmittance *= BeersLaw(lightSample*STEPS_SIZE_LIGHTS, ABSORPTION_COEFFICIENT_CLOUDS);
        // return deviation.b;
    }
    float transmittanceB = BeersLaw(totalDensity, ABSORPTION_COEFFICIENT_LIGHT);
    // float transmittanceB = BeersLaw(totalDensity, ABSORPTION_COEFFICIENT_CLOUDS);
    // float transmittanceP = SugarPowder(totalDensity, ABSORPTION_COEFFICIENT_CLOUDS, rd);
    float transmittanceP = SugarPowder(totalDensity, ABSORPTION_COEFFICIENT_SUGAR, rd);
    float beerPowder = transmittanceB*transmittanceP;
    float sun_dir = dot(rd, lightDir)*.5+.5;
    // TODO: Try modified beersugar law
    float result  = mix(transmittanceB, 2.0*beerPowder, sun_dir);
    // return result;
    // return totalTransmittance;
    // return transmittanceP*transmittanceB;
    // return beerPowder;
    // return transmittanceB;
    return result; // Good to asume linear given small steps
    // return beerPowder;

    // return (transmittanceB*transmittanceP);
    //return 1.0-(transmittanceB*transmittanceP);
}

bool calculate(
    in vec3 ro,
    in vec3 rd,
    in float phase,
    inout float current_step_size,
    inout float depth,
    inout vec3 samplePosition,
    inout int missed_steps,
    inout bool is_cruissing,
    inout float lightEnergy,
    inout float transmittance,
    out bool go_back,
    in float dither
    ){

    if (is_cruissing){
        float point_density = simpleSDF(samplePosition);
        bool hit = point_density > 0.001;
        if (hit){
            // Step back
            depth -= current_step_size;
            samplePosition -= current_step_size * rd;
            // samplePosition += dither*80.0*rd;
            float crussing_step_size = mix(STEP_SIZE, LARGE_STEP_SIZE, clamp(depth/MAX_DEPTH, 0.0, 1.0)); // Switch to small steps
            current_step_size = crussing_step_size;

            is_cruissing = false;
            go_back = true;
            missed_steps=0;
            return true;
        }
        float crussing_step_size = mix(CRUISSING_STEP_SIZE, LARGE_STEP_CRUISE, clamp(depth/MAX_DEPTH_CRUISSING, 0.0, 1.0)); // Next cruissing step
        current_step_size = crussing_step_size;
    }
    else{
        float point_density = sceneSDF(samplePosition);
        bool hit = point_density > 0.001;
        if (hit) {
            missed_steps = 0;
            vec3 ambient = vec3(AMBIENT_STRENGTH);
            float lightTransmittance = lightmarch(samplePosition, rd);
            float luminance =  sun_energy * lightTransmittance * point_density * phase;
            float sampleExtinction = max(float(0.0000000001), point_density * ABSORPTION_COEFFICIENT_CLOUDS);
            float integrated_scattering = (luminance - luminance * BeersLaw(current_step_size, sampleExtinction)) / sampleExtinction;
            lightEnergy += integrated_scattering*transmittance;
            transmittance *= BeersLaw(point_density * current_step_size, ABSORPTION_COEFFICIENT_CLOUDS);

            if (transmittance < 0.01) {
                return false;
            }
        }
        else {
            missed_steps++;
            if (missed_steps > MAX_MISSED_STEP){
                is_cruissing = true;
                missed_steps = 0;
            }

        }
        float crussing_step_size = mix(STEP_SIZE, LARGE_STEP_SIZE, clamp(depth/MAX_DEPTH, 0.0, 1.0));
        current_step_size = crussing_step_size;
    }
    depth += current_step_size;
    samplePosition += current_step_size * rd;
    return true;
}
vec2 raymarch(in vec3 ro, in vec3 rd, in float max_distance_travelled, inout float depth, in vec2 coord) {
    // TODO: Make into single variable
    float transmittance = 1.0;
    float lightEnergy = 0.0;
    vec3 lightDir = normalize(sun_position);
    float sundot = dot(rd, lightDir);
	// Double Lobe HG
    float phase= mix(HenyeyGreenstein(-SCATTERING_ANISO_BW, sundot), HenyeyGreenstein(SCATTERING_ANISO_FW, sundot), K);
    int texture_size = 469;

    coord += vec2(TIME)*1000.0; // 'randomize' and pair with TTA
    float dither = texelFetch(blue_noise, ivec2(int(coord.x)%texture_size, int(coord.y)%texture_size), 0).r * dither_strength; // TODO: Add more dither the closer
    // dither = 0.0;
    depth = dither;

    float current_step_size = LARGE_STEP_SIZE;
    vec3 samplePosition = ro + depth* rd;

    // TODO: Use missed_steps as a flag to switch between small and large steps
    bool is_cruissing = true;
    int missed_steps = 0;
    float view_height_dot = 1.0-clamp(dot(rd, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
    int marching_steps = int(mix(float(MIN_MARCHING_STEPS), float(MAX_MARCHING_STEPS), view_height_dot));
    for (int i = 0; i < marching_steps; i++) {
        bool go_back = false;
        if (!calculate(ro, rd, phase, current_step_size, depth, samplePosition, missed_steps, is_cruissing, lightEnergy, transmittance, go_back, dither)){
            break;
        }

        if (depth >= max_distance_travelled) {
            break;
        }
    }
    return clamp(vec2(lightEnergy, transmittance), 0.0, 1.0);
}

// The quadratic formula is used to solve equations of the form ax^2 + bx + c = 0
// The solutions are given by the formula: x = [-b ± sqrt(b^2 - 4ac)] / 2a
bool getOne(float b, float c, out float result) {
    float discriminant = b * b - 4.0 * c;
    if (discriminant < 0.0) {
        return false;
    } else {
        result = (-b - sqrt(discriminant)) / (2.0);
        return true;
    }
}

vec2 rayPlanesDst(in vec3 ro, in vec3 rd) {
    float t1 = (clouds_min_height*1.0 - ro.y) / rd.y;
    float t2 = (clouds_max_height*1.0 - ro.y) / rd.y;
    t1 = max(t1, 0.0);
    t2 = max(t2, 0.0);
    return vec2(min(t1, t2), max(t1, t2));
    return vec2(t1, t2);
}

vec2 raySphereShellDst(in vec3 ro, in vec3 rd, inout bool inOne, inout bool inTwo) {
    float innerRadius = clouds_min_height+earth_radius;
    float outerRadius = clouds_max_height+earth_radius;
    vec3 oc = ro;
    float b = 2.0 * dot(oc, rd);

    float c = dot(oc, oc) - innerRadius * innerRadius;
    float t1;
    bool hit1 = getOne(b, c, t1);
    float discriminant = b * b - 4.0 * c;
    float T1= abs(-b + sqrt(discriminant)) / (2.0);

    c = dot(oc, oc) - outerRadius * outerRadius;
    float T2= abs(-b + sqrt(discriminant)) / (2.0);
    float t2;
    bool hit2 = getOne(b, c, t2);

    inOne = length(ro) < innerRadius;
    inTwo = length(ro) < outerRadius;

    return abs(vec2(t1, t2));
    // return abs(vec2(t1, t2));
    if (inOne && inTwo){
        // Distance to inner shell and exit
        // return abs(vec2(t1, t2-t1));
        // return abs(vec2(0.0, t2));
        return abs(vec2(t1, t2));
    }
    // inTwo = t2 > 0.0;
    // inOne = t1 > 0.0;
    // inOne = t1 > t2;
    // // inTwo = true;
    // return (vec2(0.0, t2));

    if (inTwo){
        // Inside shell and distance to exit
        // inOne= abs(t1) > abs(t2);
        // inTwo = abs(t1) > abs(t2);

        // inTwo = t2 < 0.0;
        // inOne = t1 > 0.0;

        // // inTwo = true;
        // return (vec2(0.0, max(t2-t1, t1-t2)));
        // return (vec2(0.0, max(T2, t1)));
        if (t1 < 0.0){ // Revemove negative part of intersection
            return vec2(0.0, t2);
            return vec2(0.0, 0.0); // No intersection
        }
        return vec2(0.0, T2);
        return vec2(0.0, abs(T2));
        return (vec2(0.0, max(T2, T1)));
        return (vec2(0.0, max(t2, t1)));
    }

    // if t2 < 0.0 looking outside
    // if (t2 < 0.0){
    //     return vec2(0.0, 0.0); // No intersection
    // }

    // return (vec2(T2, t1)); // Stop at other side of t2

    // Should march from t2 to t1, stop and march again from t1 to T2
    // Make impossible because of distance view decay and height
    // return (vec2(t2, T2*T2)); // Stop at long side of t1

    if (t2 < 0.0){ // Revemove negative part of intersection
        return vec2(0.0, 0.0); // No intersection
    }
    return (vec2(t2, t1));
    // t1 = abs(t1);
    // t2 = abs(t2);
    if (!hit1){
        // inOne = false;
        if (!hit2){ // Outside looking outside
            // inTwo = false;
            return vec2(-1, -1); // No intersection
        } // in shell looking outside
        return vec2(t2, -1); // No intersection

    } else{
        if (!hit2){ // inside shell looking inside
            // inOne = false;
            return vec2(t1, -1);
        }
        return vec2(t1, t2); // inside both
    }
}

float RenderGlow(float dist, float radius, float intensity) {
  dist = max(dist, 1e-6);
	return (1.0 - exp(-25.0 * (radius / dist))) * 0.1 + (1.0 - exp(-0.05 * (radius / dist) * (radius / dist))) * 2.0;
}

vec4 RenderSky(vec3 cameraOrigin, vec3 cameraDir, float curTime, float uvy) {
  float skyT1 = pow(smoothstep(0.0, 1.0, uvy), 0.5);
  float skyT2 = pow(smoothstep(0.5, 1.0, uvy), 1.0);

  vec3 c1 = vec3(COLOUR_LIGHT_BLUE * 0.25);
  vec3 c2 = vec3(COLOUR_BRIGHT_BLUE);
  vec3 c3 = vec3(COLOUR_BRIGHT_BLUE * 1.25);
  vec3 sky = mix(c1, c2, skyT1);
  sky = mix(sky, c3, skyT2);

  float mu = inverse_lerp(1.0, -1.0, dot(cameraDir, normalize(sun_position)));
  float glow = RenderGlow(mu, 0.001, 0.5);

  sky +=  vec3(glow, glow*.6, 0.0);

  vec4 result = vec4(sky, 0.0);
  return result;
}

varying mat4 CAMERA;
// uniform vec3 camera_position_world;
// uniform mat4 camera_transform;
void vertex() {
    vec4 pos = vec4(VERTEX, 1.0);
    POSITION = pos;
    CAMERA = INV_VIEW_MATRIX;
}

vec3 get_ndc(in vec2 screen_uv, in float depth){
 return vec3(screen_uv* 2.0 - 1.0, depth);
}

float get_linear_depth(in vec3 ndc, in mat4 inv_projection_matrix){
    vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float map_depth = -view.z;
    return map_depth;
}

// vec3 get_fragment_world_position(in vec3 ndc, in mat4 inv_proj_mat){
//     vec4 world = CAMERA * inv_proj_mat * vec4(ndc, 1.0);
//     vec3 world_position = world.xyz / world.w;
//     return world_position;
// }

float raySphereIntersect(vec3 ray_origin, vec3 ray_dir, vec3 sphere_center, float sphere_radius) {
    vec3 oc = ray_origin - sphere_center;
    float b = 2.0 * dot(oc, ray_dir);
    float c = dot(oc, oc) - sphere_radius * sphere_radius;
    float discriminant = b * b - 4.0 * c;
    if (discriminant < 0.0) {
        return -1.0; // No intersection
    } else {
        discriminant = sqrt(discriminant);
        float t0 = -b - discriminant;
        float t1 = -b + discriminant;
        return -t0;
        return min(t0, t1);
    }
}
uniform sampler2D depth_texture : source_color, hint_depth_texture;
void fragment(){
    float depth = texture(depth_texture, SCREEN_UV).x;
    bool map_hit = depth < 1.0;
    // TODO: Fow now keep clouds as if never could be reached
    if (map_hit){
        // ALPHA = 0.0;
        discard;
    }
    else{
        vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
        vec4 eye = INV_PROJECTION_MATRIX * clip;
        eye /= eye.w;
        // vec3 world_position = (INV_VIEW_MATRIX * eye).xyz;
        vec3 world_position = (INV_VIEW_MATRIX * eye).xyz;

        vec3 ndc = get_ndc(SCREEN_UV, depth);
        float map_depth = get_linear_depth(ndc, INV_PROJECTION_MATRIX);
        // vec3 world_position = get_world_position(ndc, INV_PROJECTION_MATRIX); High imprecissions

        vec3 ro = CAMERA_POSITION_WORLD;
        vec3 rd = normalize(world_position - ro);
        // ro = vec3(.0, .0, .0); // WARN: with thiss enabled we disable clouds getting closer

        // ro += vec3(.0, -earth_radius, .0);
        // WARNING: Shell should be much lower than our origin
        bool inOne = false;
        bool inTwo = false;
        // vec2 rayToContainerInfo = raySphereShellDst(ro, rd, inOne, inTwo); // Fake ray origin to keep spehere centered on us
        vec2 rayToContainerInfo = rayPlanesDst(ro, rd); // Fake ray origin to keep spehere centered on us
        float dstToMarchStart = rayToContainerInfo.x;
        float dstToMarchEnd = rayToContainerInfo.y;
        // dstToMarchStart = raySphereIntersect(ro, rd, vec3(.0, earth_radius, 0.0), earth_radius+clouds_min_height ); // Fake ray origin to keep spehere centered on us
        // dstToMarchEnd = raySphereIntersect(ro, rd, vec3(.0, earth_radius, 0.0 ), earth_radius+clouds_max_height ); // Fake ray origin to keep spehere centered on us
        float ray_hit_depth = 0.0;
        ro += dstToMarchStart*rd; // Advance ray till clouds volume

        bool clouds_occluded = map_depth < min(dstToMarchStart, 4000.0); // Far plane is 4000.0
        bool no_map_hit = depth >= 1.0;
        vec2 result = raymarch(ro,rd, dstToMarchEnd-dstToMarchStart, ray_hit_depth, FRAGCOORD.xy);
        vec4 pixel = RenderSky(ro, rd, TIME, SCREEN_UV.y);
        ALBEDO = pixel.rgb;
        float transmittance = result.y;
        float energy = result.x;
        ALBEDO.rgb = energy * vec3(1.0)+ALBEDO.rgb*(transmittance);
        vec4 prev_frame_data = texture(prev_frame, SCREEN_UV);
        ALBEDO.rgb = mix(ALBEDO.rgb, prev_frame_data.rgb, temp_aa);

    }
}
