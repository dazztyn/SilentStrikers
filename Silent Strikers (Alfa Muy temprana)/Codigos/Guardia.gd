extends CharacterBody2D

@onready var state_label: Label = $StateLabel #DEBUG

## --- Variables de Movimiento y Navegación ---
var speed = 300
var acceleration = 7.0
var hit_cooldown = 1.5
var forward
@export var navigation_region: NavigationRegion2D
var player = null
var rotation2 = rotation
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animations: AnimatedSprite2D = get_node("AnimatedSprite2D")

## --- Variables de Visión y Detección ---
var wall_collision_mask = 1
@onready var line_of_sight: RayCast2D = $VisionRayCast
@onready var vision_cone: Area2D = $Vision
@onready var flashlight: PointLight2D = $FlashLight
var player_in_vision_cone = false

## --- Variables de Estado ---
enum State { PATROLLING, CHASING, SEARCHING }
var current_state = State.PATROLLING
var last_known_player_position = Vector2.ZERO

## --- Tiempo de búsqueda ---
@export var search_radius = 200.0 
var search_duration = 10.0
var search_timer = 0.0

## --- Tiempo de persecución ---
var chase_duration = 8.0
var chasing_timer = 0.0

## --- Optimización de patrullaje ---
var patrol_wait_time = 0.3  # Tiempo de espera en puntos de patrulla
var patrol_wait_timer = 0.0
var cached_patrol_points: Array[Vector2] = []
var current_patrol_index = 0
var navigation_bounds_cached = false

func _ready():
	player = Singleton.devolver_player()
	add_to_group("GuardiasM1")
	line_of_sight.add_exception(self)
	generar_cono_de_vision() # Genera el polígono del cono visual

	if navigation_region == null:
		print("[ERROR] ¡No se ha asignado un NavigationRegion2D al guardia!")
		set_physics_process(false)
		return
	
	call_deferred("_set_next_patrol_point")
	set_state(State.PATROLLING)

func generar_cono_de_vision(fov_degrees := 90, radio := 200.0, resolucion := 12):
	var fov = deg_to_rad(fov_degrees)
	var puntos = [Vector2.ZERO]
	for i in range(resolucion + 1):
		var angulo = -fov / 2 + (fov * i / float(resolucion))
		var punto = Vector2(cos(angulo), sin(angulo)) * radio
		puntos.append(punto)

	$Vision/CollisionPolygon2D.polygon = puntos
	$Vision/Polygon2D.polygon = puntos


func _physics_process(delta: float):
	hit_cooldown -= delta
	
	# Calcular forward solo si es necesario
	if not navigation_agent.is_navigation_finished():
		forward = (navigation_agent.get_next_path_position() - global_position).normalized()
	elif forward == Vector2.ZERO:
		forward = Vector2.RIGHT.rotated(rotation)
	
	# Optimizar posicionamiento de linterna
	_update_flashlight_position()

	# Procesar estado actual
	match current_state:
		State.PATROLLING:
			speed = 200
			_process_patrolling(delta)
		State.CHASING:
			speed = 300
			_process_chasing(delta)
		State.SEARCHING:
			speed = 200
			_process_searching(delta)
	
	# Verificar línea de visión solo si el jugador está en el cono
	if player_in_vision_cone:
		check_line_of_sight()

	# Optimizar animaciones y rotaciones
	_update_movement_animations()
	
	# Verificar daño al jugador
	_check_player_damage()
	
	move_and_slide()

func _update_flashlight_position():
	"""Actualiza la posición de la linterna de forma optimizada"""
	flashlight.rotation = rotation2
	flashlight.position = Vector2(197, 30).rotated(rotation2)

