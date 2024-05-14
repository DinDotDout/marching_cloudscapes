shader_type spatial;
render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;

const float EARTH_RADIUS = 6300e3;
const vec3 WIND_DIRECTION = vec3(0.0, 0.0, 1.0);

group_uniforms sampling;
uniform int min_marching_steps:hint_range(1, 100, 5) = 35;
uniform int MAX_MARCHING_STEPS:hint_range(1, 100, 5) = 60;
uniform float ez_march_threshold: hint_range(0.0, 1.0, .01) = 0.01;


group_uniforms light_interaction;
uniform float sun_energy:hint_range(.0, 100.0, .01) = 1.0;
const vec3 SUN_LIGHT_COLOR = vec3(1.0,.9, 0.6);

uniform int max_steps_lights: hint_range(1, 20) = 6;
// uniform float MAX_LIGHT_SAMPLE_DISTANCE: hint_range(.01, 4000.0, 10.0) = 600.0;
uniform float short_light_step: hint_range(.01, 400.0, 10.0) = 600.0;
uniform float long_light_step: hint_range(.01, 400.0, 10.0) = 600.0;

uniform float scattering_aniso_fw:hint_range(.0, 1.0, .01)  = .5;
uniform float scattering_aniso_bw:hint_range(.0, 1.0, .01)  = .4;

uniform highp float exctinction_coefficient_sky:hint_range(.0, .0002, .000001) = 0.;

// 0.115 to 0.3 cloudy
uniform float SCATTERING_COEFFICIENT_CLOUDS: hint_range(.0, 1.0, .001) = 0.1;
uniform float SCATTERING_COEFFICIENT_SUGAR: hint_range(.0, 0.05, .0001) = 0.1;

group_uniforms raymarched_clouds;
uniform float map_density: hint_range(0.0, 1.0, .01) = 1.0;
uniform float noise_density: hint_range(0.0, 1.0, .01) = 1.0;

uniform float clouds_min_height: hint_range(000.0, 4000, 10.0) = 1500.0;
uniform float clouds_max_height: hint_range(900.0, 10000, 10.0) = 1500.0;

// uniform float AMBIENT_STRENGTH:hint_range(.0, .101, .00001) = .0;

// Main shape
uniform float wheathermap_scale: hint_range(0.0, 1000.00, 10.0) = 1000;
// uniform float clouds_noise_scale: hint_range(0.0, .001, .00001) = 0.0002;

group_uniforms raymarched_clouds.noise;
uniform float noise_weight: hint_range(0.0, 1.0, .01) = 1.0;
uniform float clouds_noise_scale: hint_range(0.0, 300.00, 10.0) = 10000;
uniform float clouds_noise_weight_r: hint_range(0.0, 1.0, .0001) = 0.0;
uniform float clouds_noise_weight_g: hint_range(0.0, 1.0, .0001) = 0.0;
uniform float clouds_noise_weight_b: hint_range(0.0, 1.0, .0001) = 0.0;
uniform float clouds_noise_weight_a: hint_range(0.0, 1.0, .0001) = 0.0;
uniform sampler3D clouds_texture: source_color;

group_uniforms raymarched_clouds.detail_noise;
uniform float detail_noise_weight: hint_range(0.0, 1.0, .01) = 1.0;
uniform float detail_noise_scale: hint_range(0.0, 100.0, 10.0) = 10.0;
uniform float detail_noise_scale_r: hint_range(0.0, 1.0, .0001) = 0.0;
uniform float detail_noise_scale_g: hint_range(0.0, 1.0, .0001) = 0.0;
uniform float detail_noise_scale_b: hint_range(0.0, 1.0, .0001) = 0.0;
uniform sampler3D clouds_detail_texture: source_color;
group_uniforms;
group_uniforms raymarched_clouds;

uniform sampler2D wheater_map: source_color;
uniform sampler2D stratus_height_density: source_color;
uniform sampler2D cumulus_height_density: source_color; // TODO: Apply for distance to center

group_uniforms high_altitude_clouds;
uniform sampler3D cirrus: source_color;
const float CIRRUS_HEIGHT = 10000.0;
uniform float cirrus_scale: hint_range(10.0, 600, 10) = 1000.0;
uniform float cirrus_density: hint_range(0.0, 4.0, .001) = 0.0;
uniform float cirrus_coverage: hint_range(0.0, 1.0, .001) = 1.0;

