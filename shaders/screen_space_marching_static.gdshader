shader_type spatial;
render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;

const float EARTH_RADIUS = 6300e3;
// const float EARTH_RADIUS = 63000.0;
const vec3 WIND_DIRECTION = vec3(0.0, 0.0, 1.0);
const vec3 SUN_LIGHT_COLOR = vec3(1.0,.9, 0.6);

group_uniforms sampling;
uniform bool ez_marching = false;
uniform float ez_march_threshold: hint_range(0.0, 1.0, .01) = 0.01;
uniform int min_marching_steps:hint_range(1, 200, 5) = 35;
uniform int max_marching_steps:hint_range(1, 200, 5) = 60;
uniform float max_travelled: hint_range(9999.0, 999999.0, 1000.0) = 80000.0;

group_uniforms light_interaction;

uniform float sun_energy: hint_range(.0, 100.0, .01) = 1.0;
uniform vec3 ambient_light: source_color = vec3(0.8, 0.8, 1.0);
uniform float ambient_energy: hint_range(.0, 1.0, .01) = 0.4;
uniform int max_steps_lights: hint_range(1, 20) = 6;
uniform float short_light_step: hint_range(.01, 400.0, 10.0) = 600.0;
uniform float long_light_step: hint_range(.01, 400.0, 10.0) = 600.0;

uniform float scattering_aniso_fw:hint_range(.0, 1.0, .01)  = .5;
uniform float scattering_aniso_bw:hint_range(.0, 1.0, .01)  = .4;

// 0.000012
uniform highp float extinction_coefficient_sky:hint_range(.0, .0005, .000001) = 0.;

// 0.115 to 0.3 cloudy
uniform float scattering_coefficient_clouds: hint_range(.0, 1.0, .001) = 0.1;
uniform float scattering_coefficient_sugar: hint_range(.0, 0.05, .0001) = 0.1;


group_uniforms clouds;
uniform float wind_speed: hint_range(0.0, 10.0, .01) = 1.0;

group_uniforms raymarched_clouds;
uniform float map_density: hint_range(0.0, 1.0, .01) = 1.0;

uniform float clouds_min_height: hint_range(10.0, 4000, 10.0) = 1400.0;
uniform float clouds_max_height: hint_range(900.0, 10000, 10.0) = 4000.0;

// uniform float AMBIENT_STRENGTH:hint_range(.0, .101, .00001) = .0;

// Texture sizei incircle radius
uniform float wheathermap_radius: hint_range(1.0, 35000.00, 100.0) = 1000;

group_uniforms raymarched_clouds.noise;
uniform float noise_weight: hint_range(0.0, 1.0, .01) = 1.0;
uniform float noise_density: hint_range(0.0, 1.0, .01) = 1.0;
uniform float clouds_noise_scale: hint_range(1000.0, 40000.00, 100.0) = 1000;
uniform vec4 clouds_noise_fbm_weights = vec4(0.8, 0.32, 0.8, 1.0);
uniform sampler3D clouds_texture: source_color;

group_uniforms raymarched_clouds.detail_noise;
uniform float detail_noise_weight: hint_range(0.0, 0.5, .01) = 0.1;
uniform float detail_noise_scale: hint_range(1.0, 4000.0, 10.0) = 1000.0;
uniform vec3 detail_noise_fbm_weights = vec3(0.4, 0.8, 0.8);
uniform sampler3D clouds_detail_texture: source_color;
group_uniforms;
group_uniforms raymarched_clouds;

uniform sampler2D wheater_map: source_color;
// uniform sampler2D stratus_height_density: source_color;
uniform sampler2D clouds_height_density: source_color; // TODO: Apply for distance to center

group_uniforms high_altitude_clouds;
uniform sampler3D cirrus: source_color;
uniform float CIRRUS_HEIGHT: hint_range(100.0, 20000.0, 100.0) = 10000.0;
// const float CIRRUS_HEIGHT = 10000.0;
// const float CIRRUS_HEIGHT = 1000.0;
uniform float cirrus_scale: hint_range(10000.0, 30000, 100) = 1000.0;
uniform float cirrus_density: hint_range(0.0, 4.0, .001) = 0.0;
uniform float cirrus_coverage: hint_range(0.0, 1.0, .001) = 1.0;

group_uniforms sky;
uniform vec3 sky_color: source_color = vec3(.5, .675, .89);
uniform float sky_brightness: hint_range(0.0, 2.0, .01) = 1.7;
uniform float brightness_gradient_strength: hint_range(0.0, 10.0, .01) = 4.0;

group_uniforms sun;
uniform vec3 sun_position;
uniform float sun_radius: hint_range(0.0, .01, .0001) = 0.001;
group_uniforms;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D bg_texture : hint_screen_texture, source_color;

