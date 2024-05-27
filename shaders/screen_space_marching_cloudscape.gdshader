// TODO: Implement proper atmosphere scattering instead of faking it.
// TODO: Either fix the variable distance step or combine with other model depending
// on spehere intersections.
// TODO: Set up sampling as const and profile.

#define TAA_ENABLED // Comment out to enable dithering.
// #define DISTANCE_BASED_STEP_SIZE
shader_type spatial;
render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;

const float EARTH_RADIUS = 6300e3;
const vec3 WIND_DIRECTION = vec3(0.0, 0.0, 1.0);
const vec3 SUN_LIGHT_COLOR = vec3(1.0,.9, 0.6);
const float ATOMSPHERE_EXTINCTION_THRESHOLD = 0.001;

group_uniforms sampling;
uniform float fast_march_transmitance_thresh: hint_range(0.0, 1.0, .01) = 0.01;
uniform int min_marching_steps:hint_range(1, 100, 5) = 35;
uniform int max_marching_steps:hint_range(1, 100, 5) = 60;
uniform float stop_distance: hint_range(10000.0, 300000.0, 1000.0) = 35000.0;
#ifdef DISTANCE_BASED_STEP_SIZE
group_uniforms sampling.distance_based_step_size;
uniform float min_step_size: hint_range(0, 1000, 5) = 100;
uniform float max_step_size: hint_range(0, 50000, 5) = 2000;
uniform float step_size_threshold: hint_range(1000.0, 100000.0, 100.0) = 8000.0;
group_uniforms;
#endif
group_uniforms sampling.light_sampling;
uniform int max_steps_lights: hint_range(1, 20) = 5;
uniform float light_step_short: hint_range(.01, 400.0, 10.0) = 100.0;
uniform float light_step_long: hint_range(.01, 400.0, 10.0) = 400.0;
group_uniforms;

// NOTE: Could be separated into respective groups but usually they are adjusted together.
group_uniforms light_interaction;
uniform float sun_energy: hint_range(.0, 100.0, .01) = 14.0;
uniform vec3 ambient_light: source_color = vec3(0.8, 0.8, 1.0);
uniform float ambient_energy: hint_range(.0, 1.0, .01) = 0.4;
uniform float scattering_aniso_fw:hint_range(.0, 1.0, .01)  = .8;
uniform float scattering_aniso_bw:hint_range(.0, 1.0, .01)  = .5;
uniform float extinction_coefficient_sky:hint_range(.000001, .0001, .000001) = 0.000015; // 0.000012.
// NOTE: Will refer to it as scattering due to clouds having small absorption and mainly scattering.
uniform float scattering_coefficient_clouds: hint_range(.001, 1.0, .001) = 0.3; // 0.115 to 0.3 cloudy.
uniform float scattering_coefficient_sugar: hint_range(.0, 0.05, .0001) = 0.004;

group_uniforms clouds_wind;
uniform float wind_speed: hint_range(0.0, 10.0, .01) = 10.0;

group_uniforms raymarched_clouds;
uniform float map_density: hint_range(0.0, 1.0, .01) = 1.0;
uniform float clouds_min_height: hint_range(10.0, 4000, 10.0) = 1400.0;
uniform float clouds_max_height: hint_range(900.0, 10000, 10.0) = 4000.0;
uniform float wheathermap_tile_radius: hint_range(1000.0, 100000.0, 100.0) = 50000.0; // Texture size incircle radius.

group_uniforms raymarched_clouds.noise;
uniform float noise_weight: hint_range(0.0, 1.0, .01) = 0.5;
uniform float clouds_noise_scale: hint_range(1000.0, 40000.00, 100.0) = 30000.0;
uniform vec4 clouds_noise_fbm_weights = vec4(0.8, 0.32, 0.8, 1.0);
uniform sampler3D clouds_texture: source_color;

