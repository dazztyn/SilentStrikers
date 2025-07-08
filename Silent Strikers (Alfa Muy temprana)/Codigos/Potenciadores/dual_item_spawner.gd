# Sistema de spawneo para coleccionables y potenciadores
extends Node2D
class_name DualItemSpawner

@export var spawn_points: Array[Node2D] = []
@export var collectable_scene: PackedScene
@export var speed_potion_scene: PackedScene
@export var invisibility_potion_scene: PackedScene

@export var min_spawn_time: float = 3.0
@export var max_spawn_time: float = 8.0
@export var max_collectables: int = 6
@export var max_potions: int = 2

@export var collectable_spawn_chance: int = 75
@export var potion_spawn_chance: int = 25

var active_collectables: Array[BaseItem] = []
var active_potions: Array[BaseItem] = []
var spawn_timer: Timer

var collectable_types = [
	CollectableItem.CollectableType.COMPUTER,
	CollectableItem.CollectableType.MONEY_STACK,
	CollectableItem.CollectableType.BOWL,
	CollectableItem.CollectableType.GOLD_BARS
]

var potion_scenes = []

func _ready():
	# Configurar escenas de pociones
	if speed_potion_scene:
		potion_scenes.append({"scene": speed_potion_scene, "name": "Speed Potion"})
	if invisibility_potion_scene:
		potion_scenes.append({"scene": invisibility_potion_scene, "name": "Invisibility Potion"})
	
	# Configurar timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_spawn_random_item)
	add_child(spawn_timer)
	
	# Verificar spawn points
	if spawn_points.is_empty():
		collect_spawn_points()
	
	# Iniciar spawneo
	_start_spawn_timer()

func collect_spawn_points():
	var points = get_tree().get_nodes_in_group("spawn_point")
	spawn_points = points

func _spawn_random_item():
	var available_points = get_available_spawn_points()
	if available_points.is_empty():
		_start_spawn_timer()
		return
	
	# Decidir qué tipo de item spawnear
	var random_chance = randi() % 100
	
	if random_chance < collectable_spawn_chance:
		_spawn_collectable(available_points)
	else:
		_spawn_potion(available_points)
	
	_start_spawn_timer()

func _spawn_collectable(available_points: Array[Node2D]):
	if active_collectables.size() >= max_collectables or not collectable_scene:
		return
	
	var random_point = available_points[randi() % available_points.size()]
	var random_type = collectable_types[randi() % collectable_types.size()]
	
	var item = collectable_scene.instantiate()
	if item is CollectableItem:
		item.collectable_type = random_type
		item.position = random_point.global_position
		item.item_collected.connect(_on_collectable_collected)
		get_tree().current_scene.add_child(item)
		active_collectables.append(item)

func _spawn_potion(available_points: Array[Node2D]):
	if active_potions.size() >= max_potions or potion_scenes.is_empty():
		return
	
	var random_point = available_points[randi() % available_points.size()]
	var random_potion = potion_scenes[randi() % potion_scenes.size()]
	
	var item = random_potion["scene"].instantiate()
	if item is BaseItem:
		item.position = random_point.global_position
		item.item_collected.connect(_on_potion_collected)
		get_tree().current_scene.add_child(item)
		active_potions.append(item)

func get_available_spawn_points() -> Array[Node2D]:
	var available_points: Array[Node2D] = []
	var min_distance = 100.0
	
	for point in spawn_points:
		if not point or not is_instance_valid(point):
			continue
			
		var is_available = true
		
		# Verificar distancia con items coleccionables
		for item in active_collectables:
			if item and is_instance_valid(item):
				if point.global_position.distance_to(item.global_position) < min_distance:
					is_available = false
					break
		
		# Verificar distancia con pociones
		if is_available:
			for item in active_potions:
				if item and is_instance_valid(item):
					if point.global_position.distance_to(item.global_position) < min_distance:
						is_available = false
						break
		
		if is_available:
			available_points.append(point)
	
	return available_points

func _on_collectable_collected(item: BaseItem):
	if item in active_collectables:
		active_collectables.erase(item)

func _on_potion_collected(item: BaseItem):
	if item in active_potions:
		active_potions.erase(item)

func _start_spawn_timer():
	var wait_time = randf_range(min_spawn_time, max_spawn_time)
	spawn_timer.wait_time = wait_time
	spawn_timer.start()

# Función para forzar spawn de un item específico (para testing)
func spawn_specific_collectable(collectable_type: CollectableItem.CollectableType, spawn_point: Node2D):
	if not collectable_scene or not spawn_point:
		return
	
	var item = collectable_scene.instantiate()
	if item is CollectableItem:
		item.collectable_type = collectable_type
		item.position = spawn_point.global_position
		item.item_collected.connect(_on_collectable_collected)
		get_tree().current_scene.add_child(item)
		active_collectables.append(item)

func spawn_specific_potion(potion_scene: PackedScene, spawn_point: Node2D):
	if not potion_scene or not spawn_point:
		return
	
	var item = potion_scene.instantiate()
	if item is BaseItem:
		item.position = spawn_point.global_position
		item.item_collected.connect(_on_potion_collected)
		get_tree().current_scene.add_child(item)
		active_potions.append(item)

func clear_all_items():
	# Función para limpiar todos los items activos
	for item in active_collectables:
		if item and is_instance_valid(item):
			item.queue_free()
	active_collectables.clear()
	
	for item in active_potions:
		if item and is_instance_valid(item):
			item.queue_free()
	active_potions.clear()
