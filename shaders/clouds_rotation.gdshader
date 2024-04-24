shader_type spatial;
// render_mode use_half_res_pass;
render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;

// #define SIMPLE_MARCH

// uniform float K:hint_range(0.0, 1.0, .01) = 0.5;
const float K = 0.7;


// uniform float MAX_DEPTH: hint_range(0.0, 1000.0, .1) = 100.0;
// Main light model
group_uniforms sampling;
uniform int MAX_MARCHING_STEPS:hint_range(1, 1000, 1) = 100;
uniform float STEP_SIZE:hint_range(.0, 100.0, .01) = .3;
uniform float LARGE_STEP_SIZE:hint_range(.01, 200.0, .01) = .3;
uniform float max_depth:hint_range(.001, 100000.0, 100.) = 1000;

// #ifndef SIMPLE_MARCH
uniform float CRUISSING_STEP_SIZE:hint_range(.01, 200.0, .01) = .3;
uniform float LARGE_STEP_CRUISE:hint_range(.01, 1000.0, .01) = .3;
// #endif
uniform float max_depth_crussing:hint_range(.001, 100000.0, 100.) = 1000;
// uniform float STEP_SIZE:hint_range(.-1, .3, .001) = .3;
// uniform float LARGE_STEP_SIZE:hint_range(.00, .3, .001) = .3;
// const float STEP_SIZE= .3;

uniform int MAX_STEPS_LIGHTS:hint_range(1, 20) = 6;
uniform float STEPS_SIZE_LIGHTS:hint_range(0.001, 5.8, .001) = .09;

group_uniforms light_interaction;
uniform float SCATTERING_ANISO_FW:hint_range(.0, 1.0, .01)  = .5;
uniform float SCATTERING_ANISO_BW:hint_range(.0, 1.0, .01)  = .4;
// const float SCATTERING_ANISO= .3;
uniform float ABSORPTION_COEFFICIENT_CLOUDS :hint_range(.0, 2.0, .001) = 0.11;
uniform float ABSORPTION_COEFFICIENT_LIGHT :hint_range(.0, 4.0, .001) = 0.67;
// const float ABSORPTION_COEFFICIENT = 1.32;
uniform float ABSORPTION_COEFFICIENT_SUGAR :hint_range(.0, 4.0, .001) = 0.64;
// const float ABSORPTION_COEFFICIENT_SUGAR = 5.52;
// uniform float AIR_ABSORPTION_COEFFICIENT :hint_range(.0, 1.0, .0001) = 0.02;
const float AIR_ABSORPTION_COEFFICIENT = 0.03;
// const float ABSORPTION_COEFFICIENT_SUGAR = 5.90;

const float EPSILON = 0.001;



group_uniforms textures;
uniform sampler3D voronoi: source_color;
uniform sampler3D voronoi2: source_color;

uniform sampler3D perlin: source_color;
uniform sampler2D blue_noise: source_color;

uniform sampler2D map: source_color;
uniform sampler2D prev_frame: source_color;

group_uniforms clouds;
uniform float sun_energy:hint_range(.0, 5.0, .01) = 1.0;
uniform sampler2D stratus: source_color;
uniform sampler2D cumulus: source_color;
uniform sampler2D cumulonimbus: source_color;

// Main shape
uniform float cut_size: hint_range(0.0, .01, .0001) = 0.0;
uniform float cut_size2: hint_range(0.0, .01, .00001) = 0.0;


uniform float density: hint_range(0.0, 2.0, .01) = 1.;
uniform float coverage: hint_range(0.0, 1.0, .01) = 0.5;

uniform float second_degrade: hint_range(0.0, 1.0, .01) = 0.5;
uniform float third_degrade: hint_range(0.0, 1.0, .01) = 0.5;
uniform float last_degrade: hint_range(0.0, 1.0, .01) = 0.5;


uniform float n_tiles: hint_range(1.0, 10.0, .1) = 1.0;
uniform float blend_low: hint_range(.0, 1.0, .1) = 1.0;
uniform float blend_high: hint_range(.0, 1.0, .1) = 1.0;

// Auto-updated uniforms
group_uniforms auto_update;
uniform vec3 boxSize;
uniform vec3 sun_position;

