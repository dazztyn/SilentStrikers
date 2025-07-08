extends CharacterBody2D

var puntaje
var speed = 500
var initial_speed = 500
@export var velMax = 750
var salud
var muerto: bool = false # Para cambiar el salud <= 0
var puntaje_win = 2500
var game = false # Para ver si la partida termino o sigue
var invisibility_time = 5
var jugador: CharacterBody2D
var mapa: Node2D
@onready var footstep_audio: AudioStreamPlayer2D = $pasos

# === SISTEMA DE MODO DE JUEGO ===
var is_multiplayer: bool = false
var multiplayer_errors: int = 0  # Contador de errores de multiplayer

# === VARIABLES PARA SONIDOS DE PASO ===
var is_walking: bool = false
var footstep_timer: float = 0.0
var footstep_interval: float = 0.4  # Intervalo entre pasos en segundos

# === SISTEMA DE HECHIZOS SIMPLES ===
var spell_z_cost = 200    # Costo hechizo Z
var spell_x_cost = 600      # Costo hechizo X  
var spell_c_cost = 1000      # Costo hechizo C

# === NUEVO SISTEMA DE ITEMS ===
@export var spawn_points_it: Array[NodePath] = []
@export var spawn_points_pd: Array[NodePath] = []
var item_spawner: ItemSpawner
var invisibilidad_usada = false #para que el cooldown empiece a correr sólo cuando se usó
var item_recogido = false #para que se cambie la posicion del item robable
var controls_confused = false
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	Singleton.registrar_player(self)
	salud = 3
	jugador = get_node(".")
	mapa = get_node("..")
	puntaje = 0
	muerto = false
	
	# Initialize new item spawner system
	item_spawner = ItemSpawner.new(mapa, spawn_points_it, spawn_points_pd)
	
	# Detectar modo de juego
	detect_game_mode()
	
	setup_footstep_audio()
	
	# Conectar señales solo si es multiplayer
	if is_multiplayer and WebSocketManager:
		WebSocketManager.connect("game_data_received", _on_spell_received)
		WebSocketManager.connect("game_ended", _on_opponent_won)
		# Conectar también para manejar errores de send-game-data

func detect_game_mode():
	if WebSocketManager and WebSocketManager.is_in_match():
		is_multiplayer = true
		print("🌐 Modo: MULTIPLAYER")
	else:
		is_multiplayer = false
		print("🎮 Modo: SINGLEPLAYER")

func setup_footstep_audio():
	if footstep_audio:
		footstep_audio.volume_db = -15.0  # Ajusta el volumen según necesites
		footstep_audio.autoplay = false
		footstep_audio.stream_paused = false

func _on_websocket_message(data: Dictionary):
	# Interceptar mensajes para detectar errores de send-game-data
	var event = data.get("event", "")
	var status = data.get("status", "")
	var msg = data.get("msg", "")
	
	if event == "send-game-data" and status == "ERROR":
		print("⚠️ Error multiplayer detectado: ", msg)
		multiplayer_errors += 1
		
		if multiplayer_errors >= 3:
			print("🔄 Cambiando a modo SINGLEPLAYER")
			is_multiplayer = false
			multiplayer_errors = 0

