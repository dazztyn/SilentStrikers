extends Node

# === CONFIGURACIÓN DE TAMAÑO Y POSICIÓN ===
var size_multiplier: float = 1.5  # 1.0 = 100%, 1.5 = 150%, 2.0 = 200%
var position_offset: Vector2 = Vector2(-650, 150)  # Ajustar posición fácilmente

# Referencias a nodos UI
var player_list_ui: Control
var player_list_container: VBoxContainer
var refresh_button: Button
var title_label: Label
var name_input: LineEdit
var change_name_button: Button

# Datos
var my_player_data = {}
var current_players = []
var player_items = {}
var pending_requests = {}

# Configuración
var status_colors = {
	"AVAILABLE": Color.GREEN,
	"BUSY": Color.YELLOW,
	"IN_MATCH": Color.RED
}

var status_icons = {
	"AVAILABLE": "●",
	"BUSY": "◐",
	"IN_MATCH": "◆"
}

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	create_player_list_ui()
	_ready_auto_refresh()
	WebSocketManager.request_online_players()
	
	# ← CONECTAR NUEVAS SEÑALES
	WebSocketManager.match_request_canceled.connect(_on_match_request_canceled)
	WebSocketManager.match_request_canceled_by_sender.connect(_on_match_request_canceled_by_sender)

