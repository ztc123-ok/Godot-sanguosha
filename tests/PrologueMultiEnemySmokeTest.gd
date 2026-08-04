extends Node
## 序章 1v2 多敌人战斗冒烟测试。
## 覆盖：
##  1) 第一战只创建一个 AI；
##  2) 第二战创建两个 AI；
##  3) 初始回合顺序为玩家、AI1、AI2；
##  4) 已死亡 AI 会被跳过；
##  5) 玩家可以分别选择两个 AI 作为【杀】的目标；
##  6) 击败第一个 AI 时战斗不会结束；
##  7) 击败第二个 AI 后才判定胜利；
##  8) 玩家死亡时第二战自动重开（仍是 1v2）；
##  9) 失败不会增加序章完成进度；
## 10) 第二战胜利后解锁村落；
## 11) 第一战原有 1v1 流程不回归。

var failures: Array[String] = []
var _battle_won_flag: bool = false


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	_test_battle1_single_enemy()
	await _test_battle2_two_enemies()
	await _test_turn_order_and_dead_skip()
	await _test_player_can_target_both_enemies()
	await _test_first_enemy_death_continues()
	await _test_all_enemies_dead_wins()
	await _test_player_death_restarts_battle()
	await _test_victory_unlocks_village()
	await _test_battle1_flow_unchanged()
	await _test_targeted_tricks_both_enemies()
	await _test_aoe_both_enemies_and_death_flow()
	await _test_multiplayer_rescue_order()
	await _test_serpent_spear_target_choice()
	await _test_ai_serpent_spear_target_driver()
	await _test_fanjian_target_choice()
	await _test_lijian_two_males()
	await _test_skill_activation_any_target()
	await _test_ai_skills_target_human()
	await _test_borrow_sword_designated_target()
	await _test_ai_liuli_transfer()
	await _test_ai_lijian_in_1v2()
	await _test_ai_jieyin_targets_ally()
	await _test_ai_qingnang_heals_ally()
	await _test_ai_guicai_respects_team()
	await _test_ai_steal_equipment_target()
	await _test_ai_rende_is_bounded()
	await _test_liubei_xuchu_simayi_no_watchdog_loop()
	await _test_simayi_double_zhangliao_no_watchdog_loop()
	await _test_card_count_invariant_transient_zones()
	await _test_ai_yiji_team_allocation()
	await _test_ai_guanxing_judgement_optimization()

	if failures.is_empty():
		print("PROLOGUE_MULTI_ENEMY_SMOKE_TEST: PASS (1v2 roster / turn order / target / victory / skills / cards / AI)")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("PROLOGUE_MULTI_ENEMY_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)


## 动态构造 GameManager：active_battle 必须在节点进入场景树前设置，
## 这样 _ready 才会按关卡生成对应数量的敌人。
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
	p2.player_name = "Player2"
	p2.role_name = "反贼"
	p2.is_ai = true
	players_node.add_child(p1)
	players_node.add_child(p2)
	game.add_child(players_node)
	add_child(game)
	return game


func _start_battle2(game: GameManager) -> void:
	game.setup_generals(&"caocao", &"lvbu")
	game.players[2].assign_general(GeneralFactory.create_general(&"guanyu"))
	game.start_match()


func _start_battle2_with_generals(game: GameManager, p2_id: StringName, p3_id: StringName) -> void:
	game.setup_generals(&"caocao", p2_id)
	game.players[2].assign_general(GeneralFactory.create_general(p3_id))
	game.start_match()


func _set_hand(player: BattlePlayer, cards: Array) -> void:
	player.hand.clear()
	for card: Card in cards:
		player.hand.append(card)
	player.hand_changed.emit()


func _pass_nullification_chain(game: GameManager) -> void:
	var guard: int = 0
	while game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE and guard < 8:
		var responder: BattlePlayer = game.players[game._nullification_responder_index]
		game._pass_nullification(responder)
		guard += 1


func _test_battle1_single_enemy() -> void:
	var game := _make_game(1)
	await get_tree().process_frame
	_expect(game.enemies.size() == 1, "第一战只创建一个 AI")
	_expect(game.players.size() == 2, "第一战共两名角色")
	_expect(game.enemies[0] == game.player2, "第一战 AI 复用 Player2")
	_expect(game.enemies[0].is_ai, "第一战 AI 标记为 AI")
	game.queue_free()
	await get_tree().process_frame


func _test_battle2_two_enemies() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_expect(game.enemies.size() == 2, "第二战创建两个 AI")
	_expect(game.players.size() == 3, "第二战共三名角色")
	_expect(game.players[0] == game.player1, "玩家位于角色列表首位")
	_expect(game.players[1] == game.enemies[0], "AI1 位于玩家之后")
	_expect(game.players[2] == game.enemies[1], "AI2 位于 AI1 之后")
	_expect(game.enemies[0].is_ai and game.enemies[1].is_ai, "两个 AI 均标记为 AI")
	_expect(
		game.enemies[0].general_id == &"" and game.enemies[1].general_id == &"",
		"选将阶段敌人尚未配将"
	)
	game.queue_free()
	await get_tree().process_frame


func _test_turn_order_and_dead_skip() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	_expect(game.current_player() == game.player1, "初始回合为玩家")
	_expect(game.turn_number == 1, "首回合已开始")
	_expect(game.next_living_player_index(0) == 1, "玩家后轮到 AI1")
	_expect(game.next_living_player_index(1) == 2, "AI1 后轮到 AI2")
	_expect(game.next_living_player_index(2) == 0, "AI2 后轮回到玩家")
	## 已死亡 AI 跳过：AI1 阵亡后，玩家直接轮到 AI2。
	game.enemies[0].take_damage(999)
	_expect(game.enemies[0].is_dying(), "AI1 已阵亡")
	_expect(game.next_living_player_index(0) == 2, "AI1 死亡后玩家直接轮到 AI2")
	_expect(game.next_living_player_index(2) == 0, "AI2 后仍轮回到玩家")
	_expect(game.choose_ai_target(game.enemies[1]) == game.player1, "AI 目标始终为玩家")
	game.queue_free()
	await get_tree().process_frame


func _test_player_can_target_both_enemies() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	## 【杀】指定 AI1：AI1 无闪扣血，AI2 不受影响。
	_set_hand(game.player1, [SlashCard.new()])
	_set_hand(game.enemies[0], [])
	_set_hand(game.enemies[1], [DodgeCard.new()])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(game.enemies[0].hp == game.enemies[0].max_hp - 1, "杀可指定 AI1 并只伤害 AI1")
	_expect(game.enemies[1].hp == game.enemies[1].max_hp, "杀 AI1 不伤害 AI2")
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "结算后回到出牌阶段")
	## 【杀】指定 AI2：AI2 无闪扣血。
	_set_hand(game.player1, [SlashCard.new()])
	_set_hand(game.enemies[0], [DodgeCard.new()])
	_set_hand(game.enemies[1], [])
	game.player1.slash_used_this_turn = false
	game.request_card_on_target(0, 2)
	game._perform_ai_response()
	_expect(game.enemies[1].hp == game.enemies[1].max_hp - 1, "杀可指定 AI2 并只伤害 AI2")
	_expect(game.enemies[0].hp == game.enemies[0].max_hp - 1, "杀 AI2 不伤害 AI1")
	game.queue_free()
	await get_tree().process_frame