# Actualización del movimiento y las animaciones
func _process(delta):
	if muerto:
		return
	
	velocity = Vector2()
	
	# === SISTEMA DE INVISIBILIDAD SIMPLIFICADO ===
	if invisible():
		invisibility_time -= delta
		if invisibility_time <= 0:
			_end_invisibility()
	
	# === SISTEMA DE SPAWNEO SIMPLIFICADO ===
	if item_recogido:
		item_recogido = false
		if item_spawner:
			item_spawner.spawn_random_item()

	# === CONTROLES CON CONFUSIÓN ===
	if controls_confused:
		# Controles invertidos
		if Input.is_action_pressed("ui_right"):
			velocity.x -= 1  # Invertido: derecha va a izquierda
		if Input.is_action_pressed("ui_left"):
			velocity.x += 1  # Invertido: izquierda va a derecha
		if Input.is_action_pressed("ui_down"):
			velocity.y -= 1  # Invertido: abajo va arriba
		if Input.is_action_pressed("ui_up"):
			velocity.y += 1  # Invertido: arriba va abajo
	else:
		# Controles normales
		if Input.is_action_pressed("ui_right"):
			velocity.x += 1
		if Input.is_action_pressed("ui_left"):
			velocity.x -= 1
		if Input.is_action_pressed("ui_down"):
			velocity.y += 1
		if Input.is_action_pressed("ui_up"):
			velocity.y -= 1
		
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
	
	update_animation()
	handle_footstep_sounds(delta)
	move_and_slide()

# === NUEVAS FUNCIONES PARA EL SISTEMA DE ITEMS ===

func _end_invisibility():
	invisibility_time = 5
	jugador.collision_layer = 1|2|3
	modulate.a = 1
	invisibilidad_usada = false
	# Spawn a new powerup when invisibility ends
	if item_spawner:
		item_spawner.spawn_random_powerup()

# === SISTEMA DE SONIDOS DE PASO ===
func handle_footstep_sounds(delta):
	var was_walking = is_walking
	is_walking = velocity.length() > 0
	
	if is_walking:
		footstep_timer += delta
		# Ajustar intervalo según velocidad
		var current_interval = footstep_interval
		if velocity.length() > 400:  # Corriendo rápido
			current_interval = 0.25
		elif velocity.length() > 300:  # Corriendo normal
			current_interval = 0.3
		else:  # Caminando
			current_interval = 0.4
		
		if footstep_timer >= current_interval:
			footstep_timer = 0.0
			play_footstep_sound()
	else:
		footstep_timer = 0.0
		# Si dejó de caminar, parar el audio gradualmente
		if was_walking and footstep_audio and footstep_audio.playing:
			stop_footstep_sound()

func play_footstep_sound():
	if footstep_audio and footstep_audio.stream:
		# Solo reproducir si no está ya sonando para evitar solapamientos
		if not footstep_audio.playing:
			footstep_audio.play()

func stop_footstep_sound():
	if footstep_audio and footstep_audio.playing:
		footstep_audio.stop()



# === SISTEMA DE HECHIZOS ===

func _input(event):
	if muerto:
		return
		
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Z:
				try_cast_spell_z()
			KEY_X:
				try_cast_spell_x()
			KEY_C:
				try_cast_spell_c()

func try_cast_spell_z():
	if is_multiplayer:
		if puntaje < spell_z_cost:
			print("❌ Hechizo Z - Puntos insuficientes. Necesitas: ", spell_z_cost, " | Tienes: ", puntaje)
			return

	if is_multiplayer:
		send_spell("Z")
		puntaje -= spell_z_cost
		print("🔥 HECHIZO Z ENVIADO! Costo: ", spell_z_cost, " | Puntos restantes: ", puntaje)
		

func try_cast_spell_x():
	if is_multiplayer:
		if puntaje < spell_x_cost:
			print("❌ Hechizo X - Puntos insuficientes. Necesitas: ", spell_x_cost, " | Tienes: ", puntaje)
			return
	
	if is_multiplayer:
		send_spell("X")
		puntaje -= spell_x_cost
		print("⚡ HECHIZO X ENVIADO! Costo: ", spell_x_cost, " | Puntos restantes: ", puntaje)

func try_cast_spell_c():
	if is_multiplayer:
		if puntaje < spell_c_cost:
			print("❌ Hechizo C - Puntos insuficientes. Necesitas: ", spell_c_cost, " | Tienes: ", puntaje)
			return

	if is_multiplayer:
		send_spell("C")
		puntaje -= spell_c_cost
		print("💥 HECHIZO C ENVIADO! Costo: ", spell_c_cost, " | Puntos restantes: ", puntaje)

