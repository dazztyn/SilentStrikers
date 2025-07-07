extends CanvasLayer

@onready var score_label = $Puntaje
@onready var life_label = $Vida
@onready var oportunidad_1 = $oportunidad_1	
@onready var oportunidad_2 = $oportunidad_2	
@onready var oportunidad_3 = $oportunidad_3	
@onready var barra_de_puntaje_1 = $barra_de_puntaje_1
@onready var barra_de_puntaje_2 = $barra_de_puntaje_2
@onready var barra_de_puntaje_3 = $barra_de_puntaje_3

var player: CharacterBody2D
var salud: int 

func _ready():
	player = Singleton.devolver_player()
	
	# Verificar si la referencia al jugador es válida
	if player == null:
		print("Error: El nodo 'Ladron' no se encuentra.")
		return  # Detiene la ejecución si no se encuentra el jugador

	oportunidad_1.value = 1
	oportunidad_2.value = 1
	oportunidad_3.value = 1

		

func _process(delta):
	if player != null:
		update_hud()

func update_hud():# Actualiza las etiquetas del HUD con los valores del jugador

	score_label.text = "Puntaje: " + str(player.puntaje)
	
	if player.puntaje <=150:
		barra_de_puntaje_1.value = player.puntaje
		barra_de_puntaje_2.value=0
		barra_de_puntaje_3.value=0
	elif player.puntaje <= 450:
		barra_de_puntaje_1.value = 150
		barra_de_puntaje_2.value = player.puntaje - 150
		barra_de_puntaje_3.value=0
	elif player.puntaje <= 1000:
		barra_de_puntaje_1.value = 150
		barra_de_puntaje_2.value = 300
		barra_de_puntaje_3.value = player.puntaje - 450
	if player.salud == 2:
		oportunidad_3.value = 0
	elif player.salud == 1:
		oportunidad_2.value=0
	elif player.salud == 0:
		oportunidad_1.value = 0
