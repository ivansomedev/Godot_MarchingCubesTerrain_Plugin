class_name MC_ChunkGizmo extends EditorNode3DGizmo

func _redraw():
	clear()
	var holder: BaseChunk = get_node_3d()
	# Только если выбран единственный чанк
	if len(EditorInterface.get_selection().get_selected_nodes()) != 1:
		return
	if EditorInterface.get_selection().get_selected_nodes()[0] != holder:
		return
	
	# Рукоятки для подъема опускания карты высот (базовый функционал вместо кистей)
	var corners = PackedVector3Array()
	var ids = PackedInt32Array()
	for z in range(holder.size.z):
		for x in range(holder.size.x):
			var y = holder.height_map[z][x]
			corners.append(Vector3(x * holder.cell_size, y, z * holder.cell_size))
			ids.append(z * holder.size.x + x)
	add_handles(corners, get_plugin().get_material("handles", self), ids)


func _get_handle_name(handle_id: int, secondary: bool) -> String:
	return str(handle_id);


func _get_handle_value(handle_id: int, secondary: bool) -> Variant:
	var terrain: BaseChunk = get_node_3d()
	var z = handle_id / terrain.size.z
	var x = handle_id % terrain.size.z
	return terrain.height_map[z][x];


func _commit_handle(handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	var terrain: BaseChunk = get_node_3d()
	var z = handle_id / terrain.size.z
	var x = handle_id % terrain.size.z
	
	if cancel:
		terrain.height_map[z][x] = restore
	else:
		var undo_redo := MarchingCubesTerrainPlugin.instance.get_undo_redo()
		
		var do_value = terrain.height_map[z][x]
	
		undo_redo.create_action("move terrain point")
		undo_redo.add_do_method(self, "move_terrain_point", terrain, handle_id, do_value)
		undo_redo.add_undo_method(self, "move_terrain_point", terrain, handle_id, restore)
		undo_redo.commit_action()
		
	terrain.update_gizmos()

# 
func move_terrain_point(terrain: BaseChunk, handle_id: int, height: float):
	var z = handle_id / terrain.size.z
	var x = handle_id % terrain.size.z
	terrain.height_map[z][x] = height
	terrain.regenerate_mesh()
	terrain.update_gizmos()

# позволяет рукоятке двигаться
func _set_handle(handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var terrain: BaseChunk = get_node_3d()
	var z = handle_id / terrain.size.z
	var x = handle_id % terrain.size.z
	var y = terrain.height_map[z][x]
	
	var handle_position = terrain.to_global(Vector3(x * terrain.cell_size, y, z * terrain.cell_size))
	# Convert mouse movement to 3D world coordinates using raycasting
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)
	
	# We want the movement restricted to the Y-axis.
	# Create a plane that is parallel to the XZ plane (normal pointing along Y-axis)
	var plane = Plane(Vector3(ray_dir.x, 0, ray_dir.z), handle_position)
	var intersection = plane.intersects_ray(ray_origin, ray_dir)
	
	if intersection:
		intersection = terrain.to_local(intersection)
		terrain.height_map[z][x] = intersection.y
		terrain.update_gizmos()