func create_player_list_ui():
	print("👥 Creando UI de lista de jugadores...")
	
	# Buscar o crear CanvasLayer
	var ui_layer = get_tree().current_scene.get_node_or_null("UI")
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UI"
		get_tree().current_scene.add_child(ui_layer)
		await get_tree().process_frame
	
	# Contenedor principal con tamaño escalado
	player_list_ui = Control.new()
	player_list_ui.name = "PlayerListUI"
	player_list_ui.size = Vector2(300 * size_multiplier, 450 * size_multiplier)
	player_list_ui.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	player_list_ui.position = position_offset
	ui_layer.add_child(player_list_ui)
	
	# Fondo
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = player_list_ui.size
	bg.z_index = -1
	player_list_ui.add_child(bg)
	
	# Título
	title_label = Label.new()
	title_label.text = "👥 Jugadores Online (0)"
	title_label.position = Vector2(10 * size_multiplier, 5 * size_multiplier)
	title_label.size = Vector2(280 * size_multiplier, 25 * size_multiplier)
	title_label.add_theme_font_size_override("font_size", int(14 * size_multiplier))
	title_label.modulate = Color.CYAN
	player_list_ui.add_child(title_label)
	
	# Botón refresh
	refresh_button = Button.new()
	refresh_button.text = "🔄"
	refresh_button.position = Vector2(260 * size_multiplier, 5 * size_multiplier)
	refresh_button.size = Vector2(30 * size_multiplier, 25 * size_multiplier)
	refresh_button.add_theme_font_size_override("font_size", int(14 * size_multiplier))
	refresh_button.pressed.connect(_on_refresh_pressed)
	player_list_ui.add_child(refresh_button)
	
	# Área de scroll para la lista
	var scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(5 * size_multiplier, 35 * size_multiplier)
	scroll_container.size = Vector2(290 * size_multiplier, 320 * size_multiplier)
	player_list_ui.add_child(scroll_container)
	
	# Contenedor de jugadores
	player_list_container = VBoxContainer.new()
	player_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_list_container.add_theme_constant_override("separation", int(5 * size_multiplier))
	scroll_container.add_child(player_list_container)
	
	# --- SECCIÓN: Input para cambiar nombre ---
	
	# Separador visual
	var separator = HSeparator.new()
	separator.position = Vector2(5 * size_multiplier, 360 * size_multiplier)
	separator.size = Vector2(290 * size_multiplier, 5 * size_multiplier)
	separator.modulate = Color.GRAY
	player_list_ui.add_child(separator)
	
	# Label para el input
	var input_label = Label.new()
	input_label.text = "✏️ Cambiar nombre:"
	input_label.position = Vector2(10 * size_multiplier, 370 * size_multiplier)
	input_label.size = Vector2(150 * size_multiplier, 20 * size_multiplier)
	input_label.add_theme_font_size_override("font_size", int(12 * size_multiplier))
	input_label.modulate = Color.LIGHT_GRAY
	player_list_ui.add_child(input_label)
	
	# Input de texto para el nombre
	name_input = LineEdit.new()
	name_input.placeholder_text = "Nuevo nombre..."
	name_input.position = Vector2(10 * size_multiplier, 395 * size_multiplier)
	name_input.size = Vector2(200 * size_multiplier, 30 * size_multiplier)
	name_input.add_theme_font_size_override("font_size", int(12 * size_multiplier))
	name_input.max_length = 20
	
	# Estilo del input
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	input_style.border_color = Color.GRAY
	input_style.border_width_bottom = int(2 * size_multiplier)
	input_style.border_width_top = int(2 * size_multiplier)
	input_style.border_width_left = int(2 * size_multiplier)
	input_style.border_width_right = int(2 * size_multiplier)
	input_style.corner_radius_top_left = int(5 * size_multiplier)
	input_style.corner_radius_top_right = int(5 * size_multiplier)
	input_style.corner_radius_bottom_left = int(5 * size_multiplier)
	input_style.corner_radius_bottom_right = int(5 * size_multiplier)
	name_input.add_theme_stylebox_override("normal", input_style)
	
	# Estilo cuando está enfocado
	var input_style_focus = StyleBoxFlat.new()
	input_style_focus.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	input_style_focus.border_color = Color.CYAN
	input_style_focus.border_width_bottom = int(2 * size_multiplier)
	input_style_focus.border_width_top = int(2 * size_multiplier)
	input_style_focus.border_width_left = int(2 * size_multiplier)
	input_style_focus.border_width_right = int(2 * size_multiplier)
	input_style_focus.corner_radius_top_left = int(5 * size_multiplier)
	input_style_focus.corner_radius_top_right = int(5 * size_multiplier)
	input_style_focus.corner_radius_bottom_left = int(5 * size_multiplier)
	input_style_focus.corner_radius_bottom_right = int(5 * size_multiplier)
	name_input.add_theme_stylebox_override("focus", input_style_focus)
	
	player_list_ui.add_child(name_input)
	
	# Botón para cambiar nombre
	change_name_button = Button.new()
	change_name_button.text = "✓"
	change_name_button.position = Vector2(220 * size_multiplier, 395 * size_multiplier)
	change_name_button.size = Vector2(70 * size_multiplier, 30 * size_multiplier)
	change_name_button.add_theme_font_size_override("font_size", int(14 * size_multiplier))
	
	# Estilo del botón
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.6, 0.2, 0.8)
	button_style.corner_radius_top_left = int(5 * size_multiplier)
	button_style.corner_radius_top_right = int(5 * size_multiplier)
	button_style.corner_radius_bottom_left = int(5 * size_multiplier)
	button_style.corner_radius_bottom_right = int(5 * size_multiplier)
	change_name_button.add_theme_stylebox_override("normal", button_style)
	
	# Estilo cuando se presiona
	var button_style_pressed = StyleBoxFlat.new()
	button_style_pressed.bg_color = Color(0.1, 0.4, 0.1, 0.8)
	button_style_pressed.corner_radius_top_left = int(5 * size_multiplier)
	button_style_pressed.corner_radius_top_right = int(5 * size_multiplier)
	button_style_pressed.corner_radius_bottom_left = int(5 * size_multiplier)
	button_style_pressed.corner_radius_bottom_right = int(5 * size_multiplier)
	change_name_button.add_theme_stylebox_override("pressed", button_style_pressed)
	change_name_button.pressed.connect(_on_change_name_button_pressed)
	player_list_ui.add_child(change_name_button)
	
	name_input.text_submitted.connect(_on_name_input_submitted)
	
	print("✅ UI de lista de jugadores creada con multiplicador: ", size_multiplier)