func _test_first_enemy_death_continues() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	_battle_won_flag = false
	game.battle_finished.connect(func(player_won: bool) -> void:
		_battle_won_flag = player_won
	)
	## 击杀 AI1：战斗必须继续，且已阵亡角色不能再被选中。
	_set_hand(game.player1, [SlashCard.new()])
	_set_hand(game.enemies[0], [])
	_set_hand(game.enemies[1], [])
	game.enemies[0].hp = 1
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(game.enemies[0].is_dying(), "击败第一个 AI")
	_expect(game.flow_state != GameManager.FlowState.GAME_OVER, "击败第一个 AI 后战斗不结束")
	_expect(game.living_enemies().size() == 1, "击败第一个 AI 后仅剩一名存活敌人")
	_expect(not _battle_won_flag, "击败第一个 AI 时不发出胜利信号")
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "击败第一个 AI 后回到出牌阶段")
	## 已死亡敌人不能再被选中（规则层拒绝）。
	_set_hand(game.player1, [SlashCard.new()])
	game.request_card_on_target(0, 1)
	_expect(game.enemies[0].hp == 0 or game.enemies[0].hp < 0, "阵亡 AI 不会被再次结算")
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "选中阵亡目标被拒绝后仍可继续出牌")
	game.queue_free()
	await get_tree().process_frame


func _test_all_enemies_dead_wins() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	_battle_won_flag = false
	game.battle_finished.connect(func(player_won: bool) -> void:
		_battle_won_flag = player_won
	)
	## 先击杀 AI1，战斗继续。
	_set_hand(game.player1, [SlashCard.new()])
	_set_hand(game.enemies[0], [])
	_set_hand(game.enemies[1], [])
	game.enemies[0].hp = 1
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(game.flow_state != GameManager.FlowState.GAME_OVER, "第一个 AI 阵亡后战斗未结束")
	## 再击杀 AI2，才判定胜利。
	_set_hand(game.player1, [SlashCard.new()])
	game.enemies[1].hp = 1
	game.player1.slash_used_this_turn = false
	game.request_card_on_target(0, 2)
	game._perform_ai_response()
	_expect(game.enemies[1].is_dying(), "第二个 AI 被击败")
	_expect(game.flow_state == GameManager.FlowState.GAME_OVER, "全部反贼阵亡后判定胜利")
	_expect(game.winner == game.player1, "胜利者为玩家")
	_expect(_battle_won_flag, "胜利时发出 battle_finished(true)")
	game.queue_free()
	await get_tree().process_frame


