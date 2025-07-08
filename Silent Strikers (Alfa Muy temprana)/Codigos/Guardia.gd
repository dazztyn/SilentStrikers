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

## --- Variables de patrullaje mejoradas ---
@export var min_patrol_distance = 200.0    # Aumentado para más variedad
@export var max_patrol_distance = 500.0    # Rango máximo para evitar puntos muy lejanos
@export var preferred_patrol_distance = 300.0  # Distancia preferida
@export var patrol_wait_time = 0.3
var patrol_timer = 0.0
var is_waiting_at_patrol_point = false

## --- Sistema anti-stuck ---
var last_position = Vector2.ZERO
var stuck_check_timer = 0.0
var stuck_check_interval = 2.0
var stuck_threshold = 20.0
var stuck_counter = 0
var max_stuck_attempts = 3
var force_movement_timer = 0.0

## --- Cache para optimización ---
var cached_nav_bounds: Rect2
var cached_nav_polygons: Array[PackedVector2Array]
var nav_cache_valid = false

## --- Sistema de puntos de patrulla mejorado ---
var patrol_points: Array[Vector2] = []
var current_patrol_index = 0
var last_visited_points: Array[int] = []  # Historial de puntos visitados
var max_history_size = 3  # Evitar los últimos 3 puntos visitados

func _ready():
	player = Singleton.devolver_player()
	add_to_group("GuardiasM1")
	line_of_sight.add_exception(self)
	generar_cono_de_vision()

	if navigation_region == null:
		print("[ERROR] ¡No se ha asignado un NavigationRegion2D al guardia!")
		set_physics_process(false)
		return
	
	# Configurar NavigationAgent2D
	navigation_agent.path_desired_distance = 15.0
	navigation_agent.target_desired_distance = 25.0
	navigation_agent.path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_EDGECENTERED
	
	# Validar y cachear la configuración de navegación
	if not _validate_navigation_setup():
		print("[ERROR] La configuración de navegación no es válida!")
		set_physics_process(false)
		return
	
	# Generar puntos de patrulla con mejor distribución
	_generate_patrol_points()
	
	call_deferred("_set_next_patrol_point")
	set_state(State.PATROLLING)
	
	# Inicializar sistema anti-stuck
	last_position = global_position
	stuck_check_timer = stuck_check_interval

func _validate_navigation_setup() -> bool:
	if navigation_region == null:
		print("[ERROR] NavigationRegion2D es null")
		return false
	
	if navigation_region.navigation_polygon == null:
		print("[ERROR] NavigationPolygon es null")
		return false
	
	var nav_poly = navigation_region.navigation_polygon
	if nav_poly.get_outline_count() == 0:
		print("[ERROR] NavigationPolygon no tiene contornos")
		return false
	
	# Cachear polígonos y bounds
	cached_nav_polygons.clear()
	var first_outline = nav_poly.get_outline(0)
	if first_outline.is_empty():
		print("[ERROR] El primer contorno está vacío")
		return false
	
	cached_nav_bounds = Rect2(first_outline[0], Vector2.ZERO)
	
	for i in range(nav_poly.get_outline_count()):
		var outline = nav_poly.get_outline(i)
		if outline.is_empty():
			continue
		cached_nav_polygons.append(outline)
		for point in outline:
			cached_nav_bounds = cached_nav_bounds.expand(point)
	
	nav_cache_valid = true
	print("[INFO] Navegación configurada correctamente. Bounds: ", cached_nav_bounds)
	
	return true

