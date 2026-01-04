extends Node3D
class_name InteractableItem

@export var ItemHighlightMesh : MeshInstance3D


func GainFocus():
	if (ItemHighlightMesh != null):
		ItemHighlightMesh.visible = true
	else:
		return

func LoseFocus():
	if (ItemHighlightMesh != null):
		ItemHighlightMesh.visible = false
	else:
		return
	
