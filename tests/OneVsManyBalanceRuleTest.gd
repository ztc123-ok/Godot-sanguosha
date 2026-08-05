extends Node
## 仅覆盖本批次的【孤军】与击杀奖励，重点验证伤害链提交顺序与 continuation。

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _test_lone_army_draw_modifier()
	await _test_kill_reward_exclusive_choices()
	await _test_last_enemy_has_no_reward()
	await _test_multiple_kills_queue_rewards_and_resume_once()
	await _test_simultaneous_dying_chain_defers_reward()
	await _test_buff_ui_visualization()

	if failures.is_empty():
		print("ONE_VS_MANY_BALANCE_RULE_TEST: PASS (lone army / kill reward / death-chain continuation)")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("ONE_VS_MANY_BALANCE_RULE_TEST: %s" % failure)
		get_tree().quit(1)


func _make_game(active_battle: int) -> GameManager:
	PrologueState.active_battle = active_battle
	var game := GameManager.new()
	var players_node := Node.new()
	players_node.name = "Players"
	var p1 := BattlePlayer.new()
	p1.name = "Player1"
	p1.player_name = "Player1"
	p1.role_name = "主公"
	var p2 := BattlePlayer.new()
	p2.name = "Player2"
	p2.player_name = "AI 反贼 1"
	p2.role_name = "反贼"
	p2.is_ai = true
	players_node.add_child(p1)
	players_node.add_child(p2)
	game.add_child(players_node)
	add_child(game)
	return game


func _start(game: GameManager) -> void:
	game.setup_generals(&"caocao", &"lvbu")
	for index: int in range(1, game.enemies.size()):
		game.enemies[index].assign_general(GeneralFactory.create_general(&"guanyu"))
	game.start_match(false)
	game.phase = GameManager.Phase.PLAY
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE


func _clear_all_hands(game: GameManager) -> void:
	for player: BattlePlayer in game.players:
		player.hand.clear()
		player.hand_changed.emit()


func _test_lone_army_draw_modifier() -> void:
	var duel := _make_game(1)
	await get_tree().process_frame
	_start(duel)
	_expect(duel.draw_count_for(duel.player1) == 2, "第一战摸牌数保持 2 且没有【孤军】")
	_expect(duel.combat_modifier_statuses_for(duel.player1).is_empty(), "第一战不展示【孤军】")
	duel.queue_free()
	await get_tree().process_frame

	var game := _make_game(2)
	await get_tree().process_frame
	_start(game)
	_expect(game.draw_count_for(game.player1) == 3, "两名敌人存活时【孤军】令玩家摸 3")
	_expect(
		not game.combat_modifier_statuses_for(game.player1).is_empty()
		and game.combat_modifier_statuses_for(game.player1)[0].contains("摸牌+1"),
		"【孤军】通过统一战斗修正状态对 UI 可见"
	)
	_clear_all_hands(game)
	game.phase = GameManager.Phase.JUDGEMENT
	game._skip_draw_phase = false
	game._finish_judgement_phase()
	_expect(game.player1.hand.size() == 3, "实际摸牌阶段使用【孤军】修正后的 3 张")
	game.player1.assign_general(GeneralFactory.create_general(&"zhouyu"))
	_clear_all_hands(game)
	game.phase = GameManager.Phase.JUDGEMENT
	game.flow_state = GameManager.FlowState.IDLE
	game._finish_judgement_phase()
	_expect(
		game.flow_state == GameManager.FlowState.SKILL_CONFIRM
		and game._draw_context.original_count == 3,
		"【孤军】先进入 DrawContext，再与武将摸牌技能组合"
	)
	game.request_confirm_skill()
	_expect(game.player1.hand.size() == 4, "【英姿】在【孤军】3张基础上继续增加至4张")
	game.enemies[0].hp = 0
	_expect(game.draw_count_for(game.player1) == 2, "一名敌人阵亡后【孤军】动态恢复标准摸 2")
	var before_skip: int = game.player1.hand.size()
	game.phase = GameManager.Phase.JUDGEMENT
	game._skip_draw_phase = true
	game._finish_judgement_phase()
	_expect(game.player1.hand.size() == before_skip, "跳过摸牌阶段不会获得【孤军】额外牌")
	game.queue_free()
	await get_tree().process_frame


func _test_kill_reward_exclusive_choices() -> void:
	var heal_game := _make_game(2)
	await get_tree().process_frame
	_start(heal_game)
	_clear_all_hands(heal_game)
	heal_game.player1.hp = heal_game.player1.max_hp - 1
	heal_game.enemies[0].hp = 1
	heal_game._start_damage(
		heal_game.player1,
		heal_game.enemies[0],
		1,
		GameManager.DamageNature.NORMAL,
		Callable(heal_game, "_return_to_play")
	)
	_expect(heal_game.flow_state == GameManager.FlowState.KILL_REWARD, "非末敌阵亡后进入独立奖励流程")
	heal_game.request_option(0)
	_expect(heal_game.player1.hp == heal_game.player1.max_hp, "选择回复只回复 1 点体力")
	_expect(heal_game.player1.hand.is_empty(), "选择回复时不会同时摸牌")
	heal_game.queue_free()
	await get_tree().process_frame

	var draw_game := _make_game(2)
	await get_tree().process_frame
	_start(draw_game)
	_clear_all_hands(draw_game)
	draw_game.enemies[0].hp = 1
	draw_game._start_damage(
		draw_game.player1,
		draw_game.enemies[0],
		1,
		GameManager.DamageNature.NORMAL,
		Callable(draw_game, "_return_to_play")
	)
	_expect(
		draw_game.choice_labels.size() == 2 and draw_game.choice_labels[0].contains("实际回复 0"),
		"满体力时回复选项仍可选并明确提示实际收益为 0"
	)
	draw_game.request_option(1)
	_expect(draw_game.player1.hand.size() == 2, "选择摸牌只获得 2 张牌")
	_expect(draw_game.player1.hp == draw_game.player1.max_hp, "选择摸牌不会额外回复体力")
	draw_game.queue_free()
	await get_tree().process_frame


