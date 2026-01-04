@tool
extends VoxelLodTerrain

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var stone = load("res://assets/textures/Stone.png")
	var grass = load("res://assets/textures/Grass.png")
	var wood = load("res://assets/textures/Wood.png")
	
	var texture_2d_array = Texture2DArray.new()
	texture_2d_array.create_from_images([grass, stone, wood])
	
	material.set("shader_parameter/u_texture_array", texture_2d_array)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
