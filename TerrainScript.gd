extends VoxelGeneratorMultipassCB

func _generate_pass(voxel_tool: VoxelToolMultipassGenerator, pass_index: int):
	var min_pos := voxel_tool.get_main_area_min()
	var max_pos := voxel_tool.get_main_area_max()

	if pass_index == 0:
		# Base terrain
		for gz in range(min_pos.z, max_pos.z):
			for gx in range(min_pos.x, max_pos.x):
				# Do things with `voxel_tool`
				# ...

	elif pass_index == 1:
		# Trees
		# ...
