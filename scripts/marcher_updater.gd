@tool
extends MeshInstance3D

# TODO: Set to 2d without sampling for best performance.
# var tex1: ViewportTexture = ViewportTexture.new()
# var tex2: ViewportTexture = ViewportTexture.new()
# var current_tex: ViewportTexture = tex1
# var prev_tex: ViewportTexture = tex2
@export var light: DirectionalLight3D

var material: ShaderMaterial
func _ready() -> void:
	material = self.get_active_material(0)
	# tex1.viewport_path = get_viewport().get_path()
	# tex2.viewport_path = get_viewport().get_path()


func _process(_delta: float) -> void:
	pass
	# material.set_shader_parameter("sun_direction", light.global_transform.basis.z)
	# material.set_shader_parameter("sun_direction", light.rotation)

	# var temp = current_tex
	# current_tex = prev_tex
	# prev_tex = temp

	# Set the previous texture as a uniform in your shader.
	# material.set_shader_parameter("prev_frame", prev_tex)

# Create lookup table texture? use simple 1D gradient as approximation?
# // Define the size of the lookup table
# const int TABLE_SIZE = 1000;
#
# # // Create the lookup table
# float lookupTable[TABLE_SIZE];
#
# # // Fill the lookup table with precomputed values
# for (int i = 0; i < TABLE_SIZE; ++i) {
#     float height01 = (float)i / (TABLE_SIZE - 1);
#     lookupTable[i] = exp(-height01 * densityFalloff) * (1 - height01);
# }

