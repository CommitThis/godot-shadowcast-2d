extends Object

class_name SCUtilities


static var _max_texture_size: int = 4096
static var _max_texture_size_set: bool = false

## Returns the maximum texture size supported by the rendering device.
## This is used to determine the maximum size of textures that can be created
## for heightmaps.
static func get_max_texture_size() -> int:
    if not _max_texture_size_set:
        var rendering_device = RenderingServer.get_rendering_device()
        if rendering_device:
            _max_texture_size = rendering_device.limit_get(RenderingDevice.LIMIT_MAX_TEXTURE_SIZE_2D)
        else:
            push_warning("Failed to get rendering device, using default max texture size.")
        # Don't keep trying to set the max texture size even if we fail to
        # get a rendering device.
        _max_texture_size_set = true
    return _max_texture_size


## Calculates aspect ratio correct maximum texture size. The texture is
## required to be aspect ratio correct so that, when rays are cast through the
## scene, the z-step is uniform in all (x,y) directions.
static func calculate_viewport_size(desired: Vector2):
    var max_size_1d = get_max_texture_size()
    if desired.x <= max_size_1d and desired.y <= max_size_1d:
        return desired

    var scale_by = min(
            float(max_size_1d) / desired.x,
            float(max_size_1d) / desired.y
        )
    return desired * scale_by


static func find_shadow_context(tree: SceneTree) -> SCShadowContext:
    var find_recursive = true
    var find_owned = false
    return tree.root.find_child(
            'SCShadowContext',
            find_recursive,
            find_owned)


