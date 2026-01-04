extends Node
class_name InventoryHandler

signal OnItemDropped(fromSlotID: int, toSlotID: int, data: Dictionary)

@export var PlayerBody: CharacterBody3D
@export_flags_3d_physics var CollisionMask: int

@export var HotbarSize: int = 9
@export var ItemSlotsCount: int = 20 + HotbarSize

@export var InventoryGrid: GridContainer
@export var HotbarContainer: HBoxContainer
@export var InventorySlotPrefab: PackedScene

# Logical inventory data (index == slot ID)
var InventorySlots: Array[InventorySlot] = []

# All UI slot views per slot ID (hotbar + inventory grid)
var SlotViewsByID: Dictionary = {}

var EquippedSlot: int = -1


# --------------------------------------------------------------------
# READY
# --------------------------------------------------------------------
func _ready():
	InventorySlots.resize(ItemSlotsCount)

	# --- HOTBAR (slots 0–8)
	for i in range(0, HotbarSize):
		var slot := InventorySlotPrefab.instantiate() as InventorySlot
		slot.InventorySlotID = i
		slot.OnItemDropped.connect(ItemDroppedOnSlot)
		slot.OnItemEquiped.connect(ItemEquipped)
		HotbarContainer.add_child(slot)

		InventorySlots[i] = slot
		RegisterSlotView(slot)

	# --- INVENTORY GRID (slots 9–19)
	for i in range(HotbarSize, ItemSlotsCount):
		var slot := InventorySlotPrefab.instantiate() as InventorySlot
		slot.InventorySlotID = i
		slot.OnItemDropped.connect(ItemDroppedOnSlot)
		slot.OnItemEquiped.connect(ItemEquipped)
		InventoryGrid.add_child(slot)

		InventorySlots[i] = slot
		RegisterSlotView(slot)


# --------------------------------------------------------------------
# SLOT VIEW REGISTRATION & SYNC
# --------------------------------------------------------------------
func RegisterSlotView(slot: InventorySlot):
	var id := slot.InventorySlotID
	if not SlotViewsByID.has(id):
		SlotViewsByID[id] = []
	SlotViewsByID[id].append(slot)


func UpdateSlotViews(slot_id: int, data: ItemData, equipped: bool):
	if not SlotViewsByID.has(slot_id):
		return

	for slot in SlotViewsByID[slot_id]:
		slot.FillSlot(data, equipped)


# --------------------------------------------------------------------
# INVENTORY LOGIC
# --------------------------------------------------------------------
func PickupItem(item: ItemData):
	# Try stacking first
	for slot in InventorySlots:
		if slot.SlotData != null and slot.SlotData == item:
			if slot.SlotData.StackSize < slot.SlotData.MaxStack:
				slot.SlotData.StackSize += 1
				slot.UpdateStackLabel()
				return

	# Otherwise find empty slot
	for slot in InventorySlots:
		if slot.SlotData == null:
			item.StackSize = 1
			slot.FillSlot(item, false)
			return

	# Inventory full → drop
	var world_item := item.ItemModelPrefab.instantiate() as Node3D
	PlayerBody.get_parent().add_child(world_item)
	world_item.global_position = PlayerBody.global_position + PlayerBody.global_transform.basis.z * -2.0


func ItemEquipped(slot_id: int):
	# Bounds check
	if slot_id < 0 or slot_id >= HotbarSize:
		return

	# Unequip previous slot (remove highlight if it had an item)
	if EquippedSlot != -1 and EquippedSlot != slot_id:
		var prev_item := InventorySlots[EquippedSlot].SlotData
		UpdateSlotViews(EquippedSlot, prev_item, false)

	# Update selected slot
	EquippedSlot = slot_id
	var slot_item := InventorySlots[slot_id].SlotData

	# Only show highlight if item exists
	if slot_item != null:
		UpdateSlotViews(slot_id, slot_item, true)
	else:
		UpdateSlotViews(slot_id, null, false)
		
	# Hide all selected highlights first
	for slot in InventorySlots:
		slot.SelectedHighlight.visible = false

# Show for currently selected slot
	InventorySlots[EquippedSlot].SelectedHighlight.visible = true