func _test_player_death_restarts_battle() -> void:
	PrologueState.active_battle = 2
	PrologueState.completed_battles = 0
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var game: GameManager = main.get_node("GameManager")
	_expect(game.enemies.size() == 2, "Main 场景按第二战生成两个 AI")
	_start_battle2(game)
	var completed_before: int = PrologueState.completed_battles
	## 玩家阵亡 → 失败 → Main 自动重开本场（仍是 1v2）。
	game.player1.hp = 0
	game._declare_death(game.player1)
	_expect(game.flow_state == GameManager.FlowState.GAME_OVER, "玩家阵亡后进入结束状态")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(game.flow_state != GameManager.FlowState.GAME_OVER, "玩家阵亡后自动重开对局")
	_expect(game.current_player() == game.player1 and game.player1.hp == game.player1.max_hp, "重开后玩家满体力先手")
	_expect(game.enemies.size() == 2, "重开后第二战仍是 1v2")
	_expect(PrologueState.completed_battles == completed_before, "失败不会增加序章完成进度")
	_expect(not PrologueState.can_enter_village(), "失败后村落不解锁")
	main.queue_free()
	await get_tree().process_frame


func _test_victory_unlocks_village() -> void:
	PrologueState.active_battle = 2
	PrologueState.completed_battles = 0
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	_battle_won_flag = false
	game.battle_finished.connect(func(player_won: bool) -> void:
		_battle_won_flag = player_won
	)
	_set_hand(game.player1, [SlashCard.new(), SlashCard.new()])
	_set_hand(game.enemies[0], [])
	_set_hand(game.enemies[1], [])
	game.enemies[0].hp = 1
	game.enemies[1].hp = 1
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(game.flow_state != GameManager.FlowState.GAME_OVER, "首个敌人阵亡后战斗继续")
	game.player1.slash_used_this_turn = false
	game.request_card_on_target(0, 2)
	game._perform_ai_response()
	_expect(game.flow_state == GameManager.FlowState.GAME_OVER and _battle_won_flag, "全部敌人阵亡后胜利")
	## Main 的胜利处理：更新进度并解锁村落。
	PrologueState.complete_active_battle()
	_expect(PrologueState.completed_battles == 2, "第二战胜利后序章进度更新")
	_expect(PrologueState.can_enter_village(), "第二战胜利后解锁村落")
	game.queue_free()
	await get_tree().process_frame


func _test_battle1_flow_unchanged() -> void:
	PrologueState.active_battle = 1
	var game := _make_game(1)
	await get_tree().process_frame
	game.setup_generals(&"caocao", &"lvbu")
	game.start_match()
	_expect(game.players.size() == 2 and game.enemies.size() == 1, "第一战保持 1v1")
	_expect(game.current_player() == game.player1, "第一战玩家先手")
	_expect(game.next_living_player_index(0) == 1 and game.next_living_player_index(1) == 0, "第一战双人轮转正常")
	_set_hand(game.player1, [SlashCard.new()])
	_set_hand(game.enemies[0], [DodgeCard.new()])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(game.enemies[0].hp == game.enemies[0].max_hp, "第一战杀/闪结算正常")
	game.queue_free()
	await get_tree().process_frame


## 单体锦囊可分别指定两个 AI 作为目标。
func _test_targeted_tricks_both_enemies() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	## 过河拆桥 → AI1（弃置其唯一手牌）。
	_set_hand(game.player1, [DismantleCard.new()])
	_set_hand(game.enemies[0], [PeachCard.new()])
	_set_hand(game.enemies[1], [])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain(game)
	_expect(game.enemies[0].hand.is_empty(), "过河拆桥可指定 AI1")
	## 顺手牵羊 → AI2（获得其手牌）。
	var wine := WineCard.new()
	_set_hand(game.player1, [StealCard.new()])
	_set_hand(game.enemies[1], [wine])
	game.request_card_on_target(0, 2)
	_pass_nullification_chain(game)
	_expect(game.player1.hand.has(wine), "顺手牵羊可指定 AI2 并获得其手牌")
	game.queue_free()
	await get_tree().process_frame


## 群体牌按“全部其他角色”结算，且第一个目标死亡不阻断后续目标。
func _test_aoe_both_enemies_and_death_flow() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	_set_hand(game.player1, [BarbarianInvasionCard.new()])
	_set_hand(game.enemies[0], [])
	_set_hand(game.enemies[1], [])
	game.enemies[0].hp = 1
	game.request_card_use(0)
	_pass_nullification_chain(game)
	game._perform_ai_response()
	_expect(game.enemies[0].is_dying(), "南蛮先结算 AI1 并使其阵亡")
	_expect(game.flow_state != GameManager.FlowState.GAME_OVER, "南蛮中 AI1 阵亡后战斗不结束")
	_pass_nullification_chain(game)
	game._perform_ai_response()
	_expect(game.enemies[1].hp == game.enemies[1].max_hp - 1, "南蛮继续结算 AI2")
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "群体牌结算完成后回到出牌阶段")
	game.queue_free()
	await get_tree().process_frame