func send_spell(spell_type: String):
	# Solo enviar en modo multiplayer
	if not is_multiplayer:
		return
	
	if WebSocketManager:
		var spell_data = {
			"spell": spell_type
		}
		
		WebSocketManager.send_game_data(spell_data)
		print("📡 Hechizo ", spell_type, " enviado: ", spell_data)
		
		# Efecto visual local
		if spell_type != "death":
			show_spell_cast_effect(spell_type)
	else:
		print("⚠️ WebSocketManager no disponible")

func show_spell_cast_effect(spell: String):
	match spell:
		"Z":
			modulate = Color.BLUE
		"X":
			modulate = Color.PURPLE
		"C":
			modulate = Color.RED
	
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(func(): modulate = Color.WHITE)
	add_child(timer)
	timer.start()

# === RECIBIR HECHIZOS DEL OPONENTE (SOLO MULTIPLAYER) ===

func _on_spell_received(data: Dictionary):
	if not is_multiplayer:
		return
		
	var spell = data.get("spell", "")
	
	if spell != "":
		print("🎯 Hechizo recibido del oponente: ", spell)
		apply_spell_effect(spell)

func apply_spell_effect(spell: String):
	match spell:
		"Z":
			apply_spell_z_effect()
		"X":
			apply_spell_x_effect()
		"C":
			apply_spell_c_effect()
		"death":
			apply_opponent_death_notification()
		_:
			print("⚠️ Hechizo desconocido: ", spell)

func apply_opponent_death_notification():
	# Solo en multiplayer
	if not is_multiplayer:
		return
		
	print("🎉 El oponente ha muerto - ¡HAS GANADO!")
	
	game = true
	muerto = false
	
	if WebSocketManager:
		WebSocketManager.finish_game({
			"winner_reason": "opponent_died",
			"final_score": puntaje
		})
	
	go_to_victory_scene()

func _on_opponent_won(data: Dictionary):
	# Solo en multiplayer
	if not is_multiplayer:
		return
		
	print("😵 El oponente ha ganado la partida")
	
	muerto = true
	game = true
	
	go_to_defeat_scene()

func apply_spell_z_effect():
	print("🐌 Has sido ralentizado por el oponente")
	
	var original_speed = speed
	speed = max(100, speed - 200)
	modulate = Color.CYAN
	var timer = Timer.new()
	timer.wait_time = 8.0
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if not muerto:
			speed = original_speed
			modulate = Color.WHITE
			print("⭐ Efecto de ralentización terminado")
	)
	add_child(timer)
	timer.start()

func apply_spell_c_effect():
	print("😵 Aturdido por el rival papu")
	
	var original_speed = speed
	speed = 0
	modulate = Color.ORCHID
	var timer = Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if not muerto:
			speed = original_speed
			modulate = Color.WHITE
			print("Aturdision complertada")
	)
	add_child(timer)
	timer.start()

func apply_spell_x_effect():
	print("🌀 Tus controles han sido confundidos por el oponente")
	
	controls_confused = true
	modulate = Color.MAGENTA
	var timer = Timer.new()
	timer.wait_time = 10.0
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if not muerto:
			controls_confused = false
			modulate = Color.WHITE
			print("⭐ Efecto de confusión terminado")
	)
	add_child(timer)
	timer.start()

# === FUNCIONES ORIGINALES ===

func update_animation():
	if velocity.length() > 0:
		animated_sprite.play()
		if velocity.x != 0:
			animated_sprite.animation = "Derecha" 
			animated_sprite.flip_h = velocity.x < 0
		elif velocity.y != 0:
			if velocity.y > 0:
				animated_sprite.animation = "Abajo"
			else:
				animated_sprite.animation = "Arriba"
	else:
		animated_sprite.stop()

