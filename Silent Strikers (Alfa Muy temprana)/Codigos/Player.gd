extends CharacterBody2D

# === VARIABLES BÁSICAS ===
var puntaje: int = 0
var speed: float = 500.0
var initial_speed: float = 500.0
@export var velMax: float = 750.0
var salud: int = 3
var max_salud: int = 3
var muerto: bool = false
var puntaje_win: int = 1000
var game: bool = false

# === SISTEMA DE INVISIBILIDAD ===
var invisibility_time: float = 0.0
var invisibility_duration: float = 5.0
var invisibility_alpha: float = 0.5
var invisibilidad_usada: bool = false

# === REFERENCIAS A NODOS ===
var jugador: CharacterBody2D
var mapa: Node2D
@onready var footstep_audio: AudioStreamPlayer2D = $pasos
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# === SISTEMA DE MODO DE JUEGO ===
var is_multiplayer: bool = false
var multiplayer_errors: int = 0

# === SISTEMA DE SONIDOS DE PASO ===
var is_walking: bool = false
var footstep_timer: float = 0.0
var footstep_interval: float = 0.4

# === SISTEMA DE HECHIZOS ===
var spell_z_cost: int = 200
var spell_x_cost: int = 600
var spell_c_cost: int = 1000

# === SISTEMA DE CONFUSIÓN ===
var controls_confused: bool = false

# === SISTEMA DE EFECTOS TEMPORALES ===
var active_effects: Array[Dictionary] = []

func _ready():
	# Configuración inicial
	Singleton.registrar_player(self)
	jugador = self
	mapa = get_parent()
	
	# Detectar modo de juego
	detect_game_mode()
	
	# Configurar audio
	setup_footstep_audio()
	
	# Conectar señales multiplayer
	if is_multiplayer and WebSocketManager:
		WebSocketManager.connect("game_data_received", _on_spell_received)
		WebSocketManager.connect("game_ended", _on_opponent_won)
	
	print("🎮 Player inicializado - Modo: ", "MULTIPLAYER" if is_multiplayer else "SINGLEPLAYER")

func detect_game_mode():
	if WebSocketManager and WebSocketManager.is_in_match():
		is_multiplayer = true
		print("🌐 Modo: MULTIPLAYER")
	else:
		is_multiplayer = false
		print("🎮 Modo: SINGLEPLAYER")

func setup_footstep_audio():
	if footstep_audio:
		footstep_audio.volume_db = -15.0
		footstep_audio.autoplay = false
		footstep_audio.stream_paused = false

# === SISTEMA DE MOVIMIENTO Y ANIMACIÓN ===
func _process(delta):
	if muerto:
		return
	
	# Procesar efectos temporales
	process_temporary_effects(delta)
	
	# Sistema de invisibilidad
	if invisibilidad_usada:
		invisibility_time -= delta
		if invisibility_time <= 0.0:
			end_invisibility()
	
	# Movimiento
	handle_movement()
	
	# Animaciones
	update_animation()
	
	# Sonidos de pasos
	handle_footstep_sounds(delta)
	
	# Movimiento físico
	move_and_slide()

func handle_movement():
	velocity = Vector2.ZERO
	
	# Determinar controles (normales o confundidos)
	var right_pressed = Input.is_action_pressed("ui_right")
	var left_pressed = Input.is_action_pressed("ui_left")
	var down_pressed = Input.is_action_pressed("ui_down")
	var up_pressed = Input.is_action_pressed("ui_up")
	
	if controls_confused:
		# Controles invertidos
		if right_pressed:
			velocity.x = -1
		if left_pressed:
			velocity.x = 1
		if down_pressed:
			velocity.y = -1
		if up_pressed:
			velocity.y = 1
	else:
		# Controles normales
		if right_pressed:
			velocity.x = 1
		if left_pressed:
			velocity.x = -1
		if down_pressed:
			velocity.y = 1
		if up_pressed:
			velocity.y = -1
	
	# Normalizar y aplicar velocidad
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed

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

