# Script base para todos los items
extends Area2D
class_name BaseItem

signal item_collected(item: BaseItem)

@export var item_name: String = "Item Base"
@export var item_description: String = "Descripción del item"
@export var item_texture: Texture2D
@export var item_scale: Vector2 = Vector2(0.3, 0.3)
@export var collection_sound: AudioStream

var player_in_range: bool = false
var is_collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Configurar apariencia
	if item_texture:
		sprite.texture = item_texture
	
	scale = item_scale
	
	# Configurar audio
	if collection_sound and audio_player:
		audio_player.stream = collection_sound

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		player_in_range = true
		show_interaction_hint()

func _on_body_exited(body: Node2D):
	if body.name == "Player":
		player_in_range = false
		hide_interaction_hint()

func _process(delta):
	if player_in_range and Input.is_action_just_pressed("interactuar") and not is_collected:
		collect_item()

func collect_item():
	if is_collected:
		return
	
	is_collected = true
	
	# Reproducir sonido
	if audio_player and audio_player.stream:
		audio_player.play()
	
	# Aplicar efecto del item
	apply_effect()
	
	# Emitir señal
	item_collected.emit(self)
	
	# Animación de recolección
	create_collection_animation()

func apply_effect():
	# Función virtual que debe ser sobrescrita por las clases hijas
	print("Efecto base aplicado: ", item_name)

func create_collection_animation():
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func show_interaction_hint():
	# Opcional: mostrar indicador de interacción
	modulate = Color.YELLOW

func hide_interaction_hint():
	modulate = Color.WHITE