group_uniforms sky;
uniform vec3 sky_color: source_color = vec3(.5, .675, .89);
uniform float sky_brightness: hint_range(0.0, 1.0, .01) = 0.7;
uniform float brightness_gradient_strength: hint_range(0.0, 10.0, .01) = 4.0;

group_uniforms sun;
uniform vec3 sun_position;
uniform float sun_radius: hint_range(0.0, .01, .0001) = 0.001;
group_uniforms;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D bg_texture : hint_screen_texture, source_color;

#include "res://shaders/raymarch_utils.gdshaderinc"
float simple_sdf(vec3 p) {
    float atmosphere_height = length(p - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
    float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);
    vec2 mapSize = vec2(textureSize(wheater_map, 0));
    float map_coverage = (texture(wheater_map, ((p.xz/wheathermap_scale)+vec2(-200.0, 200.0+TIME*0.3))/mapSize)).r;

    vec3 clouds_noise_size = vec3(textureSize(clouds_texture, 0));
    vec4 clouds_layers = texture(clouds_texture, (p/vec3(clouds_noise_scale)-WIND_DIRECTION*TIME*1.00)/clouds_noise_size);
    float cumulus_noise =  0.0;
    /* Calculate cloud noise fbm*/ {
        vec4 noise_weights = vec4(clouds_noise_weight_r, clouds_noise_weight_g, clouds_noise_weight_b, clouds_noise_weight_a);
        vec4 normalized_weights = noise_weights / dot(noise_weights, vec4(1.0)); // Divide by sum
        float fbm = dot(clouds_layers, normalized_weights);
        cumulus_noise = fbm;
    }
    float cumulus_color = texture(cumulus_height_density, vec2(normalized_y, 0)).r;
    map_coverage *= noise_density;
    return clamp(smoothmin(map_coverage, cumulus_noise, noise_weight*2.0)*map_density*cumulus_color, .0, 1.0);
}

float scene_sdf(vec3 p) {
    float clouds = simple_sdf(p);
    float detail_fbm = 0.0;
    /* Calculate cloud detail noise fbm*/ {
        vec3 detail_noise_weights = vec3(detail_noise_scale_r, detail_noise_scale_g, detail_noise_scale_b);
        vec3 normalized_weights = detail_noise_weights / dot(detail_noise_weights, vec3(1.0)); // Divide by sum
        vec3 detail_noise_size = vec3(textureSize(clouds_detail_texture, 0));
        vec3 clouds_degrade = texture(clouds_detail_texture, (p/vec3(detail_noise_scale)-WIND_DIRECTION*TIME*2.0)/detail_noise_size).rgb;
        detail_fbm = dot(clouds_degrade.rgb, normalized_weights);
    }
    float one_minus_shape = 1.0 - clouds;
    float detail_erode_weight = one_minus_shape*one_minus_shape*one_minus_shape; // Erode more towards the edges
    float erosion = (detail_fbm) * detail_erode_weight * detail_noise_weight; // This affects the interior
    float clouds_density = clouds - erosion;
    return max(0.0, clouds_density);
}

float lightmarch_simple_sdf(in highp vec3 p, in vec3 rd) {
    vec3 lightDir = normalize(sun_position);
    float step_size = short_light_step;

    float randomDeviation = hash11(dot(p, vec3(12.256, 2.646, 6.356)) + TIME);
    p += randomDeviation*step_size*lightDir;

    float totalDensity = 0.0;
    for (int i = 0; i < max_steps_lights; i++) {
        step_size = mix(short_light_step, long_light_step, float(i)/float(max_steps_lights));
        float lightSample = simple_sdf(p+rd*float(i)*step_size);
        totalDensity += lightSample*step_size; // integration in step
    }

    float transmittanceB = beers_law(totalDensity, SCATTERING_COEFFICIENT_CLOUDS); // Out scattering approximation, assume no absorption
    float transmittanceP = SugarPowder(totalDensity, SCATTERING_COEFFICIENT_SUGAR); // In scattering approximation
    float beerPowder = transmittanceB+transmittanceP;
    float sun_dir = dot(rd, lightDir)*.5+.5;
    float result  = mix(transmittanceB, beerPowder, sun_dir);
    return result;
}

