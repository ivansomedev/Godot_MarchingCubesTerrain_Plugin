@tool
class_name CutSphere extends CSGSphere3D

# Окей, вместо базового класса будем использовать свой, 
# чтобы вынести сюда часть функционала
@export var is_cutter := true
@export var gizmo_color: Material = preload("res://addons/MarchingCubesTerrain/materials/Gizmo.material")
@export var step_children := 1.5
@export var noisiness:int = 5 

# Gizmos 
func _ready() -> void:
	radius = 5.0
	material = gizmo_color

#region generator

# Возвращает объем текущей точки
static func get_vol_s(point:Vector3i, args:Array): # cell_size:float, pos:Vector3, rad:float):
	var cell_size = args[0]
	var p = Vector3(point) * cell_size
	var distance = p.distance_to(args[1]) #pos) 
	var t = (distance - (args[2] - cell_size * 0.5)) / cell_size
	return clamp(t, 0.0, 1.0)  # Линейно убывает от 1 до 0


# Наизнанку для добавления
# args = [cell_size, position, radius, noisiness:int]
static func get_vol_a(point:Vector3i, args:Array): 
	var cell_size = args[0]
	var p = Vector3(point) * cell_size
	var distance = p.distance_to(args[1]) 
	
	var noisiness = args[3]
	# Я хочу модифицировать дистанцию, чтобы получить шум
	distance += _hash3d(point.x, point.y, point.z) % 10 / noisiness 
	
	var t = (distance - (args[2] - cell_size * 0.5)) / cell_size
	return clamp(1.0 - t, 0.0, 1.0) 


# Простая хеш-функция для 3D координат
static func _hash3d(x:int, y:int, z:int) -> int:
	var h = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	return abs(h)
# вот вроде и прикольно... Но...
#func get_vol_noise(point:Vector3i, cell_size:float):
	#var n = form_noise.get_noise_3d(point.x, point.y, point.z)
	#if form_noise:
		#return min(n, get_vol_a(point, cell_size, position, radius))
	#else:
		#return 0.0


# Возвращает размеры bounding box в округленные до координат вокселей
static func get_box_s(chunk_size:Vector3, cell_size:float, pos:Vector3, rad:float):
	var grid_center = pos / cell_size
	var grid_radius = ceil(rad / cell_size)
	
	return {
		'min_x': max(0, floor(grid_center.x - grid_radius)),
		'max_x': min(chunk_size.x - 1, ceil(grid_center.x + grid_radius)),
		'min_y': floor(grid_center.y - grid_radius),
		'max_y': ceil(grid_center.y + grid_radius),
		'min_z': max(0, floor(grid_center.z - grid_radius)),
		'max_z': min(chunk_size.z - 1, ceil(grid_center.z + grid_radius))
	}

#endregion