## 1v2 濒死救援须按座次询问完整一圈，不能在第一名角色放弃后直接宣告死亡。
func _test_multiplayer_rescue_order() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	var rescuer: BattlePlayer = game.enemies[1]
	game.player1.is_ai = false
	game.enemies[0].is_ai = true
	rescuer.is_ai = false
	game.player1.hp = 0
	_set_hand(game.player1, [])
	_set_hand(game.enemies[0], [])
	_set_hand(rescuer, [PeachCard.new()])
	game._enter_dying(game.player1, Callable())
	_expect(
		game.flow_state == GameManager.FlowState.DYING_RESCUE and game.rescue_actor == rescuer,
		"濒死者与 AI1 放弃后继续询问 AI2"
	)
	game._use_rescue_card(rescuer, 0)
	_expect(game.player1.hp == 1 and game.dying_player == null, "AI2 可在完整救援轮次中使用桃救回濒死者")
	game.queue_free()
	await get_tree().process_frame


## 丈八蛇矛视为【杀】时，玩家可任选两个 AI 之一作为目标。
func _test_serpent_spear_target_choice() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	game.player1.weapon = SerpentSpear.new()
	_set_hand(game.player1, [PeachCard.new(), WineCard.new()])
	_set_hand(game.enemies[0], [DodgeCard.new()])
	_set_hand(game.enemies[1], [DodgeCard.new()])
	game.request_serpent_spear()
	_expect(game.flow_state == GameManager.FlowState.SELECTING_TARGET, "丈八蛇矛多人局等待选择目标")
	game.request_target(1)
	game._perform_ai_response()
	_expect(game.enemies[0].hp == game.enemies[0].max_hp, "丈八蛇矛可选 AI1 为目标")
	## 第二次发动，选择 AI2。
	game.player1.slash_used_this_turn = false
	_set_hand(game.player1, [PeachCard.new(), WineCard.new()])
	_set_hand(game.enemies[0], [DodgeCard.new()])
	_set_hand(game.enemies[1], [DodgeCard.new()])
	game.request_serpent_spear()
	game.request_target(2)
	game._perform_ai_response()
	_expect(game.enemies[1].hp == game.enemies[1].max_hp, "丈八蛇矛可选 AI2 为目标")
	game.queue_free()
	await get_tree().process_frame


## 全 AI 的主公使用丈八蛇矛时必须自动选敌方目标，不得停在 SELECTING_TARGET。
func _test_ai_serpent_spear_target_driver() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	game.player1.is_ai = true
	game.current_player_index = 0
	game.phase = GameManager.Phase.PLAY
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.player1.weapon = SerpentSpear.new()
	_set_hand(game.player1, [NullificationCard.new(), NullificationCard.new()])
	_set_hand(game.enemies[0], [])
	_set_hand(game.enemies[1], [])
	game._perform_ai_play()
	_expect(
		game.flow_state in [GameManager.FlowState.RESPONDING_SLASH, GameManager.FlowState.MULTI_RESPONSE],
		"AI 主公发动丈八蛇矛后自动进入目标的闪响应"
	)
	game._perform_ai_response()
	_expect(
		game.enemies[0].hp == game.enemies[0].max_hp - 1
		and game.flow_state == GameManager.FlowState.PLAY_ACTIVE,
		"AI 丈八蛇矛结算后不卡在选目标状态"
	)
	game.queue_free()
	await get_tree().process_frame


## 反间（玩家周瑜）可任选一个 AI 作为目标。
func _test_fanjian_target_choice() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	game.setup_generals(&"zhouyu", &"lvbu")
	game.players[2].assign_general(GeneralFactory.create_general(&"guanyu"))
	game.start_match()
	## 周瑜的英姿在摸牌阶段先触发，先确认再进入出牌阶段。
	if game.flow_state == GameManager.FlowState.SKILL_CONFIRM:
		game.request_confirm_skill()
	var heart := PeachCard.new()
	heart.suit = Card.Suit.HEART
	_set_hand(game.player1, [heart])
	_set_hand(game.enemies[0], [])
	_set_hand(game.enemies[1], [])
	game.request_begin_skill(&"fanjian")
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_TARGET, "反间先选择目标")
	game.request_skill_target(2)
	_expect(game.flow_state == GameManager.FlowState.CHOOSING_SUIT, "反间选完 AI2 后进入选花色")
	## 目标为 AI，花色由 AI 选择；直接指定黑桃以保证确定性（红桃牌 → 花色不同）。
	game._resolve_fanjian_suit(0)
	_expect(heart in game.enemies[1].hand, "反间目标 AI2 获得随机牌")
	_expect(game.enemies[1].hp == game.enemies[1].max_hp - 1, "反间花色不同对 AI2 造成伤害")
	game.queue_free()
	await get_tree().process_frame


