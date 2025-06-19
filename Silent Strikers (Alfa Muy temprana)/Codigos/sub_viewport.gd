extends SubViewport

@onready var minimap_camera: Camera2D = $Camera2D
@onready var player: CharacterBody2D = get_node("/root/TestMapa1/CharacterBody2D")
@onready var tilemap: TileMap = $TileMap  # ruta correcta al TileMap
@onready var player_icon: Node2D = $Node2D/jugador_icono
@onready var guard_icon_texture := preload("res://Imagenes/item_robable_04.png")

var guard_icons := []

func _ready():
	for guard in get_tree().get_nodes_in_group("Guardias"):
		var icon = Sprite2D.new()
		icon.texture = guard_icon_texture
		icon.centered = true
		icon.scale = Vector2(0.5, 0.5)
		add_child(icon)
		guard_icons.append({ "guard": guard, "icon": icon })

func _process(_delta):
	if player and minimap_camera and tilemap:
		minimap_camera.global_position = player.global_position

		var half_size = get_size() * 0.5
		var tilemap_offset = tilemap.position

		# Ajustamos posición del jugador sumando el offset del TileMap
		player_icon.position = (player.global_position - minimap_camera.global_position) + half_size + tilemap_offset

		for dic in guard_icons:
			var guard = dic["guard"]
			var icon = dic["icon"]
			icon.position = (guard.global_position - minimap_camera.global_position) + half_size + tilemap_offset
