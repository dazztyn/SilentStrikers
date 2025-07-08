extends Node
class_name ItemSpawner

# Simplified item spawning system that replaces complex texture-based logic

var spawn_points_items: Array[NodePath] = []
var spawn_points_powerups: Array[NodePath] = []
var parent_node: Node2D
var current_spawn_index: int = 0

# Item type pools for random selection
var collectible_types = ["collectible_high", "collectible_medium", "collectible_low"]
var powerup_types = ["speed_boost", "invisibility", "health_restore"]

func _init(parent: Node2D, item_points: Array[NodePath], powerup_points: Array[NodePath]):
	parent_node = parent
	spawn_points_items = item_points
	spawn_points_powerups = powerup_points

func spawn_random_item() -> BaseItem:
	if spawn_points_items.size() == 0:
		return null
	
	var item_type = collectible_types[randi() % collectible_types.size()]
	var spawn_position = get_random_spawn_position(spawn_points_items)
	var item = BaseItem.create_item(item_type, spawn_position, Vector2(0.2, 0.2))
	
	if parent_node and item:
		parent_node.add_child(item)
	
	return item

func spawn_random_powerup() -> BaseItem:
	if spawn_points_powerups.size() == 0:
		return null
	
	var powerup_type = powerup_types[randi() % powerup_types.size()]
	var spawn_position = get_random_spawn_position(spawn_points_powerups)
	var powerup = BaseItem.create_item(powerup_type, spawn_position, Vector2(0.3, 0.3))
	
	if parent_node and powerup:
		parent_node.add_child(powerup)
	
	return powerup

func spawn_specific_item(item_type: String, is_powerup: bool = false) -> BaseItem:
	var spawn_points = spawn_points_powerups if is_powerup else spawn_points_items
	var scale_factor = Vector2(0.3, 0.3) if is_powerup else Vector2(0.2, 0.2)
	
	if spawn_points.size() == 0:
		return null
	
	var spawn_position = get_random_spawn_position(spawn_points)
	var item = BaseItem.create_item(item_type, spawn_position, scale_factor)
	
	if parent_node and item:
		parent_node.add_child(item)
	
	return item

func get_random_spawn_position(spawn_points: Array[NodePath]) -> Vector2:
	if spawn_points.size() == 0:
		return Vector2.ZERO
	
	var new_index = randi() % spawn_points.size()
	# Avoid spawning in the same location twice in a row
	if new_index == current_spawn_index and spawn_points.size() > 1:
		new_index = (new_index + 1) % spawn_points.size()
	
	current_spawn_index = new_index
	
	var spawn_node = parent_node.get_node_or_null(spawn_points[current_spawn_index])
	if spawn_node:
		return spawn_node.global_position
	
	return Vector2.ZERO

func get_spawn_point_count() -> Dictionary:
	return {
		"items": spawn_points_items.size(),
		"powerups": spawn_points_powerups.size()
	}