#include "res://shaders/main_raymarching/raymarch_utils.gdshaderinc"
vec2 rotateAroundCenter(vec2 normalizedCoordinates, float angleInRadians, vec2 center) {
    // Translate to origin
    vec2 translatedCoordinates = normalizedCoordinates - center;

    // Rotate
    // float angleInRadians = radians(angleInDegrees);
    float cosAngle = cos(angleInRadians);
    float sinAngle = sin(angleInRadians);
    float rotatedX = translatedCoordinates.x * cosAngle - translatedCoordinates.y * sinAngle;
    float rotatedZ = translatedCoordinates.x * sinAngle + translatedCoordinates.y * cosAngle;

    // Translate back
    vec2 rotatedCoordinates = vec2(rotatedX, rotatedZ) + center;

    return rotatedCoordinates;
}
uniform float speed_up: hint_range(0.0, .02, .0001) = 0.001;
uniform float base_speed_up: hint_range(0.00, 1.00, .001) = 0.01;
uniform float persistence: hint_range(0.00, 1.00, .001) = 0.01;
float simpleSDF(vec3 p, vec3 position) {
    vec3 boundsMin = -boxSize * .5+position;
    vec3 boundsMax = boxSize * .5+position;

    float normalized_x = (p.x - boundsMin.x) / (boundsMax.x - boundsMin.x)*n_tiles;
    float normalized_z = (p.z - boundsMin.z) / (boundsMax.z - boundsMin.z)*n_tiles;
    float normalized_y = (p.y - boundsMin.y) / (boundsMax.y - boundsMin.y)*n_tiles;
    // vec2 rotatedCoordinates = rotateAroundCenter(vec2(normalized_x, normalized_z), TIME*PI*.0001, vec2(boxSize.xz)/2.0);
    // vec2 rotatedCoordinates = rotateAroundCenter(vec2(), TIME*PI*.0001, vec2(size));

    // vec3 map_tex = (texture(map, vec2(normalized_x, normalized_z)-vec2(.0,  0.0))).rgb;
    vec2 center = vec2(0.5, 0.5); // Center of the UV coordinates
    vec2 uv = vec2(normalized_x, normalized_z);
    vec3 map_tex = (texture(map,uv)).rgb;

    float map_coverage = map_tex.r;
    float clouds_type = map_tex.g;
    float precipitation = map_tex.b;

    // vec2 center = vec2(0.5, 0.5); // Center of the world coordinates
    // rotation_speed = mix(.0055, 0.01, normalized_y)*1.;
    // float rotation_speed_y = mix(.0, speed_up, normalized_y)*step(1.0-speed_up, 1.0);
    float rotation_speed_y = speed_up*normalized_y;
    // rotation_speed = 1.0;
    float rotation_speed = TIME*rotation_speed_y+TIME*-base_speed_up;
    vec2 rotatedP = rotateAroundCenter(p.xz, rotation_speed, center);
    vec4 clouds_layers = texture(voronoi, vec3(rotatedP, p.y)*vec3(cut_size)+vec3(.0, .0, 0.0));
    // vec4 clouds_layers = texture(voronoi, p*vec3(cut_size)+vec3(.0, .0, 0.0));


    // const int octaves = 4; // 4 texture layers
    // float maxAmplitude = (1.0 - pow(persistence, float(octaves))) / (1.0 - persistence);
    // float amplitude = pow(persistence, float(octaves - 1));
    float maxAmplitude = 0.0;
    float amplitude = 1.0;

    float first_layer = clouds_layers.r;
    float result_layer = first_layer*coverage;
    maxAmplitude += amplitude;
    amplitude *= persistence;

    float second_layer = clouds_layers.g;
    result_layer += second_layer*amplitude;
    result_layer *= coverage;
    maxAmplitude += amplitude;
    amplitude *= persistence;

    float third_layer = clouds_layers.b;
    result_layer += third_layer*amplitude*coverage;
    result_layer *= coverage;
    maxAmplitude += amplitude;
    amplitude *= persistence;

    float last_layer = clouds_layers.a;
    result_layer += last_layer*amplitude;
    result_layer *= coverage;
    maxAmplitude += amplitude;
    // amplitude *= persistence;
    result_layer /= maxAmplitude;

    // first_layer = smoothstep(1.0-map_coverage, 1.0, first_layer);
    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);

    float stratus_color = texture(stratus, vec2(normalized_y, TIME*.0)).r;
    float cumulus_color = texture(cumulus, vec2(normalized_y, TIME*.0)).r;
    float cumulonimbus_color = texture(cumulonimbus, vec2(normalized_y, TIME*.0)).r;

    float mixed_color = mix(mix(stratus_color, cumulus_color, smoothstep(0.0,blend_low, clouds_type)),
            cumulonimbus_color, smoothstep(blend_low, blend_high, clouds_type));
    // float clouds = first_layer*mixed_color;
    // float clouds = first_layer*cumulonimbus_color;
    float clouds = result_layer*cumulonimbus_color;

    return clouds*density;

}