func aumentar_puntaje(cantidad):
	puntaje += cantidad
	print("Puntaje actual: ", puntaje)
	
	if is_multiplayer:
		if puntaje >= spell_z_cost:
			print("  ✅ Z disponible (", spell_z_cost, " pts)")
		if puntaje >= spell_x_cost:
			print("  ✅ X disponible (", spell_x_cost, " pts)")
		if puntaje >= spell_c_cost:
			print("  ✅ C disponible (", spell_c_cost, " pts)")

	
	if puntaje >= puntaje_win:
		game = true
		print("¡Ganaste por puntaje!")
		
		if is_multiplayer:
			# Multiplayer: enviar finish-game
			if WebSocketManager:
				WebSocketManager.finish_game({
					"winner_reason": "reached_target_score",
					"final_score": puntaje
				})
		
		go_to_victory_scene()

func perder_salud(cantidad):
	salud -= cantidad
	print("Salud actual: ", salud)
	
	if salud <= 0:
		muerto = true
		print("💀 Has muerto!")
		
		if is_multiplayer:
			# Multiplayer: avisar muerte al oponente
			if WebSocketManager:
				send_spell("death")
				print("📡 Señal de muerte enviada al oponente")
		
		go_to_defeat_scene()

# === FUNCIONES DE NAVEGACIÓN SEGÚN MODO ===

func go_to_victory_scene():
	if is_multiplayer:
		print("🎯 Cargando pantalla de victoria MULTIPLAYER")
		get_tree().change_scene_to_file("res://GUI/Escenas/win_escene.tscn")
	else:
		print("🎯 Cargando pantalla de victoria SINGLEPLAYER")
		get_tree().change_scene_to_file("res://Escenas/victory_screen.tscn")

func go_to_defeat_scene():
	if is_multiplayer:
		print("💀 Cargando pantalla de derrota MULTIPLAYER")
		get_tree().change_scene_to_file("res://GUI/Escenas/loss_escene.tscn")
	else:
		print("💀 Cargando pantalla de derrota SINGLEPLAYER")
		get_tree().change_scene_to_file("res://Escenas/defeat_screen.tscn")

func aumentar_velocidad(cantidad):
	if muerto or speed >= velMax:
		speed = velMax
		return
	speed += cantidad
	# Spawn a new powerup using the new system
	if item_spawner:
		item_spawner.spawn_random_powerup()
	print("Velocidad actual: ", speed)

# === NUEVAS FUNCIONES REQUERIDAS ===

func aplicar_invisibilidad(transparencia):
	"""Nueva función para aplicar invisibilidad reemplazando transparentar()"""
	jugador.collision_layer = 0
	modulate.a = transparencia
	invisibilidad_usada = true
	print("Invisibilidad aplicada con transparencia: ", transparencia)

func restaurar_salud(cantidad):
	"""Nueva función para restaurar salud"""
	if muerto:
		return
	salud += cantidad
	print("Salud restaurada. Salud actual: ", salud)

# === FUNCIONES ORIGINALES MANTENIDAS ===

#hace que el jugador sea indetectable y cambia la opacidad del sprite
func transparentar(transparencia):
	"""Función original mantenida por compatibilidad"""
	aplicar_invisibilidad(transparencia)

func invisible():
	return invisibilidad_usada

func recoger():
	item_recogido = true

# === FUNCIONES SIMPLIFICADAS DE SPAWNEO ===
# Las funciones de spawneo ahora se manejan através del ItemSpawner
# Mantenemos funciones simplificadas para compatibilidad si es necesario

func spawn_item_at_random_location():
	"""Función simplificada para spawnar item en ubicación aleatoria"""
	if item_spawner:
		item_spawner.spawn_random_item()

func spawn_powerup_at_random_location():
	"""Función simplificada para spawnar powerup en ubicación aleatoria"""
	if item_spawner:
		item_spawner.spawn_random_powerup()
