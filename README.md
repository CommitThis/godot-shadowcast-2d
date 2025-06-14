# Godot Shadow Cast 2D

![Demo Capture](demo.gif)

This Godot plugin implements shadow casting for 2D projects using a heightmap
traversing ray caster. It features

* Screen space shadow casting to `PointLight2D`s and `DirectionalLight`s with
  unity stepping;
* Support "background" and "foreground" shadows. Foreground shadows can overhang
  the background;
* "Overscanning" such that shadows can be cast from outside the visible range of
  the main scene;
* Flexible configuration options.

## Acknowledgements

Special thanks to [Barney Codes](https://www.youtube.com/@BarneyCodes/videos) on
YouTube. His videos[^v1][^v2][^v3] and sketches[^d1][^d2] on were instrumental in
getting the finer detail correct, and has some of the clearest explanations of
step-based ray casting. He's also kindly allowed me to use a generated height
map and texture for an island from his sketches used in the demo.

[^v1]: https://www.youtube.com/watch?v=bMTeCqNkId8
[^v2]: https://www.youtube.com/watch?v=6bnFfE82AJg
[^v3]: https://www.youtube.com/watch?v=fZh2p0odPyQ
[^d1]: https://editor.p5js.org/BarneyCodes/sketches/brfZ0NNpZ
[^d2]: https://editor.p5js.org/BarneyCodes/sketches/rEmwEye8F

## Requirements

Heightmap textures should be linear colour space and in the EXR format. The
reason for using EXR is so that we can worry less about the range of values in
the heightmap -- height values would otherwise have to be limited by some
scaling factor and range, whereas EXR can accomodate any value representable by
floating point numbers.

> Note: negative numbers have not been tested


## Quick Start

1. Instantiate the `SCShadowContext` scene as a child of the main scene.
   1. Set it's camera leader and resolution properties.
2. For generating height data, add `SCHeightSprite2D`s to your scene, selecting
   an appropriate height map texture.
3. To receive shadows
   1.  Add the `SCShadowMaterial` to desired objects;
   2.  To this material, set the node path to the `SCShadowContext` instance in
       the "Shadow Context" property
   3.  To this material, add an instance of `SCShadowSettings` in the "Shadow
       Settings" property



## How it Works

The basic concept of this plugin is to render heightmap data to a texture that
can then be read by a shader that samples height values along a ray that
is cast from an origin pixel on an object towards some light object.


### The Shadow Context (`SCShadowContext`)

This is a scene, intended to be used as a sub-scene, which holds sub-viewports
that heightmap data is rendered to and later exposed to a shader. It's also
responsible for synchronising the main viewport camera so that the textures are
always representative of what's occurring in the main scene.

The two viewports are for background and foreground data. One way of thinking
about these is that the background could be for terrain data, and the foreground
could be for objects that may "float" above it. The height data is treated
differently based on the target viewport; this will be covered in the section
regarding the `SCHeightSprite2D` class.


Options:

* `Resolution`: The internal resolution of the viewport. See note for a big
  caveat!
* `Overscan`: The factor by which to overdraw/scale the heightmap viewport.
  Values larger than `1.0` will effectively zoom out by this factor, allowing
  for the drawing of height data beyond that which is visible in the main
  screen. This **must** be set to the same value as what's supplied to the
  shadow shader.
* `Camera Leader`. The camera with which to synchronise so that the heightmap
  data always follows what is on the screen.

The viewports:
* Have 3D disabled
* Have HDR 2D enabled (for EXR format heightmaps)
* Has a camera attached which is synchronised against the camera leader, to which:
* a black texture is attached so that the viewport is always cleared to
  black every frame



> Note: The setting of the resolution is best kept as the same as the main
>       viewport. You might think you can reduce the viewport resolution to
>       get a smaller heightmap texture, and consequently get shadows with less
>       rays at the cost of fidelity, but unfortunately that's not how it
>       currently works. The shadow receiving shader only uses the size of the
>       main screen and the overscan factor, mapping the screen UV to the
>       viewport UV. The effect of this is that, while the is a guaranteed
>       relationship between the two textues (any given UV in the screen will
>       map to the correct position in the heightmap regardless of it's sixe),
>       rays will effectively be traversing in the main screen's coordinate
>       system, and therefore rays will take the same amount of steps but
>       traversing less texels/pixels in the viewport.



### The Height Sprite (`SCHeightSprite2D`)

This is an extension of the standard `Sprite2D` Godot class and can be treated
likewise. How it differs is that it exposes some properties for rendering
height data to the shadow context. It has the following options:

* `Height Texture`: This should be a plain texture representing the sprite's
  height data. This should be the same size as the sprite's texture as no
  scaling is performed.
* `Render To`: Whether to render the height data to the background or foreground
  viewports.
* `Base Height`: A constant which is added to the heightmap data when drawn to
  the heightmap viewport, effectively "raising" the height.


When the sprite enters the tree, it will search for the shadow context and
add to the relevant viewport a `Sprite2D` that contains the height data. This
"nested" sprite is setup with a material and shader for rendering.

When the sprite exits the tree, this sprite will be removed from the target
viewport.

> Note: The target can't be changed at runtime presently.


#### Texture Formats

As explained earlier, the height data should be in EXR format. Although you may
get away with something like a PNG, I just can't vouch for the results.

However, the texture data is different depending on the target viewport. If
rendering to the backgorund, the texture should be in the usual format:
RGBA, with the red channel containing the height data, and usually with an
alpha of all ones.

When rendering to the foreground, the red channel is the same, and the green
channel contains the absolute height "below". The reason for using an absolute
value for "below" is so that we don't have to worry about negative colour, which
can apparentely cause some issues with various tooling.

In both cases, the unit values are normalised to (`1.0 / 255.0`), i.e., a value
of `1.0` represents `255` units in the Z-plane.


### The Shadow Material (`SCShadowMaterial`)

This is a custom material that extends from Godot's `ShaderMaterial`. It is
pretty simple:
* It is a place where shadow settings can be stored or referenced;
* Is responsible for compiling the shader and handling parameter changes based
  on signals from the settings object.
* Is responsible for hooking up the heightmap viewports to the respective
  shader parameters.

Unfortunately, the generated shader parameters are exposed by the editor, so if
using an `SCShadowSettings` instance, the proeprties will be editable in two
places for the same materials. It does not seem possible for this to be hidden,
but might be addressable if the class was written in C++... possibly. Basically,
we can't properly override `_get_property_list()` which provides the editor
with the list of shader parameters.



### The Shadow Settings (`SCShadowSettings`)

The shadow settings resource controls all the settings related to rendering
shadows. Its a an object in it's own right so that it can be shared across
multiple materials, providing at least some consistency across different
shadow receiving objects.

There are two groups of options: those that control compilation settings, and
those that are actual shader parameters. The reason for having compilation
settings is that some of the operations could be expensive. For example, you
may not want to cast shadows from the foreground, which would take up an
additional sample and branch per step per pixel. Having this as a compilation
parameter means that you wont pay for what you don't use.

The downside of this approach is that the shadow casting shader is not
accessible as a standalone shader resource.

#### Compilation Settings

* `sample_method`: Use direct or bilinear texture sampling.
* `height_sample`: Which height viewport(s) to sample.
* `light_method`: Render unshaded with shadows, or with a basic Phong implementation.
* `fade_under`: Interval within which to fade light if the source is below the heightmap.
* `falloff`: Algorithm which fades out the shadow strength based on the distance to it's occluder.

#### Runtime Settings

* `max_steps`:  Maximum number of steps to take before ray is expired.
* `ray_step_scale`:  Scale the ray steps size.
* `shadow_strength`:  Allow detail from Phong shading to be visible even in shadow.
* `overscan`:  Factor by which height data is overscanned/overdrawn.
* `disable_shadows`:  Disable shadows.


## Getting Normal Sprites to Receive Shadows

The advantage of having a custom material is that ordinary objects can receive
shadows too! There is, however, a little setup required to achieve this.

First, you apply the `SCShadowMaterial` to the object, and set it up as usual:

1. Set the path to the `SCShadowContext`;
2. Load or create an instance of `SCShadowSettings`, as usual.

Then, you need to add a snippet of code to the objects `_ready()` function:

```gdscript
func _ready() -> void:
    if self.material is not SCShadowMaterial:
        return

    var mat: SCShadowMaterial = self.material
    mat.set_context_node(self)
```

Ultimately, this is because the shadow shader reads from the viewports in
the `SCShadowContext`, but being controlled by a material, which aren't
technically in the tree (if you ignore composition), the context needs to be
found. When you set up the material with the shadow context parameter, you
aren't setting it's instance, you are setting _it's path in the tree_. This is
so it can be looked up later. And in order to look it up, you need an object in
the tree. `set_context_node` gives the material such an object (the caller),
which can then be used to find the actual shadow context.




## Tools

### `heightmap_to_exr.py`

This script converts either greyscale or RGBA (with the red channel containing
heightmap data) to the EXR format. It requires that the following be installed:

* `OpenEXR`
* `numpy`
* `opencv-python`
* `pillow`

#### Usage

```
usage: heightmap_to_exr.py [-h] --infile INFILE
        [--outdir OUTDIR]
        [--srgb]
        [--scale SCALE]
        [--floor FLOOR]
        [--normals]
        [--normal-sobel-ksize N]
        [--normal-full-z-range]
        [--normal-use-scharr]
```

#### Arguments

| Argument                | Parameter? | Description                                                                                                     |
|-------------------------|------------|-----------------------------------------------------------------------------------------------------------------|
| `--infile`              | `Path`     | Path to the input image, either greyscale or RGBA.                                                              |
| `--outdir`              | `Path`     | Directory to save the output files. Default is the current directory.                                           |
| `--srgb`                | `bool`     | Convert the image from sRGB before processing.                                                                  |
| `--scale`               | `float`    | Scale factor for the heightmap. Height values are multiplied by this value in the output image. Default is 1.0. |
| `--floor`               | `float`    | Floor value for the heightmap. Default is 0.0.                                                                  |
| `--normals`             | flag       | Generate a normal map from the heightmap.                                                                       |
| `--normal-sobel-ksize`  | `int`      | Sobel kernel size for normal map generation. Default is 3.                                                      |
| `--normal-full-z-range` | flag       | Generate normal map with full Z range ([-1, 1] instead of [0, 1]).                                              |
| `--normal-use-scharr`   | flag       | Use Scharr filter instead of Sobel for normal map generation.                                                   |



## Possible future features:

* Auto detecting of main camera
* Auto detection of main resolution
* While I haven't looked into it, if the shader preprocessor is anything like
  the C pre-processor, it may be possible to set `#ifndef` defaults so the
  shader is available as a resource in it's own right. The question would then
  be what defaults to use? An alternative would be to create shaders that set
  fixed defines and then include the shader body.
* Proper scaling for camera zoom (see known issue).
* The foreground raycast could be adapted to march _through_ textures
  representing things like clouds. Would probably need to include additional
  information for density, for which the blue texture channel could be used.
* It might also be worthwhile to allow `SCHeightSprite2D` textures to render to
  the height viewport only. This follows from the previous point on clouds: it
  might be nice to have clouds casting shadows without them actually being
  visible in the main viewport.

## Known Issues

* A camera zoom other than `(1.0, 1.0)` will have different apparent shadow
  lengths. This is because the rays are cast in screen space, and the shader
  makes no accomodation for the zoom. For example, if zoomed out to
  `(0.5, 0.5)`, horizontal rays will still step length 1 pixels per step. A
  workaround would be to update the `ray_step_scale` shader parameter (although
  this is a scalar and not adequate for non "square" zooms).