func _generate_patrol_points():
	patrol_points.clear()
	var nav_region_pos = navigation_region.global_position
	
	# Usar grilla más espaciada para mejor distribución
	var grid_size = 120.0  # Aumentado para más separación
	var points_added = 0
	
	# Generar puntos en grilla regular
	for x in range(int(cached_nav_bounds.position.x), int(cached_nav_bounds.end.x), int(grid_size)):
		for y in range(int(cached_nav_bounds.position.y), int(cached_nav_bounds.end.y), int(grid_size)):
			var test_point = Vector2(x, y)
			
			# Verificar si está dentro de algún polígono
			for polygon in cached_nav_polygons:
				if Geometry2D.is_point_in_polygon(test_point, polygon):
					var global_point = test_point + nav_region_pos
					patrol_points.append(global_point)
					points_added += 1
					break
	
	# Añadir puntos adicionales en posiciones estratégicas (esquinas, centro)
	_add_strategic_points(nav_region_pos)
	
	# Añadir algunos puntos aleatorios para más variedad
	_add_random_points(nav_region_pos, 5)
	
	print("[INFO] Puntos de patrulla generados: ", patrol_points.size())
	
	# Filtrar puntos demasiado cercanos entre sí
	_filter_close_points()
	
	print("[INFO] Puntos de patrulla después del filtro: ", patrol_points.size())

func _add_strategic_points(nav_region_pos: Vector2):
	var strategic_positions = [
		cached_nav_bounds.position,                                    # Esquina superior izquierda
		Vector2(cached_nav_bounds.end.x, cached_nav_bounds.position.y), # Esquina superior derecha
		cached_nav_bounds.end,                                         # Esquina inferior derecha
		Vector2(cached_nav_bounds.position.x, cached_nav_bounds.end.y), # Esquina inferior izquierda
		cached_nav_bounds.get_center(),                                # Centro
		Vector2(cached_nav_bounds.get_center().x, cached_nav_bounds.position.y), # Centro superior
		Vector2(cached_nav_bounds.get_center().x, cached_nav_bounds.end.y),      # Centro inferior
		Vector2(cached_nav_bounds.position.x, cached_nav_bounds.get_center().y), # Centro izquierdo
		Vector2(cached_nav_bounds.end.x, cached_nav_bounds.get_center().y)       # Centro derecho
	]
	
	for pos in strategic_positions:
		for polygon in cached_nav_polygons:
			if Geometry2D.is_point_in_polygon(pos, polygon):
				var global_point = pos + nav_region_pos
				patrol_points.append(global_point)
				break

func _add_random_points(nav_region_pos: Vector2, count: int):
	for i in range(count):
		for attempt in range(10):  # Máximo 10 intentos por punto
			var random_point = Vector2(
				randf_range(cached_nav_bounds.position.x, cached_nav_bounds.end.x),
				randf_range(cached_nav_bounds.position.y, cached_nav_bounds.end.y)
			)
			
			for polygon in cached_nav_polygons:
				if Geometry2D.is_point_in_polygon(random_point, polygon):
					var global_point = random_point + nav_region_pos
					patrol_points.append(global_point)
					break

func _filter_close_points():
	var filtered_points: Array[Vector2] = []
	var min_distance_between_points = 80.0  # Distancia mínima entre puntos de patrulla
	
	for point in patrol_points:
		var too_close = false
		for existing_point in filtered_points:
			if point.distance_to(existing_point) < min_distance_between_points:
				too_close = true
				break
		
		if not too_close:
			filtered_points.append(point)
	
	patrol_points = filtered_points

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
	
	# Sistema anti-stuck
	_check_stuck_state(delta)
	
	forward = (navigation_agent.get_next_path_position() - global_position).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT.rotated(rotation)
		
	flashlight.rotation = rotation2
	flashlight.position = Vector2(197, 30).rotated(rotation2)

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
	
	if player_in_vision_cone:
		check_line_of_sight()

	var move_dir = velocity.normalized()
	if move_dir != Vector2.ZERO:
		rotation2 = move_dir.angle()
		vision_cone.rotation = rotation2
		line_of_sight.rotation = rotation2
		flashlight.rotation = rotation2

		var horizontal = false
		if move_dir.x > 0 and (move_dir.y > -0.3 and move_dir.y < 0.3):
			animations.play("Derecha")
			horizontal = true
		elif move_dir.x < 0 and (move_dir.y > -0.3 and move_dir.y < 0.3):
			animations.play("Izquierda")
			horizontal = true
			flashlight.position = Vector2(197, 30-60).rotated(rotation2)
		if not horizontal:
			if move_dir.y > 0:
				animations.play("Abajo")
			elif move_dir.y < 0:
				animations.play("Arriba")
				flashlight.position = Vector2(197-30, 30).rotated(rotation2)

	if abs(player.position.x - position.x) < 70 and abs(player.position.y - position.y) < 120 and hit_cooldown < 0 and not player.invisible():
		player.perder_salud(1)
		hit_cooldown = 1.5
	
	move_and_slide()