# === SISTEMA DE SONIDOS DE PASO ===
func handle_footstep_sounds(delta):
	var was_walking = is_walking
	is_walking = velocity.length() > 0
	
	if is_walking:
		footstep_timer += delta
		
		# Ajustar intervalo según velocidad
		var current_interval = footstep_interval
		if velocity.length() > 400:
			current_interval = 0.25
		elif velocity.length() > 300:
			current_interval = 0.3
		else:
			current_interval = 0.4
		
		if footstep_timer >= current_interval:
			footstep_timer = 0.0
			play_footstep_sound()
	else:
		footstep_timer = 0.0
		if was_walking and footstep_audio and footstep_audio.playing:
			stop_footstep_sound()

func play_footstep_sound():
	if footstep_audio and footstep_audio.stream and not footstep_audio.playing:
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
	if is_multiplayer and puntaje < spell_z_cost:
		print("❌ Hechizo Z - Puntos insuficientes. Necesitas: ", spell_z_cost, " | Tienes: ", puntaje)
		return
	
	if is_multiplayer:
		send_spell("Z")
		puntaje -= spell_z_cost
		print("🔥 HECHIZO Z ENVIADO! Costo: ", spell_z_cost, " | Puntos restantes: ", puntaje)

func try_cast_spell_x():
	if is_multiplayer and puntaje < spell_x_cost:
		print("❌ Hechizo X - Puntos insuficientes. Necesitas: ", spell_x_cost, " | Tienes: ", puntaje)
		return
	
	if is_multiplayer:
		send_spell("X")
		puntaje -= spell_x_cost
		print("⚡ HECHIZO X ENVIADO! Costo: ", spell_x_cost, " | Puntos restantes: ", puntaje)

func try_cast_spell_c():
	if is_multiplayer and puntaje < spell_c_cost:
		print("❌ Hechizo C - Puntos insuficientes. Necesitas: ", spell_c_cost, " | Tienes: ", puntaje)
		return
	
	if is_multiplayer:
		send_spell("C")
		puntaje -= spell_c_cost
		print("💥 HECHIZO C ENVIADO! Costo: ", spell_c_cost, " | Puntos restantes: ", puntaje)

func send_spell(spell_type: String):
	if not is_multiplayer or not WebSocketManager:
		return
	
	var spell_data = {"spell": spell_type}
	WebSocketManager.send_game_data(spell_data)
	print("📡 Hechizo ", spell_type, " enviado: ", spell_data)
	
	if spell_type != "death":
		show_spell_cast_effect(spell_type)

func show_spell_cast_effect(spell: String):
	var effect_color = Color.WHITE
	match spell:
		"Z":
			effect_color = Color.BLUE
		"X":
			effect_color = Color.PURPLE
		"C":
			effect_color = Color.RED
	
	apply_temporary_effect("spell_cast", 1.0, {"color": effect_color})

# === SISTEMA DE EFECTOS RECIBIDOS ===
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

func apply_spell_z_effect():
	print("🐌 Has sido ralentizado por el oponente")
	var slow_amount = 200.0
	var original_speed = speed
	speed = max(100, speed - slow_amount)
	
	apply_temporary_effect("slowness", 8.0, {
		"original_speed": original_speed,
		"color": Color.CYAN
	})

func apply_spell_x_effect():
	print("🌀 Tus controles han sido confundidos por el oponente")
	controls_confused = true
	
	apply_temporary_effect("confusion", 10.0, {
		"color": Color.MAGENTA
	})

func apply_spell_c_effect():
	print("😵 Aturdido por el rival")
	var original_speed = speed
	speed = 0
	
	apply_temporary_effect("stun", 4.0, {
		"original_speed": original_speed,
		"color": Color.ORCHID
	})

func apply_opponent_death_notification():
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
	if not is_multiplayer:
		return
	
	print("😵 El oponente ha ganado la partida")
	muerto = true
	game = true
	go_to_defeat_scene()

# === SISTEMA DE EFECTOS TEMPORALES ===
func apply_temporary_effect(effect_type: String, duration: float, data: Dictionary = {}):
	var effect = {
		"type": effect_type,
		"duration": duration,
		"data": data
	}
	
	active_effects.append(effect)
	
	# Aplicar efecto visual si tiene color
	if data.has("color"):
		modulate = data["color"]

