extends BaseItem
class_name PowerUpItem

enum PowerUpType {
	SPEED_POTION,
	INVISIBILITY_POTION,
}

@export var power_up_type: PowerUpType = PowerUpType.SPEED_POTION

# Configuraciones de potenciadores
var power_up_configs = {
	PowerUpType.SPEED_POTION: {
		"name": "Poción de Velocidad",
		"description": "Aumenta tu velocidad temporalmente",
		"texture_path": "res://assets/Imagenes/Potenciadores/Monster.png",
		"effect_value": 50.0
	},
	PowerUpType.INVISIBILITY_POTION: {
		"name": "Poción de Invisibilidad",
		"description": "Te hace invisible temporalmente",
		"texture_path": "res://assets/Imagenes/Potenciadores/Inv.png",
		"effect_value": 5.0
	}
}

var effect_value: float = 50.0

func _ready():
	super._ready()
	configure_power_up()

func configure_power_up():
	if power_up_configs.has(power_up_type):
		var config = power_up_configs[power_up_type]
		
		item_name = config["name"]
		item_description = config["description"]
		effect_value = config["effect_value"]
		
		# Cargar textura
		var texture = load(config["texture_path"])
		if texture:
			item_texture = texture
			if sprite:
				sprite.texture = texture

func apply_effect():
	var player = Singleton.devolver_player()
	if not player:
		return
	
	match power_up_type:
		PowerUpType.SPEED_POTION:
			player.aumentar_velocidad(effect_value)
			print("Velocidad aumentada en: ", effect_value)
		
		PowerUpType.INVISIBILITY_POTION:
			player.aplicar_invisibilidad(effect_value, 0.5)
			print("Invisibilidad aplicada por: ", effect_value, " segundos")
