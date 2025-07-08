# Items coleccionables que solo dan puntos
extends BaseItem
class_name CollectableItem

enum CollectableType {
	COMPUTER,
	MONEY_STACK,
	BOWL,
	GOLD_BARS
}

@export var collectable_type: CollectableType = CollectableType.COMPUTER

# Configuraciones de items coleccionables
var collectable_configs = {
	CollectableType.COMPUTER: {
		"name": "Computadora",
		"description": "Una computadora valiosa",
		"texture_path": "res://assets/Imagenes/item_robable_04.png",
		"score": 150
	},
	CollectableType.MONEY_STACK: {
		"name": "Fajo de Dinero",
		"description": "Un fajo de billetes",
		"texture_path": "res://assets/Imagenes/item_robable_02.png",
		"score": 50
	},
	CollectableType.BOWL: {
		"name": "Tazón",
		"description": "Un tazón decorativo",
		"texture_path": "res://assets/Imagenes/item_robable_03.png",
		"score": 100
	},
	CollectableType.GOLD_BARS: {
		"name": "Lingotes de Oro",
		"description": "Lingotes de oro puro",
		"texture_path": "res://assets/Imagenes/item_robable_01.png",
		"score": 250
	}
}

var score_value: int = 100

func _ready():
	super._ready()
	configure_collectable()

func configure_collectable():
	if collectable_configs.has(collectable_type):
		var config = collectable_configs[collectable_type]
		
		item_name = config["name"]
		item_description = config["description"]
		score_value = config["score"]
		
		# Cargar textura
		var texture = load(config["texture_path"])
		if texture:
			item_texture = texture
			if sprite:
				sprite.texture = texture

func apply_effect():
	var player = Singleton.devolver_player()
	if player:
		player.aumentar_puntaje(score_value)
		print("¡Objeto robado! +", score_value, " puntos | Item: ", item_name)
