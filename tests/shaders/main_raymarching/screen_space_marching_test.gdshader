shader_type spatial;
// render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;
render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled;
// render_mode cull_disabled, unshaded;
// render_mode cull_disabled, unshaded, depth_draw_never;
const float K = 0.7;

group_uniforms sampling;
uniform int MAX_MISSED_STEP:hint_range(1, 20, 1) = 10;
uniform int MIN_MARCHING_STEPS:hint_range(1, 1000, 1) = 35;
uniform int MAX_MARCHING_STEPS:hint_range(1, 1000, 1) = 60;
uniform float STEP_SIZE:hint_range(.0, 100.0, 1) = 1.;
uniform float LARGE_STEP_SIZE:hint_range(.01, 300.0, 1) = .3;
uniform float MAX_DEPTH:hint_range(.001, 10000.0, 100) = 1000;

uniform float CRUISSING_STEP_SIZE:hint_range(.01, 200.0, 1) = .3;
uniform float LARGE_STEP_CRUISE:hint_range(.01, 1000.0, 1) = .3;

uniform float MAX_DEPTH_CRUISSING:hint_range(.001, 10000, 100) = 1000;
uniform float dither_strength: hint_range(.0, 100.0, 1) = 20.0;

group_uniforms light_interaction;
uniform float sun_energy:hint_range(.0, 100.0, .01) = 1.0;
uniform int MAX_STEPS_LIGHTS:hint_range(1, 20) = 6;
uniform float STEPS_SIZE_LIGHTS:hint_range(0.001, 20.0, .001) = .09;
uniform float STEPS_SIZE_LIGHTS_LARGE:hint_range(0.001, 20.0, .001) = .09;

uniform float SCATTERING_ANISO_FW:hint_range(.0, 1.0, .01)  = .5;
uniform float SCATTERING_ANISO_BW:hint_range(.0, 1.0, .01)  = .4;

uniform highp float EXCTINCTION_COEFFICIENT_SKY:hint_range(.0, .0002, .000001) = 0.;
uniform float SCATTERING_COEFFICIENT_CLOUDS :hint_range(.0, 3.0, .001) = 0.11;
uniform float SCATTERING_COEFFICIENT_SUGAR:hint_range(.0, 3.0, .001) = 0.11;


// group_uniforms post_processing;
// uniform float temp_aa: hint_range(.0, 1.0, .01) = 0.0;

group_uniforms clouds;
uniform float earth_radius: hint_range(0.0, 6300000.0, 100) = 6000.0;
// uniform float clouds_min_height: hint_range(0.0, 400) = 5.0;
// uniform float clouds_max_height: hint_range(0.0, 400) = 15.0;
uniform float clouds_min_height: hint_range(500.0, 4000) = 1500.0;
uniform float clouds_max_height: hint_range(900.0, 4000) = 1500.0;
// uniform float AMBIENT_STRENGTH:hint_range(.0, .101, .00001) = .0;
uniform sampler2D stratus: source_color;
uniform sampler2D cumulus: source_color; // TODO: Apply for distance to center
uniform sampler2D cumulonimbus: source_color;

// Main shape
uniform float map_cut_size: hint_range(0.0, .001, .00001) = 0.0;
uniform float cut_size: hint_range(0.0, .001, .00001) = 0.0;
uniform float cut_size2: hint_range(0.0, .003, .00001) = 0.0;

uniform float clouds_type_test: hint_range(0.0, 1.0, .01) = 0.0;


// WARNING: Probably will remove and hardcode according to clouds type
uniform float base_density: hint_range(0.0, 1.0, .01) = 1.;
// uniform float coverage: hint_range(0.0, 1.0, .01) = 0.5;

uniform float second_degrade: hint_range(0.0, .3, .0001) = 0.0;
uniform float third_degrade: hint_range(0.0, .3, .0001) = 0.0;
uniform float last_degrade: hint_range(0.0, .3, .0001) = 0.0;

group_uniforms sky_color;
uniform vec3 COLOUR_LIGHT_BLUE: source_color;
uniform vec3 COLOUR_BRIGHT_BLUE: source_color;