func _on_name_input_submitted(new_text: String):
	_on_change_name_button_pressed()

func _on_change_name_button_pressed():
	var new_name = name_input.text.strip_edges()
	
	if new_name.length() == 0:
		print("⚠️ El nombre no puede estar vacío")
		return
	
	if new_name.length() < 2:
		print("⚠️ El nombre debe tener al menos 2 caracteres")
		return
	
	print("✏️ Cambiando nombre a: ", new_name)
	
	WebSocketManager.change_player_name(new_name)
	
	name_input.text = ""
	name_input.placeholder_text = "Nombre cambiado..."
	
	# Restaurar placeholder después de un tiempo
	await get_tree().create_timer(2.0).timeout
	name_input.placeholder_text = "Nuevo nombre..."

func update_current_player_name(new_name: String):
	"""Función para actualizar el nombre mostrado cuando se recibe confirmación del servidor"""
	if my_player_data.has("name"):
		my_player_data["name"] = new_name
		print("✅ Nombre actualizado localmente a: ", new_name)
		
		# Actualizar la lista para reflejar el cambio
		call_deferred("request_online_players")

func _on_refresh_pressed():
	print("🔄 Actualizando lista de jugadores manualmente...")
	request_online_players()

func request_online_players():
	if WebSocketManager and WebSocketManager.has_method("request_online_players"):
		WebSocketManager.request_online_players()
	else:
		print("⚠️ No se puede actualizar: WebSocket no disponible")

func set_my_player_data(data: Dictionary):
	my_player_data = data
	print("🆔 Datos del jugador establecidos: ", data.get("name", ""))

func update_player_list(players_data: Array):
	current_players = players_data
	
	# Guardar solicitudes pendientes antes de limpiar
	var temp_pending = pending_requests.duplicate()
	
	# Limpiar lista actual
	for child in player_list_container.get_children():
		child.queue_free()
	
	player_items.clear()
	
	# Actualizar título
	title_label.text = "👥 Jugadores Online (" + str(players_data.size()) + ")"
	
	# Agregar cada jugador
	for player_data in players_data:
		create_player_item(player_data)
	
	# Restaurar solicitudes pendientes si aún existen
	for player_id in temp_pending.keys():
		if player_items.has(player_id):
			var request_data = temp_pending[player_id]
			show_match_request_internal(request_data.player_name, player_id, request_data.match_id, false)

