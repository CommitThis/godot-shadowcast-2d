
@icon("res://addons/c9.shadowcast-2d/icons/SCShadowContext.svg")
extends Node2D

class_name SCShadowContext

## The resolution of the origin viewport. This should match, at the very least,
## the aspect ratio of the main viewport. Once changed, the shadow heightmap
## render area will be resized and scaled appropriately. Try not to change this
## to frequently, not only is this slow, but if too frequent, can actually cause
## the engine to crash.
@export var resolution: Vector2 = Vector2(0, 0): set = _set_resolution

## The amount by which to "overscan" the target viewports.
## This can be used to render heightmap data "beyond" the bounds of the main
## viewport, allowing shadows to be generated from heights outside the viewable
## area. This must match the overscan set in the shader.
@export_range(1.0, 2.0) var overscan: float = 1.0: set = _set_overscan

## The camera that will be used to determine what part of the heightmap
## to render. This is used to synchronise cameras for the foreground and
## background heightmaps, so that they are rendering the heightmap data at the
## the same scale and position of the main camera.
@export var camera_leader: Camera2D = null


var camera_sync: SCCameraSynchroniser = SCCameraSynchroniser.new()
var relative_scale: Vector2 = Vector2(0, 0)


@onready var clear_background: Sprite2D = $SCBackgroundHeights/Camera2D/ClearColour
@onready var clear_foreground: Sprite2D = $SCForegroundHeights/Camera2D/ClearColour


func _set_overscan(new_overscan: float):
    print("Setting overscan to: ", new_overscan)
    overscan = new_overscan
    call_deferred("_setup_heightmap")

func _set_resolution(new_resolution):
    print("Setting resolution to: ", new_resolution)
    resolution = new_resolution
    if not clear_background:
        return
    if not clear_foreground:
        return
    _setup_heightmap()



func get_background():
    return $SCBackgroundHeights

func get_foreground():
    return $SCForegroundHeights

func get_background_texture():
    return $SCBackgroundHeights.get_texture()

func get_foreground_texture():
    return $SCForegroundHeights.get_texture()





func _setup_heightmap():
    if not camera_leader:
        print("No camera leader set, cannot setup heightmap.")
        return
    var camera_zoom           = camera_leader.zoom
    var resolution_origin     = resolution
    var resolution_desired    = resolution * overscan
    var resolution_calculated = SCUtilities.calculate_viewport_size(resolution_desired)
    var viewport_size         = get_viewport().get_visible_rect().size
    var camera_scale          = (resolution_calculated / viewport_size) / overscan
    var clear_size            = (resolution_calculated / camera_scale) / camera_zoom

    $SCForegroundHeights.size = resolution_calculated
    $SCBackgroundHeights.size = resolution_calculated

    clear_background.scale = clear_size
    clear_foreground.scale = clear_size

    camera_sync.set_scale(camera_scale)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    self._setup_heightmap()
    self.camera_sync.set_source_camera(self.camera_leader)
    self.camera_sync.add_target($SCBackgroundHeights/Camera2D)
    self.camera_sync.add_target($SCForegroundHeights/Camera2D)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    self.camera_sync.sync()
