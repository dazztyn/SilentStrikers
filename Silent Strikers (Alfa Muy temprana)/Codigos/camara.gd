extends Node2D

@export var vision_range: float = 400.0
@export var vision_angle_degrees: float = 90.0
@export var wall_collision_mask: int = 1
@export var draw_vision_cone: bool = true
@export var vision_cone_color: Color = Color(1, 0, 0, 0.3)

@export var player: CharacterBody2D
@onready var raycast: RayCast2D = $RayCast2D

var player_detected: bool = false
var last_known_position: Vector2 = Vector2.ZERO
var rotation2 := rotation  # dirección visual de la cámara

func _ready():
	player = get_node("../Player")
	raycast.collision_mask = wall_collision_mask | player.collision_layer

func _process(delta):
	check_vision()

	if player_detected or last_known_position != Vector2.ZERO:
		var target_dir = (last_known_position - global_position).angle()
		rotation2 = lerp_angle(rotation2, target_dir, delta * 2.5)

	if draw_vision_cone:
		queue_redraw()

func check_vision():
	var dir_to_player = player.global_position - global_position
	var distance = dir_to_player.length()

	if distance > vision_range:
		player_detected = false
		return

	var dir_norm = dir_to_player.normalized()
	var angle_to_player = Vector2.RIGHT.rotated(rotation2).angle_to(dir_norm)
	var limit_angle = deg_to_rad(vision_angle_degrees / 2.0)

	if abs(angle_to_player) <= limit_angle + deg_to_rad(20):
		raycast.target_position = to_local(player.global_position)
		raycast.force_raycast_update()
		if raycast.is_colliding() and raycast.get_collider() == player:
			last_known_position = player.global_position
			if not player_detected:
				_on_player_detected()
			player_detected = true
			return

	if player_detected:
		_on_player_lost()
	player_detected = false

func get_closest_guardia() -> Node:
	var closest = null
	var closest_dist = INF

	for guardia in get_tree().get_nodes_in_group("Guardias"):
		if not guardia.is_inside_tree():
			continue
		var dist = global_position.distance_to(guardia.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = guardia
	return closest

func _on_player_detected():
	print("📷 Cámara detectó al ladrón.")
	var guardia = get_closest_guardia()
	if guardia:
		guardia.last_known_player_position = last_known_position
		guardia.current_state = guardia.State.CHASING
		guardia.chasing_timer = guardia.chase_duration

func _on_player_lost():
	print("📷 Cámara perdió de vista al ladrón.")

func _draw():
	var half_angle = deg_to_rad(vision_angle_degrees / 2.0)
	var segments = 20
	var points = PackedVector2Array()

	for i in range(segments + 1):
		var angle = -half_angle + (i / float(segments)) * (2 * half_angle)
		points.append(Vector2.RIGHT.rotated(angle + rotation2) * vision_range * 2)

	if points.size() > 0:
		draw_line(Vector2.ZERO, points[0], vision_cone_color, 1.0)
		draw_polyline(points, vision_cone_color, 1.0)
		draw_line(Vector2.ZERO, points[-1], vision_cone_color, 1.0)
