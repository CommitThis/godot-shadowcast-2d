@tool
extends EditorPlugin

func _enter_tree() -> void:
    add_custom_type('SCHeightSprite2D', 'Sprite2D',
            preload('scripts/SCHeightSprite2D.gd'),
            preload('icons/SCHeightSprite2D.svg'))

    add_custom_type('SCShadowMaterial', 'ShaderMaterial',
            preload('scripts/SCShadowMaterial.gd'),
            preload('icons/SCShadowMaterial.svg'))

    add_custom_type('SCShadowSettings', 'Resource',
            preload('scripts/SCShadowSettings.gd'),
            preload('icons/SCShadowSettings.svg'))


func _exit_tree() -> void:
    remove_custom_type('SCHeightSprite2D')
    remove_custom_type('SCShadowMaterial')
    remove_custom_type('SCShadowSettings')