func _check_stuck_state(delta):
	stuck_check_timer -= delta
	
	if stuck_check_timer <= 0.0:
		stuck_check_timer = stuck_check_interval
		
		var distance_moved = global_position.distance_to(last_position)
		
		if distance_moved < stuck_threshold and current_state == State.PATROLLING:
			stuck_counter += 1
			print("[WARNING] Guardia posiblemente atascado. Movimiento: ", distance_moved, " Contador: ", stuck_counter)
			
			if stuck_counter >= max_stuck_attempts:
				print("[INFO] Guardia atascado detectado, aplicando corrección")
				_unstuck_guard()
				stuck_counter = 0
		else:
			stuck_counter = 0
		
		last_position = global_position

func _unstuck_guard():
	# Saltar a un punto lejano
	var far_points = _get_far_points()
	if far_points.size() > 0:
		var random_point = far_points[randi() % far_points.size()]
		navigation_agent.target_position = random_point
		print("[INFO] Saltando a punto lejano: ", random_point)
		is_waiting_at_patrol_point = false
		return
	
	# Movimiento forzado en dirección aleatoria
	var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var escape_point = global_position + random_direction * preferred_patrol_distance
	navigation_agent.target_position = escape_point
	print("[INFO] Movimiento de escape a: ", escape_point)
	
	velocity = random_direction * speed * 0.5
	force_movement_timer = 1.0

func _get_far_points() -> Array[Vector2]:
	var far_points: Array[Vector2] = []
	var current_pos = global_position
	
	for point in patrol_points:
		var distance = current_pos.distance_to(point)
		if distance >= preferred_patrol_distance:
			far_points.append(point)
	
	return far_points

func _process_patrolling(delta):
	if force_movement_timer > 0:
		force_movement_timer -= delta
		if force_movement_timer <= 0:
			velocity = Vector2.ZERO
		return
	
	if is_waiting_at_patrol_point:
		patrol_timer -= delta
		velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
		if patrol_timer <= 0.0:
			is_waiting_at_patrol_point = false
			_set_next_patrol_point()
	else:
		if navigation_agent.is_navigation_finished():
			is_waiting_at_patrol_point = true
			patrol_timer = patrol_wait_time
		else:
			_update_navigation_velocity(delta)

func _process_chasing(delta):
	chasing_timer -= delta
	if chasing_timer <= 0.0:
		set_state(State.SEARCHING)
		search_timer = search_duration
		return
		
	navigation_agent.target_position = player.global_position
	last_known_player_position = player.global_position
	_update_navigation_velocity(delta)

func _process_searching(delta):
	search_timer -= delta
	if search_timer <= 0.0:
		set_state(State.PATROLLING)
		_set_next_patrol_point()
		return
	if navigation_agent.is_navigation_finished():
		var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
		var random_point = last_known_player_position + random_direction * randf_range(50, search_radius)
		navigation_agent.target_position = random_point
	_update_navigation_velocity(delta)

func _update_navigation_velocity(delta):
	if not navigation_agent.is_navigation_finished():
		var next_pos = navigation_agent.get_next_path_position()
		var dir = (next_pos - global_position).normalized()
		velocity = velocity.lerp(dir * speed, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)