## 离间（玩家貂蝉）在两名男性 AI 时可选两人并结算决斗。
func _test_lijian_two_males() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	game.setup_generals(&"diaochan", &"lvbu")
	game.players[2].assign_general(GeneralFactory.create_general(&"guanyu"))
	game.start_match()
	_set_hand(game.player1, [DodgeCard.new()])
	_set_hand(game.enemies[0], [SlashCard.new()])
	_set_hand(game.enemies[1], [SlashCard.new()])
	game.request_begin_skill(&"lijian")
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_CARDS, "离间选择代价牌")
	game.request_skill_toggle_hand_card(0)
	game.request_confirm_skill_cards()
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_TARGET, "离间第一步选择决斗使用者")
	game.request_skill_target(1)
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_TARGET, "离间第二步选择决斗对象")
	game.request_skill_target(2)
	_pass_nullification_chain(game)
	## 决斗：AI2 先出杀 → AI1 出杀 → AI2 无杀受伤害。
	game._perform_ai_response()
	game._perform_ai_response()
	game._perform_ai_response()
	_expect(game.enemies[1].hp == game.enemies[1].max_hp - 1, "离间令 AI1 对 AI2 造成决斗伤害")
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "离间结算完成回到出牌阶段")
	game.queue_free()
	await get_tree().process_frame


## 结姻/青囊的发动条件在多人局中检查全部存活角色，而非只看默认对手。
func _test_skill_activation_any_target() -> void:
	## 结姻：AI1 女性不合法，但 AI2 男性受伤仍可发动。
	var game := _make_game(2)
	await get_tree().process_frame
	game.setup_generals(&"sunshangxiang", &"diaochan")
	game.players[2].assign_general(GeneralFactory.create_general(&"xiahoudun"))
	game.start_match()
	game.enemies[1].hp = game.enemies[1].max_hp - 1
	_set_hand(game.player1, [PeachCard.new(), WineCard.new()])
	_expect(
		game.can_use_skill(game.player1, game.player1.get_skill(&"jieyin")),
		"结姻：AI1 女性不可但 AI2 男性受伤仍可发动"
	)
	game.queue_free()
	await get_tree().process_frame
	## 青囊：自己满体力、AI2 受伤时仍可发动。
	var game2 := _make_game(2)
	await get_tree().process_frame
	game2.setup_generals(&"huatuo", &"diaochan")
	game2.players[2].assign_general(GeneralFactory.create_general(&"xiahoudun"))
	game2.start_match()
	game2.enemies[1].hp = game2.enemies[1].max_hp - 1
	_set_hand(game2.player1, [DodgeCard.new()])
	_expect(
		game2.can_use_skill(game2.player1, game2.player1.get_skill(&"qingnang")),
		"青囊：任一名存活角色受伤即可发动"
	)
	game2.queue_free()
	await get_tree().process_frame


## AI 技能多人化：突袭偷玩家手牌、反间以玩家为目标。
func _test_ai_skills_target_human() -> void:
	## AI 张辽：摸牌阶段对玩家发动突袭。
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game, &"zhangliao", &"lvbu")
	game.current_player_index = 1
	_set_hand(game.player1, [PeachCard.new()])
	_set_hand(game.enemies[0], [])
	_set_hand(game.enemies[1], [])
	game._begin_turn()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "AI 张辽摸牌阶段询问突袭")
	game._perform_ai_skill_confirm()
	_expect(game.player1.hand.is_empty(), "AI 张辽突袭获得玩家手牌")
	_expect(game.enemies[0].hand.size() == 1, "AI 张辽获得一张手牌")
	game.queue_free()
	await get_tree().process_frame
	## AI 周瑜：反间目标始终为玩家。
	var game2 := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game2, &"zhouyu", &"lvbu")
	game2.current_player_index = 1
	_set_hand(game2.player1, [])
	_set_hand(game2.enemies[0], [SlashCard.new()])
	_set_hand(game2.enemies[1], [])
	game2._begin_turn()
	## 周瑜的英姿在摸牌阶段先触发，AI 自动确认后再进入出牌阶段。
	_expect(game2.flow_state == GameManager.FlowState.SKILL_CONFIRM, "AI 周瑜先触发英姿")
	game2._perform_ai_skill_confirm()
	game2._perform_ai_play()
	_expect(game2.flow_state == GameManager.FlowState.CHOOSING_SUIT, "AI 周瑜对玩家发动反间")
	_expect(game2._fanjian_target == game2.player1, "AI 反间目标为玩家")
	game2.queue_free()
	await get_tree().process_frame