func create_player_item(player_data: Dictionary):
	var player_id = player_data.get("id", "")
	var player_name = player_data.get("name", "Desconocido")
	var player_status = player_data.get("status", "AVAILABLE")
	var game_data = player_data.get("game", {})
	var game_name = game_data.get("name", "Sin juego")
	
	# Contenedor del jugador con tamaño escalado
	var player_item = Control.new()
	player_item.custom_minimum_size.y = 70 * size_multiplier
	player_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_item.name = "PlayerItem_" + player_id
	
	# Guardar referencia
	player_items[player_id] = player_item
	
	# Fondo del item
	var item_bg = ColorRect.new()
	item_bg.size = Vector2(280 * size_multiplier, 65 * size_multiplier)
	item_bg.color = Color(0.2, 0.2, 0.2, 0.5)
	item_bg.name = "ItemBg"
	
	# Destacar si soy yo
	if player_id == my_player_data.get("id", ""):
		item_bg.color = Color(0.2, 0.4, 0.6, 0.7)
	
	player_item.add_child(item_bg)
	
	# Icono de estado
	var status_icon = Label.new()
	status_icon.text = status_icons.get(player_status, "●")
	status_icon.position = Vector2(10 * size_multiplier, 5 * size_multiplier)
	status_icon.size = Vector2(20 * size_multiplier, 20 * size_multiplier)
	status_icon.modulate = status_colors.get(player_status, Color.WHITE)
	status_icon.add_theme_font_size_override("font_size", int(16 * size_multiplier))
	status_icon.name = "StatusIcon"
	player_item.add_child(status_icon)
	
	# Nombre del jugador
	var name_label = Label.new()
	name_label.text = player_name
	if player_id == my_player_data.get("id", ""):
		name_label.text += " (Tú)"
	name_label.position = Vector2(35 * size_multiplier, 5 * size_multiplier)
	name_label.size = Vector2(200 * size_multiplier, 20 * size_multiplier)
	name_label.add_theme_font_size_override("font_size", int(12 * size_multiplier))
	name_label.modulate = Color.WHITE
	name_label.name = "NameLabel"
	player_item.add_child(name_label)
	
	# Estado del jugador
	var status_label = Label.new()
	status_label.text = get_status_text(player_status)
	status_label.position = Vector2(35 * size_multiplier, 20 * size_multiplier)
	status_label.size = Vector2(150 * size_multiplier, 15 * size_multiplier)
	status_label.add_theme_font_size_override("font_size", int(10 * size_multiplier))
	status_label.modulate = status_colors.get(player_status, Color.GRAY)
	status_label.name = "StatusLabel"
	player_item.add_child(status_label)
	
	# Juego actual
	var game_label = Label.new()
	game_label.text = "🎮 " + game_name
	game_label.position = Vector2(35 * size_multiplier, 35 * size_multiplier)
	game_label.size = Vector2(200 * size_multiplier, 15 * size_multiplier)
	game_label.add_theme_font_size_override("font_size", int(9 * size_multiplier))
	game_label.modulate = Color.LIGHT_GRAY
	game_label.name = "GameLabel"
	player_item.add_child(game_label)
	
	# Contenedor de botones de aceptar/declinar
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(200 * size_multiplier, 25 * size_multiplier)
	button_container.size = Vector2(70 * size_multiplier, 30 * size_multiplier)
	button_container.add_theme_constant_override("separation", int(5 * size_multiplier))
	button_container.visible = false
	button_container.name = "ButtonContainer"
	player_item.add_child(button_container)
	
	# Botón aceptar (✅)
	var accept_button = Button.new()
	accept_button.text = "✅"
	accept_button.custom_minimum_size = Vector2(30 * size_multiplier, 30 * size_multiplier)
	accept_button.add_theme_font_size_override("font_size", int(14 * size_multiplier))
	var accept_style = StyleBoxFlat.new()
	accept_style.bg_color = Color.GREEN
	accept_style.corner_radius_top_left = int(5 * size_multiplier)
	accept_style.corner_radius_top_right = int(5 * size_multiplier)
	accept_style.corner_radius_bottom_left = int(5 * size_multiplier)
	accept_style.corner_radius_bottom_right = int(5 * size_multiplier)
	accept_button.add_theme_stylebox_override("normal", accept_style)
	accept_button.pressed.connect(_on_accept_match_request.bind(player_id))
	accept_button.name = "AcceptButton"
	button_container.add_child(accept_button)
	
	# Botón declinar (❌)
	var decline_button = Button.new()
	decline_button.text = "❌"
	decline_button.custom_minimum_size = Vector2(30 * size_multiplier, 30 * size_multiplier)
	decline_button.add_theme_font_size_override("font_size", int(14 * size_multiplier))
	var decline_style = StyleBoxFlat.new()
	decline_style.bg_color = Color.RED
	decline_style.corner_radius_top_left = int(5 * size_multiplier)
	decline_style.corner_radius_top_right = int(5 * size_multiplier)
	decline_style.corner_radius_bottom_left = int(5 * size_multiplier)
	decline_style.corner_radius_bottom_right = int(5 * size_multiplier)
	decline_button.add_theme_stylebox_override("normal", decline_style)
	decline_button.pressed.connect(_on_decline_match_request.bind(player_id))
	decline_button.name = "DeclineButton"
	button_container.add_child(decline_button)
	
	# BOTONES DE ACCIÓN PARA OTROS JUGADORES
	if player_id != my_player_data.get("id", ""):
		# Contenedor de botones de acción
		var action_container = HBoxContainer.new()
		action_container.position = Vector2(200 * size_multiplier, 25 * size_multiplier)
		action_container.size = Vector2(70 * size_multiplier, 25 * size_multiplier)
		action_container.add_theme_constant_override("separation", int(3 * size_multiplier))
		action_container.name = "ActionContainer"
		player_item.add_child(action_container)
		
		# Botón de chat privado (💬)
		var chat_button = Button.new()
		chat_button.text = "💬"
		chat_button.custom_minimum_size = Vector2(25 * size_multiplier, 25 * size_multiplier)
		chat_button.add_theme_font_size_override("font_size", int(12 * size_multiplier))
		chat_button.pressed.connect(_on_private_chat_button.bind(player_data))
		chat_button.name = "ChatButton"
		action_container.add_child(chat_button)
		
		# ← VERIFICAR SI TENGO SOLICITUD PENDIENTE A ESTE JUGADOR
		if WebSocketManager.has_pending_request_to(player_id):
			# Mostrar botón de cancelar en lugar de desafiar
			var cancel_button = Button.new()
			cancel_button.text = "🚫"
			cancel_button.custom_minimum_size = Vector2(25 * size_multiplier, 25 * size_multiplier)
			cancel_button.add_theme_font_size_override("font_size", int(12 * size_multiplier))
			cancel_button.pressed.connect(_on_cancel_match_request.bind(player_data))
			cancel_button.name = "CancelButton"
			cancel_button.modulate = Color.ORANGE
			action_container.add_child(cancel_button)
		else:
			# Botón de desafío (solo para jugadores disponibles)
			if player_status == "AVAILABLE":
				var challenge_button = Button.new()
				challenge_button.text = "⚔️"
				challenge_button.custom_minimum_size = Vector2(25 * size_multiplier, 25 * size_multiplier)
				challenge_button.add_theme_font_size_override("font_size", int(12 * size_multiplier))
				challenge_button.pressed.connect(_on_challenge_player.bind(player_data))
				challenge_button.name = "ChallengeButton"
				action_container.add_child(challenge_button)
	
	player_list_container.add_child(player_item)

