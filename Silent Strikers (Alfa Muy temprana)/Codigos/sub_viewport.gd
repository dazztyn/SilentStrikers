extends SubViewport

@onready var minimap_camera = $Camera2D
@onready var player = get_node("/root/Mapa de Prueba/Ladron")  # Cambiá esta ruta si es diferente

func _process(_delta):
	if player and minimap_camera:
		minimap_camera.global_position = player.global_position
