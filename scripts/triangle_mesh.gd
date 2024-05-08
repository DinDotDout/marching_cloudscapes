@tool
extends MeshInstance3D


func _ready() -> void:
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