group_uniforms raymarched_clouds.detail_noise;
uniform float detail_noise_weight: hint_range(0.0, 0.5, .01) = 0.10;
uniform float detail_noise_scale: hint_range(1.0, 4000.0, 10.0) = 1500.0;
uniform vec3 detail_noise_fbm_weights = vec3(0.4, 0.8, 0.8);
uniform sampler3D clouds_detail_texture: source_color;
group_uniforms;
group_uniforms raymarched_clouds;

uniform sampler2D wheater_map: source_color;
uniform sampler2D clouds_height_density: source_color; // TODO: Apply for distance to center.

group_uniforms high_altitude_clouds;
uniform sampler3D cirrus: source_color;
uniform float cirrus_height: hint_range(100.0, 20000.0, 100.0) = 10000.0;
uniform float cirrus_scale: hint_range(10000.0, 30000, 100) = 30000.0;
uniform float cirrus_density: hint_range(0.0, 4.0, .001) = 3.0;
uniform float cirrus_coverage: hint_range(0.0, 1.0, .001) = 1.0;

group_uniforms sky;
uniform vec3 sky_color: source_color = vec3(.39, .59, .83);
uniform float sky_brightness: hint_range(0.0, 2.0, .01) = 1.0;
uniform float brightness_gradient_strength: hint_range(0.0, 10.0, .01) = 2.5;

group_uniforms sun;
uniform vec3 sun_position = vec3(0.0, 0.7, 0.7);
uniform float sun_radius: hint_range(0.0, .01, .0001) = 0.0002;
group_uniforms;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D bg_texture : hint_screen_texture, source_color;

struct SunData {
    vec3 light_dir;
    float mu;
};

struct WorldSpaceData {
    vec3 world_position;
    float linear_depth;
};

#include "res://shaders/raymarch_utils.gdshaderinc"

float simple_sdf(vec3 p) {
    vec2 normalized_coordinates = (p.xz/(wheathermap_tile_radius*2.0));
    // NOTE: could use more texture channels to sequeeze in more data.
    float map_coverage = texture(wheater_map, normalized_coordinates + vec2(0.5)).r; // Center texture above us.
    float clouds_fbm=  0.0;
    /* Calculate clouds noise fbm*/ {
        vec3 wind = WIND_DIRECTION*TIME*wind_speed*0.001;
        vec4 clouds_layers = texture(clouds_texture, (p/vec3(clouds_noise_scale)-wind));
        vec4 normalized_weights = clouds_noise_fbm_weights / dot(clouds_noise_fbm_weights, vec4(1.0));
        clouds_fbm = dot(clouds_layers, normalized_weights);
    }
    float atmosphere_height = length(p - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
    float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);

    float clouds_height_gradient = texture(clouds_height_density, vec2(normalized_y, 0)).r;
    clouds_height_gradient = max(0.0, clouds_height_gradient);

    return clamp(smoothmin(map_coverage, clouds_fbm, noise_weight*2.0)*map_density*clouds_height_gradient, .0, 1.0);
}

float scene_sdf(vec3 p) {
    float clouds = simple_sdf(p);
    float detail_fbm = 0.0;
    /* Calculate clouds detail noise fbm*/ {
        vec3 wind = WIND_DIRECTION*TIME*wind_speed*0.001;
        vec3 normalized_weights = detail_noise_fbm_weights / dot(detail_noise_fbm_weights, vec3(1.0));
        vec3 clouds_degrade = texture(clouds_detail_texture, (p/vec3(detail_noise_scale)-wind)).rgb;
        detail_fbm = dot(clouds_degrade.rgb, normalized_weights) * detail_noise_weight;
    }
    float one_minus_clouds = 1.0 - clouds;
    float detail_erode_weight = one_minus_clouds*one_minus_clouds*one_minus_clouds; // Erode more towards the edges.
    float clouds_density = clouds - (detail_fbm*detail_erode_weight);
    return max(0.0, clouds_density);
}