func _on_private_chat_button(player_data: Dictionary):
	var player_name = player_data.get("name", "")
	var player_id = player_data.get("id", "")
	print("💬 Iniciando chat privado con: ", player_name)
	
	# Enviar señal al chat system para cambiar a modo privado
	var chat_system = get_node_or_null("../ChatSystem")
	if chat_system:
		chat_system.start_private_chat(player_name, player_id)
	
	# Notificar en el chat
	if chat_system:
		chat_system.add_chat_message("Sistema", "💬 Chat privado iniciado con " + player_name)

# ← NUEVA FUNCIÓN PARA CANCELAR SOLICITUDES
func _on_cancel_match_request(player_data: Dictionary):
	var player_name = player_data.get("name", "")
	var player_id = player_data.get("id", "")
	print("🚫 Cancelando solicitud de partida a: ", player_name)
	
	# Enviar cancelación al servidor
	WebSocketManager.cancel_match_request()
	
	# Notificar en el chat
	var chat_system = get_node_or_null("../ChatSystem")
	if chat_system:
		chat_system.add_chat_message("Sistema", "🚫 Solicitud de partida cancelada a " + player_name)

func get_status_text(status: String) -> String:
	match status:
		"AVAILABLE":
			return "Disponible"
		"BUSY":
			return "Ocupado"
		"IN_MATCH":
			return "En partida"
		_:
			return "Desconocido"