group_uniforms textures;
uniform sampler3D voronoi: source_color;
uniform sampler3D voronoi2: source_color;
uniform sampler2D blue_noise: source_color;
// uniform sampler2D prev_frame: source_color;

uniform sampler2D map: source_color;

group_uniforms auto_update;
uniform vec3 sun_position;
// uniform vec3 sun_direction;

#include "res://shaders/raymarch_utils.gdshaderinc"

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
    float stratus_coverage = .8;
    result_layer *= stratus_coverage;
    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);
    float stratus_color = texture(stratus, vec2(height, TIME*.0)).r;
    // stratus_color = 1.0;
    // stratus_color = texture(cumulonimbus, vec2(height, TIME*.0)).r;
    const float stratus_density = .1;
    // return result_layer*stratus_density;
    return stratus_color*result_layer*stratus_density;
}

// Bake whipiness into texture?
float get_cumulus(in float height, in vec4 clouds_layers, in float map_coverage){
    float maxAmplitude = 0.0;
    float amplitude = 1.0;
    // float persistence = 4.5;
    float persistence = .2;
    persistence = .0;
    float result_layer = 0.0;

    for(int i = 0; i < 4; i++){
        float layer = clouds_layers[i];
        result_layer += layer * amplitude;
        maxAmplitude += amplitude;
        amplitude *= persistence;
    }

    result_layer /= maxAmplitude;
    float cumulus_coverage = .5;
    result_layer *= cumulus_coverage;
    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);
    float cumulus_color = texture(cumulus, vec2(height, 0)).r;
    const float cumulus_density = .4;
    // return base_density*result_layer*cumulus_density;
    // return cumulus_color*result_layer*cumulus_density;
    return cumulus_color*result_layer*base_density;
    // return cumulus_color*base_density;
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
    float normalized_y = inverse_lerp(clouds_min_height, clouds_max_height, p.y);
    // normalized_y = clamp(normalized_y, 0.0, 1.0); // forze zero where cannot see below our plane?

    // vec3 map_tex = (texture(map, fract(uv*map_cut_size))).rgb;
    vec3 map_tex = (texture(map, (p.xz*map_cut_size))).rgb;
    // map_tex = vec3(1.0);

    float map_coverage = map_tex.r;
    // map_coverage = 1.0;
    float clouds_type = 1.0-map_tex.g;
    // clouds_type = 1.0;
    float precipitation = map_tex.b;

    // Clouds type set which one will be, but chance of one or other increases with coverage or height?
    vec4 clouds_layers = texture(voronoi, p*vec3(cut_size)+vec3(.0, .0, TIME*0.01));
    float stratus_color = get_stratus(normalized_y, clouds_layers, map_coverage);
    float cumulus_color = get_cumulus(normalized_y, clouds_layers, map_coverage);
    float clouds = mix(stratus_color, cumulus_color, clouds_type_test);

    clouds = cumulus_color;
    // clouds = stratus_color;
    return clouds;

}

float sceneSDF(vec3 p) {
    float clouds = simpleSDF(p);
    vec4 clouds_degrade = 1.0-texture(voronoi2, p*vec3(cut_size2)-vec3(.0, .0, TIME*.05));
    clouds -= (1.0-clouds_degrade.r)*second_degrade;
    // clouds = mix(clouds_layers2,(1.0-clouds_layers2.r)*second_degrade;
    clouds -= (1.0-clouds_degrade.r)*third_degrade;
    clouds -= (1.0-clouds_degrade.r)*last_degrade;
    return clouds;
}



// TODO: Add flat clouds to sky
// vec3 skybox(in vec3 ro, in vec3 rd){
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
    // return texture_bg(ro, rd);