## 借刀杀人：玩家使用时可指定“被出杀”的目标；AI 使用则固定指定自己。
func _test_borrow_sword_designated_target() -> void:
	## 玩家使用：指定 AI1 对 AI2 出杀。
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	game.enemies[0].weapon = QinggangSword.new()
	_set_hand(game.player1, [BorrowSwordCard.new()])
	_set_hand(game.enemies[0], [SlashCard.new()])
	_set_hand(game.enemies[1], [])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain(game)
	_expect(game.flow_state == GameManager.FlowState.SELECTING_TARGET, "玩家使用借刀杀人后选择指定出杀目标")
	game.request_target(2)
	_expect(game.flow_state == GameManager.FlowState.BORROW_RESPONSE, "指定 AI2 后进入借刀响应")
	game._perform_ai_response()
	game._perform_ai_response()
	_expect(game.enemies[1].hp == game.enemies[1].max_hp - 1, "AI1 按指定对 AI2 出杀并造成伤害")
	_expect(game.enemies[0].hand.is_empty(), "AI1 打出杀响应借刀")
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "借刀结算完成回到出牌阶段")
	game.queue_free()
	await get_tree().process_frame
	## AI 使用：固定指定自己。
	var game2 := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game2)
	var p1_weapon := QinggangSword.new()
	game2.player1.weapon = p1_weapon
	_set_hand(game2.enemies[0], [BorrowSwordCard.new()])
	_set_hand(game2.player1, [])
	_set_hand(game2.enemies[1], [])
	game2._use_target_trick(game2.enemies[0], game2.player1, 0)
	_pass_nullification_chain(game2)
	_expect(game2._borrow_slash_target == game2.enemies[0], "AI 使用借刀杀人时指定自己为出杀目标")
	game2._borrow_give_weapon()
	_expect(game2.player1.weapon == null and game2.enemies[0].hand.has(p1_weapon), "玩家不出杀则交出武器给 AI")
	game2.queue_free()
	await get_tree().process_frame


## AI 大乔【流离】在 1v2 中转移【杀】的目标。
func _test_ai_liuli_transfer() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game, &"daqiao", &"lvbu")
	_set_hand(game.player1, [SlashCard.new()])
	_set_hand(game.enemies[0], [PeachCard.new()])
	_set_hand(game.enemies[1], [])
	game.request_card_on_target(0, 1)
	await get_tree().create_timer(0.45).timeout
	_expect(game.pending_target == game.enemies[1] or game.enemies[1].hp < game.enemies[1].max_hp or game.enemies[0].hand.is_empty(), "AI 大乔成功发动【流离】转移【杀】的目标")
	game.queue_free()
	await get_tree().process_frame


## AI 貂蝉【离间】在 1v2 中令两名男性使用【决斗】。
func _test_ai_lijian_in_1v2() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game, &"diaochan", &"lvbu")
	game.current_player_index = 1
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.phase = GameManager.Phase.PLAY
	_set_hand(game.enemies[0], [PeachCard.new()])
	_set_hand(game.player1, [])
	_set_hand(game.enemies[1], [])
	game._perform_ai_play()
	_expect(game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE or game.flow_state == GameManager.FlowState.DUEL_RESPONSE or game.enemies[1].hp < game.enemies[1].max_hp or game.player1.hp < game.player1.max_hp, "AI 貂蝉在 1v2 中成功发动【离间】")
	game.queue_free()
	await get_tree().process_frame


## AI 孙尚香【结姻】优先选择受伤男性 AI 队友而非敌人。
func _test_ai_jieyin_targets_ally() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game, &"sunshangxiang", &"lvbu")
	game.current_player_index = 1
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.phase = GameManager.Phase.PLAY
	game.player1.hp = game.player1.max_hp - 1
	game.enemies[0].hp = game.enemies[0].max_hp
	game.enemies[1].hp = game.enemies[1].max_hp - 1
	var reserved_peach := PeachCard.new()
	_set_hand(game.enemies[0], [reserved_peach, DodgeCard.new(), NullificationCard.new()])
	game._perform_ai_play()
	_expect(
		game.enemies[0].hp == game.enemies[0].max_hp
		and game.enemies[1].hp == game.enemies[1].max_hp
		and game.player1.hp == game.player1.max_hp - 1,
		"满血 AI 孙尚香【结姻】治疗受伤男性队友且不治疗敌方主公"
	)
	_expect(
		reserved_peach in game.enemies[0].hand and game.enemies[0].hand.size() == 1,
		"AI 孙尚香发动【结姻】时保留【桃】，只弃置另外两张牌"
	)
	game.queue_free()
	await get_tree().process_frame

	## 满血反贼孙尚香面对受伤主公时不得弃两牌给敌方回血。
	var game2 := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game2, &"sunshangxiang", &"lvbu")
	game2.current_player_index = 1
	game2.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game2.phase = GameManager.Phase.PLAY
	game2.player1.hp = game2.player1.max_hp - 1
	game2.enemies[0].hp = game2.enemies[0].max_hp
	game2.enemies[1].hp = game2.enemies[1].max_hp
	var keep1 := DodgeCard.new()
	var keep2 := NullificationCard.new()
	_set_hand(game2.enemies[0], [keep1, keep2])
	game2._perform_ai_play()
	_expect(
		game2.player1.hp == game2.player1.max_hp - 1
		and keep1 in game2.enemies[0].hand and keep2 in game2.enemies[0].hand,
		"满血反贼孙尚香不会对受伤主公发动负收益【结姻】"
	)
	game2.queue_free()
	await get_tree().process_frame


## AI 华佗【青囊】在自己满血时治疗受伤 AI 队友。
func _test_ai_qingnang_heals_ally() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game, &"huatuo", &"lvbu")
	game.current_player_index = 1
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.phase = GameManager.Phase.PLAY
	game.enemies[0].hp = game.enemies[0].max_hp
	game.enemies[1].hp = game.enemies[1].max_hp - 1
	_set_hand(game.enemies[0], [SlashCard.new()])
	game._perform_ai_play()
	_expect(game.enemies[1].hp == game.enemies[1].max_hp, "AI 华佗【青囊】在自己满血时治疗受伤队友")
	game.queue_free()
	await get_tree().process_frame


