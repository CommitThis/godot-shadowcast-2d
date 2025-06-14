extends Object

class_name SCShaderCompiler

enum SampleMethod {
    DIRECT   = 0, ## Sample the height directly at the pixel
    BILINEAR = 1  ## Sample the height using bilinear interpolation
}

enum HeightSample {
    BACKGROUND = 0, ## Sample the height from the background texture
    FOREGROUND = 1, ## Sample the height from the foreground texture
    BOTH       = 2  ## Sample the height from both textures
}

enum LightMethod {
    DIRECT = 0, ## Use a direct light source
    PHONG  = 1  ## Use a Phong shading model
}

enum Falloff {
    NONE        = 0, ## No falloff, light is constant
    SIGMOID     = 1, ## Sigmoid falloff, light fades out smoothly
    EXPONENTIAL = 2, ## Exponential falloff, light fades slowly at first, then quickly
    LINEAR      = 3  ## Linear falloff, light fades out linearly
}

static func sample_method_string(sample_method: SampleMethod) -> String:
    match sample_method:
        SampleMethod.DIRECT:   return "DIRECT"
        SampleMethod.BILINEAR: return "BILINEAR"
    return "UNKNOWN"

static func height_sample_string(height_sample: HeightSample) -> String:
    match height_sample:
        HeightSample.BACKGROUND: return "BACKGROUND"
        HeightSample.FOREGROUND: return "FOREGROUND"
        HeightSample.BOTH:       return "BOTH"
    return "UNKNOWN"

static func light_method_string(light_method: LightMethod) -> String:
    match light_method:
        LightMethod.DIRECT: return "DIRECT"
        LightMethod.PHONG:  return "PHONG"
    return "UNKNOWN"

static func falloff_string(falloff: Falloff) -> String:
    match falloff:
        Falloff.NONE:        return "NONE"
        Falloff.SIGMOID:     return "SIGMOID"
        Falloff.EXPONENTIAL: return "EXPONENTIAL"
        Falloff.LINEAR:      return "LINEAR"
    return "UNKNOWN"


const shader_impl = """
shader_type canvas_item;

#define FALLOFF_NONE        0
#define FALLOFF_SIGMOID     1
#define FALLOFF_EXPONENTIAL 2
#define FALLOFF_LINEAR      3

__option_height__
__option_sample__
__option_light__
__option_fade_under__
__option_falloff__

#include "res://addons/c9.shadowcast-2d/shaders/ShadowShader.gdshaderinc"
"""

static func get_shadow_shader_code(light_method: LightMethod,
                       sample_method: SampleMethod,
                       height_sample: HeightSample,
                       falloff: Falloff,
                       fade_under: float) -> String:
    var opt_sample:     String = ""
    var opt_light:      String = ""
    var opt_fade_under: String = ""
    var opt_falloff:    String = ""
    var opt_height:     String = ""
    match height_sample:
        HeightSample.BACKGROUND: opt_height = "#define HEIGHT_SAMPLE_BACKGROUND"
        HeightSample.FOREGROUND: opt_height = "#define HEIGHT_SAMPLE_FOREGROUND"
        HeightSample.BOTH:       opt_height = "#define HEIGHT_SAMPLE_BOTH"
    match falloff:
        Falloff.NONE:        opt_falloff = "#define FALLOFF_IS FALLOFF_NONE"
        Falloff.SIGMOID:     opt_falloff = "#define FALLOFF_IS FALLOFF_SIGMOID"
        Falloff.EXPONENTIAL: opt_falloff = "#define FALLOFF_IS FALLOFF_EXPONENTIAL"
        Falloff.LINEAR:      opt_falloff = "#define FALLOFF_IS FALLOFF_LINEAR"
    if light_method == LightMethod.PHONG:
        opt_light = "#define SHADE_PHONG"
    if sample_method == SampleMethod.BILINEAR:
        opt_sample = "#define SAMPLE_BILINEAR"
    if fade_under > 0.0:
        opt_fade_under = "#define FADE_UNDER %f" % fade_under

    var code = shader_impl
    code = code.replace("__option_height__", opt_height)
    code = code.replace("__option_sample__", opt_sample)
    code = code.replace("__option_light__", opt_light)
    code = code.replace("__option_fade_under__", opt_fade_under)
    code = code.replace("__option_falloff__", opt_falloff)

    return code

static func get_shadow_shader(light_method: LightMethod,
                       sample_method: SampleMethod,
                       height_sample: HeightSample,
                       falloff: Falloff,
                       fade_under: float) -> Shader:
    var shader: Shader = Shader.new()
    shader.code = get_shadow_shader_code(
            light_method,
            sample_method,
            height_sample,
            falloff,
            fade_under)

    return shader

static var background_shader: Shader = load("res://addons/c9.shadowcast-2d/shaders/BackgroundHeights.gdshader")
static var foreground_shader: Shader = load("res://addons/c9.shadowcast-2d/shaders/ForegroundHeights.gdshader")

static func get_viewport_shader(target: SCHeightSprite2D.RenderHeightTo):
    var shader: Shader = null
    match target:
        SCHeightSprite2D.RenderHeightTo.BACKGROUND: shader = background_shader
        SCHeightSprite2D.RenderHeightTo.FOREGROUND: shader = foreground_shader
    return shader
