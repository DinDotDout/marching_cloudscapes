// Some postprocessing tests and effects
shader_type canvas_item;
render_mode unshaded;


float hash( float n )
{
    return fract(sin(n)*43758.5453);
}

const mat3 aces_input_matrix = mat3(
        vec3(0.59719f, 0.07600f, 0.02840f),
        vec3(0.35458f, 0.90834f, 0.13383f),
        vec3(0.04823f, 0.01566f, 0.83777f)
);

const mat3 aces_output_matrix = mat3( 
    vec3( 1.60475f, -0.10208f, -0.00327f),
    vec3(-0.53108f,  1.10813f, -0.07276f),
    vec3(-0.07367f, -0.00605f,  1.07602f)

);


vec3 rtt_and_odt_fit(vec3 v)
{
    vec3 a = v * (v + 0.0245786f) - 0.000090537f;
    vec3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

// https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
vec3 ACES(vec3 v)
{
    v = aces_input_matrix * v;
    v = rtt_and_odt_fit(v);
    return aces_output_matrix * v;
}

// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACES_fast( vec3 x )
{
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return (x*(a*x+b))/(x*(c*x+d)+e);
}

const ivec2 offsets[8] = ivec2[8]( ivec2(-1,-1), ivec2(-1, 1), 
        ivec2(1, -1), ivec2(1, 1), 
        ivec2(1, 0), ivec2(0, -1), 
        ivec2(0, 1), ivec2(-1, 0));

vec3 RGBToYCoCg( vec3 RGB )
{
    float Y = dot(RGB, vec3(  1, 2,  1 )) * 0.25;
    float Co= dot(RGB, vec3(  2, 0, -2 )) * 0.25 + ( 0.5 * 256.0/255.0 );
    float Cg= dot(RGB, vec3( -1, 2, -1 )) * 0.25 + ( 0.5 * 256.0/255.0 );
    return vec3(Y, Co, Cg);
}

vec3 YCoCgToRGB( vec3 YCoCg )
{
    float Y= YCoCg.x;
    float Co= YCoCg.y - ( 0.5 * 256.0 / 255.0 );
    float Cg= YCoCg.z - ( 0.5 * 256.0 / 255.0 );
    float R= Y + Co-Cg;
    float G= Y + Cg;
    float B= Y - Co-Cg;
    return vec3(R,G,B);
}

uniform sampler2D prev_frame: hint_screen_texture, source_color, repeat_disable, filter_nearest;
uniform float bloom_amount: hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float bloom_radius: hint_range(1.0, 30.0, .01) = 5.0;
uniform float exposure_scale: hint_range(0.001, 10.0, .01) = 0.05;

void fragment()
{
    vec2 q = UV;
     vec2  blurRadius = vec2(bloom_radius) * TEXTURE_PIXEL_SIZE.xy;
	
     vec4 total_sum = vec4(0.0);
     float NUM_SAMPLES = 20.;
     float phiOffset = hash(dot(FRAGCOORD.xy, vec2(1.12,2.251)) + TIME);
     for(float i = 0.; i < NUM_SAMPLES; i++)
     {
         vec2 r = blurRadius * i / NUM_SAMPLES;
         float phi = (i / NUM_SAMPLES + phiOffset) * 2.0 * 3.1415926;
         vec2 uv = q + vec2(sin(phi), cos(phi))*r;
         total_sum += textureLod(TEXTURE, uv, 0.0);
     }
     total_sum.xyz = mix(textureLod(TEXTURE, q, 0.0).xyz, total_sum.xyz / NUM_SAMPLES, bloom_amount);
      float exposure = exposure_scale * (0.8+0.2*sin(0.5*TIME)*sin(1.8*TIME));
      COLOR.rgb = ACES(exposure*total_sum.xyz);
     //COLOR.rgb = ACES(total_sum.xyz);
     // COLOR.rgb = textureLod(TEXTURE, q, 0.0).xyz;
     COLOR.a = 1.0;

	vec2 v = -1.0 + 2.0*q;
    // v.x *= TEXTURE_PIXEL_SIZE.x/ TEXTURE_PIXEL_SIZE.y;
    v.x *= TEXTURE_PIXEL_SIZE.y/ TEXTURE_PIXEL_SIZE.x;
    float vign = smoothstep(3.0, 0.2, length(v));
    vec2 centerToUv = q-vec2(0.5);
	vec3 aberr;
    aberr.x = textureLod(TEXTURE, vec2(0.5)+centerToUv*0.995,0.0).x; 
    aberr.y = textureLod(TEXTURE, vec2(0.5)+centerToUv*0.997, 0.0).y;
    aberr.z = textureLod(TEXTURE, vec2(0.5)+centerToUv, 0.0).z;
    //COLOR = vec4(pow(vign*aberr, vec3(0.2+1.0/2.2)), 1.0);
    // aberr = texture(TEXTURE, UV).rgb; 
    // COLOR = vec4(aberr*vign, 1.0);
}