func _update_movement_animations():
	"""Actualiza animaciones y rotaciones basadas en el movimiento"""
	var move_dir = velocity.normalized()
	if move_dir != Vector2.ZERO:
		rotation2 = move_dir.angle()
		vision_cone.rotation = rotation2
		line_of_sight.rotation = rotation2
		flashlight.rotation = rotation2

		var horizontal = false
		if move_dir.x > 0 and abs(move_dir.y) < 0.3:
			animations.play("Derecha")
			horizontal = true
		elif move_dir.x < 0 and abs(move_dir.y) < 0.3:
			animations.play("Izquierda")
			horizontal = true
			flashlight.position = Vector2(197, 30-60).rotated(rotation2)
		
		if not horizontal:
			if move_dir.y > 0:
				animations.play("Abajo")
			elif move_dir.y < 0:
				animations.play("Arriba")
				flashlight.position = Vector2(197-30, 30).rotated(rotation2)

func _check_player_damage():
	"""Verifica si el jugador debe recibir daño"""
	if abs(player.position.x - position.x) < 70 and abs(player.position.y - position.y) < 120 and hit_cooldown < 0 and not player.invisible():
		player.perder_salud(1)
		hit_cooldown = 1.5

func _process_patrolling(delta):
	if navigation_agent.is_navigation_finished():
		# Esperar en el punto de patrulla antes de moverse al siguiente
		patrol_wait_timer += delta
		if patrol_wait_timer >= patrol_wait_time:
			patrol_wait_timer = 0.0
			_set_next_patrol_point()
	else:
		# Resetear el timer si nos estamos moviendo
		patrol_wait_timer = 0.0
	
	_update_navigation_velocity(delta)

func _process_chasing(delta):
	chasing_timer -= delta
	navigation_agent.target_position = last_known_player_position
	_update_navigation_velocity(delta)

func _process_searching(delta):
	search_timer -= delta
	if search_timer <= 0.0:
		set_state(State.PATROLLING)
		patrol_wait_timer = 0.0  # Resetear timer de patrulla
		_set_next_patrol_point()
		return
	
	if navigation_agent.is_navigation_finished():
		# Generar punto de búsqueda de forma más eficiente
		var search_angle = randf_range(0, TAU)
		var search_distance = randf_range(search_radius * 0.5, search_radius)
		var search_point = last_known_player_position + Vector2.RIGHT.rotated(search_angle) * search_distance
		
		# Obtener punto válido más cercano
		if navigation_region and navigation_region.navigation_polygon:
			var map = navigation_region.get_navigation_map()
			var closest_valid_point = NavigationServer2D.map_get_closest_point(map, search_point - navigation_region.global_position)
			if closest_valid_point != Vector2.ZERO:
				navigation_agent.target_position = closest_valid_point + navigation_region.global_position
			else:
				navigation_agent.target_position = search_point
		else:
			navigation_agent.target_position = search_point
	
	_update_navigation_velocity(delta)

func _update_navigation_velocity(delta):
	if not navigation_agent.is_navigation_finished():
		var next_pos = navigation_agent.get_next_path_position()
		var dir = (next_pos - global_position).normalized()
		velocity = velocity.lerp(dir * speed, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)

func _set_next_patrol_point():
	if navigation_region == null or navigation_region.navigation_polygon == null:
		print("[Guardia] NavigationRegion2D o su polígono no están asignados.")
		return

	# Cachear puntos de patrulla si no se han calculado
	if not navigation_bounds_cached:
		_cache_patrol_points()
		if cached_patrol_points.is_empty():
			print("[Guardia] No se pudieron cachear puntos de patrulla válidos.")
			return
	
	# Usar puntos pre-calculados en lugar de generación aleatoria
	if cached_patrol_points.size() > 0:
		current_patrol_index = (current_patrol_index + 1) % cached_patrol_points.size()
		var target_point = cached_patrol_points[current_patrol_index]
		navigation_agent.target_position = target_point + navigation_region.global_position
	else:
		print("[Guardia] No hay puntos de patrulla disponibles.")

