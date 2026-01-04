extends Control
class_name InventorySlot

signal OnItemEquiped(SlotID)
signal OnItemDropped(fromSlotID: int, toSlotID: int, data: Dictionary)


@export var EquippedHighlight : Panel
@export var IconSlot : TextureRect
@export var HotbarSize := 8
@export var StackLabel: Label
@export var SelectedHighlight: Panel

func IsShiftPressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

var InventorySlotID : int = -1
var SlotFilled : bool = false

var SlotData : ItemData

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if (event.button_index == MOUSE_BUTTON_LEFT and event.double_click):
			OnItemEquiped.emit(InventorySlotID)

func FillSlot(data: ItemData, equipped: bool):
	SlotData = data
	EquippedHighlight.visible = equipped

	if SlotData != null:
		SlotFilled = true
		IconSlot.texture = SlotData.Icon
		UpdateStackLabel()
	else:
		SlotFilled = false
		IconSlot.texture = null
		StackLabel.visible = false
		
func UpdateStackLabel():
	if SlotData != null and SlotData.StackSize > 1:
		StackLabel.text = str(SlotData.StackSize)
		StackLabel.visible = true
	else:
		StackLabel.visible = false


func _get_drag_data(at_position: Vector2) -> Variant:
	if not SlotFilled:
		return null

	var amount := SlotData.StackSize
	var split := false

	if IsShiftPressed() and SlotData.StackSize > 1:
		amount = SlotData.StackSize / 2
		split = true

	var preview := TextureRect.new()
	preview.texture = IconSlot.texture
	preview.size = IconSlot.size
	set_drag_preview(preview)

	return {
		"Type": "Item",
		"ID": InventorySlotID,
		"Amount": amount,
		"Split": split
	}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY \
		and data.has("Type") \
		and data["Type"] == "Item"
 
	

func _drop_data(at_position: Vector2, data: Variant) -> void:
	OnItemDropped.emit(data["ID"], self.InventorySlotID, data)

	
func UpdateCount():
	if SlotData != null:
		IconSlot.tooltip_text = str(SlotData.StackSize)
