extends Node2D
## 组合根节点。只负责在 Godot 生命周期中绑定领域管理器和 UI 管理器。

const MAP_SCENE := "res://scenes/MapScene.tscn"

@onready var game_manager: GameManager = $GameManager
@onready var ui_manager: UIManager = $UIManager


func _ready() -> void:
	ui_manager.bind_game_manager(game_manager)
	game_manager.battle_finished.connect(_on_battle_finished)


func _on_battle_finished(player_won: bool) -> void:
	## 纯 AI 自动化模式下由 GameManager 自行按相同配置重开，不介入场景流转。
	if game_manager.is_automated_mode():
		return
	if player_won:
		PrologueState.complete_active_battle()
		get_tree().call_deferred("change_scene_to_file", MAP_SCENE)
	else:
		# 玩家阵亡后沿用当前全部武将，直接重开本场战斗（第二战重开仍是 1v2）。
		game_manager.call_deferred("request_restart_match")
