vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texturecolor = Texel(texture, texture_coords);
    vec4 graytexture = texturecolor.rrra;
    vec4 gray = color.rrra;
    return graytexture * gray;
}