// }
float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 rotate_vector(vec3 rd){
    float maxDeviation = 0.0;  // Define your max deviation here
    float theta = maxDeviation * rand(rd.xz) * PI;  // Random rotation angle within max deviation
    float phi = 2.0 * PI * rand(rd.zx);  // Random rotation direction

    // Rotation matrix components
    float st = sin(theta);
    float ct = cos(theta);
    float sp = sin(phi);
    float cp = cos(phi);

    // Rotate the ray direction
    vec3 rd_rotated = vec3(
        rd.x * ct - rd.y * st * cp - rd.z * st * sp,
        rd.x * st * cp + rd.y * ct + rd.z * sp,
        rd.x * st * sp - rd.y * sp + rd.z * ct
    );
    return rd_rotated;

    // samplePosition = p + lightDir * step_size + rd_rotated * randomDeviation * 1.0;
}

float lightmarch(in highp vec3 p, in vec3 rd, float dither) {
    vec3 lightDir = normalize(sun_position);
    float totalDensity = 0.0;
    float totalTransmittance = 1.0;
    vec3 samplePosition = p;
    float step_size = STEPS_SIZE_LIGHTS;
    float result = 0.0;
    for (int i = 0; i < MAX_STEPS_LIGHTS; i++) {
        vec3 randomDeviation = vec3(dither);
        samplePosition = p + lightDir * step_size ;
        // samplePosition = p + rd * step_size ;
        float lightSample = sceneSDF(samplePosition);

        totalDensity += lightSample * step_size; // integration in step
        step_size = mix(STEPS_SIZE_LIGHTS, STEPS_SIZE_LIGHTS_LARGE, float(i)/float(MAX_STEPS_LIGHTS));
        // step_size = STEPS_SIZE_LIGHTS;
    }
    result /= float(MAX_STEPS_LIGHTS);

    // TODO: probably should have the same value for both
    float transmittanceB = BeersLaw(totalDensity, SCATTERING_COEFFICIENT_CLOUDS); // Out scattering approximation, assume no absorption
    float transmittanceP = SugarPowder(totalDensity, SCATTERING_COEFFICIENT_SUGAR); // In scattering approximation
    float beerPowder = transmittanceB*transmittanceP;
    float sun_dir = dot(rd, lightDir)*.5+.5;
    result  = mix(transmittanceB, 1.0*beerPowder, sun_dir);
    return result;
}

float lightmarch2(in highp vec3 p, in vec3 rd, float dither) {
    vec3 lightDir = normalize(sun_position);
    float totalDensity = 0.0;
    float totalTransmittance = 1.0;
    vec3 samplePosition = p;
    float step_size = STEPS_SIZE_LIGHTS;
    float result = 0.0;

    for (int i = 0; i < MAX_STEPS_LIGHTS; i++) {
        // samplePosition += sun_direction*stepL*hash(dot(p, vec3(12.256, 2.646, 6.356)) + iTime);

        samplePosition = p + lightDir * step_size ;
        float lightSample = sceneSDF(samplePosition);
        float transmittanceB = BeersLaw(lightSample*step_size, SCATTERING_COEFFICIENT_CLOUDS); // Out scattering approximation, assume no absorption
        float transmittanceP = SugarPowder(lightSample*step_size, SCATTERING_COEFFICIENT_SUGAR); // In scattering approximation

        float beerPowder = transmittanceB*transmittanceP;
        float sun_dir = dot(rd, lightDir)*.5+.5;
        result += mix(transmittanceB, 1.0*beerPowder, sun_dir);
        step_size = mix(STEPS_SIZE_LIGHTS, STEPS_SIZE_LIGHTS_LARGE, float(i)/float(MAX_STEPS_LIGHTS));
        // step_size = STEPS_SIZE_LIGHTS;
    }
    result /= float(MAX_STEPS_LIGHTS);
    return result; // Good to asume linear given small steps
}

