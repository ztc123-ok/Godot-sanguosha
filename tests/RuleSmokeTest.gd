extends Node
## 无界面规则冒烟测试。命令：
## Godot --headless --path . --scene res://tests/RuleSmokeTest.tscn

@onready var game: GameManager = $GameManager
@onready var p1: BattlePlayer = $GameManager/Players/Player1
@onready var p2: BattlePlayer = $GameManager/Players/Player2

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	game._action_generation += 1
	_expect(p1.hp == 4 and p2.hp == 4, "双方初始体力为 4")
	_expect(p1.hand.size() == 6 and p2.hand.size() == 4, "起手 4 张且主公首回合摸 2")
	_expect(game.phase == GameManager.Phase.PLAY, "自动阶段后进入出牌阶段")

	_test_dodge_cancels_slash()
	_test_wine_slash_damage()
	_test_repeated_dying_rescue()
	_test_hand_limit_discard()

	if failures.is_empty():
		print("RULE_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("RULE_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)


func _test_dodge_cancels_slash() -> void:
	_prepare_play()
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [DodgeCard.new()])
	game.request_card_on_target(0, 1)
	_expect(game.flow_state == GameManager.FlowState.RESPONDING_SLASH, "杀后进入闪响应")
	game._perform_ai_slash_response()
	_expect(p2.hp == 4, "闪令杀无效")
	_expect(p1.slash_used_this_turn, "杀次数标记已消耗")
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "闪结算后返回出牌阶段")


func _test_wine_slash_damage() -> void:
	_prepare_play()
	p1.wine_active = true
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [])
	game.request_card_on_target(0, 1)
	game._perform_ai_slash_response()
	_expect(p2.hp == 2, "酒杀造成 2 点伤害")
	_expect(not p1.wine_active, "下一张杀消耗酒效果")


func _test_repeated_dying_rescue() -> void:
	_prepare_play()
	p1.wine_active = true
	p2.hp = 1
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [PeachCard.new(), WineCard.new()])
	game.request_card_on_target(0, 1)
	game._perform_ai_slash_response()
	_expect(p2.hp == -1 and game.flow_state == GameManager.FlowState.DYING_RESCUE, "负体力进入濒死")
	game._perform_ai_rescue()
	_expect(p2.hp == 0 and game.flow_state == GameManager.FlowState.DYING_RESCUE, "体力 0 仍需继续自救")
	game._perform_ai_rescue()
	_expect(p2.hp == 1 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "回复至 1 后脱离濒死")


func _test_hand_limit_discard() -> void:
	_prepare_play()
	p1.hp = 2
	_set_hand(p1, [
		SlashCard.new(),
		DodgeCard.new(),
		PeachCard.new(),
		WineCard.new(),
	])
	game.request_end_play_phase()
	_expect(game.flow_state == GameManager.FlowState.DISCARDING, "结束出牌后进入弃牌阶段")
	game.request_discard(0)
	game.request_discard(0)
	_expect(p1.hand.size() == 2, "手牌弃至当前体力")
	_expect(game.phase == GameManager.Phase.END, "弃牌完成后进入结束阶段")


func _prepare_play() -> void:
	game._action_generation += 1
	game.current_player_index = 0
	game.phase = GameManager.Phase.PLAY
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.selected_hand_index = -1
	game.pending_attacker = null
	game.pending_target = null
	game.dying_player = null
	game.winner = null
	p1.hp = 4
	p2.hp = 4
	p1.reset_turn_flags()
	p2.reset_turn_flags()


func _set_hand(player: BattlePlayer, cards: Array) -> void:
	player.hand.clear()
	for card: Card in cards:
		player.hand.append(card)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

