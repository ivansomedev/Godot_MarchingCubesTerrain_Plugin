@tool
class_name BaseChunk extends MeshInstance3D

# Попытка № 3 -- regenerate_mesh()
## 1 buffer_by_height() Точки плотности от высоты
## 1.1 buffer_by_content() Влияние на точки модификаторов
	# 1.2 забиваем точки плотности от сфер+сложений только там где ВЫШЕ высоты / либо УЖЕ есть пустые точки?
## 2  генерация мешей по точкам (у точек теперь есть метка можно ли по ним собрать чанк)

## Этот класс базовый MeshInstance3D > BaseChunk > Chunk
# 

@export_storage var height_map : Array # Хранит карту высот 
@export var chunk_coords : Vector2i = Vector2i.ZERO
@export var size:Vector3i = Vector3i(33, 64, 33)

@export var cell_size := 2.0
@export var SurfaceLevel := 0.5 # Граница поверхности, все что больше этого значения - твердое

var gen_buffer:Dictionary
var processor:SurfaceTool

## Debug vars
# для генерации хоть какой-то карты высот в основном для теста
	# В целях отладки, предполагается, что инструмент ручной.
@export_category("Debug")
@export var debug_noise:FastNoiseLite 
@export var height_points := false
@export var draw_volume := false
@export var baseMat:Material = preload("res://addons/MarchingCubesTerrain/materials/StoneTriplanar.tres")
var painter:Painter

func _ready() -> void:
	painter = Painter.new()
	if height_map.is_empty():
		generate_height_map()
	regenerate_mesh()

func _debug_heightmap():
	painter.remove_points(self)
	for z in range(size.z):
		for x in range(size.x):
			var world_y = height_map[z][x]
			var point = Vector3(x, 0, z) * cell_size + Vector3(0, world_y, 0)
			painter.draw_point(point, self, 0.1, Color.RED)

func _debug_volume():
	for key:Vector3i in gen_buffer:
		var coord = Vector3(key.x, key.y, key.z) * cell_size
		var cp:ChunkPoint = gen_buffer[key]
		#if cp.root:
			#painter.draw_point(coord, self, 0.1, Color(cp.val,cp.val,cp.val))
		#else:
		if not cp.root:
			painter.draw_point(coord, self, 0.1, Color.GREEN)


func generate_height_map():
	height_map = []
	height_map.resize(size.z)
	for z in range(size.z):
		height_map[z] = []
		height_map[z].resize(size.x)
		for x in range(size.x):
			height_map[z][x] = 0.0
			if debug_noise:
				var noise_sample = debug_noise.get_noise_2d(x, z)
				height_map[z][x] = noise_sample * size.y 

func regenerate_mesh():
	#print(regenerate_mesh)
	if height_points:
		_debug_heightmap()
	gen_buffer = {} # Всегда ли нужно очищать?
	buffer_by_height()
	buffer_by_content()
	if draw_volume:
		_debug_volume()
	draw_mesh()

# Окей, а вот и инструментики
func buffer_by_content():
	var substractions = find_children("*", "CSGSphere3D")
	for sub:CutSphere in substractions:
		cut_shpere_with_children(sub)

func cut_shpere_with_children(sub:CutSphere):
	var origin_pos_in_chunk = sub.global_position - position
	var noise_factor = 10
	if sub.noisiness:
		noise_factor = sub.noisiness
	
	if sub.is_cutter:
		substract_sphere(origin_pos_in_chunk, sub.radius)
	else:
		add_sphere(origin_pos_in_chunk, sub.radius, noise_factor)
	
	for child in sub.get_children():
		if child is CutSphere:
			var child_pos_in_chunk = child.global_position - position
			var dist = origin_pos_in_chunk.distance_to(child_pos_in_chunk) 
			var steps = floor(dist / sub.step_children)
			var w_by_step = 1.0 / steps
			for i in range(steps):
				if sub.is_cutter:
					substract_sphere(
						lerp(origin_pos_in_chunk, child_pos_in_chunk, i * w_by_step),
						lerp(sub.radius, child.radius, i * w_by_step))
				else:
					add_sphere(
						lerp(origin_pos_in_chunk, child_pos_in_chunk, i * w_by_step),
						lerp(sub.radius, child.radius, i * w_by_step), noise_factor)
			cut_shpere_with_children(child)


