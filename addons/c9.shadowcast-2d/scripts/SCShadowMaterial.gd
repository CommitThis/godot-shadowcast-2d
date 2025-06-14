@tool
@icon("res://addons/c9.shadowcast-2d/icons/SCShadowMaterial.svg")
extends ShaderMaterial
class_name SCShadowMaterial


# We need to have a reference to something within the tree which can be used to
# find the shadow context. Since this is a material, it is not in the tree, so
# it needs to be set by something in the tree.
var _context_node: Node = null

@export var shadow_context:  NodePath
@export var shadow_settings: SCShadowSettings = null: set = _set_shadow_settings


func _disconnect_if(shadow_settings: SCShadowSettings, name: String, target: Callable) -> void:
    if shadow_settings.is_connected(name, target):
        shadow_settings.disconnect(name, target)


func _set_shadow_settings(new_settings: SCShadowSettings) -> void:
    if shadow_settings:
        _disconnect_if(shadow_settings, 'shader_parameter_changed', _on_parameter_change)
        _disconnect_if(shadow_settings, 'compilation_settings_changed', _on_compilation_required)

    shadow_settings = new_settings

    if shadow_settings:
        _on_compilation_required()
        shadow_settings.connect('shader_parameter_changed', _on_parameter_change)
        shadow_settings.connect('compilation_settings_changed', _on_compilation_required)




func _on_parameter_change(name: String, value: Variant) -> void:
    self.set_shader_parameter(name, value)


func _on_compilation_required() -> void:
    self.shader = SCShaderCompiler.get_shadow_shader(
            shadow_settings.light_method,
            shadow_settings.sample_method,
            shadow_settings.height_sample,
            shadow_settings.falloff,
            shadow_settings.fade_under
        )
    if not self.shadow_settings:
        return
    set_shader_parameter('max_steps',       shadow_settings.max_steps)
    set_shader_parameter('ray_step_scale',  shadow_settings.ray_step_scale)
    set_shader_parameter('shadow_strength', shadow_settings.shadow_strength)
    set_shader_parameter('overscan',        shadow_settings.overscan)


func _connect_viewport_textures():
    if shadow_context.is_empty():
        return

    if not _context_node:
        return

    var subscene_node = _context_node.get_node_or_null(shadow_context)
    if not subscene_node:
        return

    if subscene_node is not SCShadowContext:
        push_warning("SCShadowMaterial: The node at the path '%s' is not an SCShadowContext." % shadow_context)
        return

    var context: SCShadowContext = subscene_node
    set_shader_parameter('foreground_heights', context.get_foreground_texture())
    set_shader_parameter('background_heights', context.get_background_texture())


func set_context_node(node: Node):
    _context_node = node
    _connect_viewport_textures()



func _validate_property(property: Dictionary):
    var valid_props = [
        "shadow_settings",
        "shadow_context"
    ]

    if property.name not in valid_props:
        property.usage = PROPERTY_USAGE_NO_EDITOR