float sceneSDF(vec3 p, vec3 position) {
    vec3 boundsMin = -boxSize * .5+position;
    vec3 boundsMax = boxSize * .5+position;

    float normalized_y = (p.y - boundsMin.y) / (boundsMax.y - boundsMin.y)*n_tiles;
    float rotation_speed_y = mix(.0, speed_up, normalized_y)*step(1.0-speed_up, 1.0);
    // rotation_speed_y = 1.0;
    float rotation_speed = TIME*rotation_speed_y+TIME*-base_speed_up;
    // rotation_speed = 1.0;
    float clouds = simpleSDF(p, position);
    vec2 center = vec2(0.5, 0.5); // Center of the UV coordinates
    vec2 rotatedP = rotateAroundCenter(p.xz, rotation_speed, center);
    vec4 clouds_layers2 = texture(voronoi2, vec3(rotatedP, p.y)*vec3(cut_size2)+vec3(.0, .0, 0.0));

    // vec4 clouds_layers2 = texture(voronoi2, p*vec3(cut_size2)-vec3(.0, .0, TIME*.0));
    clouds -= (clouds_layers2.r)*second_degrade;
    clouds -= (clouds_layers2.g)*third_degrade;
    clouds -= (clouds_layers2.b)*last_degrade;
    return clouds;
}


// TODO: InSatterin Trans as vec4

// uniform float border_mix: hint_range(0.0, .2, .001) = 0.0;
// uniform float mixbal: hint_range(0.0, 1.0, .001) = 0.0;
// Gold Noise ©2015 dcerisano@standard3d.com
// - based on the Golden Ratio
// - uniform normalized distribution
// - fastest static noise generator function (also runs at low precision)
// - use with indicated fractional seeding method. 

const float PHI = 1.61803398874989484820459;  // Φ = Golden Ratio   
float random(in vec3 xyz){
       return fract(tan(distance(xyz.xy*PHI, xyz.xy)*xyz.z)*xyz.x);
}

float lightmarch(in vec3 p, in vec3 rd, in vec3 position) {
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
        float lightSample = sceneSDF(p, position);
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
    float result  = mix(transmittanceB, beerPowder, sun_dir);
    // return totalTransmittance;
    // return transmittanceB;
    // return beerPowder;
    return result; // Good to asume linear given small steps
    // return beerPowder;

    // return (transmittanceB*transmittanceP);
    //return 1.0-(transmittanceB*transmittanceP);
}