float lightmarch_simple_sdf(in highp vec3 p, in vec3 rd, in SunData sun_data) {
    float total_density = 0.0;
    for (int i = 0; i < max_steps_lights; i++) {
        float step_size = mix(light_step_short, light_step_long, float(i)/float(max_steps_lights));
        float light_sample = simple_sdf(p);
        total_density += light_sample*step_size; // Integration in step.
        p += sun_data.light_dir*step_size*float(i);
    }

    float in_scattering = beers_law(total_density, scattering_coefficient_clouds); // Out scattering approximation, assume no absorption.
    float out_scattering = sugar_powder(total_density, scattering_coefficient_sugar); // In scattering approximation.
    float beer_powder = in_scattering+out_scattering;
    float mu_normalized = -sun_data.mu*.5+.5;
    float result  = mix(in_scattering, beer_powder, mu_normalized);
    return result;
}


float lightmarch(in highp vec3 p, in vec3 rd, in SunData sun_data) {
    float total_density = 0.0;
    for (int i = 0; i < max_steps_lights; i++) {
        float light_sample = scene_sdf(p);
        float step_size = mix(light_step_short, light_step_long, float(i)/float(max_steps_lights));
        total_density += light_sample*step_size; // Integration in step.
        p += sun_data.light_dir*step_size*float(i);
    }

    // Far sample to catch further clouds
    float light_sample = scene_sdf(p+sun_data.light_dir*1000.0);
    total_density += light_sample*1000.0;

    float in_scattering = beers_law(total_density, scattering_coefficient_clouds); // Out scattering approximation, assume no absorption.
    float out_scattering = sugar_powder(total_density, scattering_coefficient_sugar); // In scattering approximation.
    float beer_powder = in_scattering+out_scattering;
    float inv_mu_normalized = -sun_data.mu*.5+.5;
    float result = mix(in_scattering, beer_powder, inv_mu_normalized);
    return result;
}


// NOTE: Could retrieve hit depth for other effects.
vec4 raymarch(in highp vec3 ro, in vec3 rd, in float max_distance_travelled, in SunData sun_data){
    vec4 light = vec4(vec3(0.0), 1.0);

    // Double Lobe HG.
    float phase = mix(henyey_greenstein(-scattering_aniso_bw, sun_data.mu), henyey_greenstein(scattering_aniso_fw, sun_data.mu), 0.5);
    vec3 ambient = ambient_light*ambient_energy;

    // NOTE: Maybe a texture would ensure better randomness.
#ifdef TAA_ENABLED
    float dither = hash11(dot(rd, vec3(12.256, 2.646, 6.356)));
#else
    // NOTE: If no taa is used, dithering + TIME can be used to hide dither.
    float dither = hash11(dot(rd, vec3(12.256, 2.646, 6.356)) + TIME);
#endif

    float view_height_dot = abs(dot(rd, vec3(0.0, 1.0, 0.0))); // 0 horizon 1 up/down.
    int total_marching_steps = int(mix(float(max_marching_steps), float(min_marching_steps), view_height_dot));
#ifdef DISTANCE_BASED_STEP_SIZE
    float step_size = min_step_size;
#else
    float step_size = max_distance_travelled/float(total_marching_steps); // Ensure we reach the end
#endif

    float depth = dither*step_size;

    highp vec3 sample_position = ro + depth * rd;
    for (int i = 0; i <  total_marching_steps; i++) {
        float point_density;
        point_density = scene_sdf(sample_position);
#ifdef DISTANCE_BASED_STEP_SIZE // Calculate variable step size based on distance.
        float t = depth / step_size_threshold; // NOTE: Works best for now.
        // t = (t*t)+t;
        // t = t*t*t;
        step_size = min(mix(min_step_size, max_step_size, t), max_step_size);
#endif
        if (point_density > 0.001){
            float light_transmittance;
            if (light.a < fast_march_transmitance_thresh) {
                light_transmittance = lightmarch_simple_sdf(sample_position, rd, sun_data);
            }
            else{
                light_transmittance = lightmarch(sample_position, rd, sun_data);
            }
            // light_transmittance = lightmarch(sample_position, rd, sun_data);
            vec3 radiance = ambient + sun_energy*SUN_LIGHT_COLOR*light_transmittance*phase;
            radiance *= point_density; // Captured radiance
            float local_scattering = point_density * scattering_coefficient_clouds;
            float step_scattering = beers_law(step_size*point_density, scattering_coefficient_clouds);
            vec3 integrated_scattering = (radiance - radiance * step_scattering) / local_scattering;
            light.rgb += integrated_scattering*light.a;
            light.a *= step_scattering;
            if (light.a < 0.01) {
                break;
            }
        }
        depth += step_size;
        sample_position += step_size * rd;
        if (depth >= max_distance_travelled) {
            break;
        }
    }
    return light;
}

