extends Node
 
const FADE_DURATION := 0.3
const GAME_SCREEN_PATH := "res://scenes/main/GameScreen.tscn"
 
@onready var _fade_rect: ColorRect = $SceneTransition/FadeRect
@onready var _current_scene_node: Node = $CurrentScene
 
var _is_transitioning := false
 
 
func _ready() -> void:
	_fade_rect.modulate.a = 0.0
	_load_initial_scene()
 
 
func _load_initial_scene() -> void:
	var scene = load(GAME_SCREEN_PATH)
	var instance = scene.instantiate()
	_current_scene_node.add_child(instance)
 
 
# Cambia la escena activa con fade. No se usa en el flujo normal del juego.
func change_scene(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
 
	await _fade(1.0)
 
	for child in _current_scene_node.get_children():
		child.queue_free()
 
	var scene = load(path)
	var instance = scene.instantiate()
	_current_scene_node.add_child(instance)
 
	await _fade(0.0)
	_is_transitioning = false
 
 
func _fade(target_alpha: float) -> void:
	var tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", target_alpha, FADE_DURATION)
	await tween.finished