func _test_last_enemy_has_no_reward() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start(game)
	_clear_all_hands(game)
	game.enemies[0].hp = 0
	game.enemies[1].hp = 1
	game._start_damage(
		game.player1,
		game.enemies[1],
		1,
		GameManager.DamageNature.NORMAL,
		Callable(game, "_return_to_play")
	)
	_expect(game.flow_state == GameManager.FlowState.GAME_OVER, "最后一名敌人阵亡后直接胜利")
	_expect(game.choice_labels.is_empty(), "最后一名敌人阵亡不弹出战利品选项")
	game.queue_free()
	await get_tree().process_frame


func _test_multiple_kills_queue_rewards_and_resume_once() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start(game)
	var third := BattlePlayer.new()
	third.name = "Player4"
	third.player_name = "AI 反贼 3"
	third.role_name = "反贼"
	third.is_ai = true
	third.assign_general(GeneralFactory.create_general(&"xuchu"))
	game.get_node("Players").add_child(third)
	game.enemies.append(third)
	game.players.append(third)
	third.reset_for_match()
	_clear_all_hands(game)
	game.player1.hp = game.player1.max_hp - 1
	game.enemies[0].hp = 1
	game.enemies[1].hp = 1
	game.enemies[0].chained = true
	game.enemies[1].chained = true
	var continuation_calls: Array[int] = [0]
	var finish := func() -> void:
		continuation_calls[0] += 1
		game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game._start_damage(
		game.player1,
		game.enemies[0],
		1,
		GameManager.DamageNature.FIRE,
		finish
	)
	_expect(
		game.enemies[0].is_dying() and game.enemies[1].is_dying()
		and game.flow_state == GameManager.FlowState.KILL_REWARD,
		"连环伤害先完整结算两名敌人的死亡，再进入奖励队列"
	)
	game.request_option(1)
	_expect(
		game.flow_state == GameManager.FlowState.KILL_REWARD and game.player1.hand.size() == 2,
		"首个奖励完成后继续处理下一奖励，不提前恢复 continuation"
	)
	game.request_option(0)
	_expect(game.player1.hp == game.player1.max_hp, "第二个击杀奖励可独立选择回复")
	_expect(continuation_calls[0] == 1, "多次连续击杀只恢复一次原 continuation")
	_expect(game._pending_kill_rewards.is_empty(), "连续击杀奖励全部消费且不重复")
	game.queue_free()
	await get_tree().process_frame


func _test_simultaneous_dying_chain_defers_reward() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start(game)
	_clear_all_hands(game)
	game.player1.hp = 1
	game.enemies[0].hp = 1
	game.player1.chained = true
	game.enemies[0].chained = true
	game._start_damage(
		game.player1,
		game.enemies[0],
		1,
		GameManager.DamageNature.FIRE,
		Callable(game, "_return_to_play")
	)
	_expect(game.player1.is_dying() and game.enemies[0].is_dying(), "玩家与敌人在同一连环伤害链中均完整进入濒死并阵亡")
	_expect(game.flow_state == GameManager.FlowState.GAME_OVER, "同链中玩家阵亡后按统一胜负入口判负")
	_expect(game._pending_kill_rewards.is_empty(), "玩家死亡时清除延迟奖励且从未提前弹出")
	game.queue_free()
	await get_tree().process_frame


func _test_buff_ui_visualization() -> void:
	PrologueState.active_battle = 2
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var game: GameManager = main.get_node("GameManager")
	var ui: UIManager = main.get_node("UIManager")
	game.request_use_default_generals()
	game.request_start_match()
	ui.refresh()
	_expect(ui.buff_panel.visible, "第二战玩家区域常驻显示独立 Buff 面板")
	_expect(ui.buff_list.get_child_count() == 1, "【孤军】生成独立可视化徽章")
	if ui.buff_list.get_child_count() == 1:
		var badge: PanelContainer = ui.buff_list.get_child(0) as PanelContainer
		var label: Label = badge.get_child(0) as Label
		_expect(
			label != null and label.text.contains("【孤军】") and label.text.contains("= 3 张"),
			"Buff 徽章直接展示名称、规则公式与当前收益"
		)
		_expect(
			badge.tooltip_text.contains("关卡 Buff")
			and badge.tooltip_text.contains("每多一名敌人"),
			"Buff tooltip 展示来源和完整描述"
		)
	main.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
