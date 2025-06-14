extends Object

class_name SCCameraSynchroniser

var source: Camera2D = null
var targets: Dictionary = {}
var scale: Vector2 = Vector2(1, 1)


func set_source_camera(camera: Camera2D):
    self.source = camera
    
func set_scale(new_scale: Vector2):
    self.scale = new_scale

func add_target(camera: Camera2D):
    self.targets[camera.get_instance_id()] = camera

func remove_target(camera: Camera2D):
    self.targets.erase(camera.get_instance_id())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func sync() -> void:
    if not self.source:
        return
    for camera_id in self.targets:
        var camera = self.targets[camera_id]
        camera.global_position = self.source.global_position
        camera.zoom            = self.source.zoom * self.scale
        camera.rotation        = self.source.rotation
        camera.offset          = self.source.offset
