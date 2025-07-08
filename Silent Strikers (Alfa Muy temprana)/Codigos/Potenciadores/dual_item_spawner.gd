# Sistema de spawneo para coleccionables y potenciadores (CON DEBUG)
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
	print("🎮 DUAL ITEM SPAWNER INICIADO")
	print("📍 Spawn points configurados: ", spawn_points.size())
	print("📦 Collectable scene: ", collectable_scene != null)
	print("⚡ Speed potion scene: ", speed_potion_scene != null)
	print("👻 Invisibility potion scene: ", invisibility_potion_scene != null)
	
	# Configurar escenas de pociones
	if speed_potion_scene:
		potion_scenes.append({"scene": speed_potion_scene, "name": "Speed Potion"})
	if invisibility_potion_scene:
		potion_scenes.append({"scene": invisibility_potion_scene, "name": "Invisibility Potion"})
	
	print("🧪 Pociones configuradas: ", potion_scenes.size())
	
	# Configurar timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_spawn_random_item)
	add_child(spawn_timer)
	
	# Verificar spawn points
	if spawn_points.is_empty():
		print("⚠️ No hay spawn points configurados, buscando grupo 'spawn_point'")
		collect_spawn_points()
	
	print("📍 Spawn points finales: ", spawn_points.size())
	
	# Iniciar spawneo
	print("⏰ Iniciando timer de spawn...")
	_start_spawn_timer()

func collect_spawn_points():
	var points = get_tree().get_nodes_in_group("spawn_point")
	spawn_points = points
	print("📍 Puntos encontrados en grupo 'spawn_point': ", points.size())

func _spawn_random_item():
	print("🎲 Intentando spawnear item...")
	
	var available_points = get_available_spawn_points()
	print("📍 Puntos disponibles: ", available_points.size())
	
	if available_points.is_empty():
		print("❌ No hay puntos disponibles")
		_start_spawn_timer()
		return
	
	# Decidir qué tipo de item spawnear
	var random_chance = randi() % 100
	print("🎯 Probabilidad: ", random_chance)
	
	if random_chance < collectable_spawn_chance:
		print("💎 Intentando spawnear coleccionable...")
		_spawn_collectable(available_points)
	else:
		print("🧪 Intentando spawnear poción...")
		_spawn_potion(available_points)
	
	_start_spawn_timer()

func _spawn_collectable(available_points: Array[Node2D]):
	print("💎 Spawn coleccionable - Activos: ", active_collectables.size(), "/", max_collectables)
	
	if active_collectables.size() >= max_collectables:
		print("❌ Máximo de coleccionables alcanzado")
		return
		
	if not collectable_scene:
		print("❌ No hay escena de coleccionable configurada")
		return
	
	var random_point = available_points[randi() % available_points.size()]
	var random_type = collectable_types[randi() % collectable_types.size()]
	
	print("📍 Spawneando en posición: ", random_point.global_position)
	print("🎯 Tipo: ", random_type)
	
	var item = collectable_scene.instantiate()
	if item is CollectableItem:
		item.collectable_type = random_type
		item.position = random_point.global_position
		item.item_collected.connect(_on_collectable_collected)
		get_tree().current_scene.add_child(item)
		active_collectables.append(item)
		print("✅ Item coleccionable spawneado: ", item.item_name)
	else:
		print("❌ El item no es CollectableItem")
		item.queue_free()

func _spawn_potion(available_points: Array[Node2D]):
	print("🧪 Spawn poción - Activos: ", active_potions.size(), "/", max_potions)
	
	if active_potions.size() >= max_potions:
		print("❌ Máximo de pociones alcanzado")
		return
		
	if potion_scenes.is_empty():
		print("❌ No hay escenas de poción configuradas")
		return
	
	var random_point = available_points[randi() % available_points.size()]
	var random_potion = potion_scenes[randi() % potion_scenes.size()]
	
	print("📍 Spawneando poción en posición: ", random_point.global_position)
	print("🎯 Tipo: ", random_potion["name"])
	
	var item = random_potion["scene"].instantiate()
	if item is BaseItem:
		item.position = random_point.global_position
		item.item_collected.connect(_on_potion_collected)
		get_tree().current_scene.add_child(item)
		active_potions.append(item)
		print("✅ Poción spawneada: ", random_potion["name"])
	else:
		print("❌ El item no es BaseItem")
		item.queue_free()

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
	print("✅ Item coleccionable recolectado: ", item.item_name)

func _on_potion_collected(item: BaseItem):
	if item in active_potions:
		active_potions.erase(item)
	print("✅ Poción recolectada: ", item.item_name)

func _start_spawn_timer():
	var wait_time = randf_range(min_spawn_time, max_spawn_time)
	spawn_timer.wait_time = wait_time
	spawn_timer.start()
	print("⏰ Timer iniciado: ", wait_time, " segundos")

# Función para testing manual
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				print("🧪 SPAWN FORZADO - Coleccionable")
				var points = get_available_spawn_points()
				if not points.is_empty():
					_spawn_collectable(points)
			KEY_F2:
				print("🧪 SPAWN FORZADO - Poción")
				var points = get_available_spawn_points()
				if not points.is_empty():
					_spawn_potion(points)
