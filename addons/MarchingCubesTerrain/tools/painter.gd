@tool
class_name Painter extends Node

var handled_input := false
var points:Array[Ray3] = []

#var transp := preload("res://addons/MarchingCubesTerrain/materials/Transparent.tres")

var materialCashe := {}

func _ready() -> void:
	materialCashe = {}

# Смещение существующих вершин?
# Не, это фигня. Мне надо пару методов для отладки опять
## Окей, мы записываем путь, кисточки, а потом воссоздаем ОБВОДКУ
# 
func draw_in(brush_pos:Vector3, brush:CSGCylinder3D):
	if points == []:
		var step = PI / brush.sides * 2
		for i in range(brush.sides):
			var a = i * step
			var dir = Vector3(cos(a),0,sin(a))
			var R = Ray3.new(brush_pos + dir * brush.radius, dir) 
			points.append(R)
	else:
		#print('continue', points)
		# Окей, тут нужно расширить область... ограниченную точками
		# Проверяем какие уже существующие точки попали в область кисти.
		# Передвинем их от центра кисти в новую позицию. (+установить направление) 
		for ray:Ray3 in points:
			if brush_pos.distance_to(ray.origin) < brush.radius:
				var dir = brush_pos.direction_to(ray.origin)
				ray.origin = brush_pos + dir * brush.radius
				ray.direction = dir
		#points = []


class Ray3:
	var origin: Vector3
	var direction: Vector3
	func _init(p_origin: Vector3, p_direction: Vector3):
		origin = p_origin
		direction = p_direction.normalized()

	func distance_to(point: Vector3) -> float:
		var to_point = point - origin
		var t = to_point.dot(direction)
		var projection = origin + direction * t
		return projection.distance_to(point)



func remove_points(parent:Node3D):
	for view in parent.get_children():
		if view is MeshInstance3D:
			parent.remove_child(view)
			view.free()

func draw_all_points(parent:Node3D):
	for i in range(points.size()):
		var ray:Ray3 = points[i]
		var ray_prev:Ray3 = points[i-1]
		draw_point(ray.origin, parent)
		draw_line(ray.origin, ray_prev.origin, parent)
		draw_line(ray.origin, ray.origin + ray.direction, parent)


func draw_point(pos:Vector3, parent:Node3D, rad := 0.05, color = Color.WHITE):
	var mi = MeshInstance3D.new()
	var sp = SphereMesh.new()
	var mat:ORMMaterial3D = null
	
	if materialCashe.has(color):
		mat = materialCashe[color]
	else:
		mat = ORMMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		materialCashe[color] = mat
	
	mi.mesh = sp
	mi.cast_shadow = false
	mi.position = pos
	sp.radius = rad
	sp.height = rad*2
	mi.material_overlay = mat
	parent.add_child(mi)


func draw_box(pos:Vector3, parent:Node3D):
	var mi = MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = Vector3(2,2,2)
	mi.position = pos
	parent.add_child(mi)
	#mi.set_surface_override_material(0, transp)


func draw_line(pos1:Vector3, pos2:Vector3, parent:Node3D):
	var mi = MeshInstance3D.new()
	var im = ImmediateMesh.new()
	mi.mesh = im
	mi.cast_shadow = false
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(pos1)
	im.surface_add_vertex(pos2)
	im.surface_end()
	parent.add_child(mi)