float lightmarch(in highp vec3 p, in vec3 rd) {
    vec3 lightDir = normalize(sun_position);
    float step_size = short_light_step;
    float randomDeviation = hash11(dot(p, vec3(12.256, 2.646, 6.356)) + TIME);
    p += randomDeviation*step_size*lightDir;
    float totalDensity = 0.0;
    for (int i = 0; i < max_steps_lights; i++) {
        step_size = mix(short_light_step, long_light_step, float(i)/float(max_steps_lights));
        float lightSample = scene_sdf(p+rd*float(i)*step_size);
        totalDensity += lightSample*step_size; // integration in step
    }

    float mu = dot(rd, -lightDir);
    float transmittanceB = beers_law(totalDensity, SCATTERING_COEFFICIENT_CLOUDS); // Out scattering approximation, assume no absorption
    float transmittanceP = SugarPowder(totalDensity, SCATTERING_COEFFICIENT_SUGAR); // In scattering approximation
    float beerPowder = transmittanceB+transmittanceP;
    float sun_dir = dot(rd, lightDir)*.5+.5;
    float result  = mix(transmittanceB, beerPowder, sun_dir);
    return result;
}
vec4 raymarch(in highp vec3 ro, in vec3 rd, in float max_distance_travelled, inout highp float depth) {
    vec4 light = vec4(vec3(0.0), 1.0);
    vec3 lightDir = normalize(sun_position);
    // Double Lobe HG
    float mu = dot(rd, lightDir);
    float phase = mix(henyey_greenstein(-scattering_aniso_bw, mu), henyey_greenstein(scattering_aniso_fw, mu), 0.5);

    float view_height_dot = clamp(dot(rd, vec3(0.0, 1.0, 0.0)), 0.0, 1.0); // 0 horizon 1 up
    int marching_steps = int(mix(float(MAX_MARCHING_STEPS), float(min_marching_steps), view_height_dot));
    float detail_step_size = max_distance_travelled/float(marching_steps)/1.0; // Ensure we reach the end
    float traverse_step_size = detail_step_size*3.0; // Ensure we reach the end
    float current_step_size = traverse_step_size;
    depth += hash11(dot(rd, vec3(12.256, 2.646, 6.356)) + TIME)*traverse_step_size;

    highp vec3 samplePosition = ro + depth * rd;
    int missed_steps = 0;
    bool traversing = true;
    for (int i = 0; i < marching_steps; i++) {

        float point_density;
        traversing = false;
        current_step_size = detail_step_size;

        // if (traversing || light.a <= ez_march_threshold){
        //     point_density = simple_sdf(samplePosition);
        // }
        // else{
        //     point_density = scene_sdf(samplePosition);
        // }

        point_density = scene_sdf(samplePosition);
        bool hit = point_density > 0.001;
        if (hit) {
            current_step_size = detail_step_size;
            float lightTransmittance;
            lightTransmittance = lightmarch(samplePosition, rd);
            // if (light.a < ez_march_threshold) {
            //     lightTransmittance = lightmarch_simple_sdf(samplePosition, rd);
            // }
            // else{
            //     lightTransmittance = lightmarch(samplePosition, rd);
            // }

            float atmosphere_height = length(samplePosition - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
            float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);

            vec3 ambient = (0.5 + 0.6*normalized_y)*vec3(0.4, 0.6, 1.0)*.2 + vec3(0.4) * max(0.0, 1.0-2.0*normalized_y);
            ambient = vec3(0.8, 0.8, 1.0)*.4;
            vec3 radiance = ambient + sun_energy*SUN_LIGHT_COLOR*lightTransmittance*phase;
            radiance *= point_density; // Captured radiance
            float localExtinction = point_density * SCATTERING_COEFFICIENT_CLOUDS;
            float stepExtinction = beers_law(detail_step_size*point_density, SCATTERING_COEFFICIENT_CLOUDS);
            vec3 integrated_scattering = (radiance - radiance * stepExtinction) / localExtinction;
            light.rgb += integrated_scattering*light.a;
            light.a *= stepExtinction;
            if (light.a < 0.01) {
                break;
            }

            // missed_steps = 0; // Reset
            // if (traversing){
            //     depth -= traverse_step_size;
            //     samplePosition -= traverse_step_size * rd;
            //     current_step_size = detail_step_size;
            // }
            // else{
            //     current_step_size = detail_step_size;
            //     float lightTransmittance;
            //     if (light.a < ez_march_threshold) {
            //         lightTransmittance = lightmarch_simple_sdf(samplePosition, rd);
            //     }
            //     else{
            //         lightTransmittance = lightmarch(samplePosition, rd);
            //     }
            //
            //     float atmosphere_height = length(samplePosition - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
            //     float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);
            //
            //     vec3 ambient = (0.5 + 0.6*normalized_y)*vec3(0.4, 0.6, 1.0)*.2 + vec3(0.4) * max(0.0, 1.0-2.0*normalized_y);
            //     ambient = vec3(0.8, 0.8, 1.0)*.4;
            //     vec3 radiance = ambient + sun_energy*SUN_LIGHT_COLOR*lightTransmittance*phase;
            //     radiance *= point_density; // Captured radiance
            //     float localExtinction = point_density * SCATTERING_COEFFICIENT_CLOUDS;
            //     float stepExtinction = beers_law(detail_step_size*point_density, SCATTERING_COEFFICIENT_CLOUDS);
            //     vec3 integrated_scattering = (radiance - radiance * stepExtinction) / localExtinction;
            //     light.rgb += integrated_scattering*light.a;
            //     light.a *= stepExtinction;
            //     if (light.a < 0.01) {
            //         break;
            //     }
            // }
            // traversing = false;
        }
        // else{
        //     missed_steps++;
        //     if (missed_steps > 4){
        //         traversing = true;
        //         current_step_size = traverse_step_size;
        //     }
        // }

        depth += detail_step_size;
        samplePosition += detail_step_size * rd;
        if (depth >= max_distance_travelled) {
            break;
        }
    }
    return light;
}

