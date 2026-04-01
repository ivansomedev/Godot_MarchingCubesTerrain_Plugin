@tool
class_name MarchingCubesTerrainPlugin extends EditorPlugin

var gizmo_plugin: MC_GizmoPlugin
var undo_redo: EditorUndoRedoManager

# трава
# https://www.youtube.com/shorts/NbF5pGo2FGY?feature=share

# расчет через шейдеры ???
# https://youtu.be/dzcFB_9xHtg

## Основные положения, чтобы не забыть, что мы тут делаем.
	# MarchCubesTerrain - менеджер чанков
	# Chunk - Карта высот 
	# CutSphere / Dome - модифиакторы

static var instance : MarchingCubesTerrainPlugin

var control_panel
#var active_terrain:MarchCubesTerrain = null
var active_chunk:BaseChunk = null
var terrain_hovered := false

var painter:Painter # for debug draw

var brush_scene := preload("res://addons/MarchingCubesTerrain/content/brush.tscn")

## Tool attribute variables
var _brush:CSGCylinder3D
var draw_mode := false
var brush_position : Vector3
var brush_size : float = 15.0
# The point where the height drag started
var base_position : Vector3
# Словарь ключей для кисти (координаты высот)
var current_draw_pattern : Dictionary



#region Plugin-base
func _enable_plugin() -> void:
	add_custom_type("BaseChunk", "MeshInstance3D", preload("res://addons/MarchingCubesTerrain/BaseChunk.gd"), 
		preload("res://addons/MarchingCubesTerrain/content/ChunkIcon.svg"))
	
	add_custom_type("Chunk", "BaseChunk", preload("res://addons/MarchingCubesTerrain/BaseChunk.gd"), 
		preload("res://addons/MarchingCubesTerrain/content/ChunkIcon.svg"))
		
	set_input_event_forwarding_always_enabled()
	if !Engine.is_editor_hint(): return
	
	# Использование выделения для начала/остановки редактирования
	EditorInterface.get_selection().selection_changed.connect(selection_changed)
	#get_tree().node_added.connect(on_tree_node_added)
	#get_tree().node_removed.connect(on_tree_node_removed)
	painter = Painter.new()


# Initialization of the plugin
func _enter_tree() -> void:
	instance = self
	call_deferred("_deferred_enter_tree")

func _deferred_enter_tree() -> void:
	gizmo_plugin = MC_GizmoPlugin.new()
	add_node_3d_gizmo_plugin(gizmo_plugin)
	
	control_panel = preload("res://addons/MarchingCubesTerrain/content/panel.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, control_panel)
	init_controls()


## Disable 
# Remove autoloads here.
func _disable_plugin() -> void:
	remove_custom_type("BaseChunk")


# Clean-up of the plugin goes here.
func _exit_tree() -> void:
	remove_control_from_docks(control_panel)
	if control_panel:
		control_panel.free()
	
	if gizmo_plugin:
		remove_node_3d_gizmo_plugin(gizmo_plugin)
		gizmo_plugin = null
#endregion

#region control-panel

func init_controls():
	var brush_toggle = control_panel.get_node("VBoxContainer/HeightBtn")
	var slider = control_panel.get_node("VBoxContainer/SliderBrushSize")
	var label = control_panel.get_node("VBoxContainer/LabelBrushSize")
	var mm_regen = control_panel.get_node("VBoxContainer/MMGen")
	
	brush_toggle.toggled.connect(change_bruch)
	slider.value_changed.connect(change_size.bind(label))
	mm_regen.pressed.connect(regenerate_marchCubes)

func change_bruch(toggled_on:bool):
	draw_mode = toggled_on

func change_size(value:float, label:Label):
	label.text = str(value)
	brush_size = value
	if is_instance_valid(_brush):
		_brush.radius = brush_size


func regenerate_marchCubes():
	if active_chunk != null:
		active_chunk.regenerate_mesh()

#endregion

########################################
###### Жизненный цикл

# Выделение изменено. начать/остановить редактирование?
func selection_changed():
	assert(get_editor_interface() && get_editor_interface().get_selection())
	var selection = get_editor_interface().get_selection().get_selected_nodes()
	handle_selected_chunk(selection)


func handle_selected_chunk(selection:Array):
	active_chunk = null
	#active_terrain = null
	
	if selection.size() == 1:
		if selection[0] is BaseChunk:
			active_chunk = selection[0]
		#if selection[0] is MarchCubesTerrain:
			#active_terrain = selection[0]
			#_init_brush()


func _init_brush():
	if is_instance_valid(_brush):
		#_brush.reparent(active_terrain.get_tree().root)
		return 
	else:
		_brush = brush_scene.instantiate()
		#active_terrain.get_tree().root.add_child(_brush)


#region user-interface

# Эта функция обрабатывает щелчки мыши в 3D-окне просмотра.
func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	#print(_forward_3d_gui_input)
	var selected = EditorInterface.get_selection().get_selected_nodes()
	if not selected or len(selected) > 1:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return handle_mouse(camera, event)
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func handle_mouse(camera: Camera3D, event: InputEvent) -> int:
	terrain_hovered = false
	var is_shift = Input.is_key_pressed(KEY_SHIFT)
	
	#if draw_mode and active_terrain != null:
		#var editor_viewport = EditorInterface.get_editor_viewport_3d()
		#var mouse_pos = editor_viewport.get_mouse_position()	
		#var ray_origin := camera.project_ray_origin(mouse_pos)
		#var ray_dir := camera.project_ray_normal(mouse_pos)
		#
		#var local_ray_dir = ray_dir * active_terrain.transform
		#var set_plane = Plane(Vector3(local_ray_dir.x, 0, local_ray_dir.z), base_position)
		#var set_position = set_plane.intersects_ray(active_terrain.to_local(ray_origin), local_ray_dir)
		#if set_position:
			#brush_position = set_position
			#_brush.position = brush_position
			#print("кисточка!", brush_position)
	
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS
	
#endregion
