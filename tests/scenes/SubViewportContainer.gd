extends Node; 

var viewport : Viewport
var sprite : Sprite2D
var textures : Array

var current_frame : int = 0

# var image = viewport_texture.get_data()
var prev_vp_texture
var vp_texture
# Called when the node enters the scene tree for the first time.
var image_texture = ImageTexture.new()
func _ready():
	vp_texture = self.get_viewport().get_texture()
	self.material.set_shader_parameter("prev_frame", vp_texture)

	# print(vp_texture)
	# image = vp_texture.get_data()
	# image_texture.create_from_image(image)
	pass

# Now you can pass image_texture to your shader as a uniform
# For example, if you have a Sprite with a shader, you can do:
# $Sprite.material.set_shader_param("prev_frame", image_texture)
# viewport = get_node("Viewport")  # Replace with the path to your Viewport node
# sprite = get_node("Viewport/Sprite")  # Replace with the path to your Sprite node

# textures = [ViewportTexture.new(), ViewportTexture.new()]
# for i in range(2):
#     textures[i].viewport_path = NodePath("Viewport")



func _process(delta):
	# self.material.set_shader_parameter("prev_frame", vp_texture)
	# vp_texture = self.get_viewport().get_texture()
	# image = viewport_texture.get_data()
	# image_texture.create_from_image(image)
	# current_frame = (current_frame + 1) % 2
	# sprite.texture = textures[current_frame]
	# self.material.set_shader_param("prev_frame", textures[(current_frame + 1) % 2])
	# prev_vp_texture = vp_texture.duplicate(false)
	pass