vec3 render_sun(in float mu, in float radius) {
    float mu_normalized = 1.0-(mu * 0.5 + 0.5);
    mu_normalized = max(mu_normalized, 1e-6);
    float sun_intensity = (1.0 - exp(-25.0 * (radius / mu_normalized))) * 0.1; // Soft edge
    sun_intensity += (1.0 - exp(-0.05 * pow(radius / mu_normalized, 2))) * 2.0; // Hard edge
    vec3 sun = vec3(sun_intensity, sun_intensity * 0.6, 0.0) * sun_energy;
    return sun;
}

vec3 render_sky(in vec3 rd) {
    vec3 background = 3.0*vec3(sky_color); // uper sky
    background += vec3(sky_brightness) * max(0.0, 1.0 - brightness_gradient_strength*rd.y); // lower sky half
    return background;
}

float render_high_clouds(in vec3 ro, in vec3 rd){
    float cirrus_distance = ray_sphere_distance(
            ro,
            rd,
            vec3(.0, -EARTH_RADIUS, .0),
            EARTH_RADIUS + cirrus_height).y;

    // bool above_cirrus = cirrus_distance < 0.0;
    // if (above_cirrus){
    //     return 0.0;
    // }
    float above_cirrus = step(0.0, cirrus_distance);

    // Scrolling up direction to simulate change over time.
    vec3 wind = (vec3(0,1,0)-WIND_DIRECTION)*TIME*wind_speed*0.0005;
    vec2 cirrus_tex = texture(cirrus, ((ro+rd*cirrus_distance)/cirrus_scale+wind)).rg; // Fixed distance
    float high_clouds = (cirrus_tex.r*cirrus_tex.g)/2.0; // Fbm
    high_clouds = max(0.0, high_clouds - (1.0-cirrus_coverage)); // Degrade
    float cirrus_extinction = exp(-extinction_coefficient_sky * abs(cirrus_distance));
    high_clouds *= cirrus_density*cirrus_extinction;

    high_clouds *= above_cirrus; // Only render below cirrus layer
    return high_clouds;
}

vec2 get_ray_start_end(in vec3 ro, in vec3 rd){
    vec2 inner_sphere_dst = ray_sphere_distance(
            ro,
            rd, 
            vec3(.0, -EARTH_RADIUS, .0),
            EARTH_RADIUS+clouds_min_height);

    vec2 outer_sphere_dst = ray_sphere_distance(
            ro,
            rd,
            vec3(.0, -EARTH_RADIUS, .0),
            EARTH_RADIUS+clouds_max_height);

    float ray_start_dst = inner_sphere_dst.y;
    float ray_end_dst = outer_sphere_dst.y;

    bool inside_inner = inner_sphere_dst.x < 0.0;
    bool inside_outer = outer_sphere_dst.x < 0.0;

    bool no_inner_intersection = inner_sphere_dst.x < 0.0 && inner_sphere_dst.y < 0.0;
    if (no_inner_intersection){ // Outside inner intersecting outer shell
        ray_start_dst = max(.0, outer_sphere_dst.x) ;
    }
    else if (!inside_outer){
        ray_start_dst = outer_sphere_dst.x;
        ray_end_dst = inner_sphere_dst.x;
    }
    else if (!inside_inner){ // Positive so outside inner shell but intersecting inner
        ray_start_dst = 0.0;
        ray_end_dst = inner_sphere_dst.x; // min max travelled?
    } // Else is default case

    float ray_travel_dst = min(ray_end_dst, stop_distance)-ray_start_dst;
    return vec2(ray_start_dst, ray_travel_dst);
}

