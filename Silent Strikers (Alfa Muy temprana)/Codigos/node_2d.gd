extends Node2D  # o SubViewport si lo ponés ahí

@onready var jugador_icono = $jugador_icono
@onready var guardia_icono = $guardia_icono
@onready var jugador = get_node("/root/TestMapa1/CharacterBody2D")  # Cambiá si es distinto

func _process(_delta):
	jugador_icono.global_position = jugador.global_position
	
	for guardia in get_tree().get_nodes_in_group("Guardias"):
		guardia_icono.global_position = guardia.global_position