bool calculate_simple(
    in vec3 ro,
    in vec3 rd,
    in float phase,
    in float point_density,
    inout float current_step_size,
    inout float depth,
    inout vec3 samplePosition,
    inout float lightEnergy,
    inout float transmittance,
    in vec3 position
){
    if (point_density > 0.001) {
        float lightTransmittance = lightmarch(samplePosition, rd, position);
        float S = sun_energy * lightTransmittance * point_density * phase;
        float sampleExtinction = max(float(0.0000000001), point_density * ABSORPTION_COEFFICIENT_CLOUDS);
        float Sint = (S - S * exp(-sampleExtinction * current_step_size)) / sampleExtinction;
        lightEnergy += Sint*transmittance;
        transmittance *= BeersLaw(point_density * current_step_size, ABSORPTION_COEFFICIENT_CLOUDS);
        if (transmittance < 0.01) {
            return false;
        }
    }
    current_step_size = mix(STEP_SIZE, LARGE_STEP_SIZE, clamp(depth/max_depth, 0.0, 1.0));
    depth += current_step_size;
    samplePosition += current_step_size * rd;
    return true;
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
    in vec3 position,
    out bool go_back
    ){
    if (is_cruissing){
        float point_density = simpleSDF(samplePosition, position);
        bool hit = point_density > 0.001;
        if (hit){
            depth -= current_step_size;
            samplePosition -= current_step_size* rd;
            float crussing_step_size = mix(STEP_SIZE, LARGE_STEP_SIZE, clamp(depth/max_depth, 0.0, 1.0)); // Switch to small steps
            current_step_size = crussing_step_size;

            is_cruissing = false;
            // current_step_size = STEP_SIZE;
            go_back = true;
            missed_steps=0;
            return true;
        }
        float crussing_step_size = mix(CRUISSING_STEP_SIZE, LARGE_STEP_CRUISE, clamp(depth/max_depth_crussing, 0.0, 1.0)); // Next cruissing step
        current_step_size = crussing_step_size;
    }
    else{
        float point_density = sceneSDF(samplePosition, position);
        bool hit = point_density > 0.001;
        // small_step_size = mix(STEP_SIZE, LARGE_STEP_SIZE, 1.0-transmittance);
        // float distanceFactor = clamp(length(samplePosition - ro) / 2000.0, .0, 1.0);
        // small_step_size = mix(current_step_size / 2.0, current_step_size * 2.0, clamp(point_density * distanceFactor, 0.0, 1.0));
        // small_step_size = mix(STEP_SIZE, LARGE_STEP_SIZE, (point_density + distanceFactor)/2.0);
        if (hit) {
            missed_steps = 0;
			// float small_step_size = mix(STEP_SIZE, LARGE_STEP_SIZE, clamp(depth/max_depth, 0.0, 1.0));
            float lightTransmittance = lightmarch(samplePosition, rd, position);
            float luminance = sun_energy * lightTransmittance * point_density * phase;
            float sampleExtinction = max(float(0.0000000001), point_density * ABSORPTION_COEFFICIENT_CLOUDS);
            float integrated_scattering = (luminance - luminance * BeersLaw(current_step_size, sampleExtinction)) / sampleExtinction;
            lightEnergy+= integrated_scattering*transmittance;
            transmittance *= BeersLaw(point_density * current_step_size, ABSORPTION_COEFFICIENT_CLOUDS);
            if (transmittance < 0.01) {
                return false;
            }
        }
        else {
            missed_steps++;
            if (missed_steps > 10){
                is_cruissing = true;
                // current_step_size = STEP_SIZE;
                missed_steps = 0;
            }

        }
        float crussing_step_size = mix(STEP_SIZE, LARGE_STEP_SIZE, clamp(depth/max_depth, 0.0, 1.0));
        current_step_size = crussing_step_size;
        // float small_step_size = STEP_SIZE;
        // current_step_size = small_step_size;
    }
    depth += current_step_size;
    samplePosition += current_step_size * rd;
    return true;
}


uniform float dither_size: hint_range(.0, 1.0, .01) = 1.0;
vec2 raymarch(in vec3 ro, in vec3 rd, in float dst, in vec4 coord, in vec3 position, in vec2 uv) {
    vec3 lightDir = normalize(sun_position);
    float transmittance = 1.0;
    float lightEnergy = 0.0;
    float sundot = dot(rd, lightDir);
	// Double Lobe HG
    float phase= mix(HenyeyGreenstein(-SCATTERING_ANISO_BW, sundot), HenyeyGreenstein(SCATTERING_ANISO_FW, sundot), K);
    int missed_steps = 0;
	// Reduce large step banding artifacts
    // int texture_size = 1023;
    int texture_size = 469;
    coord *= dither_size;
    coord += vec4(TIME)*1000.0;
    float dither = texelFetch(blue_noise, ivec2(int(coord.x)%texture_size, int(coord.y)%texture_size), 0).r * 10.0; // TODO: Add more dither the closer
    // float dither = texelFetch(blue_noise, ivec2(int(coord.x)%texture_size, int(coord.y)%texture_size), 0).r * STEP_SIZE; // TODO: Add more dither the closer
    // float dither = texelFetch(blue_noise, ivec2(int(coord.x)&texture_size, int(coord.y)&texture_size), 0).r * 0.4; // TODO: Add more dither the closer
    // float dither = texture(blue_noise, uv).r * 9.4; // TODO: Add more dither the closer
    // dither  = .0;
    float current_step_size = LARGE_STEP_SIZE;
    // float current_step_size = STEP_SIZE;
    float depth = dither;
    vec3 samplePosition = ro + depth* rd;
    bool is_cruissing = true;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {

#ifdef SIMPLE_MARCH
        float point_density = sceneSDF(samplePosition, position);
        if (!calculate_simple(ro, rd, phase, point_density, current_step_size, depth, samplePosition, lightEnergy, transmittance, position)){
            break;
        }
#else
        bool go_back = false;
        if (!calculate(ro, rd, phase, current_step_size, depth, samplePosition, missed_steps, is_cruissing, lightEnergy, transmittance, position, go_back)){
            break;
        }
        // if (go_back){
            // i--;
            // continue;
        // }
#endif


        if (depth > dst) {
            break;
        }
    }

    return clamp(vec2(lightEnergy, transmittance), 0.0, 1.0);
}


