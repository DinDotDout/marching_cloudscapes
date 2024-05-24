shader_type canvas_item;
render_mode unshaded;


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
uniform float mixval: hint_range(0.0, 1.0, 0.1) = 0.95;
uniform int samples: hint_range(0, 20, 1) = 8;
void fragment()
{
    vec2 q = UV;
    vec3 new = RGBToYCoCg(textureLod(TEXTURE, q, 0.0).xyz);
    vec3 history = RGBToYCoCg(textureLod(prev_frame, q, 0.0).xyz);
    vec3 colorAvg = new;
    vec3 colorVar = new*new;

    // Marco Salvi's Implementation (by Chris Wyman)
    for(int i = 0; i < samples; i++)
    {
        vec2 offset = vec2(offsets[i]);
        vec3 fetch = RGBToYCoCg(texelFetch(TEXTURE, ivec2(FRAGCOORD.xy)+ivec2(offset), 0).xyz);
        colorAvg += fetch;
        colorVar += fetch*fetch;
    }
    colorAvg /= float(samples)+1.0;
    colorVar /= float(samples)+1.0;
    float gColorBoxSigma = 0.95;
    vec3 sigma = sqrt(max(vec3(0.0), colorVar - colorAvg*colorAvg));
    vec3 colorMin = colorAvg - gColorBoxSigma * sigma;
    vec3 colorMax = colorAvg + gColorBoxSigma * sigma;
    history = clamp(history, colorMin, colorMax);
    COLOR.rgb = YCoCgToRGB(mix(new, history, mixval));
}
