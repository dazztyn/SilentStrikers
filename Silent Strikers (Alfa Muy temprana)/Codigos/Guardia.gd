extends CharacterBody2D

## --- Variables de Movimiento y Navegación ---
var speed = 300
var acceleration = 7.0
var forward
@export var patrol_points: Array[NodePath] = []
var player: CharacterBody2D
var rotation2 = rotation #rotación usada para la vision, No es la rotación del guardia

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var vision_polygon := $Polygon2D

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
@onready var animations: AnimationPlayer = get_node("AnimationPlayer")

func _ready():
	player = get_node("../Ladron")
	add_to_group("Guardias")
	vision_raycast.add_exception(self)
	vision_raycast.collision_mask = wall_collision_mask | player.collision_layer

	_set_next_patrol_point()

func _process(delta: float) -> void:
	vision_raycast.target_position = to_local(player.global_position)
	vision_raycast.force_raycast_update()	
	
func _physics_process(delta):
	
	_update_vision_cone()

	
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
	# Patrulla normal
	if navigation_agent.is_navigation_finished():
		_set_next_patrol_point()
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


func _set_next_patrol_point():
	if patrol_points.size() == 0:
		return
	var patrol_node = get_node_or_null(patrol_points[patrol_index])
	if patrol_node:
		navigation_agent.target_position = patrol_node.global_position
	patrol_index = (patrol_index + 1) % patrol_points.size()


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
		
func _update_vision_cone():
	var half_angle = deg_to_rad(vision_angle_degrees / 2.0)
	var segments = 20
	var points = PackedVector2Array()
	points.append(Vector2.ZERO) # Centro del cono

	for i in range(segments + 1):
		var angle = -half_angle + ((half_angle) * 2.0 * i / segments)
		points.append(Vector2.RIGHT.rotated(angle + rotation2) * vision_range)

	vision_polygon.polygon = points
	vision_polygon.color = Color(1, 1, 0.5, 0.4) # Amarillo claro translúcido
