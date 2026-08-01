extends Node2D
## 组合根节点。只负责在 Godot 生命周期中绑定领域管理器和 UI 管理器。

const MAP_SCENE := "res://scenes/MapScene.tscn"

@onready var game_manager: GameManager = $GameManager
@onready var ui_manager: UIManager = $UIManager


func _ready() -> void:
	ui_manager.bind_game_manager(game_manager)
	game_manager.match_finished.connect(_on_match_finished)


func _on_match_finished(winner: BattlePlayer, _loser: BattlePlayer) -> void:
	if winner == game_manager.player1:
		PrologueState.complete_active_battle()
		get_tree().call_deferred("change_scene_to_file", MAP_SCENE)
	else:
		# 玩家阵亡后沿用当前双方武将，直接重开本场战斗。
		game_manager.call_deferred("request_restart_match")
