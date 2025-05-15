extends Node2D  # o SubViewport si lo ponés ahí

@onready var jugador_icono = $jugador_icono
@onready var enemigo_icono = $guardia_icono
@onready var jugador = get_node("/root/Mapa de Prueba/Ladron")
@onready var enemigo = get_node("/root/Mapa de Prueba/Guardia 2")  # Cambiá si es distinto

func _process(_delta):
	jugador_icono.global_position = jugador.global_position
	enemigo_icono.global_position = enemigo.global_position
	
