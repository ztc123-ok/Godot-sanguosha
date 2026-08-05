extends Node2D
## 组合根节点。只负责在 Godot 生命周期中绑定领域管理器和 UI 管理器。

@onready var game_manager: GameManager = $GameManager
@onready var ui_manager: UIManager = $UIManager


func _ready() -> void:
	ui_manager.bind_game_manager(game_manager)
	game_manager.battle_finished.connect(_on_battle_finished)
	if DeveloperLauncher.has_pending_launch():
		call_deferred("_apply_developer_configuration")


func _apply_developer_configuration() -> void:
	var configuration: Dictionary = DeveloperLauncher.consume_launch_configuration()
	if configuration.is_empty():
		return
	var enemy_general_ids: Array[StringName] = []
	for general_id: Variant in configuration.get("enemy_general_ids", []):
		enemy_general_ids.append(StringName(general_id))
	var configured := game_manager.prepare_match_with_generals(
		StringName(configuration.get("player_general_id", GeneralFactory.DEFAULT_PLAYER_GENERAL)),
		enemy_general_ids,
		bool(configuration.get("skip_general_selection", true))
	)
	if configured:
		return
	push_error("开发者启动配置无法应用，已回退到普通选将流程。")
	DeveloperLauncher.end_session()
	game_manager.begin_general_selection(false)


func _on_battle_finished(player_won: bool) -> void:
	## 纯 AI 自动化模式下由 GameManager 自行按相同配置重开，不介入场景流转。
	if game_manager.is_automated_mode():
		return
	if player_won:
		if DeveloperLauncher.is_session_active():
			DeveloperLauncher.end_session()
		var completed_battle := BattleSession.report_outcome(true)
		var return_scene := str(completed_battle.get("return_scene", "res://scenes/MapScene.tscn"))
		get_tree().call_deferred("change_scene_to_file", return_scene)
	else:
		var battle := BattleSession.active_definition()
		if bool(battle.get("retry_on_loss", true)):
			BattleSession.report_outcome(false)
			## 沿用当前全部武将，直接重开本场战斗。
			game_manager.call_deferred("request_restart_match")
		else:
			if DeveloperLauncher.is_session_active():
				DeveloperLauncher.end_session()
			var completed_battle := BattleSession.report_outcome(false)
			var failure_scene := str(completed_battle.get("failure_scene", "res://scenes/MapScene.tscn"))
			get_tree().call_deferred("change_scene_to_file", failure_scene)
