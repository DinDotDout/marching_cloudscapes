shader_type sky;
render_mode use_half_res_pass;
// render_mode  ;
// render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;

#define K 0.5

const float EARTH_RADIUS = 6300e3;
// const float EARTH_RADIUS = .0;
// render_mode cull_disabled;

// render_mode cull_disabled, unshaded;
// render_mode cull_disabled, unshaded, depth_draw_never;

group_uniforms sampling;
uniform int MIN_MARCHING_STEPS:hint_range(1, 100, 5) = 35;
uniform int MAX_MARCHING_STEPS:hint_range(1, 100, 5) = 60;

group_uniforms light_interaction;
uniform float sun_energy:hint_range(.0, 1000.0, .01) = 1.0;
const vec3 SUN_POWER = vec3(1.0,.9, 0.6);

uniform int MAX_STEPS_LIGHTS: hint_range(1, 20) = 6;
uniform float MAX_LIGHT_SAMPLE_DISTANCE: hint_range(.01, 1000.0, 10.0) = 600.0;

uniform float SCATTERING_ANISO_FW:hint_range(.0, 1.0, .01)  = .5;
uniform float SCATTERING_ANISO_BW:hint_range(.0, 1.0, .01)  = .4;

uniform highp float EXCTINCTION_COEFFICIENT_SKY:hint_range(.0, .0002, .000001) = 0.;
uniform float SCATTERING_COEFFICIENT_CLOUDS :hint_range(.0, 1.0, .001) = 0.11;


// group_uniforms post_processing;
// uniform float temp_aa: hint_range(.0, 1.0, .01) = 0.0;

group_uniforms clouds;
uniform float clouds_min_height: hint_range(000.0, 4000) = 1500.0;
uniform float clouds_max_height: hint_range(900.0, 10000) = 1500.0;
// uniform float AMBIENT_STRENGTH:hint_range(.0, .101, .00001) = .0;
uniform sampler2D stratus: source_color;
uniform sampler2D cumulus: source_color; // TODO: Apply for distance to center
uniform sampler2D cumulonimbus: source_color;

// Main shape
uniform float map_cut_size: hint_range(0.0, .001, .00001) = 0.0;
uniform float cut_size: hint_range(0.0, .001, .00001) = 0.0;
uniform float cut_size2: hint_range(0.0, .003, .00001) = 0.0;
uniform float cut_cirrus: hint_range(0.0, .003, .00001) = 0.0;

uniform float clouds_type_test: hint_range(0.0, 1.0, .01) = 0.0;

// WARNING: Probably will remove and hardcode according to clouds type
uniform float base_density: hint_range(0.0, 1.0, .01) = 1.;
uniform float base_coverage: hint_range(0.0, 1.0, .01) = 0.5;

uniform float second_degrade: hint_range(0.0, .3, .0001) = 0.0;
uniform float third_degrade: hint_range(0.0, .3, .0001) = 0.0;
uniform float last_degrade: hint_range(0.0, .3, .0001) = 0.0;

group_uniforms sky_color;
uniform vec3 COLOUR_LIGHT_BLUE: source_color;
uniform vec3 COLOUR_BRIGHT_BLUE: source_color;


group_uniforms textures;
uniform sampler3D voronoi: source_color;
uniform sampler3D voronoi2: source_color;
uniform sampler3D cirrus: source_color;
// uniform sampler2D prev_frame: source_color;

uniform sampler2D map: source_color;

group_uniforms auto_update;
uniform vec3 sun_position = vec3(0, 1, 0);
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
    float stratus_coverage = .8;
    result_layer *= stratus_coverage;
    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);
    float stratus_color = texture(stratus, vec2(height, TIME*.0)).r;
    // stratus_color = 1.0;
    // stratus_color = texture(cumulonimbus, vec2(height, TIME*.0)).r;
    const float stratus_density = .03;
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
    float cumulus_coverage = base_coverage;
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
    float cumulonimbus_coverage = 1.0;
    result_layer *= cumulonimbus_coverage;
    // result_layer -= coverage;
    result_layer = smoothstep(1.0-map_coverage, 1.0, result_layer);
    float cumulonimbus_color = texture(cumulonimbus, vec2(height, TIME*.0)).r;

    const float cumulonimbus_density = 1.0;
    return cumulonimbus_color*result_layer*cumulonimbus_density;
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
    // vec3 map_tex = (texture(map, fract(uv*map_cut_size))).rgb;
    // vec3 map_tex = (texture(map, (p.xz*map_cut_size)-vec2(.0, TIME*.00))).rgb;
    vec3 map_tex = (texture(map, (p.xz*map_cut_size)-vec2(.20, 0.50))).rgb;
    // map_tex = vec3(1.0);

    float map_coverage = map_tex.r;
    // map_coverage = 1.0;
    float clouds_type = map_tex.g;
    // clouds_type = 1.0;
    float precipitation = map_tex.b;

    // Clouds type set which one will be, but chance of one or other increases with coverage or height?
    vec4 clouds_layers = texture(voronoi, p*vec3(cut_size)+vec3(.0, .0, TIME*0.02));
    float stratus_color = get_stratus(normalized_y, clouds_layers, map_coverage);
    float cumulus_color = get_cumulus(normalized_y, clouds_layers, map_coverage);
    float cumulonimbus_color = get_cumulonimbus(normalized_y, clouds_layers, map_coverage);
    float clouds = mix(stratus_color, cumulus_color, clouds_type_test);
    // float clouds = mix(stratus_color, cumulus_color, clouds_type);

    // clouds = cumulus_color;
    // clouds = stratus_color;
    // clouds = cumulonimbus_color;
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
    float mu = dot(rd, -lightDir);
    float transmittanceP = SugarPowder(totalDensity, SCATTERING_COEFFICIENT_CLOUDS); // In scattering approximation
    float beerPowder = transmittanceB+transmittanceP;
    float sun_dir = dot(rd, -lightDir)*.5+.5;
    float result  = mix(transmittanceB, beerPowder, sun_dir);
    return result;
}