func ItemDroppedOnSlot(from_id: int, to_id: int, data: Dictionary):
	if from_id == to_id:
		return

	if from_id < 0 or from_id >= InventorySlots.size():
		return
	if to_id < 0 or to_id >= InventorySlots.size():
		return

	var from_slot := InventorySlots[from_id]
	var to_slot := InventorySlots[to_id]

	var amount: int = int(data["Amount"])
	var item := from_slot.SlotData
	if item == null:
		return

	# Merge stacks
	if to_slot.SlotData != null and to_slot.SlotData == item:
		var can_add: int = min(
			amount,
			to_slot.SlotData.MaxStack - to_slot.SlotData.StackSize
		)

		if can_add <= 0:
			return

		to_slot.SlotData.StackSize += can_add
		from_slot.SlotData.StackSize -= can_add

		to_slot.UpdateStackLabel()
		from_slot.UpdateStackLabel()

		if from_slot.SlotData.StackSize <= 0:
			UpdateSlotViews(from_id, null, false)

		return

	# Move to empty slot
	if to_slot.SlotData == null:
		var new_item := item.duplicate()
		new_item.StackSize = amount

		to_slot.FillSlot(new_item, false)

		from_slot.SlotData.StackSize -= amount
		from_slot.UpdateStackLabel()

		if from_slot.SlotData.StackSize <= 0:
			UpdateSlotViews(from_id, null, false)



# --------------------------------------------------------------------
# DROP TO WORLD (drag outside UI)
# --------------------------------------------------------------------
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY \
		and data.has("Type") \
		and data["Type"] == "Item"


func _drop_data(at_position: Vector2, data: Variant) -> void:
	OnItemDropped.emit(data["ID"], self.InventorySlotID, data)


# --------------------------------------------------------------------
# WORLD RAYCAST
# --------------------------------------------------------------------
func GetWorldMousePosition() -> Vector3:
	var mouse_pos := get_viewport().get_mouse_position()
	var cam := get_viewport().get_camera_3d()
	var ray_start := cam.project_ray_origin(mouse_pos)
	var ray_end := ray_start + cam.project_ray_normal(mouse_pos) * 10.0

	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end,
		CollisionMask
	)

	var result := PlayerBody.get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		return result["position"] + Vector3.UP * 0.5

	return ray_start.lerp(ray_end, 0.5) + Vector3.UP * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drop_item"):
		DropEquippedItem()

func DropEquippedItem():
	if EquippedSlot == -1:
		return

	var slot := InventorySlots[EquippedSlot]
	var item := slot.SlotData
	if item == null:
		EquippedSlot = -1
		return

	# Reduce stack
	item.StackSize -= 1
	if item.StackSize > 0:
		InventorySlots[EquippedSlot].UpdateStackLabel()
	else:
		UpdateSlotViews(EquippedSlot, null, false)
		EquippedSlot = -1

	# Spawn world item
	var world_item := item.ItemModelPrefab.instantiate() as Node3D
	PlayerBody.get_parent().add_child(world_item)
	world_item.global_position = PlayerBody.global_position + PlayerBody.global_transform.basis.z * -2.0

func _input(event: InputEvent) -> void:
	var IsInventoryOpen= \
	InventoryGrid.get_parent()\
	.get_parent().get_parent().visible
	
	# Drop item
	if event.is_action_pressed("drop_item"):
		if not IsInventoryOpen:
			DropEquippedItem()

	# Hotbar scroll
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			CycleHotbar(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			CycleHotbar(1)
			
	if event is InputEventKey and event.pressed:
		var key : int = event.keycode

		if key >= KEY_1 and key <= KEY_9:
			var slot := key - KEY_1
			if slot < HotbarSize:
				ItemEquipped(slot)
				
	if event.is_action_pressed("open_close_inventory"):
		var inventory_root := InventoryGrid.get_parent().get_parent().get_parent()
		if inventory_root.visible == false:
			inventory_root.visible = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			inventory_root.visible = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func CycleHotbar(direction: int):
	if HotbarSize <= 0:
		return

	var current: int = EquippedSlot
	if current == -1:
		current = 0

	var next: int = (current + direction) % HotbarSize
	if next < 0:
		next += HotbarSize

	ItemEquipped(next)
