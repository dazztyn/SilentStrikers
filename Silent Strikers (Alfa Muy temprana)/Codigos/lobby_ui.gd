extends Control

@onready var user_list = $UserList
@onready var chat_box = $ChatBox
@onready var chat_input = $ChatInput
@onready var send_button = $SendButton
@onready var send_request_button = $SendRequestButton

func _ready():
	send_button.pressed.connect(_on_send_button_pressed)
	chat_input.text_submitted.connect(_on_chat_input_submitted)
	send_request_button.pressed.connect(_on_send_request)
	user_list.item_selected.connect(_on_user_selected)

func _on_send_button_pressed():
	send_message(chat_input.text)

func _on_chat_input_submitted(text):
	send_message(text)

func send_message(text: String):
	if text.strip_edges() != "":
		chat_box.append_text("Tú: %s\n" % text)
		chat_input.clear()
		# Aquí deberías enviar el mensaje por red (WebSocket o similar)

func _on_user_selected(index):
	send_request_button.disabled = false

func _on_send_request():
	var selected_user = user_list.get_item_text(user_list.get_selected_items()[0])
	print("Solicitud enviada a:", selected_user)
	# Aquí puedes enviar una solicitud real por red
