shader_type spatial;
render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;
// render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled;

const float EARTH_RADIUS = 6300e3;

group_uniforms sampling;
uniform int MIN_MARCHING_STEPS:hint_range(1, 100, 5) = 35;
uniform int MAX_MARCHING_STEPS:hint_range(1, 100, 5) = 60;

group_uniforms light_interaction;
uniform float sun_energy:hint_range(.0, 100.0, .01) = 1.0;
const vec3 SUN_POWER = vec3(1.0,.9, 0.6);

uniform int MAX_STEPS_LIGHTS: hint_range(1, 20) = 6;
uniform float MAX_LIGHT_SAMPLE_DISTANCE: hint_range(.01, 1000.0, 10.0) = 600.0;

uniform float SCATTERING_ANISO_FW:hint_range(.0, 1.0, .01)  = .5;
uniform float SCATTERING_ANISO_BW:hint_range(.0, 1.0, .01)  = .4;

uniform highp float EXCTINCTION_COEFFICIENT_SKY:hint_range(.0, .0002, .000001) = 0.;

// 0.115 to 0.3 cloudy
uniform float SCATTERING_COEFFICIENT_CLOUDS :hint_range(.0, 1.0, .001) = 0.11;
const vec3 wind_direction = vec3(0.0, 0.0, 1.0);

// group_uniforms post_processing;
// uniform float temp_aa: hint_range(.0, 1.0, .01) = 0.0;

group_uniforms high_altitude_clouds;
uniform sampler3D cirrus: source_color;
const float cirrus_height = 10000.0;
uniform float cirrus_scale: hint_range(0.0, 0.0003, .000001) = 0.0;
uniform float cirrus_density: hint_range(0.0, 4.0, .001) = 0.0;
uniform float cirrus_mix: hint_range(0.0, 1.0, .001) = 0.0;
uniform float cirrus_coverage: hint_range(0.0, 1.0, .001) = 1.0;

group_uniforms raymarched_clouds;
// uniform float EARTH_RADIUS:hint_range(.0, 200000.0, .01) = 1.0;
uniform float clouds_min_height: hint_range(000.0, 4000) = 1500.0;
uniform float clouds_max_height: hint_range(900.0, 10000) = 1500.0;

// uniform float AMBIENT_STRENGTH:hint_range(.0, .101, .00001) = .0;
// uniform sampler2D cumulonimbus: source_color;

// Main shape
// const float wheathermap_scale = 0.00001;
uniform float wheathermap_scale: hint_range(0.0, .001, .00001) = 0.0002;
uniform float clouds_noise_scale: hint_range(0.0, .001, .00001) = 0.0002;
uniform float clouds_detail_scale: hint_range(0.0, .003, .00001) = 0.001;

uniform float clouds_detail_scale_r: hint_range(0.0, .3, .0001) = 0.0;
uniform float clouds_detail_scale_g: hint_range(0.0, .3, .0001) = 0.0;
uniform float clouds_detail_scale_b: hint_range(0.0, .3, .0001) = 0.0;

uniform sampler2D wheater_map: source_color;
uniform sampler3D clouds_texture: source_color;
uniform sampler3D clouds_detail_texture: source_color;
uniform sampler2D stratus: source_color;
uniform sampler2D cumulus: source_color; // TODO: Apply for distance to center

group_uniforms sky_color;
uniform vec3 COLOUR_LIGHT_BLUE: source_color;
uniform vec3 COLOUR_BRIGHT_BLUE: source_color;

// uniform sampler2D prev_frame: source_color;

// WARNING: Probably will remove and hardcode according to clouds type
group_uniforms debug;
#define DEBUG_CLOUDS
#ifdef DEBUG_CLOUDS
uniform float clouds_type: hint_range(0.0, 1.0, .01) = 0.0;
uniform bool manual_clouds_attributes = false;
uniform float base_density: hint_range(0.0, 1.0, .01) = 1.;
uniform float base_coverage: hint_range(0.0, 1.0, .01) = 1.0;
uniform float amplitude1: hint_range(0.0, 1.0, .01) = 1.0;
uniform float amplitude2: hint_range(0.0, 1.0, .01) = 1.0;
uniform float amplitude3: hint_range(0.0, 1.0, .01) = 1.0;
uniform float amplitude4: hint_range(0.0, 1.0, .01) = 1.0;
#endif

