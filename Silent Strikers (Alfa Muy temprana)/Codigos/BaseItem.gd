extends Area2D
class_name BaseItem

# Base class for all items in the game
# Removes dependency on texture matching and provides a clean interface

var player_in_range = false
@export var item_type: String = "default"
@export var points_value: int = 100
@export var effect_data: Dictionary = {}
@onready var jugador = Singleton.devolver_player()

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false

func _process(delta):
	if player_in_range and Input.is_action_just_pressed("interactuar"):
		collect()
		queue_free()

# Virtual function to be overridden by subclasses
func collect():
	if jugador:
		jugador.aumentar_puntaje(points_value)
		apply_effect()

# Virtual function to be overridden by subclasses
func apply_effect():
	pass

# Factory method to create different item types
static func create_item(type: String, position: Vector2 = Vector2.ZERO, scale_factor: Vector2 = Vector2.ONE) -> BaseItem:
	var item_scene_path = "res://Escenas/item.tscn"
	var powerup_scene_path = "res://Escenas/potenciador.tscn"
	
	match type:
		"collectible_high":
			return _create_collectible_item(item_scene_path, 200, position, scale_factor)
		"collectible_medium":
			return _create_collectible_item(item_scene_path, 150, position, scale_factor)
		"collectible_low":
			return _create_collectible_item(item_scene_path, 100, position, scale_factor)
		"speed_boost":
			return _create_powerup_item(powerup_scene_path, "speed", position, scale_factor)
		"invisibility":
			return _create_powerup_item(powerup_scene_path, "invisibility", position, scale_factor)
		"health_restore":
			return _create_powerup_item(powerup_scene_path, "health", position, scale_factor)
		_:
			return _create_collectible_item(item_scene_path, 100, position, scale_factor)

static func _create_collectible_item(scene_path: String, points: int, position: Vector2, scale_factor: Vector2) -> BaseItem:
	var item = preload("res://Escenas/item.tscn").instantiate()
	item.points_value = points
	item.item_type = "collectible"
	item.position = position
	item.scale = scale_factor
	return item

static func _create_powerup_item(scene_path: String, powerup_type: String, position: Vector2, scale_factor: Vector2) -> BaseItem:
	var item = preload("res://Escenas/potenciador.tscn").instantiate()
	item.item_type = powerup_type
	item.position = position
	item.scale = scale_factor
	return item