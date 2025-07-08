extends Node

# Este script ahora solo maneja la integración con la UI local
# El WebSocket real está en el singleton

@onready var ChatSystem = get_node("../ChatSystem")

func _ready():
	print("🔗 Cliente WebSocket local iniciado")
	# Conectar señales del singleton
	WebSocketManager.connect("player_connected", _on_player_connected)
	WebSocketManager.connect("match_request_received", _on_match_request_received)
	WebSocketManager.connect("match_accepted", _on_match_accepted)
	WebSocketManager.connect("match_ready", _on_match_ready)
	WebSocketManager.connect("rematch_requested", _on_rematch_request)
	WebSocketManager.connect("match_started", _on_match_started)
	WebSocketManager.connect("match_quit", _on_close_match)
	WebSocketManager.connect("player_list_updated", _on_player_list_updated)
	WebSocketManager.connect("chat_message_received", _on_chat_message_received)
	WebSocketManager.connect("game_ended", _on_game_ended)
	WebSocketManager.connect("match_request_canceled", _on_match_request_canceled)
	WebSocketManager.connect("match_request_canceled_by_sender", _on_match_request_canceled_by_sender)
	WebSocketManager.connect("match_rejected", _on_match_rejected)

func _on_match_rejected(data: Dictionary):
	var player_list = get_node_or_null("../PlayerListSystem")
	var player_id = data.get("playerId", "")
	if player_list and player_list.has_method("_on_match_rejected"):
		player_list._on_match_rejected(data)
		_on_match_request_canceled(player_id)

func _on_rematch_request():
	if ChatSystem and ChatSystem.has_method("on_message_received"):
		ChatSystem.on_message_received("Rival", "Quiere la revancha")

func _on_close_match():
	WebSocketManager.quit_match()
	var main_menu = load("res://Escenas/main_menu.tscn")
	if main_menu:
		get_tree().change_scene_to_packed(main_menu)
	else:
		print("No se encontro la escena de menu")

func _on_game_ended(data: Dictionary):
	var loss_screen = load("res://GUI/Escenas/loss_escene.tscn")
	if loss_screen:
		get_tree().change_scene_to_packed(loss_screen)
	else:
		print("No se encontro la escena de derrota")

func _on_player_connected(data: Dictionary):
	print("✅ Jugador conectado: ", data.get("name", ""))
	
	if ChatSystem and ChatSystem.has_method("set_player_name"):
		ChatSystem.set_player_name(data.get("name", ""))
	
	var player_list = get_node_or_null("../PlayerListSystem")
	if player_list and player_list.has_method("set_my_player_data"):
		player_list.set_my_player_data(data)

func _on_match_request_received(player_name: String, player_id: String, match_id: String):
	var player_list = get_node_or_null("../PlayerListSystem")
	if player_list and player_list.has_method("show_match_request"):
		player_list.show_match_request(player_name, player_id, match_id)

func _on_match_accepted(data: Dictionary):
	var player_list = get_node_or_null("../PlayerListSystem")
	if player_list and player_list.has_method("connect_match"):
		player_list.connect_match()

func _on_match_ready(data: Dictionary):
	WebSocketManager.ping_match()

func _on_match_started(data: Dictionary):
	print("🎮 Partida iniciada, cargando selección de mapas...")
	
	if ChatSystem and ChatSystem.has_method("prepare_for_scene_change"):
		ChatSystem.prepare_for_scene_change()
	
	# Cambiar a selección de mapas
	var map_selection_scene = load("res://GUI/Escenas/map_select_multijugador.tscn")
	if map_selection_scene:
		get_tree().change_scene_to_packed(map_selection_scene)
	else:
		print("❌ Error: No se pudo cargar MapSelection.tscn")

func _on_player_list_updated(players: Array):
	var player_list = get_node_or_null("../PlayerListSystem")
	if player_list and player_list.has_method("update_player_list"):
		player_list.update_player_list(players)

func _on_chat_message_received(sender: String, message: String):
	if ChatSystem and ChatSystem.has_method("on_message_received"):
		ChatSystem.on_message_received(sender, message)

# ← NUEVAS FUNCIONES PARA MANEJAR CANCELACIONES
func _on_match_request_canceled(player_id: String):
	var player_list = get_node_or_null("../PlayerListSystem")
	if player_list and player_list.has_method("_on_match_request_canceled"):
		player_list._on_match_request_canceled(player_id)

func _on_match_request_canceled_by_sender(player_name: String, player_id: String):
	var player_list = get_node_or_null("../PlayerListSystem")
	if player_list and player_list.has_method("_on_match_request_canceled_by_sender"):
		player_list._on_match_request_canceled_by_sender(player_name, player_id)

# Funciones de conveniencia para mantener compatibilidad
func send_message(data: Dictionary):
	WebSocketManager.send_message(data)

func send_public_message(text: String):
	WebSocketManager.send_public_message(text)

func request_online_players():
	WebSocketManager.request_online_players()
