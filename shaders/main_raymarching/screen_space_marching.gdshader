// uniform sampler2D prev_frame; // The previous frame
// uniform sampler2D depth_buffer; // The depth buffer
// uniform mat4 prev_view_proj_inv; // The inverse of the previous frame's view projection matrix
// uniform mat4 curr_view_proj; // The current frame's view projection matrix
//
// void fragment() {
//     // Get the depth value for the current pixel.
//     float depth = texture(depth_buffer, UV).r;
//
//     // Calculate the world position of the current pixel.
//     vec4 clipPos = vec4(UV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
//     vec4 worldPos = prev_view_proj_inv * clipPos;
//     worldPos /= worldPos.w;
//
//     // Project the world position into the current frame's clip space.
//     vec4 clipPosCurr = curr_view_proj * worldPos;
//     clipPosCurr /= clipPosCurr.w;
//
//     // Calculate the UV coordinates in the previous frame.
//     vec2 prevUV = clipPosCurr.xy * 0.5 + 0.5;
//
//     // Sample the previous frame using the calculated UV coordinates.
//     vec4 color = texture(prev_frame, prevUV);
//
//     // Output the color.
//     COLOR = color;
// }
shader_type spatial;
render_mode cull_disabled, unshaded;
// render_mode cull_disabled, unshaded, depth_draw_never;
uniform int MAX_MARCHING_STEPS:hint_range(1, 1000, 1) = 100;
uniform float STEP_SIZE:hint_range(.0, 30.0, .01) = .3;
uniform float LARGE_STEP_SIZE:hint_range(.01, 5.0, .01) = .3;
uniform int MAX_STEPS_LIGHTS:hint_range(1, 20) = 6;
uniform float STEPS_SIZE_LIGHTS:hint_range(0.001, 5.8, .001) = .09;

const float K = 0.7;
uniform float SCATTERING_ANISO_FW:hint_range(.0, 1.0, .01)  = .5;
uniform float SCATTERING_ANISO_BW:hint_range(.0, 1.0, .01)  = .4;
uniform float ABSORPTION_COEFFICIENT_CLOUDS :hint_range(.0, 2.0, .01) = 0.11;
uniform float ABSORPTION_COEFFICIENT_LIGHT :hint_range(.0, 4.0, .01) = 0.67;
// const float ABSORPTION_COEFFICIENT = 1.32;
uniform float ABSORPTION_COEFFICIENT_SUGAR :hint_range(.0, 4.0, .01) = 0.64;
uniform sampler2D sky_color: hint_default_black;
uniform sampler2D blue_noise: hint_default_black;

uniform vec3 sunPosition;

const vec3 SKY_COLORS[3] = vec3[3](vec3(0.8, 0.38, 0.00), vec3(0.18, 0.43, 0.76), vec3(0.40, 0.70, 0.90));

const float EPSILON = 0.001;
varying mat4 CAMERA;

#include "res://shaders/main_raymarching/raymarch_utils.gdshaderinc"


vec3 texture_bg(in vec3 ro, in vec3 rd) {
    // rd = clamp(rd, .0, 1.0);
    // rd = fract(rd);
    float normalized_rdy = inverse_lerp(-1.0, 1.0, rd.y);

    vec2 uv = vec2(atan(rd.z, rd.x) / (2.0 * PI) + 0.5, asin(rd.y) / PI + 0.5);
    return texture(sky_color, clamp(uv.yy,.0, 1.0)).rgb;
}

