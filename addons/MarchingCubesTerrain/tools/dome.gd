@tool
class_name Dome extends Node3D

## Модификатор для создания куполообразных пещер
## Имеет две ручки: радиус основания и высота купола

# событие для перерисовки вышестоящего чанка
## todo: 
# 1. сделать, чтобы чанк обновлялся
# 2. добавить реакцию на перемещения position
# 3. Подумать над инструментом Добавление, а то сейчас только "вычитание"
signal tool_changed(dome:Dome) 

@export var radius:float = 3.0:
	set(val):
		radius = val
		update_visual()
@export var height:float = 5.0:
	set(val):
		height = clamp(val, 1.0, 100.0)
		update_visual()
@export var step_children:float = 1.5
@export var slope_children:bool = false

# Визуализация
@export var gizmo_color: Material = preload("res://addons/MarchingCubesTerrain/materials/Gizmo.material")
var circle_mesh: CSGTorus3D
var top_handle: CSGSphere3D
var side_handle: CSGSphere3D
var child_mesh:Array

static var UP_PLANE = Plane(Vector3.UP, 0)

# Возвращает объем в заданной точке сетки
static func get_vol_s(point:Vector3i, cell_size:float, 
		pos:Vector3, rad:float, hei:float,
		slope_plane:Plane = UP_PLANE):

	var loc = Vector3(point) * cell_size - pos
	if loc.y > hei:
		return 1.0
	
	var rad_f = rad / sqrt(hei)
	var r = sqrt(hei-loc.y) * rad_f
	var h_d = sqrt(loc.x*loc.x+loc.z*loc.z)-r
	
	var plane_dis = slope_plane.distance_to(loc)
	if plane_dis < 0:
		var v = clamp( -plane_dis, 0.0, 1.0)
		return max(v, h_d)
	
	return clamp(h_d, 0.0, 1.0)

# Возвращает размеры bounding box в округленные до координат вокселей
static func get_box_s(chunk_size:Vector3, cell_size:float, pos:Vector3, rad:float, hei:float):
	var grid_center = pos / cell_size
	var grid_radius = ceil(rad / cell_size)
	var grid_height = ceil(hei / cell_size)
	return {
		'min_x': max(0, floor(grid_center.x - grid_radius) - 1),
		'max_x': min(chunk_size.x - 1, ceil(grid_center.x + grid_radius) + 1),
		'min_y': floor(grid_center.y) - 4,
		'max_y': ceil(grid_center.y + grid_height + 1),
		'min_z': max(0, floor(grid_center.z - grid_radius) - 1),
		'max_z': min(chunk_size.z - 1, ceil(grid_center.z + grid_radius) + 1)
	}

#region gismos
func _ready() -> void:
	if Engine.is_editor_hint():
		create_gizmos()


func create_gizmos():
	#print(create_gizmos)
	# Круг основание
	circle_mesh = CSGTorus3D.new()
	circle_mesh.outer_radius = radius
	circle_mesh.inner_radius = radius - 0.05
	circle_mesh.sides = 32
	circle_mesh.material_override = gizmo_color
	add_child(circle_mesh)
	
	side_handle = CSGSphere3D.new()
	side_handle.radius = 0.1
	side_handle.material_override = gizmo_color
	side_handle.position.x = radius
	add_child(side_handle)
	
	top_handle = CSGSphere3D.new()
	top_handle.radius = 0.1
	top_handle.material_override = gizmo_color
	top_handle.position.y = height
	add_child(top_handle)
	
	for child in get_children():
		child_mesh = []
		if child is Dome:
			child_mesh.append( _line(Vector3.ZERO, Vector3(child.position.x, child.position.y, child.position.z)))


# update_gizmos - это стандартная функция
func update_visual():
	if not Engine.is_editor_hint():
		return
	if circle_mesh:
		circle_mesh.outer_radius = radius
		circle_mesh.inner_radius = radius - 0.05
	if top_handle:
		top_handle.position.y = height
	if side_handle:
		side_handle.position.x = radius
	emit_signal("tool_changed", self)


func _line(pos1:Vector3, pos2:Vector3):
	var mi = MeshInstance3D.new()
	var im = ImmediateMesh.new()
	mi.mesh = im
	mi.cast_shadow = false
	mi.material_overlay = gizmo_color
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(pos1)
	im.surface_add_vertex(pos2)
	im.surface_end()
	add_child(mi)
	return mi
#endregion
