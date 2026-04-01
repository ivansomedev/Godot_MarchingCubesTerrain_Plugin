class_name MC_GizmoPlugin extends EditorNode3DGizmoPlugin

func _init():
	create_material("brush", Color(1, 1, 1), false, true)
	create_material("brush_pattern", Color(0.7, 0.7, 0.7), false, true)
	create_material("removechunk", Color(1,0,0), false, true)
	create_material("addchunk", Color(0,1,0), false, true)
	
	create_handle_material("handles")

var chunk_gizmo : MC_ChunkGizmo
var dome_gizmo : DomeGizmo

func _create_gizmo(node):
	if node is BaseChunk:
		chunk_gizmo = MC_ChunkGizmo.new()
		return chunk_gizmo
	elif node is Dome:
		dome_gizmo = DomeGizmo.new()
		return dome_gizmo
	else:
		return null


func _get_gizmo_name() -> String:
	return "Marching Cubes Terrain"