bool calculate(
    in highp vec3 ro,
    in vec3 rd,
    in float phase,
    inout float current_step_size,
    inout highp float depth,
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
            float mul=1.0/2.0;
            depth -= current_step_size/mul;
            samplePosition -= current_step_size/mul * rd;
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
            float lightTransmittance = lightmarch(samplePosition, rd, dither);
            float luminance = (sun_energy * lightTransmittance) * point_density * phase;
            float localExtinction = point_density * SCATTERING_COEFFICIENT_CLOUDS;
            float extinction_across_step = BeersLaw(current_step_size*point_density, SCATTERING_COEFFICIENT_CLOUDS);
            float integrated_scattering = (luminance - luminance * extinction_across_step) / localExtinction;
            lightEnergy += integrated_scattering*transmittance;
            transmittance *= extinction_across_step;
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
vec2 raymarch(in highp vec3 ro, in vec3 rd, in float max_distance_travelled, inout highp float depth, in vec2 coord) {
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
    highp vec3 samplePosition = ro + depth* rd;

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

vec2 rayPlanesDst(in vec3 ro, in vec3 rd) {
    float t1 = (clouds_min_height - ro.y) / rd.y;
    float t2 = (clouds_max_height - ro.y) / rd.y;
    t1 = max(t1, 0.0);
    t2 = max(t2, 0.0);
    return vec2(min(t1, t2), max(t1, t2));
}

vec2 raySphereShellDst(in vec3 ro, in vec3 rd) {
    ro += vec3(.0, -earth_radius, .0);

     // Avoid precission loss by bringing center of sphere to origin
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

    float t2;
    bool hit2 = getOne(b, c, t2);
    float T2 = abs(-b + sqrt(discriminant)) / (2.0);
    // CASE 1
    return abs(vec2(t1, t2));
    if (length(ro) <= innerRadius) {
        return abs(vec2(t1, t2));
    }
    // if (length(ro) > innerRadius && length(ro) < outerRadius) {
    //     if (hit1){
    //         return abs(vec2(t1, T2));
    //     }
    //     return abs(vec2(0, T2));
    //
    // }
    // CASE 3
    if (length(ro) > outerRadius) {
        if (hit2){
            return (vec2(0, T2));
        }
        // return abs(vec2(0, 2));
    }
    // return abs(vec2(0, 0));

    return abs(vec2(t1, t2));
    if (length(ro) > innerRadius) {
        if (length(ro) < outerRadius) {

            if (rd.y > 0.0) { // looking up
                if (t1 < 0.0) { // looking to t2
                    return vec2(0.0, -t2);
                }
                if (t2 < 0.0) { // looking to t1
                    return vec2(0.0, -t2);
                }
            }
            else{
                if (t1 < 0.0) { // looking to t2
                    return vec2(0.0, -t2);
                }
                if (t2 < 0.0) { // looking to t1
                    return vec2(0.0, -t2);
                }

            }
        }
    }


    // t1 = max(-t1, 0.0);
    // t2 = max(-t2, 0.0);
    // return vec2(min(t1, t2), max(t1, t2));
    // return (vec2(t1, t2));
    return abs(vec2(t1, t2));

}

float RenderGlow(float dist, float radius, float intensity) {
  dist = max(dist, 1e-6);
	return (1.0 - exp(-25.0 * (radius / dist))) * 0.1 + (1.0 - exp(-0.05 * (radius / dist) * (radius / dist))) * 2.0;
}

vec4 RenderSky(vec3 cameraOrigin, vec3 cameraDir, float uvy) {
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

void vertex() {
    POSITION = vec4(VERTEX, 1.0); // Stack in front of camera
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
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D bg_texture : hint_screen_texture, source_color;
void fragment(){
    highp float depth = texture(depth_texture, SCREEN_UV).x;
    bool map_hit = depth != 1.0;
    highp vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    int i = 0;
    highp vec4 eye = INV_PROJECTION_MATRIX * clip;
    eye /= eye.w;
    highp vec3 world_position = (INV_VIEW_MATRIX * eye).xyz;
    highp vec3 ndc = get_ndc(SCREEN_UV, depth);
    highp float map_depth = get_linear_depth(ndc, INV_PROJECTION_MATRIX);

    highp vec3 ro = CAMERA_POSITION_WORLD;
    vec3 rd = normalize(world_position - ro);

    // WARNING: Shell should be much lower than our origin
    vec2 rayToContainerInfo = raySphereShellDst(ro, rd); // Fake ray origin to keep spehere centered on us

    // vec2 rayToContainerInfo = rayPlanesDst(ro, rd); // Fake ray origin to keep spehere centered on us
    float dstToMarchStart = rayToContainerInfo.x;
    float dstToMarchEnd = rayToContainerInfo.y;

    vec2 coord = vec2(FRAGCOORD.xy);
    int texture_size = 469;

    coord += vec2(TIME)*1000.0; // 'randomize' and pair with TTA

    // float dither = texelFetch(blue_noise, ivec2(int(coord.x)%texture_size, int(coord.y)%texture_size), 0).r; // TODO: Add more dither the closer

    if (!map_hit){ // Discard if something hit and not out of bounds
        bool clouds_plane_hit = dstToMarchEnd - dstToMarchStart != 0.0;
        float threshold = 0.01; // Define your threshold
        float distance_to_threshold = -log(threshold) / EXCTINCTION_COEFFICIENT_SKY;
        float total_distance = dstToMarchStart-clouds_min_height; // Atenuate based on plane distance
        // total_distance = dstToMarchStart; // Atenuate based on plane distance

        bool scattering_to_high = dstToMarchStart > distance_to_threshold;
        vec4 pixel = RenderSky(ro, rd, SCREEN_UV.y);
        // In sphere will never happen? // or use just scattering to high?

        // Scattering too far can happen
        if (!clouds_plane_hit || scattering_to_high){ // Skip rendering clouds where no clouds can be seen
            ALBEDO = pixel.rgb;
            // discard;
        }
        else{
            float ray_hit_depth = 0.0;
            ro += dstToMarchStart*rd; // Advance ray till clouds volume
            vec2 result = raymarch(ro,rd, dstToMarchEnd-dstToMarchStart, ray_hit_depth, FRAGCOORD.xy);
            float transmittance = result.y;
            float energy = result.x;
            float extinction = exp(-EXCTINCTION_COEFFICIENT_SKY * total_distance);

            vec3 clouds = energy * vec3(1.0);
            vec3 color = clamp(clouds+pixel.rgb*(transmittance), 0.0, 1.0);
            // color = vec3(energy);
            // color = vec3(transmittance);
            ALBEDO = mix(pixel.rgb, color, extinction);
        }
    }
    else{ // We hit something. is it in between the clouds?
        if (map_depth<dstToMarchStart){ // Discard if map closer than clouds
            discard;
        }
        bool clouds_plane_hit = dstToMarchEnd - dstToMarchStart != 0.0;
        float threshold = 0.01; // Define your threshold
        float distance_to_threshold = -log(threshold) / EXCTINCTION_COEFFICIENT_SKY;
        bool scattering_to_high = dstToMarchStart > distance_to_threshold;
        vec4 pixel = RenderSky(ro, rd, SCREEN_UV.y);
        if (!clouds_plane_hit || scattering_to_high){ // Skip rendering clouds where no clouds can be seen
            discard;
        }

        // Map through clouds
        float distance_to_travel = min(map_depth, dstToMarchEnd-dstToMarchStart);
        float ray_hit_depth = 0.0;
        ro += dstToMarchStart*rd; // Advance ray till clouds volume

        vec2 result = raymarch(ro,rd,distance_to_travel , ray_hit_depth, FRAGCOORD.xy);
        float transmittance = result.y;
        float energy = result.x;
        float total_distance = dstToMarchStart; // Atenuate based on plane distance
                                           // float attenuatoin = smoothstep(30000.0, 100.0, total_distance);
        float extinction = exp(-EXCTINCTION_COEFFICIENT_SKY * total_distance);
        vec3 clouds = energy * vec3(1.0);
        vec3 gamma = vec3(1.0/2.2); // Standard gamma correction value
        clouds = pow(clouds, gamma); // Apply gamma correction

        vec3 bg_color = texture(bg_texture, SCREEN_UV).rgb;
        vec3 color= clouds+bg_color*(transmittance);
        ALBEDO.rgb = color;
    }
}

