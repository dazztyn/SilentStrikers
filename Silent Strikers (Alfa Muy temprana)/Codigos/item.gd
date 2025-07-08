extends BaseItem

# Collectible item that gives points to the player
# Now uses the new BaseItem system instead of texture-based logic

@export var puntos = 200  # Kept for backward compatibility

func _ready():
	super._ready()
	# Initialize points_value from puntos for backward compatibility
	if puntos != 200:
		points_value = puntos

func collect():
	if jugador:
		jugador.aumentar_puntaje(points_value)
		jugador.recoger()

# Backward compatibility function
func recoger():
	collect()
