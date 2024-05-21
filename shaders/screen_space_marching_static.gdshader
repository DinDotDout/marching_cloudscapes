shader_type spatial;
render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;

const float EARTH_RADIUS = 6300e3;
const vec3 WIND_DIRECTION = vec3(0.0, 0.0, 1.0);
const vec3 SUN_LIGHT_COLOR = vec3(1.0,.9, 0.6);

group_uniforms sampling;
uniform bool ez_marching = false;
uniform float ez_march_threshold: hint_range(0.0, 1.0, .01) = 0.01;
uniform int min_marching_steps:hint_range(1, 200, 5) = 35;
uniform int max_marching_steps:hint_range(1, 200, 5) = 60;

group_uniforms light_interaction;
uniform float sun_energy:hint_range(.0, 100.0, .01) = 1.0;

uniform int max_steps_lights: hint_range(1, 20) = 6;
uniform float short_light_step: hint_range(.01, 400.0, 10.0) = 600.0;
uniform float long_light_step: hint_range(.01, 400.0, 10.0) = 600.0;

uniform float scattering_aniso_fw:hint_range(.0, 1.0, .01)  = .5;
uniform float scattering_aniso_bw:hint_range(.0, 1.0, .01)  = .4;

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
uniform float detail_noise_weight: hint_range(0.0, 1.0, .01) = 1.0;
uniform float detail_noise_scale: hint_range(1.0, 4000.0, 10.0) = 1000.0;
uniform vec3 detail_noise_fbm_weights = vec3(0.4, 0.8, 0.8);
uniform sampler3D clouds_detail_texture: source_color;
group_uniforms;
group_uniforms raymarched_clouds;

uniform sampler2D wheater_map: source_color;
// uniform sampler2D stratus_height_density: source_color;
uniform sampler2D cumulus_height_density: source_color; // TODO: Apply for distance to center

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

