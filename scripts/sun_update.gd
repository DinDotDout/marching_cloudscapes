@tool
extends MeshInstance3D
@export var sun: Node3D
var material: ShaderMaterial

# TODO: Set to 2d without sampling for best performance.
var tex1: ViewportTexture = ViewportTexture.new()
var tex2: ViewportTexture = ViewportTexture.new()
var current_tex: ViewportTexture = tex1
var prev_tex: ViewportTexture = tex2


func _ready():
	material = self.get_surface_override_material(0)
	tex1.viewport_path = get_viewport().get_path()
	tex2.viewport_path = get_viewport().get_path()
	# print(tex1.viewport_path)
	# print(tex2.viewport_path)
	# print(tex1)
	# print(tex2)


func _process(_delta):
	material.set_shader_parameter("sunPosition", sun.global_transform.origin)
	material.set_shader_parameter("boxSize", self.scale)

	# Swap the textures.
	var temp = current_tex
	current_tex = prev_tex
	prev_tex = temp

	# Set the previous texture as a uniform in your shader.

	material.set_shader_parameter("prev_frame", prev_tex)
