extends BaseItem

# Powerup item that applies various effects to the player
# Now uses the new BaseItem system instead of texture-based logic

@export var potenciado = 0.25  # Kept for backward compatibility
@export var powerup_type: String = "speed"  # "speed", "invisibility", "health"

func _ready():
	super._ready()
	# Set item_type based on powerup_type for the new system
	item_type = powerup_type

func collect():
	if jugador:
		apply_effect()

func apply_effect():
	match item_type:
		"speed":
			potenciar()
		"invisibility":
			invisibilizar()
		"health":
			restaurar_salud()
		_:
			# Fallback for backward compatibility
			potenciar()

# Backward compatibility functions
func potenciar():
	if jugador:
		jugador.aumentar_velocidad(potenciado)

func invisibilizar():
	if jugador:
		jugador.aplicar_invisibilidad(0.5)

func restaurar_salud():
	if jugador:
		jugador.restaurar_salud(1)