varying vec3 position; //Vertex Position
void vertex() {
    POSITION = vec4(VERTEX, 1.0);
    // position = (MODEL_MATRIX * vec4(VERTEX,1)).xyz; //Vertex Position in World Space
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

vec3 get_world_position(in vec3 ndc, in mat4 inv_proj_mat){
    vec4 world = CAMERA * inv_proj_mat * vec4(ndc, 1.0);
    vec3 world_position = world.xyz / world.w;
    return world_position;
}




uniform float noise_size = .1;
uniform float skybox_dist: hint_range(0.0, 10000, 10) = 4000;

uniform float coverage: hint_range(0.0, 1.0, .01) = 0.5;
uniform float coverage2: hint_range(0.0, 1.0, .01) = 0.5;
uniform float horizon_fade: hint_range(0.0, 1.0) = .1;
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
    // float sunDot = dot(normalize(sunPosition), rd);
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

uniform sampler3D voronoi: hint_default_black;
uniform sampler2D density_gradient: hint_default_black;
uniform float cut_size: hint_range(0.0, .01, .0001) = 0.0;
// uniform float base_density: hint_range(0.0, 1.0, .01) = 0.5;
uniform float base_density: hint_range(0.0, 1.0, .01) = 0.12;
uniform float second_degrade: hint_range(0.0, 1.0, .01) = 0.35;
uniform float third_degrade: hint_range(0.0, 1.0, .01) = 0.5;
uniform float last_degrade: hint_range(0.0, 1.0, .01) = 0.15;
uniform float earth_radius: hint_range(0.0, 10000.0, 100) = 6000.0;
// uniform float clouds_min_height: hint_range(0.0, 400) = 5.0;
// uniform float clouds_max_height: hint_range(0.0, 400) = 15.0;
uniform float clouds_min_height: hint_range(500.0, 4000) = 1500.0;
uniform float clouds_max_height: hint_range(900.0, 4000) = 1500.0;
float sceneSDF(vec3 p) {
    vec4 clouds_layers = texture(voronoi, p*vec3(cut_size)+vec3(.0, .0, TIME*.0));
    float first_layer = clouds_layers.r;
    // float second_layer = clouds_layers.g;
    // float third_layer = clouds_layers.b;
    // float last_layer = clouds_layers.a;
    // float density = 1.0-texture(density_gradient, vec2(1.0)*p.y/clouds_max_height).r;
    // density *= step(0.0, p.y);
    // if (p.y <= 1.001){
        // return 0.0;
    // }
    // float density = texture(density_gradient, vec2(1.0)*max(p.y, .001)/clouds_max_height).r;
    
    // float density = mix(1.0,base_density,  max(p.y, .0)/clouds_max_height);
    // first_layer = smoothstep(density, 1.0, first_layer);
    first_layer = smoothstep(base_density, 1.0, first_layer);

    // first_layer -= (1.0-second_layer)*second_degrade;
    // first_layer -= (1.0-third_layer)*third_degrade;
    // first_layer -= (1.0-last_layer)*last_degrade;
    return first_layer;
}


float lightmarch(in vec3 p, in vec3 rd) {
    vec3 lightDir = normalize(sunPosition);
    float totalDensity = 0.0;
    // float stepSize = 0.009;

    for (int i = 0; i < MAX_STEPS_LIGHTS; i++) {
        p += lightDir * STEPS_SIZE_LIGHTS;
        float lightSample = sceneSDF(p);
        totalDensity += lightSample * STEPS_SIZE_LIGHTS; // integration in step
    }
    float transmittanceB = BeersLaw(totalDensity, ABSORPTION_COEFFICIENT_LIGHT);
    float transmittanceP = SugarPowder(totalDensity, ABSORPTION_COEFFICIENT_SUGAR, rd);
    float beerPowder = transmittanceB*transmittanceP;
    float sun_dir = dot(rd, lightDir)*.5+.5;
    float result  = mix(transmittanceB, beerPowder, sun_dir);
    return result;

    // return beerPowder;

    // return (transmittanceB*transmittanceP);
    //return 1.0-(transmittanceB*transmittanceP);
}
vec2 raymarch(in vec3 ro, in vec3 rd, in float max_depth, inout float depth, vec2 coord) {
    vec3 lightDir = normalize(sunPosition);
    float transmittance = 1.0;
    float lightEnergy = 0.0;
    float sundot = dot(rd, lightDir);
    // float phase = HenyeyGreenstein(SCATTERING_ANISO, dot(rd, lightDir)); // Brighter around sun
    float phase= mix(HenyeyGreenstein(-SCATTERING_ANISO_BW, sundot), HenyeyGreenstein(SCATTERING_ANISO_FW, sundot), K);

    float dither = texelFetch(blue_noise, ivec2(int(coord.x)%469, int(coord.y)%469), 0).r * 4.4; // TODO: Add more dither the closer
    // dither = 0.0;
    depth += dither;

    vec3 samplePosition = ro + depth* rd;

    float step_size = STEP_SIZE;
    float current_step_size = STEP_SIZE;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float density = sceneSDF(samplePosition);
                // transmittance *= BeersLaw(depth, AIR_ABSORPTION_COEFFICIENT);

        // Use min defined step the farther the bigger the step, step bigger if lower density too
        if (density > 0.001) {
            float lightTransmittance = lightmarch(samplePosition, rd);
            // float luminance = density;
            // luminance *= phase;
            //
            // lightEnergy += STEP_SIZE * transmittance * lightTransmittance * luminance;
            // transmittance *= BeersLaw(density * STEP_SIZE, ABSORPTION_COEFFICIENT_CLOUDS);
            float S = 3.0 * lightTransmittance * density * phase;
            float sampleExtinction = max(float(0.0000000001), density * ABSORPTION_COEFFICIENT_CLOUDS);
            float Sint = (S - S * exp(-sampleExtinction * STEP_SIZE)) / sampleExtinction;
            lightEnergy += Sint*transmittance;
            transmittance *= BeersLaw(density * STEP_SIZE, ABSORPTION_COEFFICIENT_CLOUDS);

            if (transmittance < 0.01) {
                break;
            }
        }
        // Skip steps when density is low
        // depth += current_step_size;


        depth += STEP_SIZE;
        samplePosition += STEP_SIZE * rd;

        if (depth > max_depth) {
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

vec2 raySphereShellDst3(in vec3 ro, in vec3 rd) {
    float innerRadius = clouds_min_height+earth_radius;
    float outerRadius = clouds_max_height+earth_radius;
    vec3 oc = ro;
    float b = 2.0 * dot(oc, rd);
    float c = dot(oc, oc) - innerRadius * innerRadius;
    float discriminant = b * b - 4.0 * c;
    if (discriminant < 0.0) {
        return vec2(-1.0); // No intersection
    } else {
        float t1 = (-b - sqrt(discriminant)) / 2.0;
        c = dot(oc, oc) - outerRadius * outerRadius;
        discriminant = b * b - 4.0 * c;
        if (discriminant < 0.0) {
            return vec2(-1.0); // No intersection
        } else {
            float t2 = (-b + sqrt(discriminant)) / 2.0;
            return vec2(-t1, -t2);
        }
    }
}

vec2 raySphereShellDst2(vec3 ro, vec3 rd) {
    float innerRadius = clouds_min_height;
    float outerRadius = clouds_max_height;
    vec3 oc = ro;
    float b = 2.0 * dot(oc, rd);
    float c = dot(oc, oc) - outerRadius * outerRadius;
    float discriminant = b * b - 4.0 * c;
    if (discriminant < 0.0) {
        return vec2(-1.0); // No intersection
    } else {
        float t = (-b + sqrt(discriminant)) / 2.0;
        return vec2(t);
    }
}


uniform sampler2D depth_texture : source_color, hint_depth_texture;
void fragment(){
    float depth = texture(depth_texture, SCREEN_UV).x;
    vec3 ndc = get_ndc(SCREEN_UV, depth);
    float map_depth = get_linear_depth(ndc, INV_PROJECTION_MATRIX);
    vec3 world_position = get_world_position(ndc, INV_PROJECTION_MATRIX);

    vec3 ro = CAMERA_POSITION_WORLD;
    // vec3 rd = normalize(world_position - ro);
    vec3 rd = normalize(world_position - ro);
    // ro = vec3(.0, .0, .0);
    // ro += vec3(.0, -earth_radius, .0);
    // WARNING: Shell should be much lower than our origin
    bool inOne = false;
    bool inTwo = false;
    vec2 rayToContainerInfo = raySphereShellDst(ro, rd, inOne, inTwo); // Fake ray origin to keep spehere centered on us

    float dstToMarchStart = rayToContainerInfo.x;
    float dstInsideShell = rayToContainerInfo.y;
    // dstInsideShell = 10000.0;

    // float ray_hit_depth = dstToMarchStart;
    float ray_hit_depth = 0.0;
    // ro = ro + dstToMarchStart * rd;
    // ro = vec3(.0, earth_radius, .0) + ro + dstToMarchStart * rd;
    // ro = ro + clouds_min_height* rd;
    // ro = vec3(.0, earth_radius, .0)+clouds_min_height* rd;
    // ro = vec3(.0, earth_radius, .0)+dstToMarchStart* rd;

    // ro += CAMERA_POSITION_WORLD; // Set back to camera postition to calculate noise position

    ro = CAMERA_POSITION_WORLD; // Set back to camera postition to calculate noise position
    // ro = vec3(.0, 0.0, .0);
    ro += dstToMarchStart*rd;

    // ro += dstInsideShell*rd;

    // ro = clouds_min_height* rd;
 
    bool clouds_occluded = map_depth < min(dstInsideShell, 4000.0); // Far plane is 4000.0
    // clouds_occluded = false;
    if (clouds_occluded){
        discard;
    }
    // else if (dot(ro, ro) > clouds_max_height * clouds_max_height) { // Skip if outside the sphere
    //     discard;
    // }
    else { // For now we assume we cannot reach the container
        vec2 result = raymarch(ro,rd, dstInsideShell, ray_hit_depth, FRAGCOORD.xy);
        bool hit_march_first = ray_hit_depth < map_depth && ray_hit_depth > 0.0;
        // hit_march_first = true;

        if(hit_march_first){
            float transmittance = result.y;
            ALBEDO = skybox(ro, rd); // Try skipping if occluded
            float energy = result.x;
            ALBEDO.rgb = energy * vec3(1.0)+ALBEDO.rgb*(transmittance);
            bool map_infitiy = depth >= 1.0;
            ALPHA = float(map_infitiy);

            // ALPHA = 1.0-transmittance;
        } else{
            discard;
        }
    }

    // ro = CAMERA_POSITION_WORLD; // Set back to camera postition to calculate noise position
    // bool inOne1 = length(ro) < clouds_min_height;
    // bool inTwo1 = length(ro) < clouds_max_height;


    // if (inOne && inTwo){
    //     vec3 white = vec3(1.0);
    //     ALBEDO = white;
    // }
    // else if (inOne){
    //     vec3 green = vec3(0.0, 1.0, 0.0);
    //     ALBEDO = green;
    // }
    // else if (inTwo){
    //     vec3 blue = vec3(0.0, 0.0, 1.0);
    //     ALBEDO = blue;
    // }
    // else{
    //     vec3 black = vec3(0.0, 0.0, 0.0);
    //     ALBEDO = black;
    // }
    // if (inOne1 && inTwo1){
    //     ALBEDO = vec3(1.0, 1.0, 1.0);
    // }
    // else if (inOne1){
    //     ALBEDO = vec3(0.0, 1.0, 0.0);
    // }
    // else if (inTwo1){
    //     ALBEDO = vec3(0.0, 0.0, 1.0);
    // }
    // else{
    //     ALBEDO = vec3(0.0, 0.0, 0.0);
    // }
    // ALPHA = 1.0;
}