func add_sphere(pos:Vector3, rad:float, noisiness:int):
	var box = CutSphere.get_box_s(size, cell_size, pos, rad)
	var check_roots = []
	
	for x in range(box.min_x, box.max_x):
		for z in range(box.min_z, box.max_z):
			for y in range(box.min_y, box.max_y):
				var coord = Vector3(x,y,z) * cell_size
				var dist = coord.distance_to(pos)
				var height = height_map[z][x]
				
				# Если ниже высоты... тогда только если есть ключ?
				if dist < rad + cell_size * 2: # and (coord.y > height):
					calculate_box(	Vector3i(x,y,z), check_roots,
									CutSphere.get_vol_a, [cell_size, pos, rad, noisiness], _max_buffer)
	update_roots_for(check_roots)

func substract_sphere(pos:Vector3, rad:float):
	# Границы поиска в индексах сетки >> тут же по идее и "грязный флаг" повесить
	var box = CutSphere.get_box_s(size, cell_size, pos, rad)
	var check_roots = []
	
	for x in range(box.min_x, box.max_x):
		for z in range(box.min_z, box.max_z):
			for y in range(box.min_y, box.max_y):
				var coord = Vector3(x,y,z) * cell_size
				var dist = coord.distance_to(pos)
				var height = height_map[z][x]
				# Тут раньше был большой кусок... упаковано в calculate_box
				if dist < rad + cell_size * 2 and coord.y < height:
					calculate_box(	Vector3i(x,y,z), check_roots, 
									CutSphere.get_vol_s, [cell_size, pos, rad], _min_buffer)
	update_roots_for(check_roots)


# Окей, volume_func - должны принимать key:Vector3i, args:Array
func calculate_box(key_point:Vector3i, check_roots:Array, volume_func:Callable, args:Array, buffer_func:Callable):
	var keys = [
		key_point, key_point+Vector3i(1,0,0), 
		key_point+Vector3i(1,0,1), key_point+Vector3i(0,0,1),
		key_point+Vector3i(0,1,0), key_point+Vector3i(1,1,0), 
		key_point+Vector3i(1,1,1), key_point+Vector3i(0,1,1)]
	for key in keys:
		var vol = volume_func.call(key, args)
		check_roots.append(buffer_func.call(key, vol))


# Записывает минимальное значение в буфер и возвращает ключ буфера.
func _min_buffer(key:Vector3i, new_val:float, root:bool=false) -> Vector3i:
	if key in gen_buffer:
		gen_buffer[key].val = min(gen_buffer[key].val, new_val)
	else:
		gen_buffer[key] = ChunkPoint.new(new_val, root)
	return key

func _max_buffer(key:Vector3i, new_val:float, root:bool=false) -> Vector3i:
	if key in gen_buffer:
		gen_buffer[key].val = max(gen_buffer[key].val, new_val)
	else:
		gen_buffer[key] = ChunkPoint.new(new_val, root)
	return key


func update_roots_for(check_roots:Array):
	for key:Vector3i in check_roots:
		var is_root = gen_buffer.has(key+Vector3i(1,0,0))
		is_root = is_root and gen_buffer.has(key+Vector3i(1,0,1))
		is_root = is_root and gen_buffer.has(key+Vector3i(0,0,1))
		is_root = is_root and gen_buffer.has(key+Vector3i(0,1,0))
		is_root = is_root and gen_buffer.has(key+Vector3i(1,1,0))
		is_root = is_root and gen_buffer.has(key+Vector3i(1,1,1))
		is_root = is_root and gen_buffer.has(key+Vector3i(0,1,1))
		gen_buffer[key].root = is_root



# Заполняем point_buffer по карте высот используем Vector4 чтобы было понятно, 
	# можно ли опереться на точку, как на "чанк" ?
	# if ChunkPoint.root Значит можно брать x+1, y+1, z+1
