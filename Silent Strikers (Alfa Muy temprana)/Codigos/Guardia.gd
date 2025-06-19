extends CharacterBody2D

## --- Variables de Movimiento y Navegación ---
var speed = 300
var acceleration = 7.0
var forward
var player: CharacterBody2D
var rotation2 = rotation #rotación usada para la vision, No es la rotación del guardia
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@export var patrol_area_node: NodePath # Para asignar la ZonaDePatrulla desde el editor
@export var patrol_idle_duration = 3.0 # Segundos que espera al llegar a un punto
var patrol_area: Area2D
var patrol_idle_timer = 0.0

## --- Variables de Visión y Detección ---
var vision_range = 300.0
var vision_angle_degrees = 90.0
var wall_collision_mask = 1
@onready var vision_raycast: RayCast2D = $VisionRayCast
@onready var vision_area: Area2D = $Vision

## --- Variables de Estado ---
enum State { PATROLLING, CHASING, SEARCHING }
var current_state = State.PATROLLING
var patrol_index = 0
var player_detected = false
var last_known_player_position = Vector2.ZERO

## --- Tiempo de búsqueda ---
var search_duration = 10.0 # Segundos que espera buscando
var search_timer = 0.0

## --- Tiempo de persecución ---
var chase_duration = 8.0 # Segundos que dura el estado de persecución activado después de obtener la última posición del jugador
var chasing_timer = 0.0

## --- Dibujo y Animación ---
@export var draw_vision_cone: bool = true
@export var vision_cone_color: Color = Color(1, 1, 0, 0.3)
@onready var animations: AnimatedSprite2D = get_node("AnimatedSprite2D")

func _ready():
	player = get_node("../Ladron")
	add_to_group("GuardiasMP")
	vision_raycast.add_exception(self)
	vision_raycast.collision_mask = wall_collision_mask | player.collision_layer
	if patrol_area_node:
		patrol_area = get_node_or_null(patrol_area_node)
	if not patrol_area:
		print("No se asignó área de patrullaje. Usando puntos fijos.")
		_set_next_patrol_point()
	else:
		print("Usando área de patrullaje dinámica.")
		_set_new_random_destination()

func _process(delta: float) -> void:
	vision_raycast.target_position = to_local(player.global_position)
	vision_raycast.force_raycast_update()	
	
func _physics_process(delta):
	if player.invisible():
		current_state = State.PATROLLING
	forward = (navigation_agent.get_next_path_position() - global_position).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT.rotated(rotation) # fallback si no hay camino
	check_vision(forward)
	
	match current_state:
		State.PATROLLING:
			vision_range = 300
			vision_angle_degrees = 90
			speed = 200
			_process_patrolling(delta)
		State.CHASING:
			vision_range = 600
			vision_angle_degrees = 120
			speed = 300
			_process_chasing(delta)
		State.SEARCHING:
			vision_range = 400
			vision_angle_degrees = 90
			speed = 200
			_process_searching(delta)

	# Rotación
	var move_dir = velocity.normalized()
	if move_dir != Vector2.ZERO:
		var horizontal = false
		if move_dir.x > 0 and (move_dir.y > -0.3 and move_dir.y < 0.3):
			animations.play("Derecha")
			horizontal = true
		elif move_dir.x < 0 and (move_dir.y > -0.3 and move_dir.y < 0.3):
			animations.play("Izquierda")
			horizontal = true
		if not horizontal:
			if move_dir.y > 0  or (move_dir.y > 0 and move_dir.x < 0) or (move_dir.y > 0 and move_dir.x > 0):
				animations.play("Abajo")
			elif move_dir.y < 0 or (move_dir.y < 0 and move_dir.x < 0) or (move_dir.y < 0 and move_dir.x > 0):
				animations.play("Arriba")
		rotation2 = move_dir.angle()
	
	move_and_slide()
	
	if draw_vision_cone:
		queue_redraw()