vec3 render_sun(float dist, float radius) {
    dist = max(dist, 1e-6);
    float glow = (1.0 - exp(-25.0 * (radius / dist))) * 0.1 + (1.0 - exp(-0.05 * (radius / dist) * (radius / dist))) * 2.0;
    vec3 sun =  vec3(glow, glow*.6, 0.0)*sun_energy;
    return sun;
}

vec3 render_sky(vec3 cameraDir) {
    vec3 background = 3.0*vec3(sky_color); // uper sky
    background += vec3(sky_brightness) * max(0.0, 1.0 - brightness_gradient_strength*cameraDir.y); // lower sky half
    return background;
}

void vertex() {
    POSITION = vec4(VERTEX, 1.); // Stack in front of camera
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


void fragment(){
    highp float depth = texture(depth_texture, SCREEN_UV).x;
    bool map_hit = depth != 1.0;
    highp vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    // highp vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
    int i = 0;
    highp vec4 eye = INV_PROJECTION_MATRIX * clip;
    eye /= eye.w;
    highp vec3 world_position = (INV_VIEW_MATRIX * eye).xyz;
    highp vec3 ndc = get_ndc(SCREEN_UV, depth);
    highp float map_depth = get_linear_depth(ndc, INV_PROJECTION_MATRIX);

    highp vec3 ro = CAMERA_POSITION_WORLD;
    vec3 rd = normalize(world_position - ro);

    // TODO: Fix fly over clouds
    float dstToMarchStart = ray_sphere_distance(ro, rd, vec3(.0, -EARTH_RADIUS, .0), EARTH_RADIUS+clouds_min_height);
    float dstToMarchEnd = ray_sphere_distance(ro, rd, vec3(.0, -EARTH_RADIUS, .0), EARTH_RADIUS+clouds_max_height);
    int texture_size = 469;


    float total_distance = dstToMarchStart; // Atenuate based on plane distance
    total_distance -= clouds_min_height;
    float extinction = exp(-exctinction_coefficient_sky * total_distance);
    if (!map_hit){ // Discard if something hit and not out of bounds
        bool clouds_plane_hit = dstToMarchEnd - dstToMarchStart != 0.0;
        float threshold = 0.001; // Define your threshold
        float distance_to_threshold = -log(threshold) / exctinction_coefficient_sky;
        // total_distance = dstToMarchStart; // Atenuate based on plane distance

        bool scattering_to_high = dstToMarchStart > distance_to_threshold;
        vec3 sky = render_sky(rd);
        float mu = dot(rd, normalize(sun_position));
        float mu_norm = inverse_lerp(1.0, -1.0, mu);
        vec3 sun = render_sun(mu_norm, sun_radius);

        if (!clouds_plane_hit || scattering_to_high){ // Skip rendering clouds where no clouds can be seen
            ALBEDO = sky+sun;
            vec3 color = mix(sky, sky+sun, extinction);
            ALBEDO = color;
        }
        else{
            float ray_hit_depth = 0.0;

            float cosine = length(vec3(rd.x, 0.0, rd.z));
            vec4 result = raymarch(ro+rd*dstToMarchStart,rd, dstToMarchEnd-dstToMarchStart, ray_hit_depth);
            float transmittance = result.w;
            vec3 clouds_color = result.xyz;
            vec3 earth_center = vec3(0, EARTH_RADIUS, 0); // assuming Earth's center is at (0, EARTH_RADIUS, 0)
            float cirrus_distance = ray_sphere_distance(ro, rd, vec3(.0, -EARTH_RADIUS, .0), EARTH_RADIUS + CIRRUS_HEIGHT);
            vec3 evolution_over_time = vec3(0,1,0); // Pan y axis to simulate wind
            vec3 cirrusSize = vec3(textureSize(cirrus, 0));
            // float high_clouds = texture(cirrus, (p/cirrus_scale+(evolution_over_time+WIND_DIRECTION)*TIME*0.01)).r;
            float cirrus_extinction = exp(-exctinction_coefficient_sky * cirrus_distance);
            float high_clouds = texture(cirrus, (cirrus_distance*rd/cirrus_scale+(evolution_over_time-WIND_DIRECTION)*TIME*.01)/cirrusSize).r;
            high_clouds -= (1.0-cirrus_coverage);
            high_clouds = max(0.0, high_clouds);
            // high_clouds *= cirrus_density*cirrus_extinction;
            high_clouds *= cirrus_density*extinction;
            vec3 skybox = (sky+high_clouds+sun)*transmittance+clouds_color;
            skybox = mix(sky, skybox, extinction);
            ALBEDO = skybox;
        }
    }
    else{ // We hit something. is it in between the clouds?

        // This already works if disable but can be optimized
        if (map_depth<dstToMarchStart){ // Discard if map closer than clouds plane
            discard;
        }

        bool clouds_plane_hit = dstToMarchEnd - dstToMarchStart != 0.0;
        float threshold = 0.001; // Define your threshold
        float distance_to_threshold = -log(threshold) / exctinction_coefficient_sky;
        bool scattering_to_high = dstToMarchStart > distance_to_threshold;
        vec3 sky = render_sky(rd);
        float mu = dot(rd, normalize(sun_position));
        float mu_norm = inverse_lerp(1.0, -1.0, mu);
        vec3 sun = render_sun(mu_norm, sun_radius);
        if (!clouds_plane_hit || scattering_to_high){ // Skip rendering clouds where no clouds can be seen
            discard;
        }
        if (dstToMarchStart < 0.0){
            ALBEDO = sky+sun;
            vec3 color = mix(sky, sky+sun, extinction);
            ALBEDO = color;
        }
        else { // Above clouds
            // Map through clouds
            float distance_to_travel = min(map_depth, dstToMarchEnd-dstToMarchStart);
            float ray_hit_depth = 0.0;
            vec4 result = raymarch(ro+rd*dstToMarchStart,rd, distance_to_travel , ray_hit_depth);
            vec3 energy = result.xyz;
            float transmittance = result.w;
            // float total_distance = dstToMarchStart; // Atenuate based on plane distance
            // float total_distance = dstToMarchStart-clouds_min_height; // Atenuate based on plane distance
            // float extinction = exp(-exctinction_coefficient_sky * total_distance);
            vec3 clouds = energy * vec3(1.0);

            vec3 bg_color = texture(bg_texture, SCREEN_UV).rgb;
            vec3 color = clouds+bg_color*(transmittance);
            ALBEDO.rgb = color;
        }
    }
}