const float cumulus_density = 1.0;
const float inv_cumulus_coverage = 0.0;

const float stratus_density = 0.3;
const float inv_stratus_coverage = .2;

group_uniforms auto_update;
uniform vec3 sun_position;
// uniform vec3 sun_direction;
#include "res://shaders/raymarch_utils.gdshaderinc"
float hash11( float n )
{
    return fract(sin(n)*43758.5453);
}

float get_stratus(in float height, in vec4 clouds_layers, in float map_coverage){
    float maxAmplitude = 0.0;
    float amplitude = 1.0;
    float persistence = 0.3;
    float result_layer = 0.0;
    for(int i = 0; i < 4; i++){
        float layer = clouds_layers[i];
        result_layer += layer * amplitude;
        maxAmplitude += amplitude;
        amplitude *= persistence;
    }

    result_layer /= maxAmplitude;

#ifdef DEBUG_CLOUDS
    if (manual_clouds_attributes){
        result_layer *= step(1.0-base_coverage, result_layer);
        result_layer *= base_density;
    }
    else{
        result_layer *= step(inv_stratus_coverage, result_layer);
        result_layer *= stratus_density;
    }
#else
    result_layer *= step(inv_stratus_coverage, result_layer);
    result_layer *= stratus_density;
#endif

    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);
    float stratus_color = texture(stratus, vec2(height, 0)).r;
    return stratus_color*result_layer;
}

float get_cumulus(in float height, in vec4 clouds_layers, in float map_coverage){
    float maxAmplitude = 0.0;
    float amplitude = 1.0;
    float persistence = .8;
    float result_layer = 0.0;
    result_layer = clouds_layers[0]*amplitude1;
    maxAmplitude += amplitude;
    amplitude *= persistence;

    result_layer += clouds_layers[1]*amplitude2;
    maxAmplitude += amplitude;
    amplitude *= persistence;

    result_layer += clouds_layers[2]*amplitude3;
    maxAmplitude += amplitude;
    amplitude *= persistence;

    result_layer += clouds_layers[3]*amplitude4;
    maxAmplitude += amplitude;
    amplitude *= persistence;

    // for(int i = 0; i < 4; i++){
    //     float layer = clouds_layers[i];
    //     result_layer += layer * amplitude;
    //     maxAmplitude += amplitude;
    //     amplitude *= persistence;
    // }

    result_layer /= maxAmplitude;
    return result_layer; 
#ifdef DEBUG_CLOUDS
    if (manual_clouds_attributes){
        result_layer *= step(1.0-base_coverage, result_layer);
        result_layer *= base_density;
    }
    else{

        result_layer *= step(inv_cumulus_coverage, result_layer);
        result_layer *= cumulus_density;
    }
#else
    result_layer *= step(inv_cumulus_coverage, result_layer);
    result_layer *= cumulus_density;
#endif
    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);
    float cumulus_color = texture(cumulus, vec2(height, 0)).r;
    return cumulus_color*result_layer;
}


