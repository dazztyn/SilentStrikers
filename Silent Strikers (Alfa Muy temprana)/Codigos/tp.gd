extends Area2D

@export var target_position: Vector2
@onready var player = Singleton.devolver_player()

func _on_body_entered(body):
	if body == player:
		print("Jugador entro en el cuerpo")
		body.global_position =  Vector2(1629, 2522)