#include "res://shaders/raymarch_utils.gdshaderinc"
float simple_sdf(vec3 p) {
    float atmosphere_height = length(p - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
    float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);
    // normalized_y = inverse_lerp(clouds_min_height, clouds_max_height, p.y);
    vec2 normalized_coordinates = (p.xz/(wheathermap_radius*2.0));
    vec2 map = texture(wheater_map, normalized_coordinates + vec2(0.5)).rg; // Center texture above us
    float map_coverage = max(map.r, map.g);
    float cumulus_noise =  0.0;
    /* Calculate cloud noise fbm*/ {
        vec3 wind = WIND_DIRECTION*TIME*wind_speed*0.001;
        vec4 clouds_layers = texture(clouds_texture, (p/vec3(clouds_noise_scale)-wind));
        vec4 normalized_weights = clouds_noise_fbm_weights / dot(clouds_noise_fbm_weights, vec4(1.0));
        float fbm = dot(clouds_layers, normalized_weights);
        cumulus_noise = fbm*noise_density;
    }
    float clouds_height_gradient = texture(cumulus_height_density, vec2(normalized_y, 0)).r;
    clouds_height_gradient = max(0.0, clouds_height_gradient);
    return clamp(smoothmin(map_coverage, cumulus_noise, noise_weight*2.0)*map_density*clouds_height_gradient, .0, 1.0);
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

float lightmarch_simple_sdf(in highp vec3 p, in vec3 rd, in vec3 light_dir, in float dither) {
    p += dither*short_light_step*light_dir;
    float total_density = 0.0;
    for (int i = 0; i < max_steps_lights; i++) {
        float step_size = mix(short_light_step, long_light_step, float(i)/float(max_steps_lights));
        float light_sample = simple_sdf(p+light_dir*float(i)*step_size);
        total_density += light_sample*step_size; // integration in step
    }

    float in_scattering = beers_law(total_density, scattering_coefficient_clouds); // Out scattering approximation, assume no absorption
    float out_scattering = sugar_powder(total_density, scattering_coefficient_sugar); // In scattering approximation
    float beer_powder = in_scattering+out_scattering;
    float sun_dir = dot(rd, -light_dir)*.5+.5;
    float result  = mix(in_scattering, beer_powder, sun_dir);
    return result;
}

float lightmarch(in highp vec3 p, in vec3 rd, in vec3 light_dir, in float dither) {
    p += dither*short_light_step*light_dir;
    float total_density = 0.0;
    for (int i = 0; i < max_steps_lights; i++) {
        float step_size = mix(short_light_step, long_light_step, float(i)/float(max_steps_lights));
        float light_sample = scene_sdf(p+light_dir*float(i)*step_size);
        total_density += light_sample*step_size; // integration in step
    }

    float in_scattering = beers_law(total_density, scattering_coefficient_clouds); // Out scattering approximation, assume no absorption
    float out_scattering = sugar_powder(total_density, scattering_coefficient_sugar); // In scattering approximation
    float beer_powder = in_scattering+out_scattering;
    float mu_normalized = dot(rd, -light_dir)*.5+.5;
    float result  = mix(in_scattering, beer_powder, mu_normalized);
    return result;
}

// NOTE: Could retrieve hit normalized_depth for other effects.
vec4 raymarch(in highp vec3 ro, in vec3 rd, in float max_distance_travelled, in float mu) {
    vec4 light = vec4(vec3(0.0), 1.0);
    vec3 light_dir = normalize(sun_position);

    // Double Lobe HG
    float phase = mix(henyey_greenstein(-scattering_aniso_bw, mu), henyey_greenstein(scattering_aniso_fw, mu), 0.5);

    float view_height_dot = clamp(dot(rd, vec3(0.0, 1.0, 0.0)), 0.0, 1.0); // 0 horizon 1 up
    int marching_steps = int(mix(float(max_marching_steps), float(min_marching_steps), view_height_dot));
    float detail_step_size = max_distance_travelled/float(marching_steps)/1.0; // Ensure we reach the end
    float traverse_step_size = detail_step_size*3.0; // Ensure we reach the end
    float current_step_size = traverse_step_size;
    float dither = hash11(dot(rd, vec3(12.256, 2.646, 6.356)) + TIME);
    float depth = dither*traverse_step_size;
    // float depth = dither*detail_step_size;
    // depth = 0.0;

    highp vec3 samplePosition = ro + depth * rd;
    int missed_steps = 0;
    bool traversing = true;
    for (int i = 0; i < marching_steps; i++) {
        float point_density;
		if (!ez_marching){
			if (traversing){
				point_density = simple_sdf(samplePosition);
			}
			else{
				point_density = scene_sdf(samplePosition);
			}
		}else{
			point_density = scene_sdf(samplePosition);
		}
        bool hit = point_density > 0.001;
		if (ez_marching){
			current_step_size = detail_step_size;
			if (hit){
				float light_transmittance = lightmarch(samplePosition, rd, light_dir, dither);
				float atmosphere_height = length(samplePosition - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
				float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);

				vec3 ambient = (0.5 + 0.6*normalized_y)*vec3(0.4, 0.6, 1.0)*.2 + vec3(0.4) * max(0.0, 1.0-2.0*normalized_y);
				ambient = vec3(0.8, 0.8, 1.0)*.4;
				vec3 radiance = ambient + sun_energy*SUN_LIGHT_COLOR*light_transmittance*phase;
				radiance *= point_density; // Captured radiance
				float localExtinction = point_density * scattering_coefficient_clouds;
				float stepExtinction = beers_law(current_step_size*point_density, scattering_coefficient_clouds);
				vec3 integrated_scattering = (radiance - radiance * stepExtinction) / localExtinction;
				light.rgb += integrated_scattering*light.a;
				light.a *= stepExtinction;
				if (light.a < 0.01) {
					break;
				}
			}
		}else{
			if (hit) {
				missed_steps = 0; // Reset
				if (traversing){
					depth -= traverse_step_size;
					samplePosition -= traverse_step_size * rd;
					current_step_size = detail_step_size;
                    marching_steps--;
				}
				else{
					current_step_size = detail_step_size;
					float light_transmittance;
					if (light.a < ez_march_threshold) {
						light_transmittance = lightmarch_simple_sdf(samplePosition, rd, light_dir, dither);
					}
					else{
						light_transmittance = lightmarch(samplePosition, rd, light_dir, dither);
					}

					float atmosphere_height = length(samplePosition - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
					float normalized_y = clamp((atmosphere_height-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);

					vec3 ambient = (0.5 + 0.6*normalized_y)*vec3(0.4, 0.6, 1.0)*.2 + vec3(0.4) * max(0.0, 1.0-2.0*normalized_y);
					ambient = vec3(0.8, 0.8, 1.0)*.4;
					vec3 radiance = ambient + sun_energy*SUN_LIGHT_COLOR*light_transmittance*phase;
					radiance *= point_density; // Captured radiance
					float localExtinction = point_density * scattering_coefficient_clouds;
					float stepExtinction = beers_law(current_step_size*point_density, scattering_coefficient_clouds);
					vec3 integrated_scattering = (radiance - radiance * stepExtinction) / localExtinction;
					light.rgb += integrated_scattering*light.a;
					light.a *= stepExtinction;
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
        samplePosition += current_step_size * rd;
        if (depth >= max_distance_travelled) {
            break;
        }
    }
    return light;
}

vec3 render_sun(in float mu, in float radius) {
    float mu_normalized = 1.0-(mu * 0.5 + 0.5);
    mu_normalized = max(mu_normalized, 1e-6);
    float glow = (1.0 - exp(-25.0 * (radius / mu_normalized))) * 0.1 + (1.0 - exp(-0.05 * (radius / mu_normalized) * (radius / mu_normalized))) * 2.0;
    vec3 sun =  vec3(glow, glow*.6, 0.0)*sun_energy;
    return sun;
}

vec3 render_sky(in vec3 rd) {
    vec3 background = 3.0*vec3(sky_color); // uper sky
    background += vec3(sky_brightness) * max(0.0, 1.0 - brightness_gradient_strength*rd.y); // lower sky half
    return background;
}

float render_high_clouds(vec3 ro, vec3 rd){
    float cirrus_distance = ray_sphere_distance(
            ro,
            rd,
            vec3(.0, -EARTH_RADIUS, .0),
            EARTH_RADIUS + CIRRUS_HEIGHT);

    vec3 wind = (vec3(0,1,0)-WIND_DIRECTION)*TIME*wind_speed*0.0005;

    // Add up direction to simulate change over time
    vec2 cirrus_tex = texture(cirrus, ((ro+rd*cirrus_distance)/cirrus_scale+wind)).rg; // Fixed distance
                                                                                       // vec2 cirrus_tex = texture(cirrus, ((ro+rd*CIRRUS_HEIGHT)/cirrus_scale+wind)).rg; // Infinite distance
    float high_clouds = (cirrus_tex.r*cirrus_tex.g)/2.0; // Fbm
    high_clouds = max(0.0, high_clouds - (1.0-cirrus_coverage)); // Degrade
    float cirrus_extinction = exp(-extinction_coefficient_sky * abs(cirrus_distance));
    high_clouds *= cirrus_density*cirrus_extinction; // Use same extinction to have more manual control.
    float over_cirrus = step(0.0, cirrus_distance);
    high_clouds *= over_cirrus;
    return high_clouds;
}

void vertex() {
    POSITION = vec4(VERTEX, 1.); // Stack in front of camera
}

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct FragmentData {
    vec3 world_position;
    float linear_depth;
};


FragmentData get_fragment_data(in float normalized_depth, in vec2 screen_uv, in mat4 inv_projection_matrix, in mat4 inv_view_matrix){
    highp vec3 ndc = vec3(screen_uv* 2.0 - 1.0, normalized_depth);
    highp vec4 clip = vec4(ndc, 1.0);
    highp vec4 eye = inv_projection_matrix * clip;
    eye /= eye.w;

    highp vec3 world_position = (inv_view_matrix * eye).xyz;

    vec4 view = inv_projection_matrix * clip;
    view.xyz /= view.w;
    float linear_scene_depth = -view.z;

    FragmentData frag;
    frag.world_position = world_position;
    frag.linear_depth = linear_scene_depth;
    return frag;
}


void fragment(){
    highp float normalized_depth = texture(depth_texture, SCREEN_UV).x;
    FragmentData frag = get_fragment_data(normalized_depth, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);

    highp vec3 ro = CAMERA_POSITION_WORLD;
    vec3 rd = normalize(frag.world_position - ro);

    bool map_hit = normalized_depth < 1.0;
    float distance_to_inner_shell = ray_sphere_distance(ro, rd, vec3(.0, -EARTH_RADIUS, .0), EARTH_RADIUS+clouds_min_height);
    float distance_to_outer_shell = ray_sphere_distance(ro, rd, vec3(.0, -EARTH_RADIUS, .0), EARTH_RADIUS+clouds_max_height);
    float extinction = exp(-extinction_coefficient_sky * abs(distance_to_inner_shell));

    distance_to_inner_shell = max(0.0, distance_to_inner_shell);
    distance_to_outer_shell = max(0.0, distance_to_outer_shell);

    float threshold = 0.001;
    float distance_to_threshold = -log(threshold) / extinction_coefficient_sky;
    bool is_extinction_to_high = distance_to_inner_shell > distance_to_threshold;


    vec3 light_direction = normalize(sun_position);
    float mu = dot(rd, light_direction);
    vec3 sky = render_sky(rd);
    vec3 sun = render_sun(mu, sun_radius);
    float high_clouds = render_high_clouds(ro, rd);
    // vec3 sky = vec3(0.0);
    // {
    //     sky = 3.0*vec3(sky_color); // uper sky
    //     sky += vec3(sky_brightness) * max(0.0, 1.0 - brightness_gradient_strength*rd.y); // lower sky half
    // }
    //
    // vec3 sun = vec3(0.0);
    // {
    //     float mu_normalized = 1.0-(mu * 0.5 + 0.5);
    //     mu_normalized = max(mu_normalized, 1e-6);
    //     float glow = (1.0 - exp(-25.0 * (sun_radius / mu_normalized))) * 0.1 + (1.0 - exp(-0.05 * (sun_radius / mu_normalized) * (sun_radius / mu_normalized))) * 2.0;
    //     sun =  vec3(glow, glow*.6, 0.0)*sun_energy;
    // }
    //
    //
    // float high_clouds = 0.0;
    // /* Calculate high clouds noise fbm*/ {
    //     float cirrus_distance = ray_sphere_distance(
    //             ro,
    //             rd,
    //             vec3(.0, -EARTH_RADIUS, .0),
    //             EARTH_RADIUS + CIRRUS_HEIGHT);
    //
    //     vec3 wind = (vec3(0,1,0)-WIND_DIRECTION)*TIME*wind_speed*0.0005;
    //
    //     // Add up direction to simulate change over time
    //     vec2 cirrus_tex = texture(cirrus, ((ro+rd*cirrus_distance)/cirrus_scale+wind)).rg; // Fixed distance
    //     // vec2 cirrus_tex = texture(cirrus, ((ro+rd*CIRRUS_HEIGHT)/cirrus_scale+wind)).rg; // Infinite distance
    //     high_clouds = (cirrus_tex.r*cirrus_tex.g)/2.0; // Fbm
    //     high_clouds = max(0.0, high_clouds - (1.0-cirrus_coverage)); // Degrade
    //     float cirrus_extinction = exp(-extinction_coefficient_sky * abs(cirrus_distance));
    //     high_clouds *= cirrus_density*cirrus_extinction; // Use same extinction to have more manual control.
    //     // float over_cirrus = step(0.0, cirrus_distance);
    //     // high_clouds *= over_cirrus;
    // }
    ro += rd*distance_to_inner_shell;
    float distance_to_travel = distance_to_outer_shell-distance_to_inner_shell;
    // distance_to_travel = distance_to_outer_shell;

    if (!map_hit) {
        if (is_extinction_to_high){
            ALBEDO = sky+sun+high_clouds;
        } else {
            float depth = 0.0;
            vec4 result = raymarch(ro, rd, distance_to_travel, mu);

            float transmittance = result.w;
            vec3 clouds_color = result.xyz;
            vec3 skybox = (sky+high_clouds+sun)*transmittance+clouds_color;
            // TODO: fix sun opsition;
            skybox = mix(sky, skybox, extinction);
            // skybox = mix(sky+sun, skybox, extinction);
            ALBEDO = skybox;
        }
    } else {
        bool scene_is_closer = frag.linear_depth < distance_to_inner_shell; // clouds plane behind map
        if (scene_is_closer){
            discard;
        }
        		// TODO: Combine with !hit and place outside?
		// NOTE: Will generally not hapen as far plane is usually closer
		// NOTE: Not needed as being inside the clouds is not an option yet
        if (distance_to_inner_shell == -1.0){ // We did not intersct
            ALBEDO = sky+sun;
            vec3 color = mix(sky, sky+sun, extinction);
            ALBEDO = color;
        }

        else {
            float depth = 0.0;
            vec4 result = raymarch(ro, rd, distance_to_travel, mu);
            vec3 energy = result.xyz;
            float transmittance = result.w;
            vec3 clouds = energy * vec3(1.0);
            vec3 bg_color = texture(bg_texture, SCREEN_UV).rgb;
            vec3 color = clouds + (bg_color) * (transmittance);
            ALBEDO.rgb = color;
        }
    }
}