#define TEST
vec4 raymarch(in highp vec3 ro, in vec3 rd, in float max_distance_travelled, inout highp float depth) {
    vec4 light = vec4(vec3(0.0), 1.0);
    vec3 lightDir = normalize(sun_position);
    float mu = dot(rd, lightDir);

	// Double Lobe HG
    float phase= mix(HenyeyGreenstein(-SCATTERING_ANISO_BW, mu), HenyeyGreenstein(SCATTERING_ANISO_FW, mu), K);

    float view_height_dot = 1.0-clamp(dot(rd, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
    int marching_steps = int(mix(float(MIN_MARCHING_STEPS), float(MAX_MARCHING_STEPS), view_height_dot));
    float current_step_size = max_distance_travelled/float(marching_steps); // Ensure we reach the end

	// Add some randomness to the ray direction
    depth = hash11(dot(rd, vec3(12.256, 2.646, 6.356)) + TIME*1.0)*current_step_size;

    highp vec3 samplePosition = ro + depth * rd;
    for (int i = 0; i < marching_steps; i++) {
		float point_density = sceneSDF(samplePosition);

		bool hit = point_density > 0.001;
		if (hit) {

			float lightTransmittance;
			if (light.a < 0.3) {
				lightTransmittance = lightmarch_cheap(samplePosition, rd);
			}
			else{
				lightTransmittance = lightmarch(samplePosition, rd);
			}

			float atmoHeight = length(samplePosition - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
			float normalized_y = clamp((atmoHeight-clouds_min_height)/(clouds_max_height-clouds_min_height), 0.0, 1.0);

			vec3 ambient = (0.5 + 0.6*normalized_y)*vec3(0.2, 0.5, 1.0)*.5 + vec3(0.3) * max(0.0, 1.0-2.0*normalized_y);
			ambient = vec3(0.8, 0.8, 1.0)*.5;
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

vec2 raySphereShellDst(in vec3 ro, in vec3 rd) {
     // Avoid precission loss by bringing center of sphere to origin
	// ro -= vec3(.0, EARTH_RADIUS, .0);
    // float innerRadius = clouds_min_height+EARTH_RADIUS;
    // float outerRadius = clouds_max_height+EARTH_RADIUS;
    float innerRadius = clouds_min_height;
    float outerRadius = clouds_max_height;
    vec3 oc = ro;
    float b = 2.0 * dot(oc, rd);

	// ro += vec3(.0, +EARTH_RADIUS, .0);
	// ro += vec3(.0, +EARTH_RADIUS, .0);
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
    // return abs(vec2(t1, t2));

	// ro += vec3(.0, +EARTH_RADIUS, .0);
	// ro += vec3(.0, +EARTH_RADIUS, .0);
		// return abs(vec2(t2, t1));
    if (length(ro) <= innerRadius) {
        return abs(vec2(t1, t2));
    }

	// return abs(vec2(t1, t2));
	return abs(vec2(.0, t2));
    if (length(ro) > innerRadius && length(ro) < outerRadius) {
        if (hit1){
            // return abs(vec2(t1, T2));
        }
        return abs(vec2(0, t1));
        return abs(vec2(0, T2));

    }

    // CASE 3
    if (length(ro) > outerRadius) {
        if (hit2){
            return (vec2(0, T2));
        }
        // return abs(vec2(0, 2));
    }
    // return abs(vec2(0, 0));

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

  float mu = dot(cameraDir, normalize(sun_position));
  // float mu_norm = inverse_lerp(1.0, -1.0, mu);

  // vec3 background = 6.0*mix(vec3(0.2, 0.52, 1.0), vec3(0.8, 0.95, 1.0), pow(0.5+0.5*mu, 15.0)); // uper sky
  // background += mix(vec3(3.5), vec3(0.0), min(1.0, 2.3*cameraDir.y))*1.0; // lower sky half
  vec3 background = 6.0*mix(vec3(0.2, 0.52, 1.0), vec3(0.8, 0.95, 1.0), pow(0.5+0.5*mu, 15.0)); // uper sky
  background += mix(vec3(3.5), vec3(0.0), min(1.0, 2.3*cameraDir.y))*1.0; // lower sky half
  // background = mix(COLOR_SKY_TOP, COLOR_SKY_MID, pow(mu_norm, 15.0)); // uper sky
  // background += mix(COLOR_SKY_BOTTOM, vec3(0.0), min(1.0, 2.3*cameraDir.y)); // lower sky half

  vec4 result = vec4(background, 0.0);
  // vec4 result = vec4(sky, 0.0);

  return result;
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

float ray_plane_distance(in vec3 ro, in vec3 rd, in vec3 plane_position){
	float denom = dot(vec3(0,1,0), rd);
	if (abs(denom) > 0.0001){
		float t = dot(plane_position - ro, vec3(0,1,0)) / denom;
		return t;
	}
	return -1.0;
}

// uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D bg_texture : hint_screen_texture, source_color;
void sky(){
	// if (AT_CUBEMAP_PASS) {
 //        // Sets the radiance cubemap to a nice shade of blue instead of doing
 //        // expensive sky calculations
 //        COLOR = vec3(0.2, 0.6, 1.0);
 //    } else {
 //        // Do expensive sky calculations for background sky only
 //        // COLOR = get_sky_color(rd);
 //    }
	vec3 rd = vec3(EYEDIR.xz / clamp(EYEDIR.y, 0.0, 1.0), 1.0);

	if (AT_HALF_RES_PASS) {
        // Run cloud calculation for 1/4 of the pixels
		// WARNING: Shell should be much lower than our origin
		vec2 rayToContainerInfo = raySphereShellDst(POSITION, rd); // Fake ray origin to keep spehere centered on us
		float dstToMarchStart = rayToContainerInfo.x;
		float dstToMarchEnd = rayToContainerInfo.y;
		dstToMarchStart = ray_plane_distance(POSITION, rd, vec3(0,clouds_min_height,0));
		dstToMarchEnd = ray_plane_distance(POSITION, rd, vec3(0,clouds_max_height,0));

		// int texture_size = 469;

		bool clouds_plane_hit = dstToMarchEnd - dstToMarchStart != 0.0;
		float threshold = 0.001; // Define your threshold
		float distance_to_threshold = -log(threshold) / EXCTINCTION_COEFFICIENT_SKY;
		float total_distance = dstToMarchStart-clouds_min_height; // Atenuate based on plane distance
																  // total_distance = dstToMarchStart; // Atenuate based on plane distance
		bool scattering_to_high = dstToMarchStart > distance_to_threshold;
		vec4 pixel = RenderSky(POSITION, rd, SCREEN_UV.y);
		float mu = dot(rd, normalize(sun_position));
		float mu_norm = inverse_lerp(1.0, -1.0, mu);
		float glow = RenderGlow(mu_norm, 0.001, 0.5);
		vec3 sun =  vec3(glow, glow*.6, 0.0)*20.0;

		// Scattering too far can happen
		// if (!clouds_plane_hit || scattering_to_high){ // Skip rendering clouds where no clouds can be seen
		// 	vec3 hdr = pixel.rgb;
		// 	COLOR = hdr;
		// 	COLOR = vec3(0.2, 0.6, 1.0);
		//
		// }
		// else{
		float ray_hit_depth = 0.0;
		// POSITION += dstToMarchStart*rd; // Advance ray till clouds volume
		vec4 result = raymarch(POSITION,rd, dstToMarchEnd-dstToMarchStart, ray_hit_depth);
		float transmittance = result.w;
		vec3 energy = result.xyz;
		float extinction = exp(-EXCTINCTION_COEFFICIENT_SKY * total_distance);

		// vec3 pC = ray_sphere_distance(POSITION, rd, 100000.0)*rd;
		// float sample_high_clouds = texture(cirrus, pC*cut_cirrus).r;
		// vec3 high_clouds = transmittance*vec3(3.0)*max(0.0, sample_high_clouds-0.0);

		vec3 clouds = energy * vec3(1.0);
		vec3 color = clouds+pixel.rgb*(transmittance)+sun*transmittance;
		// color += high_clouds*3.0;

		COLOR = clouds;
		ALPHA = transmittance;
		// ALBEDO = mix(pixel.rgb, color, extinction)/18.0;
		// vec3 hdr = mix(pixel.rgb, color, extinction);
		// COLOR = hdr;
			// COLOR = color;
		// }

    } else {
        // At full resolution pass, blend sky and clouds together
        // vec3 color = generate_sky(rd);

		vec4 pixel = RenderSky(POSITION, rd, SCREEN_UV.y);
		float mu = dot(rd, normalize(sun_position));
		float mu_norm = inverse_lerp(1.0, -1.0, mu);
		float glow = RenderGlow(mu_norm, 0.001, 0.5);
		vec3 sun =  vec3(glow, glow*.6, 0.0)*20.0;
		vec3 color = pixel.rgb+sun;
        COLOR = color + HALF_RES_COLOR.rgb * HALF_RES_COLOR.a;
		// COLOR.rgb = mix(pixel.rgb, HALF_RES_COLOR.rgb, 1.0-HALF_RES_COLOR.a);
    }
    // highp vec3 ro = POSITION;
    // vec3 rd = normalize(world_position - ro);

}