func process_temporary_effects(delta):
	for i in range(active_effects.size() - 1, -1, -1):
		var effect = active_effects[i]
		effect["duration"] -= delta
		
		if effect["duration"] <= 0:
			end_temporary_effect(effect)
			active_effects.remove_at(i)

func end_temporary_effect(effect: Dictionary):
	match effect["type"]:
		"slowness":
			if effect["data"].has("original_speed"):
				speed = effect["data"]["original_speed"]
			print("⭐ Efecto de ralentización terminado")
		
		"confusion":
			controls_confused = false
			print("⭐ Efecto de confusión terminado")
		
		"stun":
			if effect["data"].has("original_speed"):
				speed = effect["data"]["original_speed"]
			print("⭐ Efecto de aturdimiento terminado")
		
		"spell_cast":
			pass  # Solo efecto visual
	
	# Restaurar color si no hay otros efectos con color
	var has_color_effect = false
	for active_effect in active_effects:
		if active_effect["data"].has("color"):
			has_color_effect = true
			break
	
	if not has_color_effect:
		modulate = Color.WHITE

# === FUNCIONES DE STATS Y EFECTOS ===
func aumentar_puntaje(cantidad: int):
	puntaje += cantidad
	print("Puntaje actual: ", puntaje)
	
	if is_multiplayer:
		print("  Hechizos disponibles:")
		if puntaje >= spell_z_cost:
			print("    ✅ Z (", spell_z_cost, " pts)")
		if puntaje >= spell_x_cost:
			print("    ✅ X (", spell_x_cost, " pts)")
		if puntaje >= spell_c_cost:
			print("    ✅ C (", spell_c_cost, " pts)")
	
	
	if puntaje >= puntaje_win and is_multiplayer == false:
		game = true
		print("¡Ganaste por puntaje!")
		
		if is_multiplayer and WebSocketManager:
			WebSocketManager.finish_game({
				"winner_reason": "reached_target_score",
				"final_score": puntaje
			})
		
		go_to_victory_scene()

func aumentar_velocidad(cantidad: float):
	if muerto:
		return
	
	speed = min(speed + cantidad, velMax)
	print("Velocidad aumentada. Velocidad actual: ", speed)

func perder_salud(cantidad: int):
	salud -= cantidad
	print("Salud actual: ", salud)
	
	if salud <= 0:
		muerto = true
		print("💀 Has muerto!")
		
		if is_multiplayer and WebSocketManager:
			send_spell("death")
			print("📡 Señal de muerte enviada al oponente")
		
		go_to_defeat_scene()

func restaurar_salud(cantidad: int):
	if muerto:
		return
	
	salud = min(salud + cantidad, max_salud)
	print("Salud restaurada. Salud actual: ", salud)

func aplicar_invisibilidad(duration: float, alpha: float):
	if muerto:
		return
	
	collision_layer = 0
	modulate.a = alpha
	invisibilidad_usada = true
	invisibility_time = duration
	invisibility_duration = duration
	invisibility_alpha = alpha
	
	print("Invisibilidad aplicada por: ", duration, " segundos")

func end_invisibility():
	invisibility_time = 0.0
	invisibilidad_usada = false
	collision_layer = 1|2|3
	
	# Restaurar alpha solo si no hay otros efectos
	var has_color_effect = false
	for effect in active_effects:
		if effect["data"].has("color"):
			has_color_effect = true
			break
	
	if not has_color_effect:
		modulate.a = 1.0
	
	print("Invisibilidad terminada")

func invisible() -> bool:
	return invisibilidad_usada

# === FUNCIONES DE NAVEGACIÓN ===
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
		GameState.current_map_path = get_tree().current_scene.scene_file_path
		print("💀 Cargando pantalla de derrota SINGLEPLAYER")
		get_tree().change_scene_to_file("res://Escenas/defeat_screen.tscn")

# === FUNCIONES DE COMPATIBILIDAD (para items existentes) ===
func transparentar(transparencia: float):
	aplicar_invisibilidad(invisibility_duration, transparencia)

func recoger():
	# Función de compatibilidad - ahora manejado por el sistema de items
	print("Item recogido (sistema legacy)")

# === MANEJO DE ERRORES MULTIPLAYER ===
func _on_websocket_message(data: Dictionary):
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
