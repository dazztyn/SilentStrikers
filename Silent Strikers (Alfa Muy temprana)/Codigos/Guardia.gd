extends CharacterBody2D

@onready var state_label: Label = $StateLabel #DEBUG
@onready var vision_polygon := $Polygon2D
@onready var line_of_sight: RayCast2D = $VisionRayCast
@onready var vision_cone: Area2D = $Vision
@onready var flashlight: PointLight2D = $FlashLight
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animations: AnimatedSprite2D = get_node("AnimatedSprite2D")

## --- Variables de Movimiento y Navegación ---
var speed = 300
var acceleration = 7.0
var forward
@export var navigation_region: NavigationRegion2D
@export var player: CharacterBody2D
var rotation2 = rotation

## --- Variables de Visión y Detección ---
var wall_collision_mask = 1
var player_in_vision_cone = false
@export var vision_angle_degrees := 60.0
@export var vision_range := 200.0

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

func _ready():
	add_to_group("GuardiasM1")
	line_of_sight.add_exception(self)

	if navigation_region == null:
		print("[ERROR] ¡No se ha asignado un NavigationRegion2D al guardia!")
		set_physics_process(false)
		return
	
	call_deferred("_set_next_patrol_point")
	set_state(State.PATROLLING)

func _physics_process(delta: float):
	forward = (navigation_agent.get_next_path_position() - global_position).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT.rotated(rotation)

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
		if move_dir.x > 0 and abs(move_dir.y) < 0.3:
			animations.play("Derecha")
			horizontal = true
		elif move_dir.x < 0 and abs(move_dir.y) < 0.3:
			animations.play("Izquierda")
			horizontal = true

		if not horizontal:
			if move_dir.y > 0:
				animations.play("Abajo")
			elif move_dir.y < 0:
				animations.play("Arriba")

	_update_vision_cone()
	move_and_slide()

func _process_patrolling(delta):
	if navigation_agent.is_navigation_finished():
		_set_next_patrol_point()
	_update_navigation_velocity(delta)

func _process_chasing(delta):
	chasing_timer -= delta
	navigation_agent.target_position = last_known_player_position
	_update_navigation_velocity(delta)

func _process_searching(delta):
	search_timer -= delta
	if search_timer <= 0.0:
		set_state(State.PATROLLING)
		_set_next_patrol_point()
		return
	if navigation_agent.is_navigation_finished():
		var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
		var random_point = last_known_player_position + random_direction * randf_range(0, search_radius)
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
	if navigation_region == null or navigation_region.navigation_polygon == null:
		print("[Guardia] NavigationRegion2D o su polígono no están asignados.")
		return

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

	const MAX_ATTEMPTS = 30
	for i in range(MAX_ATTEMPTS):
		var random_point = Vector2(
			randf_range(overall_bounds.position.x, overall_bounds.end.x),
			randf_range(overall_bounds.position.y, overall_bounds.end.y)
		)

		for outline_index in range(nav_poly.get_outline_count()):
			var polygon_points = nav_poly.get_outline(outline_index)
			if Geometry2D.is_point_in_polygon(random_point, polygon_points):
				var map = navigation_region.get_navigation_map()
				var closest_valid_point = NavigationServer2D.map_get_closest_point(map, random_point)
				navigation_agent.target_position = closest_valid_point
				return

	print("[Guardia] No se pudo encontrar un punto de patrulla válido después de %d intentos." % MAX_ATTEMPTS)

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

func _update_vision_cone():
	var half_angle = deg_to_rad(vision_angle_degrees / 2.0)
	var segments = 20
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)

	for i in range(segments + 1):
		var angle = -half_angle + ((half_angle * 2.0) * i / segments)
		points.append(Vector2.RIGHT.rotated(angle + rotation2) * vision_range)

	vision_polygon.polygon = points
	vision_polygon.color = Color(1, 1, 0.5, 0.4)
