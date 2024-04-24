shader_type spatial;
render_mode unshaded, ambient_light_disabled,shadows_disabled, cull_disabled, depth_draw_never;
uniform sampler2D bg_texture : source_color, hint_screen_texture;
uniform sampler2D depth_texture : source_color, hint_screen_texture;
uniform sampler2D bb_texture : source_color;

void vertex() {
    vec4 pos = vec4(VERTEX, 1.0);
    POSITION = pos;
}


void fragment(){
    vec4 screen_tx = texture(bg_texture, SCREEN_UV);
    vec4 depth_tx = texture(depth_texture, SCREEN_UV);
    vec4 bb_tx = texture(bb_texture, SCREEN_UV);
    //if (depth_tx)
    ALBEDO = screen_tx.rgb;
    ALBEDO = bb_tx.rgb;
}
