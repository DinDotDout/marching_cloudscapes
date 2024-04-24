@tool
extends MeshInstance3D

# TODO: Set to 2d without sampling for best performance.
var tex1: ViewportTexture = ViewportTexture.new()
var tex2: ViewportTexture = ViewportTexture.new()
var current_tex: ViewportTexture = tex1
var prev_tex: ViewportTexture = tex2
var material: ShaderMaterial
func _ready() -> void:
	material = self.get_surface_override_material(0)
	tex1.viewport_path = get_viewport().get_path()
	tex2.viewport_path = get_viewport().get_path()

	if self.mesh != null:
		return

	var existing_verts: Array = self.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if existing_verts.size() >= 3:
		return

	var verts: PackedVector3Array = PackedVector3Array()
	var _ok: bool = verts.append(Vector3(-1.0, -1.0, 0.0))
	_ok = verts.append(Vector3(-1.0, 3.0, 0.0))
	_ok = verts.append(Vector3(3.0, -1.0, 0.0))

	var mesh_array: Array = []
	_ok = mesh_array.resize(Mesh.ARRAY_MAX)  #required size for ArrayMesh Array
	mesh_array[Mesh.ARRAY_VERTEX] = verts  #position of vertex array in ArrayMesh Array
	self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)


func _process(_delta):
	# Swap the textures.
	var temp = current_tex
	current_tex = prev_tex
	prev_tex = temp

	# Set the previous texture as a uniform in your shader.
	material.set_shader_parameter("prev_frame", prev_tex)