float simpleSDF(vec3 p) {
    // NOTE: This should be always between the range given we start and stop at that position
    // p += vec3(.0, EARTH_RADIUS, .0);
    // p += EARTH_RADIUS;
    float atmoHeight = length(p - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
    float normalized_y = clamp((atmoHeight-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);

    normalized_y = inverse_lerp(clouds_min_height, clouds_max_height, p.y);
    normalized_y = clamp(normalized_y, 0.0, 1.0); // forze zero where cannot see below our plane?
    //
    // vec3 map_tex = (texture(wheater_map, fract(uv*wheathermap_scale))).rgb;
    // float relation = 35000.0/512.0;
    vec3 map_tex = (texture(wheater_map, (p.xz*wheathermap_scale)+wind_direction.xz*TIME*.001)).rgb;
    // vec3 map_tex = (texture(wheater_map, (p.xz*wheathermap_scale)-vec2(.20, 0.50))).rgb;

    float map_coverage = map_tex.r;
    float precipitation = map_tex.b;

    // Clouds type set which one will be, but chance of one or other increases with coverage or height?

    vec4 clouds_layers = texture(clouds_texture, p*vec3(clouds_noise_scale)-wind_direction*TIME*0.003);

    // return  smoothstep(1.0-map_coverage, 1.0, 1.0);

    float cumulus_col = texture(cumulus, vec2(normalized_y, 0)).r;
    cumulus_col = map_tex.r*cumulus_col;

    // cumulus_col = get_cumulus(normalized_y, clouds_layers, map_coverage);
    // return cumulus_col-clouds_layers.a;
    // cumulus_col = clouds_layers.r*cumulus_col;
    // cumulus_col = clouds_layers.r;
    // cumulus_col = get_cumulus(normalized_y, clouds_layers, map_coverage);
    cumulus_col *= step(1.0-base_coverage, cumulus_col);
    return cumulus_col*base_density;
    // return map_tex.r*cumulus_col; // Times height map sample and full sample at sceneSDF and go back to two step types?
    // return map_tex.r;
    float stratus_color = get_stratus(normalized_y, clouds_layers, map_coverage);
    float cumulus_color = get_cumulus(normalized_y, clouds_layers, map_coverage);

#ifdef DEBUG_CLOUDS
    float clouds = mix(stratus_color, cumulus_color, clouds_type);
#else
    float clouds_type = map_tex.g;
    float clouds = mix(stratus_color, cumulus_color, clouds_type);
#endif
    return clouds;

}

float sceneSDF(vec3 p) {
    float clouds = simpleSDF(p);
    vec4 clouds_detail = texture(clouds_detail_texture, p*vec3(clouds_detail_scale)-wind_direction*.05);
    clouds -= (clouds_detail.r)*clouds_detail_scale_r;
    clouds -= (clouds_detail.g)*clouds_detail_scale_g;
    clouds -= (clouds_detail.b)*clouds_detail_scale_b;
    return clouds;
}

float lightmarch_cheap(in highp vec3 p, in vec3 rd) {
    vec3 lightDir = normalize(sun_position);

    float zMaxl         = 600.;
    float step_size         = MAX_LIGHT_SAMPLE_DISTANCE/float(MAX_STEPS_LIGHTS);
    float randomDeviation = hash11(dot(p, vec3(12.256, 2.646, 6.356)) + TIME);
    p += randomDeviation*step_size*lightDir;
	
    float totalDensity = 0.0;
    for (int i = 0; i < MAX_STEPS_LIGHTS; i++) {
        float lightSample = simpleSDF(p+rd*float(i)*step_size);
        totalDensity += lightSample; // integration in step
    }

    float transmittanceB = BeersLaw(totalDensity*step_size, SCATTERING_COEFFICIENT_CLOUDS); // Out scattering approximation, assume no absorption
    float mu = dot(rd, -lightDir);
    float transmittanceP = SugarPowder(totalDensity, SCATTERING_COEFFICIENT_CLOUDS); // In scattering approximation
    float beerPowder = transmittanceB+transmittanceP;
    float sun_dir = dot(rd, -lightDir)*.5+.5;
    float result  = mix(transmittanceB, beerPowder, sun_dir);
    return result;
}

float lightmarch(in highp vec3 p, in vec3 rd) {
    vec3 lightDir = normalize(sun_position);

	float step_size = MAX_LIGHT_SAMPLE_DISTANCE/float(MAX_STEPS_LIGHTS);
    float randomDeviation = hash11(dot(p, vec3(12.256, 2.646, 6.356)) + TIME);
    p += randomDeviation*step_size*lightDir;
	
    float totalDensity = 0.0;
    for (int i = 0; i < MAX_STEPS_LIGHTS; i++) {
        float lightSample = sceneSDF(p+rd*float(i)*step_size);
        totalDensity += lightSample; // integration in step
    }

    float transmittanceB = BeersLaw(totalDensity*step_size, SCATTERING_COEFFICIENT_CLOUDS); // Out scattering approximation, assume no absorption
    // return transmittanceB;
    float mu = dot(rd, -lightDir);
    float transmittanceP = SugarPowder(totalDensity, SCATTERING_COEFFICIENT_CLOUDS); // In scattering approximation
    float beerPowder = transmittanceB+transmittanceP;
    float sun_dir = dot(rd, -lightDir)*.5+.5;
    float result  = mix(transmittanceB, beerPowder, sun_dir);
    return result;
}


vec4 raymarch(in highp vec3 ro, in vec3 rd, in float max_distance_travelled, inout highp float depth, in vec2 coord) {
    vec4 light = vec4(vec3(0.0), 1.0);
    vec3 lightDir = normalize(sun_position);
    float mu = dot(rd, lightDir);

	// Double Lobe HG
    float phase= mix(HenyeyGreenstein(-SCATTERING_ANISO_BW, mu), HenyeyGreenstein(SCATTERING_ANISO_FW, mu), 0.5);

    float view_height_dot = 1.0-clamp(dot(rd, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
    int marching_steps = int(mix(float(MIN_MARCHING_STEPS), float(MAX_MARCHING_STEPS), view_height_dot));
    float current_step_size = max_distance_travelled/float(marching_steps); // Ensure we reach the end

	// Add some randomness to the ray direction
    depth += hash11(dot(rd, vec3(12.256, 2.646, 6.356)) + TIME)*current_step_size;

    highp vec3 samplePosition = ro + depth * rd;
    for (int i = 0; i < marching_steps; i++) {
		float point_density = sceneSDF(samplePosition);

		bool hit = point_density > 0.001;
		if (hit) {
			float lightTransmittance;
			if (light.a < 0.3) {
				// lightTransmittance = lightmarch_cheap(samplePosition, rd);
				lightTransmittance = lightmarch(samplePosition, rd);
			}
			else{
				lightTransmittance = lightmarch(samplePosition, rd);
			}

			float atmoHeight = length(samplePosition - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
			float normalized_y = clamp((atmoHeight-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);

			vec3 ambient = (0.5 + 0.6*normalized_y)*vec3(0.2, 0.5, 1.0)*.1 + vec3(0.3) * max(0.0, 1.0-2.0*normalized_y);
			// vec3 ambient = (3.5 + 0.6*normalized_y)*vec3(0.2, 0.5, 1.0)*2.1 + vec3(0.3) * max(0.0, 1.0-2.0*normalized_y);
            // vec3 ambient = (0.5 + 0.6*normalized_y)*vec3(0.2, 0.5, 1.0)*6.5 + vec3(0.8) * max(0.0, 1.0-2.0*normalized_y);
			// ambient = (0.6*normalized_y)*vec3(0.4, 0.6, 1.0)*.1 + vec3(0.3) * max(0.0, 1.0-2.0*normalized_y);
			// ambient = vec3(0.8, 0.8, 1.0)*.2;
			vec3 radiance = ambient + sun_energy*SUN_POWER*lightTransmittance*phase;
			radiance *= point_density; // Captured radiance
			float localExtinction = point_density * SCATTERING_COEFFICIENT_CLOUDS;
			float stepExtinction = BeersLaw(current_step_size*point_density, SCATTERING_COEFFICIENT_CLOUDS);
			vec3 integrated_scattering = (radiance - radiance * stepExtinction) / localExtinction;
			light.rgb += integrated_scattering*light.a;
			light.a *= stepExtinction;
			if (light.a < 0.01) {
				break;
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

// TODO: Fix flight
float intersectSphere(vec3 origin, vec3 dir, vec3 spherePos, float sphereRad){
	vec3 oc = origin - spherePos;
	float b = 2.0 * dot(dir, oc);
	float c = dot(oc, oc) - sphereRad*sphereRad;
	float disc = b * b - 4.0 * c;
	if (disc < 0.0)
		return -1.0;
    float q = (-b - sign(b) * sqrt(disc)) / 2.0;
	float t0 = q;
	float t1 = c / q;
    float minT = min(t0, t1);
    float maxT = max(t0, t1);
    t0 = minT;
    t1 = maxT;
	// if (t1 < 0.0)
	// 	return -1.0;
    // return t1;
    return mix(t1, t0, step(0.0, t0));
    // return max(t0, 0.0) + max(t1 - t0, 0.0);

    return (t0 < 0.0) ? t1 : t0;
}

float RenderGlow(float dist, float radius, float intensity) {
  dist = max(dist, 1e-6);
	return (1.0 - exp(-25.0 * (radius / dist))) * 0.1 + (1.0 - exp(-0.05 * (radius / dist) * (radius / dist))) * 2.0;
}

vec3 RenderSky(vec3 cameraOrigin, vec3 cameraDir, float uvy) {
  float skyT1 = pow(smoothstep(0.0, 1.0, uvy), 0.5);
  float skyT2 = pow(smoothstep(0.5, 1.0, uvy), 1.0);

  vec3 c1 = vec3(COLOUR_LIGHT_BLUE * 0.25);
  vec3 c2 = vec3(COLOUR_BRIGHT_BLUE);
  vec3 c3 = vec3(COLOUR_BRIGHT_BLUE * 1.25);
  vec3 sky = mix(c1, c2, skyT1);
  sky = mix(sky, c3, skyT2);

  float mu = dot(cameraDir, normalize(sun_position));
  float mu_norm = inverse_lerp(-1.0, 1.0, mu);

  // vec3 background = 6.0*mix(vec3(0.2, 0.52, 1.0), vec3(0.8, 0.95, 1.0), pow(0.5+0.5*mu, 15.0)); // uper sky
  // background += mix(vec3(3.5), vec3(0.0), min(1.0, 2.3*cameraDir.y))*1.0; // lower sky half
  vec3 background = 3.0*mix(vec3(0.2, 0.52, 1.0), vec3(0.8, 0.95, 1.0), pow(mu_norm, 15.0)); // uper sky
  background += mix(vec3(0.7), vec3(0.0), min(1.0, 2.3*cameraDir.y))*1.0; // lower sky half

  // background = mix(COLOR_SKY_TOP, COLOR_SKY_MID, pow(mu_norm, 15.0)); // uper sky
  // background += mix(COLOR_SKY_BOTTOM, vec3(0.0), min(1.0, 2.3*cameraDir.y)); // lower sky half
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


uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D bg_texture : hint_screen_texture, source_color;
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

    // WARNING: Shell should be much lower than our origin
    // vec2 rayToContainerInfo = raySphereShellDst(ro, rd); // Fake ray origin to keep spehere centered on us
    // dstToMarchStart = rayToContainerInfo.x;
    // dstToMarchEnd = rayToContainerInfo.y;
    float dstToMarchStart = intersectSphere(ro, rd, vec3(.0, -EARTH_RADIUS, .0), EARTH_RADIUS+clouds_min_height);
    float dstToMarchEnd = intersectSphere(ro, rd, vec3(.0, -EARTH_RADIUS, .0), EARTH_RADIUS+clouds_max_height);

    vec2 coord = vec2(FRAGCOORD.xy);
    int texture_size = 469;

    coord += vec2(TIME)*1000.0; // 'randomize' and pair with TTA

    ro += dstToMarchStart*rd; // Advance ray till clouds volume
    if (!map_hit){ // Discard if something hit and not out of bounds
        bool clouds_plane_hit = dstToMarchEnd - dstToMarchStart != 0.0;
        float threshold = 0.001; // Define your threshold
        float distance_to_threshold = -log(threshold) / EXCTINCTION_COEFFICIENT_SKY;
        float total_distance = dstToMarchStart; // Atenuate based on plane distance
        // total_distance = dstToMarchStart; // Atenuate based on plane distance

        bool scattering_to_high = dstToMarchStart > distance_to_threshold;
        vec3 sky = RenderSky(ro, rd, SCREEN_UV.y);
        float mu = dot(rd, normalize(sun_position));
        float mu_norm = inverse_lerp(1.0, -1.0, mu);
        float glow = RenderGlow(mu_norm, 0.001, 0.5);
        vec3 sun =  vec3(glow, glow*.6, 0.0)*2.;
		// clouds_plane_hit = true;
		// scattering_to_high = false;
        // Scattering too far can happen
		if (dstToMarchStart < 0.0){
            ALBEDO = sky+sun;
		}
        else
			if (!clouds_plane_hit || scattering_to_high){ // Skip rendering clouds where no clouds can be seen
				ALBEDO = sky+sun;
        }
        else{
            float ray_hit_depth = 0.0;

            float cosine = length(vec3(rd.x, 0.0, rd.z));
            vec4 result = raymarch(ro,rd, dstToMarchEnd-dstToMarchStart, ray_hit_depth, FRAGCOORD.xy);
            float transmittance = result.w;
            vec3 energy = result.xyz;
            float extinction = exp(-EXCTINCTION_COEFFICIENT_SKY * total_distance);

            vec3 earth_center = vec3(0, EARTH_RADIUS, 0); // assuming Earth's center is at (0, EARTH_RADIUS, 0)
            vec3 p = ray_sphere_distance(ro, rd, -earth_center, EARTH_RADIUS + cirrus_height)*rd;
            vec3 evolution_over_time = vec3(0,1,0);
			float high_clouds = texture(cirrus, p*cirrus_scale+(evolution_over_time+wind_direction)*TIME*0.01).r;
			high_clouds -= (1.0-cirrus_coverage);
            high_clouds = max(0.0, high_clouds);
            high_clouds *= cirrus_density;

            vec3 clouds = energy;
            vec3 color = clouds+sky*(transmittance)+sun*transmittance;
            color += vec3(high_clouds)*transmittance;

            vec3 hdr = mix(sky+sun, color, extinction);
            ALBEDO = hdr;
        }
    }
    else{ // We hit something. is it in between the clouds?

		// This already works if disable but can be optimized
        if (map_depth<dstToMarchStart){ // Discard if map closer than clouds plane
            discard;
        }

        bool clouds_plane_hit = dstToMarchEnd - dstToMarchStart != 0.0;
        float threshold = 0.001; // Define your threshold
        float distance_to_threshold = -log(threshold) / EXCTINCTION_COEFFICIENT_SKY;
        bool scattering_to_high = dstToMarchStart > distance_to_threshold;
        vec3 sky = RenderSky(ro, rd, SCREEN_UV.y);
        float mu = dot(rd, normalize(sun_position));
        float mu_norm = inverse_lerp(1.0, -1.0, mu);
        float glow = RenderGlow(mu_norm, 0.001, 0.5);
        vec3 sun =  vec3(glow, glow*.6, 0.0)*20.0;
        if (!clouds_plane_hit || scattering_to_high){ // Skip rendering clouds where no clouds can be seen
            discard;
        }
		if (dstToMarchStart < 0.0){
             ALBEDO = sky.rgb+sun;
		}
        else {
        // Map through clouds
        float distance_to_travel = min(map_depth, dstToMarchEnd-dstToMarchStart);
        float ray_hit_depth = 0.0;
        vec4 result = raymarch(ro,rd, distance_to_travel , ray_hit_depth, FRAGCOORD.xy);
        vec3 energy = result.xyz;
        float transmittance = result.w;
        // float total_distance = dstToMarchStart; // Atenuate based on plane distance
        float total_distance = dstToMarchStart-clouds_min_height; // Atenuate based on plane distance
        float extinction = exp(-EXCTINCTION_COEFFICIENT_SKY * total_distance);
        vec3 clouds = energy * vec3(1.0);

        vec3 bg_color = texture(bg_texture, SCREEN_UV).rgb;
        vec3 color = clouds+bg_color*(transmittance);
        // ALBEDO.rgb = color;
		}
        // ALBEDO.rgb = clouds;
    }
    // ALBEDO /= 18.0;
}
