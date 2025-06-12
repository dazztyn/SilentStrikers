extends Control

@onready var chat_label = $VBoxContainer/Label
@onready var chat_input = $VBoxContainer/HBoxContainer/LineEdit
@onready var send_button = $VBoxContainer/HBoxContainer/Button
@onready var score_list = $Panel/VBoxContainer

# Asume que WebSocketClient es un singleton (autoload) o está en la escena
@onready var ws 

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	chat_input.text_submitted.connect(_on_send_pressed)
	ws = get_node("../..").get_node("ws")

func _on_send_pressed():
	var msg = chat_input.text.strip_edges()
	if msg != "":
		ws.send_chat_message(msg)
		chat_input.text = ""

func show_chat_message(text: String):
	chat_label.text += "\n" + text

func update_score(player: String, score: int):
	for child in score_list.get_children():
		if child.name == player:
			child.text = "%s: %d" % [player, score]
			return

	# Si no existe, lo creamos
	var lbl = Label.new()
	lbl.name = player
	lbl.text = "%s: %d" % [player, score]
	score_list.add_child(lbl)