func _on_challenge_player(player_data: Dictionary):
	var player_name = player_data.get("name", "")
	var player_id = player_data.get("id", "")
	print("⚔️ Desafiando a jugador: ", player_name)
	
	# ← ENVIAR SOLICITUD CON NOMBRE PARA TRACKING
	WebSocketManager.send_match_request(player_id, player_name)
	
	# Notificar en chat
	var chat_system = get_node_or_null("../ChatSystem")
	if chat_system:
		chat_system.add_chat_message("Sistema", "🎯 Desafiando a " + player_name + "...")
	
	# ACTUALIZAR LA LISTA inmediatamente después de enviar el desafío
	print("🔄 Actualizando lista después de enviar desafío...")
	call_deferred("request_online_players")

# ← NUEVAS FUNCIONES PARA MANEJAR CANCELACIONES
func _on_match_request_canceled(player_id: String):
	print("✅ Solicitud cancelada exitosamente")
	
	# Notificar en el chat
	var chat_system = get_node_or_null("../ChatSystem")
	if chat_system:
		chat_system.add_chat_message("Sistema", "✅ Solicitud de partida cancelada exitosamente")
	
	# Actualizar la lista para reflejar el cambio
	call_deferred("request_online_players")

func _on_match_request_canceled_by_sender(player_name: String, player_id: String):
	print("🚫 Solicitud cancelada por: ", player_name)
	
	# Ocultar la solicitud si estaba visible
	hide_match_request(player_id)
	
	# Notificar en el chat
	var chat_system = get_node_or_null("../ChatSystem")
	if chat_system:
		chat_system.add_chat_message("Sistema", "🚫 " + player_name + " canceló su solicitud de partida")

func _ready_auto_refresh():
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_on_auto_refresh)
	timer.autostart = true
	add_child(timer)
	print("⏰ Auto-refresh configurado cada 2 segundos")

func show_match_request(player_name: String, player_id: String, match_id: String):
	show_match_request_internal(player_name, player_id, match_id, true)

