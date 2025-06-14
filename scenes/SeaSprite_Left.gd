extends Sprite2D

func _ready() -> void:
    if self.material is not SCShadowMaterial:
        return

    var mat: SCShadowMaterial = self.material
    mat.set_context_node(self)