struct SunData {
    vec3 light_dir;
    float mu;
};

#include "res://shaders/raymarch_utils.gdshaderinc"
float simple_sdf(vec3 p) {
    float atmosphere_height = length(p - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
    float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);
    // normalized_y = inverse_lerp(clouds_min_height, clouds_max_height, p.y);
    vec2 normalized_coordinates = (p.xz/(wheathermap_radius*2.0));
    vec2 map = texture(wheater_map, normalized_coordinates + vec2(0.5)).rg; // Center texture above us
    float map_coverage = max(map.r, map.g);
    float clouds_noise =  0.0;
    /* Calculate cloud noise fbm*/ {
        vec3 wind = WIND_DIRECTION*TIME*wind_speed*0.001;
        vec4 clouds_layers = texture(clouds_texture, (p/vec3(clouds_noise_scale)-wind));
        vec4 normalized_weights = clouds_noise_fbm_weights / dot(clouds_noise_fbm_weights, vec4(1.0));
        float fbm = dot(clouds_layers, normalized_weights);
        clouds_noise = fbm*noise_density;
    }
    float clouds_height_gradient = texture(clouds_height_density, vec2(normalized_y, 0)).r;
    clouds_height_gradient = max(0.0, clouds_height_gradient);
    return clamp(smoothmin(map_coverage, clouds_noise, noise_weight*2.0)*map_density*clouds_height_gradient, .0, 1.0);
}

float scene_sdf(vec3 p) {
    float clouds = simple_sdf(p);
    float detail_fbm = 0.0;
    /* Calculate cloud detail noise fbm*/ {
        vec3 wind = WIND_DIRECTION*TIME*wind_speed*0.001;
        vec3 normalized_weights = detail_noise_fbm_weights / dot(detail_noise_fbm_weights, vec3(1.0));
        vec3 clouds_degrade = texture(clouds_detail_texture, (p/vec3(detail_noise_scale)-wind)).rgb;
        detail_fbm = dot(clouds_degrade.rgb, normalized_weights) * detail_noise_weight;
    }
    float one_minus_shape = 1.0 - clouds;
    float detail_erode_weight = one_minus_shape*one_minus_shape*one_minus_shape; // Erode more towards the edges
    float erosion = (detail_fbm) * detail_erode_weight; // NOTE: This affects the interior
    float clouds_density = clouds - erosion;
    return max(0.0, clouds_density);
}

float lightmarch_simple_sdf(in highp vec3 p, in vec3 rd, in SunData sun_data, in float dither) {
    p += dither*short_light_step*sun_data.light_dir;
    float total_density = 0.0;
    for (int i = 0; i < max_steps_lights; i++) {
        float step_size = mix(short_light_step, long_light_step, float(i)/float(max_steps_lights));
        float light_sample = simple_sdf(p);
        total_density += light_sample*step_size; // integration in step
        p += sun_data.light_dir*step_size*float(i);
    }

    float in_scattering = beers_law(total_density, scattering_coefficient_clouds); // Out scattering approximation, assume no absorption
    float out_scattering = sugar_powder(total_density, scattering_coefficient_sugar); // In scattering approximation
    float beer_powder = in_scattering+out_scattering;
    float mu_normalized = -sun_data.mu*.5+.5;
    float result  = mix(in_scattering, beer_powder, mu_normalized);
    return result;
}


float lightmarch(in highp vec3 p, in vec3 rd, in SunData sun_data, in float dither) {
    p += dither*short_light_step*sun_data.light_dir;
    float total_density = 0.0;
    for (int i = 0; i < max_steps_lights; i++) {
        float light_sample = scene_sdf(p);

        float step_size = mix(short_light_step, long_light_step, float(i)/float(max_steps_lights));
        total_density += light_sample*step_size; // integration in step
        p += sun_data.light_dir*step_size*float(i);
    }

    float in_scattering = beers_law(total_density, scattering_coefficient_clouds); // Out scattering approximation, assume no absorption
    float out_scattering = sugar_powder(total_density, scattering_coefficient_sugar); // In scattering approximation
    float beer_powder = in_scattering+out_scattering;
    float inv_mu_normalized = -sun_data.mu*.5+.5;
    float result = mix(in_scattering, beer_powder, inv_mu_normalized);
    return result;
}