## AI 司马懿把同身份角色视为队友：不恶化好判定，并会改善坏判定。
func _test_ai_guicai_respects_team() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game, &"simayi", &"lvbu")
	var owner: BattlePlayer = game.enemies[0]
	var ally: BattlePlayer = game.enemies[1]
	var reason: StringName = StringName("delayed_%d" % int(Card.CardType.INDULGENCE))
	var good := PeachCard.new(); good.suit = Card.Suit.HEART
	var bad := SlashCard.new(); bad.suit = Card.Suit.SPADE
	_set_hand(owner, [bad])
	_expect(
		game._ai_guicai_card_index(owner, JudgementContext.new(reason, ally, good)) == -1,
		"AI 鬼才不会用坏牌恶化队友已成功的判定"
	)
	var helpful := PeachCard.new(); helpful.suit = Card.Suit.HEART
	_set_hand(owner, [helpful])
	_expect(
		game._ai_guicai_card_index(owner, JudgementContext.new(reason, ally, bad)) == 0,
		"AI 鬼才会改善同阵营队友的不利判定"
	)
	game.queue_free()
	await get_tree().process_frame


## AI 顺手牵羊使用完整目标规则，能选择零手牌但有装备的敌人。
func _test_ai_steal_equipment_target() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	game.player1.is_ai = true
	game.current_player_index = 0
	game.phase = GameManager.Phase.PLAY
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	var weapon := QinggangSword.new()
	game.enemies[0].weapon = weapon
	_set_hand(game.player1, [StealCard.new()])
	_set_hand(game.enemies[0], [])
	_set_hand(game.enemies[1], [])
	game._perform_ai_play()
	_pass_nullification_chain(game)
	_expect(
		game.enemies[0].weapon == null and weapon in game.player1.hand,
		"AI 顺手牵羊可取得零手牌目标的装备"
	)
	game.queue_free()
	await get_tree().process_frame


## AI 仁德仅向队友直接交牌且一次达到回复阈值；无队友的主公不会进入选择死锁。
func _test_ai_rende_is_bounded() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game, &"liubei", &"xuchu")
	var liubei: BattlePlayer = game.enemies[0]
	var ally: BattlePlayer = game.enemies[1]
	game.current_player_index = 1
	game.phase = GameManager.Phase.PLAY
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	liubei.hp = liubei.max_hp - 1
	_set_hand(liubei, [DodgeCard.new(), DodgeCard.new()])
	_set_hand(ally, [])
	game._perform_ai_play()
	_expect(
		ally.hand.size() == 2 and liubei.hp == liubei.max_hp
		and game.flow_state == GameManager.FlowState.PLAY_ACTIVE,
		"AI 刘备一次完成有界仁德并回到出牌状态"
	)
	game.queue_free()
	await get_tree().process_frame

	var game2 := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game2, &"xuchu", &"simayi")
	game2.player1.assign_general(GeneralFactory.create_general(&"liubei"))
	game2.player1.is_ai = true
	game2.current_player_index = 0
	game2.phase = GameManager.Phase.PLAY
	game2.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game2.player1.hp = game2.player1.max_hp - 1
	_set_hand(game2.player1, [DodgeCard.new(), NullificationCard.new()])
	game2._perform_ai_play()
	_expect(
		game2.flow_state not in [GameManager.FlowState.SKILL_SELECT_CARDS, GameManager.FlowState.SKILL_SELECT_TARGET],
		"刘备对许褚+司马懿且无队友时不进入仁德选择死锁"
	)
	game2.queue_free()
	await get_tree().process_frame


## 报告中的固定组合高倍速跑多个回合，AI 决策必须自然推进且不依赖 Watchdog。
func _test_liubei_xuchu_simayi_no_watchdog_loop() -> void:
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 100.0
	var game := _make_game(2)
	await get_tree().process_frame
	game.setup_generals(&"liubei", &"xuchu")
	game.players[2].assign_general(GeneralFactory.create_general(&"simayi"))
	for player: BattlePlayer in game.players:
		player.is_ai = true
	game.watchdog_interval = 0.25
	game.start_match()
	var first_turn: int = game.turn_number
	var initial_kicks: int = game._watchdog_kick_count
	var guard: int = 0
	while (
		game.flow_state != GameManager.FlowState.GAME_OVER
		and game.turn_number <= first_turn + 8
		and guard < 4000
	):
		await get_tree().process_frame
		guard += 1
	_expect(guard < 4000, "刘备对许褚+司马懿在限定帧内推进多个回合")
	_expect(game._watchdog_kick_count == initial_kicks, "固定组合多回合运行无需 Watchdog 驱动")
	game.queue_free()
	await get_tree().process_frame
	Engine.time_scale = previous_scale


