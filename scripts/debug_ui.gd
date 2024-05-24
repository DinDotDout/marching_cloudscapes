extends Control

@export var scene: Node
var terrain

var clouds_material: ShaderMaterial
var thresh : HBoxContainer
var hbox_slider1: HBoxContainer
var hbox_slider2: HBoxContainer
var hide_terrain: Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	thresh = %thresh
	hbox_slider1 = %min_steps
	hbox_slider2 = %max_steps
	hide_terrain = %showing_terrain

	var _ok: int = thresh.get_child(0).value_changed.connect(_on_slider3)
	_ok = hbox_slider1.get_child(0).value_changed.connect(_on_slider1)
	_ok = hbox_slider2.get_child(0).value_changed.connect(_on_slider2)
	_ok = hide_terrain.toggled.connect(_on_button_pressed_terrain)


	if not scene:
		return
	clouds_material = scene.find_child("clouds").get_active_material(0)
	terrain = scene.find_child("Terrain3D")

	# Set initial values
	thresh.get_child(0).value = clouds_material.get_shader_parameter("fast_march_transmitance_thresh")
	hbox_slider1.get_child(0).value = clouds_material.get_shader_parameter("min_marching_steps")
	hbox_slider2.get_child(0).value = clouds_material.get_shader_parameter("max_marching_steps")
	if not terrain:
		hide_terrain.visible = false

		return
	hide_terrain.button_pressed = terrain.visible


func _on_button_pressed_terrain(state: bool) -> void:
	var text = "showing terrain" if state else "hidding terrain"
	hide_terrain.set_text(text)
	if terrain:
		terrain.visible = state

func _on_slider3(value: float) -> void:
	thresh.get_child(1).set_text("threshold "+str(value))
	if clouds_material:
		clouds_material.set_shader_parameter("fast_march_transmitance_thresh", value)

func _on_slider1(value: float) -> void:
	hbox_slider1.get_child(1).set_text("min steps "+str(value))
	if clouds_material:
		clouds_material.set_shader_parameter("min_marching_steps", value)

func _on_slider2(value: float) -> void:
	hbox_slider2.get_child(1).set_text("max steps "+ str(value))
	if clouds_material:
		clouds_material.set_shader_parameter("max_marching_steps", value)
