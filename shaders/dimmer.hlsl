vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texturecolor = Texel(texture, texture_coords);
    vec4 graytexture = texturecolor.rrra;
    float c = (color.r + color.g + color.b)/3.0;
    vec4 gray = vec4(c, c, c, color.a);
    return graytexture * gray;
}