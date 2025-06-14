extends Node2D


var resize_timer: Timer
var pending_resize: bool = false

func _set_shadow_size():
    var ctx: SCShadowContext = SCUtilities.find_shadow_context(get_tree())
    if not ctx:
        return
    #print(get_tree().root.size)
    ctx.resolution = get_tree().root.size



func _resize_timeout() -> void:
    print("Island: Resize timeout reached, updating shadow size.")
    if not pending_resize:
        return
    pending_resize = false
    _set_shadow_size()


func _on_resize() -> void:
    print("Island: Resize detected, scheduling shadow size update.")
    pending_resize = true
    resize_timer.start()



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    var ctx: SCShadowContext = SCUtilities.find_shadow_context(get_tree())
    if not ctx:
        print("Island: No shadow context found, cannot proceed.")
        return

    $Camera2D/BackgroundContents.texture = ctx.get_background_texture()
    $Camera2D/BackgroundContents.scale = Vector2(0.2, 0.2)

    $Camera2D/ForegroundContents.texture = ctx.get_foreground_texture()
    $Camera2D/ForegroundContents.scale = Vector2(0.2, 0.2)

    resize_timer = Timer.new()
    resize_timer.wait_time = 0.1
    resize_timer.one_shot = true
    resize_timer.connect("timeout", _resize_timeout)
    add_child(resize_timer)


    get_tree().root.size_changed.connect(_on_resize)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
    var light: PointLight2D = $PointLight2D
    var camera: Camera2D = $Camera2D
    var centre: Vector2 = Vector2(576, 324)
    var smiley: Sprite2D = $Smiley

    var t = Time.get_ticks_msec() / 1000.0

    var f_s = 0.08
    var w_s = 2 * PI * f_s
    var A_s = 200
    var smiley_offset = Vector2(
        cos(w_s * t) * A_s,
        sin(w_s * t) * A_s
    )

    smiley.position = centre + smiley_offset
    smiley.rotation = -w_s * t


    var f_l = 0.05
    var w_l = 2 * PI * f_l
    var A_l  = 400
    var light_offset    = Vector2(
            sin(w_l * t) * A_l,
            cos(w_l * t) * A_l
            # 0.0
            )

    light.position = centre + light_offset

    var A_c = 100
    var f_c = 0.02
    var w_c = 2 * PI * f_c
    var camera_offset = Vector2(
        cos(w_c * t) * A_c,
        sin(w_c * t) * A_c
    )
    camera.position = centre + camera_offset
