@tool
class_name SCShadowSettings extends Resource

const HeightSample = SCShaderCompiler.HeightSample
const SampleMethod = SCShaderCompiler.SampleMethod
const LightMethod  = SCShaderCompiler.LightMethod
const Falloff      = SCShaderCompiler.Falloff


@export_group("Shader Compilation Settings")
@export var sample_method: SampleMethod = SampleMethod.BILINEAR:   set = _set_sample_method
@export var height_sample: HeightSample = HeightSample.BACKGROUND: set = _set_height_sample
@export var light_method:  LightMethod  = LightMethod.PHONG:       set = _set_light_method
## Whether to fade the light if the light source is below the heightmap. The
## value is the number of Z units below the heightmap at which the no light
## should be "emitted". A value of 0.0 or less will disable fading.
@export var fade_under:    float        = 0.0:                     set = _set_fade_under
@export var falloff:       Falloff      = Falloff.SIGMOID:         set = _set_falloff


@export_group("Shader Parameters")
## The maximum number of steps the ray can take before it is expired.
@export var max_steps:       int   = 200: set = _set_max_steps

## The ray step scale is a multiplier applied to the ray step size. This allows
## rays to have a larger step size allowing them to travel further for a given
## number of steps. This is useful for performance, but can lead to artifacts:
##
## * If the step is too large, it may "pass through" heightmap features; and,
## * At larger steps sizes, shadows may appear to be "ripple" towards the end
##   of the shadowed area.
@export var ray_step_scale:  float = 1.0: set = _set_ray_step_scale

## The strength of the shadow. This is a multiplier applied to the shadow
## intensity, which is calculated based on the heightmap data. Values less than
## 1.0 will allow detail from the Phong calculation to show through and
## therefore will appear to be be less flat.
@export_range(0.0, 1.0) var shadow_strength: float = 0.7: set = _set_shadow_strength

## The amount by which to "overscan" the target viewports. This renders
## heaightmap data "beyond" the bounds of the main viewport, allowing shadows
## to be generated from heights outside the viewable area.
@export_range(1.0, 2.0, 0.05) var overscan: float = 1.0: set = _set_overscan

@export var disable_shadows: bool = false: set = _set_disable_shadows


var falloff_alpha: float = -1.0



signal shader_parameter_changed(name: String, value: Variant)
signal compilation_settings_changed


# func get_effectivefalloff_alpha() -> float:
#     if falloff_alpha >= 0.0:
#         return falloff_alpha
#     return get_default_alpha_for_falloff()

# func get_default_alpha_for_falloff():
#     match falloff:
#         Falloff.SIGMOID:
#             return 0.5
#         Falloff.LINEAR:
#             return 1.0
#         Falloff.EXPONENTIAL:
#             return 6.0
#         _:
#             return 0.0


func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []

    # var alpha_hint = "Default for %s: %.1f" % [
    #     Falloff.keys()[falloff],
    #     get_default_alpha_for_falloff()
    # ]
    # properties.append({
    #     "name": "falloff_alpha",
    #     "type": TYPE_FLOAT,
    #     "usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
    #     "hint": PROPERTY_HINT_RANGE,
    #     "hint_string": "-1,10,0.1,suffix: (" + alpha_hint + ")"
    # })
    return properties



func emit_compilation_settings_changed() -> void:
    compilation_settings_changed.emit()

func emit_shader_parameter_changed(name: String, value: Variant) -> void:
    shader_parameter_changed.emit(name, value)

func _set_sample_method(new_sample_method: SampleMethod) -> void:
    if sample_method != new_sample_method:
        sample_method = new_sample_method
        emit_compilation_settings_changed()

func _set_height_sample(new_height_sample: HeightSample) -> void:
    if height_sample != new_height_sample:
        height_sample = new_height_sample
        emit_compilation_settings_changed()

func _set_light_method(new_light_method: LightMethod) -> void:
    if light_method != new_light_method:
        light_method = new_light_method
        emit_compilation_settings_changed()

func _set_falloff(new_falloff: Falloff) -> void:
    if falloff != new_falloff:
        falloff = new_falloff
        if falloff_alpha < 0.0:
            falloff_alpha = -1.0
        emit_compilation_settings_changed()
        notify_property_list_changed()


func _set_fade_under(new_fade_under: float) -> void:
    if fade_under != new_fade_under:
        fade_under = new_fade_under
        emit_compilation_settings_changed()


func _set_max_steps(new_max_steps: int) -> void:
    if max_steps != new_max_steps:
        max_steps = new_max_steps
        emit_shader_parameter_changed("max_steps", new_max_steps)

func _set_ray_step_scale(new_ray_step_scale: float) -> void:
    if ray_step_scale != new_ray_step_scale:
        ray_step_scale = new_ray_step_scale
        emit_shader_parameter_changed("ray_step_scale", new_ray_step_scale)

func _set_shadow_strength(new_shadow_strength: float) -> void:
    if shadow_strength != new_shadow_strength:
        shadow_strength = new_shadow_strength
        emit_shader_parameter_changed("shadow_strength", new_shadow_strength)

func _set_overscan(new_overscan: float) -> void:
    if overscan != new_overscan:
        overscan = new_overscan
        emit_shader_parameter_changed("overscan", new_overscan)


func _set_disable_shadows(new_disable_shadows: bool) -> void:
    if disable_shadows != new_disable_shadows:
        disable_shadows = new_disable_shadows
        emit_shader_parameter_changed("disable_shadows", disable_shadows)