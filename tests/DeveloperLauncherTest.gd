extends Node
## 开发者入口、确定性阵容与跳过选将的回归测试。

var failures: Array[String] = []


func _ready() -> void:
	DeveloperLauncher.cancel_pending_launch()
	PrologueState.completed_battles = 0
	PrologueState.active_battle = 0
	_test_configuration_validation()
	await _test_skip_selection_launch()
	await _test_review_selection_launch()
	await _test_dynamic_catalog_battle()
	_test_command_line_parsing()
	await _test_map_entry_visibility()
	DeveloperLauncher.cancel_pending_launch()
	PrologueState.active_battle = 0
	if failures.is_empty():
		print("DEVELOPER_LAUNCHER_TEST: PASS (catalog / dynamic 1vN roster / skip selection / CLI)")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("DEVELOPER_LAUNCHER_TEST: %s" % failure)
		get_tree().quit(1)


func _test_configuration_validation() -> void:
	_expect(
		not DeveloperLauncher.request_launch(3, &"caocao", [&"lvbu"], true),
		"拒绝不存在的关卡"
	)
	_expect(
		not DeveloperLauncher.request_launch(2, &"caocao", [&"lvbu", &"caocao"], true),
		"拒绝重复武将阵容"
	)
	_expect(
		not DeveloperLauncher.request_launch(1, &"caocao", [&"lvbu", &"zhangliao"], true),
		"拒绝超过关卡容量的敌方阵容"
	)
	BattleCatalog.register_battle({
		"id": &"duplicate_policy_test",
		"display_name": "重复武将策略验证",
		"enemy_count": 3,
		"allow_duplicate_generals": true,
	})
	_expect(
		DeveloperLauncher.request_launch(
			&"duplicate_policy_test",
			&"caocao",
			[&"lvbu", &"lvbu", &"lvbu"],
			true
		),
		"战斗定义可显式允许任意数量的重复武将"
	)
	DeveloperLauncher.cancel_pending_launch()
	BattleSession.clear_active_battle()
	BattleCatalog.unregister_battle(&"duplicate_policy_test")


func _test_skip_selection_launch() -> void:
	_expect(
		DeveloperLauncher.request_launch(2, &"caocao", [&"xuchu", &"lvbu"], true),
		"接受第二战确定性启动配置"
	)
	_expect(PrologueState.active_battle == 2, "开发入口绕过进度并激活第二战")
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var game: GameManager = main.get_node("GameManager")
	_expect(game.players.size() == 3, "第二战创建玩家与两名 AI")
	_expect(game.player1.general_id == &"caocao", "指定玩家武将生效")
	_expect(
		game.enemies[0].general_id == &"xuchu" and game.enemies[1].general_id == &"lvbu",
		"两名敌方武将按配置顺序生效"
	)
	_expect(game.flow_state != GameManager.FlowState.GENERAL_SELECTION, "勾选跳过选将后直接开局")
	_expect(DeveloperLauncher.is_session_active(), "消费配置后标记开发测试会话")
	main.queue_free()
	await get_tree().process_frame
	DeveloperLauncher.end_session()


func _test_review_selection_launch() -> void:
	_expect(
		DeveloperLauncher.request_launch(1, &"zhaoyun", [&"zhangfei"], false),
		"接受停留在选将界面的配置"
	)
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var game: GameManager = main.get_node("GameManager")
	var ui: UIManager = main.get_node("UIManager")
	_expect(game.players.size() == 2, "第一战维持 1v1")
	_expect(game.flow_state == GameManager.FlowState.GENERAL_SELECTION, "未跳过时停留在选将阶段")
	_expect(
		game.player1.general_id == &"zhaoyun" and game.enemies[0].general_id == &"zhangfei",
		"选将界面已预载指定阵容"
	)
	_expect(ui.general_panel.visible and not ui.start_match_button.disabled, "指定阵容可在选将界面复核并开局")
	main.queue_free()
	await get_tree().process_frame
	DeveloperLauncher.end_session()


func _test_command_line_parsing() -> void:
	DeveloperLauncher.cancel_pending_launch()
	var accepted := DeveloperLauncher.parse_command_line(PackedStringArray([
		"--dev-battle=prologue_2",
		"--dev-player=simayi",
		"--dev-enemies=zhangliao,lvbu",
		"--dev-skip-selection",
	]))
	var configuration: Dictionary = DeveloperLauncher.pending_configuration()
	_expect(accepted and configuration.get("battle_index") == 2, "命令行解析目标关卡")
	_expect(configuration.get("battle_id") == &"prologue_2", "旧数字参数解析为稳定战斗 ID")
	_expect(configuration.get("player_general_id") == &"simayi", "命令行解析玩家武将")
	_expect(configuration.get("enemy_general_ids", []).size() == 2, "命令行解析完整敌方阵容")
	_expect(configuration.get("skip_general_selection") == true, "命令行解析跳过选将")
	DeveloperLauncher.cancel_pending_launch()


func _test_dynamic_catalog_battle() -> void:
	var registered := BattleCatalog.register_battle({
		"id": &"developer_swarm_test",
		"display_name": "开发验证：四敌人战",
		"chapter_id": &"test",
		"enemy_count": 4,
		"enemy_slots": [
			{"label": "前锋", "default_general_id": &"xuchu"},
			{"label": "左翼", "default_general_id": &"zhaoyun"},
			{"label": "右翼", "default_general_id": &"lvbu"},
			{"label": "后援", "default_general_id": &"diaochan"},
		],
		"combat_modifiers": [],
		"kill_reward": &"",
		"developer_enabled": true,
	})
	_expect(registered, "战斗目录允许运行时注册未来战斗")
	var enemy_ids: Array[StringName] = [&"xuchu", &"zhaoyun", &"lvbu", &"diaochan"]
	_expect(
		DeveloperLauncher.request_launch(&"developer_swarm_test", &"caocao", enemy_ids, true),
		"开发入口接受字符串战斗 ID 与四名敌人"
	)
	_expect(BattleSession.active_battle_id == &"developer_swarm_test", "通用战斗会话激活非序章战斗")

	var panel: Control = load("res://scenes/DeveloperPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame
	var options: Array = panel.get("enemy_options")
	_expect(options.size() == 4, "开发面板按战斗定义动态生成四个选将槽位")
	panel.queue_free()
	await get_tree().process_frame

	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var game: GameManager = main.get_node("GameManager")
	_expect(game.players.size() == 5 and game.enemies.size() == 4, "通用战斗定义创建 1v4 阵容")
	var actual_ids: Array[StringName] = []
	for enemy: BattlePlayer in game.enemies:
		actual_ids.append(enemy.general_id)
	_expect(actual_ids == enemy_ids, "任意数量敌方武将均按目录槽位顺序生效")
	main.queue_free()
	await get_tree().process_frame
	DeveloperLauncher.end_session()
	BattleSession.clear_active_battle()
	BattleCatalog.unregister_battle(&"developer_swarm_test")


func _test_map_entry_visibility() -> void:
	var map: Control = load("res://scenes/MapScene.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	var developer_button: Button = map.get_node("%DeveloperButton")
	_expect(developer_button.visible == DeveloperLauncher.is_available(), "开发入口只按调试构建能力显示")
	map.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