func show_match_request_internal(player_name: String, player_id: String, match_id: String, notify_chat: bool = true):
	print("🎯 Mostrando solicitud de partida de: ", player_name, " (ID: ", player_id, ")")
	
	# Guardar datos de la solicitud
	pending_requests[player_id] = {
		"player_name": player_name,
		"match_id": match_id,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Buscar el item del jugador en la lista
	var player_item = player_items.get(player_id)
	if not player_item:
		print("⚠️ No se encontró el item del jugador en la lista")
		return
	
	# Obtener el contenedor de botones
	var button_container = player_item.get_node_or_null("ButtonContainer")
	if not button_container:
		print("⚠️ No se encontró el contenedor de botones")
		return
	
	# Mostrar los botones de aceptar/declinar
	button_container.visible = true
	
	# Ocultar el contenedor de acciones si existe
	var action_container = player_item.get_node_or_null("ActionContainer")
	if action_container:
		action_container.visible = false
	
	# Cambiar el fondo para destacar la solicitud
	var item_bg = player_item.get_node_or_null("ItemBg")
	if item_bg:
		item_bg.color = Color(0.6, 0.3, 0.1, 0.8)
	
	# Actualizar el estado en el label
	var status_label = player_item.get_node_or_null("StatusLabel")
	if status_label:
		status_label.text = "¡Te ha desafiado!"
		status_label.modulate = Color.YELLOW
	
	# Notificar en el chat solo si se especifica
	if notify_chat:
		var chat_system = get_node_or_null("../ChatSystem")
		if chat_system:
			chat_system.add_chat_message("Sistema", "⚔️ " + player_name + " te ha desafiado a una partida!")
		
		# Agregar timer automático solo para nuevas solicitudes
		setup_auto_decline_timer(player_id, 30.0)

func _on_accept_match_request(player_id: String):
	print("✅ Aceptando solicitud de partida del jugador: ", player_id)
	
	var request_data = pending_requests.get(player_id, {})
	var player_name = request_data.get("player_name", "")
	
	# Enviar respuesta de aceptación al servidor
	var accept_response = {
		"event": "accept-match"
	}
	WebSocketManager.send_message(accept_response)
	
	# Notificar en el chat
	var chat_system = get_node_or_null("../ChatSystem")
	if chat_system:
		chat_system.add_chat_message("Sistema", "✅ Has aceptado el desafío de " + player_name)
	
	connect_match()
	
	# Ocultar solicitud
	hide_match_request(player_id)
	
	# Actualizar lista
	call_deferred("request_online_players")

func connect_match():
	var connect_match = {
		"event" : "connect-match"
	}
	WebSocketManager.send_message(connect_match)

func _on_decline_match_request(player_id: String):
	print("❌ Declinando solicitud de partida del jugador: ", player_id)
	
	var request_data = pending_requests.get(player_id, {})
	var player_name = request_data.get("player_name", "")
	
	# Enviar respuesta de rechazo al servidor
	var decline_response = {
		"event": "reject-match"
	}
	WebSocketManager.send_message(decline_response)
	
	# Notificar en el chat
	var chat_system = get_node_or_null("../ChatSystem")
	if chat_system:
		chat_system.add_chat_message("Sistema", "❌ Has declinado el desafío de " + player_name)
	
	# Ocultar solicitud
	hide_match_request(player_id)
	
	# Actualizar lista
	call_deferred("request_online_players")

func setup_auto_decline_timer(player_id: String, timeout_seconds: float):
	# Crear timer para auto-declinar
	var timer = Timer.new()
	timer.wait_time = timeout_seconds
	timer.one_shot = true
	timer.timeout.connect(_on_auto_decline_timeout.bind(player_id, timer))
	add_child(timer)
	timer.start()
	
	print("⏰ Timer de auto-decline configurado para ", timeout_seconds, " segundos")

func _on_auto_decline_timeout(player_id: String, timer: Timer):
	print("⏰ Tiempo agotado para solicitud de: ", player_id)
	
	# Solo auto-declinar si la solicitud aún está pendiente
	if pending_requests.has(player_id):
		# Enviar rechazo automático
		var decline_response = {
			"event": "reject-match"
		}
		WebSocketManager.send_message(decline_response)
		
		# Notificar en el chat
		var chat_system = get_node_or_null("../ChatSystem")
		if chat_system:
			chat_system.add_chat_message("Sistema", "⏰ Solicitud de partida expirada automáticamente")
		
		# Ocultar solicitud
		hide_match_request(player_id)
		
		# Actualizar lista
		call_deferred("request_online_players")
	
	# Limpiar timer
	timer.queue_free()

func hide_match_request(player_id: String):
	print("🚫 Ocultando solicitud de partida del jugador: ", player_id)
	
	# Remover de solicitudes pendientes
	pending_requests.erase(player_id)
	
	# Buscar el item del jugador
	var player_item = player_items.get(player_id)
	if not player_item:
		return
	
	# Ocultar botones de aceptar/declinar
	var button_container = player_item.get_node_or_null("ButtonContainer")
	if button_container:
		button_container.visible = false
	
	# Mostrar botones de acción nuevamente si aplica
	var action_container = player_item.get_node_or_null("ActionContainer")
	if action_container:
		action_container.visible = true
	
	# Restaurar color de fondo normal
	var item_bg = player_item.get_node_or_null("ItemBg")
	if item_bg:
		if player_id == my_player_data.get("id", ""):
			item_bg.color = Color(0.2, 0.4, 0.6, 0.7)
		else:
			item_bg.color = Color(0.2, 0.2, 0.2, 0.5)
	
	# Restaurar estado normal
	var status_label = player_item.get_node_or_null("StatusLabel")
	if status_label:
		# Buscar los datos del jugador para restaurar su estado
		for player_data in current_players:
			if player_data.get("id") == player_id:
				status_label.text = get_status_text(player_data.get("status", "AVAILABLE"))
				status_label.modulate = status_colors.get(player_data.get("status", "AVAILABLE"), Color.GRAY)
				break

func _on_auto_refresh():
	if WebSocketManager and WebSocketManager.has_method("request_online_players"):
		WebSocketManager.request_online_players()
