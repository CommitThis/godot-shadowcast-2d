uniform sampler2D foreground_heights : filter_nearest;
uniform sampler2D background_heights;

uniform float scale           = 255.0;
uniform uint  max_steps       = 200u;
uniform float ray_step_scale  = 1.0;
uniform float shadow_strength = 0.7;
uniform float overscan        = 1.0;
uniform float falloff_alpha   = 0.0;
uniform bool  disable_shadows = false;

/* The screen pixel size is available in the fragment stage but not the
   light stage. This is used to pass it from fragment to light. */
varying vec2 screen_pixel_size;
varying vec2 screen_resolution;
varying vec2 height_pixel_size;
varying vec2 height_resolution;


#define to_uv(screen_size, position) position / screen_size
#define to_pos(screen_size, uv) uv * screen_size


/* Utility macros so we don't have to define our own type, but
   still have the code look like it makes sense. */
#define above(vec) vec.r
#define below(vec) vec.g
#define height(vec) vec.b



void fragment()
{
    screen_pixel_size = SCREEN_PIXEL_SIZE;
    screen_resolution = 1.0 / SCREEN_PIXEL_SIZE;
    height_pixel_size = screen_pixel_size / overscan;
    height_resolution = screen_resolution * overscan;
}



vec2 screen_pos_to_height_pos(vec2 screen_pos) {
    vec2 overscan_offset = screen_resolution * (overscan - 1.0) * 0.5;
    return screen_pos + overscan_offset;
}

vec2 screen_uv_to_height_pos(vec2 screen_uv) {
    return screen_pos_to_height_pos(screen_uv * screen_resolution);
}

vec2 height_position_to_height_uv(vec2 height_pos) {
    return height_pos / height_resolution;
}

vec3 light_pos_to_height_pos(vec3 light_screen_pos) {
    vec2 overscan_offset = screen_resolution * (overscan - 1.0) * 0.5;
    return vec3(light_screen_pos.xy + overscan_offset, light_screen_pos.z);
}

vec3 get_step(vec3 light_dir) {
    return normalize(light_dir) * ray_step_scale;// * overscan;
}





vec4 sample_bilinear(sampler2D sampler, vec2 height_position)
{
    /* Extract fractional position (in-between pixels) */
    vec2 fractional = fract(height_position);

    /* Convert position to whole numbers */
    vec2 whole = height_position - fractional;

    /* UV position rounded to whole pixel */
    vec2 uv = height_position_to_height_uv(whole);

    /* Size of pixel with zero added for swizzle convenience */
    vec3 tex = vec3(height_pixel_size, 0.0);

    /* Texture sampling neighbours */
    vec4 top_left     = texture(sampler, uv + tex.zz);
    vec4 top_right    = texture(sampler, uv + tex.xz);
    vec4 bottom_left  = texture(sampler, uv + tex.zy);
    vec4 bottom_right = texture(sampler, uv + tex.xy);


    /* linear interpolated height between top left and right */
    vec4 top    = mix(top_left,    top_right,    fractional.x);
    vec4 bottom = mix(bottom_left, bottom_right, fractional.x);

    /* linear interpolated between top and bottom */
    return mix(top, bottom, fractional.y) * scale;
}



float sample_background_direct(vec2 height_pos)
{
    /* Note: this is sampled via nearest neighbour filtering */
    vec2 height_uv = height_position_to_height_uv(height_pos);
    return texture(background_heights, height_uv).r * scale;
}



float sample_background(vec2 screen_pos)
{
#ifdef SAMPLE_BILINEAR
    return sample_bilinear(background_heights, screen_pos).r;
#else
    return sample_background_direct(screen_pos);
#endif
}


vec2 sample_foreground(vec2 height_pos)
{
    vec2 height_uv = height_position_to_height_uv(height_pos);

    vec4 sample = texture(foreground_heights, height_uv);
    return vec2(
        sample.r * scale, // Above
        sample.g * scale  // Below
    );

}



void light()
{
    vec2  start_pos      = screen_uv_to_height_pos(SCREEN_UV);
    float start_height   = sample_background(start_pos);

    vec3  ray_start      = vec3(start_pos, start_height);
    vec3  light_dir      = LIGHT_DIRECTION;

    vec3  light_pos      = light_pos_to_height_pos(LIGHT_POSITION);
    float light_distance = length(ray_start - light_pos);

    uint steps = max_steps;
    if (!LIGHT_IS_DIRECTIONAL) {
        /* If the light is _not_ directional, adjust the light direction to take
           into account the starting height. Directional lights have a constant
           direction at any position. Also, they don't have a position so any
           calculation using that would be meaningless. */
        light_dir = normalize(light_pos - ray_start);
    }

#ifdef SHADE_PHONG
    /* TODO: Specular */
    float nDotL  = dot(NORMAL, light_dir);
    float cNdotL = max(0.0, nDotL);
    vec4  light  = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY * cNdotL, LIGHT_COLOR.a);