func buffer_by_height():
	for x in range(size.x-1):
		for z in range(size.z-1):
			# Высоты 4-х углов ячейки
			var h1 = height_map[z][x]
			var h2 = height_map[z][x+1]
			var h3 = height_map[z+1][x+1]
			var h4 = height_map[z+1][x]
			# Вертикальный диапазон кубиков
			var min_box_y = floor(min(h1, h2, h3, h4) / cell_size)
			var max_box_y = ceil(max(h1, h2, h3, h4) / cell_size)

			for box_y in range(min_box_y, max_box_y):
				# Кажется, что это можно сократить чтобы не вычислять дважды.
				# Но я не знаю что быстрее проверить условие if или выполнить _vol_Y 
				gen_buffer[Vector3i(x, box_y, z)] = ChunkPoint.new(_vol_Y(h1, box_y), true)
				gen_buffer[Vector3i(x+1, box_y, z)] = ChunkPoint.new(_vol_Y(h2, box_y))
				gen_buffer[Vector3i(x+1, box_y, z+1)] = ChunkPoint.new(_vol_Y(h3, box_y))
				gen_buffer[Vector3i(x, box_y, z+1)] = ChunkPoint.new(_vol_Y(h4, box_y))
				
				if box_y == int(max_box_y - 1):
					gen_buffer[Vector3i(x, box_y+1, z)] = ChunkPoint.new(_vol_Y(h1, box_y+1))
					gen_buffer[Vector3i(x+1, box_y+1, z)] = ChunkPoint.new(_vol_Y(h2, box_y+1))
					gen_buffer[Vector3i(x+1, box_y+1, z+1)] = ChunkPoint.new(_vol_Y(h3, box_y+1))
					gen_buffer[Vector3i(x, box_y+1, z+1)] = ChunkPoint.new(_vol_Y(h4, box_y+1))


func _vol_Y(world_y:float, voxel_y:int) -> float:
	var diff = world_y - voxel_y * cell_size
	return (diff / cell_size) + SurfaceLevel


# Окей, мы возвращаемся к точкам, однако я надеюсь сэкономить проверки
func draw_mesh():
	if processor == null:
		processor = SurfaceTool.new() 
	processor.clear()
	processor.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for key:Vector3i in gen_buffer:
		var cp:ChunkPoint = gen_buffer[key]
		if cp.root:
			var _dots = [
				cp.val,
				gen_buffer[key + Vector3i(1,0,0)].val,
				gen_buffer[key + Vector3i(1,0,1)].val,
				gen_buffer[key + Vector3i(0,0,1)].val,
				gen_buffer[key + Vector3i(0,1,0)].val,
				gen_buffer[key + Vector3i(1,1,0)].val,
				gen_buffer[key + Vector3i(1,1,1)].val,
				gen_buffer[key + Vector3i(0,1,1)].val,]
			# Действительные координаты углов:
			var _corners = MarchTables.get_corners(key.x,key.y,key.z, cell_size)
			var cubeInd = MarchTables.calculate_index_of_cube_configuration(_dots)
			var triang = MarchTables.triangulation[cubeInd]
			var i = 0
			while triang[i] != -1:
				var a0 = MarchTables.cornerIndexAFromEdge[triang[i]]
				var b0 = MarchTables.cornerIndexBFromEdge[triang[i]]
				var a1 = MarchTables.cornerIndexAFromEdge[triang[i+1]]
				var b1 = MarchTables.cornerIndexBFromEdge[triang[i+1]]
				var a2 = MarchTables.cornerIndexAFromEdge[triang[i+2]]
				var b2 = MarchTables.cornerIndexBFromEdge[triang[i+2]]
				# Интерполированные вершины
				var vertA:Vector3 = get_interpolated_point(_corners[a0], _dots[a0], _corners[b0], _dots[b0])
				var vertB:Vector3 = get_interpolated_point(_corners[a1], _dots[a1], _corners[b1], _dots[b1])
				var vertC:Vector3 = get_interpolated_point(_corners[a2], _dots[a2], _corners[b2], _dots[b2])
				processor.add_vertex(vertC)
				processor.add_vertex(vertB)
				processor.add_vertex(vertA)
				i += 3
	processor.index()
	processor.generate_normals()
	self.mesh = processor.commit()

func get_interpolated_point(p0: Vector3, val0: float, p1: Vector3, val1: float) -> Vector3:
	if abs(val1 - val0) < 0.0001:
		return (p0 + p1) / 2
	# Коэффициент интерполяции (где между 0 и 1 находится поверхность)
	var t = (SurfaceLevel - val0) / (val1 - val0)
	t = clamp(t, 0.0, 1.0)
	return p0.lerp(p1, t) # Линейная интерполяция позиции


class ChunkPoint:
	var val:float
	var root:bool
	func _init(density:float, root:=false) -> void:
		self.val = density
		self.root = root
