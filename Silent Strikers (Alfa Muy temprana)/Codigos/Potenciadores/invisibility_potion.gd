# Poción de invisibilidad
extends BaseItem
class_name InvisibilityPotion

@export var invisibility_duration: float = 5.0
@export var invisibility_alpha: float = 0.5

func _ready():
	super._ready()
	item_name = "Poción de Invisibilidad"
	item_description = "Te hace invisible temporalmente"
	item_texture = preload("res://assets/Imagenes/Potenciadores/Inv.png")

func apply_effect():
	var player = Singleton.devolver_player()
	if player:
		player.aplicar_invisibilidad(invisibility_duration, invisibility_alpha)
		print("Invisibilidad aplicada por: ", invisibility_duration, " segundos")
