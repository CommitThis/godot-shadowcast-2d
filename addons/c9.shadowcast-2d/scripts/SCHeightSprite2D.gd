extends Sprite2D

class_name SCHeightSprite2D

enum RenderHeightTo {
    BACKGROUND, ## Render the heightmap to the background viewport.
    FOREGROUND  ## Render the heightmap to the foreground viewport.
}

## The texture containing the heightmap data. This texture should be in the EXR
## format and have the height data encoded in the red channel, with the green
## and blue channels unused.
##
## The range of the heightmap values, with respect to Godot's Z axis coordinates
## is to map the EXR range [0.0, 1.0] to [0, 255]. In this way, the coordinate
## system of the viewport and heightmap renderer is uniform in all dimensions.
@export var height_texture: Texture2D = null

@export var render_to: RenderHeightTo = RenderHeightTo.BACKGROUND

## The base height of the heightmap. When the heightmap is drawn to the selected
## viewport, this value is added to the height channel.
@export var base_height: float = 0.0:
    set(value):
        if value != base_height:
            base_height = value
            if self._height_sprite:
                self._height_sprite.material.set_shader_parameter("base_height", value)

var _height_sprite: Sprite2D = null
var _xform_dirty: bool = false
var _visibility_dirty: bool = false
var _context: SCShadowContext = null

var _last_transform: Transform2D = Transform2D()


func __update_transform():
    self._height_sprite.global_transform = self.global_transform
    self._height_sprite.modulate = self.modulate
    self._height_sprite.visible = self.visible
    self._last_transform = self.global_transform
    self._xform_dirty = false


func __update_visibility():
    self._height_sprite.visible = self.visible


func __free():
    if self._height_sprite:
        self._height_sprite.queue_free()


func __setup():
    self._context = SCUtilities.find_shadow_context(get_tree())
    if not self._context:
        return

    if not self.height_texture:
        return

    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = SCShaderCompiler.get_viewport_shader(self.render_to)
    material.set_shader_parameter("base_height", self.base_height)

    self._height_sprite = Sprite2D.new()
    self._height_sprite.material = material
    self._height_sprite.texture = self.height_texture

    var target: SubViewport = null
    match self.render_to:
        RenderHeightTo.BACKGROUND: target = self._context.get_background()
        RenderHeightTo.FOREGROUND: target = self._context.get_foreground()

    target.add_child(self._height_sprite)
    self._xform_dirty = true
    self._visibility_dirty = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    if self.material is SCShadowMaterial:
        (self.material as SCShadowMaterial).set_context_node(self)
    self.__setup()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    if self._height_sprite and _last_transform != self.transform:
        self.__update_transform()
    if self._height_sprite and self._visibility_dirty:
        self.__update_visibility()


func _notification(what: int) -> void:
    match what:
        NOTIFICATION_TRANSFORM_CHANGED: self._xform_dirty = true
        NOTIFICATION_VISIBILITY_CHANGED: self._visibility_dirty = true
        NOTIFICATION_EXIT_TREE: self.__free()