#else
    vec4  light  = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY, LIGHT_COLOR.a);
#endif


    vec3 ray_step = light_dir * ray_step_scale;


    /*  Can't assume unity step length as it may be scaled */
    if (!LIGHT_IS_DIRECTIONAL) {
        steps = min(max_steps, uint(light_distance / length(ray_step)));
    }


    if (disable_shadows) {
        LIGHT = light;
    }

    else {

#ifdef FADE_UNDER
        /*  This section fades out the light if it's position is underneath the
            "surface" of the height map. This is done linearly, using the fraction
            of the Z distance to the fade out height, clamped to [0, 1].

            A value of 0.0 has no fade out. A value of 100.0 will fully fade the
            light once it is over 100.0 units below the surface.

            Note that this currently does not take into account any "objects" in
            the foreground.

            Directional lights are ignored as they are infinitely far away from any
            surface, and they cannot be "below" the surface.
        */
        float height_at_light = sample_direct(LIGHT_POSITION.xy);
        if (!LIGHT_IS_DIRECTIONAL && LIGHT_POSITION.z < height_at_light) {
            float delta_z = height_at_light - LIGHT_POSITION.z;
            light *= (1.0 - clamp(delta_z / FADE_UNDER, 0.0, 1.0));
        }
#endif


        float in_shadow = 0.0;

        vec3 ray = ray_start;
        for (uint ii = 0u; ii < max_steps; ++ii) {
            ray += ray_step;

            /* A branchless alternative would be to invert `in_shadow` to
              `is_lit`,initialise it to 1.0, and then use

                is_lit *= sign(ray.z - h) * 0.5 + 0.5;

               This does depend on how likely it is the ray will be blocked and
               how many steps it will take to reach the light. The obvious
               insight is that it is always faster to to find something than it
               is to not, i.e., if the rays are more likely to be blocked than
               it may be more performant to use the branching version. Whereas
               if they rays are usually not blocked, then the branchless version
               may be faster.

                The reason this is not an option (yet) in the compiler is that
                it is more diffcult to implement when considering foreground
                where multiple tests are rquired.
            */
#if defined(HEIGHT_SAMPLE_BACKGROUND) || defined(HEIGHT_SAMPLE_BOTH)
            float h = sample_background(ray.xy);
            if (ray.z < h) {
                in_shadow = 1.0; break;
            }
#endif
#if defined(HEIGHT_SAMPLE_FOREGROUND) || defined(HEIGHT_SAMPLE_BOTH)
            /* This explicitly does direct sampling with the foreground texture
               using nearest neighbour filtering. This is because using linear
               texture filtering in the backend causes artefacts along the
               tangent between the edge of the visible sprite and the edge of
               the shadowed area. The reason for this is that the test between
               above and below heights is nebulous if they are interpolated.
               Whereas with the terrain, it's either above or below, so the test
               is clear.

               What is confusing is how the engine texture filter differs from
               the custom bilinear filter: It was implemented because rays
               sampled directly with linear texture filtering cause stair step
               artefacts. The difference may be down to how texture filtering
               works when texel positions and sizes have a 1:1 relationship
               with render target (the viewport) pixels.*/
            vec2 fg_h = sample_foreground(ray.xy);
            if (ray.z < above(fg_h) && ray.z > below(fg_h)) {
                in_shadow = 1.0; break;
            }

#endif
        }



        /*  Ratio of the length of the ray before it was blocked to the maximum
            length of the ray. We need to calculate the maximum length separately
            in the event the step size is not unit sized. For example, if we
            didn't do this, the exponential falloff would start contributing
            light as the result passes 1. */
        float max_length = length(ray_step) * float(max_steps);
        float ray_dist = length(ray - ray_start);
        float ray_ratio = ray_dist / max_length;


        /*  Check if ray has moved past the light */
        float lDotL = dot(light_dir, normalize(ray_step));
        if (!LIGHT_IS_DIRECTIONAL && lDotL < 0.0) {
            in_shadow = 0.0;
        }

        /* Check if ray has moved beyond the screen */
        vec2 height_pos = height_position_to_height_uv(ray.xy);
        if (height_pos.x < 0.0 || height_pos.x > 1.0 ||
            height_pos.y < 0.0 || height_pos.y > 1.0) {
            in_shadow = 0.0;
        }


#if FALLOFF_IS == FALLOFF_SIGMOID
        float darkness = in_shadow * shadow_strength *
            (1.0 - smoothstep(0.0, 1.0, ray_ratio));
#elif FALLOFF_IS == FALLOFF_EXPONENTIAL
        float darkness = in_shadow * shadow_strength * (1.0 - pow(ray_ratio, 6));
#elif FALLOFF_IS == FALLOFF_LINEAR
        float darkness = in_shadow * shadow_strength * (1.0 - ray_ratio);
#else /*  No falloff */
        float darkness = in_shadow * shadow_strength;
#endif

        LIGHT = vec4(light.rgb * (1.0 - darkness), light.a);
    }
}