func _set_next_patrol_point():
	if patrol_points.is_empty():
		print("[ERROR] No hay puntos de patrulla disponibles")
		return
	
	var current_pos = global_position
	var valid_candidates: Array[Dictionary] = []
	
	# Evaluar todos los puntos según criterios de distancia y historial
	for i in range(patrol_points.size()):
		var point = patrol_points[i]
		var distance = current_pos.distance_to(point)
		
		# Saltar puntos demasiado cercanos
		if distance < min_patrol_distance:
			continue
		
		# Saltar puntos demasiado lejanos
		if distance > max_patrol_distance:
			continue
		
		# Saltar puntos visitados recientemente
		if last_visited_points.has(i):
			continue
		
		# Calcular puntuación basada en distancia preferida
		var distance_score = 1.0 - abs(distance - preferred_patrol_distance) / preferred_patrol_distance
		distance_score = max(0.0, distance_score)
		
		valid_candidates.append({
			"index": i,
			"point": point,
			"distance": distance,
			"score": distance_score
		})
	
	# Si no hay candidatos válidos, limpiar historial y intentar de nuevo
	if valid_candidates.is_empty():
		last_visited_points.clear()
		print("[INFO] Limpiando historial de puntos visitados")
		
		# Buscar cualquier punto que esté en el rango mínimo
		for i in range(patrol_points.size()):
			var point = patrol_points[i]
			var distance = current_pos.distance_to(point)
			
			if distance >= min_patrol_distance:
				valid_candidates.append({
					"index": i,
					"point": point,
					"distance": distance,
					"score": distance / max_patrol_distance
				})
	
	if valid_candidates.is_empty():
		print("[WARNING] No se encontraron puntos válidos, usando punto más lejano")
		_use_farthest_point()
		return
	
	# Ordenar por puntuación (mejor a peor)
	valid_candidates.sort_custom(func(a, b): return a.score > b.score)
	
	# Seleccionar uno de los mejores 3 candidatos (para añadir variedad)
	var top_candidates = valid_candidates.slice(0, min(3, valid_candidates.size()))
	var selected = top_candidates[randi() % top_candidates.size()]
	
	# Actualizar historial
	last_visited_points.append(selected.index)
	if last_visited_points.size() > max_history_size:
		last_visited_points.pop_front()
	
	# Establecer objetivo
	navigation_agent.target_position = selected.point
	current_patrol_index = selected.index
	
	print("[INFO] Nuevo punto de patrulla: ", selected.point, " Distancia: ", selected.distance, " Puntuación: ", selected.score)

func _use_farthest_point():
	var farthest_point = patrol_points[0]
	var max_distance = 0.0
	var farthest_index = 0
	
	for i in range(patrol_points.size()):
		var distance = global_position.distance_to(patrol_points[i])
		if distance > max_distance:
			max_distance = distance
			farthest_point = patrol_points[i]
			farthest_index = i
	
	navigation_agent.target_position = farthest_point
	current_patrol_index = farthest_index
	print("[INFO] Usando punto más lejano: ", farthest_point, " Distancia: ", max_distance)

func _on_player_detected():
	print("¡Jugador DETECTADO!")
	set_state(State.CHASING)
	chasing_timer = chase_duration
	search_timer = 0.0
	is_waiting_at_patrol_point = false
	stuck_counter = 0

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
	line_of_sight.target_position = to_local(player.global_position)
	line_of_sight.force_raycast_update()
	if not line_of_sight.is_colliding():
		if current_state != State.CHASING:
			_on_player_detected()
		last_known_player_position = player.global_position
		set_state(State.CHASING)
	else:
		_on_player_lost()

func set_state(new_state):
	if new_state == current_state:
		return
	current_state = new_state
	if state_label:
		match current_state:
			State.PATROLLING:
				state_label.text = "Patrolling"
			State.CHASING:
				state_label.text = "CHASING!"
			State.SEARCHING:
				state_label.text = "Searching..."
