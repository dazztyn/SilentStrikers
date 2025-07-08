extends BaseItem
class_name SpeedPotion

@export var speed_boost: float = 50.0

func _ready():
	super._ready()
	item_name = "Poción de Velocidad"
	item_description = "Aumenta tu velocidad de movimiento"
	item_texture = preload("res://assets/Imagenes/Potenciadores/Monster.png")

func apply_effect():
	var player = Singleton.devolver_player()
	if player:
		player.aumentar_velocidad(speed_boost)
		print("Velocidad aumentada en: ", speed_boost)