## 第二轮报告声称的输入组合即使强制保留重复张辽，也必须由正常 AI 回调推进。
func _test_simayi_double_zhangliao_no_watchdog_loop() -> void:
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 100.0
	var game := _make_game(2)
	await get_tree().process_frame
	game.setup_generals(&"simayi", &"zhangliao")
	for player: BattlePlayer in game.players:
		player.is_ai = true
	game.watchdog_interval = 0.25
	game.start_match(false)
	## 正式模式会去重；此处在开局复位后重新注入，仅用于覆盖报告声称的精确阵容。
	game.players[2].assign_general(GeneralFactory.create_general(&"zhangliao"))
	game._begin_turn()
	var first_turn: int = game.turn_number
	var initial_kicks: int = game._watchdog_kick_count
	var guard: int = 0
	while (
		game.flow_state != GameManager.FlowState.GAME_OVER
		and game.turn_number <= first_turn + 8
		and guard < 4000
	):
		await get_tree().process_frame
		guard += 1
	_expect(guard < 4000, "司马懿对双张辽在限定帧内推进多个回合")
	_expect(game._watchdog_kick_count == initial_kicks, "司马懿对双张辽无需 Watchdog 驱动")
	game.queue_free()
	await get_tree().process_frame
	Engine.time_scale = previous_scale


## 守恒统计必须包含私有区、展示区与其他临时区域；牌厂当前实际基准为103张。
func _test_card_count_invariant_transient_zones() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2(game)
	var baseline: int = game.match_card_count
	_expect(baseline == 103 and game.card_count_invariant_holds(), "开局实体牌基准为103且总量守恒")
	game._begin_guanxing(game.player1, Callable(game, "_return_to_play"))
	_expect(game.tracked_card_count() == baseline, "观星私有区计入实体牌守恒")
	game.request_cancel_deck_reorder()
	game._begin_yiji(game.player1, Callable(game, "_return_to_play"))
	_expect(game.tracked_card_count() == baseline, "遗计私有区计入实体牌守恒")
	game.request_cancel_card_assignment()
	for _index: int in 3:
		game.revealed_cards.append(game.draw_pile.pop_back())
	_expect(game.tracked_card_count() == baseline, "五谷展示区计入实体牌守恒")
	for card: Card in game.revealed_cards:
		game.draw_pile.append(card)
	game.revealed_cards.clear()
	_expect(game.card_count_invariant_holds(), "临时区域归还后实体牌仍严格守恒")
	game.queue_free()
	await get_tree().process_frame


## AI 郭嘉【遗计】优先分配牌给需要的 AI 队友。
func _test_ai_yiji_team_allocation() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game, &"guojia", &"lvbu")
	game.enemies[1].hp = 1
	var peach := PeachCard.new()
	var wine := WineCard.new()
	game.private_cards = [peach, wine]
	game._begin_yiji(game.enemies[0], Callable())
	await get_tree().create_timer(0.35).timeout
	_expect(game.enemies[1].hand.size() > 0, "AI 郭嘉【遗计】将自救牌分配给低血量 AI 队友")
	game.queue_free()
	await get_tree().process_frame


## AI 诸葛亮【观星】根据存活人数计算张数(1v2中为3张)，并根据判定区规避劣势。
func _test_ai_guanxing_judgement_optimization() -> void:
	var game := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game, &"zhugeliang", &"lvbu")
	var c1 := SlashCard.new(); c1.suit = Card.Suit.SPADE; c1.rank = 7
	var c2 := PeachCard.new(); c2.suit = Card.Suit.HEART; c2.rank = 9
	var c3 := DodgeCard.new(); c3.suit = Card.Suit.DIAMOND; c3.rank = 3
	game.draw_pile = [c3, c2, c1]
	game.enemies[0].indulgence_card = IndulgenceCard.new()
	game._begin_guanxing(game.enemies[0], Callable())
	_expect(game.private_cards.size() == 3, "1v2 模式下观星张数为 min(5, 3) = 3 张")
	_expect(game.deck_reorder_top.front() == c2, "AI 诸葛亮【观星】自动将红桃牌放在最顶部规避【乐不思蜀】")
	game.queue_free()
	await get_tree().process_frame

	var game2 := _make_game(2)
	await get_tree().process_frame
	_start_battle2_with_generals(game2, &"zhugeliang", &"lvbu")
	var s1 := SlashCard.new(); s1.suit = Card.Suit.SPADE; s1.rank = 7
	var s2 := DismantleCard.new(); s2.suit = Card.Suit.CLUB; s2.rank = 10
	var s3 := DodgeCard.new(); s3.suit = Card.Suit.DIAMOND; s3.rank = 3
	game2.draw_pile = [s3, s2, s1]
	game2.enemies[0].supply_shortage_card = SupplyShortageCard.new()
	game2._begin_guanxing(game2.enemies[0], Callable())
	_expect(game2.deck_reorder_top.front() == s2, "AI 诸葛亮【观星】自动将梅花牌放在最顶部规避【兵粮寸断】")
	game2.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
