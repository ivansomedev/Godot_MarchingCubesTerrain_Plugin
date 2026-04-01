@tool
class_name Chunk extends BaseChunk

#region To-do
## Далее:
# Редактирование высоты кисточкой (страшно)
# Добавить текстуре регулируемый наклон
# Придумать как смешать 2 текстуры
#endregion

func regenerate_mesh():
	#print(regenerate_mesh)
	gen_buffer = {} # Всегда ли нужно очищать?
	painter.remove_points(self) # Очищаем дебаг графику
	
	generate_height_map() 
	
	buffer_by_height()
	buffer_by_content()
	draw_mesh()


# Окей, а вот и инструментики
func buffer_by_content():
	# Вообще раз уж, это связанный инструмент, я вероятно могу перенести
	# внутрь него часть функционала, чтобы сделать этот класс компактным 
	var caves = find_children("*", "Dome", false)
	var time_s = Time.get_ticks_msec()
	var count := 0
	for sub:Dome in caves:
		count += substract_dome_with_children(sub)
	print(count, " dome substractions:", Time.get_ticks_msec() - time_s, " миллисек.")
	
	# Окей, сферы ПОСЛЕ
	var substractions = find_children("*", "CSGSphere3D", false)
	for sub:CutSphere in substractions:
		cut_shpere_with_children(sub)



# Окей, эта функция рекурсивная, потому что мы обходим дерево
func substract_dome_with_children(sub_dome:Dome) -> int:
	var origin_pos_in_chunk = sub_dome.global_position - position
	substract_dome(origin_pos_in_chunk, sub_dome.radius, sub_dome.height, Dome.UP_PLANE)
	
	var count := 1
	var slope_plane = Dome.UP_PLANE
	#var step = sub_dome.step_children
	for child in sub_dome.get_children():
		if child is Dome:
			var child_pos_in_chunk = child.global_position - position
			var dist = origin_pos_in_chunk.distance_to(child_pos_in_chunk)  
			## Окей, нам нужен наклон - и у нас ЕСТЬ 3 точки
			if sub_dome.slope_children:
				slope_plane = Plane(child.position, Vector3.ZERO, sub_dome.side_handle.position)
				#print("slope:", slope_plane)
				
			var steps = floor(dist / sub_dome.step_children) # Количество ожидаемых шагов (берем срез)
			var w_by_step = 1.0 / steps
			for i in range(steps):
				substract_dome(
					lerp(origin_pos_in_chunk, child_pos_in_chunk, i * w_by_step),
					lerp(sub_dome.radius, child.radius, i * w_by_step), 
					lerp(sub_dome.height, child.height, i * w_by_step),
					slope_plane)
				count += 1
			count += substract_dome_with_children(child)
	return count


func substract_dome(pos:Vector3, rad:float, hei:float, slope_plane:Plane):
	## Границы поиска в индексах сетки
	var box = Dome.get_box_s(size, cell_size, pos, rad, hei)
	var check_roots = []
	for x in range(box.min_x, box.max_x):
		for z in range(box.min_z, box.max_z):
			for y in range(box.min_y, box.max_y):
				
				var coord = Vector3(x,y,z) * cell_size
				var height = height_map[z][x]
				if coord.y > height:
					continue # Обрезаем лишние
				#var vol = volums[0] # debug
				#if vol < 1.0:
					#painter.draw_point(Vector3(x,y,z) * cell_size, self, 0.2, Color(vol, vol, vol))
				# Еще бы вот это сократить...
				var volums = [
					Dome.get_vol_s(Vector3i(x,y,z), cell_size, pos, rad, hei, slope_plane),
					Dome.get_vol_s(Vector3i(x+1,y,z), cell_size, pos, rad, hei, slope_plane),
					Dome.get_vol_s(Vector3i(x+1,y,z+1), cell_size, pos, rad, hei, slope_plane),
					Dome.get_vol_s(Vector3i(x,y,z+1), cell_size, pos, rad, hei, slope_plane),
					Dome.get_vol_s(Vector3i(x,y+1,z), cell_size, pos, rad, hei, slope_plane),
					Dome.get_vol_s(Vector3i(x+1,y+1,z), cell_size, pos, rad, hei, slope_plane),
					Dome.get_vol_s(Vector3i(x+1,y+1,z+1), cell_size, pos, rad, hei, slope_plane),
					Dome.get_vol_s(Vector3i(x,y+1,z+1), cell_size, pos, rad, hei, slope_plane),]
				
				check_roots.append( _min_buffer(Vector3i(x,y,z), volums[0], true) )
				check_roots.append( _min_buffer(Vector3i(x+1,y,z), volums[1]) )
				check_roots.append( _min_buffer(Vector3i(x+1,y,z+1), volums[2]) )
				check_roots.append( _min_buffer(Vector3i(x,y,z+1), volums[3]) )
				
				check_roots.append( _min_buffer(Vector3i(x,y+1,z), volums[4]) )
				check_roots.append( _min_buffer(Vector3i(x+1,y+1,z), volums[5]) )
				check_roots.append( _min_buffer(Vector3i(x+1,y+1,z+1), volums[6]) )
				check_roots.append( _min_buffer(Vector3i(x,y+1,z+1), volums[7]) )
	
	update_roots_for(check_roots)