func _cache_patrol_points():
	"""Pre-calcula puntos de patrulla válidos para mejorar rendimiento"""
	cached_patrol_points.clear()
	
	var nav_poly = navigation_region.navigation_polygon
	if nav_poly.get_outline_count() == 0:
		print("[Guardia] El NavigationPolygon no tiene contornos definidos.")
		return

	var overall_bounds: Rect2
	var first_outline = nav_poly.get_outline(0)
	if not first_outline.is_empty():
		overall_bounds = Rect2(first_outline[0], Vector2.ZERO)
	else:
		print("[Guardia] El primer contorno de la región de navegación está vacío.")
		return
		
	for i in range(nav_poly.get_outline_count()):
		for point in nav_poly.get_outline(i):
			overall_bounds = overall_bounds.expand(point)

	# Generar puntos de patrulla de forma más eficiente usando una grid
	var grid_size = 8  # Divisiones por lado para generar puntos candidatos
	var map = navigation_region.get_navigation_map()
	
	for x in range(grid_size):
		for y in range(grid_size):
			var progress_x = x / float(grid_size - 1)
			var progress_y = y / float(grid_size - 1)
			
			var candidate_point = Vector2(
				lerp(overall_bounds.position.x, overall_bounds.end.x, progress_x),
				lerp(overall_bounds.position.y, overall_bounds.end.y, progress_y)
			)
			
			# Verificar si el punto está dentro del polígono
			for outline_index in range(nav_poly.get_outline_count()):
				var polygon_points = nav_poly.get_outline(outline_index)
				
				if Geometry2D.is_point_in_polygon(candidate_point, polygon_points):
					var closest_valid_point = NavigationServer2D.map_get_closest_point(map, candidate_point)
					
					if closest_valid_point != Vector2.ZERO:
						cached_patrol_points.append(closest_valid_point)
						break
	
	# Agregar algunos puntos aleatorios adicionales para variedad
	for i in range(5):
		var random_point = Vector2(
			randf_range(overall_bounds.position.x, overall_bounds.end.x),
			randf_range(overall_bounds.position.y, overall_bounds.end.y)
		)
		
		for outline_index in range(nav_poly.get_outline_count()):
			var polygon_points = nav_poly.get_outline(outline_index)
			
			if Geometry2D.is_point_in_polygon(random_point, polygon_points):
				var closest_valid_point = NavigationServer2D.map_get_closest_point(map, random_point)
				
				if closest_valid_point != Vector2.ZERO:
					cached_patrol_points.append(closest_valid_point)
					break
	
	navigation_bounds_cached = true
	print("[Guardia] Se cachearon %d puntos de patrulla." % cached_patrol_points.size())

func _on_player_detected():
	print("¡Jugador DETECTADO!")
	set_state(State.CHASING)
	chasing_timer = chase_duration
	search_timer = 0.0

func _on_player_lost():
	if current_state == State.CHASING:
		set_state(State.SEARCHING)
		search_timer = search_duration

func _on_vision_body_entered(body: Node2D):
	if body == player:
		player_in_vision_cone = true
		print("Jugador entró en el cono de visión.")

func _on_vision_body_exited(body: Node2D):
	if body == player:
		player_in_vision_cone = false
		print("Jugador salió del cono de visión.")
		if current_state == State.CHASING:
			_on_player_lost()

func check_line_of_sight():
	"""Verifica línea de visión de forma optimizada"""
	line_of_sight.target_position = to_local(player.global_position)
	line_of_sight.force_raycast_update()
	
	if not line_of_sight.is_colliding():
		# Jugador visible
		last_known_player_position = player.global_position
		if current_state != State.CHASING:
			_on_player_detected()
	else:
		# Jugador no visible
		if current_state == State.CHASING:
			_on_player_lost()

func set_state(new_state):
	if new_state == current_state:
		return
		
	current_state = new_state
	
	# Resetear timers específicos según el estado
	match new_state:
		State.PATROLLING:
			patrol_wait_timer = 0.0
		State.CHASING:
			# No resetear timers específicos, mantener flujo
			pass
		State.SEARCHING:
			# No resetear timers específicos, mantener flujo
			pass
	
	# Actualizar label de debug
	if state_label:
		match current_state:
			State.PATROLLING:
				state_label.text = "Patrolling"
			State.CHASING:
				state_label.text = "CHASING!"
			State.SEARCHING:
				state_label.text = "Searching..."
