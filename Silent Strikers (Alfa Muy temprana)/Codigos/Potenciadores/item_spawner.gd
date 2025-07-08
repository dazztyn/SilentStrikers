# Sistema de spawneo de items
extends Node2D
class_name ItemSpawner

@export var spawn_points: Array[Node2D] = []
@export var item_scenes: Array[PackedScene] = []
@export var min_spawn_time: float = 5.0
@export var max_spawn_time: float = 15.0
@export var max_items_on_map: int = 3

var active_items: Array[BaseItem] = []
var spawn_timer: Timer

func _ready():
	# Configurar timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_spawn_random_item)
	add_child(spawn_timer)
	
	# Validar puntos de spawn
	if spawn_points.is_empty():
		collect_spawn_points()
	
	# Iniciar spawneo
	_start_spawn_timer()

func collect_spawn_points():
	# Recoger automáticamente todos los nodos con grupo "spawn_point"
	var points = get_tree().get_nodes_in_group("spawn_point")
	spawn_points = points

func _spawn_random_item():
	# Verificar si hay espacio para más items
	if active_items.size() >= max_items_on_map:
		_start_spawn_timer()
		return
	
	# Verificar que hay scenes e items disponibles
	if item_scenes.is_empty() or spawn_points.is_empty():
		print("No hay scenes de items o puntos de spawn configurados")
		return
	
	# Seleccionar punto de spawn libre
	var available_points = get_available_spawn_points()
	if available_points.is_empty():
		print("No hay puntos de spawn disponibles")
		_start_spawn_timer()
		return
	
	# Seleccionar item y punto aleatorio
	var random_scene = item_scenes[randi() % item_scenes.size()]
	var random_point = available_points[randi() % available_points.size()]
	
	# Crear item
	var item = random_scene.instantiate()
	if item is BaseItem:
		item.position = random_point.global_position
		item.item_collected.connect(_on_item_collected)
		get_tree().current_scene.add_child(item)
		active_items.append(item)
		print("Item spawneado: ", item.item_name, " en posición: ", item.position)
	else:
		print("El scene no es un BaseItem válido")
		item.queue_free()
	
	# Reiniciar timer
	_start_spawn_timer()

func get_available_spawn_points() -> Array[Node2D]:
	var available_points: Array[Node2D] = []
	var min_distance = 100.0  # Distancia mínima entre items
	
	for point in spawn_points:
		var is_available = true
		
		for item in active_items:
			if item and is_instance_valid(item):
				if point.global_position.distance_to(item.global_position) < min_distance:
					is_available = false
					break
		
		if is_available:
			available_points.append(point)
	
	return available_points

func _on_item_collected(item: BaseItem):
	# Remover item de la lista activa
	if item in active_items:
		active_items.erase(item)
	
	print("Item recolectado: ", item.item_name)

func _start_spawn_timer():
	var wait_time = randf_range(min_spawn_time, max_spawn_time)
	spawn_timer.wait_time = wait_time
	spawn_timer.start()

func force_spawn_item(item_scene: PackedScene, spawn_point: Node2D):
	# Función para forzar spawn de un item específico
	if not item_scene or not spawn_point:
		return
	
	var item = item_scene.instantiate()
	if item is BaseItem:
		item.position = spawn_point.global_position
		item.item_collected.connect(_on_item_collected)
		get_tree().current_scene.add_child(item)
		active_items.append(item)
		print("Item forzado: ", item.item_name)

func clear_all_items():
	# Función para limpiar todos los items activos
	for item in active_items:
		if item and is_instance_valid(item):
			item.queue_free()
	active_items.clear()