func _process_patrolling(delta):
	if patrol_area:
		if navigation_agent.is_navigation_finished():
			velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
			patrol_idle_timer -= delta
			
			if patrol_idle_timer <= 0:
				_set_new_random_destination()
		else:
			_update_navigation_velocity(delta)

func _process_chasing(delta):
	chasing_timer -= delta
	navigation_agent.target_position = last_known_player_position
	if navigation_agent.is_navigation_finished():
		# Si llegó a la última posición conocida y no ve al jugador, inicia búsqueda
		if not player_detected:
			current_state = State.SEARCHING
			search_timer = search_duration

	_update_navigation_velocity(delta)


func _process_searching(delta):
	search_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
	
	if search_timer <= 0.0:
		current_state = State.PATROLLING
		_set_next_patrol_point()

func _update_navigation_velocity(delta):
	if not navigation_agent.is_navigation_finished():
		var next_pos = navigation_agent.get_next_path_position()
		var dir = (next_pos - global_position).normalized()
		velocity = velocity.lerp(dir * speed, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)


func _set_new_random_destination():
	if not patrol_area: return

	# Obtenemos los límites del área de patrullaje en coordenadas globales
	var patrol_shape_node = patrol_area.get_node_or_null("CollisionShape2D")
	if not patrol_shape_node: return
	
	var global_bounds = patrol_shape_node.global_transform * patrol_shape_node.shape.get_rect()
	
	var global_random_point = Vector2(
		randf_range(global_bounds.position.x, global_bounds.end.x),
		randf_range(global_bounds.position.y, global_bounds.end.y)
	)
	
	# La ajustamos al punto caminable más cercano para evitar errores
	var map = get_world_2d().navigation_map
	var safe_point = NavigationServer2D.map_get_closest_point(map, global_random_point)
	
	navigation_agent.target_position = safe_point
	patrol_idle_timer = patrol_idle_duration


func check_vision(guard_forward_direction: Vector2):
	var was_detected = player_detected
	var detected_now = false

	var dir_to_player = player.global_position - global_position
	var dist = dir_to_player.length()

	if dist <= vision_range:
		var dir_norm = dir_to_player.normalized()
		var dot = guard_forward_direction.dot(dir_norm)
		var limit_dot = cos(deg_to_rad(vision_angle_degrees / 2.0))
		
		if current_state == State.SEARCHING:
			if dot < vision_angle_degrees/360:
				# ACTUALIZA SIEMPRE el raycast
				if (vision_raycast.is_colliding() and vision_raycast.get_collider() == player):
					detected_now = true
					last_known_player_position = player.global_position
		else:
			if dot > limit_dot:
				# ACTUALIZA SIEMPRE el raycast
				if (vision_raycast.is_colliding() and vision_raycast.get_collider() == player) or (chasing_timer > 0 and not player.invisible()):
					detected_now = true
					last_known_player_position = player.global_position
					current_state = State.CHASING

	player_detected = detected_now
	if player_detected and not was_detected:
		_on_player_detected()
	elif not player_detected and was_detected:
		_on_player_lost()

func _on_player_detected():
	print("¡Jugador DETECTADO!")
	current_state = State.CHASING
	chasing_timer = chase_duration
	search_timer = 0.0

func _on_player_lost():
	print("¡Jugador Perdido¡")

func _draw():
	var half_angle = deg_to_rad(vision_angle_degrees / 2.0)
	var segments = 20
	var points = PackedVector2Array()

	for i in range(segments + 1):
		var angle = -half_angle + ((half_angle) * 2.0 * i / segments)
		points.append(Vector2.RIGHT.rotated(angle+rotation2) * vision_range)

	if points.size() > 0:
		draw_line(Vector2.ZERO, points[0], vision_cone_color, 1.0)
		draw_polyline(points, vision_cone_color, 1.0)
		draw_line(Vector2.ZERO, points[-1], vision_cone_color, 1.0)