WorldSpaceData get_world_space_data(in float normalized_depth, in vec2 screen_uv, in mat4 inv_projection_matrix, in mat4 inv_view_matrix){
    highp vec3 ndc = vec3(screen_uv* 2.0 - 1.0, normalized_depth);
    highp vec4 clip = vec4(ndc, 1.0);
    highp vec4 eye = inv_projection_matrix * clip;
    eye /= eye.w;

    highp vec3 world_position = (inv_view_matrix * eye).xyz;

    vec4 view = inv_projection_matrix * clip;
    view.xyz /= view.w;
    float linear_scene_depth = -view.z;
    return WorldSpaceData(world_position, linear_scene_depth);
}

void vertex() {
    POSITION = vec4(VERTEX, 1.); // Stack triangle mesh in front of camera.
}

void fragment(){
    highp float normalized_depth = texture(depth_texture, SCREEN_UV).x;
    WorldSpaceData frag = get_world_space_data(normalized_depth, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
    highp vec3 ro = CAMERA_POSITION_WORLD;
    vec3 rd = normalize(frag.world_position - ro);

    vec2 start_end = get_ray_start_end(ro, rd);
    float ray_start_dst = start_end.x;
    float ray_travel_dst = start_end.y;

    SunData sun_data;
    sun_data.light_dir = normalize(sun_position);
    sun_data.mu = dot(rd, sun_data.light_dir);
    vec3 sky = render_sky(rd);
    vec3 sun = render_sun(sun_data.mu, sun_radius);
    float high_clouds = render_high_clouds(ro, rd);

    float atmosphere_extinction = exp(-extinction_coefficient_sky * (ray_start_dst));
    float distance_to_threshold = -log(ATOMSPHERE_EXTINCTION_THRESHOLD) / extinction_coefficient_sky;
    bool is_extinction_to_high = ray_start_dst > distance_to_threshold; // Avoid rendering when ray is too far away

    bool scene_under_clouds = frag.linear_depth < ray_start_dst; // clouds plane behind map
    bool valid_depth = normalized_depth < 1.0; // Max scene depth
    if ((scene_under_clouds || map_density <= .0) && valid_depth){
        vec3 scene = texture(bg_texture, SCREEN_UV).rgb;
        atmosphere_extinction = exp(-extinction_coefficient_sky * (frag.linear_depth));
        scene = mix(sky, scene, atmosphere_extinction);
        ALBEDO.rgb = scene;
    }
    else if (is_extinction_to_high || ray_travel_dst <= 0.0){ // No visible clouds
        ALBEDO = sky+high_clouds+sun;
    } else {
        float depth = 0.0;
        ro += rd*ray_start_dst; // Advance ray to start position
        if (!valid_depth){
            vec4 result = raymarch(ro, rd, ray_travel_dst, sun_data);
            float transmittance = result.w;
            vec3 clouds_color = result.xyz;
            vec3 skybox = (sky+high_clouds+sun)*transmittance+clouds_color;
            // Keep the sun visible but fade out the clouds.
            skybox = mix(sky+sun*transmittance, skybox, atmosphere_extinction);
            ALBEDO = skybox;
        }
        else{
            ray_travel_dst = min(ray_travel_dst, frag.linear_depth - ray_start_dst);
            vec4 result = raymarch(ro, rd, ray_travel_dst, sun_data);
            float transmittance = result.w;
            vec3 clouds_color = result.xyz;
            vec3 scene = texture(bg_texture, SCREEN_UV).rgb;

            vec3 clouds_scene_overlay = clouds_color + scene * transmittance;
            atmosphere_extinction = exp(-extinction_coefficient_sky * (frag.linear_depth));
            clouds_scene_overlay = mix(sky, clouds_scene_overlay, atmosphere_extinction);
            ALBEDO.rgb = clouds_scene_overlay;
        }
    }
}
