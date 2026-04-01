class_name DomeGizmo extends EditorNode3DGizmo

func _redraw():
	clear()
	var holder: Dome = get_node_3d()
	# Только если выбран единственный чанк
	if len(EditorInterface.get_selection().get_selected_nodes()) != 1:
		return
	if EditorInterface.get_selection().get_selected_nodes()[0] != holder:
		return
	
	# Рукоятки для подъема опускания карты высот (базовый функционал вместо кистей)
	var corners = PackedVector3Array()
	var ids = PackedInt32Array()
	
	corners.append(holder.top_handle.position)
	ids.append(0)
	corners.append(holder.side_handle.position)
	ids.append(1)
	add_handles(corners, get_plugin().get_material("handles", self), ids)

func _get_handle_name(handle_id: int, secondary: bool) -> String:
	if handle_id == 0:
		return "height"
	return "radius"

func _get_handle_value(handle_id: int, secondary: bool) -> Variant:
	var holder: Dome = get_node_3d()
	if handle_id == 0:
		return holder.height
	else:
		return holder.radius

#func _commit_handle(handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	#var holder: Dome = get_node_3d()
	#holder.update_gizmos()

# позволяет рукоятке двигаться
func _set_handle(handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var holder: Dome = get_node_3d()
	var handle_position = Vector3.ZERO
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)
	
	if handle_id == 0:
		handle_position = holder.to_global(holder.top_handle.position)
		# Convert mouse movement to 3D world coordinates using raycasting
		# Движение вдоль Y для handle_id == 0
		var plane = Plane(Vector3(ray_dir.x, 0, ray_dir.z), handle_position)
		var intersection = plane.intersects_ray(ray_origin, ray_dir)
		
		if intersection:
			intersection = holder.to_local(intersection)
			holder.height = intersection.y
			holder.update_gizmos()
	else:
		handle_position = holder.to_global(holder.side_handle.position)
		var plane = Plane(Vector3(ray_dir.x, ray_dir.y, 0), handle_position)
		var intersection = plane.intersects_ray(ray_origin, ray_dir)
		
		if intersection:
			intersection = holder.to_local(intersection)
			holder.radius = intersection.x # side_handle.position.x = intersection.x
			holder.update_gizmos()
