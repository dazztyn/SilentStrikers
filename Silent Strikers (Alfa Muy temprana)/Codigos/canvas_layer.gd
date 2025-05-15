extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var life_label = $LifeLabel
var player: CharacterBody2D

func _ready():
	player = get_node("../Ladron")  # Ajusta la ruta al nodo del jugador
	
	# Verificar si la referencia al jugador es válida
	if player == null:
		print("Error: El nodo 'Ladron' no se encuentra.")
		return  # Detiene la ejecución si no se encuentra el jugador
	
	update_hud()

func _process(delta):
	if player != null:
		update_hud()

func update_hud():# Actualiza las etiquetas del HUD con los valores del jugador
	
	if player != null:
		score_label.text = "Puntaje: " + str(player.puntaje)
		life_label.text = "Vida: " + str(player.salud)
	else:
		print("El jugador no está disponible.")