// NOTE: Could retrieve hit normalized_depth for other effects.
vec4 raymarch(in highp vec3 ro, in vec3 rd, in float max_distance_travelled, in SunData sun_data, out float depth){
    // vec3 light_dir = normalize(sun_position);

    vec4 light = vec4(vec3(0.0), 1.0);

    // Double Lobe HG
    float phase = mix(henyey_greenstein(-scattering_aniso_bw, sun_data.mu), henyey_greenstein(scattering_aniso_fw, sun_data.mu), 0.5);

    float view_height_dot = clamp(dot(rd, vec3(0.0, 1.0, 0.0)), 0.0, 1.0); // 0 horizon 1 up
    int marching_steps = int(mix(float(max_marching_steps), float(min_marching_steps), view_height_dot));
    float detail_step_size = max_distance_travelled/float(marching_steps); // Ensure we reach the end
    float traverse_step_size = detail_step_size*1.0; // Ensure we reach the end
    // float current_step_size = traverse_step_size;
    float current_step_size = detail_step_size;
    float dither = hash11(dot(rd, vec3(12.256, 2.646, 6.356)) + TIME);
    depth = dither*traverse_step_size;
    // depth = 0.0;
    highp vec3 sample_position = ro + depth * rd;
    int missed_steps = 0;
    bool traversing = false;
    for (int i = 0; i < marching_steps; i++) {
        float point_density;
        if (!ez_marching){
            if (traversing){
                point_density = simple_sdf(sample_position);
            }
            else{
                point_density = scene_sdf(sample_position);
            }
        }else{
            point_density = scene_sdf(sample_position);
        }
        bool hit = point_density > 0.001;
        if (ez_marching){
            current_step_size = detail_step_size;
            if (hit){
                float light_transmittance = lightmarch(sample_position, rd, sun_data, dither);
                float atmosphere_height = length(sample_position - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
                float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);

                // vec3 ambient = (0.5 + 0.6*normalized_y)*vec3(0.4, 0.6, 1.0)*.2 + vec3(0.4) * max(0.0, 1.0-2.0*normalized_y);
                // vec3 ambient = vec3(0.8, 0.8, 1.0)*.4;
                vec3 ambient = ambient_light*ambient_energy;
                vec3 radiance = ambient + sun_energy*SUN_LIGHT_COLOR*light_transmittance*phase;
                radiance *= point_density; // Captured radiance
                float local_extinction = point_density * scattering_coefficient_clouds;
                float step_extinction = beers_law(current_step_size*point_density, scattering_coefficient_clouds);
                vec3 integrated_scattering = (radiance - radiance * step_extinction) / local_extinction;
                light.rgb += integrated_scattering*light.a;
                light.a *= step_extinction;
                if (light.a < 0.01) {
                    break;
                }
            }
        }else{
            if (hit) {
                missed_steps = 0; // Reset
                if (traversing){
                    depth -= traverse_step_size;
                    sample_position -= traverse_step_size * rd;
                    current_step_size = detail_step_size;
                    marching_steps--;
                }
                else{
                    current_step_size = detail_step_size;
                    float light_transmittance;
                    if (light.a < ez_march_threshold) {
                        light_transmittance = lightmarch_simple_sdf(sample_position, rd, sun_data, dither);
                    }
                    else{
                        light_transmittance = lightmarch(sample_position, rd, sun_data, dither);
                    }

                    float atmosphere_height = length(sample_position - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
                    float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);

                    vec3 ambient = (0.5 + 0.6*normalized_y)*vec3(0.4, 0.6, 1.0)*.2 + vec3(0.4) * max(0.0, 1.0-2.0*normalized_y);
                    // ambient = vec3(0.8, 0.8, 1.0)*.4;
                    ambient = ambient_light*ambient_energy;

                    vec3 radiance = ambient + sun_energy*SUN_LIGHT_COLOR*light_transmittance*phase;
                    radiance *= point_density; // Captured radiance
                    float local_extinction = point_density * scattering_coefficient_clouds;
                    float step_extinction = beers_law(current_step_size*point_density, scattering_coefficient_clouds);
                    vec3 integrated_scattering = (radiance - radiance * step_extinction) / local_extinction;
                    light.rgb += integrated_scattering*light.a;
                    light.a *= step_extinction;
                    if (light.a < 0.01) {
                        break;
                    }
                }
                traversing = false;
            }
            else{
                missed_steps++;
                if (missed_steps > 4){
                    traversing = true;
                    current_step_size = traverse_step_size;
                }
            }
        }

        depth += current_step_size;
        sample_position += current_step_size * rd;
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
            EARTH_RADIUS + CIRRUS_HEIGHT).y;

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

void vertex() {
    POSITION = vec4(VERTEX, 1.); // Stack in front of camera
}


struct WorldSpaceData {
    vec3 world_position;
    float linear_depth;
};

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

vec2 get_ray_start_end(in vec3 ro, in vec3 rd){
    vec2 distance_to_inner_sphere = ray_sphere_distance(
            ro,
            rd, 
            vec3(.0, -EARTH_RADIUS, .0),
            EARTH_RADIUS+clouds_min_height);

    vec2 distance_to_outer_sphere = ray_sphere_distance(
            ro,
            rd,
            vec3(.0, -EARTH_RADIUS, .0),
            EARTH_RADIUS+clouds_max_height);

    float start_distance = distance_to_inner_sphere.y;
    float travel_distance = distance_to_outer_sphere.y - distance_to_inner_sphere.y;

    bool inside_inner = distance_to_inner_sphere.x < 0.0;
    bool inside_outer = distance_to_outer_sphere.x < 0.0;

    bool no_inner_intersection = distance_to_inner_sphere.x < 0.0 && distance_to_inner_sphere.y < 0.0;
    if (no_inner_intersection){ // Outside inner intersecting outer shell
        start_distance = max(.0, distance_to_outer_sphere.x) ;
        travel_distance = distance_to_outer_sphere.y;
    }
    else if (!inside_outer){
        start_distance = distance_to_outer_sphere.x;
        travel_distance = distance_to_inner_sphere.x - distance_to_outer_sphere.x;
    }
    else if (!inside_inner){ // Positive so outside inner shell but intersecting inner
        start_distance = 0.0;
        travel_distance = distance_to_inner_sphere.x; // min max travelled?
    } // Else is default case
        return vec2(start_distance, min(travel_distance, max_travelled));
    }


#define ATMOSPHERIC_SCATTERING
void fragment(){
    highp float normalized_depth = texture(depth_texture, SCREEN_UV).x;
    WorldSpaceData frag = get_world_space_data(normalized_depth, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);

    highp vec3 ro = CAMERA_POSITION_WORLD;
    vec3 rd = normalize(frag.world_position - ro);

    vec2 start_end = get_ray_start_end(ro, rd);
    float start_distance = start_end.x;
    float travel_distance = start_end.y;

    float extinction = exp(-extinction_coefficient_sky * (start_distance));
    float threshold = 0.001;
    float distance_to_threshold = -log(threshold) / extinction_coefficient_sky;
    bool is_extinction_to_high = start_distance > distance_to_threshold;

    SunData sun_data;
    sun_data.light_dir = normalize(sun_position);
    sun_data.mu = dot(rd, sun_data.light_dir);
    vec3 sky = render_sky(rd);
    vec3 sun = render_sun(sun_data.mu, sun_radius);

    float high_clouds = render_high_clouds(ro, rd);
    ro += rd*start_distance;


    bool scene_under_clouds = frag.linear_depth < start_distance; // clouds plane behind map
    bool valid_depth = normalized_depth < 1.0; // Max depth
    if (scene_under_clouds && valid_depth){
#ifdef ATMOSPHERIC_SCATTERING
        float map_extinction = exp(-extinction_coefficient_sky * (frag.linear_depth));
        vec3 scene = texture(bg_texture, SCREEN_UV).rgb;
        float extinction = exp(-extinction_coefficient_sky * (frag.linear_depth));
        scene = mix(sky, scene, map_extinction);
        ALBEDO.rgb = scene;
#else
        discard;
#endif
    }
    else if (is_extinction_to_high){ // No need to render clouds
        ALBEDO = sky+high_clouds;
        // discard;
    } else {
        float depth = 0.0;
        // NOTE: Is distance to travel going to far or to short and thus not showing clouds
        // Probably using second root unnecessaryly
        if (!valid_depth){
            vec4 result = raymarch(ro, rd, travel_distance, sun_data, depth);
            float transmittance = result.w;
            vec3 clouds_color = result.xyz;
            vec3 skybox = (sky+high_clouds+sun)*transmittance+clouds_color;
            skybox = mix(sky, skybox, extinction);
            ALBEDO = skybox;
        }
        else{
            travel_distance = min(travel_distance, frag.linear_depth - start_distance);
            vec4 result = raymarch(ro, rd, travel_distance, sun_data, depth);
            float transmittance = result.w;
            vec3 clouds_color = result.xyz;
            vec3 scene = texture(bg_texture, SCREEN_UV).rgb;
#ifdef ATMOSPHERIC_SCATTERING
            // TODO: extinctoin should affect map as well so a different approach should be taken
            float map_extinction = exp(-extinction_coefficient_sky * (frag.linear_depth));
            vec3 clouds_scene_overlay = clouds_color + scene * transmittance;
            clouds_scene_overlay = mix(sky, clouds_scene_overlay, map_extinction);
            // clouds_scene_overlay = mix(scene, clouds_scene_overlay, extinction);
#else
            vec3 clouds_scene_overlay = clouds_color + scene * transmittance;
#endif
            ALBEDO.rgb = clouds_scene_overlay;
        }
    }

}