vec2 rayBoxDst(vec3 rayOrigin, vec3 invRaydir, vec3 pos) {
    vec3 boundsMin = -boxSize * .5+pos;
    vec3 boundsMax = boxSize * .5+pos;

    // Adapted from: http://jcgt.org/published/0007/03/04/
    vec3 t0 = (boundsMin - rayOrigin) * invRaydir;
    vec3 t1 = (boundsMax - rayOrigin) * invRaydir;
    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);

    float dstA = max(max(tmin.x, tmin.y), tmin.z);
    float dstB = min(tmax.x, min(tmax.y, tmax.z));

    // CASE 1: ray intersects box from outside (0 <= dstA <= dstB)
    // dstA is dst to nearest intersection, dstB dst to far intersection

    // CASE 2: ray intersects box from inside (dstA < 0 < dstB)
    // dstA is the dst to intersection behind the ray, dstB is dst to forward intersection

    // CASE 3: ray misses box (dstA > dstB)

    float dstToBox = max(0, dstA);
    float dstInsideBox = max(0, dstB - dstToBox);
    return vec2(dstToBox, dstInsideBox);
}

// varying vec3 camera; //Local Camera position
varying vec3 position; //Vertex Position
void vertex() {
	// position = VERTEX; // For model space
    // camera = (VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz; // For model space
    position = (MODEL_MATRIX * vec4(VERTEX,1)).xyz; //Vertex Position in World Space
}


vec3 getSkyColor(vec3 rd) {
    float sunIntensity = max(dot(rd, normalize(sun_position)), 0.0);
    vec3 skyColor = mix(vec3(0.15, 0.3, 0.6), vec3(1.0, 0.6, 0.3), sunIntensity);
    return skyColor;
}
// uniform float base_lum:hint_range(-1.0, 1.0, .01) = 0.5;
// uniform float base_trans:hint_range(-1.0, 1.0, .01) = 0.5;
// uniform sampler2D depth_text: hint_depth_texture;
uniform float temp_aa: hint_range(.0, 1.0, .01) = 1.0;
void fragment() {

    // vec3 ro = camera; // For model space
    vec3 ro = CAMERA_POSITION_WORLD;

    vec3 viewVec = (position - ro);
    vec3 rd = normalize(viewVec);

    vec2 rayToContainerInfo = rayBoxDst(ro, 1.0/rd, NODE_POSITION_WORLD);
    float dstToBox = rayToContainerInfo.x;
    float dstInsideBox = rayToContainerInfo.y;
    ro = ro + dstToBox * rd;

#ifdef DEBUG
        vec4 debug = debug_march(ro, rd, dstInsideBox);
        ALBEDO = debug.rgb;
        ALPHA = debug.a;
#else
        vec2 result = raymarch(ro,rd, dstInsideBox, FRAGCOORD, NODE_POSITION_WORLD, SCREEN_UV);
        float transmittance = result.y;
        float energy = result.x;

        // vec3 skyColor = getSkyColor(rd);
        vec3 cloudColor = vec3(energy) * vec3(1.0);
        ALBEDO.rgb = clamp(cloudColor, 0.0, 1.0);
        ALBEDO = pow(ALBEDO, vec3(1.0/2.2)); // gamma correction
        ALPHA = clamp(1.0-transmittance, 0.0, 1.0);
            // float dither = ; // TODO: Add more dither the closer

        // vec2 coord = FRAGCOORD.xy;
        // int texture_size = 469/2;
        // ALBEDO = texelFetch(blue_noise, ivec2(int(coord.x)&texture_size, int(coord.y)&texture_size), 0).rgb;
        // ALBEDO = texelFetch(blue_noise, ivec2(int(coord.x)%469, int(coord.y)%469), 0).rgb;
        // ALBEDO = texture(blue_noise, SCREEN_UV*dither_size).rgb; // TODO: Add more dither the closer
#endif
    vec4 prev_frame_data = texture(prev_frame, SCREEN_UV);
    ALBEDO.rgb = mix(ALBEDO.rgb, prev_frame_data.rgb, temp_aa);
}
